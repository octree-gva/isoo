---
sidebar_position: 14
title: Collaboration
description: No real-time collaborative editing in ISOO
---

# Collaboration

**Audience:** teams expecting Google Docs–style or CRDT co-editing.

## ISOO does not provide collaborative editing

There is **no** supported model for:

- Simultaneous multi-user editing of the same document
- Operational transforms or merge-on-save
- Document locking or check-in / check-out
- Comments, suggestions, or threaded review on content
- Real-time cursor or field-level presence

**Last save wins.** Two users editing the same document concurrently can overwrite each other’s changes. Operational procedure should be single-editor-per-document or external coordination.

## Viewing presence (not collaboration)

Text and table document pages run a lightweight **viewing presence** heartbeat:

- Shows when **other signed-in users** are on the same document URL
- Does **not** block saves or indicate what others are editing
- Uses in-memory storage by default; **Memcached** (`MEMCACHE_SERVER`) shares presence across app instances

This is awareness only—“Alice is also viewing this document”—not collaboration infrastructure.

Presence endpoints:

- `POST …/docs/{doc_id}/presence` — heartbeat
- `POST …/docs/{doc_id}/presence/leave` — leave notification

Annex pages and exports do not use presence.

## What to use instead

| Need | Approach |
|------|----------|
| Audit trail | [Document versioning](./document-versioning.md) + [git integration](./git-integration.md) |
| Review workload | [Review](./review.md) dashboard |
| Offline/async review | [Project export](./export.md) PDF/HTML packs |
| Access control | [Authentication](./authentication.md) + IdP groups (outside ISOO) |

## See also

- [Configuration](./configuration.md) — `MEMCACHE_SERVER`
- [Text documents](./text-documents.md)
