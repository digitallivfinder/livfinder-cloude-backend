-- =============================================================================
-- Liv Finder — 0035 · public Projects marketplace
-- =============================================================================
-- `projects` was built in 0006 to hang units off a development. It is now a
-- public marketplace in its own right — /projects/{country}/…/{projectSlug} —
-- and the admin wizard already asks for a good deal more than the table can
-- hold: a tagline, a project type, a launch status distinct from the build
-- status, an ownership type, a moderation state distinct from both, highlights,
-- a marketing heading, a building count and an accept-enquiries switch. All of
-- that was collected by the form and thrown away on submit.
--
-- Three concepts were also conflated in one `status` column:
--
--   lifecycle    where the building is    announced … handed_over, on_hold, cancelled
--   launch       where the sale is        coming_soon, upcoming, launched, sold_out
--   moderation   whether we publish it    draft, pending, published, rejected, archived
--
-- `status` keeps its meaning — lifecycle — and gains `on_hold`, which the admin
-- form has always offered and the enum never accepted. The other two arrive as
-- their own columns and are migrated explicitly below rather than by reading a
-- new meaning into existing rows. "Nearing completion" is deliberately NOT a
-- stored value: it is `under_construction` above a completion threshold, and
-- storing it would let the two disagree.
--
-- IDEMPOTENT. Every statement is guarded, so a re-run is a no-op.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 0 · Guard helper
-- -----------------------------------------------------------------------------
-- MySQL has no ADD COLUMN IF NOT EXISTS. This does the information_schema check
-- and prepares the statement only when the column is genuinely absent.

DROP PROCEDURE IF EXISTS lf_add_column;
DELIMITER //
CREATE PROCEDURE lf_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column
  ) THEN
    SET @lf_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
    PREPARE lf_stmt FROM @lf_sql;
    EXECUTE lf_stmt;
    DEALLOCATE PREPARE lf_stmt;
  END IF;
END //
DELIMITER ;

DROP PROCEDURE IF EXISTS lf_add_index;
DELIMITER //
CREATE PROCEDURE lf_add_index(IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_definition TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.statistics
     WHERE table_schema = DATABASE() AND table_name = p_table AND index_name = p_index
  ) THEN
    SET @lf_sql = CONCAT('ALTER TABLE `', p_table, '` ADD ', p_definition);
    PREPARE lf_stmt FROM @lf_sql;
    EXECUTE lf_stmt;
    DEALLOCATE PREPARE lf_stmt;
  END IF;
END //
DELIMITER ;

-- -----------------------------------------------------------------------------
-- 1 · projects — the columns the product needs
-- -----------------------------------------------------------------------------

-- Lifecycle. `on_hold` was offered by the admin form and rejected by the column.
ALTER TABLE projects
  MODIFY COLUMN status ENUM('announced','presale','under_construction','completed','handed_over','on_hold','cancelled')
    NOT NULL DEFAULT 'announced';

-- The canonical public URL. Unique, so two projects cannot claim one address,
-- and NULL until the project has enough location to build one — an unpublished
-- draft has no URL and should not reserve one.
CALL lf_add_column('projects', 'canonical_path', 'VARCHAR(500) NULL AFTER slug');

-- Location ancestry. 0006 stored country/city/community and skipped state and
-- sub-community, so the canonical path could not be built and a project in a
-- federated market could not be filtered by state at all.
CALL lf_add_column('projects', 'state_id',          'BIGINT UNSIGNED NULL AFTER country_id');
CALL lf_add_column('projects', 'sub_community_id',  'BIGINT UNSIGNED NULL AFTER community_id');
CALL lf_add_column('projects', 'address_line1',     'VARCHAR(255) NULL AFTER sub_community_id');

