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
.. _plasma:

The Plasma In-Memory Object Store
=================================

.. note::

   As present, Plasma is only supported for use on Linux and macOS.

The Plasma API
--------------

Starting the Plasma store
^^^^^^^^^^^^^^^^^^^^^^^^^

You can start the Plasma store by issuing a terminal command similar to the
following:

.. code-block:: bash

  plasma_store -m 1000000000 -s /tmp/plasma

The ``-m`` flag specifies the size of the store in bytes, and the ``-s`` flag
specifies the socket that the store will listen at. Thus, the above command
allows the Plasma store to use up to 1GB of memory, and sets the socket to
``/tmp/plasma``.

Leaving the current terminal window open as long as Plasma store should keep
running. Messages, concerning such as disconnecting clients, may occasionally be
printed to the screen. To stop running the Plasma store, you can press
``Ctrl-C`` in the terminal.

Creating a Plasma client
^^^^^^^^^^^^^^^^^^^^^^^^

To start a Plasma client from Python, call ``plasma.connect`` using the same
socket name:

.. code-block:: python

  import pyarrow.plasma as plasma
  client = plasma.connect("/tmp/plasma")

If the following error occurs from running the above Python code, that
means that either the socket given is incorrect, or the ``./plasma_store`` is
not currently running. Check to see if the Plasma store is still running.

.. code-block:: shell

  >>> client = plasma.connect("/tmp/plasma")
  Connection to socket failed for pathname /tmp/plasma
  Could not connect to socket /tmp/plasma


Object IDs
^^^^^^^^^^

Each object in the Plasma store should be associated with a unique ID. The
Object ID then serves as a key that any client can use to retrieve that object
from the Plasma store. You can form an ``ObjectID`` object from a byte string of
length 20.

.. code-block:: shell

  # Create an ObjectID.
  >>> id = plasma.ObjectID(20 * b"a")

  # The character "a" is encoded as 61 in hex.
  >>> id
  ObjectID(6161616161616161616161616161616161616161)

The random generation of Object IDs is often good enough to ensure unique IDs.
You can easily create a helper function that randomly generates object IDs as
follows:

.. code-block:: python

  import numpy as np

  def random_object_id():
    return plasma.ObjectID(np.random.bytes(20))

Putting and Getting Python Objects
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Plasma supports two APIs for creating and accessing objects: A high level
API that allows storing and retrieving Python objects and a low level
API that allows creating, writing and sealing buffers and operating on
the binary data directly. In this section we describe the high level API.

This is how you can put and get a Python object:

.. code-block:: python

    # Create a python object.
    object_id = client.put("hello, world")

    # Get the object.
    client.get(object_id)

This works with all Python objects supported by the Arrow Python object
serialization.

You can also get multiple objects at the same time (which can be more
efficient since it avoids IPC round trips):

.. code-block:: python

    # Create multiple python objects.
    object_id1 = client.put(1)
    object_id2 = client.put(2)
    object_id3 = client.put(3)

    # Get the objects.
    client.get([object_id1, object_id2, object_id3])

Furthermore, it is possible to provide a timeout for the get call. If the
object is not available within the timeout, the special object
`pyarrow.ObjectNotAvailable` will be returned.

Creating an Object Buffer
^^^^^^^^^^^^^^^^^^^^^^^^^

Objects are created in Plasma in two stages. First, they are **created**, which
allocates a buffer for the object. At this point, the client can write to the
buffer and construct the object within the allocated buffer.

To create an object for Plasma, you need to create an object ID, as well as
give the object's maximum size in bytes.

.. code-block:: python

  # Create an object buffer.
  object_id = plasma.ObjectID(20 * b"a")
  object_size = 1000
  buffer = memoryview(client.create(object_id, object_size))

  # Write to the buffer.
  for i in range(1000):
    buffer[i] = i % 128

When the client is done, the client **seals** the buffer, making the object
immutable, and making it available to other Plasma clients.

.. code-block:: python

  # Seal the object. This makes the object immutable and available to other clients.
  client.seal(object_id)


Getting an Object Buffer
^^^^^^^^^^^^^^^^^^^^^^^^

After an object has been sealed, any client who knows the object ID can get
the object buffer.

.. code-block:: python

  # Create a different client. Note that this second client could be
  # created in the same or in a separate, concurrent Python session.
  client2 = plasma.connect("/tmp/plasma")

  # Get the object in the second client. This blocks until the object has been sealed.
  object_id2 = plasma.ObjectID(20 * b"a")
  [buffer2] = client2.get_buffers([object_id])

If the object has not been sealed yet, then the call to client.get_buffers will
block until the object has been sealed by the client constructing the object.
Using the ``timeout_ms`` argument to get, you can specify a timeout for this (in
milliseconds). After the timeout, the interpreter will yield control back.

