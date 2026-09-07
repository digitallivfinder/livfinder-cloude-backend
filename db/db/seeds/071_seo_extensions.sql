-- =============================================================================
-- 071_seo_extensions.sql
--
-- The rest of the SEO platform: per-URL metadata and the templates that produce
-- it, structured data, the internal link graph, backlinks, crawl auditing,
-- robots policy, sitemap files and their submissions, content quality scoring
-- and near-duplicate detection.
--
-- The through-line is that indexation is a decision the platform makes
-- deliberately and can explain, rather than something that happens to it. A
-- portal with a million facet combinations either governs its own index or has
-- its crawl budget spent for it.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- Metadata templates
--
-- Patterns, not strings. A million location pages cannot be written by hand, so
-- the title is generated from a pattern and only overridden where an editor has
-- something better to say -- which seo_meta records explicitly, so a bulk
-- regeneration never silently overwrites an editorial decision.
-- -----------------------------------------------------------------------------
INSERT INTO seo_meta_templates
  (code, name, entity_type, page_type, category_id, purpose_id, location_level,
   language_id, title_pattern, description_pattern, h1_pattern,
   og_title_pattern, og_description_pattern, max_title_length,
   max_description_length, title_suffix, priority, is_active)
SELECT
  t.code, t.name, t.entity_type, t.page_type, c.id, p.id,
  COALESCE(t.location_level, 'any'), 1,
  t.title_pattern, t.description_pattern, t.h1_pattern,
  COALESCE(t.og_title_pattern, t.title_pattern),
  COALESCE(t.og_description_pattern, t.description_pattern),
  60, 155, ' | Liv Finder', t.priority, 1
FROM (
  SELECT 'listing_re_sale' AS code, 'Real estate listing — for sale' AS name, 'listing' AS entity_type, 'listing_detail' AS page_type, 'real-estate' AS category_code, 'sale' AS purpose_code, NULL AS location_level,
         '{bedrooms} Bedroom {property_type} for Sale in {community}, {city}' AS title_pattern,
         '{bedrooms} bedroom {property_type} for sale in {community}, {city}. {area} {area_unit}, {price}. View photos, floor plans and arrange a viewing with {agency}.' AS description_pattern,
         '{bedrooms} Bedroom {property_type} in {community}' AS h1_pattern,
         NULL AS og_title_pattern, NULL AS og_description_pattern, 10 AS priority
  UNION ALL SELECT 'listing_re_rent','Real estate listing — to rent','listing','listing_detail','real-estate','rent',NULL,
         '{bedrooms} Bedroom {property_type} for Rent in {community}, {city}',
         '{bedrooms} bedroom {property_type} available to rent in {community}, {city} at {price} per year. {area} {area_unit}. Enquire through Liv Finder.',
         '{bedrooms} Bedroom {property_type} to Rent in {community}', NULL, NULL, 10
  UNION ALL SELECT 'listing_car','Car listing','listing','listing_detail','cars',NULL,NULL,
         '{year} {make} {model} for Sale in {city}',
         '{year} {make} {model} for sale in {city}. {mileage} km, {transmission}, {exterior_colour}. {price}. Full specification and history on Liv Finder.',
         '{year} {make} {model}', NULL, NULL, 10
  UNION ALL SELECT 'listing_yacht','Yacht listing','listing','listing_detail','yachts',NULL,NULL,
         '{year} {make} {model} — {length} Motor Yacht for Sale',
         '{length} {make} {model} built {year}, lying {city}. {cabins} cabins, {guests} guests. {price}. Full specification and brokerage details.',
         '{year} {make} {model}', NULL, NULL, 10
  UNION ALL SELECT 'listing_jet','Aircraft listing','listing','listing_detail','jets',NULL,NULL,
         '{year} {make} {model} for Sale — {total_time} Hours',
         '{year} {make} {model} private jet for sale. {total_time} total time, {seats} seats, {range} nm range. {price}. Full status and inspection history.',
         '{year} {make} {model}', NULL, NULL, 10
  UNION ALL SELECT 'listing_watch','Watch listing','listing','listing_detail','watches',NULL,NULL,
         '{make} {model} {reference} — {year}',
         '{make} {model}, reference {reference}, {year}. {condition} with {box_papers}. {price}. Authenticated and available through Liv Finder.',
         '{make} {model} {reference}', NULL, NULL, 10
  UNION ALL SELECT 'location_city_sale','Location landing — city, for sale','location','location_landing','real-estate','sale','city',
         'Property for Sale in {city} — {result_count} Listings',
         'Browse {result_count} properties for sale in {city}. Prices from {min_price}. Apartments, villas and townhouses from verified agencies.',
         'Property for Sale in {city}', NULL, NULL, 20
  UNION ALL SELECT 'location_community_sale','Location landing — community, for sale','location','location_landing','real-estate','sale','community',
         'Property for Sale in {community}, {city}',
         '{result_count} properties for sale in {community}, {city}. Median price {median_price}. Transaction history, service charges and available units.',
         'Property for Sale in {community}', NULL, NULL, 15
  UNION ALL SELECT 'location_community_rent','Location landing — community, to rent','location','location_landing','real-estate','rent','community',
         'Property to Rent in {community}, {city}',
         '{result_count} properties to rent in {community}, {city}. Median rent {median_rent} per year. Available now from verified agencies.',
         'Property to Rent in {community}', NULL, NULL, 15
  UNION ALL SELECT 'category_landing','Category landing','category','category_landing',NULL,NULL,'any',
         '{category} for Sale — {result_count} Listings Worldwide',
         'Browse {result_count} {category} listings from verified sellers worldwide. Filter by price, location and specification.',
         '{category} for Sale', NULL, NULL, 30
  UNION ALL SELECT 'agent_profile','Agent profile','agent','agent_profile',NULL,NULL,NULL,
         '{agent_name} — {agency} — {city}',
         '{agent_name} at {agency}, specialising in {specialisation} in {city}. {listing_count} current listings. Contact directly through Liv Finder.',
         '{agent_name}', NULL, NULL, 25
  UNION ALL SELECT 'organization_profile','Agency profile','organization','organization_profile',NULL,NULL,NULL,
         '{organization} — {listing_count} Listings — {city}',
         '{organization} in {city}. {listing_count} current listings, {agent_count} agents. Reviews, contact details and available inventory.',
         '{organization}', NULL, NULL, 25
  UNION ALL SELECT 'project_detail','Project detail','project','project_detail',NULL,NULL,NULL,
         '{project} by {developer} — {city}',
         '{project}, a {developer} development in {location}. Handover {handover_date}. Payment plans, floor plans, availability and pricing.',
         '{project}', NULL, NULL, 20
  UNION ALL SELECT 'building_detail','Building detail','building','other',NULL,NULL,'any',
         '{building}, {community} — Prices, Units and Transactions',
         'Everything about {building} in {community}: available units, service charges, transaction history and price per square foot.',
         '{building}', NULL, NULL, 20
  UNION ALL SELECT 'article','Editorial article','post','article',NULL,NULL,NULL,
         '{title}',
         '{excerpt}',
         '{title}', NULL, NULL, 40
) AS t
LEFT JOIN categories c ON c.code = t.category_code AND c.parent_id IS NULL
LEFT JOIN purposes p ON p.code = t.purpose_code;

