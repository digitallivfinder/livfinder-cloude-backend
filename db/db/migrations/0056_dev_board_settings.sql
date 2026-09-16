-- =============================================================================
-- Liv Finder — migration 0056 · Dev board settings (background photo)
-- =============================================================================
-- There is exactly one Upcoming Developments board, so its settings are a
-- single pinned row rather than a table keyed by board. Today that is just the
-- background photo behind the lists (the same thing Trello's board background
-- does); the table exists so the next board-wide preference does not need a
-- schema change of its own.
--
-- The image is stored as the URL returned by POST /v1/media/upload
-- (scope=dev-board), exactly like card covers and comment images in 0055.
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `dev_board_settings` (
  `id`                   TINYINT UNSIGNED NOT NULL,
  `background_image_url` VARCHAR(500)     DEFAULT NULL,
  `updated_at`           DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Board-wide preferences for the single Upcoming Developments board. Always one row, id = 1.';

INSERT INTO `dev_board_settings` (`id`) VALUES (1)
  ON DUPLICATE KEY UPDATE `id` = `id`;

INSERT INTO schema_migrations (version, name) VALUES ('0056', 'dev_board_settings')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
