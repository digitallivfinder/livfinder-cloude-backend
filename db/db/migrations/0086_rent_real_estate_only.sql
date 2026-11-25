-- =============================================================================
-- 0086_rent_real_estate_only.sql
--
-- Real estate is the only marketplace that rents (owner, 2026-11-25). Cars lose Rent; yachts,
-- jets and helicopters lose Charter; jets lose Lease. Every other marketplace is sale only
-- (auction stays where it was, unused by the website).
--
--   1. category_purposes  Rent, Charter and Lease are offered by real estate only.
--   2. listings           Live or waiting rentals and charters outside real estate are withdrawn,
--                         not deleted: the seller keeps them and can re-list one as a sale. Drafts
--                         are left alone; the API now refuses those purposes, so a draft must
--                         switch to Sale to publish.
--   3. listing_search     Withdrawn listings leave the search; the counters are recounted.
--
-- The charter detail columns (is_charter_available, charter_hourly_rate …) are kept, unread, so
-- no stored value is lost. Safe to run more than once.
-- =============================================================================

SET @lf_re = (SELECT id FROM categories WHERE slug = 'real-estate' AND parent_id IS NULL LIMIT 1);

-- 1. Only real estate rents.
DELETE cp FROM category_purposes cp
  JOIN categories c ON c.id = cp.category_id
  JOIN purposes p ON p.id = cp.purpose_id
 WHERE p.code IN ('rent', 'charter', 'lease')
   AND COALESCE(c.root_category_id, c.id) <> @lf_re;

-- 2. Rentals and charters outside real estate that are live or waiting for review are withdrawn.
UPDATE listings l
  JOIN purposes p ON p.id = l.purpose_id
   SET l.status = 'withdrawn'
 WHERE p.code IN ('rent', 'charter', 'lease')
   AND l.root_category_id <> @lf_re
   AND l.status IN ('active', 'pending_review')
   AND l.deleted_at IS NULL;

-- 3. Out of the search, and the counters of the marketplaces involved recounted.
DELETE ls FROM listing_search ls
  JOIN purposes p ON p.id = ls.purpose_id
 WHERE p.code IN ('rent', 'charter', 'lease')
   AND ls.root_category_id <> @lf_re;

UPDATE categories c
   SET c.listing_count = (SELECT COUNT(*) FROM listings l WHERE l.category_id = c.id AND l.deleted_at IS NULL),
       c.active_listing_count = (SELECT COUNT(*) FROM listing_search ls WHERE ls.category_id = c.id)
 WHERE COALESCE(c.root_category_id, c.id) <> @lf_re;

INSERT INTO schema_migrations (version, name) VALUES ('0086', 'rent_real_estate_only')
  ON DUPLICATE KEY UPDATE name = VALUES(name);
