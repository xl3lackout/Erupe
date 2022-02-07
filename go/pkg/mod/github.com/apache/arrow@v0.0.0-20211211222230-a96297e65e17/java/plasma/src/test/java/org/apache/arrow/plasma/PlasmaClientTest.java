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

package org.apache.arrow.plasma;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

import org.apache.arrow.plasma.exceptions.DuplicateObjectException;
import org.apache.arrow.plasma.exceptions.PlasmaClientException;
import org.apache.arrow.plasma.exceptions.PlasmaOutOfMemoryException;
import org.junit.Assert;

public class PlasmaClientTest {

  private String storeSuffix = "/tmp/store";

  private Process storeProcess;

  private int storePort;

  private ObjectStoreLink pLink;


  public PlasmaClientTest() throws Exception {
    try {
      String plasmaStorePath = System.getenv("PLASMA_STORE");
      if (plasmaStorePath == null) {
        throw new Exception("Please set plasma store path in env PLASMA_STORE");
      }

      this.startObjectStore(plasmaStorePath);
      System.loadLibrary("plasma_java");
      pLink = new PlasmaClient(this.getStoreAddress(), "", 0);
    } catch (Throwable t) {
      cleanup();
      throw t;
    }

  }

  private Process startProcess(String[] cmd) {
    ProcessBuilder builder;
    List<String> newCmd = Arrays.stream(cmd).filter(s -> s.length() > 0).collect(Collectors.toList());
    builder = new ProcessBuilder(newCmd);
    builder.inheritIO();
    Process p = null;
    try {
      p = builder.start();
    } catch (IOException e) {
      e.printStackTrace();
      return null;
    }
    System.out.println("Start process " + p.hashCode() + " OK, cmd = " + Arrays.toString(cmd).replace(',', ' '));
    return p;
  }

  private void startObjectStore(String plasmaStorePath) {
    int occupiedMemoryMB = 10;
    long memoryBytes = occupiedMemoryMB * 1000000;
    int numRetries = 10;
    Process p = null;
    while (numRetries-- > 0) {
      int currentPort = java.util.concurrent.ThreadLocalRandom.current().nextInt(0, 100000);
      String name = storeSuffix + currentPort;
      String cmd = plasmaStorePath + " -s " + name + " -m " + memoryBytes;

      p = startProcess(cmd.split(" "));

      if (p != null && p.isAlive()) {
        try {
          TimeUnit.MILLISECONDS.sleep(100);
        } catch (InterruptedException e) {
          e.printStackTrace();
        }
        if (p.isAlive()) {
          storePort = currentPort;
          break;
        }
      }
    }


    if (p == null || !p.isAlive()) {
      throw new RuntimeException("Start object store failed ...");
    } else {
      storeProcess = p;
      System.out.println("Start object store success");
    }
  }

  private void cleanup() {
    if (storeProcess != null && killProcess(storeProcess)) {
      System.out.println("Kill plasma store process forcibly");
    }
  }

  private static boolean killProcess(Process p) {
    if (p.isAlive()) {
      p.destroyForcibly();
      return true;
    } else {
      return false;
    }
  }

