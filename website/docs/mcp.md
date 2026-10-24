---
sidebar_position: 15
title: MCP access
description: Streamable HTTP MCP for Open WebUI with granular bearer scopes
---

# MCP access

**Audience:** operators connecting [Open WebUI](https://docs.openwebui.com/features/extensibility/mcp/) (for example [ia.octr.ee](https://ia.octr.ee/)) to an ISOO project.

ISOO exposes a **Streamable HTTP** MCP endpoint per project. Authentication is an **admin-minted bearer token** (Open WebUI Auth = Bearer). OAuth 2.1 is not implemented in this release.

## Project settings

1. Open the project dashboard → **Settings** → **MCP**.
2. Turn **MCP enabled** on and save.
3. Under **Credentials**, choose a **name**, **audience**, and **mode**, then create the token.
4. Copy the token **once** (it is never shown again).
5. In Open WebUI: Admin → Integrations → Add connection → Type **MCP (Streamable HTTP)**.
6. Server URL: `https://<isoo-host>/projects/<slug>/mcp`
7. Auth: **Bearer**, paste the token.

Use one Open WebUI connection per token. SOI-read and Data Protection-write need two credentials.

The **General** tab holds the project name, description, and read-only current version.

When MCP is disabled, the endpoint returns 401 for every bearer token (credentials are kept but inactive).

## Audiences and modes

| Audience | Documents visible |
|----------|-------------------|
| **Full** | All documents that are not withheld |
| **SOI** / **Data Protection** / **Basic** | Documents whose schema `export_tags` contain that tag (same rules as project export) |

| Mode | Tools |
|------|--------|
| **Read** | list/read documents, tables, forms, and form answers |
| **Read and write** | Read tools plus update document, table rows, and form answers |

Withheld documents (see [Project export](./export.md#withhold)) are omitted from every MCP list and return not-found on read or write. Forms store withhold on the project manifest entry (forms have no project `.md` stamp); text, table, annex, and form answers store it in document front matter.

## Endpoint

- `POST /projects/:slug/mcp` — JSON-RPC 2.0 (`initialize`, `tools/list`, `tools/call`)
- `GET /projects/:slug/mcp` — returns 405 (stateless; no SSE stream)
- Protocol version: `2025-11-25` (`MCP-Protocol-Version` header after initialize)
- Browser sessions and `AUTH_DISABLED=1` do **not** authorize MCP; only a valid bearer token does, and only while MCP is enabled for the project

Tokens are stored as HMAC-SHA256 (pepper = `ENCRYPTION_SECRET`). Audit lines go to `mcp_audit.jsonl` in the project data directory (tool name, access id, doc id — no body text, no raw token).

## Compliance checklist

Evaluated against MCP specification 2025-11-25, the [OWASP MCP Top 10](https://owasp.org/www-project-mcp-top-10/), and the [OWASP MCP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html).

### Spec (Streamable HTTP + tools)

| Item | Status |
|------|--------|
| Single MCP endpoint, POST and GET, JSON-RPC 2.0 | Met |
| `MCP-Protocol-Version`; unsupported version → 400 | Met |
| `Origin` present and not the app origin → 403 | Met |
| `initialize` then `tools/list` / `tools/call`; tools capability declared | Met |
| Tool `inputSchema` is JSON Schema; server validates inputs | Met |
| Validate inputs, access control, rate-limit, sanitize outputs | Met (structured JSON; no HTML/command channel) |
| OAuth 2.1, PKCE, RFC 9728, RFC 8707 audience | Gap (Open WebUI Bearer is the supported client path) |
| Session id binding | Gap (stateless on purpose) |
| Resources capability | Gap (tools only; add later if a client needs `resources/read`) |

### OWASP MCP Top 10

| Risk | Status |
|------|--------|
| MCP01 Token mismanagement | Met for hash-at-rest, show-once, expiry, revoke. Gap for short-lived OAuth tokens |
| MCP02 Privilege escalation / scope creep | Met (one audience, one mode; write tools omitted when read-only; re-checked on call) |
| MCP03 Tool poisoning | Met (static tool descriptions in code). Pinning is the client’s job |
| MCP04 Supply chain | Met (no new MCP gem). Gap: no extra scanner beyond `./bin/check` |
| MCP05 Command injection | Met (no shell, path, or URL fetch) |
| MCP06 Prompt injection via payloads | Partial: results are JSON data; document prose is not stripped |
| MCP07 Insufficient authZ | Met for bearer scope checks. Gap for OAuth identity |
| MCP08 Lack of audit | Met (project audit log). Gap for SIEM shipping |
| MCP09 Shadow MCP servers | Met (401 until MCP is enabled and an admin creates a token) |
| MCP10 Context over-sharing | Met (withhold excluded; audience filter; no cross-project token) |

### Client / operator duties (not ISOO gaps)

Human approval of tool calls (Open WebUI), message signing, multi-server isolation, install consent, and OS keychain storage of the bearer token remain on the client or operator side.

## See also

- [Project export](./export.md)
- [Authentication](./authentication.md)
- [Configuration](./configuration.md) — `ENCRYPTION_SECRET`
