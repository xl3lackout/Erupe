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

import static org.junit.Assert.assertEquals;

import java.nio.ByteOrder;

import org.junit.Test;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.NettyArrowBuf;

public class TestEndianness {

  @Test
  public void testNativeEndian() {
    final BufferAllocator a = new RootAllocator(10000);
    final ByteBuf b = NettyArrowBuf.unwrapBuffer(a.buffer(4));
    b.setInt(0, 35);
    if (ByteOrder.nativeOrder() == ByteOrder.LITTLE_ENDIAN) {
      assertEquals(b.getByte(0), 35);
      assertEquals(b.getByte(1), 0);
      assertEquals(b.getByte(2), 0);
      assertEquals(b.getByte(3), 0);
    } else {
      assertEquals(b.getByte(0), 0);
      assertEquals(b.getByte(1), 0);
      assertEquals(b.getByte(2), 0);
      assertEquals(b.getByte(3), 35);
    }
    b.release();
    a.close();
  }

}
