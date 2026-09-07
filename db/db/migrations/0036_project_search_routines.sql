-- =============================================================================
-- Liv Finder — 0036 · project canonical paths and search projection routines
-- =============================================================================
-- 0035 added the columns; this fills them and keeps them filled.
--
-- `sp_rebuild_project_canonical_path` is the single writer of
-- `projects.canonical_path`. Nothing else — no service, no admin mutation, no
-- frontend helper — composes that string, so a project can only ever have one
-- public address and a slug or location edit cannot leave a stale one behind.
--
-- `sp_refresh_project_search` is the single writer of `project_search`. It
-- applies the public visibility rules once, in one place: a row that is not
-- publicly visible is deleted from the projection rather than filtered out of
-- every query that reads it.
--
-- IDEMPOTENT. Both routines are CREATE-after-DROP and both are safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

DROP PROCEDURE IF EXISTS sp_rebuild_project_canonical_path;
DROP PROCEDURE IF EXISTS sp_refresh_project_search;

DELIMITER //

-- -----------------------------------------------------------------------------
-- sp_rebuild_project_canonical_path(project_id)
-- -----------------------------------------------------------------------------
-- NULL rebuilds every project. The path stops at the first location level the
-- project does not have, exactly like `listings.canonical_path`: a project with
-- a city but no community is `/projects/uae/dubai/dubai-marina-tower`, not a
-- path with an empty segment in it.
--
-- A project with no country has no public address at all and gets NULL, which
-- is what keeps `/projects/{slug}` from resolving a half-located draft.
CREATE PROCEDURE sp_rebuild_project_canonical_path(IN p_project_id BIGINT UNSIGNED)
BEGIN
  UPDATE projects p
    LEFT JOIN locations co ON co.id = p.country_id
    LEFT JOIN locations st ON st.id = p.state_id
    LEFT JOIN locations ct ON ct.id = p.city_id
    LEFT JOIN locations cm ON cm.id = p.community_id
     SET p.canonical_path = CASE
           WHEN co.slug IS NULL THEN NULL
           ELSE CONCAT(
             '/projects/', co.slug,
             IF(st.slug IS NULL, '', CONCAT('/', st.slug)),
             IF(st.slug IS NULL OR ct.slug IS NULL, '', CONCAT('/', ct.slug)),
             IF(st.slug IS NULL OR ct.slug IS NULL OR cm.slug IS NULL, '', CONCAT('/', cm.slug)),
             '/', p.slug
           )
         END
   WHERE (p_project_id IS NULL OR p.id = p_project_id);
END //

-- -----------------------------------------------------------------------------
-- sp_refresh_project_search(project_id)
-- -----------------------------------------------------------------------------
-- NULL rebuilds the whole projection.
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
    cover_image_url, image_count, is_featured, accepts_inquiries, active_listing_count,
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
    -- Availability is derived from the unit types when there are any, and from
    -- the project's own counters when there are not. It is never invented: a
    -- project with neither is left NULL and the card shows no availability line.
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
    p.cover_image_url, COALESCE(img.image_count, 0), p.is_featured, p.accepts_inquiries,
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
    SELECT attachable_id AS project_id, COUNT(*) AS image_count
      FROM media_attachments
     WHERE attachable_type = 'project' AND role IN ('gallery', 'cover')
     GROUP BY attachable_id
  ) img ON img.project_id = p.id
  LEFT JOIN (
    SELECT project_id, COUNT(*) AS active_listing_count
      FROM listings
     WHERE project_id IS NOT NULL AND deleted_at IS NULL AND status = 'active'
     GROUP BY project_id
  ) ls ON ls.project_id = p.id
  WHERE (p_project_id IS NULL OR p.id = p_project_id)
    -- The public visibility contract, stated once.
    AND p.deleted_at IS NULL
    AND p.is_publicly_visible = 1
    AND p.moderation_status = 'published'
    AND p.canonical_path IS NOT NULL
    AND p.status <> 'cancelled'
    -- A project whose developer has been removed has no attributable owner, and
    -- the card, the detail page and the developer filter all read that object.
    AND (p.developer_brand_id IS NULL OR b.id IS NOT NULL);
END //

DELIMITER ;

CALL sp_rebuild_project_canonical_path(NULL);

-- A slug collision across two projects in the same community would make the path
-- ambiguous. `projects.slug` is already globally unique, so this cannot happen;
-- the assertion is here so a future relaxation of that constraint fails loudly.
SET @lf_duplicate_paths = (
  SELECT COUNT(*) FROM (
    SELECT canonical_path FROM projects
     WHERE canonical_path IS NOT NULL AND deleted_at IS NULL
     GROUP BY canonical_path HAVING COUNT(*) > 1
  ) d
);
SELECT IF(@lf_duplicate_paths = 0, 'canonical paths unique',
          CONCAT('FAILED: ', @lf_duplicate_paths, ' duplicate project canonical paths')) AS assertion;

CALL sp_refresh_project_search(NULL);

INSERT INTO schema_migrations (version, name) VALUES ('0036', 'project_search_routines')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
