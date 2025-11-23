# Runtime-only rtpengine (userspace) build for local testing
# Note: built for amd64; adjust build args if targeting a different arch.
FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    build-essential \
    pkg-config \
    libip4tc-dev \
    libip6tc-dev \
    libxtables-dev \
    libiptc-dev \
    libglib2.0-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libpcap-dev \
    libmnl-dev \
    libnftnl-dev \
    libwebsockets-dev \
    libhiredis-dev \
    libspandsp-dev \
    libpcre3-dev \
    libopus-dev \
    libncurses-dev \
    libevent-dev \
    libjson-glib-dev \
    libjwt-dev \
    default-libmysqlclient-dev \
    libbencode-perl \
    libcrypt-openssl-rsa-perl \
    libio-multiplex-perl \
    libsocket6-perl \
    libwww-perl \
    libdigest-hmac-perl \
    libclone-perl \
    libnet-interface-perl \
    libconfig-tiny-perl \
    libhash-flatten-perl \
    liblist-moreutils-perl \
    libipc-sharelite-perl \
    libxml-libxml-perl \
    libfilesys-df-perl \
    libsystemd-dev \
    gperf \
    libavcodec-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libswresample-dev \
    libswscale-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/sipwise/rtpengine.git /src/rtpengine

WORKDIR /src/rtpengine/daemon
RUN ln -s /bin/true /usr/local/bin/pandoc \
 && PANDOC=/usr/local/bin/pandoc make \
 && touch rtpengine.8 \
 && make install

RUN rm -rf /src/rtpengine

EXPOSE 22222/udp 40000-40015/udp

ENTRYPOINT ["/usr/bin/rtpengine"]
CMD ["--foreground", "--listen-ng=0.0.0.0:22222", "--log-level=6", "--interface=public/eth0", "--interface=webrtc/eth0", "--port-min=40000", "--port-max=40015"]
