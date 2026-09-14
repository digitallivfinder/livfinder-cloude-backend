-- 0046_aircraft_brand_segment.sql
--
-- Jets and helicopters deliberately share `brands.kind = 'aircraft_manufacturer'`
-- (see the comment on `BRAND_KIND` in search.repository.js) — that lets a search
-- filter resolve either without a car make colliding with a watch brand on a
-- shared slug. But it means `kind` alone cannot separate a jet maker from a
-- helicopter maker, and the make/model catalogue (`?all=true`, used by the
-- add-listing Manufacturer -> Model cascade and the admin listings-table filter)
-- enumerates by kind with no listing-count join to fall back on — so the jet form
-- offered Airbus Helicopters, Bell, Leonardo Helicopters, Robinson Helicopter and
-- Sikorsky, and the helicopter form offered every jet maker right back.
--
-- This adds the finer signal and backfills the 14 seeded aircraft manufacturers
-- (031_brands.sql). Column is data-safe (ADD COLUMN, NULL) and idempotent (the
-- lf_add_column helper checks information_schema first; the backfill UPDATEs are
-- plain value assignments, safe to re-run). References `031_brands.sql` rows by
-- slug, so this must run POST-SEED (see load.sh).

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

-- NULL for every non-aircraft brand (car makes, yacht builders, watch brands,
-- property developers); only meaningful where kind = 'aircraft_manufacturer'.
CALL lf_add_column('brands', 'aircraft_segment', "ENUM('fixed_wing','rotorcraft') NULL AFTER kind");

DROP PROCEDURE IF EXISTS lf_add_column;

UPDATE brands SET aircraft_segment = 'rotorcraft'
 WHERE kind = 'aircraft_manufacturer'
   AND slug IN ('airbus-helicopters', 'leonardo-helicopters', 'bell', 'sikorsky', 'robinson-helicopter');

UPDATE brands SET aircraft_segment = 'fixed_wing'
 WHERE kind = 'aircraft_manufacturer'
   AND slug NOT IN ('airbus-helicopters', 'leonardo-helicopters', 'bell', 'sikorsky', 'robinson-helicopter');

INSERT INTO schema_migrations (version, name) VALUES ('0046', 'aircraft_brand_segment')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
