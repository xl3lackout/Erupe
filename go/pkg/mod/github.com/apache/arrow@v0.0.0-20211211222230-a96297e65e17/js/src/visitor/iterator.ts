// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import { Data } from '../data';
import { Type } from '../enum';
import { Visitor } from '../visitor';
import { VectorType } from '../interfaces';
import { BitIterator } from '../util/bit';
import { instance as getVisitor } from './get';
import {
    DataType, Dictionary,
    Bool, Null, Utf8, Binary, Decimal, FixedSizeBinary, List, FixedSizeList, Map_, Struct,
    Float, Float16, Float32, Float64,
    Int, Uint8, Uint16, Uint32, Uint64, Int8, Int16, Int32, Int64,
    Date_, DateDay, DateMillisecond,
    Interval, IntervalDayTime, IntervalYearMonth,
    Time, TimeSecond, TimeMillisecond, TimeMicrosecond, TimeNanosecond,
    Timestamp, TimestampSecond, TimestampMillisecond, TimestampMicrosecond, TimestampNanosecond,
    Union, DenseUnion, SparseUnion,
} from '../type';

/** @ignore */
export interface IteratorVisitor extends Visitor {
    visit<T extends VectorType>(node: T): IterableIterator<T['TValue'] | null>;
    visitMany <T extends VectorType>(nodes: T[]): IterableIterator<T['TValue'] | null>[];
    getVisitFn<T extends Type>(node: T): (vector: VectorType<T>) => IterableIterator<VectorType<T>['TValue'] | null>;
    getVisitFn<T extends DataType>(node: VectorType<T> | Data<T> | T): (vector: VectorType<T>) => IterableIterator<VectorType<T>['TValue'] | null>;
    visitNull                 <T extends Null>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitBool                 <T extends Bool>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInt                  <T extends Int>                  (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInt8                 <T extends Int8>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInt16                <T extends Int16>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInt32                <T extends Int32>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInt64                <T extends Int64>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUint8                <T extends Uint8>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUint16               <T extends Uint16>               (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUint32               <T extends Uint32>               (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUint64               <T extends Uint64>               (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFloat                <T extends Float>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFloat16              <T extends Float16>              (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFloat32              <T extends Float32>              (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFloat64              <T extends Float64>              (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUtf8                 <T extends Utf8>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitBinary               <T extends Binary>               (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFixedSizeBinary      <T extends FixedSizeBinary>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDate                 <T extends Date_>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDateDay              <T extends DateDay>              (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDateMillisecond      <T extends DateMillisecond>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimestamp            <T extends Timestamp>            (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimestampSecond      <T extends TimestampSecond>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimestampMillisecond <T extends TimestampMillisecond> (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimestampMicrosecond <T extends TimestampMicrosecond> (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimestampNanosecond  <T extends TimestampNanosecond>  (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTime                 <T extends Time>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimeSecond           <T extends TimeSecond>           (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimeMillisecond      <T extends TimeMillisecond>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimeMicrosecond      <T extends TimeMicrosecond>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitTimeNanosecond       <T extends TimeNanosecond>       (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDecimal              <T extends Decimal>              (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitList                 <T extends List>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitStruct               <T extends Struct>               (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitUnion                <T extends Union>                (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDenseUnion           <T extends DenseUnion>           (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitSparseUnion          <T extends SparseUnion>          (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitDictionary           <T extends Dictionary>           (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitInterval             <T extends Interval>             (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitIntervalDayTime      <T extends IntervalDayTime>      (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitIntervalYearMonth    <T extends IntervalYearMonth>    (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitFixedSizeList        <T extends FixedSizeList>        (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
    visitMap                  <T extends Map_>                 (vector: VectorType<T>): IterableIterator<T['TValue'] | null>;
}

/** @ignore */
export class IteratorVisitor extends Visitor {}

/** @ignore */
function nullableIterator<T extends DataType>(vector: VectorType<T>): IterableIterator<T['TValue'] | null> {
    const getFn = getVisitor.getVisitFn(vector);
    return new BitIterator<T['TValue'] | null>(
        vector.data.nullBitmap, vector.data.offset, vector.length, vector,
        (vec: VectorType<T>, idx: number, nullByte: number, nullBit: number) =>
            ((nullByte & 1 << nullBit) !== 0) ? getFn(vec, idx) : null
    );
}

/** @ignore */
class VectorIterator<T extends DataType> implements IterableIterator<T['TValue'] | null> {
    private index = 0;

    constructor(
        private vector: VectorType<T>,
        private getFn: (vector: VectorType<T>, index: number) => VectorType<T>['TValue']
    ) {}

    next(): IteratorResult<T['TValue'] | null> {
        if (this.index < this.vector.length) {
            return {
                value: this.getFn(this.vector, this.index++)
            };
        }

        return {done: true, value: null};
    }

    [Symbol.iterator]() {
        return this;
    }
}

/** @ignore */
function vectorIterator<T extends DataType>(vector: VectorType<T>): IterableIterator<T['TValue'] | null> {

    // If nullable, iterate manually
    if (vector.nullCount > 0) {
        return nullableIterator<T>(vector);
    }

    const { type, typeId, length } = vector;

    // Fast case, defer to native iterators if possible
    if (vector.stride === 1 && (
        (typeId === Type.Timestamp) ||
        (typeId === Type.Int && (type as Int).bitWidth !== 64) ||
        (typeId === Type.Time && (type as Time).bitWidth !== 64) ||
        (typeId === Type.Float && (type as Float).precision > 0 /* Precision.HALF */)
    )) {
        return vector.data.values.subarray(0, length)[Symbol.iterator]();
    }

    // Otherwise, iterate manually
    return new VectorIterator(vector, getVisitor.getVisitFn(vector));
}

IteratorVisitor.prototype.visitNull                 = vectorIterator;
IteratorVisitor.prototype.visitBool                 = vectorIterator;
IteratorVisitor.prototype.visitInt                  = vectorIterator;
IteratorVisitor.prototype.visitInt8                 = vectorIterator;
IteratorVisitor.prototype.visitInt16                = vectorIterator;
IteratorVisitor.prototype.visitInt32                = vectorIterator;
IteratorVisitor.prototype.visitInt64                = vectorIterator;
IteratorVisitor.prototype.visitUint8                = vectorIterator;
IteratorVisitor.prototype.visitUint16               = vectorIterator;
IteratorVisitor.prototype.visitUint32               = vectorIterator;
IteratorVisitor.prototype.visitUint64               = vectorIterator;
IteratorVisitor.prototype.visitFloat                = vectorIterator;
IteratorVisitor.prototype.visitFloat16              = vectorIterator;
IteratorVisitor.prototype.visitFloat32              = vectorIterator;
IteratorVisitor.prototype.visitFloat64              = vectorIterator;
IteratorVisitor.prototype.visitUtf8                 = vectorIterator;
IteratorVisitor.prototype.visitBinary               = vectorIterator;
IteratorVisitor.prototype.visitFixedSizeBinary      = vectorIterator;
IteratorVisitor.prototype.visitDate                 = vectorIterator;
IteratorVisitor.prototype.visitDateDay              = vectorIterator;
IteratorVisitor.prototype.visitDateMillisecond      = vectorIterator;
IteratorVisitor.prototype.visitTimestamp            = vectorIterator;
IteratorVisitor.prototype.visitTimestampSecond      = vectorIterator;
IteratorVisitor.prototype.visitTimestampMillisecond = vectorIterator;
IteratorVisitor.prototype.visitTimestampMicrosecond = vectorIterator;
IteratorVisitor.prototype.visitTimestampNanosecond  = vectorIterator;
IteratorVisitor.prototype.visitTime                 = vectorIterator;
IteratorVisitor.prototype.visitTimeSecond           = vectorIterator;
IteratorVisitor.prototype.visitTimeMillisecond      = vectorIterator;
IteratorVisitor.prototype.visitTimeMicrosecond      = vectorIterator;
IteratorVisitor.prototype.visitTimeNanosecond       = vectorIterator;
IteratorVisitor.prototype.visitDecimal              = vectorIterator;
IteratorVisitor.prototype.visitList                 = vectorIterator;
IteratorVisitor.prototype.visitStruct               = vectorIterator;
IteratorVisitor.prototype.visitUnion                = vectorIterator;
IteratorVisitor.prototype.visitDenseUnion           = vectorIterator;
IteratorVisitor.prototype.visitSparseUnion          = vectorIterator;
IteratorVisitor.prototype.visitDictionary           = vectorIterator;
IteratorVisitor.prototype.visitInterval             = vectorIterator;
IteratorVisitor.prototype.visitIntervalDayTime      = vectorIterator;
IteratorVisitor.prototype.visitIntervalYearMonth    = vectorIterator;
IteratorVisitor.prototype.visitFixedSizeList        = vectorIterator;
IteratorVisitor.prototype.visitMap                  = vectorIterator;

/** @ignore */
export const instance = new IteratorVisitor();
