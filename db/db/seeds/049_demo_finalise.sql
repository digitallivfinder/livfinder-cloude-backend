-- =============================================================================
-- Liv Finder — demo seed · finalise
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
--
-- Derives every counter, rollup and projection from the rows that were just
-- inserted, then asserts that the derived values agree with their sources.
--
-- This file is the answer to the audit's most repeated finding. Nothing above
-- writes a count; everything countable is computed here. If a number in the UI
-- disagrees with the rows behind it, that is now a bug in the application, not
-- something the seed data quietly permitted.
-- =============================================================================

SET NAMES utf8mb4;

-- 1. Location tree: rebuild the closure table and roll listing counts up the
--    subtree, so a country's count includes everything beneath it.
CALL sp_location_refresh_counts();

-- 2. Listing, agent, organisation, category and brand counters, plus account
--    quota consumption, derived from their source tables.
CALL sp_refresh_entity_counters();

-- 3. Per-location, per-category inventory and price bands, for the category
--    landing pages and the location facet.
TRUNCATE TABLE location_category_stats;
INSERT INTO location_category_stats
  (location_id, category_id, purpose, listing_count, min_price_base, max_price_base,
   avg_price_base, median_price_base)
SELECT cl.ancestor_id,
       l.root_category_id,
       CASE p.code WHEN 'sale' THEN 'sale' WHEN 'rent' THEN 'rent'
                   WHEN 'charter' THEN 'charter' WHEN 'lease' THEN 'lease'
                   WHEN 'auction' THEN 'auction' ELSE 'any' END,
       COUNT(*),
       MIN(l.price_base), MAX(l.price_base), ROUND(AVG(l.price_base), 2),
       -- MySQL has no median aggregate; the average stands in until the
       -- price-index job computes a true median.
       ROUND(AVG(l.price_base), 2)
  FROM listings l
  JOIN purposes p         ON p.id = l.purpose_id
  JOIN location_closure cl ON cl.descendant_id = l.location_id
 WHERE l.deleted_at IS NULL
   AND l.status = 'active'
   AND l.location_id IS NOT NULL
 GROUP BY cl.ancestor_id, l.root_category_id, p.code;

-- 4. Public search projection. NULL rebuilds every row.
CALL sp_refresh_listing_search(NULL);

-- 5. Platform KPI series: fill the listing/user/agent counts that were left at
--    zero, from the real tables rather than from estimates.
UPDATE platform_daily_stats s
   SET s.total_listings  = (SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL
                             AND DATE(created_at) <= s.stat_date),
       s.active_listings = (SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL
                             AND status = 'active' AND DATE(created_at) <= s.stat_date),
       s.new_listings    = (SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL
                             AND DATE(created_at) = s.stat_date),
       s.pending_listings = (SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL
                             AND status = 'pending_review' AND DATE(created_at) <= s.stat_date),
       s.sold_rented_listings = (SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL
                             AND status IN ('sold','rented') AND DATE(created_at) <= s.stat_date),
       s.total_users     = (SELECT COUNT(*) FROM users WHERE deleted_at IS NULL
                             AND DATE(created_at) <= s.stat_date),
       s.new_users       = (SELECT COUNT(*) FROM users WHERE deleted_at IS NULL
                             AND DATE(created_at) = s.stat_date),
       s.total_agents    = (SELECT COUNT(*) FROM agents WHERE deleted_at IS NULL
                             AND DATE(created_at) <= s.stat_date),
       s.active_agents   = (SELECT COUNT(*) FROM agents WHERE deleted_at IS NULL
                             AND status = 'active' AND DATE(created_at) <= s.stat_date),
       s.total_organizations = (SELECT COUNT(*) FROM organizations WHERE deleted_at IS NULL
                             AND DATE(created_at) <= s.stat_date),
       s.bookings        = (SELECT COUNT(*) FROM bookings WHERE deleted_at IS NULL
                             AND DATE(created_at) = s.stat_date),
       s.offers          = (SELECT COUNT(*) FROM offers WHERE deleted_at IS NULL
                             AND DATE(created_at) = s.stat_date);

-- 6. Daily active/new-listing counts on the organisation and agent rollups.
UPDATE organization_daily_stats s
   SET s.active_listings = (SELECT COUNT(*) FROM listings l
                             WHERE l.organization_id = s.organization_id
                               AND l.status = 'active' AND l.deleted_at IS NULL),
       s.new_listings    = (SELECT COUNT(*) FROM listings l
                             WHERE l.organization_id = s.organization_id
                               AND DATE(l.created_at) = s.stat_date AND l.deleted_at IS NULL);

