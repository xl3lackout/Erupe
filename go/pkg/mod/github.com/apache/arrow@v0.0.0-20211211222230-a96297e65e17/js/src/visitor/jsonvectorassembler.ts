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

import { BN } from '../util/bn';
import { Column } from '../column';
import { Vector } from '../vector';
import { Visitor } from '../visitor';
import { BufferType } from '../enum';
import { RecordBatch } from '../recordbatch';
import { VectorType as V } from '../interfaces';
import { UnionMode, DateUnit, TimeUnit } from '../enum';
import { BitIterator, getBit, getBool } from '../util/bit';
import { selectColumnChildrenArgs } from '../util/args';
import {
    DataType,
    Float, Int, Date_, Interval, Time, Timestamp, Union,
    Bool, Null, Utf8, Binary, Decimal, FixedSizeBinary, List, FixedSizeList, Map_, Struct,
} from '../type';

/** @ignore */
export interface JSONVectorAssembler extends Visitor {

    visit     <T extends Column>  (node: T  ): Record<string, unknown>;
    visitMany <T extends Column>  (cols: T[]): Record<string, unknown>[];
    getVisitFn<T extends DataType>(node: Column<T>): (column: Column<T>) => { name: string; count: number; VALIDITY: (0 | 1)[]; DATA?: any[]; OFFSET?: number[]; TYPE?: number[]; children?: any[] };

    visitNull                 <T extends Null>            (vector: V<T>): Record<string, never>;
    visitBool                 <T extends Bool>            (vector: V<T>): { DATA: boolean[] };
    visitInt                  <T extends Int>             (vector: V<T>): { DATA: (number | string)[]  };
    visitFloat                <T extends Float>           (vector: V<T>): { DATA: number[]  };
    visitUtf8                 <T extends Utf8>            (vector: V<T>): { DATA: string[]; OFFSET: number[] };
    visitBinary               <T extends Binary>          (vector: V<T>): { DATA: string[]; OFFSET: number[] };
    visitFixedSizeBinary      <T extends FixedSizeBinary> (vector: V<T>): { DATA: string[]  };
    visitDate                 <T extends Date_>           (vector: V<T>): { DATA: number[]  };
    visitTimestamp            <T extends Timestamp>       (vector: V<T>): { DATA: string[]  };
    visitTime                 <T extends Time>            (vector: V<T>): { DATA: number[]  };
    visitDecimal              <T extends Decimal>         (vector: V<T>): { DATA: string[]  };
    visitList                 <T extends List>            (vector: V<T>): { children: any[]; OFFSET: number[] };
    visitStruct               <T extends Struct>          (vector: V<T>): { children: any[] };
    visitUnion                <T extends Union>           (vector: V<T>): { children: any[]; TYPE: number[]  };
    visitInterval             <T extends Interval>        (vector: V<T>): { DATA: number[]  };
    visitFixedSizeList        <T extends FixedSizeList>   (vector: V<T>): { children: any[] };
    visitMap                  <T extends Map_>            (vector: V<T>): { children: any[] };
}

/** @ignore */
export class JSONVectorAssembler extends Visitor {

    /** @nocollapse */
    public static assemble<T extends Column | RecordBatch>(...args: (T | T[])[]) {
        return new JSONVectorAssembler().visitMany(selectColumnChildrenArgs(RecordBatch, args));
    }

