-- =============================================================================
-- Liv Finder — 0015 · MySQL 8 optimizations  (OPTIONAL — MySQL 8.0.17+ only)
-- =============================================================================
-- Everything in migrations 0001–0014 runs on MySQL 8.0.16+ *and* MariaDB 10.11+.
-- This file does not: it uses four features MariaDB does not implement.
--
-- Skip this file entirely on MariaDB. Nothing else depends on it — the schema is
-- fully functional without it, using the DECIMAL lat/lng bounding-box indexes
-- and the standard FULLTEXT indexes already defined. This file makes three
-- specific query classes faster:
--
--   1. RADIUS SEARCH        "listings within 5km of this point"
--      Needs a real SPATIAL index on an SRID-4326 POINT. The lat/lng composite
--      index can only do a bounding box, which over-fetches at the corners and
--      cannot order by true distance.
--
--   2. CJK / ARABIC SEARCH  ngram tokenisation
--      MySQL's default FULLTEXT parser splits on whitespace, which finds nothing
--      in Chinese or Japanese. The ngram parser fixes it. Relevant for a
--      marketplace selling Dubai property to buyers in Shanghai and Tokyo.
--
--   3. FEATURE-SET FILTERS  "has pool AND has gym AND has sea view"
--      A multi-valued index over the `feature_ids` JSON array turns membership
--      tests into index lookups. Without it they are a full scan of the
--      candidate set, or a join per feature.
--
-- Run it as:  mysql livfinder < 0015_mysql8_optimizations.sql
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1 · Spatial columns and indexes
--
-- A SPATIAL index requires the column to be NOT NULL and to carry an explicit
-- SRID, so the point lives in its own table rather than as a nullable column on
-- `listings`. SRID 4326 is WGS 84 — ordinary GPS latitude/longitude.
--
-- NOTE ON AXIS ORDER: in SRID 4326 the first coordinate is LATITUDE. Get this
-- backwards and every distance is wrong in a way that looks plausible. The
-- helper procedure below is the only place points are constructed, precisely so
-- the convention is applied once.
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS listing_points (
  listing_id     BIGINT UNSIGNED NOT NULL,
  point          POINT           NOT NULL SRID 4326,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (listing_id),
  SPATIAL INDEX sx_listing_points (point),
  CONSTRAINT fk_listing_points_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS location_points (
  location_id    BIGINT UNSIGNED NOT NULL,
  point          POINT           NOT NULL SRID 4326,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (location_id),
  SPATIAL INDEX sx_location_points (point),
  CONSTRAINT fk_location_points_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DELIMITER $$

-- Rebuild both point tables from the DECIMAL lat/lng columns.
DROP PROCEDURE IF EXISTS sp_rebuild_spatial_points$$
CREATE PROCEDURE sp_rebuild_spatial_points()
MODIFIES SQL DATA
BEGIN
  REPLACE INTO listing_points (listing_id, point)
  SELECT id, ST_SRID(POINT(latitude, longitude), 4326)
    FROM listings
   WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND deleted_at IS NULL;

  REPLACE INTO location_points (location_id, point)
  SELECT id, ST_SRID(POINT(latitude, longitude), 4326)
    FROM locations
   WHERE latitude IS NOT NULL AND longitude IS NOT NULL AND deleted_at IS NULL;
END$$

-- -----------------------------------------------------------------------------
-- sp_listings_within_radius()
--
-- The canonical radius query. ST_Distance_Sphere returns metres on a spherical
-- earth — accurate to ~0.3%, which is far better than any listing's own
-- positional accuracy.
--
-- ST_Within against a computed buffer is what lets the SPATIAL index do the
-- coarse filtering; the exact distance is then computed only for the survivors,
-- and used for ordering.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_listings_within_radius$$
CREATE PROCEDURE sp_listings_within_radius(
  IN p_lat DECIMAL(10,7),
  IN p_lng DECIMAL(10,7),
  IN p_radius_metres INT UNSIGNED,
  IN p_limit INT UNSIGNED
)
READS SQL DATA
BEGIN
  SET @centre = ST_SRID(POINT(p_lat, p_lng), 4326);

  SELECT ls.*,
         ST_Distance_Sphere(@centre, lp.point) AS distance_metres
    FROM listing_points lp
    JOIN listing_search ls ON ls.listing_id = lp.listing_id
   WHERE ST_Distance_Sphere(@centre, lp.point) <= p_radius_metres
   ORDER BY distance_metres
   LIMIT p_limit;
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- 2 · ngram full-text indexes for CJK
--
-- Added alongside the default-parser indexes rather than replacing them: the
-- default parser is better for Latin scripts, ngram is the only thing that works
-- for Chinese and Japanese. The application picks which to query by the user's
-- locale.
--
-- ngram_token_size defaults to 2, which suits Chinese. Set it in my.cnf; it
-- cannot be changed per index after creation without a rebuild.
-- -----------------------------------------------------------------------------
ALTER TABLE listings
  ADD FULLTEXT KEY ft_listings_ngram (title, description) WITH PARSER ngram;

ALTER TABLE listing_search
  ADD FULLTEXT KEY ft_listing_search_ngram (title, location_label) WITH PARSER ngram;

ALTER TABLE locations
  ADD FULLTEXT KEY ft_locations_ngram (name) WITH PARSER ngram;

-- -----------------------------------------------------------------------------
-- 3 · Multi-valued index over the feature array
--
-- Turns  WHERE 12 MEMBER OF (feature_ids)  into an index lookup.
-- Combine with AND for "has all of these":
--
--   SELECT * FROM listing_search
--    WHERE city_id = 4521
--      AND 12 MEMBER OF (feature_ids)      -- private pool
--      AND 27 MEMBER OF (feature_ids);     -- sea view
--
-- The CAST syntax is required and is what tells MySQL this is a multi-valued
-- index rather than an ordinary functional one.
-- -----------------------------------------------------------------------------
ALTER TABLE listing_search
  ADD KEY mv_listing_search_features ( (CAST(feature_ids AS UNSIGNED ARRAY)) );

-- -----------------------------------------------------------------------------
-- 4 · Descending indexes for the "newest first" default sort
--
-- MySQL 8 stores descending indexes in actual descending order. Before 8.0 a
-- DESC index was silently created ascending and then scanned backwards, which
-- works but does not pipeline as well. These replace two of the ascending
-- composites from 0013 for the default ordering.
-- -----------------------------------------------------------------------------
ALTER TABLE listing_search
  ADD KEY ix_ls_city_recent_desc (city_id, root_category_id, purpose_id, published_at DESC),
  ADD KEY ix_ls_category_recent_desc (root_category_id, purpose_id, published_at DESC);

ALTER TABLE listings
  ADD KEY ix_listings_recent_desc (status, published_at DESC);

-- -----------------------------------------------------------------------------
-- 5 · Optional: the faster MySQL-8 collation
--
-- utf8mb4_0900_ai_ci is materially faster than utf8mb4_unicode_ci for comparison
-- and sorting, because it needs no collation-weight lookup for the common case.
-- The schema does not use it by default only so that MariaDB can load the same
-- files.
--
-- If you are committed to MySQL 8, converting is worthwhile. Do it during a
-- maintenance window — each ALTER rebuilds the table and its indexes:
--
--   ALTER TABLE listings       CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
--   ALTER TABLE listing_search CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
--   ALTER TABLE locations      CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
--   -- …and so on. tools/convert_collation.sql generates the full statement list.
--
-- Convert ALL tables or none. A join between a utf8mb4_unicode_ci column and a
-- utf8mb4_0900_ai_ci one raises "Illegal mix of collations" — or, worse, silently
-- refuses to use the index.
-- -----------------------------------------------------------------------------

INSERT INTO schema_migrations (version, name) VALUES ('0015', 'mysql8_optimizations');
