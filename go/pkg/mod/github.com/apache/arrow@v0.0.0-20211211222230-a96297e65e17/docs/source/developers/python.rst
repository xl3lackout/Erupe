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
.. _python-development:

==================
Python Development
==================

This page provides general Python development guidelines and source build
instructions for all platforms.

Coding Style
============

We follow a similar PEP8-like coding style to the `pandas project
<https://github.com/pandas-dev/pandas>`_.  To check style issues, use the
:ref:`Archery <archery>` subcommand ``lint``:

.. code-block:: shell

   pip install -e arrow/dev/archery[lint]

.. code-block:: shell

   archery lint --python

Some of the issues can be automatically fixed by passing the ``--fix`` option:

.. code-block:: shell

   archery lint --python --fix

.. _python-unit-testing:

Unit Testing
============

We are using `pytest <https://docs.pytest.org/en/latest/>`_ to develop our unit
test suite. After building the project (see below) you can run its unit tests
like so:

.. code-block:: shell

   pytest arrow/python/pyarrow

Package requirements to run the unit tests are found in
``requirements-test.txt`` and can be installed if needed with ``pip install -r
requirements-test.txt``.

If you get import errors for ``pyarrow._lib`` or another PyArrow module when
trying to run the tests, run ``python -m pytest arrow/python/pyarrow`` and check
if the editable version of pyarrow was installed correctly.

The project has a number of custom command line options for its test
suite. Some tests are disabled by default, for example. To see all the options,
run

.. code-block:: shell

   pytest pyarrow --help

and look for the "custom options" section.

Test Groups
-----------

We have many tests that are grouped together using pytest marks. Some of these
are disabled by default. To enable a test group, pass ``--$GROUP_NAME``,
e.g. ``--parquet``. To disable a test group, prepend ``disable``, so
``--disable-parquet`` for example. To run **only** the unit tests for a
particular group, prepend ``only-`` instead, for example ``--only-parquet``.

The test groups currently include:

* ``gandiva``: tests for Gandiva expression compiler (uses LLVM)
* ``hdfs``: tests that use libhdfs or libhdfs3 to access the Hadoop filesystem
* ``hypothesis``: tests that use the ``hypothesis`` module for generating
  random test cases. Note that ``--hypothesis`` doesn't work due to a quirk
  with pytest, so you have to pass ``--enable-hypothesis``
* ``large_memory``: Test requiring a large amount of system RAM
* ``orc``: Apache ORC tests
* ``parquet``: Apache Parquet tests
* ``plasma``: Plasma Object Store tests
* ``s3``: Tests for Amazon S3
* ``tensorflow``: Tests that involve TensorFlow
* ``flight``: Flight RPC tests

Benchmarking
------------

For running the benchmarks, see :ref:`python-benchmarks`.

.. _build_pyarrow:

Building on Linux and MacOS
=============================

System Requirements
-------------------

On macOS, any modern XCode (6.4 or higher; the current version is 13) or
Xcode Command Line Tools (``xcode-select --install``) are sufficient.

On Linux, for this guide, we require a minimum of gcc 4.8, or clang 3.7 or
higher. You can check your version by running

.. code-block:: console

   $ gcc --version

If the system compiler is older than gcc 4.8, it can be set to a newer version
using the ``$CC`` and ``$CXX`` environment variables:

.. code-block:: shell

   export CC=gcc-4.8
   export CXX=g++-4.8

Environment Setup and Build
---------------------------

First, let's clone the Arrow git repository:

.. code-block:: shell

   git clone https://github.com/apache/arrow.git

Pull in the test data and setup the environment variables:

.. code-block:: shell

   pushd arrow
   git submodule init
   git submodule update
   export PARQUET_TEST_DATA="${PWD}/cpp/submodules/parquet-testing/data"
   export ARROW_TEST_DATA="${PWD}/testing/data"
   popd

Using Conda
~~~~~~~~~~~

Let's create a conda environment with all the C++ build and Python dependencies
from conda-forge, targeting development for Python 3.9:

On Linux and macOS:

.. code-block:: shell

    conda create -y -n pyarrow-dev -c conda-forge \
        --file arrow/ci/conda_env_unix.txt \
        --file arrow/ci/conda_env_cpp.txt \
        --file arrow/ci/conda_env_python.txt \
        --file arrow/ci/conda_env_gandiva.txt \
        compilers \
        python=3.9 \
        pandas

