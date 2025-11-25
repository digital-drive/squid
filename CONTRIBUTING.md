# Contributing to digitaldriveio/squid

Thanks for helping improve the Squid container. Follow these guidelines so new features, bugfixes, and documentation stay aligned:

## Understand the project

- The runtime image ships Squid 6.14 built from source, but all build-stage behaviour (dependencies, configure flags, verification steps, multi-arch handling) is captured in `SPECIFICATION.md`. Update that file whenever you change how the build is run.
- READMEs and DockerHub.md describe the delivered image experience. Keep them focused on features, configuration knobs, ports, and observability; avoid duplicating low-level build steps there.

## Reproducing the build

1. Run `docker build -t digitaldriveio/squid .` from the repo root; the multi-stage Dockerfile handles both the compile (build stage) and the runtime packaging stage.
2. If you need to change which Squid release is compiled, adjust `SQUID_VERSION`, `SQUID_TAG`, and the SHA256 arguments in the Dockerfile, then document the change in `SPECIFICATION.md`.
3. When iterating on cache/log initialization or supervisor scripts, edit the files under `rootfs/` and confirm `s6` still launches Squid (`pipeline rootfs/etc/services.d` and `cont-init.d`).

## Testing & verification

- Run `docker run --rm digitaldriveio/squid cat /usr/sbin/squid -V` (or similar) once the image builds to ensure the Squid binary exists and the configured options appear in the output.
- Exercise configuration changes by mounting your own `squid.conf` into `/etc/squid/squid.conf` and confirming Squid starts without parse errors.
- Keep an eye on `/var/log/squid/cache.log` and `/var/log/squid/access.log` as part of runtime validation; the `s6-log` service mirrors those lines to stdout.

## Documentation updates

- When you touch build mechanics (e.g., dependencies, flags, caching, target architectures), describe those details in `SPECIFICATION.md` and mention any runtime implications in README/DockerHub.
- If behaviour changes affect user-facing configuration, update README, DockerHub.md, and AGENTS.md so the guidance remains synchronized.
- Mention the license (`GPL-3.0-or-later`) in new docs if appropriate; this project already includes a `LICENSE` file covering that.

## Releasing

- This repository uses `release-it` (configured via `.release-it.json`) which triggers `scripts/publish-images.sh` before publishing. When you just want to bump versions or dry-run a release without waiting for the multi-architecture Docker build, export `SKIP_LOCAL_BUILD=1` before running `release-it` (or invoke the script with that variable). The hook detects the flag and skips the local buildx invocation.

## License

Everything in this repository is distributed under the GNU General Public License version 3 or later (`GPL-3.0-or-later`). Keep the `LICENSE` file up to date if the legal terms ever change.
