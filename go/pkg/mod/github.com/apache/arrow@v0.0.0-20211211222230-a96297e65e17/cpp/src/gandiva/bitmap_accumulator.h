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
#include "gandiva/dex.h"
#include "gandiva/dex_visitor.h"
#include "gandiva/eval_batch.h"
#include "gandiva/visibility.h"

namespace gandiva {

/// \brief Extract bitmap buffer from either the input/buffer vectors or the
/// local validity bitmap, and accumulates them to do the final computation.
class GANDIVA_EXPORT BitMapAccumulator : public DexDefaultVisitor {
 public:
  explicit BitMapAccumulator(const EvalBatch& eval_batch)
      : eval_batch_(eval_batch), all_invalid_(false) {}

  void Visit(const VectorReadValidityDex& dex) {
    int idx = dex.ValidityIdx();
    auto bitmap = eval_batch_.GetBuffer(idx);
    // The bitmap could be null. Ignore it in this case.
    if (bitmap != NULLPTR) {
      src_maps_.push_back(bitmap);
      src_map_offsets_.push_back(eval_batch_.GetBufferOffset(idx));
    }
  }

  void Visit(const LocalBitMapValidityDex& dex) {
    int idx = dex.local_bitmap_idx();
    auto bitmap = eval_batch_.GetLocalBitMap(idx);
    src_maps_.push_back(bitmap);
    src_map_offsets_.push_back(0);  // local bitmap has offset 0
  }

  void Visit(const TrueDex& dex) {
    // bitwise-and with 1 is always 1. so, ignore.
  }

  void Visit(const FalseDex& dex) {
    // The final result is "all 0s".
    all_invalid_ = true;
  }

  /// Compute the dst_bmap based on the contents and type of the accumulated bitmap dex.
  void ComputeResult(uint8_t* dst_bitmap);

  /// Compute the intersection of the accumulated bitmaps (with offsets) and save the
  /// result in dst_bmap.
  static void IntersectBitMaps(uint8_t* dst_map, const std::vector<uint8_t*>& src_maps,
                               const std::vector<int64_t>& src_maps_offsets,
                               int64_t num_records);

 private:
  const EvalBatch& eval_batch_;
  std::vector<uint8_t*> src_maps_;
  std::vector<int64_t> src_map_offsets_;
  bool all_invalid_;
};

}  // namespace gandiva