-- -----------------------------------------------------------------------------
-- Per-URL metadata
--
-- Generated from the template for everything, then overridden by an editor on
-- the pages that earn the attention. The distinction is recorded rather than
-- inferred, because a regeneration must not silently discard editorial work.
-- -----------------------------------------------------------------------------
INSERT INTO seo_meta
  (url_id, entity_type, entity_id, language_id, meta_title, meta_description,
   canonical_url, robots_index, robots_follow, robots_archive, robots_snippet,
   robots_image_index, max_snippet, max_image_preview, max_video_preview,
   og_title, og_description, og_type, og_image_url, og_image_width,
   og_image_height, og_image_alt, og_locale, og_site_name, twitter_card,
   twitter_title, twitter_description, twitter_image_url, twitter_site,
   is_auto_generated, generated_from_template_id, overridden_by_user_id,
   overridden_at, created_at, updated_at)
SELECT
  u.id,
  -- Metadata attaches to the URL, not to the entity behind it: one listing has
  -- a canonical page, a print page and a page per language, and they do not
  -- share a title. url_inventory resolves the URL back to its entity.
  'url', u.id, 1,
  LEFT(m.title, 255),
  LEFT(m.description, 500),
  CONCAT('https://www.livfinder.com', COALESCE(canon.url_path, u.url_path)),
  u.is_indexable, 1, 1, 1, 1,
  -1, 'large', -1,
  LEFT(m.title, 255),
  LEFT(m.description, 500),
  CASE u.page_type WHEN 'article' THEN 'article'
                   WHEN 'listing_detail' THEN 'product'
                   ELSE 'website' END,
  CONCAT('https://cdn.livfinder.com/og/', LEFT(MD5(CONCAT('og:', u.id)), 16), '.jpg'),
  1200, 630, LEFT(m.title, 255), 'en_GB', 'Liv Finder',
  'summary_large_image',
  LEFT(m.title, 255),
  LEFT(m.description, 500),
  CONCAT('https://cdn.livfinder.com/og/', LEFT(MD5(CONCAT('og:', u.id)), 16), '.jpg'),
  '@livfinder',
  m.is_auto, tmpl.id,
  CASE WHEN m.is_auto = 0 THEN 1 END,
  CASE WHEN m.is_auto = 0 THEN DATE_SUB(@now, INTERVAL MOD(u.id, 200) DAY) END,
  u.created_at, @now
FROM url_inventory u
LEFT JOIN url_inventory canon ON canon.id = u.canonical_url_id
LEFT JOIN seo_meta_templates tmpl
  ON tmpl.page_type = u.page_type
 AND tmpl.id = (SELECT MIN(t2.id) FROM seo_meta_templates t2 WHERE t2.page_type = u.page_type)
JOIN (
  SELECT u2.id AS url_id,
         CONCAT(
           CASE u2.page_type
             WHEN 'home'                  THEN 'Luxury Property, Cars, Yachts and Jets for Sale'
             WHEN 'listing_detail'        THEN 'Property for Sale'
             WHEN 'location_landing'      THEN 'Property for Sale'
             WHEN 'category_landing'      THEN 'Listings'
             WHEN 'agent_profile'         THEN 'Agent Profile'
             WHEN 'organization_profile'  THEN 'Agency Profile'
             WHEN 'project_detail'        THEN 'New Development'
             WHEN 'article'               THEN 'Market Insight'
             ELSE 'Liv Finder'
           END,
           ' — ',
           SUBSTRING_INDEX(TRIM(BOTH '/' FROM u2.url_path), '/', -1),
           ' | Liv Finder') AS title,
         CONCAT('Browse verified listings on Liv Finder. ',
                COALESCE(CONCAT(u2.result_count, ' results. '), ''),
                'Prices, photographs, floor plans and direct contact with the listing agent.') AS description,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('override:', u2.id)), 1, 4), 16, 10), 12) = 0
              THEN 0 ELSE 1 END AS is_auto
  FROM url_inventory u2
) AS m ON m.url_id = u.id;

-- -----------------------------------------------------------------------------
-- Structured data
--
-- Templates producing instances, with a validation status on each. An invalid
-- payload is a rich result that quietly disappeared; recording the errors is
-- how it gets noticed before the traffic does.
-- -----------------------------------------------------------------------------
INSERT INTO structured_data_templates
  (code, name, schema_type, entity_type, page_type, category_id, template_json,
   required_fields, is_active, priority)
SELECT
  t.code, t.name, t.schema_type, t.entity_type, t.page_type, c.id,
  t.template_json, t.required_fields, 1, t.priority