As of January 2019, the ``compilers`` package is needed on many Linux
distributions to use packages from conda-forge.

With this out of the way, you can now activate the conda environment

.. code-block:: shell

   conda activate pyarrow-dev

For Windows, see the `Building on Windows`_ section below.

We need to set some environment variables to let Arrow's build system know
about our build toolchain:

.. code-block:: shell

   export ARROW_HOME=$CONDA_PREFIX

Using pip
~~~~~~~~~

.. warning::

   If you installed Python using the Anaconda distribution or `Miniconda
   <https://conda.io/miniconda.html>`_, you cannot currently use ``virtualenv``
   to manage your development. Please follow the conda-based development
   instructions instead.

.. _python-homebrew:

On macOS, use Homebrew to install all dependencies required for
building Arrow C++:

.. code-block:: shell

   brew update && brew bundle --file=arrow/cpp/Brewfile

See :ref:`here <cpp-build-dependency-management>` for a list of dependencies you
may need.

On Debian/Ubuntu, you need the following minimal set of dependencies. All other
dependencies will be automatically built by Arrow's third-party toolchain.

.. code-block:: console

   $ sudo apt-get install libjemalloc-dev libboost-dev \
                          libboost-filesystem-dev \
                          libboost-system-dev \
                          libboost-regex-dev \
                          python-dev \
                          autoconf \
                          flex \
                          bison

If you are building Arrow for Python 3, install ``python3-dev`` instead of ``python-dev``.

On Arch Linux, you can get these dependencies via pacman.

.. code-block:: console

   $ sudo pacman -S jemalloc boost

Now, let's create a Python virtualenv with all Python dependencies in the same
folder as the repositories and a target installation folder:

.. code-block:: shell

   virtualenv -p python3.9 pyarrow-dev
   source ./pyarrow-dev/bin/activate
   pip install -r arrow/python/requirements-build.txt \
        -r arrow/python/requirements-test.txt

   # This is the folder where we will install the Arrow libraries during
   # development
   mkdir dist

If your cmake version is too old on Linux, you could get a newer one via
``pip install cmake``.

We need to set some environment variables to let Arrow's build system know
about our build toolchain:

.. code-block:: shell

   export ARROW_HOME=$(pwd)/dist
   export LD_LIBRARY_PATH=$(pwd)/dist/lib:$LD_LIBRARY_PATH

Build and test
--------------

Now build and install the Arrow C++ libraries:

.. code-block:: shell

   mkdir arrow/cpp/build
   pushd arrow/cpp/build

   cmake -DCMAKE_INSTALL_PREFIX=$ARROW_HOME \
         -DCMAKE_INSTALL_LIBDIR=lib \
         -DCMAKE_BUILD_TYPE=debug \
         -DARROW_WITH_BZ2=ON \
         -DARROW_WITH_ZLIB=ON \
         -DARROW_WITH_ZSTD=ON \
         -DARROW_WITH_LZ4=ON \
         -DARROW_WITH_SNAPPY=ON \
         -DARROW_WITH_BROTLI=ON \
         -DARROW_PARQUET=ON \
         -DARROW_PYTHON=ON \
         -DARROW_BUILD_TESTS=ON \
         ..
   make -j4
   make install
   popd

There are a number of optional components that can can be switched ON by
adding flags with ``ON``:

* ``ARROW_FLIGHT``: RPC framework
* ``ARROW_GANDIVA``: LLVM-based expression compiler
* ``ARROW_ORC``: Support for Apache ORC file format
* ``ARROW_PARQUET``: Support for Apache Parquet file format
* ``ARROW_PLASMA``: Shared memory object store

Anything set to ``ON`` above can also be turned off. Note that some compression
libraries are needed for Parquet support.

To enable C++ debugging information, pass the option ``-DCMAKE_BUILD_TYPE=debug``.

.. seealso::
   :ref:`cpp-building-building`.

If multiple versions of Python are installed in your environment, you may have
to pass additional parameters to cmake so that it can find the right
executable, headers and libraries.  For example, specifying
``-DPython3_EXECUTABLE=$VIRTUAL_ENV/bin/python`` (assuming that you're in
virtualenv) enables cmake to choose the python executable which you are using.

.. note::

   On Linux systems with support for building on multiple architectures,
   ``make`` may install libraries in the ``lib64`` directory by default. For
   this reason we recommend passing ``-DCMAKE_INSTALL_LIBDIR=lib`` because the
   Python build scripts assume the library directory is ``lib``

