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

#include <mutex>

#include "arrow/compute/exec.h"
#include "arrow/compute/exec/exec_plan.h"
#include "arrow/compute/exec/expression.h"
#include "arrow/compute/exec/options.h"
#include "arrow/compute/exec/util.h"
#include "arrow/compute/exec_internal.h"
#include "arrow/datum.h"
#include "arrow/result.h"
#include "arrow/util/async_generator.h"
#include "arrow/util/async_util.h"
#include "arrow/util/checked_cast.h"
#include "arrow/util/future.h"
#include "arrow/util/logging.h"
#include "arrow/util/optional.h"
#include "arrow/util/thread_pool.h"
#include "arrow/util/unreachable.h"

namespace arrow {

using internal::checked_cast;

namespace compute {
namespace {

struct SourceNode : ExecNode {
  SourceNode(ExecPlan* plan, std::shared_ptr<Schema> output_schema,
             AsyncGenerator<util::optional<ExecBatch>> generator)
      : ExecNode(plan, {}, {}, std::move(output_schema),
                 /*num_outputs=*/1),
        generator_(std::move(generator)) {}

  static Result<ExecNode*> Make(ExecPlan* plan, std::vector<ExecNode*> inputs,
                                const ExecNodeOptions& options) {
    RETURN_NOT_OK(ValidateExecNodeInputs(plan, inputs, 0, "SourceNode"));
    const auto& source_options = checked_cast<const SourceNodeOptions&>(options);
    return plan->EmplaceNode<SourceNode>(plan, source_options.output_schema,
                                         source_options.generator);
  }

  const char* kind_name() const override { return "SourceNode"; }

  [[noreturn]] static void NoInputs() {
    Unreachable("no inputs; this should never be called");
  }
  [[noreturn]] void InputReceived(ExecNode*, ExecBatch) override { NoInputs(); }
  [[noreturn]] void ErrorReceived(ExecNode*, Status) override { NoInputs(); }
  [[noreturn]] void InputFinished(ExecNode*, int) override { NoInputs(); }

  Status StartProducing() override {
    {
      // If another exec node encountered an error during its StartProducing call
      // it might have already called StopProducing on all of its inputs (including this
      // node).
      //
      std::unique_lock<std::mutex> lock(mutex_);
      if (stop_requested_) {
        return Status::OK();
      }
    }

    CallbackOptions options;
    auto executor = plan()->exec_context()->executor();
    if (executor) {
      // These options will transfer execution to the desired Executor if necessary.
      // This can happen for in-memory scans where batches didn't require
      // any CPU work to decode. Otherwise, parsing etc should have already
      // been placed us on the desired Executor and no queues will be pushed to.
      options.executor = executor;
      options.should_schedule = ShouldSchedule::IfDifferentExecutor;
    }
    finished_ =
        Loop([this, executor, options] {
          std::unique_lock<std::mutex> lock(mutex_);
          int total_batches = batch_count_++;
          if (stop_requested_) {
            return Future<ControlFlow<int>>::MakeFinished(Break(total_batches));
          }
          lock.unlock();

          return generator_().Then(
              [=](const util::optional<ExecBatch>& maybe_batch) -> ControlFlow<int> {
                std::unique_lock<std::mutex> lock(mutex_);
                if (IsIterationEnd(maybe_batch) || stop_requested_) {
                  stop_requested_ = true;
                  return Break(total_batches);
                }
                lock.unlock();
                ExecBatch batch = std::move(*maybe_batch);

                if (executor) {
                  auto status =
                      task_group_.AddTask([this, executor, batch]() -> Result<Future<>> {
                        return executor->Submit([=]() {
                          outputs_[0]->InputReceived(this, std::move(batch));
                          return Status::OK();
                        });
                      });
                  if (!status.ok()) {
                    outputs_[0]->ErrorReceived(this, std::move(status));
                    return Break(total_batches);
                  }
                } else {
                  outputs_[0]->InputReceived(this, std::move(batch));
                }
                return Continue();
              },
              [=](const Status& error) -> ControlFlow<int> {
                // NB: ErrorReceived is independent of InputFinished, but
                // ErrorReceived will usually prompt StopProducing which will
                // prompt InputFinished. ErrorReceived may still be called from a
                // node which was requested to stop (indeed, the request to stop
                // may prompt an error).
                std::unique_lock<std::mutex> lock(mutex_);
                stop_requested_ = true;
                lock.unlock();
                outputs_[0]->ErrorReceived(this, error);
                return Break(total_batches);
              },
              options);
        }).Then([&](int total_batches) {
          outputs_[0]->InputFinished(this, total_batches);
          return task_group_.End();
        });

    return Status::OK();
  }

  void PauseProducing(ExecNode* output) override {}

  void ResumeProducing(ExecNode* output) override {}

  void StopProducing(ExecNode* output) override {
    DCHECK_EQ(output, outputs_[0]);
    StopProducing();
  }

  void StopProducing() override {
    std::unique_lock<std::mutex> lock(mutex_);
    stop_requested_ = true;
  }

  Future<> finished() override { return finished_; }

 private:
  std::mutex mutex_;
  bool stop_requested_{false};
  int batch_count_{0};
  Future<> finished_ = Future<>::MakeFinished();
  util::AsyncTaskGroup task_group_;
  AsyncGenerator<util::optional<ExecBatch>> generator_;
};

}  // namespace

namespace internal {

void RegisterSourceNode(ExecFactoryRegistry* registry) {
  DCHECK_OK(registry->AddFactory("source", SourceNode::Make));
}

}  // namespace internal
}  // namespace compute
}  // namespace arrow