FROM (
  SELECT 'listing_realestate' AS code, 'Real estate listing' AS name, 'RealEstateListing' AS schema_type, 'listing' AS entity_type, 'listing_detail' AS page_type, 'real-estate' AS category_code,
         '{"@context":"https://schema.org","@type":"RealEstateListing","name":"{title}","url":"{canonical_url}","datePosted":"{published_at}","image":"{cover_image_url}","offers":{"@type":"Offer","price":"{price}","priceCurrency":"{currency_code}","availability":"https://schema.org/InStock"},"address":{"@type":"PostalAddress","addressLocality":"{city}","addressCountry":"{country_code}"},"geo":{"@type":"GeoCoordinates","latitude":"{latitude}","longitude":"{longitude}"},"numberOfRooms":"{bedrooms}","floorSize":{"@type":"QuantitativeValue","value":"{area}","unitCode":"MTK"}}' AS template_json,
         '["title","canonical_url","price","currency_code","city"]' AS required_fields, 10 AS priority
  UNION ALL SELECT 'listing_car','Car listing','Car','listing','listing_detail','cars',
         '{"@context":"https://schema.org","@type":"Car","name":"{title}","brand":{"@type":"Brand","name":"{make}"},"model":"{model}","vehicleModelDate":"{year}","mileageFromOdometer":{"@type":"QuantitativeValue","value":"{mileage}","unitCode":"KMT"},"offers":{"@type":"Offer","price":"{price}","priceCurrency":"{currency_code}"}}',
         '["title","make","model","price"]', 10
  UNION ALL SELECT 'listing_boat','Yacht listing','Boat','listing','listing_detail','yachts',
         '{"@context":"https://schema.org","@type":"Product","additionalType":"https://schema.org/Boat","name":"{title}","brand":{"@type":"Brand","name":"{make}"},"offers":{"@type":"Offer","price":"{price}","priceCurrency":"{currency_code}"}}',
         '["title","price"]', 10
  UNION ALL SELECT 'breadcrumbs','Breadcrumb trail','BreadcrumbList','url','other',NULL,
         '{"@context":"https://schema.org","@type":"BreadcrumbList","itemListElement":"{breadcrumb_items}"}',
         '["breadcrumb_items"]', 20
  UNION ALL SELECT 'search_results','Search results item list','ItemList','url','search_results',NULL,
         '{"@context":"https://schema.org","@type":"ItemList","numberOfItems":"{result_count}","itemListElement":"{items}"}',
         '["result_count"]', 30
  UNION ALL SELECT 'agency','Agency profile','RealEstateAgent','organization','organization_profile',NULL,
         '{"@context":"https://schema.org","@type":"RealEstateAgent","name":"{organization}","url":"{canonical_url}","telephone":"{phone}","address":{"@type":"PostalAddress","addressLocality":"{city}"},"aggregateRating":{"@type":"AggregateRating","ratingValue":"{rating_avg}","reviewCount":"{review_count}"}}',
         '["organization","canonical_url"]', 20
  UNION ALL SELECT 'agent','Agent profile','Person','agent','agent_profile',NULL,
         '{"@context":"https://schema.org","@type":"Person","name":"{agent_name}","jobTitle":"Property Consultant","worksFor":{"@type":"Organization","name":"{organization}"},"url":"{canonical_url}"}',
         '["agent_name","canonical_url"]', 20
  UNION ALL SELECT 'article','Editorial article','Article','post','article',NULL,
         '{"@context":"https://schema.org","@type":"Article","headline":"{title}","datePublished":"{published_at}","dateModified":"{updated_at}","author":{"@type":"Person","name":"{author}"},"image":"{cover_image_url}"}',
         '["title","published_at"]', 20
  UNION ALL SELECT 'faq','FAQ block','FAQPage','url','faq',NULL,
         '{"@context":"https://schema.org","@type":"FAQPage","mainEntity":"{questions}"}',
         '["questions"]', 40
  UNION ALL SELECT 'website','Site-wide search action','WebSite','site','home',NULL,
         '{"@context":"https://schema.org","@type":"WebSite","name":"Liv Finder","url":"https://www.livfinder.com","potentialAction":{"@type":"SearchAction","target":"https://www.livfinder.com/search?q={search_term_string}","query-input":"required name=search_term_string"}}',
         '[]', 50
) AS t
LEFT JOIN categories c ON c.code = t.category_code AND c.parent_id IS NULL;

INSERT INTO structured_data_instances
  (url_id, entity_type, entity_id, template_id, schema_type, language_id,
   payload, validation_status, validation_errors, validated_at, generated_at)
SELECT
  -- As with seo_meta, a structured-data payload belongs to the URL that emits
  -- it: the same listing carries different markup on its own page and inside a
  -- results list.
  u.id, 'url', u.id, t.id,
  t.schema_type, 1,
  JSON_OBJECT(
    '@context', 'https://schema.org',
    '@type', t.schema_type,
    'url', CONCAT('https://www.livfinder.com', u.url_path),
    'name', SUBSTRING_INDEX(TRIM(BOTH '/' FROM u.url_path), '/', -1)
  ),
  v.status,
  CASE WHEN v.status <> 'valid' THEN v.errors END,
  DATE_SUB(@now, INTERVAL MOD(u.id, 30) DAY),
  u.created_at
FROM url_inventory u
JOIN structured_data_templates t
  ON (t.page_type = u.page_type AND t.category_id IS NULL)
   OR t.code = 'breadcrumbs'
JOIN (
  SELECT u2.id AS url_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sdval:', u2.id)), 1, 4), 16, 10), 12),
             'valid','valid','valid','valid','valid','valid','valid','valid','valid',
             'warnings','warnings','errors') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sdval:', u2.id)), 1, 4), 16, 10), 12),
             NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             '["Missing recommended field: aggregateRating"]',
             '["Missing recommended field: image"]',
             '["Required field priceCurrency is absent from Offer","Value for price is not a number"]') AS errors
  FROM url_inventory u2
) AS v ON v.url_id = u.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hassd:', u.id)), 1, 4), 16, 10), 3) = 0;

-- -----------------------------------------------------------------------------
-- Internal links
--
-- The link graph is the mechanism by which a deep community page is discovered
-- at all. Storing it makes click depth and orphan pages computable rather than
-- guessable.
-- -----------------------------------------------------------------------------
INSERT INTO internal_links
  (from_url_id, to_url_id, anchor_text, link_context, is_nofollow,
   link_position, first_seen_at, last_seen_at)
SELECT
  f.id, t.id,
  SUBSTRING_INDEX(TRIM(BOTH '/' FROM t.url_path), '/', -1),
  l.link_context, l.is_nofollow, l.position,
  DATE_SUB(@now, INTERVAL 200 DAY), @now
FROM url_inventory f
JOIN url_inventory t
  ON t.id <> f.id
 AND t.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('link:', f.id, ':', 0)), 1, 6), 16, 10),
                    (SELECT COUNT(*) FROM url_inventory))
JOIN (
  SELECT 'navigation' AS link_context, 0 AS is_nofollow, 1 AS position
  UNION ALL SELECT 'footer',    0, 2
  UNION ALL SELECT 'related',   0, 3
  UNION ALL SELECT 'body',      0, 4
  UNION ALL SELECT 'card',      0, 5
) AS l;

INSERT INTO internal_links
  (from_url_id, to_url_id, anchor_text, link_context, is_nofollow,
   link_position, first_seen_at, last_seen_at)
