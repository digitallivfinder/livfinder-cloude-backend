-- =============================================================================
-- 0069_seller_intent_and_public_individuals.sql
--
-- `accounts.seller_intent` keeps the account type a person picked on Sell with us before a
-- social button, so their Member account can ask for the remaining details until they apply.
-- Approval now publishes an individual's advisor profile; individuals approved before this
-- change get theirs here. A profile an admin suspended or set inactive stays as it is.
-- Safe to run more than once.
-- =============================================================================

SET @add_column = (
  SELECT IF(COUNT(*) = 0,
    "ALTER TABLE accounts ADD COLUMN seller_intent ENUM('personal','organization') NULL",
    'SELECT 1')
    FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'accounts' AND column_name = 'seller_intent'
);
PREPARE add_column FROM @add_column;
EXECUTE add_column;
DEALLOCATE PREPARE add_column;

UPDATE agents ag
  JOIN accounts a ON a.owner_user_id = ag.user_id
  JOIN account_types t ON t.id = a.account_type_id
   SET ag.status = 'active',
       ag.verification_status = 'verified',
       ag.verified_at = COALESCE(ag.verified_at, a.verified_at, NOW(3)),
       ag.is_publicly_visible = 1
 WHERE t.code = 'lister' AND a.status = 'active' AND a.verification_status = 'verified'
   AND ag.status = 'pending' AND ag.deleted_at IS NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0069', 'seller_intent_and_public_individuals')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
