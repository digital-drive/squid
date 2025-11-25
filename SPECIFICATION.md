---
github_description: "Squid 7 Bookworm-slim images on amd64/arm64 by compiling branch 7 with TLS/OpenSSL ssl_crtd/eCAP support, bundling s6 supervision, persistence-friendly cache/log volumes, healthchecks, and user guidance so teams can run a complete proxy without rebuilding or managing artifacts, keeping configs file-drive."
---

# SPECIFICATION

Authoritative description of the `digitaldriveio/squid` container image.

## 1. Purpose

Provide a reproducible Squid 7 proxy (tracking Squid branch 7) built from source
within a Debian Bookworm build stage and delivered as a lean Debian
Bookworm-slim runtime.
This project packages the build pipeline, runtime image, and documentation so
operators can deploy Squid 7 on amd64 or arm64 without compiling or managing
artifacts themselves.

The multi-stage approach ensures only the required runtime dependencies are
included while still enabling features such as TLS (`--enable-ssl`), OpenSSL integration
(`--with-openssl`), the dynamic certificate helper (`--enable-ssl-crtd`), and eCAP helpers
(`--enable-ecap`).

## 2. Components

- **Build base:** `debian:bookworm` with `build-essential`, `pkg-config`, and `wget`.
  It installs the Squid dependencies (`libssl-dev`, `libecap3-dev`, `libdb-dev`),
  `libexpat1-dev`, `libcppunit-dev`, and `libcap-dev`.
- **Build steps:** Download `squid-7.3.tar.bz2` into `/var/cache/squid-build`.
  Verify the SHA256, extract it, and configure with the documented prefixes.
  Add `--enable-ssl --with-openssl --enable-ssl-crtd --enable-ecap --disable-arch-native` before compiling.
  Run `make -j$(nproc)` and `make install DESTDIR=/var/cache/squid-install`.
  `linux/amd64` adds `CFLAGS/CXXFLAGS=-march=x86-64 -mtune=generic`.
  `linux/arm64` uses Debian's hardened defaults.
- **Runtime base:** `debian:bookworm-slim`.
  It keeps the final image compact.
- **Runtime deps:** Provide `libssl3`, `libecap3`, and the `openssl` CLI for `ssl_bump` certificate workflows.
  Copy the built `/usr` tree from the build stage so every architecture shares the same Squid binaries.
- **Supervision:** `s6-overlay v3.2.1.0` and `rootfs/etc/services.d/squid` run/log scripts.
  They keep Squid running under `/init`.
- **Log streaming:** A dedicated `squid-logs` service tails `/var/log/squid/access.log` and `/var/log/squid/cache.log` as `proxy`, ensuring the same lines land in `docker logs` while the files remain on disk for persistence.
- **Files copied:** `/var/cache/squid-install/usr` includes `/usr/etc` and `/usr/lib`.
  This ensures both `amd64` and `arm64` share the same feature set.
- **Entry point:** `ENTRYPOINT ["/init"]` launches Squid through the s6 supervision tree.
- **Ports:** `3128/tcp` serves proxy traffic.
- **Volumes:** `/var/cache/squid` for cache data and `/var/log/squid` for log files.

All files in the repository must retain LF line endings to avoid Debian variance.

## 3. Build Details

- Squid 7.3 is downloaded from
  `https://github.com/squid-cache/squid/releases/download/SQUID_7_3/squid-7.3.tar.bz2`.
  The file is stored in `/var/cache/squid-build`.
  It is verified against the published SHA256 before extraction.
  (`af7d61cfe8e65a814491e974d3011e5349a208603f406ec069e70be977948437`)
- The tarball is configured with `--prefix=/usr` and `--localstatedir=/var`.
  It adds `--libexecdir=/usr/lib/squid` and `--with-pidfile=/var/run/squid/squid.pid`.
  It also enables `--disable-arch-native --enable-ssl --with-openssl --enable-ssl-crtd --enable-ecap`.
- `linux/amd64` adds `CFLAGS/CXXFLAGS=-march=x86-64 -mtune=generic`.
  Additional flags: `-O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2`.
  `linux/arm64` compiles with Debian’s hardened defaults.
- After `make -j$(nproc)` succeeds, run `make install DESTDIR=/var/cache/squid-install`.
  That stages the `/usr` tree.
  The runtime image copies that tree so the container never needs to compile again.
  Update documentation there when the build or runtime behaviour changes.

## 4. Configuration Interface

- **`squid.conf` override:** Replace `/etc/squid/squid.conf` with a bind-mounted file.
  This lets you control ACLs, cache directives, etc.
- **Drop-in snippets:** Mount files under `/etc/squid/conf.d/*.conf`; they are appended after the main config.
- **Cache persistence:** Mount `/var/cache/squid` and ensure Squid owns the directory before starting. The baked-in config uses Squid's asynchronous `aufs` store (`cache_dir aufs /var/spool/squid 4096 16 256`) for better concurrency; override `cache_dir` if you need a different store or size.
- **Log persistence:** Mount `/var/log/squid` to retain access/cache logs outside the container.
  The same streams appear via `docker logs`.
- **Reload control:** Run `docker exec <name> squid -k reconfigure` to apply config changes without a restart.

The image does not honor any environment variables; configuration remains fully file-driven to preserve Squid semantics.

## 5. Runtime Behaviour

1. During container startup, Squid ensures cache/log directories exist.
   It also verifies they have correct permissions for the `proxy` user.
   The `s6` init hook owns `/var/run/squid` so PID files stay writable.
2. Squid runs in no-daemon mode with level-1 debugging (`-N -d1`).
   `s6-log` mirrors the access/cache files under `/var/log/squid` to stdout.
   This gives both durable files and `docker logs` visibility as `/init` keeps the process alive and manages restarts.
3. Multi-architecture builds compile Squid from source with hardened defaults.
   Their resulting images keep the same feature set as `amd64`.
4. Docker's HEALTHCHECK now invokes `squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info`,
   enabled by a restrictive `cachemgr_passwd none info` rule so only that action is exposed.
   Orchestrators receive instant readiness updates without extra configuration.
5. On shutdown, Squid flushes dirty caches, writes its `cache.log`, and exits cleanly.

## 6. Failure Modes & Limitations

- Breaking changes to Squid configuration will prevent Squid from starting; check
  `/var/log/squid/cache.log` for parser errors.
- TLS interception helpers and authentication programs are not bundled by default
  and must be supplied via custom configuration or additional binaries.
- The build stage demands outbound HTTP access to download Debian archives and
  the Squid source tarball; offline builds require a local mirror or vendor.
- A `HEALTHCHECK CMD squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info` is included in the Dockerfile so
  orchestrators receive readiness signals without extra wiring; override it
  only if you need a different probe (and adjust the matching `cachemgr_passwd`).

## 7. Expected Usage

1. Build `digitaldriveio/squid` with `docker build` and tag it for your registry.
   For example, use `digitaldriveio/squid:snapshot`.
2. Provide configuration and persistence mounts tailored to your environment.
3. Route workloads through Squid by publishing `3128/tcp` and pointing clients at it.
4. Monitor logs under `/var/log/squid` or query `squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info`
   (permitted by `cachemgr_passwd none info`) for runtime visibility.

## 8. Licensing

The `digitaldriveio/squid` image and repository content are released under GPL v3 or later (`GPL-3.0-or-later`).
See `LICENSE` for the full text.

Keep this specification synchronized with README.md and AGENTS.md when any behavioural details change.
