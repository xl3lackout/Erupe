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

#include <mutex>

#include "arrow/array.h"
#include "arrow/dataset/api.h"
#include "arrow/dataset/file_base.h"
#include "arrow/filesystem/localfs.h"
#include "arrow/ipc/api.h"
#include "arrow/util/iterator.h"

#include "jni/dataset/jni_util.h"

#include "org_apache_arrow_dataset_file_JniWrapper.h"
#include "org_apache_arrow_dataset_jni_JniWrapper.h"
#include "org_apache_arrow_dataset_jni_NativeMemoryPool.h"

namespace {

jclass illegal_access_exception_class;
jclass illegal_argument_exception_class;
jclass runtime_exception_class;

jclass record_batch_handle_class;
jclass record_batch_handle_field_class;
jclass record_batch_handle_buffer_class;
jclass java_reservation_listener_class;

jmethodID record_batch_handle_constructor;
jmethodID record_batch_handle_field_constructor;
jmethodID record_batch_handle_buffer_constructor;
jmethodID reserve_memory_method;
jmethodID unreserve_memory_method;

jlong default_memory_pool_id = -1L;

jint JNI_VERSION = JNI_VERSION_1_6;

class JniPendingException : public std::runtime_error {
 public:
  explicit JniPendingException(const std::string& arg) : runtime_error(arg) {}
};

void ThrowPendingException(const std::string& message) {
  throw JniPendingException(message);
}

template <typename T>
T JniGetOrThrow(arrow::Result<T> result) {
  if (!result.status().ok()) {
    ThrowPendingException(result.status().message());
  }
  return std::move(result).ValueOrDie();
}

void JniAssertOkOrThrow(arrow::Status status) {
  if (!status.ok()) {
    ThrowPendingException(status.message());
  }
}

void JniThrow(std::string message) { ThrowPendingException(message); }

arrow::Result<std::shared_ptr<arrow::dataset::FileFormat>> GetFileFormat(
    jint file_format_id) {
  switch (file_format_id) {
    case 0:
      return std::make_shared<arrow::dataset::ParquetFileFormat>();
    default:
      std::string error_message =
          "illegal file format id: " + std::to_string(file_format_id);
      return arrow::Status::Invalid(error_message);
  }
}

class ReserveFromJava : public arrow::dataset::jni::ReservationListener {
 public:
  ReserveFromJava(JavaVM* vm, jobject java_reservation_listener)
      : vm_(vm), java_reservation_listener_(java_reservation_listener) {}

  arrow::Status OnReservation(int64_t size) override {
    JNIEnv* env;
    if (vm_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION) != JNI_OK) {
      return arrow::Status::Invalid("JNIEnv was not attached to current thread");
    }
    env->CallObjectMethod(java_reservation_listener_, reserve_memory_method, size);
    if (env->ExceptionCheck()) {
      env->ExceptionDescribe();
      env->ExceptionClear();
      return arrow::Status::Invalid("Error calling Java side reservation listener");
    }
    return arrow::Status::OK();
  }

  arrow::Status OnRelease(int64_t size) override {
    JNIEnv* env;
    if (vm_->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION) != JNI_OK) {
      return arrow::Status::Invalid("JNIEnv was not attached to current thread");
    }
    env->CallObjectMethod(java_reservation_listener_, unreserve_memory_method, size);
    if (env->ExceptionCheck()) {
      env->ExceptionDescribe();
      env->ExceptionClear();
      return arrow::Status::Invalid("Error calling Java side reservation listener");
    }
    return arrow::Status::OK();
  }

  jobject GetJavaReservationListener() { return java_reservation_listener_; }

 private:
  JavaVM* vm_;
  jobject java_reservation_listener_;
};

/// \class DisposableScannerAdaptor
/// \brief An adaptor that iterates over a Scanner instance then returns RecordBatches
/// directly.
///
/// This lessens the complexity of the JNI bridge to make sure it to be easier to
/// maintain. On Java-side, NativeScanner can only produces a single NativeScanTask
/// instance during its whole lifecycle. Each task stands for a DisposableScannerAdaptor
/// instance through JNI bridge.
///
class DisposableScannerAdaptor {
 public:
  DisposableScannerAdaptor(std::shared_ptr<arrow::dataset::Scanner> scanner,
                           arrow::dataset::TaggedRecordBatchIterator batch_itr)
      : scanner_(std::move(scanner)), batch_itr_(std::move(batch_itr)) {}

