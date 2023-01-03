#!/usr/bin/env bash

set -eo pipefail

if [ -z ${DOCKER_USERNAME+x} ] && [ -z ${DOCKER_PASSWORD+x} ]; then
    echo "Logging in to Docker"
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
fi

goreleaser $@
