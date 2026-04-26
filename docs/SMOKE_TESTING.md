# Smoke test checklist (Cloudron)

Use this after a build, before announcing a release.

## Prerequisites

- A Cloudron instance (9.1+; see `minBoxVersion` in [CloudronManifest.json](../CloudronManifest.json)).
- [Cloudron CLI](https://www.npmjs.com/package/cloudron) logged in: `cloudron login <your-server>`.
- Addons selected at install: **PostgreSQL**, **Redis**, **local storage**, **Sendmail** (or accept that email flows may not work without SMTP).

## Install

```bash
# From registry image
cloudron install --image ghcr.io/<owner>/activepieces-cloudron:0.82.1
```

or from a [CloudronVersions.json](../CloudronVersions.json) URL you host.

## Verify

1. **Open the app** in a browser. You should get the Activepieces sign-up or login page.
2. **Register the first user** and confirm the admin shell loads (left nav, “Platform” for admins).
3. **Run a small flow** (e.g. manual trigger or schedule) to confirm the worker and Redis.
4. **Check health**: `GET https://$DOMAIN/api/v1/health` (from your laptop) should return JSON with a healthy status once DB + Redis are connected.
5. **Logs**:
   ```bash
   cloudron logs --app <fqdn> -l 200
   ```
   — look for `Starting Activepieces with PM2` and no unhandled TypeORM/Redis connection errors.
6. **pgvector** (if you use AI pieces): `cloudron exec` + `psql` and `\dx` on the app database should list `vector`.
7. **Backup/restore (optional)**: from the Cloudron UI or CLI, run a one-off **Backup**, then test **Restore** on a clone or staging app to ensure PostgreSQL, Redis, and local storage are consistent (follow Cloudron’s restore docs for your version).

## Failure triage

| Symptom | Suggested check |
|--------|-------------------|
| 502 / crash loop | `cloudron status`, `cloudron logs`; confirm `memoryLimit` and addon provisioning. |
| 502 for minutes | Migrations; allow **first** boot 2–5 minutes on a cold DB. |
| “Could not connect to Redis/Postgres” | `cloudron env list` — addon vars should be non-empty. |
| Wrong webhook URL | `CLOUDRON_APP_ORIGIN` in container should match the URL you use; see `printenv` in `cloudron exec`. |
