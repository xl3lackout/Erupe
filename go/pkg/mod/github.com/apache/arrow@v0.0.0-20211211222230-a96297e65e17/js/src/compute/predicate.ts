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

import { Vector } from '../vector';
import { RecordBatch } from '../recordbatch';
import { DictionaryVector } from '../vector/dictionary';

/** @ignore */
export type ValueFunc<T> = (idx: number, cols: RecordBatch) => T | null;
/** @ignore */
export type PredicateFunc = (idx: number, cols: RecordBatch) => boolean;

/** @ignore */
export abstract class Value<T> {
    eq(other: Value<T> | T): Predicate {
        if (!(other instanceof Value)) { other = new Literal(other); }
        return new Equals(this, other);
    }
    le(other: Value<T> | T): Predicate {
        if (!(other instanceof Value)) { other = new Literal(other); }
        return new LTeq(this, other);
    }
    ge(other: Value<T> | T): Predicate {
        if (!(other instanceof Value)) { other = new Literal(other); }
        return new GTeq(this, other);
    }
    lt(other: Value<T> | T): Predicate {
        return new Not(this.ge(other));
    }
    gt(other: Value<T> | T): Predicate {
        return new Not(this.le(other));
    }
    ne(other: Value<T> | T): Predicate {
        return new Not(this.eq(other));
    }
}

/** @ignore */
export class Literal<T= any> extends Value<T> {
    constructor(public v: T) { super(); }
}

/** @ignore */
export class Col<T= any> extends Value<T> {
    public vector!: Vector;
    public colidx!: number;

    constructor(public name: string) { super(); }
    bind(batch: RecordBatch): (idx: number, batch?: RecordBatch) => any {
        if (!this.colidx) {
            // Assume column index doesn't change between calls to bind
            //this.colidx = cols.findIndex(v => v.name.indexOf(this.name) != -1);
            this.colidx = -1;
            const fields = batch.schema.fields;
            for (let idx = -1; ++idx < fields.length;) {
                if (fields[idx].name === this.name) {
                    this.colidx = idx;
                    break;
                }
            }
            if (this.colidx < 0) { throw new Error(`Failed to bind Col "${this.name}"`); }
        }

        const vec = this.vector = batch.getChildAt(this.colidx)!;
        return (idx: number) => vec.get(idx);
    }
}

/** @ignore */
export abstract class Predicate {
    abstract bind(batch: RecordBatch): PredicateFunc;
    and(...expr: Predicate[]): And { return new And(this, ...expr); }
    or(...expr: Predicate[]): Or { return new Or(this, ...expr); }
    not(): Predicate { return new Not(this); }
}

/** @ignore */
export abstract class ComparisonPredicate<T= any> extends Predicate {
    constructor(public readonly left: Value<T>, public readonly right: Value<T>) {
        super();
    }

    bind(batch: RecordBatch) {
        if (this.left instanceof Literal) {
            if (this.right instanceof Literal) {
                return this._bindLitLit(batch, this.left, this.right);
            } else { // right is a Col

                return this._bindLitCol(batch, this.left, this.right as Col);
            }
        } else { // left is a Col
            if (this.right instanceof Literal) {
                return this._bindColLit(batch, this.left as Col, this.right);
            } else { // right is a Col
                return this._bindColCol(batch, this.left as Col, this.right as Col);
            }
        }
    }

    protected abstract _bindLitLit(batch: RecordBatch, left: Literal, right: Literal): PredicateFunc;
    protected abstract _bindColCol(batch: RecordBatch, left: Col, right: Col): PredicateFunc;
    protected abstract _bindColLit(batch: RecordBatch, col: Col, lit: Literal): PredicateFunc;
    protected abstract _bindLitCol(batch: RecordBatch, lit: Literal, col: Col): PredicateFunc;
}

/** @ignore */
export abstract class CombinationPredicate extends Predicate {
    readonly children: Predicate[];
    constructor(...children: Predicate[]) {
        super();
        this.children = children;
    }
}
// add children to prototype so it doesn't get mangled in es2015/umd
(<any> CombinationPredicate.prototype).children = Object.freeze([]); // freeze for safety

/** @ignore */
export class And extends CombinationPredicate {
    constructor(...children: Predicate[]) {
        // Flatten any Ands
        children = children.reduce((accum: Predicate[], p: Predicate): Predicate[] => {
            return accum.concat(p instanceof And ? p.children : p);
        }, []);
        super(...children);
    }
    bind(batch: RecordBatch) {
        const bound = this.children.map((p) => p.bind(batch));
        return (idx: number, batch: RecordBatch) => bound.every((p) => p(idx, batch));
    }
}

/** @ignore */
export class Or extends CombinationPredicate {
    constructor(...children: Predicate[]) {
        // Flatten any Ors
        children = children.reduce((accum: Predicate[], p: Predicate): Predicate[] => {
            return accum.concat(p instanceof Or ? p.children : p);
        }, []);
        super(...children);
    }
    bind(batch: RecordBatch) {
        const bound = this.children.map((p) => p.bind(batch));
        return (idx: number, batch: RecordBatch) => bound.some((p) => p(idx, batch));
    }
}

