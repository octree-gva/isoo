---
sidebar_position: 12
title: Document export
description: Export a single text, table, form response, or annex page
---

# Document export

**Audience:** document owners who need one page as Markdown, HTML, or PDF without exporting the whole project.

From any **text document**, **table document**, **form response**, or **annex asset detail** page, use **Export** in the header (same position as project export on the dashboard).

## What is included

The export contains **only the current document**:

- Document title and metadata (version, classification, group)
- Version control table (rendered dynamically)
- Body content (text sections or table data + legend)
- For annex pages: embedded asset preview when the file is an image
- **Referenced annex assets** — see [Annex references](#annex-references) below

There is **no scope selector** — tag filtering does not apply to which document you export. You always get the page you are viewing.

## Formats

| Format | URL pattern | Notes |
|--------|-------------|-------|
| Markdown | `GET /projects/{slug}/docs/{doc_id}/export?format=md` | Single document |
| HTML | `…/export?format=html` | Print-styled, self-contained CSS |
| PDF | `…/export?format=pdf` | Headless Chrome via Ferrum |

The export modal offers the same three formats as [project export](./export.md). PDF requires Chrome in the container — see [Configuration](./configuration.md).

## Annex references

In any **textarea** (text document sections, table textarea columns, form response fields), you can reference an annex asset with BBCode:

```text
[ANNEX architectural-schema]
```

### In the editor

- BBCode appears **as typed** — no toolbar button, no preview transformation.
- Adding a reference does **not** change annex asset versioning.

### On export

When a document contains `[ANNEX {doc-id}]`:

1. Each tag is replaced by a markdown link: `[Asset title](#annex-ref-{doc-id})`.
2. The **latest uploaded file** for that annex is appended at the bottom of the export under **Referenced annex assets**.
3. Images are embedded (HTML/PDF) or included as data-URI markdown; other file types get a short text line.
4. **Export tag scope is ignored** for referenced assets — if a basic-scoped project export references an untagged annex, that asset is still embedded in the exporting document.

Relative anchor links work across Markdown, HTML, and PDF exports from the same document.

### Finding the BBCode

On each **annex asset detail** page, the **Share** section shows:

- **Permalink** — URL to the asset page (click to copy)
- **BBCode** — `[ANNEX {doc-id}]` in a code block (click to copy)

The **Referenced in** table lists text documents, tables, and form responses that currently contain the BBCode for this asset.

## Authentication

Document export URLs require a valid session (or `AUTH_DISABLED=1` in dev), same as [project export](./export.md).

## See also

- [Export](./export.md) — full project export with tag scopes
- [Annexes](./annexes.md) — uploading and tagging assets
- [Text documents](./text-documents.md)
- [Table documents](./table-documents.md)
- [Forms](./forms.md)
