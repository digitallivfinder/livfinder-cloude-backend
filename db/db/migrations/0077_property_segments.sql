-- =============================================================================
-- 0077_property_segments.sql
--
-- Residential / Commercial as a stored choice.
--
-- A real-estate listing now records its segment, chosen first in every form and feed; the
-- property types offered follow it. Each property type says which segment it belongs to —
-- Plot and Whole Building belong to both, so for those the listing's own choice decides.
--
--   1. categories.property_segment   residential | commercial | both (real-estate types only)
--   2. eight commercial types         Warehouse, Showroom, Shop, Factory, Labour Camp,
--                                     Bulk Units, Industrial Land, Commercial Floor
--   3. listings.property_segment     residential | commercial (real estate)
--      backfilled from the type; Plot and Whole Building listings → residential (every one
--      seeded so far is a villa plot or a residential building)
--   4. listing_search.property_segment + the projection procedure copying it, so a live
--      listing with an unapproved edit keeps searching under its approved segment (0060 guard)
--
-- Runs after the seeds on a fresh load (tools/load.sh). Safe to run more than once.
-- =============================================================================

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

CALL lf_add_column('categories', 'property_segment', "ENUM('residential','commercial','both') NULL DEFAULT NULL AFTER detail_table");
CALL lf_add_column('listings', 'property_segment', "ENUM('residential','commercial') NULL DEFAULT NULL AFTER category_id");
CALL lf_add_column('listing_search', 'property_segment', "ENUM('residential','commercial') NULL DEFAULT NULL AFTER category_slug");

DROP PROCEDURE IF EXISTS lf_add_column;