-- Classification and marketing.
CALL lf_add_column('projects', 'project_type', "ENUM('residential','commercial','mixed_use','hospitality','branded_residence','master_community') NOT NULL DEFAULT 'residential' AFTER category_id");
CALL lf_add_column('projects', 'tagline',      'VARCHAR(255) NULL AFTER name');
CALL lf_add_column('projects', 'marketing_heading', 'VARCHAR(255) NULL AFTER description');
CALL lf_add_column('projects', 'highlights',   'JSON NULL AFTER marketing_heading');

-- Sales state, separate from the build state.
CALL lf_add_column('projects', 'launch_status',  "ENUM('coming_soon','upcoming','launched','sold_out') NOT NULL DEFAULT 'coming_soon' AFTER status");
CALL lf_add_column('projects', 'ownership_type', "ENUM('freehold','leasehold','commonhold','usufruct','musataha','other','unknown') NOT NULL DEFAULT 'unknown' AFTER launch_status");

-- Publication, separate from both. `is_publicly_visible` stays as the operator's
-- switch; `moderation_status` is the workflow state the admin screens show.
CALL lf_add_column('projects', 'moderation_status', "ENUM('draft','pending','published','rejected','archived') NOT NULL DEFAULT 'draft' AFTER is_publicly_visible");
CALL lf_add_column('projects', 'published_at',      'DATETIME(3) NULL AFTER moderation_status');

-- Construction facts.
CALL lf_add_column('projects', 'construction_start_date', 'DATE NULL AFTER launch_date');
CALL lf_add_column('projects', 'building_count',          'SMALLINT UNSIGNED NULL AFTER total_units');

