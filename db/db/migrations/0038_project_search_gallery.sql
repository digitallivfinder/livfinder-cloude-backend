-- =============================================================================
-- Liv Finder — 0038 · project card galleries
-- =============================================================================
-- A project card could show one photograph. `project_search` carried
-- `cover_image_url` and `image_count`, so a card could say "1 / 5" and then
-- refuse to page — the arrows had nothing to move through, and the count was a
-- claim the card could not honour.
--
-- The first few gallery URLs live in the projection now, so the card slider is
-- real. Capped deliberately: a card shows a handful of images, the detail page
-- shows the gallery, and denormalising the whole set would put kilobytes of URL
-- on every row of a search result.
--
-- IDEMPOTENT. Safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

SET @lf_has_column = (
  SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'project_search' AND column_name = 'gallery_urls'
);
SET @lf_sql = IF(
  @lf_has_column = 0,
  'ALTER TABLE project_search ADD COLUMN gallery_urls VARCHAR(3000) NULL AFTER cover_image_url',
  'DO 0'
);
PREPARE lf_stmt FROM @lf_sql;
EXECUTE lf_stmt;
DEALLOCATE PREPARE lf_stmt;

DROP PROCEDURE IF EXISTS sp_refresh_project_search;

DELIMITER //

CREATE PROCEDURE sp_refresh_project_search(IN p_project_id BIGINT UNSIGNED)
BEGIN
  DELETE FROM project_search
   WHERE (p_project_id IS NULL OR project_id = p_project_id);

  INSERT INTO project_search (
    project_id, public_id, name, slug, canonical_path, tagline,
    developer_brand_id, developer_slug, developer_name, developer_logo_url,
    country_id, state_id, city_id, community_id, sub_community_id, location_label, latitude, longitude,
    project_type, status, launch_status, ownership_type, launch_date, handover_date, handover_year,
    completion_percentage, total_units, available_units, building_count,
    min_price, max_price, min_price_base, currency_code,
    bedrooms_min, bedrooms_max, area_min, area_max, unit_types, bedroom_values, availability,
    payment_plan_count, min_down_payment_percent, has_post_handover, payment_plan_types,
    cover_image_url, gallery_urls, image_count, is_featured, accepts_inquiries, active_listing_count,
    published_at, source_updated_at
  )
  SELECT
    p.id, p.public_id, p.name, p.slug, p.canonical_path, p.tagline,
    p.developer_brand_id, b.slug, b.name, b.logo_url,
    p.country_id, p.state_id, p.city_id, p.community_id, p.sub_community_id,
    NULLIF(CONCAT_WS(', ', cm.name, ct.name, st.name, co.name), ''),
    p.latitude, p.longitude,
    p.project_type, p.status, p.launch_status, p.ownership_type,
    p.launch_date, p.handover_date, YEAR(p.handover_date),
    p.completion_percentage, p.total_units, p.available_units, p.building_count,
    p.min_price, p.max_price, p.min_price_base, p.currency_code,
    ut.bedrooms_min, ut.bedrooms_max, ut.area_min, ut.area_max, ut.unit_types, ut.bedroom_values,
    COALESCE(
      ut.availability,
      CASE
        WHEN p.available_units IS NULL OR p.total_units IS NULL THEN NULL
        WHEN p.available_units = 0 THEN 'sold_out'
        WHEN p.available_units * 5 <= p.total_units THEN 'limited'
        ELSE 'available'
      END
    ),
    COALESCE(pp.plan_count, 0), pp.min_down_payment_percent,
    COALESCE(pp.has_post_handover, 0), pp.plan_types,
    p.cover_image_url, img.gallery_urls, COALESCE(img.image_count, 0),
    p.is_featured, p.accepts_inquiries,
    COALESCE(ls.active_listing_count, 0),
    p.published_at, p.updated_at
  FROM projects p
  LEFT JOIN brands b ON b.id = p.developer_brand_id AND b.deleted_at IS NULL
  LEFT JOIN locations co ON co.id = p.country_id
  LEFT JOIN locations st ON st.id = p.state_id
  LEFT JOIN locations ct ON ct.id = p.city_id
  LEFT JOIN locations cm ON cm.id = p.community_id
  LEFT JOIN (
    SELECT project_id,
           MIN(bedrooms) AS bedrooms_min,
           MAX(bedrooms) AS bedrooms_max,
           MIN(min_size) AS area_min,
           MAX(COALESCE(max_size, min_size)) AS area_max,
           LEFT(GROUP_CONCAT(DISTINCT unit_type ORDER BY unit_type SEPARATOR ','), 500) AS unit_types,
           LEFT(GROUP_CONCAT(DISTINCT bedrooms ORDER BY bedrooms SEPARATOR ','), 120) AS bedroom_values,
           CASE
             WHEN SUM(availability = 'available') > 0 THEN 'available'
             WHEN SUM(availability = 'limited') > 0 THEN 'limited'
             WHEN SUM(availability = 'coming_soon') > 0 THEN 'coming_soon'
             ELSE 'sold_out'
           END AS availability
      FROM project_unit_types
     GROUP BY project_id
  ) ut ON ut.project_id = p.id
  LEFT JOIN (
    SELECT project_id,
           COUNT(*) AS plan_count,
           MIN(down_payment_percent) AS min_down_payment_percent,
           MAX(COALESCE(post_handover_percent, 0) > 0 OR COALESCE(post_handover_months, 0) > 0) AS has_post_handover,
           LEFT(GROUP_CONCAT(DISTINCT plan_type ORDER BY plan_type SEPARATOR ','), 200) AS plan_types
      FROM project_payment_plans
     WHERE is_active = 1 AND project_id IS NOT NULL
     GROUP BY project_id
  ) pp ON pp.project_id = p.id
  LEFT JOIN (
    -- The first few gallery URLs, primary first, newline-separated because a
    -- URL cannot contain one. `group_concat_max_len` defaults to 1024, which
    -- would silently truncate mid-URL, so it is raised for this statement.
    SELECT ma.attachable_id AS project_id,
           COUNT(*) AS image_count,
           LEFT(
             GROUP_CONCAT(
               COALESCE(a.cdn_url, a.url)
               ORDER BY ma.is_primary DESC, ma.sort_order ASC, ma.id ASC
               SEPARATOR '\n'
             ),
             3000
           ) AS gallery_urls
      FROM media_attachments ma
      JOIN media_assets a ON a.id = ma.media_asset_id AND a.deleted_at IS NULL
     WHERE ma.attachable_type = 'project' AND ma.role IN ('gallery', 'cover')
     GROUP BY ma.attachable_id
  ) img ON img.project_id = p.id
  LEFT JOIN (
    SELECT project_id, COUNT(*) AS active_listing_count
      FROM listings
     WHERE project_id IS NOT NULL AND deleted_at IS NULL AND status = 'active'
     GROUP BY project_id
  ) ls ON ls.project_id = p.id
  WHERE (p_project_id IS NULL OR p.id = p_project_id)
    AND p.deleted_at IS NULL
    AND p.is_publicly_visible = 1
    AND p.moderation_status = 'published'
    AND p.canonical_path IS NOT NULL
    AND p.status <> 'cancelled'
    AND (p.developer_brand_id IS NULL OR b.id IS NOT NULL);
END //

DELIMITER ;

SET SESSION group_concat_max_len = 8192;
CALL sp_refresh_project_search(NULL);

INSERT INTO schema_migrations (version, name) VALUES ('0038', 'project_search_gallery')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
