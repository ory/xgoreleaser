FROM alpine:3.12

RUN addgroup -S ory; \
    adduser -S ory -G ory -D -u 10000 -h /home/ory -s /bin/nologin; \
    chown -R ory:ory /home/ory

RUN apk add -U --no-cache ca-certificates

COPY xgoreleaser-test /usr/bin/xgoreleaser-test

USER 10000

ENTRYPOINT ["/usr/bin/xgoreleaser-test"]