SELECT
  f.id, t.id,
  SUBSTRING_INDEX(TRIM(BOTH '/' FROM t.url_path), '/', -1),
  'breadcrumb', 0, 0,
  DATE_SUB(@now, INTERVAL 200 DAY), @now
FROM url_inventory f
JOIN url_inventory t ON t.id = f.canonical_url_id AND t.id <> f.id;

UPDATE url_inventory u
LEFT JOIN (SELECT to_url_id, COUNT(*) n FROM internal_links GROUP BY to_url_id) l
  ON l.to_url_id = u.id
SET u.internal_inlink_count = COALESCE(l.n, 0);

-- -----------------------------------------------------------------------------
-- Backlinks
--
-- Third-party links, including the toxic ones. is_disavowed is what turns a
-- negative-SEO complaint into a documented action rather than an assertion.
-- -----------------------------------------------------------------------------
INSERT INTO backlinks
  (source_domain, source_url, source_url_hash, target_url_id, target_url,
   anchor_text, link_type, domain_rating, page_rating, estimated_traffic,
   is_toxic, is_disavowed, first_seen_at, last_seen_at, lost_at, source, created_at)
SELECT
  d.domain,
  CONCAT('https://', d.domain, '/', d.slug, '/', LEFT(MD5(CONCAT('bl:', u.id, d.domain)), 10)),
  UNHEX(SHA2(CONCAT('https://', d.domain, '/', d.slug, '/', LEFT(MD5(CONCAT('bl:', u.id, d.domain)), 10)), 256)),
  u.id,
  CONCAT('https://www.livfinder.com', u.url_path),
  d.anchor,
  d.link_type, d.domain_rating,
  GREATEST(1, d.domain_rating - MOD(CONV(SUBSTRING(MD5(CONCAT('pr:', u.id, d.domain)), 1, 4), 16, 10), 30)),
  MOD(CONV(SUBSTRING(MD5(CONCAT('tr:', u.id, d.domain)), 1, 5), 16, 10), 9000),
  d.is_toxic, d.is_toxic,
  DATE_SUB(@today, INTERVAL 200 + MOD(CONV(SUBSTRING(MD5(CONCAT('bfs:', u.id, d.domain)), 1, 4), 16, 10), 900) DAY),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('blost:', u.id, d.domain)), 1, 4), 16, 10), 9) = 0
       THEN DATE_SUB(@today, INTERVAL 40 DAY) ELSE @today END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('blost:', u.id, d.domain)), 1, 4), 16, 10), 9) = 0
       THEN DATE_SUB(@today, INTERVAL 40 DAY) END,
  'ahrefs', @now
FROM url_inventory u
JOIN (
  SELECT 'ft.com' AS domain, 'house-home' AS slug, 'Dubai luxury market' AS anchor, 'follow' AS link_type, 91 AS domain_rating, 0 AS is_toxic, 0 AS slot
  UNION ALL SELECT 'cnbc.com',           'realestate',   'global property portal',   'follow',   93, 0, 1
  UNION ALL SELECT 'architecturaldigest.com','stories',  'Liv Finder',                'follow',   88, 0, 2
  UNION ALL SELECT 'robbreport.com',     'shelter',      'this waterfront villa',     'follow',   82, 0, 3
  UNION ALL SELECT 'boatinternational.com','yachts',     'superyachts for sale',      'follow',   76, 0, 4
  UNION ALL SELECT 'reddit.com',         'r/dubai',      'here',                      'ugc',      91, 0, 5
  UNION ALL SELECT 'medium.com',         'p',            'property search',           'nofollow', 84, 0, 6
  UNION ALL SELECT 'expat-forum.example','threads',      'listings site',             'follow',   34, 0, 7
  UNION ALL SELECT 'seo-directory.example','listings',   'buy property dubai cheap',  'follow',    4, 1, 8
  UNION ALL SELECT 'link-farm.example',  'out',          'click here best property',  'follow',    2, 1, 9
  UNION ALL SELECT 'partner-agency.example','partners',  'Liv Finder',                'sponsored',41, 0, 10
  UNION ALL SELECT 'linkedin.com',       'pulse',        'market report',             'nofollow', 98, 0, 11
) AS d
  ON d.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('bldom:', u.id)), 1, 4), 16, 10), 12)
   OR d.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('bldom2:', u.id)), 1, 4), 16, 10), 12)
WHERE u.is_indexable = 1
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasbl:', u.id)), 1, 4), 16, 10), 3) = 0;

-- -----------------------------------------------------------------------------
-- Crawl auditing
-- -----------------------------------------------------------------------------
INSERT INTO crawl_sessions
  (crawler, started_at, finished_at, urls_crawled, urls_ok, urls_redirect,
   urls_client_error, urls_server_error, issues_found, status, config)
SELECT
  s.crawler,
  DATE_SUB(@now, INTERVAL s.days_ago DAY),
  CASE WHEN s.status <> 'running'
       THEN DATE_ADD(DATE_SUB(@now, INTERVAL s.days_ago DAY), INTERVAL s.minutes MINUTE) END,
  s.crawled, s.ok, s.redirect, s.client_error, s.server_error, s.issues, s.status,
  JSON_OBJECT('max_depth', 6, 'respect_robots', TRUE, 'concurrency', 8,
              'user_agent', CONCAT('LivFinderAudit/2.1 (+https://www.livfinder.com/bot)'))
FROM (
  SELECT 'internal_audit' AS crawler, 1 AS days_ago, 84 AS minutes, 'completed' AS status,
         1550 AS crawled, 1421 AS ok, 96 AS redirect, 28 AS client_error, 5 AS server_error, 214 AS issues
  UNION ALL SELECT 'internal_audit', 8,  91, 'completed', 1512, 1388, 92, 27, 5, 231
  UNION ALL SELECT 'internal_audit', 15, 88, 'completed', 1477, 1350, 90, 32, 5, 258
  UNION ALL SELECT 'internal_audit', 22, 96, 'completed', 1440, 1300, 94, 41, 5, 287
  UNION ALL SELECT 'internal_audit', 29,  6, 'failed',     140,  128,  8,  4, 0,  12
  UNION ALL SELECT 'screaming_frog', 3,  47, 'completed',  800,  742, 41, 15, 2,  96
  UNION ALL SELECT 'ahrefs',         5, 210, 'completed', 1550, 1430, 90, 25, 5, 180
  UNION ALL SELECT 'semrush',        6, 195, 'completed', 1550, 1425, 92, 28, 5, 192
  UNION ALL SELECT 'internal_audit', 0,  22, 'running',    380,  349, 22,  8, 1,  44
) AS s;

