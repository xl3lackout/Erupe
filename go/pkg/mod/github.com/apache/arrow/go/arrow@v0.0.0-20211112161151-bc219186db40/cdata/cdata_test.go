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

// +build cgo
// +build test

// use test tag so that we only run these tests when the "test" tag is present
// so that the .c and other framework infrastructure is only compiled in during
// testing, and the .c files and symbols are not present in release builds.

package cdata

import (
	"io"
	"runtime"
	"testing"
	"time"
	"unsafe"

	"github.com/apache/arrow/go/arrow"
	"github.com/apache/arrow/go/arrow/array"
	"github.com/apache/arrow/go/arrow/decimal128"
	"github.com/apache/arrow/go/arrow/memory"
	"github.com/stretchr/testify/assert"
)

func TestSchemaExport(t *testing.T) {
	sc := exportInt32TypeSchema()
	f, err := importSchema(&sc)
	assert.NoError(t, err)

	keys, _ := getMetadataKeys()
	vals, _ := getMetadataValues()

	assert.Equal(t, arrow.PrimitiveTypes.Int32, f.Type)
	assert.Equal(t, keys, f.Metadata.Keys())
	assert.Equal(t, vals, f.Metadata.Values())

	// schema was released when importing
	assert.True(t, schemaIsReleased(&sc))
}

func TestSimpleArrayExport(t *testing.T) {
	assert.False(t, test1IsReleased())

	testarr := exportInt32Array()
	arr, err := ImportCArrayWithType(testarr, arrow.PrimitiveTypes.Int32)
	assert.NoError(t, err)

	assert.False(t, test1IsReleased())
	assert.True(t, isReleased(testarr))

	arr.Release()
	runtime.GC()
	assert.Eventually(t, test1IsReleased, 1*time.Second, 10*time.Millisecond)
}

func TestSimpleArrayAndSchema(t *testing.T) {
	sc := exportInt32TypeSchema()
	testarr := exportInt32Array()

	// grab address of the buffer we stuck into the ArrowArray object
	buflist := (*[2]unsafe.Pointer)(unsafe.Pointer(testarr.buffers))
	origvals := (*[10]int32)(unsafe.Pointer(buflist[1]))

	fld, arr, err := ImportCArray(testarr, &sc)
	assert.NoError(t, err)
	assert.Equal(t, arrow.PrimitiveTypes.Int32, fld.Type)
	assert.EqualValues(t, 10, arr.Len())

	// verify that the address is the same of the first integer for the
	// slice that is being used by the array.Interface and the original buffer
	vals := arr.(*array.Int32).Int32Values()
	assert.Same(t, &vals[0], &origvals[0])

	// and that the values are correct
	for i, v := range vals {
		assert.Equal(t, int32(i+1), v)
	}
}

func TestPrimitiveSchemas(t *testing.T) {
	tests := []struct {
		typ arrow.DataType
		fmt string
	}{
		{arrow.PrimitiveTypes.Int8, "c"},
		{arrow.PrimitiveTypes.Int16, "s"},
		{arrow.PrimitiveTypes.Int32, "i"},
		{arrow.PrimitiveTypes.Int64, "l"},
		{arrow.PrimitiveTypes.Uint8, "C"},
		{arrow.PrimitiveTypes.Uint16, "S"},
		{arrow.PrimitiveTypes.Uint32, "I"},
		{arrow.PrimitiveTypes.Uint64, "L"},
		{arrow.FixedWidthTypes.Boolean, "b"},
		{arrow.Null, "n"},
		{arrow.FixedWidthTypes.Float16, "e"},
		{arrow.PrimitiveTypes.Float32, "f"},
		{arrow.PrimitiveTypes.Float64, "g"},
		{&arrow.FixedSizeBinaryType{ByteWidth: 3}, "w:3"},
		{arrow.BinaryTypes.Binary, "z"},
		{arrow.BinaryTypes.String, "u"},
		{&arrow.Decimal128Type{Precision: 16, Scale: 4}, "d:16,4"},
		{&arrow.Decimal128Type{Precision: 15, Scale: 0}, "d:15,0"},
		{&arrow.Decimal128Type{Precision: 15, Scale: -4}, "d:15,-4"},
	}

	for _, tt := range tests {
		t.Run(tt.typ.Name(), func(t *testing.T) {
			sc := testPrimitive(tt.fmt)

			f, err := ImportCArrowField(&sc)
			assert.NoError(t, err)

			assert.True(t, arrow.TypeEqual(tt.typ, f.Type))

			assert.True(t, schemaIsReleased(&sc))
		})
	}
}

