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

#pragma once

#include <vector>

#include "arrow/util/macros.h"

#include "arrow/util/logging.h"
#include "gandiva/llvm_includes.h"

namespace gandiva {

/// \brief Tracks validity/value builders in LLVM.
class GANDIVA_EXPORT LValue {
 public:
  explicit LValue(llvm::Value* data, llvm::Value* length = NULLPTR,
                  llvm::Value* validity = NULLPTR)
      : data_(data), length_(length), validity_(validity) {}
  virtual ~LValue() = default;

  llvm::Value* data() { return data_; }
  llvm::Value* length() { return length_; }
  llvm::Value* validity() { return validity_; }

  void set_data(llvm::Value* data) { data_ = data; }

  // Append the params required when passing this as a function parameter.
  virtual void AppendFunctionParams(std::vector<llvm::Value*>* params) {
    params->push_back(data_);
    if (length_ != NULLPTR) {
      params->push_back(length_);
    }
  }

 private:
  llvm::Value* data_;
  llvm::Value* length_;
  llvm::Value* validity_;
};

class GANDIVA_EXPORT DecimalLValue : public LValue {
 public:
  DecimalLValue(llvm::Value* data, llvm::Value* validity, llvm::Value* precision,
                llvm::Value* scale)
      : LValue(data, NULLPTR, validity), precision_(precision), scale_(scale) {}

  llvm::Value* precision() { return precision_; }
  llvm::Value* scale() { return scale_; }

  void AppendFunctionParams(std::vector<llvm::Value*>* params) override {
    LValue::AppendFunctionParams(params);
    params->push_back(precision_);
    params->push_back(scale_);
  }

 private:
  llvm::Value* precision_;
  llvm::Value* scale_;
};

}  // namespace gandiva
