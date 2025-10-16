# docker run --rm -it \
#   -p 5060:5060/udp \
#   -p 5060:5060/tcp \
#   -p 5061:5061/tcp \
#   -p 10000-20000:10000-20000/udp \
#   sm6wjm.se/asterisk:latest

# Mapping config

# docker run --rm -it \
#   -p 5060:5060/udp \
#   -p 5060:5060/tcp \
#   -p 5061:5061/tcp -p 10000-10005:10000-10005/udp \
#   sm6wjm.se/asterisk:latest


# docker build . -t sm6wjm.se/asterisk:latest

# etc-asterisk/

# asterisk -rvvvvv
# pjsip set logger on
# pjsip show registrations


# Build the latest Asterisk on Debian 13 (Trixie)
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive \
    ASTERISK_USER=asterisk \
    ASTERISK_GROUP=asterisk

# Base tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git build-essential pkg-config  curl wget \
    libncurses-dev \
    libnewt-dev \
    libcurl4-openssl-dev \
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
    #procps nano net-tools iproute2 \

# Checkout the newest non-RC tag (e.g., 22.5.2, 21.10.0, 20.16.0, etc.)
WORKDIR /usr/src

# Or download a specific version directly
# https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-23.0.0.tar.gz
# Shallow clone of latest master branch
#RUN git clone --depth 1 --branch master https://github.com/asterisk/asterisk.git

RUN wget https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-23.0.0.tar.gz && \
    tar xzf asterisk-23.0.0.tar.gz && \
    cd asterisk-23.0.0 && \
    ./configure  --with-pjproject-bundled --with-jansson-bundled && \
    make -j$(nproc) && make install

#WORKDIR /usr/src/asterisk

# Configure & build with bundled pjproject for predictable SIP stack
#RUN ./configure --with-pjproject-bundled --with-jansson-bundled
#RUN make menuselect.makeopts
#RUN make -j$(nproc) && make install && ldconfig

# Copy etc files to /etc/asterisk
COPY etc-asterisk /etc/asterisk

# Create runtime user
# RUN groupadd -r "${ASTERISK_GROUP}" && useradd -r -g "${ASTERISK_GROUP}" "${ASTERISK_USER}" \
#  && chown -R "${ASTERISK_USER}:${ASTERISK_GROUP}" \
#       /etc/asterisk /var/{lib,log,spool}/asterisk /usr/lib/asterisk || true

# Common SIP/RTP ports (adjust as needed)
EXPOSE 5060/udp 5060/tcp 5061/tcp 10000-20000/udp

# USER asterisk

# Asterisk installs under /usr/sbin by default per project docs
# Run in foreground with some verbosity
# CMD ["/usr/sbin/asterisk", "-fvvv"]

# drop into bash
CMD ["/bin/bash"]
