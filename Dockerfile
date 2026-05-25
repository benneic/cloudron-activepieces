# Cloudron image: reuse upstream published image for /usr/src/app + isolate config.
# Final stage must use cloudron/base per https://docs.cloudron.io/packaging/guidelines/

ARG AP_VERSION=0.83.1
FROM ghcr.io/activepieces/activepieces:${AP_VERSION} AS upstream

FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c
ARG AP_VERSION=0.83.1

LABEL org.opencontainers.image.title="Activepieces (Cloudron)"
LABEL org.opencontainers.image.version="${AP_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/activepieces/activepieces"

# Match upstream: Node 24, deps for engine/pieces, psql for pgvector bootstrap.
# Force /usr/bin first for this RUN so `npm`/`node` are Node 24, not base image’s Node 22.
RUN set -eux; \
  export PATH="/usr/bin:/usr/local/bin:${PATH}"; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg postgresql-client \
    poppler-utils poppler-data procps locales \
    python3 g++ make build-essential git unzip \
    libcap-dev \
  && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && node -e "if(+process.versions.node.split('.')[0]<24) process.exit(1)" \
  && rm -rf /var/lib/apt/lists/*

# Bun and other global CLIs are copied from upstream below (after /usr/local/lib/node_modules).

# Upstream isolates user code; config used when execution is sandboxed
COPY --from=upstream /usr/local/etc/isolate /usr/local/etc/isolate

# isolated-vm lives under /usr/src in upstream base image
COPY --from=upstream /usr/src/node_modules /usr/src/node_modules

# Application tree (built app + production node_modules, trimmed pieces, web dist)
COPY --from=upstream /usr/src/app /usr/src/app

# Writable cache: persist under /app/data
RUN set -eux; \
  rm -rf /usr/src/app/cache; \
  mkdir -p /app/data/cache; \
  ln -s /app/data/cache /usr/src/app/cache

# Upstream base image installs global npm CLIs (pm2, esbuild, node-gyp, …). Copy them from the
# upstream image so versions track AP_VERSION instead of duplicating pinned installs here.
COPY --from=upstream /usr/local/lib/node_modules/ /usr/local/lib/node_modules/
RUN --mount=from=upstream,source=/usr/local/bin,target=/upstream-bin,ro \
  set -eux; \
  for f in /upstream-bin/*; do \
    name=$(basename "$f"); \
    case "$name" in node|nodejs) continue ;; esac; \
    cp -a "$f" "/usr/local/bin/$name"; \
  done; \
  command -v pm2-runtime; \
  command -v esbuild; \
  command -v bun

RUN mkdir -p /app/code

COPY start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Activepieces serves HTTP; Cloudron terminates TLS. Port must match httpPort in manifest.
EXPOSE 8000

# Cloudron start script: maps addon env, drops privileges, runs upstream entrypoint
CMD [ "/app/code/start.sh" ]