func TestImportTemporalSchema(t *testing.T) {
	tests := []struct {
		typ arrow.DataType
		fmt string
	}{
		{arrow.FixedWidthTypes.Date32, "tdD"},
		{arrow.FixedWidthTypes.Date64, "tdm"},
		{arrow.FixedWidthTypes.Time32s, "tts"},
		{arrow.FixedWidthTypes.Time32ms, "ttm"},
		{arrow.FixedWidthTypes.Time64us, "ttu"},
		{arrow.FixedWidthTypes.Time64ns, "ttn"},
		{arrow.FixedWidthTypes.Duration_s, "tDs"},
		{arrow.FixedWidthTypes.Duration_ms, "tDm"},
		{arrow.FixedWidthTypes.Duration_us, "tDu"},
		{arrow.FixedWidthTypes.Duration_ns, "tDn"},
		{arrow.FixedWidthTypes.MonthInterval, "tiM"},
		{arrow.FixedWidthTypes.DayTimeInterval, "tiD"},
		{arrow.FixedWidthTypes.MonthDayNanoInterval, "tin"},
		{arrow.FixedWidthTypes.Timestamp_s, "tss:"},
		{&arrow.TimestampType{Unit: arrow.Second, TimeZone: "Europe/Paris"}, "tss:Europe/Paris"},
		{arrow.FixedWidthTypes.Timestamp_ms, "tsm:"},
		{&arrow.TimestampType{Unit: arrow.Millisecond, TimeZone: "Europe/Paris"}, "tsm:Europe/Paris"},
		{arrow.FixedWidthTypes.Timestamp_us, "tsu:"},
		{&arrow.TimestampType{Unit: arrow.Microsecond, TimeZone: "Europe/Paris"}, "tsu:Europe/Paris"},
		{arrow.FixedWidthTypes.Timestamp_ns, "tsn:"},
		{&arrow.TimestampType{Unit: arrow.Nanosecond, TimeZone: "Europe/Paris"}, "tsn:Europe/Paris"},
	}

	for _, tt := range tests {
		t.Run(tt.typ.Name(), func(t *testing.T) {
			sc := testPrimitive(tt.fmt)

			f, err := ImportCArrowField(&sc)
			assert.NoError(t, err)

			assert.True(t, arrow.TypeEqual(tt.typ, f.Type))

			assert.True(t, schemaIsReleased(&sc))
		})
	}
}

func TestListSchemas(t *testing.T) {
	tests := []struct {
		typ    arrow.DataType
		fmts   []string
		names  []string
		isnull []bool
	}{
		{arrow.ListOf(arrow.PrimitiveTypes.Int8), []string{"+l", "c"}, []string{"", "item"}, []bool{true}},
		{arrow.FixedSizeListOfNonNullable(2, arrow.PrimitiveTypes.Int64), []string{"+w:2", "l"}, []string{"", "item"}, []bool{false}},
		{arrow.ListOfNonNullable(arrow.ListOf(arrow.PrimitiveTypes.Int32)), []string{"+l", "+l", "i"}, []string{"", "item", "item"}, []bool{false, true}},
	}

	for _, tt := range tests {
		t.Run(tt.typ.Name(), func(t *testing.T) {
			sc := testNested(tt.fmts, tt.names, tt.isnull)
			defer freeMallocedSchemas(sc)

			top := (*[1]*CArrowSchema)(unsafe.Pointer(sc))[0]
			f, err := ImportCArrowField(top)
			assert.NoError(t, err)

			assert.True(t, arrow.TypeEqual(tt.typ, f.Type))

			assert.True(t, schemaIsReleased(top))
		})
	}
}

func TestStructSchemas(t *testing.T) {
	tests := []struct {
		typ   arrow.DataType
		fmts  []string
		names []string
		flags []int64
	}{
		{arrow.StructOf(
			arrow.Field{Name: "a", Type: arrow.PrimitiveTypes.Int8, Nullable: true},
			arrow.Field{Name: "b", Type: arrow.BinaryTypes.String, Nullable: true, Metadata: metadata2},
		), []string{"+s", "c", "u"}, []string{"", "a", "b"}, []int64{flagIsNullable, flagIsNullable, flagIsNullable}},
	}

	for _, tt := range tests {
		t.Run(tt.typ.Name(), func(t *testing.T) {
			sc := testStruct(tt.fmts, tt.names, tt.flags)
			defer freeMallocedSchemas(sc)

			top := (*[1]*CArrowSchema)(unsafe.Pointer(sc))[0]
			f, err := ImportCArrowField(top)
			assert.NoError(t, err)

			assert.True(t, arrow.TypeEqual(tt.typ, f.Type))

			assert.True(t, schemaIsReleased(top))
		})
	}
}

