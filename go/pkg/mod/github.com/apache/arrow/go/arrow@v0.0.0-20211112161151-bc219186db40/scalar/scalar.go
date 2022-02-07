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

package scalar

import (
	"encoding/binary"
	"fmt"
	"hash/maphash"
	"math"
	"math/big"
	"reflect"
	"strconv"
	"unsafe"

	"github.com/apache/arrow/go/arrow"
	"github.com/apache/arrow/go/arrow/array"
	"github.com/apache/arrow/go/arrow/bitutil"
	"github.com/apache/arrow/go/arrow/decimal128"
	"github.com/apache/arrow/go/arrow/endian"
	"github.com/apache/arrow/go/arrow/float16"
	"github.com/apache/arrow/go/arrow/internal/debug"
	"github.com/apache/arrow/go/arrow/memory"
	"golang.org/x/xerrors"
)

// Scalar represents a single value of a specific DataType as opposed to
// an array.
//
// Scalars are useful for passing single value inputs to compute functions
// (not yet implemented) or for representing individual array elements,
// (with a non-trivial cost though).
type Scalar interface {
	fmt.Stringer
	// IsValid returns true if the value is non-null, otherwise false.
	IsValid() bool
	// The datatype of the value in this scalar
	DataType() arrow.DataType
	// Performs cheap validation checks, returns nil if successful
	Validate() error
	// Perform more expensive validation checks, returns nil if successful
	ValidateFull() error
	// Cast the value to the desired DataType (returns an error if unable to do so)
	// should take semantics into account and modify the value accordingly.
	CastTo(arrow.DataType) (Scalar, error)

	// internal only functions for delegation
	value() interface{}
	equals(Scalar) bool
	//TODO(zeroshade): approxEquals
}

type Releasable interface {
	Release()
	Retain()
}

func validateOptional(s *scalar, value interface{}, valueDesc string) error {
	if s.Valid && value == nil {
		return xerrors.Errorf("%s scalar is marked valid but doesn't have a %s", s.Type, valueDesc)
	}
	if !s.Valid && value != nil && !reflect.ValueOf(value).IsNil() {
		return xerrors.Errorf("%s scalar is marked null but has a %s", s.Type, valueDesc)
	}
	return nil
}

type scalar struct {
	Type  arrow.DataType
	Valid bool
}

func (s *scalar) String() string {
	if !s.Valid {
		return "null"
	}

	return "..."
}

func (s *scalar) IsValid() bool { return s.Valid }

func (s *scalar) Validate() error {
	if s.Type == nil {
		return xerrors.New("scalar lacks a type")
	}
	return nil
}

func (s *scalar) ValidateFull() error {
	return s.Validate()
}

func (s scalar) DataType() arrow.DataType { return s.Type }

type Null struct {
	scalar
}

// by the time we get here we already know that the rhs is the right type
func (n *Null) equals(s Scalar) bool {
	debug.Assert(s.DataType().ID() == arrow.NULL, "scalar null equals should only receive null")
	return true
}

func (n *Null) value() interface{} { return nil }

func (n *Null) CastTo(dt arrow.DataType) (Scalar, error) {
	return MakeNullScalar(dt), nil
}

func (n *Null) Validate() (err error) {
	err = n.scalar.Validate()
	if err != nil {
		return
	}
	if n.Valid {
		err = xerrors.New("null scalar should have Valid = false")
	}
	return
}

func (n *Null) ValidateFull() error { return n.Validate() }

var (
	ScalarNull *Null = &Null{scalar{Type: arrow.Null, Valid: false}}
)

type PrimitiveScalar interface {
	Scalar
	Data() []byte
}

type Boolean struct {
	scalar
	Value bool
}

// by the time we get here we already know that the rhs is the right type
func (n *Boolean) equals(rhs Scalar) bool {
	return n.Value == rhs.(*Boolean).Value
}

func (s *Boolean) value() interface{} { return s.Value }

func (s *Boolean) Data() []byte {
	return (*[1]byte)(unsafe.Pointer(&s.Value))[:]
}

func (s *Boolean) String() string {
	if !s.Valid {
		return "null"
	}
	val, err := s.CastTo(arrow.BinaryTypes.String)
	if err != nil {
		return "..."
	}
	return string(val.(*String).Value.Bytes())
}

