-- =============================================================================
-- 0075_optional_area_unit.sql
--
-- Lets an account leave its area unit unchosen.
--
-- The website shows prices and sizes in, first, the signed-in person's own choice and, failing
-- that, the usual currency and unit of the country they are in (m² in France, sq ft in the UAE).
-- `users.preferred_currency_id` is already nullable, so "never chose a currency" is visible.
-- `preferred_area_unit` was NOT NULL DEFAULT 'sqft', so every account appeared to have chosen
-- square feet and a new account in Paris was shown sq ft. From here a new account starts with
-- NULL and follows its location until the person picks a unit.
--
-- Existing values are kept: there is no telling a deliberate 'sqft' from the old default.
-- Safe to run more than once.
-- =============================================================================

ALTER TABLE users
  MODIFY preferred_area_unit VARCHAR(20) NULL DEFAULT NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0075', 'optional_area_unit')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
