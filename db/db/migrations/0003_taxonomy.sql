-- =============================================================================
-- Liv Finder — 0003 · Taxonomy
-- =============================================================================
-- Categories, listing types, purposes, the attribute registry, features and
-- brands.
--
-- THE ATTRIBUTE PROBLEM
-- ---------------------
-- Six asset classes share one marketplace but almost no filters. Real estate
-- filters on bedrooms and plot size; cars on mileage and transmission; yachts on
-- LOA and cabins; jets on range and total airframe hours; watches on reference
-- number and box-and-papers. There are three ways to model that, and this schema
-- uses all three on purpose, each where it wins:
--
--   1. Per-category detail tables (migration 0007) — real typed, indexed columns
--      for the ~12 filters per category that users actually touch. This is what
--      makes search fast, and it is the only one of the three that can serve a
--      range filter from an index.
--   2. This attribute registry — declarative metadata describing every field:
--      its type, unit, validation, which categories it applies to, how it renders
--      and whether it is a facet. The listing form, the filter panel and the spec
--      table are all generated from these rows, so adding "carbon ceramic brakes"
--      to cars is an INSERT, not a release.
--   3. A JSON document on the listing (0007) — the long tail, everything not
--      worth a column.
--
-- Using only EAV would be slow; only columns would be rigid; only JSON would be
-- unqueryable. The split is the design.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- categories — asset classes and their sub-types
--
-- Self-referencing so the six top-level classes and their listing types live in
-- one tree: real-estate → villa, apartment, penthouse; cars → supercar, SUV.
-- `root_category_id` is denormalised so "which asset class is this?" never needs
-- a recursive walk.
-- -----------------------------------------------------------------------------
CREATE TABLE categories (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  parent_id      INT UNSIGNED    NULL,
  root_category_id INT UNSIGNED  NULL,
  -- Stable machine key used in code and URLs: real-estate, cars, yachts, jets,
  -- helicopters, watches. Never renamed once published.
  code           VARCHAR(60)     NOT NULL,
  slug           VARCHAR(80)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  name_plural    VARCHAR(120)    NOT NULL,
  depth          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  path           VARCHAR(255)    NOT NULL,

  description    TEXT            NULL,
  icon           VARCHAR(80)     NULL,
  hero_image_url VARCHAR(500)    NULL,
  accent_color   CHAR(7)         NULL,

  -- Which per-category detail table in 0007 backs listings in this tree.
  detail_table   ENUM('real_estate','vehicle','marine','aviation','timepiece') NULL,
  -- Canonical unit for this category's headline size figure (sqft for property
  -- in the Gulf, m for yacht LOA, mm for watch cases).
  primary_unit   VARCHAR(20)     NULL,

  status         ENUM('active','inactive','draft') NOT NULL DEFAULT 'active',
  is_visible     TINYINT(1)      NOT NULL DEFAULT 1,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     INT             NOT NULL DEFAULT 0,

  listing_count        INT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,

  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  meta           JSON            NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_public_id (public_id),
  UNIQUE KEY uq_categories_code (code),
  UNIQUE KEY uq_categories_parent_slug (parent_id, slug),
  UNIQUE KEY uq_categories_path (path),
  KEY ix_categories_parent (parent_id, status, sort_order),
  KEY ix_categories_root (root_category_id, status, sort_order),
  KEY ix_categories_visible (status, is_visible, sort_order),
  CONSTRAINT fk_categories_parent FOREIGN KEY (parent_id)        REFERENCES categories (id) ON DELETE RESTRICT,
  CONSTRAINT fk_categories_root   FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Deferred from 0002: location_category_stats.category_id could not be
-- constrained before `categories` existed.
ALTER TABLE location_category_stats
  ADD CONSTRAINT fk_location_category_stats_category
  FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE;

CREATE TABLE category_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  category_id    INT UNSIGNED    NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  name_plural    VARCHAR(120)    NOT NULL,
  slug           VARCHAR(80)     NULL,
  description    TEXT            NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_category_translations (category_id, language_id),
  CONSTRAINT fk_category_translations_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_category_translations_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- purposes — what the transaction is
