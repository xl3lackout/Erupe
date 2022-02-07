// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#include "arrow/csv/writer.h"
#include "arrow/array.h"
#include "arrow/compute/cast.h"
#include "arrow/io/interfaces.h"
#include "arrow/ipc/writer.h"
#include "arrow/record_batch.h"
#include "arrow/result.h"
#include "arrow/result_internal.h"
#include "arrow/stl_allocator.h"
#include "arrow/util/iterator.h"
#include "arrow/util/logging.h"
#include "arrow/util/make_unique.h"

#include "arrow/visitor_inline.h"

namespace arrow {
namespace csv {
// This implementation is intentionally light on configurability to minimize the size of
// the initial PR. Additional features can be added as there is demand and interest to
// implement them.
//
// The algorithm used here at a high level is to break RecordBatches/Tables into slices
// and convert each slice independently.  A slice is then converted to CSV by first
// scanning each column to determine the size of its contents when rendered as a string in
// CSV. For non-string types this requires casting the value to string (which is cached).
// This data is used to understand the precise length of each row and a single allocation
// for the final CSV data buffer. Once the final size is known each column is then
// iterated over again to place its contents into the CSV data buffer. The rationale for
// choosing this approach is it allows for reuse of the cast functionality in the compute
// module and inline data visiting functionality in the core library. A performance
// comparison has not been done using a naive single-pass approach. This approach might
// still be competitive due to reduction in the number of per row branches necessary with
// a single pass approach. Profiling would likely yield further opportunities for
// optimization with this approach.

namespace {

struct SliceIteratorFunctor {
  Result<std::shared_ptr<RecordBatch>> Next() {
    if (current_offset < batch->num_rows()) {
      std::shared_ptr<RecordBatch> next = batch->Slice(current_offset, slice_size);
      current_offset += slice_size;
      return next;
    }
    return IterationTraits<std::shared_ptr<RecordBatch>>::End();
  }
  const RecordBatch* const batch;
  const int64_t slice_size;
  int64_t current_offset;
};

RecordBatchIterator RecordBatchSliceIterator(const RecordBatch& batch,
                                             int64_t slice_size) {
  SliceIteratorFunctor functor = {&batch, slice_size, /*offset=*/static_cast<int64_t>(0)};
  return RecordBatchIterator(std::move(functor));
}

// Counts the number of quotes in s.
int64_t CountQuotes(util::string_view s) {
  return static_cast<int64_t>(std::count(s.begin(), s.end(), '"'));
}

// Matching quote pair character length.
constexpr int64_t kQuoteCount = 2;
constexpr int64_t kQuoteDelimiterCount = kQuoteCount + /*end_char*/ 1;
constexpr const char* kStrComma = ",";

// Interface for generating CSV data per column.
// The intended usage is to iteratively call UpdateRowLengths for a column and
// then PopulateColumns. PopulateColumns must be called in the reverse order of the
// populators (it populates data backwards).
class ColumnPopulator {
 public:
  ColumnPopulator(MemoryPool* pool, std::string end_chars,
                  std::shared_ptr<Buffer> null_string)
      : end_chars_(std::move(end_chars)),
        null_string_(std::move(null_string)),
        pool_(pool) {}

  virtual ~ColumnPopulator() = default;

  // Adds the number of characters each entry in data will add to to elements
  // in row_lengths.
  Status UpdateRowLengths(const Array& data, int32_t* row_lengths) {
    compute::ExecContext ctx(pool_);
    // Populators are intented to be applied to reasonably small data.  In most cases
    // threading overhead would not be justified.
    ctx.set_use_threads(false);
    ASSIGN_OR_RAISE(
        std::shared_ptr<Array> casted,
        compute::Cast(data, /*to_type=*/utf8(), compute::CastOptions(), &ctx));
    casted_array_ = internal::checked_pointer_cast<StringArray>(casted);
    return UpdateRowLengths(row_lengths);
  }

