---
description: Squid 6 on Debian with s6, ready for caching proxy use.
---

# digitaldriveio/squid

Squid 6.14 with SSL and eCAP support is precompiled for Debian Bookworm-slim.
You can run a modern caching proxy without ever building it from source.
The image runs Squid under `s6-overlay v3.2.1.0` as the unprivileged `proxy` user.
It keeps logs and cache directories persistent-friendly and publishes `3128/tcp` for client traffic.

## Highlights

- Only the required runtime libraries (`libssl3`, `libecap3`) are installed so the image stays small.
- Squid launches in the foreground (`/usr/sbin/squid -N -d1`) while `s6` monitors restarts.
  `s6-log` streams access/cache logs to stdout.
- `cache` and `log` directories are owned by `proxy`, so they can be mounted as named volumes.
  `docker logs` mirrors the same output from those files.
- A built-in healthcheck runs `squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info`, enabled via a dedicated localhost-only listener and a `cachemgr_passwd none info` rule so only that action is exposed.

## Quickstart

```bash
docker build -t digitaldriveio/squid .

docker run --name squid \
  -p 3128:3128 \
  digitaldriveio/squid:snapshot
```

## Runtime configuration

- **Configuration:** Mount your `squid.conf` (read-only if practical) into `/etc/squid/squid.conf`.
  That gives you control over ACLs and caches; drop snippets in `/etc/squid/conf.d/*.conf`.
- **Cache directory:** Persist `/var/cache/squid` to retain warm cache contents across restarts.
  Use `-v squid-cache:/var/cache/squid` for named volumes.
- **Logs:** Persist `/var/log/squid` to keep the log history or let `s6-log` stream them to stdout.
  `docker logs` carries the same output from those streams.
- **Reload:** Send `squid -k reconfigure` inside the container after configuration changes.
  The service keeps running so you do not need to restart it.
- **Ports:** Publish `3128/tcp` for proxy traffic from clients.

## Volumes

```bash
-v squid-cache:/var/cache/squid
-v squid-logs:/var/log/squid
```

These ensure the proxy keeps warm caches and audit trails even when containers are replaced.

## Observability

- Access logs: `/var/log/squid/access.log` (mirrored to stdout)
- Cache logs: `/var/log/squid/cache.log` (mirrored to stdout)
- Manager interface: `docker exec squid squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info` (other cache manager actions remain disabled).
- Healthcheck: `HEALTHCHECK CMD squidclient -h 127.0.0.1 -p 3199 cache_object://127.0.0.1/info`

## Notes

- The build stage compiles Squid 6.14 with TLS/eCAP so the runtime ships with a feature-complete proxy.
  It still starts from Debian Bookworm-slim.
- Mounting TLS interception/authentication helpers and adjusting TLS mode is handled via your `squid.conf`.
  The image ships without auth helpers to keep things lean.
- Need a different Squid release? Build arguments like `SQUID_VERSION` and `SQUID_TAG` can be passed to `docker build`.

## License

`digitaldriveio/squid` is distributed under `GPL-3.0-or-later` (see `LICENSE`).
