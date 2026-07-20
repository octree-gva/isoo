---
sidebar_position: 13
title: Git integration
description: Nested git backend, optional remote mirror, and sync
---

# Git integration

**Audience:** platform teams responsible for backup, DR, and change auditing of ISOO data.

ISOO supports four exclusive storage backends via `STORAGE_BACKEND`: `local`, `git`, `webdav`, and `s3`. This page covers **`STORAGE_BACKEND=git`**.

All project content is edited under `$DATA_PATH` (default `tmp/data/`). With the git backend, ISOO maintains a **nested git repository** there (separate from the application source repo). Template bundles stay in `data/templates/` (this repo).

For `local`, data stays only on disk under `DATA_PATH` with no nested commits. See [Configuration](./configuration.md).

## Local commits (git backend)

When `STORAGE_BACKEND=git`, every write commits to the data repo under `$DATA_PATH`:

- Document save (text, table, form response)
- Table row add/update/soft-delete
- Project create
- Annex upload, metadata, exclude/restore
- Demo seeding

Commit author comes from `GIT_AUTHOR_NAME` and `GIT_AUTHOR_EMAIL`.

Initialise once:

```bash
ruby bin/init-data-git
```

Inspect history:

```bash
cd tmp/data && git log --oneline
```

(Replace `tmp/data` with your `$DATA_PATH` if customized.)

## Optional remote push

Set:

```bash
STORAGE_BACKEND=git
GIT_REMOTE_URL=git@github.com:acme/isoo-data.git
GIT_FORCE_PUSH=1
```

| Variable | Effect |
|----------|--------|
| `GIT_REMOTE_URL` | Enables remote features when non-empty |
| `GIT_FORCE_PUSH=1` | After each commit, `git push --force origin main` |

Without `GIT_FORCE_PUSH`, commits stay local even if `GIT_REMOTE_URL` is set.

Use a **dedicated data repository**—not a branch others push to. The app assumes it owns `$DATA_PATH`.

## Sync from remote

When `STORAGE_BACKEND=git` **and** `GIT_REMOTE_URL` is set, the header shows **Sync**:

1. Refuses if the data repo has uncommitted changes (`dirty`)
2. `git fetch origin`
3. `git reset --hard origin/main`

**Warning:** sync discards local commits not on the remote. Push before syncing on another host, or use sync only on read replicas.

## Application repo vs data repo

| Path | Git |
|------|-----|
| ISOO source code | Your clone of the app repository |
| `data/templates/` | Tracked in app repo (template bundle) |
| `$DATA_PATH/projects/*` | Nested data repo only (default: `tmp/data/projects/`) |

Back up `$DATA_PATH` as a volume or via the remote mirror.

## See also

- [Configuration](./configuration.md)
- [Document versioning](./document-versioning.md)
- [Install](./install.md)
