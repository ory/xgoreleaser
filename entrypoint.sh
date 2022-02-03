#!/usr/bin/env bash

set -euxo pipefail

if [ -n $DOCKER_USERNAME ] && [ -n $DOCKER_PASSWORD ]; then
    echo "Logging in to Docker"
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
fi

goreleaser $@
