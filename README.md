# LivFinder API

The backend for the LivFinder marketplace, client portal and admin portal.

Express 5 on Node 20+, talking to the existing LivFinder MySQL schema through
`mysql2/promise` and a repository layer. There is no ORM and no second schema:
the SQL in `db/migrations` is the authority, and this service reads and writes it
directly.

```
livfinder-backend/
├── src/
│   ├── app.js               Express wiring: security, CORS, CSRF, routers
│   ├── server.js            listen, boot checks, graceful shutdown
│   ├── config/              env (validated at boot), logger, storage factory
│   ├── db/                  pool, parameterised query helpers, transactions
│   ├── middleware/          request id, auth, permissions, validation, errors,
│   │                        rate limits, CSRF, security headers
│   ├── modules/             one folder per domain (auth, accounts, listings,
│   │                        search, media, portal, admin, public, editorial,
│   │                        locations, engagement, system)
│   ├── serializers/         database rows → the shapes the frontend reads
│   ├── storage/             StorageAdapter + local and S3 implementations
│   └── utils/               ids, slugs, canonical paths, categories, secrets
├── scripts/                 operational scripts (below)
└── tests/                   unit + integration (integration hits the real DB)
```

## Getting started

```bash
cp .env.example .env          # adjust DB_* and SESSION_SECRET
npm install
npm run dev                   # or: npm start
```

The API listens on `PORT` (4000 by default; the checked-in `.env` uses 4100
because port 4000 was already taken on the development machine).

```bash
curl localhost:4100/health            # liveness — never touches the database
curl localhost:4100/health/database   # readiness
npm run health-check                  # full deployment readiness report
```

### First run against a fresh database

```bash
cd ../db/db && tools/load.sh all --fresh --with-mysql8   # schema + seed
cd ../../livfinder-backend
npm run backfill:canonical-paths     # align listing URLs with the route contract
npm run seed:dev-passwords           # give the demo users a usable password
npm run import:frontend-media        # import the frontend's listing imagery
npm run maintenance                  # run the scheduled jobs once
```

## Scripts

| Command | What it does |
|---|---|
| `npm run dev` / `npm start` | Run the API |
| `npm test` | Unit tests (no database) |
| `npm run test:integration` | Integration tests against the real database |
| `npm run test:all` | Both |
| `npm run smoke` | End-to-end HTTP smoke test against a running server |
| `npm run health-check` | Database, schema, seed, projection, storage and config |
| `npm run maintenance` | The scheduled pass: reapers, expiry, indexing, counters |
| `npm run seed:dev-passwords` | Argon2id passwords for the seeded demo users |
| `npm run import:frontend-media` | Import `frontend/public` listing imagery |
| `npm run backfill:canonical-paths` | Rewrite `listings.canonical_path` |
| `npm run cleanup:test-artifacts` | Remove rows left by an interrupted test run |

## How it is put together

**The database is the authority.** Publication rules live in
`v_public_listings`, `v_public_organizations` and `v_public_agents`; the search
projection is maintained by `sp_refresh_listing_search`; account permissions come
from `v_account_permissions`. The API calls those seams rather than reimplementing
them, so a rule cannot drift between the two.

**Reads and writes are separated by shape, not by service.** A results page reads
`listing_search` — one indexed range scan, one image per card. A detail page reads
the transactional tables and returns the full gallery. Nothing ships a gallery to
a grid.

**Every multi-table write is a transaction.** Signup writes a user, an account, a
membership, an organisation, a licence and a verification request or none of them.
Creating a listing writes `listings`, the category detail table, features,
attributes and media, then refreshes the projection.

**Serializers are deliberate.** No `snake_case` row reaches the browser. Each
serializer emits the exact shape the corresponding frontend screen already read,
which is why the frontend switch from fixtures to live data changed no markup.

## Security

- **Sessions** are rows in `user_sessions`. The cookie carries an opaque random
  token; only its SHA-256 is stored. `session_epoch` makes "sign out everywhere"
  a single `UPDATE`, and a suspended user's sessions die immediately.
- **Passwords** are Argon2id. A legacy bcrypt hash still verifies and is upgraded
  in place on the owner's next successful sign-in.
- **CSRF** is a signed double-submit token bound to the session, required on every
  cookie-authenticated mutation.
- **Authorization** is enforced per endpoint: platform permissions from
  `user_roles`/`role_permissions` for admin, per-membership capabilities for the
  portal, and a resource-level ownership check for anything addressed by id. A
  listing belonging to another account returns 404, not 403 — confirming it exists
  would leak a competitor's inventory.
- **SQL** is always parameterised; the query helper refuses a mismatched
  placeholder count. Sort keys and column names select from allow-lists.
- **Uploads** are validated by reading the actual image bytes, not the declared
  Content-Type. Storage keys are randomised and carry nothing the caller supplied.
- **Secrets** (payment provider keys) are AES-256-GCM encrypted at rest and never
  returned; the API reports `{ configured, hint }`.
