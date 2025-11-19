# digitaldriveio/squid (Docker Hub README)

Multi-stage Squid 6 build: the first stage compiles Squid 6.14 from the GitHub
`SQUID_6_14` release (downloaded as `squid-6.14.tar.bz2` and verified via SHA256)
on `debian:bookworm`, the second packages the binaries on `debian:bookworm-slim`
with minimal runtime dependencies. Non-`amd64` targets skip the source build and
install Debian's `squid` package instead so the platform gains a working proxy
without overflowing the QEMU builder.

## Highlights

- Build stage installs `build-essential`, `pkg-config`, `wget`, `libssl-dev`,
  `libecap3-dev`, `libcap-dev`, and the rest of the toolchain needed to compile
  Squid 6.14 with TLS and eCAP support.
- Non-`amd64` builds skip the source build and just use Debian's packaged `squid`
  binary, enabling the multi-arch manifest without unhappy QEMU runs.
- Runtime stage copies the compiled `/usr` and `/var` trees into a slim Debian
  image, installs `libssl3` and `libecap3`, and runs Squid as the `proxy` user.
- Ports: `3128/tcp` for the proxy; Squid stays in the foreground (`-N -d1`).

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

- No healthcheck is shipped by default; add your own (`squidclient mgr:info` is a good target).
- The image is file-driven: configure Squid via `squid.conf` and drop-in snippets
  rather than environment variables.
- TLS interception, authentication helpers, and advanced cachefeatures depend on
  the configuration you mount into the container; they are not baked into the image.