func (s *Boolean) CastTo(dt arrow.DataType) (Scalar, error) {
	if !s.Valid {
		return MakeNullScalar(dt), nil
	}

	if dt.ID() == arrow.STRING {
		return NewStringScalar(strconv.FormatBool(s.Value)), nil
	}

	val := 0
	if s.Value {
		val = 1
	}

	switch dt.ID() {
	case arrow.UINT8:
		return NewUint8Scalar(uint8(val)), nil
	case arrow.INT8:
		return NewInt8Scalar(int8(val)), nil
	case arrow.UINT16:
		return NewUint16Scalar(uint16(val)), nil
	case arrow.INT16:
		return NewInt16Scalar(int16(val)), nil
	case arrow.UINT32:
		return NewUint32Scalar(uint32(val)), nil
	case arrow.INT32:
		return NewInt32Scalar(int32(val)), nil
	case arrow.UINT64:
		return NewUint64Scalar(uint64(val)), nil
	case arrow.INT64:
		return NewInt64Scalar(int64(val)), nil
	case arrow.FLOAT16:
		return NewFloat16Scalar(float16.New(float32(val))), nil
	case arrow.FLOAT32:
		return NewFloat32Scalar(float32(val)), nil
	case arrow.FLOAT64:
		return NewFloat64Scalar(float64(val)), nil
	default:
		return nil, xerrors.Errorf("invalid scalar cast from type bool to type %s", dt)
	}
}

func NewBooleanScalar(val bool) *Boolean {
	return &Boolean{scalar{arrow.FixedWidthTypes.Boolean, true}, val}
}

type Float16 struct {
	scalar
	Value float16.Num
}

func (s *Float16) value() interface{} { return s.Value }

func (f *Float16) Data() []byte {
	return (*[arrow.Float16SizeBytes]byte)(unsafe.Pointer(&f.Value))[:]
}
func (f *Float16) equals(rhs Scalar) bool {
	return f.Value == rhs.(*Float16).Value
}
func (f *Float16) CastTo(to arrow.DataType) (Scalar, error) {
	if !f.Valid {
		return MakeNullScalar(to), nil
	}

	if r, ok := numericMap[to.ID()]; ok {
		return convertToNumeric(reflect.ValueOf(f.Value.Float32()), r.valueType, r.scalarFunc), nil
	}

	if to.ID() == arrow.BOOL {
		return NewBooleanScalar(f.Value.Uint16() != 0), nil
	} else if to.ID() == arrow.STRING {
		return NewStringScalar(f.Value.String()), nil
	}

	return nil, xerrors.Errorf("cannot cast non-null float16 scalar to type %s", to)
}

func (s *Float16) String() string {
	if !s.Valid {
		return "null"
	}
	val, err := s.CastTo(arrow.BinaryTypes.String)
	if err != nil {
		return "..."
	}
	return string(val.(*String).Value.Bytes())
}

func NewFloat16ScalarFromFloat32(val float32) *Float16 {
	return NewFloat16Scalar(float16.New(val))
}

func NewFloat16Scalar(val float16.Num) *Float16 {
	return &Float16{scalar{arrow.FixedWidthTypes.Float16, true}, val}
}

type Decimal128 struct {
	scalar
	Value decimal128.Num
}

func (s *Decimal128) value() interface{} { return s.Value }

func (s *Decimal128) String() string {
	if !s.Valid {
		return "null"
	}
	val, err := s.CastTo(arrow.BinaryTypes.String)
	if err != nil {
		return "..."
	}
	return string(val.(*String).Value.Bytes())
}

func (s *Decimal128) equals(rhs Scalar) bool {
	return s.Value == rhs.(*Decimal128).Value
}

func (s *Decimal128) CastTo(to arrow.DataType) (Scalar, error) {
	if !s.Valid {
		return MakeNullScalar(to), nil
	}

	switch to.ID() {
	case arrow.DECIMAL128:
		return NewDecimal128Scalar(s.Value, to), nil
	case arrow.STRING:
		dt := s.Type.(*arrow.Decimal128Type)
		scale := big.NewFloat(math.Pow10(int(dt.Scale)))
		val := (&big.Float{}).SetInt(s.Value.BigInt())
		return NewStringScalar(val.Quo(val, scale).Text('g', int(dt.Precision))), nil
	}

	return nil, xerrors.Errorf("cannot cast non-nil decimal128 scalar to type %s", to)
}

