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

class TestGandivaSelectableProjector < Test::Unit::TestCase
  include Helper::Buildable

  def setup
    omit("Gandiva is required") unless defined?(::Gandiva)

    field1 = Arrow::Field.new("field1", Arrow::Int32DataType.new)
    field2 = Arrow::Field.new("field2", Arrow::Int32DataType.new)
    @schema = Arrow::Schema.new([field1, field2])

    input_arrays = [
      build_int32_array([1, 2, 3, 4]),
      build_int32_array([11, 13, 15, 17]),
    ]
    @record_batch = Arrow::RecordBatch.new(@schema,
                                           input_arrays[0].length,
                                           input_arrays)

    @field_node1 = Gandiva::FieldNode.new(field1)
    @field_node2 = Gandiva::FieldNode.new(field2)
    add_function_node =
      Gandiva::FunctionNode.new("add",
                                [@field_node1, @field_node2],
                                Arrow::Int32DataType.new)
    subtract_function_node =
      Gandiva::FunctionNode.new("subtract",
                                [@field_node1, @field_node2],
                                Arrow::Int32DataType.new)
    add_result = Arrow::Field.new("add_result", Arrow::Int32DataType.new)
    add_expression = Gandiva::Expression.new(add_function_node, add_result)
    subtract_result = Arrow::Field.new("subtract_result",
                                       Arrow::Int32DataType.new)
    subtract_expression = Gandiva::Expression.new(subtract_function_node,
                                                  subtract_result)
    @selection_vector = Gandiva::UInt16SelectionVector.new(@record_batch.n_rows)
    @projector =
      Gandiva::SelectableProjector.new(@schema,
                                       [add_expression, subtract_expression],
                                       @selection_vector.mode)
  end

  def test_evaluate
    two_node = Gandiva::Int32LiteralNode.new(2)
    condition_node = Gandiva::FunctionNode.new("greater_than",
                                               [@field_node1, two_node],
                                               Arrow::BooleanDataType.new)
    condition = Gandiva::Condition.new(condition_node)
    filter = Gandiva::Filter.new(@schema, condition)
    filter.evaluate(@record_batch, @selection_vector)
    outputs = @projector.evaluate(@record_batch, @selection_vector)
    assert_equal([
                   [18, 21],
                   [-12, -13],
                 ],
                 outputs.collect(&:values))
  end
end
