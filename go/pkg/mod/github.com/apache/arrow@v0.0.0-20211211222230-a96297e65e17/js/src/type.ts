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

/* eslint-disable @typescript-eslint/naming-convention */

import { Field } from './schema';
import { flatbuffers } from 'flatbuffers';
import { VectorType as V } from './interfaces';
import { TypedArrayConstructor } from './interfaces';

import Long = flatbuffers.Long;
import {
    Type,
    Precision, UnionMode,
    DateUnit, TimeUnit, IntervalUnit
} from './enum';

/** @ignore */
export type TimeBitWidth = 32 | 64;
/** @ignore */
export type IntBitWidth = 8 | 16 | 32 | 64;
/** @ignore */
export type IsSigned = { 'true': true; 'false': false };
/** @ignore */
export type RowLike<T extends { [key: string]: DataType }> =
      ( Iterable<[string, T[keyof T]['TValue'] | null]> )
    & { [P in keyof T]: T[P]['TValue'] | null }
    & { get<K extends keyof T>(key: K): T[K]['TValue'] | null }
    & { set<K extends keyof T>(key: K, val: T[K]['TValue'] | null): void }
    ;

/** @ignore */
export type MapLike<K extends DataType = any, V extends DataType = any> =
      { [P in K['TValue']]: V['TValue'] | null }
    & ( Map<K['TValue'], V['TValue'] | null> )
    ;

export interface DataType<TType extends Type = Type, TChildren extends { [key: string]: DataType } = any> {
    readonly TType: TType;
    readonly TArray: any;
    readonly TValue: any;
    readonly ArrayType: any;
    readonly children: Field<TChildren[keyof TChildren]>[];
}

/**
 * An abstract base class for classes that encapsulate metadata about each of
 * the logical types that Arrow can represent.
 */
export abstract class DataType<TType extends Type = Type, TChildren extends { [key: string]: DataType } = any> {

    public [Symbol.toStringTag]: string;

    /** @nocollapse */ static            isNull (x: any): x is Null            { return x?.typeId === Type.Null;            }
    /** @nocollapse */ static             isInt (x: any): x is Int_            { return x?.typeId === Type.Int;             }
    /** @nocollapse */ static           isFloat (x: any): x is Float           { return x?.typeId === Type.Float;           }
    /** @nocollapse */ static          isBinary (x: any): x is Binary          { return x?.typeId === Type.Binary;          }
    /** @nocollapse */ static            isUtf8 (x: any): x is Utf8            { return x?.typeId === Type.Utf8;            }
    /** @nocollapse */ static            isBool (x: any): x is Bool            { return x?.typeId === Type.Bool;            }
    /** @nocollapse */ static         isDecimal (x: any): x is Decimal         { return x?.typeId === Type.Decimal;         }
    /** @nocollapse */ static            isDate (x: any): x is Date_           { return x?.typeId === Type.Date;            }
    /** @nocollapse */ static            isTime (x: any): x is Time_           { return x?.typeId === Type.Time;            }
    /** @nocollapse */ static       isTimestamp (x: any): x is Timestamp_      { return x?.typeId === Type.Timestamp;       }
    /** @nocollapse */ static        isInterval (x: any): x is Interval_       { return x?.typeId === Type.Interval;        }
    /** @nocollapse */ static            isList (x: any): x is List            { return x?.typeId === Type.List;            }
    /** @nocollapse */ static          isStruct (x: any): x is Struct          { return x?.typeId === Type.Struct;          }
    /** @nocollapse */ static           isUnion (x: any): x is Union_          { return x?.typeId === Type.Union;           }
    /** @nocollapse */ static isFixedSizeBinary (x: any): x is FixedSizeBinary { return x?.typeId === Type.FixedSizeBinary; }
    /** @nocollapse */ static   isFixedSizeList (x: any): x is FixedSizeList   { return x?.typeId === Type.FixedSizeList;   }
    /** @nocollapse */ static             isMap (x: any): x is Map_            { return x?.typeId === Type.Map;             }
    /** @nocollapse */ static      isDictionary (x: any): x is Dictionary      { return x?.typeId === Type.Dictionary;      }

    public get typeId(): TType { return <any> Type.NONE; }

    protected static [Symbol.toStringTag] = ((proto: DataType) => {
        (<any> proto).children = null;
        (<any> proto).ArrayType = Array;
        return proto[Symbol.toStringTag] = 'DataType';
    })(DataType.prototype);
}