func NewDecimal128Scalar(val decimal128.Num, typ arrow.DataType) *Decimal128 {
	return &Decimal128{scalar{typ, true}, val}
}

type Extension struct {
	scalar
	Value Scalar
}

func (s *Extension) value() interface{} { return s.Value }
func (s *Extension) equals(rhs Scalar) bool {
	return Equals(s.Value, rhs.(*Extension).Value)
}
func (e *Extension) Validate() (err error) {
	if err = e.scalar.Validate(); err != nil {
		return err
	}

	if !e.Valid {
		if e.Value != nil {
			err = xerrors.Errorf("null %s scalar has storage value", e.Type)
		}
		return
	}

	switch {
	case e.Value == nil:
		err = xerrors.Errorf("non-null %s scalar doesn't have a storage value", e.Type)
	case !e.Value.IsValid():
		err = xerrors.Errorf("non-null %s scalar has a null storage value", e.Type)
	default:
		if err = e.Value.Validate(); err != nil {
			err = xerrors.Errorf("%s scalar fails validation for storage value: %w", e.Type, err)
		}
	}
	return
}

func (e *Extension) ValidateFull() error {
	if err := e.Validate(); err != nil {
		return err
	}

	if e.Valid {
		return e.Value.ValidateFull()
	}
	return nil
}

func (s *Extension) CastTo(to arrow.DataType) (Scalar, error) {
	if !s.Valid {
		return MakeNullScalar(to), nil
	}

	if arrow.TypeEqual(s.Type, to) {
		return s, nil
	}

	return nil, xerrors.Errorf("cannot cast non-null extension scalar of type %s to type %s", s.Type, to)
}

func (s *Extension) String() string {
	if !s.Valid {
		return "null"
	}
	val, err := s.CastTo(arrow.BinaryTypes.String)
	if err != nil {
		return "..."
	}
	return string(val.(*String).Value.Bytes())
}

func NewExtensionScalar(storage Scalar, typ arrow.DataType) *Extension {
	return &Extension{scalar{typ, true}, storage}
}

func convertToNumeric(v reflect.Value, to reflect.Type, fn reflect.Value) Scalar {
	return fn.Call([]reflect.Value{v.Convert(to)})[0].Interface().(Scalar)
}

// MakeNullScalar creates a scalar value of the desired type representing a null value
func MakeNullScalar(dt arrow.DataType) Scalar {
	return makeNullFn[byte(dt.ID()&0x3f)](dt)
}

func unsupportedScalarType(dt arrow.DataType) Scalar {
	panic("unsupported scalar data type: " + dt.ID().String())
}

func invalidScalarType(dt arrow.DataType) Scalar {
	panic("invalid scalar type: " + dt.ID().String())
}

type scalarMakeNullFn func(arrow.DataType) Scalar

var makeNullFn [64]scalarMakeNullFn

