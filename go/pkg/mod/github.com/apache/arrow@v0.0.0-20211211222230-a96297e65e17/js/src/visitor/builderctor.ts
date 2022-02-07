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
import { DataType } from '../type';
import { Visitor } from '../visitor';
import { VectorType, BuilderCtor } from '../interfaces';
import { BinaryBuilder } from '../builder/binary';
import { BoolBuilder } from '../builder/bool';
import { DateBuilder, DateDayBuilder, DateMillisecondBuilder } from '../builder/date';
import { DecimalBuilder } from '../builder/decimal';
import { DictionaryBuilder } from '../builder/dictionary';
import { FixedSizeBinaryBuilder } from '../builder/fixedsizebinary';
import { FixedSizeListBuilder } from '../builder/fixedsizelist';
import { FloatBuilder, Float16Builder, Float32Builder, Float64Builder } from '../builder/float';
import { IntervalBuilder, IntervalDayTimeBuilder, IntervalYearMonthBuilder } from '../builder/interval';
import { IntBuilder, Int8Builder, Int16Builder, Int32Builder, Int64Builder, Uint8Builder, Uint16Builder, Uint32Builder, Uint64Builder } from '../builder/int';
import { ListBuilder } from '../builder/list';
import { MapBuilder } from '../builder/map';
import { NullBuilder } from '../builder/null';
import { StructBuilder } from '../builder/struct';
import { TimestampBuilder, TimestampSecondBuilder, TimestampMillisecondBuilder, TimestampMicrosecondBuilder, TimestampNanosecondBuilder } from '../builder/timestamp';
import { TimeBuilder, TimeSecondBuilder, TimeMillisecondBuilder, TimeMicrosecondBuilder, TimeNanosecondBuilder } from '../builder/time';
import { UnionBuilder, DenseUnionBuilder, SparseUnionBuilder } from '../builder/union';
import { Utf8Builder } from '../builder/utf8';

/** @ignore */
export interface GetBuilderCtor extends Visitor {
    visit<T extends Type>(type: T): BuilderCtor<T>;
    visitMany<T extends Type>(types: T[]): BuilderCtor<T>[];
    getVisitFn<T extends Type>(type: T): () => BuilderCtor<T>;
    getVisitFn<T extends DataType>(node: VectorType<T> | Data<T> | T): () => BuilderCtor<T>;
}

/** @ignore */
export class GetBuilderCtor extends Visitor {
    public visitNull                 () { return NullBuilder;                 }
    public visitBool                 () { return BoolBuilder;                 }
    public visitInt                  () { return IntBuilder;                  }
    public visitInt8                 () { return Int8Builder;                 }
    public visitInt16                () { return Int16Builder;                }
    public visitInt32                () { return Int32Builder;                }
    public visitInt64                () { return Int64Builder;                }
    public visitUint8                () { return Uint8Builder;                }
    public visitUint16               () { return Uint16Builder;               }
    public visitUint32               () { return Uint32Builder;               }
    public visitUint64               () { return Uint64Builder;               }
    public visitFloat                () { return FloatBuilder;                }
    public visitFloat16              () { return Float16Builder;              }
    public visitFloat32              () { return Float32Builder;              }
    public visitFloat64              () { return Float64Builder;              }
    public visitUtf8                 () { return Utf8Builder;                 }
    public visitBinary               () { return BinaryBuilder;               }
    public visitFixedSizeBinary      () { return FixedSizeBinaryBuilder;      }
    public visitDate                 () { return DateBuilder;                 }
    public visitDateDay              () { return DateDayBuilder;              }
    public visitDateMillisecond      () { return DateMillisecondBuilder;      }
    public visitTimestamp            () { return TimestampBuilder;            }
    public visitTimestampSecond      () { return TimestampSecondBuilder;      }
    public visitTimestampMillisecond () { return TimestampMillisecondBuilder; }
    public visitTimestampMicrosecond () { return TimestampMicrosecondBuilder; }
    public visitTimestampNanosecond  () { return TimestampNanosecondBuilder;  }
    public visitTime                 () { return TimeBuilder;                 }
    public visitTimeSecond           () { return TimeSecondBuilder;           }
    public visitTimeMillisecond      () { return TimeMillisecondBuilder;      }
    public visitTimeMicrosecond      () { return TimeMicrosecondBuilder;      }
    public visitTimeNanosecond       () { return TimeNanosecondBuilder;       }
    public visitDecimal              () { return DecimalBuilder;              }
    public visitList                 () { return ListBuilder;                 }
    public visitStruct               () { return StructBuilder;               }
    public visitUnion                () { return UnionBuilder;                }
    public visitDenseUnion           () { return DenseUnionBuilder;           }
    public visitSparseUnion          () { return SparseUnionBuilder;          }
    public visitDictionary           () { return DictionaryBuilder;           }
    public visitInterval             () { return IntervalBuilder;             }
    public visitIntervalDayTime      () { return IntervalDayTimeBuilder;      }
    public visitIntervalYearMonth    () { return IntervalYearMonthBuilder;    }
    public visitFixedSizeList        () { return FixedSizeListBuilder;        }
    public visitMap                  () { return MapBuilder;                  }
}

/** @ignore */
export const instance = new GetBuilderCtor();
