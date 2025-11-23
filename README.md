# digitaldriveio/squid

The `digitaldriveio/squid` project packages a Squid branch 6.14 proxy by
compiling it inside a reproducible multi-stage Debian Bookworm pipeline so
users can distribute a lean, feature-complete Debian Bookworm-slim runtime.
The build enables TLS and ECAP support with conservative flags on `amd64`
and hardened defaults on `arm64`, then copies the resulting binaries into
the runtime image so operators never have to compile Squid themselves.

## Features

- Runs a Squid 6.14 proxy (built from source in the build stage) on a Debian Bookworm-slim runtime with only the libraries Squid actually needs (`libssl3`, `libecap3`), keeping the image compact.
- Squid runs in the foreground (`-N -d1`) so Docker/s6 can supervise it while still emitting actionable log lines and restarting transparently.
- Mounts-friendly: configuration, cache, and log directories can all be persisted easily, and the `rootfs/etc/services.d` tree (bundled with `s6-overlay v3.2.1.0`) provides the supervisor/run/log scripts.

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

> **Security note:** the built-in `/etc/squid/squid.conf` simply covers `_localnet` as `acl localnet src all` and allows `http_access` to `localnet`, so the default image behaves like an open proxy inside the container network; mount a stricter config (ideally read-only) before exposing the container externally.

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

| Aspect              | Recommendation                                                                                                     |
|---------------------|--------------------------------------------------------------------------------------------------------------------|
| Listening port      | Publish `3128/tcp` so workloads can reach the proxy.                                                               |
| Squid configuration | Mount `/etc/squid/squid.conf` (read-only) or drop files under `conf.d/`.                                           |
| Cache directory     | Persist `/var/cache/squid` to warm caches between container restarts.                                              |
| Logs                | Mount `/var/log/squid` if host-level log shipping or inspection is needed (also streamed via `docker logs`).       |
| Reload control      | Use `squid -k reconfigure` inside the container to apply config changes (the bundled service runs `squid -N -d1`). |

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

`digitaldriveio/squid` is distributed under the GNU General Public License v3 or later (`GPL-3.0-or-later`). See `LICENSE` for the full terms.
