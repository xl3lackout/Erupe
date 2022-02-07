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

#include "jni/org_apache_arrow_gandiva_evaluator_ExpressionRegistryJniHelper.h"

#include <memory>

#include "Types.pb.h"
#include "arrow/util/logging.h"
#include "gandiva/arrow.h"
#include "gandiva/expression_registry.h"

using gandiva::DataTypePtr;
using gandiva::ExpressionRegistry;

types::TimeUnit MapTimeUnit(arrow::TimeUnit::type& unit) {
  switch (unit) {
    case arrow::TimeUnit::MILLI:
      return types::TimeUnit::MILLISEC;
    case arrow::TimeUnit::SECOND:
      return types::TimeUnit::SEC;
    case arrow::TimeUnit::MICRO:
      return types::TimeUnit::MICROSEC;
    case arrow::TimeUnit::NANO:
      return types::TimeUnit::NANOSEC;
  }
  // satisfy gcc. should be unreachable.
  return types::TimeUnit::SEC;
}

void ArrowToProtobuf(DataTypePtr type, types::ExtGandivaType* gandiva_data_type) {
  switch (type->id()) {
    case arrow::Type::BOOL:
      gandiva_data_type->set_type(types::GandivaType::BOOL);
      break;
    case arrow::Type::UINT8:
      gandiva_data_type->set_type(types::GandivaType::UINT8);
      break;
    case arrow::Type::INT8:
      gandiva_data_type->set_type(types::GandivaType::INT8);
      break;
    case arrow::Type::UINT16:
      gandiva_data_type->set_type(types::GandivaType::UINT16);
      break;
    case arrow::Type::INT16:
      gandiva_data_type->set_type(types::GandivaType::INT16);
      break;
    case arrow::Type::UINT32:
      gandiva_data_type->set_type(types::GandivaType::UINT32);
      break;
    case arrow::Type::INT32:
      gandiva_data_type->set_type(types::GandivaType::INT32);
      break;
    case arrow::Type::UINT64:
      gandiva_data_type->set_type(types::GandivaType::UINT64);
      break;
    case arrow::Type::INT64:
      gandiva_data_type->set_type(types::GandivaType::INT64);
      break;
    case arrow::Type::HALF_FLOAT:
      gandiva_data_type->set_type(types::GandivaType::HALF_FLOAT);
      break;
    case arrow::Type::FLOAT:
      gandiva_data_type->set_type(types::GandivaType::FLOAT);
      break;
    case arrow::Type::DOUBLE:
      gandiva_data_type->set_type(types::GandivaType::DOUBLE);
      break;
    case arrow::Type::STRING:
      gandiva_data_type->set_type(types::GandivaType::UTF8);
      break;
    case arrow::Type::BINARY:
      gandiva_data_type->set_type(types::GandivaType::BINARY);
      break;
    case arrow::Type::DATE32:
      gandiva_data_type->set_type(types::GandivaType::DATE32);
      break;
    case arrow::Type::DATE64:
      gandiva_data_type->set_type(types::GandivaType::DATE64);
      break;
    case arrow::Type::TIMESTAMP: {
      gandiva_data_type->set_type(types::GandivaType::TIMESTAMP);
      std::shared_ptr<arrow::TimestampType> cast_time_stamp_type =
          std::dynamic_pointer_cast<arrow::TimestampType>(type);
      arrow::TimeUnit::type unit = cast_time_stamp_type->unit();
      types::TimeUnit time_unit = MapTimeUnit(unit);
      gandiva_data_type->set_timeunit(time_unit);
      break;
    }
    case arrow::Type::TIME32: {
      gandiva_data_type->set_type(types::GandivaType::TIME32);
      std::shared_ptr<arrow::Time32Type> cast_time_32_type =
          std::dynamic_pointer_cast<arrow::Time32Type>(type);
      arrow::TimeUnit::type unit = cast_time_32_type->unit();
      types::TimeUnit time_unit = MapTimeUnit(unit);
      gandiva_data_type->set_timeunit(time_unit);
      break;
    }
    case arrow::Type::TIME64: {
      gandiva_data_type->set_type(types::GandivaType::TIME32);
      std::shared_ptr<arrow::Time64Type> cast_time_64_type =
          std::dynamic_pointer_cast<arrow::Time64Type>(type);
      arrow::TimeUnit::type unit = cast_time_64_type->unit();
      types::TimeUnit time_unit = MapTimeUnit(unit);
      gandiva_data_type->set_timeunit(time_unit);
      break;
    }
    case arrow::Type::NA:
      gandiva_data_type->set_type(types::GandivaType::NONE);
      break;
    case arrow::Type::DECIMAL: {
      gandiva_data_type->set_type(types::GandivaType::DECIMAL);
      gandiva_data_type->set_precision(0);
      gandiva_data_type->set_scale(0);
      break;
    }
    case arrow::Type::INTERVAL_MONTHS:
      gandiva_data_type->set_type(types::GandivaType::INTERVAL);
      gandiva_data_type->set_intervaltype(types::IntervalType::YEAR_MONTH);
      break;
    case arrow::Type::INTERVAL_DAY_TIME:
      gandiva_data_type->set_type(types::GandivaType::INTERVAL);
      gandiva_data_type->set_intervaltype(types::IntervalType::DAY_TIME);
      break;
    default:
      // un-supported types. test ensures that
      // when one of these are added build breaks.
      DCHECK(false);
  }
}

