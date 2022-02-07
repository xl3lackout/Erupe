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

class TestFileOutputStream < Test::Unit::TestCase
  sub_test_case(".new") do
    def test_create
      tempfile = Tempfile.open("arrow-io-file-output-stream")
      tempfile.write("Hello")
      tempfile.close
      file = Arrow::FileOutputStream.new(tempfile.path, false)
      file.close
      assert_equal("", File.read(tempfile.path))
    end

    def test_append
      tempfile = Tempfile.open("arrow-io-file-output-stream")
      tempfile.write("Hello")
      tempfile.close
      file = Arrow::FileOutputStream.new(tempfile.path, true)
      file.close
      assert_equal("Hello", File.read(tempfile.path))
    end
  end
end
