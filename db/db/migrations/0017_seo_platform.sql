-- =============================================================================
-- Liv Finder — 0017 · SEO platform
-- =============================================================================
-- For a marketplace like this, organic search is not a channel — it is the
-- business. A property portal lives or dies on ranking for "villas for sale in
-- palm jumeirah" and ten thousand queries like it, and that is a data problem
-- long before it is a content problem.
--
-- Migration 0011 gave each entity a seo_title and seo_description. That is the
-- bare minimum and it does not survive contact with a real portal, because:
--
--   · THE FACET EXPLOSION. Six categories x five location tiers x price bands x
--     bedroom counts x amenities produces millions of URL combinations. Almost
--     all of them are thin, near-duplicate pages that will burn crawl budget and
--     drag down the whole domain if indexed. Deciding *which* combinations
--     deserve indexation is the single highest-leverage SEO decision a portal
--     makes, and it has to be a governed ruleset, not a per-page checkbox.
--
--   · EVERY URL MUST RESOLVE FOREVER. Slugs change when an agent fixes a typo,
--     a community is renamed, a listing is re-categorised. Each of those breaks
--     a ranking that took months to earn unless the old URL 301s. That needs a
--     history, not a redirect someone remembered to add.
--
--   · YOU CANNOT IMPROVE WHAT YOU DO NOT MEASURE. Impressions, clicks, position
--     and Core Web Vitals per URL are what turn SEO from opinion into work.
--
--   · STRUCTURED DATA IS TABLE STAKES. RealEstateListing, Vehicle, Product,
--     Offer, BreadcrumbList, FAQPage. Rich results are most of the visible SERP
--     real estate in this vertical.
--
-- The centrepiece is `url_inventory`: one row per public URL the platform is
-- willing to own. Everything else — meta, hreflang, structured data, robots,
-- metrics, issues — hangs off it. Without a registry you cannot answer "how many
-- indexable pages do we have", which is the first question any audit asks.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- url_inventory — every public URL, registered
-- -----------------------------------------------------------------------------
CREATE TABLE url_inventory (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_path       VARCHAR(500)    NOT NULL,
  -- SHA-256 of the path. The unique index lives here rather than on url_path
  -- because a 500-char utf8mb4 column exceeds InnoDB's 3072-byte key limit, and
  -- because a fixed-width binary key is materially faster to probe on a table
  -- that will hold millions of rows.
  url_hash       BINARY(32)      NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,

  page_type      ENUM('home','category_landing','location_landing','search_results','listing_detail','agent_profile','organization_profile','project_detail','article','editorial_index','static_page','brand_landing','faq','sitemap','other') NOT NULL DEFAULT 'other',
  entity_type    VARCHAR(60)     NULL,
  entity_id      BIGINT UNSIGNED NULL,

  -- Resolved facet context. Denormalised so indexation rules can be evaluated
  -- with a query rather than by parsing the URL.
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  -- How many filters are applied beyond category+location. The single strongest
  -- predictor of a thin page: depth 0-1 is usually worth indexing, depth 3+
  -- almost never is.
  facet_depth    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  facet_signature VARCHAR(255)   NULL,

  -- Indexation decision and why it was made. `decided_by` matters: an
  -- automatic rule can be overridden by an editor, and the override must not be
  -- silently reverted the next time the rules run.
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  index_decision ENUM('index','noindex','noindex_follow','canonical_to_other','blocked_by_robots','pending') NOT NULL DEFAULT 'pending',
  decided_by     ENUM('rule','manual','default') NOT NULL DEFAULT 'default',
  indexation_rule_id INT UNSIGNED NULL,
  canonical_url_id BIGINT UNSIGNED NULL,

  -- Inventory behind the page. A location/category page with three listings is
  -- thin by definition; this is what the indexation rules key on.
  result_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  word_count     INT UNSIGNED    NULL,
  has_unique_content TINYINT(1)  NOT NULL DEFAULT 0,

  -- Link equity signals, maintained from `internal_links`.
  internal_inlink_count INT UNSIGNED NOT NULL DEFAULT 0,
  click_depth    TINYINT UNSIGNED NULL,

  http_status    SMALLINT UNSIGNED NOT NULL DEFAULT 200,
  last_crawled_at DATETIME(3)    NULL,
  last_modified_at DATETIME(3)   NULL,
  first_seen_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- Set when a URL stops being generated. Kept rather than deleted, because a
  -- retired URL still needs to 301 and still appears in Search Console for
  -- months afterwards.
  retired_at     DATETIME(3)     NULL,

  priority       DECIMAL(2,1)    NOT NULL DEFAULT 0.5,
  change_frequency ENUM('always','hourly','daily','weekly','monthly','yearly','never') NOT NULL DEFAULT 'weekly',
  in_sitemap     TINYINT(1)      NOT NULL DEFAULT 0,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_url_inventory_hash (url_hash),
  KEY ix_url_inventory_path (url_path(191)),
  KEY ix_url_inventory_entity (entity_type, entity_id),
  KEY ix_url_inventory_indexable (is_indexable, page_type, result_count),
  KEY ix_url_inventory_facet (page_type, facet_depth, result_count),
  KEY ix_url_inventory_sitemap (in_sitemap, is_indexable, last_modified_at),
  KEY ix_url_inventory_location (location_id, category_id, purpose_id),
  KEY ix_url_inventory_crawl (last_crawled_at),
  KEY ix_url_inventory_status (http_status, is_indexable),
  KEY ix_url_inventory_retired (retired_at),
  CONSTRAINT fk_url_inventory_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_url_inventory_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_url_inventory_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE SET NULL,
  CONSTRAINT fk_url_inventory_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_url_inventory_canonical FOREIGN KEY (canonical_url_id) REFERENCES url_inventory (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- facet_indexation_rules — which filter combinations deserve to be indexed
--
-- The most consequential table in this migration.
--
-- A portal that indexes every facet combination floods the index with thin,
-- near-duplicate pages, exhausts crawl budget on URLs nobody searches for, and
-- earns a site-wide quality penalty. A portal that indexes none of them leaves
-- its highest-intent long-tail queries — "4 bedroom villa for sale in arabian
-- ranches" — on the table entirely.
--
-- The answer is a governed ruleset with minimum inventory thresholds, evaluated
-- in priority order, first match wins.
-- -----------------------------------------------------------------------------
CREATE TABLE facet_indexation_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  -- Lower number evaluated first. First matching rule decides.
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,

  -- Match conditions. NULL means "any".
  page_type      VARCHAR(60)     NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_level ENUM('country','state','city','community','sub_community','any') NOT NULL DEFAULT 'any',
  -- Which filter dimensions are present, as a sorted signature such as
  -- 'bedrooms' or 'bedrooms|price'. This is what distinguishes a page worth
  -- indexing from a combinatorial accident.
  facet_signature VARCHAR(255)   NULL,
  min_facet_depth TINYINT UNSIGNED NULL,
  max_facet_depth TINYINT UNSIGNED NULL,

  -- Inventory thresholds. A page with two results is thin whatever else is true
  -- of it, and will not rank regardless.
  min_result_count INT UNSIGNED  NOT NULL DEFAULT 0,
  min_unique_words INT UNSIGNED  NOT NULL DEFAULT 0,
  -- Optional demand gate: only index a combination people actually search for,
  -- measured from our own search logs.
  min_monthly_searches INT UNSIGNED NULL,

  decision       ENUM('index','noindex','noindex_follow','canonical_to_parent') NOT NULL DEFAULT 'noindex',
  -- Where to point the canonical when the decision is canonical_to_parent:
  -- usually the same page with the last facet removed.
  canonical_strategy ENUM('self','strip_last_facet','strip_all_facets','parent_location','category_root') NOT NULL DEFAULT 'self',
  include_in_sitemap TINYINT(1)  NOT NULL DEFAULT 0,
  sitemap_priority DECIMAL(2,1)  NOT NULL DEFAULT 0.5,

  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Populated by the evaluation job so the effect of a rule is visible before
  -- and after a change.
  matched_url_count INT UNSIGNED NOT NULL DEFAULT 0,
  last_evaluated_at DATETIME(3)  NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_facet_rules_eval (is_active, priority),
  KEY ix_facet_rules_scope (page_type, category_id, location_level),
  CONSTRAINT fk_facet_rules_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_rules_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE CASCADE,
  CONSTRAINT fk_facet_rules_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE url_inventory
  ADD CONSTRAINT fk_url_inventory_rule FOREIGN KEY (indexation_rule_id) REFERENCES facet_indexation_rules (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- seo_meta — the full metadata record, polymorphic
--
-- Separate from the entity's own seo_title/seo_description columns, which stay
-- as the simple author-facing fields. This is the resolved, per-locale, complete
-- record the renderer emits: OG, Twitter, robots directives, canonical.
-- -----------------------------------------------------------------------------
CREATE TABLE seo_meta (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_id         BIGINT UNSIGNED NULL,
  entity_type    VARCHAR(60)     NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,

  meta_title     VARCHAR(255)    NULL,
  meta_description VARCHAR(500)  NULL,
  meta_keywords  VARCHAR(500)    NULL,
  canonical_url  VARCHAR(700)    NULL,

  -- Robots directives as discrete columns rather than a free-text string,
  -- because they are queried ("how many noindex pages do we have") and because
  -- a typo in a hand-written robots string is invisible until traffic drops.
  robots_index   TINYINT(1)      NOT NULL DEFAULT 1,
  robots_follow  TINYINT(1)      NOT NULL DEFAULT 1,
  robots_archive TINYINT(1)      NOT NULL DEFAULT 1,
  robots_snippet TINYINT(1)      NOT NULL DEFAULT 1,
  robots_image_index TINYINT(1)  NOT NULL DEFAULT 1,
  max_snippet    SMALLINT        NULL,
  max_image_preview ENUM('none','standard','large') NULL,
  max_video_preview SMALLINT     NULL,
  unavailable_after DATETIME(3)  NULL,

  -- Open Graph. og_image is the single highest-impact field for social CTR and
  -- is worth generating per entity rather than falling back to a site default.
  og_title       VARCHAR(255)    NULL,
  og_description VARCHAR(500)    NULL,
  og_type        VARCHAR(60)     NULL DEFAULT 'website',
  og_image_url   VARCHAR(700)    NULL,
  og_image_width SMALLINT UNSIGNED NULL,
  og_image_height SMALLINT UNSIGNED NULL,
  og_image_alt   VARCHAR(255)    NULL,
  og_locale      VARCHAR(12)     NULL,
  og_site_name   VARCHAR(120)    NULL,

  twitter_card   ENUM('summary','summary_large_image','app','player') NULL DEFAULT 'summary_large_image',
  twitter_title  VARCHAR(255)    NULL,
  twitter_description VARCHAR(500) NULL,
  twitter_image_url VARCHAR(700) NULL,
  twitter_site   VARCHAR(60)     NULL,
  twitter_creator VARCHAR(60)    NULL,

  -- Distinguishes generated metadata from an editor's override, so a
  -- regeneration pass does not overwrite hand-written copy.
  is_auto_generated TINYINT(1)   NOT NULL DEFAULT 1,
  generated_from_template_id INT UNSIGNED NULL,
  overridden_by_user_id BIGINT UNSIGNED NULL,
  overridden_at  DATETIME(3)     NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_seo_meta (entity_type, entity_id, language_id),
  KEY ix_seo_meta_url (url_id),
  KEY ix_seo_meta_robots (robots_index, entity_type),
  KEY ix_seo_meta_override (is_auto_generated, overridden_at),
  CONSTRAINT fk_seo_meta_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_meta_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_meta_user FOREIGN KEY (overridden_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- seo_meta_templates — pattern-generated metadata
--
-- 500,000 listing pages cannot have hand-written titles. Templates produce them
-- from entity data, with a rules layer so a Dubai villa gets a different pattern
-- from a London flat.
-- -----------------------------------------------------------------------------
CREATE TABLE seo_meta_templates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(80)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  entity_type    VARCHAR(60)     NOT NULL,
  page_type      VARCHAR(60)     NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_level ENUM('country','state','city','community','sub_community','any') NOT NULL DEFAULT 'any',
  language_id    SMALLINT UNSIGNED NULL,

  -- Mustache-style placeholders resolved against the entity:
  --   {{bedrooms}} Bedroom {{category.name}} for Sale in {{location.name}}
  title_pattern  VARCHAR(500)    NOT NULL,
  description_pattern VARCHAR(1000) NULL,
  h1_pattern     VARCHAR(500)    NULL,
  og_title_pattern VARCHAR(500)  NULL,
  og_description_pattern VARCHAR(1000) NULL,

  -- Guard rails, checked at generation time. A truncated title in the SERP costs
  -- clicks; these bounds are what stops a template silently producing them.
  max_title_length SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  max_description_length SMALLINT UNSIGNED NOT NULL DEFAULT 158,
  -- Appended only if the result stays within max_title_length.
  title_suffix   VARCHAR(120)    NULL,

  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_seo_templates_code (code),
  KEY ix_seo_templates_match (entity_type, is_active, priority),
  CONSTRAINT fk_seo_templates_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_templates_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_templates_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE seo_meta
  ADD CONSTRAINT fk_seo_meta_template FOREIGN KEY (generated_from_template_id) REFERENCES seo_meta_templates (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- seo_hreflang_alternates
--
-- A table, not a JSON column on seo_meta, because hreflang must be reciprocal:
-- if EN points at AR, AR must point back at EN or Google ignores the whole
-- cluster. Reciprocity is checkable with a self-join here and not at all in JSON.
-- -----------------------------------------------------------------------------
CREATE TABLE seo_hreflang_alternates (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_id         BIGINT UNSIGNED NOT NULL,
  alternate_url_id BIGINT UNSIGNED NULL,
  -- BCP-47 with optional region: 'en', 'ar-AE', 'en-GB', or 'x-default'.
  hreflang       VARCHAR(16)     NOT NULL,
  alternate_url  VARCHAR(700)    NOT NULL,
  is_x_default   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Set by the validator when the alternate does not point back. An unreciprocated
  -- cluster is silently ignored by search engines, which is the worst kind of bug.
  is_reciprocal  TINYINT(1)      NULL,
  last_validated_at DATETIME(3)  NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_hreflang (url_id, hreflang),
  KEY ix_hreflang_alternate (alternate_url_id),
  KEY ix_hreflang_invalid (is_reciprocal, last_validated_at),
  CONSTRAINT fk_hreflang_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_hreflang_alt FOREIGN KEY (alternate_url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Structured data (JSON-LD)
-- -----------------------------------------------------------------------------
CREATE TABLE structured_data_templates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(80)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  schema_type    ENUM('RealEstateListing','SingleFamilyResidence','Apartment','House','Product','Vehicle','Car','Boat','Offer','AggregateOffer','Organization','RealEstateAgent','Person','LocalBusiness','BreadcrumbList','FAQPage','Article','NewsArticle','WebSite','WebPage','SearchAction','ItemList','Review','AggregateRating','VideoObject','ImageObject','Place','PostalAddress','GeoCoordinates') NOT NULL,
  entity_type    VARCHAR(60)     NULL,
  page_type      VARCHAR(60)     NULL,
  category_id    INT UNSIGNED    NULL,
  -- The JSON-LD body with placeholders, resolved per entity at render or
  -- generation time.
  template_json  JSON            NOT NULL,
  -- Fields that must resolve to non-empty or the block is omitted entirely.
  -- Emitting structured data with missing required properties earns a manual
  -- action, which is worse than emitting none.
  required_fields JSON           NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sd_templates_code (code),
  KEY ix_sd_templates_match (entity_type, is_active, priority),
  CONSTRAINT fk_sd_templates_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE structured_data_instances (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_id         BIGINT UNSIGNED NULL,
  entity_type    VARCHAR(60)     NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  template_id    INT UNSIGNED    NULL,
  schema_type    VARCHAR(60)     NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  payload        JSON            NOT NULL,
  -- Validation state from the Rich Results test. Stored because invalid markup
  -- silently loses rich results rather than erroring anywhere visible.
  validation_status ENUM('unvalidated','valid','warnings','errors') NOT NULL DEFAULT 'unvalidated',
  validation_errors JSON         NULL,
  validated_at   DATETIME(3)     NULL,
  generated_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sd_instances (entity_type, entity_id, schema_type, language_id),
  KEY ix_sd_instances_url (url_id),
  KEY ix_sd_instances_validation (validation_status, validated_at),
  CONSTRAINT fk_sd_instances_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_sd_instances_template FOREIGN KEY (template_id) REFERENCES structured_data_templates (id) ON DELETE SET NULL,
  CONSTRAINT fk_sd_instances_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- slug_history — every slug an entity has ever had
--
-- The mechanism that stops URL changes destroying rankings. When a slug changes,
-- the old one is written here; the router consults this table before returning a
-- 404 and issues a 301 instead.
--
-- This is why `redirects` alone is not sufficient: it relies on someone
-- remembering. This is automatic and exhaustive.
-- -----------------------------------------------------------------------------
CREATE TABLE slug_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entity_type    VARCHAR(60)     NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  old_slug       VARCHAR(280)    NOT NULL,
  new_slug       VARCHAR(280)    NOT NULL,
  old_path       VARCHAR(500)    NULL,
  new_path       VARCHAR(500)    NULL,
  old_path_hash  BINARY(32)      NULL,
  reason         VARCHAR(255)    NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  -- Traffic still arriving at the old URL. A rule with zero hits over a year can
  -- be retired; one with thousands must never be.
  hit_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  last_hit_at    DATETIME(3)     NULL,
  changed_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_slug_history_old (entity_type, old_slug),
  KEY ix_slug_history_entity (entity_type, entity_id, changed_at),
  KEY ix_slug_history_path (old_path_hash),
  KEY ix_slug_history_hits (hit_count),
  CONSTRAINT fk_slug_history_user FOREIGN KEY (changed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Sitemaps
--
-- 0013's `sitemap_entries` stays as the entry list. These add the index and file
-- layer above it: a portal with millions of URLs needs a sitemap index pointing
-- at many files, each capped at 50,000 URLs and 50 MB, split by type so that
-- indexation can be diagnosed per segment.
-- -----------------------------------------------------------------------------
CREATE TABLE sitemap_files (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  sitemap_group  VARCHAR(60)     NOT NULL,
  file_index     SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  file_path      VARCHAR(500)    NOT NULL,
  url_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  file_size_bytes BIGINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NULL,
  sitemap_type   ENUM('urlset','index','image','video','news') NOT NULL DEFAULT 'urlset',
  status         ENUM('building','ready','stale','failed') NOT NULL DEFAULT 'building',
  generated_at   DATETIME(3)     NULL,
  last_modified_at DATETIME(3)   NULL,
  -- Recorded so "is Google actually reading our sitemaps" is answerable.
  last_fetched_by_google_at DATETIME(3) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sitemap_files (sitemap_group, file_index, language_id),
  KEY ix_sitemap_files_status (status, generated_at),
  CONSTRAINT fk_sitemap_files_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE sitemap_entries
  ADD COLUMN url_id BIGINT UNSIGNED NULL AFTER id,
  ADD COLUMN sitemap_file_id INT UNSIGNED NULL AFTER sitemap_group,
  -- Image and video extensions, which materially help image/video search for a
  -- photography-driven vertical.
  ADD COLUMN image_count SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER alternates,
  ADD COLUMN video_count SMALLINT UNSIGNED NOT NULL DEFAULT 0 AFTER image_count,
  ADD COLUMN images JSON NULL AFTER video_count,
  ADD KEY ix_sitemap_entries_url (url_id),
  ADD KEY ix_sitemap_entries_file (sitemap_file_id),
  ADD CONSTRAINT fk_sitemap_entries_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_sitemap_entries_file FOREIGN KEY (sitemap_file_id) REFERENCES sitemap_files (id) ON DELETE SET NULL;

CREATE TABLE sitemap_submissions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  sitemap_file_id INT UNSIGNED   NULL,
  search_engine  ENUM('google','bing','yandex','baidu','naver','seznam') NOT NULL,
  submission_type ENUM('sitemap','url_inspection','indexnow','url_removal') NOT NULL DEFAULT 'sitemap',
  target_url     VARCHAR(700)    NULL,
  status         ENUM('pending','submitted','accepted','rejected','failed') NOT NULL DEFAULT 'pending',
  response_code  SMALLINT UNSIGNED NULL,
  response_body  VARCHAR(2000)   NULL,
  urls_submitted INT UNSIGNED    NULL,
  urls_indexed   INT UNSIGNED    NULL,
  submitted_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_sitemap_submissions (search_engine, status, submitted_at),
  KEY ix_sitemap_submissions_file (sitemap_file_id),
  CONSTRAINT fk_sitemap_submissions_file FOREIGN KEY (sitemap_file_id) REFERENCES sitemap_files (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- robots_rules — robots.txt as data
-- -----------------------------------------------------------------------------
CREATE TABLE robots_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  user_agent     VARCHAR(120)    NOT NULL DEFAULT '*',
  directive      ENUM('allow','disallow','crawl_delay','sitemap','clean_param') NOT NULL,
  path_pattern   VARCHAR(500)    NOT NULL,
  -- Documented reasoning. A blanket Disallow added years ago with no note is
  -- how portals accidentally deindex whole sections and cannot explain why.
  reason         VARCHAR(500)    NULL,
  brand_id       INT UNSIGNED    NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_robots_rules (is_active, user_agent, sort_order),
  CONSTRAINT fk_robots_rules_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- internal_links — the internal link graph
--
-- Internal linking is the main lever a portal has over which of its own pages
-- rank. Storing the graph makes three questions answerable: which pages are
-- orphaned, how deep from the homepage a page sits, and where link equity is
-- pooling uselessly.
-- -----------------------------------------------------------------------------
CREATE TABLE internal_links (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_url_id    BIGINT UNSIGNED NOT NULL,
  to_url_id      BIGINT UNSIGNED NOT NULL,
  anchor_text    VARCHAR(255)    NULL,
  link_context   ENUM('navigation','footer','breadcrumb','body','related','sidebar','pagination','card','cta') NOT NULL DEFAULT 'body',
  is_nofollow    TINYINT(1)      NOT NULL DEFAULT 0,
  -- Ordinal within its context, a proxy for prominence.
  link_position  SMALLINT UNSIGNED NULL,
  first_seen_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_seen_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_internal_links (from_url_id, to_url_id, link_context, link_position),
  -- Reverse direction answers "what links here", which is the useful one.
  KEY ix_internal_links_to (to_url_id, link_context),
  KEY ix_internal_links_anchor (anchor_text(64)),
  CONSTRAINT fk_internal_links_from FOREIGN KEY (from_url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_internal_links_to FOREIGN KEY (to_url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Keywords and rank tracking
-- -----------------------------------------------------------------------------
CREATE TABLE seo_keywords (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  keyword        VARCHAR(255)    NOT NULL,
  keyword_hash   BINARY(32)      NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  -- Third-party volume and difficulty, refreshed periodically.
  monthly_search_volume INT UNSIGNED NULL,
  difficulty     TINYINT UNSIGNED NULL,
  cpc_estimate   DECIMAL(10,2)   NULL,
  -- Commercial intent matters more than volume in this vertical: "villas for
  -- sale in palm jumeirah" converts, "palm jumeirah" does not.
  intent         ENUM('informational','navigational','commercial','transactional','local') NULL,
  -- Grouped so a cluster of near-synonyms is tracked as one target.
  cluster_name   VARCHAR(160)    NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  is_tracked     TINYINT(1)      NOT NULL DEFAULT 0,
  priority       ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_seo_keywords (keyword_hash, language_id, country_id),
  KEY ix_seo_keywords_tracked (is_tracked, priority),
  KEY ix_seo_keywords_volume (monthly_search_volume),
  KEY ix_seo_keywords_cluster (cluster_name),
  KEY ix_seo_keywords_target (category_id, location_id),
  CONSTRAINT fk_seo_keywords_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_keywords_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_keywords_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_keywords_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which URL we intend to rank for a keyword. Declaring it is what makes
-- cannibalisation detectable: two URLs targeting one keyword compete with each
-- other and neither wins.
CREATE TABLE keyword_targets (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  keyword_id     BIGINT UNSIGNED NOT NULL,
  url_id         BIGINT UNSIGNED NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 1,
  assigned_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_keyword_targets (keyword_id, url_id),
  KEY ix_keyword_targets_url (url_id),
  CONSTRAINT fk_keyword_targets_keyword FOREIGN KEY (keyword_id) REFERENCES seo_keywords (id) ON DELETE CASCADE,
  CONSTRAINT fk_keyword_targets_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_keyword_targets_user FOREIGN KEY (assigned_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE keyword_rankings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  keyword_id     BIGINT UNSIGNED NOT NULL,
  checked_on     DATE            NOT NULL,
  search_engine  ENUM('google','bing','yandex','baidu') NOT NULL DEFAULT 'google',
  device         ENUM('desktop','mobile') NOT NULL DEFAULT 'mobile',
  country_id     BIGINT UNSIGNED NULL,
  -- NULL means not in the tracked window (usually top 100), which is
  -- meaningfully different from position 100.
  rank_position  SMALLINT UNSIGNED NULL,
  previous_position SMALLINT UNSIGNED NULL,
  ranking_url_id BIGINT UNSIGNED NULL,
  ranking_url    VARCHAR(700)    NULL,
  -- Which SERP features are present. Losing position 1 to an AI overview is a
  -- different problem from losing it to a competitor, and only visible here.
  serp_features  SET('featured_snippet','local_pack','image_pack','video','people_also_ask','knowledge_panel','ads_top','ads_bottom','shopping','ai_overview','sitelinks') NULL,
  estimated_traffic INT UNSIGNED NULL,
  competitor_domain VARCHAR(191) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_keyword_rankings (keyword_id, checked_on, search_engine, device),
  KEY ix_keyword_rankings_date (checked_on, rank_position),
  KEY ix_keyword_rankings_url (ranking_url_id, checked_on),
  CONSTRAINT fk_keyword_rankings_keyword FOREIGN KEY (keyword_id) REFERENCES seo_keywords (id) ON DELETE CASCADE,
  CONSTRAINT fk_keyword_rankings_url FOREIGN KEY (ranking_url_id) REFERENCES url_inventory (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_console_metrics — impressions, clicks, CTR, position per URL per query
--
-- Imported daily from Search Console. This is the only source of truth for what
-- the site actually ranks for, as opposed to what it was optimised for, and the
-- two differ constantly.
--
-- Partitioned by month: at query x page x day granularity a busy portal produces
-- tens of millions of rows a year, and retention has to be a DROP PARTITION.
-- -----------------------------------------------------------------------------
CREATE TABLE search_console_metrics (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  metric_date    DATE            NOT NULL,
  url_id         BIGINT UNSIGNED NULL,
  url_path       VARCHAR(500)    NOT NULL,
  query_text     VARCHAR(255)    NULL,
  country_code   CHAR(3)         NULL,
  device         ENUM('desktop','mobile','tablet') NOT NULL DEFAULT 'mobile',
  search_type    ENUM('web','image','video','news','discover') NOT NULL DEFAULT 'web',
  impressions    INT UNSIGNED    NOT NULL DEFAULT 0,
  clicks         INT UNSIGNED    NOT NULL DEFAULT 0,
  ctr            DECIMAL(7,5)    NULL,
  average_position DECIMAL(6,2)  NULL,
  imported_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id, metric_date),
  KEY ix_gsc_url_date (url_id, metric_date),
  KEY ix_gsc_query (query_text(64), metric_date),
  KEY ix_gsc_date_clicks (metric_date, clicks),
  KEY ix_gsc_path (url_path(191), metric_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(metric_date)) (
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
-- core_web_vitals — field data per URL
--
-- Page experience is a ranking factor and, more importantly, LCP on a
-- photography-heavy listing page is a conversion problem in its own right. Field
-- data (real users) rather than lab data, because that is what is measured.
-- -----------------------------------------------------------------------------
CREATE TABLE core_web_vitals (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_id         BIGINT UNSIGNED NULL,
  url_path       VARCHAR(500)    NOT NULL,
  measured_on    DATE            NOT NULL,
  device         ENUM('desktop','mobile','all') NOT NULL DEFAULT 'mobile',
  data_source    ENUM('crux','rum','lighthouse','pagespeed') NOT NULL DEFAULT 'rum',
  -- 75th percentile, which is the threshold Google assesses against.
  lcp_p75_ms     INT UNSIGNED    NULL,
  inp_p75_ms     INT UNSIGNED    NULL,
  cls_p75        DECIMAL(6,4)    NULL,
  fcp_p75_ms     INT UNSIGNED    NULL,
  ttfb_p75_ms    INT UNSIGNED    NULL,
  -- Share of samples in each bucket, which is what the assessment actually uses.
  lcp_good_pct   DECIMAL(5,2)    NULL,
  inp_good_pct   DECIMAL(5,2)    NULL,
  cls_good_pct   DECIMAL(5,2)    NULL,
  overall_assessment ENUM('good','needs_improvement','poor','insufficient_data') NULL,
  sample_count   INT UNSIGNED    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_cwv (url_path(180), measured_on, device, data_source),
  KEY ix_cwv_url (url_id, measured_on),
  KEY ix_cwv_assessment (overall_assessment, measured_on),
  CONSTRAINT fk_cwv_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Crawling — ours and theirs
-- -----------------------------------------------------------------------------
CREATE TABLE crawl_sessions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  crawler        ENUM('internal_audit','googlebot','bingbot','yandexbot','ahrefs','semrush','screaming_frog','other') NOT NULL DEFAULT 'internal_audit',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finished_at    DATETIME(3)     NULL,
  urls_crawled   INT UNSIGNED    NOT NULL DEFAULT 0,
  urls_ok        INT UNSIGNED    NOT NULL DEFAULT 0,
  urls_redirect  INT UNSIGNED    NOT NULL DEFAULT 0,
  urls_client_error INT UNSIGNED NOT NULL DEFAULT 0,
  urls_server_error INT UNSIGNED NOT NULL DEFAULT 0,
  issues_found   INT UNSIGNED    NOT NULL DEFAULT 0,
  status         ENUM('running','completed','failed','cancelled') NOT NULL DEFAULT 'running',
  config         JSON            NULL,
  PRIMARY KEY (id),
  KEY ix_crawl_sessions (crawler, started_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE crawl_results (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  crawl_session_id BIGINT UNSIGNED NOT NULL,
  url_id         BIGINT UNSIGNED NULL,
  url_path       VARCHAR(500)    NOT NULL,
  http_status    SMALLINT UNSIGNED NOT NULL,
  redirect_target VARCHAR(700)   NULL,
  -- Chains beyond one hop leak link equity and waste crawl budget; recorded so
  -- they can be flattened.
  redirect_chain_length TINYINT UNSIGNED NOT NULL DEFAULT 0,
  response_time_ms INT UNSIGNED  NULL,
  content_length_bytes INT UNSIGNED NULL,
  title          VARCHAR(500)    NULL,
  meta_description VARCHAR(1000) NULL,
  h1_text        VARCHAR(500)    NULL,
  h1_count       SMALLINT UNSIGNED NULL,
  word_count     INT UNSIGNED    NULL,
  canonical_url  VARCHAR(700)    NULL,
  -- Set when the canonical points elsewhere, which silently removes the page
  -- from the index and is a common accidental foot-gun.
  is_self_canonical TINYINT(1)   NULL,
  robots_directives VARCHAR(255) NULL,
  internal_link_count SMALLINT UNSIGNED NULL,
  external_link_count SMALLINT UNSIGNED NULL,
  image_count    SMALLINT UNSIGNED NULL,
  images_missing_alt SMALLINT UNSIGNED NULL,
  structured_data_types VARCHAR(500) NULL,
  crawled_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_crawl_results_session (crawl_session_id, http_status),
  KEY ix_crawl_results_url (url_id, crawled_at),
  KEY ix_crawl_results_status (http_status, crawled_at),
  CONSTRAINT fk_crawl_results_session FOREIGN KEY (crawl_session_id) REFERENCES crawl_sessions (id) ON DELETE CASCADE,
  CONSTRAINT fk_crawl_results_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Bot hits from the access log. Answers "where is crawl budget going", which for
-- a portal with millions of URLs is usually "into facet pages we did not want
-- indexed".
CREATE TABLE crawl_budget_daily (
  stat_date      DATE            NOT NULL,
  crawler        VARCHAR(60)     NOT NULL,
  page_type      VARCHAR(60)     NOT NULL,
  request_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_urls    INT UNSIGNED    NOT NULL DEFAULT 0,
  bytes_served   BIGINT UNSIGNED NOT NULL DEFAULT 0,
  avg_response_ms INT UNSIGNED   NULL,
  status_2xx     INT UNSIGNED    NOT NULL DEFAULT 0,
  status_3xx     INT UNSIGNED    NOT NULL DEFAULT 0,
  status_4xx     INT UNSIGNED    NOT NULL DEFAULT 0,
  status_5xx     INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Crawl spend on URLs we do not want indexed. The number to drive down.
  wasted_requests INT UNSIGNED   NOT NULL DEFAULT 0,
  PRIMARY KEY (stat_date, crawler, page_type),
  KEY ix_crawl_budget_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- seo_issues — the audit backlog
--
-- Findings from crawls and validators, deduplicated and assignable, so SEO work
-- is a tracked queue rather than a spreadsheet someone emails round.
-- -----------------------------------------------------------------------------
CREATE TABLE seo_issues (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_id         BIGINT UNSIGNED NULL,
  url_path       VARCHAR(500)    NULL,
  issue_type     ENUM('missing_title','duplicate_title','title_too_long','title_too_short','missing_description','duplicate_description','description_too_long','missing_h1','multiple_h1','thin_content','duplicate_content','broken_internal_link','broken_external_link','redirect_chain','redirect_loop','orphan_page','missing_alt_text','large_image','slow_lcp','poor_cls','missing_canonical','canonical_mismatch','noindex_in_sitemap','blocked_by_robots','missing_hreflang','hreflang_not_reciprocal','invalid_structured_data','mixed_content','missing_og_image','keyword_cannibalisation','soft_404','crawl_error') NOT NULL,
  severity       ENUM('info','low','medium','high','critical') NOT NULL DEFAULT 'medium',
  details        VARCHAR(1000)   NULL,
  -- Where two pages collide, so cannibalisation and duplicate titles point at
  -- the other side of the problem.
  related_url_id BIGINT UNSIGNED NULL,
  detected_by    ENUM('crawler','validator','monitor','manual','import') NOT NULL DEFAULT 'crawler',
  crawl_session_id BIGINT UNSIGNED NULL,
  status         ENUM('open','acknowledged','in_progress','fixed','wont_fix','false_positive') NOT NULL DEFAULT 'open',
  assigned_to_user_id BIGINT UNSIGNED NULL,
  resolution_note VARCHAR(1000)  NULL,
  -- Estimated monthly clicks at stake, so the backlog can be ordered by value
  -- rather than by severity label.
  estimated_impact INT UNSIGNED  NULL,
  first_detected_at DATETIME(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_detected_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  resolved_at    DATETIME(3)     NULL,
  occurrence_count INT UNSIGNED  NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_seo_issues (url_id, issue_type, related_url_id),
  KEY ix_seo_issues_queue (status, severity, estimated_impact),
  KEY ix_seo_issues_type (issue_type, status),
  KEY ix_seo_issues_assignee (assigned_to_user_id, status),
  KEY ix_seo_issues_session (crawl_session_id),
  CONSTRAINT fk_seo_issues_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_issues_related FOREIGN KEY (related_url_id) REFERENCES url_inventory (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_issues_session FOREIGN KEY (crawl_session_id) REFERENCES crawl_sessions (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_issues_user FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- content_quality_scores
--
-- Thin and duplicate content across a large template-driven site is the most
-- common cause of a site-wide quality problem. Scoring every page makes it
-- findable before it is punished.
-- -----------------------------------------------------------------------------
CREATE TABLE content_quality_scores (
  url_id         BIGINT UNSIGNED NOT NULL,
  scored_on      DATE            NOT NULL,
  word_count     INT UNSIGNED    NULL,
  unique_word_count INT UNSIGNED NULL,
  -- Share of the page's text that also appears on other pages of the site. The
  -- number that matters for template-generated location pages.
  boilerplate_ratio DECIMAL(5,4) NULL,
  readability_score DECIMAL(5,2) NULL,
  -- 0-100 composite driving the "improve this page" queue.
  quality_score  TINYINT UNSIGNED NULL,
  has_unique_intro TINYINT(1)    NULL,
  has_faq        TINYINT(1)      NULL,
  has_images     TINYINT(1)      NULL,
  has_structured_data TINYINT(1) NULL,
  internal_links_out SMALLINT UNSIGNED NULL,
  result_count   INT UNSIGNED    NULL,
  is_thin        TINYINT(1)      NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (url_id, scored_on),
  KEY ix_content_quality_thin (is_thin, quality_score),
  KEY ix_content_quality_date (scored_on, quality_score),
  CONSTRAINT fk_content_quality_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Near-duplicate page clusters, by shingled-text similarity. Same idea as the
-- perceptual image hashing in 0016, applied to copy.
CREATE TABLE content_duplicate_clusters (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  canonical_url_id BIGINT UNSIGNED NOT NULL,
  similarity_threshold DECIMAL(5,4) NOT NULL DEFAULT 0.9000,
  member_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  status         ENUM('open','canonicalised','rewritten','ignored') NOT NULL DEFAULT 'open',
  detected_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  resolved_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_content_dupe_status (status, member_count),
  CONSTRAINT fk_content_dupe_url FOREIGN KEY (canonical_url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE content_duplicate_members (
  cluster_id     BIGINT UNSIGNED NOT NULL,
  url_id         BIGINT UNSIGNED NOT NULL,
  similarity      DECIMAL(5,4)   NOT NULL,
  added_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (cluster_id, url_id),
  KEY ix_content_dupe_members_url (url_id),
  CONSTRAINT fk_content_dupe_members_cluster FOREIGN KEY (cluster_id) REFERENCES content_duplicate_clusters (id) ON DELETE CASCADE,
  CONSTRAINT fk_content_dupe_members_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- seo_experiments — controlled title and meta tests
--
-- Splitting a homogeneous set of pages (all Dubai apartment listings, say) into
-- variants and comparing CTR is the only reliable way to know whether a title
-- pattern helps. Opinions about title tags are plentiful; evidence is not.
-- -----------------------------------------------------------------------------
CREATE TABLE seo_experiments (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(200)    NOT NULL,
  hypothesis     VARCHAR(1000)   NULL,
  experiment_type ENUM('title','description','h1','structured_data','internal_linking','content_length','og_image') NOT NULL DEFAULT 'title',
  -- Which pages take part, as a stored selector evaluated against url_inventory.
  scope_page_type VARCHAR(60)    NULL,
  scope_category_id INT UNSIGNED NULL,
  scope_filter   JSON            NULL,
  status         ENUM('draft','running','paused','concluded','abandoned') NOT NULL DEFAULT 'draft',
  started_at     DATETIME(3)     NULL,
  ended_at       DATETIME(3)     NULL,
  -- Search results take weeks to stabilise; ending early is how teams convince
  -- themselves of effects that are not there.
  minimum_duration_days SMALLINT UNSIGNED NOT NULL DEFAULT 28,
  primary_metric ENUM('clicks','impressions','ctr','average_position','conversions') NOT NULL DEFAULT 'ctr',
  result_summary VARCHAR(2000)   NULL,
  winning_variant_id INT UNSIGNED NULL,
  confidence_level DECIMAL(5,2)  NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_seo_experiments_status (status, started_at),
  CONSTRAINT fk_seo_experiments_category FOREIGN KEY (scope_category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_seo_experiments_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE seo_experiment_variants (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  experiment_id  INT UNSIGNED    NOT NULL,
  variant_key    VARCHAR(20)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  is_control     TINYINT(1)      NOT NULL DEFAULT 0,
  traffic_share  DECIMAL(5,2)    NOT NULL DEFAULT 50.00,
  title_pattern  VARCHAR(500)    NULL,
  description_pattern VARCHAR(1000) NULL,
  config         JSON            NULL,
  url_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  impressions    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ctr            DECIMAL(7,5)    NULL,
  average_position DECIMAL(6,2)  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_seo_variants (experiment_id, variant_key),
  CONSTRAINT fk_seo_variants_experiment FOREIGN KEY (experiment_id) REFERENCES seo_experiments (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE seo_experiments
  ADD CONSTRAINT fk_seo_experiments_winner FOREIGN KEY (winning_variant_id) REFERENCES seo_experiment_variants (id) ON DELETE SET NULL;

-- Which variant a given URL is in. Assignment must be sticky and deterministic:
-- a page that flips between variants measures nothing.
CREATE TABLE seo_experiment_assignments (
  experiment_id  INT UNSIGNED    NOT NULL,
  url_id         BIGINT UNSIGNED NOT NULL,
  variant_id     INT UNSIGNED    NOT NULL,
  assigned_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (experiment_id, url_id),
  KEY ix_seo_assignments_variant (variant_id),
  KEY ix_seo_assignments_url (url_id),
  CONSTRAINT fk_seo_assignments_experiment FOREIGN KEY (experiment_id) REFERENCES seo_experiments (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_assignments_url FOREIGN KEY (url_id) REFERENCES url_inventory (id) ON DELETE CASCADE,
  CONSTRAINT fk_seo_assignments_variant FOREIGN KEY (variant_id) REFERENCES seo_experiment_variants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- backlinks — the off-page side
-- -----------------------------------------------------------------------------
CREATE TABLE backlinks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  source_domain  VARCHAR(191)    NOT NULL,
  source_url     VARCHAR(700)    NOT NULL,
  source_url_hash BINARY(32)     NOT NULL,
  target_url_id  BIGINT UNSIGNED NULL,
  target_url     VARCHAR(700)    NOT NULL,
  anchor_text    VARCHAR(255)    NULL,
  link_type      ENUM('follow','nofollow','ugc','sponsored','redirect','canonical','image') NOT NULL DEFAULT 'follow',
  domain_rating  TINYINT UNSIGNED NULL,
  page_rating    TINYINT UNSIGNED NULL,
  estimated_traffic INT UNSIGNED NULL,
  is_toxic       TINYINT(1)      NOT NULL DEFAULT 0,
  -- Marked for the disavow file. Kept as a flag rather than a deletion so the
  -- file can be regenerated and the decision is reviewable.
  is_disavowed   TINYINT(1)      NOT NULL DEFAULT 0,
  first_seen_at  DATE            NULL,
  last_seen_at   DATE            NULL,
  lost_at        DATE            NULL,
  source         VARCHAR(60)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_backlinks (source_url_hash, target_url(180)),
  KEY ix_backlinks_target (target_url_id, link_type),
  KEY ix_backlinks_domain (source_domain, domain_rating),
  KEY ix_backlinks_toxic (is_toxic, is_disavowed),
  KEY ix_backlinks_lost (lost_at),
  CONSTRAINT fk_backlinks_target FOREIGN KEY (target_url_id) REFERENCES url_inventory (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Extend redirects with chain detection
-- -----------------------------------------------------------------------------
ALTER TABLE redirects
  ADD COLUMN from_path_hash BINARY(32) NULL AFTER from_path,
  ADD COLUMN target_url_id BIGINT UNSIGNED NULL AFTER to_path,
  -- Hops to the final destination. Anything above 1 leaks link equity and
  -- should be flattened; above 4 most crawlers give up entirely.
  ADD COLUMN chain_length TINYINT UNSIGNED NOT NULL DEFAULT 1 AFTER status_code,
  ADD COLUMN final_target VARCHAR(700) NULL AFTER chain_length,
  ADD COLUMN is_loop TINYINT(1) NOT NULL DEFAULT 0 AFTER final_target,
  ADD COLUMN last_validated_at DATETIME(3) NULL AFTER last_hit_at,
  ADD KEY ix_redirects_chain (chain_length, is_loop),
  ADD KEY ix_redirects_hash (from_path_hash),
  ADD CONSTRAINT fk_redirects_target_url FOREIGN KEY (target_url_id) REFERENCES url_inventory (id) ON DELETE SET NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0017', 'seo_platform');
