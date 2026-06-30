---
sidebar_position: 10
title: Document versioning
description: Semver bumps, version control history, and audit sidecars
---

# Document versioning

**Audience:** operators explaining audit trails to assessors and backup teams.

Every substantive save bumps an **ISO semver** on the document (`iso27001.version` in front matter) and appends a row to **Document Version Control** history.

## Version bumps

| Save type | Bump rule |
|-----------|-----------|
| Normal save | **Patch** +1 (`0.1.0` → `0.1.1`) |
| **Significant change** checked | **Minor** +1 (`0.1.2` → `0.2.0`) |

Annex metadata saves, uploads, exclude/restore, and table operations follow the same semver rules where applicable.

## Where history lives

| Location | Contents |
|----------|----------|
| **Markdown body** | Version table rows (version, date, author, changes) prepended on save; stripped from displayed content |
| **Front matter** | Current `iso27001.version`, `timestamp` |
| **`.audit.yaml`** | For confidential docs: `version`, `modified_at`, `modified_by` in plain git |

The UI shows the version table only when at least one row exists.

## Export behaviour

HTML/PDF export always renders a **Document Version Control** section:

1. Prefer rows parsed from the markdown body
2. If none, synthesise one row from audit metadata / front matter (e.g. fresh `0.1.0` “Document first created”)

Exports demote heading levels so the version block fits the print layout.

## Required change notes

Saves require a **document changes** description (except some table row operations that commit with a generic message). Empty change notes return HTTP **400**.

## Git commits

Typical commit message: `{doc_id} v{version}: {changes}`.

Annex exclude/restore uses messages like `{doc_id}: excluded from export`.

## See also

- [Text documents](./text-documents.md)
- [Table documents](./table-documents.md)
- [Git integration](./git-integration.md)
- [Project export](./export.md)
- [Document export](./document-export.md)
