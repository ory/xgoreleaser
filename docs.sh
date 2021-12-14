#!/bin/bash

if [[ $(git describe --tags) == *"pre"* ]]; then
  echo "This is a pre-release, skipping docs publishing."
  exit 0
fi

bash <(curl -s https://raw.githubusercontent.com/ory/ci/master/src/scripts/install/git.sh)

(cd docs; npm i)

node "./docs/scripts/docker-tag.js" "docs/config.js" "${TAG_VERSION}"
node "./docs/scripts/rerelease.js" "v${DOCS_VERSION}"
rm -rf "./docs/versioned_docs/version-v${DOCS_VERSION}"

(cd docs; npm run docusaurus docs:version "v${DOCS_VERSION}")
(cd docs; npm run format)

git add -A
git stash || true
git checkout master || true
git pull -ff || true
git stash pop || true
git commit --allow-empty -a -m "autogen(docs): generate and bump docs" || true
git push origin HEAD:master || true