- **Errors** never carry SQL, a stack trace or a constraint message. Every
  response carries `X-Request-ID`, and every error body carries the same
  `traceId`.
- **Logs** redact credentials, cookies and tokens at every depth.
- **CORS** echoes an explicit origin, never `*`, and always with credentials enabled.
  The allow-list is authoritative in production. Outside production any loopback origin
  is also accepted, because `localhost` and `127.0.0.1` are different origins to a
  browser and rejecting whichever one the developer typed blocks every request.

## Storage

`StorageAdapter` has two implementations and two visibilities:

- `public` — listing galleries, logos, agent photos. Served under
  `STORAGE_PUBLIC_BASE_URL`.
- `private` — verification and identity documents. No public URL exists; they are
  read back only through an authorised endpoint or a short-lived signed link.

### Seeded CDN imagery

`db/seeds/*` ship absolute `https://cdn.livfinder.com/...` URLs for roughly 2,500
avatars, logos, covers and hero images across a dozen tables. That host is real in a
deployed environment and resolves nowhere else, so without help every one of those
images renders broken.

`middleware/legacyMedia.js` rewrites them on the response — one place, rather than in
each of the many serializers that emit an image URL, and without editing seed data that
is not actually wrong. With `MEDIA_CDN_BASE_URL` set the URLs are rewritten to that
origin; with it empty the API serves a generated stand-in from `/media/placeholder/...`,
deterministic per path so a given agent always gets the same colour and initials.
`MEDIA_LEGACY_CDN_HOST` names the host to look for.

`STORAGE_DRIVER=local` writes under `LOCAL_STORAGE_PATH` and the API serves the
public tree at `/media`. `STORAGE_DRIVER=s3` uses AWS SDK v3 and works with S3,
R2, MinIO or Spaces via `STORAGE_ENDPOINT`. Both support presigned uploads: S3
returns a genuine presigned `PUT`, and the local driver returns an HMAC-signed
endpoint that behaves the same way, so the client flow is identical in
development.

## API surface

| Group | Path |
|---|---|
| Health | `GET /health`, `/health/database`, `/health/storage` |
| Public marketplace | `GET /v1/public/home`, `/listings`, `/listings/by-path`, `/listings/:reference`, `/companies`, `/companies/:slug/profile`, `/agents`, `/agents/:slug`, `/directory`, `/listing-agency`, `/countries`, `/locations`, `/filter-options/:category/:key`, `/:category/search-options`, `/:category/popular-searches`, `/hierarchy/:category`, `/editorial`, `/blogs`, `/sitemap`, `/redirects` |
| Auth | `POST /v1/auth/login`, `/logout`, `/forgot-password`, `/reset-password`, `/change-password`, `/email/verify`, `/email/resend`, `/active-account`; `GET /session`, `/sessions`, `/oauth/:provider`, `/oauth/:provider/callback` |
| Accounts | `POST /v1/accounts/personal/signup`, `/organization/signup`, `/verification/uploads/presign`, `/verification/submit`; `GET /verification/status`, `/me`, `/email-available` |
| Media | `POST /v1/media/upload`; listing gallery `GET/POST /v1/media/listings/:id/media`, `PATCH .../reorder`, `PATCH/DELETE .../:mediaId`; `GET /v1/media/verification-documents/:id` |
| Engagement | `/v1/favourites`, `/v1/saved-searches`, `/v1/inquiries`, `/v1/bookings`, `/v1/offers`, `/v1/notifications` |
| Portal | `/v1/portal/dashboard`, `/listings`, `/leads`, `/inquiries`, `/messages`, `/bookings`, `/offers`, `/reviews`, `/favourites`, `/saved-searches`, `/profile`, `/organization`, `/organization/agents`, `/categories`, `/category-requests`, `/access-requests`, `/integrations`, `/payments`, `/billing`, `/payouts`, `/settings/{account,notifications,privacy}` |
| Admin | `/v1/admin/dashboard`, `/listings`, `/developments`, `/developers`, `/companies`, `/individuals`, `/agents`, `/leads`, `/contacts`, `/articles`, `/media`, `/reviews`, `/reports`, `/roles`, `/access-users`, `/system-logs`, `/packages`, `/categories`, `/locations/*`, `/settings/*`, `/permission-catalog`, `/me/permissions` |

Lists answer `{ data, pageInfo: { page, pageSize, total, totalPages, hasMore } }`
(admin lists answer `{ items, total, page, pageSize, totalPages, summary, options }`,
the shape those tables were built for). Detail and mutation endpoints answer
`{ data }`. Errors answer:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Some information is invalid.",
             "fields": { "email": "Enter a valid email address." },
             "traceId": "…" } }
