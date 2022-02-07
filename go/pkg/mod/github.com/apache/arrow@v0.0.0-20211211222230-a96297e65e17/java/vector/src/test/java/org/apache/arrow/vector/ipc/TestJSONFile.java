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

package org.apache.arrow.vector.ipc;

import static org.junit.Assert.assertEquals;

import java.io.File;
import java.io.IOException;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.UInt1Vector;
import org.apache.arrow.vector.UInt4Vector;
import org.apache.arrow.vector.UInt8Vector;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.complex.StructVector;
import org.apache.arrow.vector.complex.impl.ComplexWriterImpl;
import org.apache.arrow.vector.complex.writer.BaseWriter;
import org.apache.arrow.vector.dictionary.DictionaryProvider;
import org.apache.arrow.vector.dictionary.DictionaryProvider.MapDictionaryProvider;
import org.apache.arrow.vector.types.pojo.Schema;
import org.apache.arrow.vector.util.Validator;
import org.junit.Assert;
import org.junit.Test;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class TestJSONFile extends BaseFileTest {
  private static final Logger LOGGER = LoggerFactory.getLogger(TestJSONFile.class);

  @Test
  public void testNoBatches() throws IOException {
    File file = new File("target/no_batches.json");

    try (BufferAllocator originalVectorAllocator =
             allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
         StructVector parent = StructVector.empty("parent", originalVectorAllocator)) {
      BaseWriter.ComplexWriter writer = new ComplexWriterImpl("root", parent);
      BaseWriter.StructWriter rootWriter = writer.rootAsStruct();
      rootWriter.integer("int");
      rootWriter.uInt1("uint1");
      rootWriter.bigInt("bigInt");
      rootWriter.float4("float");
      JsonFileWriter jsonWriter = new JsonFileWriter(file, JsonFileWriter.config().pretty(true));
      jsonWriter.start(new VectorSchemaRoot(parent.getChild("root")).getSchema(), null);
      jsonWriter.close();
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);
    }
  }

  @Test
  public void testWriteRead() throws IOException {
    File file = new File("target/mytest.json");
    int count = COUNT;

    // write
    try (BufferAllocator originalVectorAllocator =
           allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
         StructVector parent = StructVector.empty("parent", originalVectorAllocator)) {
      writeData(count, parent);
      writeJSON(file, new VectorSchemaRoot(parent.getChild("root")), null);
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateContent(count, root);
      }
    }
  }

  @Test
  public void testWriteReadComplexJSON() throws IOException {
    File file = new File("target/mytest_complex.json");
    int count = COUNT;

    // write
    try (
        BufferAllocator originalVectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        StructVector parent = StructVector.empty("parent", originalVectorAllocator)) {
      writeComplexData(count, parent);
      writeJSON(file, new VectorSchemaRoot(parent.getChild("root")), null);
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator);
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateComplexContent(count, root);
      }
    }
  }

  @Test
  public void testWriteComplexJSON() throws IOException {
    File file = new File("target/mytest_write_complex.json");
    int count = COUNT;
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        StructVector parent = StructVector.empty("parent", vectorAllocator)) {
      writeComplexData(count, parent);
      VectorSchemaRoot root = new VectorSchemaRoot(parent.getChild("root"));
      validateComplexContent(root.getRowCount(), root);
      writeJSON(file, root, null);
    }
  }

  public void writeJSON(File file, VectorSchemaRoot root, DictionaryProvider provider) throws IOException {
    JsonFileWriter writer = new JsonFileWriter(file, JsonFileWriter.config().pretty(true));
    writer.start(root.getSchema(), provider);
    writer.write(root);
    writer.close();
  }


  @Test
  public void testWriteReadUnionJSON() throws IOException {
    File file = new File("target/mytest_write_union.json");
    int count = COUNT;
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        StructVector parent = StructVector.empty("parent", vectorAllocator)) {
      writeUnionData(count, parent);
      printVectors(parent.getChildrenFromFields());

      try (VectorSchemaRoot root = new VectorSchemaRoot(parent.getChild("root"))) {
        validateUnionData(count, root);
        writeJSON(file, root, null);

        // read
        try (BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE)) {
          JsonFileReader reader = new JsonFileReader(file, readerAllocator);

          Schema schema = reader.start();
          LOGGER.debug("reading schema: " + schema);

          try (VectorSchemaRoot rootFromJson = reader.read();) {
            validateUnionData(count, rootFromJson);
            Validator.compareVectorSchemaRoot(root, rootFromJson);
          }
        }
      }
    }
  }

  @Test
  public void testWriteReadDateTimeJSON() throws IOException {
    File file = new File("target/mytest_datetime.json");
    int count = COUNT;

    // write
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        StructVector parent = StructVector.empty("parent", vectorAllocator)) {

      writeDateTimeData(count, parent);

      printVectors(parent.getChildrenFromFields());

      VectorSchemaRoot root = new VectorSchemaRoot(parent.getChild("root"));
      validateDateTimeContent(count, root);

      writeJSON(file, new VectorSchemaRoot(parent.getChild("root")), null);
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateDateTimeContent(count, root);
      }
    }
  }

  @Test
  public void testWriteReadDictionaryJSON() throws IOException {
    File file = new File("target/mytest_dictionary.json");

    // write
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE)
    ) {
      MapDictionaryProvider provider = new MapDictionaryProvider();

      try (VectorSchemaRoot root = writeFlatDictionaryData(vectorAllocator, provider)) {
        printVectors(root.getFieldVectors());
        validateFlatDictionary(root, provider);
        writeJSON(file, root, provider);
      }

      // Need to close dictionary vectors
      for (long id : provider.getDictionaryIds()) {
        provider.lookup(id).getVector().close();
      }
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateFlatDictionary(root, reader);
      }
    }
  }

  @Test
  public void testWriteReadNestedDictionaryJSON() throws IOException {
    File file = new File("target/mytest_dict_nested.json");

    // data being written:
    // [['foo', 'bar'], ['foo'], ['bar']] -> [[0, 1], [0], [1]]

    // write
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE)
    ) {
      MapDictionaryProvider provider = new MapDictionaryProvider();

      try (VectorSchemaRoot root = writeNestedDictionaryData(vectorAllocator, provider)) {
        printVectors(root.getFieldVectors());
        validateNestedDictionary(root, provider);
        writeJSON(file, root, provider);
      }

      // Need to close dictionary vectors
      for (long id : provider.getDictionaryIds()) {
        provider.lookup(id).getVector().close();
      }
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateNestedDictionary(root, reader);
      }
    }
  }

  @Test
  public void testWriteReadDecimalJSON() throws IOException {
    File file = new File("target/mytest_decimal.json");

    // write
    try (BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        VectorSchemaRoot root = writeDecimalData(vectorAllocator)) {
      printVectors(root.getFieldVectors());
      validateDecimalData(root);
      writeJSON(file, root, null);
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateDecimalData(root);
      }
    }
  }

  @Test
  public void testSetStructLength() throws IOException {
    File file = new File("../../docs/source/format/integration_json_examples/struct.json");
    if (!file.exists()) {
      file = new File("../docs/source/format/integration_json_examples/struct.json");
    }
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        FieldVector vector = root.getVector("struct_nullable");
        Assert.assertEquals(7, vector.getValueCount());
      }
    }
  }

  @Test
  public void testWriteReadVarBinJSON() throws IOException {
    File file = new File("target/mytest_varbin.json");
    int count = COUNT;

    // write
    try (
        BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        StructVector parent = StructVector.empty("parent", vectorAllocator)) {
      writeVarBinaryData(count, parent);
      VectorSchemaRoot root = new VectorSchemaRoot(parent.getChild("root"));
      validateVarBinary(count, root);
      writeJSON(file, new VectorSchemaRoot(parent.getChild("root")), null);
    }

    // read
    try (BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateVarBinary(count, root);
      }
    }
  }

  @Test
  public void testWriteReadMapJSON() throws IOException {
    File file = new File("target/mytest_map.json");

    // write
    try (BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        VectorSchemaRoot root = writeMapData(vectorAllocator)) {
      printVectors(root.getFieldVectors());
      validateMapData(root);
      writeJSON(file, root, null);
    }

    // read
    try (BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)) {
      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateMapData(root);
      }
    }
  }

  @Test
  public void testWriteReadNullJSON() throws IOException {
    File file = new File("target/mytest_null.json");
    int valueCount = 10;

    // write
    try (BufferAllocator vectorAllocator = allocator.newChildAllocator("original vectors", 0, Integer.MAX_VALUE);
        VectorSchemaRoot root = writeNullData(valueCount)) {
      printVectors(root.getFieldVectors());
      validateNullData(root, valueCount);
      writeJSON(file, root, null);
    }

    // read
    try (
        BufferAllocator readerAllocator = allocator.newChildAllocator("reader", 0, Integer.MAX_VALUE);
        JsonFileReader reader = new JsonFileReader(file, readerAllocator)
    ) {

      Schema schema = reader.start();
      LOGGER.debug("reading schema: " + schema);

      // initialize vectors
      try (VectorSchemaRoot root = reader.read();) {
        validateNullData(root, valueCount);
      }
    }
  }

  @Test
  public void testNoOverFlowWithUINT() {
    try (final UInt8Vector uInt8Vector = new UInt8Vector("uint8", allocator);
        final UInt4Vector uInt4Vector = new UInt4Vector("uint4", allocator);
        final UInt1Vector uInt1Vector = new UInt1Vector("uint1", allocator)) {

      long[] longValues = new long[]{Long.MIN_VALUE, Long.MAX_VALUE, -1L};
      uInt8Vector.allocateNew(3);
      uInt8Vector.setValueCount(3);
      for (int i = 0; i < longValues.length; i++) {
        uInt8Vector.set(i, longValues[i]);
        long readValue = uInt8Vector.getObjectNoOverflow(i).longValue();
        assertEquals(readValue, longValues[i]);
      }

      int[] intValues = new int[]{Integer.MIN_VALUE, Integer.MAX_VALUE, -1};
      uInt4Vector.allocateNew(3);
      uInt4Vector.setValueCount(3);
      for (int i = 0; i < intValues.length; i++) {
        uInt4Vector.set(i, intValues[i]);
        int actualValue = (int) UInt4Vector.getNoOverflow(uInt4Vector.getDataBuffer(), i);
        assertEquals(intValues[i], actualValue);
      }

      byte[] byteValues = new byte[]{Byte.MIN_VALUE, Byte.MAX_VALUE, -1};
      uInt1Vector.allocateNew(3);
      uInt1Vector.setValueCount(3);
      for (int i = 0; i < byteValues.length; i++) {
        uInt1Vector.set(i, byteValues[i]);
        byte actualValue = (byte) UInt1Vector.getNoOverflow(uInt1Vector.getDataBuffer(), i);
        assertEquals(byteValues[i], actualValue);
      }
    }
  }
}
