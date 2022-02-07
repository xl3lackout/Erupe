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

==========
Data Types
==========

.. doxygenenum:: arrow::Type::type

.. doxygenclass:: arrow::DataType
   :members:

.. _api-type-factories:

Factory functions
=================

These functions are recommended for creating data types.  They may return
new objects or existing singletons, depending on the type requested.

.. doxygengroup:: type-factories
   :project: arrow_cpp
   :content-only:

Concrete type subclasses
========================

Primitive
---------

.. doxygenclass:: arrow::NullType
   :members:

.. doxygenclass:: arrow::BooleanType
   :members:

.. doxygengroup:: numeric-datatypes
   :content-only:
   :members:

Temporal
--------

.. doxygenenum:: arrow::TimeUnit::type

.. doxygengroup:: temporal-datatypes
   :content-only:
   :members:

Binary-like
-----------

.. doxygengroup:: binary-datatypes
   :content-only:
   :members:

Nested
------

.. doxygengroup:: nested-datatypes
   :content-only:
   :members:

Dictionary-encoded
------------------

.. doxygenclass:: arrow::DictionaryType
   :members:

Extension types
---------------

.. doxygenclass:: arrow::ExtensionType
   :members:


Fields and Schemas
==================

.. doxygengroup:: schema-factories
   :project: arrow_cpp
   :content-only:

.. doxygenclass:: arrow::Field
   :members:

.. doxygenclass:: arrow::Schema
   :members:
