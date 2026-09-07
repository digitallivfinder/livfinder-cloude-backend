# Performance and scaling

Why the schema looks the way it does, what to measure, and what to change as
volume grows.

---

## The four decisions that matter most

### 1. Monotonic primary keys

Every table uses `BIGINT UNSIGNED AUTO_INCREMENT`. InnoDB stores rows in
primary-key order, so a monotonic key means inserts always append to the
right-most page. A random key (a UUID stored as a string, or `UUID()` in its
default layout) scatters inserts across the whole index, causing page splits, a
fragmented tablespace, and a buffer pool that has to hold far more of the index
to stay warm. At high write rates this is the difference between a working system
and a stalling one.

Public identifiers are separate: `public_id CHAR(26) ASCII` holding a ULID.
Sortable by creation time, opaque to clients, 26 bytes, and portable — it needs
no `UUID_TO_BIN()`, which MariaDB does not have. Internal ids are never exposed.

### 2. Deliberate denormalisation, with enforcement

Two places break normal form on purpose. Both are documented in the migration
that does it, and both are enforced so they cannot drift.

**The location chain on `listings`.** `country_id`, `state_id`, `city_id`,
`community_id` and `sub_community_id` are all stored, not just the deepest.
"Villas in Dubai" then becomes one indexed predicate rather than a join to
`locations` plus a closure walk — on the single most-executed query in the
product. Maintained by `trg_listings_location_bi` / `_bu`, so any write path
produces a consistent chain.

**Contact details on `listings`.** Resolving a phone number through
listing → agent → branch → organisation at render time is both a join and a
policy question (which number wins?). Storing the resolved value makes the
lead-generation path a column read, and lets an individual listing override the
agency default.

### 3. Class-table inheritance for category specifications

Six asset classes share ~70 specification columns between them, of which any one
row uses about 12. Three options:

| Approach | Range filters | Row width | Verdict |
|---|---|---|---|
| All columns on `listings` | Fast | ~70 columns, permanently sparse | Bloats the hottest clustered index |
| JSON only | Full scan | Narrow | Cannot serve `bedrooms >= 3 AND area BETWEEN …` from an index |
| Detail table per class | Fast | Narrow | **Chosen** |

Five tables — `listing_real_estate`, `listing_vehicle`, `listing_marine`,
`listing_aviation`, `listing_timepiece` — each keyed 1:1 on `listings.id`.
Helicopters and jets share `listing_aviation` because their specification set is
genuinely identical; `root_category_id` separates them.

The long tail lives in `listings.attributes` (JSON) for rendering, and in
`listing_attribute_values` (typed EAV) for the rare filterable-but-not-promoted
field. `attributes.backing_column` records which physical column backs each
registered attribute, so the mapping exists in exactly one place.

### 4. A maintained read model for search

MySQL has no materialized views, so `listing_search` is the equivalent: one flat
row per publicly visible listing carrying everything a result card renders —
title, price, cover image, pre-rendered location breadcrumb, agent name and
photo, agency name and logo, contact numbers, and the category's filterable
specs.

Assembled normally, a result page joins `listings` to `locations` ×4, `agents`,
`organizations`, `listing_media` and a detail table, with an `ORDER BY` and a
`LIMIT/OFFSET` on top. From the projection it is one indexed range scan.

The trade-off, stated plainly: it is duplicated data and it can go stale. Three
things keep it honest.

1. It is derived, never authoritative. If it disagrees with `listings`, it is
   wrong and gets rebuilt.
2. `sp_refresh_listing_search(listing_id)` rebuilds one row from source. The
   application calls it on write; a job calls it for anything whose
   `source_updated_at` lags `listings.updated_at`.
3. It holds only public listings. Nothing in the portal or admin reads it, so a
   staleness bug can never affect an owner's view of their own data.

If you would rather not carry it, drop the table and point search at
`v_public_listings`. Everything else works unchanged; you pay the joins.

---

## Index strategy

Indexes here are wide composites rather than many single-column indexes, because
MySQL uses one index per table reference. A composite in the right column order
is what turns a filesort into an index scan.

The order is **equality predicates → range predicate → sort key**, and it follows
observed filter-panel usage rather than schema order.

```sql
-- ix_ls_city_price (city_id, root_category_id, purpose_id, price_base)
SELECT * FROM listing_search
 WHERE city_id = 1000032 AND root_category_id = 1 AND purpose_id = 1
   AND price_base BETWEEN 2000000 AND 8000000
 ORDER BY price_base LIMIT 24;
--  three equalities, then a range on the fourth column, then ORDER BY on that
--  same column: one index, no filesort.
```

