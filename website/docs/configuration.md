---
sidebar_position: 3
title: Configuration
description: Environment variables reference for ISOO
---

# Configuration

**Audience:** operators wiring ISOO into existing infrastructure (identity, cache, secrets, git remotes).

Copy `.env.example` to `.env` and adjust. Docker Compose reads these variables for the `app` service.

## Application core

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATA_PATH` | no | `tmp/data` (repo root) | Root for project instances and nested git. Templates stay in `data/templates/`. In Docker: `/app/tmp/data`. |
| `TEMPLATES_PATH` | no | `data/templates` (repo root) | Read-only template bundles (tracked in this repo). |
| `RACK_ENV` | no | `development` | `production` enables template view caching. |
| `PORT` | no | `9292` | Puma listen port. |
| `BIND` | no | `0.0.0.0` | Puma bind address. |
| `RACK_MAX_THREADS` | no | `5` | Puma thread pool. |
| `WEB_CONCURRENCY` | no | `0` | Puma workers (`0` = single process). |
| `ISOO_LOCALE` | no | `en` | UI locale (`config/locales/`). |

## Authentication and sessions

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `AUTH_DISABLED` | no | `0` | `1` bypasses OIDC entirely; fixed dev user. Use for CI/tests only in non-production. |
| `AUTH_ALLOWED_EMAIL_DOMAINS` | no | *(empty)* | Comma-separated email domains allowed to sign in (e.g. `voca.city,example.com`). Empty = allow all domains. Checked on callback and every request. |
| `SESSION_SECRET` | yes (prod) | dev default in Compose | Rack session signing secret. Use 64+ random bytes in production. |
| `SESSION_IDLE_TIMEOUT_SECONDS` | no | `7200` | Idle session expiry; expired users redirect to login. |

Details: [Authentication](./authentication.md). Step-by-step Zitadel example: [Zitadel (example IdP)](./zitadel.md).

## OIDC (OpenID Connect)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OIDC_ISSUER` | yes* | `http://localhost:8080` | **Browser-facing** issuer URL (discovery, authorize redirect). |
| `OIDC_ISSUER_INTERNAL` | no | `http://zitadel:8080` | **Server-side** issuer host for token exchange inside Docker network. |
| `OIDC_CLIENT_ID` | yes* | auto via entrypoint | OAuth client ID. Written to `docker/zitadel/oidc.env` on first boot. |
| `OIDC_CLIENT_SECRET` | yes* | auto via entrypoint | OAuth client secret. |
| `OIDC_REDIRECT_URI` | yes* | `http://localhost:9292/auth/callback` | Must match IdP app registration exactly. |

\* Not required when `AUTH_DISABLED=1`. With Docker Compose + Zitadel, client credentials are provisioned automatically unless you override for an external IdP.

Scopes requested: `openid email profile`. User email and name are stored in the Rack session.

## Confidential documents

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ENCRYPTION_SECRET` | yes (prod) | dev placeholder | Encrypts confidential `.md` / `.csv` as `.enc`. Plain `.audit.yaml` sidecars keep version metadata visible in git. |

Without `ENCRYPTION_SECRET`, confidential classification still works in dev but encryption is not enforced the same way.

## Memcached (optional)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MEMCACHE_SERVER` | no | `memcached:11211` in Compose | Host:port. **Empty string disables** Memcached; in-memory fallbacks used. |
| `MEMCACHE_NAMESPACE` | no | `isoo` | Key prefix for cache and presence when Memcached is enabled. |

When enabled: manifest/schema caching and cross-instance [document presence](./collaboration.md) use Memcached.

## Git remote sync (optional)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GIT_REMOTE_URL` | no | *(empty)* | Remote URL (`https://…` or `git@…`). Empty = local commits only. |
| `GIT_FORCE_PUSH` | no | *(empty)* | `1` pushes `origin main` with **force** after each commit when `GIT_REMOTE_URL` is set. |
| `GIT_AUTHOR_NAME` | no | `ISOO` | Git commit author name in the nested data repo. |
| `GIT_AUTHOR_EMAIL` | no | `isoo@local` | Git commit author email in the nested data repo. |

Details: [Git integration](./git-integration.md).

## Seeding

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SEED_PROJECT_SLUG` | no | `demo` | Project slug created by `rake isoo:seed`. |
| `SEED_PROJECT_NAME` | no | `Acme Open Source` | Display name. |
| `SEED_AUTHOR` | no | `seed@isoo.local` | Author on seeded commits. |
| `SEED_RESET` | no | *(unset)* | `1` deletes existing `SEED_PROJECT_SLUG` project before recreate. |
| `SEED_FORCE` | no | *(unset)* | `1` re-runs demo content population even if `.demo_seeded` marker exists. |

Details: [Seeding](./seeding.md).

## PDF export

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CHROME_NO_SANDBOX` | no | `1` in Docker image | Passed to headless Chrome (Ferrum). Set `1` in containers without sandbox privileges. |

## Template maintenance (rake)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TEMPLATE_ID` | no | `voca` | Template bundle under `data/templates/<id>/`. Used for **New project**, `isoo:seed`, `isoo:validate_templates`, and `isoo:sync_export_tags`. See [Templates](./templates.md). |

## See also

- [Templates](./templates.md)
- [Authentication](./authentication.md)
- [Git integration](./git-integration.md)
- [Install](./install.md)
