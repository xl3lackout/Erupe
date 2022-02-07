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

class TestGandivaCondition < Test::Unit::TestCase
  def setup
    omit("Gandiva is required") unless defined?(::Gandiva)
    field1 = Arrow::Field.new("field1", Arrow::Int32DataType.new)
    field2 = Arrow::Field.new("field2", Arrow::Int32DataType.new)
    field1_node = Gandiva::FieldNode.new(field1)
    field2_node = Gandiva::FieldNode.new(field2)
    function_node = Gandiva::FunctionNode.new("equal",
                                              [field1_node, field2_node],
                                              Arrow::BooleanDataType.new)
    @condition = Gandiva::Condition.new(function_node)
  end

  def test_to_s
    assert_equal("bool equal((int32) field1, (int32) field2)",
                 @condition.to_s)
  end
end
