# SPECIFICATION

Authoritative description of the `digitaldriveio/squid` container image.

## 1. Purpose

Provide a reproducible Squid 6 proxy (tracking Squid branch 6) built from source
within a Debian Bookworm build stage and delivered as a lean Debian
Bookworm-slim runtime.
The multi-stage approach ensures only the required runtime dependencies are
included while still enabling features such as TLS (`--enable-ssl`) and eCAP
helpers (`--enable-ecap`).

## 2. Components

| Component    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
|--------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build base   | `debian:bookworm` with `build-essential`, `pkg-config`, `wget`, and Squid deps                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Build steps  | Downloads `squid-6.14.tar.bz2` from `https://github.com/squid-cache/squid/releases/download/SQUID_6_14/` into `/var/cache/squid-build`, verifies SHA256, runs `./configure --prefix=/usr --localstatedir=/var --libexecdir=/usr/lib/squid --with-pidfile=/var/run/squid/squid.pid --enable-ssl --enable-ecap --disable-arch-native`, then `make && make install DESTDIR=/var/cache/squid-install`. `linux/amd64` adds `CFLAGS=CXXFLAGS=-march=x86-64 -mtune=generic` while `linux/arm64` compiles with Debian's hardened defaults. |
| Runtime base | `debian:bookworm-slim` to keep the final image small                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Runtime deps | `libssl3`, `libecap3` installed via `apt`; Squid binaries are copied from the build stage regardless of architecture.                                                                                                                                                                                                                                                                                                                                                                                                              |
| Supervision  | `s6-overlay v3.2.1.0` plus `rootfs/etc/services.d/squid` run/log scripts ensure Squid runs under `/init`.                                                                                                                                                                                                                                                                                                                                                                                                                          |
| Files copied | `/var/cache/squid-install/usr` (includes `/usr/etc`, `/usr/lib`, etc.) for every supported architecture so `amd64` and `arm64` share the same feature set.                                                                                                                                                                                                                                                                                                                                                                         |
| Entry point  | `ENTRYPOINT ["/init"]` (with `s6-overlay` launching Squid via `rootfs/etc/services.d/squid`)                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Ports        | `3128/tcp` (proxy)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Volumes      | `/var/cache/squid` (cache), `/var/log/squid` (logs)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

All files in the repository must retain LF line endings to avoid Debian variance.

## 3. Build Details

- Squid 6.14 is downloaded from `https://github.com/squid-cache/squid/releases/download/SQUID_6_14/squid-6.14.tar.bz2`, stored in `/var/cache/squid-build`, and verified against the published SHA256 (`cdc6b6c1ed519836bebc03ef3a6ed3935c411b1152920b18a2210731d96fdf67`) before extraction.
- The tarball is configured with `--prefix=/usr`, `--localstatedir=/var`, `--libexecdir=/usr/lib/squid`, and `--with-pidfile=/var/run/squid/squid.pid`, alongside `--disable-arch-native --enable-ssl --enable-ecap`; `linux/amd64` adds `CFLAGS/CXXFLAGS=-march=x86-64 -mtune=generic -O2 -fstack-protector-strong -D_FORTIFY_SOURCE=2`, while `linux/arm64` compiles with Debian’s hardened defaults.
- After `make -j$(nproc)` succeeds, `make install DESTDIR=/var/cache/squid-install` stages the `/usr` tree that is copied into the runtime image so the final container never needs to compile anything.
- See `CONTRIBUTING.md` for how to reproduce builds, test contributions, and update documentation when the build or runtime behaviour changes.

## 4. Configuration Interface

| Mechanism             | Behaviour                                                                                                             |
|-----------------------|-----------------------------------------------------------------------------------------------------------------------|
| `squid.conf` override | Replace `/etc/squid/squid.conf` with a bind-mounted file to control ACLs, cache directives, etc.                      |
| Drop-in snippets      | Mount files under `/etc/squid/conf.d/*.conf`; they are appended after the main config.                                |
| Cache persistence     | Mount `/var/cache/squid` and ensure Squid owns the directory before starting.                                         |
| Log persistence       | Mount `/var/log/squid` to retain access/cache logs outside the container (the same streams appear via `docker logs`). |
| Reload control        | Run `docker exec <name> squid -k reconfigure` to apply config changes without a restart.                              |

The image does not honor any environment variables; configuration remains fully file-driven to preserve Squid semantics.

## 5. Runtime Behaviour

1. During container startup, Squid ensures cache/log directories exist and have
   correct permissions for the `proxy` user (the `s6` init hook also owns
   `/var/run/squid` so PID files stay writable).
2. Squid runs in no-daemon mode with level-1 debugging (`-N -d1`) while `s6-log`
   mirrors the access/cache files under `/var/log/squid` to stdout, giving both
   durable files and `docker logs` visibility as `/init` keeps the process alive
   and manages restarts.
3. Multi-architecture builds compile Squid from source with hardened defaults so their resulting images keep the same feature set as `amd64`.
4. Docker’s HEALTHCHECK now invokes `squidclient mgr:info`, so orchestrators receive instant readiness updates without extra configuration.
5. On shutdown, Squid flushes dirty caches, writes its `cache.log`, and exits cleanly.

## 6. Failure Modes & Limitations

- Breaking changes to Squid configuration will prevent Squid from starting; check
  `/var/log/squid/cache.log` for parser errors.
- TLS interception helpers and authentication programs are not bundled by default
  and must be supplied via custom configuration or additional binaries.
- The build stage demands outbound HTTP access to download Debian archives and
  the Squid source tarball; offline builds require a local mirror or vendor.
- A `HEALTHCHECK CMD squidclient mgr:info` is included in the Dockerfile so
  orchestrators receive readiness signals without extra wiring; override it
  only if you need a different probe.

## 7. Expected Usage

1. Build `digitaldriveio/squid` with `docker build` and tag it as needed for your registry (e.g., `digitaldriveio/squid:snapshot`).
2. Provide configuration and persistence mounts tailored to your environment.
3. Route workloads through Squid by publishing `3128/tcp` and pointing clients at it.
4. Monitor logs under `/var/log/squid` or query `squidclient mgr:info` for runtime
   visibility.

## 8. Licensing

The `digitaldriveio/squid` image (and the associated repository content) is released under the GNU General Public License version 3 or later (`GPL-3.0-or-later`). See `LICENSE` for the full text.

Keep this specification synchronized with README.md and AGENTS.md when any behavioural details change.
