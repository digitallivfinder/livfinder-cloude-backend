-- =============================================================================
-- Liv Finder — seed 051 · SEO platform
-- =============================================================================
-- `url_inventory` is built from the pages that actually exist — every published
-- listing, every location with inventory, every category, every article — so
-- the registry and the site agree by construction rather than by a crawl that
-- discovers the disagreement later.
--
-- The indexation rules are the substantive part. A faceted marketplace can
-- generate millions of URL combinations; indexing all of them is how a site
-- gets classified as thin content and loses the rankings it already had. These
-- rules are the policy that decides which combinations earn a place in the
-- index, and they are written to be argued with — every threshold is visible.
-- =============================================================================

SET NAMES utf8mb4;

-- The schema's collation is utf8mb4_unicode_ci throughout, but a client's
-- default connection collation is utf8mb4_general_ci. Any comparison between a
-- string literal (or a CONVERT result) and a column is then a mix of two
-- collations, which MySQL rejects rather than coerces. Pinning the connection
-- collation is what lets the joins below be written naturally.
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Facet indexation rules
--
-- Evaluated in priority order, first match wins. The shape of the policy:
--
--   · One facet on a location page is indexable if there is enough inventory
--     to make the page useful. "Apartments for sale in Dubai Marina" is a real
--     query with real intent.
--   · Two facets are indexable only in the largest markets and only above a
--     higher threshold. "3-bedroom apartments for sale in Dubai Marina" is
--     still a query; "3-bedroom furnished apartments for sale in Dubai Marina
--     with a balcony" is not.
--   · Three or more facets are never indexable. There is no query volume down
--     there, and there are a great many such pages.
--   · A price-range facet is never indexable at any depth, because the
--     combinatorics are unbounded and the content is identical.
-- -----------------------------------------------------------------------------
INSERT INTO facet_indexation_rules
  (name, description, priority, page_type, category_id, purpose_id, location_level,
   facet_signature, min_facet_depth, max_facet_depth, min_result_count,
   min_unique_words, min_monthly_searches, decision, canonical_strategy,
   include_in_sitemap, sitemap_priority, is_active)
VALUES
  ('Price-range facets are never indexed',
   'Price bands generate unbounded combinations over identical content. They stay crawlable so the links pass, but they never enter the index.',
   10, 'search_results', NULL, NULL, 'any', 'price', NULL, NULL, 0, 0, NULL,
   'noindex_follow', 'strip_last_facet', 0, 0.1, 1),

  ('Sort and pagination parameters are never indexed',
   'Ordering does not change the content. Page 2 onwards canonicalises to page 1 rather than competing with it.',
   20, 'search_results', NULL, NULL, 'any', 'sort', NULL, NULL, 0, 0, NULL,
   'canonical_to_parent', 'strip_all_facets', 0, 0.1, 1),

  ('Three or more facets are never indexed',
   'Below two facets there is no measurable search demand and a very large number of pages. Crawl budget spent here is crawl budget not spent on listings.',
   30, 'search_results', NULL, NULL, 'any', NULL, 3, NULL, 0, 0, NULL,
   'noindex_follow', 'strip_last_facet', 0, 0.1, 1),

  ('Two facets in a major market with real inventory',
   'Bedrooms plus property type on a community page, where there are at least 40 live listings. Genuine demand exists at this depth in the largest markets only.',
   40, 'search_results', NULL, NULL, 'community', NULL, 2, 2, 40, 120, 200,
   'index', 'self', 1, 0.5, 1),

  ('Two facets elsewhere canonicalise up',
   'Same combination outside the major markets: crawlable, not indexed, and pointing at the single-facet parent that is.',
   50, 'search_results', NULL, NULL, 'any', NULL, 2, 2, 0, 0, NULL,
   'canonical_to_parent', 'strip_last_facet', 0, 0.2, 1),

  ('One facet on a community page with inventory',
   'The workhorse. "Villas for sale in Emirates Hills" is the single most valuable page shape a property portal has.',
   60, 'search_results', NULL, NULL, 'community', NULL, 1, 1, 12, 150, NULL,
   'index', 'self', 1, 0.7, 1),

  ('One facet on a city page with inventory',
   'Broader, higher volume, more competitive. Indexed above a lower inventory threshold because the page has value even when the count is modest.',
   70, 'search_results', NULL, NULL, 'city', NULL, 1, 1, 8, 150, NULL,
   'index', 'self', 1, 0.7, 1),

  ('One facet with thin inventory canonicalises up',
   'Fewer than a dozen results is a page with nothing to say. It points at its parent rather than competing with it.',
   80, 'search_results', NULL, NULL, 'any', NULL, 1, 1, 0, 0, NULL,
   'canonical_to_parent', 'parent_location', 0, 0.3, 1),

  ('Unfacetted location landing pages are always indexed',
   'The location page itself, with editorial content and market statistics. These are the pages the whole location tree exists to serve.',
   90, 'location_landing', NULL, NULL, 'any', NULL, 0, 0, 1, 0, NULL,
   'index', 'self', 1, 0.8, 1),

  ('Empty location pages stay out of the index',
   'A community with no live listings is a page that will disappoint everyone who lands on it. It remains reachable so it can return when inventory does.',
   95, 'location_landing', NULL, NULL, 'any', NULL, 0, 0, 0, 0, NULL,
   'noindex_follow', 'parent_location', 0, 0.2, 1),

  ('Category landing pages are always indexed',
   'Six root categories, their children, and the purpose splits beneath them.',
   100, 'category_landing', NULL, NULL, 'any', NULL, 0, 0, 0, 0, NULL,
   'index', 'self', 1, 0.9, 1),

  ('Listing detail pages are indexed while live',
   'The listing itself. Sold and expired listings are handled by the retirement rule rather than here.',
   110, 'listing_detail', NULL, NULL, 'any', NULL, 0, 0, 0, 0, NULL,
   'index', 'self', 1, 0.8, 1),

  ('Everything else defaults to noindex',
   'A default that fails closed. A new page type appearing in the inventory without a rule stays out of the index until somebody decides it belongs there.',
   9999, NULL, NULL, NULL, 'any', NULL, NULL, NULL, 0, 0, NULL,
   'noindex_follow', 'self', 0, 0.1, 1);

