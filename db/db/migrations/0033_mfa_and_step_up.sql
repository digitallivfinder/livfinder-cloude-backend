-- =============================================================================
-- Liv Finder — migration 0033 · MFA and step-up
-- =============================================================================
-- SEC-IAM-002 makes multi-factor authentication mandatory for workforce,
-- privileged and seller-administrator accounts. SEC-IAM-011 requires
-- re-authentication before nine high-risk actions.
--
-- Both were modelled and neither existed: `user_mfa_factors` was an empty table
-- and `users.mfa_enabled` was surfaced read-only, so it could be displayed but
-- never become true. The only thing the schema was missing to support step-up
-- was somewhere to record that a session had recently re-proved itself.
--
-- IDEMPOTENT. Safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1 · When a session last re-proved itself
-- -----------------------------------------------------------------------------
-- On the session rather than the user: step-up authorises *this* browser for a
-- short window. Recording it per user would let a step-up on a laptop silently
-- authorise a high-risk action from a phone, which is the opposite of the point.

SET @has_column := (SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE()
                      AND table_name = 'user_sessions'
                      AND column_name = 'stepped_up_at');
SET @sql := IF(@has_column = 0,
  'ALTER TABLE `user_sessions`
     ADD COLUMN `stepped_up_at` DATETIME(3) NULL
       COMMENT ''Last successful step-up re-authentication on this session''
       AFTER `last_used_at`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 2 · Recovery codes are hashed, not encrypted
-- -----------------------------------------------------------------------------
-- `secret_encrypted` is VARBINARY(512), which held an AES-GCM blob for a TOTP
-- secret comfortably. A recovery code is a *credential*: it is verified, never
-- read back, so it is stored as an Argon2id hash in the same column. Argon2id
-- output is longer than the TOTP blob, so the column is widened rather than
-- silently truncating a hash — a truncated hash never matches, and the failure
-- would look like a wrong code rather than a storage bug.

SET @length := (SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.columns
                WHERE table_schema = DATABASE()
                  AND table_name = 'user_mfa_factors'
                  AND column_name = 'secret_encrypted');
SET @sql := IF(@length IS NOT NULL AND @length < 1024,
  'ALTER TABLE `user_mfa_factors`
     MODIFY COLUMN `secret_encrypted` VARBINARY(1024) NULL
       COMMENT ''AES-256-GCM blob for a TOTP secret, or an Argon2id hash for a recovery code''',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 3 · Look-ups this feature performs on every verification
-- -----------------------------------------------------------------------------

SET @has_index := (SELECT COUNT(*) FROM information_schema.statistics
                   WHERE table_schema = DATABASE()
                     AND table_name = 'user_mfa_factors'
                     AND index_name = 'ix_mfa_user_type_confirmed');
SET @sql := IF(@has_index = 0,
  'CREATE INDEX `ix_mfa_user_type_confirmed`
     ON `user_mfa_factors` (`user_id`, `factor_type`, `confirmed_at`)',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Record the migration.
--
-- Every other file in this directory ends with this line; these five did not, so the five
-- changes they make were applied to the database while `schema_migrations` went on reporting
-- the schema as five versions older than it is. Anything that reads the ledger to decide what
-- to run — a deployment, a restore, a new environment — would conclude these were outstanding.
-- Idempotent, so re-applying the file re-asserts the row rather than failing on it.
INSERT INTO schema_migrations (version, name) VALUES ('0033', 'mfa_and_step_up')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