INSERT INTO crawl_results
  (crawl_session_id, url_id, url_path, http_status, redirect_target,
   redirect_chain_length, response_time_ms, content_length_bytes, title,
   meta_description, h1_text, h1_count, word_count, canonical_url,
   is_self_canonical, robots_directives, internal_link_count,
   external_link_count, image_count, images_missing_alt, structured_data_types,
   crawled_at)
SELECT
  cs.id, u.id, u.url_path,
  r.http_status,
  CASE WHEN r.http_status = 301
       THEN CONCAT('https://www.livfinder.com', COALESCE(canon.url_path, '/')) END,
  CASE WHEN r.http_status = 301 THEN 1 ELSE 0 END,
  r.response_ms,
  40000 + MOD(CONV(SUBSTRING(MD5(CONCAT('clen:', u.id)), 1, 5), 16, 10), 180000),
  LEFT(sm.meta_title, 500), LEFT(sm.meta_description, 1000),
  SUBSTRING_INDEX(TRIM(BOTH '/' FROM u.url_path), '/', -1),
  1,
  COALESCE(u.word_count, 120 + MOD(u.id, 900)),
  sm.canonical_url,
  CASE WHEN u.canonical_url_id IS NULL OR u.canonical_url_id = u.id THEN 1 ELSE 0 END,
  CASE WHEN u.is_indexable = 1 THEN 'index,follow' ELSE 'noindex,follow' END,
  COALESCE(u.internal_inlink_count, 0),
  MOD(CONV(SUBSTRING(MD5(CONCAT('ext:', u.id)), 1, 4), 16, 10), 14),
  MOD(CONV(SUBSTRING(MD5(CONCAT('img:', u.id)), 1, 4), 16, 10), 40),
  MOD(CONV(SUBSTRING(MD5(CONCAT('noalt:', u.id)), 1, 4), 16, 10), 5),
  'RealEstateListing,BreadcrumbList',
  cs.started_at
FROM crawl_sessions cs
JOIN url_inventory u
  ON MOD(CONV(SUBSTRING(MD5(CONCAT('crawlpick:', cs.id, ':', u.id)), 1, 4), 16, 10), 5) = 0
LEFT JOIN url_inventory canon ON canon.id = u.canonical_url_id
LEFT JOIN seo_meta sm ON sm.url_id = u.id
JOIN (
  SELECT u2.id AS url_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('status:', u2.id)), 1, 4), 16, 10), 20),
             200,200,200,200,200,200,200,200,200,200,
             200,200,200,200,200,200,301,301,404,500) AS http_status,
         120 + MOD(CONV(SUBSTRING(MD5(CONCAT('rt:', u2.id)), 1, 4), 16, 10), 1400) AS response_ms
  FROM url_inventory u2
) AS r ON r.url_id = u.id
WHERE cs.crawler = 'internal_audit' AND cs.status = 'completed';

INSERT INTO crawl_budget_daily
  (stat_date, crawler, page_type, request_count, unique_urls, bytes_served,
   avg_response_ms, status_2xx, status_3xx, status_4xx, status_5xx,
   wasted_requests)
SELECT
  DATE_SUB(@today, INTERVAL d.n DAY),
  c.crawler,
  pt.page_type,
  v.requests,
  ROUND(v.requests * 0.62),
  v.requests * 92000,
  180 + MOD(CONV(SUBSTRING(MD5(CONCAT('cbrt:', c.crawler, pt.page_type, d.n)), 1, 4), 16, 10), 900),
  ROUND(v.requests * 0.91),
  ROUND(v.requests * 0.05),
  ROUND(v.requests * 0.03),
  ROUND(v.requests * 0.01),
  -- Requests spent on URLs the platform did not want indexed. The number this
  -- table exists to make visible.
  ROUND(v.requests * CASE WHEN pt.page_type = 'search_results' THEN 0.62 ELSE 0.08 END)
FROM (SELECT n FROM tmp_n WHERE n < 30) AS d
CROSS JOIN (
  SELECT 'googlebot' AS crawler, 1.00 AS share
  UNION ALL SELECT 'bingbot', 0.34
  UNION ALL SELECT 'yandexbot', 0.11
  UNION ALL SELECT 'ahrefs', 0.08
) AS c
CROSS JOIN (
  SELECT 'listing_detail' AS page_type, 0.44 AS weight
  UNION ALL SELECT 'location_landing', 0.21
  UNION ALL SELECT 'search_results', 0.18
  UNION ALL SELECT 'category_landing', 0.07
  UNION ALL SELECT 'agent_profile', 0.05
  UNION ALL SELECT 'article', 0.05
) AS pt
JOIN (
  SELECT c2.crawler, pt2.page_type, d2.n AS days_ago,
         GREATEST(10, ROUND(9000 * c2.share * pt2.weight
           * (0.85 + MOD(CONV(SUBSTRING(MD5(CONCAT('cb:', c2.crawler, pt2.page_type, d2.n)), 1, 4), 16, 10), 31) / 100))) AS requests
  FROM (SELECT 'googlebot' AS crawler, 1.00 AS share UNION ALL SELECT 'bingbot', 0.34
        UNION ALL SELECT 'yandexbot', 0.11 UNION ALL SELECT 'ahrefs', 0.08) c2
  CROSS JOIN (SELECT 'listing_detail' AS page_type, 0.44 AS weight
              UNION ALL SELECT 'location_landing', 0.21 UNION ALL SELECT 'search_results', 0.18
              UNION ALL SELECT 'category_landing', 0.07 UNION ALL SELECT 'agent_profile', 0.05
              UNION ALL SELECT 'article', 0.05) pt2
  CROSS JOIN (SELECT n FROM tmp_n WHERE n < 30) d2
) AS v ON v.crawler = c.crawler AND v.page_type = pt.page_type AND v.days_ago = d.n;

-- -----------------------------------------------------------------------------
-- Robots policy
--
-- Every rule carries the reason it exists, because a disallow nobody can
-- explain is a disallow nobody dares remove.
-- -----------------------------------------------------------------------------
INSERT INTO robots_rules
  (user_agent, directive, path_pattern, reason, sort_order, is_active, created_at)
