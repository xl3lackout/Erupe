#!/usr/bin/env bash
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

set -e
set -u

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARROW_DIR="${SOURCE_DIR}/../.."
ARROW_SITE_DIR="${ARROW_DIR}/../arrow-site"

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

version=$1
release_tag="apache-arrow-${version}"
branch_name=release-docs-${version}

pushd "${ARROW_SITE_DIR}"
git fetch --all --prune --tags --force -j$(nproc)
git checkout .
git checkout master
git clean -d -f -x
git branch -D asf-site || :
git checkout -b asf-site origin/asf-site
git rebase apache/asf-site
git branch -D ${branch_name} || :
git checkout -b ${branch_name}
versioned_paths=()
for versioned_path in docs/*.0/; do
  versioned_paths+=(${versioned_path})
done
rm -rf docs/*
git checkout "${versioned_paths[@]}"
curl \
  --fail \
  --location \
  --remote-name \
  https://apache.jfrog.io/artifactory/arrow/docs/${version}/docs.tar.gz
tar xvf docs.tar.gz
rm -f docs.tar.gz
git checkout docs/c_glib/index.html
git add docs
git commit -m "[Website] Update documentations for ${version}"
popd

: ${PUSH:=1}

if [ ${PUSH} -gt 0 ]; then
  pushd "${ARROW_SITE_DIR}"
  git push -u origin ${branch_name}
  github_url=$(git remote get-url origin | \
                 sed \
                   -e 's,^git@github.com:,https://github.com/,' \
                   -e 's,\.git$,,')
  popd

  echo "Success!"
  echo "Create a pull request:"
  echo "  ${github_url}/pull/new/${branch_name}"
fi
