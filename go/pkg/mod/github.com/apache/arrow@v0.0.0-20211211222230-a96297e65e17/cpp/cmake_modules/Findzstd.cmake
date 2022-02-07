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

if(MSVC AND NOT DEFINED ZSTD_MSVC_LIB_PREFIX)
  set(ZSTD_MSVC_LIB_PREFIX "lib")
endif()
set(ZSTD_LIB_NAME_BASE "${ZSTD_MSVC_LIB_PREFIX}zstd")

if(ARROW_ZSTD_USE_SHARED)
  set(ZSTD_LIB_NAMES)
  if(CMAKE_IMPORT_LIBRARY_SUFFIX)
    list(APPEND
         ZSTD_LIB_NAMES
         "${CMAKE_IMPORT_LIBRARY_PREFIX}${ZSTD_LIB_NAME_BASE}${CMAKE_IMPORT_LIBRARY_SUFFIX}"
    )
  endif()
  list(APPEND ZSTD_LIB_NAMES
       "${CMAKE_SHARED_LIBRARY_PREFIX}${ZSTD_LIB_NAME_BASE}${CMAKE_SHARED_LIBRARY_SUFFIX}"
  )
else()
  if(MSVC AND NOT DEFINED ZSTD_MSVC_STATIC_LIB_SUFFIX)
    set(ZSTD_MSVC_STATIC_LIB_SUFFIX "_static")
  endif()
  set(ZSTD_STATIC_LIB_SUFFIX
      "${ZSTD_MSVC_STATIC_LIB_SUFFIX}${CMAKE_STATIC_LIBRARY_SUFFIX}")
  set(ZSTD_LIB_NAMES
      "${CMAKE_STATIC_LIBRARY_PREFIX}${ZSTD_LIB_NAME_BASE}${ZSTD_STATIC_LIB_SUFFIX}")
endif()

# First, find via if specified ZSTD_ROOT
if(ZSTD_ROOT)
  message(STATUS "Using ZSTD_ROOT: ${ZSTD_ROOT}")
  find_library(ZSTD_LIB
               NAMES ${ZSTD_LIB_NAMES}
               PATHS ${ZSTD_ROOT}
               PATH_SUFFIXES ${ARROW_LIBRARY_PATH_SUFFIXES}
               NO_DEFAULT_PATH)
  find_path(ZSTD_INCLUDE_DIR
            NAMES zstd.h
            PATHS ${ZSTD_ROOT}
            NO_DEFAULT_PATH
            PATH_SUFFIXES ${ARROW_INCLUDE_PATH_SUFFIXES})

else()
  # Second, find via pkg_check_modules
  find_package(PkgConfig QUIET)
  pkg_check_modules(ZSTD_PC libzstd)
  if(ZSTD_PC_FOUND)
    set(ZSTD_INCLUDE_DIR "${ZSTD_PC_INCLUDEDIR}")

    list(APPEND ZSTD_PC_LIBRARY_DIRS "${ZSTD_PC_LIBDIR}")
    find_library(ZSTD_LIB
                 NAMES ${ZSTD_LIB_NAMES}
                 PATHS ${ZSTD_PC_LIBRARY_DIRS}
                 NO_DEFAULT_PATH
                 PATH_SUFFIXES ${ARROW_LIBRARY_PATH_SUFFIXES})
  else()
    # Third, check all other CMake paths
    find_library(ZSTD_LIB
                 NAMES ${ZSTD_LIB_NAMES}
                 PATH_SUFFIXES ${ARROW_LIBRARY_PATH_SUFFIXES})
    find_path(ZSTD_INCLUDE_DIR
              NAMES zstd.h
              PATH_SUFFIXES ${ARROW_INCLUDE_PATH_SUFFIXES})
  endif()
endif()

find_package_handle_standard_args(zstd REQUIRED_VARS ZSTD_LIB ZSTD_INCLUDE_DIR)

if(zstd_FOUND)
  add_library(zstd::libzstd UNKNOWN IMPORTED)
  set_target_properties(zstd::libzstd
                        PROPERTIES IMPORTED_LOCATION "${ZSTD_LIB}"
                                   INTERFACE_INCLUDE_DIRECTORIES "${ZSTD_INCLUDE_DIR}")
endif()
