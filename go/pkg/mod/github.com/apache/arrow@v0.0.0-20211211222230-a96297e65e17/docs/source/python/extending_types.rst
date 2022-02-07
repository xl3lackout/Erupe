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

.. currentmodule:: pyarrow
.. _extending_types:

Extending pyarrow
=================

Controlling conversion to pyarrow.Array with the ``__arrow_array__`` protocol
-----------------------------------------------------------------------------

The :func:`pyarrow.array` function has built-in support for Python sequences,
numpy arrays and pandas 1D objects (Series, Index, Categorical, ..) to convert
those to Arrow arrays. This can be extended for other array-like objects
by implementing the ``__arrow_array__`` method (similar to numpy's ``__array__``
protocol).

For example, to support conversion of your duck array class to an Arrow array,
define the ``__arrow_array__`` method to return an Arrow array::

    class MyDuckArray:

        ...

        def __arrow_array__(self, type=None):
            # convert the underlying array values to a pyarrow Array
            import pyarrow
            return pyarrow.array(..., type=type)

The ``__arrow_array__`` method takes an optional `type` keyword which is passed
through from :func:`pyarrow.array`. The method is allowed to return either
a :class:`~pyarrow.Array` or a :class:`~pyarrow.ChunkedArray`.


Defining extension types ("user-defined types")
-----------------------------------------------

Arrow has the notion of extension types in the metadata specification as a
possibility to extend the built-in types. This is done by annotating any of the
built-in Arrow logical types (the "storage type") with a custom type name and
optional serialized representation ("ARROW:extension:name" and
"ARROW:extension:metadata" keys in the Field’s custom_metadata of an IPC
message).
See the :ref:`format_metadata_extension_types` section of the metadata
specification for more details.

Pyarrow allows you to define such extension types from Python.

There are currently two ways:

* Subclassing :class:`PyExtensionType`: the (de)serialization is based on pickle.
  This is a good option for an extension type that is only used from Python.
* Subclassing :class:`ExtensionType`: this allows to give a custom
  Python-independent name and serialized metadata, that can potentially be
  recognized by other (non-Python) Arrow implementations such as PySpark.

For example, we could define a custom UUID type for 128-bit numbers which can
be represented as ``FixedSizeBinary`` type with 16 bytes.
Using the first approach, we create a ``UuidType`` subclass, and implement the
``__reduce__`` method to ensure the class can be properly pickled::

    class UuidType(pa.PyExtensionType):

        def __init__(self):
            pa.PyExtensionType.__init__(self, pa.binary(16))

        def __reduce__(self):
            return UuidType, ()

This can now be used to create arrays and tables holding the extension type::

    >>> uuid_type = UuidType()
    >>> uuid_type.extension_name
    'arrow.py_extension_type'
    >>> uuid_type.storage_type
    FixedSizeBinaryType(fixed_size_binary[16])

    >>> import uuid
    >>> storage_array = pa.array([uuid.uuid4().bytes for _ in range(4)], pa.binary(16))
    >>> arr = pa.ExtensionArray.from_storage(uuid_type, storage_array)
    >>> arr
    <pyarrow.lib.ExtensionArray object at 0x7f75c2f300a0>
    [
      A6861959108644B797664AEEE686B682,
      718747F48E5F4058A7261E2B6B228BE8,
      7FE201227D624D96A5CD8639DEF2A68B,
      C6CA8C7F95744BFD9462A40B3F57A86C
    ]

This array can be included in RecordBatches, sent over IPC and received in
another Python process. The custom UUID type will be preserved there, as long
as the definition of the class is available (the type can be unpickled).

For example, creating a RecordBatch and writing it to a stream using the
IPC protocol::

    >>> batch = pa.RecordBatch.from_arrays([arr], ["ext"])
    >>> sink = pa.BufferOutputStream()
    >>> with pa.RecordBatchStreamWriter(sink, batch.schema) as writer:
    ...    writer.write_batch(batch)
    >>> buf = sink.getvalue()

and then reading it back yields the proper type::

    >>> with pa.ipc.open_stream(buf) as reader:
    ...    result = reader.read_all()
    >>> result.column('ext').type
    UuidType(extension<arrow.py_extension_type>)

We can define the same type using the other option::

    class UuidType(pa.ExtensionType):

        def __init__(self):
            pa.ExtensionType.__init__(self, pa.binary(16), "my_package.uuid")

        def __arrow_ext_serialize__(self):
            # since we don't have a parameterized type, we don't need extra
            # metadata to be deserialized
            return b''

        @classmethod
        def __arrow_ext_deserialize__(self, storage_type, serialized):
            # return an instance of this subclass given the serialized
            # metadata.
            return UuidType()

This is a slightly longer implementation (you need to implement the special
methods ``__arrow_ext_serialize__`` and ``__arrow_ext_deserialize__``), and the
extension type needs to be registered to be received through IPC (using
:func:`register_extension_type`), but it has
now a unique name::

    >>> uuid_type = UuidType()
    >>> uuid_type.extension_name
    'my_package.uuid'

    >>> pa.register_extension_type(uuid_type)

The receiving application doesn't need to be Python but can still recognize
the extension type as a "uuid" type, if it has implemented its own extension
type to receive it.
If the type is not registered in the receiving application, it will fall back
to the storage type.

