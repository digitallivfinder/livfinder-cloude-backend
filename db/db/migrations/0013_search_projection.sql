-- =============================================================================
-- Liv Finder — 0013 · Search projection
-- =============================================================================
-- `listing_search` is a flat, read-only projection of everything the public
-- search result page needs: one row per publicly-visible listing, no joins.
--
-- WHY THIS EXISTS
-- ---------------
-- A luxury result card shows title, price, cover image, location breadcrumb,
-- agent name and photo, agency name and logo, plus three or four category
-- specs. Assembled normally that is `listings` joined to `locations` ×2,
-- `agents`, `organizations`, `listing_media` and a per-category detail table —
-- seven tables, on the highest-traffic query in the product, with an ORDER BY
-- and a LIMIT/OFFSET on top.
--
-- MySQL has no materialized views, so this is the equivalent: a maintained
-- table, refreshed on write and rebuildable from scratch. It is the difference
-- between a search page that holds up under load and one that does not.
--
-- THE TRADE-OFF, STATED HONESTLY
-- ------------------------------
-- This is duplicated data and it can go stale. Three things keep it honest:
--   1. It is derived, never authoritative. `listings` is the source of truth; if
--      the two disagree, this table is wrong and gets rebuilt.
--   2. `sp_refresh_listing_search()` in 0014 rebuilds one row from the source
--      tables. The application calls it on listing write; the reconciliation job
--      calls it for anything whose `source_updated_at` lags.
--   3. It holds only publicly-visible listings. Nothing in the portal or admin
--      reads it, so a staleness bug can never affect an owner's view of their
--      own data — only a search result that is at most one refresh cycle old.
--
-- If you would rather not carry this, drop the table and point search at
-- `v_public_listings` in 0014. Everything else in the schema works unchanged;
-- you will simply pay the joins.
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE listing_search (
  listing_id     BIGINT UNSIGNED NOT NULL,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(32)     NOT NULL,

  -- ---- Classification ------------------------------------------------------
  root_category_id INT UNSIGNED  NOT NULL,
  category_id    INT UNSIGNED    NOT NULL,
  purpose_id     SMALLINT UNSIGNED NOT NULL,
  category_slug  VARCHAR(80)     NOT NULL,
  purpose_slug   VARCHAR(40)     NOT NULL,

  -- ---- Display -------------------------------------------------------------
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NOT NULL,
  canonical_path VARCHAR(500)    NOT NULL,
  cover_image_url VARCHAR(500)   NULL,
  image_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,

  -- ---- Price ---------------------------------------------------------------
  price          DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL,
  price_base     DECIMAL(18,2)   NULL,
  price_period   VARCHAR(20)     NULL,
  price_per_area DECIMAL(18,2)   NULL,

  -- ---- Location ------------------------------------------------------------
  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  sub_community_id BIGINT UNSIGNED NULL,
  -- Pre-rendered breadcrumb ("Palm Jumeirah, Dubai, UAE"). Built once on
  -- refresh instead of on every card render.
  location_label VARCHAR(400)    NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,

  -- ---- Attribution ---------------------------------------------------------
  organization_id BIGINT UNSIGNED NULL,
  organization_name VARCHAR(200) NULL,
  organization_logo_url VARCHAR(500) NULL,
  agent_id       BIGINT UNSIGNED NULL,
  agent_name     VARCHAR(200)    NULL,
  agent_slug     VARCHAR(220)    NULL,
  agent_photo_url VARCHAR(500)   NULL,
  -- Contact detail, carried through so the card's Call/WhatsApp buttons work
  -- from the same single read.
  contact_phone  VARCHAR(40)     NULL,
  contact_whatsapp VARCHAR(40)   NULL,

  -- ---- Badges --------------------------------------------------------------
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  is_premium     TINYINT(1)      NOT NULL DEFAULT 0,
  is_verified    TINYINT(1)      NOT NULL DEFAULT 0,
  is_exclusive   TINYINT(1)      NOT NULL DEFAULT 0,
  has_virtual_tour TINYINT(1)    NOT NULL DEFAULT 0,

  -- ---- Cross-category filter columns ---------------------------------------
  -- Deliberately generic names. `spec_a`..`spec_f` hold whichever numeric
  -- filters matter for the row's category, per the mapping below. This is what
  -- lets one set of indexes serve six asset classes without six sets of
  -- category-specific columns sitting NULL on 5/6 of the rows.
  --
  --            spec_a        spec_b        spec_c         spec_d        spec_e      spec_f
  -- property   bedrooms      bathrooms     built_sqft     plot_sqft     year_built  floor
  -- cars       model_year    mileage_km    horsepower     engine_cc     seats       doors
  -- yachts     loa_ft        build_year    cabins         guests        engine_hrs  max_knots
  -- aviation   year_built    total_hours   pax_capacity   range_nm      cycles      cruise_kts
  -- watches    year          case_mm       power_reserve  water_res_m   jewels      —
  --
  -- `spec_labels` carries the human-readable rendering so a card does not need
  -- to know the mapping to display "7 Beds · 8 Baths · 8,900 sqft".
  spec_a         INT             NULL,
  spec_b         INT             NULL,
  spec_c         INT             NULL,
  spec_d         INT             NULL,
  spec_e         INT             NULL,
  spec_f         INT             NULL,
  spec_labels    JSON            NULL,

  -- Enum-ish filters shared across classes (furnishing, transmission, condition,
  -- movement type). Same reasoning as the spec columns.
  facet_a        VARCHAR(60)     NULL,
  facet_b        VARCHAR(60)     NULL,
  facet_c        VARCHAR(60)     NULL,

  brand_id       INT UNSIGNED    NULL,
  brand_model_id INT UNSIGNED    NULL,
  project_id     BIGINT UNSIGNED NULL,
  -- Denormalised feature ids, so "has pool AND has gym" can be answered from
  -- this row. On MySQL 8.0.17+ a multi-valued index over this makes membership
  -- tests indexed — see 0015.
  feature_ids    JSON            NULL,

  -- ---- Ranking -------------------------------------------------------------
  quality_score  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  published_at   DATETIME(3)     NULL,
  last_refreshed_at DATETIME(3)  NULL,
  boost_score    SMALLINT UNSIGNED NOT NULL DEFAULT 0,

  -- ---- Freshness -----------------------------------------------------------
  -- `listings.updated_at` at the time this row was built. The reconciliation job
  -- compares the two to find drift.
  source_updated_at DATETIME(3)  NOT NULL,
  refreshed_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (listing_id),

  -- --- Index strategy -------------------------------------------------------
  -- Each composite matches one real filter+sort combination. Location column
  -- first (the most selective predicate a user applies), then category/purpose,
  -- then the sort key — so MySQL can satisfy filter and ORDER BY from one index
  -- and skip the filesort entirely.
  KEY ix_ls_city_price (city_id, root_category_id, purpose_id, price_base),
  KEY ix_ls_city_recent (city_id, root_category_id, purpose_id, published_at),
  KEY ix_ls_city_ranked (city_id, root_category_id, purpose_id, quality_score),
  KEY ix_ls_community_price (community_id, root_category_id, purpose_id, price_base),
  KEY ix_ls_community_ranked (community_id, root_category_id, purpose_id, quality_score),
  KEY ix_ls_sub_community (sub_community_id, root_category_id, purpose_id, price_base),
  KEY ix_ls_country (country_id, root_category_id, purpose_id, quality_score),
  -- Category browse with no location filter.
  KEY ix_ls_category_price (root_category_id, purpose_id, price_base),
  KEY ix_ls_category_ranked (root_category_id, purpose_id, quality_score, published_at),
  -- The two most common property filters, kept ahead of price so a
  -- "3-bed, under 5m" query narrows on beds first.
  KEY ix_ls_spec_ab (root_category_id, spec_a, spec_b, price_base),
  KEY ix_ls_spec_c (root_category_id, spec_c, price_base),
  KEY ix_ls_facets (root_category_id, facet_a, facet_b, price_base),
  KEY ix_ls_brand (brand_id, brand_model_id, price_base),
  KEY ix_ls_project (project_id, price_base),
  KEY ix_ls_org (organization_id, published_at),
  KEY ix_ls_agent (agent_id, published_at),
  KEY ix_ls_featured (is_featured, root_category_id, quality_score),
  KEY ix_ls_geo (latitude, longitude),
  -- Reconciliation sweep.
  KEY ix_ls_freshness (source_updated_at),

  CONSTRAINT fk_listing_search_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Free-text over the projection: title plus the pre-rendered location label, so
-- "villa palm jumeirah" matches without joining to `locations`.
ALTER TABLE listing_search ADD FULLTEXT KEY ft_listing_search (title, location_label);

-- -----------------------------------------------------------------------------
-- sitemap_entries
--
-- The audit found two 404 URLs published into sitemap.xml because the sitemap
-- was generated from a different dataset than the one the router used. Here the
-- sitemap is a table, written only from resolvable canonical paths, and
-- `last_verified_at` records when a URL was last confirmed to resolve. A path
-- that has never been verified is never emitted.
-- -----------------------------------------------------------------------------
CREATE TABLE sitemap_entries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  url_path       VARCHAR(500)    NOT NULL,
  entity_type    ENUM('listing','agent','organization','project','post','page','location','category','term') NOT NULL,
  entity_id      BIGINT UNSIGNED NULL,
  -- Which per-category sitemap file this belongs in.
  sitemap_group  VARCHAR(60)     NOT NULL DEFAULT 'default',
  priority       DECIMAL(2,1)    NOT NULL DEFAULT 0.5,
  change_frequency ENUM('always','hourly','daily','weekly','monthly','yearly','never') NOT NULL DEFAULT 'weekly',
  last_modified_at DATETIME(3)   NULL,
  -- Set by the verifier job after confirming the path returns 200. Unverified
  -- paths are excluded from generated sitemaps.
  last_verified_at DATETIME(3)   NULL,
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  language_id    SMALLINT UNSIGNED NULL,
  -- hreflang alternates: {"ar":"/ar/...","fr":"/fr/..."}
  alternates     JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sitemap_entries_path (url_path),
  KEY ix_sitemap_group (sitemap_group, is_indexable, last_modified_at),
  KEY ix_sitemap_entity (entity_type, entity_id),
  KEY ix_sitemap_verify (is_indexable, last_verified_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0013', 'search_projection');
