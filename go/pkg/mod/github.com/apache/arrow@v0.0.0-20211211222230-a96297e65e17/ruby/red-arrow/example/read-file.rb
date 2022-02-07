#!/usr/bin/env ruby
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

require "arrow"

Arrow::MemoryMappedInputStream.open("/tmp/file.arrow") do |input|
  reader = Arrow::RecordBatchFileReader.new(input)
  fields = reader.schema.fields
  reader.each_with_index do |record_batch, i|
    puts("=" * 40)
    puts("record-batch[#{i}]:")
    fields.each do |field|
      field_name = field.name
      values = record_batch.collect do |record|
        record[field_name]
      end
      puts("  #{field_name}: #{values.inspect}")
    end
  end
end