  // Places string data onto each row in output and updates the corresponding row
  // row pointers in preparation for calls to other (preceding) ColumnPopulators.
  // Implementations may apply certain checks e.g. for illegal values, which in case of
  // failure causes this function to return an error Status.
  // Args:
  //   output: character buffer to write to.
  //   offsets: an array of end of row column within the the output buffer (values are
  //   one past the end of the position to write to).
  virtual Status PopulateColumns(char* output, int32_t* offsets) const = 0;

 protected:
  virtual Status UpdateRowLengths(int32_t* row_lengths) = 0;
  std::shared_ptr<StringArray> casted_array_;
  const std::string end_chars_;
  std::shared_ptr<Buffer> null_string_;

 private:
  MemoryPool* const pool_;
};

// Copies the contents of to out properly escaping any necessary characters.
// Returns the position prior to last copied character (out_end is decremented).
char* EscapeReverse(arrow::util::string_view s, char* out_end) {
  for (const char* val = s.data() + s.length() - 1; val >= s.data(); val--, out_end--) {
    if (*val == '"') {
      *out_end = *val;
      out_end--;
    }
    *out_end = *val;
  }
  return out_end;
}

// Populator used for non-string/binary types, or when unquoted strings/binary types are
// desired. It assumes the strings in the casted array do not require quoting or escaping.
// This is enforced by setting reject_values_with_quotes to true, in which case a check
// for quotes is applied and will cause populating the columns to fail. This guarantees
// compliance with RFC4180 section 2.5.
class UnquotedColumnPopulator : public ColumnPopulator {
 public:
  explicit UnquotedColumnPopulator(MemoryPool* memory_pool, std::string end_chars,
                                   std::shared_ptr<Buffer> null_string_,
                                   bool reject_values_with_quotes)
      : ColumnPopulator(memory_pool, std::move(end_chars), std::move(null_string_)),
        reject_values_with_quotes_(reject_values_with_quotes) {}

  Status UpdateRowLengths(int32_t* row_lengths) override {
    for (int x = 0; x < casted_array_->length(); x++) {
      row_lengths[x] += casted_array_->IsNull(x)
                            ? static_cast<int32_t>(null_string_->size())
                            : casted_array_->value_length(x);
    }
    return Status::OK();
  }

  Status PopulateColumns(char* output, int32_t* offsets) const override {
    // Function applied to valid values cast to string.
    auto valid_function = [&](arrow::util::string_view s) {
      int32_t next_column_offset = static_cast<int32_t>(s.length() + end_chars_.size());
      memcpy((output + *offsets - next_column_offset), s.data(), s.length());
      memcpy((output + *offsets - end_chars_.size()), end_chars_.c_str(),
             end_chars_.size());
      *offsets -= next_column_offset;
      offsets++;
      return Status::OK();
    };

    // Function applied to null values cast to string.
    auto null_function = [&]() {
      // For nulls, the configured null value string is copied into the output.
      int32_t next_column_offset =
          static_cast<int32_t>(null_string_->size() + end_chars_.size());
      memcpy((output + *offsets - next_column_offset), null_string_->data(),
             null_string_->size());
      memcpy((output + *offsets - end_chars_.size()), end_chars_.c_str(),
             end_chars_.size());
      *offsets -= next_column_offset;
      offsets++;
      return Status::OK();
    };

    if (reject_values_with_quotes_) {
      // When using this UnquotedColumnPopulator on values that, after casting, could
      // produce quotes, we need to return an error in accord with RFC4180. We need to
      // precede valid_func with a check.
      return VisitArrayDataInline<StringType>(
          *casted_array_->data(),
          [&](arrow::util::string_view s) {
            RETURN_NOT_OK(CheckStringHasNoStructuralChars(s));
            return valid_function(s);
          },
          null_function);
    } else {
      // Populate without checking and rejecting values with quotes.
      return VisitArrayDataInline<StringType>(*casted_array_->data(), valid_function,
                                              null_function);
    }
  }

