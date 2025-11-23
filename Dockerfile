# -------- BUILD STAGE --------
FROM debian:bookworm-slim AS build
ARG TARGETARCH

LABEL maintainer="Maxence Winandy <maxence.winandy@digital-drive.io>"

ARG SQUID_VERSION=6.14
ARG SQUID_TAG=SQUID_6_14
ARG SQUID_SHA256=cdc6b6c1ed519836bebc03ef3a6ed3935c411b1152920b18a2210731d96fdf67
ARG SQUID_CFLAGS="-march=x86-64 -mtune=generic -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2"
ARG SQUID_LDFLAGS="-Wl,-z,relro,-z,now"

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential pkg-config wget perl \
      libssl-dev libecap3-dev libdb-dev libexpat1-dev \
      libcppunit-dev libcap-dev ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /var/cache/squid-build
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) ARCH_CFLAGS="${SQUID_CFLAGS}" ;; \
        arm64) ARCH_CFLAGS="-O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    export SQUID_CFLAGS="${ARCH_CFLAGS}"; \
    export SQUID_CXXFLAGS="${ARCH_CFLAGS}"; \
    wget https://github.com/squid-cache/squid/releases/download/${SQUID_TAG}/squid-${SQUID_VERSION}.tar.bz2; \
    echo "${SQUID_SHA256}  squid-${SQUID_VERSION}.tar.bz2" > squid-${SQUID_VERSION}.tar.bz2.sha256; \
    sha256sum -c squid-${SQUID_VERSION}.tar.bz2.sha256; \
    tar xjf squid-${SQUID_VERSION}.tar.bz2; \
    cd squid-${SQUID_VERSION}; \
    export CFLAGS="${ARCH_CFLAGS}"; \
    export CXXFLAGS="${ARCH_CFLAGS}"; \
    export LDFLAGS="${SQUID_LDFLAGS}"; \
    ./configure --prefix=/usr \
                --localstatedir=/var \
                --libexecdir=/usr/lib/squid \
                --with-pidfile=/var/run/squid/squid.pid \
                --disable-arch-native \
                --enable-ssl \
                --enable-ecap; \
    make -j$(nproc); \
    make install DESTDIR=/var/cache/squid-install


# -------- RUNTIME STAGE --------
FROM debian:bookworm-slim

LABEL maintainer="Maxence Winandy <maxence.winandy@digital-drive.io>"

ARG TARGETARCH
ARG S6_OVERLAY_VERSION=3.2.1.0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      sudo \
      tzdata \
      xz-utils \
      procps \
      libssl3 \
      libecap3 \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if ! getent group proxy >/dev/null; then \
        groupadd -r proxy; \
    fi; \
    if ! getent passwd proxy >/dev/null; then \
        useradd -r -g proxy -s /usr/sbin/nologin proxy; \
    fi

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) S6_ARCH="x86_64" ;; \
        arm64) S6_ARCH="aarch64" ;; \
        *) echo "Unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL -o /tmp/s6-overlay-noarch.tar.xz \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
    curl -fsSL -o /tmp/s6-overlay.tar.xz \
        "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz"; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay.tar.xz; \
    chmod 0755 /init; \
    chmod 0755 /command/s6-setuidgid; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay.tar.xz


COPY --from=build /var/cache/squid-install/usr /usr

COPY rootfs/ /

USER root

RUN set -eux; \
    chmod +x \
        /etc/cont-init.d/10-squid-dirs \
        /etc/services.d/squid/run \
        /etc/services.d/squid/log/run

VOLUME ["/var/cache/squid", "/var/log/squid"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD /usr/bin/squidclient mgr:info

ENTRYPOINT ["/init"]
