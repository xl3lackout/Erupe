﻿// Licensed to the Apache Software Foundation (ASF) under one or more
// contributor license agreements. See the NOTICE file distributed with
// this work for additional information regarding copyright ownership.
// The ASF licenses this file to You under the Apache License, Version 2.0
// (the "License"); you may not use this file except in compliance with
// the License.  You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

using System;
using System.Collections.Generic;

namespace Apache.Arrow
{
    public partial class Schema
    {
        public class Builder
        {
            private readonly List<Field> _fields;
            private Dictionary<string, string> _metadata;

            public Builder()
            {
                _fields = new List<Field>();
            }

            public Builder Clear()
            {
                _fields.Clear();
                _metadata?.Clear();
                return this;
            }

            public Builder Field(Field field)
            {
                if (field == null) return this;

                _fields.Add(field);
                return this;
            }

            public Builder Field(Action<Field.Builder> fieldBuilderAction)
            {
                if (fieldBuilderAction == null) return this;

                var fieldBuilder = new Field.Builder();
                fieldBuilderAction(fieldBuilder);
                Field field = fieldBuilder.Build();

                _fields.Add(field);
                return this;
            }

            public Builder Metadata(string key, string value)
            {
                if (string.IsNullOrWhiteSpace(key))
                {
                    throw new ArgumentNullException(nameof(key));
                }

                _metadata ??= new Dictionary<string, string>();

                _metadata[key] = value;
                return this;
            }

            public Builder Metadata(IEnumerable<KeyValuePair<string, string>> dictionary)
            {
                if (dictionary == null)
                {
                    throw new ArgumentNullException(nameof(dictionary));
                }
                foreach (KeyValuePair<string, string> entry in dictionary)
                {
                    Metadata(entry.Key, entry.Value);
                }
                return this;
            }

            public Schema Build()
            {
                return new Schema(_fields, _metadata);
            }
        }
    }
}