 private:
  // Returns an error status if s has any structural characters.
  static Status CheckStringHasNoStructuralChars(const util::string_view& s) {
    if (std::any_of(s.begin(), s.end(), [](const char& c) {
          return c == '\n' || c == '\r' || c == ',' || c == '"';
        })) {
      return Status::Invalid(
          "CSV values may not contain structural characters if quoting style is "
          "\"None\". See RFC4180. Invalid value: ",
          s);
    }
    return Status::OK();
  }

  // Whether to reject values with quotes when populating.
  const bool reject_values_with_quotes_;
};

// Strings need special handling to ensure they are escaped properly.
// This class handles escaping assuming that all strings will be quoted
// and that the only character within the string that needs to escaped is
// a quote character (") and escaping is done my adding another quote.
class QuotedColumnPopulator : public ColumnPopulator {
 public:
  QuotedColumnPopulator(MemoryPool* pool, std::string end_chars,
                        std::shared_ptr<Buffer> null_string)
      : ColumnPopulator(pool, std::move(end_chars), std::move(null_string)) {}

  Status UpdateRowLengths(int32_t* row_lengths) override {
    const StringArray& input = *casted_array_;
    int row_number = 0;
    row_needs_escaping_.resize(casted_array_->length());
    VisitArrayDataInline<StringType>(
        *input.data(),
        [&](arrow::util::string_view s) {
          // Each quote in the value string needs to be escaped.
          int64_t escaped_count = CountQuotes(s);
          // TODO: Maybe use 64 bit row lengths or safe cast?
          row_needs_escaping_[row_number] = escaped_count > 0;
          row_lengths[row_number] += static_cast<int32_t>(s.length()) +
                                     static_cast<int32_t>(escaped_count + kQuoteCount);
          row_number++;
        },
        [&]() {
          row_needs_escaping_[row_number] = false;
          row_lengths[row_number] += static_cast<int32_t>(null_string_->size());
          row_number++;
        });
    return Status::OK();
  }

  Status PopulateColumns(char* output, int32_t* offsets) const override {
    auto needs_escaping = row_needs_escaping_.begin();
    VisitArrayDataInline<StringType>(
        *(casted_array_->data()),
        [&](arrow::util::string_view s) {
          // still needs string content length to be added
          char* row_end = output + *offsets;
          int32_t next_column_offset = 0;
          if (!*needs_escaping) {
            next_column_offset = static_cast<int32_t>(s.length() + kQuoteDelimiterCount);
            memcpy(row_end - next_column_offset + /*quote_offset=*/1, s.data(),
                   s.length());
          } else {
            // Adjust row_end by 2 + end_chars_.size(): 1 quote char, end_chars_.size()
            // and 1 to position at the first position to write to.
            next_column_offset = static_cast<int32_t>(
                row_end - EscapeReverse(s, row_end - 2 - end_chars_.size()));
          }
          *(row_end - next_column_offset) = '"';
          *(row_end - end_chars_.size() - 1) = '"';
          memcpy(row_end - end_chars_.size(), end_chars_.data(), end_chars_.length());
          *offsets -= next_column_offset;
          offsets++;
          needs_escaping++;
        },
        [&]() {
          // For nulls, the configured null value string is copied into the output.
          int32_t next_column_offset =
              static_cast<int32_t>(null_string_->size() + end_chars_.size());
          memcpy((output + *offsets - next_column_offset), null_string_->data(),
                 null_string_->size());
          memcpy((output + *offsets - end_chars_.size()), end_chars_.c_str(),
                 end_chars_.size());
          *offsets -= next_column_offset;
          offsets++;
          needs_escaping++;
        });

    return Status::OK();
  }