Parameterized extension type
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The above example used a fixed storage type with no further metadata. But
more flexible, parameterized extension types are also possible.

The example given here implements an extension type for the `pandas "period"
data type <https://pandas.pydata.org/pandas-docs/stable/user_guide/timeseries.html#time-span-representation>`__,
representing time spans (e.g., a frequency of a day, a month, a quarter, etc).
It is stored as an int64 array which is interpreted as the number of time spans
of the given frequency since 1970.

::

    class PeriodType(pa.ExtensionType):

        def __init__(self, freq):
            # attributes need to be set first before calling
            # super init (as that calls serialize)
            self._freq = freq
            pa.ExtensionType.__init__(self, pa.int64(), 'my_package.period')

        @property
        def freq(self):
            return self._freq

        def __arrow_ext_serialize__(self):
            return "freq={}".format(self.freq).encode()

        @classmethod
        def __arrow_ext_deserialize__(cls, storage_type, serialized):
            # return an instance of this subclass given the serialized
            # metadata.
            serialized = serialized.decode()
            assert serialized.startswith("freq=")
            freq = serialized.split('=')[1]
            return PeriodType(freq)

Here, we ensure to store all information in the serialized metadata that is
needed to reconstruct the instance (in the ``__arrow_ext_deserialize__`` class
method), in this case the frequency string.

Note that, once created, the data type instance is considered immutable. If,
in the example above, the ``freq`` parameter would change after instantiation,
the reconstruction of the type instance after IPC will be incorrect.
In the example above, the ``freq`` parameter is therefore stored in a private
attribute with a public read-only property to access it.

Parameterized extension types are also possible using the pickle-based type
subclassing :class:`PyExtensionType`. The equivalent example for the period
data type from above would look like::

    class PeriodType(pa.PyExtensionType):

        def __init__(self, freq):
            self._freq = freq
            pa.PyExtensionType.__init__(self, pa.int64())

        @property
        def freq(self):
            return self._freq

        def __reduce__(self):
            return PeriodType, (self.freq,)

Also the storage type does not need to be fixed but can be parameterized.

Custom extension array class
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

By default, all arrays with an extension type are constructed or deserialized into
a built-in :class:`ExtensionArray` object. Nevertheless, one could want to subclass
:class:`ExtensionArray` in order to add some custom logic specific to the extension
type. Arrow allows to do so by adding a special method ``__arrow_ext_class__`` to the
definition of the extension type.

For instance, let us consider the example from the `Numpy Quickstart <https://docs.scipy.org/doc/numpy-1.13.0/user/quickstart.html>`_ of points in 3D space.
We can store these as a fixed-size list, where we wish to be able to extract
the data as a 2-D Numpy array ``(N, 3)`` without any copy::

    class Point3DArray(pa.ExtensionArray):
        def to_numpy_array(self):
            return self.storage.flatten().to_numpy().reshape((-1, 3))


    class Point3DType(pa.PyExtensionType):
        def __init__(self):
            pa.PyExtensionType.__init__(self, pa.list_(pa.float32(), 3))

        def __reduce__(self):
            return Point3DType, ()

        def __arrow_ext_class__(self):
            return Point3DArray

Arrays built using this extension type now have the expected custom array class::

    >>> storage = pa.array([[1, 2, 3], [4, 5, 6]], pa.list_(pa.float32(), 3))
    >>> arr = pa.ExtensionArray.from_storage(Point3DType(), storage)
    >>> arr
    <__main__.Point3DArray object at 0x7f40dea80670>
    [
        [
            1,
            2,
            3
        ],
        [
            4,
            5,
            6
        ]
    ]

The additional methods in the extension class are then available to the user::

    >>> arr.to_numpy_array()
    array([[1., 2., 3.],
       [4., 5., 6.]], dtype=float32)


This array can be sent over IPC, received in another Python process, and the custom
extension array class will be preserved (as long as the definitions of the classes above
are available).

The same ``__arrow_ext_class__`` specialization can be used with custom types defined
by subclassing :class:`ExtensionType`.


Conversion to pandas
~~~~~~~~~~~~~~~~~~~~

The conversion to pandas (in :meth:`Table.to_pandas`) of columns with an
extension type can controlled in case there is a corresponding
`pandas extension array <https://pandas.pydata.org/pandas-docs/stable/development/extending.html#extension-types>`__
for your extension type.

For this, the :meth:`ExtensionType.to_pandas_dtype` method needs to be
implemented, and should return a ``pandas.api.extensions.ExtensionDtype``
subclass instance.

Using the pandas period type from above as example, this would look like::

    class PeriodType(pa.ExtensionType):
        ...

        def to_pandas_dtype(self):
            import pandas as pd
            return pd.PeriodDtype(freq=self.freq)

Secondly, the pandas ``ExtensionDtype`` on its turn needs to have the
``__from_arrow__`` method implemented: a method that given a pyarrow Array
or ChunkedArray of the extension type can construct the corresponding
pandas ``ExtensionArray``. This method should have the following signature::


    class MyExtensionDtype(pd.api.extensions.ExtensionDtype):
        ...

        def __from_arrow__(self, array: pyarrow.Array/ChunkedArray) -> pandas.ExtensionArray:
            ...

This way, you can control the conversion of a pyarrow ``Array`` of your pyarrow
extension type to a pandas ``ExtensionArray`` that can be stored in a DataFrame.