VALUES
  ('*', 'disallow', '/search', 'Faceted search produces near-infinite URL combinations with no unique content. Landing pages carry the indexable version.', 10, 1, NOW(3)),
  ('*', 'disallow', '/*?sort=', 'Sort order is a presentation choice, not a distinct page.', 11, 1, NOW(3)),
  ('*', 'disallow', '/*?page=', 'Pagination beyond page one is handled by the sitemap, not by crawl.', 12, 1, NOW(3)),
  ('*', 'disallow', '/*?utm_', 'Campaign parameters create duplicate URLs for the same page.', 13, 1, NOW(3)),
  ('*', 'disallow', '/account', 'Authenticated area. Nothing here is public and nothing here should be crawled.', 20, 1, NOW(3)),
  ('*', 'disallow', '/agent-portal', 'Agent-only tooling behind authentication.', 21, 1, NOW(3)),
  ('*', 'disallow', '/api/', 'The API is versioned and documented; the crawler has no business in it.', 22, 1, NOW(3)),
  ('*', 'disallow', '/checkout', 'Transactional flow. Crawling it wastes budget and can create phantom sessions.', 23, 1, NOW(3)),
  ('*', 'allow', '/search/saved-collections', 'Curated collections are editorial pages that happen to live under the search path.', 30, 1, NOW(3)),
  ('*', 'allow', '/_next/static/', 'Static assets must be fetchable or the rendered page is judged on a broken layout.', 31, 1, NOW(3)),
  ('*', 'sitemap', 'https://www.livfinder.com/sitemap.xml', 'Sitemap index for every locale and content type.', 1, 1, NOW(3)),
  ('*', 'clean_param', 'ref&utm_source&utm_medium&utm_campaign&gclid&fbclid', 'Parameter stripping for the crawlers that support it.', 40, 1, NOW(3)),
  ('GPTBot', 'disallow', '/', 'Editorial and listing content is not licensed for model training. Reviewed quarterly with legal.', 50, 1, NOW(3)),
  ('CCBot', 'disallow', '/', 'Same position as GPTBot.', 51, 1, NOW(3)),
  ('SemrushBot', 'crawl_delay', '10', 'Third-party auditors were consuming meaningful origin capacity at peak.', 60, 1, NOW(3)),
  ('AhrefsBot', 'crawl_delay', '10', 'As above.', 61, 1, NOW(3)),
  ('MJ12bot', 'disallow', '/', 'No commercial relationship and a persistent crawl rate. Blocked outright.', 62, 1, NOW(3));

-- -----------------------------------------------------------------------------
-- Sitemaps
--
-- Split into files because the fifty-thousand-URL limit is real, and submitted
-- per file so a rejection identifies which slice was wrong.
-- -----------------------------------------------------------------------------
INSERT INTO sitemap_files
  (sitemap_group, file_index, file_path, url_count, file_size_bytes,
   language_id, sitemap_type, status, generated_at, last_modified_at,
   last_fetched_by_google_at, created_at, updated_at)
SELECT
  g.sitemap_group, g.file_index, g.file_path, g.url_count,
  g.url_count * 320, g.language_id, g.sitemap_type, g.status,
  DATE_SUB(@now, INTERVAL g.hours_ago HOUR),
  DATE_SUB(@now, INTERVAL g.hours_ago HOUR),
  DATE_SUB(@now, INTERVAL g.hours_ago - 2 HOUR),
  DATE_SUB(@now, INTERVAL 400 DAY), @now
FROM (
  SELECT 'index' AS sitemap_group, 0 AS file_index, '/sitemap.xml' AS file_path, 14 AS url_count, 1 AS language_id, 'index' AS sitemap_type, 'ready' AS status, 3 AS hours_ago
  UNION ALL SELECT 'listings',  1, '/sitemaps/listings-1.xml',   50000, 1, 'urlset', 'ready', 4
  UNION ALL SELECT 'listings',  2, '/sitemaps/listings-2.xml',   50000, 1, 'urlset', 'ready', 4
  UNION ALL SELECT 'listings',  3, '/sitemaps/listings-3.xml',   18422, 1, 'urlset', 'ready', 4
  UNION ALL SELECT 'locations', 1, '/sitemaps/locations-1.xml',  41280, 1, 'urlset', 'ready', 12
  UNION ALL SELECT 'projects',  1, '/sitemaps/projects-1.xml',    2410, 1, 'urlset', 'ready', 24
  UNION ALL SELECT 'agents',    1, '/sitemaps/agents-1.xml',      9180, 1, 'urlset', 'ready', 24
  UNION ALL SELECT 'agencies',  1, '/sitemaps/agencies-1.xml',    1240, 1, 'urlset', 'ready', 24
  UNION ALL SELECT 'editorial', 1, '/sitemaps/editorial-1.xml',    860, 1, 'urlset', 'ready', 6
  UNION ALL SELECT 'buildings', 1, '/sitemaps/buildings-1.xml',  12800, 1, 'urlset', 'stale', 90
  UNION ALL SELECT 'images',    1, '/sitemaps/images-1.xml',      50000, 1, 'image',  'ready', 8
  UNION ALL SELECT 'images',    2, '/sitemaps/images-2.xml',      33900, 1, 'image',  'ready', 8
  UNION ALL SELECT 'videos',    1, '/sitemaps/videos-1.xml',       4120, 1, 'video',  'ready', 8
  UNION ALL SELECT 'listings-ar', 1, '/sitemaps/ar/listings-1.xml', 50000, 2, 'urlset', 'ready', 5
  UNION ALL SELECT 'listings-fr', 1, '/sitemaps/fr/listings-1.xml', 22400, 3, 'urlset', 'building', 1
) AS g;

INSERT INTO sitemap_submissions
  (sitemap_file_id, search_engine, submission_type, target_url, status,
   response_code, response_body, urls_submitted, urls_indexed, submitted_at,
   created_at)
SELECT
  f.id, e.search_engine, 'sitemap',
  CONCAT('https://www.livfinder.com', f.file_path),
  CASE WHEN f.status = 'building' THEN 'pending'
       WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('sub:', f.id, e.search_engine)), 1, 4), 16, 10), 18) = 0 THEN 'failed'
       ELSE 'accepted' END,
  CASE WHEN f.status = 'building' THEN NULL
       WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('sub:', f.id, e.search_engine)), 1, 4), 16, 10), 18) = 0 THEN 429
       ELSE 200 END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('sub:', f.id, e.search_engine)), 1, 4), 16, 10), 18) = 0
       THEN 'Quota exceeded for this property. Retry after the daily reset.' END,
  f.url_count,
  -- Submitted is not indexed, and the gap is the whole subject of the SEO
  -- programme. Roughly two thirds is a healthy portal.
  ROUND(f.url_count * (0.52 + MOD(CONV(SUBSTRING(MD5(CONCAT('idx:', f.id, e.search_engine)), 1, 4), 16, 10), 34) / 100)),
  DATE_SUB(@now, INTERVAL 2 HOUR), DATE_SUB(@now, INTERVAL 2 HOUR)
