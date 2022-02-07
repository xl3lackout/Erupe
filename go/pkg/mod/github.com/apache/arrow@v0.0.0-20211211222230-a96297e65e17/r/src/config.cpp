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

#include "./arrow_types.h"

#if defined(ARROW_R_WITH_ARROW)

#include <arrow/config.h>

// [[arrow::export]]
std::vector<std::string> build_info() {
  auto info = arrow::GetBuildInfo();
  return {info.version_string, info.compiler_id, info.compiler_version,
          info.compiler_flags, info.git_id};
}

// [[arrow::export]]
std::vector<std::string> runtime_info() {
  auto info = arrow::GetRuntimeInfo();
  return {info.simd_level, info.detected_simd_level};
}

#endif