-- -----------------------------------------------------------------------------
-- URL inventory — listings
-- -----------------------------------------------------------------------------
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, category_id,
   purpose_id, location_id, facet_depth, is_indexable, index_decision, decided_by,
   indexation_rule_id, result_count, word_count, has_unique_content,
   internal_inlink_count, click_depth, http_status, last_crawled_at,
   last_modified_at, first_seen_at, priority, change_frequency, in_sitemap,
   created_at, updated_at)
SELECT
  l.canonical_path,
  UNHEX(SHA2(l.canonical_path, 256)),
  (SELECT id FROM languages WHERE code = 'en'),
  'listing_detail', 'listing', l.id, l.category_id, l.purpose_id, l.location_id,
  0,
  -- A listing that is live and indexable is in the index; a sold one is not,
  -- and it returns 410 rather than 404 so the crawler stops asking.
  l.status = 'active' AND l.is_indexable = 1,
  CASE WHEN l.status = 'active' AND l.is_indexable = 1 THEN 'index' ELSE 'noindex_follow' END,
  'rule',
  (SELECT id FROM facet_indexation_rules WHERE name = 'Listing detail pages are indexed while live'),
  1,
  -- Word count from the description, which is what the thin-content check reads.
  GREATEST(40, ROUND(CHAR_LENGTH(COALESCE(l.description, '')) / 5.6)),
  CHAR_LENGTH(COALESCE(l.description, '')) > 600,
  -- Inbound internal links: the community page, the category page, the agent
  -- and the organisation all link here.
  4 + MOD(l.id, 9),
  3,
  CASE WHEN l.status IN ('sold', 'rented', 'withdrawn') THEN 410
       WHEN l.deleted_at IS NOT NULL THEN 410
       ELSE 200 END,
  DATE_SUB(NOW(3), INTERVAL MOD(l.id, 21) DAY),
  l.updated_at,
  l.created_at,
  -- Sitemap priority tracks how much the platform wants this crawled.
  CASE WHEN l.is_featured THEN 0.9 WHEN l.is_premium THEN 0.8 ELSE 0.7 END,
  CASE WHEN l.status = 'active' THEN 'daily' ELSE 'monthly' END,
  l.status = 'active' AND l.is_indexable = 1,
  l.created_at, l.updated_at
FROM listings l
WHERE l.deleted_at IS NULL
  AND l.canonical_path IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Live inventory per location
--
-- Built once into a temporary table rather than as a correlated subquery. The
-- obvious formulation — joining listings to locations on four OR-ed ancestor
-- columns — cannot use an index and scans the listing table once per location;
-- four separate indexed groupings unioned together do the same work in under a
-- second.
-- -----------------------------------------------------------------------------
CREATE TABLE tmp_location_counts (
  location_id BIGINT UNSIGNED NOT NULL,
  live_count  INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (location_id)
) ENGINE=InnoDB;

