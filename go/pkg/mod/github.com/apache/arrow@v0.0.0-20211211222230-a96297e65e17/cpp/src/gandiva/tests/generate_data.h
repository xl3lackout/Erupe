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

#include <stdlib.h>
#include <random>
#include <string>

#include "arrow/util/decimal.h"
#include "arrow/util/io_util.h"

#pragma once

namespace gandiva {

template <typename C_TYPE>
class DataGenerator {
 public:
  virtual ~DataGenerator() = default;

  virtual C_TYPE GenerateData() = 0;
};

class Random {
 public:
  Random() : gen_(::arrow::internal::GetRandomSeed()) {}
  explicit Random(uint64_t seed) : gen_(seed) {}

  int32_t next() { return gen_(); }

 private:
  std::default_random_engine gen_;
};

class Int32DataGenerator : public DataGenerator<int32_t> {
 public:
  Int32DataGenerator() {}

  int32_t GenerateData() { return random_.next(); }

 protected:
  Random random_;
};

class BoundedInt32DataGenerator : public Int32DataGenerator {
 public:
  explicit BoundedInt32DataGenerator(uint32_t upperBound)
      : Int32DataGenerator(), upperBound_(upperBound) {}

  int32_t GenerateData() {
    int32_t value = (random_.next() % upperBound_);
    return value;
  }

 protected:
  uint32_t upperBound_;
};

class Int64DataGenerator : public DataGenerator<int64_t> {
 public:
  Int64DataGenerator() {}

  int64_t GenerateData() { return random_.next(); }

 protected:
  Random random_;
};

class Decimal128DataGenerator : public DataGenerator<arrow::Decimal128> {
 public:
  explicit Decimal128DataGenerator(bool large) : large_(large) {}

  arrow::Decimal128 GenerateData() {
    uint64_t low = random_.next();
    int64_t high = random_.next();
    if (large_) {
      high += (1ull << 62);
    }
    return arrow::Decimal128(high, low);
  }

 protected:
  bool large_;
  Random random_;
};

class FastUtf8DataGenerator : public DataGenerator<std::string> {
 public:
  explicit FastUtf8DataGenerator(int max_len) : max_len_(max_len), cur_char_('a') {}

  std::string GenerateData() {
    std::string generated_str;

    int slen = random_.next() % max_len_;
    for (int i = 0; i < slen; ++i) {
      generated_str += generate_next_char();
    }
    return generated_str;
  }

 private:
  char generate_next_char() {
    ++cur_char_;
    if (cur_char_ > 'z') {
      cur_char_ = 'a';
    }
    return cur_char_;
  }

  Random random_;
  unsigned int max_len_;
  char cur_char_;
};

class Utf8IntDataGenerator : public DataGenerator<std::string> {
 public:
  Utf8IntDataGenerator() {}

  std::string GenerateData() { return std::to_string(random_.next()); }

 private:
  Random random_;
};

class Utf8FloatDataGenerator : public DataGenerator<std::string> {
 public:
  Utf8FloatDataGenerator() {}

  std::string GenerateData() {
    return std::to_string(
        static_cast<float>(random_.next()) /
        static_cast<float>(RAND_MAX / 100));  // random float between 0.0 to 100.0
  }

 private:
  Random random_;
};

}  // namespace gandiva
