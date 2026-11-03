-- =============================================================================
-- 0071_plan_included_addons.sql
--
-- A plan that offers an add-on now switches it on for its accounts. This does it once for
-- accounts already on such a plan, including any switched off before the rule existed.
-- Safe to run more than once.
-- =============================================================================

INSERT INTO account_addons
  (public_id, account_id, addon_code, plan_id, amount, currency_code, status, started_at, enabled_by_user_id)
SELECT UPPER(LEFT(REPLACE(UUID(), '-', ''), 26)), s.account_id, pa.addon_code, s.plan_id, pa.amount,
       pa.currency_code, 'active', NOW(3), NULL
  FROM subscriptions s
  JOIN plan_addons pa ON pa.plan_id = s.plan_id AND pa.is_available = 1
 WHERE s.status IN ('active', 'trialing', 'past_due')
ON DUPLICATE KEY UPDATE
  plan_id = VALUES(plan_id), amount = VALUES(amount), currency_code = VALUES(currency_code),
  started_at = IF(account_addons.status = 'active', account_addons.started_at, NOW(3)),
  status = 'active', ends_at = NULL, cancelled_at = NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0071', 'plan_included_addons')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
