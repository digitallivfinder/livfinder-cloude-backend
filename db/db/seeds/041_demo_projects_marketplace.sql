-- =============================================================================
-- Liv Finder — demo seed · developments on the public marketplace
-- =============================================================================
-- 0035_projects_marketplace.sql and 0036_project_search_routines.sql carry data steps as well
-- as schema: they publish the developments that were already public, derive their launch state,
-- turn the `amenities` JSON into rows and give every development its canonical address. On a
-- database that already has projects, `migrate` does all of that. On a fresh `load.sh all` the
-- migrations run before 041_demo_projects.sql inserts anything, so those steps find no rows —
-- and every development stays a draft with no address, invisible on the website.
--
-- This applies the same steps to the seeded developments, straight after they are inserted.
-- Everything is guarded exactly as in the migrations, so it never overrides a later edit.
-- =============================================================================

SET NAMES utf8mb4;

-- Publication follows the flag that already governed it (0035 §2).
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

-- A development under construction has, by definition, launched.
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

UPDATE projects
   SET launch_status = 'sold_out'
 WHERE available_units IS NOT NULL AND available_units = 0
   AND total_units IS NOT NULL AND total_units > 0
   AND status NOT IN ('cancelled', 'on_hold');

UPDATE projects p
  JOIN locations l ON l.id = COALESCE(p.community_id, p.city_id)
   SET p.state_id = l.state_id
 WHERE p.state_id IS NULL AND l.state_id IS NOT NULL;

-- A development's dates agree with its stage. The seed drew them independently, so a
-- "Handed over, 100% complete" development could show a 2028 handover and one "under
-- construction" a handover already past. Measured from the day of the load, so the demo stays
-- right whenever it is loaded. Assignments run left to right: launch and construction start are
-- pulled back behind the handover date just set.
UPDATE projects
   SET handover_date = DATE_SUB(CURDATE(), INTERVAL (4 + id % 20) MONTH),
       launch_date = LEAST(COALESCE(launch_date, handover_date), DATE_SUB(handover_date, INTERVAL 36 MONTH)),
       construction_start_date = LEAST(COALESCE(construction_start_date, handover_date), DATE_SUB(handover_date, INTERVAL 30 MONTH))
 WHERE status IN ('handed_over', 'completed')
   AND handover_date IS NOT NULL AND handover_date > CURDATE();

UPDATE projects
   SET handover_date = DATE_ADD(CURDATE(), INTERVAL (6 + id % 30) MONTH)
 WHERE status IN ('under_construction', 'presale', 'announced')
   AND handover_date IS NOT NULL AND handover_date <= CURDATE();

-- One row per amenity, from the JSON list the seed wrote (0035 §4).
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

-- `/projects/{country}/{state}/{city}/{community}/{slug}` (0036).
CALL sp_rebuild_project_canonical_path(NULL);
