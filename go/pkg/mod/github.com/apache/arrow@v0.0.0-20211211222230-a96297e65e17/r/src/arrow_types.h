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

#pragma once

#include <cpp11/R.hpp>

#include "./arrow_cpp11.h"

#if defined(ARROW_R_WITH_ARROW)

#include <arrow/buffer.h>  // for RBuffer definition below
#include <arrow/result.h>
#include <arrow/status.h>

#include <limits>
#include <memory>
#include <utility>

// forward declaration-only headers
#include <arrow/c/abi.h>
#include <arrow/compute/type_fwd.h>
#include <arrow/csv/type_fwd.h>

#if defined(ARROW_R_WITH_DATASET)
#include <arrow/dataset/type_fwd.h>
#endif

#include <arrow/filesystem/type_fwd.h>
#include <arrow/io/type_fwd.h>
#include <arrow/ipc/type_fwd.h>

#if defined(ARROW_R_WITH_JSON)
#include <arrow/json/type_fwd.h>
#endif

#include <arrow/type_fwd.h>
#include <arrow/util/type_fwd.h>

namespace arrow {
namespace compute {

class ExecPlan;
class ExecNode;

}  // namespace compute
}  // namespace arrow

#if defined(ARROW_R_WITH_PARQUET)
#include <parquet/type_fwd.h>
#endif

#if defined(ARROW_R_WITH_DATASET)
namespace ds = ::arrow::dataset;
#endif

namespace compute = ::arrow::compute;
namespace fs = ::arrow::fs;

std::shared_ptr<arrow::RecordBatch> RecordBatch__from_arrays(SEXP, SEXP);
arrow::MemoryPool* gc_memory_pool();
arrow::compute::ExecContext* gc_context();

#define VECTOR_PTR_RO(x) ((const SEXP*)DATAPTR_RO(x))

namespace arrow {

static inline void StopIfNotOk(const Status& status) {
  if (!status.ok()) {
    // ARROW-13039: be careful not to interpret our error message as a %-format string
    std::string s = status.ToString();
    cpp11::stop("%s", s.c_str());
  }
}

template <typename R>
auto ValueOrStop(R&& result) -> decltype(std::forward<R>(result).ValueOrDie()) {
  StopIfNotOk(result.status());
  return std::forward<R>(result).ValueOrDie();
}

namespace r {
class RTasks;

std::shared_ptr<arrow::DataType> InferArrowType(SEXP x);
std::shared_ptr<arrow::Array> vec_to_arrow__reuse_memory(SEXP x);
bool can_reuse_memory(SEXP x, const std::shared_ptr<arrow::DataType>& type);

Status count_fields(SEXP lst, int* out);

void inspect(SEXP obj);
std::shared_ptr<arrow::Array> vec_to_arrow_Array(
    SEXP x, const std::shared_ptr<arrow::DataType>& type, bool type_inferred);
std::shared_ptr<arrow::ChunkedArray> vec_to_arrow_ChunkedArray(
    SEXP x, const std::shared_ptr<arrow::DataType>& type, bool type_inferred);

// the integer64 sentinel
constexpr int64_t NA_INT64 = std::numeric_limits<int64_t>::min();

template <typename RVector>
class RBuffer : public MutableBuffer {
 public:
  explicit RBuffer(RVector vec)
      : MutableBuffer(reinterpret_cast<uint8_t*>(DATAPTR(vec)),
                      vec.size() * sizeof(typename RVector::value_type),
                      arrow::CPUDevice::memory_manager(gc_memory_pool())),
        vec_(vec) {}

