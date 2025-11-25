# AGENTS.MD

## Purpose of the Image

This image delivers Squid **branch 6** built atop Debian Bookworm. A dedicated
build stage compiles the desired Squid 6 release with the required feature
flags, while the runtime stage packages the result on a lightweight Debian
Bookworm-slim base without forcing users to compile Squid themselves.

## Internal Components

### 1. Build Stage

- Based on `debian:bookworm` with `build-essential`, `pkg-config`, `wget`, and
  the dependencies required to compile Squid (OpenSSL, ECAP, Berkeley DB, etc.).
- Downloads `squid-6.14.tar.bz2` from the GitHub release `SQUID_6_14`, stores it
  under `/var/cache/squid-build`, and verifies the published SHA256 before
  extraction.
- Configures Squid with `/usr` prefixes plus `--enable-ssl`, `--with-openssl`,
  `--enable-ssl-crtd`, and `--enable-ecap`. When
  the build runs on `linux/amd64`, it adds conservative compiler flags
  (`-march=x86-64 -mtune=generic`) so the binary remains portable across Intel/AMD
  hosts; other architectures skip those flags and fall back to Debian's binary
  package.
- Installs the built artifacts under `/var/cache/squid-install` for later reuse.

### 2. Runtime Stage

- Starts from `debian:bookworm-slim` and installs only the runtime libraries
  plus the `openssl` CLI so Squid's `ssl_crtd` helper can initialize certificate
  stores for `ssl_bump` without extra tooling.
  - Copies the compiled `/usr` tree (which includes the Squid configuration
  under `/usr/etc`) from the build stage (built under `/var/cache/squid-install`)
  into the final image; cache/log directories are created at runtime. On
  non-`amd64` targets the stage installs Debian's `squid` package so the runtime
  still ships the proxy without needing to copy missing build artifacts. The
  runtime stage also deploys `s6-overlay v3.2.1.0`, copies the `rootfs/etc/services.d/squid`
  definition (run/log scripts), and runs via `/init` so PID/log dirs are owned by
  `proxy`.
- Creates `/var/cache/squid` and `/var/log/squid`, ensures `proxy:proxy`
  ownership, streams Squid logs to Docker stdout via `s6-log`, and runs as the
  unprivileged `proxy` user. The bundled `squid.conf` configures the asynchronous
  `aufs` cache store so disk I/O happens via helper threads instead of blocking
  the main worker.
- Command: `CMD ["/usr/sbin/squid", "-N", "-d1"]` keeps Squid running in the
  foreground so Docker can supervise it directly.

## Configuration Inputs & Run-time Behaviour

- Provide your own `squid.conf` via a bind mount to `/etc/squid/squid.conf` (read-only is encouraged).
- Drop-in snippets can live under `/etc/squid/conf.d/*.conf` to keep the base
  config untouched.
- Cache (`/var/cache/squid`) and logs (`/var/log/squid`) are best persisted
  through volumes so the proxy keeps warm caches and audit trails across
  restarts.
- Reload configuration without restarting the container via `squid -k reconfigure`.

## Use Cases

1. **Caching egress for CI/CD** – place the Squid container in front of build
   agents to cache packages and reduce bandwidth on repeated runs.
2. **Controlled outbound proxy for multi-service stacks** – route internal HTTP
   traffic through Squid to enforce ACLs, bandwidth limits, or authentication.
3. **Testing proxy configurations** – mount different `squid.conf` files to
   prototype ACLs, rate limits, or security rules inside containers.

## Health & Lifecycle

1. The multi-stage build outputs a Squid install tailored to Debian binaries.
2. The runtime image runs Squid as `proxy`, exposing `3128/tcp` to the host.
3. Logs are written under `/var/log/squid`, mirrored to container stdout by
   `s6-log`, and can be shipped to the host or retained in volumes.
4. On shutdown, Docker signals Squid which cleans up its cache before exit.

## Known Limitations

- The build stage requires network access to download dependencies and the
  Squid tarball, so offline rebuilds are not currently supported.
- TLS interception helpers and auth helpers are not bundled out of the box;
  add them through custom configuration and helper binaries if needed.
- No healthcheck is configured by default; add one (e.g., using `squidclient
  cache_object://127.0.0.1/info`) if orchestrators need readiness signals.

## Example Project Structure

    .
    ├── Dockerfile            # multi-stage build definition
    ├── config/squid.conf     # optional override
    └── AGENTS.md             # this document

## Guidance

- Keep `README.md`, `SPECIFICATION.md`, and `DockerHub.md` synchronized with
  any behaviour or option changes affecting the Squid build or runtime.
- Favor declarative Squid configuration inside version-controlled `config/`
  directories instead of relying on runtime environment variables.
- Use LF line endings so Debian tooling and shell scripts behave consistently.

## Licensing

The image and the accompanying repository artifacts are distributed under the
GNU General Public License version 3 or later (`GPL-3.0-or-later`). Update
`LICENSE` if licensing terms evolve and mention the license in the other docs.
