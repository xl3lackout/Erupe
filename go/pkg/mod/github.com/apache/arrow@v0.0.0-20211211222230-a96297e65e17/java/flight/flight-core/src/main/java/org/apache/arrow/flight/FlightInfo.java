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

package org.apache.arrow.flight;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URISyntaxException;
import java.nio.ByteBuffer;
import java.nio.channels.Channels;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

import org.apache.arrow.flight.impl.Flight;
import org.apache.arrow.vector.ipc.ReadChannel;
import org.apache.arrow.vector.ipc.WriteChannel;
import org.apache.arrow.vector.ipc.message.IpcOption;
import org.apache.arrow.vector.ipc.message.MessageSerializer;
import org.apache.arrow.vector.types.pojo.Schema;
import org.apache.arrow.vector.validate.MetadataV4UnionChecker;

import com.fasterxml.jackson.databind.util.ByteBufferBackedInputStream;
import com.google.common.collect.ImmutableList;
import com.google.protobuf.ByteString;

/**
 * A POJO representation of a FlightInfo, metadata associated with a set of data records.
 */
public class FlightInfo {
  private final Schema schema;
  private final FlightDescriptor descriptor;
  private final List<FlightEndpoint> endpoints;
  private final long bytes;
  private final long records;
  private final IpcOption option;

  /**
   * Constructs a new instance.
   *
   * @param schema The schema of the Flight
   * @param descriptor An identifier for the Flight.
   * @param endpoints A list of endpoints that have the flight available.
   * @param bytes The number of bytes in the flight
   * @param records The number of records in the flight.
   */
  public FlightInfo(Schema schema, FlightDescriptor descriptor, List<FlightEndpoint> endpoints, long bytes,
      long records) {
    this(schema, descriptor, endpoints, bytes, records, IpcOption.DEFAULT);
  }

  /**
   * Constructs a new instance.
   *
   * @param schema The schema of the Flight
   * @param descriptor An identifier for the Flight.
   * @param endpoints A list of endpoints that have the flight available.
   * @param bytes The number of bytes in the flight
   * @param records The number of records in the flight.
   * @param option IPC write options.
   */
  public FlightInfo(Schema schema, FlightDescriptor descriptor, List<FlightEndpoint> endpoints, long bytes,
                    long records, IpcOption option) {
    Objects.requireNonNull(schema);
    Objects.requireNonNull(descriptor);
    Objects.requireNonNull(endpoints);
    MetadataV4UnionChecker.checkForUnion(schema.getFields().iterator(), option.metadataVersion);
    this.schema = schema;
    this.descriptor = descriptor;
    this.endpoints = endpoints;
    this.bytes = bytes;
    this.records = records;
    this.option = option;
  }

  /**
   * Constructs from the protocol buffer representation.
   */
  FlightInfo(Flight.FlightInfo pbFlightInfo) throws URISyntaxException {
    try {
      final ByteBuffer schemaBuf = pbFlightInfo.getSchema().asReadOnlyByteBuffer();
      schema = pbFlightInfo.getSchema().size() > 0 ?
          MessageSerializer.deserializeSchema(
              new ReadChannel(Channels.newChannel(new ByteBufferBackedInputStream(schemaBuf))))
          : new Schema(ImmutableList.of());
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
    descriptor = new FlightDescriptor(pbFlightInfo.getFlightDescriptor());
    endpoints = new ArrayList<>();
    for (final Flight.FlightEndpoint endpoint : pbFlightInfo.getEndpointList()) {
      endpoints.add(new FlightEndpoint(endpoint));
    }
    bytes = pbFlightInfo.getTotalBytes();
    records = pbFlightInfo.getTotalRecords();
    option = IpcOption.DEFAULT;
  }

  public Schema getSchema() {
    return schema;
  }

  public long getBytes() {
    return bytes;
  }

  public long getRecords() {
    return records;
  }

  public FlightDescriptor getDescriptor() {
    return descriptor;
  }

  public List<FlightEndpoint> getEndpoints() {
    return endpoints;
  }

  /**
   * Converts to the protocol buffer representation.
   */
  Flight.FlightInfo toProtocol() {
    // Encode schema in a Message payload
    ByteArrayOutputStream baos = new ByteArrayOutputStream();
    try {
      MessageSerializer.serialize(new WriteChannel(Channels.newChannel(baos)), schema, option);
    } catch (IOException e) {
      throw new RuntimeException(e);
    }
    return Flight.FlightInfo.newBuilder()
        .addAllEndpoint(endpoints.stream().map(t -> t.toProtocol()).collect(Collectors.toList()))
        .setSchema(ByteString.copyFrom(baos.toByteArray()))
        .setFlightDescriptor(descriptor.toProtocol())
        .setTotalBytes(FlightInfo.this.bytes)
        .setTotalRecords(records)
        .build();
  }

  /**
   * Get the serialized form of this protocol message.
   *
   * <p>Intended to help interoperability by allowing non-Flight services to still return Flight types.
   */
  public ByteBuffer serialize() {
    return ByteBuffer.wrap(toProtocol().toByteArray());
  }

  /**
   * Parse the serialized form of this protocol message.
   *
   * <p>Intended to help interoperability by allowing Flight clients to obtain stream info from non-Flight services.
   *
   * @param serialized The serialized form of the FlightInfo, as returned by {@link #serialize()}.
   * @return The deserialized FlightInfo.
   * @throws IOException if the serialized form is invalid.
   * @throws URISyntaxException if the serialized form contains an unsupported URI format.
   */
  public static FlightInfo deserialize(ByteBuffer serialized) throws IOException, URISyntaxException {
    return new FlightInfo(Flight.FlightInfo.parseFrom(serialized));
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    FlightInfo that = (FlightInfo) o;
    return bytes == that.bytes &&
        records == that.records &&
        schema.equals(that.schema) &&
        descriptor.equals(that.descriptor) &&
        endpoints.equals(that.endpoints);
  }

  @Override
  public int hashCode() {
    return Objects.hash(schema, descriptor, endpoints, bytes, records);
  }

  @Override
  public String toString() {
    return "FlightInfo{" +
        "schema=" + schema +
        ", descriptor=" + descriptor +
        ", endpoints=" + endpoints +
        ", bytes=" + bytes +
        ", records=" + records +
        '}';
  }
}
