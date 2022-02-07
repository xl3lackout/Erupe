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

class FeatherTest < Test::Unit::TestCase
  include Helper::Fixture

  def setup
    columns = {
      "message" => Arrow::StringArray.new(["Start", "Crash", "Shutdown"]),
      "is_critical" => Arrow::BooleanArray.new([false, true, false]),
    }
    @table = Arrow::Table.new(columns)

    @output = Tempfile.new(["red-arrow", ".feather"])
    begin
      yield(@output)
    ensure
      @output.close!
    end
  end

  def test_default
    @table.save(@output.path)
    @output.close

    assert_equal(@table, Arrow::Table.load(@output.path))
  end

  def test_compression
    @table.save(@output.path, compression: :zstd)
    @output.close

    assert_equal(@table, Arrow::Table.load(@output.path))
  end
end
