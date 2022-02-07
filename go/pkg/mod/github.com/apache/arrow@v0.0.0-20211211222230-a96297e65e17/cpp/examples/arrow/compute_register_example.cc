// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements. See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership. The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

#include <arrow/api.h>
#include <arrow/compute/api.h>
#include <arrow/compute/exec/exec_plan.h>
#include <arrow/compute/exec/expression.h>
#include <arrow/compute/exec/options.h>
#include <arrow/util/async_generator.h>
#include <arrow/util/future.h>

#include <cstdlib>
#include <iostream>
#include <memory>

// Demonstrate registering an Arrow compute function outside of the Arrow source tree

namespace cp = ::arrow::compute;

#define ABORT_ON_FAILURE(expr)                     \
  do {                                             \
    arrow::Status status_ = (expr);                \
    if (!status_.ok()) {                           \
      std::cerr << status_.message() << std::endl; \
      abort();                                     \
    }                                              \
  } while (0);

class ExampleFunctionOptionsType : public cp::FunctionOptionsType {
  const char* type_name() const override { return "ExampleFunctionOptionsType"; }
  std::string Stringify(const cp::FunctionOptions&) const override {
    return "ExampleFunctionOptionsType";
  }
  bool Compare(const cp::FunctionOptions&, const cp::FunctionOptions&) const override {
    return true;
  }
  std::unique_ptr<cp::FunctionOptions> Copy(const cp::FunctionOptions&) const override;
  // optional: support for serialization
  // Result<std::shared_ptr<Buffer>> Serialize(const FunctionOptions&) const override;
  // Result<std::unique_ptr<FunctionOptions>> Deserialize(const Buffer&) const override;
};

cp::FunctionOptionsType* GetExampleFunctionOptionsType() {
  static ExampleFunctionOptionsType options_type;
  return &options_type;
}

class ExampleFunctionOptions : public cp::FunctionOptions {
 public:
  ExampleFunctionOptions() : cp::FunctionOptions(GetExampleFunctionOptionsType()) {}
};

std::unique_ptr<cp::FunctionOptions> ExampleFunctionOptionsType::Copy(
    const cp::FunctionOptions&) const {
  return std::unique_ptr<cp::FunctionOptions>(new ExampleFunctionOptions());
}

arrow::Status ExampleFunctionImpl(cp::KernelContext* ctx, const cp::ExecBatch& batch,
                                  arrow::Datum* out) {
  *out->mutable_array() = *batch[0].array();
  return arrow::Status::OK();
}

class ExampleNodeOptions : public cp::ExecNodeOptions {};

// a basic ExecNode which ignores all input batches
class ExampleNode : public cp::ExecNode {
 public:
  ExampleNode(ExecNode* input, const ExampleNodeOptions&)
      : ExecNode(/*plan=*/input->plan(), /*inputs=*/{input},
                 /*input_labels=*/{"ignored"},
                 /*output_schema=*/input->output_schema(), /*num_outputs=*/1) {}

  const char* kind_name() const override { return "ExampleNode"; }

  arrow::Status StartProducing() override {
    outputs_[0]->InputFinished(this, 0);
    return arrow::Status::OK();
  }

  void ResumeProducing(ExecNode* output) override {}
  void PauseProducing(ExecNode* output) override {}

  void StopProducing(ExecNode* output) override { inputs_[0]->StopProducing(this); }
  void StopProducing() override { inputs_[0]->StopProducing(); }

  void InputReceived(ExecNode* input, cp::ExecBatch batch) override {}
  void ErrorReceived(ExecNode* input, arrow::Status error) override {}
  void InputFinished(ExecNode* input, int total_batches) override {}

  arrow::Future<> finished() override { return inputs_[0]->finished(); }
};

arrow::Result<cp::ExecNode*> ExampleExecNodeFactory(cp::ExecPlan* plan,
                                                    std::vector<cp::ExecNode*> inputs,
                                                    const cp::ExecNodeOptions& options) {
  const auto& example_options =
      arrow::internal::checked_cast<const ExampleNodeOptions&>(options);

  return plan->EmplaceNode<ExampleNode>(inputs[0], example_options);
}

const cp::FunctionDoc func_doc{
    "Example function to demonstrate registering an out-of-tree function",
    "",
    {"x"},
    "ExampleFunctionOptions"};

int main(int argc, char** argv) {
  const std::string name = "compute_register_example";
  auto func = std::make_shared<cp::ScalarFunction>(name, cp::Arity::Unary(), &func_doc);
  cp::ScalarKernel kernel({cp::InputType::Array(arrow::int64())}, arrow::int64(),
                          ExampleFunctionImpl);
  kernel.mem_allocation = cp::MemAllocation::NO_PREALLOCATE;
  ABORT_ON_FAILURE(func->AddKernel(std::move(kernel)));

  auto registry = cp::GetFunctionRegistry();
  ABORT_ON_FAILURE(registry->AddFunction(std::move(func)));

  arrow::Int64Builder builder(arrow::default_memory_pool());
  std::shared_ptr<arrow::Array> arr;
  ABORT_ON_FAILURE(builder.Append(42));
  ABORT_ON_FAILURE(builder.Finish(&arr));
  auto options = std::make_shared<ExampleFunctionOptions>();
  auto maybe_result = cp::CallFunction(name, {arr}, options.get());
  ABORT_ON_FAILURE(maybe_result.status());

  std::cout << maybe_result->make_array()->ToString() << std::endl;

  // Expression serialization will raise NotImplemented if an expression includes
  // FunctionOptions for which serialization is not supported.
  auto expr = cp::call(name, {}, options);
  auto maybe_serialized = cp::Serialize(expr);
  std::cerr << maybe_serialized.status().ToString() << std::endl;

  auto exec_registry = cp::default_exec_factory_registry();
  ABORT_ON_FAILURE(
      exec_registry->AddFactory("compute_register_example", ExampleExecNodeFactory));

  auto maybe_plan = cp::ExecPlan::Make();
  ABORT_ON_FAILURE(maybe_plan.status());
  auto plan = maybe_plan.ValueOrDie();

  arrow::AsyncGenerator<arrow::util::optional<cp::ExecBatch>> source_gen, sink_gen;
  ABORT_ON_FAILURE(
      cp::Declaration::Sequence(
          {
              {"source", cp::SourceNodeOptions{arrow::schema({}), source_gen}},
              {"compute_register_example", ExampleNodeOptions{}},
              {"sink", cp::SinkNodeOptions{&sink_gen}},
          })
          .AddToPlan(plan.get())
          .status());

  return EXIT_SUCCESS;
}