func init() {
	makeNullFn = [...]scalarMakeNullFn{
		arrow.NULL:              func(dt arrow.DataType) Scalar { return ScalarNull },
		arrow.BOOL:              func(dt arrow.DataType) Scalar { return &Boolean{scalar: scalar{dt, false}} },
		arrow.UINT8:             func(dt arrow.DataType) Scalar { return &Uint8{scalar: scalar{dt, false}} },
		arrow.INT8:              func(dt arrow.DataType) Scalar { return &Int8{scalar: scalar{dt, false}} },
		arrow.UINT16:            func(dt arrow.DataType) Scalar { return &Uint16{scalar: scalar{dt, false}} },
		arrow.INT16:             func(dt arrow.DataType) Scalar { return &Int16{scalar: scalar{dt, false}} },
		arrow.UINT32:            func(dt arrow.DataType) Scalar { return &Uint32{scalar: scalar{dt, false}} },
		arrow.INT32:             func(dt arrow.DataType) Scalar { return &Int32{scalar: scalar{dt, false}} },
		arrow.UINT64:            func(dt arrow.DataType) Scalar { return &Uint64{scalar: scalar{dt, false}} },
		arrow.INT64:             func(dt arrow.DataType) Scalar { return &Int64{scalar: scalar{dt, false}} },
		arrow.FLOAT16:           func(dt arrow.DataType) Scalar { return &Float16{scalar: scalar{dt, false}} },
		arrow.FLOAT32:           func(dt arrow.DataType) Scalar { return &Float32{scalar: scalar{dt, false}} },
		arrow.FLOAT64:           func(dt arrow.DataType) Scalar { return &Float64{scalar: scalar{dt, false}} },
		arrow.STRING:            func(dt arrow.DataType) Scalar { return &String{&Binary{scalar: scalar{dt, false}}} },
		arrow.BINARY:            func(dt arrow.DataType) Scalar { return &Binary{scalar: scalar{dt, false}} },
		arrow.FIXED_SIZE_BINARY: func(dt arrow.DataType) Scalar { return &FixedSizeBinary{&Binary{scalar: scalar{dt, false}}} },
		arrow.DATE32:            func(dt arrow.DataType) Scalar { return &Date32{scalar: scalar{dt, false}} },
		arrow.DATE64:            func(dt arrow.DataType) Scalar { return &Date64{scalar: scalar{dt, false}} },
		arrow.TIMESTAMP:         func(dt arrow.DataType) Scalar { return &Timestamp{scalar: scalar{dt, false}} },
		arrow.TIME32:            func(dt arrow.DataType) Scalar { return &Time32{scalar: scalar{dt, false}} },
		arrow.TIME64:            func(dt arrow.DataType) Scalar { return &Time64{scalar: scalar{dt, false}} },
		arrow.INTERVAL: func(dt arrow.DataType) Scalar {
			if arrow.TypeEqual(dt, arrow.FixedWidthTypes.MonthInterval) {
				return &MonthInterval{scalar: scalar{dt, false}}
			}
			if arrow.TypeEqual(dt, arrow.FixedWidthTypes.MonthDayNanoInterval) {
				return &MonthDayNanoInterval{scalar: scalar{dt, false}}
			}
			return &DayTimeInterval{scalar: scalar{dt, false}}
		},
		arrow.INTERVAL_MONTHS:         func(dt arrow.DataType) Scalar { return &MonthInterval{scalar: scalar{dt, false}} },
		arrow.INTERVAL_DAY_TIME:       func(dt arrow.DataType) Scalar { return &DayTimeInterval{scalar: scalar{dt, false}} },
		arrow.INTERVAL_MONTH_DAY_NANO: func(dt arrow.DataType) Scalar { return &MonthDayNanoInterval{scalar: scalar{dt, false}} },
		arrow.DECIMAL128:              func(dt arrow.DataType) Scalar { return &Decimal128{scalar: scalar{dt, false}} },
		arrow.LIST:                    func(dt arrow.DataType) Scalar { return &List{scalar: scalar{dt, false}} },
		arrow.STRUCT:                  func(dt arrow.DataType) Scalar { return &Struct{scalar: scalar{dt, false}} },
		arrow.SPARSE_UNION:            unsupportedScalarType,
		arrow.DENSE_UNION:             unsupportedScalarType,
		arrow.DICTIONARY:              unsupportedScalarType,
		arrow.LARGE_STRING:            unsupportedScalarType,
		arrow.LARGE_BINARY:            unsupportedScalarType,
		arrow.LARGE_LIST:              unsupportedScalarType,
		arrow.DECIMAL256:              unsupportedScalarType,
		arrow.MAP:                     func(dt arrow.DataType) Scalar { return &Map{&List{scalar: scalar{dt, false}}} },
		arrow.EXTENSION:               func(dt arrow.DataType) Scalar { return &Extension{scalar: scalar{dt, false}} },
		arrow.FIXED_SIZE_LIST:         func(dt arrow.DataType) Scalar { return &FixedSizeList{&List{scalar: scalar{dt, false}}} },
		arrow.DURATION:                func(dt arrow.DataType) Scalar { return &Duration{scalar: scalar{dt, false}} },
		// invalid data types to fill out array size 2^6 - 1
		63: invalidScalarType,
	}

	f := numericMap[arrow.FLOAT16]
	f.scalarFunc = reflect.ValueOf(NewFloat16ScalarFromFloat32)
	f.valueType = reflect.TypeOf(float32(0))
	numericMap[arrow.FLOAT16] = f
}

