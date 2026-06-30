---
sidebar_position: 5
title: Templates
description: Create and configure OKF template bundles for new projects
---

# Templates

**Audience:** operators and compliance leads who maintain the document set shipped to every new ISMS project.

ISOO does not ship a document editor for arbitrary structure at runtime. Instead, each **template bundle** under `data/templates/<template-id>/` defines the full OKF tree (markdown, schemas, manifest). **New project** copies one bundle into `data/projects/<slug>/` and resets versions and table data.

The bundled **voca** template is the default ISO 27001 starter set. Fork it for your organisation or build a smaller bundle from scratch.

## Template bundle layout

```
data/templates/<template-id>/
  manifest.yaml              # bundle id, display name, document index
  export_tags.yaml           # scoped export tag definitions
  guidance/
    descriptions.yaml        # optional dashboard blurbs per doc_id
  context/                   # example folder — any path segment works
    organisation-overview/
      organisation-overview.md
      organisation-overview.schema.yaml
      organisation-overview.csv          # tables only
  policies/
  registers/
  audit/
  …
```

| File | Role |
|------|------|
| `manifest.yaml` | Lists every document slot: `doc_id`, `path`, `kind`, `seq`, `title`. Optional `id` and `name` identify the bundle. |
| `{doc-id}.md` | Front matter (`iso27001`, `classification`, …) + body. Text docs use section headings that match the schema. |
| `{doc-id}.schema.yaml` | `kind: text`, `table`, or `form`. Drives the UI and validation. |
| `{doc-id}.csv` | Required for `kind: table` (header row + `_internal` columns). |
| `export_tags.yaml` | Tag ids used in `export_tags` on schemas and annex metadata. |
| `guidance/descriptions.yaml` | Optional map `doc_id →` short description on the project dashboard. |

Documents follow [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md): one directory per document, shared `doc_id` basename on `.md`, `.schema.yaml`, and `.csv`.

## Document kinds in `manifest.yaml`

| `kind` | Schema `kind` | Notes |
|--------|---------------|-------|
| `text` | `text` | `sections[]` with `key`, `label`, `level`, `field_type`, `editable`. |
| `table` | `table` | `primary_key`, `columns[]`, `_internal` (`_row_id`, `_deleted_at`). CSV header must match column keys + internal keys. |
| `form` | `form` | `response_kind: text` or `table`. Template includes stamp `.md`/`.csv` removed on project create; responses are created later from the template schema. |
| `file_annex` | `file_annex` | Optional in templates. Moved to `annexes[]` on create. Most deployments add annex slots after project creation instead. |

Set `seq` on manifest entries to control dashboard and [export](./export.md) ordering.

## Configure which template **New project** uses

Each ISOO deployment uses **one** template bundle for the **New project** button (not a per-project picker in the UI).

Set in `.env` or Docker Compose for the `app` service:

```bash
TEMPLATE_ID=my-org
```

| Variable | Default | Effect |
|----------|---------|--------|
| `TEMPLATE_ID` | `voca` | Directory `data/templates/<id>/` copied when creating a project from the UI or `rake isoo:seed` |

Restart the app after changing `TEMPLATE_ID`. The new-project modal shows the active template name and id.

**Requirements:**

- `data/templates/<TEMPLATE_ID>/` must exist.
- `manifest.yaml` must be valid — run `rake isoo:validate_templates` before go-live.

Existing projects are **not** affected. Each project keeps its own copy under `data/projects/<slug>/` with `id:` in `manifest.yaml` recording which bundle it came from (used for export tags and form response templates).

## Create your own template

### 1. Copy the starter bundle

```bash
cp -a data/templates/voca data/templates/my-org
```

Edit `data/templates/my-org/manifest.yaml`:

```yaml
---
id: my-org
name: My Organisation ISMS
documents:
  - doc_id: organisation-overview
    path: context/organisation-overview
    kind: text
    seq: 1
    title: Organisation Overview
  # …
```

The `id` field should match the directory name (`my-org`).

### 2. Trim or extend documents

- **Remove** documents: delete manifest entries and their directories.
- **Add** a text document: create `policies/my-policy/my-policy.md`, `my-policy.schema.yaml`, and add a manifest row.
- **Add** a table: include `.csv` with a header row matching `columns` + `_internal` keys (see voca registers for examples).
- **Add** a form: `kind: form`, `response_kind: text|table`, schema `kind: form`, plus stamp files (removed automatically on project create).

Keep `doc_id` stable (lowercase, hyphens). It appears in URLs, git commits, and `[ANNEX doc-id]` BBCode.

### 3. Export tags (optional)

Edit `export_tags.yaml` for your tag names, then assign tags on schemas:

```yaml
export_tags:
  - basic
  - data_protection
```

Or run the assigner after editing rules in code:

```bash
TEMPLATE_ID=my-org bundle exec rake isoo:sync_export_tags
```

### 4. Dashboard guidance (optional)

`guidance/descriptions.yaml`:

```yaml
organisation-overview: |
  Short blurb shown on the project dashboard under this document.
```

### 5. Validate

```bash
TEMPLATE_ID=my-org bundle exec rake isoo:validate_templates
```

Fixes manifest/schema/CSV mismatches before any project uses the bundle.

### 6. Deploy

1. Set `TEMPLATE_ID=my-org` in production `.env`.
2. Ensure `data/templates/my-org/` is on the server (tracked in the app image or mounted volume).
3. Restart ISOO.
4. Create a test project from the UI and walk through text, table, and form flows.

## What happens on **New project**

`ProjectCreator` (see `app/services/project_creator.rb`):

1. Copies `data/templates/<TEMPLATE_ID>/` → `data/projects/<slug>/`.
2. Sets `manifest.yaml` `name` from the form; preserves `id` from the template.
3. Resets every document to version `0.1.0` in front matter.
4. Clears table CSVs to **header row only**.
5. Moves `kind: form` entries to `forms[]` and deletes form stamp files.
6. Moves `kind: file_annex` entries to `annexes[]` if present.
7. Encrypts confidential documents when `ENCRYPTION_SECRET` is set.
8. Commits to the `data/` git repo.

Annexes are usually **empty** on new projects unless your template includes `file_annex` entries or you use [seeding](./seeding.md).

## Changing templates after projects exist

| Change | Effect |
|--------|--------|
| Edit template files | Only **new** projects get the update. |
| Edit a live project | Change files under `data/projects/<slug>/` directly (schemas, markdown). |
| Re-sync from template | Not automatic — copy changes manually or recreate the project. |

See also the README section on [changing text document structure](https://github.com/voca/isoo/blob/main/README.md#changing-text-document-structure) for schema edits on existing projects.

## Maintenance commands

```bash
# Validate active template (TEMPLATE_ID or voca)
bundle exec rake isoo:validate_templates

# Validate a specific bundle
TEMPLATE_ID=my-org bundle exec rake isoo:validate_templates

# Sync export_tags from assigner rules into template schemas
TEMPLATE_ID=my-org bundle exec rake isoo:sync_export_tags
```

In Docker:

```bash
docker compose run --rm --no-deps -e TEMPLATE_ID=my-org app bundle exec rake isoo:validate_templates
```

## See also

- [Configuration](./configuration.md) — `TEMPLATE_ID`, `DATA_PATH`
- [Seeding](./seeding.md) — demo content on top of the voca template
- [Text documents](./text-documents.md) — section schema reference
- [Table documents](./table-documents.md) — column types
- [Forms](./forms.md) — form templates and responses
- [Project export](./export.md) — `export_tags` and scopes
