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

import { Column } from './column';
import { Data } from './data';
import { TypedArray, TypedArrayDataType } from './interfaces';
import { RecordBatchReader } from './ipc/reader';
import { RecordBatchFileWriter, RecordBatchStreamWriter } from './ipc/writer';
import { RecordBatch, _InternalEmptyPlaceholderRecordBatch } from './recordbatch';
import { Field, Schema } from './schema';
import { DataType, RowLike, Struct } from './type';
import { selectArgs, selectColumnArgs } from './util/args';
import { isAsyncIterable, isIterable, isPromise } from './util/compat';
import { distributeColumnsIntoRecordBatches, distributeVectorsIntoRecordBatches } from './util/recordbatch';
import { Applicative, Clonable, Sliceable } from './vector';
import { Chunked, StructVector, Vector, VectorBuilderOptions, VectorBuilderOptionsAsync } from './vector/index';

type VectorMap = { [key: string]: Vector | Exclude<TypedArray, Uint8ClampedArray> };
type Fields<T extends { [key: string]: DataType }> = (keyof T)[] | Field<T[keyof T]>[];
type ChildData<T extends { [key: string]: DataType }> = Data<T[keyof T]>[] | Vector<T[keyof T]>[];
type Columns<T extends { [key: string]: DataType }> = Column<T[keyof T]>[] | Column<T[keyof T]>[][];

export interface Table<T extends { [key: string]: DataType } = any> {

    get(index: number): Struct<T>['TValue'];
    [Symbol.iterator](): IterableIterator<RowLike<T>>;

    slice(begin?: number, end?: number): Table<T>;
    concat(...others: Vector<Struct<T>>[]): Table<T>;
    clone(chunks?: RecordBatch<T>[], offsets?: Uint32Array): Table<T>;
}

