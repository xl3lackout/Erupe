<!---
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
-->

# Java Plasma Client

## Setup Build Environment

Install:
 - java 8 or later
 - maven 3.3 or later
 - the same requirement of build [Arrow C++](https://github.com/apache/arrow/tree/master/cpp)

## Build the jar of plasma client

```
cd ..
mvn clean install -pl plasma -am -Dmaven.test.skip
```

## Building and running tests
```
./test.sh
```