JNIEXPORT jbyteArray JNICALL
Java_org_apache_arrow_gandiva_evaluator_ExpressionRegistryJniHelper_getGandivaSupportedDataTypes(  // NOLINT
    JNIEnv* env, jobject types_helper) {
  types::GandivaDataTypes gandiva_data_types;
  auto supported_types = ExpressionRegistry::supported_types();
  for (auto const& type : supported_types) {
    types::ExtGandivaType* gandiva_data_type = gandiva_data_types.add_datatype();
    ArrowToProtobuf(type, gandiva_data_type);
  }
  auto size = gandiva_data_types.ByteSizeLong();
  std::unique_ptr<jbyte[]> buffer{new jbyte[size]};
  gandiva_data_types.SerializeToArray(reinterpret_cast<void*>(buffer.get()), size);
  jbyteArray ret = env->NewByteArray(size);
  env->SetByteArrayRegion(ret, 0, size, buffer.get());
  return ret;
}

/*
 * Class:     org_apache_arrow_gandiva_types_ExpressionRegistryJniHelper
 * Method:    getGandivaSupportedFunctions
 * Signature: ()[B
 */
JNIEXPORT jbyteArray JNICALL
Java_org_apache_arrow_gandiva_evaluator_ExpressionRegistryJniHelper_getGandivaSupportedFunctions(  // NOLINT
    JNIEnv* env, jobject types_helper) {
  ExpressionRegistry expr_registry;
  types::GandivaFunctions gandiva_functions;
  for (auto function = expr_registry.function_signature_begin();
       function != expr_registry.function_signature_end(); function++) {
    types::FunctionSignature* function_signature = gandiva_functions.add_function();
    function_signature->set_name((*function).base_name());
    types::ExtGandivaType* return_type = function_signature->mutable_returntype();
    ArrowToProtobuf((*function).ret_type(), return_type);
    for (auto& param_type : (*function).param_types()) {
      types::ExtGandivaType* proto_param_type = function_signature->add_paramtypes();
      ArrowToProtobuf(param_type, proto_param_type);
    }
  }
  auto size = gandiva_functions.ByteSizeLong();
  std::unique_ptr<jbyte[]> buffer{new jbyte[size]};
  gandiva_functions.SerializeToArray(reinterpret_cast<void*>(buffer.get()), size);
  jbyteArray ret = env->NewByteArray(size);
  env->SetByteArrayRegion(ret, 0, size, buffer.get());
  return ret;
}