/** @ignore */
export interface Null extends DataType<Type.Null> { TArray: void; TValue: null }
/** @ignore */
export class Null extends DataType<Type.Null> {
    public toString() { return `Null`; }
    public get typeId() { return Type.Null as Type.Null; }
    protected static [Symbol.toStringTag] = ((proto: Null) => {
        return proto[Symbol.toStringTag] = 'Null';
    })(Null.prototype);
}

/** @ignore */
type Ints = Type.Int | Type.Int8 | Type.Int16 | Type.Int32 | Type.Int64 | Type.Uint8 | Type.Uint16 | Type.Uint32 | Type.Uint64;
/** @ignore */
type IType = {
    [Type.Int   ]: { bitWidth: IntBitWidth; isSigned: true | false; TArray: IntArray;    TValue: number | bigint | Int32Array | Uint32Array };
    [Type.Int8  ]: { bitWidth:           8; isSigned: true;         TArray: Int8Array;   TValue: number };
    [Type.Int16 ]: { bitWidth:          16; isSigned: true;         TArray: Int16Array;  TValue: number };
    [Type.Int32 ]: { bitWidth:          32; isSigned: true;         TArray: Int32Array;  TValue: number };
    [Type.Int64 ]: { bitWidth:          64; isSigned: true;         TArray: Int32Array;  TValue: bigint | Int32Array | Uint32Array };
    [Type.Uint8 ]: { bitWidth:           8; isSigned: false;        TArray: Uint8Array;  TValue: number };
    [Type.Uint16]: { bitWidth:          16; isSigned: false;        TArray: Uint16Array; TValue: number };
    [Type.Uint32]: { bitWidth:          32; isSigned: false;        TArray: Uint32Array; TValue: number };
    [Type.Uint64]: { bitWidth:          64; isSigned: false;        TArray: Uint32Array; TValue: bigint | Int32Array | Uint32Array };
};

/** @ignore */
interface Int_<T extends Ints = Ints> extends DataType<T> { TArray: IType[T]['TArray']; TValue: IType[T]['TValue'] }
/** @ignore */
class Int_<T extends Ints = Ints> extends DataType<T> {
    constructor(public readonly isSigned: IType[T]['isSigned'],
                public readonly bitWidth: IType[T]['bitWidth']) {
        super();
    }
    public get typeId() { return Type.Int as T; }
    public get ArrayType(): TypedArrayConstructor<IType[T]['TArray']> {
        switch (this.bitWidth) {
            case  8: return this.isSigned ?  Int8Array :  Uint8Array;
            case 16: return this.isSigned ? Int16Array : Uint16Array;
            case 32: return this.isSigned ? Int32Array : Uint32Array;
            case 64: return this.isSigned ? Int32Array : Uint32Array;
        }
        throw new Error(`Unrecognized ${this[Symbol.toStringTag]} type`);
    }
    public toString() { return `${this.isSigned ? `I` : `Ui`}nt${this.bitWidth}`; }
    protected static [Symbol.toStringTag] = ((proto: Int_) => {
        (<any> proto).isSigned = null;
        (<any> proto).bitWidth = null;
        return proto[Symbol.toStringTag] = 'Int';
    })(Int_.prototype);
}

export { Int_ as Int };

/** @ignore */
export class Int8 extends Int_<Type.Int8> { constructor() { super(true, 8); } }
/** @ignore */
export class Int16 extends Int_<Type.Int16> { constructor() { super(true, 16); } }
/** @ignore */
export class Int32 extends Int_<Type.Int32> { constructor() { super(true, 32); } }
/** @ignore */
export class Int64 extends Int_<Type.Int64> { constructor() { super(true, 64); } }
/** @ignore */
export class Uint8 extends Int_<Type.Uint8> { constructor() { super(false, 8); } }
/** @ignore */
export class Uint16 extends Int_<Type.Uint16> { constructor() { super(false, 16); } }
/** @ignore */
export class Uint32 extends Int_<Type.Uint32> { constructor() { super(false, 32); } }
/** @ignore */
export class Uint64 extends Int_<Type.Uint64> { constructor() { super(false, 64); } }

