---
sidebar_position: 7
title: Table documents
description: CSV-backed registers with typed columns and soft delete
---

# Table documents

**Audience:** operators managing registers (assets, risks, legal requirements, etc.).

Table documents combine:

- A **markdown** file (metadata + version history in body after saves)
- A **`.csv`** data file with column headers from the schema
- A **`.schema.yaml`** with `kind: table`, column definitions, and types

## Column types

Schemas support typed columns including text, dates, booleans, URLs, **`textarea`** (markdown; supports `[ANNEX …]` BBCode — see [Document export](./document-export.md#annex-references)), and **`review_date`** (used by [Review](./review.md) to flag overdue rows).

Internal columns `_row_id` and `_deleted_at` are managed by the app and hidden from exports.

## Editing

- **Add row** — POST new row from the table UI or row wizard.
- **Edit row** — per-row page with patch save.
- **Delete row** — soft delete: sets `_deleted_at`; row stays in CSV but is hidden from UI and exports.

Table document saves (metadata / bulk fullscreen edit) require a **document changes** note and bump document version like text documents.

## Fullscreen editor

Tables with many rows support a fullscreen grid editor for bulk row edits in one save.

## CSV and encryption

Confidential tables encrypt the `.csv` as `.csv.enc` with the same `ENCRYPTION_SECRET` mechanism as text documents.

## Git

Row add/update/delete and table saves each commit to `data/`.

## See also

- [Document versioning](./document-versioning.md)
- [Review](./review.md)
- [Project export](./export.md)
- [Document export](./document-export.md)
