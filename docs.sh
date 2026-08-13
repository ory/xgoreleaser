#!/bin/bash

set -euxo pipefail

if [[ $(git describe --tags) == *"pre"* ]]; then
  echo "This is a pre-release, skipping docs publishing."
  exit 0
fi

ory_ci_ref="99c3afad6f2bcb8e8f557fd1abe9d0044e884b69"
ory_ci_git_sha256="2eb76c21de45243ca68b9a94de6cd90bd48b9d2aa57cf39300e0d1539c6ccbb4"
ory_ci_git_script="$(mktemp)"
trap 'rm -f "${ory_ci_git_script}"' EXIT

curl --fail --location --silent --show-error \
  "https://raw.githubusercontent.com/ory/ci/${ory_ci_ref}/src/scripts/install/git.sh" \
  --output "${ory_ci_git_script}"

if command -v sha256sum >/dev/null 2>&1; then
  printf '%s  %s\n' "${ory_ci_git_sha256}" "${ory_ci_git_script}" | sha256sum --check -
elif command -v shasum >/dev/null 2>&1; then
  printf '%s  %s\n' "${ory_ci_git_sha256}" "${ory_ci_git_script}" | shasum -a 256 --check -
else
  echo "Unable to verify ory/ci helper: no SHA-256 utility found." >&2
  exit 1
fi

bash "${ory_ci_git_script}"

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
