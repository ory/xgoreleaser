# oryd/xgoreleaser

This image is published as [oryd/xgoreleaser](https://hub.docker.com/repository/docker/oryd/xgoreleaser). It's tag (e.g. 1.13.5) reflects the Golang version used.
This is a fork of [docker/golang-cross](https://github.com/docker/golang-cross).

To build this image, run locally:

```shell script
docker build -t oryd/xgoreleaser:1.14.2-0.131.1 .
docker push oryd/xgoreleaser:1.14.2-0.131.1
```

To build this image using the CI, create a new release with the desired Golang version
