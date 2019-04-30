# Multistage docker build, requires docker 17.05

# builder stage
FROM ubuntu:16.04 as blockchain

RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install \
        ca-certificates \
        cmake \
        g++ \
        make \
        pkg-config \
        graphviz \
        doxygen \
        git \
        curl \
        libtool-bin \
        autoconf \
        automake \
        bzip2 \
        xsltproc \
        gperf \
        unzip

WORKDIR /usr/local

#Cmake
ARG CMAKE_VERSION=3.13.0
ARG CMAKE_VERSION_DOT=v3.13
ARG CMAKE_HASH=4058b2f1a53c026564e8936698d56c3b352d90df067b195cb749a97a3d273c90 
RUN set -ex \
    && curl -s -O https://cmake.org/files/${CMAKE_VERSION_DOT}/cmake-${CMAKE_VERSION}.tar.gz \
    && echo "${CMAKE_HASH}  cmake-${CMAKE_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf cmake-${CMAKE_VERSION}.tar.gz \
    && cd cmake-${CMAKE_VERSION} \
    && ./configure \
    && make \
    && make install

## Boost
ARG BOOST_VERSION=1_68_0
ARG BOOST_VERSION_DOT=1.68.0
ARG BOOST_HASH=7f6130bc3cf65f56a618888ce9d5ea704fa10b462be126ad053e80e553d6d8b7
RUN set -ex \
    && curl -s -L -o  boost_${BOOST_VERSION}.tar.bz2 https://dl.bintray.com/boostorg/release/${BOOST_VERSION_DOT}/source/boost_${BOOST_VERSION}.tar.bz2 \
    && echo "${BOOST_HASH}  boost_${BOOST_VERSION}.tar.bz2" | sha256sum -c \
    && tar -xvf boost_${BOOST_VERSION}.tar.bz2 \
    && cd boost_${BOOST_VERSION} \
    && ./bootstrap.sh \
    && ./b2 --build-type=minimal link=static runtime-link=static --with-chrono --with-date_time --with-filesystem --with-program_options --with-regex --with-serialization --with-system --with-thread --with-locale threading=multi threadapi=pthread cflags="-fPIC" cxxflags="-fPIC" stage
ENV BOOST_ROOT /usr/local/boost_${BOOST_VERSION}

# OpenSSL
ARG OPENSSL_VERSION=1.1.0j
ARG OPENSSL_HASH=31bec6c203ce1a8e93d5994f4ed304c63ccf07676118b6634edded12ad1b3246
RUN set -ex \
    && curl -s -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz \
    && echo "${OPENSSL_HASH}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf openssl-${OPENSSL_VERSION}.tar.gz \
    && cd openssl-${OPENSSL_VERSION} \
    && ./Configure linux-x86_64 no-shared --static -fPIC \
    && make build_generated \
    && make libcrypto.a \
    && make install
ENV OPENSSL_ROOT_DIR=/usr/local/openssl-${OPENSSL_VERSION}

