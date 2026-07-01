---
sidebar_position: 4
title: Authentication
description: OIDC login, session idle timeout, and email domain restrictions
---

# Authentication

**Audience:** IT services teams integrating ISOO with corporate identity and access policy.

ISOO protects **all project routes**, exports, annex downloads, and static app assets. Unauthenticated paths are limited to health checks (`/health`, `/health/live`, `/health/ready`), Prometheus `/metrics`, and OIDC flow endpoints (`/auth/login`, `/auth/callback`, `/auth/logout`).

## OIDC flow

1. Unauthenticated user hits a protected URL → redirect to `/auth/login`.
2. App redirects to IdP **authorize** endpoint with `response_type=code`, scopes `openid email profile`, and a random `state` stored in session.
3. IdP returns to `OIDC_REDIRECT_URI` (`/auth/callback`) with `code` and `state`.
4. App validates `state`, exchanges `code` for tokens at the token endpoint (using `OIDC_ISSUER_INTERNAL` for server-side discovery).
5. Userinfo yields `email` and `name` → stored in `rack.session['user']`.
6. Subsequent requests run domain check and idle timeout, then proceed.

Discovery document is fetched from `{issuer}/.well-known/openid-configuration` (public issuer for browser URLs, internal issuer for back-channel).

### Docker Compose default

Zitadel runs as the bundled IdP. The app entrypoint waits for Zitadel, creates the OIDC application if needed, and writes `docker/zitadel/oidc.env`. See [Zitadel (example IdP)](./zitadel.md) for a full walkthrough and production hardening. Override `OIDC_*` in `.env` to use an external provider (Azure AD, Keycloak, etc.) with the same variable names.

### Required variables (production)

| Variable | Purpose |
|----------|---------|
| `OIDC_ISSUER` | Public issuer URL users and browsers see |
| `OIDC_ISSUER_INTERNAL` | Reachable issuer from the app container |
| `OIDC_CLIENT_ID` | OAuth client ID |
| `OIDC_CLIENT_SECRET` | OAuth client secret |
| `OIDC_REDIRECT_URI` | Callback URL registered at the IdP |
| `SESSION_SECRET` | Session cookie signing |

## Disabling authentication

```bash
AUTH_DISABLED=1
```

When set:

- OIDC middleware is skipped.
- Every request runs as a fixed dev identity (`dev@local` / `Developer`).
- Login UI elements are hidden.

Use for **local development, CI, and automated tests only**. Do not set in production.

## Email domain restriction

```bash
AUTH_ALLOWED_EMAIL_DOMAINS=voca.city,example.com
```

| Value | Behaviour |
|-------|-----------|
| Empty or unset | Any email domain from the IdP is accepted |
| Comma-separated list | Only matching domains (case-insensitive) may use the app |

Enforcement points:

- Immediately after successful OIDC callback
- On **every** authenticated request (revokes session if domain no longer allowed)

Rejected users receive HTTP **403** with a message naming their email domain.

## Session idle timeout

```bash
SESSION_IDLE_TIMEOUT_SECONDS=7200
```

Default: **2 hours**. Each request refreshes the idle clock. Expired sessions are cleared and the user is sent to `/auth/login`.

## Logout

`GET /auth/logout` clears the session and redirects to `/`.

## Error handling

| Condition | HTTP | Detail |
|-----------|------|--------|
| Missing `code` on callback | 400 | Sign-in response incomplete |
| `state` mismatch | 400 | Session expired or CSRF |
| Token exchange failure | 401 | IdP rejected exchange |
| Domain not allowed | 403 | Email domain forbidden |

User-facing copy is in `config/locales/en.yml` under `errors.*`.

## See also

- [Configuration](./configuration.md)
- [Zitadel (example IdP)](./zitadel.md)
- [Install](./install.md)