--
-- Not every purpose applies to every asset class: property is sale/rent, yachts
-- are sale/charter, watches are sale only. `category_purposes` is the join that
-- makes the filter panel offer only what is real for the current category.
-- -----------------------------------------------------------------------------
CREATE TABLE purposes (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(40)     NOT NULL,
  slug           VARCHAR(40)     NOT NULL,
  name           VARCHAR(80)     NOT NULL,
  -- Recurring purposes (rent, charter) require a rate period on the price;
  -- one-off purposes (sale) must not have one.
  is_recurring   TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_purposes_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE category_purposes (
  category_id    INT UNSIGNED    NOT NULL,
  purpose_id     SMALLINT UNSIGNED NOT NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (category_id, purpose_id),
  KEY ix_category_purposes_purpose (purpose_id),
  CONSTRAINT fk_category_purposes_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_category_purposes_purpose  FOREIGN KEY (purpose_id)  REFERENCES purposes (id)   ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- attributes — the field registry
--
-- One row per distinct specification field across the whole marketplace. The
-- listing form, filter panel, spec table and validation layer all read from
-- here, which is what keeps six asset classes from becoming six codebases.
-- -----------------------------------------------------------------------------
CREATE TABLE attributes (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  -- Machine key referenced by application code and by the JSON attribute
  -- document on listings: bedrooms, mileage_km, loa_m, total_time_hours.
  code           VARCHAR(80)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(500)    NULL,
  data_type      ENUM('integer','decimal','string','boolean','enum','multi_enum','date','year','range') NOT NULL,
  unit_code      VARCHAR(20)     NULL,

  -- Which physical column on the per-category detail table this attribute is
  -- backed by, when it is one of the promoted hot filters. NULL means it lives
  -- only in the JSON document. This is the bridge between the declarative
  -- registry and the typed storage in 0007.
  backing_column VARCHAR(64)     NULL,

  -- UI + query behaviour, so the frontend needs no per-field special-casing.
  ui_control     ENUM('text','textarea','number','select','multiselect','checkbox','radio','range_slider','toggle','date','year_select','tags') NOT NULL DEFAULT 'text',
  is_filterable  TINYINT(1)      NOT NULL DEFAULT 0,
  -- Filterable means "can appear in a WHERE"; facet means "we also render a
  -- count-per-value list for it". Facets are expensive; not every filter is one.
  is_facet       TINYINT(1)      NOT NULL DEFAULT 0,
  is_sortable    TINYINT(1)      NOT NULL DEFAULT 0,
  is_searchable  TINYINT(1)      NOT NULL DEFAULT 0,
  -- Shown in the card/summary strip rather than only the full spec table.
  is_highlight   TINYINT(1)      NOT NULL DEFAULT 0,

  min_value      DECIMAL(20,4)   NULL,
  max_value      DECIMAL(20,4)   NULL,
  decimal_places TINYINT UNSIGNED NOT NULL DEFAULT 0,
  validation_regex VARCHAR(255)  NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_attributes_code (code),
  KEY ix_attributes_filterable (is_filterable, is_facet)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE attribute_options (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  attribute_id   INT UNSIGNED    NOT NULL,
  value          VARCHAR(120)    NOT NULL,
  label          VARCHAR(160)    NOT NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_attribute_options (attribute_id, value),
  KEY ix_attribute_options_attr (attribute_id, sort_order),
  CONSTRAINT fk_attribute_options_attribute FOREIGN KEY (attribute_id) REFERENCES attributes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE attribute_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  attribute_id   INT UNSIGNED    NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(500)    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_attribute_translations (attribute_id, language_id),
  CONSTRAINT fk_attribute_translations_attribute FOREIGN KEY (attribute_id) REFERENCES attributes (id) ON DELETE CASCADE,
  CONSTRAINT fk_attribute_translations_language  FOREIGN KEY (language_id)  REFERENCES languages (id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which attributes apply to which category, and how they behave there. The same
-- attribute can be required for villas and optional for plots, so the rules live
-- on the join rather than on the attribute.
CREATE TABLE category_attributes (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  category_id    INT UNSIGNED    NOT NULL,
  attribute_id   INT UNSIGNED    NOT NULL,
  is_required    TINYINT(1)      NOT NULL DEFAULT 0,
  is_filterable  TINYINT(1)      NOT NULL DEFAULT 1,
  is_visible     TINYINT(1)      NOT NULL DEFAULT 1,
  -- Groups fields into form sections and spec-table blocks: "Basics",
  -- "Dimensions", "Engine & performance", "Provenance".
  group_label    VARCHAR(80)     NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_category_attributes (category_id, attribute_id),
  KEY ix_category_attributes_cat (category_id, sort_order),
  KEY ix_category_attributes_attr (attribute_id),
  CONSTRAINT fk_category_attributes_category  FOREIGN KEY (category_id)  REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_category_attributes_attribute FOREIGN KEY (attribute_id) REFERENCES attributes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- features / amenities
--
-- Distinct from attributes: an attribute has a value ("4 bedrooms"), a feature
-- is a boolean tag the listing either has or does not ("Private pool", "Helipad",
-- "Beach access"). Modelled as a many-to-many because that is the only shape
-- that supports "has all of [pool, gym, sea view]" as an indexed query.
-- -----------------------------------------------------------------------------
CREATE TABLE feature_groups (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  icon           VARCHAR(80)     NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_feature_groups_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE features (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  feature_group_id INT UNSIGNED  NULL,
  code           VARCHAR(80)     NOT NULL,
  slug           VARCHAR(100)    NOT NULL,
  name           VARCHAR(140)    NOT NULL,
  icon           VARCHAR(80)     NULL,
  -- Surfaced as a filter chip rather than buried in the full amenity list.
  is_premium     TINYINT(1)      NOT NULL DEFAULT 0,
  is_filterable  TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_features_code (code),
  UNIQUE KEY uq_features_slug (slug),
  KEY ix_features_group (feature_group_id, sort_order),
  CONSTRAINT fk_features_group FOREIGN KEY (feature_group_id) REFERENCES feature_groups (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE feature_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  feature_id     INT UNSIGNED    NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(140)    NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_feature_translations (feature_id, language_id),
  CONSTRAINT fk_feature_translations_feature  FOREIGN KEY (feature_id)  REFERENCES features (id)  ON DELETE CASCADE,
  CONSTRAINT fk_feature_translations_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE category_features (
  category_id    INT UNSIGNED    NOT NULL,
  feature_id     INT UNSIGNED    NOT NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (category_id, feature_id),
  KEY ix_category_features_feature (feature_id),
  CONSTRAINT fk_category_features_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_category_features_feature  FOREIGN KEY (feature_id)  REFERENCES features (id)   ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- brands and models
--
-- One table for every kind of maker in the marketplace — car marques, yacht
-- yards, aircraft manufacturers, watch houses, property developers — because
-- they all need the same things (slug, logo, country of origin, verification,
-- a landing page, listing counts) and users search them the same way.
-- `kind` keeps them apart; nothing else needs to.
-- -----------------------------------------------------------------------------
CREATE TABLE brands (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  kind           ENUM('car_make','yacht_builder','aircraft_manufacturer','watch_brand','property_developer') NOT NULL,
  name           VARCHAR(140)    NOT NULL,
  slug           VARCHAR(160)    NOT NULL,
  logo_url       VARCHAR(500)    NULL,
  country_id     BIGINT UNSIGNED NULL,
  founded_year   SMALLINT UNSIGNED NULL,
  website_url    VARCHAR(500)    NULL,
  description    TEXT            NULL,
  -- Marks the marques that get their own curated landing page and premium
  -- placement (Ferrari, Patek Philippe, Emaar) versus the long tail.
  is_luxury      TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     INT             NOT NULL DEFAULT 0,
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_brands_public_id (public_id),
  UNIQUE KEY uq_brands_kind_slug (kind, slug),
  KEY ix_brands_kind_active (kind, is_active, sort_order, name),
  KEY ix_brands_name (name),
  KEY ix_brands_country (country_id),
  CONSTRAINT fk_brands_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE brand_models (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  brand_id       INT UNSIGNED    NOT NULL,
  -- Sub-models: 911 → 911 Turbo S. Nullable parent keeps one table for both.
  parent_id      INT UNSIGNED    NULL,
  name           VARCHAR(160)    NOT NULL,
  slug           VARCHAR(180)    NOT NULL,
  -- Watch reference or aircraft type designator, where the market identifies a
  -- model by code rather than name (5711/1A, G650ER).
  reference_code VARCHAR(80)     NULL,
  body_type      VARCHAR(60)     NULL,
  production_start_year SMALLINT UNSIGNED NULL,
  production_end_year   SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     INT             NOT NULL DEFAULT 0,
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_brand_models_slug (brand_id, slug),
  KEY ix_brand_models_brand (brand_id, is_active, sort_order, name),
  KEY ix_brand_models_parent (parent_id),
  KEY ix_brand_models_name (name),
  CONSTRAINT fk_brand_models_brand  FOREIGN KEY (brand_id)  REFERENCES brands (id)       ON DELETE CASCADE,
  CONSTRAINT fk_brand_models_parent FOREIGN KEY (parent_id) REFERENCES brand_models (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0003', 'taxonomy');