func TestMapSchemas(t *testing.T) {
	tests := []struct {
		typ        *arrow.MapType
		keysSorted bool
		fmts       []string
		names      []string
		flags      []int64
	}{
		{arrow.MapOf(arrow.PrimitiveTypes.Int8, arrow.BinaryTypes.String), false, []string{"+m", "+s", "c", "u"}, []string{"", "entries", "key", "value"}, []int64{flagIsNullable, 0, 0, flagIsNullable}},
		{arrow.MapOf(arrow.PrimitiveTypes.Int8, arrow.BinaryTypes.String), true, []string{"+m", "+s", "c", "u"}, []string{"", "entries", "key", "value"}, []int64{flagIsNullable | flagMapKeysSorted, 0, 0, flagIsNullable}},
	}

	for _, tt := range tests {
		t.Run(tt.typ.Name(), func(t *testing.T) {
			sc := testMap(tt.fmts, tt.names, tt.flags)
			defer freeMallocedSchemas(sc)

			top := (*[1]*CArrowSchema)(unsafe.Pointer(sc))[0]
			f, err := ImportCArrowField(top)
			assert.NoError(t, err)

			tt.typ.KeysSorted = tt.keysSorted
			assert.True(t, arrow.TypeEqual(tt.typ, f.Type))

			assert.True(t, schemaIsReleased(top))
		})
	}
}

func TestSchema(t *testing.T) {
	// schema is exported as an equivalent struct type (+ top-level metadata)
	sc := arrow.NewSchema([]arrow.Field{
		{Name: "nulls", Type: arrow.Null, Nullable: false},
		{Name: "values", Type: arrow.PrimitiveTypes.Int64, Nullable: true, Metadata: metadata1},
	}, &metadata2)

	cst := testSchema([]string{"+s", "n", "l"}, []string{"", "nulls", "values"}, []int64{0, 0, flagIsNullable})
	defer freeMallocedSchemas(cst)

	top := (*[1]*CArrowSchema)(unsafe.Pointer(cst))[0]
	out, err := ImportCArrowSchema(top)
	assert.NoError(t, err)

	assert.True(t, sc.Equal(out))
	assert.True(t, sc.Metadata().Equal(out.Metadata()))

	assert.True(t, schemaIsReleased(top))
}

func createTestInt8Arr() array.Interface {
	bld := array.NewInt8Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]int8{1, 2, 0, -3}, []bool{true, true, false, true})
	return bld.NewInt8Array()
}

func createTestInt16Arr() array.Interface {
	bld := array.NewInt16Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]int16{1, 2, -3}, []bool{true, true, true})
	return bld.NewInt16Array()
}

func createTestInt32Arr() array.Interface {
	bld := array.NewInt32Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]int32{1, 2, 0, -3}, []bool{true, true, false, true})
	return bld.NewInt32Array()
}

func createTestInt64Arr() array.Interface {
	bld := array.NewInt64Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]int64{1, 2, -3}, []bool{true, true, true})
	return bld.NewInt64Array()
}

func createTestUint8Arr() array.Interface {
	bld := array.NewUint8Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]uint8{1, 2, 0, 3}, []bool{true, true, false, true})
	return bld.NewUint8Array()
}

func createTestUint16Arr() array.Interface {
	bld := array.NewUint16Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]uint16{1, 2, 3}, []bool{true, true, true})
	return bld.NewUint16Array()
}

func createTestUint32Arr() array.Interface {
	bld := array.NewUint32Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]uint32{1, 2, 0, 3}, []bool{true, true, false, true})
	return bld.NewUint32Array()
}

func createTestUint64Arr() array.Interface {
	bld := array.NewUint64Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]uint64{1, 2, 3}, []bool{true, true, true})
	return bld.NewUint64Array()
}

func createTestBoolArr() array.Interface {
	bld := array.NewBooleanBuilder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]bool{true, false, false}, []bool{true, true, false})
	return bld.NewBooleanArray()
}

