-- =============================================================================
-- Liv Finder — demo seed · project editorial content
-- =============================================================================
-- The demo projects shipped with a single-sentence description and nothing in
-- `marketing_heading` or `highlights`, so the public detail page had one line of
-- prose where an off-plan buyer expects an overview.
--
-- Every sentence below is COMPOSED FROM THE PROJECT'S OWN COLUMNS — its
-- developer, community, project type, unit counts, handover date, price range,
-- completion percentage, amenities and payment plans. Nothing is asserted that
-- the record does not already hold, so the copy cannot contradict the facts
-- printed beside it. This is demo content in the sense that a real operator
-- would write something better; it is not invented data.
--
-- Only rows still carrying the one-line seed description are rewritten, so a
-- project edited through the admin wizard is never overwritten.
--
-- IDEMPOTENT. A second run matches nothing.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;
SET SESSION group_concat_max_len = 8192;

-- -----------------------------------------------------------------------------
-- 1 · Marketing heading
-- -----------------------------------------------------------------------------
UPDATE projects p
  LEFT JOIN locations cm ON cm.id = p.community_id
  LEFT JOIN locations ct ON ct.id = p.city_id
   SET p.marketing_heading = CONCAT(
         CASE p.project_type
           WHEN 'mixed_use' THEN 'A mixed-use address'
           WHEN 'commercial' THEN 'A commercial address'
           WHEN 'hospitality' THEN 'A hospitality address'
           WHEN 'branded_residence' THEN 'A branded residence'
           WHEN 'master_community' THEN 'A master community'
           ELSE 'A residential address'
         END,
         ' in ', COALESCE(cm.name, ct.name, 'the heart of the city')
       )
 WHERE p.deleted_at IS NULL
   AND p.marketing_heading IS NULL;

-- -----------------------------------------------------------------------------
-- 2 · Description
-- -----------------------------------------------------------------------------
-- Three paragraphs, blank-line separated: what and where, what is for sale, and
-- how it is bought. Each clause is dropped when the underlying column is null,
-- so a sparser project simply gets a shorter description.
UPDATE projects p
  LEFT JOIN brands b ON b.id = p.developer_brand_id
  LEFT JOIN locations cm ON cm.id = p.community_id
  LEFT JOIN locations ct ON ct.id = p.city_id
  LEFT JOIN locations co ON co.id = p.country_id
  LEFT JOIN (
    SELECT project_id, GROUP_CONCAT(label ORDER BY sort_order SEPARATOR ', ') AS amenities
      FROM project_amenities GROUP BY project_id
  ) am ON am.project_id = p.id
  LEFT JOIN (
    SELECT project_id,
           COUNT(*) AS plan_count,
           MIN(down_payment_percent) AS min_down,
           MAX(COALESCE(post_handover_percent, 0) > 0) AS post_handover
      FROM project_payment_plans WHERE is_active = 1 AND project_id IS NOT NULL
     GROUP BY project_id
  ) pp ON pp.project_id = p.id
   SET p.description = CONCAT_WS('\n\n',
         -- What it is and where.
         CONCAT_WS(' ',
           -- The article travels with the adjective: "a completed", "an
           -- under-construction". Deriving it from the raw enum produced
           -- "a under construction", which reads as a typo on every page.
           CONCAT(p.name, ' is ',
                  CASE p.status
                    WHEN 'announced' THEN 'an announced'
                    WHEN 'presale' THEN 'a pre-launch'
                    WHEN 'under_construction' THEN 'an under-construction'
                    WHEN 'completed' THEN 'a completed'
                    WHEN 'handed_over' THEN 'a handed-over'
                    WHEN 'on_hold' THEN 'an on-hold'
                    ELSE 'a'
                  END,
                  ' ', REPLACE(p.project_type, '_', ' '), ' development',
                  IF(b.name IS NULL, '', CONCAT(' by ', b.name)),
                  IF(COALESCE(cm.name, ct.name) IS NULL, '',
                     CONCAT(' in ', COALESCE(cm.name, ct.name),
                            IF(co.name IS NULL, '', CONCAT(', ', co.name)))),
                  '.'),
           IF(p.total_units IS NULL, NULL,
              CONCAT('The masterplan comprises ', FORMAT(p.total_units, 0), ' residences',
                     IF(p.building_count IS NULL, '', CONCAT(' across ', p.building_count, ' buildings')),
                     '.')),
           IF(p.handover_date IS NULL, NULL,
              CONCAT('Handover is scheduled for ', DATE_FORMAT(p.handover_date, '%M %Y'), '.')),
           IF(p.completion_percentage IS NULL OR p.status NOT IN ('under_construction', 'presale'), NULL,
              CONCAT('Construction is ', p.completion_percentage, '% complete.'))
         ),
         -- What is for sale.
         CONCAT_WS(' ',
           IF(p.min_price IS NULL, NULL,
              CONCAT('Prices start from ', COALESCE(p.currency_code, ''), ' ', FORMAT(p.min_price, 0),
                     IF(p.max_price IS NULL OR p.max_price = p.min_price, '',
                        CONCAT(' and reach ', COALESCE(p.currency_code, ''), ' ', FORMAT(p.max_price, 0))),
                     '.')),
           IF(p.available_units IS NULL, NULL,
              CONCAT(IF(p.available_units = 0,
                        'The current release is fully sold.',
                        CONCAT(FORMAT(p.available_units, 0), ' residences remain available in the current release.')))),
           IF(p.ownership_type IN ('freehold', 'leasehold'),
              CONCAT('Ownership is ', p.ownership_type, '.'), NULL)
         ),
         -- How it is bought, and what comes with it.
         CONCAT_WS(' ',
           IF(am.amenities IS NULL, NULL,
              CONCAT('Residents have access to ', LOWER(am.amenities), '.')),
           IF(pp.plan_count IS NULL, NULL,
              CONCAT(IF(pp.plan_count = 1, 'A payment plan is', CONCAT(pp.plan_count, ' payment plans are')),
                     ' available',
                     IF(pp.min_down IS NULL, '', CONCAT(', starting from ', FORMAT(pp.min_down, 0), '% down')),
                     IF(pp.post_handover = 1, ', including a post-handover option', ''),
                     '.')),
           'Register your interest for the full price list, floor plans and payment schedule.'
         )
       )
 WHERE p.deleted_at IS NULL
   -- The untouched one-line seed description, or one this seed wrote before.
   -- Anything an operator has edited through the admin wizard is left alone.
   AND p.description IS NOT NULL
   AND (
     (p.description NOT LIKE '%\n%' AND p.description LIKE '% development by %')
     OR p.description LIKE '%Register your interest for the full price list%'
   );

