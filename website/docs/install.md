---
sidebar_position: 2
title: Install
description: Deploy ISOO with Docker Compose
---

# Install

**Audience:** platform / infrastructure teams deploying ISOO on a server or developer machine.

## Prerequisites

- Docker and Docker Compose
- Ports **9292** (app), **8080** (Zitadel console), **1080** (MailCatcher, dev only)

## Quickstart

From the ISOO repository root:

```bash
docker compose build
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app ruby bin/init-data-git
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed
docker compose up -d
```

First boot can take **1–2 minutes** while Zitadel initializes and the entrypoint registers the OIDC client (`docker/zitadel/oidc.env`).

| URL | Service |
|-----|---------|
| http://localhost:9292 | ISOO |
| http://localhost:8080 | Zitadel console |
| http://localhost:1080 | MailCatcher (dev email) |

Default Zitadel admin (dev only): `admin@zitadel.localhost` / `Password1!`

After seeding, open http://localhost:9292/projects/demo .

## Data git repository

ISOO versions project files with **local git commits** under `data/`. Initialise once:

```bash
docker compose run --rm --no-deps app ruby bin/init-data-git
```

No remote is required. See [Git integration](./git-integration.md) for optional push/sync.

## Production notes

- Set strong `SESSION_SECRET` (64+ bytes) and `ENCRYPTION_SECRET` — see [Configuration](./configuration.md).
- Keep `AUTH_DISABLED=0` and configure corporate OIDC or the bundled Zitadel — see [Authentication](./authentication.md).
- Mount `data/` on persistent storage.
- Health checks: `GET /health/live`, `GET /health/ready`, metrics at `GET /metrics` (unauthenticated).

## App without full Compose stack

For local development without Zitadel:

```bash
docker compose run --rm --no-deps -e AUTH_DISABLED=1 -p 9292:9292 app bundle exec rackup -o 0.0.0.0 -p 9292
```

## Validate templates

Before shipping template changes or setting a custom `TEMPLATE_ID`:

```bash
docker compose run --rm --no-deps app bundle exec rake isoo:validate_templates
```

See [Templates](./templates.md) for creating your own bundle.

## See also

- [Configuration](./configuration.md)
- [Authentication](./authentication.md)
- [Seeding](./seeding.md)