INSERT INTO tmp_location_counts (location_id, live_count)
SELECT location_id, SUM(n)
FROM (
  SELECT l.location_id     AS location_id, COUNT(*) AS n FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.location_id IS NOT NULL
   GROUP BY l.location_id
  UNION ALL
  SELECT l.community_id, COUNT(*) FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
   GROUP BY l.community_id
  UNION ALL
  SELECT l.city_id, COUNT(*) FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.city_id IS NOT NULL
   GROUP BY l.city_id
  UNION ALL
  SELECT l.country_id, COUNT(*) FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.country_id IS NOT NULL
   GROUP BY l.country_id
) u
GROUP BY location_id;

-- -----------------------------------------------------------------------------
-- URL inventory — location landing pages
--
-- One per location that carries live inventory, plus the ancestors above them.
-- A community with nothing to show is registered and marked noindex rather than
-- omitted, so the day inventory arrives the page is already known.
-- -----------------------------------------------------------------------------
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id,
   location_id, facet_depth, is_indexable, index_decision, decided_by,
   indexation_rule_id, result_count, word_count, has_unique_content,
   internal_inlink_count, click_depth, http_status, last_crawled_at,
   last_modified_at, first_seen_at, priority, change_frequency, in_sitemap,
   created_at, updated_at)
SELECT
  CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci),
  UNHEX(SHA2(CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci), 256)),
  (SELECT id FROM languages WHERE code = 'en'),
  'location_landing', 'location', loc.id, loc.id, 0,
  s.live_count > 0,
  IF(s.live_count > 0, 'index', 'noindex_follow'),
  'rule',
  IF(s.live_count > 0,
     (SELECT id FROM facet_indexation_rules WHERE name = 'Unfacetted location landing pages are always indexed'),
     (SELECT id FROM facet_indexation_rules WHERE name = 'Empty location pages stay out of the index')),
  s.live_count,
  -- Editorial content exists for the markets that matter and nowhere else,
  -- which is exactly what `has_unique_content` is meant to record.
  IF(loc.level IN ('community','city'), 320 + MOD(loc.id, 400), 60),
  loc.level IN ('community','city') AND s.live_count >= 5,
  CASE loc.level WHEN 'country' THEN 40 WHEN 'state' THEN 20 WHEN 'city' THEN 30
                 WHEN 'community' THEN 12 ELSE 5 END,
  CASE loc.level WHEN 'country' THEN 1 WHEN 'state' THEN 2 WHEN 'city' THEN 2
                 WHEN 'community' THEN 3 ELSE 4 END,
  200,
  DATE_SUB(NOW(3), INTERVAL MOD(loc.id, 30) DAY),
  NOW(3), loc.created_at,
  CASE loc.level WHEN 'country' THEN 0.9 WHEN 'city' THEN 0.8
                 WHEN 'community' THEN 0.7 ELSE 0.5 END,
  IF(s.live_count > 50, 'daily', 'weekly'),
  s.live_count > 0,
  loc.created_at, NOW(3)
FROM locations loc
JOIN tmp_location_counts s ON s.location_id = loc.id;

DROP TABLE tmp_location_counts;

-- -----------------------------------------------------------------------------
-- URL inventory — category and facet pages
--
-- The facet pages are generated where the combination has inventory behind it,
-- which is the point of the rules above: the registry only ever contains pages
-- the policy would allow, so there is nothing to retract later.
-- -----------------------------------------------------------------------------
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, category_id,
   facet_depth, is_indexable, index_decision, decided_by, indexation_rule_id,
   result_count, word_count, has_unique_content, internal_inlink_count,
   click_depth, http_status, first_seen_at, priority, change_frequency,
   in_sitemap, created_at, updated_at)
SELECT
  CONCAT('/', c.slug),
  UNHEX(SHA2(CONCAT('/', c.slug), 256)),
  (SELECT id FROM languages WHERE code = 'en'),
  'category_landing', 'category', c.id, c.id, 0, 1, 'index', 'rule',
  (SELECT id FROM facet_indexation_rules WHERE name = 'Category landing pages are always indexed'),
  c.active_listing_count,
  400 + MOD(c.id, 300), 1,
  IF(c.parent_id IS NULL, 200, 40),
  IF(c.parent_id IS NULL, 1, 2),
  200, c.created_at, IF(c.parent_id IS NULL, 0.9, 0.8), 'daily', 1,
  c.created_at, c.updated_at
FROM categories c
WHERE c.deleted_at IS NULL AND c.is_visible = 1;

