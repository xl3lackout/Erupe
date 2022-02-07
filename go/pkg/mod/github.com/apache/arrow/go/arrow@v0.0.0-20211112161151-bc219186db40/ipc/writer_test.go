// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package ipc_test

import (
	"bytes"
	"fmt"
	"testing"

	"github.com/apache/arrow/go/arrow"
	"github.com/apache/arrow/go/arrow/array"
	"github.com/apache/arrow/go/arrow/ipc"
	"github.com/apache/arrow/go/arrow/memory"
	"github.com/stretchr/testify/assert"
)

// reproducer from ARROW-13529
func TestSliceAndWrite(t *testing.T) {
	alloc := memory.NewGoAllocator()
	schema := arrow.NewSchema([]arrow.Field{
		{Name: "s", Type: arrow.BinaryTypes.String},
	}, nil)

	b := array.NewRecordBuilder(alloc, schema)
	defer b.Release()

	b.Field(0).(*array.StringBuilder).AppendValues([]string{"foo", "bar", "baz"}, nil)
	rec := b.NewRecord()
	defer rec.Release()

	sliceAndWrite := func(rec array.Record, schema *arrow.Schema) {
		slice := rec.NewSlice(1, 2)
		defer slice.Release()

		fmt.Println(slice.Columns()[0].(*array.String).Value(0))

		var buf bytes.Buffer
		w := ipc.NewWriter(&buf, ipc.WithSchema(schema))
		w.Write(slice)
		w.Close()
	}

	assert.NotPanics(t, func() {
		for i := 0; i < 2; i++ {
			sliceAndWrite(rec, schema)
		}
	})
}
