# Liv Finder — database

The complete backend database for a global luxury marketplace spanning six asset
classes: real estate, cars, yachts, jets, helicopters and watches.

**506 tables · 7 views · 4 stored routines · 4 triggers · 1,192 foreign keys ·
2,643 indexes · 161,142 real locations across five tiers · roughly a million
demo rows that are internally consistent by construction, with every table
populated.**

Target is **MySQL 8.0.16+**. Migrations `0001`–`0014` and `0016`–`0029` also
load unchanged on **MariaDB 10.11+**; `0015` is a MySQL-8-only optimisation
layer and is opt-in.

Everything here is plain SQL. There is no generator, no build step and no
language runtime: what is in `migrations/` and `seeds/` is what loads.

---

## Quick start

```bash
cd db
cp .env.example .env          # edit connection settings
tools/load.sh all --fresh     # drop, create, migrate, seed, verify
```

That takes about forty-five seconds on a laptop and ends with 101 assertions
reporting `PASS`. Or with make:

```bash
make fresh        # everything
make migrate      # migrations only
make seed         # seeds only
make verify       # re-run the assertions
make mysql8       # add the MySQL-8-only optimisations
make integrity    # the nightly consistency checks
make counts       # row counts
```

Using Docker instead:

```bash
docker compose up -d
docker compose exec -T mysql mysql -uroot -proot livfinder < /dev/null  # wait for ready
tools/load.sh all --fresh --with-mysql8
```

---

## What is in here

```
db/
  migrations/            29 ordered DDL files, applied in filename order
  seeds/                 47 data files, applied in filename order
  tools/
    load.sh              loader; keeps foreign-key checks on throughout
    integrity_check.sql  consistency checks for cron
  docs/
    SCHEMA.md            table-by-table reference, grouped by domain
    LOCATIONS.md         the geography model and its coverage matrix
    PERFORMANCE.md       indexing, partitioning and scaling notes
    ERD.md               entity-relationship diagrams
```

### Migrations

| File | Contents |
|------|----------|
| `0001_conventions_and_reference.sql` | Conventions, languages, currencies, FX rates, units, settings, feature flags |
| `0002_geography.sql` | The location tree, closure table, country/state profiles, translations, aliases, boundaries |
| `0003_taxonomy.sql` | Categories, purposes, the attribute registry, features, brands and models |
| `0004_identity_and_access.sql` | Users, accounts, account types and transitions, members, RBAC, sessions, GDPR |
| `0005_organizations_and_agents.sql` | Organisations, licences, branches, category access, agents, verification, API clients |
| `0006_listings.sql` | Projects, listings, translations, media library, features, price and status history |
| `0007_listing_details.sql` | Five per-category detail tables (real estate, vehicle, marine, aviation, timepiece) |
| `0008_engagement.sql` | Inquiries, messaging, favourites, collections, saved searches, bookings, offers, reviews, notifications |
| `0009_finance.sql` | Plans, subscriptions, invoices, payments, refunds, payouts, double-entry ledger, promotions |
| `0010_moderation_and_audit.sql` | Report reasons, reports, moderation queue, partitioned audit and system logs, abuse controls |
| `0011_editorial.sql` | Authors, editorial taxonomy, posts, pages, location landing pages, navigation, redirects |
| `0012_analytics.sql` | Partitioned event stream, daily rollups, search logs, price index, jobs, webhooks |
| `0013_search_projection.sql` | `listing_search` — the flat read model for public search — and `sitemap_entries` |
| `0014_views_and_routines.sql` | Visibility views, tree/counter/projection routines, integrity triggers |
| `0015_mysql8_optimizations.sql` | **Opt-in.** Spatial indexes, ngram full-text, multi-valued JSON indexes, descending indexes |
| `0016_media_asset_management.sql` | Asset library, renditions, crops, captions, EXIF, moderation, video, virtual tours, floor plans, resumable uploads, CDN purges |
| `0017_seo_platform.sql` | URL inventory and indexation rules, metadata templates, structured data, hreflang, redirects, internal links, backlinks, crawl auditing, sitemaps, content quality |
| `0018_payments_infrastructure.sql` | Gateways and routing, payment intents and attempts, 3-D Secure, mandates, splits, disputes, settlements, payouts, dunning, fraud scoring |
| `0019_tax_and_accounting.sql` | Jurisdictions, rates and rules, registrations, place of supply, chart of accounts, double-entry journals, revenue recognition, filings, budgets, period close |
| `0020_crm_and_leads.sql` | Contacts, leads, pipelines, routing pools, SLA clocks, activities, tasks, viewings, deals, commissions, call tracking, nurture |
| `0021_advertising_and_monetization.sql` | Advertisers, campaigns, line items, creatives, placements, delivery events, promotions and inventory, credits, affiliates |
| `0022_search_infrastructure.sql` | Ranking profiles and signals, synonyms, query rewrites, facets, curation, boosting, zero-result triage, experiments, similarity, index queue |
| `0023_feeds_and_integrations.sql` | Providers and connections, external reference map, field and value mappings, feed imports, API clients and logs, webhooks |
| `0024_compliance_and_contracts.sql` | Regulatory authorities, permits, KYC, beneficial ownership, sanctions screening, source of funds, contracts and signatures, suspicious activity reports |
| `0025_communications_and_support.sql` | Sending domains and reputation, suppressions, broadcast campaigns, delivery events, support tickets, knowledge base |
| `0026_platform_operations.sql` | Transactional outbox, durable queues, dead letters, idempotency keys, distributed locks, circuit breakers, workflows, health checks |
| `0027_tenancy_and_governance.sql` | Tenants, domains, settings and visibility rules, data field registry, ROPA, processors, retention, legal holds, consent receipts |
| `0028_property_inventory.sql` | Buildings, floors, units, ownership, registry transactions, tenancies, rent schedules, maintenance, valuations, mortgages, payment plans, market statistics |
| `0029_analytics_platform.sql` | Sessions, attribution models and touchpoints, conversions and credits, channel performance, funnels, cohorts, the metric dictionary, alerts, dashboards, reports |