FROM sitemap_files f
JOIN (
  SELECT 'google' AS search_engine UNION ALL SELECT 'bing' UNION ALL SELECT 'yandex'
) AS e;

INSERT INTO sitemap_submissions
  (sitemap_file_id, search_engine, submission_type, target_url, status,
   response_code, urls_submitted, urls_indexed, submitted_at, created_at)
SELECT
  NULL, 'bing', 'indexnow',
  CONCAT('https://www.livfinder.com', u.url_path),
  'accepted', 200, 1, 1,
  DATE_SUB(@now, INTERVAL MOD(u.id, 300) MINUTE),
  DATE_SUB(@now, INTERVAL MOD(u.id, 300) MINUTE)
FROM url_inventory u
WHERE u.is_indexable = 1
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('indexnow:', u.id)), 1, 4), 16, 10), 8) = 0;

-- -----------------------------------------------------------------------------
-- Content quality and duplication
--
-- Thin and near-duplicate pages are the two things that cost a large portal its
-- crawl budget. Scoring them per URL is what makes the noindex decision
-- defensible instead of arbitrary.
-- -----------------------------------------------------------------------------
INSERT INTO content_quality_scores
  (url_id, scored_on, word_count, unique_word_count, boilerplate_ratio,
   readability_score, quality_score, has_unique_intro, has_faq, has_images,
   has_structured_data, internal_links_out, result_count, is_thin, computed_at)
SELECT
  u.id, DATE_SUB(@today, INTERVAL d.n * 7 DAY),
  w.words,
  ROUND(w.words * 0.42),
  ROUND(w.boilerplate, 4),
  ROUND(48 + MOD(CONV(SUBSTRING(MD5(CONCAT('read:', u.id)), 1, 4), 16, 10), 34), 2),
  w.quality,
  CASE WHEN w.words > 260 THEN 1 ELSE 0 END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('faq:', u.id)), 1, 4), 16, 10), 4) = 0 THEN 1 ELSE 0 END,
  1,
  CASE WHEN EXISTS (SELECT 1 FROM structured_data_instances s WHERE s.url_id = u.id) THEN 1 ELSE 0 END,
  MOD(CONV(SUBSTRING(MD5(CONCAT('lo:', u.id)), 1, 4), 16, 10), 40),
  u.result_count,
  -- Thin is a compound judgement, not a word count: a page with few words but a
  -- hundred results is a legitimate index; a page with few words and no results
  -- is nothing.
  CASE WHEN w.words < 160 AND COALESCE(u.result_count, 0) < 4 THEN 1 ELSE 0 END,
  @now
FROM url_inventory u
JOIN (SELECT n FROM tmp_n WHERE n < 4) AS d
JOIN (
  SELECT u2.id AS url_id,
         80 + MOD(CONV(SUBSTRING(MD5(CONCAT('words:', u2.id)), 1, 5), 16, 10), 1400) AS words,
         (0.28 + MOD(CONV(SUBSTRING(MD5(CONCAT('boiler:', u2.id)), 1, 4), 16, 10), 45) / 100) AS boilerplate,
         20 + MOD(CONV(SUBSTRING(MD5(CONCAT('qual:', u2.id)), 1, 4), 16, 10), 78) AS quality
  FROM url_inventory u2
) AS w ON w.url_id = u.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hascq:', u.id)), 1, 4), 16, 10), 3) = 0;

INSERT INTO content_duplicate_clusters
  (canonical_url_id, similarity_threshold, member_count, status, detected_at,
   resolved_at)
SELECT
  u.id, 0.9200, 0, c.status,
  DATE_SUB(@now, INTERVAL c.days_ago DAY),
  CASE WHEN c.status IN ('canonicalised', 'rewritten', 'ignored')
       THEN DATE_SUB(@now, INTERVAL c.days_ago - 4 DAY) END
FROM url_inventory u
JOIN (
  SELECT u2.id AS url_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dupstat:', u2.id)), 1, 4), 16, 10), 5),
             'canonicalised','canonicalised','rewritten','ignored','open') AS status,
         10 + MOD(CONV(SUBSTRING(MD5(CONCAT('dupage:', u2.id)), 1, 4), 16, 10), 180) AS days_ago
  FROM url_inventory u2
) AS c ON c.url_id = u.id
WHERE u.page_type IN ('location_landing', 'category_landing')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasdup:', u.id)), 1, 4), 16, 10), 4) = 0;

INSERT INTO content_duplicate_members (cluster_id, url_id, similarity, added_at)
SELECT
  cl.id, m.id,
  ROUND(0.92 + MOD(CONV(SUBSTRING(MD5(CONCAT('sim:', cl.id, m.id)), 1, 4), 16, 10), 8) / 100, 4),
  cl.detected_at
FROM content_duplicate_clusters cl
JOIN url_inventory m
  ON m.id <> cl.canonical_url_id
 AND m.page_type IN ('location_landing', 'category_landing')
 AND MOD(CONV(SUBSTRING(MD5(CONCAT('dupmem:', cl.id, ':', m.id)), 1, 5), 16, 10), 120) = 0;

-- The canonical page is a member of its own cluster, at a similarity of one.
INSERT INTO content_duplicate_members (cluster_id, url_id, similarity, added_at)
SELECT cl.id, cl.canonical_url_id, 1.0000, cl.detected_at
FROM content_duplicate_clusters cl;

UPDATE content_duplicate_clusters cl
JOIN (SELECT cluster_id, COUNT(*) n FROM content_duplicate_members GROUP BY cluster_id) m
  ON m.cluster_id = cl.id
SET cl.member_count = m.n;

-- Clusters that turned out to have only the canonical page in them are not
-- duplicates at all.
DELETE FROM content_duplicate_members
 WHERE cluster_id IN (SELECT id FROM content_duplicate_clusters WHERE member_count < 2);
DELETE FROM content_duplicate_clusters WHERE member_count < 2;