/** @ignore */
export class Equals extends ComparisonPredicate {
    // Helpers used to cache dictionary reverse lookups between calls to bind
    private lastDictionary: Vector|undefined;
    private lastKey: number|undefined;

    protected _bindLitLit(_batch: RecordBatch, left: Literal, right: Literal): PredicateFunc {
        const rtrn: boolean = left.v == right.v;
        return () => rtrn;
    }

    protected _bindColCol(batch: RecordBatch, left: Col, right: Col): PredicateFunc {
        const left_func = left.bind(batch);
        const right_func = right.bind(batch);
        return (idx: number, batch: RecordBatch) => left_func(idx, batch) == right_func(idx, batch);
    }

    protected _bindColLit(batch: RecordBatch, col: Col, lit: Literal): PredicateFunc {
        const col_func = col.bind(batch);
        if (col.vector instanceof DictionaryVector) {
            let key: any;
            const vector = col.vector as DictionaryVector;
            if (vector.dictionary !== this.lastDictionary) {
                key = vector.reverseLookup(lit.v);
                this.lastDictionary = vector.dictionary;
                this.lastKey = key;
            } else {
                key = this.lastKey;
            }

            if (key === -1) {
                // the value doesn't exist in the dictionary - always return
                // false
                // TODO: special-case of PredicateFunc that encapsulates this
                // "always false" behavior. That way filtering operations don't
                // have to bother checking
                return () => false;
            } else {
                return (idx: number) => {
                    return vector.getKey(idx) === key;
                };
            }
        } else {
            return (idx: number, cols: RecordBatch) => col_func(idx, cols) == lit.v;
        }
    }

    protected _bindLitCol(batch: RecordBatch, lit: Literal, col: Col) {
        // Equals is commutative
        return this._bindColLit(batch, col, lit);
    }
}

/** @ignore */
export class LTeq extends ComparisonPredicate {
    protected _bindLitLit(_batch: RecordBatch, left: Literal, right: Literal): PredicateFunc {
        const rtrn: boolean = left.v <= right.v;
        return () => rtrn;
    }

    protected _bindColCol(batch: RecordBatch, left: Col, right: Col): PredicateFunc {
        const left_func = left.bind(batch);
        const right_func = right.bind(batch);
        return (idx: number, cols: RecordBatch) => left_func(idx, cols) <= right_func(idx, cols);
    }

    protected _bindColLit(batch: RecordBatch, col: Col, lit: Literal): PredicateFunc {
        const col_func = col.bind(batch);
        return (idx: number, cols: RecordBatch) => col_func(idx, cols) <= lit.v;
    }

    protected _bindLitCol(batch: RecordBatch, lit: Literal, col: Col) {
        const col_func = col.bind(batch);
        return (idx: number, cols: RecordBatch) => lit.v <= col_func(idx, cols);
    }
}

/** @ignore */
export class GTeq extends ComparisonPredicate {
    protected _bindLitLit(_batch: RecordBatch, left: Literal, right: Literal): PredicateFunc {
        const rtrn: boolean = left.v >= right.v;
        return () => rtrn;
    }

    protected _bindColCol(batch: RecordBatch, left: Col, right: Col): PredicateFunc {
        const left_func = left.bind(batch);
        const right_func = right.bind(batch);
        return (idx: number, cols: RecordBatch) => left_func(idx, cols) >= right_func(idx, cols);
    }

    protected _bindColLit(batch: RecordBatch, col: Col, lit: Literal): PredicateFunc {
        const col_func = col.bind(batch);
        return (idx: number, cols: RecordBatch) => col_func(idx, cols) >= lit.v;
    }

    protected _bindLitCol(batch: RecordBatch, lit: Literal, col: Col) {
        const col_func = col.bind(batch);
        return (idx: number, cols: RecordBatch) => lit.v >= col_func(idx, cols);
    }
}

/** @ignore */
export class Not extends Predicate {
    constructor(public readonly child: Predicate) {
        super();
    }

    bind(batch: RecordBatch) {
        const func = this.child.bind(batch);
        return (idx: number, batch: RecordBatch) => !func(idx, batch);
    }
}

/** @ignore */
export class CustomPredicate extends Predicate {
    constructor(private next: PredicateFunc, private bind_: (batch: RecordBatch) => void) {
        super();
    }

    bind(batch: RecordBatch) {
        this.bind_(batch);
        return this.next;
    }
}

export function lit(v: any): Value<any> { return new Literal(v); }
export function col(n: string): Col<any> { return new Col(n); }
export function and(...p: Predicate[]): And { return new And(...p); }
export function or(...p: Predicate[]): Or { return new Or(...p); }
export function custom(next: PredicateFunc, bind: (batch: RecordBatch) => void) {
    return new CustomPredicate(next, bind);
}
