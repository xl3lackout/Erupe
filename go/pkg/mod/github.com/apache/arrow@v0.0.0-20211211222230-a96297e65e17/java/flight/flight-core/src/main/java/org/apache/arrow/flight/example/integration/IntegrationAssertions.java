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

package org.apache.arrow.flight.example.integration;

import java.util.Objects;

/**
 * Utility methods to implement integration tests without using JUnit assertions.
 */
final class IntegrationAssertions {

  /**
   * Assert that the given code throws the given exception or subclass thereof.
   *
   * @param clazz The exception type.
   * @param body The code to run.
   * @param <T> The exception type.
   * @return The thrown exception.
   */
  @SuppressWarnings("unchecked")
  static <T extends Throwable> T assertThrows(Class<T> clazz, AssertThrows body) {
    try {
      body.run();
    } catch (Throwable t) {
      if (clazz.isInstance(t)) {
        return (T) t;
      }
      throw new AssertionError("Expected exception of class " + clazz + " but got " + t.getClass(), t);
    }
    throw new AssertionError("Expected exception of class " + clazz + " but did not throw.");
  }

  /**
   * Assert that the two (non-array) objects are equal.
   */
  static void assertEquals(Object expected, Object actual) {
    if (!Objects.equals(expected, actual)) {
      throw new AssertionError("Expected:\n" + expected + "\nbut got:\n" + actual);
    }
  }

  /**
   * Assert that the value is false, using the given message as an error otherwise.
   */
  static void assertFalse(String message, boolean value) {
    if (value) {
      throw new AssertionError("Expected false: " + message);
    }
  }

  /**
   * An interface used with {@link #assertThrows(Class, AssertThrows)}.
   */
  @FunctionalInterface
  interface AssertThrows {

    void run() throws Throwable;
  }
}
