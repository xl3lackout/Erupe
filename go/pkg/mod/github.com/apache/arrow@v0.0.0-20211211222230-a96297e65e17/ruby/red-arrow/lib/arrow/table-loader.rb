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

require "uri"

module Arrow
  class TableLoader
    class << self
      def load(input, options={})
        new(input, options).load
      end
    end

    def initialize(input, options={})
      input = input.to_path if input.respond_to?(:to_path)
      @input = input
      @options = options
      fill_options
    end

    def load
      if @input.is_a?(URI)
        custom_load_method = "load_from_uri"
      elsif @input.is_a?(String) and ::File.directory?(@input)
        custom_load_method = "load_from_directory"
      else
        custom_load_method = "load_from_file"
      end
      unless respond_to?(custom_load_method, true)
        available_schemes = []
        (methods(true) | private_methods(true)).each do |name|
          match_data = /\Aload_from_/.match(name.to_s)
          if match_data
            available_schemes << match_data.post_match
          end
        end
        message = "Arrow::Table load source must be one of ["
        message << available_schemes.join(", ")
        message << "]: #{@input.inspect}"
        raise ArgumentError, message
      end
      __send__(custom_load_method)
    end

    private
    def load_from_file
      format = @options[:format]
      custom_load_method = "load_as_#{format}"
      unless respond_to?(custom_load_method, true)
        available_formats = []
        (methods(true) | private_methods(true)).each do |name|
          match_data = /\Aload_as_/.match(name.to_s)
          if match_data
            available_formats << match_data.post_match
          end
        end
        deprecated_formats = ["batch", "stream"]
        available_formats -= deprecated_formats
        message = "Arrow::Table load format must be one of ["
        message << available_formats.join(", ")
        message << "]: #{format.inspect}"
        raise ArgumentError, message
      end
      if method(custom_load_method).arity.zero?
        __send__(custom_load_method)
      else
        # For backward compatibility.
        __send__(custom_load_method, @input)
      end
    end

    def fill_options
      if @options[:format] and @options.key?(:compression)
        return
      end

      case @input
      when Buffer
        info = {}
      when URI
        extension = PathExtension.new(@input.path)
        info = extension.extract
      else
        extension = PathExtension.new(@input)
        info = extension.extract
      end
      format = info[:format]
      @options = @options.dup
      if format
        @options[:format] ||= format.to_sym
      else
        @options[:format] ||= :arrow
      end
      unless @options.key?(:compression)
        @options[:compression] = info[:compression]
      end
    end

    def open_input_stream
      if @input.is_a?(Buffer)
        BufferInputStream.new(@input)
      else
        MemoryMappedInputStream.new(@input)
      end
    end

    def load_raw(input, reader)
      schema = reader.schema
      record_batches = []
      reader.each do |record_batch|
        record_batches << record_batch
      end
      table = Table.new(schema, record_batches)
      table.instance_variable_set(:@input, input)
      table
    end

    def load_as_arrow
      input = nil
      reader = nil
      error = nil
      reader_class_candidates = [
        RecordBatchFileReader,
        RecordBatchStreamReader,
      ]
      reader_class_candidates.each do |reader_class_candidate|
        input = open_input_stream
        begin
          reader = reader_class_candidate.new(input)
        rescue Arrow::Error
          error = $!
        else
          break
        end
      end
      raise error if reader.nil?
      load_raw(input, reader)
    end

    # @since 1.0.0
    def load_as_arrow_file
      input = open_input_stream
      reader = RecordBatchFileReader.new(input)
      load_raw(input, reader)
    end

    # @deprecated Use `format: :arrow_file` instead.
    def load_as_batch
      load_as_arrow_file
    end

    # @since 1.0.0
    def load_as_arrow_streaming
      input = open_input_stream
      reader = RecordBatchStreamReader.new(input)
      load_raw(input, reader)
    end

    # @deprecated Use `format: :arrow_streaming` instead.
    def load_as_stream
      load_as_arrow_streaming
    end

    if Arrow.const_defined?(:ORCFileReader)
      def load_as_orc
        input = open_input_stream
        reader = ORCFileReader.new(input)
        field_indexes = @options[:field_indexes]
        reader.set_field_indexes(field_indexes) if field_indexes
        table = reader.read_stripes
        table.instance_variable_set(:@input, input)
        table
      end
    end

    def csv_load(options)
      options.delete(:format)
      if @input.is_a?(Buffer)
        CSVLoader.load(@input.data.to_s, **options)
      else
        CSVLoader.load(Pathname.new(@input), **options)
      end
    end

    def load_as_csv
      csv_load(@options.dup)
    end

    def load_as_tsv
      options = @options.dup
      options[:delimiter] = "\t"
      csv_load(options.dup)
    end

    def load_as_feather
      input = open_input_stream
      reader = FeatherFileReader.new(input)
      table = reader.read
      table.instance_variable_set(:@input, input)
      table
    end

    def load_as_json
      input = open_input_stream
      reader = JSONReader.new(input)
      table = reader.read
      table.instance_variable_set(:@input, input)
      table
    end
  end
end
