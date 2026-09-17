-- =============================================================================
-- 0057 — a real "unlimited" sentinel for listing/agent-seat quotas
-- =============================================================================
-- `accounts.listing_quota` is the column `POST /listings` actually enforces
-- (`listing_used >= listing_quota` blocks creation), and it was NOT NULL. The
-- seeded convention on `plans.listing_quota` uses 0 to mean "unlimited" (see
-- Enterprise's own description: "Unlimited listings, unlimited seats..."), but
-- 0 also correctly means "zero listings allowed" for the Free plan ("No
-- listing capability"). Copying a plan's 0 straight onto the account column
-- collapses both meanings into a hard cap of zero — assigning Enterprise (or
-- Free) through the package-change screen blocked the account from creating
-- any listing at all, the opposite of what Enterprise promises.
--
-- `session.serializer.js` (`membership.listing_quota === null ? null : ...`)
-- already expected this column to support a real NULL-is-unlimited sentinel;
-- the schema just never allowed it. This migration:
--   1. Makes `accounts.listing_quota` / `featured_quota` and
--      `plans.listing_quota` / `agent_seat_quota` nullable.
--   2. Fixes the one plan whose 0 was actually meant as "unlimited" —
--      Enterprise — to NULL. Every other plan's 0 (only Free) genuinely means
--      zero, per its own description, and is left as-is.
--   3. Reconciles the accounts already on Enterprise (previously hand-seeded
--      at a stand-in 500) to the real NULL, matching `changeAccountPackage`'s
--      own comment that "the account's own quota mirrors the plan".
-- `plans.featured_quota` and `lead_quota` have no such ambiguity in the
-- current catalogue (no plan uses 0 to mean "unlimited" for either) and are
-- left as NOT NULL.
-- =============================================================================

ALTER TABLE accounts
  MODIFY COLUMN listing_quota int unsigned NULL DEFAULT NULL,
  MODIFY COLUMN featured_quota int unsigned NULL DEFAULT NULL;

ALTER TABLE plans
  MODIFY COLUMN listing_quota int unsigned NULL DEFAULT NULL,
  MODIFY COLUMN agent_seat_quota int unsigned NULL DEFAULT NULL;

UPDATE plans
   SET listing_quota = NULL, agent_seat_quota = NULL
 WHERE code = 'enterprise';

UPDATE accounts a
  JOIN subscriptions s ON s.account_id = a.id AND s.status IN ('active', 'trialing', 'past_due')
  JOIN plans p ON p.id = s.plan_id
   SET a.listing_quota = NULL
 WHERE p.code = 'enterprise';

INSERT INTO schema_migrations (version, name) VALUES ('0057', 'quota_unlimited_sentinel')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