```

## Configuration

See `.env.example` for the full list. The ones that matter:

`DB_HOST` `DB_PORT` `DB_USER` `DB_PASSWORD` `DB_NAME` `DB_SOCKET` ·
`PORT` `FRONTEND_URL` `LIVFINDER_ALLOWED_ORIGINS` `TRUST_PROXY` ·
`SESSION_SECRET` (≥32 chars; also derives the CSRF and settings-encryption keys)
`SESSION_COOKIE_NAME` `SESSION_TTL_DAYS` `COOKIE_DOMAIN` `COOKIE_SAMESITE` ·
`STORAGE_DRIVER` `LOCAL_STORAGE_PATH` `STORAGE_PUBLIC_BASE_URL` `STORAGE_ENDPOINT`
`STORAGE_REGION` `STORAGE_BUCKET` `STORAGE_ACCESS_KEY` `STORAGE_SECRET_KEY` ·
`MEDIA_LEGACY_CDN_HOST` `MEDIA_CDN_BASE_URL` ·
`MAIL_DRIVER` `MAIL_FROM` `SMTP_*` · `PAYMENTS_DRIVER` `STRIPE_*` ·
`LOG_LEVEL` `RATE_LIMIT_*`

`SESSION_SECRET` is validated at boot; the process refuses to start without a
usable one. Nothing secret is ever exposed under a `NEXT_PUBLIC_` name.

## Scheduling

`npm run maintenance` should run on a timer (every few minutes is enough). It
returns crashed workers' queue claims, releases expired locks, half-opens cooled
circuit breakers, expires lapsed listings, drains the search-index queue and
refreshes the derived counters. Without it the database's own integrity checks
correctly report a growing operational backlog.

## What changed on 28 August 2026

Worked through the Gap Register, the Pending Work Register and the API Anatomy. The short
version: the write path is connected, the permission model is rebuilt, and several endpoints
that had never successfully run now do.

### Permissions — rebuilt

Two vocabularies existed and only one was enforced, so the Role Access matrix showed per-category
control that did not exist: ticking "Cars → Edit" produced a role that could edit every category.
Migration `0032` replaces both with `<domain>.<action>` (105 codes) and moves the category onto
the grant as a **scope** (`role_scopes`), which is what LIV-IAM-001 §6.2 asks for and what makes
per-category control real. Full write-up: `db/db/docs/permissions.md`.

### New endpoints

`PATCH /admin/companies/:id` · `PATCH /admin/individuals/:id` · `POST|PATCH /admin/agents` ·
`PATCH /admin/companies/:id/package` · `POST|PATCH|DELETE /admin/developments` ·
`POST|PATCH|DELETE /admin/brands` and `/admin/brand-models` ·
`POST /admin/users/:id/reset-access` · `GET /admin/audit-events` ·
`DELETE /auth/sessions/:id` · `GET|POST|DELETE /auth/mfa` · `POST /auth/step-up`

### Services that were modelled but inert

- **Notifications.** 420 seeded rows, working read endpoints, no producer. Now written on an
  enquiry, a viewing, an offer and a moderation decision — `modules/system/notifications.service.js`.
- **Analytics.** `listing_daily_stats` had no writer, so every trend chart was frozen at the seed
  dates. Views and enquiries now increment it, and `npm run maintenance` reconciles any drift.
- **Redirects.** Eight seeded rows with nothing consulting them; `frontend/src/middleware.js` does.
- **MFA and step-up.** SEC-IAM-002 and SEC-IAM-011. TOTP verified against the RFC 6238 vectors.
- **Idempotency-Key.** SEC-API-004. A retried enquiry, viewing or offer now arrives once.
- **SSRF allow-list.** SEC-APP-012. The OAuth callback fetched administrator-supplied URLs with
  no destination checks; the cloud metadata endpoint is now refused.
- **Upload scanning.** SEC-APP-011. `scan_status` records the truth — `skipped` when no scanner
  is configured, which is a different claim from `clean`. The seeds said `clean` for 5,723 files
  nothing had ever looked at; that is corrected.

### Defects found while working

Each of these made a real user action fail:

- Inquiries, bookings and offers returned the **listing's** id, status, created_at and currency,
  because `PORTAL_LISTING_COLUMNS` was spliced in after the entity's own columns and mysql2 keys
  a row by column name. No `PATCH` could ever match.
- `inquiry_status_history.note`, `offer_events.occurred_at` and `activities.subject` do not
  exist — every status change, offer response and lead note was a 500.
- `offers.status` has no `'new'` member, so no offer could ever be placed from the marketplace.
- `legacyMediaRewrite` mutated its payload, throwing on any response containing a frozen object.
- A function in the admin catalogue payload crossed the RSC boundary, crashing the Roles page.
- `verifyPassword` returns `{ valid }`, not a boolean — treating it as truthy would have made
  every MFA recovery code match. Caught by its own test.

### Verification

`./.work/verify-all.sh` runs everything: 190 backend tests, 94 smoke checks, 16 health checks,
331 frontend tests, 84 pages asserted with content proof, 37 write assertions against the
database, 101 seed assertions and 209 integrity checks.
