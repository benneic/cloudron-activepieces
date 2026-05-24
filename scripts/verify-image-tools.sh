#!/usr/bin/env bash
# Verify runtime CLIs required by Activepieces exist in a built Cloudron image.
# Fails the build if upstream adds/changes global tooling we failed to copy from the upstream stage.
set -euo pipefail

IMAGE="${1:?usage: verify-image-tools.sh <image>}"
AP_VERSION="${2:?usage: verify-image-tools.sh <image> <ap_version>}"

UPSTREAM="ghcr.io/activepieces/activepieces:${AP_VERSION}"

echo "Checking ${IMAGE} against upstream ${UPSTREAM}..."

docker pull "${UPSTREAM}" >/dev/null
docker pull "${IMAGE}" >/dev/null

UPSTREAM_BINS=$(
  docker run --rm "${UPSTREAM}" sh -c '
    for f in /usr/local/bin/*; do
      name=$(basename "$f")
      case "$name" in node|nodejs) continue ;; esac
      echo "$name"
    done' | sort -u
)

CHECK_SCRIPT=$(
  cat <<'EOS'
set -e
pm2-runtime --version >/dev/null
esbuild --version >/dev/null
bun --version >/dev/null
node -v | grep -q "^v24"
EOS
)

while IFS= read -r bin; do
  [[ -z "${bin}" ]] && continue
  CHECK_SCRIPT+="command -v '${bin}' >/dev/null || { echo 'MISSING: ${bin}' >&2; exit 1; }"$'\n'
done <<< "${UPSTREAM_BINS}"

echo "${CHECK_SCRIPT}" | docker run --rm -i "${IMAGE}" sh -s

echo "Runtime CLI check passed."
