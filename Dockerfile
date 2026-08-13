ARG GO_VERSION=1.25.2

# OS-X SDK parameters
# NOTE: when changing version here, make sure to also change OSX_CODENAME below to match
ARG OSX_SDK=MacOSX15.0.sdk

# To get the SHA sum do:8056533314010954413
# wget https://s3.dockerproject.org/darwin/v2/${OSX_SDK}.tar.xz
#
# We no longer use this.
#
# ARG OSX_SDK_SUM=694a66095a3514328e970b14978dc78c0f4d170e590fa7b2c3d3674b75f0b713

# OSX-cross parameters. Go 1.15 requires OSX >= 10.11
ARG OSX_VERSION_MIN=12.7
# Choose latest commit from here: https://github.com/tpoechtrager/osxcross/commits/master/CHANGELOG
ARG OSX_CROSS_COMMIT=f873f534c6cdb0776e457af8c7513da1e02abe59

# Libtool parameters
ARG LIBTOOL_VERSION=2.4.6_4
# Use ouput from:
#
# brew reinstall libtool --verbose --debug | grep curl
#
# You may wnant to clean the homebrew cache first.
ARG LIBTOOL_SHA=dfb94265706b7204b346e3e5d48e149d7c7870063740f0c4ab2d6ec971260517
ARG OSX_CODENAME=big_sur

FROM golang:${GO_VERSION}-trixie AS base
ENV OSX_CROSS_PATH=/osxcross

FROM base AS osx-sdk
ARG OSX_SDK
# ARG OSX_SDK_SUM
# This is generated from: https://github.com/tpoechtrager/osxcross#packaging-the-sdk
ADD https://storage.googleapis.com/ory.sh/build-assets/${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"
#RUN echo "${OSX_SDK_SUM}"  "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c -

FROM base AS osx-cross-base
ARG DEBIAN_FRONTEND=noninteractive
# Dependencies for https://github.com/tpoechtrager/osxcross:
# TODO split these into "build-time" and "runtime" dependencies so that build-time deps do not end up in the final image
RUN apt-get update -qq
RUN apt-get install -y -q --no-install-recommends \
    clang \
    file \
    llvm \
    patch \
    xz-utils \
    cmake make libssl-dev libxml2-dev \
    gcc g++ zlib1g-dev libmpc-dev libmpfr-dev libgmp-dev
