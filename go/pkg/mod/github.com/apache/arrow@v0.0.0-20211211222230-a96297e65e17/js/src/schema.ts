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

import { DataType } from './type';

export class Schema<T extends { [key: string]: DataType } = any> {

    public readonly fields: Field<T[keyof T]>[];
    public readonly metadata: Map<string, string>;
    public readonly dictionaries: Map<number, DataType>;

    constructor(fields: Field[] = [],
                metadata?: Map<string, string> | null,
                dictionaries?: Map<number, DataType> | null) {
        this.fields = (fields || []) as Field<T[keyof T]>[];
        this.metadata = metadata || new Map();
        if (!dictionaries) {
            dictionaries = generateDictionaryMap(fields);
        }
        this.dictionaries = dictionaries;
    }
    public get [Symbol.toStringTag]() { return 'Schema'; }
    public toString() {
        return `Schema<{ ${this.fields.map((f, i) => `${i}: ${f}`).join(', ')} }>`;
    }

    public select<K extends keyof T = any>(...columnNames: K[]) {
        const names = columnNames.reduce((xs, x) => (xs[x] = true) && xs, Object.create(null));
        return new Schema<{ [P in K]: T[P] }>(this.fields.filter((f) => names[f.name]), this.metadata);
    }
    public selectAt<K extends T[keyof T] = any>(...columnIndices: number[]) {
        return new Schema<{ [key: string]: K }>(columnIndices.map((i) => this.fields[i]).filter(Boolean), this.metadata);
    }

    public assign<R extends { [key: string]: DataType } = any>(schema: Schema<R>): Schema<T & R>;
    public assign<R extends { [key: string]: DataType } = any>(...fields: (Field<R[keyof R]> | Field<R[keyof R]>[])[]): Schema<T & R>;
    public assign<R extends { [key: string]: DataType } = any>(...args: (Schema<R> | Field<R[keyof R]> | Field<R[keyof R]>[])[]) {

        const other = (args[0] instanceof Schema
            ? args[0] as Schema<R>
            : Array.isArray(args[0])
                ? new Schema<R>(<Field<R[keyof R]>[]> args[0])
                : new Schema<R>(<Field<R[keyof R]>[]> args));

        const curFields = [...this.fields] as Field[];
        const metadata = mergeMaps(mergeMaps(new Map(), this.metadata), other.metadata);
        const newFields = other.fields.filter((f2) => {
            const i = curFields.findIndex((f) => f.name === f2.name);
            return ~i ? (curFields[i] = f2.clone({
                metadata: mergeMaps(mergeMaps(new Map(), curFields[i].metadata), f2.metadata)
            })) && false : true;
        }) as Field[];

        const newDictionaries = generateDictionaryMap(newFields, new Map());

        return new Schema<T & R>(
            [...curFields, ...newFields], metadata,
            new Map([...this.dictionaries, ...newDictionaries])
        );
    }
}

export class Field<T extends DataType = any> {

    public static new<T extends DataType = any>(props: { name: string | number; type: T; nullable?: boolean; metadata?: Map<string, string> | null }): Field<T>;
    public static new<T extends DataType = any>(name: string | number | Field<T>, type: T, nullable?: boolean, metadata?: Map<string, string> | null): Field<T>;
    /** @nocollapse */
    public static new<T extends DataType = any>(...args: any[]) {
        let [name, type, nullable, metadata] = args;
        if (args[0] && typeof args[0] === 'object') {
            ({ name } = args[0]);
            (type === undefined) && (type = args[0].type);
            (nullable === undefined) && (nullable = args[0].nullable);
            (metadata === undefined) && (metadata = args[0].metadata);
        }
        return new Field<T>(`${name}`, type, nullable, metadata);
    }

    public readonly type: T;
    public readonly name: string;
    public readonly nullable: boolean;
    public readonly metadata: Map<string, string>;

    constructor(name: string, type: T, nullable = false, metadata?: Map<string, string> | null) {
        this.name = name;
        this.type = type;
        this.nullable = nullable;
        this.metadata = metadata || new Map();
    }

    public get typeId() { return this.type.typeId; }
    public get [Symbol.toStringTag]() { return 'Field'; }
    public toString() { return `${this.name}: ${this.type}`; }
    public clone<R extends DataType = T>(props: { name?: string | number; type?: R; nullable?: boolean; metadata?: Map<string, string> | null }): Field<R>;
    public clone<R extends DataType = T>(name?: string | number | Field<T>, type?: R, nullable?: boolean, metadata?: Map<string, string> | null): Field<R>;
    public clone<R extends DataType = T>(...args: any[]) {
        let [name, type, nullable, metadata] = args;
        (!args[0] || typeof args[0] !== 'object')
            ? ([name = this.name, type = this.type, nullable = this.nullable, metadata = this.metadata] = args)
            : ({name = this.name, type = this.type, nullable = this.nullable, metadata = this.metadata} = args[0]);
        return Field.new<R>(name, type, nullable, metadata);
    }
}

/** @ignore */
function mergeMaps<TKey, TVal>(m1?: Map<TKey, TVal> | null, m2?: Map<TKey, TVal> | null): Map<TKey, TVal> {
    return new Map([...(m1 || new Map()), ...(m2 || new Map())]);
}

/** @ignore */
function generateDictionaryMap(fields: Field[], dictionaries = new Map<number, DataType>()): Map<number, DataType> {

    for (let i = -1, n = fields.length; ++i < n;) {
        const field = fields[i];
        const type = field.type;
        if (DataType.isDictionary(type)) {
            if (!dictionaries.has(type.id)) {
                dictionaries.set(type.id, type.dictionary);
            } else if (dictionaries.get(type.id) !== type.dictionary) {
                throw new Error(`Cannot create Schema containing two different dictionaries with the same Id`);
            }
        }
        if (type.children && type.children.length > 0) {
            generateDictionaryMap(type.children, dictionaries);
        }
    }

    return dictionaries;
}

// Add these here so they're picked up by the externs creator
// in the build, and closure-compiler doesn't minify them away
(Schema.prototype as any).fields = null;
(Schema.prototype as any).metadata = null;
(Schema.prototype as any).dictionaries = null;

(Field.prototype as any).type = null;
(Field.prototype as any).name = null;
(Field.prototype as any).nullable = null;
(Field.prototype as any).metadata = null;
