# digitaldriveio/squid

Multi-stage Debian Bookworm build that compiles Squid **branch 6.14** from the
official GitHub release (`SQUID_6_14`) and ships the resulting binaries on a
slim runtime image. This keeps the final runtime lean while still enabling
feature-rich compiler flags such as TLS and ECAP support.

## Features

- Build stage pulls `debian:bookworm`, installs build dependencies, downloads
  the Squid 6.14 BZ2 release from GitHub, verifies the provided SHA256 (`cdc6...`),
  and configures it with `--enable-ssl` / `--enable-ecap`. When building for
  `linux/amd64`, the configure step also sets `-march=x86-64 -mtune=generic`,
  keeping the binary compatible with older x86_64 hosts. Non-`amd64` targets skip
  the source build and rely on Debian's packaged `squid` so the multi-arch image
  remains lightweight.
- Runtime stage is based on `debian:bookworm-slim` and carries only the
  libraries Squid actually needs (`libssl3`, `libecap3`).
- Runs Squid in the foreground (`-N`) so Docker sees real process restarts.
- Mounts-friendly: configuration, cache, and log directories can all be
  persisted easily, and Squid is supervised via `s6` so PID/log directories are
  pre-warmed and the process restarts cleanly. The `rootfs/etc/services.d`
  tree defines the supervisor scripts and ships with `s6-overlay v3.2.1.0`.

## Quick Start

```bash
docker build -t digitaldriveio/squid .

docker run \
  --name squid \
  -p 3128:3128 \
  digitaldriveio/squid:snapshot
```

Point applications at `http://localhost:3128` (or `http://<container-host>:3128`).

The build accepts `SQUID_VERSION`/`SQUID_TAG` arguments so you can track other
branch-6 releases if needed:

```bash
docker build --build-arg SQUID_VERSION=6.14 \
  --build-arg SQUID_TAG=SQUID_6_14 \
  -t digitaldriveio/squid:6.14 .
```

### Custom configuration

```bash
mkdir -p ./config ./cache ./logs
cp examples/squid.conf ./config/squid.conf

docker run \
  --name squid \
  -p 3128:3128 \
  -v $(pwd)/config/squid.conf:/etc/squid/squid.conf:ro \
  -v $(pwd)/cache:/var/cache/squid \
  -v $(pwd)/logs:/var/log/squid \
  digitaldriveio/squid:snapshot
```

Reload configuration after tweaks:

```bash
docker exec squid squid -k reconfigure
```

## Configuration & Persistence

| Aspect              | Recommendation                                                           |
|---------------------|--------------------------------------------------------------------------|
| Listening port      | Publish `3128/tcp` so workloads can reach the proxy.                     |
| Squid configuration | Mount `/etc/squid/squid.conf` (read-only) or drop files under `conf.d/`. |
| Cache directory     | Persist `/var/cache/squid` to warm caches between container restarts.      |
| Logs                | Mount `/var/log/squid` if host-level log shipping or inspection is needed (also streamed via `docker logs`). |
| Reload control      | Use `squid -k reconfigure` inside the container to apply config changes.   |

There are no runtime environment variables; configure Squid via its native
file-based syntax so you retain the full power of ACLs, caching, and helpers.

## Observability

- Access logs: `/var/log/squid/access.log`
- Cache logs: `/var/log/squid/cache.log`
- Manager interface: `docker exec squid squidclient mgr:info`

`docker logs squid` shows the same access/cache log lines because the `s6-log`
service fans them out to stdout while rotating files under `/var/log/squid`.
These files can be shipped to your log backend or inspected manually.

## Development Notes

1. Keep `README.md`, `SPECIFICATION.md`, and `DockerHub.md` aligned whenever the
   multi-stage build, Squid version, or configuration surface changes.
2. Use LF line endings and avoid shellisms that differ between Alpine and Debian.
3. Extend configuration or helper scripting under a dedicated `config/` or
   `scripts/` directory to keep the Dockerfile focused on building and copying.

## License

Specify your licensing terms here (MIT, Apache-2.0, etc.).