Object.defineProperty(Int8.prototype, 'ArrayType', { value: Int8Array });
Object.defineProperty(Int16.prototype, 'ArrayType', { value: Int16Array });
Object.defineProperty(Int32.prototype, 'ArrayType', { value: Int32Array });
Object.defineProperty(Int64.prototype, 'ArrayType', { value: Int32Array });
Object.defineProperty(Uint8.prototype, 'ArrayType', { value: Uint8Array });
Object.defineProperty(Uint16.prototype, 'ArrayType', { value: Uint16Array });
Object.defineProperty(Uint32.prototype, 'ArrayType', { value: Uint32Array });
Object.defineProperty(Uint64.prototype, 'ArrayType', { value: Uint32Array });

/** @ignore */
type Floats = Type.Float | Type.Float16 | Type.Float32 | Type.Float64;
/** @ignore */
type FType = {
    [Type.Float  ]: { precision: Precision;        TArray: FloatArray;    TValue: number };
    [Type.Float16]: { precision: Precision.HALF;   TArray: Uint16Array;   TValue: number };
    [Type.Float32]: { precision: Precision.SINGLE; TArray: Float32Array;  TValue: number };
    [Type.Float64]: { precision: Precision.DOUBLE; TArray: Float64Array;  TValue: number };
};

/** @ignore */
export interface Float<T extends Floats = Floats> extends DataType<T> { TArray: FType[T]['TArray']; TValue: number }
/** @ignore */
export class Float<T extends Floats = Floats> extends DataType<T> {
    constructor(public readonly precision: Precision) {
        super();
    }
    public get typeId() { return Type.Float as T; }
    public get ArrayType(): TypedArrayConstructor<FType[T]['TArray']> {
        switch (this.precision) {
            case Precision.HALF: return Uint16Array;
            case Precision.SINGLE: return Float32Array;
            case Precision.DOUBLE: return Float64Array;
        }
        // @ts-ignore
        throw new Error(`Unrecognized ${this[Symbol.toStringTag]} type`);
    }
    public toString() { return `Float${(this.precision << 5) || 16}`; }
    protected static [Symbol.toStringTag] = ((proto: Float) => {
        (<any> proto).precision = null;
        return proto[Symbol.toStringTag] = 'Float';
    })(Float.prototype);
}

/** @ignore */
export class Float16 extends Float<Type.Float16> { constructor() { super(Precision.HALF); } }
/** @ignore */
export class Float32 extends Float<Type.Float32> { constructor() { super(Precision.SINGLE); } }
/** @ignore */
export class Float64 extends Float<Type.Float64> { constructor() { super(Precision.DOUBLE); } }

Object.defineProperty(Float16.prototype, 'ArrayType', { value: Uint16Array });
Object.defineProperty(Float32.prototype, 'ArrayType', { value: Float32Array });
Object.defineProperty(Float64.prototype, 'ArrayType', { value: Float64Array });

/** @ignore */
export interface Binary extends DataType<Type.Binary> { TArray: Uint8Array; TValue: Uint8Array; ArrayType: TypedArrayConstructor<Uint8Array> }
/** @ignore */
export class Binary extends DataType<Type.Binary> {
    constructor() {
        super();
    }
    public get typeId() { return Type.Binary as Type.Binary; }
    public toString() { return `Binary`; }
    protected static [Symbol.toStringTag] = ((proto: Binary) => {
        (<any> proto).ArrayType = Uint8Array;
        return proto[Symbol.toStringTag] = 'Binary';
    })(Binary.prototype);
}

/** @ignore */
export interface Utf8 extends DataType<Type.Utf8> { TArray: Uint8Array; TValue: string; ArrayType: TypedArrayConstructor<Uint8Array> }
/** @ignore */
export class Utf8 extends DataType<Type.Utf8> {
    constructor() {
        super();
    }
    public get typeId() { return Type.Utf8 as Type.Utf8; }
    public toString() { return `Utf8`; }
    protected static [Symbol.toStringTag] = ((proto: Utf8) => {
        (<any> proto).ArrayType = Uint8Array;
        return proto[Symbol.toStringTag] = 'Utf8';
    })(Utf8.prototype);
}

/** @ignore */
export interface Bool extends DataType<Type.Bool> { TArray: Uint8Array; TValue: boolean; ArrayType: TypedArrayConstructor<Uint8Array> }
/** @ignore */
export class Bool extends DataType<Type.Bool> {
    constructor() {
        super();
    }
    public get typeId() { return Type.Bool as Type.Bool; }
    public toString() { return `Bool`; }
    protected static [Symbol.toStringTag] = ((proto: Bool) => {
        (<any> proto).ArrayType = Uint8Array;
        return proto[Symbol.toStringTag] = 'Bool';
    })(Bool.prototype);
}

