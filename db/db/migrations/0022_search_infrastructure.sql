-- =============================================================================
-- Liv Finder — 0022 · Search infrastructure
-- =============================================================================
-- Migration 0007 built `listing_search`: the flat, denormalised read model that
-- makes a results page one indexed range scan. That solves *retrieval*. This
-- migration is about everything that decides what happens to the rows once they
-- have been retrieved, and what happens when retrieval finds nothing.
--
-- Search is the product. On a portal, the difference between a good results
-- page and a mediocre one is the difference between the business working and
-- not working, and almost none of that difference lives in the WHERE clause.
-- It lives in:
--
-- RANKING. `search_ranking_profiles` and `search_ranking_signals` make the sort
-- order a configuration rather than a hardcoded ORDER BY. Weights are versioned
-- and A/B testable, which is the only honest way to answer "did that change
-- help?". Paid promotion is a signal here like any other, with a declared
-- weight — so the commercial thumb on the scale is visible and auditable rather
-- than buried in code.
--
-- LANGUAGE. A Gulf portal is searched in English, Arabic and transliterated
-- Arabic simultaneously. "JBR", "Jumeirah Beach Residence" and "جي بي آر" are
-- the same place. `search_synonyms` is what makes them find each other, and
-- `search_query_rewrites` handles the rest — misspellings, plurals, and the
-- long tail of "2 bhk" meaning "2 bedroom".
--
-- FAILURE. `search_zero_result_queries` is the most valuable table here. Every
-- row is a customer who wanted something and was told there is nothing — either
-- a gap in inventory worth buying, or a gap in the query understanding worth
-- fixing. Most portals throw this away.
--
-- MERCHANDISING. `search_curations` lets a human pin, bury or annotate results
-- for a specific query. Every serious search product needs this escape hatch,
-- because there is always a query the algorithm gets wrong and a deadline
-- before the model can be retrained.
--
-- Note on scope: this is the *control plane*. Whether the actual inverted index
-- is MySQL FULLTEXT (see 0015), OpenSearch or Typesense, the configuration,
-- the training data and the feedback loop live here — so the index can be
-- rebuilt or replaced without losing the accumulated knowledge of what people
-- search for and what they click.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · RANKING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_ranking_profiles
--
-- A named, versioned set of ranking weights. Profiles differ by context — the
-- default results page, a map search, a saved-search alert and the "similar
-- properties" rail all want different orderings of the same inventory.
--
-- Versioning rather than mutation matters: a live experiment must keep serving
-- the exact weights it was launched with, even while someone edits the next
-- version in the admin.
-- -----------------------------------------------------------------------------
CREATE TABLE search_ranking_profiles (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(500)    NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  -- Where this profile is used.
  context        ENUM('search_results','map_search','category_landing','location_landing','similar_listings','recommendations','saved_search_alert','autocomplete','agent_listings','project_listings') NOT NULL DEFAULT 'search_results',
  root_category_id INT UNSIGNED  NULL,
  country_id     BIGINT UNSIGNED NULL,
  -- How the signal scores combine. Linear is a weighted sum; multiplicative
  -- suits boost-style signals where a 0 should zero the row rather than
  -- subtract from it.
  combination    ENUM('linear','multiplicative','hybrid') NOT NULL DEFAULT 'linear',
  -- Diversity: cap how many results one agency may occupy in a page, so a
  -- single large agency cannot own the whole first screen. Without this, small
  -- agencies leave the platform.
  max_per_organization TINYINT UNSIGNED NULL,
  max_per_agent  TINYINT UNSIGNED NULL,
  max_per_project TINYINT UNSIGNED NULL,
  -- Freshness half-life in days: how quickly an unrefreshed listing decays.
  freshness_half_life_days SMALLINT UNSIGNED NULL,
  -- Whether paid promotion applies at all in this context. It should not apply
  -- in "similar listings", where it is user-hostile.
  apply_promotions TINYINT(1)    NOT NULL DEFAULT 1,
  promotion_slots_per_page TINYINT UNSIGNED NULL,
  status         ENUM('draft','active','experimental','retired') NOT NULL DEFAULT 'draft',
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  activated_at   DATETIME(3)     NULL,
  retired_at     DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ranking_profiles_version (code, version),
  KEY ix_ranking_profiles_context (context, status, is_default),
  CONSTRAINT fk_ranking_profiles_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_ranking_profiles_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_ranking_signals
--
-- The individual inputs and their weights. Rows rather than a JSON blob so the
-- admin can show one slider per signal, and so "which profiles use listing
-- quality?" is an indexed query when a signal is retired.
--
-- `normalization` matters more than it looks: view counts are unbounded and
-- power-law distributed, so summing a raw count with a 0–1 quality score means
-- the count is the only signal that ever matters.
-- -----------------------------------------------------------------------------
CREATE TABLE search_ranking_signals (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  profile_id     INT UNSIGNED    NOT NULL,
  signal_code    ENUM('text_relevance','geo_distance','price_competitiveness','freshness','recency_of_refresh','listing_quality','completeness','photo_count','has_video','has_virtual_tour','verified_listing','verified_agent','agent_response_rate','agent_response_time','organization_rating','engagement_ctr','engagement_inquiries','favourite_rate','view_velocity','promotion_boost','featured_boost','exclusive','price_reduced','new_listing','duplicate_penalty','stale_penalty','low_quality_penalty','random_tiebreak') NOT NULL,
  weight         DECIMAL(8,4)    NOT NULL DEFAULT 1.0000,
  normalization  ENUM('none','min_max','z_score','log','sigmoid','percentile') NOT NULL DEFAULT 'none',
  -- Clamp so one extreme value cannot dominate the sum.
  min_value      DECIMAL(12,4)   NULL,
  max_value      DECIMAL(12,4)   NULL,
  -- Signals that only apply in some contexts, e.g. geo_distance only when the
  -- query has a location.
  applies_when   VARCHAR(200)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  notes          VARCHAR(400)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ranking_signal (profile_id, signal_code),
  KEY ix_ranking_signals_code (signal_code, is_active),
  CONSTRAINT fk_ranking_signals_profile FOREIGN KEY (profile_id) REFERENCES search_ranking_profiles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_boost_rules
--
-- Editorial and commercial overrides that sit on top of the profile: boost new
-- developments in a launch week, suppress a category in a market where the
-- inventory is thin, lift a location that is being advertised.
--
-- Time-bounded by design, because an untimed manual boost is a permanent
-- distortion nobody remembers adding.
-- -----------------------------------------------------------------------------
CREATE TABLE search_boost_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(160)    NOT NULL,
  profile_id     INT UNSIGNED    NULL,
  -- What is boosted.
  subject_type   ENUM('listing','organization','agent','project','category','location','brand','attribute') NOT NULL,
  subject_id     BIGINT UNSIGNED NULL,
  attribute_code VARCHAR(60)     NULL,
  attribute_value VARCHAR(200)   NULL,
  -- Where it applies.
  scope_location_id BIGINT UNSIGNED NULL,
  scope_category_id INT UNSIGNED NULL,
  scope_purpose_id SMALLINT UNSIGNED NULL,
  boost_type     ENUM('multiply','add','pin','bury','exclude') NOT NULL DEFAULT 'multiply',
  boost_value    DECIMAL(8,4)    NOT NULL DEFAULT 1.0000,
  pin_position   TINYINT UNSIGNED NULL,
  reason         VARCHAR(300)    NULL,
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_boost_rules_active (is_active, starts_at, ends_at),
  KEY ix_boost_rules_subject (subject_type, subject_id),
  KEY ix_boost_rules_scope (scope_location_id, scope_category_id),
  CONSTRAINT fk_boost_rules_profile FOREIGN KEY (profile_id) REFERENCES search_ranking_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_boost_rules_location FOREIGN KEY (scope_location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_boost_rules_category FOREIGN KEY (scope_category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · QUERY UNDERSTANDING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_synonym_sets / search_synonyms
--
-- Grouped rather than paired, because synonymy is transitive and pairwise rows
-- get inconsistent the moment a third form is added. A set holds every surface
-- form of one concept; one member is the canonical.
--
-- `expansion` distinguishes the two behaviours that are usually conflated:
--   two_way — any member finds any other. "flat" ⇄ "apartment".
--   one_way — the query form maps to the canonical but not back. "cheap"
--             should find "affordable" listings; a listing described as
--             "affordable" should not be surfaced for someone typing the
--             canonical term in reverse.
-- -----------------------------------------------------------------------------
CREATE TABLE search_synonym_sets (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  canonical_term VARCHAR(160)    NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  set_type       ENUM('location','property_type','feature','brand','amenity','generic','abbreviation','transliteration','misspelling') NOT NULL DEFAULT 'generic',
  expansion      ENUM('two_way','one_way') NOT NULL DEFAULT 'two_way',
  -- Optional binding to a real entity, which is what turns "JBR" into a
  -- location filter rather than a text match.
  location_id    BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  feature_id     INT UNSIGNED    NULL,
  notes          VARCHAR(300)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_synonym_sets_canonical (canonical_term, language_id),
  KEY ix_synonym_sets_location (location_id),
  KEY ix_synonym_sets_type (set_type, is_active),
  CONSTRAINT fk_synonym_sets_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
  CONSTRAINT fk_synonym_sets_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_synonym_sets_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE search_synonyms (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  set_id         INT UNSIGNED    NOT NULL,
  term           VARCHAR(160)    NOT NULL,
  -- Folded form the matcher actually compares: lowercase, diacritics removed,
  -- Arabic normalised (alef forms unified, tatweel stripped). Same discipline
  -- as `locations.name_ascii` in 0002.
  term_normalized VARCHAR(160)   NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  is_canonical   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Down-weight a loose synonym so it contributes less relevance than an exact
  -- term match.
  weight         DECIMAL(5,3)    NOT NULL DEFAULT 1.000,
  match_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_synonym_term (set_id, term_normalized),
  -- The lookup the query parser does on every search.
  KEY ix_synonyms_lookup (term_normalized, language_id),
  CONSTRAINT fk_synonyms_set FOREIGN KEY (set_id) REFERENCES search_synonym_sets (id) ON DELETE CASCADE,
  CONSTRAINT fk_synonyms_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_query_rewrites
--
-- Whole-query transformations applied before parsing: fixing a common
-- misspelling, stripping a noise phrase, or mapping a local idiom onto real
-- filters. "2 bhk dubai marina" becomes bedrooms=2 + location=Dubai Marina,
-- and that mapping is data because it differs by market.
-- -----------------------------------------------------------------------------
CREATE TABLE search_query_rewrites (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  pattern        VARCHAR(300)    NOT NULL,
  pattern_type   ENUM('exact','prefix','contains','regex') NOT NULL DEFAULT 'exact',
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  rewrite_type   ENUM('replace','append','strip','redirect','apply_filters') NOT NULL DEFAULT 'replace',
  replacement    VARCHAR(300)    NULL,
  -- Structured filters this query implies, applied instead of (or as well as)
  -- the text match.
  applied_filters JSON           NULL,
  -- For `redirect`: send the user straight to a landing page instead of a
  -- results page. "dubai marina" is better served by the community page.
  redirect_url   VARCHAR(500)    NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  hit_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  last_hit_at    DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_query_rewrites_lookup (pattern_type, is_active, priority),
  KEY ix_query_rewrites_pattern (pattern),
  CONSTRAINT fk_query_rewrites_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
  CONSTRAINT fk_query_rewrites_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_stopwords
--
-- Per-language noise words. Language-specific and market-specific: "villa" is a
-- stopword in a villa-only vertical and a critical term everywhere else, so
-- this is configuration, never a constant in code.
-- -----------------------------------------------------------------------------
CREATE TABLE search_stopwords (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  term           VARCHAR(80)     NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  -- Keep the word for phrase matching but ignore it for scoring, rather than
  -- dropping it entirely. Dropping "not" changes meaning.
  soft           TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_stopwords_term (language_id, term),
  CONSTRAINT fk_stopwords_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_suggestions
--
-- The autocomplete dictionary. Deliberately a maintained table rather than a
-- live aggregate over `search_queries`: autocomplete must answer in single-digit
-- milliseconds on every keystroke, and it must not suggest a query that returns
-- nothing.
--
-- `result_count` is refreshed nightly and suggestions that fall to zero are
-- deactivated — the most common autocomplete failure is confidently completing
-- to a dead end.
-- -----------------------------------------------------------------------------
CREATE TABLE search_suggestions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  suggestion     VARCHAR(200)    NOT NULL,
  suggestion_normalized VARCHAR(200) NOT NULL,
  suggestion_type ENUM('location','category','project','brand','agent','organization','query','feature','combination') NOT NULL DEFAULT 'query',
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  -- What selecting it should do: a location suggestion applies a location
  -- filter, not a text search.
  target_type    ENUM('search','location','category','project','brand','agent','organization','url') NOT NULL DEFAULT 'search',
  target_id      BIGINT UNSIGNED NULL,
  target_url     VARCHAR(500)    NULL,
  -- Display extras: "Dubai Marina · Dubai · 1,204 properties".
  context_label  VARCHAR(200)    NULL,
  icon           VARCHAR(60)     NULL,
  result_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Popularity drives ordering; impressions and selections give a click-through
  -- rate so a suggestion that is always shown and never picked can be demoted.
  search_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  impression_count INT UNSIGNED  NOT NULL DEFAULT 0,
  selection_count INT UNSIGNED   NOT NULL DEFAULT 0,
  score          DECIMAL(10,4)   NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_curated     TINYINT(1)      NOT NULL DEFAULT 0,
  last_searched_at DATETIME(3)   NULL,
  refreshed_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_suggestions_norm (suggestion_normalized, suggestion_type, language_id, country_id),
  -- The prefix query: normalised prefix, active, best score first. Leading-edge
  -- LIKE 'abc%' uses this index.
  KEY ix_suggestions_prefix (is_active, suggestion_normalized, score),
  KEY ix_suggestions_type (suggestion_type, country_id, score),
  KEY ix_suggestions_target (target_type, target_id),
  CONSTRAINT fk_suggestions_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
  CONSTRAINT fk_suggestions_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · FACETS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_facet_definitions
--
-- Which filters appear, in what order, rendered how, for which category. A
-- yacht search needs length and cabins; a watch search needs case size and
-- movement; showing both to both is the fastest way to make a multi-vertical
-- marketplace feel broken.
--
-- Bound to the 0003 attribute registry, so adding a filterable field is still
-- an INSERT rather than a deploy.
-- -----------------------------------------------------------------------------
CREATE TABLE search_facet_definitions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  label          VARCHAR(120)    NOT NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  attribute_id   INT UNSIGNED    NULL,
  -- Which physical column or attribute this facet filters on. Named rather than
  -- guessed so the query builder does not have to infer it.
  source_column  VARCHAR(60)     NULL,
  facet_type     ENUM('checkbox','radio','range','slider','select','multiselect','toggle','tree','search','date_range','colour') NOT NULL DEFAULT 'checkbox',
  data_type      ENUM('int','decimal','string','boolean','date','enum','set') NOT NULL DEFAULT 'string',
  unit_id        SMALLINT UNSIGNED NULL,
  -- Presentation.
  display_order  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_collapsed_by_default TINYINT(1) NOT NULL DEFAULT 0,
  show_counts    TINYINT(1)      NOT NULL DEFAULT 1,
  max_visible_options TINYINT UNSIGNED NULL,
  -- Range facets: fixed buckets rather than a continuous slider, because
  -- "1M–2M" is how buyers think and it caches far better.
  range_buckets  JSON            NULL,
  min_value      DECIMAL(18,2)   NULL,
  max_value      DECIMAL(18,2)   NULL,
  step_value     DECIMAL(18,2)   NULL,
  -- Whether selecting this facet produces an indexable URL. Cross-referenced
  -- with `facet_indexation_rules` from 0017 — this is the UI half of the same
  -- decision.
  is_url_facet   TINYINT(1)      NOT NULL DEFAULT 0,
  url_segment    VARCHAR(40)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_facet_definitions (code, category_id, purpose_id),
  KEY ix_facet_definitions_category (category_id, is_active, display_order),
  CONSTRAINT fk_facet_definitions_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_definitions_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_definitions_attribute FOREIGN KEY (attribute_id) REFERENCES attributes (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_definitions_unit FOREIGN KEY (unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_facet_counts
--
-- Precomputed "(1,204)" numbers next to each filter option, per market and
-- category. Computing these live means a GROUP BY per facet per request, which
-- is the single most expensive thing a results page can do.
--
-- Refreshed by a scheduled job. Counts are allowed to be minutes stale — a
-- filter count that is off by three is invisible; a results page that takes
-- four seconds is not.
-- -----------------------------------------------------------------------------
CREATE TABLE search_facet_counts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  facet_id       INT UNSIGNED    NOT NULL,
  -- The scope this count applies within.
  location_id    BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  -- The facet option.
  option_value   VARCHAR(160)    NOT NULL,
  option_label   VARCHAR(200)    NULL,
  option_id      BIGINT UNSIGNED NULL,
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  min_price_base DECIMAL(18,2)   NULL,
  max_price_base DECIMAL(18,2)   NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_facet_count (facet_id, location_id, category_id, purpose_id, option_value),
  -- The read path: everything for this scope in one range scan.
  KEY ix_facet_counts_scope (location_id, category_id, purpose_id, facet_id),
  KEY ix_facet_counts_stale (computed_at),
  CONSTRAINT fk_facet_counts_facet FOREIGN KEY (facet_id) REFERENCES search_facet_definitions (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_counts_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · FEEDBACK LOOP
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_result_events
--
-- Impressions and clicks at result-position granularity: the training data for
-- any learning-to-rank model and the evidence for every ranking argument.
--
-- Month-partitioned and unjoined, like the other event tables. `position` is
-- the whole point — a click at rank 1 says far less about relevance than a
-- click at rank 30, and any click model that ignores position is measuring
-- presentation rather than quality.
-- -----------------------------------------------------------------------------
CREATE TABLE search_result_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  event_type     ENUM('impression','click','inquiry','favourite','call','skip','next_page','refine') NOT NULL DEFAULT 'impression',
  -- Ties the row back to the exact search that produced it.
  search_id      BIGINT UNSIGNED NULL,
  query_hash     CHAR(32)        CHARACTER SET ascii NULL,
  query_text     VARCHAR(300)    NULL,
  listing_id     BIGINT UNSIGNED NULL,
  position       SMALLINT UNSIGNED NULL,
  page_number    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  ranking_profile_id INT UNSIGNED NULL,
  experiment_variant_id INT UNSIGNED NULL,
  -- Was this result shown because someone paid for it? Without this column the
  -- click data is contaminated and every model trained on it learns to prefer
  -- paid inventory.
  is_promoted    TINYINT(1)      NOT NULL DEFAULT 0,
  relevance_score DECIMAL(10,4)  NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  user_id        BIGINT UNSIGNED NULL,
  device_type    ENUM('desktop','mobile','tablet','app','bot','other') NOT NULL DEFAULT 'other',
  -- Dwell time on the listing after a click. The best single proxy for whether
  -- the result was actually what they wanted.
  dwell_seconds  MEDIUMINT UNSIGNED NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_search_events_query (query_hash, occurred_at),
  KEY ix_search_events_listing (listing_id, event_type, occurred_at),
  KEY ix_search_events_profile (ranking_profile_id, event_type, occurred_at),
  KEY ix_search_events_variant (experiment_variant_id, occurred_at),
  KEY ix_search_events_session (session_id, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p2027_01 VALUES LESS THAN (TO_DAYS('2027-02-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- search_zero_result_queries
--
-- Aggregated, not raw: one row per distinct normalised query, with a count.
-- This is the highest-value table in the migration and it is deliberately small
-- enough that a human reads it weekly.
--
-- Each row is one of three things, and `resolution` records which:
--   · a real inventory gap  → tell the sales team what to go and win
--   · a query we misunderstand → add a synonym or a rewrite
--   · a market we do not cover → say so honestly on the results page
-- -----------------------------------------------------------------------------
CREATE TABLE search_zero_result_queries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  query_normalized VARCHAR(300)  NOT NULL,
  query_sample   VARCHAR(300)    NULL,
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  -- Filters that were applied alongside the text, because "no results" is
  -- usually caused by the filter combination, not the words.
  filters_sample JSON            NULL,
  occurrence_count INT UNSIGNED  NOT NULL DEFAULT 1,
  unique_visitors INT UNSIGNED   NOT NULL DEFAULT 1,
  first_seen_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- What happened after: did they refine, or did they leave? An abandonment
  -- rate near 1.0 is a query worth fixing this week.
  abandonment_rate DECIMAL(5,4)  NULL,
  status         ENUM('new','triaged','inventory_gap','query_understanding','out_of_market','spam','resolved','ignored') NOT NULL DEFAULT 'new',
  resolution     VARCHAR(400)    NULL,
  resolved_by_user_id BIGINT UNSIGNED NULL,
  resolved_at    DATETIME(3)     NULL,
  -- Set when a synonym or rewrite was created in response, so the fix is
  -- traceable back to the complaint.
  synonym_set_id INT UNSIGNED    NULL,
  rewrite_id     INT UNSIGNED    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_zero_result_query (query_normalized, country_id, category_id),
  -- The triage queue: most frequent unhandled first.
  KEY ix_zero_results_triage (status, occurrence_count),
  KEY ix_zero_results_recent (last_seen_at),
  CONSTRAINT fk_zero_results_synonym FOREIGN KEY (synonym_set_id) REFERENCES search_synonym_sets (id) ON DELETE SET NULL,
  CONSTRAINT fk_zero_results_rewrite FOREIGN KEY (rewrite_id) REFERENCES search_query_rewrites (id) ON DELETE SET NULL,
  CONSTRAINT fk_zero_results_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_curations
--
-- Human overrides for a specific query: pin this listing to the top, bury that
-- one, show this banner. Every search product needs the escape hatch, and
-- putting it in the schema means it is auditable and expiring rather than a
-- hotfix in a template.
-- -----------------------------------------------------------------------------
CREATE TABLE search_curations (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  query_normalized VARCHAR(300)  NOT NULL,
  match_type     ENUM('exact','prefix','contains') NOT NULL DEFAULT 'exact',
  country_id     BIGINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NULL,
  curation_type  ENUM('pin','bury','exclude','banner','redirect','message') NOT NULL DEFAULT 'pin',
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  pin_position   TINYINT UNSIGNED NULL,
  banner_html    TEXT            NULL,
  message_text   VARCHAR(500)    NULL,
  redirect_url   VARCHAR(500)    NULL,
  reason         VARCHAR(300)    NULL,
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_curations_lookup (query_normalized, is_active, match_type),
  KEY ix_curations_expiry (is_active, ends_at),
  CONSTRAINT fk_curations_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_curations_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  CONSTRAINT fk_curations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 5 · EXPERIMENTS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_experiments / search_experiment_variants / search_experiment_exposures
--
-- Distinct from `seo_experiments` in 0017, which split *pages* to test what
-- Google does. These split *users* to test what buyers do, which needs sticky
-- assignment, a primary metric declared before launch, and a guardrail metric
-- that stops the test if it does damage.
--
-- Declaring the primary metric up front is not bureaucracy: it is what stops
-- the post-hoc search for any metric that moved, which is how most A/B
-- programmes quietly stop working.
-- -----------------------------------------------------------------------------
CREATE TABLE search_experiments (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  hypothesis     VARCHAR(1000)   NULL,
  experiment_type ENUM('ranking','facets','layout','autocomplete','recommendations','pagination','default_sort','promotion_density') NOT NULL DEFAULT 'ranking',
  -- Metrics, declared before the experiment starts.
  primary_metric ENUM('click_through_rate','inquiry_rate','call_rate','favourite_rate','search_refinement_rate','zero_result_rate','session_depth','time_to_first_click','conversion_rate','revenue_per_session') NOT NULL DEFAULT 'inquiry_rate',
  guardrail_metrics SET('zero_result_rate','bounce_rate','page_load_ms','inquiry_rate','revenue_per_session','organization_diversity') NULL,
  minimum_sample_size INT UNSIGNED NULL,
  -- Where users are split.
  traffic_percentage TINYINT UNSIGNED NOT NULL DEFAULT 100,
  targeting_criteria JSON        NULL,
  country_id     BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  status         ENUM('draft','running','paused','concluded','abandoned','rolled_out','rolled_back') NOT NULL DEFAULT 'draft',
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  concluded_at   DATETIME(3)     NULL,
  winning_variant_id INT UNSIGNED NULL,
  -- Result, recorded honestly including "no significant difference", which is
  -- the most common and most frequently unrecorded outcome.
  outcome        ENUM('variant_won','control_won','no_difference','inconclusive','stopped_by_guardrail') NULL,
  confidence_level DECIMAL(5,2)  NULL,
  results_summary VARCHAR(2000)  NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_search_experiments_code (code),
  UNIQUE KEY uq_search_experiments_public (public_id),
  KEY ix_search_experiments_status (status, starts_at),
  CONSTRAINT fk_search_experiments_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_search_experiments_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE search_experiment_variants (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  experiment_id  INT UNSIGNED    NOT NULL,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  is_control     TINYINT(1)      NOT NULL DEFAULT 0,
  traffic_share  TINYINT UNSIGNED NOT NULL DEFAULT 50,
  ranking_profile_id INT UNSIGNED NULL,
  -- Non-ranking overrides: page size, facet order, promotion density.
  config_overrides JSON          NULL,
  -- Observed results, refreshed from the daily rollup.
  exposures      INT UNSIGNED    NOT NULL DEFAULT 0,
  searches       INT UNSIGNED    NOT NULL DEFAULT 0,
  clicks         INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  conversions    INT UNSIGNED    NOT NULL DEFAULT 0,
  primary_metric_value DECIMAL(12,6) NULL,
  lift_percent   DECIMAL(8,3)    NULL,
  p_value        DECIMAL(8,6)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_experiment_variant (experiment_id, code),
  CONSTRAINT fk_experiment_variants_experiment FOREIGN KEY (experiment_id) REFERENCES search_experiments (id) ON DELETE CASCADE,
  CONSTRAINT fk_experiment_variants_profile FOREIGN KEY (ranking_profile_id) REFERENCES search_ranking_profiles (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE search_experiments
  ADD CONSTRAINT fk_search_experiments_winner FOREIGN KEY (winning_variant_id)
      REFERENCES search_experiment_variants (id) ON DELETE SET NULL;

-- Sticky assignment. Stored rather than recomputed from a hash so that a change
-- to the bucketing function, or to the variant split mid-flight, cannot silently
-- move users between arms and invalidate the result.
CREATE TABLE search_experiment_exposures (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  experiment_id  INT UNSIGNED    NOT NULL,
  variant_id     INT UNSIGNED    NOT NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  first_exposed_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_exposed_at DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  exposure_count INT UNSIGNED    NOT NULL DEFAULT 1,
  converted      TINYINT(1)      NOT NULL DEFAULT 0,
  converted_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_exposure_visitor (experiment_id, visitor_id),
  KEY ix_exposures_variant (variant_id, first_exposed_at),
  KEY ix_exposures_user (user_id),
  CONSTRAINT fk_exposures_experiment FOREIGN KEY (experiment_id) REFERENCES search_experiments (id) ON DELETE CASCADE,
  CONSTRAINT fk_exposures_variant FOREIGN KEY (variant_id) REFERENCES search_experiment_variants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 6 · RECOMMENDATIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- listing_similarities
--
-- Precomputed item-to-item neighbours: the "similar properties" rail. Computed
-- offline and stored, because computing similarity at request time across
-- millions of listings is not something a database does in 40ms.
--
-- `similarity_type` keeps the different notions apart. Two listings can be
-- similar in price and utterly different in location, and the rail under a
-- listing page wants a blend while a "more from this building" module wants
-- exactly one.
-- -----------------------------------------------------------------------------
CREATE TABLE listing_similarities (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  similar_listing_id BIGINT UNSIGNED NOT NULL,
  similarity_type ENUM('blended','content','location','price','collaborative','same_building','same_project','same_agent') NOT NULL DEFAULT 'blended',
  score          DECIMAL(7,6)    NOT NULL DEFAULT 0,
  rank_position  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Why, so the UI can label the rail honestly ("also in Marina Gate").
  reason_code    VARCHAR(60)     NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_listing_similarity (listing_id, similar_listing_id, similarity_type),
  -- The read path: top N neighbours of this listing, already ordered.
  KEY ix_similarities_read (listing_id, similarity_type, rank_position),
  KEY ix_similarities_reverse (similar_listing_id),
  CONSTRAINT fk_similarities_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_similarities_similar FOREIGN KEY (similar_listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- user_affinity_profiles
--
-- What we have learned about one visitor's taste, from their own behaviour.
-- Deliberately interpretable — weighted preferences over real dimensions rather
-- than an opaque embedding — because a recommendation a user can see the reason
-- for is one they trust, and because a preference profile is personal data a
-- user is entitled to see and delete under GDPR. An embedding cannot be shown
-- to anyone, which makes that obligation impossible to meet honestly.
-- -----------------------------------------------------------------------------
CREATE TABLE user_affinity_profiles (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  -- Inferred intent.
  primary_intent ENUM('buy','rent','browse','invest','sell','unknown') NOT NULL DEFAULT 'unknown',
  root_category_id INT UNSIGNED  NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  -- Inferred budget, from what they actually look at rather than what they say.
  budget_p25_base DECIMAL(18,2)  NULL,
  budget_median_base DECIMAL(18,2) NULL,
  budget_p75_base DECIMAL(18,2)  NULL,
  -- Weighted preference vectors over real dimensions, each as
  -- {"id": weight} so a UI can render "mostly looking at Dubai Marina".
  location_affinity JSON         NULL,
  category_affinity JSON         NULL,
  feature_affinity JSON          NULL,
  bedroom_affinity JSON          NULL,
  brand_affinity JSON            NULL,
  -- Engagement summary driving how aggressively we recommend.
  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiry_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  favourite_count INT UNSIGNED   NOT NULL DEFAULT 0,
  search_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  session_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Confidence, so a profile built from three page views is not treated like
  -- one built from three hundred.
  confidence     DECIMAL(5,4)    NOT NULL DEFAULT 0,
  lifecycle_stage ENUM('new','browsing','shortlisting','deciding','transacted','dormant') NOT NULL DEFAULT 'new',
  first_seen_at  DATETIME(3)     NULL,
  last_active_at DATETIME(3)     NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_affinity_user (user_id),
  UNIQUE KEY uq_affinity_visitor (visitor_id),
  KEY ix_affinity_stage (lifecycle_stage, last_active_at),
  KEY ix_affinity_expiry (expires_at),
  CONSTRAINT fk_affinity_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_affinity_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- user_recommendations
--
-- The materialised per-user feed. Generated in batch, served by index.
--
-- `shown_count` and `dismissed_at` exist so the same three properties are not
-- recommended forever. Recommendation fatigue is the reason these modules stop
-- being clicked, and it is entirely preventable in the data.
-- -----------------------------------------------------------------------------
CREATE TABLE user_recommendations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  slot           ENUM('home_feed','email_digest','saved_search_alert','similar_rail','you_might_like','price_drop','new_match','push') NOT NULL DEFAULT 'home_feed',
  score          DECIMAL(8,6)    NOT NULL DEFAULT 0,
  rank_position  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  reason_code    ENUM('similar_to_viewed','matches_saved_search','popular_in_area','price_drop','new_in_area','same_building','matches_budget','trending','agent_you_contacted') NULL,
  reason_text    VARCHAR(200)    NULL,
  source_listing_id BIGINT UNSIGNED NULL,
  saved_search_id BIGINT UNSIGNED NULL,
  generated_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NULL,
  shown_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  first_shown_at DATETIME(3)     NULL,
  clicked_at     DATETIME(3)     NULL,
  dismissed_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_recommendation (user_id, listing_id, slot),
  KEY ix_recommendations_user (user_id, slot, rank_position),
  KEY ix_recommendations_visitor (visitor_id, slot, rank_position),
  KEY ix_recommendations_expiry (expires_at),
  KEY ix_recommendations_listing (listing_id),
  CONSTRAINT fk_recommendations_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_recommendations_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_recommendations_saved_search FOREIGN KEY (saved_search_id) REFERENCES saved_searches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- saved_search_matches
--
-- Which listings a saved search has already alerted on. Without this table the
-- alert job either re-sends the same properties every run, or relies on a
-- high-water-mark id that silently misses listings edited into range after the
-- fact — both are real, common bugs.
-- -----------------------------------------------------------------------------
CREATE TABLE saved_search_matches (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  saved_search_id BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  match_reason   ENUM('new_listing','price_drop','back_on_market','newly_matching','reduced_below_budget') NOT NULL DEFAULT 'new_listing',
  matched_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  price_at_match DECIMAL(18,2)   NULL,
  previous_price DECIMAL(18,2)   NULL,
  notified_at    DATETIME(3)     NULL,
  notification_channel ENUM('email','push','sms','whatsapp','in_app') NULL,
  opened_at      DATETIME(3)     NULL,
  clicked_at     DATETIME(3)     NULL,
  inquired_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_saved_search_match (saved_search_id, listing_id, match_reason),
  -- The sender: unnotified matches, oldest first.
  KEY ix_saved_matches_pending (saved_search_id, notified_at),
  KEY ix_saved_matches_listing (listing_id, matched_at),
  KEY ix_saved_matches_user (user_id, matched_at),
  CONSTRAINT fk_saved_matches_search FOREIGN KEY (saved_search_id) REFERENCES saved_searches (id) ON DELETE CASCADE,
  CONSTRAINT fk_saved_matches_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_trending
--
-- What is being searched right now, per market, with the change against the
-- prior window. Powers the "trending in Dubai" module, the editorial calendar
-- and the sales team's sense of where demand is moving.
-- -----------------------------------------------------------------------------
CREATE TABLE search_trending (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  window_type    ENUM('hour','day','week','month') NOT NULL DEFAULT 'day',
  window_start   DATETIME        NOT NULL,
  scope_type     ENUM('global','country','city','category') NOT NULL DEFAULT 'global',
  scope_id       BIGINT UNSIGNED NULL,
  subject_type   ENUM('query','location','category','project','brand','feature') NOT NULL DEFAULT 'query',
  subject_id     BIGINT UNSIGNED NULL,
  subject_label  VARCHAR(200)    NOT NULL,
  search_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_visitors INT UNSIGNED   NOT NULL DEFAULT 0,
  previous_count INT UNSIGNED    NOT NULL DEFAULT 0,
  change_percent DECIMAL(10,2)   NULL,
  rank_position  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  previous_rank  SMALLINT UNSIGNED NULL,
  is_breakout    TINYINT(1)      NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_trending (window_type, window_start, scope_type, scope_id, subject_type, subject_label),
  KEY ix_trending_read (scope_type, scope_id, window_type, window_start, rank_position)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 7 · INDEX MAINTENANCE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- search_index_queue
--
-- The reindex outbox. When a listing changes, a row lands here in the same
-- transaction as the write; a worker drains it into `listing_search` and any
-- external index.
--
-- Doing it this way rather than reindexing inline is what keeps a listing edit
-- fast, and what makes a missed update recoverable — the queue is the evidence
-- that something was meant to happen.
-- -----------------------------------------------------------------------------
CREATE TABLE search_index_queue (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type   ENUM('listing','project','agent','organization','location','post','category') NOT NULL DEFAULT 'listing',
  subject_id     BIGINT UNSIGNED NOT NULL,
  operation      ENUM('upsert','delete','reindex','partial') NOT NULL DEFAULT 'upsert',
  -- Which fields changed, so a price edit can do a partial update instead of a
  -- full document rebuild.
  changed_fields JSON            NULL,
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 5,
  status         ENUM('pending','processing','completed','failed','skipped') NOT NULL DEFAULT 'pending',
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  last_error     VARCHAR(500)    NULL,
  -- Set while a worker holds the row, with the worker's identity, so a crashed
  -- worker's claims can be reclaimed rather than lost.
  claimed_by     VARCHAR(80)     NULL,
  claimed_at     DATETIME(3)     NULL,
  available_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  processed_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- The claim query: pending work that is due, highest priority first.
  KEY ix_index_queue_claim (status, available_at, priority),
  KEY ix_index_queue_subject (subject_type, subject_id, status),
  KEY ix_index_queue_stuck (status, claimed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_index_state
--
-- Per-document freshness: when the source last changed against when the index
-- last saw it. This is what makes "is the index stale?" answerable rather than
-- a matter of faith, and it is how a partial reindex knows what to re-send.
-- -----------------------------------------------------------------------------
CREATE TABLE search_index_state (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type   ENUM('listing','project','agent','organization','location','post','category') NOT NULL DEFAULT 'listing',
  subject_id     BIGINT UNSIGNED NOT NULL,
  index_name     VARCHAR(60)     NOT NULL DEFAULT 'listing_search',
  source_updated_at DATETIME(3)  NULL,
  indexed_at     DATETIME(3)     NULL,
  -- Content hash of the indexed document, so a no-op update can be skipped
  -- instead of rewriting the row and invalidating caches for nothing.
  document_hash  CHAR(32)        CHARACTER SET ascii NULL,
  document_version INT UNSIGNED  NOT NULL DEFAULT 1,
  is_stale       TINYINT(1)      NOT NULL DEFAULT 0,
  is_indexed     TINYINT(1)      NOT NULL DEFAULT 0,
  exclusion_reason ENUM('unpublished','deleted','moderation_hold','low_quality','duplicate','no_images','expired') NULL,
  error_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_error     VARCHAR(500)    NULL,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_index_state (index_name, subject_type, subject_id),
  KEY ix_index_state_stale (index_name, is_stale, source_updated_at),
  KEY ix_index_state_errors (error_count, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_daily_stats
--
-- The search health rollup. Zero-result rate and click-through by market are
-- the two numbers that tell you whether search is working, and they should be
-- on a wall, not in an ad-hoc query.
-- -----------------------------------------------------------------------------
CREATE TABLE search_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  device_type    ENUM('desktop','mobile','tablet','app','all') NOT NULL DEFAULT 'all',
  ranking_profile_id INT UNSIGNED NULL,
  searches       INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_searchers INT UNSIGNED  NOT NULL DEFAULT 0,
  zero_result_searches INT UNSIGNED NOT NULL DEFAULT 0,
  refined_searches INT UNSIGNED  NOT NULL DEFAULT 0,
  result_impressions BIGINT UNSIGNED NOT NULL DEFAULT 0,
  result_clicks  INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  favourites     INT UNSIGNED    NOT NULL DEFAULT 0,
  avg_results_per_search DECIMAL(10,2) NULL,
  avg_click_position DECIMAL(6,2) NULL,
  median_time_to_click_ms INT UNSIGNED NULL,
  zero_result_rate DECIMAL(7,4)  NULL,
  click_through_rate DECIMAL(7,4) NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_search_daily (stat_date, country_id, root_category_id, device_type, ranking_profile_id),
  KEY ix_search_daily_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0022', 'search_infrastructure');
