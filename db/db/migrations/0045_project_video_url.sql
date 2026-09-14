-- 0045_project_video_url.sql
--
-- The developments admin "Project Video" card (detail-page Media & Documents tab
-- and the add-development wizard) offers two ways to attach a video: upload a
-- file, or paste a hosted URL (YouTube / Vimeo / a direct link). The upload path
-- persists through the `video` media role; the hosted URL had nowhere to live
-- and was silently dropped on save. This adds the column it needs.
--
-- Pure ADD COLUMN, NULL — data-safe and idempotent (the lf_add_column helper
-- checks information_schema first). Not a post-seed migration (no seed
-- dependency), so no load.sh change — same as 0042 and 0044.

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

-- A hosted video URL for the project. NULL when the project has an uploaded
-- video (the `video` media role) or no video at all. VARCHAR(500) matches the
-- sibling `brochure_url` / `cover_image_url` columns.
CALL lf_add_column('projects', 'video_url', 'VARCHAR(500) NULL AFTER brochure_url');

DROP PROCEDURE IF EXISTS lf_add_column;

INSERT INTO schema_migrations (version, name) VALUES ('0045', 'project_video_url')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
