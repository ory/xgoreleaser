ARG GO_VERSION=1.25.2

# OS-X SDK parameters
# NOTE: when changing version here, make sure to also change OSX_CODENAME below to match
ARG OSX_SDK=MacOSX11.3.sdk

# To get the SHA sum do:8056533314010954413
# wget https://s3.dockerproject.org/darwin/v2/${OSX_SDK}.tar.xz
#
# We no longer use this.
#
# ARG OSX_SDK_SUM=694a66095a3514328e970b14978dc78c0f4d170e590fa7b2c3d3674b75f0b713

# OSX-cross parameters. Go 1.15 requires OSX >= 10.11
ARG OSX_VERSION_MIN=11.3
# Choose latest commit from here: https://github.com/tpoechtrager/osxcross/commits/master/CHANGELOG
ARG OSX_CROSS_COMMIT=c0cb74c8c01a66be0b6d05788f05201d87d9df9f

# Libtool parameters
ARG LIBTOOL_VERSION=2.4.6_4
# Use ouput from:
#
# brew reinstall libtool --verbose --debug | grep curl
#
# You may wnant to clean the homebrew cache first.
ARG LIBTOOL_SHA=dfb94265706b7204b346e3e5d48e149d7c7870063740f0c4ab2d6ec971260517
ARG OSX_CODENAME=big_sur

FROM golang:${GO_VERSION}-bookworm AS base
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
    cmake make libssl-dev lzma-dev libxml2-dev \
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
    software-properties-common \
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

RUN curl -LO https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/goreleaser_Linux_x86_64.tar.gz \
    && mkdir -p goreleaser_Linux_x86_64 \
    && tar -xvf goreleaser_Linux_x86_64.tar.gz -C goreleaser_Linux_x86_64 \
    && mv goreleaser_Linux_x86_64/goreleaser /usr/local/bin/goreleaser-oss \
    && rm -rf goreleaser_Linux_x86_64.* goreleaser_Linux_x86_64/

RUN curl -Lo "goreleaser-pro_Linux_x86_64.tar.gz" "https://github.com/goreleaser/goreleaser-pro/releases/download/v${GORELEASER_VERSION}/goreleaser-pro_Linux_x86_64.tar.gz" \
    && mkdir -p goreleaser-pro_Linux_x86_64 \
    && tar -xvf goreleaser-pro_Linux_x86_64.tar.gz -C goreleaser-pro_Linux_x86_64 \
    && mv goreleaser-pro_Linux_x86_64/goreleaser /usr/local/bin/goreleaser \
    && rm -rf goreleaser-pro_Linux_x86_64.* goreleaser-pro_Linux_x86_64/

RUN goreleaser --version && goreleaser-oss --version

RUN go install github.com/sigstore/cosign/cmd/cosign@v1.3.0
RUN go install github.com/CycloneDX/cyclonedx-gomod@v1.0.0

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
COPY --from=libtool   "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH

RUN curl -O https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/aarch64-linux-musl-cross.tgz \
    && sha512 -c 8695ff86979cdf30fbbcd33061711f5b1ebc3c48a87822b9ca56cde6d3a22abd4dab30fdcd1789ac27c6febbaeb9e5bde59d79d66552fae53d54cc1377a19272 aarch64-linux-musl-cross.tgz \
    && tar xzf aarch64-linux-musl-cross.tgz \
    && mv aarch64-linux-musl-cross /aarch64-linux-musl-cross

RUN curl -O https://github.com/musl-cc/musl.cc/releases/download/v0.0.1/arm-linux-musleabihf-cross.tgz \
    && sha512 -c fe006d9176cedb453fd817f892f61f6bac273c15879f9c537e22c75b8da4995991211f6d23b0c0c97a87121fe55cf9f9f29cc3d1cf9376804535f07b6c017729 arm-linux-musleabihf-cross.tgz \
    && tar xzf arm-linux-musleabihf-cross.tgz \
    && mv arm-linux-musleabihf-cross /arm-linux-musleabihf-cross

ENV PATH=/aarch64-linux-musl-cross/bin:/arm-linux-musleabihf-cross/bin:$PATH

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
VOLUME /project
WORKDIR /project
RUN git config --global --add safe.directory /project

ENTRYPOINT ["/entrypoint.sh"]
CMD ["-v"]
