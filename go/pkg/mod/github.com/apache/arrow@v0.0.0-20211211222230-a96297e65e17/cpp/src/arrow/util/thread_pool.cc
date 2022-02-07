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

#include "arrow/util/thread_pool.h"

#include <algorithm>
#include <condition_variable>
#include <deque>
#include <list>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "arrow/util/io_util.h"
#include "arrow/util/logging.h"

namespace arrow {
namespace internal {

Executor::~Executor() = default;

namespace {

struct Task {
  FnOnce<void()> callable;
  StopToken stop_token;
  Executor::StopCallback stop_callback;
};

}  // namespace

struct SerialExecutor::State {
  std::deque<Task> task_queue;
  std::mutex mutex;
  std::condition_variable wait_for_tasks;
  bool finished{false};
};

SerialExecutor::SerialExecutor() : state_(std::make_shared<State>()) {}

SerialExecutor::~SerialExecutor() = default;

Status SerialExecutor::SpawnReal(TaskHints hints, FnOnce<void()> task,
                                 StopToken stop_token, StopCallback&& stop_callback) {
  // While the SerialExecutor runs tasks synchronously on its main thread,
  // SpawnReal may be called from external threads (e.g. when transferring back
  // from blocking I/O threads), so we need to keep the state alive *and* to
  // lock its contents.
  //
  // Note that holding the lock while notifying the condition variable may
  // not be sufficient, as some exit paths in the main thread are unlocked.
  auto state = state_;
  {
    std::lock_guard<std::mutex> lk(state->mutex);
    state->task_queue.push_back(
        Task{std::move(task), std::move(stop_token), std::move(stop_callback)});
  }
  state->wait_for_tasks.notify_one();
  return Status::OK();
}

void SerialExecutor::MarkFinished() {
  // Same comment as SpawnReal above
  auto state = state_;
  {
    std::lock_guard<std::mutex> lk(state->mutex);
    state->finished = true;
  }
  state->wait_for_tasks.notify_one();
}

void SerialExecutor::RunLoop() {
  // This is called from the SerialExecutor's main thread, so the
  // state is guaranteed to be kept alive.
  std::unique_lock<std::mutex> lk(state_->mutex);

  while (!state_->finished) {
    while (!state_->task_queue.empty()) {
      Task task = std::move(state_->task_queue.front());
      state_->task_queue.pop_front();
      lk.unlock();
      if (!task.stop_token.IsStopRequested()) {
        std::move(task.callable)();
      } else {
        if (task.stop_callback) {
          std::move(task.stop_callback)(task.stop_token.Poll());
        }
        // Can't break here because there may be cleanup tasks down the chain we still
        // need to run.
      }
      lk.lock();
    }
    // In this case we must be waiting on work from external (e.g. I/O) executors.  Wait
    // for tasks to arrive (typically via transferred futures).
    state_->wait_for_tasks.wait(
        lk, [&] { return state_->finished || !state_->task_queue.empty(); });
  }
}

struct ThreadPool::State {
  State() = default;

  // NOTE: in case locking becomes too expensive, we can investigate lock-free FIFOs
  // such as https://github.com/cameron314/concurrentqueue

  std::mutex mutex_;
  std::condition_variable cv_;
  std::condition_variable cv_shutdown_;
  std::condition_variable cv_idle_;

  std::list<std::thread> workers_;
  // Trashcan for finished threads
  std::vector<std::thread> finished_workers_;
  std::deque<Task> pending_tasks_;

  // Desired number of threads
  int desired_capacity_ = 0;

  // Total number of tasks that are either queued or running
  int tasks_queued_or_running_ = 0;

