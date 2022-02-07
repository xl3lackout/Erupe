// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#include <gtest/gtest.h>

#include "arrow/memory_pool.h"
#include "arrow/status.h"
#include "gandiva/node.h"
#include "gandiva/projector.h"
#include "gandiva/tests/test_util.h"
#include "gandiva/tree_expr_builder.h"

namespace gandiva {

using arrow::binary;
using arrow::boolean;
using arrow::int32;

class TestBinary : public ::testing::Test {
 public:
  void SetUp() { pool_ = arrow::default_memory_pool(); }

 protected:
  arrow::MemoryPool* pool_;
};

TEST_F(TestBinary, TestSimple) {
  // schema for input fields
  auto field_a = field("a", binary());
  auto field_b = field("b", binary());
  auto schema = arrow::schema({field_a, field_b});

  // output fields
  auto res = field("res", int32());

  // build expressions.
  // a > b ? octet_length(a) : octet_length(b)
  auto node_a = TreeExprBuilder::MakeField(field_a);
  auto node_b = TreeExprBuilder::MakeField(field_b);
  auto octet_len_a = TreeExprBuilder::MakeFunction("octet_length", {node_a}, int32());
  auto octet_len_b = TreeExprBuilder::MakeFunction("octet_length", {node_b}, int32());

  auto is_greater =
      TreeExprBuilder::MakeFunction("greater_than", {node_a, node_b}, boolean());
  auto if_greater =
      TreeExprBuilder::MakeIf(is_greater, octet_len_a, octet_len_b, int32());
  auto expr = TreeExprBuilder::MakeExpression(if_greater, res);

  // Build a projector for the expressions.
  std::shared_ptr<Projector> projector;
  auto status = Projector::Make(schema, {expr}, TestConfiguration(), &projector);
  EXPECT_TRUE(status.ok()) << status.message();

  // Create a row-batch with some sample data
  int num_records = 4;
  auto array_a =
      MakeArrowArrayBinary({"foo", "hello", "hi", "bye"}, {true, true, true, false});
  auto array_b =
      MakeArrowArrayBinary({"fo", "hellos", "hi", "bye"}, {true, true, true, true});

  // expected output
  auto exp = MakeArrowArrayInt32({3, 6, 2, 3}, {true, true, true, true});

  // prepare input record batch
  auto in_batch = arrow::RecordBatch::Make(schema, num_records, {array_a, array_b});

  // Evaluate expression
  arrow::ArrayVector outputs;
  status = projector->Evaluate(*in_batch, pool_, &outputs);
  EXPECT_TRUE(status.ok());

  // Validate results
  EXPECT_ARROW_ARRAY_EQUALS(exp, outputs.at(0));
}

TEST_F(TestBinary, TestIfElse) {
  // schema for input fields
  auto field0 = field("f0", arrow::binary());
  auto field1 = field("f1", arrow::binary());

  auto schema = arrow::schema({field0, field1});

  auto f0 = TreeExprBuilder::MakeField(field0);
  auto f1 = TreeExprBuilder::MakeField(field1);

  // output fields
  auto field_result = field("out", arrow::binary());

  // Build expression
  auto cond = TreeExprBuilder::MakeFunction("isnotnull", {f0}, arrow::boolean());
  auto ifexpr = TreeExprBuilder::MakeIf(cond, f0, f1, arrow::binary());
  auto expr = TreeExprBuilder::MakeExpression(ifexpr, field_result);

  // Build a projector for the expressions.
  std::shared_ptr<Projector> projector;
  auto status = Projector::Make(schema, {expr}, TestConfiguration(), &projector);
  EXPECT_TRUE(status.ok());

  // Create a row-batch with some sample data
  int num_records = 4;
  auto array_f0 =
      MakeArrowArrayBinary({"foo", "hello", "hi", "bye"}, {true, true, true, false});
  auto array_f1 =
      MakeArrowArrayBinary({"fe", "fi", "fo", "fum"}, {true, true, true, true});

  // expected output
  auto exp =
      MakeArrowArrayBinary({"foo", "hello", "hi", "fum"}, {true, true, true, true});

  // prepare input record batch
  auto in_batch = arrow::RecordBatch::Make(schema, num_records, {array_f0, array_f1});

  // Evaluate expression
  arrow::ArrayVector outputs;
  status = projector->Evaluate(*in_batch, pool_, &outputs);
  EXPECT_TRUE(status.ok());

  // Validate results
  EXPECT_ARROW_ARRAY_EQUALS(exp, outputs.at(0));
}

}  // namespace gandiva
