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

class DataTypeTest < Test::Unit::TestCase
  sub_test_case(".resolve") do
    test("DataType") do
      assert_equal(Arrow::BooleanDataType.new,
                   Arrow::DataType.resolve(Arrow::BooleanDataType.new))
    end

    test("String") do
      assert_equal(Arrow::BooleanDataType.new,
                   Arrow::DataType.resolve("boolean"))
    end

    test("Symbol") do
      assert_equal(Arrow::BooleanDataType.new,
                   Arrow::DataType.resolve(:boolean))
    end

    test("Array") do
      field = Arrow::Field.new(:visible, :boolean)
      assert_equal(Arrow::ListDataType.new(field),
                   Arrow::DataType.resolve([:list, field]))
    end

    test("Hash") do
      field = Arrow::Field.new(:visible, :boolean)
      assert_equal(Arrow::ListDataType.new(field),
                   Arrow::DataType.resolve(type: :list, field: field))
    end

    test("_") do
      assert_equal(Arrow::FixedSizeBinaryDataType.new(10),
                   Arrow::DataType.resolve([:fixed_size_binary, 10]))
    end

    test("abstract") do
      message =
        "abstract type: <:floating_point>: " +
        "use one of not abstract type: [" +
        "Arrow::DoubleDataType, " +
        "Arrow::FloatDataType]"
      assert_raise(ArgumentError.new(message)) do
        Arrow::DataType.resolve(:floating_point)
      end
    end
  end

  sub_test_case("instance methods") do
    def setup
      @data_type = Arrow::StringDataType.new
    end

    sub_test_case("#==") do
      test("Arrow::DataType") do
        assert do
          @data_type == @data_type
        end
      end

      test("not Arrow::DataType") do
        assert do
          not (@data_type == 29)
        end
      end
    end
  end
end