func createTestNullArr() array.Interface {
	return array.NewNull(2)
}

func createTestFloat32Arr() array.Interface {
	bld := array.NewFloat32Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]float32{1.5, 0}, []bool{true, false})
	return bld.NewFloat32Array()
}

func createTestFloat64Arr() array.Interface {
	bld := array.NewFloat64Builder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]float64{1.5, 0}, []bool{true, false})
	return bld.NewFloat64Array()
}

func createTestFSBArr() array.Interface {
	bld := array.NewFixedSizeBinaryBuilder(memory.DefaultAllocator, &arrow.FixedSizeBinaryType{ByteWidth: 3})
	defer bld.Release()

	bld.AppendValues([][]byte{[]byte("foo"), []byte("bar"), nil}, []bool{true, true, false})
	return bld.NewFixedSizeBinaryArray()
}

func createTestBinaryArr() array.Interface {
	bld := array.NewBinaryBuilder(memory.DefaultAllocator, arrow.BinaryTypes.Binary)
	defer bld.Release()

	bld.AppendValues([][]byte{[]byte("foo"), []byte("bar"), nil}, []bool{true, true, false})
	return bld.NewBinaryArray()
}

func createTestStrArr() array.Interface {
	bld := array.NewStringBuilder(memory.DefaultAllocator)
	defer bld.Release()

	bld.AppendValues([]string{"foo", "bar", ""}, []bool{true, true, false})
	return bld.NewStringArray()
}

func createTestDecimalArr() array.Interface {
	bld := array.NewDecimal128Builder(memory.DefaultAllocator, &arrow.Decimal128Type{Precision: 16, Scale: 4})
	defer bld.Release()

	bld.AppendValues([]decimal128.Num{decimal128.FromU64(12345670), decimal128.FromU64(0)}, []bool{true, false})
	return bld.NewDecimal128Array()
}

func TestPrimitiveArrs(t *testing.T) {
	tests := []struct {
		name string
		fn   func() array.Interface
	}{
		{"int8", createTestInt8Arr},
		{"uint8", createTestUint8Arr},
		{"int16", createTestInt16Arr},
		{"uint16", createTestUint16Arr},
		{"int32", createTestInt32Arr},
		{"uint32", createTestUint32Arr},
		{"int64", createTestInt64Arr},
		{"uint64", createTestUint64Arr},
		{"bool", createTestBoolArr},
		{"null", createTestNullArr},
		{"float32", createTestFloat32Arr},
		{"float64", createTestFloat64Arr},
		{"fixed size binary", createTestFSBArr},
		{"binary", createTestBinaryArr},
		{"utf8", createTestStrArr},
		{"decimal128", createTestDecimalArr},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			arr := tt.fn()
			defer arr.Release()

			carr := createCArr(arr)
			defer freeTestArr(carr)

			imported, err := ImportCArrayWithType(carr, arr.DataType())
			assert.NoError(t, err)
			assert.True(t, array.ArrayEqual(arr, imported))
			assert.True(t, isReleased(carr))

			imported.Release()
		})
	}
}

func TestPrimitiveSliced(t *testing.T) {
	arr := createTestInt16Arr()
	defer arr.Release()

	sl := array.NewSlice(arr, 1, 2)
	defer sl.Release()

	carr := createCArr(sl)
	defer freeTestArr(carr)

	imported, err := ImportCArrayWithType(carr, arr.DataType())
	assert.NoError(t, err)
	assert.True(t, array.ArrayEqual(sl, imported))
	assert.True(t, array.ArraySliceEqual(arr, 1, 2, imported, 0, int64(imported.Len())))
	assert.True(t, isReleased(carr))

	imported.Release()
}

func createTestListArr() array.Interface {
	bld := array.NewListBuilder(memory.DefaultAllocator, arrow.PrimitiveTypes.Int8)
	defer bld.Release()

	vb := bld.ValueBuilder().(*array.Int8Builder)

	bld.Append(true)
	vb.AppendValues([]int8{1, 2}, []bool{true, true})

	bld.Append(true)
	vb.AppendValues([]int8{3, 0}, []bool{true, false})

	bld.AppendNull()

	return bld.NewArray()
}

