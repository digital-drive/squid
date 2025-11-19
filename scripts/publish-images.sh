#!/usr/bin/env bash
set -euo pipefail

IMAGE_BASE="digitaldriveio/squid"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER_NAME="${BUILDER_NAME:-dns-healthcheck-builder}"

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  exit 1
fi

IFS='.' read -r MAJOR MINOR _ <<<"$VERSION"
MINOR_TAG="${MAJOR}"
if [[ -n "${MINOR:-}" ]]; then
  MINOR_TAG="${MAJOR}.${MINOR}"
fi

if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx use "$BUILDER_NAME" >/dev/null
else
  docker buildx create --name "$BUILDER_NAME" --use >/dev/null
fi

docker buildx build \
  --platform "$PLATFORMS" \
  -t "${IMAGE_BASE}:${VERSION}" \
  -t "${IMAGE_BASE}:${MINOR_TAG}" \
  -t "${IMAGE_BASE}:${MAJOR}" \
  --push \
  .
