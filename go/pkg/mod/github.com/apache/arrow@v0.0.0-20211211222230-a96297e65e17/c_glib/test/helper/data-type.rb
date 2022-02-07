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

module Helper
  module DataType
    def boolean_data_type
      Arrow::BooleanDataType.new
    end

    def int8_data_type
      Arrow::Int8DataType.new
    end

    def int16_data_type
      Arrow::Int16DataType.new
    end

    def int32_data_type
      Arrow::Int32DataType.new
    end

    def int64_data_type
      Arrow::Int64DataType.new
    end

    def uint8_data_type
      Arrow::UInt8DataType.new
    end

    def uint16_data_type
      Arrow::UInt16DataType.new
    end

    def uint32_data_type
      Arrow::UInt32DataType.new
    end

    def uint64_data_type
      Arrow::UInt64DataType.new
    end

    def string_data_type
      Arrow::StringDataType.new
    end

    def date64_data_type
      Arrow::Date64DataType.new
    end
  end
end
