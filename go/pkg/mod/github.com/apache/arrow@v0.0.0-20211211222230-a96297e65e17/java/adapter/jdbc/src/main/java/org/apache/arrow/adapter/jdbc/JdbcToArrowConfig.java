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

package org.apache.arrow.adapter.jdbc;

import static org.apache.arrow.vector.types.FloatingPointPrecision.DOUBLE;
import static org.apache.arrow.vector.types.FloatingPointPrecision.SINGLE;

import java.sql.Types;
import java.util.Calendar;
import java.util.Map;
import java.util.function.Function;

import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.util.Preconditions;
import org.apache.arrow.vector.types.DateUnit;
import org.apache.arrow.vector.types.TimeUnit;
import org.apache.arrow.vector.types.pojo.ArrowType;

/**
 * This class configures the JDBC-to-Arrow conversion process.
 * <p>
 * The allocator is used to construct the {@link org.apache.arrow.vector.VectorSchemaRoot},
 * and the calendar is used to define the time zone of any
 * {@link org.apache.arrow.vector.types.pojo.ArrowType.Timestamp}
 * fields that are created during the conversion.  Neither field may be <code>null</code>.
 * </p>
 * <p>
 * If the <code>includeMetadata</code> flag is set, the Arrow field metadata will contain information
 * from the corresponding {@link java.sql.ResultSetMetaData} that was used to create the
 * {@link org.apache.arrow.vector.types.pojo.FieldType} of the corresponding
 * {@link org.apache.arrow.vector.FieldVector}.
 * </p>
 * <p>
 * If there are any {@link java.sql.Types#ARRAY} fields in the {@link java.sql.ResultSet}, the corresponding
 * {@link JdbcFieldInfo} for the array's contents must be defined here.  Unfortunately, the sub-type
 * information cannot be retrieved from all JDBC implementations (H2 for example, returns
 * {@link java.sql.Types#NULL} for the array sub-type), so it must be configured here.  The column index
 * or name can be used to map to a {@link JdbcFieldInfo}, and that will be used for the conversion.
 * </p>
 */
public final class JdbcToArrowConfig {

  private final Calendar calendar;
  private final BufferAllocator allocator;
  private final boolean includeMetadata;
  private final boolean reuseVectorSchemaRoot;
  private final Map<Integer, JdbcFieldInfo> arraySubTypesByColumnIndex;
  private final Map<String, JdbcFieldInfo> arraySubTypesByColumnName;

  public static final int DEFAULT_TARGET_BATCH_SIZE = 1024;
  public static final int NO_LIMIT_BATCH_SIZE = -1;

  /**
   * The maximum rowCount to read each time when partially convert data.
   * Default value is 1024 and -1 means disable partial read.
   * default is -1 which means disable partial read.
   * Note that this flag only useful for {@link JdbcToArrow#sqlToArrowVectorIterator}
   * 1) if targetBatchSize != -1, it will convert full data into multiple vectors
   * with valueCount no more than targetBatchSize.
   * 2) if targetBatchSize == -1, it will convert full data into a single vector in {@link ArrowVectorIterator}
   * </p>
   */
  private final int targetBatchSize;

  private final Function<JdbcFieldInfo, ArrowType> jdbcToArrowTypeConverter;

  /**
   * Constructs a new configuration from the provided allocator and calendar.  The <code>allocator</code>
   * is used when constructing the Arrow vectors from the ResultSet, and the calendar is used to define
   * Arrow Timestamp fields, and to read time-based fields from the JDBC <code>ResultSet</code>. 
   *
   * @param allocator       The memory allocator to construct the Arrow vectors with.
   * @param calendar        The calendar to use when constructing Timestamp fields and reading time-based results.
   */
  JdbcToArrowConfig(BufferAllocator allocator, Calendar calendar) {
    this(allocator, calendar,
        /* include metadata */ false,
        /* reuse vector schema root */ false,
        /* array sub-types by column index */ null,
        /* array sub-types by column name */ null,
        DEFAULT_TARGET_BATCH_SIZE, null);
  }

