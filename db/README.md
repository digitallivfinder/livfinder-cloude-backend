# Liv Finder

A global luxury marketplace across six asset classes — real estate, cars, yachts,
jets, helicopters and watches.

This repository currently contains **the backend database**: schema, seed data and
tooling. The frontend (Next.js 16 / React 19, four route groups: public
marketplace, authentication, client portal, admin portal) lives separately and is
documented in its own project audit.

---

## What is here

```
db/          the database — 506 tables, 29 migrations, 47 ordered seed files, tooling
```

See **[db/README.md](db/README.md)** for the full guide. The short version:

```bash
cd db
cp .env.example .env
tools/load.sh all --fresh
```

About 30 seconds, ending with 40+ consistency assertions reporting `PASS`.

---

## Highlights

**A real five-level location hierarchy.**
Country → State → City → Community → Sub-Community, with 161,142 rows.
Countries, states and cities are sourced from ISO 3166 open data — 250 countries
with dialling codes and currencies, 5,308 ISO 3166-2 subdivisions, 152,976 cities
with coordinates. Communities and sub-communities are hand-authored for the
markets that matter: Dubai alone has 91 communities and 663 sub-communities at
Bayut/Property Finder parity, and 40 other countries are curated to community
depth or deeper. Nothing is invented — where a market does not genuinely use a
fifth tier, it has none. Coverage matrix in
**[db/docs/LOCATIONS.md](db/docs/LOCATIONS.md)**.

**Six asset classes, one marketplace, no compromise on search.**
A shared `listings` table for everything genuinely common, five per-category
detail tables giving each class real typed indexed columns for its own filters,
a declarative attribute registry so adding a field is an `INSERT`, and a
maintained flat read model (`listing_search`) so a result page is one indexed
range scan instead of a seven-table join.

**Built for scale from the start.**
Monotonic primary keys, opaque ULID public ids, composite indexes ordered to serve
filter and sort from one index, month-partitioned event and audit tables so
retention is a `DROP PARTITION`, daily rollups so no dashboard ever aggregates
the raw stream, and a double-entry ledger that balances. Reasoning and the scaling
path in **[db/docs/PERFORMANCE.md](db/docs/PERFORMANCE.md)**.

**Counts that cannot lie.**
Every counter is either a `COUNT` over an index built for it, or a value derived
by a stored procedure from the rows it counts — and the seed asserts they agree.
This is a direct response to the frontend audit, which found tab labels, summary
cards and pagination totals across seven screens to be hardcoded numbers that
disagreed with the data behind them.

**Global by construction.**
Multi-currency with a base-currency amount on every priced row (so cross-currency
sorting is one indexed comparison), FX snapshots stored on financial rows, dual
metric/imperial columns for the filters where both are genuinely used, translation
tables for locations, categories, features, listings and editorial content, and
per-country address formats, measurement systems and subdivision labels.

---

## Also addressed here

Five gaps the frontend audit called out as designed-but-not-built or
deferred-to-backend now have a real data model:

| Audit finding | Where it lives now |
|---|---|
| Organisation roles (owner/manager/viewer) existed only as unused function signatures | `account_members.role` + `v_account_permissions` — roles are per *membership*, so the same person can hold different ones at different agencies |
| No way to change account type after signup | `account_type_change_requests` + `account_type_transitions` — a reviewable workflow with document upload and an audit trail |
| Call and WhatsApp buttons inert site-wide because no fixture had the fields | `listings.contact_phone` / `contact_whatsapp` / `contact_email`, resolved at write time, plus per-channel `allow_*` flags |
| Session identity in a client-set, non-HttpOnly cookie | `user_sessions` — server-side rows storing only the SHA-256 of the token, with `session_epoch` for global sign-out |
| No persistent moderation or audit store | `reports` + `report_actions` + `moderation_queue` + partitioned `audit_logs` with field-level before/after |

Plus: 404 URLs reaching `sitemap.xml` (the sitemap is now a table built from the
visibility *view*, with per-URL verification), and no verification pipeline
(`verification_requests` with licence expiry checks).

---

## Status

The database is complete and verified: every migration and seed loads cleanly with
foreign key checks enabled, and both assertion suites pass. It has been validated
against a live server end to end.

Next steps, in order:

1. Point the API layer at this schema — the views and stored routines are the
   intended seams.
2. Enable migration `0015` if you are on MySQL 8, for radius search, CJK
   full-text and indexed feature-set filters.
3. Wire the scheduled jobs listed in `db/docs/PERFORMANCE.md`; every derived
   structure in the schema depends on one.
4. Geocode the community centroids currently left `NULL` before enabling map
   search in those markets.

---

## Changes made while wiring the API (2026-08-26)

The schema is unchanged apart from one additive migration. The rest were
compatibility fixes needed to load cleanly on MySQL 8.4.

**`migrations/0030_backend_integration.sql`** — additive only:
JSON-valued `settings` rows for the admin General/Payment Settings documents and
for the payment provider credentials (`is_secret = 1`, encrypted by the API), and
four covering indexes for the portal listings screen, the admin lead pipeline,
the portal inquiry inbox and the favourites list.

**Seed compatibility with MySQL 8.4** — behaviour is unchanged in every case:

| File | Fix |
|---|---|
| all seeds | `CREATE TEMPORARY TABLE` → `CREATE TABLE` for the `tmp_*` scratch tables. MySQL cannot reference the same temporary table twice in one statement ("Can't reopen table"), which several seeds do. |
| all seeds | `SET @today = CURDATE()` → `CAST(... AS CHAR) COLLATE utf8mb4_unicode_ci`. MySQL 8.4 gives a user variable assigned a temporal value `latin1_swedish_ci`, which then collides with utf8mb4 literals inside `CASE`. |
| `053_tax_and_accounting.sql` | `system` quoted — it is a reserved word in MySQL 8. |
| `060_operations.sql` | Claiming a queue message now pushes `visible_at` forward by the visibility timeout, so a live in-flight claim no longer looks like a dead worker. |
| `075_crm_search_ops_extensions.sql` | `location_boundaries` polygons written latitude-first, matching `POINT(latitude, longitude)` in migration `0015`. SRID 4326 is latitude-first in MySQL. |

**`tools/integrity_check.sql`** — three checks referenced columns that do not
exist and could never pass: `permits` → `listing_permits` (and `expires_on` →
`expires_at`); `distributed_locks.released_at` removed, since releasing a lock
deletes its row, with the same one-hour grace the neighbouring operational checks
use.

The loader needs a relaxed `sql_mode` for a handful of seeds that use
`ONLY_FULL_GROUP_BY`-incompatible aggregates. `STRICT_TRANS_TABLES` is kept, so
bad data still errors rather than truncating:

```bash
mysql --init-command="SET SESSION sql_mode='STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION'" …
```

**Scheduled jobs.** The four operational integrity checks — stuck queue messages,
expired locks, open circuit breakers, stuck index queue — measure the absence of
the scheduled pass this repository's "next steps" called for. It now exists as
`livfinder-backend/npm run maintenance` and should run on a timer. With it, all
93 standalone checks and all 101 seed assertions pass.

