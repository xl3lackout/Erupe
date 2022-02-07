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

import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;

import org.apache.arrow.flight.impl.Flight;

import com.google.common.collect.ImmutableList;

/**
 * POJO to convert to/from the underlying protobuf FlightEndpoint.
 */
public class FlightEndpoint {
  private List<Location> locations;
  private Ticket ticket;

  /**
   * Constructs a new instance.
   *
   * @param ticket A ticket that describe the key of a data stream.
   * @param locations  The possible locations the stream can be retrieved from.
   */
  public FlightEndpoint(Ticket ticket, Location... locations) {
    super();
    Objects.requireNonNull(ticket);
    this.locations = ImmutableList.copyOf(locations);
    this.ticket = ticket;
  }

  /**
   * Constructs from the protocol buffer representation.
   */
  FlightEndpoint(Flight.FlightEndpoint flt) throws URISyntaxException {
    locations = new ArrayList<>();
    for (final Flight.Location location : flt.getLocationList()) {
      locations.add(new Location(location.getUri()));
    }
    ticket = new Ticket(flt.getTicket());
  }

  public List<Location> getLocations() {
    return locations;
  }

  public Ticket getTicket() {
    return ticket;
  }

  /**
   * Converts to the protocol buffer representation.
   */
  Flight.FlightEndpoint toProtocol() {
    Flight.FlightEndpoint.Builder b = Flight.FlightEndpoint.newBuilder()
        .setTicket(ticket.toProtocol());

    for (Location l : locations) {
      b.addLocation(l.toProtocol());
    }
    return b.build();
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (o == null || getClass() != o.getClass()) {
      return false;
    }
    FlightEndpoint that = (FlightEndpoint) o;
    return locations.equals(that.locations) &&
        ticket.equals(that.ticket);
  }

  @Override
  public int hashCode() {
    return Objects.hash(locations, ticket);
  }

  @Override
  public String toString() {
    return "FlightEndpoint{" +
        "locations=" + locations +
        ", ticket=" + ticket +
        '}';
  }
}