# ZMQ
ARG ZMQ_VERSION=v4.2.5
ARG ZMQ_HASH=d062edd8c142384792955796329baf1e5a3377cd
RUN set -ex \
    && git clone https://github.com/zeromq/libzmq.git -b ${ZMQ_VERSION} --depth=1 \
    && cd libzmq \
    && test `git rev-parse HEAD` = ${ZMQ_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install \
    && ldconfig

# ncurses
ARG NCURSES_VERSION=6.1
ARG READLINE_HASH=750d437185286f40a369e1e4f4764eda932b9459b5ec9a731628393dd3d32334
RUN set -ex \
    && curl -s -O ftp://ftp.invisible-island.net/ncurses/ncurses-6.1.tar.gz \
    && tar -xzf ncurses-${NCURSES_VERSION}.tar.gz \
    && cd ncurses-${NCURSES_VERSION} \
    && CFLAGS="-fPIC" CXXFLAGS="-P -fPIC" ./configure --enable-termcap --with-termlib \
    && make \
    && make install

# zmq.hpp
ARG CPPZMQ_VERSION=v4.3.0
ARG CPPZMQ_HASH=213da0b04ae3b4d846c9abc46bab87f86bfb9cf4
RUN set -ex \
    && git clone https://github.com/zeromq/cppzmq.git -b ${CPPZMQ_VERSION} --depth=1 \
    && cd cppzmq \
    && test `git rev-parse HEAD` = ${CPPZMQ_HASH} || exit 1 \
    && mv *.hpp /usr/local/include

# Readline
ARG READLINE_VERSION=7.0
ARG READLINE_HASH=750d437185286f40a369e1e4f4764eda932b9459b5ec9a731628393dd3d32334
RUN set -ex \
    && curl -s -O https://ftp.gnu.org/gnu/readline/readline-${READLINE_VERSION}.tar.gz \
    && echo "${READLINE_HASH}  readline-${READLINE_VERSION}.tar.gz" | sha256sum -c \
    && tar -xzf readline-${READLINE_VERSION}.tar.gz \
    && cd readline-${READLINE_VERSION} \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
    && make \
    && make install

# Sodium
ARG SODIUM_VERSION=1.0.16
ARG SODIUM_HASH=675149b9b8b66ff44152553fb3ebf9858128363d
RUN set -ex \
    && git clone https://github.com/jedisct1/libsodium.git -b ${SODIUM_VERSION} --depth=1 \
    && cd libsodium \
    && test `git rev-parse HEAD` = ${SODIUM_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure \
    && make \
    && make check \
    && make install

# Udev
ARG UDEV_VERSION=v3.2.6
ARG UDEV_HASH=0c35b136c08d64064efa55087c54364608e65ed6
RUN set -ex \
    && git clone https://github.com/gentoo/eudev -b ${UDEV_VERSION} \
    && cd eudev \
    && test `git rev-parse HEAD` = ${UDEV_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --disable-gudev --disable-introspection --disable-hwdb --disable-manpages --disable-shared \
    && make \
    && make install

# Libusb
ARG USB_VERSION=v1.0.22
ARG USB_HASH=0034b2afdcdb1614e78edaa2a9e22d5936aeae5d
RUN set -ex \
    && git clone https://github.com/libusb/libusb.git -b ${USB_VERSION} \
    && cd libusb \
    && test `git rev-parse HEAD` = ${USB_HASH} || exit 1 \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --disable-shared \
    && make \
    && make install

# Hidapi
ARG HIDAPI_VERSION=hidapi-0.8.0-rc1
ARG HIDAPI_HASH=40cf516139b5b61e30d9403a48db23d8f915f52c
RUN set -ex \
    && git clone https://github.com/signal11/hidapi -b ${HIDAPI_VERSION} \
    && cd hidapi \
    && test `git rev-parse HEAD` = ${HIDAPI_HASH} || exit 1 \
    && ./bootstrap \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install

# Protobuf
ARG PROTOBUF_VERSION=v3.6.1
ARG PROTOBUF_HASH=48cb18e5c419ddd23d9badcfe4e9df7bde1979b2
RUN set -ex \
    && git clone https://github.com/protocolbuffers/protobuf -b ${PROTOBUF_VERSION} \
    && cd protobuf \
    && test `git rev-parse HEAD` = ${PROTOBUF_HASH} || exit 1 \
    && git submodule update --init --recursive \
    && ./autogen.sh \
    && CFLAGS="-fPIC" CXXFLAGS="-fPIC" ./configure --enable-static --disable-shared \
    && make \
    && make install \
    && ldconfig

WORKDIR /src
COPY src/loki .

ENV USE_SINGLE_BUILDDIR=1
ARG NPROC
RUN set -ex && \
    git submodule init && git submodule update && \
    rm -rf build && \
    if [ -z "$NPROC" ] ; \
    then make -j$(nproc) release-static ; \
    else make -j$NPROC release-static ; \
    fi

# lokinet build
FROM alpine:latest as network

RUN apk update && \
    apk add build-base cmake git libcap-dev curl ninja bash binutils-gold

WORKDIR /src
COPY src/loki-network /src/

RUN make NINJA=ninja STATIC_LINK=ON BUILD_TYPE=Release
RUN ./lokinet-bootstrap

# storage server build
#FROM alpine:latest as storage
FROM ubuntu:latest as storage

#RUN apk update && apk add build-essential git cmake libssl-dev libsodium-dev wget pkg-config
RUN apt update && apt install -y build-essential git cmake libssl-dev libsodium-dev wget pkg-config
WORKDIR /src

COPY src/loki-storage-server/install-deps-linux.sh install-deps-linux.sh
RUN ./install-deps-linux.sh
COPY src/loki-storage-server .
RUN mkdir -p build && cd build && sodium_LIBRARY_RELEASE="deps/sodium/lib" cmake .. -DBOOST_ROOT="/src/deps/boost" -DOPENSSL_ROOT_DIR="/usr/include/openssl/" && cmake --build .
#RUN find . -name httpserver

#CMD ["build/httpserver", "127.0.0.1", "3000"]
#EXPOSE 3000

# runtime stage
FROM ubuntu:latest
RUN set -ex && \
    apt-get update && \
    apt-get --no-install-recommends --yes install ca-certificates curl && \
    apt-get clean && \
    rm -rf /var/lib/apt
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash - && apt-get install -y nodejs

WORKDIR /usr/src/app
RUN mkdir bin
COPY --from=blockchain /src/build/release/bin/lokid bin/lokid
#COPY lokinet-docker.ini /root/.lokinet/lokinet.ini
COPY --from=network /src/build/lokinet bin/lokinet
#COPY --from=network /root/.lokinet/bootstrap.signed /root/.lokinet/
COPY --from=storage /src/build/httpserver/httpserver bin/httpserver
COPY daemon.js .
COPY ini.js .
COPY lib.js .
COPY lokinet.js .
COPY index.js .
COPY launcher-docker.ini launcher.ini

EXPOSE 22022 22023 22024 1090/udp 1190 38154 38155 38157 38158
CMD ["node", "index.js"]