# Cloudron image: reuse upstream published image for /usr/src/app + isolate config.
# Final stage must use cloudron/base per https://docs.cloudron.io/packaging/guidelines/

ARG AP_VERSION=0.82.1
FROM ghcr.io/activepieces/activepieces:${AP_VERSION} AS upstream

FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c

ARG AP_VERSION=0.82.1
LABEL org.opencontainers.image.title="Activepieces (Cloudron)"
LABEL org.opencontainers.image.version="${AP_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/activepieces/activepieces"

# Match upstream: Node 24.14, deps for engine/pieces, psql for pgvector bootstrap
RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg postgresql-client \
    poppler-utils poppler-data procps locales \
    python3 g++ make build-essential git unzip \
    libcap-dev \
  && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

# Bun (used by some upstream tooling) — keep binary from upstream image
COPY --from=upstream /usr/local/bin/bun /usr/local/bin/bun
RUN chmod +x /usr/local/bin/bun

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

RUN npm install -g --no-fund --no-audit pm2@6.0.10

RUN mkdir -p /app/code

COPY start.sh /app/code/start.sh
RUN chmod +x /app/code/start.sh

# Activepieces serves HTTP; Cloudron terminates TLS. Port must match httpPort in manifest.
EXPOSE 8000

# Cloudron start script: maps addon env, drops privileges, runs upstream entrypoint
CMD [ "/app/code/start.sh" ]
