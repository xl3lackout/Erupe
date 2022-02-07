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

class Decimal256ArrayTest < Test::Unit::TestCase
  sub_test_case(".new") do
    test("build") do
      data_type = Arrow::Decimal256DataType.new(3, 1)
      values = [
        10.1,
        nil,
        "10.1",
        BigDecimal("10.1"),
      ]
      array = Arrow::Decimal256Array.new(data_type, values)
      assert_equal([
                     BigDecimal("10.1"),
                     nil,
                     BigDecimal("10.1"),
                     BigDecimal("10.1"),
                   ],
                   array.to_a)
    end
  end
end