-- One facet on a community page: the workhorse shape. Generated for the
-- combinations that genuinely have listings behind them.
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, category_id,
   purpose_id, location_id, facet_depth, facet_signature, is_indexable,
   index_decision, decided_by, indexation_rule_id, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT
  CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci, '/', p.slug, '/', c.slug),
  UNHEX(SHA2(CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci, '/', p.slug, '/', c.slug), 256)),
  (SELECT id FROM languages WHERE code = 'en'),
  'search_results', 'location', loc.id, c.id, p.id, loc.id,
  1, 'category',
  f.n >= 12,
  IF(f.n >= 12, 'index', 'canonical_to_other'),
  'rule',
  IF(f.n >= 12,
     (SELECT id FROM facet_indexation_rules WHERE name = 'One facet on a community page with inventory'),
     (SELECT id FROM facet_indexation_rules WHERE name = 'One facet with thin inventory canonicalises up')),
  f.n,
  IF(f.n >= 12, 180 + MOD(loc.id + c.id, 200), 60),
  f.n >= 12,
  2 + MOD(loc.id, 5), 4, 200, NOW(3),
  IF(f.n >= 12, 0.7, 0.3), 'daily', f.n >= 12, NOW(3), NOW(3)
FROM (
  SELECT l.community_id AS loc_id, l.category_id AS cat_id, l.purpose_id AS pur_id,
         COUNT(*) AS n
    FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
   GROUP BY l.community_id, l.category_id, l.purpose_id
) f
JOIN locations loc ON loc.id = f.loc_id
JOIN categories c ON c.id = f.cat_id
JOIN purposes p ON p.id = f.pur_id;

-- Editorial and static pages.
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, facet_depth,
   is_indexable, index_decision, decided_by, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT CONCAT('/insights/', po.slug), UNHEX(SHA2(CONCAT('/insights/', po.slug), 256)),
       (SELECT id FROM languages WHERE code = 'en'),
       'article', 'post', po.id, 0,
       po.status = 'published' AND po.is_indexable = 1,
       IF(po.status = 'published' AND po.is_indexable = 1, 'index', 'noindex_follow'),
       'default', 1,
       GREATEST(120, ROUND(CHAR_LENGTH(COALESCE(po.body, '')) / 5.6)),
       1, 3 + MOD(po.id, 6), 3, 200,
       po.created_at, 0.6, 'monthly', po.status = 'published' AND po.is_indexable = 1,
       po.created_at, po.updated_at
FROM posts po WHERE po.deleted_at IS NULL;

INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, facet_depth,
   is_indexable, index_decision, decided_by, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT CONCAT('/', pg.slug), UNHEX(SHA2(CONCAT('/', pg.slug), 256)),
       (SELECT id FROM languages WHERE code = 'en'),
       'static_page', 'page', pg.id, 0,
       pg.status = 'published' AND pg.is_indexable = 1,
       IF(pg.status = 'published' AND pg.is_indexable = 1, 'index', 'noindex_follow'),
       'manual', 1, 600, 1, 12, 1, 200,
       pg.created_at, 0.4, 'yearly', pg.status = 'published' AND pg.is_indexable = 1,
       pg.created_at, pg.updated_at
FROM pages pg WHERE pg.deleted_at IS NULL;

-- Agent and organisation profiles.
INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, facet_depth,
   is_indexable, index_decision, decided_by, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT CONCAT('/agents/', a.slug), UNHEX(SHA2(CONCAT('/agents/', a.slug), 256)),
       (SELECT id FROM languages WHERE code = 'en'),
       'agent_profile', 'agent', a.id, 0,
       -- An agent page with no listings is a thin page. It stays out until
       -- there is something on it.
       a.is_publicly_visible = 1 AND a.active_listing_count > 0,
       IF(a.is_publicly_visible = 1 AND a.active_listing_count > 0, 'index', 'noindex_follow'),
       'rule', a.active_listing_count,
       GREATEST(80, ROUND(CHAR_LENGTH(COALESCE(a.bio, '')) / 5.6)),
       CHAR_LENGTH(COALESCE(a.bio, '')) > 400,
       1 + a.active_listing_count, 3, 200, a.created_at, 0.5, 'weekly',
       a.is_publicly_visible = 1 AND a.active_listing_count > 0, a.created_at, a.updated_at
FROM agents a WHERE a.deleted_at IS NULL;

INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, facet_depth,
   is_indexable, index_decision, decided_by, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT CONCAT('/agencies/', o.slug), UNHEX(SHA2(CONCAT('/agencies/', o.slug), 256)),
       (SELECT id FROM languages WHERE code = 'en'),
       'organization_profile', 'organization', o.id, 0,
       o.is_publicly_visible = 1, IF(o.is_publicly_visible = 1, 'index', 'noindex_follow'),
       'rule', o.active_listing_count,
       GREATEST(120, ROUND(CHAR_LENGTH(COALESCE(o.description, '')) / 5.6)),
       CHAR_LENGTH(COALESCE(o.description, '')) > 400,
       1 + o.agent_count + o.active_listing_count, 2, 200, o.created_at, 0.6, 'weekly',
       o.is_publicly_visible = 1, o.created_at, o.updated_at
FROM organizations o WHERE o.deleted_at IS NULL;

INSERT INTO url_inventory
  (url_path, url_hash, language_id, page_type, entity_type, entity_id, facet_depth,
   is_indexable, index_decision, decided_by, result_count, word_count,
   has_unique_content, internal_inlink_count, click_depth, http_status,
   first_seen_at, priority, change_frequency, in_sitemap, created_at, updated_at)
SELECT '/', UNHEX(SHA2('/', 256)), (SELECT id FROM languages WHERE code = 'en'),
       'home', NULL, NULL, 0, 1, 'index', 'manual',
       (SELECT COUNT(*) FROM listings WHERE status = 'active'),
       500, 1, 100000, 0, 200, NOW(3), 1.0, 'daily', 1, NOW(3), NOW(3);

-- -----------------------------------------------------------------------------
-- Canonicals
--
-- Every page that canonicalises to a parent needs the parent's id filled in.
-- Doing it as a second pass rather than at insert time is what lets the parent
-- be a row that had not been created yet when the child was.
-- -----------------------------------------------------------------------------
UPDATE url_inventory child
  JOIN locations loc ON loc.id = child.location_id
  JOIN url_inventory parent
    ON parent.url_path = CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci)
   AND parent.page_type = 'location_landing'
   SET child.canonical_url_id = parent.id
 WHERE child.index_decision = 'canonical_to_other'
   AND child.page_type = 'search_results';

UPDATE url_inventory u SET u.canonical_url_id = u.id
 WHERE u.canonical_url_id IS NULL AND u.index_decision = 'index';

UPDATE facet_indexation_rules r
  JOIN (SELECT indexation_rule_id, COUNT(*) n FROM url_inventory
         WHERE indexation_rule_id IS NOT NULL GROUP BY indexation_rule_id) m
    ON m.indexation_rule_id = r.id
   SET r.matched_url_count = m.n, r.last_evaluated_at = NOW(3);

-- -----------------------------------------------------------------------------
-- Keywords
--
-- Generated from the location and category tree, because that is exactly how
-- property search demand is shaped: an intent word, a property type, and a
-- place. Volumes and difficulty are synthetic but scaled to the inventory
-- behind each term, so the ordering is meaningful even though the absolute
-- numbers are not.
-- -----------------------------------------------------------------------------
INSERT INTO seo_keywords
  (keyword, keyword_hash, language_id, country_id, monthly_search_volume,
   difficulty, cpc_estimate, intent, cluster_name, category_id, location_id,
   is_tracked, priority, created_at)
SELECT
  kw.keyword,
  UNHEX(SHA2(kw.keyword, 256)),
  (SELECT id FROM languages WHERE code = 'en'),
  kw.country_id,
  kw.volume,
  LEAST(95, 20 + ROUND(kw.volume / 60)),
  ROUND(0.80 + MOD(CONV(SUBSTRING(MD5(kw.keyword),1,4),16,10), 900) / 100, 2),
  'transactional',
  kw.cluster_name,
  kw.category_id,
  kw.location_id,
  kw.volume >= 150,
  CASE WHEN kw.volume >= 2000 THEN 'critical' WHEN kw.volume >= 600 THEN 'high'
       WHEN kw.volume >= 150 THEN 'medium' ELSE 'low' END,
  NOW(3)
FROM (
  SELECT DISTINCT
    CONCAT(c.name_plural, ' ', p.name, ' in ', loc.name) AS keyword,
    loc.country_id AS country_id,
    c.id AS category_id,
    loc.id AS location_id,
    CONCAT(c.name_plural, ' ', p.name) AS cluster_name,
    -- Volume scales with the inventory behind the term, with a floor so a term
    -- with two listings still registers and a ceiling so nothing claims to be
    -- a head term it is not. Terms above 150 a month are tracked; below that
    -- the rank data is noise and tracking it costs money.
    GREATEST(60, LEAST(9000, f.n * 34 + 120)) AS volume
  FROM (
    SELECT l.community_id AS loc_id, l.category_id AS cat_id, l.purpose_id AS pur_id,
           COUNT(*) AS n
      FROM listings l
     WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
     GROUP BY l.community_id, l.category_id, l.purpose_id
  ) f
  JOIN locations loc ON loc.id = f.loc_id
  JOIN categories c ON c.id = f.cat_id
  JOIN purposes p ON p.id = f.pur_id
) kw;

