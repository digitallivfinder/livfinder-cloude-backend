-- 0044_floor_plan_unit_fields.sql
--
-- The developments admin "Add Floor Plan" modal (both the add-development wizard
-- and the detail-page Media & Documents tab) collects a unit type and a bedroom
-- count for every floor plan, but `floor_plans` had nowhere to store either, so
-- that part of the form was discarded on save. This adds the two columns.
--
-- Pure ADD COLUMN, both NULL — data-safe and idempotent (the lf_add_column
-- helper checks information_schema first). Not a post-seed migration.

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

-- Free-text unit type ("Apartment", "Townhouse", …). The form offers a curated
-- list (DEVELOPMENT_PROPERTY_TYPES) but the column is not an ENUM so the list
-- can grow without a migration.
CALL lf_add_column('floor_plans', 'unit_type', 'VARCHAR(80) NULL AFTER name');

-- Bedroom count for the plan. NULL for a plan that does not describe a home
-- (a whole-floor plate, a retail unit).
CALL lf_add_column('floor_plans', 'bedrooms', 'TINYINT UNSIGNED NULL AFTER unit_type');

DROP PROCEDURE IF EXISTS lf_add_column;

INSERT INTO schema_migrations (version, name) VALUES ('0044', 'floor_plan_unit_fields')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