.. code-block:: shell

  >>> buffer
  <memory at 0x7fdbdc96e708>
  >>> buffer[1]
  1
  >>> buffer2
  <plasma.plasma.PlasmaBuffer object at 0x7fdbf2770e88>
  >>> view2 = memoryview(buffer2)
  >>> view2[1]
  1
  >>> view2[129]
  1
  >>> bytes(buffer[1:4])
  b'\x01\x02\x03'
  >>> bytes(view2[1:4])
  b'\x01\x02\x03'


Listing objects in the store
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The objects in the store can be listed in the following way (note that
this functionality is currently experimental and the concrete representation
of the object info might change in the future):

.. code-block:: python

  import pyarrow.plasma as plasma
  import time

  client = plasma.connect("/tmp/plasma")

  client.put("hello, world")
  # Sleep a little so we get different creation times
  time.sleep(2)
  client.put("another object")
  # Create an object that is not sealed yet
  object_id = plasma.ObjectID.from_random()
  client.create(object_id, 100)
  print(client.list())

  >>> {ObjectID(4cba8f80c54c6d265b46c2cdfcee6e32348b12be): {'construct_duration': 0,
  >>>  'create_time': 1535223642,
  >>>  'data_size': 460,
  >>>  'metadata_size': 0,
  >>>  'ref_count': 0,
  >>>  'state': 'sealed'},
  >>> ObjectID(a7598230b0c26464c9d9c99ae14773ee81485428): {'construct_duration': 0,
  >>>  'create_time': 1535223644,
  >>>  'data_size': 460,
  >>>  'metadata_size': 0,
  >>>  'ref_count': 0,
  >>>  'state': 'sealed'},
  >>> ObjectID(e603ab0c92098ebf08f90bfcea33ff98f6476870): {'construct_duration': -1,
  >>>  'create_time': 1535223644,
  >>>  'data_size': 100,
  >>>  'metadata_size': 0,
  >>>  'ref_count': 1,
  >>>  'state': 'created'}}


Using Arrow and Pandas with Plasma
----------------------------------

Storing Arrow Objects in Plasma
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To store an Arrow object in Plasma, we must first **create** the object and then
**seal** it. However, Arrow objects such as ``Tensors`` may be more complicated
to write than simple binary data.

To create the object in Plasma, you still need an ``ObjectID`` and a size to
pass in. To find out the size of your Arrow object, you can use pyarrow
API such as ``pyarrow.ipc.get_tensor_size``.

.. code-block:: python

  import numpy as np
  import pyarrow as pa

  # Create a pyarrow.Tensor object from a numpy random 2-dimensional array
  data = np.random.randn(10, 4)
  tensor = pa.Tensor.from_numpy(data)

  # Create the object in Plasma
  object_id = plasma.ObjectID(np.random.bytes(20))
  data_size = pa.ipc.get_tensor_size(tensor)
  buf = client.create(object_id, data_size)

To write the Arrow ``Tensor`` object into the buffer, you can use Plasma to
convert the ``memoryview`` buffer into a ``pyarrow.FixedSizeBufferWriter``
object. A ``pyarrow.FixedSizeBufferWriter`` is a format suitable for Arrow's
``pyarrow.ipc.write_tensor``:

.. code-block:: python

  # Write the tensor into the Plasma-allocated buffer
  stream = pa.FixedSizeBufferWriter(buf)
  pa.ipc.write_tensor(tensor, stream)  # Writes tensor's 552 bytes to Plasma stream

To finish storing the Arrow object in Plasma, call ``seal``:

.. code-block:: python

  # Seal the Plasma object
  client.seal(object_id)

Getting Arrow Objects from Plasma
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

To read the object, first retrieve it as a ``PlasmaBuffer`` using its object ID.

.. code-block:: python

  # Get the arrow object by ObjectID.
  [buf2] = client.get_buffers([object_id])

To convert the ``PlasmaBuffer`` back into an Arrow ``Tensor``, first create a
pyarrow ``BufferReader`` object from it. You can then pass the ``BufferReader``
into ``pyarrow.ipc.read_tensor`` to reconstruct the Arrow ``Tensor`` object:

.. code-block:: python

  # Reconstruct the Arrow tensor object.
  reader = pa.BufferReader(buf2)
  tensor2 = pa.ipc.read_tensor(reader)

Finally, you can use ``pyarrow.ipc.read_tensor`` to convert the Arrow object
back into numpy data:

.. code-block:: python

  # Convert back to numpy
  array = tensor2.to_numpy()