-- Whether the public page offers an enquiry form at all.
CALL lf_add_column('projects', 'accepts_inquiries', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER is_featured');

CALL lf_add_index('projects', 'uq_projects_canonical_path', 'UNIQUE KEY uq_projects_canonical_path (canonical_path)');
CALL lf_add_index('projects', 'fk_projects_state',          'CONSTRAINT fk_projects_state FOREIGN KEY (state_id) REFERENCES locations (id) ON DELETE SET NULL');
CALL lf_add_index('projects', 'fk_projects_sub_community',  'CONSTRAINT fk_projects_sub_community FOREIGN KEY (sub_community_id) REFERENCES locations (id) ON DELETE SET NULL');
CALL lf_add_index('projects', 'ix_projects_public',         'KEY ix_projects_public (is_publicly_visible, moderation_status, status, is_featured)');
CALL lf_add_index('projects', 'ix_projects_handover',       'KEY ix_projects_handover (handover_date, is_publicly_visible)');
CALL lf_add_index('projects', 'ix_projects_type',           'KEY ix_projects_type (project_type, launch_status)');

-- -----------------------------------------------------------------------------
-- 2 · Migrate the three status concepts explicitly
-- -----------------------------------------------------------------------------
-- Nothing is inferred twice. Publication comes from the flag that already
-- governed it; launch state comes from the lifecycle the row already recorded,
-- because a development under construction has, by definition, launched. Rows
-- already carrying a non-default value are left alone so a re-run cannot
-- overwrite an operator's later edit.

UPDATE projects
   SET moderation_status = CASE
         WHEN deleted_at IS NOT NULL THEN 'archived'
         WHEN is_publicly_visible = 1 THEN 'published'
         ELSE 'draft'
       END,
       published_at = CASE
         WHEN is_publicly_visible = 1 AND published_at IS NULL THEN COALESCE(launch_date, created_at)
         ELSE published_at
       END
 WHERE moderation_status = 'draft';

UPDATE projects
   SET launch_status = CASE status
         WHEN 'announced' THEN 'upcoming'
         WHEN 'presale' THEN 'launched'
         WHEN 'under_construction' THEN 'launched'
         WHEN 'completed' THEN 'launched'
         WHEN 'handed_over' THEN 'launched'
         ELSE 'coming_soon'
       END
 WHERE launch_status = 'coming_soon';

-- Sold out is a fact about inventory, not an operator's guess.
UPDATE projects
   SET launch_status = 'sold_out'
 WHERE available_units IS NOT NULL AND available_units = 0
   AND total_units IS NOT NULL AND total_units > 0
   AND status NOT IN ('cancelled', 'on_hold');

-- State and sub-community, from the location tree the community already sits in.
UPDATE projects p
  JOIN locations l ON l.id = COALESCE(p.community_id, p.city_id)
   SET p.state_id = l.state_id
 WHERE p.state_id IS NULL AND l.state_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3 · project_unit_types — the marketing summary of what is for sale
-- -----------------------------------------------------------------------------
-- Deliberately NOT `property_units`. A unit type is "2-bedroom apartment, 1,150
-- to 1,340 sqft, from AED 2.4m, limited availability" — one row describing a
-- hundred apartments. `property_units` is unit 1204 on floor 12, and a project
-- announced two years before completion has none of those rows and should not
-- need to invent them in order to publish a price list.

CREATE TABLE IF NOT EXISTS project_unit_types (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  project_id     BIGINT UNSIGNED NOT NULL,
  -- Matches `property_units.unit_type` so the two vocabularies cannot drift.
  unit_type      ENUM('apartment','penthouse','duplex','villa','townhouse','studio','loft','office','retail','warehouse','plot','floor','whole_building','other') NOT NULL DEFAULT 'apartment',
  category_id    INT UNSIGNED    NULL,
  name           VARCHAR(160)    NULL,
  bedrooms       TINYINT UNSIGNED NULL,
  bathrooms      DECIMAL(4,1)    NULL,
  min_size       DECIMAL(12,2)   NULL,
  max_size       DECIMAL(12,2)   NULL,
  area_unit_id   SMALLINT UNSIGNED NULL,
  starting_price DECIMAL(18,2)   NULL,
  max_price      DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  availability   ENUM('available','limited','sold_out','coming_soon') NOT NULL DEFAULT 'available',
  available_units INT UNSIGNED   NULL,
  total_units    INT UNSIGNED    NULL,
  floor_plan_id  BIGINT UNSIGNED NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_project_unit_types_public (public_id),
  KEY ix_project_unit_types_project (project_id, sort_order),
  KEY ix_project_unit_types_beds (project_id, bedrooms, unit_type),
  CONSTRAINT fk_project_unit_types_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  CONSTRAINT fk_project_unit_types_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_project_unit_types_area_unit FOREIGN KEY (area_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_project_unit_types_plan FOREIGN KEY (floor_plan_id) REFERENCES floor_plans (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4 · project_amenities — a row per amenity, not a JSON blob
-- -----------------------------------------------------------------------------
-- `projects.amenities` is a JSON array of display strings. It stays (nothing
-- reads it as a filter, and dropping it would lose data), but an amenity that
-- has to be facetable and translatable is a row.

CREATE TABLE IF NOT EXISTS project_amenities (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  project_id     BIGINT UNSIGNED NOT NULL,
  -- Free-text is deliberate: the amenity vocabulary is editorial and grows with
  -- every market. `slug` is what a facet groups on; `label` is what is shown.
  slug           VARCHAR(120)    NOT NULL,
  label          VARCHAR(160)    NOT NULL,
  category       VARCHAR(60)     NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_project_amenity (project_id, slug),
  KEY ix_project_amenities_slug (slug),
  CONSTRAINT fk_project_amenities_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backfill from the JSON column so nothing that is live today disappears.
INSERT IGNORE INTO project_amenities (project_id, slug, label, sort_order)
SELECT p.id,
       LEFT(LOWER(REGEXP_REPLACE(REGEXP_REPLACE(j.label, '[^A-Za-z0-9]+', '-'), '(^-|-$)', '')), 120),
       LEFT(j.label, 160),
       j.idx
  FROM projects p
  JOIN JSON_TABLE(
         COALESCE(p.amenities, JSON_ARRAY()),
         '$[*]' COLUMNS (idx FOR ORDINALITY, label VARCHAR(200) PATH '$')
       ) j ON TRUE
 WHERE j.label IS NOT NULL AND j.label <> '';

-- -----------------------------------------------------------------------------
-- 5 · project_search — the flat projection the public search reads
-- -----------------------------------------------------------------------------
-- Same discipline as `listing_search`: a result page is an indexed scan over one
-- table rather than a nine-table join with two correlated aggregates. Only rows
-- that pass the public visibility rules are ever inserted, so visibility is
-- enforced by the refresh, not re-derived per request.

CREATE TABLE IF NOT EXISTS project_search (
  project_id     BIGINT UNSIGNED NOT NULL,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NOT NULL,
  canonical_path VARCHAR(500)    NOT NULL,
  tagline        VARCHAR(255)    NULL,

  developer_brand_id INT UNSIGNED NULL,
  developer_slug VARCHAR(160)    NULL,
  developer_name VARCHAR(140)    NULL,
  developer_logo_url VARCHAR(500) NULL,

  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  sub_community_id BIGINT UNSIGNED NULL,
  location_label VARCHAR(400)    NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,

  project_type   VARCHAR(40)     NOT NULL,
  status         VARCHAR(40)     NOT NULL,
  launch_status  VARCHAR(40)     NOT NULL,
  ownership_type VARCHAR(40)     NOT NULL,
  launch_date    DATE            NULL,
  handover_date  DATE            NULL,
  handover_year  SMALLINT UNSIGNED NULL,
  completion_percentage TINYINT UNSIGNED NULL,

  total_units    INT UNSIGNED    NULL,
  available_units INT UNSIGNED   NULL,
  building_count SMALLINT UNSIGNED NULL,
  min_price      DECIMAL(18,2)   NULL,
  max_price      DECIMAL(18,2)   NULL,
  min_price_base DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,

  -- Aggregates over project_unit_types, so a bedroom or unit-size filter is a
  -- column comparison rather than an EXISTS against a child table.
  bedrooms_min   TINYINT UNSIGNED NULL,
  bedrooms_max   TINYINT UNSIGNED NULL,
  area_min       DECIMAL(12,2)   NULL,
  area_max       DECIMAL(12,2)   NULL,
  unit_types     VARCHAR(500)    NULL,
  bedroom_values VARCHAR(120)    NULL,
  availability   VARCHAR(40)     NULL,

  -- Aggregates over project_payment_plans, for the payment-plan filters.
  payment_plan_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  min_down_payment_percent DECIMAL(6,3) NULL,
  has_post_handover TINYINT(1)   NOT NULL DEFAULT 0,
  payment_plan_types VARCHAR(200) NULL,

  cover_image_url VARCHAR(500)   NULL,
  image_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  accepts_inquiries TINYINT(1)   NOT NULL DEFAULT 1,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,
  published_at   DATETIME(3)     NULL,
  source_updated_at DATETIME(3)  NOT NULL,

  PRIMARY KEY (project_id),
  KEY ix_project_search_developer (developer_brand_id, is_featured),
  KEY ix_project_search_country (country_id, status, is_featured),
  KEY ix_project_search_state (state_id, status),
  KEY ix_project_search_city (city_id, status, handover_date),
  KEY ix_project_search_community (community_id, status),
  KEY ix_project_search_status (status, launch_status, is_featured),
  KEY ix_project_search_handover (handover_date),
  KEY ix_project_search_price (min_price_base),
  KEY ix_project_search_featured (is_featured, published_at),
  KEY ix_project_search_completion (completion_percentage),
  KEY ix_project_search_type (project_type),
  UNIQUE KEY uq_project_search_path (canonical_path)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0035', 'projects_marketplace')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;

DROP PROCEDURE IF EXISTS lf_add_column;
DROP PROCEDURE IF EXISTS lf_add_index;
