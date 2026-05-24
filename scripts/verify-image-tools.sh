#!/usr/bin/env bash
# Verify runtime CLIs required by Activepieces exist in a built Cloudron image.
# Fails the build if upstream adds/changes global tooling we failed to copy from the upstream stage.
set -euo pipefail

IMAGE="${1:?usage: verify-image-tools.sh <image>}"
AP_VERSION="${2:?usage: verify-image-tools.sh <image> <ap_version>}"

UPSTREAM="ghcr.io/activepieces/activepieces:${AP_VERSION}"

echo "Checking ${IMAGE} against upstream ${UPSTREAM}..."

UPSTREAM_BINS=$(
  docker run --rm "${UPSTREAM}" sh -c '
    for f in /usr/local/bin/*; do
      name=$(basename "$f")
      case "$name" in node|nodejs) continue ;; esac
      echo "$name"
    done' | sort -u
)

MISSING=0
while IFS= read -r bin; do
  [[ -z "${bin}" ]] && continue
  if ! docker run --rm "${IMAGE}" sh -c "command -v '${bin}' >/dev/null"; then
    echo "MISSING in Cloudron image: ${bin} (present in upstream /usr/local/bin)" >&2
    MISSING=1
  fi
done <<< "${UPSTREAM_BINS}"

docker run --rm "${IMAGE}" sh -c '
  set -e
  pm2-runtime --version >/dev/null
  esbuild --version >/dev/null
  bun --version >/dev/null
  node -v | grep -q "^v24"
'

if [[ "${MISSING}" -ne 0 ]]; then
  echo "Runtime CLI check failed. Ensure Dockerfile copies upstream /usr/local/lib/node_modules and /usr/local/bin (except node)." >&2
  exit 1
fi

echo "Runtime CLI check passed."
