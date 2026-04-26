# Activepieces for Cloudron

[Activepieces](https://www.activepieces.com/) is an open source workflow automation platform: connect apps, run scheduled or event-driven automations, and use AI pieces with a visual builder. This package runs the **Community Edition** in a single Cloudron app container.

**What you get**

- **Managed data**: Cloudron [PostgreSQL](https://docs.cloudron.io/packaging/addons/) (with the `vector` extension for AI features), [Redis](https://docs.cloudron.io/packaging/addons/) for the job queue, and [local storage](https://docs.cloudron.io/packaging/addons/) for cache and app-owned files on disk.
- **Email**: optional [Sendmail](https://docs.cloudron.io/packaging/addons/) addon for outbound SMTP (password reset, invites), mapped to Activepieces’ SMTP settings.
- **Sensible defaults**: one process runs both the API and the worker (`WORKER_AND_APP`); public URL and database URLs are read from Cloudron on every start.

**Relationship to upstream**

This is *unofficial* packaging. The application code is built from the upstream [activepieces/activepieces](https://github.com/activepieces/activepieces) image; this repository only adds a Cloudron base image, startup script, and manifest. Report product bugs to Activepieces; report packaging issues to this repo’s issue tracker.

**Licensing**

Activepieces Community Edition is [MIT](https://github.com/activepieces/activepieces/blob/main/LICENSE). Check upstream for enterprise / commercial features.
