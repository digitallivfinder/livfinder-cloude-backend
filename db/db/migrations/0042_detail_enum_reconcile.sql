-- 0042_detail_enum_reconcile.sql
--
-- Reconcile the listing detail-table ENUM columns with the values the API's Zod
-- schemas (listings.schemas.js) and the portal field sets actually need. Until
-- now several values passed Zod validation and were then rejected by the column
-- (documented in frontend .../listingFieldSafety.js CONTRACT_MISMATCHES). This
-- adds the missing members; it removes nothing, so it is data-safe and can be
-- re-run (MODIFY COLUMN to the same definition is a no-op).
--
-- Zod is aligned to these columns in the same change set.

-- listing_vehicle.transmission: electric cars have a single-speed reduction gear.
ALTER TABLE `listing_vehicle`
  MODIFY COLUMN `transmission`
  ENUM('manual','automatic','semi_automatic','cvt','dual_clutch','single_speed') NULL;

-- listing_vehicle.fuel_type: an "other" catch-all (e.g. LPG, CNG, ethanol).
ALTER TABLE `listing_vehicle`
  MODIFY COLUMN `fuel_type`
  ENUM('petrol','diesel','hybrid','plug_in_hybrid','electric','hydrogen','other') NULL;

-- listing_vehicle.condition_type: "restored" and "project" are real used-car
-- conditions the schema already offered; "salvage" stays.
ALTER TABLE `listing_vehicle`
  MODIFY COLUMN `condition_type`
  ENUM('new','used','certified_pre_owned','classic','salvage','restored','project') NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0042', 'detail_enum_reconcile')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
