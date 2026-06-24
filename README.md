# Activepieces for Cloudron

Unofficial [Cloudron](https://www.cloudron.io/) packaging for [Activepieces](https://github.com/activepieces/activepieces) — an open source workflow / automation platform (Zapier-style) with a visual builder, 200+ integrations, and optional AI features.

**This repository** does not fork Activepieces. The container image reuses the official `ghcr.io/activepieces/activepieces` build artifacts on top of `cloudron/base:5.0.0` (required for Cloudron), with a `start.sh` that maps [Cloudron addon](https://docs.cloudron.io/packaging/addons/) environment variables to Activepieces’ `AP_*` settings.

## What you get

| Layer | Role |
|--------|------|
| **PostgreSQL** (addon) | App database. The `vector` extension is enabled on startup for AI / vector features. |
| **Redis** (addon) | Job queue and related state. |
| **Local storage** (addon) | `/app/data` (cache symlink, generated secrets, config). |
| **Sendmail** (addon) | Outbound SMTP for invites and password reset (optional; all four SMTP env vars must be set for Activepieces to use them). |

**Execution mode** defaults to `UNSANDBOXED` so flows run under Cloudron’s container limits. Stricter sandbox modes may need extra Linux capabilities and are not enabled here (see [Activepieces sandboxing](https://www.activepieces.com/docs/install/architecture/sandboxing)).

## Install

### End users (recommended): install from published `CloudronVersions.json`

The package is published through a version catalog file:

- Catalog URL: `https://raw.githubusercontent.com/benneic/cloudron-activepieces/main/CloudronVersions.json`

Choose one install path:

1. **Cloudron dashboard (Community Apps)**
   - Open Cloudron dashboard as admin.
   - Go to **App Store** -> **Community Apps**.
   - Add the catalog URL above.
   - Install **Activepieces** from the community list.

2. **Cloudron CLI**

   ```bash
   cloudron install --versions-url https://raw.githubusercontent.com/benneic/cloudron-activepieces/main/CloudronVersions.json
   ```

### Maintainers / developers: build from source

Use this flow only if you are developing this package locally.

1. **Clone** this repository:

   ```bash
   git clone <your-fork-or-upstream-url> activepieces-cloudron
   cd activepieces-cloudron
   ```

2. **Build the image** without pushing to a registry (on first run the CLI may ask for a project name; it is only used to label the build):

   ```bash
   cloudron build --no-push
   ```

3. **Install** the app on your Cloudron (from the same directory, with `CloudronManifest.json` present). Pick location, domain, and addons in the wizard as usual:

   ```bash
   cloudron install
   ```

### Update

After new commits (for example a bump to `AP_VERSION` in the `Dockerfile` and `version` in `CloudronManifest.json`):

1. **Pull** the latest `main` (or your release branch).

   ```bash
   git pull
   ```

2. **Rebuild** the image, still without pushing a registry build:

   ```bash
   cloudron build --no-push
   ```

3. **Update** the already-installed app to use the new image the CLI just built:

   ```bash
   cloudron update
   ```

## First run and security

- The **first user to register** becomes the **platform admin** (Activepieces’ own user database).
- This package does **not** use the Cloudron `proxyauth` addon, so the login page is world-reachable on your app URL. Hardening options:
  - Use **SAML / Google / GitHub** under Activepieces *Platform → SSO* where your edition allows it, or
  - Put the app behind a VPN, or
  - Install a second app with `proxyauth` in front (advanced; not part of this manifest).
- `AP_*` secrets are generated once under `/app/data/config` and persist across restarts and backups.

## Configuration

Read Activepieces’ [environment variables](https://www.activepieces.com/docs/install/configuration/environment-variables) for the full list. For Cloudron, pass overrides with:

```bash
cloudron env set --app your.activepieces.domain AP_TELEMETRY_ENABLED=false
```

Useful flags:

| Variable | Notes |
|----------|--------|
| `AP_TELEMETRY_ENABLED` | Set `false` to opt out. |
| `AP_EXECUTION_MODE` | Default `UNSANDBOXED`; other modes may not work on Cloudron. |
| `AP_WEBHOOK_TIMEOUT_SECONDS` | Webhook timeout (default 30). |

`AP_FRONTEND_URL` is set from `CLOUDRON_APP_ORIGIN` (or `https://$CLOUDRON_APP_DOMAIN`) in `start.sh` — do not set it unless you know you need a different public URL for webhooks.

## Backups and updates

- Cloudron [backups](https://docs.cloudron.io/backups/) include the PostgreSQL and Redis **addons** and the **local storage** volume, so your DB, queue state, and `/app/data` stay consistent with restores.
- If you installed from the community catalog URL, update from the Cloudron dashboard once a newer catalog version is available.
- For **rebuilding and shipping a new version of this package**, use the [Install / Update](#install) flow (`git pull`, `cloudron build --no-push`, `cloudron update`) after you have aligned `Dockerfile` and `CloudronManifest.json` with the Activepieces version you want.
- Catalog publishing and registry images are handled by [upstream-watch.yml](.github/workflows/upstream-watch.yml) (see [Automation](#automation-in-this-repo)); use a local `cloudron build` only when you need to test packaging changes before they land on `main`.

## Automation in this repo

[upstream-watch.yml](.github/workflows/upstream-watch.yml) checks [activepieces/activepieces](https://github.com/activepieces/activepieces) for a newer semver every Monday (06:00 UTC), or on demand via **Actions → Upstream release watch → Run workflow**. When needed it bumps `main`, builds and pushes `ghcr.io/…/activepieces-cloudron:<ver>`, runs [scripts/verify-image-tools.sh](scripts/verify-image-tools.sh), commits the new entry to [CloudronVersions.json](CloudronVersions.json), and pushes tag `vX.Y.Z`. If `main` already matches upstream but the catalog entry is missing, it builds and publishes without re-bumping.

**Requirements:** In GitHub → Settings → Actions → General, set workflow permissions to **Read and write**. If `main` has branch protection, allow `github-actions[bot]` to bypass or push directly.

**Publishing a version locally** (without CI):

```bash
docker buildx build -t YOUR_REGISTRY/activepieces:0.82.1 --build-arg AP_VERSION=0.82.1 --push .
npm ci
node scripts/publish-version.mjs 'YOUR_REGISTRY/activepieces:0.82.1'
```

## Troubleshooting

| Issue | What to do |
|-------|------------|
| Unhealthy in dashboard | `cloudron logs --app <fqdn> -f`; the manifest `healthCheckPath` is `/api/v1/health` (2xx = healthy). |
| DB / migrations | `cloudron exec --app <fqdn> -- bash -c 'psql "..."'` using addon vars from `printenv \| grep POSTGRES` |
| pgvector errors | `CREATE EXTENSION vector` is run in `start.sh`; ensure the postgres addon is provisioned. |
| `promisify(undefined)` / `file-compressor.ts` / `ERR_INVALID_ARG_TYPE` | The app must run on **Node 24+** (see `start.sh` `PATH` and the Dockerfile). `cloudron/base` ships Node 22 first on `PATH`; this package prepends the distro Node from NodeSource. Rebuild and update. |
| Code step: `spawn esbuild ENOENT` / `Compilation Error` | Code steps need upstream global CLIs (**esbuild**, **bun**, etc.). The Dockerfile copies them from `ghcr.io/activepieces/activepieces:${AP_VERSION}`; rebuild and `cloudron update`. Stale failed artifacts under `/app/data/cache/.../codes/` are rewritten on the next run. |

## Smoke testing

See [docs/SMOKE_TESTING.md](docs/SMOKE_TESTING.md).

## License

- This packaging: [LICENSE](LICENSE) in this repo (MIT unless stated otherwise in [LICENSE](LICENSE)).
- [Activepieces](https://github.com/activepieces/activepieces) Community Edition is [MIT](https://github.com/activepieces/activepieces/blob/main/LICENSE). Enterprise / commercial features are per upstream.

Replace placeholder maintainer fields in [CloudronManifest.json](CloudronManifest.json) (`packagerName`, `packagerUrl`, `contactEmail`, and optionally `iconUrl` / `mediaLinks`) before publishing a community app listing.
