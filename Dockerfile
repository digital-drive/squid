# -------- BUILD STAGE --------
FROM debian:bookworm-slim AS build
ARG TARGETARCH

LABEL maintainer="Maxence Winandy <maxence.winandy@digital-drive.io>"

ARG SQUID_VERSION=6.14
ARG SQUID_TAG=SQUID_6_14
ARG SQUID_SHA256=cdc6b6c1ed519836bebc03ef3a6ed3935c411b1152920b18a2210731d96fdf67
ARG SQUID_CFLAGS="-march=x86-64 -mtune=generic"
ARG SQUID_LDFLAGS=""

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential pkg-config wget perl \
      libssl-dev libecap3-dev libdb-dev libexpat1-dev \
      libcppunit-dev libcap-dev ca-certificates\
 && rm -rf /var/lib/apt/lists/*

WORKDIR /var/cache/squid-build
RUN set -eux; \
    if [ "$TARGETARCH" = "amd64" ]; then \
        wget https://github.com/squid-cache/squid/releases/download/${SQUID_TAG}/squid-${SQUID_VERSION}.tar.bz2; \
        echo "${SQUID_SHA256}  squid-${SQUID_VERSION}.tar.bz2" > squid-${SQUID_VERSION}.tar.bz2.sha256; \
        sha256sum -c squid-${SQUID_VERSION}.tar.bz2.sha256; \
        tar xjf squid-${SQUID_VERSION}.tar.bz2; \
        cd squid-${SQUID_VERSION}; \
        CFLAGS="${SQUID_CFLAGS}" CXXFLAGS="${SQUID_CFLAGS}" LDFLAGS="${SQUID_LDFLAGS}" \
            ./configure --prefix=/usr \
                        --localstatedir=/var \
                        --libexecdir=/usr/lib/squid \
                        --enable-ssl \
                        --enable-ecap; \
        make -j$(nproc); \
        make install DESTDIR=/var/cache/squid-install; \
    else \
        mkdir -p /var/cache/squid-install/usr; \
    fi


# -------- RUNTIME STAGE --------
FROM debian:bookworm-slim
ARG TARGETARCH
ARG S6_VERSION=v3.2.1.0

LABEL maintainer="Maxence Winandy <maxence.winandy@digital-drive.io>"

RUN set -eux; \
    apt-get update; \
    pkg_list="libssl3 libecap3"; \
    if [ "$TARGETARCH" != "amd64" ]; then \
        pkg_list="$pkg_list squid"; \
    fi; \
    apt-get install -y --no-install-recommends $pkg_list; \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /var/cache/squid-install/usr /usr

RUN set -eux; \
    case "$TARGETARCH" in \
        amd64) S6_ARCH=amd64 ;; \
        arm64) S6_ARCH=aarch64 ;; \
        *) echo "unsupported TARGETARCH=$TARGETARCH"; exit 1 ;; \
    esac; \
    wget "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.gz" -O /tmp/s6-overlay.tar.gz; \
    tar xzf /tmp/s6-overlay.tar.gz -C /; \
    rm /tmp/s6-overlay.tar.gz

COPY rootfs/ /

ENTRYPOINT ["/init"]
