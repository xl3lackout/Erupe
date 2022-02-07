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

class StructArrayTest < Test::Unit::TestCase
  sub_test_case(".new") do
    test("build") do
      data_type = Arrow::StructDataType.new(visible: :boolean,
                                            count: :uint64)
      values = [
        [true, 1],
        nil,
        [false, 2],
      ]
      array = Arrow::StructArray.new(data_type, values)
      assert_equal([
                     [true, false, false],
                     [1, 0, 2],
                   ],
                   [
                     array.find_field(0).to_a,
                     array.find_field(1).to_a,
                   ])
    end
  end

  sub_test_case("instance methods") do
    def setup
      @data_type = Arrow::StructDataType.new(visible: {type: :boolean},
                                             count: {type: :uint64})
      @values = [
        [true, 1],
        [false, 2],
      ]
      @array = Arrow::StructArray.new(@data_type, @values)
    end

    test("#[]") do
      assert_equal([
                     {"visible" => true,  "count" => 1},
                     {"visible" => false, "count" => 2},
                   ],
                   @array.to_a)
    end

    test("#get_value") do
      assert_equal([
                     {"visible" => true,  "count" => 1},
                     {"visible" => false, "count" => 2},
                   ],
                   [
                     @array.get_value(0),
                     @array.get_value(1),
                   ])
    end

    sub_test_case("#find_field") do
      test("Integer") do
        assert_equal([
                       [true, false],
                       [1, 2],
                     ],
                     [
                       @array.find_field(0).to_a,
                       @array.find_field(1).to_a,
                     ])
      end

      test("String, Symbol") do
        assert_equal([
                       [true, false],
                       [1, 2],
                     ],
                     [
                       @array.find_field("visible").to_a,
                       @array.find_field(:count).to_a,
                     ])
      end
    end
  end
end
