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

include(ProcessorCount)
processorcount(NPROC)

add_custom_target(rapidjson)
add_custom_target(toolchain)
add_custom_target(toolchain-benchmarks)
add_custom_target(toolchain-tests)

# Accumulate all bundled targets and we will splice them together later as
# libarrow_dependencies.a so that third party libraries have something usable
# to create statically-linked builds with some BUNDLED dependencies, including
# allocators like jemalloc and mimalloc
set(ARROW_BUNDLED_STATIC_LIBS)

# Accumulate all system dependencies to provide suitable static link
# parameters to the third party libraries.
set(ARROW_SYSTEM_DEPENDENCIES)

# ----------------------------------------------------------------------
# Toolchain linkage options

set(ARROW_RE2_LINKAGE
    "static"
    CACHE STRING "How to link the re2 library. static|shared (default static)")

if(ARROW_PROTOBUF_USE_SHARED)
  set(Protobuf_USE_STATIC_LIBS OFF)
else()
  set(Protobuf_USE_STATIC_LIBS ON)
endif()

# ----------------------------------------------------------------------
# Resolve the dependencies

set(ARROW_THIRDPARTY_DEPENDENCIES
    AWSSDK
    benchmark
    Boost
    Brotli
    BZip2
    c-ares
    gflags
    GLOG
    google_cloud_cpp_storage
    gRPC
    GTest
    LLVM
    Lz4
    opentelemetry-cpp
    ORC
    re2
    Protobuf
    RapidJSON
    Snappy
    Thrift
    utf8proc
    xsimd
    ZLIB
    zstd)

# TODO(wesm): External GTest shared libraries are not currently
# supported when building with MSVC because of the way that
# conda-forge packages have 4 variants of the libraries packaged
# together
if(MSVC AND "${GTest_SOURCE}" STREQUAL "")
  set(GTest_SOURCE "BUNDLED")
endif()

# For backward compatibility. We use "BOOST_SOURCE" if "Boost_SOURCE"
# isn't specified and "BOOST_SOURCE" is specified.
# We renamed "BOOST" dependency name to "Boost" in 3.0.0 because
# upstreams (CMake and Boost) use "Boost" not "BOOST" as package name.
if("${Boost_SOURCE}" STREQUAL "" AND NOT "${BOOST_SOURCE}" STREQUAL "")
  set(Boost_SOURCE ${BOOST_SOURCE})
endif()

# For backward compatibility. We use "RE2_SOURCE" if "re2_SOURCE"
# isn't specified and "RE2_SOURCE" is specified.
# We renamed "RE2" dependency name to "re2" in 3.0.0 because
# upstream uses "re2" not "RE2" as package name.
if("${re2_SOURCE}" STREQUAL "" AND NOT "${RE2_SOURCE}" STREQUAL "")
  set(re2_SOURCE ${RE2_SOURCE})
endif()

message(STATUS "Using ${ARROW_DEPENDENCY_SOURCE} approach to find dependencies")

if(ARROW_DEPENDENCY_SOURCE STREQUAL "CONDA")
  if(MSVC)
    set(ARROW_PACKAGE_PREFIX "$ENV{CONDA_PREFIX}/Library")
  else()
    set(ARROW_PACKAGE_PREFIX $ENV{CONDA_PREFIX})
  endif()
  set(ARROW_ACTUAL_DEPENDENCY_SOURCE "SYSTEM")
  message(STATUS "Using CONDA_PREFIX for ARROW_PACKAGE_PREFIX: ${ARROW_PACKAGE_PREFIX}")
else()
  set(ARROW_ACTUAL_DEPENDENCY_SOURCE "${ARROW_DEPENDENCY_SOURCE}")
endif()

if(ARROW_PACKAGE_PREFIX)
  message(STATUS "Setting (unset) dependency *_ROOT variables: ${ARROW_PACKAGE_PREFIX}")
  set(ENV{PKG_CONFIG_PATH} "${ARROW_PACKAGE_PREFIX}/lib/pkgconfig/")

  if(NOT ENV{BOOST_ROOT})
    set(ENV{BOOST_ROOT} ${ARROW_PACKAGE_PREFIX})
  endif()
  if(NOT ENV{Boost_ROOT})
    set(ENV{Boost_ROOT} ${ARROW_PACKAGE_PREFIX})
  endif()
endif()

# For each dependency, set dependency source to global default, if unset
foreach(DEPENDENCY ${ARROW_THIRDPARTY_DEPENDENCIES})
  if("${${DEPENDENCY}_SOURCE}" STREQUAL "")
    set(${DEPENDENCY}_SOURCE ${ARROW_ACTUAL_DEPENDENCY_SOURCE})
    # If no ROOT was supplied and we have a global prefix, use it
    if(NOT ${DEPENDENCY}_ROOT AND ARROW_PACKAGE_PREFIX)
      set(${DEPENDENCY}_ROOT ${ARROW_PACKAGE_PREFIX})
    endif()
  endif()
endforeach()

macro(build_dependency DEPENDENCY_NAME)
  if("${DEPENDENCY_NAME}" STREQUAL "AWSSDK")
    build_awssdk()
  elseif("${DEPENDENCY_NAME}" STREQUAL "benchmark")
    build_benchmark()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Boost")
    build_boost()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Brotli")
    build_brotli()
  elseif("${DEPENDENCY_NAME}" STREQUAL "BZip2")
    build_bzip2()
  elseif("${DEPENDENCY_NAME}" STREQUAL "c-ares")
    build_cares()
  elseif("${DEPENDENCY_NAME}" STREQUAL "gflags")
    build_gflags()
  elseif("${DEPENDENCY_NAME}" STREQUAL "GLOG")
    build_glog()
  elseif("${DEPENDENCY_NAME}" STREQUAL "google_cloud_cpp_storage")
    build_google_cloud_cpp_storage()
  elseif("${DEPENDENCY_NAME}" STREQUAL "gRPC")
    build_grpc()
  elseif("${DEPENDENCY_NAME}" STREQUAL "GTest")
    build_gtest()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Lz4")
    build_lz4()
  elseif("${DEPENDENCY_NAME}" STREQUAL "opentelemetry-cpp")
    build_opentelemetry()
  elseif("${DEPENDENCY_NAME}" STREQUAL "ORC")
    build_orc()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Protobuf")
    build_protobuf()
  elseif("${DEPENDENCY_NAME}" STREQUAL "RapidJSON")
    build_rapidjson()
  elseif("${DEPENDENCY_NAME}" STREQUAL "re2")
    build_re2()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Snappy")
    build_snappy()
  elseif("${DEPENDENCY_NAME}" STREQUAL "Thrift")
    build_thrift()
  elseif("${DEPENDENCY_NAME}" STREQUAL "utf8proc")
    build_utf8proc()
  elseif("${DEPENDENCY_NAME}" STREQUAL "xsimd")
    build_xsimd()
  elseif("${DEPENDENCY_NAME}" STREQUAL "ZLIB")
    build_zlib()
  elseif("${DEPENDENCY_NAME}" STREQUAL "zstd")
    build_zstd()
  else()
    message(FATAL_ERROR "Unknown thirdparty dependency to build: ${DEPENDENCY_NAME}")
  endif()
endmacro()

# Find modules are needed by the consumer in case of a static build, or if the
# linkage is PUBLIC or INTERFACE.
macro(provide_find_module PACKAGE_NAME)
  set(module_ "${CMAKE_SOURCE_DIR}/cmake_modules/Find${PACKAGE_NAME}.cmake")
  if(EXISTS "${module_}")
    message(STATUS "Providing CMake module for ${PACKAGE_NAME}")
    install(FILES "${module_}" DESTINATION "${ARROW_CMAKE_INSTALL_DIR}")
  endif()
  unset(module_)
endmacro()

macro(resolve_dependency DEPENDENCY_NAME)
  set(options)
  set(one_value_args HAVE_ALT IS_RUNTIME_DEPENDENCY REQUIRED_VERSION USE_CONFIG)
  set(multi_value_args PC_PACKAGE_NAMES)
  cmake_parse_arguments(ARG
                        "${options}"
                        "${one_value_args}"
                        "${multi_value_args}"
                        ${ARGN})
  if(ARG_UNPARSED_ARGUMENTS)
    message(SEND_ERROR "Error: unrecognized arguments: ${ARG_UNPARSED_ARGUMENTS}")
  endif()
  if("${ARG_IS_RUNTIME_DEPENDENCY}" STREQUAL "")
    set(ARG_IS_RUNTIME_DEPENDENCY TRUE)
  endif()

  if(ARG_HAVE_ALT)
    set(PACKAGE_NAME "${DEPENDENCY_NAME}Alt")
  else()
    set(PACKAGE_NAME ${DEPENDENCY_NAME})
  endif()
  set(FIND_PACKAGE_ARGUMENTS ${PACKAGE_NAME})
  if(ARG_REQUIRED_VERSION)
    list(APPEND FIND_PACKAGE_ARGUMENTS ${ARG_REQUIRED_VERSION})
  endif()
  if(ARG_USE_CONFIG)
    list(APPEND FIND_PACKAGE_ARGUMENTS CONFIG)
  endif()
  if(${DEPENDENCY_NAME}_SOURCE STREQUAL "AUTO")
    find_package(${FIND_PACKAGE_ARGUMENTS})
    if(${${PACKAGE_NAME}_FOUND})
      set(${DEPENDENCY_NAME}_SOURCE "SYSTEM")
    else()
      build_dependency(${DEPENDENCY_NAME})
      set(${DEPENDENCY_NAME}_SOURCE "BUNDLED")
    endif()
  elseif(${DEPENDENCY_NAME}_SOURCE STREQUAL "BUNDLED")
    build_dependency(${DEPENDENCY_NAME})
  elseif(${DEPENDENCY_NAME}_SOURCE STREQUAL "SYSTEM")
    find_package(${FIND_PACKAGE_ARGUMENTS} REQUIRED)
  endif()
  if(${DEPENDENCY_NAME}_SOURCE STREQUAL "SYSTEM" AND ARG_IS_RUNTIME_DEPENDENCY)
    provide_find_module(${PACKAGE_NAME})
    list(APPEND ARROW_SYSTEM_DEPENDENCIES ${PACKAGE_NAME})
    find_package(PkgConfig QUIET)
    foreach(ARG_PC_PACKAGE_NAME ${ARG_PC_PACKAGE_NAMES})
      pkg_check_modules(${ARG_PC_PACKAGE_NAME}_PC
                        ${ARG_PC_PACKAGE_NAME}
                        NO_CMAKE_PATH
                        NO_CMAKE_ENVIRONMENT_PATH
                        QUIET)
      if(${${ARG_PC_PACKAGE_NAME}_PC_FOUND})
        string(APPEND ARROW_PC_REQUIRES_PRIVATE " ${ARG_PC_PACKAGE_NAME}")
      endif()
    endforeach()
  endif()
endmacro()

# ----------------------------------------------------------------------
# Thirdparty versions, environment variables, source URLs

set(THIRDPARTY_DIR "${arrow_SOURCE_DIR}/thirdparty")

# Include vendored Flatbuffers
include_directories(SYSTEM "${THIRDPARTY_DIR}/flatbuffers/include")

# ----------------------------------------------------------------------
# Some EP's require other EP's

if(PARQUET_REQUIRE_ENCRYPTION)
  set(ARROW_JSON ON)
endif()

if(ARROW_WITH_OPENTELEMETRY)
  set(ARROW_WITH_PROTOBUF ON)
endif()

if(ARROW_THRIFT)
  set(ARROW_WITH_ZLIB ON)
endif()

if(ARROW_HIVESERVER2 OR ARROW_PARQUET)
  set(ARROW_WITH_THRIFT ON)
  if(ARROW_HIVESERVER2)
    set(ARROW_THRIFT_REQUIRED_COMPONENTS COMPILER)
  else()
    set(ARROW_THRIFT_REQUIRED_COMPONENTS)
  endif()
else()
  set(ARROW_WITH_THRIFT OFF)
endif()

if(ARROW_FLIGHT)
  set(ARROW_WITH_GRPC ON)
endif()

if(ARROW_WITH_GRPC)
  set(ARROW_WITH_ZLIB ON)
endif()

if(ARROW_GCS)
  set(ARROW_WITH_GOOGLE_CLOUD_CPP ON)
endif()

if(ARROW_JSON)
  set(ARROW_WITH_RAPIDJSON ON)
endif()

if(ARROW_ORC
   OR ARROW_FLIGHT
   OR ARROW_GANDIVA)
  set(ARROW_WITH_PROTOBUF ON)
endif()

if(ARROW_S3)
  set(ARROW_WITH_ZLIB ON)
endif()

if((NOT ARROW_COMPUTE) AND (NOT ARROW_GANDIVA))
  set(ARROW_WITH_UTF8PROC OFF)
endif()

if((NOT ARROW_COMPUTE)
   AND (NOT ARROW_GANDIVA)
   AND (NOT ARROW_WITH_GRPC))
  set(ARROW_WITH_RE2 OFF)
endif()

# ----------------------------------------------------------------------
# Versions and URLs for toolchain builds, which also can be used to configure
# offline builds
# Note: We should not use the Apache dist server for build dependencies

macro(set_urls URLS)
  set(${URLS} ${ARGN})
  if(CMAKE_VERSION VERSION_LESS 3.7)
    # ExternalProject doesn't support backup URLs;
    # Feature only available starting in 3.7
    list(GET ${URLS} 0 ${URLS})
  endif()
endmacro()

# Read toolchain versions from cpp/thirdparty/versions.txt
file(STRINGS "${THIRDPARTY_DIR}/versions.txt" TOOLCHAIN_VERSIONS_TXT)
foreach(_VERSION_ENTRY ${TOOLCHAIN_VERSIONS_TXT})
  # Exclude comments
  if(NOT ((_VERSION_ENTRY MATCHES "^[^#][A-Za-z0-9-_]+_VERSION=")
          OR (_VERSION_ENTRY MATCHES "^[^#][A-Za-z0-9-_]+_CHECKSUM=")))
    continue()
  endif()

  string(REGEX MATCH "^[^=]*" _VARIABLE_NAME ${_VERSION_ENTRY})
  string(REPLACE "${_VARIABLE_NAME}=" "" _VARIABLE_VALUE ${_VERSION_ENTRY})

  # Skip blank or malformed lines
  if(_VARIABLE_VALUE STREQUAL "")
    continue()
  endif()

  # For debugging
  message(STATUS "${_VARIABLE_NAME}: ${_VARIABLE_VALUE}")

  set(${_VARIABLE_NAME} ${_VARIABLE_VALUE})
endforeach()

if(DEFINED ENV{ARROW_ABSL_URL})
  set(ABSL_SOURCE_URL "$ENV{ARROW_ABSL_URL}")
