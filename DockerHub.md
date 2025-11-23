---
description: Squid6 multi-stage Docker image with SSL/ECAP build and s6-managed runtime; ideal caching proxy svc.
---

# digitaldriveio/squid (Docker Hub README)

Multi-stage Squid 6 build: the first stage compiles Squid 6.14 from the GitHub
`SQUID_6_14` release (downloaded as `squid-6.14.tar.bz2` and verified via SHA256)
on `debian:bookworm`, the second packages the binaries on `debian:bookworm-slim`
with minimal runtime dependencies. The runtime image ships `s6-overlay v3.2.1.0`
plus the `rootfs/etc/services.d/squid` supervision scripts so Squid runs under
`/init` with PID/log dirs owned by `proxy`. Both `linux/amd64` and `linux/arm64`
targets compile Squid from source so multi-arch manifests keep identical features.

## Highlights

- Build stage installs `build-essential`, `pkg-config`, `wget`, `libssl-dev`,
  `libecap3-dev`, `libcap-dev`, and the rest of the toolchain needed to compile
  Squid 6.14 with TLS and eCAP support on both `amd64` (with `-march=x86-64 -mtune=generic`)
  and `arm64` (with Debian's hardened defaults).
- Runtime stage copies the compiled `/usr` and `/var` trees into a slim Debian
  image, installs `libssl3` and `libecap3`, and runs Squid as the `proxy` user.
- Ports: `3128/tcp` for the proxy; the bundled service runs Squid with `-N -d1` so Docker sees real restarts and still captures log output.

## Usage

```bash
docker build -t digitaldriveio/squid .

docker run \
  --name squid \
  -p 3128:3128 \
  digitaldriveio/squid:snapshot
```

### With persistence & custom config

```bash
docker run \
  --name squid \
  -p 3128:3128 \
  -v ./config/squid.conf:/etc/squid/squid.conf:ro \
  -v squid-cache:/var/cache/squid \
  -v squid-logs:/var/log/squid \
  digitaldriveio/squid:snapshot
```

Reload config after edits:

```bash
docker exec squid squid -k reconfigure
```

## Notes

- The image ships with a Docker `HEALTHCHECK` that runs `squidclient mgr:info`, so orchestrators detect readiness out of the box; replace it if you prefer a different probe.
- The image is file-driven: configure Squid via `squid.conf` and drop-in snippets
  rather than environment variables.
- TLS interception, authentication helpers, and advanced cachefeatures depend on
  the configuration you mount into the container; they are not baked into the image.
- Squid writes `access.log` / `cache.log` under `/var/log/squid` and the bundled
  `s6-log` service mirrors those lines to stdout, so `docker logs` exposes the same stream.

## License

`digitaldriveio/squid` is published under the GNU General Public License v3 or later (`GPL-3.0-or-later`). See `LICENSE` for details.