/** @ignore */
export interface Decimal extends DataType<Type.Decimal> { TArray: Uint32Array; TValue: Uint32Array; ArrayType: TypedArrayConstructor<Uint32Array> }
/** @ignore */
export class Decimal extends DataType<Type.Decimal> {
    constructor(public readonly scale: number,
                public readonly precision: number) {
        super();
    }
    public get typeId() { return Type.Decimal as Type.Decimal; }
    public toString() { return `Decimal[${this.precision}e${this.scale > 0 ? `+` : ``}${this.scale}]`; }
    protected static [Symbol.toStringTag] = ((proto: Decimal) => {
        (<any> proto).scale = null;
        (<any> proto).precision = null;
        (<any> proto).ArrayType = Uint32Array;
        return proto[Symbol.toStringTag] = 'Decimal';
    })(Decimal.prototype);
}

/** @ignore */
export type Dates = Type.Date | Type.DateDay | Type.DateMillisecond;
/** @ignore */
export interface Date_<T extends Dates = Dates> extends DataType<T> { TArray: Int32Array; TValue: Date; ArrayType: TypedArrayConstructor<Int32Array> }
/** @ignore */
export class Date_<T extends Dates = Dates> extends DataType<T> {
    constructor(public readonly unit: DateUnit) {
        super();
    }
    public get typeId() { return Type.Date as T; }
    public toString() { return `Date${(this.unit + 1) * 32}<${DateUnit[this.unit]}>`; }
    protected static [Symbol.toStringTag] = ((proto: Date_) => {
        (<any> proto).unit = null;
        (<any> proto).ArrayType = Int32Array;
        return proto[Symbol.toStringTag] = 'Date';
    })(Date_.prototype);
}

/** @ignore */
export class DateDay extends Date_<Type.DateDay> { constructor() { super(DateUnit.DAY); } }
/** @ignore */
export class DateMillisecond extends Date_<Type.DateMillisecond> { constructor() { super(DateUnit.MILLISECOND); } }

/** @ignore */
type Times = Type.Time | Type.TimeSecond | Type.TimeMillisecond | Type.TimeMicrosecond | Type.TimeNanosecond;
/** @ignore */
type TimesType = {
    [Type.Time           ]: { unit: TimeUnit;             TValue: number | Int32Array };
    [Type.TimeSecond     ]: { unit: TimeUnit.SECOND;      TValue: number             };
    [Type.TimeMillisecond]: { unit: TimeUnit.MILLISECOND; TValue: number             };
    [Type.TimeMicrosecond]: { unit: TimeUnit.MICROSECOND; TValue: Int32Array         };
    [Type.TimeNanosecond ]: { unit: TimeUnit.NANOSECOND;  TValue: Int32Array         };
};

/** @ignore */
interface Time_<T extends Times = Times> extends DataType<T> { TArray: Int32Array; TValue: TimesType[T]['TValue']; ArrayType: TypedArrayConstructor<Int32Array> }
/** @ignore */
class Time_<T extends Times = Times> extends DataType<T> {
    constructor(public readonly unit: TimesType[T]['unit'],
                public readonly bitWidth: TimeBitWidth) {
        super();
    }
    public get typeId() { return Type.Time as T; }
    public toString() { return `Time${this.bitWidth}<${TimeUnit[this.unit]}>`; }
    protected static [Symbol.toStringTag] = ((proto: Time_) => {
        (<any> proto).unit = null;
        (<any> proto).bitWidth = null;
        (<any> proto).ArrayType = Int32Array;
        return proto[Symbol.toStringTag] = 'Time';
    })(Time_.prototype);
}

export { Time_ as Time };

/** @ignore */
export class TimeSecond extends Time_<Type.TimeSecond> { constructor() { super(TimeUnit.SECOND, 32); } }
/** @ignore */
export class TimeMillisecond extends Time_<Type.TimeMillisecond> { constructor() { super(TimeUnit.MILLISECOND, 32); } }
/** @ignore */
export class TimeMicrosecond extends Time_<Type.TimeMicrosecond> { constructor() { super(TimeUnit.MICROSECOND, 64); } }
/** @ignore */
export class TimeNanosecond extends Time_<Type.TimeNanosecond> { constructor() { super(TimeUnit.NANOSECOND, 64); } }