-- -----------------------------------------------------------------------------
-- SEO experiments
--
-- Split by URL rather than by visitor, because the thing under test is what the
-- crawler sees. Which means the unit of assignment is the page, the metric comes
-- from search console, and the minimum duration is measured in weeks.
-- -----------------------------------------------------------------------------
INSERT INTO seo_experiments
  (name, hypothesis, experiment_type, scope_page_type, scope_category_id,
   status, started_at, ended_at, minimum_duration_days, primary_metric,
   result_summary, confidence_level, created_at, updated_at)
SELECT
  e.name, e.hypothesis, e.experiment_type, e.scope_page_type, c.id, e.status,
  DATE_SUB(@now, INTERVAL e.started_days_ago DAY),
  CASE WHEN e.status IN ('concluded', 'abandoned')
       THEN DATE_SUB(@now, INTERVAL e.started_days_ago - e.ran_days DAY) END,
  e.minimum_duration_days, e.primary_metric,
  CASE WHEN e.status = 'concluded' THEN e.result_summary END,
  CASE WHEN e.status = 'concluded' THEN e.confidence END,
  DATE_SUB(@now, INTERVAL e.started_days_ago + 7 DAY), @now
FROM (
  SELECT 'Result count in listing-page titles' AS name,
         'Adding the result count to location landing titles gives the searcher a reason to click that the competing portals do not offer, so click-through improves without a change in position.' AS hypothesis,
         'title' AS experiment_type, 'location_landing' AS scope_page_type, NULL AS category_code,
         'concluded' AS status, 120 AS started_days_ago, 56 AS ran_days, 28 AS minimum_duration_days,
         'ctr' AS primary_metric,
         'Variant B lifted click-through from 3.11 per cent to 3.68 per cent, an eighteen per cent relative gain, with average position unchanged at 8.4. Rolled out to all location landings. The effect was concentrated in queries with a location modifier, which is what the hypothesis predicted.' AS result_summary,
         96.00 AS confidence
  UNION ALL SELECT 'Price range in meta descriptions',
         'Stating the price range in the description qualifies the click, so click-through falls slightly but the sessions that arrive convert better.',
         'description','location_landing',NULL,'concluded',150,60,28,'conversions',
         'Click-through fell 4 per cent as expected; enquiry rate per session rose 11 per cent. Net enquiries up 6 per cent. Rolled out.',
         91.00
  UNION ALL SELECT 'FAQ structured data on community pages',
         'FAQ rich results expand the listing in the results page, taking vertical space away from competitors and lifting click-through.',
         'structured_data','location_landing',NULL,'running',34,0,42,'ctr',NULL,NULL
  UNION ALL SELECT 'Longer unique introductions on thin community pages',
         'The thin pages are thin because they are templated. Two hundred words of genuinely community-specific text should move them out of the thin bucket and into the index.',
         'content_length','location_landing',NULL,'running',21,0,56,'impressions',NULL,NULL
  UNION ALL SELECT 'Related-listing block above the fold',
         'Moving the related block above the fold increases internal links from deep pages and reduces click depth on the long tail.',
         'internal_linking','listing_detail',NULL,'running',12,0,42,'impressions',NULL,NULL
  UNION ALL SELECT 'Bedroom count first in car listing titles',
         'Ported from the property template without thinking. Cars do not have bedrooms.',
         'title','listing_detail','cars','abandoned',200,3,28,'ctr',NULL,NULL
  UNION ALL SELECT 'Branded suffix on agent profiles',
         'Dropping the site name from agent profile titles frees characters for the specialisation, which is what people actually search for.',
         'title','agent_profile',NULL,'paused',60,0,28,'clicks',NULL,NULL
) AS e
LEFT JOIN categories c ON c.code = e.category_code AND c.parent_id IS NULL;

INSERT INTO seo_experiment_variants
  (experiment_id, variant_key, name, is_control, traffic_share, title_pattern,
   description_pattern, url_count, impressions, clicks, ctr, average_position)
SELECT
  e.id, v.variant_key, v.name, v.is_control, 50.00,
  CASE WHEN e.experiment_type = 'title' THEN v.pattern END,
  CASE WHEN e.experiment_type = 'description' THEN v.pattern END,
  0, 0, 0, NULL, NULL
FROM seo_experiments e
JOIN (
  SELECT 'A' AS variant_key, 'Control' AS name, 1 AS is_control, '{existing pattern}' AS pattern
  UNION ALL SELECT 'B', 'Treatment', 0, '{treatment pattern}'
) AS v;

INSERT INTO seo_experiment_assignments (experiment_id, url_id, variant_id, assigned_at)
SELECT
  e.id, u.id, v.id, e.started_at
FROM seo_experiments e
JOIN url_inventory u
  ON u.page_type = e.scope_page_type
 AND u.is_indexable = 1
JOIN seo_experiment_variants v
  ON v.experiment_id = e.id
 -- Split on a hash of the URL, so the same page stays in the same arm across
 -- re-runs and a page never sees both treatments.
 AND v.variant_key = CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('arm:', e.id, ':', u.id)), 1, 4), 16, 10), 2) = 0
                          THEN 'A' ELSE 'B' END
WHERE e.status IN ('running', 'concluded', 'paused');

-- Variant performance follows the assignment counts, with the treatment arm
-- carrying the lift the experiment concluded.
UPDATE seo_experiment_variants v
JOIN seo_experiments e ON e.id = v.experiment_id
JOIN (
  SELECT variant_id, COUNT(*) AS n FROM seo_experiment_assignments GROUP BY variant_id
) a ON a.variant_id = v.id
SET v.url_count = a.n,
    v.impressions = a.n * (900 + MOD(CONV(SUBSTRING(MD5(CONCAT('imp:', v.id)), 1, 4), 16, 10), 2600)),
    v.average_position = ROUND(6 + MOD(CONV(SUBSTRING(MD5(CONCAT('pos:', v.id)), 1, 4), 16, 10), 90) / 10, 2);

UPDATE seo_experiment_variants v
SET v.clicks = ROUND(v.impressions * (CASE WHEN v.is_control = 1 THEN 0.0311 ELSE 0.0368 END)),
    v.ctr = CASE WHEN v.is_control = 1 THEN 0.03110 ELSE 0.03680 END
WHERE v.impressions > 0;

UPDATE seo_experiments e
JOIN seo_experiment_variants v ON v.experiment_id = e.id AND v.is_control = 0
SET e.winning_variant_id = v.id
WHERE e.status = 'concluded';

DROP TABLE IF EXISTS tmp_n;
