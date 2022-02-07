// Copyright 2014 The ql Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/*
Package driver registers QL sql/drivers named "ql", "ql2" and a memory driver named "ql-mem".

See also [0], [1] and [3].

Usage

A skeleton program using ql/driver.

	package main

	import (
		"database/sql"

		_ "modernc.org/ql/driver"
	)

	func main() {
		...
		// Disk file DB
		db, err := sql.Open("ql", "ql.db")  // [2]
		// alternatively
		db, err := sql.Open("ql", "file://ql.db")

		// and/or

		// Disk file DB using V2 format
		db, err := sql.Open("ql2", "ql.db")
		// alternatively
		db, err := sql.Open("ql2", "file://ql.db")

		// and/or

		// RAM DB
		mdb, err := sql.Open("ql-mem", "mem.db")
		// alternatively
		mdb, err := sql.Open("ql", "memory://mem.db")
		if err != nil {
			log.Fatal(err)
		}

		// Use db/mdb here
		...
	}

This package exports nothing.

Links

Referenced from above:

  [0]: http://godoc.org/modernc.org/ql
  [1]: http://golang.org/pkg/database/sql/
  [2]: http://golang.org/pkg/database/sql/#Open
  [3]: http://golang.org/pkg/database/sql/driver
*/
package driver // import "modernc.org/ql/driver"

import "modernc.org/ql"

func init() {
	ql.RegisterDriver()
	ql.RegisterDriver2()
	ql.RegisterMemDriver()
}