### Seeds

| File | Rows | Contents |
|------|-----:|----------|
| `010_reference.sql` | ~150 | 15 languages, 24 currencies, FX rates, 20 units, settings, feature flags, 12 scheduled jobs |
| `020_geo_countries.sql` | 3,984 | 250 countries with ISO codes, dialling codes, currencies, plus 3,484 localised names |
| `021_geo_states.sql` | 10,616 | 5,308 ISO 3166-2 subdivisions with native names and coordinates |
| `022_geo_cities_*.sql` | 152,976 | Every city in the source dataset, with coordinates |
| `023_geo_communities.sql` | 1,103 | 809 curated communities + 288 search aliases |
| `024_geo_sub_communities.sql` | 1,799 | Curated sub-communities — the fifth tier |
| `025_geo_finalise.sql` | — | Rebuilds the closure table and paths, then asserts the tree is sound |
| `030_taxonomy.sql` | ~370 | 6 asset classes + 52 listing types, 65 attributes, 75 features, 14 report reasons |
| `031_brands.sql` | ~290 | 118 real brands across five maker kinds, 177 models |
| `032_access_and_plans.sql` | ~230 | 5 account types, 16 transitions, 26 permissions, 7 roles, 7 plans, 19 templates |
| `040_demo_identity.sql` | 1,955 | 328 users, 192 accounts, 42 organisations, 126 agents, licences, memberships |
| `041_demo_projects.sql` | 24 | Off-plan developments with payment plans |
| `042_demo_listings.sql` | 10,794 | 520 listings + detail rows + 5,637 media + features + translations + history |
| `043_demo_engagement.sql` | 6,413 | 720 inquiries, conversations, favourites, saved searches, bookings, offers, reviews |
| `044_demo_finance.sql` | 2,728 | Subscriptions, invoices, payments, payouts, 1,528 balanced ledger entries |
| `045_demo_editorial.sql` | 1,126 | 8 authors, 72 articles, taxonomy, 13 pages, landing pages, redirects |
| `046_demo_analytics.sql` | 68,654 | Daily rollups derived from the engagement rows, search logs |
| `047_demo_moderation.sql` | 1,348 | Reports with full action trails, moderation queue, verification, audit logs |
| `049_demo_finalise.sql` | — | Derives every counter and projection, then asserts they agree with their sources |
| `050_media.sql` | 20,000+ | Renditions, EXIF, moderation results, processing jobs, licences, usage rights |
| `051_seo.sql` | 6,000+ | URL inventory with indexation decisions, redirects, hreflang, search-console metrics |
| `052_payments.sql` | 3,000+ | Gateways and routing rules, intents and attempts, 3-D Secure, disputes, settlements |
| `053_tax_and_accounting.sql` | 8,000+ | Jurisdictions and rates, registrations, tax transactions, journals, revenue recognition |
| `054_crm.sql` | 12,000+ | Contacts, leads with scoring, pipelines, SLA clocks, activities, viewings, deals |
| `055_monetization.sql` | 5,000+ | Advertisers and campaigns, promotions with counted inventory, credit lots, affiliates |
| `056_search.sql` | 9,000+ | Ranking profiles, synonyms, rewrites, facets, zero-result triage, similarity |
| `057_integrations.sql` | 4,000+ | Providers, connections, external reference map, feed imports with a deletion safety valve |
| `058_compliance.sql` | 3,000+ | Permits with expiry, KYC cases, beneficial owners, sanctions screening, contracts |
| `059_communications.sql` | 6,000+ | Sending domains, reputation, suppressions, campaigns, support tickets, knowledge base |
| `060_operations.sql` | 2,500+ | Outbox, queues, dead letters, idempotency keys, locks, circuit breakers, workflows |
| `061_tenancy_governance.sql` | 4,000+ | 12 tenants with domains and visibility rules, the Article 30 record set, consent receipts |
| `062_property.sql` | 20,000+ | Buildings and units under the listings, ownership, transactions, tenancies, valuations, mortgages, market statistics |
| `063_analytics.sql` | 20,000+ | Sessions, touchpoints, four attribution models, funnels, cohorts, the metric dictionary, dashboards |
| `070_media_extensions.sql` | 27,000+ | Video, virtual tours, floor plans with rooms, crops, captions, uploads, gated documents |
| `071_seo_extensions.sql` | 20,000+ | Metadata templates, structured data, the link graph, backlinks, crawls, sitemaps, experiments |
| `072_translations.sql` | 1,200+ | Categories, attributes and features in four languages; the machine-translated long tail marked as such |
| `073_identity_extensions.sql` | 3,600+ | Sessions, one-time tokens, federated identity, second factors, consent log, identity documents |
| `074_finance_extensions.sql` | 12,000+ | Credit notes, mandates, splits, bank feeds and reconciliation, escrow, dunning, metered billing, quotes, budgets, tax filings |
| `075_crm_search_ops_extensions.sql` | 30,000+ | Lead forms and routing rules, requirements, sharing, nurture, curation, ad delivery, fraud, AML escalation |
| `099_platform_finalise.sql` | — | Re-derives the cross-layer counters, then asserts 89 platform invariants |

