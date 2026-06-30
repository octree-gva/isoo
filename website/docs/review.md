---
sidebar_position: 12
title: Review
description: Stale documents and expired review dates
---

# Review

**Audience:** document owners and IT staff monitoring ISMS maintenance workload.

The **Reviews** screen on a project surfaces documents that need attention. It does not send notifications or assign tasks—it is a read-only dashboard.

## Stale documents

Lists **editable text and table** documents not updated in **12 months** (configurable constant in code: `ProjectReview::STALE_AFTER_MONTHS`).

“Last updated” uses confidential `.audit.yaml` `modified_at` when present, otherwise front matter `timestamp`.

## Oldest documents

Shows the **five** editable text/table documents with the oldest last-updated date—useful for prioritising refresh work.

## Expired review dates

Scans **table** documents for columns with `type: review_date`. Any row with a date **on or before today** appears with:

- Document title
- Column label
- Row identifier (primary key value)
- Days overdue

Common registers: supplier review dates, legal assessment next dates, etc.

## What review does not do

- No email or webhook alerts
- No workflow assignment or approval chains
- No automatic locking of expired rows

Operators use export and git history for evidence; review is a triage list only.

## See also

- [Table documents](./table-documents.md)
- [Document versioning](./document-versioning.md)