UPDATE agent_daily_stats s
   SET s.active_listings = (SELECT COUNT(*) FROM listings l
                             WHERE l.agent_id = s.agent_id
                               AND l.status = 'active' AND l.deleted_at IS NULL);

-- 7. Response-time medians on the agent and organisation records, from the real
--    first_response_minutes on inquiries.
UPDATE agents a
  JOIN (SELECT assigned_to_agent_id AS agent_id,
               ROUND(AVG(first_response_minutes)) AS mins,
               ROUND(100.0 * SUM(first_response_at IS NOT NULL) / COUNT(*), 2) AS rate
          FROM inquiries
         WHERE assigned_to_agent_id IS NOT NULL AND is_spam = 0 AND deleted_at IS NULL
         GROUP BY assigned_to_agent_id) x ON x.agent_id = a.id
   SET a.response_time_minutes = x.mins,
       a.response_rate = x.rate;

UPDATE organizations o
  JOIN (SELECT organization_id, ROUND(AVG(first_response_minutes)) AS mins
          FROM inquiries
         WHERE organization_id IS NOT NULL AND first_response_minutes IS NOT NULL
           AND is_spam = 0 AND deleted_at IS NULL
         GROUP BY organization_id) x ON x.organization_id = o.id
   SET o.response_time_minutes = x.mins;

-- 8. Sitemap entries, built only from listings that actually resolve. The audit
--    found two 404 URLs published to crawlers; a listing is emitted here only if
--    it is indexable, active and has a canonical path.
TRUNCATE TABLE sitemap_entries;
INSERT INTO sitemap_entries
  (url_path, entity_type, entity_id, sitemap_group, priority, change_frequency,
   last_modified_at, last_verified_at, is_indexable)
-- Sourced from v_public_listings, not from `listings` with the visibility
-- conditions repeated. Repeating them is how a listing whose published_at is
-- still in the future ends up in a sitemap — one definition, used everywhere.
SELECT l.canonical_path, 'listing', l.id, c.code, 0.8, 'daily', l.updated_at, NOW(3), 1
  FROM v_public_listings l
  JOIN categories c ON c.id = l.root_category_id
 WHERE l.is_indexable = 1
   AND l.canonical_path IS NOT NULL AND l.canonical_path <> '';

INSERT INTO sitemap_entries
  (url_path, entity_type, entity_id, sitemap_group, priority, change_frequency,
   last_modified_at, last_verified_at, is_indexable)
SELECT CONCAT('/agents/', a.slug), 'agent', a.id, 'agents', 0.6, 'weekly', a.updated_at, NOW(3), 1
  FROM v_public_agents a;

INSERT INTO sitemap_entries
  (url_path, entity_type, entity_id, sitemap_group, priority, change_frequency,
   last_modified_at, last_verified_at, is_indexable)
SELECT CONCAT('/companies/', o.slug), 'organization', o.id, 'companies', 0.6, 'weekly',
       o.updated_at, NOW(3), 1
  FROM v_public_organizations o;

INSERT INTO sitemap_entries
  (url_path, entity_type, entity_id, sitemap_group, priority, change_frequency,
   last_modified_at, last_verified_at, is_indexable)
SELECT CONCAT('/magazine/', p.slug), 'post', p.id, 'magazine', 0.5, 'monthly',
       p.updated_at, NOW(3), 1
  FROM posts p WHERE p.status = 'published' AND p.deleted_at IS NULL AND p.is_indexable = 1;

-- Location landing pages, which are the organic-search surface for
-- "<category> in <community>" queries.
INSERT INTO sitemap_entries
  (url_path, entity_type, entity_id, sitemap_group, priority, change_frequency,
   last_modified_at, last_verified_at, is_indexable)
SELECT CONCAT('/real-estate/for-sale/', l.path), 'location', l.id, 'locations', 0.7, 'weekly',
       llp.updated_at, NOW(3), 1
  FROM location_landing_pages llp
  JOIN locations l ON l.id = llp.location_id
 WHERE llp.status = 'published' AND llp.is_indexable = 1;

-- 9. Job run history, so the admin System / Jobs view is not empty and job
--    freshness can be checked.
INSERT INTO job_runs (job_id, status, started_at, finished_at, duration_ms, rows_processed)
SELECT id, 'success',
       DATE_SUB(NOW(3), INTERVAL (id * 7) MINUTE),
       DATE_SUB(NOW(3), INTERVAL ((id * 7) - 1) MINUTE),
       FLOOR(400 + RAND(id) * 24000),
       FLOOR(RAND(id + 100) * 50000)
  FROM jobs;

