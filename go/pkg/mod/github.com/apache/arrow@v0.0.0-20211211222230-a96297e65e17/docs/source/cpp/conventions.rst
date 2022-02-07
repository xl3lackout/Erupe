.. Licensed to the Apache Software Foundation (ASF) under one
.. or more contributor license agreements.  See the NOTICE file
.. distributed with this work for additional information
.. regarding copyright ownership.  The ASF licenses this file
.. to you under the Apache License, Version 2.0 (the
.. "License"); you may not use this file except in compliance
.. with the License.  You may obtain a copy of the License at

..   http://www.apache.org/licenses/LICENSE-2.0

.. Unless required by applicable law or agreed to in writing,
.. software distributed under the License is distributed on an
.. "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
.. KIND, either express or implied.  See the License for the
.. specific language governing permissions and limitations
.. under the License.

.. default-domain:: cpp
.. highlight:: cpp

.. cpp:namespace:: arrow

Conventions
===========

The Arrow C++ API follows a few simple guidelines.  As with many rules,
there may be exceptions.

Language version
----------------

Arrow is C++11-compatible.  A few backports are used for newer functionality,
for example the :class:`std::string_view` class.

Namespacing
-----------

All the Arrow API (except macros) is namespaced inside a ``arrow`` namespace,
and nested namespaces thereof.

Safe pointers
-------------

Arrow objects are usually passed and stored using safe pointers -- most of
the time :class:`std::shared_ptr` but sometimes also :class:`std::unique_ptr`.

Immutability
------------

Many Arrow objects are immutable: once constructed, their logical properties
cannot change anymore.  This makes it possible to use them in multi-threaded
scenarios without requiring tedious and error-prone synchronization.

There are obvious exceptions to this, such as IO objects or mutable data buffers.

Error reporting
---------------

Most APIs indicate a successful or erroneous outcome by returning a
:class:`arrow::Status` instance.  Arrow doesn't throw exceptions of its
own, but third-party exceptions might propagate through, especially
:class:`std::bad_alloc` (but Arrow doesn't use the standard allocators for
large data).

When an API can return either an error code or a successful value, it usually
does so by returning the template class
:class:`arrow::Result <template\<class T\> arrow::Result>`.  However,
some APIs (usually deprecated) return :class:`arrow::Status` and pass the
result value as an out-pointer parameter.

Here is an example of checking the outcome of an operation::

   const int64_t buffer_size = 4096;

   auto maybe_buffer = arrow::AllocateBuffer(buffer_size, &buffer);
   if (!maybe_buffer.ok()) {
      // ... handle error
   } else {
      std::shared_ptr<arrow::Buffer> buffer = *maybe_buffer;
      // ... use allocated buffer
   }

If the caller function itself returns a :class:`arrow::Result` or
:class:`arrow::Status` and wants to propagate any non-successful outcome, two
convenience macros are available:

* :c:macro:`ARROW_RETURN_NOT_OK` takes a :class:`arrow::Status` parameter
  and returns it if not successful.

* :c:macro:`ARROW_ASSIGN_OR_RAISE` takes a :class:`arrow::Result` parameter,
  assigns its result to a *lvalue* if successful, or returns the corresponding
  :class:`arrow::Status` on error.

For example::

   arrow::Status DoSomething() {
      const int64_t buffer_size = 4096;
      std::shared_ptr<arrow::Buffer> buffer;
      ARROW_ASSIGN_OR_RAISE(buffer, arrow::AllocateBuffer(buffer_size));
      // ... allocation successful, do something with buffer below

      // return success at the end
      return Status::OK();
   }

.. seealso::
   :doc:`API reference for error reporting <api/support>`