RUN rm -rf /var/lib/apt/lists/*

FROM osx-cross-base AS osx-cross
ARG OSX_CROSS_COMMIT
WORKDIR "${OSX_CROSS_PATH}"
RUN git clone https://github.com/tpoechtrager/osxcross.git . \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && rm -rf ./.git
COPY --from=osx-sdk "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ARG OSX_VERSION_MIN
RUN UNATTENDED=yes OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM base AS libtool
ARG LIBTOOL_VERSION
ARG LIBTOOL_SHA
ARG OSX_CODENAME
ARG OSX_SDK
RUN mkdir -p "${OSX_CROSS_PATH}/target/SDK/${OSX_SDK}/usr/"

RUN curl -L --globoff --show-error --user-agent Homebrew/3.2.9\ \(Macintosh\;\ Intel\ Mac\ OS\ X\ 11.5.1\)\ curl/7.64.1 --header Accept-Language:\ en --retry 3 --header Authorization:\ Bearer\ QQ== --location --silent --request GET https://ghcr.io/v2/homebrew/core/libtool/blobs/sha256:${LIBTOOL_SHA} --output - \
	| gzip -dc | tar xf - \
		-C "${OSX_CROSS_PATH}/target/SDK/${OSX_SDK}/usr/" \
		--strip-components=2 \
		"libtool/${LIBTOOL_VERSION}/include/" \
		"libtool/${LIBTOOL_VERSION}/lib/"

FROM osx-cross-base AS final
ARG DEBIAN_FRONTEND=noninteractive

RUN curl -fsSL test.docker.com -o get-docker.sh && sh get-docker.sh
RUN curl -sL https://deb.nodesource.com/setup_21.x | bash -s
RUN apt-get update -y
RUN apt-get upgrade -y
RUN apt-get install -y --no-install-recommends \
    libltdl-dev \
    gcc-mingw-w64 \
    parallel \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    gettext \
    jq \
    nodejs \
    build-essential \
    docker-ce docker-ce-cli containerd.io \
    gcc cpp binutils \
    musl-tools
RUN apt-get update -y
RUN apt-get install -y \
    gcc-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf
RUN rm -rf /var/lib/apt/lists/*

ARG GORELEASER_VERSION=2.12.5
ARG TARGETARCH

RUN case "${TARGETARCH}" in \
        amd64) GR_ARCH=x86_64 ;; \
        arm64) GR_ARCH=arm64 ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac \
    && curl -LO https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/goreleaser_Linux_${GR_ARCH}.tar.gz \
    && mkdir -p goreleaser_Linux_${GR_ARCH} \
    && tar -xvf goreleaser_Linux_${GR_ARCH}.tar.gz -C goreleaser_Linux_${GR_ARCH} \
    && mv goreleaser_Linux_${GR_ARCH}/goreleaser /usr/local/bin/goreleaser-oss \
    && rm -rf goreleaser_Linux_${GR_ARCH}.* goreleaser_Linux_${GR_ARCH}/

RUN case "${TARGETARCH}" in \
        amd64) GR_ARCH=x86_64 ;; \
        arm64) GR_ARCH=arm64 ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac \
    && curl -Lo "goreleaser-pro_Linux_${GR_ARCH}.tar.gz" "https://github.com/goreleaser/goreleaser-pro/releases/download/v${GORELEASER_VERSION}/goreleaser-pro_Linux_${GR_ARCH}.tar.gz" \
    && mkdir -p goreleaser-pro_Linux_${GR_ARCH} \
    && tar -xvf goreleaser-pro_Linux_${GR_ARCH}.tar.gz -C goreleaser-pro_Linux_${GR_ARCH} \
    && mv goreleaser-pro_Linux_${GR_ARCH}/goreleaser /usr/local/bin/goreleaser \
    && rm -rf goreleaser-pro_Linux_${GR_ARCH}.* goreleaser-pro_Linux_${GR_ARCH}/

RUN goreleaser --version && goreleaser-oss --version

RUN go install github.com/sigstore/cosign/cmd/cosign@v1.3.0
RUN go install github.com/CycloneDX/cyclonedx-gomod@v1.0.0

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
COPY --from=libtool   "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH

# musl.cc toolchain checksums
# aarch64-linux-musl-cross  (x86_64-hosted, targets aarch64) — used on amd64 build hosts
ENV AARCH64_CROSS_SUM=8695ff86979cdf30fbbcd33061711f5b1ebc3c48a87822b9ca56cde6d3a22abd4dab30fdcd1789ac27c6febbaeb9e5bde59d79d66552fae53d54cc1377a19272
# aarch64-linux-musl-native  (aarch64-hosted, targets aarch64) — used on arm64 build hosts
ENV AARCH64_NATIVE_SUM=16d544e09845c9dbba50f29e0cb04dd661e17eb63c56acad6a67fd2a78aa7596b792477c7177d3cd56d408a27dc291a90507df882f2b099c0f25511ce08fd3b5
# arm-linux-musleabihf-cross (x86_64-hosted, targets armhf)  — only available for amd64 build hosts
ENV ARMSUM=fe006d9176cedb453fd817f892f61f6bac273c15879f9c537e22c75b8da4995991211f6d23b0c0c97a87121fe55cf9f9f29cc3d1cf9376804535f07b6c017729
# x86_64-linux-musl-cross (x86_64-hosted, targets x86_64 musl) — sysroot extracted for arm64 build hosts
ENV X86_64_MUSL_CROSS_SUM=52abd1a56e670952116e35d1a62e048a9b6160471d988e16fa0e1611923dd108a581d2e00874af5eb04e4968b1ba32e0eb449a1f15c3e4d5240ebe09caf5a9f3

# Install musl cross-compilation toolchains.
# On amd64: aarch64-linux-musl-cross (cross) + arm-linux-musleabihf-cross (cross)
#           x86_64-linux-musl-gcc -> musl-gcc symlink (musl-tools already provides the sysroot)
# On arm64: aarch64-linux-musl-native (native, same-arch)
#           x86_64-linux-musl-cross sysroot extracted (crt files + libc; these are x86_64 target
#           files, not host executables, so no QEMU needed) + gcc-x86-64-linux-gnu as compiler
RUN case "${TARGETARCH}" in \
        amd64) \
            curl -LO https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/aarch64-linux-musl-cross.tgz \
            && echo "$AARCH64_CROSS_SUM  aarch64-linux-musl-cross.tgz" > aarch64.sum \
            && sha512sum -c aarch64.sum \
            && tar xzf aarch64-linux-musl-cross.tgz \
            && mv aarch64-linux-musl-cross /aarch64-linux-musl-cross \
            && rm aarch64-linux-musl-cross.tgz aarch64.sum \
            && curl -LO https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/arm-linux-musleabihf-cross.tgz \
            && echo "$ARMSUM  arm-linux-musleabihf-cross.tgz" > arm.sum \
            && sha512sum -c arm.sum \
            && tar xzf arm-linux-musleabihf-cross.tgz \
            && mv arm-linux-musleabihf-cross /arm-linux-musleabihf-cross \
            && rm arm-linux-musleabihf-cross.tgz arm.sum \
            && ln -sf /usr/bin/musl-gcc /usr/local/bin/x86_64-linux-musl-gcc \
            ;; \
        arm64) \
            curl -LO https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/aarch64-linux-musl-native.tgz \
            && echo "$AARCH64_NATIVE_SUM  aarch64-linux-musl-native.tgz" > aarch64.sum \
            && sha512sum -c aarch64.sum \
            && tar xzf aarch64-linux-musl-native.tgz \
            && mv aarch64-linux-musl-native /aarch64-linux-musl-cross \
            && rm aarch64-linux-musl-native.tgz aarch64.sum \
            && curl -LO https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/x86_64-linux-musl-cross.tgz \
            && echo "$X86_64_MUSL_CROSS_SUM  x86_64-linux-musl-cross.tgz" > x86_64.sum \
            && sha512sum -c x86_64.sum \
            && tar xzf x86_64-linux-musl-cross.tgz \
            && mv x86_64-linux-musl-cross/x86_64-linux-musl /x86_64-linux-musl \
            && rm -rf x86_64-linux-musl-cross.tgz x86_64.sum x86_64-linux-musl-cross \
            && curl -LO https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/arm-linux-musleabihf-cross.tgz \
            && echo "$ARMSUM  arm-linux-musleabihf-cross.tgz" > arm.sum \
            && sha512sum -c arm.sum \
            && tar xzf arm-linux-musleabihf-cross.tgz \
            && mv arm-linux-musleabihf-cross/arm-linux-musleabihf /arm-linux-musleabihf \
            && rm -rf arm-linux-musleabihf-cross.tgz arm.sum arm-linux-musleabihf-cross \
            && apt-get update -qq \
            && apt-get install -y --no-install-recommends gcc-x86-64-linux-gnu libc6-dev-amd64-cross \
            && rm -rf /var/lib/apt/lists/* \
            && printf '#!/bin/sh\nexec x86_64-linux-gnu-gcc -B/x86_64-linux-musl/lib -L/x86_64-linux-musl/lib -isystem /x86_64-linux-musl/include "$@"\n' \
               > /usr/local/bin/x86_64-linux-musl-gcc \
            && chmod +x /usr/local/bin/x86_64-linux-musl-gcc \
            && printf '#!/bin/sh\nexec arm-linux-gnueabihf-gcc -B/arm-linux-musleabihf/lib -L/arm-linux-musleabihf/lib -isystem /arm-linux-musleabihf/include "$@"\n' \
               > /usr/local/bin/arm-linux-musleabihf-gcc \
            && chmod +x /usr/local/bin/arm-linux-musleabihf-gcc \
            ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac

# Symlink only prefixed musl cross-compiler tools into /usr/local/bin to avoid
# unprefixed binaries (like `ld`) shadowing system tools and breaking glibc builds.
RUN for tool in /aarch64-linux-musl-cross/bin/aarch64-linux-musl-*; do \
        [ -e "$tool" ] && ln -sf "$tool" /usr/local/bin/$(basename "$tool"); \
    done \
    && for tool in /arm-linux-musleabihf-cross/bin/arm-linux-musleabihf-*; do \
        [ -e "$tool" ] && ln -sf "$tool" /usr/local/bin/$(basename "$tool"); \
    done 2>/dev/null || true

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
VOLUME /project
WORKDIR /project
RUN git config --global --add safe.directory /project

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-v"]
