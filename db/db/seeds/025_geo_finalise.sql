-- =============================================================================
-- Liv Finder — geography seed  (finalise)
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
-- Regenerate with:  python3 db/tools/build_geo_seed.py
--
-- Rebuilds the closure table and re-derives depth/path/ancestor
-- columns from parent_id, then sanity-checks the result. If the
-- hierarchy were inconsistent, the assertions below would fail.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

CALL sp_location_rebuild_tree();

-- Assertions. Each must return 0; a non-zero count means the seed is
-- wrong and should not be trusted.
SELECT COUNT(*) AS orphaned_non_country_locations
  FROM locations WHERE parent_id IS NULL AND level <> 'country';

SELECT COUNT(*) AS locations_missing_country_ancestor
  FROM locations WHERE country_id IS NULL;

SELECT COUNT(*) AS path_depth_mismatches
  FROM locations
 WHERE depth <> (LENGTH(path) - LENGTH(REPLACE(path, '/', '')));

SELECT COUNT(*) AS closure_self_rows_missing
  FROM locations l
  LEFT JOIN location_closure c
    ON c.ancestor_id = l.id AND c.descendant_id = l.id AND c.depth = 0
 WHERE c.ancestor_id IS NULL;

COMMIT;
SET autocommit = 1;
