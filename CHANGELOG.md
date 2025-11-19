# CHANGELOG

## [0.5.0] - 2025-11-19

### Changed

- Build stage now compiles Squid only for `linux/amd64`; other targets rely on
  Debian's packaged `squid` in the runtime image so multi-arch builds avoid
  expensive QEMU compilations.

## [0.4.1] - 2025-11-19

### Fixed

- Only add the `-march=x86-64 -mtune=generic` compiler flags when the build
  runs on `linux/amd64`; other platforms skip that option so arm64 builds still
  configure successfully.

## [0.3.3] - 2025-11-19

### Fixed

- Build inside `/var/cache/squid-build` and install into `/var/cache/squid-install`
  so the build artefacts never depend on `/tmp`, keeping them on a stable
  filesystem that the runtime stage can still copy from.

## [0.3.2] - 2025-11-19

### Fixed

- Add `ca-certificates` in the build stage so `wget` can trust the GitHub TLS
  certificate when fetching the `squid-6.14.tar.bz2` release.

## [0.3.1] - 2025-11-19

### Fixed

- Download the `squid-6.14.tar.bz2` release, verify it against the published
  SHA256 checksum, and unpack it so the build stage always uses the same source
  archive.

## [0.3.0] - 2025-11-19

### Changed

- Switch the build to download Squid 6.14 from the `SQUID_6_14` GitHub release,
  make the version/tag configurable via build arguments, and keep copying the
  runtime `/etc` tree into the slim image.

## [0.2.1] - 2025-11-19

### Fixed

- Copy the build-generated `/etc` tree instead of `/var` so multi-arch builds
  can merge files without conflicting against runtime `/var` directories.

## [0.2.0] - 2025-11-19

### Changed

- Switch the Dockerfile to a Debian Bookworm multi-stage build that compiles
  Squid 6.10 from source in the build stage and ships the result on Debian
  Bookworm-slim.

## [0.1.0] - 2025-11-19

### Added

- Initial Debian-based Squid 6 container documentation (AGENTS.md, README.md,
  SPECIFICATION.md, and DockerHub.md reflecting the multi-stage build).