  /**
   * Constructs a new configuration from the provided allocator and calendar.  The <code>allocator</code>
   * is used when constructing the Arrow vectors from the ResultSet, and the calendar is used to define
   * Arrow Timestamp fields, and to read time-based fields from the JDBC <code>ResultSet</code>. 
   *
   * @param allocator       The memory allocator to construct the Arrow vectors with.
   * @param calendar        The calendar to use when constructing Timestamp fields and reading time-based results.
   * @param includeMetadata Whether to include JDBC field metadata in the Arrow Schema Field metadata.
   * @param reuseVectorSchemaRoot Whether to reuse the vector schema root for each data load.
   * @param arraySubTypesByColumnIndex The type of the JDBC array at the column index (1-based).
   * @param arraySubTypesByColumnName  The type of the JDBC array at the column name.
   * @param jdbcToArrowTypeConverter The function that maps JDBC field type information to arrow type. If set to null,
   *                                 the default mapping will be used, which is defined as:
   *  <ul>
   *    <li>CHAR --> ArrowType.Utf8</li>
   *    <li>NCHAR --> ArrowType.Utf8</li>
   *    <li>VARCHAR --> ArrowType.Utf8</li>
   *    <li>NVARCHAR --> ArrowType.Utf8</li>
   *    <li>LONGVARCHAR --> ArrowType.Utf8</li>
   *    <li>LONGNVARCHAR --> ArrowType.Utf8</li>
   *    <li>NUMERIC --> ArrowType.Decimal(precision, scale)</li>
   *    <li>DECIMAL --> ArrowType.Decimal(precision, scale)</li>
   *    <li>BIT --> ArrowType.Bool</li>
   *    <li>TINYINT --> ArrowType.Int(8, signed)</li>
   *    <li>SMALLINT --> ArrowType.Int(16, signed)</li>
   *    <li>INTEGER --> ArrowType.Int(32, signed)</li>
   *    <li>BIGINT --> ArrowType.Int(64, signed)</li>
   *    <li>REAL --> ArrowType.FloatingPoint(FloatingPointPrecision.SINGLE)</li>
   *    <li>FLOAT --> ArrowType.FloatingPoint(FloatingPointPrecision.SINGLE)</li>
   *    <li>DOUBLE --> ArrowType.FloatingPoint(FloatingPointPrecision.DOUBLE)</li>
   *    <li>BINARY --> ArrowType.Binary</li>
   *    <li>VARBINARY --> ArrowType.Binary</li>
   *    <li>LONGVARBINARY --> ArrowType.Binary</li>
   *    <li>DATE --> ArrowType.Date(DateUnit.DAY)</li>
   *    <li>TIME --> ArrowType.Time(TimeUnit.MILLISECOND, 32)</li>
   *    <li>TIMESTAMP --> ArrowType.Timestamp(TimeUnit.MILLISECOND, calendar timezone)</li>
   *    <li>CLOB --> ArrowType.Utf8</li>
   *    <li>BLOB --> ArrowType.Binary</li>
   *    <li>NULL --> ArrowType.Null</li>
   *  </ul>
   */
  JdbcToArrowConfig(
      BufferAllocator allocator,
      Calendar calendar,
      boolean includeMetadata,
      boolean reuseVectorSchemaRoot,
      Map<Integer, JdbcFieldInfo> arraySubTypesByColumnIndex,
      Map<String, JdbcFieldInfo> arraySubTypesByColumnName,
      int targetBatchSize,
      Function<JdbcFieldInfo, ArrowType> jdbcToArrowTypeConverter) {
    Preconditions.checkNotNull(allocator, "Memory allocator cannot be null");
    this.allocator = allocator;
    this.calendar = calendar;
    this.includeMetadata = includeMetadata;
    this.reuseVectorSchemaRoot = reuseVectorSchemaRoot;
    this.arraySubTypesByColumnIndex = arraySubTypesByColumnIndex;
    this.arraySubTypesByColumnName = arraySubTypesByColumnName;
    this.targetBatchSize = targetBatchSize;

    // set up type converter
    this.jdbcToArrowTypeConverter = jdbcToArrowTypeConverter != null ? jdbcToArrowTypeConverter :
        fieldInfo -> {
          final String timezone;
          if (calendar != null) {
            timezone = calendar.getTimeZone().getID();
          } else {
            timezone = null;
          }

          switch (fieldInfo.getJdbcType()) {
            case Types.BOOLEAN:
            case Types.BIT:
              return new ArrowType.Bool();
            case Types.TINYINT:
              return new ArrowType.Int(8, true);
            case Types.SMALLINT:
              return new ArrowType.Int(16, true);
            case Types.INTEGER:
              return new ArrowType.Int(32, true);
            case Types.BIGINT:
              return new ArrowType.Int(64, true);
            case Types.NUMERIC:
            case Types.DECIMAL:
              int precision = fieldInfo.getPrecision();
              int scale = fieldInfo.getScale();
              return new ArrowType.Decimal(precision, scale, 128);
            case Types.REAL:
            case Types.FLOAT:
              return new ArrowType.FloatingPoint(SINGLE);
            case Types.DOUBLE:
              return new ArrowType.FloatingPoint(DOUBLE);
            case Types.CHAR:
            case Types.NCHAR:
            case Types.VARCHAR:
            case Types.NVARCHAR:
            case Types.LONGVARCHAR:
            case Types.LONGNVARCHAR:
            case Types.CLOB:
              return new ArrowType.Utf8();
            case Types.DATE:
              return new ArrowType.Date(DateUnit.DAY);
            case Types.TIME:
              return new ArrowType.Time(TimeUnit.MILLISECOND, 32);
            case Types.TIMESTAMP:
              return new ArrowType.Timestamp(TimeUnit.MILLISECOND, timezone);
            case Types.BINARY:
            case Types.VARBINARY:
            case Types.LONGVARBINARY:
            case Types.BLOB:
              return new ArrowType.Binary();
            case Types.ARRAY:
              return new ArrowType.List();
            case Types.NULL:
              return new ArrowType.Null();
            default:
              // no-op, shouldn't get here
              return null;
          }
        };
  }

