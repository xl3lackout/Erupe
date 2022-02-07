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

class TestJSONReader < Test::Unit::TestCase
  include Helper::Buildable
  include Helper::Omittable

  sub_test_case("#read") do
    def open_input(json)
      buffer = Arrow::Buffer.new(json)
      Arrow::BufferInputStream.new(buffer)
    end

    def test_default
      table = Arrow::JSONReader.new(open_input(<<-JSON))
{ "message": "Hello", "count": 3.5, "valid": false }
{ "message": "World", "count": 3.25, "valid": true }
      JSON
      columns = {
        "message" => build_string_array(["Hello", "World"]),
        "count" => build_double_array([3.5, 3.25]),
        "valid" => build_boolean_array([false, true]),
      }
      assert_equal(build_table(columns),
                   table.read)
    end

    sub_test_case("unexpected-field-behavior") do
      def setup
        @options = Arrow::JSONReadOptions.new
        field = Arrow::Field.new("message", Arrow::StringDataType.new)
        schema = Arrow::Schema.new([field])
        @options.schema = schema
      end

      def test_ignore
        @options.unexpected_field_behavior = :ignore
        table = Arrow::JSONReader.new(open_input(<<-JSON), @options)
{ "message": "Hello", "count": 3.5, "valid": false }
{ "message": "World", "count": 3.25, "valid": true }
        JSON
        columns = {
          "message" => build_string_array(["Hello", "World"]),
        }
        assert_equal(build_table(columns),
                     table.read)
      end

      def test_error
        @options.unexpected_field_behavior = :error
        table = Arrow::JSONReader.new(open_input(<<-JSON), @options)
{ "message": "Hello", "count": 3.5, "valid": false }
{ "message": "World", "count": 3.25, "valid": true }
        JSON
        assert_raise(Arrow::Error::Invalid) do
          table.read
        end
      end

      def test_infer_type
        @options.unexpected_field_behavior = :infer_type
        table = Arrow::JSONReader.new(open_input(<<-JSON), @options)
{ "message": "Hello", "count": 3.5, "valid": false }
{ "message": "World", "count": 3.25, "valid": true }
        JSON
        columns = {
          "message" => build_string_array(["Hello", "World"]),
          "count" => build_double_array([3.5, 3.25]),
          "valid" => build_boolean_array([false, true]),
        }
        assert_equal(build_table(columns),
                     table.read)
      end
    end
  end
end
