FROM alpine:3.8

ARG LIBTORRENT_RELEASE_TAG=libtorrent-1_1_13
ARG QBITTORRENT_REPO_URL=https://github.com/qbittorrent/qBittorrent.git

# Install required packages
RUN apk add --no-cache \
        boost-system \
        boost-thread \
        ca-certificates \
        dumb-init \
        libressl \
        qt5-qtbase

# Compiling qBitTorrent following instructions on
#  
RUN set -x \
    # Install build dependencies
 && apk add --no-cache -t .build-deps \
        boost-dev \
        curl \
        cmake \
        g++ \
        make \
        libressl-dev \
    # Build lib rasterbar from source code (required by qBittorrent)
    # Until https://github.com/qbittorrent/qBittorrent/issues/6132 is fixed, need to use version 1.0.*
 && LIBTORRENT_RASTERBAR_URL=$(curl -sSL https://api.github.com/repos/arvidn/libtorrent/releases/tags/${LIBTORRENT_RELEASE_TAG} | grep browser_download_url  | grep libtorrent-rasterbar | head -n 1 | cut -d '"' -f 4) \
 && CPU_COUNT=$(nproc) \
 && mkdir /tmp/libtorrent-rasterbar \
 && curl -sSL $LIBTORRENT_RASTERBAR_URL | tar xzC /tmp/libtorrent-rasterbar \
 && cd /tmp/libtorrent-rasterbar/* \
 && mkdir build \
 && cd build \
 && cmake .. \
 && make install -j${CPU_COUNT} \
    # Clean-up
 && cd / \
 && apk del --purge .build-deps \
 && rm -rf /tmp/*

ENV LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH

RUN set -x \
    # Install build dependencies
 && apk add --no-cache -t .build-deps \
        boost-dev \
        g++ \
        git \
        make \
        libressl-dev \
        qt5-qttools-dev \
    # Build qBittorrent from source code
 && git clone ${QBITTORRENT_REPO_URL} /tmp/qbittorrent \
 && cd /tmp/qbittorrent \
    # Checkout latest release
 && latesttag=$(git describe --tags `git rev-list --tags --max-count=1`) \
 && git checkout $latesttag \
    # Compile
 && export PKG_CONFIG_PATH=/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH \
 && ./configure --disable-gui \
 && CPU_COUNT=$(nproc) \
 && make install -j${CPU_COUNT} \
    # Clean-up
 && cd / \
 && apk del --purge .build-deps \
 && rm -rf /tmp/* \
    # Add non-root user
 && adduser -S -D -u 520 -g 520 -s /sbin/nologin qbittorrent \
    # Create symbolic links to simplify mounting
 && mkdir -p /home/qbittorrent/.config/qBittorrent \
 && mkdir -p /home/qbittorrent/.local/share/data/qBittorrent \
 && mkdir /downloads \
 && chmod go+rw -R /home/qbittorrent /downloads \
 && ln -s /home/qbittorrent/.config/qBittorrent /config \
 && ln -s /home/qbittorrent/.local/share/data/qBittorrent /torrents \
    # Check it works
 && su qbittorrent -s /bin/sh -c 'qbittorrent-nox -v'

# Default configuration file.
COPY qBittorrent.conf /default/qBittorrent.conf
COPY entrypoint.sh /

VOLUME ["/config", "/torrents", "/downloads"]

ENV HOME=/home/qbittorrent

USER qbittorrent

EXPOSE 8080 6881

ENTRYPOINT ["dumb-init", "/entrypoint.sh"]
CMD ["qbittorrent-nox"]
