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

class TestGIOInputStream < Test::Unit::TestCase
  include Helper::Buildable

  def test_reader_backend
    data = [true]
    field = Arrow::Field.new("enabled", Arrow::BooleanDataType.new)
    schema = Arrow::Schema.new([field])

    tempfile = Tempfile.open("arrow-gio-input-stream")
    output = Arrow::FileOutputStream.new(tempfile.path, false)
    begin
      file_writer = Arrow::RecordBatchFileWriter.new(output, schema)
      begin
        record_batch = Arrow::RecordBatch.new(schema,
                                              data.size,
                                              [build_boolean_array(data)])
        file_writer.write_record_batch(record_batch)
      ensure
        file_writer.close
      end
    ensure
      output.close
    end

    file = Gio::File.new_for_path(tempfile.path)
    input_stream = file.read
    input = Arrow::GIOInputStream.new(input_stream)
    begin
      file_reader = Arrow::RecordBatchFileReader.new(input)
      assert_equal([field.name],
                   file_reader.schema.fields.collect(&:name))
      assert_equal(Arrow::RecordBatch.new(schema,
                                          data.size,
                                          [build_boolean_array(data)]),
                   file_reader.read_record_batch(0))
    ensure
      input.close
    end
  end

  def test_getter
    input_stream = Gio::MemoryInputStream.new("Hello")
    input = Arrow::GIOInputStream.new(input_stream)
    assert_equal(input_stream, input.raw)
  end

  def test_peek
    input_stream = Gio::MemoryInputStream.new("Hello World")
    buffered_input_stream = Gio::BufferedInputStream.new(input_stream)
    input = Arrow::GIOInputStream.new(buffered_input_stream)
    assert_equal("He", input.peek(2).to_s)
    assert_equal("Hel", input.read_bytes(3).to_s)
    assert_equal("lo ", input.peek(3).to_s)
  end
end
