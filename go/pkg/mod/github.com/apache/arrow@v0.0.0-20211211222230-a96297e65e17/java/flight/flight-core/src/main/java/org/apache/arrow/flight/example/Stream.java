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

package org.apache.arrow.flight.example;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.UUID;
import java.util.function.Consumer;

import org.apache.arrow.flight.FlightProducer.ServerStreamListener;
import org.apache.arrow.memory.ArrowBuf;
import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.AutoCloseables;
import org.apache.arrow.vector.VectorLoader;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.dictionary.DictionaryProvider;
import org.apache.arrow.vector.ipc.message.ArrowRecordBatch;
import org.apache.arrow.vector.types.pojo.Schema;

import com.google.common.base.Throwables;
import com.google.common.collect.ImmutableList;

/**
 * A collection of Arrow record batches.
 */
public class Stream implements AutoCloseable, Iterable<ArrowRecordBatch> {

  private final String uuid = UUID.randomUUID().toString();
  private final DictionaryProvider dictionaryProvider;
  private final List<ArrowRecordBatch> batches;
  private final Schema schema;
  private final long recordCount;

  /**
   * Create a new instance.
   *
   * @param schema The schema for the record batches.
   * @param batches The data associated with the stream.
   * @param recordCount The total record count across all batches.
   */
  public Stream(
      final Schema schema,
      final DictionaryProvider dictionaryProvider,
      List<ArrowRecordBatch> batches,
      long recordCount) {
    this.schema = schema;
    this.dictionaryProvider = dictionaryProvider;
    this.batches = ImmutableList.copyOf(batches);
    this.recordCount = recordCount;
  }

  public Schema getSchema() {
    return schema;
  }

  @Override
  public Iterator<ArrowRecordBatch> iterator() {
    return batches.iterator();
  }

  public long getRecordCount() {
    return recordCount;
  }

  public String getUuid() {
    return uuid;
  }

  /**
   * Sends that data from this object to the given listener.
   */
  public void sendTo(BufferAllocator allocator, ServerStreamListener listener) {
    try (VectorSchemaRoot root = VectorSchemaRoot.create(schema, allocator)) {
      listener.start(root, dictionaryProvider);
      final VectorLoader loader = new VectorLoader(root);
      int counter = 0;
      for (ArrowRecordBatch batch : batches) {
        final byte[] rawMetadata = Integer.toString(counter).getBytes(StandardCharsets.UTF_8);
        final ArrowBuf metadata = allocator.buffer(rawMetadata.length);
        metadata.writeBytes(rawMetadata);
        loader.load(batch);
        // Transfers ownership of the buffer - do not free buffer ourselves
        listener.putNext(metadata);
        counter++;
      }
      listener.completed();
    } catch (Exception ex) {
      listener.error(ex);
    }
  }

  /**
   * Throws an IllegalStateException if the given ticket doesn't correspond to this stream.
   */
  public void verify(ExampleTicket ticket) {
    if (!uuid.equals(ticket.getUuid())) {
      throw new IllegalStateException("Ticket doesn't match.");
    }
  }

  @Override
  public void close() throws Exception {
    AutoCloseables.close(batches);
  }

  /**
   * Provides the functionality to create a new stream by adding batches serially.
   */
  public static class StreamCreator {

    private final Schema schema;
    private final BufferAllocator allocator;
    private final List<ArrowRecordBatch> batches = new ArrayList<>();
    private final Consumer<Stream> committer;
    private long recordCount = 0;
    private DictionaryProvider dictionaryProvider;

    /**
     * Creates a new instance.
     *
     * @param schema The schema for batches in the stream.
     * @param dictionaryProvider The dictionary provider for the stream.
     * @param allocator  The allocator used to copy data permanently into the stream.
     * @param committer A callback for when the stream is ready to be finalized (no more batches).
     */
    public StreamCreator(Schema schema, DictionaryProvider dictionaryProvider,
        BufferAllocator allocator, Consumer<Stream> committer) {
      this.allocator = allocator;
      this.committer = committer;
      this.schema = schema;
      this.dictionaryProvider = dictionaryProvider;
    }

    /**
     * Abandon creation of the stream.
     */
    public void drop() {
      try {
        AutoCloseables.close(batches);
      } catch (Exception ex) {
        throw Throwables.propagate(ex);
      }
    }

    public void add(ArrowRecordBatch batch) {
      batches.add(batch.cloneWithTransfer(allocator));
      recordCount += batch.getLength();
    }

    /**
     * Complete building the stream (no more batches can be added).
     */
    public void complete() {
      Stream stream = new Stream(schema, dictionaryProvider, batches, recordCount);
      committer.accept(stream);
    }

  }

}