else()
  set_urls(ABSL_SOURCE_URL
           "https://github.com/abseil/abseil-cpp/archive/${ARROW_ABSL_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_AWS_C_COMMON_URL})
  set(AWS_C_COMMON_SOURCE_URL "$ENV{ARROW_AWS_C_COMMON_URL}")
else()
  set_urls(AWS_C_COMMON_SOURCE_URL
           "https://github.com/awslabs/aws-c-common/archive/${ARROW_AWS_C_COMMON_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_AWS_CHECKSUMS_URL})
  set(AWS_CHECKSUMS_SOURCE_URL "$ENV{ARROW_AWS_CHECKSUMS_URL}")
else()
  set_urls(AWS_CHECKSUMS_SOURCE_URL
           "https://github.com/awslabs/aws-checksums/archive/${ARROW_AWS_CHECKSUMS_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_AWS_C_EVENT_STREAM_URL})
  set(AWS_C_EVENT_STREAM_SOURCE_URL "$ENV{ARROW_AWS_C_EVENT_STREAM_URL}")
else()
  set_urls(AWS_C_EVENT_STREAM_SOURCE_URL
           "https://github.com/awslabs/aws-c-event-stream/archive/${ARROW_AWS_C_EVENT_STREAM_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_AWSSDK_URL})
  set(AWSSDK_SOURCE_URL "$ENV{ARROW_AWSSDK_URL}")
else()
  set_urls(AWSSDK_SOURCE_URL
           "https://github.com/aws/aws-sdk-cpp/archive/${ARROW_AWSSDK_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/aws-sdk-cpp-${ARROW_AWSSDK_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_BOOST_URL})
  set(BOOST_SOURCE_URL "$ENV{ARROW_BOOST_URL}")
else()
  string(REPLACE "." "_" ARROW_BOOST_BUILD_VERSION_UNDERSCORES
                 ${ARROW_BOOST_BUILD_VERSION})
  set_urls(BOOST_SOURCE_URL
           # These are trimmed boost bundles we maintain.
           # See cpp/build-support/trim-boost.sh
           # FIXME(ARROW-6407) automate uploading this archive to ensure it reflects
           # our currently used packages and doesn't fall out of sync with
           # ${ARROW_BOOST_BUILD_VERSION_UNDERSCORES}
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/boost_${ARROW_BOOST_BUILD_VERSION_UNDERSCORES}.tar.gz"
           "https://boostorg.jfrog.io/artifactory/main/release/${ARROW_BOOST_BUILD_VERSION}/source/boost_${ARROW_BOOST_BUILD_VERSION_UNDERSCORES}.tar.gz"
           "https://sourceforge.net/projects/boost/files/boost/${ARROW_BOOST_BUILD_VERSION}/boost_${ARROW_BOOST_BUILD_VERSION_UNDERSCORES}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_BROTLI_URL})
  set(BROTLI_SOURCE_URL "$ENV{ARROW_BROTLI_URL}")
else()
  set_urls(BROTLI_SOURCE_URL
           "https://github.com/google/brotli/archive/${ARROW_BROTLI_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/brotli-${ARROW_BROTLI_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_BZIP2_URL})
  set(ARROW_BZIP2_SOURCE_URL "$ENV{ARROW_BZIP2_URL}")
else()
  set_urls(ARROW_BZIP2_SOURCE_URL
           "https://sourceware.org/pub/bzip2/bzip2-${ARROW_BZIP2_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/bzip2-${ARROW_BZIP2_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_CARES_URL})
  set(CARES_SOURCE_URL "$ENV{ARROW_CARES_URL}")
else()
  set_urls(CARES_SOURCE_URL
           "https://c-ares.haxx.se/download/c-ares-${ARROW_CARES_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/cares-${ARROW_CARES_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_CRC32C_URL})
  set(CRC32C_URL "$ENV{ARROW_CRC32C_URL}")
else()
  set_urls(CRC32C_SOURCE_URL
           "https://github.com/google/crc32c/archive/${ARROW_CRC32C_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GBENCHMARK_URL})
  set(GBENCHMARK_SOURCE_URL "$ENV{ARROW_GBENCHMARK_URL}")
else()
  set_urls(GBENCHMARK_SOURCE_URL
           "https://github.com/google/benchmark/archive/${ARROW_GBENCHMARK_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/gbenchmark-${ARROW_GBENCHMARK_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GFLAGS_URL})
  set(GFLAGS_SOURCE_URL "$ENV{ARROW_GFLAGS_URL}")
else()
  set_urls(GFLAGS_SOURCE_URL
           "https://github.com/gflags/gflags/archive/${ARROW_GFLAGS_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/gflags-${ARROW_GFLAGS_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GLOG_URL})
  set(GLOG_SOURCE_URL "$ENV{ARROW_GLOG_URL}")
else()
  set_urls(GLOG_SOURCE_URL
           "https://github.com/google/glog/archive/${ARROW_GLOG_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/glog-${ARROW_GLOG_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GOOGLE_CLOUD_CPP_URL})
  set(google_cloud_cpp_storage_SOURCE_URL "$ENV{ARROW_GOOGLE_CLOUD_CPP_URL}")
else()
  set_urls(google_cloud_cpp_storage_SOURCE_URL
           "https://github.com/googleapis/google-cloud-cpp/archive/${ARROW_GOOGLE_CLOUD_CPP_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GRPC_URL})
  set(GRPC_SOURCE_URL "$ENV{ARROW_GRPC_URL}")
else()
  set_urls(GRPC_SOURCE_URL
           "https://github.com/grpc/grpc/archive/${ARROW_GRPC_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/grpc-${ARROW_GRPC_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_GTEST_URL})
  set(GTEST_SOURCE_URL "$ENV{ARROW_GTEST_URL}")
else()
  set_urls(GTEST_SOURCE_URL
           "https://github.com/google/googletest/archive/release-${ARROW_GTEST_BUILD_VERSION}.tar.gz"
           "https://chromium.googlesource.com/external/github.com/google/googletest/+archive/release-${ARROW_GTEST_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/gtest-${ARROW_GTEST_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_JEMALLOC_URL})
  set(JEMALLOC_SOURCE_URL "$ENV{ARROW_JEMALLOC_URL}")
else()
  set_urls(JEMALLOC_SOURCE_URL
           "https://github.com/jemalloc/jemalloc/releases/download/${ARROW_JEMALLOC_BUILD_VERSION}/jemalloc-${ARROW_JEMALLOC_BUILD_VERSION}.tar.bz2"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/jemalloc-${ARROW_JEMALLOC_BUILD_VERSION}.tar.bz2"
  )
endif()

if(DEFINED ENV{ARROW_MIMALLOC_URL})
  set(MIMALLOC_SOURCE_URL "$ENV{ARROW_MIMALLOC_URL}")
else()
  set_urls(MIMALLOC_SOURCE_URL
           "https://github.com/microsoft/mimalloc/archive/${ARROW_MIMALLOC_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/mimalloc-${ARROW_MIMALLOC_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_NLOHMANN_JSON_URL})
  set(NLOHMANN_JSON_SOURCE_URL "$ENV{ARROW_NLOHMANN_JSON_URL}")
else()
  set_urls(NLOHMANN_JSON_SOURCE_URL
           "https://github.com/nlohmann/json/archive/${ARROW_NLOHMANN_JSON_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_LZ4_URL})
  set(LZ4_SOURCE_URL "$ENV{ARROW_LZ4_URL}")
else()
  set_urls(LZ4_SOURCE_URL
           "https://github.com/lz4/lz4/archive/${ARROW_LZ4_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/lz4-${ARROW_LZ4_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_ORC_URL})
  set(ORC_SOURCE_URL "$ENV{ARROW_ORC_URL}")
else()
  set_urls(ORC_SOURCE_URL
           "https://archive.apache.org/dist/orc/orc-${ARROW_ORC_BUILD_VERSION}/orc-${ARROW_ORC_BUILD_VERSION}.tar.gz"
           "https://github.com/apache/orc/archive/rel/release-${ARROW_ORC_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_OPENTELEMETRY_URL})
  set(OPENTELEMETRY_SOURCE_URL "$ENV{ARROW_OPENTELEMETRY_URL}")
else()
  # TODO: add mirror
  set_urls(OPENTELEMETRY_SOURCE_URL
           "https://github.com/open-telemetry/opentelemetry-cpp/archive/refs/tags/${ARROW_OPENTELEMETRY_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_OPENTELEMETRY_PROTO_URL})
  set(OPENTELEMETRY_PROTO_SOURCE_URL "$ENV{ARROW_OPENTELEMETRY_PROTO_URL}")
else()
  # TODO: add mirror
  # N.B. upstream pins to particular commits, not tags
  set_urls(OPENTELEMETRY_PROTO_SOURCE_URL
           "https://github.com/open-telemetry/opentelemetry-proto/archive/${ARROW_OPENTELEMETRY_PROTO_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_PROTOBUF_URL})
  set(PROTOBUF_SOURCE_URL "$ENV{ARROW_PROTOBUF_URL}")
else()
  string(SUBSTRING ${ARROW_PROTOBUF_BUILD_VERSION} 1 -1
                   ARROW_PROTOBUF_STRIPPED_BUILD_VERSION)
  # strip the leading `v`
  set_urls(PROTOBUF_SOURCE_URL
           "https://github.com/protocolbuffers/protobuf/releases/download/${ARROW_PROTOBUF_BUILD_VERSION}/protobuf-all-${ARROW_PROTOBUF_STRIPPED_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/protobuf-${ARROW_PROTOBUF_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_RE2_URL})
  set(RE2_SOURCE_URL "$ENV{ARROW_RE2_URL}")
else()
  set_urls(RE2_SOURCE_URL
           "https://github.com/google/re2/archive/${ARROW_RE2_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/re2-${ARROW_RE2_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_RAPIDJSON_URL})
  set(RAPIDJSON_SOURCE_URL "$ENV{ARROW_RAPIDJSON_URL}")
else()
  set_urls(RAPIDJSON_SOURCE_URL
           "https://github.com/miloyip/rapidjson/archive/${ARROW_RAPIDJSON_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/rapidjson-${ARROW_RAPIDJSON_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_SNAPPY_URL})
  set(SNAPPY_SOURCE_URL "$ENV{ARROW_SNAPPY_URL}")
else()
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS
                                              "4.9")
    # There is a bug in GCC < 4.9 with Snappy 1.1.9, so revert to 1.1.8 "SNAPPY_OLD" for those (ARROW-14661)
    set_urls(SNAPPY_SOURCE_URL
             "https://github.com/google/snappy/archive/${ARROW_SNAPPY_OLD_BUILD_VERSION}.tar.gz"
             "https://github.com/ursa-labs/thirdparty/releases/download/latest/snappy-${ARROW_SNAPPY_OLD_BUILD_VERSION}.tar.gz"
    )
    set(ARROW_SNAPPY_BUILD_SHA256_CHECKSUM ${ARROW_SNAPPY_OLD_BUILD_SHA256_CHECKSUM})
  else()
    set_urls(SNAPPY_SOURCE_URL
             "https://github.com/google/snappy/archive/${ARROW_SNAPPY_BUILD_VERSION}.tar.gz"
             "https://github.com/ursa-labs/thirdparty/releases/download/latest/snappy-${ARROW_SNAPPY_BUILD_VERSION}.tar.gz"
    )

    # This can be removed when https://github.com/google/snappy/pull/148 is released
    # Some platforms don't have patch, but this is probably ok to skip
    find_program(patch "patch")
    if(patch)
      set(SNAPPY_PATCH_COMMAND "patch" "snappy.cc"
                               "${CMAKE_SOURCE_DIR}/build-support/snappy-UBSAN.patch")
    endif()
  endif()
endif()

if(DEFINED ENV{ARROW_THRIFT_URL})
  set(THRIFT_SOURCE_URL "$ENV{ARROW_THRIFT_URL}")
else()
  set_urls(THRIFT_SOURCE_URL
           "https://www.apache.org/dyn/closer.cgi?action=download&filename=/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://downloads.apache.org/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://github.com/apache/thrift/archive/v${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://apache.claz.org/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://apache.cs.utah.edu/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://apache.mirrors.lucidnetworks.net/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://apache.osuosl.org/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://ftp.wayne.edu/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://mirror.olnevhost.net/pub/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://mirrors.gigenet.com/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://mirrors.koehn.com/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://mirrors.ocf.berkeley.edu/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://mirrors.sonic.net/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://us.mirrors.quenda.co/apache/thrift/${ARROW_THRIFT_BUILD_VERSION}/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/thrift-${ARROW_THRIFT_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_UTF8PROC_URL})
  set(ARROW_UTF8PROC_SOURCE_URL "$ENV{ARROW_UTF8PROC_URL}")
else()
  set_urls(ARROW_UTF8PROC_SOURCE_URL
           "https://github.com/JuliaStrings/utf8proc/archive/${ARROW_UTF8PROC_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_XSIMD_URL})
  set(XSIMD_SOURCE_URL "$ENV{ARROW_XSIMD_URL}")
else()
  set_urls(XSIMD_SOURCE_URL
           "https://github.com/xtensor-stack/xsimd/archive/${ARROW_XSIMD_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_ZLIB_URL})
  set(ZLIB_SOURCE_URL "$ENV{ARROW_ZLIB_URL}")
else()
  set_urls(ZLIB_SOURCE_URL
           "https://zlib.net/fossils/zlib-${ARROW_ZLIB_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/zlib-${ARROW_ZLIB_BUILD_VERSION}.tar.gz"
  )
endif()

if(DEFINED ENV{ARROW_ZSTD_URL})
  set(ZSTD_SOURCE_URL "$ENV{ARROW_ZSTD_URL}")
else()
  set_urls(ZSTD_SOURCE_URL
           "https://github.com/facebook/zstd/archive/${ARROW_ZSTD_BUILD_VERSION}.tar.gz"
           "https://github.com/ursa-labs/thirdparty/releases/download/latest/zstd-${ARROW_ZSTD_BUILD_VERSION}.tar.gz"
  )
endif()

# ----------------------------------------------------------------------
# ExternalProject options

set(EP_CXX_FLAGS
    "${CMAKE_CXX_COMPILER_ARG1} ${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}}"
)
set(EP_C_FLAGS
    "${CMAKE_C_COMPILER_ARG1} ${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}}")

if(NOT MSVC_TOOLCHAIN)
  # Set -fPIC on all external projects
  set(EP_CXX_FLAGS "${EP_CXX_FLAGS} -fPIC")
  set(EP_C_FLAGS "${EP_C_FLAGS} -fPIC")
endif()

# CC/CXX environment variables are captured on the first invocation of the
# builder (e.g make or ninja) instead of when CMake is invoked into to build
# directory. This leads to issues if the variables are exported in a subshell
# and the invocation of make/ninja is in distinct subshell without the same
# environment (CC/CXX).
set(EP_COMMON_TOOLCHAIN -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
                        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER})

if(CMAKE_AR)
  set(EP_COMMON_TOOLCHAIN ${EP_COMMON_TOOLCHAIN} -DCMAKE_AR=${CMAKE_AR})
endif()

if(CMAKE_RANLIB)
  set(EP_COMMON_TOOLCHAIN ${EP_COMMON_TOOLCHAIN} -DCMAKE_RANLIB=${CMAKE_RANLIB})
endif()

# External projects are still able to override the following declarations.
# cmake command line will favor the last defined variable when a duplicate is
# encountered. This requires that `EP_COMMON_CMAKE_ARGS` is always the first
# argument.
set(EP_COMMON_CMAKE_ARGS
    ${EP_COMMON_TOOLCHAIN}
    ${EP_COMMON_CMAKE_ARGS}
    -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
    -DCMAKE_C_FLAGS=${EP_C_FLAGS}
    -DCMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_C_FLAGS}
    -DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}
    -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${EP_CXX_FLAGS}
    -DCMAKE_CXX_STANDARD=${CMAKE_CXX_STANDARD}
    -DCMAKE_EXPORT_NO_PACKAGE_REGISTRY=${CMAKE_EXPORT_NO_PACKAGE_REGISTRY}
    -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=${CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY})

if(NOT ARROW_VERBOSE_THIRDPARTY_BUILD)
  set(EP_LOG_OPTIONS
      LOG_CONFIGURE
      1
      LOG_BUILD
      1
      LOG_INSTALL
      1
      LOG_DOWNLOAD
      1
      LOG_OUTPUT_ON_FAILURE
      1)
  set(Boost_DEBUG FALSE)
else()
  set(EP_LOG_OPTIONS)
  set(Boost_DEBUG TRUE)
endif()

# Ensure that a default make is set
if("${MAKE}" STREQUAL "")
  if(NOT MSVC)
    find_program(MAKE make)
  endif()
endif()

# Using make -j in sub-make is fragile
# see discussion https://github.com/apache/arrow/pull/2779
if(${CMAKE_GENERATOR} MATCHES "Makefiles")
  set(MAKE_BUILD_ARGS "")
else()
  # limit the maximum number of jobs for ninja
  set(MAKE_BUILD_ARGS "-j${NPROC}")
endif()

# ----------------------------------------------------------------------
# Find pthreads

set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)

# ----------------------------------------------------------------------
# Add Boost dependencies (code adapted from Apache Kudu)

macro(build_boost)
  set(BOOST_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/boost_ep-prefix/src/boost_ep")

  # This is needed by the thrift_ep build
  set(BOOST_ROOT ${BOOST_PREFIX})

  if(ARROW_BOOST_REQUIRE_LIBRARY)
    set(BOOST_LIB_DIR "${BOOST_PREFIX}/stage/lib")
    set(BOOST_BUILD_LINK "static")
    if("${CMAKE_BUILD_TYPE}" STREQUAL "DEBUG")
      set(BOOST_BUILD_VARIANT "debug")
    else()
      set(BOOST_BUILD_VARIANT "release")
    endif()
    if(MSVC)
      set(BOOST_CONFIGURE_COMMAND ".\\\\bootstrap.bat")
    else()
      set(BOOST_CONFIGURE_COMMAND "./bootstrap.sh")
    endif()

    set(BOOST_BUILD_WITH_LIBRARIES "filesystem" "system")
    string(REPLACE ";" "," BOOST_CONFIGURE_LIBRARIES "${BOOST_BUILD_WITH_LIBRARIES}")
    list(APPEND BOOST_CONFIGURE_COMMAND "--prefix=${BOOST_PREFIX}"
         "--with-libraries=${BOOST_CONFIGURE_LIBRARIES}")
    set(BOOST_BUILD_COMMAND "./b2" "-j${NPROC}" "link=${BOOST_BUILD_LINK}"
                            "variant=${BOOST_BUILD_VARIANT}")
    if(MSVC)
      string(REGEX REPLACE "([0-9])$" ".\\1" BOOST_TOOLSET_MSVC_VERSION
                           ${MSVC_TOOLSET_VERSION})
      list(APPEND BOOST_BUILD_COMMAND "toolset=msvc-${BOOST_TOOLSET_MSVC_VERSION}")
      set(BOOST_BUILD_WITH_LIBRARIES_MSVC)
      foreach(_BOOST_LIB ${BOOST_BUILD_WITH_LIBRARIES})
        list(APPEND BOOST_BUILD_WITH_LIBRARIES_MSVC "--with-${_BOOST_LIB}")
      endforeach()
      list(APPEND BOOST_BUILD_COMMAND ${BOOST_BUILD_WITH_LIBRARIES_MSVC})
    else()
      list(APPEND BOOST_BUILD_COMMAND "cxxflags=-fPIC")
    endif()

    if(MSVC)
      string(REGEX
             REPLACE "^([0-9]+)\\.([0-9]+)\\.[0-9]+$" "\\1_\\2"
                     ARROW_BOOST_BUILD_VERSION_NO_MICRO_UNDERSCORE
                     ${ARROW_BOOST_BUILD_VERSION})
      set(BOOST_LIBRARY_SUFFIX "-vc${MSVC_TOOLSET_VERSION}-mt")
      if(BOOST_BUILD_VARIANT STREQUAL "debug")
        set(BOOST_LIBRARY_SUFFIX "${BOOST_LIBRARY_SUFFIX}-gd")
      endif()
      set(BOOST_LIBRARY_SUFFIX
          "${BOOST_LIBRARY_SUFFIX}-x64-${ARROW_BOOST_BUILD_VERSION_NO_MICRO_UNDERSCORE}")
    else()
      set(BOOST_LIBRARY_SUFFIX "")
    endif()
    set(BOOST_STATIC_SYSTEM_LIBRARY
        "${BOOST_LIB_DIR}/libboost_system${BOOST_LIBRARY_SUFFIX}${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
    set(BOOST_STATIC_FILESYSTEM_LIBRARY
        "${BOOST_LIB_DIR}/libboost_filesystem${BOOST_LIBRARY_SUFFIX}${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
    set(BOOST_SYSTEM_LIBRARY boost_system_static)
    set(BOOST_FILESYSTEM_LIBRARY boost_filesystem_static)
    set(BOOST_BUILD_PRODUCTS ${BOOST_STATIC_SYSTEM_LIBRARY}
                             ${BOOST_STATIC_FILESYSTEM_LIBRARY})

    add_thirdparty_lib(boost_system STATIC_LIB "${BOOST_STATIC_SYSTEM_LIBRARY}")

    add_thirdparty_lib(boost_filesystem STATIC_LIB "${BOOST_STATIC_FILESYSTEM_LIBRARY}")

    externalproject_add(boost_ep
                        URL ${BOOST_SOURCE_URL}
                        URL_HASH "SHA256=${ARROW_BOOST_BUILD_SHA256_CHECKSUM}"
                        BUILD_BYPRODUCTS ${BOOST_BUILD_PRODUCTS}
                        BUILD_IN_SOURCE 1
                        CONFIGURE_COMMAND ${BOOST_CONFIGURE_COMMAND}
                        BUILD_COMMAND ${BOOST_BUILD_COMMAND}
                        INSTALL_COMMAND "" ${EP_LOG_OPTIONS})
    add_dependencies(boost_system_static boost_ep)
    add_dependencies(boost_filesystem_static boost_ep)
  else()
    externalproject_add(boost_ep
                        ${EP_LOG_OPTIONS}
                        BUILD_COMMAND ""
                        CONFIGURE_COMMAND ""
                        INSTALL_COMMAND ""
                        URL ${BOOST_SOURCE_URL}
                        URL_HASH "SHA256=${ARROW_BOOST_BUILD_SHA256_CHECKSUM}")
  endif()
  set(Boost_INCLUDE_DIR "${BOOST_PREFIX}")
  set(Boost_INCLUDE_DIRS "${Boost_INCLUDE_DIR}")
  add_dependencies(toolchain boost_ep)
  set(BOOST_VENDORED TRUE)
endmacro()

if(ARROW_FLIGHT AND ARROW_BUILD_TESTS)
  set(ARROW_BOOST_REQUIRED_VERSION "1.64")
else()
  set(ARROW_BOOST_REQUIRED_VERSION "1.58")
endif()

set(Boost_USE_MULTITHREADED ON)
if(MSVC AND ARROW_USE_STATIC_CRT)
  set(Boost_USE_STATIC_RUNTIME ON)
endif()
set(Boost_ADDITIONAL_VERSIONS
    "1.75.0"
    "1.75"
    "1.74.0"
    "1.74"
    "1.73.0"
    "1.73"
    "1.72.0"
    "1.72"
    "1.71.0"
    "1.71"
    "1.70.0"
    "1.70"
    "1.69.0"
    "1.69"
    "1.68.0"
    "1.68"
    "1.67.0"
    "1.67"
    "1.66.0"
    "1.66"
    "1.65.0"
    "1.65"
    "1.64.0"
    "1.64"
    "1.63.0"
    "1.63"
    "1.62.0"
    "1.61"
    "1.61.0"
    "1.62"
    "1.60.0"
    "1.60")

# Thrift needs Boost if we're building the bundled version with version < 0.13,
# so we first need to determine whether we're building it
if(ARROW_WITH_THRIFT AND Thrift_SOURCE STREQUAL "AUTO")
  find_package(Thrift 0.11.0 MODULE COMPONENTS ${ARROW_THRIFT_REQUIRED_COMPONENTS})
  if(Thrift_FOUND)
    find_package(PkgConfig QUIET)
    pkg_check_modules(THRIFT_PC
                      thrift
                      NO_CMAKE_PATH
                      NO_CMAKE_ENVIRONMENT_PATH
                      QUIET)
    if(THRIFT_PC_FOUND)
      string(APPEND ARROW_PC_REQUIRES_PRIVATE " thrift")
    endif()
  else()
    set(Thrift_SOURCE "BUNDLED")
  endif()
endif()

# Thrift < 0.13 has a compile-time header dependency on boost
if(Thrift_SOURCE STREQUAL "BUNDLED" AND ARROW_THRIFT_BUILD_VERSION VERSION_LESS "0.13")
  set(THRIFT_REQUIRES_BOOST TRUE)
elseif(THRIFT_VERSION VERSION_LESS "0.13")
  set(THRIFT_REQUIRES_BOOST TRUE)
else()
  set(THRIFT_REQUIRES_BOOST FALSE)
endif()

# Compilers that don't support int128_t have a compile-time
# (header-only) dependency on Boost for int128_t.
if(ARROW_USE_UBSAN)
  # NOTE: Avoid native int128_t on clang with UBSan as it produces linker errors
  # (such as "undefined reference to '__muloti4'")
  set(ARROW_USE_NATIVE_INT128 FALSE)
else()
  include(CheckCXXSymbolExists)
  check_cxx_symbol_exists("_M_ARM64" "" WIN32_ARM64_TARGET)
  if(WIN32_ARM64_TARGET AND CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    # NOTE: For clang/win-arm64, native int128_t produce linker errors
    set(ARROW_USE_NATIVE_INT128 FALSE)
  else()
    check_cxx_symbol_exists("__SIZEOF_INT128__" "" ARROW_USE_NATIVE_INT128)
  endif()
endif()

# - Gandiva has a compile-time (header-only) dependency on Boost, not runtime.
# - Tests need Boost at runtime.
# - S3FS and Flight benchmarks need Boost at runtime.
if(ARROW_BUILD_INTEGRATION
   OR ARROW_BUILD_TESTS
   OR (ARROW_FLIGHT AND ARROW_BUILD_BENCHMARKS)
   OR (ARROW_S3 AND ARROW_BUILD_BENCHMARKS))
  set(ARROW_BOOST_REQUIRED TRUE)
  set(ARROW_BOOST_REQUIRE_LIBRARY TRUE)
elseif(ARROW_GANDIVA
       OR (ARROW_WITH_THRIFT AND THRIFT_REQUIRES_BOOST)
       OR (NOT ARROW_USE_NATIVE_INT128))
  set(ARROW_BOOST_REQUIRED TRUE)
  set(ARROW_BOOST_REQUIRE_LIBRARY FALSE)
else()
  set(ARROW_BOOST_REQUIRED FALSE)
endif()

if(ARROW_BOOST_REQUIRED)
  resolve_dependency(Boost
                     HAVE_ALT
                     TRUE
                     REQUIRED_VERSION
                     ${ARROW_BOOST_REQUIRED_VERSION}
                     IS_RUNTIME_DEPENDENCY
                     # libarrow.so doesn't depend on libboost*.
                     FALSE)

  if(TARGET Boost::system)
    set(BOOST_SYSTEM_LIBRARY Boost::system)
    set(BOOST_FILESYSTEM_LIBRARY Boost::filesystem)
  elseif(BoostAlt_FOUND)
    set(BOOST_SYSTEM_LIBRARY ${Boost_SYSTEM_LIBRARY})
    set(BOOST_FILESYSTEM_LIBRARY ${Boost_FILESYSTEM_LIBRARY})
  else()
    set(BOOST_SYSTEM_LIBRARY boost_system_static)
    set(BOOST_FILESYSTEM_LIBRARY boost_filesystem_static)
  endif()
  set(ARROW_BOOST_LIBS ${BOOST_SYSTEM_LIBRARY} ${BOOST_FILESYSTEM_LIBRARY})

  message(STATUS "Boost include dir: ${Boost_INCLUDE_DIR}")
  message(STATUS "Boost libraries: ${ARROW_BOOST_LIBS}")

  include_directories(SYSTEM ${Boost_INCLUDE_DIR})
endif()

# ----------------------------------------------------------------------
# cURL

macro(find_curl)
  if(NOT TARGET CURL::libcurl)
    find_package(CURL REQUIRED)
    if(NOT TARGET CURL::libcurl)
      # For CMake 3.11 or older
      add_library(CURL::libcurl UNKNOWN IMPORTED)
      set_target_properties(CURL::libcurl
                            PROPERTIES INTERFACE_INCLUDE_DIRECTORIES
                                       "${CURL_INCLUDE_DIRS}" IMPORTED_LOCATION
                                                              "${CURL_LIBRARIES}")
    endif()
  endif()
endmacro()

# ----------------------------------------------------------------------
# Snappy

macro(build_snappy)
  message(STATUS "Building snappy from source")
  set(SNAPPY_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/snappy_ep/src/snappy_ep-install")
  set(SNAPPY_STATIC_LIB_NAME snappy)
  set(SNAPPY_STATIC_LIB
      "${SNAPPY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}${SNAPPY_STATIC_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  set(SNAPPY_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DSNAPPY_BUILD_TESTS=OFF
      -DSNAPPY_BUILD_BENCHMARKS=OFF
      "-DCMAKE_INSTALL_PREFIX=${SNAPPY_PREFIX}")

  externalproject_add(snappy_ep
                      ${EP_LOG_OPTIONS}
                      BUILD_IN_SOURCE 1
                      INSTALL_DIR ${SNAPPY_PREFIX}
                      URL ${SNAPPY_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_SNAPPY_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${SNAPPY_CMAKE_ARGS}
                      PATCH_COMMAND ${SNAPPY_PATCH_COMMAND}
                      BUILD_BYPRODUCTS "${SNAPPY_STATIC_LIB}")

  file(MAKE_DIRECTORY "${SNAPPY_PREFIX}/include")

  add_library(Snappy::snappy STATIC IMPORTED)
  set_target_properties(Snappy::snappy
                        PROPERTIES IMPORTED_LOCATION "${SNAPPY_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${SNAPPY_PREFIX}/include")
  add_dependencies(toolchain snappy_ep)
  add_dependencies(Snappy::snappy snappy_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS Snappy::snappy)
endmacro()

if(ARROW_WITH_SNAPPY)
  resolve_dependency(Snappy PC_PACKAGE_NAMES snappy)
  if(${Snappy_SOURCE} STREQUAL "SYSTEM" AND NOT snappy_PC_FOUND)
    get_target_property(SNAPPY_LIB Snappy::snappy IMPORTED_LOCATION)
    string(APPEND ARROW_PC_LIBS_PRIVATE " ${SNAPPY_LIB}")
  endif()
  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(SNAPPY_INCLUDE_DIRS Snappy::snappy INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${SNAPPY_INCLUDE_DIRS})
endif()

# ----------------------------------------------------------------------
# Brotli

macro(build_brotli)
  message(STATUS "Building brotli from source")
  set(BROTLI_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/brotli_ep/src/brotli_ep-install")
  set(BROTLI_INCLUDE_DIR "${BROTLI_PREFIX}/include")
  set(BROTLI_LIB_DIR lib)
  set(BROTLI_STATIC_LIBRARY_ENC
      "${BROTLI_PREFIX}/${BROTLI_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}brotlienc-static${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(BROTLI_STATIC_LIBRARY_DEC
      "${BROTLI_PREFIX}/${BROTLI_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}brotlidec-static${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(BROTLI_STATIC_LIBRARY_COMMON
      "${BROTLI_PREFIX}/${BROTLI_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}brotlicommon-static${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(BROTLI_CMAKE_ARGS ${EP_COMMON_CMAKE_ARGS} "-DCMAKE_INSTALL_PREFIX=${BROTLI_PREFIX}"
                        -DCMAKE_INSTALL_LIBDIR=${BROTLI_LIB_DIR})

  externalproject_add(brotli_ep
                      URL ${BROTLI_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_BROTLI_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${BROTLI_STATIC_LIBRARY_ENC}"
                                       "${BROTLI_STATIC_LIBRARY_DEC}"
                                       "${BROTLI_STATIC_LIBRARY_COMMON}"
                                       ${BROTLI_BUILD_BYPRODUCTS}
                                       ${EP_LOG_OPTIONS}
                      CMAKE_ARGS ${BROTLI_CMAKE_ARGS}
                      STEP_TARGETS headers_copy)

  add_dependencies(toolchain brotli_ep)
  file(MAKE_DIRECTORY "${BROTLI_INCLUDE_DIR}")

  add_library(Brotli::brotlicommon STATIC IMPORTED)
  set_target_properties(Brotli::brotlicommon
                        PROPERTIES IMPORTED_LOCATION "${BROTLI_STATIC_LIBRARY_COMMON}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${BROTLI_INCLUDE_DIR}")
  add_dependencies(Brotli::brotlicommon brotli_ep)

  add_library(Brotli::brotlienc STATIC IMPORTED)
  set_target_properties(Brotli::brotlienc
                        PROPERTIES IMPORTED_LOCATION "${BROTLI_STATIC_LIBRARY_ENC}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${BROTLI_INCLUDE_DIR}")
  add_dependencies(Brotli::brotlienc brotli_ep)

  add_library(Brotli::brotlidec STATIC IMPORTED)
  set_target_properties(Brotli::brotlidec
                        PROPERTIES IMPORTED_LOCATION "${BROTLI_STATIC_LIBRARY_DEC}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${BROTLI_INCLUDE_DIR}")
  add_dependencies(Brotli::brotlidec brotli_ep)

  list(APPEND
       ARROW_BUNDLED_STATIC_LIBS
       Brotli::brotlicommon
       Brotli::brotlienc
       Brotli::brotlidec)
endmacro()

if(ARROW_WITH_BROTLI)
  resolve_dependency(Brotli PC_PACKAGE_NAMES libbrotlidec libbrotlienc)
  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(BROTLI_INCLUDE_DIR Brotli::brotlicommon
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${BROTLI_INCLUDE_DIR})
endif()

if(PARQUET_REQUIRE_ENCRYPTION AND NOT ARROW_PARQUET)
  set(PARQUET_REQUIRE_ENCRYPTION OFF)
endif()
set(ARROW_OPENSSL_REQUIRED_VERSION "1.0.2")
if(BREW_BIN AND NOT OPENSSL_ROOT_DIR)
  execute_process(COMMAND ${BREW_BIN} --prefix "openssl@1.1"
                  OUTPUT_VARIABLE OPENSSL11_BREW_PREFIX
                  OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(OPENSSL11_BREW_PREFIX)
    set(OPENSSL_ROOT_DIR ${OPENSSL11_BREW_PREFIX})
  else()
    execute_process(COMMAND ${BREW_BIN} --prefix "openssl"
                    OUTPUT_VARIABLE OPENSSL_BREW_PREFIX
                    OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(OPENSSL_BREW_PREFIX)
      set(OPENSSL_ROOT_DIR ${OPENSSL_BREW_PREFIX})
    endif()
  endif()
endif()

set(ARROW_USE_OPENSSL OFF)
if(PARQUET_REQUIRE_ENCRYPTION
   OR ARROW_FLIGHT
   OR ARROW_S3)
  # OpenSSL is required
  if(ARROW_OPENSSL_USE_SHARED)
    # Find shared OpenSSL libraries.
    set(OpenSSL_USE_STATIC_LIBS OFF)
    # Seems that different envs capitalize this differently?
    set(OPENSSL_USE_STATIC_LIBS OFF)
    set(BUILD_SHARED_LIBS_KEEP ${BUILD_SHARED_LIBS})
    set(BUILD_SHARED_LIBS ON)

    find_package(OpenSSL ${ARROW_OPENSSL_REQUIRED_VERSION} REQUIRED)
    set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_KEEP})
    unset(BUILD_SHARED_LIBS_KEEP)
  else()
    # Find static OpenSSL headers and libs
    set(OpenSSL_USE_STATIC_LIBS ON)
    set(OPENSSL_USE_STATIC_LIBS ON)
    find_package(OpenSSL ${ARROW_OPENSSL_REQUIRED_VERSION} REQUIRED)
  endif()
  set(ARROW_USE_OPENSSL ON)
endif()

if(ARROW_USE_OPENSSL)
  message(STATUS "Found OpenSSL Crypto Library: ${OPENSSL_CRYPTO_LIBRARY}")
  message(STATUS "Building with OpenSSL (Version: ${OPENSSL_VERSION}) support")

  list(APPEND ARROW_SYSTEM_DEPENDENCIES "OpenSSL")

  include_directories(SYSTEM ${OPENSSL_INCLUDE_DIR})
else()
  message(STATUS "Building without OpenSSL support. Minimum OpenSSL version ${ARROW_OPENSSL_REQUIRED_VERSION} required."
  )
endif()

# ----------------------------------------------------------------------
# GLOG

macro(build_glog)
  message(STATUS "Building glog from source")
  set(GLOG_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/glog_ep-prefix/src/glog_ep")
  set(GLOG_INCLUDE_DIR "${GLOG_BUILD_DIR}/include")
  if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
    set(GLOG_LIB_SUFFIX "d")
  else()
    set(GLOG_LIB_SUFFIX "")
  endif()
  set(GLOG_STATIC_LIB
      "${GLOG_BUILD_DIR}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}glog${GLOG_LIB_SUFFIX}${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GLOG_CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC")
  set(GLOG_CMAKE_C_FLAGS "${EP_C_FLAGS} -fPIC")
  if(CMAKE_THREAD_LIBS_INIT)
    set(GLOG_CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${CMAKE_THREAD_LIBS_INIT}")
    set(GLOG_CMAKE_C_FLAGS "${EP_C_FLAGS} ${CMAKE_THREAD_LIBS_INIT}")
  endif()

  if(APPLE)
    # If we don't set this flag, the binary built with 10.13 cannot be used in 10.12.
    set(GLOG_CMAKE_CXX_FLAGS "${GLOG_CMAKE_CXX_FLAGS} -mmacosx-version-min=10.9")
  endif()

  set(GLOG_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${GLOG_BUILD_DIR}"
      -DBUILD_SHARED_LIBS=OFF
      -DBUILD_TESTING=OFF
      -DWITH_GFLAGS=OFF
      -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${GLOG_CMAKE_CXX_FLAGS}
      -DCMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}=${GLOG_CMAKE_C_FLAGS}
      -DCMAKE_CXX_FLAGS=${GLOG_CMAKE_CXX_FLAGS})
  externalproject_add(glog_ep
                      URL ${GLOG_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_GLOG_BUILD_SHA256_CHECKSUM}"
                      BUILD_IN_SOURCE 1
                      BUILD_BYPRODUCTS "${GLOG_STATIC_LIB}"
                      CMAKE_ARGS ${GLOG_CMAKE_ARGS} ${EP_LOG_OPTIONS})

  add_dependencies(toolchain glog_ep)
  file(MAKE_DIRECTORY "${GLOG_INCLUDE_DIR}")

  add_library(glog::glog STATIC IMPORTED)
  set_target_properties(glog::glog
                        PROPERTIES IMPORTED_LOCATION "${GLOG_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GLOG_INCLUDE_DIR}")
  add_dependencies(glog::glog glog_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS glog::glog)
endmacro()

if(ARROW_USE_GLOG)
  resolve_dependency(GLOG PC_PACKAGE_NAMES libglog)
  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(GLOG_INCLUDE_DIR glog::glog INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${GLOG_INCLUDE_DIR})
endif()

# ----------------------------------------------------------------------
# gflags

if(ARROW_BUILD_TESTS
   OR ARROW_BUILD_BENCHMARKS
   OR ARROW_BUILD_INTEGRATION
   OR ARROW_PLASMA
   OR ARROW_USE_GLOG
   OR ARROW_WITH_GRPC)
  set(ARROW_NEED_GFLAGS 1)
else()
  set(ARROW_NEED_GFLAGS 0)
endif()

macro(build_gflags)
  message(STATUS "Building gflags from source")

  set(GFLAGS_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/gflags_ep-prefix/src/gflags_ep")
  set(GFLAGS_INCLUDE_DIR "${GFLAGS_PREFIX}/include")
  if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
    set(GFLAGS_LIB_SUFFIX "_debug")
  else()
    set(GFLAGS_LIB_SUFFIX "")
  endif()
  if(MSVC)
    set(GFLAGS_STATIC_LIB "${GFLAGS_PREFIX}/lib/gflags_static${GFLAGS_LIB_SUFFIX}.lib")
  else()
    set(GFLAGS_STATIC_LIB "${GFLAGS_PREFIX}/lib/libgflags${GFLAGS_LIB_SUFFIX}.a")
  endif()
  set(GFLAGS_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${GFLAGS_PREFIX}"
      -DBUILD_SHARED_LIBS=OFF
      -DBUILD_STATIC_LIBS=ON
      -DBUILD_PACKAGING=OFF
      -DBUILD_TESTING=OFF
      -DBUILD_CONFIG_TESTS=OFF
      -DINSTALL_HEADERS=ON)

  file(MAKE_DIRECTORY "${GFLAGS_INCLUDE_DIR}")
  externalproject_add(gflags_ep
                      URL ${GFLAGS_SOURCE_URL} ${EP_LOG_OPTIONS}
                      URL_HASH "SHA256=${ARROW_GFLAGS_BUILD_SHA256_CHECKSUM}"
                      BUILD_IN_SOURCE 1
                      BUILD_BYPRODUCTS "${GFLAGS_STATIC_LIB}"
                      CMAKE_ARGS ${GFLAGS_CMAKE_ARGS})

  add_dependencies(toolchain gflags_ep)

  add_thirdparty_lib(gflags STATIC_LIB ${GFLAGS_STATIC_LIB})
  set(GFLAGS_LIBRARY gflags_static)
  set_target_properties(${GFLAGS_LIBRARY}
                        PROPERTIES INTERFACE_COMPILE_DEFINITIONS "GFLAGS_IS_A_DLL=0"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GFLAGS_INCLUDE_DIR}")
  if(MSVC)
    set_target_properties(${GFLAGS_LIBRARY} PROPERTIES INTERFACE_LINK_LIBRARIES
                                                       "shlwapi.lib")
  endif()
  set(GFLAGS_LIBRARIES ${GFLAGS_LIBRARY})

  set(GFLAGS_VENDORED TRUE)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS gflags_static)
endmacro()

if(ARROW_NEED_GFLAGS)
  set(ARROW_GFLAGS_REQUIRED_VERSION "2.1.0")
  resolve_dependency(gflags
                     HAVE_ALT
                     TRUE
                     REQUIRED_VERSION
                     ${ARROW_GFLAGS_REQUIRED_VERSION}
                     IS_RUNTIME_DEPENDENCY
                     FALSE)
  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${GFLAGS_INCLUDE_DIR})

  if(NOT TARGET ${GFLAGS_LIBRARIES})
    if(TARGET gflags-shared)
      set(GFLAGS_LIBRARIES gflags-shared)
    elseif(TARGET gflags_shared)
      set(GFLAGS_LIBRARIES gflags_shared)
    endif()
  endif()
endif()

# ----------------------------------------------------------------------
# Thrift

macro(build_thrift)
  if(CMAKE_VERSION VERSION_LESS 3.10)
    message(FATAL_ERROR "Building thrift using ExternalProject requires at least CMake 3.10"
    )
  endif()
  message("Building Apache Thrift from source")
  set(THRIFT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/thrift_ep-install")
  set(THRIFT_INCLUDE_DIR "${THRIFT_PREFIX}/include")
  set(THRIFT_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${THRIFT_PREFIX}"
      "-DCMAKE_INSTALL_RPATH=${THRIFT_PREFIX}/lib"
      -DBUILD_COMPILER=OFF
      -DBUILD_SHARED_LIBS=OFF
      -DBUILD_TESTING=OFF
      -DBUILD_EXAMPLES=OFF
      -DBUILD_TUTORIALS=OFF
      -DWITH_QT4=OFF
      -DWITH_C_GLIB=OFF
      -DWITH_JAVA=OFF
      -DWITH_PYTHON=OFF
      -DWITH_HASKELL=OFF
      -DWITH_CPP=ON
      -DWITH_STATIC_LIB=ON
      -DWITH_LIBEVENT=OFF
      # Work around https://gitlab.kitware.com/cmake/cmake/issues/18865
      -DBoost_NO_BOOST_CMAKE=ON)

  # Thrift also uses boost. Forward important boost settings if there were ones passed.
  if(DEFINED BOOST_ROOT)
    list(APPEND THRIFT_CMAKE_ARGS "-DBOOST_ROOT=${BOOST_ROOT}")
  endif()
  if(DEFINED Boost_NAMESPACE)
    list(APPEND THRIFT_CMAKE_ARGS "-DBoost_NAMESPACE=${Boost_NAMESPACE}")
  endif()

  set(THRIFT_STATIC_LIB_NAME "${CMAKE_STATIC_LIBRARY_PREFIX}thrift")
  if(MSVC)
    if(ARROW_USE_STATIC_CRT)
      set(THRIFT_STATIC_LIB_NAME "${THRIFT_STATIC_LIB_NAME}mt")
      list(APPEND THRIFT_CMAKE_ARGS "-DWITH_MT=ON")
    else()
      set(THRIFT_STATIC_LIB_NAME "${THRIFT_STATIC_LIB_NAME}md")
      list(APPEND THRIFT_CMAKE_ARGS "-DWITH_MT=OFF")
    endif()
  endif()
  if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
    set(THRIFT_STATIC_LIB_NAME "${THRIFT_STATIC_LIB_NAME}d")
  endif()
  set(THRIFT_STATIC_LIB
      "${THRIFT_PREFIX}/lib/${THRIFT_STATIC_LIB_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}")

  if(BOOST_VENDORED)
    set(THRIFT_DEPENDENCIES ${THRIFT_DEPENDENCIES} boost_ep)
  endif()

  externalproject_add(thrift_ep
                      URL ${THRIFT_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_THRIFT_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${THRIFT_STATIC_LIB}"
                      CMAKE_ARGS ${THRIFT_CMAKE_ARGS}
                      DEPENDS ${THRIFT_DEPENDENCIES} ${EP_LOG_OPTIONS})

  add_library(thrift::thrift STATIC IMPORTED)
  # The include directory must exist before it is referenced by a target.
  file(MAKE_DIRECTORY "${THRIFT_INCLUDE_DIR}")
  set_target_properties(thrift::thrift
                        PROPERTIES IMPORTED_LOCATION "${THRIFT_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${THRIFT_INCLUDE_DIR}")
  add_dependencies(toolchain thrift_ep)
  add_dependencies(thrift::thrift thrift_ep)
  set(THRIFT_VERSION ${ARROW_THRIFT_BUILD_VERSION})

  list(APPEND ARROW_BUNDLED_STATIC_LIBS thrift::thrift)
endmacro()

if(ARROW_WITH_THRIFT)
  # We already may have looked for Thrift earlier, when considering whether
  # to build Boost, so don't look again if already found.
  if(NOT Thrift_FOUND)
    # Thrift c++ code generated by 0.13 requires 0.11 or greater
    resolve_dependency(Thrift
                       REQUIRED_VERSION
                       0.11.0
                       PC_PACKAGE_NAMES
                       thrift)
  endif()
  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${THRIFT_INCLUDE_DIR})

  string(REPLACE "." ";" VERSION_LIST ${THRIFT_VERSION})
  list(GET VERSION_LIST 0 THRIFT_VERSION_MAJOR)
  list(GET VERSION_LIST 1 THRIFT_VERSION_MINOR)
  list(GET VERSION_LIST 2 THRIFT_VERSION_PATCH)
endif()

# ----------------------------------------------------------------------
# Protocol Buffers (required for ORC and Flight and Gandiva libraries)

macro(build_protobuf)
  message("Building Protocol Buffers from source")
  set(PROTOBUF_VENDORED TRUE)
  set(PROTOBUF_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/protobuf_ep-install")
  set(PROTOBUF_INCLUDE_DIR "${PROTOBUF_PREFIX}/include")
  # Newer protobuf releases always have a lib prefix independent from CMAKE_STATIC_LIBRARY_PREFIX
  set(PROTOBUF_STATIC_LIB
      "${PROTOBUF_PREFIX}/lib/libprotobuf${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(PROTOC_STATIC_LIB "${PROTOBUF_PREFIX}/lib/libprotoc${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(Protobuf_PROTOC_LIBRARY "${PROTOC_STATIC_LIB}")
  set(PROTOBUF_COMPILER "${PROTOBUF_PREFIX}/bin/protoc")

  if(CMAKE_VERSION VERSION_LESS 3.7)
    set(PROTOBUF_CONFIGURE_ARGS
        "AR=${CMAKE_AR}"
        "RANLIB=${CMAKE_RANLIB}"
        "CC=${CMAKE_C_COMPILER}"
        "CXX=${CMAKE_CXX_COMPILER}"
        "--disable-shared"
        "--prefix=${PROTOBUF_PREFIX}"
        "CFLAGS=${EP_C_FLAGS}"
        "CXXFLAGS=${EP_CXX_FLAGS}")
    set(PROTOBUF_BUILD_COMMAND ${MAKE} ${MAKE_BUILD_ARGS})
    if(CMAKE_OSX_SYSROOT)
      list(APPEND PROTOBUF_CONFIGURE_ARGS "SDKROOT=${CMAKE_OSX_SYSROOT}")
      list(APPEND PROTOBUF_BUILD_COMMAND "SDKROOT=${CMAKE_OSX_SYSROOT}")
    endif()
    set(PROTOBUF_EXTERNAL_PROJECT_ADD_ARGS
        CONFIGURE_COMMAND
        "./configure"
        ${PROTOBUF_CONFIGURE_ARGS}
        BUILD_COMMAND
        ${PROTOBUF_BUILD_COMMAND})
  else()
    # Strip lto flags (which may be added by dh_auto_configure)
    # See https://github.com/protocolbuffers/protobuf/issues/7092
    set(PROTOBUF_C_FLAGS ${EP_C_FLAGS})
    set(PROTOBUF_CXX_FLAGS ${EP_CXX_FLAGS})
    string(REPLACE "-flto=auto" "" PROTOBUF_C_FLAGS "${PROTOBUF_C_FLAGS}")
    string(REPLACE "-ffat-lto-objects" "" PROTOBUF_C_FLAGS "${PROTOBUF_C_FLAGS}")
    string(REPLACE "-flto=auto" "" PROTOBUF_CXX_FLAGS "${PROTOBUF_CXX_FLAGS}")
    string(REPLACE "-ffat-lto-objects" "" PROTOBUF_CXX_FLAGS "${PROTOBUF_CXX_FLAGS}")
    set(PROTOBUF_CMAKE_ARGS
        ${EP_COMMON_CMAKE_ARGS}
        -DBUILD_SHARED_LIBS=OFF
        -DCMAKE_INSTALL_LIBDIR=lib
        "-DCMAKE_INSTALL_PREFIX=${PROTOBUF_PREFIX}"
        -Dprotobuf_BUILD_TESTS=OFF
        -Dprotobuf_DEBUG_POSTFIX=
        "-DCMAKE_C_FLAGS=${PROTOBUF_C_FLAGS}"
        "-DCMAKE_CXX_FLAGS=${PROTOBUF_CXX_FLAGS}"
        "-DCMAKE_C_FLAGS_${UPPERCASE_BUILD_TYPE}=${PROTOBUF_C_FLAGS}"
        "-DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${PROTOBUF_CXX_FLAGS}")
    if(MSVC AND NOT ARROW_USE_STATIC_CRT)
      list(APPEND PROTOBUF_CMAKE_ARGS "-Dprotobuf_MSVC_STATIC_RUNTIME=OFF")
    endif()
    if(ZLIB_ROOT)
      list(APPEND PROTOBUF_CMAKE_ARGS "-DZLIB_ROOT=${ZLIB_ROOT}")
    endif()
    set(PROTOBUF_EXTERNAL_PROJECT_ADD_ARGS CMAKE_ARGS ${PROTOBUF_CMAKE_ARGS}
                                           SOURCE_SUBDIR "cmake")
  endif()

  externalproject_add(protobuf_ep
                      ${PROTOBUF_EXTERNAL_PROJECT_ADD_ARGS}
                      BUILD_BYPRODUCTS "${PROTOBUF_STATIC_LIB}" "${PROTOBUF_COMPILER}"
                                       ${EP_LOG_OPTIONS}
                      BUILD_IN_SOURCE 1
                      URL ${PROTOBUF_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_PROTOBUF_BUILD_SHA256_CHECKSUM}")

  file(MAKE_DIRECTORY "${PROTOBUF_INCLUDE_DIR}")

  add_library(arrow::protobuf::libprotobuf STATIC IMPORTED)
  set_target_properties(arrow::protobuf::libprotobuf
                        PROPERTIES IMPORTED_LOCATION "${PROTOBUF_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${PROTOBUF_INCLUDE_DIR}")
  add_library(arrow::protobuf::libprotoc STATIC IMPORTED)
  set_target_properties(arrow::protobuf::libprotoc
                        PROPERTIES IMPORTED_LOCATION "${PROTOC_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${PROTOBUF_INCLUDE_DIR}")
  add_executable(arrow::protobuf::protoc IMPORTED)
  set_target_properties(arrow::protobuf::protoc PROPERTIES IMPORTED_LOCATION
                                                           "${PROTOBUF_COMPILER}")

  add_dependencies(toolchain protobuf_ep)
  add_dependencies(arrow::protobuf::libprotobuf protobuf_ep)
  add_dependencies(arrow::protobuf::protoc protobuf_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS arrow::protobuf::libprotobuf)
endmacro()

if(ARROW_WITH_PROTOBUF)
  if(ARROW_WITH_GRPC)
    # FlightSQL uses proto3 optionals, which require 3.15 or later.
    set(ARROW_PROTOBUF_REQUIRED_VERSION "3.15.0")
  elseif(ARROW_GANDIVA_JAVA)
    # google::protobuf::MessageLite::ByteSize() is deprecated since
    # Protobuf 3.4.0.
    set(ARROW_PROTOBUF_REQUIRED_VERSION "3.4.0")
  else()
    set(ARROW_PROTOBUF_REQUIRED_VERSION "2.6.1")
  endif()
  resolve_dependency(Protobuf
                     REQUIRED_VERSION
                     ${ARROW_PROTOBUF_REQUIRED_VERSION}
                     PC_PACKAGE_NAMES
                     protobuf)

  if(ARROW_PROTOBUF_USE_SHARED AND MSVC_TOOLCHAIN)
    add_definitions(-DPROTOBUF_USE_DLLS)
  endif()

  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${PROTOBUF_INCLUDE_DIR})

  if(TARGET arrow::protobuf::libprotobuf)
    set(ARROW_PROTOBUF_LIBPROTOBUF arrow::protobuf::libprotobuf)
  else()
    # CMake 3.8 or older don't define the targets
    if(NOT TARGET protobuf::libprotobuf)
      add_library(protobuf::libprotobuf UNKNOWN IMPORTED)
      set_target_properties(protobuf::libprotobuf
                            PROPERTIES IMPORTED_LOCATION "${PROTOBUF_LIBRARY}"
                                       INTERFACE_INCLUDE_DIRECTORIES
                                       "${PROTOBUF_INCLUDE_DIR}")
    endif()
    set(ARROW_PROTOBUF_LIBPROTOBUF protobuf::libprotobuf)
  endif()
  if(TARGET arrow::protobuf::libprotoc)
    set(ARROW_PROTOBUF_LIBPROTOC arrow::protobuf::libprotoc)
  else()
    # CMake 3.8 or older don't define the targets
    if(NOT TARGET protobuf::libprotoc)
      if(PROTOBUF_PROTOC_LIBRARY AND NOT Protobuf_PROTOC_LIBRARY)
        # Old CMake versions have a different casing.
        set(Protobuf_PROTOC_LIBRARY ${PROTOBUF_PROTOC_LIBRARY})
      endif()
      if(NOT Protobuf_PROTOC_LIBRARY)
        message(FATAL_ERROR "libprotoc was set to ${Protobuf_PROTOC_LIBRARY}")
      endif()
      add_library(protobuf::libprotoc UNKNOWN IMPORTED)
      set_target_properties(protobuf::libprotoc
                            PROPERTIES IMPORTED_LOCATION "${Protobuf_PROTOC_LIBRARY}"
                                       INTERFACE_INCLUDE_DIRECTORIES
                                       "${PROTOBUF_INCLUDE_DIR}")
    endif()
    set(ARROW_PROTOBUF_LIBPROTOC protobuf::libprotoc)
  endif()
  if(TARGET arrow::protobuf::protoc)
    set(ARROW_PROTOBUF_PROTOC arrow::protobuf::protoc)
  else()
    if(NOT TARGET protobuf::protoc)
      add_executable(protobuf::protoc IMPORTED)
      set_target_properties(protobuf::protoc PROPERTIES IMPORTED_LOCATION
                                                        "${PROTOBUF_PROTOC_EXECUTABLE}")
    endif()
    set(ARROW_PROTOBUF_PROTOC protobuf::protoc)
  endif()

  # Log protobuf paths as we often see issues with mixed sources for
  # the libraries and protoc.
  get_target_property(PROTOBUF_PROTOC_EXECUTABLE ${ARROW_PROTOBUF_PROTOC}
                      IMPORTED_LOCATION)
  message(STATUS "Found protoc: ${PROTOBUF_PROTOC_EXECUTABLE}")
  # Protobuf_PROTOC_LIBRARY is set by all versions of FindProtobuf.cmake
  message(STATUS "Found libprotoc: ${Protobuf_PROTOC_LIBRARY}")
  get_target_property(PROTOBUF_LIBRARY ${ARROW_PROTOBUF_LIBPROTOBUF} IMPORTED_LOCATION)
  message(STATUS "Found libprotobuf: ${PROTOBUF_LIBRARY}")
  message(STATUS "Found protobuf headers: ${PROTOBUF_INCLUDE_DIR}")
endif()

# ----------------------------------------------------------------------
# jemalloc - Unix-only high-performance allocator

if(ARROW_JEMALLOC)
  message(STATUS "Building (vendored) jemalloc from source")
  # We only use a vendored jemalloc as we want to control its version.
  # Also our build of jemalloc is specially prefixed so that it will not
  # conflict with the default allocator as well as other jemalloc
  # installations.
  # find_package(jemalloc)

  set(ARROW_JEMALLOC_USE_SHARED OFF)
  set(JEMALLOC_PREFIX
      "${CMAKE_CURRENT_BINARY_DIR}/jemalloc_ep-prefix/src/jemalloc_ep/dist/")
  set(JEMALLOC_LIB_DIR "${JEMALLOC_PREFIX}/lib")
  set(JEMALLOC_STATIC_LIB
      "${JEMALLOC_LIB_DIR}/libjemalloc_pic${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(JEMALLOC_CONFIGURE_COMMAND ./configure "AR=${CMAKE_AR}" "CC=${CMAKE_C_COMPILER}")
  if(CMAKE_OSX_SYSROOT)
    list(APPEND JEMALLOC_CONFIGURE_COMMAND "SDKROOT=${CMAKE_OSX_SYSROOT}")
  endif()
  if(DEFINED ARROW_JEMALLOC_LG_PAGE)
    # Used for arm64 manylinux wheels in order to make the wheel work on both
    # 4k and 64k page arm64 systems.
    list(APPEND JEMALLOC_CONFIGURE_COMMAND "--with-lg-page=${ARROW_JEMALLOC_LG_PAGE}")
  endif()
  list(APPEND
       JEMALLOC_CONFIGURE_COMMAND
       "--prefix=${JEMALLOC_PREFIX}"
       "--libdir=${JEMALLOC_LIB_DIR}"
       "--with-jemalloc-prefix=je_arrow_"
       "--with-private-namespace=je_arrow_private_"
       "--without-export"
       "--disable-shared"
       # Don't override operator new()
       "--disable-cxx"
       "--disable-libdl"
       # See https://github.com/jemalloc/jemalloc/issues/1237
       "--disable-initial-exec-tls"
       ${EP_LOG_OPTIONS})
  set(JEMALLOC_BUILD_COMMAND ${MAKE} ${MAKE_BUILD_ARGS})
  if(CMAKE_OSX_SYSROOT)
    list(APPEND JEMALLOC_BUILD_COMMAND "SDKROOT=${CMAKE_OSX_SYSROOT}")
  endif()
  externalproject_add(jemalloc_ep
                      URL ${JEMALLOC_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_JEMALLOC_BUILD_SHA256_CHECKSUM}"
                      PATCH_COMMAND touch doc/jemalloc.3 doc/jemalloc.html
                                    # The prefix "je_arrow_" must be kept in sync with the value in memory_pool.cc
                      CONFIGURE_COMMAND ${JEMALLOC_CONFIGURE_COMMAND}
                      BUILD_IN_SOURCE 1
                      BUILD_COMMAND ${JEMALLOC_BUILD_COMMAND}
                      BUILD_BYPRODUCTS "${JEMALLOC_STATIC_LIB}"
                      INSTALL_COMMAND ${MAKE} -j1 install)

  # Don't use the include directory directly so that we can point to a path
  # that is unique to our codebase.
  include_directories(SYSTEM "${CMAKE_CURRENT_BINARY_DIR}/jemalloc_ep-prefix/src/")
  # The include directory must exist before it is referenced by a target.
  file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/jemalloc_ep-prefix/src/")
  add_library(jemalloc::jemalloc STATIC IMPORTED)
  set_target_properties(jemalloc::jemalloc
                        PROPERTIES INTERFACE_LINK_LIBRARIES Threads::Threads
                                   IMPORTED_LOCATION "${JEMALLOC_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${CMAKE_CURRENT_BINARY_DIR}/jemalloc_ep-prefix/src")
  add_dependencies(jemalloc::jemalloc jemalloc_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS jemalloc::jemalloc)
endif()

# ----------------------------------------------------------------------
# mimalloc - Cross-platform high-performance allocator, from Microsoft

if(ARROW_MIMALLOC)
  message(STATUS "Building (vendored) mimalloc from source")
  # We only use a vendored mimalloc as we want to control its build options.

  set(MIMALLOC_LIB_BASE_NAME "mimalloc")
  if(WIN32)
    set(MIMALLOC_LIB_BASE_NAME "${MIMALLOC_LIB_BASE_NAME}-static")
  endif()
  if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
    set(MIMALLOC_LIB_BASE_NAME "${MIMALLOC_LIB_BASE_NAME}-${LOWERCASE_BUILD_TYPE}")
  endif()

  set(MIMALLOC_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/mimalloc_ep/src/mimalloc_ep")
  set(MIMALLOC_INCLUDE_DIR "${MIMALLOC_PREFIX}/include/mimalloc-1.7")
  set(MIMALLOC_STATIC_LIB
      "${MIMALLOC_PREFIX}/lib/mimalloc-1.7/${CMAKE_STATIC_LIBRARY_PREFIX}${MIMALLOC_LIB_BASE_NAME}${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  set(MIMALLOC_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${MIMALLOC_PREFIX}"
      -DMI_OVERRIDE=OFF
      -DMI_LOCAL_DYNAMIC_TLS=ON
      -DMI_BUILD_OBJECT=OFF
      -DMI_BUILD_SHARED=OFF
      -DMI_BUILD_TESTS=OFF)

  externalproject_add(mimalloc_ep
                      URL ${MIMALLOC_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_MIMALLOC_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${MIMALLOC_CMAKE_ARGS}
                      BUILD_BYPRODUCTS "${MIMALLOC_STATIC_LIB}")

  include_directories(SYSTEM ${MIMALLOC_INCLUDE_DIR})
  file(MAKE_DIRECTORY ${MIMALLOC_INCLUDE_DIR})

  add_library(mimalloc::mimalloc STATIC IMPORTED)
  set_target_properties(mimalloc::mimalloc
                        PROPERTIES INTERFACE_LINK_LIBRARIES Threads::Threads
                                   IMPORTED_LOCATION "${MIMALLOC_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${MIMALLOC_INCLUDE_DIR}")
  add_dependencies(mimalloc::mimalloc mimalloc_ep)
  add_dependencies(toolchain mimalloc_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS mimalloc::mimalloc)
endif()

# ----------------------------------------------------------------------
# Google gtest

macro(build_gtest)
  message(STATUS "Building gtest from source")
  set(GTEST_VENDORED TRUE)
  set(GTEST_CMAKE_CXX_FLAGS ${EP_CXX_FLAGS})

  if(CMAKE_BUILD_TYPE MATCHES DEBUG)
    set(CMAKE_GTEST_DEBUG_EXTENSION "d")
  else()
    set(CMAKE_GTEST_DEBUG_EXTENSION "")
  endif()

  if(APPLE)
    set(GTEST_CMAKE_CXX_FLAGS ${GTEST_CMAKE_CXX_FLAGS} -DGTEST_USE_OWN_TR1_TUPLE=1
                              -Wno-unused-value -Wno-ignored-attributes)
  endif()

  if(MSVC)
    set(GTEST_CMAKE_CXX_FLAGS "${GTEST_CMAKE_CXX_FLAGS} -DGTEST_CREATE_SHARED_LIBRARY=1")
  endif()

  set(GTEST_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/googletest_ep-prefix")
  set(GTEST_INCLUDE_DIR "${GTEST_PREFIX}/include")

  set(_GTEST_LIBRARY_DIR "${GTEST_PREFIX}/lib")

  if(MSVC)
    set(_GTEST_IMPORTED_TYPE IMPORTED_IMPLIB)
    set(_GTEST_LIBRARY_SUFFIX
        "${CMAKE_GTEST_DEBUG_EXTENSION}${CMAKE_IMPORT_LIBRARY_SUFFIX}")
  else()
    set(_GTEST_IMPORTED_TYPE IMPORTED_LOCATION)
    set(_GTEST_LIBRARY_SUFFIX
        "${CMAKE_GTEST_DEBUG_EXTENSION}${CMAKE_SHARED_LIBRARY_SUFFIX}")

  endif()

  set(GTEST_SHARED_LIB
      "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest${_GTEST_LIBRARY_SUFFIX}")
  set(GMOCK_SHARED_LIB
      "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gmock${_GTEST_LIBRARY_SUFFIX}")
  set(GTEST_MAIN_SHARED_LIB
      "${_GTEST_LIBRARY_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest_main${_GTEST_LIBRARY_SUFFIX}"
  )
  set(GTEST_INSTALL_NAME_DIR "$<INSTALL_PREFIX$<ANGLE-R>/lib")
  # Fix syntax highlighting mess introduced by unclosed bracket above
  set(dummy ">")

  set(GTEST_CMAKE_ARGS
      ${EP_COMMON_TOOLCHAIN}
      -DBUILD_SHARED_LIBS=ON
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_CXX_FLAGS=${GTEST_CMAKE_CXX_FLAGS}
      -DCMAKE_CXX_FLAGS_${UPPERCASE_BUILD_TYPE}=${GTEST_CMAKE_CXX_FLAGS}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DCMAKE_INSTALL_NAME_DIR=${GTEST_INSTALL_NAME_DIR}
      -DCMAKE_INSTALL_PREFIX=${GTEST_PREFIX}
      -DCMAKE_MACOSX_RPATH=OFF)
  set(GMOCK_INCLUDE_DIR "${GTEST_PREFIX}/include")

  add_definitions(-DGTEST_LINKED_AS_SHARED_LIBRARY=1)

  if(MSVC AND NOT ARROW_USE_STATIC_CRT)
    set(GTEST_CMAKE_ARGS ${GTEST_CMAKE_ARGS} -Dgtest_force_shared_crt=ON)
  endif()

  externalproject_add(googletest_ep
                      URL ${GTEST_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_GTEST_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS ${GTEST_SHARED_LIB} ${GTEST_MAIN_SHARED_LIB}
                                       ${GMOCK_SHARED_LIB}
                      CMAKE_ARGS ${GTEST_CMAKE_ARGS} ${EP_LOG_OPTIONS})
  if(WIN32)
    # Copy the built shared libraries to the same directory as our
    # test programs because Windows doesn't provided rpath (run-time
    # search path) feature. We need to put these shared libraries to
    # the same directory as our test programs or add
    # _GTEST_LIBRARY_DIR to PATH when we run our test programs. We
    # choose the former because the latter may be forgotten.
    set(_GTEST_RUNTIME_DIR "${GTEST_PREFIX}/bin")
    set(_GTEST_RUNTIME_SUFFIX
        "${CMAKE_GTEST_DEBUG_EXTENSION}${CMAKE_SHARED_LIBRARY_SUFFIX}")
    set(_GTEST_RUNTIME_LIB
        "${_GTEST_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest${_GTEST_RUNTIME_SUFFIX}"
    )
    set(_GMOCK_RUNTIME_LIB
        "${_GTEST_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gmock${_GTEST_RUNTIME_SUFFIX}"
    )
    set(_GTEST_MAIN_RUNTIME_LIB
        "${_GTEST_RUNTIME_DIR}/${CMAKE_SHARED_LIBRARY_PREFIX}gtest_main${_GTEST_RUNTIME_SUFFIX}"
    )
    if(CMAKE_VERSION VERSION_LESS 3.9)
      message(FATAL_ERROR "Building GoogleTest from source on Windows requires at least CMake 3.9"
      )
    endif()
    get_property(_GENERATOR_IS_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
    if(_GENERATOR_IS_MULTI_CONFIG)
      set(_GTEST_RUNTIME_OUTPUT_DIR "${BUILD_OUTPUT_ROOT_DIRECTORY}/${CMAKE_BUILD_TYPE}")
    else()
      set(_GTEST_RUNTIME_OUTPUT_DIR ${BUILD_OUTPUT_ROOT_DIRECTORY})
    endif()
    externalproject_add_step(googletest_ep copy
                             COMMAND ${CMAKE_COMMAND} -E make_directory
                                     ${_GTEST_RUNTIME_OUTPUT_DIR}
                             COMMAND ${CMAKE_COMMAND} -E copy ${_GTEST_RUNTIME_LIB}
                                     ${_GTEST_RUNTIME_OUTPUT_DIR}
                             COMMAND ${CMAKE_COMMAND} -E copy ${_GMOCK_RUNTIME_LIB}
                                     ${_GTEST_RUNTIME_OUTPUT_DIR}
                             COMMAND ${CMAKE_COMMAND} -E copy ${_GTEST_MAIN_RUNTIME_LIB}
                                     ${_GTEST_RUNTIME_OUTPUT_DIR}
                             DEPENDEES install)
  endif()

  # The include directory must exist before it is referenced by a target.
  file(MAKE_DIRECTORY "${GTEST_INCLUDE_DIR}")

  add_library(GTest::gtest SHARED IMPORTED)
  set_target_properties(GTest::gtest
                        PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GTEST_SHARED_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")

  add_library(GTest::gtest_main SHARED IMPORTED)
  set_target_properties(GTest::gtest_main
                        PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GTEST_MAIN_SHARED_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")

  add_library(GTest::gmock SHARED IMPORTED)
  set_target_properties(GTest::gmock
                        PROPERTIES ${_GTEST_IMPORTED_TYPE} "${GMOCK_SHARED_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GTEST_INCLUDE_DIR}")
  add_dependencies(toolchain-tests googletest_ep)
  add_dependencies(GTest::gtest googletest_ep)
  add_dependencies(GTest::gtest_main googletest_ep)
  add_dependencies(GTest::gmock googletest_ep)
endmacro()

if(ARROW_TESTING)
  resolve_dependency(GTest
                     REQUIRED_VERSION
                     1.10.0
                     USE_CONFIG
                     TRUE)

  if(NOT GTEST_VENDORED)
    # TODO(wesm): This logic does not work correctly with the MSVC static libraries
    # built for the shared crt

    #     set(CMAKE_REQUIRED_LIBRARIES GTest::GTest GTest::Main GTest::GMock)
    #     CHECK_CXX_SOURCE_COMPILES("
    # #include <gmock/gmock.h>
    # #include <gtest/gtest.h>

    # class A {
    #   public:
    #     int run() const { return 1; }
    # };

    # class B : public A {
    #   public:
    #     MOCK_CONST_METHOD0(run, int());
    # };

    # TEST(Base, Test) {
    #   B b;
    # }" GTEST_COMPILES_WITHOUT_MACRO)
    #     if (NOT GTEST_COMPILES_WITHOUT_MACRO)
    #       message(STATUS "Setting GTEST_LINKED_AS_SHARED_LIBRARY=1 on GTest::GTest")
    #       add_compile_definitions("GTEST_LINKED_AS_SHARED_LIBRARY=1")
    #     endif()
    #     set(CMAKE_REQUIRED_LIBRARIES)
  endif()

  get_target_property(GTEST_INCLUDE_DIR GTest::gtest INTERFACE_INCLUDE_DIRECTORIES)
  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${GTEST_INCLUDE_DIR})
endif()

macro(build_benchmark)
  message(STATUS "Building benchmark from source")
  if(CMAKE_VERSION VERSION_LESS 3.6)
    message(FATAL_ERROR "Building gbenchmark from source requires at least CMake 3.6")
  endif()

  if(NOT MSVC)
    set(GBENCHMARK_CMAKE_CXX_FLAGS "${EP_CXX_FLAGS} -std=c++11")
  endif()

  if(APPLE AND (CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang" OR CMAKE_CXX_COMPILER_ID
                                                               STREQUAL "Clang"))
    set(GBENCHMARK_CMAKE_CXX_FLAGS "${GBENCHMARK_CMAKE_CXX_FLAGS} -stdlib=libc++")
  endif()

  set(GBENCHMARK_PREFIX
      "${CMAKE_CURRENT_BINARY_DIR}/gbenchmark_ep/src/gbenchmark_ep-install")
  set(GBENCHMARK_INCLUDE_DIR "${GBENCHMARK_PREFIX}/include")
  set(GBENCHMARK_STATIC_LIB
      "${GBENCHMARK_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}benchmark${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GBENCHMARK_MAIN_STATIC_LIB
      "${GBENCHMARK_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}benchmark_main${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GBENCHMARK_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${GBENCHMARK_PREFIX}"
      -DCMAKE_INSTALL_LIBDIR=lib
      -DBENCHMARK_ENABLE_TESTING=OFF
      -DCMAKE_CXX_FLAGS=${GBENCHMARK_CMAKE_CXX_FLAGS})
  if(APPLE)
    set(GBENCHMARK_CMAKE_ARGS ${GBENCHMARK_CMAKE_ARGS} "-DBENCHMARK_USE_LIBCXX=ON")
  endif()

  externalproject_add(gbenchmark_ep
                      URL ${GBENCHMARK_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_GBENCHMARK_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${GBENCHMARK_STATIC_LIB}"
                                       "${GBENCHMARK_MAIN_STATIC_LIB}"
                      CMAKE_ARGS ${GBENCHMARK_CMAKE_ARGS} ${EP_LOG_OPTIONS})

  # The include directory must exist before it is referenced by a target.
  file(MAKE_DIRECTORY "${GBENCHMARK_INCLUDE_DIR}")

  add_library(benchmark::benchmark STATIC IMPORTED)
  set_target_properties(benchmark::benchmark
                        PROPERTIES IMPORTED_LOCATION "${GBENCHMARK_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${GBENCHMARK_INCLUDE_DIR}")

  add_library(benchmark::benchmark_main STATIC IMPORTED)
  set_target_properties(benchmark::benchmark_main
                        PROPERTIES IMPORTED_LOCATION "${GBENCHMARK_MAIN_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${GBENCHMARK_INCLUDE_DIR}")

  add_dependencies(toolchain-benchmarks gbenchmark_ep)
  add_dependencies(benchmark::benchmark gbenchmark_ep)
  add_dependencies(benchmark::benchmark_main gbenchmark_ep)
endmacro()

if(ARROW_BUILD_BENCHMARKS)
  set(BENCHMARK_REQUIRED_VERSION 1.6.0)
  resolve_dependency(benchmark
                     REQUIRED_VERSION
                     ${BENCHMARK_REQUIRED_VERSION}
                     IS_RUNTIME_DEPENDENCY
                     FALSE)
  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(BENCHMARK_INCLUDE_DIR benchmark::benchmark
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${BENCHMARK_INCLUDE_DIR})
endif()

macro(build_rapidjson)
  message(STATUS "Building RapidJSON from source")
  set(RAPIDJSON_PREFIX
      "${CMAKE_CURRENT_BINARY_DIR}/rapidjson_ep/src/rapidjson_ep-install")
  set(RAPIDJSON_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      -DRAPIDJSON_BUILD_DOC=OFF
      -DRAPIDJSON_BUILD_EXAMPLES=OFF
      -DRAPIDJSON_BUILD_TESTS=OFF
      "-DCMAKE_INSTALL_PREFIX=${RAPIDJSON_PREFIX}")

  externalproject_add(rapidjson_ep
                      ${EP_LOG_OPTIONS}
                      PREFIX "${CMAKE_BINARY_DIR}"
                      URL ${RAPIDJSON_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_RAPIDJSON_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${RAPIDJSON_CMAKE_ARGS})

  set(RAPIDJSON_INCLUDE_DIR "${RAPIDJSON_PREFIX}/include")

  add_dependencies(toolchain rapidjson_ep)
  add_dependencies(toolchain-tests rapidjson_ep)
  add_dependencies(rapidjson rapidjson_ep)

  set(RAPIDJSON_VENDORED TRUE)
endmacro()

if(ARROW_WITH_RAPIDJSON)
  set(ARROW_RAPIDJSON_REQUIRED_VERSION "1.1.0")
  resolve_dependency(RapidJSON
                     HAVE_ALT
                     TRUE
                     REQUIRED_VERSION
                     ${ARROW_RAPIDJSON_REQUIRED_VERSION}
                     IS_RUNTIME_DEPENDENCY
                     FALSE)

  if(RapidJSON_INCLUDE_DIR)
    set(RAPIDJSON_INCLUDE_DIR "${RapidJSON_INCLUDE_DIR}")
  endif()

  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${RAPIDJSON_INCLUDE_DIR})
endif()

macro(build_xsimd)
  message(STATUS "Building xsimd from source")
  set(XSIMD_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/xsimd_ep/src/xsimd_ep-install")
  set(XSIMD_CMAKE_ARGS ${EP_COMMON_CMAKE_ARGS} "-DCMAKE_INSTALL_PREFIX=${XSIMD_PREFIX}")

  externalproject_add(xsimd_ep
                      ${EP_LOG_OPTIONS}
                      PREFIX "${CMAKE_BINARY_DIR}"
                      URL ${XSIMD_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_XSIMD_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${XSIMD_CMAKE_ARGS})

  set(XSIMD_INCLUDE_DIR "${XSIMD_PREFIX}/include")

  add_dependencies(toolchain xsimd_ep)
  add_dependencies(toolchain-tests xsimd_ep)

  set(XSIMD_VENDORED TRUE)
endmacro()

if((NOT ARROW_SIMD_LEVEL STREQUAL "NONE") OR (NOT ARROW_RUNTIME_SIMD_LEVEL STREQUAL "NONE"
                                             ))
  set(xsimd_SOURCE "BUNDLED")
  resolve_dependency(xsimd)
  # TODO: Don't use global includes but rather target_include_directories
  include_directories(SYSTEM ${XSIMD_INCLUDE_DIR})
endif()

macro(build_zlib)
  message(STATUS "Building ZLIB from source")
  set(ZLIB_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/zlib_ep/src/zlib_ep-install")
  if(MSVC)
    if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
      set(ZLIB_STATIC_LIB_NAME zlibstaticd.lib)
    else()
      set(ZLIB_STATIC_LIB_NAME zlibstatic.lib)
    endif()
  else()
    set(ZLIB_STATIC_LIB_NAME libz.a)
  endif()
  set(ZLIB_STATIC_LIB "${ZLIB_PREFIX}/lib/${ZLIB_STATIC_LIB_NAME}")
  set(ZLIB_CMAKE_ARGS ${EP_COMMON_CMAKE_ARGS} "-DCMAKE_INSTALL_PREFIX=${ZLIB_PREFIX}"
                      -DBUILD_SHARED_LIBS=OFF)

  externalproject_add(zlib_ep
                      URL ${ZLIB_SOURCE_URL} ${EP_LOG_OPTIONS}
                      URL_HASH "SHA256=${ARROW_ZLIB_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${ZLIB_STATIC_LIB}"
                      CMAKE_ARGS ${ZLIB_CMAKE_ARGS})

  file(MAKE_DIRECTORY "${ZLIB_PREFIX}/include")

  add_library(ZLIB::ZLIB STATIC IMPORTED)
  set(ZLIB_LIBRARIES ${ZLIB_STATIC_LIB})
  set(ZLIB_INCLUDE_DIRS "${ZLIB_PREFIX}/include")
  set_target_properties(ZLIB::ZLIB
                        PROPERTIES IMPORTED_LOCATION ${ZLIB_LIBRARIES}
                                   INTERFACE_INCLUDE_DIRECTORIES ${ZLIB_INCLUDE_DIRS})

  add_dependencies(toolchain zlib_ep)
  add_dependencies(ZLIB::ZLIB zlib_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS ZLIB::ZLIB)
endmacro()

if(ARROW_WITH_ZLIB)
  resolve_dependency(ZLIB PC_PACKAGE_NAMES zlib)

  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(ZLIB_INCLUDE_DIR ZLIB::ZLIB INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${ZLIB_INCLUDE_DIR})
endif()

macro(build_lz4)
  message(STATUS "Building lz4 from source")
  set(LZ4_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/lz4_ep-prefix/src/lz4_ep")
  set(LZ4_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/lz4_ep-prefix")

  if(MSVC)
    if(ARROW_USE_STATIC_CRT)
      if(${UPPERCASE_BUILD_TYPE} STREQUAL "DEBUG")
        set(LZ4_RUNTIME_LIBRARY_LINKAGE "/p:RuntimeLibrary=MultiThreadedDebug")
      else()
        set(LZ4_RUNTIME_LIBRARY_LINKAGE "/p:RuntimeLibrary=MultiThreaded")
      endif()
    endif()
    set(LZ4_STATIC_LIB
        "${LZ4_BUILD_DIR}/build/VS2010/bin/x64_${CMAKE_BUILD_TYPE}/liblz4_static.lib")
    set(LZ4_BUILD_COMMAND
        BUILD_COMMAND msbuild.exe /m /p:Configuration=${CMAKE_BUILD_TYPE} /p:Platform=x64
        /p:PlatformToolset=v140 ${LZ4_RUNTIME_LIBRARY_LINKAGE} /t:Build
        ${LZ4_BUILD_DIR}/build/VS2010/lz4.sln)
  else()
    set(LZ4_STATIC_LIB "${LZ4_BUILD_DIR}/lib/liblz4.a")
    # Must explicitly invoke sh on MinGW
    set(LZ4_BUILD_COMMAND
        BUILD_COMMAND sh "${CMAKE_SOURCE_DIR}/build-support/build-lz4-lib.sh"
        "AR=${CMAKE_AR}" "OS=${CMAKE_SYSTEM_NAME}")
  endif()

  # We need to copy the header in lib to directory outside of the build
  externalproject_add(lz4_ep
                      URL ${LZ4_SOURCE_URL} ${EP_LOG_OPTIONS}
                      URL_HASH "SHA256=${ARROW_LZ4_BUILD_SHA256_CHECKSUM}"
                      UPDATE_COMMAND ${CMAKE_COMMAND} -E copy_directory
                                     "${LZ4_BUILD_DIR}/lib" "${LZ4_PREFIX}/include"
                                     ${LZ4_PATCH_COMMAND}
                      CONFIGURE_COMMAND ""
                      INSTALL_COMMAND ""
                      BINARY_DIR ${LZ4_BUILD_DIR}
                      BUILD_BYPRODUCTS ${LZ4_STATIC_LIB} ${LZ4_BUILD_COMMAND})

  file(MAKE_DIRECTORY "${LZ4_PREFIX}/include")
  add_library(LZ4::lz4 STATIC IMPORTED)
  set_target_properties(LZ4::lz4
                        PROPERTIES IMPORTED_LOCATION "${LZ4_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${LZ4_PREFIX}/include")
  add_dependencies(toolchain lz4_ep)
  add_dependencies(LZ4::lz4 lz4_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS LZ4::lz4)
endmacro()

if(ARROW_WITH_LZ4)
  resolve_dependency(Lz4 PC_PACKAGE_NAMES liblz4)

  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(LZ4_INCLUDE_DIR LZ4::lz4 INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${LZ4_INCLUDE_DIR})
endif()

macro(build_zstd)
  message(STATUS "Building zstd from source")
  set(ZSTD_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/zstd_ep-install")

  set(ZSTD_CMAKE_ARGS
      ${EP_COMMON_TOOLCHAIN}
      "-DCMAKE_INSTALL_PREFIX=${ZSTD_PREFIX}"
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_LIBDIR=${CMAKE_INSTALL_LIBDIR}
      -DZSTD_BUILD_PROGRAMS=off
      -DZSTD_BUILD_SHARED=off
      -DZSTD_BUILD_STATIC=on
      -DZSTD_MULTITHREAD_SUPPORT=off)

  if(MSVC)
    set(ZSTD_STATIC_LIB "${ZSTD_PREFIX}/${CMAKE_INSTALL_LIBDIR}/zstd_static.lib")
    if(ARROW_USE_STATIC_CRT)
      set(ZSTD_CMAKE_ARGS ${ZSTD_CMAKE_ARGS} "-DZSTD_USE_STATIC_RUNTIME=on")
    endif()
  else()
    set(ZSTD_STATIC_LIB "${ZSTD_PREFIX}/${CMAKE_INSTALL_LIBDIR}/libzstd.a")
    # Only pass our C flags on Unix as on MSVC it leads to a
    # "incompatible command-line options" error
    set(ZSTD_CMAKE_ARGS
        ${ZSTD_CMAKE_ARGS}
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
        -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
        -DCMAKE_C_FLAGS=${EP_C_FLAGS}
        -DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS})
  endif()

  if(CMAKE_VERSION VERSION_LESS 3.7)
    message(FATAL_ERROR "Building zstd using ExternalProject requires at least CMake 3.7")
  endif()

  externalproject_add(zstd_ep
                      ${EP_LOG_OPTIONS}
                      CMAKE_ARGS ${ZSTD_CMAKE_ARGS}
                      SOURCE_SUBDIR "build/cmake"
                      INSTALL_DIR ${ZSTD_PREFIX}
                      URL ${ZSTD_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_ZSTD_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${ZSTD_STATIC_LIB}")

  file(MAKE_DIRECTORY "${ZSTD_PREFIX}/include")

  add_library(zstd::libzstd STATIC IMPORTED)
  set_target_properties(zstd::libzstd
                        PROPERTIES IMPORTED_LOCATION "${ZSTD_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${ZSTD_PREFIX}/include")

  add_dependencies(toolchain zstd_ep)
  add_dependencies(zstd::libzstd zstd_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS zstd::libzstd)
endmacro()

if(ARROW_WITH_ZSTD)
  # ARROW-13384: ZSTD_minCLevel was added in v1.4.0, required by ARROW-13091
  resolve_dependency(zstd
                     PC_PACKAGE_NAMES
                     libzstd
                     REQUIRED_VERSION
                     1.4.0)

  if(TARGET zstd::libzstd)
    set(ARROW_ZSTD_LIBZSTD zstd::libzstd)
  else()
    # "SYSTEM" source will prioritize cmake config, which exports
    # zstd::libzstd_{static,shared}
    if(ARROW_ZSTD_USE_SHARED)
      if(TARGET zstd::libzstd_shared)
        set(ARROW_ZSTD_LIBZSTD zstd::libzstd_shared)
      endif()
    else()
      if(TARGET zstd::libzstd_static)
        set(ARROW_ZSTD_LIBZSTD zstd::libzstd_static)
      endif()
    endif()
  endif()

  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(ZSTD_INCLUDE_DIR ${ARROW_ZSTD_LIBZSTD}
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${ZSTD_INCLUDE_DIR})
endif()

# ----------------------------------------------------------------------
# RE2 (required for Gandiva)

macro(build_re2)
  message(STATUS "Building RE2 from source")
  set(RE2_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/re2_ep-install")
  set(RE2_STATIC_LIB
      "${RE2_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}re2${CMAKE_STATIC_LIBRARY_SUFFIX}")

  set(RE2_CMAKE_ARGS ${EP_COMMON_CMAKE_ARGS} "-DCMAKE_INSTALL_PREFIX=${RE2_PREFIX}"
                     -DCMAKE_INSTALL_LIBDIR=lib)

  externalproject_add(re2_ep
                      ${EP_LOG_OPTIONS}
                      INSTALL_DIR ${RE2_PREFIX}
                      URL ${RE2_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_RE2_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${RE2_CMAKE_ARGS}
                      BUILD_BYPRODUCTS "${RE2_STATIC_LIB}")

  file(MAKE_DIRECTORY "${RE2_PREFIX}/include")
  add_library(re2::re2 STATIC IMPORTED)
  set_target_properties(re2::re2
                        PROPERTIES IMPORTED_LOCATION "${RE2_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${RE2_PREFIX}/include")

  add_dependencies(toolchain re2_ep)
  add_dependencies(re2::re2 re2_ep)
  set(RE2_VENDORED TRUE)
  # Set values so that FindRE2 finds this too
  set(RE2_LIB ${RE2_STATIC_LIB})
  set(RE2_INCLUDE_DIR "${RE2_PREFIX}/include")

  list(APPEND ARROW_BUNDLED_STATIC_LIBS re2::re2)
endmacro()

if(ARROW_WITH_RE2)
  # Don't specify "PC_PACKAGE_NAMES re2" here because re2.pc may
  # include -std=c++11. It's not compatible with C source and C++
  # source not uses C++ 11.
  resolve_dependency(re2 HAVE_ALT TRUE)
  if(${re2_SOURCE} STREQUAL "SYSTEM")
    get_target_property(RE2_LIB re2::re2 IMPORTED_LOCATION)
    string(APPEND ARROW_PC_LIBS_PRIVATE " ${RE2_LIB}")
  endif()
  add_definitions(-DARROW_WITH_RE2)

  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(RE2_INCLUDE_DIR re2::re2 INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${RE2_INCLUDE_DIR})
endif()

macro(build_bzip2)
  message(STATUS "Building BZip2 from source")
  set(BZIP2_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/bzip2_ep-install")
  set(BZIP2_STATIC_LIB
      "${BZIP2_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}bz2${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  set(BZIP2_EXTRA_ARGS "CC=${CMAKE_C_COMPILER}" "CFLAGS=${EP_C_FLAGS}")

  if(CMAKE_OSX_SYSROOT)
    list(APPEND BZIP2_EXTRA_ARGS "SDKROOT=${CMAKE_OSX_SYSROOT}")
  endif()

  if(CMAKE_AR)
    list(APPEND BZIP2_EXTRA_ARGS AR=${CMAKE_AR})
  endif()

  if(CMAKE_RANLIB)
    list(APPEND BZIP2_EXTRA_ARGS RANLIB=${CMAKE_RANLIB})
  endif()

  externalproject_add(bzip2_ep
                      ${EP_LOG_OPTIONS}
                      CONFIGURE_COMMAND ""
                      BUILD_IN_SOURCE 1
                      BUILD_COMMAND ${MAKE} libbz2.a ${MAKE_BUILD_ARGS}
                                    ${BZIP2_EXTRA_ARGS}
                      INSTALL_COMMAND ${MAKE} install PREFIX=${BZIP2_PREFIX}
                                      ${BZIP2_EXTRA_ARGS}
                      INSTALL_DIR ${BZIP2_PREFIX}
                      URL ${ARROW_BZIP2_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_BZIP2_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${BZIP2_STATIC_LIB}")

  file(MAKE_DIRECTORY "${BZIP2_PREFIX}/include")
  add_library(BZip2::BZip2 STATIC IMPORTED)
  set_target_properties(BZip2::BZip2
                        PROPERTIES IMPORTED_LOCATION "${BZIP2_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${BZIP2_PREFIX}/include")
  set(BZIP2_INCLUDE_DIR "${BZIP2_PREFIX}/include")

  add_dependencies(toolchain bzip2_ep)
  add_dependencies(BZip2::BZip2 bzip2_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS BZip2::BZip2)
endmacro()

if(ARROW_WITH_BZ2)
  resolve_dependency(BZip2)
  if(${BZip2_SOURCE} STREQUAL "SYSTEM")
    string(APPEND ARROW_PC_LIBS_PRIVATE " ${BZIP2_LIBRARIES}")
  endif()

  if(NOT TARGET BZip2::BZip2)
    add_library(BZip2::BZip2 UNKNOWN IMPORTED)
    set_target_properties(BZip2::BZip2
                          PROPERTIES IMPORTED_LOCATION "${BZIP2_LIBRARIES}"
                                     INTERFACE_INCLUDE_DIRECTORIES "${BZIP2_INCLUDE_DIR}")
  endif()
  include_directories(SYSTEM "${BZIP2_INCLUDE_DIR}")
endif()

macro(build_utf8proc)
  message(STATUS "Building utf8proc from source")
  set(UTF8PROC_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/utf8proc_ep-install")
  if(MSVC)
    set(UTF8PROC_STATIC_LIB "${UTF8PROC_PREFIX}/lib/utf8proc_static.lib")
  else()
    set(UTF8PROC_STATIC_LIB
        "${UTF8PROC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}utf8proc${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
  endif()

  set(UTF8PROC_CMAKE_ARGS
      ${EP_COMMON_TOOLCHAIN}
      "-DCMAKE_INSTALL_PREFIX=${UTF8PROC_PREFIX}"
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DBUILD_SHARED_LIBS=OFF)

  externalproject_add(utf8proc_ep
                      ${EP_LOG_OPTIONS}
                      CMAKE_ARGS ${UTF8PROC_CMAKE_ARGS}
                      INSTALL_DIR ${UTF8PROC_PREFIX}
                      URL ${ARROW_UTF8PROC_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_UTF8PROC_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS "${UTF8PROC_STATIC_LIB}")

  file(MAKE_DIRECTORY "${UTF8PROC_PREFIX}/include")
  add_library(utf8proc::utf8proc STATIC IMPORTED)
  set_target_properties(utf8proc::utf8proc
                        PROPERTIES IMPORTED_LOCATION "${UTF8PROC_STATIC_LIB}"
                                   INTERFACE_COMPILER_DEFINITIONS "UTF8PROC_STATIC"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${UTF8PROC_PREFIX}/include")

  add_dependencies(toolchain utf8proc_ep)
  add_dependencies(utf8proc::utf8proc utf8proc_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS utf8proc::utf8proc)
endmacro()

if(ARROW_WITH_UTF8PROC)
  resolve_dependency(utf8proc
                     REQUIRED_VERSION
                     "2.2.0"
                     PC_PACKAGE_NAMES
                     libutf8proc)

  add_definitions(-DARROW_WITH_UTF8PROC)

  # TODO: Don't use global definitions but rather
  # target_compile_definitions or target_link_libraries
  get_target_property(UTF8PROC_COMPILER_DEFINITIONS utf8proc::utf8proc
                      INTERFACE_COMPILER_DEFINITIONS)
  if(UTF8PROC_COMPILER_DEFINITIONS)
    add_definitions(-D${UTF8PROC_COMPILER_DEFINITIONS})
  endif()

  # TODO: Don't use global includes but rather
  # target_include_directories or target_link_libraries
  get_target_property(UTF8PROC_INCLUDE_DIR utf8proc::utf8proc
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${UTF8PROC_INCLUDE_DIR})
endif()

macro(build_cares)
  message(STATUS "Building c-ares from source")
  set(CARES_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/cares_ep-install")
  set(CARES_INCLUDE_DIR "${CARES_PREFIX}/include")

  # If you set -DCARES_SHARED=ON then the build system names the library
  # libcares_static.a
  set(CARES_STATIC_LIB
      "${CARES_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}cares${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  set(CARES_CMAKE_ARGS
      "${EP_COMMON_CMAKE_ARGS}"
      -DCARES_STATIC=ON
      -DCARES_SHARED=OFF
      -DCMAKE_INSTALL_LIBDIR=lib
      "-DCMAKE_INSTALL_PREFIX=${CARES_PREFIX}")

  externalproject_add(cares_ep
                      ${EP_LOG_OPTIONS}
                      URL ${CARES_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_CARES_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${CARES_CMAKE_ARGS}
                      BUILD_BYPRODUCTS "${CARES_STATIC_LIB}")

  file(MAKE_DIRECTORY ${CARES_INCLUDE_DIR})

  add_dependencies(toolchain cares_ep)
  add_library(c-ares::cares STATIC IMPORTED)
  set_target_properties(c-ares::cares
                        PROPERTIES IMPORTED_LOCATION "${CARES_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${CARES_INCLUDE_DIR}")
  add_dependencies(c-ares::cares cares_ep)

  if(APPLE)
    # libresolv must be linked from c-ares version 1.16.1
    find_library(LIBRESOLV_LIBRARY NAMES resolv libresolv REQUIRED)
    set_target_properties(c-ares::cares PROPERTIES INTERFACE_LINK_LIBRARIES
                                                   "${LIBRESOLV_LIBRARY}")
  endif()

  set(CARES_VENDORED TRUE)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS c-ares::cares)
endmacro()

# ----------------------------------------------------------------------
# Dependencies for Arrow Flight RPC

macro(build_absl_once)
  if(NOT TARGET absl_ep)
    message(STATUS "Building Abseil-cpp from source")
    set(ABSL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/absl_ep-install")
    set(ABSL_INCLUDE_DIR "${ABSL_PREFIX}/include")
    set(ABSL_CMAKE_ARGS
        "${EP_COMMON_CMAKE_ARGS}" -DABSL_RUN_TESTS=OFF -DCMAKE_INSTALL_LIBDIR=lib
        "-DCMAKE_INSTALL_PREFIX=${ABSL_PREFIX}")
    set(ABSL_BUILD_BYPRODUCTS)
    set(ABSL_LIBRARIES)

    # Abseil produces the following libraries, each is fairly small, but there
    # are (as you can see), many of them. We need to add the libraries first,
    # and then describe how they depend on each other. The list can be
    # refreshed using:
    #   ls -1 $PREFIX/lib/libabsl_*.a | sed -e 's/.*libabsl_//' -e 's/.a$//'
    set(_ABSL_LIBS
        bad_any_cast_impl
        bad_optional_access
        bad_variant_access
        base
        city
        civil_time
        cord
        debugging_internal
        demangle_internal
        examine_stack
        exponential_biased
        failure_signal_handler
        flags
        flags_commandlineflag
        flags_commandlineflag_internal
        flags_config
        flags_internal
        flags_marshalling
        flags_parse
        flags_private_handle_accessor
        flags_program_name
        flags_reflection
        flags_usage
        flags_usage_internal
        graphcycles_internal
        hash
        hashtablez_sampler
        int128
        leak_check
        leak_check_disable
        log_severity
        malloc_internal
        periodic_sampler
        random_distributions
        random_internal_distribution_test_util
        random_internal_platform
        random_internal_pool_urbg
        random_internal_randen
        random_internal_randen_hwaes
        random_internal_randen_hwaes_impl
        random_internal_randen_slow
        random_internal_seed_material
        random_seed_gen_exception
        random_seed_sequences
        raw_hash_set
        raw_logging_internal
        scoped_set_env
        spinlock_wait
        stacktrace
        status
        statusor
        strerror
        str_format_internal
        strings
        strings_internal
        symbolize
        synchronization
        throw_delegate
        time
        time_zone
        wyhash)
    # Abseil creates a number of header-only targets, which are needed to resolve dependencies.
    # The list can be refreshed using:
    #   comm -13 <(ls -l $PREFIX/lib/libabsl_*.a | sed -e 's/.*libabsl_//' -e 's/.a$//' | sort -u) \
    #            <(ls -1 $PREFIX/lib/pkgconfig/absl_*.pc | sed -e 's/.*absl_//' -e 's/.pc$//' | sort -u)
    set(_ABSL_INTERFACE_LIBS
        algorithm
        algorithm_container
        any
        atomic_hook
        bad_any_cast
        base_internal
        bind_front
        bits
        btree
        cleanup
        cleanup_internal
        compare
        compressed_tuple
        config
        container_common
        container_memory
        core_headers
        counting_allocator
        debugging
        dynamic_annotations
        endian
        errno_saver
        fast_type_id
        fixed_array
        flags_path_util
        flat_hash_map
        flat_hash_set
        function_ref
        hash_function_defaults
        hash_policy_traits
        hashtable_debug
        hashtable_debug_hooks
        have_sse
        inlined_vector
        inlined_vector_internal
        kernel_timeout_internal
        layout
        memory
        meta
        node_hash_map
        node_hash_policy
        node_hash_set
        numeric
        numeric_representation
        optional
        pretty_function
        random_bit_gen_ref
        random_internal_distribution_caller
        random_internal_fastmath
        random_internal_fast_uniform_bits
        random_internal_generate_real
        random_internal_iostream_state_saver
        random_internal_mock_helpers
        random_internal_nonsecure_base
        random_internal_pcg_engine
        random_internal_randen_engine
        random_internal_salted_seed_seq
        random_internal_traits
        random_internal_uniform_helper
        random_internal_wide_multiply
        random_random
        raw_hash_map
        span
        str_format
        type_traits
        utility
        variant)

    foreach(_ABSL_LIB ${_ABSL_LIBS})
      set(_ABSL_STATIC_LIBRARY
          "${ABSL_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}absl_${_ABSL_LIB}${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
      add_library(absl::${_ABSL_LIB} STATIC IMPORTED)
      set_target_properties(absl::${_ABSL_LIB}
                            PROPERTIES IMPORTED_LOCATION ${_ABSL_STATIC_LIBRARY}
                                       INTERFACE_INCLUDE_DIRECTORIES
                                       "${ABSL_INCLUDE_DIR}")
      list(APPEND ABSL_BUILD_BYPRODUCTS ${_ABSL_STATIC_LIBRARY})
    endforeach()
    foreach(_ABSL_LIB ${_ABSL_INTERFACE_LIBS})
      add_library(absl::${_ABSL_LIB} INTERFACE IMPORTED)
      set_target_properties(absl::${_ABSL_LIB} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES
                                                          "${ABSL_INCLUDE_DIR}")
    endforeach()

    # Extracted the dependency information using the Abseil pkg-config files:
    #   grep Requires $PREFIX/pkgconfig/absl_*.pc | \
    #   sed -e 's;.*/absl_;set_property(TARGET absl::;' \
    #       -e 's/.pc:Requires:/ PROPERTY INTERFACE_LINK_LIBRARIES /' \
    #       -e 's/ = 20210324,//g' \
    #       -e 's/ = 20210324//g' \
    #       -e 's/absl_/absl::/g' \
    #       -e 's/$/)/'  | \
    #   grep -v 'INTERFACE_LINK_LIBRARIES[ ]*)'
    set_property(TARGET absl::algorithm_container
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::algorithm absl::core_headers
                          absl::meta)
    set_property(TARGET absl::algorithm PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::any
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bad_any_cast
                          absl::config
                          absl::core_headers
                          absl::fast_type_id
                          absl::type_traits
                          absl::utility)
    set_property(TARGET absl::atomic_hook PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                                   absl::core_headers)
    set_property(TARGET absl::bad_any_cast_impl
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::raw_logging_internal)
    set_property(TARGET absl::bad_any_cast PROPERTY INTERFACE_LINK_LIBRARIES
                                                    absl::bad_any_cast_impl absl::config)
    set_property(TARGET absl::bad_optional_access
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::raw_logging_internal)
    set_property(TARGET absl::bad_variant_access
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::raw_logging_internal)
    set_property(TARGET absl::base_internal PROPERTY INTERFACE_LINK_LIBRARIES
                                                     absl::config absl::type_traits)
    set_property(TARGET absl::base
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::atomic_hook
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::dynamic_annotations
                          absl::log_severity
                          absl::raw_logging_internal
                          absl::spinlock_wait
                          absl::type_traits)
    set_property(TARGET absl::bind_front
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::base_internal
                          absl::compressed_tuple)
    set_property(TARGET absl::bits PROPERTY INTERFACE_LINK_LIBRARIES absl::core_headers)
    set_property(TARGET absl::btree
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::container_common
                          absl::compare
                          absl::compressed_tuple
                          absl::container_memory
                          absl::cord
                          absl::core_headers
                          absl::layout
                          absl::memory
                          absl::strings
                          absl::throw_delegate
                          absl::type_traits
                          absl::utility)
    set_property(TARGET absl::city PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                            absl::core_headers absl::endian)
    set_property(TARGET absl::cleanup_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::base_internal absl::core_headers
                          absl::utility)
    set_property(TARGET absl::cleanup
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::cleanup_internal absl::config
                          absl::core_headers)
    set_property(TARGET absl::compare PROPERTY INTERFACE_LINK_LIBRARIES
                                               absl::core_headers absl::type_traits)
    set_property(TARGET absl::compressed_tuple PROPERTY INTERFACE_LINK_LIBRARIES
                                                        absl::utility)
    set_property(TARGET absl::container_common PROPERTY INTERFACE_LINK_LIBRARIES
                                                        absl::type_traits)
    set_property(TARGET absl::container_memory
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::memory
                          absl::type_traits
                          absl::utility)
    set_property(TARGET absl::cord
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::base_internal
                          absl::compressed_tuple
                          absl::config
                          absl::core_headers
                          absl::endian
                          absl::fixed_array
                          absl::function_ref
                          absl::inlined_vector
                          absl::optional
                          absl::raw_logging_internal
                          absl::strings
                          absl::strings_internal
                          absl::throw_delegate
                          absl::type_traits)
    set_property(TARGET absl::core_headers PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::counting_allocator PROPERTY INTERFACE_LINK_LIBRARIES
                                                          absl::config)
    set_property(TARGET absl::debugging_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::core_headers
                          absl::config
                          absl::dynamic_annotations
                          absl::errno_saver
                          absl::raw_logging_internal)
    set_property(TARGET absl::debugging PROPERTY INTERFACE_LINK_LIBRARIES
                                                 absl::stacktrace absl::leak_check)
    set_property(TARGET absl::demangle_internal PROPERTY INTERFACE_LINK_LIBRARIES
                                                         absl::base absl::core_headers)
    set_property(TARGET absl::dynamic_annotations PROPERTY INTERFACE_LINK_LIBRARIES
                                                           absl::config)
    set_property(TARGET absl::endian PROPERTY INTERFACE_LINK_LIBRARIES absl::base
                                              absl::config absl::core_headers)
    set_property(TARGET absl::errno_saver PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::examine_stack
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::stacktrace
                          absl::symbolize
                          absl::config
                          absl::core_headers
                          absl::raw_logging_internal)
    set_property(TARGET absl::exponential_biased PROPERTY INTERFACE_LINK_LIBRARIES
                                                          absl::config absl::core_headers)
    set_property(TARGET absl::failure_signal_handler
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::examine_stack
                          absl::stacktrace
                          absl::base
                          absl::config
                          absl::core_headers
                          absl::errno_saver
                          absl::raw_logging_internal)
    set_property(TARGET absl::fast_type_id PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::fixed_array
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::compressed_tuple
                          absl::algorithm
                          absl::config
                          absl::core_headers
                          absl::dynamic_annotations
                          absl::throw_delegate
                          absl::memory)
    set_property(TARGET absl::flags_commandlineflag_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config absl::fast_type_id)
    set_property(TARGET absl::flags_commandlineflag
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::fast_type_id
                          absl::flags_commandlineflag_internal
                          absl::optional
                          absl::strings)
    set_property(TARGET absl::flags_config
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::flags_path_util
                          absl::flags_program_name
                          absl::core_headers
                          absl::strings
                          absl::synchronization)
    set_property(TARGET absl::flags_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::config
                          absl::flags_commandlineflag
                          absl::flags_commandlineflag_internal
                          absl::flags_config
                          absl::flags_marshalling
                          absl::synchronization
                          absl::meta
                          absl::utility)
    set_property(TARGET absl::flags_marshalling
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::log_severity
                          absl::strings
                          absl::str_format)
    set_property(TARGET absl::flags_parse
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::flags_config
                          absl::flags
                          absl::flags_commandlineflag
                          absl::flags_commandlineflag_internal
                          absl::flags_internal
                          absl::flags_private_handle_accessor
                          absl::flags_program_name
                          absl::flags_reflection
                          absl::flags_usage
                          absl::strings
                          absl::synchronization)
    set_property(TARGET absl::flags_path_util PROPERTY INTERFACE_LINK_LIBRARIES
                                                       absl::config absl::strings)
    set_property(TARGET absl::flags
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::flags_commandlineflag
                          absl::flags_config
                          absl::flags_internal
                          absl::flags_reflection
                          absl::base
                          absl::core_headers
                          absl::strings)
    set_property(TARGET absl::flags_private_handle_accessor
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::flags_commandlineflag
                          absl::flags_commandlineflag_internal
                          absl::strings)
    set_property(TARGET absl::flags_program_name
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::flags_path_util
                          absl::strings
                          absl::synchronization)
    set_property(TARGET absl::flags_reflection
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::flags_commandlineflag
                          absl::flags_private_handle_accessor
                          absl::flags_config
                          absl::strings
                          absl::synchronization
                          absl::flat_hash_map)
    set_property(TARGET absl::flags_usage_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::flags_config
                          absl::flags
                          absl::flags_commandlineflag
                          absl::flags_internal
                          absl::flags_path_util
                          absl::flags_private_handle_accessor
                          absl::flags_program_name
                          absl::flags_reflection
                          absl::strings
                          absl::synchronization)
    set_property(TARGET absl::flags_usage
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::flags_usage_internal
                          absl::strings
                          absl::synchronization)
    set_property(TARGET absl::flat_hash_map
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::container_memory
                          absl::hash_function_defaults
                          absl::raw_hash_map
                          absl::algorithm_container
                          absl::memory)
    set_property(TARGET absl::flat_hash_set
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::container_memory
                          absl::hash_function_defaults
                          absl::raw_hash_set
                          absl::algorithm_container
                          absl::core_headers
                          absl::memory)
    set_property(TARGET absl::function_ref PROPERTY INTERFACE_LINK_LIBRARIES
                                                    absl::base_internal absl::meta)
    set_property(TARGET absl::graphcycles_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::malloc_internal
                          absl::raw_logging_internal)
    set_property(TARGET absl::hash_function_defaults
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::cord
                          absl::hash
                          absl::strings)
    set_property(TARGET absl::hash
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::city
                          absl::config
                          absl::core_headers
                          absl::endian
                          absl::fixed_array
                          absl::meta
                          absl::int128
                          absl::strings
                          absl::optional
                          absl::variant
                          absl::utility
                          absl::wyhash)
    set_property(TARGET absl::hash_policy_traits PROPERTY INTERFACE_LINK_LIBRARIES
                                                          absl::meta)
    set_property(TARGET absl::hashtable_debug_hooks PROPERTY INTERFACE_LINK_LIBRARIES
                                                             absl::config)
    set_property(TARGET absl::hashtable_debug PROPERTY INTERFACE_LINK_LIBRARIES
                                                       absl::hashtable_debug_hooks)
    set_property(TARGET absl::hashtablez_sampler
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::exponential_biased
                          absl::have_sse
                          absl::synchronization)
    set_property(TARGET absl::inlined_vector_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::compressed_tuple
                          absl::core_headers
                          absl::memory
                          absl::span
                          absl::type_traits)
    set_property(TARGET absl::inlined_vector
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::algorithm
                          absl::core_headers
                          absl::inlined_vector_internal
                          absl::throw_delegate
                          absl::memory)
    set_property(TARGET absl::int128 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                              absl::core_headers absl::bits)
    set_property(TARGET absl::kernel_timeout_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::core_headers
                          absl::raw_logging_internal absl::time)
    set_property(TARGET absl::layout
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::meta
                          absl::strings
                          absl::span
                          absl::utility)
    set_property(TARGET absl::leak_check PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                                  absl::core_headers)
    set_property(TARGET absl::log_severity PROPERTY INTERFACE_LINK_LIBRARIES
                                                    absl::core_headers)
    set_property(TARGET absl::malloc_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::dynamic_annotations
                          absl::raw_logging_internal)
    set_property(TARGET absl::memory PROPERTY INTERFACE_LINK_LIBRARIES absl::core_headers
                                              absl::meta)
    set_property(TARGET absl::meta PROPERTY INTERFACE_LINK_LIBRARIES absl::type_traits)
    set_property(TARGET absl::node_hash_map
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::container_memory
                          absl::hash_function_defaults
                          absl::node_hash_policy
                          absl::raw_hash_map
                          absl::algorithm_container
                          absl::memory)
    set_property(TARGET absl::node_hash_policy PROPERTY INTERFACE_LINK_LIBRARIES
                                                        absl::config)
    set_property(TARGET absl::node_hash_set
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::hash_function_defaults
                          absl::node_hash_policy
                          absl::raw_hash_set
                          absl::algorithm_container
                          absl::memory)
    set_property(TARGET absl::numeric PROPERTY INTERFACE_LINK_LIBRARIES absl::int128)
    set_property(TARGET absl::numeric_representation PROPERTY INTERFACE_LINK_LIBRARIES
                                                              absl::config)
    set_property(TARGET absl::optional
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bad_optional_access
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::memory
                          absl::type_traits
                          absl::utility)
    set_property(TARGET absl::periodic_sampler
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::core_headers
                          absl::exponential_biased)
    set_property(TARGET absl::random_bit_gen_ref
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::core_headers
                          absl::random_internal_distribution_caller
                          absl::random_internal_fast_uniform_bits
                          absl::type_traits)
    set_property(TARGET absl::random_distributions
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::random_internal_generate_real
                          absl::random_internal_distribution_caller
                          absl::random_internal_fast_uniform_bits
                          absl::random_internal_fastmath
                          absl::random_internal_iostream_state_saver
                          absl::random_internal_traits
                          absl::random_internal_uniform_helper
                          absl::random_internal_wide_multiply
                          absl::strings
                          absl::type_traits)
    set_property(TARGET absl::random_internal_distribution_caller
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config absl::utility
                          absl::fast_type_id)
    set_property(TARGET absl::random_internal_distribution_test_util
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::raw_logging_internal
                          absl::strings
                          absl::str_format
                          absl::span)
    set_property(TARGET absl::random_internal_fastmath PROPERTY INTERFACE_LINK_LIBRARIES
                                                                absl::bits)
    set_property(TARGET absl::random_internal_fast_uniform_bits
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::random_internal_generate_real
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bits
                          absl::random_internal_fastmath
                          absl::random_internal_traits
                          absl::type_traits)
    set_property(TARGET absl::random_internal_iostream_state_saver
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::int128 absl::type_traits)
    set_property(TARGET absl::random_internal_mock_helpers
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::fast_type_id absl::optional)
    set_property(TARGET absl::random_internal_nonsecure_base
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::core_headers
                          absl::optional
                          absl::random_internal_pool_urbg
                          absl::random_internal_salted_seed_seq
                          absl::random_internal_seed_material
                          absl::span
                          absl::type_traits)
    set_property(TARGET absl::random_internal_pcg_engine
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::int128
                          absl::random_internal_fastmath
                          absl::random_internal_iostream_state_saver
                          absl::type_traits)
    set_property(TARGET absl::random_internal_platform PROPERTY INTERFACE_LINK_LIBRARIES
                                                                absl::config)
    set_property(TARGET absl::random_internal_pool_urbg
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::config
                          absl::core_headers
                          absl::endian
                          absl::random_internal_randen
                          absl::random_internal_seed_material
                          absl::random_internal_traits
                          absl::random_seed_gen_exception
                          absl::raw_logging_internal
                          absl::span)
    set_property(TARGET absl::random_internal_randen_engine
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::endian
                          absl::random_internal_iostream_state_saver
                          absl::random_internal_randen
                          absl::raw_logging_internal
                          absl::type_traits)
    set_property(TARGET absl::random_internal_randen_hwaes_impl
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::random_internal_platform
                          absl::config)
    set_property(TARGET absl::random_internal_randen_hwaes
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::random_internal_platform
                          absl::random_internal_randen_hwaes_impl absl::config)
    set_property(TARGET absl::random_internal_randen
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::random_internal_platform
                          absl::random_internal_randen_hwaes
                          absl::random_internal_randen_slow)
    set_property(TARGET absl::random_internal_randen_slow
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::random_internal_platform
                          absl::config)
    set_property(TARGET absl::random_internal_salted_seed_seq
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::inlined_vector
                          absl::optional
                          absl::span
                          absl::random_internal_seed_material
                          absl::type_traits)
    set_property(TARGET absl::random_internal_seed_material
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::core_headers
                          absl::optional
                          absl::random_internal_fast_uniform_bits
                          absl::raw_logging_internal
                          absl::span
                          absl::strings)
    set_property(TARGET absl::random_internal_traits PROPERTY INTERFACE_LINK_LIBRARIES
                                                              absl::config)
    set_property(TARGET absl::random_internal_uniform_helper
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::random_internal_traits absl::type_traits)
    set_property(TARGET absl::random_internal_wide_multiply
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::bits absl::config absl::int128)
    set_property(TARGET absl::random_random
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::random_distributions
                          absl::random_internal_nonsecure_base
                          absl::random_internal_pcg_engine
                          absl::random_internal_pool_urbg
                          absl::random_internal_randen_engine
                          absl::random_seed_sequences)
    set_property(TARGET absl::random_seed_gen_exception PROPERTY INTERFACE_LINK_LIBRARIES
                                                                 absl::config)
    set_property(TARGET absl::random_seed_sequences
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::inlined_vector
                          absl::random_internal_nonsecure_base
                          absl::random_internal_pool_urbg
                          absl::random_internal_salted_seed_seq
                          absl::random_internal_seed_material
                          absl::random_seed_gen_exception
                          absl::span)
    set_property(TARGET absl::raw_hash_map
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::container_memory
                          absl::raw_hash_set absl::throw_delegate)
    set_property(TARGET absl::raw_hash_set
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bits
                          absl::compressed_tuple
                          absl::config
                          absl::container_common
                          absl::container_memory
                          absl::core_headers
                          absl::endian
                          absl::hash_policy_traits
                          absl::hashtable_debug_hooks
                          absl::have_sse
                          absl::layout
                          absl::memory
                          absl::meta
                          absl::optional
                          absl::utility
                          absl::hashtablez_sampler)
    set_property(TARGET absl::raw_logging_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::atomic_hook
                          absl::config
                          absl::core_headers
                          absl::log_severity)
    set_property(TARGET absl::scoped_set_env
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::raw_logging_internal)
    set_property(TARGET absl::span
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::algorithm
                          absl::core_headers
                          absl::throw_delegate
                          absl::type_traits)
    set_property(TARGET absl::spinlock_wait
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::base_internal absl::core_headers
                          absl::errno_saver)
    set_property(TARGET absl::stacktrace
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::debugging_internal absl::config
                          absl::core_headers)
    set_property(TARGET absl::statusor
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::status
                          absl::core_headers
                          absl::raw_logging_internal
                          absl::type_traits
                          absl::strings
                          absl::utility
                          absl::variant)
    set_property(TARGET absl::status
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::atomic_hook
                          absl::config
                          absl::core_headers
                          absl::raw_logging_internal
                          absl::inlined_vector
                          absl::stacktrace
                          absl::symbolize
                          absl::strings
                          absl::cord
                          absl::str_format
                          absl::optional)
    set_property(TARGET absl::strerror PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                                absl::core_headers absl::errno_saver)
    set_property(TARGET absl::str_format_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bits
                          absl::strings
                          absl::config
                          absl::core_headers
                          absl::numeric_representation
                          absl::type_traits
                          absl::int128
                          absl::span)
    set_property(TARGET absl::str_format PROPERTY INTERFACE_LINK_LIBRARIES
                                                  absl::str_format_internal)
    set_property(TARGET absl::strings_internal
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::config
                          absl::core_headers
                          absl::endian
                          absl::raw_logging_internal
                          absl::type_traits)
    set_property(TARGET absl::strings
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::strings_internal
                          absl::base
                          absl::bits
                          absl::config
                          absl::core_headers
                          absl::endian
                          absl::int128
                          absl::memory
                          absl::raw_logging_internal
                          absl::throw_delegate
                          absl::type_traits)
    set_property(TARGET absl::symbolize
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::debugging_internal
                          absl::demangle_internal
                          absl::base
                          absl::config
                          absl::core_headers
                          absl::dynamic_annotations
                          absl::malloc_internal
                          absl::raw_logging_internal
                          absl::strings)
    set_property(TARGET absl::synchronization
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::graphcycles_internal
                          absl::kernel_timeout_internal
                          absl::atomic_hook
                          absl::base
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::dynamic_annotations
                          absl::malloc_internal
                          absl::raw_logging_internal
                          absl::stacktrace
                          absl::symbolize
                          absl::time)
    set_property(TARGET absl::throw_delegate
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                          absl::raw_logging_internal)
    set_property(TARGET absl::time
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::base
                          absl::civil_time
                          absl::core_headers
                          absl::int128
                          absl::raw_logging_internal
                          absl::strings
                          absl::time_zone)
    set_property(TARGET absl::type_traits PROPERTY INTERFACE_LINK_LIBRARIES absl::config)
    set_property(TARGET absl::utility
                 PROPERTY INTERFACE_LINK_LIBRARIES absl::base_internal absl::config
                          absl::type_traits)
    set_property(TARGET absl::variant
                 PROPERTY INTERFACE_LINK_LIBRARIES
                          absl::bad_variant_access
                          absl::base_internal
                          absl::config
                          absl::core_headers
                          absl::type_traits
                          absl::utility)
    set_property(TARGET absl::wyhash PROPERTY INTERFACE_LINK_LIBRARIES absl::config
                                              absl::endian absl::int128)

    externalproject_add(absl_ep
                        ${EP_LOG_OPTIONS}
                        URL ${ABSL_SOURCE_URL}
                        URL_HASH "SHA256=${ARROW_ABSL_BUILD_SHA256_CHECKSUM}"
                        CMAKE_ARGS ${ABSL_CMAKE_ARGS}
                        BUILD_BYPRODUCTS ${ABSL_BUILD_BYPRODUCTS})

    # Work around https://gitlab.kitware.com/cmake/cmake/issues/15052
    file(MAKE_DIRECTORY ${ABSL_INCLUDE_DIR})

  endif()
endmacro()

macro(build_grpc)
  resolve_dependency(c-ares
                     HAVE_ALT
                     TRUE
                     PC_PACKAGE_NAMES
                     libcares)
  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(c-ares_INCLUDE_DIR c-ares::cares INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${c-ares_INCLUDE_DIR})

  # First need to build Abseil
  build_absl_once()

  message(STATUS "Building gRPC from source")

  set(GRPC_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/grpc_ep-prefix/src/grpc_ep-build")
  set(GRPC_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/grpc_ep-install")
  set(GRPC_HOME "${GRPC_PREFIX}")
  set(GRPC_INCLUDE_DIR "${GRPC_PREFIX}/include")

  set(GRPC_STATIC_LIBRARY_GPR
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}gpr${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_STATIC_LIBRARY_GRPC
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}grpc${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_STATIC_LIBRARY_GRPCPP
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}grpc++${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_STATIC_LIBRARY_ADDRESS_SORTING
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}address_sorting${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_STATIC_LIBRARY_GRPCPP_REFLECTION
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}grpc++_reflection${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_STATIC_LIBRARY_UPB
      "${GRPC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}upb${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(GRPC_CPP_PLUGIN "${GRPC_PREFIX}/bin/grpc_cpp_plugin${CMAKE_EXECUTABLE_SUFFIX}")

  set(GRPC_CMAKE_PREFIX)

  add_custom_target(grpc_dependencies)

  add_dependencies(grpc_dependencies absl_ep)
  if(CARES_VENDORED)
    add_dependencies(grpc_dependencies cares_ep)
  endif()

  if(GFLAGS_VENDORED)
    add_dependencies(grpc_dependencies gflags_ep)
  endif()

  if(RE2_VENDORED)
    add_dependencies(grpc_dependencies re2_ep)
  endif()

  add_dependencies(grpc_dependencies ${ARROW_PROTOBUF_LIBPROTOBUF} c-ares::cares
                   ZLIB::ZLIB)

  get_target_property(GRPC_PROTOBUF_INCLUDE_DIR ${ARROW_PROTOBUF_LIBPROTOBUF}
                      INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(GRPC_PB_ROOT "${GRPC_PROTOBUF_INCLUDE_DIR}" DIRECTORY)
  get_target_property(GRPC_Protobuf_PROTOC_LIBRARY ${ARROW_PROTOBUF_LIBPROTOC}
                      IMPORTED_LOCATION)
  get_target_property(GRPC_CARES_INCLUDE_DIR c-ares::cares INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(GRPC_CARES_ROOT "${GRPC_CARES_INCLUDE_DIR}" DIRECTORY)
  get_target_property(GRPC_GFLAGS_INCLUDE_DIR ${GFLAGS_LIBRARIES}
                      INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(GRPC_GFLAGS_ROOT "${GRPC_GFLAGS_INCLUDE_DIR}" DIRECTORY)
  get_target_property(GRPC_RE2_INCLUDE_DIR re2::re2 INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(GRPC_RE2_ROOT "${GRPC_RE2_INCLUDE_DIR}" DIRECTORY)

  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${GRPC_PB_ROOT}")
  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${GRPC_GFLAGS_ROOT}")
  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${GRPC_CARES_ROOT}")
  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${GRPC_RE2_ROOT}")

  # ZLIB is never vendored
  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${ZLIB_ROOT}")
  set(GRPC_CMAKE_PREFIX "${GRPC_CMAKE_PREFIX};${ABSL_PREFIX}")

  if(RAPIDJSON_VENDORED)
    add_dependencies(grpc_dependencies rapidjson_ep)
  endif()

  # Yuck, see https://stackoverflow.com/a/45433229/776560
  string(REPLACE ";" "|" GRPC_PREFIX_PATH_ALT_SEP "${GRPC_CMAKE_PREFIX}")

  set(GRPC_CMAKE_ARGS
      "${EP_COMMON_CMAKE_ARGS}"
      -DCMAKE_PREFIX_PATH='${GRPC_PREFIX_PATH_ALT_SEP}'
      -DgRPC_ABSL_PROVIDER=package
      -DgRPC_BUILD_CSHARP_EXT=OFF
      -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF
      -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF
      -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF
      -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF
      -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF
      -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF
      -DgRPC_BUILD_TESTS=OFF
      -DgRPC_CARES_PROVIDER=package
      -DgRPC_GFLAGS_PROVIDER=package
      -DgRPC_MSVC_STATIC_RUNTIME=${ARROW_USE_STATIC_CRT}
      -DgRPC_PROTOBUF_PROVIDER=package
      -DgRPC_RE2_PROVIDER=package
      -DgRPC_SSL_PROVIDER=package
      -DgRPC_ZLIB_PROVIDER=package
      -DCMAKE_INSTALL_PREFIX=${GRPC_PREFIX}
      -DCMAKE_INSTALL_LIBDIR=lib
      -DBUILD_SHARED_LIBS=OFF)
  if(PROTOBUF_VENDORED)
    list(APPEND GRPC_CMAKE_ARGS -DgRPC_PROTOBUF_PACKAGE_TYPE=CONFIG)
  endif()
  if(OPENSSL_ROOT_DIR)
    list(APPEND GRPC_CMAKE_ARGS -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR})
  endif()

  # XXX the gRPC git checkout is huge and takes a long time
  # Ideally, we should be able to use the tarballs, but they don't contain
  # vendored dependencies such as c-ares...
  externalproject_add(grpc_ep
                      URL ${GRPC_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_GRPC_BUILD_SHA256_CHECKSUM}"
                      LIST_SEPARATOR |
                      BUILD_BYPRODUCTS ${GRPC_STATIC_LIBRARY_GPR}
                                       ${GRPC_STATIC_LIBRARY_GRPC}
                                       ${GRPC_STATIC_LIBRARY_GRPCPP}
                                       ${GRPC_STATIC_LIBRARY_ADDRESS_SORTING}
                                       ${GRPC_STATIC_LIBRARY_GRPCPP_REFLECTION}
                                       ${GRPC_STATIC_LIBRARY_UPB}
                                       ${GRPC_CPP_PLUGIN}
                      CMAKE_ARGS ${GRPC_CMAKE_ARGS} ${EP_LOG_OPTIONS}
                      DEPENDS ${grpc_dependencies})

  # Work around https://gitlab.kitware.com/cmake/cmake/issues/15052
  file(MAKE_DIRECTORY ${GRPC_INCLUDE_DIR})

  add_library(gRPC::upb STATIC IMPORTED)
  set_target_properties(gRPC::upb
                        PROPERTIES IMPORTED_LOCATION "${GRPC_STATIC_LIBRARY_UPB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")

  set(GRPC_GPR_ABSL_LIBRARIES
      absl::base
      absl::statusor
      absl::status
      absl::cord
      absl::strings
      absl::synchronization
      absl::time)
  add_library(gRPC::gpr STATIC IMPORTED)
  set_target_properties(gRPC::gpr
                        PROPERTIES IMPORTED_LOCATION "${GRPC_STATIC_LIBRARY_GPR}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}"
                                   INTERFACE_LINK_LIBRARIES "${GRPC_GPR_ABSL_LIBRARIES}")

  add_library(gRPC::address_sorting STATIC IMPORTED)
  set_target_properties(gRPC::address_sorting
                        PROPERTIES IMPORTED_LOCATION
                                   "${GRPC_STATIC_LIBRARY_ADDRESS_SORTING}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")

  add_library(gRPC::grpc++_reflection STATIC IMPORTED)
  set_target_properties(gRPC::grpc++_reflection
                        PROPERTIES IMPORTED_LOCATION
                                   "${GRPC_STATIC_LIBRARY_GRPCPP_REFLECTION}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}")

  add_library(gRPC::grpc STATIC IMPORTED)
  set(GRPC_LINK_LIBRARIES
      gRPC::gpr
      gRPC::upb
      gRPC::address_sorting
      re2::re2
      c-ares::cares
      ZLIB::ZLIB
      OpenSSL::SSL
      Threads::Threads)
  set_target_properties(gRPC::grpc
                        PROPERTIES IMPORTED_LOCATION "${GRPC_STATIC_LIBRARY_GRPC}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}"
                                   INTERFACE_LINK_LIBRARIES "${GRPC_LINK_LIBRARIES}")

  add_library(gRPC::grpc++ STATIC IMPORTED)
  set(GRPCPP_LINK_LIBRARIES gRPC::grpc ${ARROW_PROTOBUF_LIBPROTOBUF})
  set_target_properties(gRPC::grpc++
                        PROPERTIES IMPORTED_LOCATION "${GRPC_STATIC_LIBRARY_GRPCPP}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${GRPC_INCLUDE_DIR}"
                                   INTERFACE_LINK_LIBRARIES "${GRPCPP_LINK_LIBRARIES}")

  add_executable(gRPC::grpc_cpp_plugin IMPORTED)
  set_target_properties(gRPC::grpc_cpp_plugin PROPERTIES IMPORTED_LOCATION
                                                         ${GRPC_CPP_PLUGIN})

  add_dependencies(grpc_ep grpc_dependencies)
  add_dependencies(toolchain grpc_ep)
  add_dependencies(gRPC::grpc++ grpc_ep)
  add_dependencies(gRPC::grpc_cpp_plugin grpc_ep)
  set(GRPC_VENDORED TRUE)

  # ar -M rejects with the "libgrpc++.a" filename because "+" is a line
  # continuation character in these scripts, so we have to create a copy of the
  # static lib that we will bundle later

  set(GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR
      "${CMAKE_CURRENT_BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}grpcpp${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  add_custom_command(OUTPUT ${GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR}
                     COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:gRPC::grpc++>
                             ${GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR}
                     DEPENDS grpc_ep)
  add_library(gRPC::grpcpp_for_bundling STATIC IMPORTED)
  set_target_properties(gRPC::grpcpp_for_bundling
                        PROPERTIES IMPORTED_LOCATION
                                   "${GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR}")

  set_source_files_properties("${GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR}" PROPERTIES GENERATED
                                                                                TRUE)
  add_custom_target(grpc_copy_grpc++ ALL DEPENDS "${GRPC_STATIC_LIBRARY_GRPCPP_FOR_AR}")
  add_dependencies(gRPC::grpcpp_for_bundling grpc_copy_grpc++)

  list(APPEND
       ARROW_BUNDLED_STATIC_LIBS
       ${GRPC_GPR_ABSL_LIBRARIES}
       gRPC::address_sorting
       gRPC::gpr
       gRPC::grpc
       gRPC::grpcpp_for_bundling
       gRPC::upb)
endmacro()

if(ARROW_WITH_GRPC)
  set(ARROW_GRPC_REQUIRED_VERSION "1.17.0")
  resolve_dependency(gRPC
                     HAVE_ALT
                     TRUE
                     REQUIRED_VERSION
                     ${ARROW_GRPC_REQUIRED_VERSION}
                     PC_PACKAGE_NAMES
                     grpc++)

  # TODO: Don't use global includes but rather target_include_directories
  get_target_property(GRPC_INCLUDE_DIR gRPC::grpc++ INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${GRPC_INCLUDE_DIR})

  if(GRPC_VENDORED)
    set(GRPCPP_PP_INCLUDE TRUE)
    # Examples need to link to static Arrow if we're using static gRPC
    set(ARROW_GRPC_USE_SHARED OFF)
  else()
    # grpc++ headers may reside in ${GRPC_INCLUDE_DIR}/grpc++ or ${GRPC_INCLUDE_DIR}/grpcpp
    # depending on the gRPC version.
    if(EXISTS "${GRPC_INCLUDE_DIR}/grpcpp/impl/codegen/config_protobuf.h")
      set(GRPCPP_PP_INCLUDE TRUE)
    elseif(EXISTS "${GRPC_INCLUDE_DIR}/grpc++/impl/codegen/config_protobuf.h")
      set(GRPCPP_PP_INCLUDE FALSE)
    else()
      message(FATAL_ERROR "Cannot find grpc++ headers in ${GRPC_INCLUDE_DIR}")
    endif()
  endif()
endif()

# ----------------------------------------------------------------------
# GCS and dependencies

macro(build_crc32c_once)
  if(NOT TARGET crc32c_ep)
    message(STATUS "Building crc32c from source")
    # Build crc32c
    set(CRC32C_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/crc32c_ep-install")
    set(CRC32C_INCLUDE_DIR "${CRC32C_PREFIX}/include")
    set(CRC32C_CMAKE_ARGS
        ${EP_COMMON_CMAKE_ARGS}
        -DCMAKE_INSTALL_LIBDIR=lib
        "-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>"
        -DCMAKE_CXX_STANDARD=11
        -DCRC32C_BUILD_TESTS=OFF
        -DCRC32C_BUILD_BENCHMARKS=OFF
        -DCRC32C_USE_GLOG=OFF)

    set(_CRC32C_STATIC_LIBRARY
        "${CRC32C_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}crc32c${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
    set(CRC32C_BUILD_BYPRODUCTS ${_CRC32C_STATIC_LIBRARY})
    set(CRC32C_LIBRARIES crc32c)

    externalproject_add(crc32c_ep
                        ${EP_LOG_OPTIONS}
                        INSTALL_DIR ${CRC32C_PREFIX}
                        URL ${CRC32C_SOURCE_URL}
                        URL_HASH "SHA256=${ARROW_CRC32C_BUILD_SHA256_CHECKSUM}"
                        CMAKE_ARGS ${CRC32C_CMAKE_ARGS}
                        BUILD_BYPRODUCTS ${CRC32C_BUILD_BYPRODUCTS})
    # Work around https://gitlab.kitware.com/cmake/cmake/issues/15052
    file(MAKE_DIRECTORY "${CRC32C_INCLUDE_DIR}")
    add_library(Crc32c::crc32c STATIC IMPORTED)
    set_target_properties(Crc32c::crc32c
                          PROPERTIES IMPORTED_LOCATION ${_CRC32C_STATIC_LIBRARY}
                                     INTERFACE_INCLUDE_DIRECTORIES
                                     "${CRC32C_INCLUDE_DIR}")
    add_dependencies(Crc32c::crc32c crc32c_ep)
  endif()
endmacro()

macro(build_nlohmann_json_once)
  if(NOT TARGET nlohmann_json_ep)
    message(STATUS "Building nlohmann-json from source")
    # "Build" nlohmann-json
    set(NLOHMANN_JSON_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/nlohmann_json_ep-install")
    set(NLOHMANN_JSON_INCLUDE_DIR "${NLOHMANN_JSON_PREFIX}/include")
    set(NLOHMANN_JSON_CMAKE_ARGS
        ${EP_COMMON_CMAKE_ARGS}
        -DCMAKE_CXX_STANDARD=11
        "-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>"
        -DBUILD_TESTING=OFF
        -DJSON_BuildTests=OFF)

    set(NLOHMANN_JSON_BUILD_BYPRODUCTS ${NLOHMANN_JSON_PREFIX}/include/nlohmann/json.hpp)

    externalproject_add(nlohmann_json_ep
                        ${EP_LOG_OPTIONS}
                        INSTALL_DIR ${NLOHMANN_JSON_PREFIX}
                        URL ${NLOHMANN_JSON_SOURCE_URL}
                        URL_HASH "SHA256=${ARROW_NLOHMANN_JSON_BUILD_SHA256_CHECKSUM}"
                        CMAKE_ARGS ${NLOHMANN_JSON_CMAKE_ARGS}
                        BUILD_BYPRODUCTS ${NLOHMANN_JSON_BUILD_BYPRODUCTS})

    # Work around https://gitlab.kitware.com/cmake/cmake/issues/15052
    file(MAKE_DIRECTORY ${NLOHMANN_JSON_INCLUDE_DIR})

    add_library(nlohmann_json::nlohmann_json INTERFACE IMPORTED)
    set_target_properties(nlohmann_json::nlohmann_json
                          PROPERTIES INTERFACE_INCLUDE_DIRECTORIES
                                     "${NLOHMANN_JSON_INCLUDE_DIR}")
    add_dependencies(nlohmann_json::nlohmann_json nlohmann_json_ep)
  endif()
endmacro()

macro(build_google_cloud_cpp_storage)
  message(STATUS "Building google-cloud-cpp from source")
  message(STATUS "Only building the google-cloud-cpp::storage component")

  # List of dependencies taken from https://github.com/googleapis/google-cloud-cpp/blob/master/doc/packaging.md
  build_absl_once()
  build_crc32c_once()
  build_nlohmann_json_once()

  # Curl is required on all platforms, but building it internally might also trip over S3's copy.
  # For now, force its inclusion from the underlying system or fail.
  find_curl()
  find_package(OpenSSL ${ARROW_OPENSSL_REQUIRED_VERSION} REQUIRED)

  # Build google-cloud-cpp, with only storage_client

  # Inject vendored packages via CMAKE_PREFIX_PATH
  list(APPEND GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST ${ABSL_PREFIX})
  list(APPEND GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST ${CRC32C_PREFIX})
  list(APPEND GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST ${NLOHMANN_JSON_PREFIX})

  set(GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST_SEP_CHAR "|")
  list(JOIN GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST
       ${GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST_SEP_CHAR} GOOGLE_CLOUD_CPP_PREFIX_PATH)

  set(GOOGLE_CLOUD_CPP_INSTALL_PREFIX
      "${CMAKE_CURRENT_BINARY_DIR}/google_cloud_cpp_ep-install")
  set(GOOGLE_CLOUD_CPP_INCLUDE_DIR "${GOOGLE_CLOUD_CPP_INSTALL_PREFIX}/include")
  set(GOOGLE_CLOUD_CPP_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      -DBUILD_TESTING=OFF
      -DCMAKE_INSTALL_LIBDIR=lib
      "-DCMAKE_INSTALL_PREFIX=<INSTALL_DIR>"
      -DCMAKE_INSTALL_RPATH=$ORIGIN
      -DCMAKE_PREFIX_PATH=${GOOGLE_CLOUD_CPP_PREFIX_PATH}
      # Compile only the storage library and its dependencies. To enable
      # other services (Spanner, Bigtable, etc.) add them (as a list) to this
      # parameter. Each has its own `google-cloud-cpp::*` library.
      -DGOOGLE_CLOUD_CPP_ENABLE=storage)
  if(OPENSSL_ROOT_DIR)
    list(APPEND GOOGLE_CLOUD_CPP_CMAKE_ARGS -DOPENSSL_ROOT_DIR=${OPENSSL_ROOT_DIR})
  endif()

  add_custom_target(google_cloud_cpp_dependencies)

  add_dependencies(google_cloud_cpp_dependencies absl_ep)
  add_dependencies(google_cloud_cpp_dependencies crc32c_ep)
  add_dependencies(google_cloud_cpp_dependencies nlohmann_json_ep)

  set(GOOGLE_CLOUD_CPP_STATIC_LIBRARY_STORAGE
      "${GOOGLE_CLOUD_CPP_INSTALL_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}google_cloud_cpp_storage${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  set(GOOGLE_CLOUD_CPP_STATIC_LIBRARY_COMMON
      "${GOOGLE_CLOUD_CPP_INSTALL_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}google_cloud_cpp_common${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )

  externalproject_add(google_cloud_cpp_ep
                      ${EP_LOG_OPTIONS}
                      LIST_SEPARATOR ${GOOGLE_CLOUD_CPP_PREFIX_PATH_LIST_SEP_CHAR}
                      INSTALL_DIR ${GOOGLE_CLOUD_CPP_INSTALL_PREFIX}
                      URL ${google_cloud_cpp_storage_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_GOOGLE_CLOUD_CPP_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${GOOGLE_CLOUD_CPP_CMAKE_ARGS}
                      BUILD_BYPRODUCTS ${GOOGLE_CLOUD_CPP_STATIC_LIBRARY_STORAGE}
                                       ${GOOGLE_CLOUD_CPP_STATIC_LIBRARY_COMMON}
                      DEPENDS google_cloud_cpp_dependencies)

  # Work around https://gitlab.kitware.com/cmake/cmake/issues/15052
  file(MAKE_DIRECTORY ${GOOGLE_CLOUD_CPP_INCLUDE_DIR})

  add_dependencies(toolchain google_cloud_cpp_ep)

  add_library(google-cloud-cpp::common STATIC IMPORTED)
  set_target_properties(google-cloud-cpp::common
                        PROPERTIES IMPORTED_LOCATION
                                   "${GOOGLE_CLOUD_CPP_STATIC_LIBRARY_COMMON}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${GOOGLE_CLOUD_CPP_INCLUDE_DIR}")
  set_property(TARGET google-cloud-cpp::common
               PROPERTY INTERFACE_LINK_LIBRARIES
                        absl::any
                        absl::flat_hash_map
                        absl::memory
                        absl::optional
                        absl::time
                        Threads::Threads)

  add_library(google-cloud-cpp::storage STATIC IMPORTED)
  set_target_properties(google-cloud-cpp::storage
                        PROPERTIES IMPORTED_LOCATION
                                   "${GOOGLE_CLOUD_CPP_STATIC_LIBRARY_STORAGE}"
                                   INTERFACE_INCLUDE_DIRECTORIES
                                   "${GOOGLE_CLOUD_CPP_INCLUDE_DIR}")
  set_property(TARGET google-cloud-cpp::storage
               PROPERTY INTERFACE_LINK_LIBRARIES
                        google-cloud-cpp::common
                        absl::memory
                        absl::strings
                        absl::str_format
                        absl::time
                        absl::variant
                        nlohmann_json::nlohmann_json
                        Crc32c::crc32c
                        CURL::libcurl
                        Threads::Threads
                        OpenSSL::SSL
                        OpenSSL::Crypto)
  add_dependencies(google-cloud-cpp::storage google_cloud_cpp_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS google-cloud-cpp::storage
       google-cloud-cpp::common)
endmacro()

if(ARROW_WITH_GOOGLE_CLOUD_CPP)
  resolve_dependency(google_cloud_cpp_storage)
  get_target_property(google_cloud_cpp_storage_INCLUDE_DIR google-cloud-cpp::storage
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${google_cloud_cpp_storage_INCLUDE_DIR})
  get_target_property(absl_base_INCLUDE_DIR absl::base INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${absl_base_INCLUDE_DIR})
  message(STATUS "Found google-cloud-cpp::storage headers: ${google_cloud_cpp_storage_INCLUDE_DIR}"
  )
endif()

#
# HDFS thirdparty setup

if(DEFINED ENV{HADOOP_HOME})
  set(HADOOP_HOME $ENV{HADOOP_HOME})
  if(NOT EXISTS "${HADOOP_HOME}/include/hdfs.h")
    message(STATUS "Did not find hdfs.h in expected location, using vendored one")
    set(HADOOP_HOME "${THIRDPARTY_DIR}/hadoop")
  endif()
else()
  set(HADOOP_HOME "${THIRDPARTY_DIR}/hadoop")
endif()

set(HDFS_H_PATH "${HADOOP_HOME}/include/hdfs.h")
if(NOT EXISTS ${HDFS_H_PATH})
  message(FATAL_ERROR "Did not find hdfs.h at ${HDFS_H_PATH}")
endif()
message(STATUS "Found hdfs.h at: " ${HDFS_H_PATH})

include_directories(SYSTEM "${HADOOP_HOME}/include")

# ----------------------------------------------------------------------
# Apache ORC

macro(build_orc)
  message("Building Apache ORC from source")
  set(ORC_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/orc_ep-install")
  set(ORC_HOME "${ORC_PREFIX}")
  set(ORC_INCLUDE_DIR "${ORC_PREFIX}/include")
  set(ORC_STATIC_LIB
      "${ORC_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}orc${CMAKE_STATIC_LIBRARY_SUFFIX}")

  get_target_property(ORC_PROTOBUF_INCLUDE_DIR ${ARROW_PROTOBUF_LIBPROTOBUF}
                      INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(ORC_PB_ROOT "${ORC_PROTOBUF_INCLUDE_DIR}" DIRECTORY)
  get_target_property(ORC_PROTOBUF_LIBRARY ${ARROW_PROTOBUF_LIBPROTOBUF}
                      IMPORTED_LOCATION)

  get_target_property(ORC_SNAPPY_INCLUDE_DIR Snappy::snappy INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(ORC_SNAPPY_ROOT "${ORC_SNAPPY_INCLUDE_DIR}" DIRECTORY)

  get_target_property(ORC_LZ4_ROOT LZ4::lz4 INTERFACE_INCLUDE_DIRECTORIES)
  get_filename_component(ORC_LZ4_ROOT "${ORC_LZ4_ROOT}" DIRECTORY)

  # Weirdly passing in PROTOBUF_LIBRARY for PROTOC_LIBRARY still results in ORC finding
  # the protoc library.
  set(ORC_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      "-DCMAKE_INSTALL_PREFIX=${ORC_PREFIX}"
      -DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}
      -DSTOP_BUILD_ON_WARNING=OFF
      -DBUILD_LIBHDFSPP=OFF
      -DBUILD_JAVA=OFF
      -DBUILD_TOOLS=OFF
      -DBUILD_CPP_TESTS=OFF
      -DINSTALL_VENDORED_LIBS=OFF
      "-DSNAPPY_HOME=${ORC_SNAPPY_ROOT}"
      "-DSNAPPY_INCLUDE_DIR=${ORC_SNAPPY_INCLUDE_DIR}"
      "-DPROTOBUF_HOME=${ORC_PB_ROOT}"
      "-DPROTOBUF_INCLUDE_DIR=${ORC_PROTOBUF_INCLUDE_DIR}"
      "-DPROTOBUF_LIBRARY=${ORC_PROTOBUF_LIBRARY}"
      "-DPROTOC_LIBRARY=${ORC_PROTOBUF_LIBRARY}"
      "-DLZ4_HOME=${LZ4_HOME}"
      "-DZSTD_HOME=${ZSTD_HOME}")
  if(ZLIB_ROOT)
    set(ORC_CMAKE_ARGS ${ORC_CMAKE_ARGS} "-DZLIB_HOME=${ZLIB_ROOT}")
  endif()

  # Work around CMake bug
  file(MAKE_DIRECTORY ${ORC_INCLUDE_DIR})

  externalproject_add(orc_ep
                      URL ${ORC_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_ORC_BUILD_SHA256_CHECKSUM}"
                      BUILD_BYPRODUCTS ${ORC_STATIC_LIB}
                      CMAKE_ARGS ${ORC_CMAKE_ARGS} ${EP_LOG_OPTIONS})

  add_dependencies(toolchain orc_ep)

  set(ORC_VENDORED 1)
  add_dependencies(orc_ep ZLIB::ZLIB)
  add_dependencies(orc_ep LZ4::lz4)
  add_dependencies(orc_ep Snappy::snappy)
  add_dependencies(orc_ep ${ARROW_PROTOBUF_LIBPROTOBUF})

  add_library(orc::liborc STATIC IMPORTED)
  set_target_properties(orc::liborc
                        PROPERTIES IMPORTED_LOCATION "${ORC_STATIC_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${ORC_INCLUDE_DIR}")

  add_dependencies(toolchain orc_ep)
  add_dependencies(orc::liborc orc_ep)

  list(APPEND ARROW_BUNDLED_STATIC_LIBS orc::liborc)
endmacro()

if(ARROW_ORC)
  resolve_dependency(ORC)
  include_directories(SYSTEM ${ORC_INCLUDE_DIR})
  message(STATUS "Found ORC static library: ${ORC_STATIC_LIB}")
  message(STATUS "Found ORC headers: ${ORC_INCLUDE_DIR}")
endif()

# ----------------------------------------------------------------------
# OpenTelemetry C++

macro(build_opentelemetry)
  message("Building OpenTelemetry from source")

  build_nlohmann_json_once()
  find_curl()

  set(OPENTELEMETRY_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/opentelemetry_ep-install")
  set(OPENTELEMETRY_INCLUDE_DIR "${OPENTELEMETRY_PREFIX}/include")
  set(OPENTELEMETRY_STATIC_LIB
      "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}opentelemetry${CMAKE_STATIC_LIBRARY_SUFFIX}"
  )
  set(_OPENTELEMETRY_APIS api ext sdk)
  set(_OPENTELEMETRY_LIBS
      common
      http_client_curl
      ostream_span_exporter
      otlp_http_client
      otlp_http_exporter
      otlp_recordable
      proto
      resources
      trace
      version)
  set(OPENTELEMETRY_BUILD_BYPRODUCTS)
  set(OPENTELEMETRY_LIBRARIES)

  foreach(_OPENTELEMETRY_LIB ${_OPENTELEMETRY_APIS})
    add_library(opentelemetry-cpp::${_OPENTELEMETRY_LIB} INTERFACE IMPORTED)
    set_target_properties(opentelemetry-cpp::${_OPENTELEMETRY_LIB}
                          PROPERTIES INTERFACE_INCLUDE_DIRECTORIES
                                     "${OPENTELEMETRY_INCLUDE_DIR}")
  endforeach()
  foreach(_OPENTELEMETRY_LIB ${_OPENTELEMETRY_LIBS})
    # N.B. OTel targets and libraries don't follow any consistent naming scheme
    if(_OPENTELEMETRY_LIB STREQUAL "http_client_curl")
      set(_OPENTELEMETRY_STATIC_LIBRARY
          "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}${_OPENTELEMETRY_LIB}${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
    elseif(_OPENTELEMETRY_LIB STREQUAL "ostream_span_exporter")
      set(_OPENTELEMETRY_STATIC_LIBRARY
          "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}opentelemetry_exporter_ostream_span${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
    elseif(_OPENTELEMETRY_LIB STREQUAL "otlp_http_client")
      set(_OPENTELEMETRY_STATIC_LIBRARY
          "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}opentelemetry_exporter_otlp_http_client${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
    elseif(_OPENTELEMETRY_LIB STREQUAL "otlp_http_exporter")
      set(_OPENTELEMETRY_STATIC_LIBRARY
          "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}opentelemetry_exporter_otlp_http${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
    else()
      set(_OPENTELEMETRY_STATIC_LIBRARY
          "${OPENTELEMETRY_PREFIX}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}opentelemetry_${_OPENTELEMETRY_LIB}${CMAKE_STATIC_LIBRARY_SUFFIX}"
      )
    endif()
    add_library(opentelemetry-cpp::${_OPENTELEMETRY_LIB} STATIC IMPORTED)
    set_target_properties(opentelemetry-cpp::${_OPENTELEMETRY_LIB}
                          PROPERTIES IMPORTED_LOCATION ${_OPENTELEMETRY_STATIC_LIBRARY})
    list(APPEND OPENTELEMETRY_BUILD_BYPRODUCTS ${_OPENTELEMETRY_STATIC_LIBRARY})
    list(APPEND OPENTELEMETRY_LIBRARIES opentelemetry-cpp::${_OPENTELEMETRY_LIB})
  endforeach()

  set(OPENTELEMETRY_CMAKE_ARGS
      ${EP_COMMON_TOOLCHAIN}
      "-DCMAKE_INSTALL_PREFIX=${OPENTELEMETRY_PREFIX}"
      "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
      -DCMAKE_INSTALL_LIBDIR=lib
      "-DCMAKE_CXX_FLAGS=${EP_CXX_FLAGS}"
      -DBUILD_TESTING=OFF
      -DWITH_EXAMPLES=OFF)

  set(OPENTELEMETRY_PREFIX_PATH_LIST)
  # Don't specify the DEPENDS unless we actually have dependencies, else
  # Ninja/other build systems may consider this target to always be dirty
  set(_OPENTELEMETRY_DEPENDENCIES)
  add_custom_target(opentelemetry_dependencies)

  set(_OPENTELEMETRY_DEPENDENCIES "opentelemetry_dependencies")
  list(APPEND ARROW_BUNDLED_STATIC_LIBS ${OPENTELEMETRY_LIBRARIES})
  list(APPEND OPENTELEMETRY_PREFIX_PATH_LIST ${NLOHMANN_JSON_PREFIX})

  get_target_property(OPENTELEMETRY_PROTOBUF_INCLUDE_DIR ${ARROW_PROTOBUF_LIBPROTOBUF}
                      INTERFACE_INCLUDE_DIRECTORIES)
  get_target_property(OPENTELEMETRY_PROTOBUF_LIBRARY ${ARROW_PROTOBUF_LIBPROTOBUF}
                      IMPORTED_LOCATION)
  get_target_property(OPENTELEMETRY_PROTOC_EXECUTABLE ${ARROW_PROTOBUF_PROTOC}
                      IMPORTED_LOCATION)
  list(APPEND
       OPENTELEMETRY_CMAKE_ARGS
       -DWITH_OTLP=ON
       -DWITH_OTLP_HTTP=ON
       -DWITH_OTLP_GRPC=OFF
       "-DProtobuf_INCLUDE_DIR=${OPENTELEMETRY_PROTOBUF_INCLUDE_DIR}"
       "-DProtobuf_LIBRARY=${OPENTELEMETRY_PROTOBUF_INCLUDE_DIR}"
       "-DProtobuf_PROTOC_EXECUTABLE=${OPENTELEMETRY_PROTOC_EXECUTABLE}")

  # OpenTelemetry with OTLP enabled requires Protobuf definitions from a
  # submodule. This submodule path is hardcoded into their CMake definitions,
  # and submodules are not included in their releases. Add a custom build step
  # to download and extract the Protobufs.

  # Adding such a step is rather complicated, so instead: create a separate
  # ExternalProject that just fetches the Protobufs, then add a custom step
  # to the main build to copy the Protobufs.
  externalproject_add(opentelemetry_proto_ep
                      ${EP_LOG_OPTIONS}
                      URL_HASH "SHA256=${ARROW_OPENTELEMETRY_PROTO_BUILD_SHA256_CHECKSUM}"
                      URL ${OPENTELEMETRY_PROTO_SOURCE_URL}
                      BUILD_COMMAND ""
                      CONFIGURE_COMMAND ""
                      INSTALL_COMMAND ""
                      EXCLUDE_FROM_ALL OFF)

  add_dependencies(opentelemetry_dependencies nlohmann_json_ep opentelemetry_proto_ep
                   ${ARROW_PROTOBUF_LIBPROTOBUF})

  set(OPENTELEMETRY_PREFIX_PATH_LIST_SEP_CHAR "|")
  # JOIN is CMake >=3.12 only
  string(REPLACE ";" "${OPENTELEMETRY_PREFIX_PATH_LIST_SEP_CHAR}"
                 OPENTELEMETRY_PREFIX_PATH "${OPENTELEMETRY_PREFIX_PATH_LIST}")
  list(APPEND OPENTELEMETRY_CMAKE_ARGS "-DCMAKE_PREFIX_PATH=${OPENTELEMETRY_PREFIX_PATH}")

  if(CMAKE_SYSTEM_PROCESSOR STREQUAL "s390x")
    # OpenTelemetry tries to determine the processor arch for vcpkg, which fails
    # on s390x, even though it doesn't use vcpkg there. Tell it ARCH manually
    externalproject_add(opentelemetry_ep
                        ${EP_LOG_OPTIONS}
                        URL_HASH "SHA256=${ARROW_OPENTELEMETRY_BUILD_SHA256_CHECKSUM}"
                        LIST_SEPARATOR ${OPENTELEMETRY_PREFIX_PATH_LIST_SEP_CHAR}
                        CONFIGURE_COMMAND ${CMAKE_COMMAND} -E env ARCH=s390x
                                          ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR}
                                          "<SOURCE_DIR><SOURCE_SUBDIR>"
                                          ${OPENTELEMETRY_CMAKE_ARGS}
                        BUILD_COMMAND ${CMAKE_COMMAND} --build "<BINARY_DIR>" --target all
                        INSTALL_COMMAND ${CMAKE_COMMAND} --build "<BINARY_DIR>" --target
                                        install
                        URL ${OPENTELEMETRY_SOURCE_URL}
                        BUILD_BYPRODUCTS ${OPENTELEMETRY_BUILD_BYPRODUCTS}
                        EXCLUDE_FROM_ALL NOT
                        ${ARROW_WITH_OPENTELEMETRY}
                        DEPENDS ${_OPENTELEMETRY_DEPENDENCIES})
  else()
    externalproject_add(opentelemetry_ep
                        ${EP_LOG_OPTIONS}
                        URL_HASH "SHA256=${ARROW_OPENTELEMETRY_BUILD_SHA256_CHECKSUM}"
                        LIST_SEPARATOR ${OPENTELEMETRY_PREFIX_PATH_LIST_SEP_CHAR}
                        CMAKE_ARGS ${OPENTELEMETRY_CMAKE_ARGS}
                        URL ${OPENTELEMETRY_SOURCE_URL}
                        BUILD_BYPRODUCTS ${OPENTELEMETRY_BUILD_BYPRODUCTS}
                        EXCLUDE_FROM_ALL NOT
                        ${ARROW_WITH_OPENTELEMETRY}
                        DEPENDS ${_OPENTELEMETRY_DEPENDENCIES})
  endif()

  externalproject_add_step(opentelemetry_ep download_proto
                           COMMAND ${CMAKE_COMMAND} -E copy_directory
                                   $<TARGET_PROPERTY:opentelemetry_proto_ep,_EP_SOURCE_DIR>/opentelemetry
                                   $<TARGET_PROPERTY:opentelemetry_ep,_EP_SOURCE_DIR>/third_party/opentelemetry-proto/opentelemetry
                           DEPENDEES download
                           DEPENDERS configure)

  add_dependencies(toolchain opentelemetry_ep)
  add_dependencies(toolchain-tests opentelemetry_ep)

  set(OPENTELEMETRY_VENDORED 1)

  set_target_properties(opentelemetry-cpp::common
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::api;opentelemetry-cpp::sdk;Threads::Threads"
  )
  set_target_properties(opentelemetry-cpp::resources
                        PROPERTIES INTERFACE_LINK_LIBRARIES "opentelemetry-cpp::common")
  set_target_properties(opentelemetry-cpp::trace
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::common;opentelemetry-cpp::resources"
  )
  set_target_properties(opentelemetry-cpp::http_client_curl
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::ext;CURL::libcurl")
  set_target_properties(opentelemetry-cpp::proto
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "${ARROW_PROTOBUF_LIBPROTOBUF}")
  set_target_properties(opentelemetry-cpp::otlp_recordable
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::trace;opentelemetry-cpp::resources;opentelemetry-cpp::proto"
  )
  set_target_properties(opentelemetry-cpp::otlp_http_client
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::sdk;opentelemetry-cpp::proto;opentelemetry-cpp::http_client_curl;nlohmann_json::nlohmann_json"
  )
  set_target_properties(opentelemetry-cpp::otlp_http_exporter
                        PROPERTIES INTERFACE_LINK_LIBRARIES
                                   "opentelemetry-cpp::otlp_recordable;opentelemetry-cpp::otlp_http_client"
  )

  foreach(_OPENTELEMETRY_LIB ${_OPENTELEMETRY_LIBS})
    add_dependencies(opentelemetry-cpp::${_OPENTELEMETRY_LIB} opentelemetry_ep)
  endforeach()
endmacro()

if(ARROW_WITH_OPENTELEMETRY)
  set(opentelemetry-cpp_SOURCE "AUTO")
  resolve_dependency(opentelemetry-cpp)
  get_target_property(OPENTELEMETRY_INCLUDE_DIR opentelemetry-cpp::api
                      INTERFACE_INCLUDE_DIRECTORIES)
  include_directories(SYSTEM ${OPENTELEMETRY_INCLUDE_DIR})
  message(STATUS "Found OpenTelemetry headers: ${OPENTELEMETRY_INCLUDE_DIR}")
endif()

# ----------------------------------------------------------------------
# AWS SDK for C++

macro(build_awssdk)
  message("Building AWS C++ SDK from source")
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_LESS
                                              "4.9")
    message(FATAL_ERROR "AWS C++ SDK requires gcc >= 4.9")
  endif()
  set(AWSSDK_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/awssdk_ep-install")
  set(AWSSDK_INCLUDE_DIR "${AWSSDK_PREFIX}/include")
  set(AWSSDK_LIB_DIR "lib")

  if(WIN32)
    # On Windows, need to match build types
    set(AWSSDK_BUILD_TYPE ${CMAKE_BUILD_TYPE})
  else()
    # Otherwise, always build in release mode.
    # Especially with gcc, debug builds can fail with "asm constraint" errors:
    # https://github.com/TileDB-Inc/TileDB/issues/1351
    set(AWSSDK_BUILD_TYPE release)
  endif()

  set(AWSSDK_COMMON_CMAKE_ARGS
      ${EP_COMMON_CMAKE_ARGS}
      -DBUILD_SHARED_LIBS=OFF
      -DCMAKE_BUILD_TYPE=${AWSSDK_BUILD_TYPE}
      -DCMAKE_INSTALL_LIBDIR=${AWSSDK_LIB_DIR}
      -DENABLE_TESTING=OFF
      -DENABLE_UNITY_BUILD=ON
      "-DCMAKE_INSTALL_PREFIX=${AWSSDK_PREFIX}"
      "-DCMAKE_PREFIX_PATH=${AWSSDK_PREFIX}")

  set(AWSSDK_CMAKE_ARGS
      ${AWSSDK_COMMON_CMAKE_ARGS}
      -DBUILD_DEPS=OFF
      -DBUILD_ONLY=config\\$<SEMICOLON>s3\\$<SEMICOLON>transfer\\$<SEMICOLON>identity-management\\$<SEMICOLON>sts
      -DMINIMIZE_SIZE=ON)
  if(UNIX AND TARGET zlib_ep)
    list(APPEND AWSSDK_CMAKE_ARGS -DZLIB_INCLUDE_DIR=${ZLIB_INCLUDE_DIRS}
         -DZLIB_LIBRARY=${ZLIB_LIBRARIES})
  endif()

  file(MAKE_DIRECTORY ${AWSSDK_INCLUDE_DIR})

  # AWS C++ SDK related libraries to link statically
  set(_AWSSDK_LIBS
      aws-cpp-sdk-identity-management
      aws-cpp-sdk-sts
      aws-cpp-sdk-cognito-identity
      aws-cpp-sdk-s3
      aws-cpp-sdk-core
      aws-c-event-stream
      aws-checksums
      aws-c-common)
  set(AWSSDK_LIBRARIES)
  foreach(_AWSSDK_LIB ${_AWSSDK_LIBS})
    # aws-c-common -> AWS-C-COMMON
    string(TOUPPER ${_AWSSDK_LIB} _AWSSDK_LIB_UPPER)
    # AWS-C-COMMON -> AWS_C_COMMON
    string(REPLACE "-" "_" _AWSSDK_LIB_NAME_PREFIX ${_AWSSDK_LIB_UPPER})
    set(_AWSSDK_STATIC_LIBRARY
        "${AWSSDK_PREFIX}/${AWSSDK_LIB_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}${_AWSSDK_LIB}${CMAKE_STATIC_LIBRARY_SUFFIX}"
    )
    if(${_AWSSDK_LIB} MATCHES "^aws-cpp-sdk-")
      set(_AWSSDK_TARGET_NAME ${_AWSSDK_LIB})
    else()
      set(_AWSSDK_TARGET_NAME AWS::${_AWSSDK_LIB})
    endif()
    add_library(${_AWSSDK_TARGET_NAME} STATIC IMPORTED)
    set_target_properties(${_AWSSDK_TARGET_NAME}
                          PROPERTIES IMPORTED_LOCATION ${_AWSSDK_STATIC_LIBRARY}
                                     INTERFACE_INCLUDE_DIRECTORIES
                                     "${AWSSDK_INCLUDE_DIR}")
    set("${_AWSSDK_LIB_NAME_PREFIX}_STATIC_LIBRARY" ${_AWSSDK_STATIC_LIBRARY})
    list(APPEND AWSSDK_LIBRARIES ${_AWSSDK_TARGET_NAME})
  endforeach()

  externalproject_add(aws_c_common_ep
                      ${EP_LOG_OPTIONS}
                      URL ${AWS_C_COMMON_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_AWS_C_COMMON_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${AWSSDK_COMMON_CMAKE_ARGS}
                      BUILD_BYPRODUCTS ${AWS_C_COMMON_STATIC_LIBRARY})
  add_dependencies(AWS::aws-c-common aws_c_common_ep)

  externalproject_add(aws_checksums_ep
                      ${EP_LOG_OPTIONS}
                      URL ${AWS_CHECKSUMS_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_AWS_CHECKSUMS_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${AWSSDK_COMMON_CMAKE_ARGS}
                      BUILD_BYPRODUCTS ${AWS_CHECKSUMS_STATIC_LIBRARY}
                      DEPENDS aws_c_common_ep)
  add_dependencies(AWS::aws-checksums aws_checksums_ep)

  externalproject_add(aws_c_event_stream_ep
                      ${EP_LOG_OPTIONS}
                      URL ${AWS_C_EVENT_STREAM_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_AWS_C_EVENT_STREAM_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${AWSSDK_COMMON_CMAKE_ARGS}
                      BUILD_BYPRODUCTS ${AWS_C_EVENT_STREAM_STATIC_LIBRARY}
                      DEPENDS aws_checksums_ep)
  add_dependencies(AWS::aws-c-event-stream aws_c_event_stream_ep)

  set(AWSSDK_PATCH_COMMAND)
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" AND CMAKE_CXX_COMPILER_VERSION VERSION_GREATER
                                              "10")
    # Workaround for https://github.com/aws/aws-sdk-cpp/issues/1750
    set(AWSSDK_PATCH_COMMAND "sed" "-i.bak" "-e" "s/\"-Werror\"//g"
                             "<SOURCE_DIR>/cmake/compiler_settings.cmake")
  endif()
  externalproject_add(awssdk_ep
                      ${EP_LOG_OPTIONS}
                      URL ${AWSSDK_SOURCE_URL}
                      URL_HASH "SHA256=${ARROW_AWSSDK_BUILD_SHA256_CHECKSUM}"
                      CMAKE_ARGS ${AWSSDK_CMAKE_ARGS}
                      PATCH_COMMAND ${AWSSDK_PATCH_COMMAND}
                      BUILD_BYPRODUCTS ${AWS_CPP_SDK_COGNITO_IDENTITY_STATIC_LIBRARY}
                                       ${AWS_CPP_SDK_CORE_STATIC_LIBRARY}
                                       ${AWS_CPP_SDK_IDENTITY_MANAGEMENT_STATIC_LIBRARY}
                                       ${AWS_CPP_SDK_S3_STATIC_LIBRARY}
                                       ${AWS_CPP_SDK_STS_STATIC_LIBRARY}
                      DEPENDS aws_c_event_stream_ep)
  add_dependencies(toolchain awssdk_ep)
  foreach(_AWSSDK_LIB ${_AWSSDK_LIBS})
    if(${_AWSSDK_LIB} MATCHES "^aws-cpp-sdk-")
      add_dependencies(${_AWSSDK_LIB} awssdk_ep)
    endif()
  endforeach()

  set(AWSSDK_VENDORED TRUE)
  list(APPEND ARROW_BUNDLED_STATIC_LIBS ${AWSSDK_LIBRARIES})
  set(AWSSDK_LINK_LIBRARIES ${AWSSDK_LIBRARIES})
  if(UNIX)
    # on Linux and macOS curl seems to be required
    find_curl()
    set_property(TARGET aws-cpp-sdk-core
                 APPEND
                 PROPERTY INTERFACE_LINK_LIBRARIES CURL::libcurl)
    set_property(TARGET CURL::libcurl
                 APPEND
                 PROPERTY INTERFACE_LINK_LIBRARIES OpenSSL::SSL)
    if(TARGET zlib_ep)
      set_property(TARGET aws-cpp-sdk-core
                   APPEND
                   PROPERTY INTERFACE_LINK_LIBRARIES ZLIB::ZLIB)
      add_dependencies(awssdk_ep zlib_ep)
    endif()
  endif()

  # AWSSDK is static-only build
endmacro()

if(ARROW_S3)
  # See https://aws.amazon.com/blogs/developer/developer-experience-of-the-aws-sdk-for-c-now-simplified-by-cmake/

  # Workaround to force AWS CMake configuration to look for shared libraries
  if(DEFINED ENV{CONDA_PREFIX})
    if(DEFINED BUILD_SHARED_LIBS)
      set(BUILD_SHARED_LIBS_WAS_SET TRUE)
      set(BUILD_SHARED_LIBS_VALUE ${BUILD_SHARED_LIBS})
    else()
      set(BUILD_SHARED_LIBS_WAS_SET FALSE)
    endif()
    set(BUILD_SHARED_LIBS "ON")
  endif()

  # Need to customize the find_package() call, so cannot call resolve_dependency()
  if(AWSSDK_SOURCE STREQUAL "AUTO")
    find_package(AWSSDK
                 COMPONENTS config
                            s3
                            transfer
                            identity-management
                            sts)
    if(NOT AWSSDK_FOUND)
      build_awssdk()
    endif()
  elseif(AWSSDK_SOURCE STREQUAL "BUNDLED")
    build_awssdk()
  elseif(AWSSDK_SOURCE STREQUAL "SYSTEM")
    find_package(AWSSDK REQUIRED
                 COMPONENTS config
                            s3
                            transfer
                            identity-management
                            sts)
  endif()

  # Restore previous value of BUILD_SHARED_LIBS
  if(DEFINED ENV{CONDA_PREFIX})
    if(BUILD_SHARED_LIBS_WAS_SET)
      set(BUILD_SHARED_LIBS ${BUILD_SHARED_LIBS_VALUE})
    else()
      unset(BUILD_SHARED_LIBS)
    endif()
  endif()

  include_directories(SYSTEM ${AWSSDK_INCLUDE_DIR})
  message(STATUS "Found AWS SDK headers: ${AWSSDK_INCLUDE_DIR}")
  message(STATUS "Found AWS SDK libraries: ${AWSSDK_LINK_LIBRARIES}")

  if(APPLE)
    # CoreFoundation's path is hardcoded in the CMake files provided by
    # aws-sdk-cpp to use the MacOSX SDK provided by XCode which makes
    # XCode a hard dependency. Command Line Tools is often used instead
    # of the full XCode suite, so let the linker to find it.
    set_target_properties(AWS::aws-c-common
                          PROPERTIES INTERFACE_LINK_LIBRARIES
                                     "-pthread;pthread;-framework CoreFoundation")
  endif()
endif()

message(STATUS "All bundled static libraries: ${ARROW_BUNDLED_STATIC_LIBS}")

# Write out the package configurations.

configure_file("src/arrow/util/config.h.cmake" "src/arrow/util/config.h" ESCAPE_QUOTES)
install(FILES "${ARROW_BINARY_DIR}/src/arrow/util/config.h"
        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/arrow/util")