The projection carries three orderings per location tier — `price_base`,
`published_at`, `quality_score` — because those are the three sorts the UI
offers, and a query can only use one index.

### Generic spec columns

`listing_search` uses `spec_a`..`spec_f` and `facet_a`..`facet_c` rather than
category-specific columns, so one set of indexes serves all six classes instead
of five-sixths of the columns sitting NULL on every row:

| | `spec_a` | `spec_b` | `spec_c` | `spec_d` | `spec_e` | `spec_f` |
|---|---|---|---|---|---|---|
| property | bedrooms | bathrooms | built sqft | plot sqft | year built | floor |
| cars | model year | mileage km | horsepower | engine cc | seats | doors |
| yachts | LOA ft | build year | cabins | guests | engine hrs | max knots |
| aviation | year built | total hours | pax | range nm | cycles | cruise kts |
| watches | year | case mm | power reserve | water res. m | jewels | — |

The mapping exists in exactly one place — `sp_refresh_listing_search()` — so it
cannot drift between writer and reader. `spec_labels` (JSON) carries the
human-readable rendering so a card needs no knowledge of the mapping.

### Dual-unit columns

`built_area_sqm` **and** `built_area_sqft`; `mileage_km` **and**
`mileage_miles`; `length_overall_m` **and** `length_overall_ft`. Both are stored
and both are indexed, because converting inside a `WHERE` clause defeats the
index and the two halves of a global market genuinely filter in their own unit.

---

## Partitioning

Eleven tables are partitioned by month on their timestamp — all append-only, all
growing without bound:

| Table | What it holds | Typical retention |
|---|---|---|
| `analytics_events` | The raw behavioural stream | 13 months |
| `audit_logs` | Who did what to which row | 7 years |
| `system_logs` | Application and job logging | 30 days |
| `ad_impressions` | Every ad served | 90 days |
| `ad_events` | Clicks, video quartiles, conversions | 90 days |
| `search_result_events` | Impression, click and dwell per result position | 180 days |
| `message_delivery_events` | Sent, delivered, opened, bounced, complained | 12 months |
| `api_request_logs` | Inbound and outbound API traffic | 30 days |
| `field_change_log` | Field-level change history | 7 years |

The retention windows are not documentation: they are rows in
`retention_policies`, and `retention_runs` records what each pass actually did.

The reason is retention. Dropping a month is `ALTER TABLE … DROP PARTITION` —
effectively instant, and it returns the space to the filesystem. The alternative,
`DELETE … WHERE occurred_at < …`, takes hours on a large table, generates an
enormous amount of redo, blocks, and leaves the tablespace bloated because InnoDB
does not return freed pages to the OS.

Two consequences to know about:

- **No foreign keys.** InnoDB forbids them on partitioned tables. For an audit
  log that is correct anyway: an audit row must outlive the thing it refers to.
  For the event tables it is a deliberate trade — a page view must never block on
  a lock held against `listings`.
- **Every unique index must contain the partitioning column.** Hence
  `PRIMARY KEY (id, occurred_at)` rather than `(id)`.

A third consequence, specific to this schema: a partitioned table cannot be the
target of a legal hold in the usual way, because `DROP PARTITION` is
all-or-nothing. Where a hold covers partitioned data, the retention policy is
switched from `drop_partition` to `delete` for the duration — slower, but it can
be filtered.

Partitions must be created ahead of time. `jobs.partition_maintenance` runs
monthly and adds the next month while dropping anything past retention. Rows
beyond the last defined partition land in `p_max`; if `p_max` starts growing,
maintenance has stopped running.

```sql
-- Add next month
ALTER TABLE analytics_events REORGANIZE PARTITION p_max INTO (
  PARTITION p2027_02 VALUES LESS THAN (TO_DAYS('2027-03-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- Drop past retention
ALTER TABLE analytics_events DROP PARTITION p2026_06;
```

---

## Counters: never on the request path

Denormalised counters (`view_count`, `inquiry_count`, `favourite_count`,
`active_listing_count`, …) are **never incremented synchronously on a page view**.
A popular listing would serialise every concurrent viewer behind one row lock,
and that lock is held for the duration of the transaction.

Instead:

- **Traffic counters** come from the daily rollups. There is no fact table for a
  page view, so the rollup *is* the source of truth for those.