    public visit<T extends Column>(column: T) {
        const { data, name, length } = column;
        const { offset, nullCount, nullBitmap } = data;
        const type = DataType.isDictionary(column.type) ? column.type.indices : column.type;
        const buffers = Object.assign([], data.buffers, { [BufferType.VALIDITY]: undefined });
        return {
            'name': name,
            'count': length,
            'VALIDITY': DataType.isNull(type) ? undefined
                : nullCount <= 0 ? Array.from({ length }, () => 1)
                : [...new BitIterator(nullBitmap, offset, length, null, getBit)],
            ...super.visit(Vector.new(data.clone(type, offset, length, 0, buffers)))
        };
    }
    public visitNull() { return {}; }
    public visitBool<T extends Bool>({ values, offset, length }: V<T>) {
        return { 'DATA': [...new BitIterator(values, offset, length, null, getBool)] };
    }
    public visitInt<T extends Int>(vector: V<T>) {
        return {
            'DATA': vector.type.bitWidth < 64
                ? [...vector.values]
                : [...bigNumsToStrings(vector.values as (Int32Array | Uint32Array), 2)]
        };
    }
    public visitFloat<T extends Float>(vector: V<T>) {
        return { 'DATA': [...vector.values] };
    }
    public visitUtf8<T extends Utf8>(vector: V<T>) {
        return { 'DATA': [...vector], 'OFFSET': [...vector.valueOffsets] };
    }
    public visitBinary<T extends Binary>(vector: V<T>) {
        return { 'DATA': [...binaryToString(vector)], OFFSET: [...vector.valueOffsets] };
    }
    public visitFixedSizeBinary<T extends FixedSizeBinary>(vector: V<T>) {
        return { 'DATA': [...binaryToString(vector)] };
    }
    public visitDate<T extends Date_>(vector: V<T>) {
        return {
            'DATA': vector.type.unit === DateUnit.DAY
                ? [...vector.values]
                : [...bigNumsToStrings(vector.values, 2)]
        };
    }
    public visitTimestamp<T extends Timestamp>(vector: V<T>) {
        return { 'DATA': [...bigNumsToStrings(vector.values, 2)] };
    }
    public visitTime<T extends Time>(vector: V<T>) {
        return {
            'DATA': vector.type.unit < TimeUnit.MICROSECOND
                ? [...vector.values]
                : [...bigNumsToStrings(vector.values, 2)]
        };
    }
    public visitDecimal<T extends Decimal>(vector: V<T>) {
        return { 'DATA': [...bigNumsToStrings(vector.values, 4)] };
    }
    public visitList<T extends List>(vector: V<T>) {
        return {
            'OFFSET': [...vector.valueOffsets],
            'children': vector.type.children.map((f, i) =>
                this.visit(new Column(f, [vector.getChildAt(i)!])))
        };
    }
    public visitStruct<T extends Struct>(vector: V<T>) {
        return {
            'children': vector.type.children.map((f, i) =>
                this.visit(new Column(f, [vector.getChildAt(i)!])))
        };
    }
    public visitUnion<T extends Union>(vector: V<T>) {
        return {
            'TYPE': [...vector.typeIds],
            'OFFSET': vector.type.mode === UnionMode.Dense ? [...vector.valueOffsets] : undefined,
            'children': vector.type.children.map((f, i) => this.visit(new Column(f, [vector.getChildAt(i)!])))
        };
    }
    public visitInterval<T extends Interval>(vector: V<T>) {
        return { 'DATA': [...vector.values] };
    }
    public visitFixedSizeList<T extends FixedSizeList>(vector: V<T>) {
        return {
            'children': vector.type.children.map((f, i) =>
                this.visit(new Column(f, [vector.getChildAt(i)!])))
        };
    }
    public visitMap<T extends Map_>(vector: V<T>) {
        return {
            'OFFSET': [...vector.valueOffsets],
            'children': vector.type.children.map((f, i) =>
                this.visit(new Column(f, [vector.getChildAt(i)!])))
        };
    }
}

/** @ignore */
function* binaryToString(vector: Vector<Binary> | Vector<FixedSizeBinary>) {
    for (const octets of vector as Iterable<Uint8Array>) {
        yield octets.reduce((str, byte) => {
            return `${str}${('0' + (byte & 0xFF).toString(16)).slice(-2)}`;
        }, '').toUpperCase();
    }
}

/** @ignore */
function* bigNumsToStrings(values: Uint32Array | Int32Array, stride: number) {
    for (let i = -1, n = values.length / stride; ++i < n;) {
        yield `${BN.new(values.subarray((i + 0) * stride, (i + 1) * stride), false)}`;
    }
}
