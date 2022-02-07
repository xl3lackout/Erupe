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

class TestCodec < Test::Unit::TestCase
  def test_name
    codec = Arrow::Codec.new(:gzip)
    assert_equal("gzip", codec.name)
  end

  def test_compression_type
    codec = Arrow::Codec.new(:gzip)
    assert_equal(Arrow::CompressionType::GZIP, codec.compression_type)
  end

  def test_compression_level
    codec = Arrow::Codec.new(:gzip)
    assert_equal(9, codec.compression_level)
  end
end