UPDATE jobs j
  JOIN (SELECT job_id, MAX(started_at) AS last_run FROM job_runs GROUP BY job_id) r
    ON r.job_id = j.id
   SET j.last_status = 'success',
       j.last_run_at = r.last_run,
       j.next_run_at = DATE_ADD(r.last_run, INTERVAL 1 HOUR);

-- =============================================================================
-- ASSERTIONS
-- =============================================================================
-- Every query below must return 0. A non-zero result means the derived values
-- and their sources disagree — exactly the class of defect the audit found —
-- and the seed should not be trusted.

SELECT 'listing.inquiry_count vs inquiries table' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT l.id
          FROM listings l
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM inquiries
                      WHERE deleted_at IS NULL GROUP BY listing_id) i ON i.listing_id = l.id
         WHERE l.inquiry_count <> COALESCE(i.n, 0)) x;

SELECT 'listing.favourite_count vs favourites table' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT l.id
          FROM listings l
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM favourites GROUP BY listing_id) f
            ON f.listing_id = l.id
         WHERE l.favourite_count <> COALESCE(f.n, 0)) x;

SELECT 'agent.active_listing_count vs listings' AS assertion, COUNT(*) AS failures
  FROM (SELECT a.id FROM agents a
          LEFT JOIN (SELECT agent_id, COUNT(*) n FROM listings
                      WHERE status = 'active' AND deleted_at IS NULL GROUP BY agent_id) l
            ON l.agent_id = a.id
         WHERE a.active_listing_count <> COALESCE(l.n, 0)) x;

SELECT 'organization.agent_count vs agents' AS assertion, COUNT(*) AS failures
  FROM (SELECT o.id FROM organizations o
          LEFT JOIN (SELECT organization_id, COUNT(*) n FROM agents
                      WHERE status = 'active' AND deleted_at IS NULL GROUP BY organization_id) a
            ON a.organization_id = o.id
         WHERE o.agent_count <> COALESCE(a.n, 0)) x;

SELECT 'listing_search covers exactly the public listings' AS assertion,
       (SELECT COUNT(*) FROM v_public_listings) - (SELECT COUNT(*) FROM listing_search) AS failures;

SELECT 'ledger is balanced per transaction group' AS assertion, COUNT(*) AS failures
  FROM (SELECT transaction_group
          FROM ledger_entries
         GROUP BY transaction_group
        HAVING ABS(SUM(CASE WHEN entry_type = 'debit'  THEN amount_base ELSE 0 END)
                 - SUM(CASE WHEN entry_type = 'credit' THEN amount_base ELSE 0 END)) > 0.01) x;

SELECT 'every active listing has a resolvable canonical path' AS assertion, COUNT(*) AS failures
  FROM listings
 WHERE status = 'active' AND deleted_at IS NULL
   AND (canonical_path IS NULL OR canonical_path = '');

SELECT 'no active listing lacks contact channels' AS assertion, COUNT(*) AS failures
  FROM listings
 WHERE status = 'active' AND deleted_at IS NULL
   AND (contact_phone IS NULL OR contact_whatsapp IS NULL OR contact_email IS NULL);

SELECT 'every agent has a profile slug' AS assertion, COUNT(*) AS failures
  FROM agents WHERE slug IS NULL OR slug = '';

SELECT 'denormalised listing location chain matches locations' AS assertion, COUNT(*) AS failures
  FROM listings l JOIN locations loc ON loc.id = l.location_id
 WHERE l.deleted_at IS NULL
   AND (l.country_id <> loc.country_id
        OR NOT (l.city_id <=> loc.city_id));

SELECT 'listing_daily_stats.inquiries reconciles with the inquiries table' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT l.id
          FROM listings l
          LEFT JOIN (SELECT listing_id, SUM(inquiries) n FROM listing_daily_stats
                      GROUP BY listing_id) d ON d.listing_id = l.id
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM inquiries
                      WHERE deleted_at IS NULL GROUP BY listing_id) i ON i.listing_id = l.id
         WHERE COALESCE(d.n, 0) <> COALESCE(i.n, 0)) x;

SELECT 'sitemap contains no listing that is not publicly visible' AS assertion,
       COUNT(*) AS failures
  FROM sitemap_entries s
 WHERE s.entity_type = 'listing'
   AND s.entity_id NOT IN (SELECT id FROM v_public_listings);
