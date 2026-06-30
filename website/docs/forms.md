---
sidebar_position: 8
title: Forms
description: Repeatable form templates and responses
---

# Forms

**Audience:** teams running recurring records (audit reports, incident forms, meeting minutes).

Forms are **template documents** in the manifest with `kind: form`. Each form has a `response_kind` (`text` or `table`) defining the shape of created responses.

## Structure

```
audit/audit-report-template/
  audit-report-template.md          # template (stamp removed on project create)
  audit-report-template.schema.yaml
  responses/
    audit-report-template-1/
      audit-report-template-1.md
      audit-report-template-1.schema.yaml
```

On **project creation**, form templates are moved from `documents` to `forms[]` in `manifest.yaml`, template content files are stripped, and `responses: []` starts empty.

## Creating responses

1. Open the form folder from the project dashboard.
2. Click **New response**.
3. ISOO copies the template schema, assigns `doc_id` `{form_id}-{N}`, writes initial markdown (version `0.1.0` with “Document first created”), and adds the response to the manifest.

Responses are edited like normal [text](./text-documents.md) or [table](./table-documents.md) documents.

## Export tier

Exports list form responses in a separate tier after main documents and annexes. Scoped exports filter responses using the **parent form schema** `export_tags`.

## Seeding

`rake isoo:seed` creates one empty response per form when none exist (`record_version: false` for the initial copy).

## See also

- [Text documents](./text-documents.md)
- [Table documents](./table-documents.md)
- [Project export](./export.md)
- [Document export](./document-export.md)