// GetScalar creates a scalar object from the value at a given index in the
// passed in array, returns an error if unable to do so.
func GetScalar(arr array.Interface, idx int) (Scalar, error) {
	switch arr := arr.(type) {
	case *array.Binary:
		buf := memory.NewBufferBytes(arr.Value(idx))
		defer buf.Release()
		return NewBinaryScalar(buf, arr.DataType()), nil
	case *array.Boolean:
		return NewBooleanScalar(arr.Value(idx)), nil
	case *array.Date32:
		return NewDate32Scalar(arr.Value(idx)), nil
	case *array.Date64:
		return NewDate64Scalar(arr.Value(idx)), nil
	case *array.DayTimeInterval:
		return NewDayTimeIntervalScalar(arr.Value(idx)), nil
	case *array.Decimal128:
		return NewDecimal128Scalar(arr.Value(idx), arr.DataType()), nil
	case *array.Duration:
		return NewDurationScalar(arr.Value(idx), arr.DataType()), nil
	case array.ExtensionArray:
		storage, err := GetScalar(arr.Storage(), idx)
		if err != nil {
			return nil, err
		}
		return NewExtensionScalar(storage, arr.DataType()), nil
	case *array.FixedSizeBinary:
		buf := memory.NewBufferBytes(arr.Value(idx))
		defer buf.Release()
		return NewFixedSizeBinaryScalar(buf, arr.DataType()), nil
	case *array.FixedSizeList:
		size := int(arr.DataType().(*arrow.FixedSizeListType).Len())
		slice := array.NewSlice(arr.ListValues(), int64(idx*size), int64((idx+1)*size))
		defer slice.Release()
		return NewFixedSizeListScalarWithType(slice, arr.DataType()), nil
	case *array.Float16:
		return NewFloat16Scalar(arr.Value(idx)), nil
	case *array.Float32:
		return NewFloat32Scalar(arr.Value(idx)), nil
	case *array.Float64:
		return NewFloat64Scalar(arr.Value(idx)), nil
	case *array.Int8:
		return NewInt8Scalar(arr.Value(idx)), nil
	case *array.Int16:
		return NewInt16Scalar(arr.Value(idx)), nil
	case *array.Int32:
		return NewInt32Scalar(arr.Value(idx)), nil
	case *array.Int64:
		return NewInt64Scalar(arr.Value(idx)), nil
	case *array.Uint8:
		return NewUint8Scalar(arr.Value(idx)), nil
	case *array.Uint16:
		return NewUint16Scalar(arr.Value(idx)), nil
	case *array.Uint32:
		return NewUint32Scalar(arr.Value(idx)), nil
	case *array.Uint64:
		return NewUint64Scalar(arr.Value(idx)), nil
	case *array.List:
		offsets := arr.Offsets()
		slice := array.NewSlice(arr.ListValues(), int64(offsets[idx]), int64(offsets[idx+1]))
		defer slice.Release()
		return NewListScalar(slice), nil
	case *array.Map:
		offsets := arr.Offsets()
		slice := array.NewSlice(arr.ListValues(), int64(offsets[idx]), int64(offsets[idx+1]))
		defer slice.Release()
		return NewMapScalar(slice), nil
	case *array.MonthInterval:
		return NewMonthIntervalScalar(arr.Value(idx)), nil
	case *array.MonthDayNanoInterval:
		return NewMonthDayNanoIntervalScalar(arr.Value(idx)), nil
	case *array.Null:
		return ScalarNull, nil
	case *array.String:
		return NewStringScalar(arr.Value(idx)), nil
	case *array.Struct:
		children := make(Vector, arr.NumField())
		for i := range children {
			child, err := GetScalar(arr.Field(i), idx)
			if err != nil {
				return nil, err
			}
			children[i] = child
		}
		return NewStructScalar(children, arr.DataType()), nil
	case *array.Time32:
		return NewTime32Scalar(arr.Value(idx), arr.DataType()), nil
	case *array.Time64:
		return NewTime64Scalar(arr.Value(idx), arr.DataType()), nil
	case *array.Timestamp:
		return NewTimestampScalar(arr.Value(idx), arr.DataType()), nil
	}

	return nil, xerrors.Errorf("cannot create scalar from array of type %s", arr.DataType())
}

