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

#pragma once

#include <arrow/adapters/orc/adapter.h>

#include <arrow-glib/reader.hpp>
#include <arrow-glib/orc-file-reader.h>

GArrowORCFileReader *
garrow_orc_file_reader_new_raw(GArrowSeekableInputStream *input,
                               arrow::adapters::orc::ORCFileReader *arrow_reader);
arrow::adapters::orc::ORCFileReader *
garrow_orc_file_reader_get_raw(GArrowORCFileReader *reader);
