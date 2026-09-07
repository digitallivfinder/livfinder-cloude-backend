-- =============================================================================
-- Liv Finder — 0002 · Geography
-- =============================================================================
-- The location hierarchy the whole marketplace hangs off:
--
--     Country → State → City → Community → Sub-Community
--
-- MODELLING DECISION: one table, not five
-- ---------------------------------------
-- The admin portal presents five separate management screens, and the public
-- URLs are five segments deep, so five physical tables looks like the obvious
-- mapping. It is the wrong one, for three concrete reasons:
--
--   1. Breadcrumbs, "listings anywhere under Dubai", and the location facet all
--      need ancestor/descendant queries. Across five tables that is a five-way
--      join with a different shape per level; across one tree it is one indexed
--      lookup against the closure table.
--   2. Depth is not actually uniform in the real world. Monaco and Singapore
--      have no meaningful state. Dubai has genuine building-level granularity
--      below sub-community (Princess Tower, Shoreline Apartment 8). A fixed
--      five-table design cannot express either without lying.
--   3. Autocomplete searches all levels at once ("mar" → Marbella, Marina,
--      Marassi, Al Marjan Island). One table, one index, one query.
--
-- The five admin screens are served by `WHERE level = '...'`, which is an
-- indexed scan of exactly the rows that screen shows. Nothing is lost.
--
-- Three complementary access paths are maintained, deliberately redundant
-- because they serve different query shapes:
--
--   parent_id            → cascading dropdowns (one level at a time)
--   path / path_ids      → URL routing and breadcrumbs with zero joins
--   location_closure     → arbitrary-depth ancestor/descendant set operations
--
-- Plus denormalised country_id/state_id/city_id/community_id on every row, so
-- the overwhelmingly common "everything in this city" filter never touches the
-- closure table at all.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- locations — the tree
-- -----------------------------------------------------------------------------
CREATE TABLE locations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  parent_id      BIGINT UNSIGNED NULL,

  -- Semantic level. `district` and `building` are defined but not seeded: they
  -- exist so a market that needs a sixth tier (Dubai towers, Manhattan blocks)
  -- can be added as data, never as a migration.
  level          ENUM('country','state','city','district','community','sub_community','building') NOT NULL,

  -- Physical tree depth, 0 for country. Differs from `level` where a country has
  -- no state tier: Monaco's communities sit at depth 2, not 3. Routing uses
  -- `level`; tree maths uses `depth`.
  depth          TINYINT UNSIGNED NOT NULL,

  -- Denormalised ancestors. Redundant with the closure table by design: this is
  -- what makes "all listings in Dubai" a single indexed predicate on `listings`
  -- rather than a join. Maintained by the seed builder and by
  -- sp_location_rebuild_paths().
  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,

  name           VARCHAR(180)    NOT NULL,
  -- Diacritic-free, ASCII-folded form of `name`. "Málaga" → "Malaga",
  -- "Saint-Tropez" → "Saint Tropez". Autocomplete matches against this so a user
  -- typing on an English keyboard finds Nîmes, Ålesund and Şişli.
  name_ascii     VARCHAR(180)    NOT NULL,
  slug           VARCHAR(180)    NOT NULL,

  -- Full ancestor slug path without a leading slash:
  --   "united-arab-emirates/dubai/dubai/palm-jumeirah/shoreline-apartments"
  -- A URL resolves to a location in one unique-index hit, no recursion.
  path           VARCHAR(512)    NOT NULL,
  -- Same chain as ids: "1/3401/45213/900012/900431". Cheap breadcrumb rendering
  -- and a stable sort key for tree listings.
  path_ids       VARCHAR(255)    NOT NULL,

  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,
  timezone       VARCHAR(64)     NULL,

  status         ENUM('active','inactive','draft','merged') NOT NULL DEFAULT 'active',
  -- Excludes a row from public search/autocomplete while keeping it valid for
  -- existing listings and admin. Used for administrative tiers nobody searches by.
  is_searchable  TINYINT(1)      NOT NULL DEFAULT 1,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  -- Set on markets curated to full community/sub-community depth. Drives the
  -- "popular areas" modules and tells the UI a deep cascade is worth showing.
  is_core_market TINYINT(1)      NOT NULL DEFAULT 0,

  -- Where a location is deprecated in favour of another (renamed, merged,
  -- duplicate), status becomes 'merged' and this points at the survivor so old
  -- URLs can 301 instead of 404.
  merged_into_id BIGINT UNSIGNED NULL,

  population     BIGINT UNSIGNED NULL,
  area_sqkm      DECIMAL(14,3)   NULL,

  -- Rollups maintained by the stats job. Denormalised so category landing pages
  -- and the location facet can render counts without aggregating `listings`.
  listing_count        INT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,

  sort_order     INT             NOT NULL DEFAULT 0,

  -- Provenance, so a re-import can reconcile against the upstream dataset
  -- instead of duplicating rows.
  source         VARCHAR(40)     NULL,
  source_id      VARCHAR(60)     NULL,

  meta           JSON            NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_locations_public_id (public_id),
  -- A slug is unique among siblings, not globally: "downtown" may exist under
  -- Dubai and under Miami. `parent_id` is nullable and MySQL treats NULLs as
  -- distinct in unique indexes, so country slugs are additionally guarded by
  -- uq_locations_path below.
  UNIQUE KEY uq_locations_parent_slug (parent_id, slug),
  UNIQUE KEY uq_locations_path (path),
  UNIQUE KEY uq_locations_source (source, source_id),

  KEY ix_locations_parent (parent_id, status, sort_order, name),
  KEY ix_locations_level_status (level, status, name),
  KEY ix_locations_country_level (country_id, level, status),
  KEY ix_locations_state (state_id, level, status),
  KEY ix_locations_city (city_id, level, status),
  KEY ix_locations_community (community_id, level, status),
  -- Autocomplete: prefix match on the folded name, restricted to searchable
  -- rows, ordered by how much inventory the place has.
  KEY ix_locations_autocomplete (is_searchable, status, name_ascii(64), active_listing_count),
  KEY ix_locations_popular (status, level, active_listing_count),
  KEY ix_locations_bbox (latitude, longitude),
  KEY ix_locations_core_market (is_core_market, level, status),
  KEY ix_locations_merged (merged_into_id),
  KEY ix_locations_deleted (deleted_at),

  CONSTRAINT fk_locations_parent      FOREIGN KEY (parent_id)      REFERENCES locations (id) ON DELETE RESTRICT,
  CONSTRAINT fk_locations_country     FOREIGN KEY (country_id)     REFERENCES locations (id) ON DELETE RESTRICT,
  CONSTRAINT fk_locations_state       FOREIGN KEY (state_id)       REFERENCES locations (id) ON DELETE RESTRICT,
  CONSTRAINT fk_locations_city        FOREIGN KEY (city_id)        REFERENCES locations (id) ON DELETE RESTRICT,
  CONSTRAINT fk_locations_community   FOREIGN KEY (community_id)   REFERENCES locations (id) ON DELETE RESTRICT,
  CONSTRAINT fk_locations_merged_into FOREIGN KEY (merged_into_id) REFERENCES locations (id) ON DELETE SET NULL,

  -- NOTE: a `CHECK (parent_id <> id)` cannot be declared here — neither MySQL 8
  -- nor MariaDB permits an AUTO_INCREMENT column inside a CHECK. Self-parenting
  -- and longer cycles are prevented by the trigger in 0016 instead.
  CONSTRAINT ck_locations_lat CHECK (latitude  IS NULL OR (latitude  BETWEEN  -90 AND  90)),
  CONSTRAINT ck_locations_lng CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Full-text index for multi-word/fuzzy location search. Added separately because
