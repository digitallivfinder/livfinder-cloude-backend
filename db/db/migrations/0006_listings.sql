-- =============================================================================
-- Liv Finder — 0006 · Listings (core)
-- =============================================================================
-- One `listings` table for all six asset classes, carrying only what every asset
-- genuinely shares: who owns it, where it is, what it costs, what state it is
-- in, and how to contact someone about it. Everything class-specific lives in
-- the detail tables in 0007.
--
-- Two decisions worth stating plainly, because both are deliberate departures
-- from textbook normalisation:
--
-- 1. THE FULL LOCATION CHAIN IS DENORMALISED ONTO EVERY LISTING.
--    country_id / state_id / city_id / community_id / sub_community_id are all
--    stored, not just the deepest one. "Villas in Dubai" is then a single
--    indexed predicate. The normalised alternative — join to `locations`, walk
--    the closure table, filter — is several times more expensive on the single
--    most-executed query in the product. The columns are maintained from
--    `location_id` by the trigger in 0016, so they cannot drift.
--
-- 2. CONTACT DETAILS ARE DENORMALISED ONTO EVERY LISTING.
--    The audit found Call and WhatsApp dead on every listing detail page — "none
--    of the per-category mock detail-data fixtures give the agent/agency object
--    phone or whatsapp fields at all — there is nothing to wire up". Resolving a
--    number through listing → agent → organisation at render time is both a join
--    and a policy question (which number wins?). Storing the resolved contact on
--    the listing makes the lead-generation path a column read, and lets a single
--    listing legitimately override the agency default.
--
-- Money follows the schema-wide rule: `price` in the listing's own currency for
-- display, `price_base` in the platform base currency for sorting and range
-- filters. Sorting by price across a mixed-currency result set is otherwise
-- either wrong or an FX join per row.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- projects — off-plan developments
--
-- Central to Gulf property and increasingly to Spain and Portugal: units are
-- sold from a development that has its own brand, handover date and payment
-- plan. Without this, every unit in Creek Beach repeats the same developer,
-- completion date and plan as free text.
-- -----------------------------------------------------------------------------
CREATE TABLE projects (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NOT NULL,
  developer_brand_id INT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NOT NULL,

  description    MEDIUMTEXT      NULL,
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,

  status         ENUM('announced','presale','under_construction','completed','handed_over','cancelled') NOT NULL DEFAULT 'announced',
  launch_date    DATE            NULL,
  handover_date  DATE            NULL,
  completion_percentage TINYINT UNSIGNED NULL,

  total_units    INT UNSIGNED    NULL,
  available_units INT UNSIGNED   NULL,
  min_price      DECIMAL(18,2)   NULL,
  max_price      DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  min_price_base DECIMAL(18,2)   NULL,

  -- Structured deposit/instalment/handover breakdown, e.g.
  -- [{"label":"On booking","percentage":20},{"label":"On handover","percentage":40}]
  payment_plan   JSON            NULL,
  amenities      JSON            NULL,
  cover_image_url VARCHAR(500)   NULL,
  brochure_url   VARCHAR(500)    NULL,

  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  is_publicly_visible TINYINT(1) NOT NULL DEFAULT 0,
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,

  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_projects_public_id (public_id),
  UNIQUE KEY uq_projects_slug (slug),
  KEY ix_projects_developer (developer_brand_id, status),
  KEY ix_projects_location (community_id, status),
  KEY ix_projects_city (city_id, status, handover_date),
  KEY ix_projects_visible (is_publicly_visible, status, is_featured),
  CONSTRAINT fk_projects_brand     FOREIGN KEY (developer_brand_id) REFERENCES brands (id)        ON DELETE SET NULL,
  CONSTRAINT fk_projects_org       FOREIGN KEY (organization_id)    REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_projects_category  FOREIGN KEY (category_id)        REFERENCES categories (id)    ON DELETE RESTRICT,
  CONSTRAINT fk_projects_location  FOREIGN KEY (location_id)        REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_projects_country   FOREIGN KEY (country_id)         REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_projects_city      FOREIGN KEY (city_id)            REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_projects_community FOREIGN KEY (community_id)       REFERENCES locations (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- listings
-- -----------------------------------------------------------------------------
CREATE TABLE listings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- Human-quotable reference shown throughout the UI ("ID: LF-2847") and used by
  -- agents on the phone. Unique and immutable.
  reference      VARCHAR(32)     NOT NULL,

  -- ---- Ownership -----------------------------------------------------------
  account_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  created_by_user_id BIGINT UNSIGNED NULL,

  -- ---- Classification ------------------------------------------------------
  -- The leaf category (e.g. "villa"); `root_category_id` is its asset class
  -- (e.g. "real-estate"), denormalised so the six category landing pages and
  -- the per-category detail-table dispatch never walk the category tree.
  category_id    INT UNSIGNED    NOT NULL,
  root_category_id INT UNSIGNED  NOT NULL,
  purpose_id     SMALLINT UNSIGNED NOT NULL,
  project_id     BIGINT UNSIGNED NULL,
  brand_id       INT UNSIGNED    NULL,
  brand_model_id INT UNSIGNED    NULL,

  -- ---- Content -------------------------------------------------------------
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NOT NULL,
  subtitle       VARCHAR(255)    NULL,
  description    MEDIUMTEXT      NULL,
  -- Canonical detail path, stored rather than derived. The audit found two mock
  -- datasets drifting apart and publishing 404s into sitemap.xml because the URL
  -- was computed in two places. One stored value, written once, cannot drift.
  canonical_path VARCHAR(500)    NOT NULL,

  -- ---- Price ---------------------------------------------------------------
  price          DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  -- Same amount converted to the base currency at write time. Every
  -- cross-currency sort and price-range filter reads this column.
  price_base     DECIMAL(18,2)   NULL,
  price_type     ENUM('fixed','from','on_request','auction','negotiable') NOT NULL DEFAULT 'fixed',
  -- Required when the purpose is recurring (rent, charter), NULL otherwise.
  price_period   ENUM('total','year','month','week','day','hour','nautical_day','flight_hour') NULL,
  price_min      DECIMAL(18,2)   NULL,
  price_max      DECIMAL(18,2)   NULL,
  service_charge DECIMAL(18,2)   NULL,
  -- Derived at write time; the single most common sort in property search.
  price_per_area DECIMAL(18,2)   NULL,
  is_price_hidden TINYINT(1)     NOT NULL DEFAULT 0,

  -- ---- Location ------------------------------------------------------------
  -- Deepest location assigned. The five columns below are its ancestors,
  -- maintained by trg_listings_location_* in 0016.
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  sub_community_id BIGINT UNSIGNED NULL,
  address        VARCHAR(500)    NULL,
  postal_code    VARCHAR(30)     NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,
  -- Show an approximate pin instead of the exact one. Standard for high-value
  -- residential and for aircraft/yachts whose berth is confidential.
  hide_exact_location TINYINT(1) NOT NULL DEFAULT 0,

  -- ---- Lifecycle -----------------------------------------------------------
  status         ENUM('draft','pending_review','active','rejected','expired','sold','rented','withdrawn','archived') NOT NULL DEFAULT 'draft',
  -- Separate from `status` on purpose: a listing can be moderator-approved yet
  -- expired, or live yet flagged. Collapsing them loses that distinction.
  moderation_status ENUM('not_submitted','pending','approved','rejected','flagged') NOT NULL DEFAULT 'not_submitted',
  rejection_reason VARCHAR(500)  NULL,
  published_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  last_refreshed_at DATETIME(3)  NULL,
  sold_at        DATETIME(3)     NULL,

  -- ---- Placement / badges --------------------------------------------------
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  featured_until DATETIME(3)     NULL,
  is_premium     TINYINT(1)      NOT NULL DEFAULT 0,
  is_verified    TINYINT(1)      NOT NULL DEFAULT 0,
  verified_at    DATETIME(3)     NULL,
  is_exclusive   TINYINT(1)      NOT NULL DEFAULT 0,
  is_new_listing TINYINT(1)      NOT NULL DEFAULT 1,
  badge_labels   JSON            NULL,

  -- ---- Contact -------------------------------------------------------------
  -- Resolved at write time from agent → branch → organisation. See the header
  -- note: this is what makes the Call/WhatsApp buttons work.
  contact_name   VARCHAR(200)    NULL,
  contact_phone  VARCHAR(40)     NULL,
  contact_whatsapp VARCHAR(40)   NULL,
  contact_email  VARCHAR(255)    NULL,
  -- Which channels the lister actually accepts, so the UI renders only live
  -- buttons rather than showing a dead one.
  allow_call     TINYINT(1)      NOT NULL DEFAULT 1,
  allow_whatsapp TINYINT(1)      NOT NULL DEFAULT 1,
  allow_email    TINYINT(1)      NOT NULL DEFAULT 1,

  -- ---- Media summary -------------------------------------------------------
  -- Denormalised from `listing_media` so a result card needs no join at all.
  cover_image_url VARCHAR(500)   NULL,
  cover_image_alt VARCHAR(255)   NULL,
  image_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  video_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  has_virtual_tour TINYINT(1)    NOT NULL DEFAULT 0,
  has_floor_plan TINYINT(1)      NOT NULL DEFAULT 0,
  has_brochure   TINYINT(1)      NOT NULL DEFAULT 0,

  -- ---- Long-tail attributes ------------------------------------------------
  -- Everything from the attribute registry not promoted to a typed column in
  -- 0007. Rendered on the spec table; queried rarely and never on a hot path.
  attributes     JSON            NULL,

  -- ---- Counters ------------------------------------------------------------
  -- Maintained asynchronously from the analytics rollups. Never incremented
  -- synchronously on page view — that would serialise writes on popular rows.
  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_view_count INT UNSIGNED NOT NULL DEFAULT 0,
  inquiry_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  favourite_count INT UNSIGNED   NOT NULL DEFAULT 0,
  share_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  call_click_count INT UNSIGNED  NOT NULL DEFAULT 0,
  whatsapp_click_count INT UNSIGNED NOT NULL DEFAULT 0,

  -- ---- Ranking -------------------------------------------------------------
  -- 0–100 completeness of the listing (photos, description, specs). Drives both
  -- the "improve your listing" nudges and the default search ranking.
  completeness_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  -- Composite of completeness, freshness, engagement and placement. The default
  -- ordering column for search results.
  quality_score  SMALLINT UNSIGNED NOT NULL DEFAULT 0,

  -- ---- SEO -----------------------------------------------------------------
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  -- Whether this listing may enter sitemap.xml. The audit found 404 URLs being
  -- published to crawlers; the sitemap generator reads this flag and the
  -- canonical path above, so a listing that cannot resolve is never emitted.
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,

  source         ENUM('manual','import','api','feed','crm') NOT NULL DEFAULT 'manual',
  source_reference VARCHAR(120)  NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_listings_public_id (public_id),
  UNIQUE KEY uq_listings_reference (reference),
  UNIQUE KEY uq_listings_canonical_path (canonical_path),

  -- --- Index strategy -------------------------------------------------------
  -- Each of these serves one identified query shape. They are wide composites
  -- rather than many single-column indexes because MySQL will use one index per
  -- table reference; a covering composite in the right column order is what
  -- turns a filesort into an index scan.

  -- The primary search: category + purpose + location, priced, newest first.
  KEY ix_listings_search_city (status, root_category_id, purpose_id, city_id, price_base),
  KEY ix_listings_search_community (status, root_category_id, purpose_id, community_id, price_base),
  KEY ix_listings_search_country (status, root_category_id, purpose_id, country_id, price_base),
  -- Default ordering for a filtered result set.
  KEY ix_listings_ranked (status, root_category_id, quality_score, published_at),
  KEY ix_listings_recent (status, published_at),
  KEY ix_listings_featured (status, is_featured, featured_until, quality_score),
  -- Portal "My Listings" and the admin per-account views.
  KEY ix_listings_account (account_id, status, updated_at),
  KEY ix_listings_organization (organization_id, status, updated_at),
  KEY ix_listings_agent (agent_id, status, updated_at),
  -- Admin moderation queue.
  KEY ix_listings_moderation (moderation_status, created_at),
  -- Expiry sweeper.
  KEY ix_listings_expiry (status, expires_at),
  KEY ix_listings_category (category_id, status),
  KEY ix_listings_brand (brand_id, brand_model_id, status),
  KEY ix_listings_project (project_id, status),
  KEY ix_listings_location (location_id, status),
  KEY ix_listings_state (state_id, status),
  KEY ix_listings_sub_community (sub_community_id, status),
  -- Map/bbox search.
  KEY ix_listings_geo (status, latitude, longitude),
  KEY ix_listings_price (status, price_base),
  KEY ix_listings_sitemap (is_indexable, status, updated_at),
  KEY ix_listings_deleted (deleted_at),

  CONSTRAINT fk_listings_account       FOREIGN KEY (account_id)         REFERENCES accounts (id)      ON DELETE RESTRICT,
  CONSTRAINT fk_listings_organization  FOREIGN KEY (organization_id)    REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_listings_agent         FOREIGN KEY (agent_id)           REFERENCES agents (id)        ON DELETE SET NULL,
  CONSTRAINT fk_listings_creator       FOREIGN KEY (created_by_user_id) REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_listings_category      FOREIGN KEY (category_id)        REFERENCES categories (id)    ON DELETE RESTRICT,
  CONSTRAINT fk_listings_root_category FOREIGN KEY (root_category_id)   REFERENCES categories (id)    ON DELETE RESTRICT,
  CONSTRAINT fk_listings_purpose       FOREIGN KEY (purpose_id)         REFERENCES purposes (id)      ON DELETE RESTRICT,
  CONSTRAINT fk_listings_project       FOREIGN KEY (project_id)         REFERENCES projects (id)      ON DELETE SET NULL,
  CONSTRAINT fk_listings_brand         FOREIGN KEY (brand_id)           REFERENCES brands (id)        ON DELETE SET NULL,
  CONSTRAINT fk_listings_brand_model   FOREIGN KEY (brand_model_id)     REFERENCES brand_models (id)  ON DELETE SET NULL,
  CONSTRAINT fk_listings_location      FOREIGN KEY (location_id)        REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_listings_country       FOREIGN KEY (country_id)         REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_listings_state         FOREIGN KEY (state_id)           REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_listings_city          FOREIGN KEY (city_id)            REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_listings_community     FOREIGN KEY (community_id)       REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_listings_sub_community FOREIGN KEY (sub_community_id)   REFERENCES locations (id)     ON DELETE SET NULL,

  CONSTRAINT ck_listings_price_nonneg CHECK (price IS NULL OR price >= 0),
  CONSTRAINT ck_listings_completeness CHECK (completeness_score BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE listings ADD FULLTEXT KEY ft_listings (title, subtitle, description);

-- -----------------------------------------------------------------------------
-- listing_translations
-- -----------------------------------------------------------------------------
CREATE TABLE listing_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  subtitle       VARCHAR(255)    NULL,
  description    MEDIUMTEXT      NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  -- Machine translations are shown with a disclosure and are re-generated when
  -- the source text changes; human translations are never overwritten.
  is_machine_translated TINYINT(1) NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_listing_translations (listing_id, language_id),
  KEY ix_listing_translations_lang (language_id),
  CONSTRAINT fk_listing_translations_listing  FOREIGN KEY (listing_id)  REFERENCES listings (id)  ON DELETE CASCADE,
  CONSTRAINT fk_listing_translations_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- media_assets — the admin Media Library
--
-- Uploads are first-class rows, not URL strings on the listing, so the same
-- image can be reused across a listing, a project and an article; so derivative
-- sizes are tracked; and so an orphaned file can be found and reclaimed.
-- -----------------------------------------------------------------------------
CREATE TABLE media_folders (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_id      BIGINT UNSIGNED NULL,
  name           VARCHAR(180)    NOT NULL,
  path           VARCHAR(500)    NOT NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_folders_path (path),
  KEY ix_media_folders_parent (parent_id),
  CONSTRAINT fk_media_folders_parent  FOREIGN KEY (parent_id)          REFERENCES media_folders (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_folders_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE media_assets (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  folder_id      BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  uploaded_by_user_id BIGINT UNSIGNED NULL,

  media_type     ENUM('image','video','document','floor_plan','virtual_tour','audio','model_3d') NOT NULL DEFAULT 'image',
  storage_disk   VARCHAR(40)     NOT NULL DEFAULT 's3',
  storage_path   VARCHAR(700)    NOT NULL,
  url            VARCHAR(700)    NOT NULL,
  cdn_url        VARCHAR(700)    NULL,

  file_name      VARCHAR(255)    NOT NULL,
  mime_type      VARCHAR(120)    NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  width          INT UNSIGNED    NULL,
  height         INT UNSIGNED    NULL,
  duration_seconds INT UNSIGNED  NULL,
  -- SHA-256 of the file. Lets an identical re-upload be de-duplicated instead of
  -- billed and stored twice.
  checksum       CHAR(64)        NULL,
  -- Tiny base64 blurhash/LQIP for placeholder rendering before load.
  blur_hash      VARCHAR(120)    NULL,
  -- Generated derivatives: {"thumb":"...","md":"...","webp":"..."}
  variants       JSON            NULL,

  alt_text       VARCHAR(255)    NULL,
  caption        VARCHAR(500)    NULL,
  credit         VARCHAR(255)    NULL,

  -- Uploads are held until the malware/content scan clears, which the audit
  -- lists as deferred but required.
  scan_status    ENUM('pending','clean','infected','failed','skipped') NOT NULL DEFAULT 'pending',
  processing_status ENUM('pending','processing','ready','failed') NOT NULL DEFAULT 'pending',

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_media_assets_public_id (public_id),
  KEY ix_media_assets_folder (folder_id, media_type),
  KEY ix_media_assets_account (account_id, created_at),
  KEY ix_media_assets_checksum (checksum),
  KEY ix_media_assets_status (processing_status, scan_status),
  KEY ix_media_assets_deleted (deleted_at),
  CONSTRAINT fk_media_assets_folder   FOREIGN KEY (folder_id)           REFERENCES media_folders (id) ON DELETE SET NULL,
  CONSTRAINT fk_media_assets_account  FOREIGN KEY (account_id)          REFERENCES accounts (id)      ON DELETE SET NULL,
  CONSTRAINT fk_media_assets_uploader FOREIGN KEY (uploaded_by_user_id) REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Ordered join between a listing and its media. `url` is duplicated from the
-- asset so the gallery renders from one indexed read of this table alone.
CREATE TABLE listing_media (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  media_type     ENUM('image','video','document','floor_plan','virtual_tour','audio','model_3d') NOT NULL DEFAULT 'image',
  url            VARCHAR(700)    NOT NULL,
  thumbnail_url  VARCHAR(700)    NULL,
  alt_text       VARCHAR(255)    NULL,
  caption        VARCHAR(500)    NULL,
  -- Which room/deck/angle this shows, so galleries can be grouped.
  tag            VARCHAR(80)     NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_cover       TINYINT(1)      NOT NULL DEFAULT 0,
  -- Floor plans and brochures are usually gated behind a lead form.
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_listing_media_listing (listing_id, media_type, sort_order),
  KEY ix_listing_media_cover (listing_id, is_cover),
  KEY ix_listing_media_asset (media_asset_id),
  CONSTRAINT fk_listing_media_listing FOREIGN KEY (listing_id)     REFERENCES listings (id)     ON DELETE CASCADE,
  CONSTRAINT fk_listing_media_asset   FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- listing_features — many-to-many amenity tags
-- -----------------------------------------------------------------------------
CREATE TABLE listing_features (
  listing_id     BIGINT UNSIGNED NOT NULL,
  feature_id     INT UNSIGNED    NOT NULL,
  PRIMARY KEY (listing_id, feature_id),
  -- Reverse direction: "listings that have a private pool". The whole point of
  -- modelling features relationally rather than as a JSON array.
  KEY ix_listing_features_feature (feature_id, listing_id),
  CONSTRAINT fk_listing_features_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_features_feature FOREIGN KEY (feature_id) REFERENCES features (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_attribute_values — the long-tail EAV escape hatch
--
-- Only for attributes that are filterable but not promoted to a typed column.
-- Split value columns by type so a numeric range filter compares numbers rather
-- than strings.
-- -----------------------------------------------------------------------------
CREATE TABLE listing_attribute_values (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  attribute_id   INT UNSIGNED    NOT NULL,
  value_numeric  DECIMAL(20,4)   NULL,
  value_text     VARCHAR(500)    NULL,
  value_boolean  TINYINT(1)      NULL,
  value_date     DATE            NULL,
  attribute_option_id INT UNSIGNED NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_listing_attribute_values (listing_id, attribute_id, attribute_option_id),
  -- Leading with attribute_id: these queries are always "which listings have
  -- attribute X in range Y", never "all attributes of listing Z" (that comes
  -- from the JSON document instead).
  KEY ix_lav_numeric (attribute_id, value_numeric),
  KEY ix_lav_text (attribute_id, value_text(64)),
  KEY ix_lav_option (attribute_option_id, listing_id),
  KEY ix_lav_listing (listing_id),
  CONSTRAINT fk_lav_listing   FOREIGN KEY (listing_id)          REFERENCES listings (id)          ON DELETE CASCADE,
  CONSTRAINT fk_lav_attribute FOREIGN KEY (attribute_id)        REFERENCES attributes (id)        ON DELETE CASCADE,
  CONSTRAINT fk_lav_option    FOREIGN KEY (attribute_option_id) REFERENCES attribute_options (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_price_history — every price change, kept
--
-- Powers "reduced by 8%" badges, price-trend charts on the detail page, and
-- market analytics. Also the honest answer to "was this really reduced?".
-- -----------------------------------------------------------------------------
CREATE TABLE listing_price_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  old_price      DECIMAL(18,2)   NULL,
  new_price      DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL,
  old_price_base DECIMAL(18,2)   NULL,
  new_price_base DECIMAL(18,2)   NULL,
  change_percentage DECIMAL(7,2) NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  changed_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_listing_price_history (listing_id, changed_at),
  CONSTRAINT fk_lph_listing FOREIGN KEY (listing_id)         REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_lph_user    FOREIGN KEY (changed_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_status_history — the moderation audit trail
-- -----------------------------------------------------------------------------
CREATE TABLE listing_status_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  from_status    VARCHAR(40)     NULL,
  to_status      VARCHAR(40)     NOT NULL,
  from_moderation_status VARCHAR(40) NULL,
  to_moderation_status   VARCHAR(40) NULL,
  reason         VARCHAR(500)    NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  -- Distinguishes an admin decision from the expiry sweeper or an API push.
  actor_type     ENUM('user','admin','system','api') NOT NULL DEFAULT 'user',
  changed_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_listing_status_history (listing_id, changed_at),
  KEY ix_listing_status_history_user (changed_by_user_id),
  CONSTRAINT fk_lsh_listing FOREIGN KEY (listing_id)         REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_lsh_user    FOREIGN KEY (changed_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0006', 'listings');
