#!/bin/bash
set -euo pipefail

# Writable paths (localstorage; Cloudron base convention)
mkdir -p /app/data/cache /app/data/config /run/activepieces
chown -R cloudron:cloudron /app/data /run/activepieces

# Public URL: Cloudron provides origin for redirects and webhooks
if [ -n "${CLOUDRON_APP_ORIGIN:-}" ]; then
  export AP_FRONTEND_URL="${CLOUDRON_APP_ORIGIN}"
else
  export AP_FRONTEND_URL="https://${CLOUDRON_APP_DOMAIN:-localhost}"
fi

# ---- PostgreSQL (vector extension supported on Cloudron postgres addon) ----
export AP_POSTGRES_HOST="${CLOUDRON_POSTGRESQL_HOST:-}"
export AP_POSTGRES_PORT="${CLOUDRON_POSTGRESQL_PORT:-}"
export AP_POSTGRES_DATABASE="${CLOUDRON_POSTGRESQL_DATABASE:-}"
export AP_POSTGRES_USERNAME="${CLOUDRON_POSTGRESQL_USERNAME:-}"
export AP_POSTGRES_PASSWORD="${CLOUDRON_POSTGRESQL_PASSWORD:-}"

# Optional single URL (Activepieces supports this; overrides above when set in app)
# leave unset when using discrete vars; CLOUDRON_POSTGRESQL_URL is not read by app directly

# ---- Redis ----
export AP_REDIS_URL="${CLOUDRON_REDIS_URL:-}"

# ---- Outbound email (sendmail addon): use env only when all required vars are set ----
# https://www.activepieces.com/docs/install/configuration/environment-variables
if [ -n "${CLOUDRON_MAIL_SMTP_SERVER:-}" ] && [ -n "${CLOUDRON_MAIL_SMTP_PORT:-}" ] && \
   [ -n "${CLOUDRON_MAIL_SMTP_USERNAME:-}" ] && [ -n "${CLOUDRON_MAIL_SMTP_PASSWORD:-}" ]; then
  export AP_SMTP_HOST="${CLOUDRON_MAIL_SMTP_SERVER}"
  export AP_SMTP_PORT="${CLOUDRON_MAIL_SMTP_PORT}"
  export AP_SMTP_USERNAME="${CLOUDRON_MAIL_SMTP_USERNAME}"
  export AP_SMTP_PASSWORD="${CLOUDRON_MAIL_SMTP_PASSWORD}"
  if [ -n "${CLOUDRON_MAIL_FROM:-}" ]; then
    export AP_SMTP_SENDER_EMAIL="${CLOUDRON_MAIL_FROM}"
  else
    export AP_SMTP_SENDER_EMAIL="no-reply@${CLOUDRON_APP_DOMAIN:-app.localhost}"
  fi
  if [ -n "${CLOUDRON_MAIL_FROM_DISPLAY_NAME:-}" ]; then
    export AP_SMTP_SENDER_NAME="${CLOUDRON_MAIL_FROM_DISPLAY_NAME}"
  fi
fi

# ---- Core runtime (matches our packaging defaults) ----
export AP_PORT="${AP_PORT:-8000}"
export AP_ENVIRONMENT=prod
# Cloudron: no CAP_SYS_ADMIN / cgroups for isolate sandbox; keep UNSANDBOXED (see README).
export AP_EXECUTION_MODE="${AP_EXECUTION_MODE:-UNSANDBOXED}"
export AP_CONFIG_PATH="${AP_CONFIG_PATH:-/app/data/config}"
export AP_CONTAINER_TYPE=WORKER_AND_APP

# Persist long-lived secrets in /app/data (backed up with localstorage)
if [ ! -f /app/data/config/.secrets ]; then
  umask 077
  AP_ENCRYPTION_KEY=$(openssl rand -hex 16)
  AP_JWT_SECRET=$(openssl rand -hex 32)
  {
    echo "AP_ENCRYPTION_KEY=${AP_ENCRYPTION_KEY}"
    echo "AP_JWT_SECRET=${AP_JWT_SECRET}"
  } > /app/data/config/.secrets
  chown cloudron:cloudron /app/data/config/.secrets
  chmod 600 /app/data/config/.secrets
fi
set -a
# shellcheck source=/dev/null
. /app/data/config/.secrets
set +a

# Enable pgvector on first start (idempotent; extension is allowlisted on Cloudron postgres)
if command -v psql >/dev/null 2>&1 && [ -n "${AP_POSTGRES_HOST}" ] && [ -n "${AP_POSTGRES_PASSWORD}" ]; then
  PGPASSWORD="${AP_POSTGRES_PASSWORD}" psql -h "${AP_POSTGRES_HOST}" -p "${AP_POSTGRES_PORT:-5432}" \
    -U "${AP_POSTGRES_USERNAME}" -d "${AP_POSTGRES_DATABASE}" \
    -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
fi

cd /usr/src/app
exec gosu cloudron:cloudron /usr/src/app/docker-entrypoint.sh