func createTestFixedSizeList() array.Interface {
	bld := array.NewFixedSizeListBuilder(memory.DefaultAllocator, 2, arrow.PrimitiveTypes.Int64)
	defer bld.Release()

	vb := bld.ValueBuilder().(*array.Int64Builder)

	bld.Append(true)
	vb.AppendValues([]int64{1, 2}, []bool{true, true})

	bld.Append(true)
	vb.AppendValues([]int64{3, 0}, []bool{true, false})

	bld.AppendNull()
	return bld.NewArray()
}

func createTestStructArr() array.Interface {
	bld := array.NewStructBuilder(memory.DefaultAllocator, arrow.StructOf(
		arrow.Field{Name: "a", Type: arrow.PrimitiveTypes.Int8, Nullable: true},
		arrow.Field{Name: "b", Type: arrow.BinaryTypes.String, Nullable: true},
	))
	defer bld.Release()

	f1bld := bld.FieldBuilder(0).(*array.Int8Builder)
	f2bld := bld.FieldBuilder(1).(*array.StringBuilder)

	bld.Append(true)
	f1bld.Append(1)
	f2bld.Append("foo")

	bld.Append(true)
	f1bld.Append(2)
	f2bld.AppendNull()

	return bld.NewArray()
}

func createTestMapArr() array.Interface {
	bld := array.NewMapBuilder(memory.DefaultAllocator, arrow.PrimitiveTypes.Int8, arrow.BinaryTypes.String, false)
	defer bld.Release()

	kb := bld.KeyBuilder().(*array.Int8Builder)
	vb := bld.ItemBuilder().(*array.StringBuilder)

	bld.Append(true)
	kb.Append(1)
	vb.Append("foo")
	kb.Append(2)
	vb.AppendNull()

	bld.Append(true)
	kb.Append(3)
	vb.Append("bar")

	return bld.NewArray()
}

func TestNestedArrays(t *testing.T) {
	tests := []struct {
		name string
		fn   func() array.Interface
	}{
		{"list", createTestListArr},
		{"fixed size list", createTestFixedSizeList},
		{"struct", createTestStructArr},
		{"map", createTestMapArr},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			arr := tt.fn()
			defer arr.Release()

			carr := createCArr(arr)
			defer freeTestArr(carr)

			imported, err := ImportCArrayWithType(carr, arr.DataType())
			assert.NoError(t, err)
			assert.True(t, array.ArrayEqual(arr, imported))
			assert.True(t, isReleased(carr))

			imported.Release()
		})
	}
}

func TestRecordBatch(t *testing.T) {
	arr := createTestStructArr()
	defer arr.Release()

	carr := createCArr(arr)
	defer freeTestArr(carr)

	sc := testStruct([]string{"+s", "c", "u"}, []string{"", "a", "b"}, []int64{0, flagIsNullable, flagIsNullable})
	defer freeMallocedSchemas(sc)

	top := (*[1]*CArrowSchema)(unsafe.Pointer(sc))[0]
	rb, err := ImportCRecordBatch(carr, top)
	assert.NoError(t, err)
	defer rb.Release()

	assert.EqualValues(t, 2, rb.NumCols())
	rbschema := rb.Schema()
	assert.Equal(t, "a", rbschema.Field(0).Name)
	assert.Equal(t, "b", rbschema.Field(1).Name)

	rec := array.NewRecord(rbschema, []array.Interface{arr.(*array.Struct).Field(0), arr.(*array.Struct).Field(1)}, -1)
	defer rec.Release()

	assert.True(t, array.RecordEqual(rb, rec))
}

func TestRecordReaderStream(t *testing.T) {
	stream := arrayStreamTest()
	defer releaseStream(stream)

	rdr := ImportCArrayStream(stream, nil)
	i := 0
	for {
		rec, err := rdr.Read()
		if err != nil {
			if err == io.EOF {
				break
			}
			assert.NoError(t, err)
		}
		defer rec.Release()

		assert.EqualValues(t, 2, rec.NumCols())
		assert.Equal(t, "a", rec.ColumnName(0))
		assert.Equal(t, "b", rec.ColumnName(1))
		i++
		for j := 0; j < int(rec.NumRows()); j++ {
			assert.Equal(t, int32((j+1)*i), rec.Column(0).(*array.Int32).Value(j))
		}
		assert.Equal(t, "foo", rec.Column(1).(*array.String).Value(0))
		assert.Equal(t, "bar", rec.Column(1).(*array.String).Value(1))
		assert.Equal(t, "baz", rec.Column(1).(*array.String).Value(2))
	}
}