 private:
  // vec_ holds the memory
  RVector vec_;
};

std::shared_ptr<arrow::DataType> InferArrowTypeFromFactor(SEXP);

void validate_slice_offset(R_xlen_t offset, int64_t len);

void validate_slice_length(R_xlen_t length, int64_t available);

void validate_index(int i, int len);

template <typename Lambda>
void TraverseDots(cpp11::list dots, int num_fields, Lambda lambda) {
  cpp11::strings names(dots.attr(R_NamesSymbol));

  for (R_xlen_t i = 0, j = 0; j < num_fields; i++) {
    auto name_i = names[i];

    if (name_i.size() == 0) {
      cpp11::list x_i = dots[i];
      cpp11::strings names_x_i(x_i.attr(R_NamesSymbol));
      R_xlen_t n_i = x_i.size();
      for (R_xlen_t k = 0; k < n_i; k++, j++) {
        lambda(j, x_i[k], names_x_i[k]);
      }
    } else {
      lambda(j, dots[i], name_i);
      j++;
    }
  }
}

inline cpp11::writable::list FlattenDots(cpp11::list dots, int num_fields) {
  std::vector<SEXP> out(num_fields);
  auto set = [&](int j, SEXP x, cpp11::r_string) { out[j] = x; };
  TraverseDots(dots, num_fields, set);

  return cpp11::writable::list(out.begin(), out.end());
}

arrow::Status InferSchemaFromDots(SEXP lst, SEXP schema_sxp, int num_fields,
                                  std::shared_ptr<arrow::Schema>& schema);

arrow::Status AddMetadataFromDots(SEXP lst, int num_fields,
                                  std::shared_ptr<arrow::Schema>& schema);

namespace altrep {

#if defined(HAS_ALTREP)
void Init_Altrep_classes(DllInfo* dll);
#endif

SEXP MakeAltrepVector(const std::shared_ptr<ChunkedArray>& chunked_array);
bool is_arrow_altrep(SEXP x);
std::shared_ptr<ChunkedArray> vec_to_arrow_altrep_bypass(SEXP);

}  // namespace altrep

}  // namespace r
}  // namespace arrow

namespace cpp11 {

template <typename T>
struct r6_class_name {
  static const char* get(const std::shared_ptr<T>& ptr) {
    static const std::string name = arrow::util::nameof<T>(/*strip_namespace=*/true);
    return name.c_str();
  }
};

// Overrides of default R6 class names:
#define R6_CLASS_NAME(CLASS, NAME)                                         \
  template <>                                                              \
  struct r6_class_name<CLASS> {                                            \
    static const char* get(const std::shared_ptr<CLASS>&) { return NAME; } \
  }

R6_CLASS_NAME(arrow::csv::ReadOptions, "CsvReadOptions");
R6_CLASS_NAME(arrow::csv::ParseOptions, "CsvParseOptions");
R6_CLASS_NAME(arrow::csv::ConvertOptions, "CsvConvertOptions");
R6_CLASS_NAME(arrow::csv::TableReader, "CsvTableReader");
R6_CLASS_NAME(arrow::csv::WriteOptions, "CsvWriteOptions");

#if defined(ARROW_R_WITH_PARQUET)
R6_CLASS_NAME(parquet::ArrowReaderProperties, "ParquetArrowReaderProperties");
R6_CLASS_NAME(parquet::ArrowWriterProperties, "ParquetArrowWriterProperties");
R6_CLASS_NAME(parquet::WriterProperties, "ParquetWriterProperties");
R6_CLASS_NAME(parquet::arrow::FileReader, "ParquetFileReader");
R6_CLASS_NAME(parquet::WriterPropertiesBuilder, "ParquetWriterPropertiesBuilder");
R6_CLASS_NAME(parquet::arrow::FileWriter, "ParquetFileWriter");
#endif

R6_CLASS_NAME(arrow::ipc::feather::Reader, "FeatherReader");

#if defined(ARROW_R_WITH_JSON)
R6_CLASS_NAME(arrow::json::ReadOptions, "JsonReadOptions");
R6_CLASS_NAME(arrow::json::ParseOptions, "JsonParseOptions");
R6_CLASS_NAME(arrow::json::TableReader, "JsonTableReader");
#endif

#undef R6_CLASS_NAME

// Declarations of discriminated base classes.
// Definitions reside in corresponding .cpp files.
template <>
struct r6_class_name<fs::FileSystem> {
  static const char* get(const std::shared_ptr<fs::FileSystem>&);
};

template <>
struct r6_class_name<arrow::Array> {
  static const char* get(const std::shared_ptr<arrow::Array>&);
};

template <>
struct r6_class_name<arrow::Scalar> {
  static const char* get(const std::shared_ptr<arrow::Scalar>&);
};

template <>
struct r6_class_name<arrow::DataType> {
  static const char* get(const std::shared_ptr<arrow::DataType>&);
};

#if defined(ARROW_R_WITH_DATASET)

template <>
struct r6_class_name<ds::Dataset> {
  static const char* get(const std::shared_ptr<ds::Dataset>&);
};

template <>
struct r6_class_name<ds::FileFormat> {
  static const char* get(const std::shared_ptr<ds::FileFormat>&);
};

#endif

}  // namespace cpp11

#endif