  static arrow::Result<std::shared_ptr<DisposableScannerAdaptor>> Create(
      std::shared_ptr<arrow::dataset::Scanner> scanner) {
    ARROW_ASSIGN_OR_RAISE(auto batch_itr, scanner->ScanBatches());
    return std::make_shared<DisposableScannerAdaptor>(scanner, std::move(batch_itr));
  }

  arrow::Result<std::shared_ptr<arrow::RecordBatch>> Next() {
    ARROW_ASSIGN_OR_RAISE(std::shared_ptr<arrow::RecordBatch> batch, NextBatch());
    return batch;
  }

  const std::shared_ptr<arrow::dataset::Scanner>& GetScanner() const { return scanner_; }

 private:
  std::shared_ptr<arrow::dataset::Scanner> scanner_;
  arrow::dataset::TaggedRecordBatchIterator batch_itr_;

  arrow::Result<std::shared_ptr<arrow::RecordBatch>> NextBatch() {
    ARROW_ASSIGN_OR_RAISE(auto batch, batch_itr_.Next())
    return batch.record_batch;
  }
};

}  // namespace

using arrow::dataset::jni::CreateGlobalClassReference;
using arrow::dataset::jni::CreateNativeRef;
using arrow::dataset::jni::FromSchemaByteArray;
using arrow::dataset::jni::GetMethodID;
using arrow::dataset::jni::JStringToCString;
using arrow::dataset::jni::ReleaseNativeRef;
using arrow::dataset::jni::RetrieveNativeInstance;
using arrow::dataset::jni::ToSchemaByteArray;
using arrow::dataset::jni::ToStringVector;

using arrow::dataset::jni::ReservationListenableMemoryPool;
using arrow::dataset::jni::ReservationListener;

#define JNI_METHOD_START try {
// macro ended

#define JNI_METHOD_END(fallback_expr)                 \
  }                                                   \
  catch (JniPendingException & e) {                   \
    env->ThrowNew(runtime_exception_class, e.what()); \
    return fallback_expr;                             \
  }
// macro ended

jint JNI_OnLoad(JavaVM* vm, void* reserved) {
  JNIEnv* env;
  if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION) != JNI_OK) {
    return JNI_ERR;
  }
  JNI_METHOD_START
  illegal_access_exception_class =
      CreateGlobalClassReference(env, "Ljava/lang/IllegalAccessException;");
  illegal_argument_exception_class =
      CreateGlobalClassReference(env, "Ljava/lang/IllegalArgumentException;");
  runtime_exception_class =
      CreateGlobalClassReference(env, "Ljava/lang/RuntimeException;");

  record_batch_handle_class =
      CreateGlobalClassReference(env,
                                 "Lorg/apache/arrow/"
                                 "dataset/jni/NativeRecordBatchHandle;");
  record_batch_handle_field_class =
      CreateGlobalClassReference(env,
                                 "Lorg/apache/arrow/"
                                 "dataset/jni/NativeRecordBatchHandle$Field;");
  record_batch_handle_buffer_class =
      CreateGlobalClassReference(env,
                                 "Lorg/apache/arrow/"
                                 "dataset/jni/NativeRecordBatchHandle$Buffer;");
  java_reservation_listener_class =
      CreateGlobalClassReference(env,
                                 "Lorg/apache/arrow/"
                                 "dataset/jni/ReservationListener;");

  record_batch_handle_constructor =
      JniGetOrThrow(GetMethodID(env, record_batch_handle_class, "<init>",
                                "(J[Lorg/apache/arrow/dataset/"
                                "jni/NativeRecordBatchHandle$Field;"
                                "[Lorg/apache/arrow/dataset/"
                                "jni/NativeRecordBatchHandle$Buffer;)V"));
  record_batch_handle_field_constructor =
      JniGetOrThrow(GetMethodID(env, record_batch_handle_field_class, "<init>", "(JJ)V"));
  record_batch_handle_buffer_constructor = JniGetOrThrow(
      GetMethodID(env, record_batch_handle_buffer_class, "<init>", "(JJJJ)V"));
  reserve_memory_method =
      JniGetOrThrow(GetMethodID(env, java_reservation_listener_class, "reserve", "(J)V"));
  unreserve_memory_method = JniGetOrThrow(
      GetMethodID(env, java_reservation_listener_class, "unreserve", "(J)V"));

  default_memory_pool_id = reinterpret_cast<jlong>(arrow::default_memory_pool());

  return JNI_VERSION;
  JNI_METHOD_END(JNI_ERR)
}

