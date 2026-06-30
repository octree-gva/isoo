---
sidebar_position: 11
title: Project export
description: Full-project Markdown, HTML, and PDF exports with tag scopes
---

# Project export

**Audience:** teams producing auditor packs, DPO subsets, or full ISMS exports.

From the **project dashboard**, **Export** opens a modal to choose **scope** and **format**.

To export **one document only** (text, table, form response, or annex page), open that document and use **Export** in the header. See [Document export](./document-export.md).

## Formats

| Format | Output | Notes |
|--------|--------|-------|
| `md` | Single concatenated Markdown file | Download |
| `html` | Print-styled HTML | Self-contained CSS, table legends |
| `pdf` | A4 PDF | Headless Chrome via Ferrum; headers/footers with page numbers |

PDF generation requires Chrome in the container (`CHROME_NO_SANDBOX=1` in Docker). See [Configuration](./configuration.md).

## Scopes

| Scope | Documents included |
|-------|-------------------|
| **Full** | All active documents, annexes, and form responses |
| **Tag scopes** | Entries whose schema `export_tags` contains the tag |

Tags are defined in `data/templates/voca/export_tags.yaml`, for example:

| Tag | Typical use |
|-----|-------------|
| `basic` | High-level overview for leadership |
| `data_protection` | DPO / GDPR pack |
| `soi` | Security organisation & infrastructure |
| `architectural_schema` | Architecture diagram annexes |
| `network_diagram` | Network diagram annexes |
| `asset_document` | Other annex files |

Assign tags on annex metadata checkboxes or via `rake isoo:sync_export_tags` for template documents.

**Excluded annexes** (`_deleted_at` on manifest) are omitted from every scope, including full.

### Annex references and scoped export

Documents can embed annex assets via `[ANNEX doc-id]` BBCode in textareas. When a document **in** a scoped export contains such a reference, the referenced asset is **still embedded** in that document’s export even if the annex has no matching export tag. See [Document export — Annex references](./document-export.md#annex-references).

## Export ordering

1. Main documents (by manifest sequence)
2. Annexes
3. Form responses

Section dividers separate tiers in HTML/PDF.

## Content processing

- Version control table rendered dynamically (see [Document versioning](./document-versioning.md))
- Table CSV → HTML/Markdown without internal columns
- Soft-deleted table rows omitted
- Internal markdown links rewritten for exported doc ids
- Annex images embedded in HTML/PDF when `asset_kind` is image
- `[ANNEX …]` BBCode rewritten and referenced assets appended per document ([details](./document-export.md#annex-references))

## Authentication

Export URLs require a valid session (or `AUTH_DISABLED=1` in dev). There is no separate export API token.

## See also

- [Document export](./document-export.md)
- [Annexes](./annexes.md)
- [Configuration](./configuration.md) — `CHROME_NO_SANDBOX`
- [Authentication](./authentication.md)
