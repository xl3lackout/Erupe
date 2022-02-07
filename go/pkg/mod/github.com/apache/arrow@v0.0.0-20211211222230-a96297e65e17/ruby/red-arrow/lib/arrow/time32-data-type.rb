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

module Arrow
  class Time32DataType
    alias_method :initialize_raw, :initialize
    private :initialize_raw

    # Creates a new {Arrow::Time32DataType}.
    #
    # @overload initialize(unit)
    #
    #   @param unit [Arrow::TimeUnit, Symbol] The unit of the
    #     time32 data type.
    #
    #     The unit must be second or millisecond.
    #
    #   @example Create a time32 data type with Arrow::TimeUnit
    #     Arrow::Time32DataType.new(Arrow::TimeUnit::MILLI)
    #
    #   @example Create a time32 data type with Symbol
    #     Arrow::Time32DataType.new(:milli)
    #
    # @overload initialize(description)
    #
    #   @param description [Hash] The description of the time32 data
    #     type. It must have `:unit` value.
    #
    #   @option description [Arrow::TimeUnit, Symbol] :unit The unit of
    #     the time32 data type.
    #
    #     The unit must be second or millisecond.
    #
    #   @example Create a time32 data type with Arrow::TimeUnit
    #     Arrow::Time32DataType.new(unit: Arrow::TimeUnit::MILLI)
    #
    #   @example Create a time32 data type with Symbol
    #     Arrow::Time32DataType.new(unit: :milli)
    def initialize(unit)
      if unit.is_a?(Hash)
        description = unit
        unit = description[:unit]
      end
      initialize_raw(unit)
    end
  end
end