  public void doTest() {
    System.out.println("Start test.");
    int timeoutMs = 3000;
    byte[] id1 = new byte[20];
    Arrays.fill(id1, (byte) 1);
    byte[] value1 = new byte[20];
    Arrays.fill(value1, (byte) 11);
    pLink.put(id1, value1, null);

    byte[] id2 = new byte[20];
    Arrays.fill(id2, (byte) 2);
    byte[] value2 = new byte[20];
    Arrays.fill(value2, (byte) 12);
    pLink.put(id2, value2, null);
    System.out.println("Plasma java client put test success.");
    byte[] getValue1 = pLink.get(id1, timeoutMs, false);
    assert Arrays.equals(value1, getValue1);

    byte[] getValue2 = pLink.get(id2, timeoutMs, false);
    assert Arrays.equals(value2, getValue2);
    System.out.println("Plasma java client get single object test success.");
    byte[][] ids = {id1, id2};
    List<byte[]> values = pLink.get(ids, timeoutMs, false);
    assert Arrays.equals(values.get(0), value1);
    assert Arrays.equals(values.get(1), value2);
    System.out.println("Plasma java client get multi-object test success.");
    try {
      pLink.put(id1, value1, null);
      Assert.fail("Fail to throw DuplicateObjectException when put an object into plasma store twice.");
    } catch (DuplicateObjectException e) {
      System.out.println("Plasma java client put same object twice exception test success.");
    }
    byte[] id1Hash = pLink.hash(id1);
    assert id1Hash != null;
    System.out.println("Plasma java client hash test success.");
    
    boolean exist = pLink.contains(id2);
    assert exist;
    byte[] id3 = new byte[20];
    Arrays.fill(id3, (byte) 3);
    boolean notExist = pLink.contains(id3);
    assert !notExist;
    System.out.println("Plasma java client contains test success.");

    byte[] id4 = new byte[20];
    Arrays.fill(id4, (byte) 4);
    byte[] value4 = new byte[20];
    byte[] meta4 = "META4".getBytes();
    Arrays.fill(value4, (byte) 14);
    pLink.put(id4, value4, meta4);

    List<byte[]> existIds = Arrays.asList(id1, id2, id3, id4);
    List<byte[]> listIds = pLink.list();
    assert listIds.size() == 4;
    for (byte[] existId : existIds) {
      boolean found = false;
      for (byte[] listId : listIds) {
        if (Arrays.equals(listId, existId)) {
          found = true;
        }
      }
      assert found;
    }
    System.out.println("Plasma java client list test success.");

    byte[] id5 = new byte[20];
    Arrays.fill(id5, (byte) 5);
    byte[] value5 = new byte[20];
    byte[] meta5 = "META5".getBytes();
    Arrays.fill(value5, (byte) 15);
    pLink.put(id5, value5, meta5);

    byte[] getMeta4 = pLink.get(id4, timeoutMs, true);
    assert Arrays.equals(meta4, getMeta4);
    byte[] getValue4 = pLink.get(id4, timeoutMs, false);
    assert Arrays.equals(value4, getValue4);
    byte[][] ids4 = new byte[1][];
    ids4[0] = id4;
    ObjectStoreLink.ObjectStoreData fullData4 = pLink.get(ids4, timeoutMs).get(0);
    assert Arrays.equals(meta4, fullData4.metadata);
    assert Arrays.equals(value4, fullData4.data);

    byte[] getMeta5 = pLink.get(id5, timeoutMs, true);
    assert Arrays.equals(meta5, getMeta5);
    byte[] getValue5 = pLink.get(id5, timeoutMs, false);
    assert Arrays.equals(value5, getValue5);
    byte[][] ids5 = new byte[1][];
    ids5[0] = id5;
    ObjectStoreLink.ObjectStoreData fullData5 = pLink.get(ids5, timeoutMs).get(0);
    assert Arrays.equals(meta5, fullData5.metadata);
    assert Arrays.equals(value5, fullData5.data);
    System.out.println("Plasma java client metadata get test success.");
    
    byte[] id6 = getArrayFilledWithValue(20, (byte) 6);
    byte[] val6 = getArrayFilledWithValue(21, (byte) 6);
    pLink.put(id6, val6, null);
    assert pLink.contains(id6);
    pLink.delete(id6);
    assert !pLink.contains(id6);
    System.out.println("Plasma java client delete test success.");
    
    // Test calling shutdown while getting the object.
    Thread thread = new Thread(() -> {
      try {
        TimeUnit.SECONDS.sleep(1);
        cleanup();
      } catch (InterruptedException e) {
        throw new RuntimeException("Got InterruptedException when sleeping.", e);
      }
    });
    thread.start();

    try {
      byte[] idNone = new byte[20];
      Arrays.fill(idNone, (byte) 987);
      pLink.get(idNone, timeoutMs, false);
      Assert.fail("Fail to throw PlasmaClientException when get an object " +
                  "when object store shutdown.");
    } catch (PlasmaClientException e) {
      System.out.println(String.format("Expected PlasmaClientException: %s", e));
    }

    try {
      thread.join();
    } catch (Exception e) {
      System.out.println(String.format("Exception caught: %s", e));
    }
    System.out.println("All test success.");

  }

  public void doByteBufferTest() {
    System.out.println("Start ByteBuffer test.");
    PlasmaClient client = (PlasmaClient) pLink;
    byte[] id = new byte[20];
    Arrays.fill(id, (byte) 10);
    ByteBuffer buf = client.create(id, 100, null);
    assert buf.isDirect();
    for (int i = 0; i < 10; i++) {
      buf.putInt(i);
    }
    client.seal(id);
    client.release(id);
    // buf is not available now.
    assert client.contains(id);
    System.out.println("Plasma java client create test success.");

    ByteBuffer buf1 = client.getObjAsByteBuffer(id, -1, false);
    assert buf1.limit() == 100;
    for (int i = 0; i < 10; i++) {
      assert buf1.getInt() == i;
    }
    System.out.println("Plasma java client getObjAsByteBuffer test success");
    client.release(id);
  }

  public void doPlasmaOutOfMemoryExceptionTest() {
    System.out.println("Start PlasmaOutOfMemoryException test.");
    PlasmaClient client = (PlasmaClient) pLink;
    byte[] objectId = new byte[20];
    Arrays.fill(objectId, (byte) 1);
    try {
      ByteBuffer byteBuffer = client.create(objectId, 200000000, null);
      Assert.fail("Fail to create an object, The plasma store ran out of memory.");
    } catch (PlasmaOutOfMemoryException e) {
      System.out.println(String.format("Expected PlasmaOutOfMemoryException: %s", e));
      System.out.println("PlasmaOutOfMemoryException test success.");
    }
  }

  private byte[] getArrayFilledWithValue(int arrayLength, byte val) {
    byte[] arr = new byte[arrayLength];
    Arrays.fill(arr, val);
    return arr;
  }

  public String getStoreAddress() {
    return storeSuffix + storePort;
  }

  public static void main(String[] args) throws Exception {

    PlasmaClientTest plasmaClientTest = new PlasmaClientTest();
    plasmaClientTest.doPlasmaOutOfMemoryExceptionTest();
    plasmaClientTest.doByteBufferTest();
    plasmaClientTest.doTest();
  }

}
