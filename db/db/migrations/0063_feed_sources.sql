-- =============================================================================
-- 0063 — Feed sources: one XML/CSV feed URL per account per category
-- =============================================================================
-- A company (or an individual with the Integrations add-on) points LivFinder at
-- one file per category it has access to; never one per office (owner's rule,
-- 2026-10-29). LivFinder fetches it:
--
--   * on the account's schedule (hourly, every 6 hours or daily): a full fetch;
--   * every 10 minutes when `watch_changes` is on: a conditional fetch with the
--     server's ETag / Last-Modified, so an unchanged file costs one small request;
--   * at once when the company calls "refresh" (API) or "Run now" (portal).
--
-- A run whose bytes match the last one does nothing. Otherwise every entry is
-- imported unpublished (the company picks what goes live), and listings that
-- left the file are withdrawn, unless more than `max_removal_percent` of the
-- feed's listings would go at once: then the run is held for an admin to
-- release (`feed_imports.status = 'held_for_review'`).
--
-- Runs are ordinary `feed_imports` rows, tied to their feed by `feed_source_id`.
--
-- Idempotent: load.sh re-applies every file.
-- =============================================================================

CREATE TABLE IF NOT EXISTS feed_sources (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  category       VARCHAR(40)     CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  url            VARCHAR(1000)   NOT NULL,
  format         ENUM('auto','xml','csv') NOT NULL DEFAULT 'auto',
  schedule       ENUM('hourly','every_6_hours','daily') NOT NULL DEFAULT 'daily',
  watch_changes  TINYINT(1)      NOT NULL DEFAULT 1,
  status         ENUM('active','paused','error') NOT NULL DEFAULT 'active',
  max_removal_percent TINYINT UNSIGNED NOT NULL DEFAULT 20,
  -- What the server said last time, for the conditional fetch.
  etag           VARCHAR(255)    NULL,
  last_modified  VARCHAR(100)    NULL,
  last_checksum  CHAR(64)        NULL,
  last_checked_at DATETIME(3)    NULL,
  last_changed_at DATETIME(3)    NULL,
  last_run_at    DATETIME(3)     NULL,
  last_import_id BIGINT UNSIGNED NULL,
  held_import_id BIGINT UNSIGNED NULL,
  next_run_at    DATETIME(3)     NULL,
  next_check_at  DATETIME(3)     NULL,
  -- Set while a run holds the feed, so two workers never fetch it at once.
  running_since  DATETIME(3)     NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_error     VARCHAR(500)    NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_feed_sources_public_id (public_id),
  UNIQUE KEY uq_feed_sources_account_category (account_id, category),
  KEY ix_feed_sources_due (status, next_run_at),
  KEY ix_feed_sources_check (status, watch_changes, next_check_at),
  CONSTRAINT fk_feed_sources_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_sources_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_feed_sources_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

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

CALL lf_add_column('feed_imports', 'feed_source_id', 'BIGINT UNSIGNED NULL AFTER api_client_id');
DROP PROCEDURE IF EXISTS lf_add_column;

SET @lf_has_fk = (
  SELECT COUNT(*) FROM information_schema.table_constraints
   WHERE table_schema = DATABASE() AND table_name = 'feed_imports' AND constraint_name = 'fk_feed_imports_feed_source'
);
SET @lf_sql = IF(@lf_has_fk = 0,
  'ALTER TABLE feed_imports ADD KEY ix_feed_imports_feed_source (feed_source_id, created_at), ADD CONSTRAINT fk_feed_imports_feed_source FOREIGN KEY (feed_source_id) REFERENCES feed_sources (id) ON DELETE SET NULL',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

INSERT INTO schema_migrations (version, name) VALUES ('0063', 'feed_sources')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