SET @lf_has_ix = (
  SELECT COUNT(*) FROM information_schema.statistics
   WHERE table_schema = DATABASE() AND table_name = 'listing_search' AND index_name = 'ix_ls_root_segment'
);
SET @lf_sql = IF(@lf_has_ix = 0,
  'ALTER TABLE listing_search ADD INDEX ix_ls_root_segment (root_category_id, property_segment)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- 1. The segment of every real-estate type.
SET @lf_re = (SELECT id FROM categories WHERE code = 'real-estate' AND parent_id IS NULL LIMIT 1);

UPDATE categories
   SET property_segment = CASE
         WHEN slug IN ('offices', 'retail') THEN 'commercial'
         WHEN slug IN ('plots', 'buildings') THEN 'both'
         ELSE 'residential'
       END
 WHERE root_category_id = @lf_re AND id <> @lf_re;

-- 2. The commercial types the big portals use. Matched on `code`, so a re-run updates in place.
INSERT INTO categories (public_id, parent_id, root_category_id, code, slug, name, name_plural,
                        depth, path, detail_table, status, is_visible, sort_order, property_segment)
VALUES
  ('01K2F3A00000000000000SEG16', @lf_re, @lf_re, 'warehouse',        'warehouses',        'Warehouse',        'Warehouses',        1, 'real-estate/warehouses',        'real_estate', 'active', 1, 16, 'commercial'),
  ('01K2F3A00000000000000SEG17', @lf_re, @lf_re, 'showroom',         'showrooms',         'Showroom',         'Showrooms',         1, 'real-estate/showrooms',         'real_estate', 'active', 1, 17, 'commercial'),
  ('01K2F3A00000000000000SEG18', @lf_re, @lf_re, 'shop',             'shops',             'Shop',             'Shops',             1, 'real-estate/shops',             'real_estate', 'active', 1, 18, 'commercial'),
  ('01K2F3A00000000000000SEG19', @lf_re, @lf_re, 'factory',          'factories',         'Factory',          'Factories',         1, 'real-estate/factories',         'real_estate', 'active', 1, 19, 'commercial'),
  ('01K2F3A00000000000000SEG20', @lf_re, @lf_re, 'labour-camp',      'labour-camps',      'Labour Camp',      'Labour Camps',      1, 'real-estate/labour-camps',      'real_estate', 'active', 1, 20, 'commercial'),
  ('01K2F3A00000000000000SEG21', @lf_re, @lf_re, 'bulk-unit',        'bulk-units',        'Bulk Units',       'Bulk Units',        1, 'real-estate/bulk-units',        'real_estate', 'active', 1, 21, 'commercial'),
  ('01K2F3A00000000000000SEG22', @lf_re, @lf_re, 'industrial-land',  'industrial-land',   'Industrial Land',  'Industrial Land',   1, 'real-estate/industrial-land',   'real_estate', 'active', 1, 22, 'commercial'),
  ('01K2F3A00000000000000SEG23', @lf_re, @lf_re, 'commercial-floor', 'commercial-floors', 'Commercial Floor', 'Commercial Floors', 1, 'real-estate/commercial-floors', 'real_estate', 'active', 1, 23, 'commercial')
ON DUPLICATE KEY UPDATE name = VALUES(name), name_plural = VALUES(name_plural), slug = VALUES(slug),
                        path = VALUES(path), sort_order = VALUES(sort_order),
                        property_segment = VALUES(property_segment), deleted_at = NULL;

-- 3. Every real-estate listing's segment, from its type. Plot and Whole Building → residential.
UPDATE listings l
  JOIN categories c ON c.id = l.category_id
   SET l.property_segment = IF(c.property_segment = 'commercial', 'commercial', 'residential')
 WHERE l.root_category_id = @lf_re AND l.property_segment IS NULL;

-- 4. The projection: copy the segment (this redefines 0060's procedure with one column added)
--    and fill it for the rows already there.
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_refresh_listing_search$$
CREATE PROCEDURE sp_refresh_listing_search(IN p_listing_id BIGINT UNSIGNED)
MODIFIES SQL DATA
BEGIN
  -- Remove rows that no longer qualify (unpublished, expired, soft-deleted).
  DELETE ls FROM listing_search ls
   WHERE (p_listing_id IS NULL OR ls.listing_id = p_listing_id)
     AND NOT EXISTS (SELECT 1 FROM v_public_listings v WHERE v.id = ls.listing_id);

  REPLACE INTO listing_search (
    listing_id, public_id, reference,
    root_category_id, category_id, purpose_id, category_slug, purpose_slug,
    title, slug, canonical_path, cover_image_url, image_count,
    price, currency_code, price_base, price_period, price_per_area,
    country_id, state_id, city_id, community_id, sub_community_id,
    location_label, latitude, longitude,
    organization_id, organization_name, organization_logo_url,
    agent_id, agent_name, agent_slug, agent_photo_url,
    contact_phone, contact_whatsapp,
    is_featured, is_premium, is_verified, is_exclusive, has_virtual_tour,
    spec_a, spec_b, spec_c, spec_d, spec_e, spec_f, spec_labels,
    facet_a, facet_b, facet_c,
    brand_id, brand_model_id, project_id, feature_ids,
    quality_score, published_at, last_refreshed_at, boost_score,
    source_updated_at, property_segment
  )
  SELECT
    l.id, l.public_id, l.reference,
    l.root_category_id, l.category_id, l.purpose_id, cat.slug, pur.slug,
    l.title, l.slug, l.canonical_path, l.cover_image_url, l.image_count,
    l.price, l.currency_code, l.price_base, l.price_period, l.price_per_area,
    l.country_id, l.state_id, l.city_id, l.community_id, l.sub_community_id,
    -- Breadcrumb built deepest-first, skipping levels the listing does not have.
    CONCAT_WS(', ',
      NULLIF(COALESCE(sc.name, ''), ''),
      NULLIF(COALESCE(cm.name, ''), ''),
      NULLIF(COALESCE(ct.name, ''), ''),
      NULLIF(COALESCE(co.name, ''), '')
    ),
    l.latitude, l.longitude,
    l.organization_id, org.name, org.logo_url,
    l.agent_id, ag.display_name, ag.slug, ag.photo_url,
    l.contact_phone, l.contact_whatsapp,
    l.is_featured, l.is_premium, l.is_verified, l.is_exclusive, l.has_virtual_tour,

    -- spec_a..spec_f, per the mapping in 0013.
    CASE root.code
      WHEN 'real-estate' THEN re.bedrooms
      WHEN 'cars'        THEN veh.model_year
      WHEN 'yachts'      THEN FLOOR(mar.length_overall_ft)
      WHEN 'jets'        THEN av.year_built
      WHEN 'helicopters' THEN av.year_built
      WHEN 'watches'     THEN tp.year_of_production
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.bathrooms
      WHEN 'cars'        THEN veh.mileage_km
      WHEN 'yachts'      THEN mar.build_year
      WHEN 'jets'        THEN av.total_time_hours
      WHEN 'helicopters' THEN av.total_time_hours
      WHEN 'watches'     THEN FLOOR(tp.case_diameter_mm)
    END,
    CASE root.code
      WHEN 'real-estate' THEN FLOOR(re.built_area_sqft)
      WHEN 'cars'        THEN veh.horsepower
      WHEN 'yachts'      THEN mar.cabins
      WHEN 'jets'        THEN av.passenger_capacity
      WHEN 'helicopters' THEN av.passenger_capacity
      WHEN 'watches'     THEN tp.power_reserve_hours
    END,
    CASE root.code
      WHEN 'real-estate' THEN FLOOR(re.plot_area_sqft)
      WHEN 'cars'        THEN veh.engine_size_cc
      WHEN 'yachts'      THEN mar.guests_sleeping
      WHEN 'jets'        THEN av.range_nm
      WHEN 'helicopters' THEN av.range_nm
      WHEN 'watches'     THEN tp.water_resistance_m
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.year_built
      WHEN 'cars'        THEN veh.seats
      WHEN 'yachts'      THEN mar.engine_hours
      WHEN 'jets'        THEN av.cycles
      WHEN 'helicopters' THEN av.cycles
      WHEN 'watches'     THEN tp.jewels
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.floor_number
      WHEN 'cars'        THEN veh.doors
      WHEN 'yachts'      THEN FLOOR(mar.max_speed_knots)
      WHEN 'jets'        THEN av.max_cruise_speed_kts
      WHEN 'helicopters' THEN av.max_cruise_speed_kts
      ELSE NULL
    END,
    -- Human-readable spec strip for the card.
    CASE root.code
      WHEN 'real-estate' THEN JSON_OBJECT('beds', re.bedrooms, 'baths', re.bathrooms,
                                          'area_sqft', re.built_area_sqft, 'type', cat.name)
      WHEN 'cars'        THEN JSON_OBJECT('year', veh.model_year, 'mileage_km', veh.mileage_km,
                                          'transmission', veh.transmission, 'fuel', veh.fuel_type)
      WHEN 'yachts'      THEN JSON_OBJECT('length_ft', mar.length_overall_ft, 'year', mar.build_year,
                                          'cabins', mar.cabins, 'guests', mar.guests_sleeping)
      WHEN 'jets'        THEN JSON_OBJECT('year', av.year_built, 'seats', av.passenger_capacity,
                                          'range_nm', av.range_nm, 'hours', av.total_time_hours)
      WHEN 'helicopters' THEN JSON_OBJECT('year', av.year_built, 'seats', av.passenger_capacity,
                                          'range_nm', av.range_nm, 'hours', av.total_time_hours)
      WHEN 'watches'     THEN JSON_OBJECT('year', tp.year_of_production, 'case_mm', tp.case_diameter_mm,
                                          'movement', tp.movement_type, 'full_set', tp.is_full_set)
    END,

    CASE root.code
      WHEN 'real-estate' THEN re.furnishing
      WHEN 'cars'        THEN veh.transmission
      WHEN 'yachts'      THEN mar.vessel_type
      WHEN 'jets'        THEN av.aircraft_type
      WHEN 'helicopters' THEN av.aircraft_type
      WHEN 'watches'     THEN tp.movement_type
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.completion_status
      WHEN 'cars'        THEN veh.fuel_type
      WHEN 'yachts'      THEN mar.hull_material
      WHEN 'jets'        THEN av.engine_program
      WHEN 'helicopters' THEN av.engine_program
      WHEN 'watches'     THEN tp.condition_grade
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.ownership_type
      WHEN 'cars'        THEN veh.condition_type
      WHEN 'yachts'      THEN IF(mar.is_charter_available, 'charter', 'sale')
      WHEN 'watches'     THEN tp.case_material
      ELSE NULL
    END,

    l.brand_id, l.brand_model_id, l.project_id,
    (SELECT JSON_ARRAYAGG(lf.feature_id) FROM listing_features lf WHERE lf.listing_id = l.id),

    l.quality_score, l.published_at, l.last_refreshed_at,
    (l.is_featured * 100) + (l.is_premium * 50),
    l.updated_at,
    -- 0077: read from listings itself; v_public_listings is `l.*` frozen before the column existed.
    (SELECT seg.property_segment FROM listings seg WHERE seg.id = l.id)
  FROM v_public_listings l
  JOIN categories cat  ON cat.id  = l.category_id
  JOIN categories root ON root.id = l.root_category_id
  JOIN purposes   pur  ON pur.id  = l.purpose_id
  LEFT JOIN organizations org ON org.id = l.organization_id
  LEFT JOIN agents ag         ON ag.id  = l.agent_id
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations cm ON cm.id = l.community_id
  LEFT JOIN locations sc ON sc.id = l.sub_community_id
  LEFT JOIN listing_real_estate re ON re.listing_id  = l.id
  LEFT JOIN listing_vehicle veh    ON veh.listing_id = l.id
  LEFT JOIN listing_marine mar     ON mar.listing_id = l.id
  LEFT JOIN listing_aviation av    ON av.listing_id  = l.id
  LEFT JOIN listing_timepiece tp   ON tp.listing_id  = l.id
  WHERE (p_listing_id IS NULL OR l.id = p_listing_id)
    -- 0060: a live listing with changes waiting for approval keeps its approved row; the
    -- source tables already hold the owner's unreviewed edits.
    AND NOT EXISTS (SELECT 1 FROM listings pr WHERE pr.id = l.id AND pr.pending_revision_id IS NOT NULL);
END$$
DELIMITER ;


UPDATE listing_search ls
  JOIN listings l ON l.id = ls.listing_id
   SET ls.property_segment = l.property_segment
 WHERE ls.root_category_id = @lf_re;

INSERT INTO schema_migrations (version, name) VALUES ('0077', 'property_segments')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
