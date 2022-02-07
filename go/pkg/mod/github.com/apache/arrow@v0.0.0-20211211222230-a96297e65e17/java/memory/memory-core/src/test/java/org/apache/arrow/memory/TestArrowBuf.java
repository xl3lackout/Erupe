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

package org.apache.arrow.memory;

import static org.junit.Assert.assertArrayEquals;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.Arrays;

import org.junit.AfterClass;
import org.junit.BeforeClass;
import org.junit.Test;

public class TestArrowBuf {

  private static final int MAX_ALLOCATION = 8 * 1024;
  private static RootAllocator allocator;

  @BeforeClass
  public static void beforeClass() {
    allocator = new RootAllocator(MAX_ALLOCATION);
  }

  /** Ensure the allocator is closed. */
  @AfterClass
  public static void afterClass() {
    if (allocator != null) {
      allocator.close();
    }
  }

  @Test(expected = IndexOutOfBoundsException.class)
  public void testSliceOutOfBoundsLength_RaisesIndexOutOfBoundsException() {
    try (BufferAllocator allocator = new RootAllocator(128);
         ArrowBuf buf = allocator.buffer(2)
    ) {
      assertEquals(2, buf.capacity());
      buf.slice(0, 3);
    }
  }

  @Test(expected = IndexOutOfBoundsException.class)
  public void testSliceOutOfBoundsIndexPlusLength_RaisesIndexOutOfBoundsException() {
    try (BufferAllocator allocator = new RootAllocator(128);
         ArrowBuf buf = allocator.buffer(2)
    ) {
      assertEquals(2, buf.capacity());
      buf.slice(1, 2);
    }
  }

  @Test(expected = IndexOutOfBoundsException.class)
  public void testSliceOutOfBoundsIndex_RaisesIndexOutOfBoundsException() {
    try (BufferAllocator allocator = new RootAllocator(128);
         ArrowBuf buf = allocator.buffer(2)
    ) {
      assertEquals(2, buf.capacity());
      buf.slice(3, 0);
    }
  }

  @Test
  public void testSliceWithinBoundsLength_ReturnsSlice() {
    try (BufferAllocator allocator = new RootAllocator(128);
         ArrowBuf buf = allocator.buffer(2)
    ) {
      assertEquals(2, buf.capacity());
      assertEquals(1, buf.slice(1, 1).capacity());
      assertEquals(2, buf.slice(0, 2).capacity());
    }
  }

  @Test
  public void testSetBytesSliced() {
    int arrLength = 64;
    byte[] expected = new byte[arrLength];
    for (int i = 0; i < expected.length; i++) {
      expected[i] = (byte) i;
    }
    ByteBuffer data = ByteBuffer.wrap(expected);
    try (ArrowBuf buf = allocator.buffer(expected.length)) {
      buf.setBytes(0, data, 0, data.capacity());

      byte[] actual = new byte[expected.length];
      buf.getBytes(0, actual);
      assertArrayEquals(expected, actual);
    }
  }

  @Test
  public void testSetBytesUnsliced() {
    int arrLength = 64;
    byte[] arr = new byte[arrLength];
    for (int i = 0; i < arr.length; i++) {
      arr[i] = (byte) i;
    }
    ByteBuffer data = ByteBuffer.wrap(arr);

    int from = 10;
    int to = arrLength;
    byte[] expected = Arrays.copyOfRange(arr, from, to);
    try (ArrowBuf buf = allocator.buffer(expected.length)) {
      buf.setBytes(0, data, from, to - from);

      byte[] actual = new byte[expected.length];
      buf.getBytes(0, actual);
      assertArrayEquals(expected, actual);
    }
  }

  /** ARROW-9221: guard against big-endian byte buffers. */
  @Test
  public void testSetBytesBigEndian() {
    final byte[] expected = new byte[64];
    for (int i = 0; i < expected.length; i++) {
      expected[i] = (byte) i;
    }
    // Only this code path is susceptible: others use unsafe or byte-by-byte copies, while this override copies longs.
    final ByteBuffer data = ByteBuffer.wrap(expected).asReadOnlyBuffer();
    assertFalse(data.hasArray());
    assertFalse(data.isDirect());
    assertEquals(ByteOrder.BIG_ENDIAN, data.order());
    try (ArrowBuf buf = allocator.buffer(expected.length)) {
      buf.setBytes(0, data);
      byte[] actual = new byte[expected.length];
      buf.getBytes(0, actual);
      assertArrayEquals(expected, actual);
    }
  }

}