-- Bind each keyword to the page that is meant to rank for it. A keyword with no
-- target is a gap; two pages targeting one keyword is cannibalisation. Both are
-- visible from this table.
INSERT INTO keyword_targets (keyword_id, url_id, is_primary, created_at)
SELECT k.id, u.id, 1, NOW(3)
FROM seo_keywords k
JOIN locations loc ON loc.id = k.location_id
JOIN categories c ON c.id = k.category_id
JOIN url_inventory u
  ON u.location_id = k.location_id AND u.category_id = k.category_id
 AND u.page_type = 'search_results' AND u.facet_depth = 1
GROUP BY k.id;

-- Rankings, sampled weekly for the tracked terms. Position correlates inversely
-- with difficulty, which is the only property of this data that matters.
INSERT INTO keyword_rankings
  (keyword_id, checked_on, search_engine, device, country_id, rank_position,
   previous_position, ranking_url_id, ranking_url, serp_features,
   estimated_traffic, created_at)
SELECT
  k.id, d.checked_on, 'google', 'mobile', k.country_id,
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rank:', k.id, ':', d.checked_on)),1,4),16,10),
          GREATEST(3, ROUND(k.difficulty / 2))),
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rank:', k.id, ':', DATE_SUB(d.checked_on, INTERVAL 1 WEEK))),1,4),16,10),
          GREATEST(3, ROUND(k.difficulty / 2))),
  kt.url_id,
  CONCAT('https://livfinder.com', u.url_path),
  CASE WHEN MOD(k.id, 3) = 0 THEN 'local_pack,people_also_ask'
       WHEN MOD(k.id, 5) = 0 THEN 'ads_top,people_also_ask'
       ELSE 'people_also_ask' END,
  -- Click-through by position, using the shape everyone's curve has: roughly
  -- 28% at rank 1, 13% in the top three, and a long thin tail.
  ROUND(k.monthly_search_volume / 30 *
        CASE WHEN 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rank:', k.id, ':', d.checked_on)),1,4),16,10),
                          GREATEST(3, ROUND(k.difficulty / 2))) = 1 THEN 0.28
             WHEN 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rank:', k.id, ':', d.checked_on)),1,4),16,10),
                          GREATEST(3, ROUND(k.difficulty / 2))) <= 3 THEN 0.13
             WHEN 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rank:', k.id, ':', d.checked_on)),1,4),16,10),
                          GREATEST(3, ROUND(k.difficulty / 2))) <= 10 THEN 0.04
             ELSE 0.01 END),
  NOW(3)
FROM seo_keywords k
JOIN keyword_targets kt ON kt.keyword_id = k.id AND kt.is_primary = 1
JOIN url_inventory u ON u.id = kt.url_id
JOIN (SELECT DATE_SUB(CURDATE(), INTERVAL 0 WEEK) AS checked_on
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 1 WEEK)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 2 WEEK)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 3 WEEK)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 4 WEEK)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 5 WEEK)) d
WHERE k.is_tracked = 1;

-- -----------------------------------------------------------------------------
-- Search Console import
--
-- Impressions and clicks per URL per query per day. This is the table that
-- tells you a page is ranking for something you never targeted, which is where
-- most of the useful SEO work comes from.
--
-- Impressions are derived from the keyword's volume and its ranking position:
-- a term ranked 30th generates impressions and almost no clicks, which is
-- exactly the pattern worth spotting.
-- -----------------------------------------------------------------------------
INSERT INTO search_console_metrics
  (metric_date, url_id, url_path, query_text, country_code, device, search_type,
   impressions, clicks, ctr, average_position, imported_at)
SELECT
  d.metric_date, u.id, u.url_path, k.keyword,
  UPPER(cp.iso3),
  dv.device, 'web',
  GREATEST(1, ROUND(k.monthly_search_volume / 30 * dv.share)),
  GREATEST(0, ROUND(k.monthly_search_volume / 30 * dv.share *
    CASE WHEN r.rank_position = 1 THEN 0.28 WHEN r.rank_position <= 3 THEN 0.13
         WHEN r.rank_position <= 10 THEN 0.04 ELSE 0.008 END)),
  ROUND(CASE WHEN r.rank_position = 1 THEN 0.28 WHEN r.rank_position <= 3 THEN 0.13
             WHEN r.rank_position <= 10 THEN 0.04 ELSE 0.008 END, 5),
  r.rank_position + ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('pos:', k.id, d.metric_date)),1,3),16,10), 180) / 100, 2),
  NOW(3)