.. note::

   If you have conda installed but are not using it to manage dependencies,
   and you have trouble building the C++ library, you may need to set
   ``-DARROW_DEPENDENCY_SOURCE=AUTO`` or some other value (described
   :ref:`here <cpp-build-dependency-management>`)
   to explicitly tell CMake not to use conda.

.. note::

   With older versions of ``cmake`` (<3.15) you might need to pass ``-DPYTHON_EXECUTABLE``
   instead of ``-DPython3_EXECUTABLE``. See `cmake documentation <https://cmake.org/cmake/help/latest/module/FindPython3.html#artifacts-specification>`_
   for more details.

For any other C++ build challenges, see :ref:`cpp-development`.

In case you may need to rebuild the C++ part due to errors in the process it is
advisable to delete the build folder with command ``rm -rf /arrow/cpp/build``.
If the build has passed successfully and you need to rebuild due to latest pull from master,
then this step is not needed.

Now, build pyarrow:

.. code-block:: shell

   pushd arrow/python
   export PYARROW_WITH_PARQUET=1
   python setup.py build_ext --inplace
   popd

If you did build one of the optional components (in C++), you need to set the
corresponding ``PYARROW_WITH_$COMPONENT`` environment variable to 1.

If you wish to delete pyarrow build before rebuilding navigate to the ``arrow/python``
folder and run ``git clean -Xfd .``.

Now you are ready to install test dependencies and run `Unit Testing`_, as
described above.

To build a self-contained wheel (including the Arrow and Parquet C++
libraries), one can set ``--bundle-arrow-cpp``:

.. code-block:: shell

   pip install wheel  # if not installed
   python setup.py build_ext --build-type=$ARROW_BUILD_TYPE \
          --bundle-arrow-cpp bdist_wheel

.. note::
   To install an editable PyArrow build run ``pip install -e . --no-build-isolation``
   in the ``arrow/python`` directory.

Docker examples
~~~~~~~~~~~~~~~

If you are having difficulty building the Python library from source, take a
look at the ``python/examples/minimal_build`` directory which illustrates a
complete build and test from source both with the conda and pip/virtualenv
build methods.

Building with CUDA support
~~~~~~~~~~~~~~~~~~~~~~~~~~

The :mod:`pyarrow.cuda` module offers support for using Arrow platform
components with Nvidia's CUDA-enabled GPU devices. To build with this support,
pass ``-DARROW_CUDA=ON`` when building the C++ libraries, and set the following
environment variable when building pyarrow:

.. code-block:: shell

   export PYARROW_WITH_CUDA=1

Debugging
---------

Since pyarrow depends on the Arrow C++ libraries, debugging can
frequently involve crossing between Python and C++ shared libraries.

Using gdb on Linux
~~~~~~~~~~~~~~~~~~

To debug the C++ libraries with gdb while running the Python unit
   test, first start pytest with gdb:

.. code-block:: shell

   gdb --args python -m pytest pyarrow/tests/test_to_run.py -k $TEST_TO_MATCH

To set a breakpoint, use the same gdb syntax that you would when
debugging a C++ unittest, for example:

.. code-block:: shell

   (gdb) b src/arrow/python/arrow_to_pandas.cc:1874
   No source file named src/arrow/python/arrow_to_pandas.cc.
   Make breakpoint pending on future shared library load? (y or [n]) y
   Breakpoint 1 (src/arrow/python/arrow_to_pandas.cc:1874) pending.

.. _build_pyarrow_win:

Building on Windows
===================

Building on Windows requires one of the following compilers to be installed:

- `Build Tools for Visual Studio 2017 <https://download.visualstudio.microsoft.com/download/pr/3e542575-929e-4297-b6c6-bef34d0ee648/639c868e1219c651793aff537a1d3b77/vs_buildtools.exe>`_
- Visual Studio 2017

During the setup of Build Tools ensure at least one Windows SDK is selected.

Visual Studio 2019 and its build tools are currently not supported.

We bootstrap a conda environment similar to above, but skipping some of the
Linux/macOS-only packages:

First, starting from fresh clones of Apache Arrow:

.. code-block:: shell

   git clone https://github.com/apache/arrow.git

