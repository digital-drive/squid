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

| Component    | Description                                                                                                                                                                                  |
|--------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Build base   | `debian:bookworm` with `build-essential`, `pkg-config`, `wget`, and Squid deps                                                                                                               |
| Build steps  | For `linux/amd64`, downloads `squid-6.14.tar.bz2` from `https://github.com/squid-cache/squid/releases/download/SQUID_6_14/` into `/var/cache/squid-build`, verifies SHA256, runs `./configure --prefix=/usr --localstatedir=/var --libexecdir=/usr/lib/squid --enable-ssl --enable-ecap` (with `CFLAGS=CXXFLAGS=-march=x86-64 -mtune=generic`), then `make && make install DESTDIR=/var/cache/squid-install`. Other architectures skip the source build so the runtime stage can install Debian's prebuilt `squid`. |
| Runtime base | `debian:bookworm-slim` to keep the final image small                                                                                                                                         |
| Runtime deps | `libssl3`, `libecap3` installed via `apt`; non-`amd64` also get Debian’s `squid`.                                                                                                            |
| Supervision  | `s6-overlay v3.2.1.0` plus `rootfs/etc/services.d/squid` run/log scripts ensure Squid runs under `/init`.                                                                                       |
| Files copied | `/var/cache/squid-install/usr` (includes `/usr/etc`, `/usr/lib`, etc.) for `amd64`; other architectures use the Debian `squid` package instead.                                                                                                                    |
| Entry point  | `ENTRYPOINT ["/init"]` (with `s6-overlay` launching Squid via `rootfs/etc/services.d/squid`)                                                                                                                                        |
| Ports        | `3128/tcp` (proxy)                                                                                                                                                                           |
| Volumes      | `/var/cache/squid` (cache), `/var/log/squid` (logs)                                                                                                                                          |

All files in the repository must retain LF line endings to avoid Debian
variance.

## 3. Configuration Interface

| Mechanism             | Behaviour                                                                                        |
|-----------------------|--------------------------------------------------------------------------------------------------|
| `squid.conf` override | Replace `/etc/squid/squid.conf` with a bind-mounted file to control ACLs, cache directives, etc. |
| Drop-in snippets      | Mount files under `/etc/squid/conf.d/*.conf`; they are appended after the main config.           |
| Cache persistence     | Mount `/var/cache/squid` and ensure Squid owns the directory before starting.                    |
| Log persistence       | Mount `/var/log/squid` to retain access/cache logs outside the container (the same streams appear via `docker logs`). |
| Reload control        | Run `docker exec <name> squid -k reconfigure` to apply config changes without a restart.         |

The image does not honor any environment variables; configuration remains fully file-driven to preserve Squid semantics.

## 4. Runtime Behaviour

1. During container startup, Squid ensures cache/log directories exist and have
   correct permissions for the `proxy` user (the `s6` init hook also owns
   `/var/run/squid` so PID files stay writable).
2. Squid runs in no-daemon mode (`-N`) while `s6-log` mirrors the access/cache
   files under `/var/log/squid` to stdout, giving both durable files and
   `docker logs` visibility as `/init` keeps the process alive and manages restarts.
3. Non-`amd64` targets skip the source build and simply install Debian's `squid`
   package inside the runtime image so the proxy is still available on those
   platforms without rebuilding inside QEMU.
4. Health can be inferred from the Squid process exit code; optional healthchecks
   (not provided by default) can call `squidclient mgr:info` for readiness.
5. On shutdown, Squid flushes dirty caches, writes its `cache.log`, and exits cleanly.

## 5. Failure Modes & Limitations

- Breaking changes to Squid configuration will prevent Squid from starting; check
  `/var/log/squid/cache.log` for parser errors.
- TLS interception helpers and authentication programs are not bundled by default
  and must be supplied via custom configuration or additional binaries.
- The build stage demands outbound HTTP access to download Debian archives and
  the Squid source tarball; offline builds require a local mirror or vendor.
- No healthcheck is shipped; add a `HEALTHCHECK CMD squidclient mgr:info` or
  equivalent in your own manifest if orchestrators need service readiness signals.

## 6. Expected Usage

1. Build `digitaldriveio/squid` with `docker build` or pull from your registry.
2. Provide configuration and persistence mounts tailored to your environment.
3. Route workloads through Squid by publishing `3128/tcp` and pointing clients at it.
4. Monitor logs under `/var/log/squid` or query `squidclient mgr:info` for runtime
   visibility.

Keep this specification synchronized with README.md and AGENTS.md when any behavioural details change.
