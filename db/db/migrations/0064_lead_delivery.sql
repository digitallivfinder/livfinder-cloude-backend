-- =============================================================================
-- 0064 — Leads out: signed webhooks and the lead feed
-- =============================================================================
-- Every enquiry, viewing request and offer a company receives can reach its own
-- systems (owner's rules, 2026-10-29), as part of the Integrations add-on:
--
--   * webhooks: LivFinder POSTs each event (lead.created, lead.updated, and
--     listing.changes_approved / listing.changes_rejected) to the company's URL,
--     signed with HMAC-SHA256, retried with backoff. `webhook_deliveries` is the
--     outbox the delivery worker drains.
--   * the lead feed: the full history, then only what changed, as JSON, XML or
--     CSV, over the listing API (`leads:read`) or a read-only feed address for
--     CRMs that can only fetch a URL (`lead_feed_tokens`).
--
-- The `webhooks` table (0012) kept only a hash of the secret, which can verify
-- one but cannot sign with it; the secret is now also kept encrypted
-- (utils/secrets.js), and shown to the company once.
--
-- Idempotent: load.sh re-applies every file.
-- =============================================================================

DROP PROCEDURE IF EXISTS lf_add_column;
DELIMITER //
CREATE PROCEDURE lf_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column
  ) THEN
    SET @lf_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
    PREPARE lf_stmt FROM @lf_sql;
    EXECUTE lf_stmt;
    DEALLOCATE PREPARE lf_stmt;
  END IF;
END //
DELIMITER ;

CALL lf_add_column('webhooks', 'secret_encrypted', 'VARCHAR(600) NULL AFTER secret_hash');
CALL lf_add_column('webhooks', 'secret_hint', 'VARCHAR(8) NULL AFTER secret_encrypted');
CALL lf_add_column('webhooks', 'created_by_user_id', 'BIGINT UNSIGNED NULL AFTER last_failure_at');
-- The event's own id, the same on every retry, so a receiver can tell a retry from a new event.
CALL lf_add_column('webhook_deliveries', 'event_id', 'CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER webhook_id');
CALL lf_add_column('webhook_deliveries', 'last_error', 'VARCHAR(500) NULL AFTER response_body');
DROP PROCEDURE IF EXISTS lf_add_column;

CREATE TABLE IF NOT EXISTS lead_feed_tokens (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  token_hash     BINARY(32)      NOT NULL,
  token_hint     VARCHAR(8)      NULL,
  status         ENUM('active','revoked') NOT NULL DEFAULT 'active',
  last_used_at   DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  revoked_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_feed_tokens_public_id (public_id),
  UNIQUE KEY uq_lead_feed_tokens_hash (token_hash),
  KEY ix_lead_feed_tokens_account (account_id, status),
  CONSTRAINT fk_lead_feed_tokens_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_feed_tokens_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The lead feed reads each source in update order.
SET @lf_has = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'inquiries' AND index_name = 'ix_inquiries_account_updated');
SET @lf_sql = IF(@lf_has = 0, 'ALTER TABLE inquiries ADD KEY ix_inquiries_account_updated (account_id, updated_at, id)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;
SET @lf_has = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'bookings' AND index_name = 'ix_bookings_account_updated');
SET @lf_sql = IF(@lf_has = 0, 'ALTER TABLE bookings ADD KEY ix_bookings_account_updated (account_id, updated_at, id)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;
SET @lf_has = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'offers' AND index_name = 'ix_offers_account_updated');
SET @lf_sql = IF(@lf_has = 0, 'ALTER TABLE offers ADD KEY ix_offers_account_updated (account_id, updated_at, id)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_has = (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'webhook_deliveries' AND index_name = 'ix_webhook_deliveries_event');
SET @lf_sql = IF(@lf_has = 0, 'ALTER TABLE webhook_deliveries ADD KEY ix_webhook_deliveries_event (event_id)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

INSERT INTO schema_migrations (version, name) VALUES ('0064', 'lead_delivery')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