  // Are we shutting down?
  bool please_shutdown_ = false;
  bool quick_shutdown_ = false;
};

// The worker loop is an independent function so that it can keep running
// after the ThreadPool is destroyed.
static void WorkerLoop(std::shared_ptr<ThreadPool::State> state,
                       std::list<std::thread>::iterator it) {
  std::unique_lock<std::mutex> lock(state->mutex_);

  // Since we hold the lock, `it` now points to the correct thread object
  // (LaunchWorkersUnlocked has exited)
  DCHECK_EQ(std::this_thread::get_id(), it->get_id());

  // If too many threads, we should secede from the pool
  const auto should_secede = [&]() -> bool {
    return state->workers_.size() > static_cast<size_t>(state->desired_capacity_);
  };

  while (true) {
    // By the time this thread is started, some tasks may have been pushed
    // or shutdown could even have been requested.  So we only wait on the
    // condition variable at the end of the loop.

    // Execute pending tasks if any
    while (!state->pending_tasks_.empty() && !state->quick_shutdown_) {
      // We check this opportunistically at each loop iteration since
      // it releases the lock below.
      if (should_secede()) {
        break;
      }

      DCHECK_GE(state->tasks_queued_or_running_, 0);
      {
        Task task = std::move(state->pending_tasks_.front());
        state->pending_tasks_.pop_front();
        StopToken* stop_token = &task.stop_token;
        lock.unlock();
        if (!stop_token->IsStopRequested()) {
          std::move(task.callable)();
        } else {
          if (task.stop_callback) {
            std::move(task.stop_callback)(stop_token->Poll());
          }
        }
        ARROW_UNUSED(std::move(task));  // release resources before waiting for lock
        lock.lock();
      }
      if (ARROW_PREDICT_FALSE(--state->tasks_queued_or_running_ == 0)) {
        state->cv_idle_.notify_all();
      }
    }
    // Now either the queue is empty *or* a quick shutdown was requested
    if (state->please_shutdown_ || should_secede()) {
      break;
    }
    // Wait for next wakeup
    state->cv_.wait(lock);
  }
  DCHECK_GE(state->tasks_queued_or_running_, 0);

  // We're done.  Move our thread object to the trashcan of finished
  // workers.  This has two motivations:
  // 1) the thread object doesn't get destroyed before this function finishes
  //    (but we could call thread::detach() instead)
  // 2) we can explicitly join() the trashcan threads to make sure all OS threads
  //    are exited before the ThreadPool is destroyed.  Otherwise subtle
  //    timing conditions can lead to false positives with Valgrind.
  DCHECK_EQ(std::this_thread::get_id(), it->get_id());
  state->finished_workers_.push_back(std::move(*it));
  state->workers_.erase(it);
  if (state->please_shutdown_) {
    // Notify the function waiting in Shutdown().
    state->cv_shutdown_.notify_one();
  }
}

void ThreadPool::WaitForIdle() {
  std::unique_lock<std::mutex> lk(state_->mutex_);
  state_->cv_idle_.wait(lk, [this] { return state_->tasks_queued_or_running_ == 0; });
}

ThreadPool::ThreadPool()
    : sp_state_(std::make_shared<ThreadPool::State>()),
      state_(sp_state_.get()),
      shutdown_on_destroy_(true) {
#ifndef _WIN32
  pid_ = getpid();
#endif
}

ThreadPool::~ThreadPool() {
  if (shutdown_on_destroy_) {
    ARROW_UNUSED(Shutdown(false /* wait */));
  }
}

void ThreadPool::ProtectAgainstFork() {
#ifndef _WIN32
  pid_t current_pid = getpid();
  if (pid_ != current_pid) {
    // Reinitialize internal state in child process after fork()
    // Ideally we would use pthread_at_fork(), but that doesn't allow
    // storing an argument, hence we'd need to maintain a list of all
    // existing ThreadPools.
    int capacity = state_->desired_capacity_;

    auto new_state = std::make_shared<ThreadPool::State>();
    new_state->please_shutdown_ = state_->please_shutdown_;
    new_state->quick_shutdown_ = state_->quick_shutdown_;

    pid_ = current_pid;
    sp_state_ = new_state;
    state_ = sp_state_.get();

    // Launch worker threads anew
    if (!state_->please_shutdown_) {
      ARROW_UNUSED(SetCapacity(capacity));
    }
  }
#endif
}

Status ThreadPool::SetCapacity(int threads) {
  ProtectAgainstFork();
  std::unique_lock<std::mutex> lock(state_->mutex_);
  if (state_->please_shutdown_) {
    return Status::Invalid("operation forbidden during or after shutdown");
  }
  if (threads <= 0) {
    return Status::Invalid("ThreadPool capacity must be > 0");
  }
  CollectFinishedWorkersUnlocked();

  state_->desired_capacity_ = threads;
  // See if we need to increase or decrease the number of running threads
  const int required = std::min(static_cast<int>(state_->pending_tasks_.size()),
                                threads - static_cast<int>(state_->workers_.size()));
  if (required > 0) {
    // Some tasks are pending, spawn the number of needed threads immediately
    LaunchWorkersUnlocked(required);
  } else if (required < 0) {
    // Excess threads are running, wake them so that they stop
    state_->cv_.notify_all();
  }
  return Status::OK();
}

int ThreadPool::GetCapacity() {
  ProtectAgainstFork();
  std::unique_lock<std::mutex> lock(state_->mutex_);
  return state_->desired_capacity_;
}

int ThreadPool::GetNumTasks() {
  ProtectAgainstFork();
  std::unique_lock<std::mutex> lock(state_->mutex_);
  return state_->tasks_queued_or_running_;
}

int ThreadPool::GetActualCapacity() {
  ProtectAgainstFork();
  std::unique_lock<std::mutex> lock(state_->mutex_);
  return static_cast<int>(state_->workers_.size());
}

Status ThreadPool::Shutdown(bool wait) {
  ProtectAgainstFork();
  std::unique_lock<std::mutex> lock(state_->mutex_);

  if (state_->please_shutdown_) {
    return Status::Invalid("Shutdown() already called");
  }
  state_->please_shutdown_ = true;
  state_->quick_shutdown_ = !wait;
  state_->cv_.notify_all();
  state_->cv_shutdown_.wait(lock, [this] { return state_->workers_.empty(); });
  if (!state_->quick_shutdown_) {
    DCHECK_EQ(state_->pending_tasks_.size(), 0);
  } else {
    state_->pending_tasks_.clear();
  }
  CollectFinishedWorkersUnlocked();
  return Status::OK();
}

void ThreadPool::CollectFinishedWorkersUnlocked() {
  for (auto& thread : state_->finished_workers_) {
    // Make sure OS thread has exited
    thread.join();
  }
  state_->finished_workers_.clear();
}

thread_local ThreadPool* current_thread_pool_ = nullptr;

bool ThreadPool::OwnsThisThread() { return current_thread_pool_ == this; }

void ThreadPool::LaunchWorkersUnlocked(int threads) {
  std::shared_ptr<State> state = sp_state_;

  for (int i = 0; i < threads; i++) {
    state_->workers_.emplace_back();
    auto it = --(state_->workers_.end());
    *it = std::thread([this, state, it] {
      current_thread_pool_ = this;
      WorkerLoop(state, it);
    });
  }
}

Status ThreadPool::SpawnReal(TaskHints hints, FnOnce<void()> task, StopToken stop_token,
                             StopCallback&& stop_callback) {
  {
    ProtectAgainstFork();
    std::lock_guard<std::mutex> lock(state_->mutex_);
    if (state_->please_shutdown_) {
      return Status::Invalid("operation forbidden during or after shutdown");
    }
    CollectFinishedWorkersUnlocked();
    state_->tasks_queued_or_running_++;
    if (static_cast<int>(state_->workers_.size()) < state_->tasks_queued_or_running_ &&
        state_->desired_capacity_ > static_cast<int>(state_->workers_.size())) {
      // We can still spin up more workers so spin up a new worker
      LaunchWorkersUnlocked(/*threads=*/1);
    }
    state_->pending_tasks_.push_back(
        {std::move(task), std::move(stop_token), std::move(stop_callback)});
  }
  state_->cv_.notify_one();
  return Status::OK();
}

Result<std::shared_ptr<ThreadPool>> ThreadPool::Make(int threads) {
  auto pool = std::shared_ptr<ThreadPool>(new ThreadPool());
  RETURN_NOT_OK(pool->SetCapacity(threads));
  return pool;
}

Result<std::shared_ptr<ThreadPool>> ThreadPool::MakeEternal(int threads) {
  ARROW_ASSIGN_OR_RAISE(auto pool, Make(threads));
  // On Windows, the ThreadPool destructor may be called after non-main threads
  // have been killed by the OS, and hang in a condition variable.
  // On Unix, we want to avoid leak reports by Valgrind.
#ifdef _WIN32
  pool->shutdown_on_destroy_ = false;
#endif
  return pool;
}

// ----------------------------------------------------------------------
// Global thread pool

static int ParseOMPEnvVar(const char* name) {
  // OMP_NUM_THREADS is a comma-separated list of positive integers.
  // We are only interested in the first (top-level) number.
  auto result = GetEnvVar(name);
  if (!result.ok()) {
    return 0;
  }
  auto str = *std::move(result);
  auto first_comma = str.find_first_of(',');
  if (first_comma != std::string::npos) {
    str = str.substr(0, first_comma);
  }
  try {
    return std::max(0, std::stoi(str));
  } catch (...) {
    return 0;
  }
}

int ThreadPool::DefaultCapacity() {
  int capacity, limit;
  capacity = ParseOMPEnvVar("OMP_NUM_THREADS");
  if (capacity == 0) {
    capacity = std::thread::hardware_concurrency();
  }
  limit = ParseOMPEnvVar("OMP_THREAD_LIMIT");
  if (limit > 0) {
    capacity = std::min(limit, capacity);
  }
  if (capacity == 0) {
    ARROW_LOG(WARNING) << "Failed to determine the number of available threads, "
                          "using a hardcoded arbitrary value";
    capacity = 4;
  }
  return capacity;
}

// Helper for the singleton pattern
std::shared_ptr<ThreadPool> ThreadPool::MakeCpuThreadPool() {
  auto maybe_pool = ThreadPool::MakeEternal(ThreadPool::DefaultCapacity());
  if (!maybe_pool.ok()) {
    maybe_pool.status().Abort("Failed to create global CPU thread pool");
  }
  return *std::move(maybe_pool);
}

ThreadPool* GetCpuThreadPool() {
  static std::shared_ptr<ThreadPool> singleton = ThreadPool::MakeCpuThreadPool();
  return singleton.get();
}

}  // namespace internal

int GetCpuThreadPoolCapacity() { return internal::GetCpuThreadPool()->GetCapacity(); }

Status SetCpuThreadPoolCapacity(int threads) {
  return internal::GetCpuThreadPool()->SetCapacity(threads);
}

}  // namespace arrow