---

## The five-level location hierarchy

This is the part the rest of the schema hangs off, and the part most worth
reading about before using it — see **[docs/LOCATIONS.md](docs/LOCATIONS.md)**
for the full model and per-market coverage.

```
Country  →  State / Emirate / Province  →  City  →  Community  →  Sub-Community
  250              5,308                  152,976      809           1,799
```

Countries, states and cities are **real, sourced data** from
[`dr5hn/countries-states-cities-database`](https://github.com/dr5hn/countries-states-cities-database)
(ODbL), including ISO 3166-1 and 3166-2 codes, dialling codes, currencies,
coordinates and localised names.

Communities and sub-communities are **hand-authored** directly in
`seeds/023_geo_communities.sql` and `seeds/024_geo_sub_communities.sql`, because
no open dataset carries them at the granularity this market needs. Dubai alone has 91 communities and 663
sub-communities — Dubai Marina's 36 towers, Palm Jumeirah's 28 developments,
JLT's 26 clusters, Emirates Hills' sectors. Nothing in that data is generated:
where a market does not genuinely use a fifth tier, it has none rather than
invented names.

It is one table, not five. The reasoning is in the header comment of
`0002_geography.sql`; the short version is that breadcrumbs, subtree queries and
cross-level autocomplete are all one indexed lookup against a tree and a
five-way join against five tables, and real depth is not uniform anyway (Monaco
and Hong Kong have no state tier; Dubai has genuine building-level granularity).

Three access paths are maintained side by side, deliberately:

```sql
-- 1. URL → location, one unique-index hit, no recursion
SELECT id, level, name FROM locations
 WHERE path = 'united-arab-emirates/dubai/dubai/palm-jumeirah/shoreline-apartments';

-- 2. Breadcrumb, from the closure table
SELECT a.level, a.name
  FROM location_closure c JOIN locations a ON a.id = c.ancestor_id
 WHERE c.descendant_id = 60000001 ORDER BY c.depth DESC;
--  country → United Arab Emirates
--  state → Dubai
--  city → Dubai
--  community → Palm Jumeirah
--  sub_community → Shoreline Apartments

-- 3. Cascading dropdown, one level at a time
SELECT id, name FROM locations
 WHERE parent_id = 50000001 AND status = 'active' ORDER BY sort_order, name;

-- Alias search: what users actually type
SELECT l.name, l.path FROM location_aliases al JOIN locations l ON l.id = al.location_id
 WHERE al.alias_ascii = 'JBR';   -- → Jumeirah Beach Residence
```

---

## Verification

Two independent suites, both of which must report `0` on every row.

**`seeds/049_demo_finalise.sql`** derives all counters, rollups and the search
projection, then asserts the derived values agree with their sources. Run via
`make verify`:

```
listing.inquiry_count vs inquiries table                          PASS
listing.favourite_count vs favourites table                       PASS
agent.active_listing_count vs listings                            PASS
organization.agent_count vs agents                                PASS
listing_search covers exactly the public listings                 PASS
ledger is balanced per transaction group                          PASS
every active listing has a resolvable canonical path              PASS
no active listing lacks contact channels                          PASS
every agent has a profile slug                                    PASS
denormalised listing location chain matches locations             PASS
listing_daily_stats.inquiries reconciles with the inquiries table  PASS
sitemap contains no listing that is not publicly visible          PASS
```

**`seeds/099_platform_finalise.sql`** does the same for everything the corporate
layers added: 89 assertions covering tenancy and governance, the property
inventory, the analytics platform and the commercial and operational layers.
Every one of them must return zero failures. A sample:

```
current ownership shares sum to a hundred per unit                 PASS
rent instalments sum to the annual rent                            PASS
a valuation range brackets its own figure                          PASS
a market statistic below the sample floor is not publishable       PASS
attribution credit sums to exactly one per conversion per model    PASS
funnel completions and drops account for everyone who entered      PASS
a ratio KPI value agrees with its numerator over its denominator   PASS
campaign spend equals the sum of its spend entries                 PASS
promotion inventory is never oversold                              PASS
a credit lot balance equals grants less consumption                PASS
every journal balances                                             PASS
every personal-data field names an erasure action                  PASS
```

**`tools/integrity_check.sql`** is the nightly suite: checks covering
polymorphic references (which no foreign key protects), location tree soundness,
denormalised column drift, maintained counters, search-projection freshness,
money invariants and public-visibility rules. Run via `make integrity`.

Both suites found real bugs during development — a stored procedure that exited a
level-by-level loop early when a generation happened to need no changes, a
counter sourced from a rollup with a shorter retention than its fact table, and a
sitemap built from hand-repeated visibility conditions rather than from the view
that defines them. That is what they are for.

---

## Changing the seeds

There is nothing to regenerate. Every seed file is SQL you edit directly.

The demo data is mostly derived rather than typed: a seed file reads the rows
the previous files inserted and writes the rows that follow from them, using
`INSERT ... SELECT`. Where a value needs to look random it is hashed off the
source row's id —

```sql
MOD(CONV(SUBSTRING(MD5(CONCAT('some-salt:', l.id)), 1, 6), 16, 10), 100)
```

— so a reload reproduces the same database byte for byte, and a diff of the
loaded data shows only what actually changed. CRC32 is deliberately avoided for
this: its output correlates across similar inputs, so filtering on one CRC32
modulus and bucketing on another silently collapses the distribution.

To add a community or a whole market, edit `seeds/023_geo_communities.sql` or
`seeds/024_geo_sub_communities.sql` and reload. The format is a plain `VALUES`
list with the parent path in a comment above each block.

---

## Notes on the demo data

The demo dataset exists to exercise every screen, so it deliberately includes
states that a happy-path fixture would omit: listings in `draft`,
`pending_review`, `rejected` and `expired`; users in `pending_verification` and
`suspended`; a listing scheduled to publish in the future; reports at every
stage of the moderation lifecycle; failing webhooks; and expired licences.

Demo credentials are the bcrypt digest of `livfinder-demo` for every user, and
API client secrets are digests of throwaway strings. **This data must never be
loaded into an internet-reachable environment.**

---

## Reading order

If you are picking this up cold:

1. `migrations/0002_geography.sql` — the header comment explains the central
   modelling decision, and everything else references it.
2. `docs/LOCATIONS.md` — coverage, and what "real data" means per market.
3. `migrations/0006_listings.sql` and `0007_listing_details.sql` — the two
   deliberate denormalisations and the class-table-inheritance split.
4. `docs/PERFORMANCE.md` — why the indexes look the way they do, and what to
   change as volume grows.
5. `migrations/0004_identity_and_access.sql` — the user/account split, which is
   what makes organisation roles and account-type switching tractable.