 private:
  // Older version of GCC don't support custom allocators
  // at some point we should change this to use memory_pool
  // backed allocator.
  std::vector<bool> row_needs_escaping_;
};

struct PopulatorFactory {
  template <typename TypeClass>
  enable_if_t<is_base_binary_type<TypeClass>::value ||
                  std::is_same<FixedSizeBinaryType, TypeClass>::value,
              Status>
  Visit(const TypeClass& type) {
    // Determine what ColumnPopulator to use based on desired CSV quoting style.
    switch (quoting_style) {
      case QuotingStyle::None:
        // In unquoted output we must reject values with quotes. Since these types can
        // produce quotes in their output rendering, we must check them and reject if
        // quotes appear, hence reject_values_with_quotes is set to true.
        populator = new UnquotedColumnPopulator(pool, end_chars, null_string,
                                                /*reject_values_with_quotes=*/true);
        break;
        // Quoting is needed for strings/binary, or when all valid values need to be
        // quoted.
      case QuotingStyle::Needed:
      case QuotingStyle::AllValid:
        populator = new QuotedColumnPopulator(pool, end_chars, null_string);
        break;
    }
    return Status::OK();
  }

  template <typename TypeClass>
  enable_if_dictionary<TypeClass, Status> Visit(const TypeClass& type) {
    return VisitTypeInline(*type.value_type(), this);
  }

  template <typename TypeClass>
  enable_if_t<is_nested_type<TypeClass>::value || is_extension_type<TypeClass>::value,
              Status>
  Visit(const TypeClass& type) {
    return Status::Invalid("Unsupported Type:", type.ToString());
  }

  template <typename TypeClass>
  enable_if_t<is_primitive_ctype<TypeClass>::value || is_decimal_type<TypeClass>::value ||
                  is_null_type<TypeClass>::value || is_temporal_type<TypeClass>::value,
              Status>
  Visit(const TypeClass& type) {
    // Determine what ColumnPopulator to use based on desired CSV quoting style.
    switch (quoting_style) {
        // These types are assumed not to produce any quotes, so we do not need to check
        // and reject for potential quotes in the casted values in case the QuotingStyle
        // is None.
      case QuotingStyle::None:
      case QuotingStyle::Needed:
        populator = new UnquotedColumnPopulator(pool, end_chars, null_string,
                                                /*reject_values_with_quotes=*/false);
        break;
      case QuotingStyle::AllValid:
        populator = new QuotedColumnPopulator(pool, end_chars, null_string);
        break;
    }
    return Status::OK();
  }

  const std::string end_chars;
  std::shared_ptr<Buffer> null_string;
  const QuotingStyle quoting_style;
  MemoryPool* pool;
  ColumnPopulator* populator;
};

Result<std::unique_ptr<ColumnPopulator>> MakePopulator(
    const Field& field, std::string end_chars, std::shared_ptr<Buffer> null_string,
    QuotingStyle quoting_style, MemoryPool* pool) {
  PopulatorFactory factory{std::move(end_chars), std::move(null_string), quoting_style,
                           pool, nullptr};

  RETURN_NOT_OK(VisitTypeInline(*field.type(), &factory));
  return std::unique_ptr<ColumnPopulator>(factory.populator);
}

class CSVWriterImpl : public ipc::RecordBatchWriter {
 public:
  static Result<std::shared_ptr<CSVWriterImpl>> Make(
      io::OutputStream* sink, std::shared_ptr<io::OutputStream> owned_sink,
      std::shared_ptr<Schema> schema, const WriteOptions& options) {
    RETURN_NOT_OK(options.Validate());
    // Reject null string values that contain quotes.
    if (CountQuotes(options.null_string) != 0) {
      return Status::Invalid("Null string cannot contain quotes.");
    }

    ASSIGN_OR_RAISE(std::shared_ptr<Buffer> null_string,
                    arrow::AllocateBuffer(options.null_string.length()));
    memcpy(null_string->mutable_data(), options.null_string.data(),
           options.null_string.length());

    std::vector<std::unique_ptr<ColumnPopulator>> populators(schema->num_fields());
    for (int col = 0; col < schema->num_fields(); col++) {
      const std::string& end_chars =
          col < schema->num_fields() - 1 ? kStrComma : options.eol;
      ASSIGN_OR_RAISE(populators[col],
                      MakePopulator(*schema->field(col), end_chars, null_string,
                                    options.quoting_style, options.io_context.pool()));
    }
    auto writer = std::make_shared<CSVWriterImpl>(
        sink, std::move(owned_sink), std::move(schema), std::move(populators), options);
    RETURN_NOT_OK(writer->PrepareForContentsWrite());
    if (options.include_header) {
      RETURN_NOT_OK(writer->WriteHeader());
    }
    return writer;
  }