  /**
   * The calendar to use when defining Arrow Timestamp fields
   * and retrieving {@link java.sql.Date}, {@link java.sql.Time}, or {@link java.sql.Timestamp}
   * data types from the {@link java.sql.ResultSet}, or <code>null</code> if not converting.
   *
   * @return the calendar.
   */
  public Calendar getCalendar() {
    return calendar;
  }

  /**
   * The Arrow memory allocator.
   * @return the allocator.
   */
  public BufferAllocator getAllocator() {
    return allocator;
  }

  /**
   * Whether to include JDBC ResultSet field metadata in the Arrow Schema field metadata.
   *
   * @return <code>true</code> to include field metadata, <code>false</code> to exclude it.
   */
  public boolean shouldIncludeMetadata() {
    return includeMetadata;
  }

  /**
   * Get the target batch size for partial read.
   */
  public int getTargetBatchSize() {
    return targetBatchSize;
  }

  /**
   * Get whether it is allowed to reuse the vector schema root.
   */
  public boolean isReuseVectorSchemaRoot() {
    return reuseVectorSchemaRoot;
  }

  /**
   * Gets the mapping between JDBC type information to Arrow type.
   */
  public Function<JdbcFieldInfo, ArrowType> getJdbcToArrowTypeConverter() {
    return jdbcToArrowTypeConverter;
  }

  /**
   * Returns the array sub-type {@link JdbcFieldInfo} defined for the provided column index.
   *
   * @param index The {@link java.sql.ResultSetMetaData} column index of an {@link java.sql.Types#ARRAY} type.
   * @return The {@link JdbcFieldInfo} for that array's sub-type, or <code>null</code> if not defined.
   */
  public JdbcFieldInfo getArraySubTypeByColumnIndex(int index) {
    if (arraySubTypesByColumnIndex == null) {
      return null;
    } else {
      return arraySubTypesByColumnIndex.get(index);
    }
  }

  /**
   * Returns the array sub-type {@link JdbcFieldInfo} defined for the provided column name.
   *
   * @param name The {@link java.sql.ResultSetMetaData} column name of an {@link java.sql.Types#ARRAY} type.
   * @return The {@link JdbcFieldInfo} for that array's sub-type, or <code>null</code> if not defined.
   */
  public JdbcFieldInfo getArraySubTypeByColumnName(String name) {
    if (arraySubTypesByColumnName == null) {
      return null;
    } else {
      return arraySubTypesByColumnName.get(name);
    }
  }
}
