-- =============================================================================
-- 0052 — Plan allowance usage, recomputed from the listings themselves
-- =============================================================================
-- `accounts.listing_used` is what POST /v1/portal/listings checks against
-- `listing_quota` ("This account has used its listing allowance"). It was only
-- ever incremented — +1 on create, nothing on archive, withdraw, sold/rented,
-- expiry or delete — and the seed set values that never matched the rows: 47
-- accounts disagreed with their real listings, one by 474 (500/500 used while
-- owning 26), which blocked that owner from listing at all.
--
-- The rule from here on (listings.service.js `syncAccountListingUsage`): a
-- listing occupies a slot while it is draft, pending review, live or rejected
-- (awaiting a fix); archived, withdrawn, sold, rented, expired or deleted
-- listings free it. Usage is recomputed from the rows on every change, so it
-- cannot drift again. This migration brings every existing account into line.
--
-- `account_category_access.listing_used` (the per-category "X of Y" in the
-- portal) was never maintained at all; it follows the same rule per root
-- category. Developments (root 7) are projects, not listings, and are left out.
-- =============================================================================

UPDATE accounts a
   SET a.listing_used = (
         SELECT COUNT(*) FROM listings l
          WHERE l.account_id = a.id
            AND l.deleted_at IS NULL
            AND l.status IN ('draft', 'pending_review', 'active', 'rejected')
       );

UPDATE account_category_access aca
  JOIN categories c ON c.id = aca.category_id
   SET aca.listing_used = (
         SELECT COUNT(*) FROM listings l
          WHERE l.account_id = aca.account_id
            AND l.root_category_id = COALESCE(c.root_category_id, c.id)
            AND l.deleted_at IS NULL
            AND l.status IN ('draft', 'pending_review', 'active', 'rejected')
       )
 WHERE COALESCE(c.root_category_id, c.id) <> 7;

INSERT INTO schema_migrations (version, name) VALUES ('0052', 'listing_usage_recompute')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
