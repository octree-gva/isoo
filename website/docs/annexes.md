---
sidebar_position: 9
title: Annexes
description: File assets, diagrams, BBCode references, export tags, and soft exclusion
---

# Annexes

**Audience:** infrastructure and security teams maintaining architecture diagrams, network maps, and supporting files.

Annexes are **`file_annex`** documents: metadata in markdown + binary files in `annexes/files/` with a registry (`annexes/registry.yaml`, `annexes/versions.yaml`).

## Annexes vs files

| Concept | Location |
|---------|----------|
| **Annexe** | Manifest entry + `annexes/<doc-id>/` markdown and schema |
| **Uploaded file** | `annexes/files/{id}-{slug}-{version}.{ext}` |

Each slot can hold multiple file **versions** linked to document semver on upload.

## Creating annexes

- **UI:** Annexes folder → **New annex** → auto `annex-N` doc id.
- **Seeding:** `rake isoo:seed` adds `architectural-schema` and `network-diagram` with placeholder PNGs (project only, not in template manifest).

## Metadata

Annex detail page:

- Title and description
- **Export tags** (checkboxes): `architectural_schema`, `network_diagram`, `soi`, `asset_document`, etc. — defined in `data/templates/voca/export_tags.yaml`
- Upload new file (bumps document version, appends version-control row)

`asset_kind` (`image` / `document`) is inferred from the uploaded filename.

## Share and BBCode references

The **Share** section on each asset detail page provides:

| Item | Purpose |
|------|---------|
| **Permalink** | Full URL to the asset page — click to copy |
| **BBCode** | `[ANNEX {doc-id}]` — click to copy; paste into any textarea |

Use BBCode in text document sections, table textarea columns, or form response fields to reference the asset from prose. In the editor the tag stays literal; on [export](./document-export.md) it becomes a link plus an embedded asset appendix.

The **Referenced in** table lists text documents, tables, and form responses that currently contain this asset’s BBCode. Scanning is read-only and does not bump annex versioning.

## Exclude from exports (soft delete)

Operators can **exclude** an annex from all exports without deleting files:

- Sets `_deleted_at` on the manifest annex entry
- Records a version-control note
- Hides upload form; metadata remains editable
- **Restore** clears `_deleted_at`

Excluded annexes still appear in the annexes list with an **Excluded** badge.

## Download

Authenticated users download via `/projects/{slug}/annexes/{annex_id}?version=N`. Latest version when `version` is omitted.

## Export

- **Project export:** scoped exports include annexes whose schema `export_tags` match the selected scope. See [Project export](./export.md).
- **Document export:** export a single annex page from its header **Export** button. See [Document export](./document-export.md).
- Annex body exports as markdown; images embed in HTML/PDF via `ExportAnnexAssets`.
- Referenced annexes (`[ANNEX …]` in other documents) bypass tag scope when embedded — see [Annex references](./document-export.md#annex-references).

## See also

- [Document export](./document-export.md)
- [Project export](./export.md)
- [Seeding](./seeding.md)
- [Document versioning](./document-versioning.md)
