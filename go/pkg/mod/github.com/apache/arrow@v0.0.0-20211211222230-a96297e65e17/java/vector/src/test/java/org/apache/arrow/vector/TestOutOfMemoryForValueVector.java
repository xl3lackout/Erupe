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

package org.apache.arrow.vector;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.memory.OutOfMemoryException;
import org.apache.arrow.memory.RootAllocator;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

/**
 * This class tests cases where we expect to receive {@link OutOfMemoryException}.
 */
public class TestOutOfMemoryForValueVector {

  private static final String EMPTY_SCHEMA_PATH = "";

  private BufferAllocator allocator;

  @Before
  public void init() {
    allocator = new RootAllocator(200); // Start with low memory limit
  }

  @Test(expected = OutOfMemoryException.class)
  public void variableWidthVectorAllocateNew() {
    try (VarCharVector vector = new VarCharVector(EMPTY_SCHEMA_PATH, allocator)) {
      vector.allocateNew();
    }
  }

  @Test(expected = OutOfMemoryException.class)
  public void variableWidthVectorAllocateNewCustom() {
    try (VarCharVector vector = new VarCharVector(EMPTY_SCHEMA_PATH, allocator)) {
      vector.allocateNew(2342, 234);
    }
  }

  @Test(expected = OutOfMemoryException.class)
  public void fixedWidthVectorAllocateNew() {
    try (IntVector vector = new IntVector(EMPTY_SCHEMA_PATH, allocator)) {
      vector.allocateNew();
    }
  }

  @Test(expected = OutOfMemoryException.class)
  public void fixedWidthVectorAllocateNewCustom() {
    try (IntVector vector = new IntVector(EMPTY_SCHEMA_PATH, allocator)) {
      vector.allocateNew(2342);
    }
  }

  @After
  public void terminate() {
    allocator.close();
  }
}
