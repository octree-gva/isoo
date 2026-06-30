---
sidebar_position: 1
slug: /
title: Overview
description: ISOO for IT services and infrastructure teams
---

# ISOO documentation

ISOO is a self-hosted web application for managing **ISO 27001 documentation** as files on disk. It targets teams who operate internal compliance infrastructure: platform engineers, IT services, and security operations who deploy apps, wire corporate identity, back up data, and need a clear audit trail.

## What you operate

| Component | Role |
|-----------|------|
| **ISOO app** | Ruby/Roda application (Puma), port **9292** by default |
| **Zitadel** | OIDC identity provider (Docker Compose default) |
| **PostgreSQL** | Zitadel database |
| **Memcached** | Optional cache for manifest reads and document presence |
| **Chrome (headless)** | PDF export via Ferrum |
| **`data/` git repo** | All project content; local commits on every write |

Documents follow [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md): markdown + per-document `.schema.yaml` + optional `.csv` tables.

## What ISOO is not

- Not a generic wiki or real-time collaborative editor ([Collaboration](./collaboration.md))
- Not a GRC SaaS replacement for risk workflows outside document storage
- Not multi-tenant: one deployment serves your organisation’s projects

## Documentation map

Each page describes **one capability** from an operator and power-user perspective:

1. [Install](./install.md) — Docker Compose quickstart
2. [Configuration](./configuration.md) — environment variables reference
3. [Templates](./templates.md) — create template bundles and set `TEMPLATE_ID`
4. [Authentication](./authentication.md) — OIDC, sessions, domain restrictions
5. [Seeding](./seeding.md) — demo project for smoke tests
6. [Text documents](./text-documents.md)
7. [Table documents](./table-documents.md)
8. [Forms](./forms.md)
9. [Annexes](./annexes.md) — file assets (diagrams, uploads)
10. [Document versioning](./document-versioning.md)
11. [Project export](./export.md) — full project Markdown, HTML, PDF with tag scopes
12. [Document export](./document-export.md) — single page export and annex BBCode references
13. [Review](./review.md) — stale documents and expired review dates
14. [Git integration](./git-integration.md) — commits, optional remote sync
15. [Collaboration](./collaboration.md) — what ISOO does **not** provide

## Build this site locally

```bash
cd website
npm install
npm start
```

Production build: `npm run build` (output in `website/build/`).
