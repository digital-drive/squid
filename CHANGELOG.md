# CHANGELOG

## [1.2.0](/compare/v1.1.3...v1.2.0) (2025-11-24)

### Bug Fixes

* enhance squid.conf with additional ACLs and healthcheck access rules

## [1.1.3](/compare/v1.1.2...v1.1.3) (2025-11-24)

### Bug Fixes

* update squid.conf to open to localnet access and improve healthcheck configuration

 [1.1.2](/compare/v1.1.1...v1.1.2) (2025-11-24)

### Bug Fixes

* add missing http_port directive to squid configuration

## [1.1.1](/compare/v1.1.0...v1.1.1) (2025-11-24)

### Bug Fixes

* add missing runtime dependencies to Dockerfile 897191e
* remove unnecessary liblber-2.5-0 dependency from Dockerfile

## [1.1.0](/compare/v1.0.0...v1.1.0) (2025-11-24)

### Bug Fixes

* update Dockerfile to include additional dependencies for build process
* remove unnecessary dependencies from Dockerfile

## 1.0.0 (2025-11-21)

* Introduced the Squid 6.14 multi-stage Debian Bookworm build, documenting its features, configuration guidance, and licensing across README, SPECIFICATION, AGENTS, and DockerHub.
* Added an upstream healthcheck (`squidclient mgr:info`), CONTRIBUTING guide, and GPL-3.0-or-later license reference so the image is documented and ready for publication.
