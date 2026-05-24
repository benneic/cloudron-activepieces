#!/usr/bin/env bash
# Smoke-test runtime CLIs in a built Cloudron image.
# Upstream parity is enforced at build time by copying /usr/local from the upstream stage.
set -euo pipefail

IMAGE="${1:?usage: verify-image-tools.sh <image>}"

echo "Checking runtime CLIs in ${IMAGE}..."

docker run --rm "${IMAGE}" sh -c '
  set -e
  export PATH="/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin"
  for cmd in pm2 pm2-runtime esbuild bun npm npx tsc tsserver node-gyp; do
    command -v "$cmd" >/dev/null
  done
  pm2-runtime --version >/dev/null
  esbuild --version >/dev/null
  bun --version >/dev/null
  node -v | grep -q "^v24"
'

echo "Runtime CLI check passed."
