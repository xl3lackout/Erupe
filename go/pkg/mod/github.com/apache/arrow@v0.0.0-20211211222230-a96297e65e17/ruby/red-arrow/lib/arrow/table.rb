# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require "arrow/raw-table-converter"

module Arrow
  class Table
    include ColumnContainable
    include GenericFilterable
    include GenericTakeable
    include RecordContainable

    class << self
      def load(path, options={})
        TableLoader.load(path, options)
      end
    end

    alias_method :initialize_raw, :initialize
    private :initialize_raw

    # Creates a new {Arrow::Table}.
    #
    # @overload initialize(columns)
    #
    #   @param columns [::Array<Arrow::Column>] The columns of the table.
    #
    #   @example Create a table from columns
    #     count_field = Arrow::Field.new("count", :uint32)
    #     count_array = Arrow::UInt32Array.new([0, 2, nil, 4])
    #     count_column = Arrow::Column.new(count_field, count_array)
    #     visible_field = Arrow::Field.new("visible", :boolean)
    #     visible_array = Arrow::BooleanArray.new([true, nil, nil, false])
    #     visible_column = Arrow::Column.new(visible_field, visible_array)
    #     Arrow::Table.new([count_column, visible_column])
    #
    # @overload initialize(raw_table)
    #
    #   @param raw_table [Hash<String, Arrow::Array>]
    #     The pairs of column name and values of the table. Column values is
    #     `Arrow::Array`.
    #
    #   @example Create a table from column name and values
    #     Arrow::Table.new("count" => Arrow::UInt32Array.new([0, 2, nil, 4]),
    #                      "visible" => Arrow::BooleanArray.new([true, nil, nil, false]))
    #
    # @overload initialize(raw_table)
    #
    #   @param raw_table [Hash<String, Arrow::ChunkedArray>]
    #     The pairs of column name and values of the table. Column values is
    #     `Arrow::ChunkedArray`.
    #
    #   @example Create a table from column name and values
    #     count_chunks = [
    #       Arrow::UInt32Array.new([0, 2]),
    #       Arrow::UInt32Array.new([nil, 4]),
    #     ]
    #     visible_chunks = [
    #       Arrow::BooleanArray.new([true]),
    #       Arrow::BooleanArray.new([nil, nil, false]),
    #     ]
    #     Arrow::Table.new("count" => Arrow::ChunkedArray.new(count_chunks),
    #                      "visible" => Arrow::ChunkedArray.new(visible_chunks))
    #
    # @overload initialize(raw_table)
    #
    #   @param raw_table [Hash<String, ::Array>]
    #     The pairs of column name and values of the table. Column values is
    #     `Array`.
    #
    #   @example Create a table from column name and values
    #     Arrow::Table.new("count" => [0, 2, nil, 4],
    #                      "visible" => [true, nil, nil, false])
    #
    # @overload initialize(schema, columns)
    #
    #   @param schema [Arrow::Schema] The schema of the table.
    #     You can also specify schema as primitive Ruby objects.
    #     See {Arrow::Schema#initialize} for details.
    #
    #   @param columns [::Array<Arrow::Column>] The data of the table.
    #
    #   @example Create a table from schema and columns
    #     count_field = Arrow::Field.new("count", :uint32)
    #     count_array = Arrow::UInt32Array.new([0, 2, nil, 4])
    #     count_column = Arrow::Column.new(count_field, count_array)
    #     visible_field = Arrow::Field.new("visible", :boolean)
    #     visible_array = Arrow::BooleanArray.new([true, nil, nil, false])
    #     visible_column = Arrow::Column.new(visible_field, visible_array)
    #     Arrow::Table.new(Arrow::Schema.new([count_field, visible_field]),
    #                      [count_column, visible_column])
    #
    # @overload initialize(schema, arrays)
    #
    #   @param schema [Arrow::Schema] The schema of the table.
    #     You can also specify schema as primitive Ruby objects.
    #     See {Arrow::Schema#initialize} for details.
    #
    #   @param arrays [::Array<Arrow::Array>] The data of the table.
    #
    #   @example Create a table from schema and arrays
    #     count_field = Arrow::Field.new("count", :uint32)
    #     count_array = Arrow::UInt32Array.new([0, 2, nil, 4])
    #     visible_field = Arrow::Field.new("visible", :boolean)
    #     visible_array = Arrow::BooleanArray.new([true, nil, nil, false])
    #     Arrow::Table.new(Arrow::Schema.new([count_field, visible_field]),
    #                      [count_array, visible_array])
    #
    # @overload initialize(schema, record_batches)
    #
    #   @param schema [Arrow::Schema] The schema of the table.
    #     You can also specify schema as primitive Ruby objects.
    #     See {Arrow::Schema#initialize} for details.
    #
    #   @param arrays [::Array<Arrow::RecordBatch>] The data of the table.
    #
    #   @example Create a table from schema and record batches
    #     count_field = Arrow::Field.new("count", :uint32)
    #     visible_field = Arrow::Field.new("visible", :boolean)
    #     schema = Arrow::Schema.new([count_field, visible_field])
    #     record_batches = [
    #       Arrow::RecordBatch.new(schema, [[0, true], [2, nil], [nil, nil]]),
    #       Arrow::RecordBatch.new(schema, [[4, false]]),
    #     ]
    #     Arrow::Table.new(schema, record_batches)
    #
    # @overload initialize(schema, raw_records)
    #
    #   @param schema [Arrow::Schema] The schema of the table.
    #     You can also specify schema as primitive Ruby objects.
    #     See {Arrow::Schema#initialize} for details.
    #
    #   @param arrays [::Array<::Array>] The data of the table as primitive
    #     Ruby objects.
    #
    #   @example Create a table from schema and raw records
    #     schema = {
    #       count: :uint32,
    #       visible: :boolean,
    #     }
    #     raw_records = [
    #       [0, true],
    #       [2, nil],
    #       [nil, nil],
    #       [4, false],
    #     ]
    #     Arrow::Table.new(schema, raw_records)
    def initialize(*args)
      n_args = args.size
      case n_args
      when 1
        raw_table_converter = RawTableConverter.new(args[0])
        schema = raw_table_converter.schema
        values = raw_table_converter.values
      when 2
        schema = args[0]
        schema = Schema.new(schema) unless schema.is_a?(Schema)
        values = args[1]
        case values[0]
        when ::Array
          values = [RecordBatch.new(schema, values)]
        when Column
          values = values.collect(&:data)
        end
      else
        message = "wrong number of arguments (given #{n_args}, expected 1..2)"
        raise ArgumentError, message
      end
      initialize_raw(schema, values)
    end

    def each_record_batch
      return to_enum(__method__) unless block_given?

      reader = TableBatchReader.new(self)
      while record_batch = reader.read_next
        yield(record_batch)
      end
    end

    alias_method :size, :n_rows
    alias_method :length, :n_rows

    alias_method :slice_raw, :slice

    # @overload slice(offset, length)
    #
    #   @param offset [Integer] The offset of sub Arrow::Table.
    #   @param length [Integer] The length of sub Arrow::Table.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only from
    #     `offset` to `offset + length` range.
    #
    # @overload slice(index)
    #
    #   @param index [Integer] The index in this table.
    #   @return [Arrow::Record]
    #     The `Arrow::Record` corresponding to index of
    #     the table.
    #
    # @overload slice(booleans)
    #
    #   @param booleans [::Array<Boolean>]
    #     The values indicating the target rows.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only rows of indices
    #     the values of `booleans` is true.
    #
    # @overload slice(boolean_array)
    #
    #   @param boolean_array [::Array<Arrow::BooleanArray>]
    #     The values indicating the target rows.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only rows of indices
    #     the values of `boolean_array` is true.
    #
    # @overload slice(range)
    #
    #   @param range_included_end [Range] The range indicating the target rows.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only rows of the range of indices.
    #
    # @overload slice(conditions)
    #
    #   @param conditions [Hash] The conditions to select records.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only rows matched by condition
    #
    # @overload slice
    #
    #   @yield [slicer] Gives slicer that constructs condition to select records.
    #   @yieldparam slicer [Arrow::Slicer] The slicer that helps us to
    #     build condition.
    #   @yieldreturn [Arrow::Slicer::Condition, ::Array<Arrow::Slicer::Condition>]
    #     The condition to select records.
    #   @return [Arrow::Table]
    #     The sub `Arrow::Table` that covers only rows matched by condition
    #     specified by slicer.
    def slice(*args)
      slicers = []
      if block_given?
        unless args.empty?
          raise ArgumentError, "must not specify both arguments and block"
        end
        block_slicer = yield(Slicer.new(self))
        case block_slicer
        when ::Array
          slicers.concat(block_slicer)
        else
          slicers << block_slicer
        end
      else
        expected_n_args = nil
        case args.size
        when 1
          case args[0]
          when Integer
            index = args[0]
            index += n_rows if index < 0
            return nil if index < 0
            return nil if index >= n_rows
            return Record.new(self, index)
          when Hash
            condition_pairs = args[0]
            slicer = Slicer.new(self)
            conditions = []
            condition_pairs.each do |key, value|
              case value
              when Range
                # TODO: Optimize "begin <= key <= end" case by missing "between" kernel
                # https://issues.apache.org/jira/browse/ARROW-9843
                unless value.begin.nil?
                  conditions << (slicer[key] >= value.begin)
                end
                unless value.end.nil?
                  if value.exclude_end?
                    conditions << (slicer[key] < value.end)
                  else
                    conditions << (slicer[key] <= value.end)
                  end
                end
              else
                conditions << (slicer[key] == value)
              end
            end
            slicers << conditions.inject(:&)
          else
            slicers << args[0]
          end
        when 2
          offset, length = args
          slicers << (offset...(offset + length))
        else
          expected_n_args = "1..2"
        end
        if expected_n_args
          message = "wrong number of arguments " +
            "(given #{args.size}, expected #{expected_n_args})"
          raise ArgumentError, message
        end
      end

      filter_options = Arrow::FilterOptions.new
      filter_options.null_selection_behavior = :emit_null
      sliced_tables = []
      slicers.each do |slicer|
        slicer = slicer.evaluate if slicer.respond_to?(:evaluate)
        case slicer
        when Integer
          slicer += n_rows if slicer < 0
          sliced_tables << slice_by_range(slicer, n_rows - 1)
        when Range
          original_from = from = slicer.first
          to = slicer.last
          to -= 1 if slicer.exclude_end?
          from += n_rows if from < 0
          if from < 0 or from >= n_rows
            message =
              "offset is out of range (-#{n_rows + 1},#{n_rows}): " +
              "#{original_from}"
            raise ArgumentError, message
          end
          to += n_rows if to < 0
          sliced_tables << slice_by_range(from, to)
        when ::Array, BooleanArray, ChunkedArray
          sliced_tables << filter(slicer, filter_options)
        else
          message = "slicer must be Integer, Range, (from, to), " +
            "Arrow::ChunkedArray of Arrow::BooleanArray, " +
            "Arrow::BooleanArray or Arrow::Slicer::Condition: #{slicer.inspect}"
          raise ArgumentError, message
        end
      end
      if sliced_tables.size > 1
        sliced_tables[0].concatenate(sliced_tables[1..-1])
      else
        sliced_tables[0]
      end
    end

    # TODO
    #
    # @return [Arrow::Table]
    def merge(other)
      added_columns = {}
      removed_columns = {}

      case other
      when Hash
        other.each do |name, value|
          name = name.to_s
          if value
            added_columns[name] = ensure_raw_column(name, value)
          else
            removed_columns[name] = true
          end
        end
      when Table
        added_columns = {}
        other.columns.each do |column|
          name = column.name
          added_columns[name] = ensure_raw_column(name, column)
        end
      else
        message = "merge target must be Hash or Arrow::Table: " +
          "<#{other.inspect}>: #{inspect}"
        raise ArgumentError, message
      end

      new_columns = []
      columns.each do |column|
        column_name = column.name
        new_column = added_columns.delete(column_name)
        if new_column
          new_columns << new_column
          next
        end
        next if removed_columns.key?(column_name)
        new_columns << ensure_raw_column(column_name, column)
      end
      added_columns.each do |name, new_column|
        new_columns << new_column
      end
      new_fields = []
      new_arrays = []
      new_columns.each do |new_column|
        new_fields << new_column[:field]
        new_arrays << new_column[:data]
      end
      self.class.new(new_fields, new_arrays)
    end

    alias_method :remove_column_raw, :remove_column
    def remove_column(name_or_index)
      case name_or_index
      when String, Symbol
        name = name_or_index.to_s
        index = columns.index {|column| column.name == name}
        if index.nil?
          message = "unknown column: #{name_or_index.inspect}: #{inspect}"
          raise KeyError.new(message)
        end
      else
        index = name_or_index
        index += n_columns if index < 0
        if index < 0 or index >= n_columns
          message = "out of index (0..#{n_columns - 1}): " +
            "#{name_or_index.inspect}: #{inspect}"
          raise IndexError.new(message)
        end
      end
      remove_column_raw(index)
    end

    # Experimental
    def group(*keys)
      Group.new(self, keys)
    end

    # Experimental
    def window(size: nil)
      RollingWindow.new(self, size)
    end

    def save(output, options={})
      saver = TableSaver.new(self, output, options)
      saver.save
    end

    def pack
      packed_arrays = columns.collect do |column|
        column.data.pack
      end
      self.class.new(schema, packed_arrays)
    end

    alias_method :to_s_raw, :to_s
    def to_s(options={})
      format = options[:format]
      case format
      when :column
        return to_s_raw
      when :list
        formatter_class = TableListFormatter
      when :table, nil
        formatter_class = TableTableFormatter
      else
        message = ":format must be :column, :list, :table or nil"
        raise ArgumentError, "#{message}: <#{format.inspect}>"
      end
      formatter = formatter_class.new(self, options)
      formatter.format
    end

    alias_method :inspect_raw, :inspect
    def inspect
      "#{super}\n#{to_s}"
    end

    def respond_to_missing?(name, include_private)
      return true if find_column(name)
      super
    end

    def method_missing(name, *args, &block)
      if args.empty?
        column = find_column(name)
        return column if column
      end
      super
    end

    private
    def slice_by_range(from, to)
      slice_raw(from, to - from + 1)
    end

    def ensure_raw_column(name, data)
      case data
      when Array
        {
          field: Field.new(name, data.value_data_type),
          data: ChunkedArray.new([data]),
        }
      when ChunkedArray
        {
          field: Field.new(name, data.value_data_type),
          data: data,
        }
      when Column
        column = data
        data = column.data
        data = ChunkedArray.new([data]) unless data.is_a?(ChunkedArray)
        {
          field: column.field,
          data: data,
        }
      else
        message = "column must be Arrow::Array or Arrow::Column: " +
          "<#{name}>: <#{data.inspect}>: #{inspect}"
        raise ArgumentError, message
      end
    end
  end
end
