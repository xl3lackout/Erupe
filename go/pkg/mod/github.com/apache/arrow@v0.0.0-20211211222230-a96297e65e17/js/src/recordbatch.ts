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

import { Data } from './data';
import { Table } from './table';
import { Vector } from './vector';
import { Visitor } from './visitor';
import { Schema, Field } from './schema';
import { isIterable } from './util/compat';
import { Chunked } from './vector/chunked';
import { selectFieldArgs } from './util/args';
import { DataType, Struct, Dictionary } from './type';
import { ensureSameLengthData } from './util/recordbatch';
import { Clonable, Sliceable, Applicative } from './vector';
import { StructVector, VectorBuilderOptions, VectorBuilderOptionsAsync } from './vector/index';

type VectorMap = { [key: string]: Vector };
type Fields<T extends { [key: string]: DataType }> = (keyof T)[] | Field<T[keyof T]>[];
type ChildData<T extends { [key: string]: DataType }> = (Data<T[keyof T]> | Vector<T[keyof T]>)[];

export interface RecordBatch<T extends { [key: string]: DataType } = any> {
    concat(...others: Vector<Struct<T>>[]): Table<T>;
    slice(begin?: number, end?: number): RecordBatch<T>;
    clone(data: Data<Struct<T>>, children?: Vector[]): RecordBatch<T>;
}

export class RecordBatch<T extends { [key: string]: DataType } = any>
    extends StructVector<T>
    implements Clonable<RecordBatch<T>>,
               Sliceable<RecordBatch<T>>,
               Applicative<Struct<T>, Table<T>> {

    public static from<T extends { [key: string]: DataType } = any, TNull = any>(options: VectorBuilderOptions<Struct<T>, TNull>): Table<T>;
    public static from<T extends { [key: string]: DataType } = any, TNull = any>(options: VectorBuilderOptionsAsync<Struct<T>, TNull>): Promise<Table<T>>;
    /** @nocollapse */
    public static from<T extends { [key: string]: DataType } = any, TNull = any>(options: VectorBuilderOptions<Struct<T>, TNull> | VectorBuilderOptionsAsync<Struct<T>, TNull>) {
        if (isIterable<(Struct<T>)['TValue'] | TNull>(options['values'])) {
            return Table.from(options as VectorBuilderOptions<Struct<T>, TNull>);
        }
        return Table.from(options as VectorBuilderOptionsAsync<Struct<T>, TNull>);
    }

    public static new<T extends VectorMap = any>(children: T): RecordBatch<{ [P in keyof T]: T[P]['type'] }>;
    public static new<T extends { [key: string]: DataType } = any>(children: ChildData<T>, fields?: Fields<T>): RecordBatch<T>;
    /** @nocollapse */
    public static new<T extends { [key: string]: DataType } = any>(...args: any[]) {
        const [fs, xs] = selectFieldArgs<T>(args);
        const vs = xs.filter((x): x is Vector<T[keyof T]> => x instanceof Vector);
        return new RecordBatch(...ensureSameLengthData(new Schema<T>(fs), vs.map((x) => x.data)));
    }

    protected _schema: Schema;
    protected _dictionaries?: Map<number, Vector>;

    constructor(schema: Schema<T>, length: number, children: (Data | Vector)[]);
    constructor(schema: Schema<T>, data: Data<Struct<T>>, children?: Vector[]);
    constructor(...args: any[]) {
        let data: Data<Struct<T>>;
        const schema = args[0] as Schema<T>;
        let children: Vector[] | undefined;
        if (args[1] instanceof Data) {
            [, data, children] = (args as [any, Data<Struct<T>>, Vector<T[keyof T]>[]?]);
        } else {
            const fields = schema.fields as Field<T[keyof T]>[];
            const [, length, childData] = args as [any, number, Data<T[keyof T]>[]];
            data = Data.Struct(new Struct<T>(fields), 0, length, 0, null, childData);
        }
        super(data, children);
        this._schema = schema;
    }

    public clone(data: Data<Struct<T>>, children = this._children) {
        return new RecordBatch<T>(this._schema, data, children);
    }

    public concat(...others: Vector<Struct<T>>[]): Table<T> {
        const schema = this._schema, chunks = Chunked.flatten(this, ...others);
        return new Table(schema, chunks.map(({ data }) => new RecordBatch(schema, data)));
    }

    public get schema() { return this._schema; }
    public get numCols() { return this._schema.fields.length; }
    public get dictionaries() {
        return this._dictionaries || (this._dictionaries = DictionaryCollector.collect(this));
    }

    public select<K extends keyof T = any>(...columnNames: K[]) {
        const nameToIndex = this._schema.fields.reduce((m, f, i) => m.set(f.name as K, i), new Map<K, number>());
        return this.selectAt(...columnNames.map((columnName) => nameToIndex.get(columnName)!).filter((x) => x > -1));
    }
    public selectAt<K extends T[keyof T] = any>(...columnIndices: number[]) {
        const schema = this._schema.selectAt(...columnIndices);
        const childData = columnIndices.map((i) => this.data.childData[i]).filter(Boolean);
        return new RecordBatch<{ [key: string]: K }>(schema, this.length, childData);
    }
}

/**
 * An internal class used by the `RecordBatchReader` and `RecordBatchWriter`
 * implementations to differentiate between a stream with valid zero-length
 * RecordBatches, and a stream with a Schema message, but no RecordBatches.
 * @see https://github.com/apache/arrow/pull/4373
 * @ignore
 * @private
 */
/* eslint-disable @typescript-eslint/naming-convention */
export class _InternalEmptyPlaceholderRecordBatch<T extends { [key: string]: DataType } = any> extends RecordBatch<T> {
    constructor(schema: Schema<T>) {
        super(schema, 0, schema.fields.map((f) => Data.new(f.type, 0, 0, 0)));
    }
}

/** @ignore */
class DictionaryCollector extends Visitor {
    public dictionaries = new Map<number, Vector>();
    public static collect<T extends RecordBatch>(batch: T) {
        return new DictionaryCollector().visit(
            batch.data, new Struct(batch.schema.fields)
        ).dictionaries;
    }
    public visit(data: Data, type: DataType) {
        if (DataType.isDictionary(type)) {
            return this.visitDictionary(data, type);
        } else {
            data.childData.forEach((child, i) =>
                this.visit(child, type.children[i].type));
        }
        return this;
    }
    public visitDictionary(data: Data, type: Dictionary) {
        const dictionary = data.dictionary;
        if (dictionary && dictionary.length > 0) {
            this.dictionaries.set(type.id, dictionary);
        }
        return this;
    }
}
