# oryd/xgoreleaser

This image is published as [oryd/xgoreleaser](https://hub.docker.com/repository/docker/oryd/xgoreleaser). It's tag (e.g. 1.13.5) reflects the Golang version used.
This is a fork of [docker/golang-cross](https://github.com/docker/golang-cross).

To build this image, run locally:

```shell script
tag=1.14.4-0.139.0
docker build -t oryd/xgoreleaser:${tag} .
docker push oryd/xgoreleaser:${tag}
```

To build this image using the CI, create a new release with the desired Golang version.

```
docker run --mount type=bind,source="$(pwd)",target=/project \
    oryd/xgoreleaser:1.14.4-0.139.0 --skip-publish --snapshot --rm-dist
```

```
docker run --entrypoint /bin/bash -it oryd/xgoreleaser:1.14.4-0.139.0
```
