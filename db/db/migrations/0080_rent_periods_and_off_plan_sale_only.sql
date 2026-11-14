-- =============================================================================
-- 0080_rent_periods_and_off_plan_sale_only.sql
--
-- 1. Two more rent periods: Half-yearly and Quarterly (owner decision, 2026-11-14).
--      listing_real_estate.rent_period  + half_yearly, quarterly
--      listings.price_period            + half_year,   quarter
--    listing_search.price_period is a VARCHAR and needs nothing. The members are listed longest
--    first, which is the order the forms and the website's Rent duration filter show them in
--    (the options endpoint reads this ENUM). Re-listing an ENUM converts stored values by name.
--
-- 2. Off plan is for sale only: a property not yet built cannot be let. Rentals stored as
--    off_plan (or under_construction, which 0076 folded into it) become Ready, in the detail and
--    in the search projection (facet_b is real estate's completion status).
--
-- Safe to run more than once.
-- =============================================================================

SET NAMES utf8mb4;

ALTER TABLE listing_real_estate
  MODIFY COLUMN rent_period ENUM('yearly','half_yearly','quarterly','monthly','weekly','daily') NULL;

ALTER TABLE listings
  MODIFY COLUMN price_period ENUM('total','year','half_year','quarter','month','week','day','hour','nautical_day','flight_hour') NULL;

UPDATE listing_real_estate lre
  JOIN listings l ON l.id = lre.listing_id
  JOIN purposes p ON p.id = l.purpose_id
   SET lre.completion_status = 'ready',
       lre.handover_date = NULL
 WHERE p.code = 'rent'
   AND lre.completion_status IN ('off_plan','under_construction');

UPDATE listing_search ls
  JOIN listings l ON l.id = ls.listing_id
  JOIN purposes p ON p.id = l.purpose_id
   SET ls.facet_b = 'ready'
 WHERE ls.root_category_id = (SELECT id FROM categories WHERE slug = 'real-estate' AND parent_id IS NULL LIMIT 1)
   AND p.code = 'rent'
   AND ls.facet_b IN ('off_plan','under_construction');

INSERT INTO schema_migrations (version, name) VALUES ('0080', 'rent_periods_and_off_plan_sale_only')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
