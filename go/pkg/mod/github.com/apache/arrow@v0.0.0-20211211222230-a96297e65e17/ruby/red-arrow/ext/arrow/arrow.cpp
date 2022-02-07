/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#include "red-arrow.hpp"
#include "memory-view.hpp"

#include <ruby.hpp>

namespace red_arrow {
  VALUE cDate;

  VALUE cArrowTime;

  VALUE ArrowTimeUnitSECOND;
  VALUE ArrowTimeUnitMILLI;
  VALUE ArrowTimeUnitMICRO;
  VALUE ArrowTimeUnitNANO;

  ID id_BigDecimal;
  ID id_jd;
  ID id_new;
  ID id_to_datetime;
}

extern "C" void Init_arrow() {
  auto mArrow = rb_const_get_at(rb_cObject, rb_intern("Arrow"));

  auto cArrowArray = rb_const_get_at(mArrow, rb_intern("Array"));
  rb_define_method(cArrowArray, "values",
                   reinterpret_cast<rb::RawMethod>(red_arrow::array_values),
                   0);

  auto cArrowChunkedArray = rb_const_get_at(mArrow, rb_intern("ChunkedArray"));
  rb_define_method(cArrowChunkedArray, "values",
                   reinterpret_cast<rb::RawMethod>(red_arrow::chunked_array_values),
                   0);

  auto cArrowRecordBatch = rb_const_get_at(mArrow, rb_intern("RecordBatch"));
  rb_define_method(cArrowRecordBatch, "raw_records",
                   reinterpret_cast<rb::RawMethod>(red_arrow::record_batch_raw_records),
                   0);

  auto cArrowTable = rb_const_get_at(mArrow, rb_intern("Table"));
  rb_define_method(cArrowTable, "raw_records",
                   reinterpret_cast<rb::RawMethod>(red_arrow::table_raw_records),
                   0);

  red_arrow::cDate = rb_const_get(rb_cObject, rb_intern("Date"));

  red_arrow::cArrowTime = rb_const_get_at(mArrow, rb_intern("Time"));

  auto cArrowTimeUnit = rb_const_get_at(mArrow, rb_intern("TimeUnit"));
  red_arrow::ArrowTimeUnitSECOND =
    rb_const_get_at(cArrowTimeUnit, rb_intern("SECOND"));
  red_arrow::ArrowTimeUnitMILLI =
    rb_const_get_at(cArrowTimeUnit, rb_intern("MILLI"));
  red_arrow::ArrowTimeUnitMICRO =
    rb_const_get_at(cArrowTimeUnit, rb_intern("MICRO"));
  red_arrow::ArrowTimeUnitNANO =
    rb_const_get_at(cArrowTimeUnit, rb_intern("NANO"));

  red_arrow::id_BigDecimal = rb_intern("BigDecimal");
  red_arrow::id_jd = rb_intern("jd");
  red_arrow::id_new = rb_intern("new");
  red_arrow::id_to_datetime = rb_intern("to_datetime");

  red_arrow::memory_view::init(mArrow);
}
