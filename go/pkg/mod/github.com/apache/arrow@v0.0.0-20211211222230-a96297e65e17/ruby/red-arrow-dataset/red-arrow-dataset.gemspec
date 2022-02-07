# -*- ruby -*-
#
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

require_relative "lib/arrow-dataset/version"

Gem::Specification.new do |spec|
  spec.name = "red-arrow-dataset"
  version_components = [
    ArrowDataset::Version::MAJOR.to_s,
    ArrowDataset::Version::MINOR.to_s,
    ArrowDataset::Version::MICRO.to_s,
    ArrowDataset::Version::TAG,
  ]
  spec.version = version_components.compact.join(".")
  spec.homepage = "https://arrow.apache.org/"
  spec.authors = ["Apache Arrow Developers"]
  spec.email = ["dev@arrow.apache.org"]

  spec.summary = "Red Arrow Dataset is the Ruby bindings of Apache Arrow Dataset"
  spec.description =
    "Apache Arrow Dataset is one of Apache Arrow components to read and write " +
    "semantic datasets stored in different locations and formats."
  spec.license = "Apache-2.0"
  spec.files = ["README.md", "Rakefile", "Gemfile", "#{spec.name}.gemspec"]
  spec.files += ["LICENSE.txt", "NOTICE.txt"]
  spec.files += Dir.glob("lib/**/*.rb")
  spec.test_files += Dir.glob("test/**/*")
  spec.extensions = ["dependency-check/Rakefile"]

  spec.add_runtime_dependency("red-arrow", "= #{spec.version}")

  spec.add_development_dependency("bundler")
  spec.add_development_dependency("rake")
  spec.add_development_dependency("test-unit")
end
