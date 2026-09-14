-- 0047_project_rejection_reason.sql
--
-- The admin "Reject a development" action (`DevelopmentModerationActions.jsx`)
-- collects a reason, the same way listing rejection does, but `projects` had
-- nowhere to put it — unlike `listings.rejection_reason`. The reason was
-- silently dropped (Zod strips unknown keys), so a rejected development gave
-- its developer no way to see why.
--
-- Pure ADD COLUMN, NULL — data-safe and idempotent (the lf_add_column helper
-- checks information_schema first). Not a post-seed migration (no seed
-- dependency) — same as 0042, 0044 and 0045.

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

CALL lf_add_column('projects', 'rejection_reason', 'VARCHAR(500) NULL AFTER moderation_status');

DROP PROCEDURE IF EXISTS lf_add_column;

INSERT INTO schema_migrations (version, name) VALUES ('0047', 'project_rejection_reason')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
