-- =============================================================================
-- 0068_individual_listing_categories.sql
--
-- Listing creation now checks the category grant for individual sellers too. Individuals
-- who already hold listings in a category keep the right to list there. A refused or
-- revoked grant stays as the admin left it. Safe to run more than once.
-- =============================================================================

INSERT INTO account_category_access
  (account_id, category_id, status, listing_used, requested_at, reviewed_at, notes, created_at)
SELECT l.account_id, l.root_category_id, 'approved',
       SUM(l.status IN ('pending_review', 'active')), NOW(3), NOW(3),
       'Granted for listings held before category checks applied to individuals.', NOW(3)
  FROM listings l
  JOIN accounts a ON a.id = l.account_id
  JOIN account_types t ON t.id = a.account_type_id
 WHERE t.code = 'lister' AND l.deleted_at IS NULL AND l.root_category_id IS NOT NULL
 GROUP BY l.account_id, l.root_category_id
ON DUPLICATE KEY UPDATE
  status = IF(status = 'requested', 'approved', status),
  reviewed_at = IF(status = 'approved', COALESCE(reviewed_at, NOW(3)), reviewed_at);

INSERT INTO schema_migrations (version, name) VALUES ('0068', 'individual_listing_categories')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
