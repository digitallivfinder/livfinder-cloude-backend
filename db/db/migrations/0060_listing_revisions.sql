-- =============================================================================
-- 0060 — Pending revisions: owner edits wait for approval, the approved version stays live
-- =============================================================================
-- Until now an owner's change to a live listing took it off the site
-- (listings.service.js `sendBackForReview`) until a moderator approved it again.
-- The owner's rule from 2026-10-29: every change still goes to the queue, but the
-- site keeps showing the approved version until the change is approved.
--
-- How: owners keep editing the listing's own tables (every edit path, the portal
-- form, media, files and the import API, stays as it is). The first change to a
-- live listing opens a `listing_revisions` row that holds a snapshot of the public
-- page as approved, and points `listings.pending_revision_id` at it. While it is
-- set:
--
--   * the public detail page is served from the snapshot;
--   * the search projection keeps the approved row (the guard below);
--   * the slug and canonical path are not rewritten, so the URL does not move.
--
-- Approving publishes everything at once; rejecting leaves the approved version
-- live and returns the reasons to the owner, who fixes and resubmits.
--
-- Idempotent: load.sh re-applies every file.
-- =============================================================================

CREATE TABLE IF NOT EXISTS listing_revisions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  -- pending: waiting for a moderator. rejected: sent back with reasons; the owner's next
  -- change makes it pending again. approved / superseded: closed.
  status         ENUM('pending','rejected','approved','superseded') NOT NULL DEFAULT 'pending',
  -- The public page as approved, captured before the first change was applied.
  approved_snapshot JSON       NOT NULL,
  -- What the owner changed, one line per change ("Details edited", "Photos added").
  change_log     JSON            NULL,
  submitted_by_user_id BIGINT UNSIGNED NULL,
  submitted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_changed_at DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  rejection_reason VARCHAR(1000) NULL,
  -- Field-level issues: {"title": "Remove the phone number from the title."}
  rejection_fields JSON          NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_listing_revisions_public_id (public_id),
  KEY ix_listing_revisions_listing (listing_id, created_at),
  KEY ix_listing_revisions_queue (status, last_changed_at),
  CONSTRAINT fk_listing_revisions_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_revisions_submitter FOREIGN KEY (submitted_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_listing_revisions_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

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

-- The open revision, if any: the one pointer every read path checks.
CALL lf_add_column('listings', 'pending_revision_id', 'BIGINT UNSIGNED NULL DEFAULT NULL AFTER moderation_status');
DROP PROCEDURE IF EXISTS lf_add_column;

SET @lf_has_fk = (
  SELECT COUNT(*) FROM information_schema.table_constraints
   WHERE table_schema = DATABASE() AND table_name = 'listings' AND constraint_name = 'fk_listings_pending_revision'
);
SET @lf_sql = IF(@lf_has_fk = 0,
  'ALTER TABLE listings ADD CONSTRAINT fk_listings_pending_revision FOREIGN KEY (pending_revision_id) REFERENCES listing_revisions (id) ON DELETE SET NULL',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- The projection, redefined from 0014 with one guard added at the end.
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
    source_updated_at
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
    l.updated_at
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

INSERT INTO schema_migrations (version, name) VALUES ('0060', 'listing_revisions')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