-- InnoDB FULLTEXT cannot be declared inline alongside the FK definitions above
-- on every supported version.
ALTER TABLE locations ADD FULLTEXT KEY ft_locations_name (name, name_ascii);

-- -----------------------------------------------------------------------------
-- location_closure — transitive ancestor/descendant edges
--
-- One row per (ancestor, descendant) pair including the self-pair at depth 0.
-- Answers both directions in one indexed read:
--
--   descendants of X  → WHERE ancestor_id   = X     (drives "listings anywhere
--                                                    under Dubai")
--   ancestors of Y    → WHERE descendant_id = Y     (drives breadcrumbs)
--
-- ~4 rows per node at five levels, so ~650k rows for the full global tree — a
-- rounding error next to the query cost it removes.
-- -----------------------------------------------------------------------------
CREATE TABLE location_closure (
  ancestor_id    BIGINT UNSIGNED NOT NULL,
  descendant_id  BIGINT UNSIGNED NOT NULL,
  -- Generations between the two. 0 = the self-referencing row.
  depth          TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (ancestor_id, descendant_id),
  KEY ix_location_closure_descendant (descendant_id, depth),
  KEY ix_location_closure_ancestor_depth (ancestor_id, depth),
  CONSTRAINT fk_location_closure_ancestor   FOREIGN KEY (ancestor_id)   REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_location_closure_descendant FOREIGN KEY (descendant_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- location_country_profiles — country-only attributes
--
-- Kept out of `locations` deliberately. These ~20 columns apply to 250 of
-- ~160,000 rows; carrying them inline would bloat every page of the tree's
-- clustered index and slow the scans that actually matter.
-- -----------------------------------------------------------------------------
CREATE TABLE location_country_profiles (
  location_id    BIGINT UNSIGNED NOT NULL,
  iso2           CHAR(2)         NOT NULL,
  iso3           CHAR(3)         NOT NULL,
  numeric_code   CHAR(3)         NULL,
  phone_code     VARCHAR(16)     NULL,
  capital        VARCHAR(120)    NULL,
  currency_code  CHAR(3)         NULL,
  tld            VARCHAR(16)     NULL,
  native_name    VARCHAR(180)    NULL,
  nationality    VARCHAR(120)    NULL,
  region         VARCHAR(60)     NULL,
  subregion      VARCHAR(80)     NULL,
  emoji_flag     VARCHAR(16)     NULL,

  -- Address/format hints the listing forms and validators use per market.
  postal_code_format VARCHAR(120) NULL,
  postal_code_regex  VARCHAR(255) NULL,
  measurement_system ENUM('metric','imperial') NOT NULL DEFAULT 'metric',
  default_area_unit  VARCHAR(20) NOT NULL DEFAULT 'sqm',
  drive_side         ENUM('left','right') NULL,

  -- What the state tier is actually called here, so the admin UI and public
  -- breadcrumbs can say "Emirate", "Province", "Region" or "County" instead of a
  -- generic "State" that is wrong in most of the world.
  state_label    VARCHAR(40)     NOT NULL DEFAULT 'State',
  -- Depth genuinely curated for this country (see docs/LOCATIONS.md). 3 means
  -- country/state/city only; 5 means communities and sub-communities exist.
  curated_depth  TINYINT UNSIGNED NOT NULL DEFAULT 3,

  -- Marketplace controls, independent of whether the country exists as data.
  is_supported   TINYINT(1)      NOT NULL DEFAULT 0,
  is_listing_enabled TINYINT(1)  NOT NULL DEFAULT 0,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (location_id),
  UNIQUE KEY uq_country_profiles_iso2 (iso2),
  UNIQUE KEY uq_country_profiles_iso3 (iso3),
  KEY ix_country_profiles_supported (is_supported, is_listing_enabled),
  KEY ix_country_profiles_region (region, subregion),
  CONSTRAINT fk_country_profiles_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- location_state_profiles — ISO 3166-2 detail for the state tier
-- -----------------------------------------------------------------------------
CREATE TABLE location_state_profiles (
  location_id    BIGINT UNSIGNED NOT NULL,
  iso3166_2      VARCHAR(12)     NULL,
  state_code     VARCHAR(12)     NULL,
  fips_code      VARCHAR(12)     NULL,
  -- Upstream's own word for this division: province, emirate, region,
  -- department, canton, prefecture, oblast…
  subdivision_type VARCHAR(60)   NULL,
  native_name    VARCHAR(180)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (location_id),
  KEY ix_state_profiles_iso (iso3166_2),
  CONSTRAINT fk_state_profiles_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- location_translations — localised names
--
-- Seeded for the country and state tiers from the upstream dataset's own
-- translation payload, so an Arabic or French visitor sees native country and
-- region names rather than English ones.
-- -----------------------------------------------------------------------------
CREATE TABLE location_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  location_id    BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(180)    NOT NULL,
  description    TEXT            NULL,
  -- Locale-specific SEO copy for the location landing page.
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_location_translations (location_id, language_id),
  KEY ix_location_translations_lang (language_id, name(48)),
  CONSTRAINT fk_location_translations_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_location_translations_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- location_aliases — alternate names that must resolve in search
--
-- Real users type the name they know, not the canonical one: "JBR" for Jumeirah
-- Beach Residence, "Akoya" for DAMAC Hills, "Tecom" for Barsha Heights, "The
-- Palm" for Palm Jumeirah. Without this, a large share of high-intent searches
-- return nothing.
--
-- `alias_type` distinguishes a former official name (which should also 301 the
-- old URL) from a colloquial nickname (which should only affect search ranking).
-- -----------------------------------------------------------------------------
CREATE TABLE location_aliases (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  location_id    BIGINT UNSIGNED NOT NULL,
  alias          VARCHAR(180)    NOT NULL,
  alias_ascii    VARCHAR(180)    NOT NULL,
  alias_type     ENUM('abbreviation','former_name','local_name','misspelling','marketing_name') NOT NULL DEFAULT 'abbreviation',
  language_id    SMALLINT UNSIGNED NULL,
  -- Former names additionally drive a 301 from the old slug.
  is_redirecting TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_location_aliases (location_id, alias),
  KEY ix_location_aliases_lookup (alias_ascii(64)),
  CONSTRAINT fk_location_aliases_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_location_aliases_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- location_boundaries — polygon geometry, kept separate
--
-- Split from `locations` because a SPATIAL index requires a NOT NULL geometry
-- column, and only a small minority of locations will ever have a boundary
-- traced. Enables draw-on-map search and correct "is this point inside this
-- community" tests.
-- -----------------------------------------------------------------------------
CREATE TABLE location_boundaries (
  location_id    BIGINT UNSIGNED NOT NULL,
  boundary       GEOMETRY        NOT NULL,
  -- Axis-aligned bounding box, denormalised for a cheap pre-filter before the
  -- expensive polygon containment test.
  bbox_min_lat   DECIMAL(10,7)   NOT NULL,
  bbox_min_lng   DECIMAL(10,7)   NOT NULL,
  bbox_max_lat   DECIMAL(10,7)   NOT NULL,
  bbox_max_lng   DECIMAL(10,7)   NOT NULL,
  source         VARCHAR(60)     NULL,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (location_id),
  KEY ix_location_boundaries_bbox (bbox_min_lat, bbox_max_lat, bbox_min_lng, bbox_max_lng),
  CONSTRAINT fk_location_boundaries_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- location_category_stats — inventory per (location, category)
--
-- Powers "1,245 villas in Dubai" style counts, the location facet, and the
-- category landing pages, without ever aggregating the listings table at read
-- time. Refreshed incrementally by the stats job.
-- -----------------------------------------------------------------------------
CREATE TABLE location_category_stats (
  location_id    BIGINT UNSIGNED NOT NULL,
  category_id    INT UNSIGNED    NOT NULL,
  purpose        ENUM('sale','rent','charter','lease','auction','any') NOT NULL DEFAULT 'any',
  -- Counts everything at or below this location, so a country row reflects its
  -- whole subtree rather than only listings pinned directly to the country.
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  min_price_base DECIMAL(18,2)   NULL,
  max_price_base DECIMAL(18,2)   NULL,
  median_price_base DECIMAL(18,2) NULL,
  avg_price_base DECIMAL(18,2)   NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (location_id, category_id, purpose),
  KEY ix_location_category_stats_top (category_id, purpose, listing_count),
  CONSTRAINT fk_location_category_stats_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0002', 'geography');
