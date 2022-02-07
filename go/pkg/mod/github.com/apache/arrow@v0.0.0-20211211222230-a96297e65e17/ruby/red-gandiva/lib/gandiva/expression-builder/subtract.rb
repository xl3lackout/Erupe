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

require "gandiva/expression-builder/binary-operation"

module Gandiva
  class ExpressionBuilder
    class Subtract < BinaryOperation
      def initialize(left, right)
        super("subtract", left, right)
      end

      private
      def return_type(left_node, right_node)
        # TODO: Use larger type
        right_node.return_type
      end
    end
  end
end
