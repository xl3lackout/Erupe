/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.arrow.dataset.jni;

/**
 * JNI wrapper for Dataset API's native implementation.
 */
public class JniWrapper {

  private static final JniWrapper INSTANCE = new JniWrapper();

  public static JniWrapper get() {
    return INSTANCE;
  }

  private JniWrapper() {
    JniLoader.get().ensureLoaded();
  }

  /**
   * Release the DatasetFactory by destroying its reference held by JNI wrapper.
   *
   * @param datasetFactoryId the native pointer of the arrow::dataset::DatasetFactory instance.
   */
  public native void closeDatasetFactory(long datasetFactoryId);

  /**
   * Get a serialized schema from native instance of a DatasetFactory.
   *
   * @param datasetFactoryId the native pointer of the arrow::dataset::DatasetFactory instance.
   * @return the serialized schema
   * @see org.apache.arrow.vector.types.pojo.Schema
   */
  public native byte[] inspectSchema(long datasetFactoryId);

  /**
   * Create Dataset from a DatasetFactory and get the native pointer of the Dataset.
   *
   * @param datasetFactoryId the native pointer of the arrow::dataset::DatasetFactory instance.
   * @param schema the predefined schema of the resulting Dataset.
   * @return the native pointer of the arrow::dataset::Dataset instance.
   */
  public native long createDataset(long datasetFactoryId, byte[] schema);

  /**
   * Release the Dataset by destroying its reference held by JNI wrapper.
   *
   * @param datasetId the native pointer of the arrow::dataset::Dataset instance.
   */
  public native void closeDataset(long datasetId);

  /**
   * Create Scanner from a Dataset and get the native pointer of the Dataset.
   * @param datasetId the native pointer of the arrow::dataset::Dataset instance.
   * @param columns desired column names.
   *                Columns not in this list will not be emitted when performing scan operation. Null equals
   *                to "all columns".
   * @param batchSize batch size of scanned record batches.
   * @param memoryPool identifier of memory pool used in the native scanner.
   * @return the native pointer of the arrow::dataset::Scanner instance.
   */
  public native long createScanner(long datasetId, String[] columns, long batchSize, long memoryPool);

  /**
   * Get a serialized schema from native instance of a Scanner.
   *
   * @param scannerId the native pointer of the arrow::dataset::Scanner instance.
   * @return the serialized schema
   * @see org.apache.arrow.vector.types.pojo.Schema
   */
  public native byte[] getSchemaFromScanner(long scannerId);

  /**
   * Release the Scanner by destroying its reference held by JNI wrapper.
   * @param scannerId the native pointer of the arrow::dataset::Scanner instance.
   */
  public native void closeScanner(long scannerId);

  /**
   * Read next record batch from the specified scanner.
   * @param scannerId the native pointer of the arrow::dataset::Scanner instance.
   * @return an instance of {@link NativeRecordBatchHandle} describing the overall layout of the native record batch.
   */
  public native NativeRecordBatchHandle nextRecordBatch(long scannerId);

  /**
   * Release the Buffer by destroying its reference held by JNI wrapper.
   * @param bufferId the native pointer of the arrow::Buffer instance.
   */
  public native void releaseBuffer(long bufferId);

}