/** @ignore */
type Timestamps = Type.Timestamp | Type.TimestampSecond | Type.TimestampMillisecond | Type.TimestampMicrosecond | Type.TimestampNanosecond;
/** @ignore */
interface Timestamp_<T extends Timestamps = Timestamps> extends DataType<T> { TArray: Int32Array; TValue: number; ArrayType: TypedArrayConstructor<Int32Array> }
/** @ignore */
class Timestamp_<T extends Timestamps = Timestamps> extends DataType<T> {
    constructor(public readonly unit: TimeUnit,
                public readonly timezone?: string | null) {
        super();
    }
    public get typeId() { return Type.Timestamp as T; }
    public toString() { return `Timestamp<${TimeUnit[this.unit]}${this.timezone ? `, ${this.timezone}` : ``}>`; }
    protected static [Symbol.toStringTag] = ((proto: Timestamp_) => {
        (<any> proto).unit = null;
        (<any> proto).timezone = null;
        (<any> proto).ArrayType = Int32Array;
        return proto[Symbol.toStringTag] = 'Timestamp';
    })(Timestamp_.prototype);
}

export { Timestamp_ as Timestamp };

/** @ignore */
export class TimestampSecond extends Timestamp_<Type.TimestampSecond> { constructor(timezone?: string | null) { super(TimeUnit.SECOND, timezone); } }
/** @ignore */
export class TimestampMillisecond extends Timestamp_<Type.TimestampMillisecond> { constructor(timezone?: string | null) { super(TimeUnit.MILLISECOND, timezone); } }
/** @ignore */
export class TimestampMicrosecond extends Timestamp_<Type.TimestampMicrosecond> { constructor(timezone?: string | null) { super(TimeUnit.MICROSECOND, timezone); } }
/** @ignore */
export class TimestampNanosecond extends Timestamp_<Type.TimestampNanosecond> { constructor(timezone?: string | null) { super(TimeUnit.NANOSECOND, timezone); } }

/** @ignore */
type Intervals = Type.Interval | Type.IntervalDayTime | Type.IntervalYearMonth;
/** @ignore */
interface Interval_<T extends Intervals = Intervals> extends DataType<T> { TArray: Int32Array; TValue: Int32Array; ArrayType: TypedArrayConstructor<Int32Array> }
/** @ignore */
class Interval_<T extends Intervals = Intervals> extends DataType<T> {
    constructor(public readonly unit: IntervalUnit) {
        super();
    }
    public get typeId() { return Type.Interval as T; }
    public toString() { return `Interval<${IntervalUnit[this.unit]}>`; }
    protected static [Symbol.toStringTag] = ((proto: Interval_) => {
        (<any> proto).unit = null;
        (<any> proto).ArrayType = Int32Array;
        return proto[Symbol.toStringTag] = 'Interval';
    })(Interval_.prototype);
}

export { Interval_ as Interval };

/** @ignore */
export class IntervalDayTime extends Interval_<Type.IntervalDayTime> { constructor() { super(IntervalUnit.DAY_TIME); } }
/** @ignore */
export class IntervalYearMonth extends Interval_<Type.IntervalYearMonth> { constructor() { super(IntervalUnit.YEAR_MONTH); } }

/** @ignore */
export interface List<T extends DataType = any> extends DataType<Type.List, { [0]: T }>  { TArray: IterableArrayLike<T>; TValue: V<T> }
/** @ignore */
export class List<T extends DataType = any> extends DataType<Type.List, { [0]: T }> {
    constructor(child: Field<T>) {
        super();
        this.children = [child];
    }
    public readonly children: Field<T>[];
    public get typeId() { return Type.List as Type.List; }
    public toString() { return `List<${this.valueType}>`; }
    public get valueType(): T { return this.children[0].type as T; }
    public get valueField(): Field<T> { return this.children[0] as Field<T>; }
    public get ArrayType(): T['ArrayType'] { return this.valueType.ArrayType; }
    protected static [Symbol.toStringTag] = ((proto: List) => {
        (<any> proto).children = null;
        return proto[Symbol.toStringTag] = 'List';
    })(List.prototype);
}