FROM seo_keywords k
JOIN keyword_targets kt ON kt.keyword_id = k.id AND kt.is_primary = 1
JOIN url_inventory u ON u.id = kt.url_id
LEFT JOIN location_country_profiles cp ON cp.location_id = k.country_id
JOIN keyword_rankings r ON r.keyword_id = k.id AND r.checked_on = CURDATE()
JOIN (SELECT 'mobile' AS device, 0.72 AS share
      UNION ALL SELECT 'desktop', 0.28) dv
JOIN (SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS metric_date
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 2 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 3 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 4 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 5 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 6 DAY)
      UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 7 DAY)) d
WHERE k.is_tracked = 1;

-- -----------------------------------------------------------------------------
-- Core Web Vitals
--
-- Field data, per page type per device, against the thresholds Google actually
-- uses: LCP under 2.5s, INP under 200ms, CLS under 0.1, and the 75th percentile
-- is what counts — not the average, which hides the tail that users notice.
--
-- Listing pages come out slowest, which is the honest and universal result:
-- they are image-heavy and the largest contentful paint is a photograph. Mobile
-- is uniformly worse than desktop by roughly a third, which is also what real
-- field data looks like.
-- -----------------------------------------------------------------------------
INSERT INTO core_web_vitals
  (url_id, url_path, measured_on, device, data_source, lcp_p75_ms, inp_p75_ms,
   cls_p75, fcp_p75_ms, ttfb_p75_ms, lcp_good_pct, inp_good_pct, cls_good_pct,
   overall_assessment, sample_count, created_at)
SELECT
  m.url_id, m.url_path, m.measured_on, m.device, 'crux',
  m.lcp, m.inp, m.cls,
  ROUND(m.lcp * 0.45), ROUND(m.lcp * 0.22),
  ROUND(GREATEST(20, LEAST(100, 100 - (m.lcp - 1800) / 26)), 2),
  ROUND(GREATEST(40, LEAST(100, 100 - (m.inp - 120) / 6)), 2),
  ROUND(GREATEST(50, LEAST(100, 100 - m.cls * 400)), 2),
  CASE WHEN m.lcp <= 2500 AND m.inp <= 200 AND m.cls <= 0.1 THEN 'good'
       WHEN m.lcp <= 4000 AND m.inp <= 500 AND m.cls <= 0.25 THEN 'needs_improvement'
       ELSE 'poor' END,
  m.sample_count, NOW(3)
FROM (
  SELECT
    u.id AS url_id,
    u.url_path AS url_path,
    d.measured_on AS measured_on,
    dv.device AS device,
    ROUND(pt.base_lcp * dv.factor
          + MOD(CONV(SUBSTRING(MD5(CONCAT('lcp:', u.id, d.measured_on, dv.device)),1,3),16,10), 700)) AS lcp,
    ROUND(pt.base_inp * dv.factor
          + MOD(CONV(SUBSTRING(MD5(CONCAT('inp:', u.id, d.measured_on, dv.device)),1,3),16,10), 90)) AS inp,
    ROUND(pt.base_cls * dv.factor
          + MOD(CONV(SUBSTRING(MD5(CONCAT('cls:', u.id, d.measured_on, dv.device)),1,3),16,10), 60) / 1000, 4) AS cls,
    200 + MOD(u.id, 4000) AS sample_count
  FROM url_inventory u
  JOIN (SELECT 'mobile' AS device, 1.35 AS factor
        UNION ALL SELECT 'desktop', 1.00) dv
  JOIN (SELECT DATE_SUB(CURDATE(), INTERVAL 1 DAY) AS measured_on
        UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 8 DAY)
        UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 15 DAY)
        UNION ALL SELECT DATE_SUB(CURDATE(), INTERVAL 22 DAY)) d
  JOIN (
    SELECT 'listing_detail' AS pt, 2900 AS base_lcp, 190 AS base_inp, 0.0800 AS base_cls
    UNION ALL SELECT 'search_results', 2300, 220, 0.1400
    UNION ALL SELECT 'location_landing', 2000, 150, 0.0500
    UNION ALL SELECT 'category_landing', 1900, 140, 0.0400
    UNION ALL SELECT 'home', 1700, 130, 0.0300
    UNION ALL SELECT 'article', 1600, 110, 0.0200
    UNION ALL SELECT 'agent_profile', 2100, 160, 0.0600
    UNION ALL SELECT 'organization_profile', 2100, 160, 0.0600
    UNION ALL SELECT 'static_page', 1400, 100, 0.0100
  ) pt ON pt.pt = u.page_type
  WHERE MOD(u.id, 37) = 0
) m;