// MakeArrayOfNull creates an array of size length which is all null of the given data type.
func MakeArrayOfNull(dt arrow.DataType, length int, mem memory.Allocator) array.Interface {
	nullBuf := memory.NewResizableBuffer(mem)
	nullBuf.Resize(int(bitutil.BytesForBits(int64(length))))
	defer nullBuf.Release()
	memory.Set(nullBuf.Bytes(), 0xFF)

	data := array.NewData(dt, length, []*memory.Buffer{nullBuf, nil}, nil, length, 0)
	defer data.Release()
	return array.MakeFromData(data)
}

// MakeArrayFromScalar returns an array filled with the scalar value repeated length times.
// Not yet implemented for nested types such as Struct, List, extension and so on.
func MakeArrayFromScalar(sc Scalar, length int, mem memory.Allocator) (array.Interface, error) {
	if !sc.IsValid() {
		return MakeArrayOfNull(sc.DataType(), length, mem), nil
	}

	createOffsets := func(valLength int32) *memory.Buffer {
		buffer := memory.NewResizableBuffer(mem)
		buffer.Resize(arrow.Int32Traits.BytesRequired(length + 1))

		out := arrow.Int32Traits.CastFromBytes(buffer.Bytes())
		for i, offset := 0, int32(0); i < length+1; i, offset = i+1, offset+valLength {
			out[i] = offset
		}
		return buffer
	}

	createBuffer := func(data []byte) *memory.Buffer {
		buffer := memory.NewResizableBuffer(mem)
		buffer.Resize(len(data) * length)

		out := buffer.Bytes()
		copy(out, data)
		for j := len(data); j < len(out); j *= 2 {
			copy(out[j:], out[:j])
		}
		return buffer
	}

	finishFixedWidth := func(data []byte) *array.Data {
		buffer := createBuffer(data)
		defer buffer.Release()
		return array.NewData(sc.DataType(), length, []*memory.Buffer{nil, buffer}, nil, 0, 0)
	}

	switch s := sc.(type) {
	case *Boolean:
		data := memory.NewResizableBuffer(mem)
		defer data.Release()
		data.Resize(int(bitutil.BytesForBits(int64(length))))
		c := byte(0x00)
		if s.Value {
			c = 0xFF
		}
		memory.Set(data.Bytes(), c)
		defer data.Release()
		return array.NewBoolean(length, data, nil, 0), nil
	case BinaryScalar:
		if s.DataType().ID() == arrow.FIXED_SIZE_BINARY {
			data := finishFixedWidth(s.Data())
			defer data.Release()
			return array.MakeFromData(data), nil
		}

		valuesBuf := createBuffer(s.Data())
		offsetsBuf := createOffsets(int32(len(s.Data())))
		data := array.NewData(sc.DataType(), length, []*memory.Buffer{nil, offsetsBuf, valuesBuf}, nil, 0, 0)
		defer func() {
			valuesBuf.Release()
			offsetsBuf.Release()
			data.Release()
		}()
		return array.MakeFromData(data), nil
	case PrimitiveScalar:
		data := finishFixedWidth(s.Data())
		defer data.Release()
		return array.MakeFromData(data), nil
	case *Decimal128:
		data := finishFixedWidth(arrow.Decimal128Traits.CastToBytes([]decimal128.Num{s.Value}))
		defer data.Release()
		return array.MakeFromData(data), nil
	case *List:
		values := make([]array.Interface, length)
		for i := range values {
			values[i] = s.Value
		}

		valueArray, err := array.Concatenate(values, mem)
		if err != nil {
			return nil, err
		}
		defer valueArray.Release()

		offsetsBuf := createOffsets(int32(s.Value.Len()))
		defer offsetsBuf.Release()
		data := array.NewData(s.DataType(), length, []*memory.Buffer{nil, offsetsBuf}, []*array.Data{valueArray.Data()}, 0, 0)
		defer data.Release()
		return array.MakeFromData(data), nil
	case *FixedSizeList:
		values := make([]array.Interface, length)
		for i := range values {
			values[i] = s.Value
		}

		valueArray, err := array.Concatenate(values, mem)
		if err != nil {
			return nil, err
		}
		defer valueArray.Release()

		data := array.NewData(s.DataType(), length, []*memory.Buffer{nil}, []*array.Data{valueArray.Data()}, 0, 0)
		defer data.Release()
		return array.MakeFromData(data), nil
	case *Struct:
		fields := make([]*array.Data, 0)
		for _, v := range s.Value {
			arr, err := MakeArrayFromScalar(v, length, mem)
			if err != nil {
				return nil, err
			}
			defer arr.Release()
			fields = append(fields, arr.Data())
		}

		data := array.NewData(s.DataType(), length, []*memory.Buffer{nil}, fields, 0, 0)
		defer data.Release()
		return array.NewStructData(data), nil
	case *Map:
		structArr := s.GetList().(*array.Struct)
		keys := make([]array.Interface, length)
		values := make([]array.Interface, length)
		for i := 0; i < length; i++ {
			keys[i] = structArr.Field(0)
			values[i] = structArr.Field(1)
		}

		keyArr, err := array.Concatenate(keys, mem)
		if err != nil {
			return nil, err
		}
		defer keyArr.Release()

		valueArr, err := array.Concatenate(values, mem)
		if err != nil {
			return nil, err
		}
		defer valueArr.Release()

		offsetsBuf := createOffsets(int32(structArr.Len()))
		outStructArr := array.NewData(structArr.DataType(), keyArr.Len(), []*memory.Buffer{nil}, []*array.Data{keyArr.Data(), valueArr.Data()}, 0, 0)
		data := array.NewData(s.DataType(), length, []*memory.Buffer{nil, offsetsBuf}, []*array.Data{outStructArr}, 0, 0)
		defer func() {
			offsetsBuf.Release()
			outStructArr.Release()
			data.Release()
		}()
		return array.MakeFromData(data), nil
	default:
		return nil, xerrors.Errorf("array from scalar not yet implemented for type %s", sc.DataType())
	}
}

