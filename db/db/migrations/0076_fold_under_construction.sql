-- =============================================================================
-- 0076_fold_under_construction.sql
--
-- Folds a listing's "Under Construction" completion status into "Off Plan".
--
-- The two meant the same thing to a buyer — not finished yet — and the website now offers
-- All / Ready / Off Plan only. Listings stored as under_construction are moved to off_plan, in the
-- listing detail and in the search projection, so the Off Plan filter finds them.
--
-- The ENUM keeps its value so nothing that still holds it (a revision payload, an old import)
-- fails to load; the API maps it to off_plan on every write from here on.
--
-- Not touched: a development's own lifecycle status (projects.status, project_search.status),
-- where "under construction" is a construction stage, not a listing's completion status.
--
-- Safe to run more than once.
-- =============================================================================

UPDATE listing_real_estate
   SET completion_status = 'off_plan'
 WHERE completion_status = 'under_construction';

-- The projection's copy of the same value (facet_b is real estate's completion status).
UPDATE listing_search
   SET facet_b = 'off_plan'
 WHERE root_category_id = (SELECT id FROM categories WHERE slug = 'real-estate' AND parent_id IS NULL LIMIT 1)
   AND facet_b = 'under_construction';

INSERT INTO schema_migrations (version, name) VALUES ('0076', 'fold_under_construction')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
