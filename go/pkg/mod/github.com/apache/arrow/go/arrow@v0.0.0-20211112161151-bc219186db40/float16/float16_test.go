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

package float16

import (
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestFloat16(t *testing.T) {
	cases := map[Num]float32{
		{bits: 0x3c00}: 1,
		{bits: 0x4000}: 2,
		{bits: 0xc000}: -2,
		{bits: 0x0000}: 0,
		{bits: 0x5b8f}: 241.875,
		{bits: 0xdb8f}: -241.875,
		{bits: 0x48c8}: 9.5625,
		{bits: 0xc8c8}: -9.5625,
	}
	for k, v := range cases {
		f := k.Float32()
		assert.Equal(t, v, f, "float32 values should be the same")
		i := New(v)
		assert.Equal(t, k.bits, i.bits, "float16 values should be the same")
		assert.Equal(t, k.Uint16(), i.Uint16(), "float16 values should be the same")
		assert.Equal(t, k.String(), fmt.Sprintf("%v", v), "string representation differ")
	}
}