- **Counters that have a fact table** are derived from it. `inquiry_count` comes
  from `COUNT(inquiries)`, not from `SUM(listing_daily_stats.inquiries)` —
  inquiries are permanent rows while rollups are pruned on a retention schedule,
  so sourcing the counter from the rollup silently undercounts every listing older
  than that retention. (This was a real bug, caught by the assertion suite.)

`sp_refresh_entity_counters()` is the reconciliation pass. Counters are maintained
incrementally in normal operation; the procedure exists so drift is *bounded and
detectable* rather than permanent. Run nightly.

**No dashboard queries `analytics_events`.** Ever. Everything user-facing reads a
`*_daily` rollup, which is small and indexed for exactly the query the dashboard
makes. Aggregating the raw stream at request time is what turns a dashboard into
an outage.

---

## Money

`DECIMAL(18,2)` throughout, never `FLOAT`. Binary floating point cannot represent
`0.10` exactly, and errors compound across a ledger.

Every priced row stores two amounts:

- `price` + `currency_code` — what the customer sees, and what the processor
  charged.
- `price_base` — the same amount in the platform base currency (AED).

`price_base` exists because sorting a mixed-currency result set by price is
otherwise either wrong or an FX join per row. It is computed at write time.

Financial rows additionally store `exchange_rate` on the row itself, not looked
up later, because a refund six months on must use the original rate.

`ledger_entries` is double-entry: every movement produces balanced debit and
credit rows sharing a `transaction_group`. For any group,
`SUM(debit) = SUM(credit)`. That is what makes the finance reports reconcilable
rather than merely plausible, and it is asserted in the integrity suite.

---

## MySQL 8 versus MariaDB

Migrations `0001`–`0014` load unchanged on both. `0015` is MySQL-8-only and adds:

| Feature | Requires | Enables |
|---|---|---|
| `POINT NOT NULL SRID 4326` + `SPATIAL INDEX` | MySQL 8.0 | True radius search, ordered by real distance |
| `WITH PARSER ngram` on FULLTEXT | MySQL 5.7+ | Chinese and Japanese search (the default parser splits on whitespace and finds nothing) |
| `CAST(… AS UNSIGNED ARRAY)` multi-valued index | MySQL 8.0.17+ | `12 MEMBER OF (feature_ids)` as an index lookup |
| Descending indexes | MySQL 8.0 | "Newest first" pipelines properly instead of scanning backwards |

Without `0015`, radius search degrades to a bounding box over the indexed
`latitude`/`longitude` columns, CJK search does not work, and feature-set filters
scan the candidate set. Everything else is identical.

### The collation choice

The schema uses `utf8mb4_unicode_ci` rather than MySQL 8's faster
`utf8mb4_0900_ai_ci`, purely so the same files load on MariaDB. If you are
committed to MySQL 8, converting is worthwhile — but convert **all** tables or
none. A join between a `utf8mb4_unicode_ci` column and a `utf8mb4_0900_ai_ci` one
raises `Illegal mix of collations`, or worse, silently declines to use the index.
`0015` documents the conversion.

---

## Server configuration

Starting points for a dedicated instance. Measure before tuning further.

```ini
[mysqld]
# The single most important setting: 60-75% of RAM on a dedicated host. This
# schema's working set is index-heavy, and the buffer pool is what keeps it warm.
innodb_buffer_pool_size         = 24G
innodb_buffer_pool_instances    = 8

# Durability. flush_log_at_trx_commit = 1 is the only fully ACID setting; 2
# survives a process crash but not an OS crash. Use 1 for anything holding money.
innodb_flush_log_at_trx_commit  = 1
innodb_log_file_size            = 2G
innodb_flush_method             = O_DIRECT

# Concurrency
innodb_io_capacity              = 2000     # raise on NVMe
innodb_io_capacity_max          = 4000
innodb_read_io_threads          = 8
innodb_write_io_threads         = 8
max_connections                 = 500      # use a pooler; do not raise blindly

# Full-text
ngram_token_size                = 2        # 0015 only; cannot change per index later
innodb_ft_min_token_size        = 2        # so "GT", "M8", "S8" are indexable

# Statistics quality matters here: the wide composites only get chosen when the
# optimiser's cardinality estimates are good.
innodb_stats_persistent         = ON
innodb_stats_persistent_sample_pages = 64

character_set_server            = utf8mb4
collation_server                = utf8mb4_unicode_ci
```

