# ISOO

Self-hosted web app to manage ISO27001 documentation for open source projects.

Storage follows [OKF v0.1](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md): markdown + per-document `.schema.yaml` + `.csv` tables. Template bundles live in `data/templates/` (this repo). Project instances default to `tmp/data/projects/` with a nested git repo (gitignored here; optional remote via `GIT_REMOTE_URL`).

## Quickstart

```bash
docker compose build
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app ruby bin/init-data-git
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed
docker compose up -d
```

First boot may take ~1–2 minutes while Zitadel initializes and the app registers its OIDC client.

| URL | Service |
| --- | --- |
| http://localhost:9292 | ISOO (Zitadel login) |
| http://localhost:8080 | Zitadel console |
| http://localhost:1080 | MailCatcher (dev email) |

Default Zitadel admin: `admin@zitadel.localhost` / `Password1!`

Open http://localhost:9292/projects/demo after logging in — seeded with sample text and table rows.

`SEED_RESET=1` recreates the demo project; `SEED_FORCE=1` re-applies demo content. Seeding removes any other projects under `tmp/data/projects/` (or `$DATA_PATH/projects/`).

Set `AUTH_DISABLED=1` in `.env` to skip login (e.g. for tests).

**Local development only** — skip Zitadel and auth:

```bash
docker compose run --rm --no-deps -e AUTH_DISABLED=1 -p 9292:9292 app bundle exec rackup -o 0.0.0.0 -p 9292
```