void JNI_OnUnload(JavaVM* vm, void* reserved) {
  JNIEnv* env;
  vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION);
  env->DeleteGlobalRef(illegal_access_exception_class);
  env->DeleteGlobalRef(illegal_argument_exception_class);
  env->DeleteGlobalRef(runtime_exception_class);
  env->DeleteGlobalRef(record_batch_handle_class);
  env->DeleteGlobalRef(record_batch_handle_field_class);
  env->DeleteGlobalRef(record_batch_handle_buffer_class);
  env->DeleteGlobalRef(java_reservation_listener_class);

  default_memory_pool_id = -1L;
}

/*
 * Class:     org_apache_arrow_dataset_jni_NativeMemoryPool
 * Method:    getDefaultMemoryPool
 * Signature: ()J
 */
JNIEXPORT jlong JNICALL
Java_org_apache_arrow_dataset_jni_NativeMemoryPool_getDefaultMemoryPool(JNIEnv* env,
                                                                        jclass) {
  JNI_METHOD_START
  return default_memory_pool_id;
  JNI_METHOD_END(-1L)
}

/*
 * Class:     org_apache_arrow_dataset_jni_NativeMemoryPool
 * Method:    createListenableMemoryPool
 * Signature: (Lorg/apache/arrow/memory/ReservationListener;)J
 */
JNIEXPORT jlong JNICALL
Java_org_apache_arrow_dataset_jni_NativeMemoryPool_createListenableMemoryPool(
    JNIEnv* env, jclass, jobject jlistener) {
  JNI_METHOD_START
  jobject jlistener_ref = env->NewGlobalRef(jlistener);
  JavaVM* vm;
  if (env->GetJavaVM(&vm) != JNI_OK) {
    JniThrow("Unable to get JavaVM instance");
  }
  std::shared_ptr<ReservationListener> listener =
      std::make_shared<ReserveFromJava>(vm, jlistener_ref);
  auto memory_pool =
      new ReservationListenableMemoryPool(arrow::default_memory_pool(), listener);
  return reinterpret_cast<jlong>(memory_pool);
  JNI_METHOD_END(-1L)
}

/*
 * Class:     org_apache_arrow_dataset_jni_NativeMemoryPool
 * Method:    releaseMemoryPool
 * Signature: (J)V
 */
JNIEXPORT void JNICALL
Java_org_apache_arrow_dataset_jni_NativeMemoryPool_releaseMemoryPool(
    JNIEnv* env, jclass, jlong memory_pool_id) {
  JNI_METHOD_START
  if (memory_pool_id == default_memory_pool_id) {
    return;
  }
  ReservationListenableMemoryPool* pool =
      reinterpret_cast<ReservationListenableMemoryPool*>(memory_pool_id);
  if (pool == nullptr) {
    return;
  }
  std::shared_ptr<ReserveFromJava> rm =
      std::dynamic_pointer_cast<ReserveFromJava>(pool->get_listener());
  if (rm == nullptr) {
    delete pool;
    return;
  }
  delete pool;
  env->DeleteGlobalRef(rm->GetJavaReservationListener());
  JNI_METHOD_END()
}

/*
 * Class:     org_apache_arrow_dataset_jni_NativeMemoryPool
 * Method:    bytesAllocated
 * Signature: (J)J
 */
