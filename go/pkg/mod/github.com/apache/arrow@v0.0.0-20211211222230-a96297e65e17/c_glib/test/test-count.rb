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

class TestCount < Test::Unit::TestCase
  include Helper::Buildable
  include Helper::Omittable

  sub_test_case("mode") do
    def test_default
      assert_equal(2, build_int32_array([1, nil, 3]).count)

      options = Arrow::CountOptions.new
      options.mode = Arrow::CountMode::ONLY_VALID
      assert_equal(2, build_int32_array([1, nil, 3]).count(options))
    end

    def test_nulls
      options = Arrow::CountOptions.new
      options.mode = Arrow::CountMode::ONLY_NULL
      assert_equal(1, build_int32_array([1, nil, 3]).count(options))
    end

    def test_all
      options = Arrow::CountOptions.new
      options.mode = Arrow::CountMode::ALL
      assert_equal(3, build_int32_array([1, nil, 3]).count(options))
    end
  end
end
