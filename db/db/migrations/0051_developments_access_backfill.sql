-- 0051_developments_access_backfill.sql
--
-- Every development (project) belongs to a developer organization, but no developer
-- account held approved access to the Real Estate Developments category (root 7) —
-- the only approved row belonged to a car dealer. 0048 backfilled access from
-- `listings`, and developments are `projects`, so it never covered them. Without the
-- grant a developer cannot open their own Developments pages in the portal or submit
-- a development, and their website enquiries have nowhere to be worked.
--
-- Same rule as 0048: an account that owns live inventory in a category holds approved
-- access to it. Idempotent; never overrides a revoked or rejected decision.

INSERT INTO account_category_access
  (account_id, category_id, status, listing_used, requested_at, reviewed_at, created_at)
SELECT DISTINCT o.account_id, 7, 'approved', 0, NOW(3), NOW(3), NOW(3)
  FROM projects p
  JOIN organizations o ON o.id = p.organization_id AND o.deleted_at IS NULL
  LEFT JOIN account_category_access aca
         ON aca.account_id = o.account_id AND aca.category_id = 7
 WHERE p.deleted_at IS NULL
   AND o.account_id IS NOT NULL
   AND aca.id IS NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0051', 'developments_access_backfill')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
