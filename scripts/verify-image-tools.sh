#!/usr/bin/env bash
# Smoke-test runtime CLIs in a built Cloudron image.
# When the upstream image is given, also check every CLI it ships in /usr/local/bin exists in ours
# (upstream adds/removes global CLIs between releases, so no fixed list is hardcoded here).
set -euo pipefail

IMAGE="${1:?usage: verify-image-tools.sh <image> [upstream-image]}"
UPSTREAM="${2:-}"

echo "Checking runtime CLIs in ${IMAGE}..."

docker run --rm --entrypoint sh "${IMAGE}" -c '
  set -e
  export PATH="/usr/bin:/usr/local/bin:/bin:/usr/sbin:/sbin"
  for cmd in esbuild bun npm npx node-gyp; do
    command -v "$cmd" >/dev/null || { echo "Missing CLI: $cmd" >&2; exit 1; }
  done
  esbuild --version >/dev/null
  bun --version >/dev/null
  node -v | grep -q "^v24" || { echo "Expected Node 24, got $(node -v)" >&2; exit 1; }
'

if [ -n "${UPSTREAM}" ]; then
  echo "Checking /usr/local/bin parity with ${UPSTREAM}..."
  expected=$(docker run --rm --entrypoint sh "${UPSTREAM}" -c 'ls -1 /usr/local/bin' | grep -vxE 'node|nodejs' | sort)
  actual=$(docker run --rm --entrypoint sh "${IMAGE}" -c 'ls -1 /usr/local/bin' | sort)
  missing=$(comm -23 <(echo "${expected}") <(echo "${actual}"))
  if [ -n "${missing}" ]; then
    echo "CLIs present upstream but missing from image:" >&2
    echo "${missing}" >&2
    exit 1
  fi
fi

echo "Runtime CLI check passed."