func Hash(seed maphash.Seed, s Scalar) uint64 {
	var h maphash.Hash
	h.SetSeed(seed)
	binary.Write(&h, endian.Native, arrow.HashType(seed, s.DataType()))

	out := h.Sum64()
	if !s.IsValid() {
		return out
	}

	hash := func() {
		out ^= h.Sum64()
		h.Reset()
	}

	valueHash := func(v interface{}) uint64 {
		switch v := v.(type) {
		case int32:
			h.Write((*[4]byte)(unsafe.Pointer(&v))[:])
		case int64:
			h.Write((*[8]byte)(unsafe.Pointer(&v))[:])
		case arrow.Date32:
			binary.Write(&h, endian.Native, uint32(v))
		case arrow.Time32:
			binary.Write(&h, endian.Native, uint32(v))
		case arrow.MonthInterval:
			binary.Write(&h, endian.Native, uint32(v))
		case arrow.Duration:
			binary.Write(&h, endian.Native, uint64(v))
		case arrow.Date64:
			binary.Write(&h, endian.Native, uint64(v))
		case arrow.Time64:
			binary.Write(&h, endian.Native, uint64(v))
		case arrow.Timestamp:
			binary.Write(&h, endian.Native, uint64(v))
		case float16.Num:
			binary.Write(&h, endian.Native, v.Uint16())
		case decimal128.Num:
			binary.Write(&h, endian.Native, v.LowBits())
			hash()
			binary.Write(&h, endian.Native, uint64(v.HighBits()))
		}
		hash()
		return out
	}

	h.Reset()
	switch s := s.(type) {
	case *Null:
	case *Extension:
		out ^= Hash(seed, s.Value)
	case *DayTimeInterval:
		return valueHash(s.Value.Days) & valueHash(s.Value.Milliseconds)
	case *MonthDayNanoInterval:
		return valueHash(s.Value.Months) & valueHash(s.Value.Days) & valueHash(s.Value.Nanoseconds)
	case PrimitiveScalar:
		h.Write(s.Data())
		hash()
	case TemporalScalar:
		return valueHash(s.value())
	case ListScalar:
		array.Hash(&h, s.GetList().Data())
		hash()
	case *Struct:
		for _, c := range s.Value {
			if c.IsValid() {
				out ^= Hash(seed, c)
			}
		}
	}

	return out
}
