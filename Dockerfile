# Copyright Albin SM6WJM 2026
# syntax=docker/dockerfile:1

ARG DEBIAN_TAG=trixie-slim
ARG ASTERISK_VERSION=23.3.0

# ============================================================
# Stage 1: builder — compile Asterisk, stage install into /out
# ============================================================
FROM debian:${DEBIAN_TAG} AS builder

ARG ASTERISK_VERSION

ENV DEBIAN_FRONTEND=noninteractive

# Build deps (dev packages bring headers + static libs we only need to compile)
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates wget build-essential pkg-config \
    libncurses-dev \
    libnewt-dev \
    libcurl4-openssl-dev \
    libxslt1-dev \
    libedit-dev \
    libsrtp2-dev \
    libssl-dev \
    libogg-dev \
    libcodec2-dev \
    libgsm1-dev \
    libsqlite3-dev \
    libvorbis-dev \
    libsndfile1-dev \
    libspeex-dev \
    libspeexdsp-dev \
    libasound2-dev \
    libxml2-dev \
    liblua5.4-dev \
    libopus-dev \
    uuid-dev \
    libspandsp-dev \
    libsox-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
RUN wget -nv "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz" && \
    tar xzf "asterisk-${ASTERISK_VERSION}.tar.gz" && \
    rm "asterisk-${ASTERISK_VERSION}.tar.gz"

WORKDIR /usr/src/asterisk-${ASTERISK_VERSION}
RUN ./configure --with-pjproject-bundled --with-jansson-bundled && \
    make -j"$(nproc)" && \
    make DESTDIR=/out install && \
    # /var/run is a symlink to /run in the runtime image, so relocate the
    # asterisk runtime dir to /run/asterisk to keep the COPY merge happy.
    mkdir -p /out/run && \
    mv /out/var/run/asterisk /out/run/asterisk && \
    rmdir /out/var/run

# ============================================================
# Stage 2: runtime — slim image with shared libs + Asterisk
# ============================================================
FROM debian:${DEBIAN_TAG} AS runtime

ENV DEBIAN_FRONTEND=noninteractive

# Runtime shared libraries only — no toolchain, no headers, no static libs.
# Trixie uses t64-suffixed names for the 64-bit time_t transition.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates \
    libncursesw6 \
    libnewt0.52 \
    libcurl4t64 \
    libxslt1.1 \
    libedit2 \
    libsrtp2-1 \
    libssl3t64 \
    libogg0 \
    libcodec2-1.2 \
    libgsm1 \
    libsqlite3-0 \
    libvorbis0a libvorbisenc2 libvorbisfile3 \
    libsndfile1 \
    libspeex1 \
    libspeexdsp1 \
    libasound2t64 \
    libxml2 \
    liblua5.4-0 \
    libopus0 \
    libuuid1 \
    libspandsp2 \
    libsox3 \
    libsox-fmt-all \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Pull the compiled Asterisk in from the builder stage
COPY --from=builder /out/ /

# Create runtime user with specific UID:GID = 1000:1000
RUN groupadd -g 1000 asterisk && \
    useradd -u 1000 -g 1000 -r -m -s /bin/bash asterisk && \
    chown -R asterisk:asterisk \
        /etc/asterisk \
        /var/lib/asterisk \
        /var/spool/asterisk \
        /var/log/asterisk \
        /var/run/asterisk

# Common SIP/RTP ports (adjust as needed)
EXPOSE 5060/udp 5060/tcp 5061/tcp 10000-10010/udp

USER asterisk
WORKDIR /home/asterisk

CMD ["/usr/sbin/asterisk", "-cvvv"]
