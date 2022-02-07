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

#include <string>

#include "gandiva/configuration.h"
#include "gandiva/jni/config_holder.h"
#include "gandiva/jni/env_helper.h"
#include "jni/org_apache_arrow_gandiva_evaluator_ConfigurationBuilder.h"

using gandiva::ConfigHolder;
using gandiva::Configuration;
using gandiva::ConfigurationBuilder;

/*
 * Class:     org_apache_arrow_gandiva_evaluator_ConfigBuilder
 * Method:    buildConfigInstance
 * Signature: (ZZ)J
 */
JNIEXPORT jlong JNICALL
Java_org_apache_arrow_gandiva_evaluator_ConfigurationBuilder_buildConfigInstance(
    JNIEnv* env, jobject configuration, jboolean optimize, jboolean target_host_cpu) {
  ConfigurationBuilder configuration_builder;
  std::shared_ptr<Configuration> config = configuration_builder.build();
  config->set_optimize(optimize);
  config->target_host_cpu(target_host_cpu);
  return ConfigHolder::MapInsert(config);
}

/*
 * Class:     org_apache_arrow_gandiva_evaluator_ConfigBuilder
 * Method:    releaseConfigInstance
 * Signature: (J)V
 */
JNIEXPORT void JNICALL
Java_org_apache_arrow_gandiva_evaluator_ConfigurationBuilder_releaseConfigInstance(
    JNIEnv* env, jobject configuration, jlong config_id) {
  ConfigHolder::MapErase(config_id);
}