  Status WriteRecordBatch(const RecordBatch& batch) override {
    RecordBatchIterator iterator = RecordBatchSliceIterator(batch, options_.batch_size);
    for (auto maybe_slice : iterator) {
      ASSIGN_OR_RAISE(std::shared_ptr<RecordBatch> slice, maybe_slice);
      RETURN_NOT_OK(TranslateMinimalBatch(*slice));
      RETURN_NOT_OK(sink_->Write(data_buffer_));
      stats_.num_record_batches++;
    }
    return Status::OK();
  }

  Status WriteTable(const Table& table, int64_t max_chunksize) override {
    TableBatchReader reader(table);
    reader.set_chunksize(max_chunksize > 0 ? max_chunksize : options_.batch_size);
    std::shared_ptr<RecordBatch> batch;
    RETURN_NOT_OK(reader.ReadNext(&batch));
    while (batch != nullptr) {
      RETURN_NOT_OK(TranslateMinimalBatch(*batch));
      RETURN_NOT_OK(sink_->Write(data_buffer_));
      RETURN_NOT_OK(reader.ReadNext(&batch));
      stats_.num_record_batches++;
    }

    return Status::OK();
  }

  Status Close() override { return Status::OK(); }

  ipc::WriteStats stats() const override { return stats_; }

  CSVWriterImpl(io::OutputStream* sink, std::shared_ptr<io::OutputStream> owned_sink,
                std::shared_ptr<Schema> schema,
                std::vector<std::unique_ptr<ColumnPopulator>> populators,
                const WriteOptions& options)
      : sink_(sink),
        owned_sink_(std::move(owned_sink)),
        column_populators_(std::move(populators)),
        offsets_(0, 0, ::arrow::stl::allocator<char*>(options.io_context.pool())),
        schema_(std::move(schema)),
        options_(options) {}

 private:
  Status PrepareForContentsWrite() {
    // Only called once, as part of initialization
    if (data_buffer_ == nullptr) {
      ASSIGN_OR_RAISE(data_buffer_,
                      AllocateResizableBuffer(
                          options_.batch_size * schema_->num_fields() * kColumnSizeGuess,
                          options_.io_context.pool()));
    }
    return Status::OK();
  }

  int64_t CalculateHeaderSize() const {
    int64_t header_length = 0;
    for (int col = 0; col < schema_->num_fields(); col++) {
      const std::string& col_name = schema_->field(col)->name();
      header_length += col_name.size();
      header_length += CountQuotes(col_name);
    }
    // header_length + ([quotes + ','] * schema_->num_fields()) + (eol - ',')
    return header_length + (kQuoteDelimiterCount * schema_->num_fields()) +
           (options_.eol.size() - 1);
  }

  Status WriteHeader() {
    // Only called once, as part of initialization
    RETURN_NOT_OK(data_buffer_->Resize(CalculateHeaderSize(), /*shrink_to_fit=*/false));
    char* next = reinterpret_cast<char*>(data_buffer_->mutable_data() +
                                         data_buffer_->size() - options_.eol.size());
    for (int col = schema_->num_fields() - 1; col >= 0; col--) {
      *next-- = ',';
      *next-- = '"';
      next = EscapeReverse(schema_->field(col)->name(), next);
      *next-- = '"';
    }
    memcpy(data_buffer_->mutable_data() + data_buffer_->size() - options_.eol.size(),
           options_.eol.data(), options_.eol.size());
    DCHECK_EQ(reinterpret_cast<uint8_t*>(next + 1), data_buffer_->data());
    return sink_->Write(data_buffer_);
  }

