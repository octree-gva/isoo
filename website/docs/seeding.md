---
sidebar_position: 5
title: Seeding
description: Demo project and sample content for smoke tests
---

# Seeding

**Audience:** operators validating a fresh deployment or refreshing a demo environment.

`rake isoo:seed` creates (or refreshes) a **demo project** with sample text fields, table rows, form responses, and annex assets. It is intended for presentations and smoke tests—not for production ISMS content.

The seed task uses the same template as **New project** (`TEMPLATE_ID`, default `voca`). See [Templates](./templates.md).

## Run seeding

```bash
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed
```

Prerequisites:

- `bin/init-data-git` has been run (git repo under `data/`)
- Template bundle validates: `rake isoo:validate_templates`

## What seeding does

1. **Prunes** all projects under `data/projects/` except the seed slug (default `demo`).
2. **Creates** the project from the `voca` template if missing (`ProjectCreator`).
3. **Populates** content via `DemoSeeder` unless already seeded:
   - Text document fields (e.g. organisation overview, ISMS scope)
   - Table rows (legal register, risk register, assets, ROPA)
   - One response per empty form template

A marker file `.demo_seeded` in the project root prevents re-population unless forced.

## Environment variables

| Variable | Default | Effect |
|----------|---------|--------|
| `SEED_PROJECT_SLUG` | `demo` | Directory name under `data/projects/` |
| `SEED_PROJECT_NAME` | `Acme Open Source` | `manifest.yaml` display name |
| `SEED_AUTHOR` | `seed@isoo.local` | Git commit author for seed writes |
| `SEED_RESET` | — | `1` deletes the project directory before recreate |
| `SEED_FORCE` | — | `1` ignores `.demo_seeded` and re-applies demo content |

Examples:

```bash
# Recreate demo from scratch
SEED_RESET=1 docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed

# Re-fill tables/text without deleting project
SEED_FORCE=1 docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed
```

## Annex assets and templates

File annexes are **not** shipped in the voca template manifest. Seeding creates annex manifest entries, schemas, markdown metadata, and uploaded files in the **project** only. New projects created via the UI start with **zero annexes** until seeded or created manually.

## After seeding

The task prints tour URLs, e.g.:

- `/projects/demo`
- `/projects/demo/docs/organisation-overview`
- `/projects/demo/docs/legal-and-contractual-requirements-register`

## See also

- [Annexes](./annexes.md)
- [Install](./install.md)
- [Configuration](./configuration.md)