export class Table<T extends { [key: string]: DataType } = any>
    extends Chunked<Struct<T>>
    implements Clonable<Table<T>>,
               Sliceable<Table<T>>,
               Applicative<Struct<T>, Table<T>> {

    /** @nocollapse */
    public static empty<T extends { [key: string]: DataType } = Record<string, never>>(schema = new Schema<T>([])) { return new Table<T>(schema, []); }

    public static from(): Table<Record<string, never>>;
    public static from<T extends { [key: string]: DataType } = any>(source: RecordBatchReader<T>): Table<T>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg0): Table<T>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg2): Table<T>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg1): Promise<Table<T>>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg3): Promise<Table<T>>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg4): Promise<Table<T>>;
    public static from<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArg5): Promise<Table<T>>;
    public static from<T extends { [key: string]: DataType } = any>(source: PromiseLike<RecordBatchReader<T>>): Promise<Table<T>>;
    public static from<T extends { [key: string]: DataType } = any, TNull = any>(options: VectorBuilderOptions<Struct<T>, TNull>): Table<T>;
    public static from<T extends { [key: string]: DataType } = any, TNull = any>(options: VectorBuilderOptionsAsync<Struct<T>, TNull>): Promise<Table<T>>;
    /** @nocollapse */
    public static from<T extends { [key: string]: DataType } = any, TNull = any>(input?: any) {

        if (!input) { return Table.empty(); }

        if (typeof input === 'object') {
            const table = isIterable(input['values']) ? tableFromIterable<T, TNull>(input)
                 : isAsyncIterable(input['values']) ? tableFromAsyncIterable<T, TNull>(input)
                                                    : null;
            if (table !== null) { return table; }
        }

        let reader = RecordBatchReader.from<T>(input) as RecordBatchReader<T> | Promise<RecordBatchReader<T>>;

        if (isPromise<RecordBatchReader<T>>(reader)) {
            return (async () => await Table.from(await reader))();
        }
        if (reader.isSync() && (reader = reader.open())) {
            return !reader.schema ? Table.empty() : new Table<T>(reader.schema, [...reader]);
        }
        return (async (opening) => {
            const reader = await opening;
            const schema = reader.schema;
            const batches: RecordBatch[] = [];
            if (schema) {
                for await (const batch of reader) {
                    batches.push(batch);
                }
                return new Table<T>(schema, batches);
            }
            return Table.empty();
        })(reader.open());
    }

    /** @nocollapse */
    public static async fromAsync<T extends { [key: string]: DataType } = any>(source: import('./ipc/reader').FromArgs): Promise<Table<T>> {
        return await Table.from<T>(source as any);
    }

    /** @nocollapse */
    public static fromStruct<T extends { [key: string]: DataType } = any>(vector: Vector<Struct<T>>) {
        return Table.new<T>(vector.data.childData as Data<T[keyof T]>[], vector.type.children);
    }

    /**
     * @summary Create a new Table from a collection of Columns or Vectors,
     * with an optional list of names or Fields.
     *
     *
     * `Table.new` accepts an Object of
     * Columns or Vectors, where the keys will be used as the field names
     * for the Schema:
     * ```ts
     * const i32s = Int32Vector.from([1, 2, 3]);
     * const f32s = Float32Vector.from([.1, .2, .3]);
     * const table = Table.new({ i32: i32s, f32: f32s });
     * assert(table.schema.fields[0].name === 'i32');
     * ```
     *
     * It also accepts a a list of Vectors with an optional list of names or
     * Fields for the resulting Schema. If the list is omitted or a name is
     * missing, the numeric index of each Vector will be used as the name:
     * ```ts
     * const i32s = Int32Vector.from([1, 2, 3]);
     * const f32s = Float32Vector.from([.1, .2, .3]);
     * const table = Table.new([i32s, f32s], ['i32']);
     * assert(table.schema.fields[0].name === 'i32');
     * assert(table.schema.fields[1].name === '1');
     * ```
     *
     * If the supplied arguments are Columns, `Table.new` will infer the Schema
     * from the Columns:
     * ```ts
     * const i32s = Column.new('i32', Int32Vector.from([1, 2, 3]));
     * const f32s = Column.new('f32', Float32Vector.from([.1, .2, .3]));
     * const table = Table.new(i32s, f32s);
     * assert(table.schema.fields[0].name === 'i32');
     * assert(table.schema.fields[1].name === 'f32');
     * ```
     *
     * If the supplied Vector or Column lengths are unequal, `Table.new` will
     * extend the lengths of the shorter Columns, allocating additional bytes
     * to represent the additional null slots. The memory required to allocate
     * these additional bitmaps can be computed as:
     * ```ts
     * let additionalBytes = 0;
     * for (let vec in shorter_vectors) {
     *     additionalBytes += (((longestLength - vec.length) + 63) & ~63) >> 3;
     * }
     * ```
     *
     * For example, an additional null bitmap for one million null values would require
     * 125,000 bytes (`((1e6 + 63) & ~63) >> 3`), or approx. `0.11MiB`
     */
    public static new<T extends { [key: string]: DataType } = any>(...columns: Columns<T>): Table<T>;
    public static new<T extends VectorMap = any>(children: T): Table<{ [P in keyof T]: T[P] extends Vector ? T[P]['type'] : T[P] extends Exclude<TypedArray, Uint8ClampedArray> ? TypedArrayDataType<T[P]> : never}>;
    public static new<T extends { [key: string]: DataType } = any>(children: ChildData<T>, fields?: Fields<T>): Table<T>;
    /** @nocollapse */
    public static new(...cols: any[]) {
        return new Table(...distributeColumnsIntoRecordBatches(selectColumnArgs(cols)));
    }

    constructor(table: Table<T>);
    constructor(batches: RecordBatch<T>[]);
    constructor(...batches: RecordBatch<T>[]);
    constructor(schema: Schema<T>, batches: RecordBatch<T>[]);
    constructor(schema: Schema<T>, ...batches: RecordBatch<T>[]);
    constructor(...args: any[]) {

        let schema: Schema<T> = null!;

        if (args[0] instanceof Schema) { schema = args[0]; }

        const chunks = args[0] instanceof Table ? (args[0] as Table<T>).chunks : selectArgs<RecordBatch<T>>(RecordBatch, args);

        if (!schema && !(schema = chunks[0]?.schema)) {
            throw new TypeError('Table must be initialized with a Schema or at least one RecordBatch');
        }

        chunks[0] || (chunks[0] = new _InternalEmptyPlaceholderRecordBatch(schema));

        super(new Struct(schema.fields), chunks);

        this._schema = schema;
        this._chunks = chunks;
    }

    protected _schema: Schema<T>;
    // List of inner RecordBatches
    protected _chunks: RecordBatch<T>[];
    protected _children?: Column<T[keyof T]>[];

    public get schema() { return this._schema; }
    public get length() { return this._length; }
    public get chunks() { return this._chunks; }
    public get numCols() { return this._numChildren; }

    public clone(chunks = this._chunks) {
        return new Table<T>(this._schema, chunks);
    }

    public getColumn<R extends keyof T>(name: R): Column<T[R]> {
        return this.getColumnAt(this.getColumnIndex(name)) as Column<T[R]>;
    }
    public getColumnAt<R extends DataType = any>(index: number): Column<R> | null {
        return this.getChildAt(index);
    }
    public getColumnIndex<R extends keyof T>(name: R) {
        return this._schema.fields.findIndex((f) => f.name === name);
    }
    public getChildAt<R extends DataType = any>(index: number): Column<R> | null {
        if (index < 0 || index >= this.numChildren) { return null; }
        let field: Field<R>, child: Column<R>;
        const fields = (this._schema as Schema<any>).fields;
        const columns = this._children || (this._children = []) as Column[];
        if (child = columns[index]) { return child as Column<R>; }
        if (field = fields[index]) {
            const chunks = this._chunks
                .map((chunk) => chunk.getChildAt<R>(index))
                .filter((vec): vec is Vector<R> => vec != null);
            if (chunks.length > 0) {
                return (columns[index] = new Column<R>(field, chunks));
            }
        }
        return null;
    }

    // @ts-ignore
    public serialize(encoding = 'binary', stream = true) {
        const Writer = !stream
            ? RecordBatchFileWriter
            : RecordBatchStreamWriter;
        return Writer.writeAll(this).toUint8Array(true);
    }
    public count(): number {
        return this._length;
    }
    public select<K extends keyof T = any>(...columnNames: K[]) {
        const nameToIndex = this._schema.fields.reduce((m, f, i) => m.set(f.name as K, i), new Map<K, number>());
        return this.selectAt(...columnNames.map((columnName) => nameToIndex.get(columnName)!).filter((x) => x > -1));
    }
    public selectAt<K extends T[keyof T] = any>(...columnIndices: number[]) {
        const schema = this._schema.selectAt<K>(...columnIndices);
        return new Table(schema, this._chunks.map(({ length, data: { childData } }) => {
            return new RecordBatch(schema, length, columnIndices.map((i) => childData[i]).filter(Boolean));
        }));
    }
    public assign<R extends { [key: string]: DataType } = any>(other: Table<R>) {

        const fields = this._schema.fields;
        const [indices, oldToNew] = other.schema.fields.reduce((memo, f2, newIdx) => {
            const [indices, oldToNew] = memo;
            const i = fields.findIndex((f) => f.name === f2.name);
            ~i ? (oldToNew[i] = newIdx) : indices.push(newIdx);
            return memo;
        }, [[], []] as number[][]);

        const schema = this._schema.assign(other.schema);
        const columns = [
            ...fields.map((_f, i, _fs, j = oldToNew[i]) =>
                (j === undefined ? this.getColumnAt(i) : other.getColumnAt(j))!),
            ...indices.map((i) => other.getColumnAt(i)!)
        ].filter(Boolean) as Column<(T & R)[keyof T | keyof R]>[];

        return new Table<T & R>(...distributeVectorsIntoRecordBatches<any>(schema, columns));
    }
}

function tableFromIterable<T extends { [key: string]: DataType } = any, TNull = any>(input: VectorBuilderOptions<Struct<T>, TNull>) {
    const { type } = input;
    if (type instanceof Struct) {
        return Table.fromStruct(StructVector.from(input as VectorBuilderOptions<Struct<T>, TNull>));
    }
    return null;
}

function tableFromAsyncIterable<T extends { [key: string]: DataType } = any, TNull = any>(input: VectorBuilderOptionsAsync<Struct<T>, TNull>) {
    const { type } = input;
    if (type instanceof Struct) {
        return StructVector.from(input as VectorBuilderOptionsAsync<Struct<T>, TNull>).then((vector) => Table.fromStruct(vector));
    }
    return null;
}
