-- =============================================================================
-- 0084_package_access.sql
--
-- A seller's tools follow their package (owner, 2026-11-24).
--
-- A seller with a working package gets every portal module its package includes. Without one
-- (no package chosen, or payment needed and not made) the portal keeps only the basics, the API
-- and integrations stop, seller automations stop, and its listings leave search and the listing
-- pages while their own pages, the sitemap and llms.txt keep them.
--
--   settings payment.payments_required   0 = nobody pays for now (launch), 1 = a package must be
--                                        paid unless the account has free access.
--   accounts.free_access                 an admin let this account use its package without paying.
--   accounts.free_access_at / _by        when and by whom.
--   accounts.package_prompt_dismissed_at the seller pressed "Later" on the first-login package
--                                        screen; it is not shown again on its own.
--   seller_package_holds                 seller accounts without a working package right now.
--                                        Kept in step by the API (modules/accounts/entitlement.js),
--                                        read by search and the seller automations.
--
-- Post-seed in load.sh: the settings row sits beside the seeded payment settings.
-- Safe to run more than once.
-- =============================================================================

SET @has_free := (SELECT COUNT(*) FROM information_schema.columns
                   WHERE table_schema = DATABASE() AND table_name = 'accounts' AND column_name = 'free_access');
SET @ddl := IF(@has_free = 0,
  'ALTER TABLE accounts
     ADD COLUMN free_access TINYINT(1) NOT NULL DEFAULT 0 AFTER featured_used,
     ADD COLUMN free_access_at DATETIME(3) NULL AFTER free_access,
     ADD COLUMN free_access_by BIGINT UNSIGNED NULL AFTER free_access_at,
     ADD COLUMN package_prompt_dismissed_at DATETIME(3) NULL AFTER free_access_by',
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS seller_package_holds (
  account_id BIGINT UNSIGNED NOT NULL,
  reason ENUM('no_package', 'unpaid') NOT NULL,
  held_since DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (account_id),
  CONSTRAINT fk_seller_package_holds_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO settings (group_key, setting_key, value, value_type, label, description, is_public, is_secret)
VALUES ('payment', 'payments_required', '0', 'boolean', 'Clients must pay',
        'Off: every client uses their package without paying. On: a package must be paid unless the client has free access.', 0, 0)
ON DUPLICATE KEY UPDATE label = VALUES(label), description = VALUES(description);

INSERT INTO schema_migrations (version, name) VALUES ('0084', 'package_access')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
