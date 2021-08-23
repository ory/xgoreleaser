ARG GO_VERSION=1.17

# OS-X SDK parameters
# NOTE: when changing version here, make sure to also change OSX_CODENAME below to match
ARG OSX_SDK=MacOSX11.3.sdk

# To get the SHA sum do:
# wget https://s3.dockerproject.org/darwin/v2/${OSX_SDK}.tar.xz
#
# We no longer use this.
#
# ARG OSX_SDK_SUM=694a66095a3514328e970b14978dc78c0f4d170e590fa7b2c3d3674b75f0b713

# OSX-cross parameters. Go 1.15 requires OSX >= 10.11
ARG OSX_VERSION_MIN=11.3
# Choose latest commit from here: https://github.com/tpoechtrager/osxcross/commits/master/CHANGELOG
ARG OSX_CROSS_COMMIT=3351f5573c5c3f38a28a82df1ae09cad6d70f83d

# Libtool parameters
ARG LIBTOOL_VERSION=2.4.6_4
# Use ouput from:
#
# brew reinstall libtool --verbose --debug | grep curl
#
# You may wnant to clean the homebrew cache first.
ARG LIBTOOL_SHA=dfb94265706b7204b346e3e5d48e149d7c7870063740f0c4ab2d6ec971260517
ARG OSX_CODENAME=big_sur

FROM golang:${GO_VERSION}-buster AS base
ARG APT_MIRROR
RUN sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list
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
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    clang \
    file \
    llvm \
    patch \
    xz-utils \
    cmake make libssl-dev lzma-dev libxml2-dev \
    gcc g++ zlib1g-dev libmpc-dev libmpfr-dev libgmp-dev \
 && rm -rf /var/lib/apt/lists/*

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
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    libltdl-dev \
    gcc-mingw-w64 \
    musl-tools \
    parallel \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common \
    gettext \
    jq \
 && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
RUN add-apt-repository \
       "deb [arch=amd64] https://download.docker.com/linux/debian \
       $(lsb_release -cs) \
       stable"
RUN apt-get update -qq && apt-get  -y -q --no-install-recommends install docker-ce docker-ce-cli containerd.io
RUN curl -sL https://deb.nodesource.com/setup_14.x | bash -s
RUN apt install nodejs

ARG GORELEASER_VERSION=0.175.0
ARG GORELEASER_DOWNLOAD_FILE=goreleaser_Linux_x86_64.tar.gz
ARG GORELEASER_DOWNLOAD_URL=https://github.com/goreleaser/goreleaser/releases/download/v${GORELEASER_VERSION}/${GORELEASER_DOWNLOAD_FILE}

RUN wget ${GORELEASER_DOWNLOAD_URL}; \
			tar -xzf $GORELEASER_DOWNLOAD_FILE -C /usr/bin/ goreleaser; \
			rm $GORELEASER_DOWNLOAD_FILE;

COPY --from=osx-cross "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
COPY --from=libtool   "${OSX_CROSS_PATH}/." "${OSX_CROSS_PATH}/"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH

VOLUME /project
WORKDIR /project

ENTRYPOINT ["goreleaser"]
CMD ["-v"]
