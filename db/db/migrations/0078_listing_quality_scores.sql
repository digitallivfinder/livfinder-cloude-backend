-- =============================================================================
-- 0078_listing_quality_scores.sql
--
-- Listing quality scores, computed by the API (src/modules/quality/listingQuality.js).
--
-- `listings.quality_score` existed from 0006 but nothing ever computed it: it held seeded numbers
-- (0–878) that still ranked the website. The API now writes a 0–100 score from the owner's rubric
-- (photos, description, title, details, amenities, location, media, permit) and copies it to
-- `listing_search.quality_score`, which ranks results.
--
--   1. listings.quality_scored_at   when the score was last computed; the maintenance sweep
--                                   rescores anything never scored or changed since
--                                   (quality_scored_at < updated_at)
--
-- No backfill here: the API scores every listing on its first maintenance run after deploy
-- (at boot, then every ten minutes, 2000 listings per run). Safe to run more than once.
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

CALL lf_add_column('listings', 'quality_scored_at', "DATETIME(3) NULL DEFAULT NULL AFTER quality_score");

DROP PROCEDURE IF EXISTS lf_add_column;

INSERT INTO schema_migrations (version, name) VALUES ('0078', 'listing_quality_scores')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
