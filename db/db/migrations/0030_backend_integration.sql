-- =============================================================================
-- 0030_backend_integration.sql
--
-- The gaps the API layer found once it was pointed at this schema. Nothing here
-- changes an existing column, and every statement is idempotent so the file can
-- be re-applied against a database that already has it.
--
-- 1. Secret-valued settings rows for the admin Payment Settings screen. The
--    `settings` table already has `is_secret`, but no seeded row used it, so
--    there was nowhere to put a provider secret key. Values are stored
--    AES-256-GCM encrypted by the application and are never returned to a
--    browser — the API reports only `{ configured, hint }`.
--
-- 2. A covering index for the portal's "my listings" screen, which filters by
--    account and status and orders by creation date. The existing
--    ix_listings_account orders by updated_at, so the created_at sort was a
--    filesort on every page.
--
-- 3. A covering index for the admin lead pipeline, which filters by category
--    and status and orders by creation date.
--
-- 4. An index on inquiries by account, which the portal inbox reads on every
--    request and which had no supporting index.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1. Payment provider secrets
--
-- INSERT IGNORE against the existing uq_settings_key(group_key, setting_key),
-- so re-running leaves any configured value untouched.
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO settings
  (group_key, setting_key, value, value_type, label, description, is_public, is_secret)
VALUES
  ('payment', 'stripe_publishable_key', NULL, 'string', 'Stripe publishable key',
   'Safe to expose to the browser. Required before card payments can be collected.', 0, 0),
  ('payment', 'stripe_secret_key', NULL, 'string', 'Stripe secret key',
   'Server-only. Stored encrypted; never returned by the API once saved.', 0, 1),
  ('payment', 'stripe_webhook_secret', NULL, 'string', 'Stripe webhook signing secret',
   'Server-only. Used to verify webhook signatures. Stored encrypted.', 0, 1),
  ('payment', 'environment', 'test', 'string', 'Payment environment',
   'test or live. Live requires a configured secret key.', 0, 0),
  ('payment', 'proration_mode', 'immediate', 'string', 'Proration on plan change', NULL, 0, 0),
  ('payment', 'refund_window_days', '14', 'integer', 'Refund window (days)', NULL, 0, 0),
  ('payment', 'grace_period_days', '7', 'integer', 'Payment grace period (days)', NULL, 0, 0),
  ('payment', 'renewal_reminder_days', '7', 'integer', 'Renewal reminder (days before)', NULL, 0, 0),
  ('payment', 'tax_mode', 'exclusive', 'string', 'Tax handling', 'inclusive or exclusive', 0, 0),
  ('payment', 'enabled_methods', '["card","bank_transfer"]', 'json', 'Enabled payment methods', NULL, 0, 0);

-- -----------------------------------------------------------------------------
-- 2-4. Indexes.
--
-- MySQL has no CREATE INDEX IF NOT EXISTS, so each one is added through a
-- prepared statement guarded by information_schema. Re-running is a no-op.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_add_index_if_missing;
DELIMITER $$
CREATE PROCEDURE sp_add_index_if_missing(
  IN p_table VARCHAR(64), IN p_index VARCHAR(64), IN p_definition VARCHAR(500)
)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.STATISTICS
     WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = p_table AND INDEX_NAME = p_index
  ) THEN
    SET @sql = CONCAT('ALTER TABLE `', p_table, '` ADD KEY `', p_index, '` ', p_definition);
    PREPARE stmt FROM @sql;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;
  END IF;
END$$
DELIMITER ;

CALL sp_add_index_if_missing('listings', 'ix_listings_account_created',
  '(account_id, status, created_at DESC, id DESC)');

CALL sp_add_index_if_missing('leads', 'ix_leads_category_status_created',
  '(root_category_id, status, created_at DESC)');

CALL sp_add_index_if_missing('inquiries', 'ix_inquiries_account_created',
  '(account_id, deleted_at, is_spam, created_at DESC)');

CALL sp_add_index_if_missing('favourites', 'ix_favourites_user_created',
  '(user_id, created_at DESC)');

DROP PROCEDURE IF EXISTS sp_add_index_if_missing;

-- -----------------------------------------------------------------------------
-- 5. Admin settings documents
--
-- The admin General Settings and Payment Settings screens own a nested
-- configuration document (general, marketplace, accounts, listings, …). The
-- `settings` table already stores typed values, including JSON, so each section
-- of the document is one JSON-valued row rather than a new table.
--
-- The flat `general.*` / `payment.*` rows the public site reads stay where they
-- are; the API mirrors the overlapping values into them on save so the two
-- cannot drift.
-- -----------------------------------------------------------------------------
INSERT IGNORE INTO settings
  (group_key, setting_key, value, value_type, label, description, is_public, is_secret)
VALUES
  ('admin_general', 'general',      NULL, 'json', 'Platform identity',      'Name, legal name, language, currency, timezone, default country.', 0, 0),
  ('admin_general', 'marketplace',  NULL, 'json', 'Marketplace defaults',   'Page size, default sort, which public profiles are enabled.', 0, 0),
  ('admin_general', 'accounts',     NULL, 'json', 'Accounts and verification', 'Registration, verification requirements and expiry.', 0, 0),
  ('admin_general', 'listings',     NULL, 'json', 'Listing policy',         'Approval mode, validation, archive behaviour, quota handling.', 0, 0),
  ('admin_general', 'leadsReviews', NULL, 'json', 'Leads and reviews',      'Lead routing and review approval policy.', 0, 0),
  ('admin_general', 'support',      NULL, 'json', 'Support',                'Support contact routing.', 0, 0),
  ('admin_general', 'preferences',  NULL, 'json', 'Formatting preferences', 'Date and number formats, notification channels.', 0, 0),
  ('admin_payment', 'general',      NULL, 'json', 'Payments',               'Whether payments are enabled and the default currency.', 0, 0),
  ('admin_payment', 'providers',    NULL, 'json', 'Providers',              'Enabled providers and environment. Secret keys live in the payment group.', 0, 0),
  ('admin_payment', 'billing',      NULL, 'json', 'Billing',                'Cycles, proration and upgrade/downgrade timing.', 0, 0),
  ('admin_payment', 'tax',          NULL, 'json', 'Tax',                    'Tax mode, rate and label.', 0, 0),
  ('admin_payment', 'invoices',     NULL, 'json', 'Invoices',               'Numbering and delivery.', 0, 0),
  ('admin_payment', 'refunds',      NULL, 'json', 'Refunds',                'Window and permitted reasons.', 0, 0),
  ('admin_payment', 'methods',      NULL, 'json', 'Payment methods',        'Which methods customers may use.', 0, 0),
  ('admin_payment', 'notifications', NULL, 'json', 'Payment notifications', 'Which payment events notify whom.', 0, 0),
  ('admin_payment', 'failures',     NULL, 'json', 'Failed payments',        'Retry schedule, grace period and dunning.', 0, 0);

-- Record the migration.
--
-- Every other file in this directory ends with this line; these five did not, so the five
-- changes they make were applied to the database while `schema_migrations` went on reporting
-- the schema as five versions older than it is. Anything that reads the ledger to decide what
-- to run — a deployment, a restore, a new environment — would conclude these were outstanding.
-- Idempotent, so re-applying the file re-asserts the row rather than failing on it.
INSERT INTO schema_migrations (version, name) VALUES ('0030', 'backend_integration')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