/** @ignore */
export interface Struct<T extends { [key: string]: DataType } = any> extends DataType<Type.Struct> { TArray: IterableArrayLike<RowLike<T>>; TValue: RowLike<T>; dataTypes: T }
/** @ignore */
export class Struct<T extends { [key: string]: DataType } = any> extends DataType<Type.Struct, T> {
    public readonly children: Field<T[keyof T]>[];
    constructor(children: Field<T[keyof T]>[]) {
        super();
        this.children = children;
    }
    public get typeId() { return Type.Struct as Type.Struct; }
    public toString() { return `Struct<{${this.children.map((f) => `${f.name}:${f.type}`).join(`, `)}}>`; }
    protected static [Symbol.toStringTag] = ((proto: Struct) => {
        (<any> proto).children = null;
        return proto[Symbol.toStringTag] = 'Struct';
    })(Struct.prototype);
}

/** @ignore */
type Unions = Type.Union | Type.DenseUnion | Type.SparseUnion;
/** @ignore */
interface Union_<T extends Unions = Unions> extends DataType<T> { TArray: Int8Array; TValue: any; ArrayType: TypedArrayConstructor<Int8Array> }
/** @ignore */
class Union_<T extends Unions = Unions> extends DataType<T> {
    public readonly mode: UnionMode;
    public readonly typeIds: Int32Array;
    public readonly children: Field<any>[];
    public readonly typeIdToChildIndex: { [key: number]: number };
    constructor(mode: UnionMode,
                typeIds: number[] | Int32Array,
                children: Field<any>[]) {
        super();
        this.mode = mode;
        this.children = children;
        this.typeIds = typeIds = Int32Array.from(typeIds);
        this.typeIdToChildIndex = typeIds.reduce((typeIdToChildIndex, typeId, idx) => {
            return (typeIdToChildIndex[typeId] = idx) && typeIdToChildIndex || typeIdToChildIndex;
        }, Object.create(null) as { [key: number]: number });
    }
    public get typeId() { return Type.Union as T; }
    public toString() {
 return `${this[Symbol.toStringTag]}<${
        this.children.map((x) => `${x.type}`).join(` | `)
    }>`;
}
    protected static [Symbol.toStringTag] = ((proto: Union_) => {
        (<any> proto).mode = null;
        (<any> proto).typeIds = null;
        (<any> proto).children = null;
        (<any> proto).typeIdToChildIndex = null;
        (<any> proto).ArrayType = Int8Array;
        return proto[Symbol.toStringTag] = 'Union';
    })(Union_.prototype);
}

export { Union_ as Union };

/** @ignore */
export class DenseUnion extends Union_<Type.DenseUnion> {
    constructor(typeIds: number[] | Int32Array, children: Field[]) {
        super(UnionMode.Dense, typeIds, children);
    }
}

/** @ignore */
export class SparseUnion extends Union_<Type.SparseUnion> {
    constructor(typeIds: number[] | Int32Array, children: Field[]) {
        super(UnionMode.Sparse, typeIds, children);
    }
}

/** @ignore */
export interface FixedSizeBinary extends DataType<Type.FixedSizeBinary> { TArray: Uint8Array; TValue: Uint8Array; ArrayType: TypedArrayConstructor<Uint8Array> }
/** @ignore */
export class FixedSizeBinary extends DataType<Type.FixedSizeBinary> {
    constructor(public readonly byteWidth: number) {
        super();
    }
    public get typeId() { return Type.FixedSizeBinary as Type.FixedSizeBinary; }
    public toString() { return `FixedSizeBinary[${this.byteWidth}]`; }
    protected static [Symbol.toStringTag] = ((proto: FixedSizeBinary) => {
        (<any> proto).byteWidth = null;
        (<any> proto).ArrayType = Uint8Array;
        return proto[Symbol.toStringTag] = 'FixedSizeBinary';
    })(FixedSizeBinary.prototype);
}

/** @ignore */
export interface FixedSizeList<T extends DataType = any> extends DataType<Type.FixedSizeList> { TArray: IterableArrayLike<T['TArray']>; TValue: V<T> }
/** @ignore */
export class FixedSizeList<T extends DataType = any> extends DataType<Type.FixedSizeList, { [0]: T }> {
    public readonly children: Field<T>[];
    constructor(public readonly listSize: number, child: Field<T>) {
        super();
        this.children = [child];
    }
    public get typeId() { return Type.FixedSizeList as Type.FixedSizeList; }
    public get valueType(): T { return this.children[0].type as T; }
    public get valueField(): Field<T> { return this.children[0] as Field<T>; }
    public get ArrayType(): T['ArrayType'] { return this.valueType.ArrayType; }
    public toString() { return `FixedSizeList[${this.listSize}]<${this.valueType}>`; }
    protected static [Symbol.toStringTag] = ((proto: FixedSizeList) => {
        (<any> proto).children = null;
        (<any> proto).listSize = null;
        return proto[Symbol.toStringTag] = 'FixedSizeList';
    })(FixedSizeList.prototype);
}

