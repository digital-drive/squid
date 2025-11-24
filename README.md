# digitaldriveio/squid

The `digitaldriveio/squid` project packages a Squid branch 6.14 proxy by
compiling it inside a reproducible multi-stage Debian Bookworm pipeline.
That lets teams distribute a lean, feature-complete Debian Bookworm-slim
runtime without forcing operators to rebuild Squid. The build then enables TLS
and ECAP support with conservative flags on `amd64` and hardened defaults on
`arm64`, and copies the binaries into the runtime image so operators never
compile Squid themselves.

## Features

- Runs a Squid 6.14 proxy (built from source in the build stage) on Debian Bookworm-slim.
  Only the runtime libraries that Squid needs (`libssl3`, `libecap3`) are installed so the image stays compact.
- Squid runs in the foreground (`-N -d1`), so Docker/s6 can supervise it while still emitting actionable log lines.
  Restarts happen transparently and keep the log stream consistent.
- Mounts-friendly: configuration, cache, and log directories can be persisted easily.
- The `rootfs/etc/services.d` tree (bundled with `s6-overlay v3.2.1.0`) supplies the supervisor/run/log scripts.

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

> **Security note:** the built-in `/etc/squid/squid.conf` covers `_localnet` and allows `http_access` to `localnet`.
- If you override the baked-in `squid.conf`, remember the runtime healthcheck always hits `/squid-internal-mgr/info`. Allow localhost (or the healthcheck ACL) to request that manager page or change the healthcheck command so it hits an endpoint your custom config permits; otherwise the docker healthcheck will continually return `ERR_ACCESS_DENIED`.

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

- **Listening port:** Publish `3128/tcp` so workloads can reach the proxy.
- **Squid configuration:** Mount `/etc/squid/squid.conf` (read-only) or drop files under `conf.d/`.
  This controls ACLs and caching.
- **Cache directory:** Persist `/var/cache/squid` to keep caches warm between restarts.
- **Logs:** Mount `/var/log/squid` if host-level log shipping or inspection is needed.
  These same streams also appear via `docker logs`.
- **Reload control:** Run `squid -k reconfigure` inside the container to apply config changes without restarting Squid.
  The bundled service already runs `squid -N -d1` so it stays in the foreground.

There are no runtime environment variables; configure Squid via its native
file-based syntax so you retain the full power of ACLs, caching, and helpers.

## Observability

- Access logs: `/var/log/squid/access.log`
- Cache logs: `/var/log/squid/cache.log`
- Manager interface: `docker exec squid squidclient mgr:info`
- Healthcheck: Dockerfile defines `HEALTHCHECK CMD squidclient mgr:info` so orchestrators know when Squid is ready.

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

`digitaldriveio/squid` is distributed under the GNU General Public License v3 or later (`GPL-3.0-or-later`).
See `LICENSE` for the full terms.
