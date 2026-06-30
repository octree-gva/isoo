---
sidebar_position: 6
title: Text documents
description: Structured markdown documents with schema-driven sections
---

# Text documents

**Audience:** compliance operators and IT staff supporting document owners.

Text documents are **schema-driven markdown**: each document has a `.schema.yaml` defining labelled sections (`h1`/`h2`/`h3`). The UI renders one form field per editable section; saves rewrite the markdown body while preserving structure.

## Storage layout

```
context/organisation-overview/
  organisation-overview.md
  organisation-overview.schema.yaml
  organisation-overview.audit.yaml    # when confidential + encrypted
```

Front matter in `.md` holds ISO metadata (`iso27001.version`, `classification`, `doc_id`, etc.). Body holds section headings and content only—no static version-control table in templates.

## Editing

- Open a text document from the project dashboard.
- Edit fields; click **Save** and enter **document changes** (required audit note).
- Optional **significant change** checkbox bumps the **minor** semver (e.g. `0.1.0` → `0.2.0`); otherwise **patch** bump (`0.1.0` → `0.1.1`).

## Classification

Documents marked **Confidential** in front matter are encrypted at rest when `ENCRYPTION_SECRET` is set (`.md.enc`). A plain `.audit.yaml` sidecar exposes version and last-modified metadata in git.

## Form responses

Form templates produce **text** (or table) responses under `…/responses/<form-id>-N/`. They use the same editor and save flow with an extra **document title** field. See [Forms](./forms.md).

## Git

Each save triggers a local git commit in `data/` with message `{doc_id} v{version}: {changes}`.

## Textareas and annex references

Paste `[ANNEX doc-id]` into any textarea to reference an annex asset. Copy the BBCode from the asset’s **Share** section. Export behaviour is described in [Document export](./document-export.md#annex-references).

## See also

- [Annexes](./annexes.md)
- [Document export](./document-export.md)
- [Document versioning](./document-versioning.md)
- [Project export](./export.md)
- [Review](./review.md)