.. code-block:: shell

   conda create -y -n pyarrow-dev -c conda-forge ^
       --file arrow\ci\conda_env_cpp.txt ^
       --file arrow\ci\conda_env_python.txt ^
       --file arrow\ci\conda_env_gandiva.txt ^
       python=3.9
   conda activate pyarrow-dev

Now, we build and install Arrow C++ libraries.

We set a number of environment variables:

- the path of the installation directory of the Arrow C++ libraries as
  ``ARROW_HOME``
- add the path of installed DLL libraries to ``PATH``
- and choose the compiler to be used

.. code-block:: shell

   set ARROW_HOME=%cd%\arrow-dist
   set PATH=%ARROW_HOME%\bin;%PATH%
   set PYARROW_CMAKE_GENERATOR=Visual Studio 15 2017 Win64

Let's configure, build and install the Arrow C++ libraries:

.. code-block:: shell

   mkdir arrow\cpp\build
   pushd arrow\cpp\build
   cmake -G "%PYARROW_CMAKE_GENERATOR%" ^
       -DCMAKE_INSTALL_PREFIX=%ARROW_HOME% ^
       -DCMAKE_UNITY_BUILD=ON ^
       -DARROW_CXXFLAGS="/WX /MP" ^
       -DARROW_WITH_LZ4=on ^
       -DARROW_WITH_SNAPPY=on ^
       -DARROW_WITH_ZLIB=on ^
       -DARROW_WITH_ZSTD=on ^
       -DARROW_PARQUET=on ^
       -DARROW_PYTHON=on ^
       ..
   cmake --build . --target INSTALL --config Release
   popd

Now, we can build pyarrow:

.. code-block:: shell

   pushd arrow\python
   set PYARROW_WITH_PARQUET=1
   python setup.py build_ext --inplace
   popd

.. note::

   For building pyarrow, the above defined environment variables need to also
   be set. Remember this if to want to re-build ``pyarrow`` after your initial build.

Then run the unit tests with:

.. code-block:: shell

   pushd arrow\python
   py.test pyarrow -v
   popd

.. note::

   With the above instructions the Arrow C++ libraries are not bundled with
   the Python extension. This is recommended for development as it allows the
   C++ libraries to be re-built separately.

   As a consequence however, ``python setup.py install`` will also not install
   the Arrow C++ libraries. Therefore, to use ``pyarrow`` in python, ``PATH``
   must contain the directory with the Arrow .dll-files.

   If you want to bundle the Arrow C++ libraries with ``pyarrow`` add
   ``--bundle-arrow-cpp`` as build parameter:

   ``python setup.py build_ext --bundle-arrow-cpp``

   Important: If you combine ``--bundle-arrow-cpp`` with ``--inplace`` the
   Arrow C++ libraries get copied to the python source tree and are not cleared
   by ``python setup.py clean``. They remain in place and will take precedence
   over any later Arrow C++ libraries contained in ``PATH``. This can lead to
   incompatibilities when ``pyarrow`` is later built without
   ``--bundle-arrow-cpp``.

Running C++ unit tests for Python integration
---------------------------------------------

Running C++ unit tests should not be necessary for most developers. If you do
want to run them, you need to pass ``-DARROW_BUILD_TESTS=ON`` during
configuration of the Arrow C++ library build:

.. code-block:: shell

   mkdir arrow\cpp\build
   pushd arrow\cpp\build
   cmake -G "%PYARROW_CMAKE_GENERATOR%" ^
       -DCMAKE_INSTALL_PREFIX=%ARROW_HOME% ^
       -DARROW_CXXFLAGS="/WX /MP" ^
       -DARROW_PARQUET=on ^
       -DARROW_PYTHON=on ^
       -DARROW_BUILD_TESTS=ON ^
       ..
   cmake --build . --target INSTALL --config Release
   popd


Getting ``arrow-python-test.exe`` (C++ unit tests for python integration) to
run is a bit tricky because your ``%PYTHONHOME%`` must be configured to point
to the active conda environment:

.. code-block:: shell

   set PYTHONHOME=%CONDA_PREFIX%
   pushd arrow\cpp\build\release\Release
   arrow-python-test.exe
   popd

To run all tests of the Arrow C++ library, you can also run ``ctest``:

.. code-block:: shell

   set PYTHONHOME=%CONDA_PREFIX%
   pushd arrow\cpp\build
   ctest
   popd

Windows Caveats
---------------

Some components are not supported yet on Windows:

* Flight RPC
* Plasma
