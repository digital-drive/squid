# CHANGELOG

# [1.2.4](/compare/v1.2.3...v1.2.4) (2025-11-25)

### Bug Fixes

* update caching configuration to use aufs for improved concurrency 614d14a
* remove the deprecated custom `acl manager` definition now that Squid ships it as a built-in, silencing upgrade warnings

### Features

* add logging service for squid to manage access and cache logs
* add placeholder configuration file and include directive for drop-in snippets
* add release process guidelines and SKIP_LOCAL_BUILD option to scripts
* enhance Dockerfile to include OpenSSL support and SSL certificate generation

## [1.2.3](/compare/v1.2.2...v1.2.3) (2025-11-24)

### Bug Fixes

* update healthcheck to use cache_object endpoint and adjust squid.conf for improved access control

## [1.2.2](/compare/v1.2.1...v1.2.2) (2025-11-24)

### Bug Fixes

* enhance Squid configuration and initialization for improved directory management and access control
* make the Docker healthcheck hit `cache_object://127.0.0.1/info` and expose that manager action via a scoped `cachemgr_passwd` rule so the probe returns `200 OK` from localhost

## [1.2.1](/compare/v1.2.0...v1.2.1) (2025-11-24)

### Bug Fixes

* update healthcheck configuration and enhance squid.conf for manager access control

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
* Added an upstream healthcheck (`squidclient cache_object://127.0.0.1/info`), CONTRIBUTING guide, and GPL-3.0-or-later license reference so the image is documented and ready for publication.