-- -----------------------------------------------------------------------------
-- 3 · Highlights
-- -----------------------------------------------------------------------------
-- Short, checkable facts. Each entry is omitted when its column is null, so the
-- list length follows the record rather than a fixed template.
UPDATE projects p
  LEFT JOIN locations cm ON cm.id = p.community_id
  LEFT JOIN (
    SELECT project_id, MIN(down_payment_percent) AS min_down,
           MAX(COALESCE(post_handover_percent, 0) > 0) AS post_handover
      FROM project_payment_plans WHERE is_active = 1 AND project_id IS NOT NULL
     GROUP BY project_id
  ) pp ON pp.project_id = p.id
   SET p.highlights = JSON_MERGE_PRESERVE(
         JSON_ARRAY(),
         IF(cm.name IS NULL, JSON_ARRAY(), JSON_ARRAY(CONCAT(cm.name, ' location'))),
         IF(p.handover_date IS NULL, JSON_ARRAY(),
            JSON_ARRAY(CONCAT('Handover ', CONCAT('Q', QUARTER(p.handover_date), ' ', YEAR(p.handover_date))))),
         IF(p.min_price IS NULL, JSON_ARRAY(),
            JSON_ARRAY(CONCAT('From ', COALESCE(p.currency_code, ''), ' ', FORMAT(p.min_price, 0)))),
         IF(pp.min_down IS NULL, JSON_ARRAY(),
            JSON_ARRAY(CONCAT(FORMAT(pp.min_down, 0), '% down payment'))),
         IF(pp.post_handover = 1, JSON_ARRAY('Post-handover payment plan'), JSON_ARRAY()),
         IF(p.ownership_type NOT IN ('freehold', 'leasehold'), JSON_ARRAY(),
            JSON_ARRAY(CONCAT(CONCAT(UPPER(LEFT(p.ownership_type, 1)), SUBSTRING(p.ownership_type, 2)), ' ownership'))),
         IF(p.total_units IS NULL, JSON_ARRAY(),
            JSON_ARRAY(CONCAT(FORMAT(p.total_units, 0), ' residences')))
       )
 WHERE p.deleted_at IS NULL
   AND (p.highlights IS NULL OR JSON_LENGTH(p.highlights) = 0);

COMMIT;
SET autocommit = 1;

CALL sp_refresh_project_search(NULL);