Connection pooling is not optional at this table count. ProxySQL or the
framework's own pooler; `max_connections` is a ceiling, not a target.

---

## Scaling path

Roughly in the order the pressure arrives.

**Read replicas first.** This workload is overwhelmingly read-heavy. Route search,
category and detail pages to replicas; keep writes and anything read-after-write
(the portal, admin) on the primary. `listing_search` is designed for exactly this
— it is derived, so replica lag on it is visible only as a slightly stale search
result.

**Cache the shapes that do not change per user.** The category tree, the location
tree above city level, active FX rates, feature flags and settings are all small,
read constantly, and change rarely. Redis with a long TTL and explicit
invalidation on write.

**Move search to a search engine when facets get expensive.** `listing_search`
will carry a marketplace a long way, but faceted counts across many dimensions
are what relational databases are worst at. When facet computation starts
dominating, mirror the projection into Elasticsearch or OpenSearch — it is
already flat and denormalised for exactly that shape, so the mapping is
mechanical.

**Move analytics out of MySQL when the event stream outgrows retention.** The
partitioned tables are the right structure for tens of millions of rows. Past
that, stream events to ClickHouse or BigQuery and keep only the rollups in MySQL.
Nothing user-facing changes, because nothing user-facing reads the raw stream.

**Shard last, and by account.** Sharding is a large operational cost and should
be the final resort. If it becomes necessary, `account_id` is the natural key:
listings, inquiries, bookings, offers and finance all hang off it, so most
queries stay within one shard. Cross-shard reads (public search) come from the
projection, which can be maintained centrally.

---

## Queries worth watching

Add these to a slow-query dashboard from day one.

```sql
-- 1. The primary search. Should be a single index range scan.
EXPLAIN SELECT * FROM listing_search
 WHERE city_id = ? AND root_category_id = ? AND purpose_id = ?
   AND price_base BETWEEN ? AND ?
 ORDER BY quality_score DESC LIMIT 24;

-- 2. Deep pagination. LIMIT 10000, 24 reads 10,024 rows and throws away 10,000.
--    Prefer keyset pagination:
SELECT * FROM listing_search
 WHERE city_id = ? AND root_category_id = ?
   AND (quality_score, listing_id) < (?, ?)     -- last row of the previous page
 ORDER BY quality_score DESC, listing_id DESC LIMIT 24;

-- 3. Subtree counts. Fine at this size; if it becomes hot, read
--    location_category_stats instead, which is maintained for exactly this.
SELECT COUNT(*) FROM listings l
  JOIN location_closure c ON c.descendant_id = l.location_id
 WHERE c.ancestor_id = ? AND l.status = 'active';

-- 4. Feature-set filters. Indexed on MySQL 8 with 0015; a scan without it.
SELECT * FROM listing_search
 WHERE city_id = ? AND 12 MEMBER OF (feature_ids) AND 70 MEMBER OF (feature_ids);

-- 5. Inbox tab counts. The status column leads ix_inquiries_org_status so each
--    count is an index-prefix scan, not a table scan.
SELECT status, COUNT(*) FROM inquiries
 WHERE organization_id = ? AND deleted_at IS NULL AND is_spam = 0
 GROUP BY status;
```

---

## Scheduled work

Every derived structure in this schema has a job that maintains it, registered in
`jobs` so the admin portal can show what should be running and whether its output
is stale. If a number looks wrong, check `jobs.last_status` and
`jobs.max_staleness_minutes` before looking anywhere else.

| Job | Cadence | Maintains |
|---|---|---|
| `listing_search_refresh` | 5 min | The search projection, for rows whose source has moved |
| `analytics_rollup` | hourly | `*_daily_stats` from `analytics_events` |
| `listing_expiry` | hourly | Expires lapsed listings and drops them from the projection |
| `fx_refresh` | 6 h | `fx_rates` and `fx_rates_latest` |
| `entity_counters` | daily | Reconciles every denormalised counter |
| `location_counts` | daily | Per-location inventory, rolled up the subtree |
| `price_index` | daily | `price_index_daily` |
| `sitemap_rebuild` | daily | `sitemap_entries`, and verifies each URL resolves |
| `saved_search_alerts` | daily | Runs due saved searches, queues alerts |
| `session_cleanup` | daily | Reaps expired sessions and tokens in bounded batches |
| `license_expiry_check` | daily | Demotes lapsed verifications and licences |
| `partition_maintenance` | monthly | Adds the next partition, drops past retention |