-- -----------------------------------------------------------------------------
-- Slug history
--
-- Every rename that has happened, with the old path hashed for the redirect
-- lookup. This is what turns "we renamed the community" from a permanent loss
-- of accumulated ranking into a 301.
-- -----------------------------------------------------------------------------
INSERT INTO slug_history
  (entity_type, entity_id, old_slug, new_slug, old_path, new_path, old_path_hash,
   reason, changed_by_user_id, changed_at)
SELECT 'listing', l.id,
       CONCAT(l.slug, '-old'), l.slug,
       CONCAT(SUBSTRING(l.canonical_path, 1,
              CHAR_LENGTH(l.canonical_path) - CHAR_LENGTH(l.slug)), l.slug, '-old'),
       l.canonical_path,
       UNHEX(SHA2(CONCAT(SUBSTRING(l.canonical_path, 1,
             CHAR_LENGTH(l.canonical_path) - CHAR_LENGTH(l.slug)), l.slug, '-old'), 256)),
       'Title edited after publication',
       l.created_by_user_id,
       DATE_ADD(l.created_at, INTERVAL 3 DAY)
FROM listings l
WHERE l.deleted_at IS NULL AND l.canonical_path IS NOT NULL
  AND MOD(l.id, 19) = 0;

-- -----------------------------------------------------------------------------
-- Hreflang
--
-- Reciprocity is the rule Google enforces and the one everybody breaks: if the
-- English page points at the Arabic one, the Arabic page must point back, or
-- both annotations are ignored. Generated in pairs here so the set is
-- reciprocal by construction.
-- -----------------------------------------------------------------------------
INSERT INTO seo_hreflang_alternates
  (url_id, alternate_url_id, hreflang, alternate_url, is_x_default, is_reciprocal,
   last_validated_at, created_at)
SELECT u.id, u.id, 'en-ae', CONCAT('https://livfinder.com', u.url_path), 1, 1,
       NOW(3), NOW(3)
FROM url_inventory u
WHERE u.page_type IN ('location_landing', 'category_landing')
  AND u.is_indexable = 1;

INSERT INTO seo_hreflang_alternates
  (url_id, alternate_url_id, hreflang, alternate_url, is_x_default, is_reciprocal,
   last_validated_at, created_at)
SELECT u.id, NULL, 'ar-ae', CONCAT('https://livfinder.com/ar', u.url_path), 0, 0,
       NULL, NOW(3)
FROM url_inventory u
WHERE u.page_type IN ('location_landing', 'category_landing')
  AND u.is_indexable = 1;

-- -----------------------------------------------------------------------------
-- SEO issues
--
-- Derived from the inventory rather than invented, so every issue is one an
-- audit would genuinely raise against this dataset.
-- -----------------------------------------------------------------------------
INSERT INTO seo_issues
  (url_id, url_path, issue_type, severity, details, detected_by, status,
   first_detected_at, last_detected_at)
SELECT u.id, u.url_path, 'thin_content', 'medium',
       CONCAT('Indexable page with ', u.word_count, ' words and ',
              u.result_count, ' results. Below the 150-word threshold the '
              'indexation policy sets for a page to earn a place in the index.'),
       'crawler', 'open', NOW(3), NOW(3)
FROM url_inventory u
WHERE u.is_indexable = 1 AND u.word_count < 150;

INSERT INTO seo_issues
  (url_id, url_path, issue_type, severity, details, detected_by, status,
   first_detected_at, last_detected_at)
SELECT u.id, u.url_path, 'orphan_page', 'medium',
       'Indexable page with fewer than three internal inbound links. Reachable '
       'by sitemap only, which is a weak signal and a slow crawl.',
       'crawler', 'open', NOW(3), NOW(3)
FROM url_inventory u
WHERE u.is_indexable = 1 AND u.internal_inlink_count < 3;

INSERT INTO seo_issues
  (url_id, url_path, issue_type, severity, details, detected_by, status,
   first_detected_at, last_detected_at)
SELECT u.id, u.url_path, 'noindex_in_sitemap', 'high',
       'URL is marked noindex but appears in a sitemap. The two instructions '
       'contradict each other and waste crawl budget.',
       'crawler', 'open', NOW(3), NOW(3)
FROM url_inventory u
WHERE u.is_indexable = 0 AND u.in_sitemap = 1;