  Status TranslateMinimalBatch(const RecordBatch& batch) {
    if (batch.num_rows() == 0) {
      return Status::OK();
    }
    offsets_.resize(batch.num_rows());
    std::fill(offsets_.begin(), offsets_.end(), 0);

    // Calculate relative offsets for each row (excluding delimiters)
    for (int32_t col = 0; col < static_cast<int32_t>(column_populators_.size()); col++) {
      RETURN_NOT_OK(
          column_populators_[col]->UpdateRowLengths(*batch.column(col), offsets_.data()));
    }
    // Calculate cumulative offsets for each row (including delimiters).
    // ',' * num_columns - 1(last column doesn't have ,) + eol
    int32_t delimiters_length =
        static_cast<int32_t>(batch.num_columns() - 1 + options_.eol.size());
    offsets_[0] += delimiters_length;
    for (int64_t row = 1; row < batch.num_rows(); row++) {
      offsets_[row] += offsets_[row - 1] + delimiters_length;
    }
    // Resize the target buffer to required size. We assume batch to batch sizes
    // should be pretty close so don't shrink the buffer to avoid allocation churn.
    RETURN_NOT_OK(data_buffer_->Resize(offsets_.back(), /*shrink_to_fit=*/false));

    // Use the offsets to populate contents.
    for (auto populator = column_populators_.rbegin();
         populator != column_populators_.rend(); populator++) {
      RETURN_NOT_OK(
          (*populator)
              ->PopulateColumns(reinterpret_cast<char*>(data_buffer_->mutable_data()),
                                offsets_.data()));
    }
    DCHECK_EQ(0, offsets_[0]);
    return Status::OK();
  }

  static constexpr int64_t kColumnSizeGuess = 8;
  io::OutputStream* sink_;
  std::shared_ptr<io::OutputStream> owned_sink_;
  std::vector<std::unique_ptr<ColumnPopulator>> column_populators_;
  std::vector<int32_t, arrow::stl::allocator<int32_t>> offsets_;
  std::shared_ptr<ResizableBuffer> data_buffer_;
  const std::shared_ptr<Schema> schema_;
  const WriteOptions options_;
  ipc::WriteStats stats_;
};

}  // namespace

Status WriteCSV(const Table& table, const WriteOptions& options,
                arrow::io::OutputStream* output) {
  ASSIGN_OR_RAISE(auto writer, MakeCSVWriter(output, table.schema(), options));
  RETURN_NOT_OK(writer->WriteTable(table));
  return writer->Close();
}

Status WriteCSV(const RecordBatch& batch, const WriteOptions& options,
                arrow::io::OutputStream* output) {
  ASSIGN_OR_RAISE(auto writer, MakeCSVWriter(output, batch.schema(), options));
  RETURN_NOT_OK(writer->WriteRecordBatch(batch));
  return writer->Close();
}

Status WriteCSV(const std::shared_ptr<RecordBatchReader>& reader,
                const WriteOptions& options, arrow::io::OutputStream* output) {
  ASSIGN_OR_RAISE(auto writer, MakeCSVWriter(output, reader->schema(), options));
  std::shared_ptr<RecordBatch> batch;
  while (true) {
    ASSIGN_OR_RAISE(batch, reader->Next());
    if (batch == nullptr) break;
    RETURN_NOT_OK(writer->WriteRecordBatch(*batch));
  }
  return writer->Close();
}

ARROW_EXPORT
Result<std::shared_ptr<ipc::RecordBatchWriter>> MakeCSVWriter(
    std::shared_ptr<io::OutputStream> sink, const std::shared_ptr<Schema>& schema,
    const WriteOptions& options) {
  return CSVWriterImpl::Make(sink.get(), sink, schema, options);
}

ARROW_EXPORT
Result<std::shared_ptr<ipc::RecordBatchWriter>> MakeCSVWriter(
    io::OutputStream* sink, const std::shared_ptr<Schema>& schema,
    const WriteOptions& options) {
  return CSVWriterImpl::Make(sink, nullptr, schema, options);
}

}  // namespace csv
}  // namespace arrow