/** @ignore */
export interface Map_<TKey extends DataType = any, TValue extends DataType = any> extends DataType<Type.Map> {
    TArray: IterableArrayLike<Map<TKey['TValue'], TValue['TValue'] | null>>;
    TChild: Struct<{ key: TKey; value: TValue }>;
    TValue: MapLike<TKey, TValue>;
}

/** @ignore */
export class Map_<TKey extends DataType = any, TValue extends DataType = any> extends DataType<Type.Map> {
    constructor(child: Field<Struct<{ key: TKey; value: TValue }>>, keysSorted = false) {
        super();
        this.children = [child];
        this.keysSorted = keysSorted;
    }
    public readonly keysSorted: boolean;
    public readonly children: Field<Struct<{ key: TKey; value: TValue }>>[];
    public get typeId() { return Type.Map as Type.Map; }
    public get keyType(): TKey { return this.children[0].type.children[0].type as TKey; }
    public get valueType(): TValue { return this.children[0].type.children[1].type as TValue; }
    public toString() { return `Map<{${this.children[0].type.children.map((f) => `${f.name}:${f.type}`).join(`, `)}}>`; }
    protected static [Symbol.toStringTag] = ((proto: Map_) => {
        (<any> proto).children = null;
        (<any> proto).keysSorted = null;
        return proto[Symbol.toStringTag] = 'Map_';
    })(Map_.prototype);
}

/** @ignore */
const getId = ((atomicDictionaryId) => () => ++atomicDictionaryId)(-1);

/** @ignore */
export type TKeys = Int8 | Int16 | Int32 | Uint8 | Uint16 | Uint32;

/** @ignore */
export interface Dictionary<T extends DataType = any, TKey extends TKeys = TKeys> extends DataType<Type.Dictionary> { TArray: TKey['TArray']; TValue: T['TValue'] }
/** @ignore */
export class Dictionary<T extends DataType = any, TKey extends TKeys = TKeys> extends DataType<Type.Dictionary> {
    public readonly id: number;
    public readonly indices: TKey;
    public readonly dictionary: T;
    public readonly isOrdered: boolean;
    constructor(dictionary: T, indices: TKey, id?: Long | number | null, isOrdered?: boolean | null) {
        super();
        this.indices = indices;
        this.dictionary = dictionary;
        this.isOrdered = isOrdered || false;
        this.id = id == null ? getId() : typeof id === 'number' ? id : id.low;
    }
    public get typeId() { return Type.Dictionary as Type.Dictionary; }
    public get children() { return this.dictionary.children; }
    public get valueType(): T { return this.dictionary as T; }
    public get ArrayType(): T['ArrayType'] { return this.dictionary.ArrayType; }
    public toString() { return `Dictionary<${this.indices}, ${this.dictionary}>`; }
    protected static [Symbol.toStringTag] = ((proto: Dictionary) => {
        (<any> proto).id = null;
        (<any> proto).indices = null;
        (<any> proto).isOrdered = null;
        (<any> proto).dictionary = null;
        return proto[Symbol.toStringTag] = 'Dictionary';
    })(Dictionary.prototype);
}

/** @ignore */
export interface IterableArrayLike<T = any> extends ArrayLike<T>, Iterable<T> {}
/** @ignore */
export type FloatArray = Uint16Array | Float32Array | Float64Array;
/** @ignore */
export type IntArray = Int8Array | Int16Array | Int32Array | Uint8Array | Uint16Array | Uint32Array;

/** @ignore */
export function strideForType(type: DataType) {
    const t: any = type;
    switch (type.typeId) {
        case Type.Decimal: return 4;
        case Type.Timestamp: return 2;
        case Type.Date: return 1 + (t as Date_).unit;
        case Type.Interval: return 1 + (t as Interval_).unit;
        case Type.Int: return 1 + +((t as Int_).bitWidth > 32);
        case Type.Time: return 1 + +((t as Time_).bitWidth > 32);
        case Type.FixedSizeList: return (t as FixedSizeList).listSize;
        case Type.FixedSizeBinary: return (t as FixedSizeBinary).byteWidth;
        default: return 1;
    }
}
