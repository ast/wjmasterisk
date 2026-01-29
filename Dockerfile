# Copyright Albin SM6WJM 2026

# Build the latest Asterisk on Debian 13 (Trixie)
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    ASTERISK_USER=asterisk \
    ASTERISK_GROUP=asterisk

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates git build-essential pkg-config  curl wget \
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
    libsox-fmt-all \
    && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Checkout the newest non-RC tag (e.g., 22.5.2, 21.10.0, 20.16.0, etc.)
WORKDIR /usr/src

RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-23.2.0.tar.gz && \
    tar xzf asterisk-23.2.0.tar.gz && \
    cd asterisk-23.2.0 && \
    ./configure  --with-pjproject-bundled --with-jansson-bundled && \
    make -j$(nproc) && make install

# Create runtime user with specific UID:GID = 1000:1000
RUN groupadd -g 1000 asterisk && \
    useradd -u 1000 -g 1000 -r -m -s /bin/bash asterisk && \
    chown -R asterisk:asterisk /etc/asterisk

# Common SIP/RTP ports (adjust as needed)
EXPOSE 5060/udp 5060/tcp 5061/tcp 10010-10010/udp

RUN chown -R asterisk:asterisk /var/lib/asterisk \
    /var/spool/asterisk /var/log/asterisk /var/run/asterisk

USER asterisk

# Asterisk installs under /usr/sbin by default per project docs
# Run in foreground with some verbosity
CMD ["/usr/sbin/asterisk", "-cvvv"]

# TODO: Convert into multistage build with smaller final image

# drop into bash for debugging
#CMD ["/bin/bash"]
