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

class FixedSizeBinaryArrayTest < Test::Unit::TestCase
  sub_test_case(".new") do
    test("build") do
      data_type = Arrow::FixedSizeBinaryDataType.new(4)
      values = [
        "0123",
        nil,
        GLib::Bytes.new("abcd"),
      ]
      array = Arrow::FixedSizeBinaryArray.new(data_type, values)
      assert_equal([
                     "0123",
                     nil,
                     "abcd",
                   ],
                   array.to_a)
    end
  end
end