JNIEXPORT jlong JNICALL Java_org_apache_arrow_dataset_jni_NativeMemoryPool_bytesAllocated(
    JNIEnv* env, jclass, jlong memory_pool_id) {
  JNI_METHOD_START
  arrow::MemoryPool* pool = reinterpret_cast<arrow::MemoryPool*>(memory_pool_id);
  if (pool == nullptr) {
    JniThrow("Memory pool instance not found. It may not exist nor has been closed");
  }
  return pool->bytes_allocated();
  JNI_METHOD_END(-1L)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    closeDatasetFactory
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_closeDatasetFactory(
    JNIEnv* env, jobject, jlong id) {
  JNI_METHOD_START
  ReleaseNativeRef<arrow::dataset::DatasetFactory>(id);
  JNI_METHOD_END()
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    inspectSchema
 * Signature: (J)[B
 */
JNIEXPORT jbyteArray JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_inspectSchema(
    JNIEnv* env, jobject, jlong dataset_factor_id) {
  JNI_METHOD_START
  std::shared_ptr<arrow::dataset::DatasetFactory> d =
      RetrieveNativeInstance<arrow::dataset::DatasetFactory>(dataset_factor_id);
  std::shared_ptr<arrow::Schema> schema = JniGetOrThrow(d->Inspect());
  return JniGetOrThrow(ToSchemaByteArray(env, schema));
  JNI_METHOD_END(nullptr)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    createDataset
 * Signature: (J[B)J
 */
JNIEXPORT jlong JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_createDataset(
    JNIEnv* env, jobject, jlong dataset_factory_id, jbyteArray schema_bytes) {
  JNI_METHOD_START
  std::shared_ptr<arrow::dataset::DatasetFactory> d =
      RetrieveNativeInstance<arrow::dataset::DatasetFactory>(dataset_factory_id);
  std::shared_ptr<arrow::Schema> schema;
  schema = JniGetOrThrow(FromSchemaByteArray(env, schema_bytes));
  std::shared_ptr<arrow::dataset::Dataset> dataset = JniGetOrThrow(d->Finish(schema));
  return CreateNativeRef(dataset);
  JNI_METHOD_END(-1L)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    closeDataset
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_closeDataset(
    JNIEnv* env, jobject, jlong id) {
  JNI_METHOD_START
  ReleaseNativeRef<arrow::dataset::Dataset>(id);
  JNI_METHOD_END()
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    createScanner
 * Signature: (J[Ljava/lang/String;JJ)J
 */
JNIEXPORT jlong JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_createScanner(
    JNIEnv* env, jobject, jlong dataset_id, jobjectArray columns, jlong batch_size,
    jlong memory_pool_id) {
  JNI_METHOD_START
  arrow::MemoryPool* pool = reinterpret_cast<arrow::MemoryPool*>(memory_pool_id);
  if (pool == nullptr) {
    JniThrow("Memory pool does not exist or has been closed");
  }
  std::shared_ptr<arrow::dataset::Dataset> dataset =
      RetrieveNativeInstance<arrow::dataset::Dataset>(dataset_id);
  std::shared_ptr<arrow::dataset::ScannerBuilder> scanner_builder =
      JniGetOrThrow(dataset->NewScan());
  JniAssertOkOrThrow(scanner_builder->Pool(pool));
  if (columns != nullptr) {
    std::vector<std::string> column_vector = ToStringVector(env, columns);
    JniAssertOkOrThrow(scanner_builder->Project(column_vector));
  }
  JniAssertOkOrThrow(scanner_builder->BatchSize(batch_size));

  auto scanner = JniGetOrThrow(scanner_builder->Finish());
  std::shared_ptr<DisposableScannerAdaptor> scanner_adaptor =
      JniGetOrThrow(DisposableScannerAdaptor::Create(scanner));
  jlong id = CreateNativeRef(scanner_adaptor);
  return id;
  JNI_METHOD_END(-1L)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    closeScanner
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_closeScanner(
    JNIEnv* env, jobject, jlong scanner_id) {
  JNI_METHOD_START
  ReleaseNativeRef<DisposableScannerAdaptor>(scanner_id);
  JNI_METHOD_END()
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    getSchemaFromScanner
 * Signature: (J)[B
 */
JNIEXPORT jbyteArray JNICALL
Java_org_apache_arrow_dataset_jni_JniWrapper_getSchemaFromScanner(JNIEnv* env, jobject,
                                                                  jlong scanner_id) {
  JNI_METHOD_START
  std::shared_ptr<arrow::Schema> schema =
      RetrieveNativeInstance<DisposableScannerAdaptor>(scanner_id)
          ->GetScanner()
          ->options()
          ->projected_schema;
  return JniGetOrThrow(ToSchemaByteArray(env, schema));
  JNI_METHOD_END(nullptr)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    nextRecordBatch
 * Signature: (J)Lorg/apache/arrow/dataset/jni/NativeRecordBatchHandle;
 */
JNIEXPORT jobject JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_nextRecordBatch(
    JNIEnv* env, jobject, jlong scanner_id) {
  JNI_METHOD_START
  std::shared_ptr<DisposableScannerAdaptor> scanner_adaptor =
      RetrieveNativeInstance<DisposableScannerAdaptor>(scanner_id);

  std::shared_ptr<arrow::RecordBatch> record_batch =
      JniGetOrThrow(scanner_adaptor->Next());
  if (record_batch == nullptr) {
    return nullptr;  // stream ended
  }
  std::shared_ptr<arrow::Schema> schema = record_batch->schema();
  jobjectArray field_array =
      env->NewObjectArray(schema->num_fields(), record_batch_handle_field_class, nullptr);

  std::vector<std::shared_ptr<arrow::Buffer>> buffers;
  for (int i = 0; i < schema->num_fields(); ++i) {
    auto column = record_batch->column(i);
    auto dataArray = column->data();
    jobject field = env->NewObject(record_batch_handle_field_class,
                                   record_batch_handle_field_constructor,
                                   column->length(), column->null_count());
    env->SetObjectArrayElement(field_array, i, field);

    for (auto& buffer : dataArray->buffers) {
      buffers.push_back(buffer);
    }
  }

  jobjectArray buffer_array =
      env->NewObjectArray(buffers.size(), record_batch_handle_buffer_class, nullptr);

  for (size_t j = 0; j < buffers.size(); ++j) {
    auto buffer = buffers[j];
    uint8_t* data = nullptr;
    int64_t size = 0;
    int64_t capacity = 0;
    if (buffer != nullptr) {
      data = (uint8_t*)buffer->data();
      size = buffer->size();
      capacity = buffer->capacity();
    }
    jobject buffer_handle = env->NewObject(record_batch_handle_buffer_class,
                                           record_batch_handle_buffer_constructor,
                                           CreateNativeRef(buffer), data, size, capacity);
    env->SetObjectArrayElement(buffer_array, j, buffer_handle);
  }

  jobject ret = env->NewObject(record_batch_handle_class, record_batch_handle_constructor,
                               record_batch->num_rows(), field_array, buffer_array);
  return ret;
  JNI_METHOD_END(nullptr)
}

/*
 * Class:     org_apache_arrow_dataset_jni_JniWrapper
 * Method:    releaseBuffer
 * Signature: (J)V
 */
JNIEXPORT void JNICALL Java_org_apache_arrow_dataset_jni_JniWrapper_releaseBuffer(
    JNIEnv* env, jobject, jlong id) {
  JNI_METHOD_START
  ReleaseNativeRef<arrow::Buffer>(id);
  JNI_METHOD_END()
}

/*
 * Class:     org_apache_arrow_dataset_file_JniWrapper
 * Method:    makeFileSystemDatasetFactory
 * Signature: (Ljava/lang/String;II)J
 */
JNIEXPORT jlong JNICALL
Java_org_apache_arrow_dataset_file_JniWrapper_makeFileSystemDatasetFactory(
    JNIEnv* env, jobject, jstring uri, jint file_format_id) {
  JNI_METHOD_START
  std::shared_ptr<arrow::dataset::FileFormat> file_format =
      JniGetOrThrow(GetFileFormat(file_format_id));
  arrow::dataset::FileSystemFactoryOptions options;
  std::shared_ptr<arrow::dataset::DatasetFactory> d =
      JniGetOrThrow(arrow::dataset::FileSystemDatasetFactory::Make(
          JStringToCString(env, uri), file_format, options));
  return CreateNativeRef(d);
  JNI_METHOD_END(-1L)
}
