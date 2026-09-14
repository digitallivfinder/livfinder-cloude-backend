-- 0048_category_access_backfill.sql
--
-- Found during a full go-live review of all 7 categories on both admin and
-- portal: every helicopter listing (24 of them, across 18 accounts) belongs to
-- an account with NO approved `account_category_access` row for helicopters —
-- 16 have no row at all, 2 are stuck on `requested`. Every other category is
-- internally consistent (an account never owns a listing in a category it
-- lacks approved access to); this is a seed-data gap from migration 0040's
-- backfill, which only carried over rows that already existed in the old
-- `organization_category_access` table — and none of those ever granted
-- helicopters to anyone, even though helicopter listings were seeded.
--
-- Practically: no seeded portal account could open the Helicopters dashboard,
-- see its own helicopter listings, or manage its enquiries — the category was
-- unreachable in the demo data despite having live inventory.
--
-- General rule, not hardcoded to helicopters: any account that owns an active
-- listing in a category it is not `approved` for gets approved. IDEMPOTENT
-- (ON DUPLICATE KEY UPDATE); safe to re-run. Reference categories seeded in
-- 030 and listings seeded later, so this is POST-SEED (see load.sh).

INSERT INTO account_category_access
  (account_id, category_id, status, listing_used, requested_at, reviewed_at, created_at)
SELECT DISTINCT o.account_id, l.root_category_id, 'approved', 0, NOW(3), NOW(3), NOW(3)
  FROM listings l
  JOIN organizations o ON o.id = l.organization_id AND o.deleted_at IS NULL
  LEFT JOIN account_category_access aca
         ON aca.account_id = o.account_id AND aca.category_id = l.root_category_id
 WHERE l.deleted_at IS NULL
   AND (aca.id IS NULL OR aca.status <> 'approved')
ON DUPLICATE KEY UPDATE status = 'approved', reviewed_at = NOW(3);

INSERT INTO schema_migrations (version, name) VALUES ('0048', 'category_access_backfill')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
