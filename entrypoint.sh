#!/usr/bin/env bash

if [ -n $DOCKER_USERNAME ] && [ -n $DOCKER_PASSWORD ]; then
    ecoh "Logging in to Docker"
    docker login -u $DOCKER_USERNAME -p $DOCKER_PASSWORD
fi

goreleaser $@
