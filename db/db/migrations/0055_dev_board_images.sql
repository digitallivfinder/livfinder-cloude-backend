-- =============================================================================
-- Liv Finder — migration 0055 · Dev board card & comment images
-- =============================================================================
-- One optional cover image per card, one optional image per comment. Both are
-- stored as the media asset's already-resolvable URL (from
-- POST /v1/media/upload, scope=dev-board) rather than a media_assets FK — the
-- board deliberately doesn't need the gallery/rendition machinery a listing's
-- media does, just a picture on a card and a picture in a comment.
-- =============================================================================

SET NAMES utf8mb4;

SET @has_cover := (SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'dev_board_cards' AND column_name = 'cover_image_url');
SET @sql := IF(@has_cover = 0,
  'ALTER TABLE `dev_board_cards` ADD COLUMN `cover_image_url` VARCHAR(500) NULL AFTER `description`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @has_image := (SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'dev_board_comments' AND column_name = 'image_url');
SET @sql := IF(@has_image = 0,
  'ALTER TABLE `dev_board_comments` ADD COLUMN `image_url` VARCHAR(500) NULL AFTER `body`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT INTO schema_migrations (version, name) VALUES ('0055', 'dev_board_images')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