Storing Pandas DataFrames in Plasma
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Storing a Pandas ``DataFrame`` still follows the **create** then **seal**
process of storing an object in the Plasma store, however one cannot directly
write the ``DataFrame`` to Plasma with Pandas alone. Plasma also needs to know
the size of the ``DataFrame`` to allocate a buffer for.

See :ref:`pandas_interop` for more information on using Arrow with Pandas.

You can create the pyarrow equivalent of a Pandas ``DataFrame`` by using
``pyarrow.from_pandas`` to convert it to a ``RecordBatch``.

.. code-block:: python

  import pyarrow as pa
  import pandas as pd

  # Create a Pandas DataFrame
  d = {'one' : pd.Series([1., 2., 3.], index=['a', 'b', 'c']),
       'two' : pd.Series([1., 2., 3., 4.], index=['a', 'b', 'c', 'd'])}
  df = pd.DataFrame(d)

  # Convert the Pandas DataFrame into a PyArrow RecordBatch
  record_batch = pa.RecordBatch.from_pandas(df)

Creating the Plasma object requires an ``ObjectID`` and the size of the
data. Now that we have converted the Pandas ``DataFrame`` into a PyArrow
``RecordBatch``, use the ``MockOutputStream`` to determine the
size of the Plasma object.

.. code-block:: python

  # Create the Plasma object from the PyArrow RecordBatch. Most of the work here
  # is done to determine the size of buffer to request from the object store.
  object_id = plasma.ObjectID(np.random.bytes(20))
  mock_sink = pa.MockOutputStream()
  with pa.RecordBatchStreamWriter(mock_sink, record_batch.schema) as stream_writer:
      stream_writer.write_batch(record_batch)
  data_size = mock_sink.size()
  buf = client.create(object_id, data_size)

The DataFrame can now be written to the buffer as follows.

.. code-block:: python

  # Write the PyArrow RecordBatch to Plasma
  stream = pa.FixedSizeBufferWriter(buf)
  with pa.RecordBatchStreamWriter(stream, record_batch.schema) as stream_writer:
      stream_writer.write_batch(record_batch)

Finally, seal the finished object for use by all clients:

.. code-block:: python

  # Seal the Plasma object
  client.seal(object_id)

Getting Pandas DataFrames from Plasma
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Since we store the Pandas DataFrame as a PyArrow ``RecordBatch`` object,
to get the object back from the Plasma store, we follow similar steps
to those specified in `Getting Arrow Objects from Plasma`_.

We first have to convert the ``PlasmaBuffer`` returned from
``client.get_buffers`` into an Arrow ``BufferReader`` object.

.. code-block:: python

  # Fetch the Plasma object
  [data] = client.get_buffers([object_id])  # Get PlasmaBuffer from ObjectID
  buffer = pa.BufferReader(data)

From the ``BufferReader``, we can create a specific ``RecordBatchStreamReader``
in Arrow to reconstruct the stored PyArrow ``RecordBatch`` object.

.. code-block:: python

  # Convert object back into an Arrow RecordBatch
  reader = pa.RecordBatchStreamReader(buffer)
  record_batch = reader.read_next_batch()

The last step is to convert the PyArrow ``RecordBatch`` object back into
the original Pandas ``DataFrame`` structure.

.. code-block:: python

  # Convert back into Pandas
  result = record_batch.to_pandas()

Using Plasma with Huge Pages
----------------------------

On Linux it is possible to use the Plasma store with huge pages for increased
throughput. You first need to create a file system and activate huge pages with

.. code-block:: shell

  sudo mkdir -p /mnt/hugepages
  gid=`id -g`
  uid=`id -u`
  sudo mount -t hugetlbfs -o uid=$uid -o gid=$gid none /mnt/hugepages
  sudo bash -c "echo $gid > /proc/sys/vm/hugetlb_shm_group"
  sudo bash -c "echo 20000 > /proc/sys/vm/nr_hugepages"

Note that you only need root access to create the file system, not for
running the object store. You can then start the Plasma store with the ``-d``
flag for the mount point of the huge page file system and the ``-h`` flag
which indicates that huge pages are activated:

.. code-block:: shell

  plasma_store -s /tmp/plasma -m 10000000000 -d /mnt/hugepages -h

You can test this with the following script:

.. code-block:: python

  import numpy as np
  import pyarrow as pa
  import pyarrow.plasma as plasma
  import time

  client = plasma.connect("/tmp/plasma")

  data = np.random.randn(100000000)
  tensor = pa.Tensor.from_numpy(data)

  object_id = plasma.ObjectID(np.random.bytes(20))
  buf = client.create(object_id, pa.ipc.get_tensor_size(tensor))

  stream = pa.FixedSizeBufferWriter(buf)
  stream.set_memcopy_threads(4)
  a = time.time()
  pa.ipc.write_tensor(tensor, stream)
  print("Writing took ", time.time() - a)