Git still records changes under `data/`; no remote is required (see [Data and Git](#data-and-git) below).

## Development

Run the full CI suite locally (Docker):

```bash
./bin/check
```

Individual commands (`--no-deps` avoids starting Zitadel):

```bash
npm ci && npm run build:css   # after editing assets/css/app.css
docker compose run --rm --no-deps app bundle exec erb_lint --lint-all
docker compose run --rm --no-deps app bundle exec rubocop
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rspec
docker compose run --rm --no-deps app bundle exec rubocop
docker compose run --rm --no-deps app bundle exec rake security:scan
docker compose run --rm --no-deps app bundle exec rake isoo:validate_templates
docker compose run --rm --no-deps -e AUTH_DISABLED=1 app bundle exec rake isoo:seed
```

Templates live in `data/templates/voca/` (OKF bundle). To use a custom bundle for new projects, set `TEMPLATE_ID` — see the [templates documentation](https://voca.github.io/isoo/templates). Validate before seeding or shipping changes:

```bash
docker compose run --rm --no-deps app bundle exec rake isoo:validate_templates
```

## Changing text document structure

Text documents are **schema-driven**: the form fields in the UI come from `{doc-id}.schema.yaml` beside the markdown file. Seeding copies the `voca` template into `data/projects/<slug>/`; after that, each project keeps its **own** schema copies.

### One document in an existing project

Edit the project schema (not the template), for example:

```
data/projects/demo/context/documented-isms-scope/documented-isms-scope.schema.yaml
```

Each entry under `sections` defines one block in the editor:

| Field | Purpose |
| --- | --- |
| `key` | Stable id used in forms and POST params (use `snake_case`, do not rename lightly) |
| `label` | Heading text in the markdown body and the field label in the UI |
| `level` | `h1`, `h2`, or `h3` — must match the heading level in the `.md` file |
| `editable` | `false` for fixed titles; `true` for fields users edit |
| `field_type` | `text` (single line) or `textarea` (markdown) |
| `role` | `title` or `body` (title sections with `editable: false` are layout only) |

**How content is matched:** on load, ISOO parses the markdown body and maps each section by **`level` + `label`**. On save, it rebuilds the body from the schema order.

Typical changes:

- **Add a section** — append a new `sections` entry; open the document in the UI (new field is empty), fill it, **Save** with a change note.
- **Remove a section** — delete its entry from the schema; **Save** once to drop it from the stored markdown.
- **Rename a field** — change `label` only if you also update the heading in the `.md` file, or existing text will not bind to the new field until you re-enter it.

Schema files stay plain YAML even when the `.md` is encrypted. Refresh the browser after editing files on disk.

### Template-wide changes (new projects)

To change the default structure for **future** projects, edit the same file under `data/templates/voca/…`, then:

```bash
docker compose run --rm --no-deps app bundle exec rake isoo:validate_templates
```

Existing projects are **not** updated automatically. Either edit their project schemas by hand, or recreate the project (`SEED_RESET=1` for the demo seed wipes and recopies from the template).

## Documentation

Operator documentation is published at **[voca.github.io/isoo](https://voca.github.io/isoo/)** (built from [`website/`](website/) with Docusaurus).

To run the docs site locally:

```bash
cd website && npm install && npm start
```

## Confidential documents

Set `ENCRYPTION_SECRET` (required in production). Confidential documents are stored encrypted (`.enc`) with a plain `.audit.yaml` for version and modification timestamps visible in git. Non-confidential documents remain plain text. Use **Export** on the project dashboard for a full-project pack, or **Export** on any document page for a single-page download — see the [documentation](https://voca.github.io/isoo/document-export).

## Data and Git

Templates live in `data/templates/` (tracked in this repo). Project instances default to `tmp/data/projects/` with a **nested git repo** at `tmp/data/.git` (gitignored here). ISOO commits project changes on every write (document save, new project, table row, annex upload, and so on).

### Local-only (default)

No remote, network, or extra configuration is required. This is the normal setup for developers:

1. Run `bin/init-data-git` once (included in the quickstart) to create `tmp/data/.git`.
2. Use the app — each change is committed locally only.

Inspect history:

```bash
cd tmp/data && git log --oneline
```

Project files are never tracked in the **application** repo; only the nested data repo (and optional remote) holds them. Back up `tmp/data/` (or your `$DATA_PATH`) like any other state directory.

### Remote synchronization (optional)

To mirror project data to a remote after each commit (backup, second host, automation), set both variables:

| Variable | Purpose |
| --- | --- |
| `GIT_REMOTE_URL` | Remote URL (`https://…` or `git@…`) |
| `GIT_FORCE_PUSH` | `1` — push to `origin main` after every commit |
| `GIT_AUTHOR_NAME` | Commit author name (default: `ISOO`) |
| `GIT_AUTHOR_EMAIL` | Commit author email (default: `isoo@local`) |

Example in `.env`:

```bash
GIT_REMOTE_URL=git@github.com:acme/isoo-data.git
GIT_FORCE_PUSH=1
GIT_AUTHOR_NAME=Acme ISOO
GIT_AUTHOR_EMAIL=isoo@acme.example
```

Restart the app after changing these. The next document change triggers a commit and push.

Use the **Sync** button in the header (visible when `GIT_REMOTE_URL` is set) to `git fetch` and reset `$DATA_PATH` to `origin/main`. That loads the latest remote mirror before you edit. Sync is refused if you have uncommitted changes in the data repo.

**Important:** sync uses `git reset --hard origin/main` and discards local commits that were never pushed. Push (`GIT_FORCE_PUSH=1`) before syncing on another host, or sync only on read-only replicas.

The remote is a **mirror** of this instance’s project data tree. Use a dedicated repository (or bare repo) for ISOO data — not a branch others push to.

Typical production layout:

- Persistent volume on `./tmp/data` (or custom `$DATA_PATH`)
- `GIT_REMOTE_URL` + `GIT_FORCE_PUSH=1` for off-site backup
- Deploy key or token with push access to that remote only

Without `GIT_REMOTE_URL` (or with `GIT_FORCE_PUSH` unset), nothing is pushed; local commits still happen.

## Auth (Zitadel + OIDC)

`docker compose up -d` starts ISOO, Zitadel, Postgres, and MailCatcher. The app entrypoint waits for Zitadel, creates the OIDC application if needed, and loads `docker/zitadel/oidc.env`.

Zitadel sends mail to [MailCatcher](https://mailcatcher.me/). Open http://localhost:1080 for verification and password-reset emails.

On app startup, `bin/setup-zitadel-smtp` configures MailCatcher via the Zitadel Admin API (idempotent). Env-based SMTP (`ZITADEL_DEFAULTINSTANCE_SMTPCONFIGURATION_*`) is only applied on **first** Zitadel init; existing volumes need the setup script or a volume reset (`docker compose down -v`).

| Variable | Purpose |
| --- | --- |
| `AUTH_DISABLED` | `1` bypasses auth (use for tests) |
| `AUTH_ALLOWED_EMAIL_DOMAINS` | Comma-separated email domains allowed to sign in (e.g. `voca.city,example.com`). Empty = allow all domains. |
| `OIDC_ISSUER` | Public issuer URL (browser), e.g. `http://localhost:8080` |
| `OIDC_ISSUER_INTERNAL` | Server-side issuer host (`http://zitadel:8080` in Docker) |
| `OIDC_CLIENT_ID` / `OIDC_CLIENT_SECRET` | Auto-written to `docker/zitadel/oidc.env` |
| `OIDC_REDIRECT_URI` | Callback URL (`http://localhost:9292/auth/callback`) |
| `SESSION_SECRET` | Rack session secret (64+ chars in production) |

Copy `.env.example` to `.env` to override defaults. Any OIDC provider works if endpoints follow OpenID discovery.

### French export (optional)

Set `DEEPL_API_KEY` to enable **French (DeepL)** in export modals. When unset, exports are English only and `lang=fr` is ignored. See [export documentation](https://voca.github.io/isoo/export).


## Observability

The Docker image runs the app under [PM2](https://pm2.keymetrics.io/) (`pm2-runtime` + `ecosystem.config.cjs` → Puma).

| Endpoint | Purpose |
| --- | --- |
| `GET /health` / `/health/live` | Liveness (process up) |
| `GET /health/ready` | Readiness (data path, templates, optional Memcached) |
| `GET /metrics` | Prometheus text exposition |

Health and metrics are unauthenticated so load balancers and scrapers can reach them. `docker compose` healthchecks use `/health/ready`.

### Troubleshooting startup

After `docker compose restart`, wait until Zitadel is healthy (can take 1–2 minutes on a cold boot):

```bash
docker compose ps
curl -sf http://localhost:9292/health/ready
curl -sf http://localhost:8080/debug/ready
docker compose logs app --tail 30
docker compose logs zitadel --tail 30
```

The app starts Puma immediately; Zitadel SMTP/OIDC setup runs in the background. Login works once Zitadel is healthy and `docker/zitadel/oidc.env` exists. For local work without auth: `AUTH_DISABLED=1 docker compose up -d app`.

## Security checks

```bash
docker compose run --rm --no-deps app bundle exec rake security:scan
```

Runs [Brakeman](https://brakemanscanner.org/) (static analysis) and [bundler-audit](https://github.com/rubysec/bundler-audit) (gem CVEs).

## Docs

| Doc | Contents |
| --- | --- |
| [voca.github.io/isoo](https://voca.github.io/isoo/) | Published operator documentation (install, export, annexes, …) |
| [website/docs/](website/docs/) | Documentation source (Docusaurus) |
| [docs/PLAN.md](docs/PLAN.md) | Sprints, schema, validation gates |
| [docs/decisions.md](docs/decisions.md) | Locked product decisions |
| [docs/design-system.md](docs/design-system.md) | DaisyUI / ISOO tokens |

Place `VG5000.woff2` in `public/fonts/` for the brand font (falls back to system UI).
