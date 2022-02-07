# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# based on mcr.microsoft.com/windows/servercore:ltsc2019
# contains choco and vs2017 preinstalled
FROM abrarov/msvc-2017:2.11.0

# Install CMake and Ninja
ARG cmake=3.21.4
RUN choco install --no-progress -r -y cmake --version=%cmake% --installargs 'ADD_CMAKE_TO_PATH=System' && \
    choco install --no-progress -r -y gzip wget ninja

# Add unix tools to path
RUN setx path "%path%;C:\Program Files\Git\usr\bin"

# Install vcpkg
#
# Compiling vcpkg itself from a git tag doesn't work anymore since vcpkg has
# started to ship precompiled binaries for the vcpkg-tool.
ARG vcpkg
COPY ci/vcpkg/*.patch \
     ci/vcpkg/*windows*.cmake \
     arrow/ci/vcpkg/
COPY ci/scripts/install_vcpkg.sh arrow/ci/scripts/
RUN bash arrow/ci/scripts/install_vcpkg.sh /c/vcpkg %vcpkg% && \
    setx PATH "%PATH%;C:\vcpkg"

# Configure vcpkg and install dependencies
# NOTE: use windows batch environment notation for build arguments in RUN
# statements but bash notation in ENV statements
# VCPKG_FORCE_SYSTEM_BINARIES=1 spare around ~750MB of image size if the system
# cmake's and ninja's versions are recent enough
ARG build_type=release
ENV CMAKE_BUILD_TYPE=${build_type} \
    VCPKG_OVERLAY_TRIPLETS=C:\\arrow\\ci\\vcpkg \
    VCPKG_DEFAULT_TRIPLET=amd64-windows-static-md-${build_type} \
    VCPKG_FEATURE_FLAGS=-manifests

RUN vcpkg install --clean-after-build \
        abseil \
        aws-sdk-cpp[config,cognito-identity,core,identity-management,s3,sts,transfer] \
        boost-filesystem \
        boost-multiprecision \
        boost-system \
        brotli \
        bzip2 \
        c-ares \
        curl \
        flatbuffers \
        gflags \
        glog \
        google-cloud-cpp[core,storage] \
        grpc \
        lz4 \
        openssl \
        orc \
        protobuf \
        rapidjson \
        re2 \
        snappy \
        thrift \
        utf8proc \
        zlib \
        zstd

# Remove previous installations of python from the base image
# NOTE: a more recent base image (tried with 2.12.1) comes with python 3.9.7
# and the msi installers are failing to remove pip and tcl/tk "products" making
# the subsequent choco python installation step failing for installing python
# version 3.9.* due to existing python version
RUN wmic product where "name like 'python%%'" call uninstall /nointeractive && \
    rm -rf Python*

# Define the full version number otherwise choco falls back to patch number 0 (3.7 => 3.7.0)
ARG python=3.6
RUN (if "%python%"=="3.6" setx PYTHON_VERSION 3.6.8) & \
    (if "%python%"=="3.7" setx PYTHON_VERSION 3.7.4) & \
    (if "%python%"=="3.8" setx PYTHON_VERSION 3.8.6) & \
    (if "%python%"=="3.9" setx PYTHON_VERSION 3.9.1) & \
    (if "%python%"=="3.10" setx PYTHON_VERSION 3.10.0)
RUN choco install -r -y --no-progress python --version=%PYTHON_VERSION%
RUN pip install -U pip

COPY python/requirements-wheel-build.txt arrow/python/
RUN pip install -r arrow/python/requirements-wheel-build.txt

ENV CLCACHE_DIR="C:\clcache"
RUN if "%python%" NEQ "3.10" pip install clcache

# For debugging purposes
# RUN wget --no-check-certificate https://github.com/lucasg/Dependencies/releases/download/v1.10/Dependencies_x64_Release.zip
# RUN unzip Dependencies_x64_Release.zip -d Dependencies && setx path "%path%;C:\Depencencies"
