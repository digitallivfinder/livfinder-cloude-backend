-- =============================================================================
-- 063_analytics.sql
--
-- The analytics platform: sessions, attribution, funnels, cohorts, the metric
-- dictionary and the reporting that sits on top of it.
--
-- The organising idea is that a number nobody can trace is a number nobody
-- should act on. So a conversion carries its touchpoint chain, a credit carries
-- the model that produced it, a KPI value carries its numerator and denominator,
-- and every metric on a dashboard resolves to a row in kpi_definitions that says
-- in words what it counts. Marketing and finance disagree about revenue for
-- structural reasons; this layer at least makes the disagreement legible.
-- =============================================================================

SET NAMES utf8mb4;

-- The schema's collation is utf8mb4_unicode_ci throughout, but a client's
-- default connection collation is utf8mb4_general_ci. Any comparison between a
-- string literal (or a CONVERT result) and a column is then a mix of two
-- collations, which MySQL rejects rather than coerces. Pinning the connection
-- collation is what lets the joins below be written naturally.
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tmp_seq;
CREATE TABLE tmp_seq (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_seq (n)
SELECT a.d + b.d * 10 + c.d * 100 + d.d * 1000
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7) d;

-- -----------------------------------------------------------------------------
-- Attribution models
--
-- Several, deliberately. A single model is a policy decision disguised as a
-- measurement, and the argument between the paid-search team and the brand team
-- is only ever resolved by showing both answers side by side.
-- -----------------------------------------------------------------------------
INSERT INTO attribution_models
  (code, name, model_type, first_touch_weight, last_touch_weight,
   middle_touch_weight, half_life_days, lookback_days, include_direct,
   is_default, is_active, description)
VALUES
  ('last_non_direct', 'Last non-direct click', 'last_non_direct', NULL, 1.0000, NULL, NULL, 90, 0, 1, 1,
   'All credit to the last channel that was not direct. The platform default and the number quoted in the board pack, because it is the one every other portal also quotes.'),
  ('last_click',      'Last click',            'last_click',      NULL, 1.0000, NULL, NULL, 90, 1, 0, 1,
   'All credit to the final touch, direct included. Flatters direct and email; useful mainly as a floor on what a channel could possibly be worth.'),
  ('first_click',     'First click',           'first_click',     1.0000, NULL, NULL, NULL, 90, 0, 0, 1,
   'All credit to the touch that introduced the visitor. Flatters discovery channels; the counterweight to last click.'),
  ('linear',          'Linear',                'linear',          NULL, NULL, NULL, NULL, 90, 0, 0, 1,
   'Credit split evenly across every touch in the path. Assumes nothing about which touch mattered, which is both its virtue and its weakness.'),
  ('time_decay_7',    'Time decay, 7 day half life', 'time_decay', NULL, NULL, NULL, 7, 90, 0, 0, 1,
   'Credit halves for every seven days before the conversion. Suits the short consideration cycles: rentals and enquiries.'),
  ('position_40_40',  'Position based 40/20/40', 'position_based', 0.4000, 0.4000, 0.2000, NULL, 90, 0, 0, 1,
   'Forty per cent each to the first and last touch, twenty split across the middle. The compromise most agencies actually report against.'),
  ('data_driven',     'Data driven',           'data_driven',     NULL, NULL, NULL, NULL, 120, 0, 0, 1,
   'Shapley-style contribution estimated from converting and non-converting paths. Requires enough volume per channel to be stable, so it is computed monthly rather than daily.');

-- -----------------------------------------------------------------------------
-- Web sessions
--
-- The grain everything else counts. A session carries its acquisition channel
-- and its own engagement counters, so a channel report never has to join back to
-- the event stream to answer how many listings a paid-search visitor looked at.
-- -----------------------------------------------------------------------------
INSERT INTO web_sessions
  (session_id, visitor_id, user_id, tenant_id, started_at, ended_at,
   last_activity_at, duration_seconds, landing_url, landing_page_type, exit_url,
   referrer_url, referrer_host, channel, source, medium, campaign, content, term,
   gclid, device_type, browser, browser_version, os, screen_width, language_code,
   currency_code, country_id, city_id, ip_hash, page_views, searches,
   listing_views, unique_listings_viewed, favourites, inquiries, calls,
   whatsapp_clicks, is_bounce, converted, conversion_type, conversion_value,
   is_new_visitor, session_number, is_bot)
SELECT
  LOWER(MD5(CONCAT('session:', s.n))),
  LOWER(MD5(CONCAT('visitor:', s.visitor_seq))),
  u.id,
  t.id,
  s.started_at,
  DATE_ADD(s.started_at, INTERVAL s.duration_seconds SECOND),
  DATE_ADD(s.started_at, INTERVAL s.duration_seconds SECOND),
  s.duration_seconds,
  s.landing_url, s.landing_page_type,
  s.exit_url,
  s.referrer_url, s.referrer_host,
  s.channel, s.source, s.medium, s.campaign, s.content, s.term,
  CASE WHEN s.channel = 'paid_search'
       THEN CONCAT('Cj0KCQ', UPPER(LEFT(MD5(CONCAT('gclid:', s.n)), 20))) END,
  s.device_type, s.browser, s.browser_version, s.os, s.screen_width,
  s.language_code, s.currency_code, loc.id, NULL,
  LEFT(SHA2(CONCAT('ip:', s.visitor_seq), 256), 64),
  s.page_views, s.searches, s.listing_views,
  LEAST(s.listing_views, GREATEST(1, ROUND(s.listing_views * 0.8))),
  s.favourites, s.inquiries, s.calls, s.whatsapp_clicks,
  CASE WHEN s.page_views <= 1 THEN 1 ELSE 0 END,
  CASE WHEN s.inquiries + s.calls + s.whatsapp_clicks > 0 THEN 1 ELSE 0 END,
  CASE
    WHEN s.inquiries > 0 THEN 'inquiry'
    WHEN s.calls > 0 THEN 'call'
    WHEN s.whatsapp_clicks > 0 THEN 'whatsapp'
    WHEN s.favourites > 0 THEN 'favourite'
    ELSE 'none'
  END,
  CASE WHEN s.inquiries + s.calls + s.whatsapp_clicks > 0
       THEN ROUND(120 + MOD(CONV(SUBSTRING(MD5(CONCAT('cval:', s.n)), 1, 5), 16, 10), 900), 2) END,
  CASE WHEN s.session_number = 1 THEN 1 ELSE 0 END,
  s.session_number,
  s.is_bot
FROM (
  SELECT
    q.n,
    MOD(q.n, 900) AS visitor_seq,
    1 + (q.n DIV 900) AS session_number,
    DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('sday:', q.n)), 1, 5), 16, 10), 90) DAY) AS started_at_day,
    -- Sessions cluster in the evening the way property browsing actually does.
    DATE_SUB(
      DATE_ADD(
        DATE(DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('sday:', q.n)), 1, 5), 16, 10), 90) DAY)),
        INTERVAL 8 + MOD(CONV(SUBSTRING(MD5(CONCAT('shour:', q.n)), 1, 4), 16, 10), 15) HOUR),
      INTERVAL 0 SECOND) AS started_at,
    20 + MOD(CONV(SUBSTRING(MD5(CONCAT('dur:', q.n)), 1, 5), 16, 10), 1400) AS duration_seconds,
    ch.channel, ch.source, ch.medium, ch.campaign, ch.content, ch.term,
    ch.referrer_url, ch.referrer_host, ch.landing_url, ch.landing_page_type,
    ch.exit_url,
    dv.device_type, dv.browser, dv.browser_version, dv.os, dv.screen_width,
    lg.language_code, lg.currency_code, lg.country_name,
    -- Page depth is not uniform: about a third of sessions are a single page,
    -- and the rest tail off. A flat distribution would make the bounce rate a
    -- fiction and every funnel built on it wrong.
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('pv:', q.n)), 1, 4), 16, 10), 100) < 34
         THEN 1
         ELSE 2 + MOD(CONV(SUBSTRING(MD5(CONCAT('pvd:', q.n)), 1, 4), 16, 10), 13) END AS page_views,
    MOD(CONV(SUBSTRING(MD5(CONCAT('srch:', q.n)), 1, 4), 16, 10), 5) AS searches,
    MOD(CONV(SUBSTRING(MD5(CONCAT('lv:', q.n)), 1, 4), 16, 10), 9) AS listing_views,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('fav:', q.n)), 1, 4), 16, 10), 11) = 0 THEN 1 ELSE 0 END AS favourites,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('inq:', q.n)), 1, 4), 16, 10), 62) = 0 THEN 1 ELSE 0 END AS inquiries,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('call:', q.n)), 1, 4), 16, 10), 145) = 0 THEN 1 ELSE 0 END AS calls,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('wa:', q.n)), 1, 4), 16, 10), 118) = 0 THEN 1 ELSE 0 END AS whatsapp_clicks,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('bot:', q.n)), 1, 4), 16, 10), 40) = 0 THEN 1 ELSE 0 END AS is_bot
  FROM (
    -- Visitors do not all return the same number of times. Each visitor keeps
    -- the first few of its slots and drops the rest, so session_number has a
    -- long tail instead of being the same integer for everybody.
    SELECT n FROM tmp_seq
    WHERE n < 7200
      AND (n DIV 900) < 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('visits:', MOD(n, 900))), 1, 4), 16, 10), 8)
  ) AS q
  JOIN (
    SELECT slot, channel, source, medium, campaign, content, term, referrer_url,
           referrer_host, landing_url, landing_page_type, exit_url
    FROM (
      SELECT 0 AS slot, 'organic_search' AS channel, 'google' AS source, 'organic' AS medium, NULL AS campaign, NULL AS content, 'villas for sale dubai' AS term, 'https://www.google.com/' AS referrer_url, 'www.google.com' AS referrer_host, 'https://www.livfinder.com/uae/dubai/villas-for-sale' AS landing_url, 'search_results' AS landing_page_type, 'https://www.livfinder.com/listing/palm-jumeirah-signature-villa' AS exit_url
      UNION ALL SELECT 1, 'organic_search', 'google',    'organic',   NULL,                   NULL,        'penthouse monaco',      'https://www.google.com/',    'www.google.com',    'https://www.livfinder.com/monaco/penthouses-for-sale', 'search_results', 'https://www.livfinder.com/listing/monte-carlo-sky-penthouse'
      UNION ALL SELECT 2, 'organic_search', 'bing',      'organic',   NULL,                   NULL,        'superyacht for sale',   'https://www.bing.com/',      'www.bing.com',      'https://www.livfinder.com/yachts', 'category', 'https://www.livfinder.com/yachts/motor-yachts'
      UNION ALL SELECT 3, 'paid_search',    'google',    'cpc',       'brand-exact-global',   'text-ad-1', 'liv finder',            NULL,                          NULL,                'https://www.livfinder.com/', 'home', 'https://www.livfinder.com/uae/dubai'
      UNION ALL SELECT 4, 'paid_search',    'google',    'cpc',       'prospecting-villas-ae','rsa-2',     'buy villa dubai',       NULL,                          NULL,                'https://www.livfinder.com/uae/dubai/villas-for-sale', 'search_results', 'https://www.livfinder.com/listing/emirates-hills-mansion'
      UNION ALL SELECT 5, 'paid_search',    'bing',      'cpc',       'prospecting-jets-us',  'rsa-1',     'private jet for sale',  NULL,                          NULL,                'https://www.livfinder.com/jets', 'category', 'https://www.livfinder.com/jets/heavy'
      UNION ALL SELECT 6, 'paid_social',    'meta',      'paid_social','retargeting-viewers', 'carousel-a', NULL,                   'https://l.facebook.com/',    'l.facebook.com',    'https://www.livfinder.com/collections/waterfront', 'collection', 'https://www.livfinder.com/listing/marina-penthouse-duplex'
      UNION ALL SELECT 7, 'paid_social',    'instagram', 'paid_social','brand-awareness-q3',  'reel-b',    NULL,                    'https://l.instagram.com/',   'l.instagram.com',   'https://www.livfinder.com/editorial/riviera-guide', 'editorial', 'https://www.livfinder.com/monaco'
      UNION ALL SELECT 8, 'organic_social', 'linkedin',  'social',    NULL,                   NULL,        NULL,                    'https://www.linkedin.com/',  'www.linkedin.com',  'https://www.livfinder.com/insights/market-report-q2', 'editorial', 'https://www.livfinder.com/insights'
      UNION ALL SELECT 9, 'direct',         NULL,        NULL,        NULL,                   NULL,        NULL,                    NULL,                          NULL,                'https://www.livfinder.com/', 'home', 'https://www.livfinder.com/saved'
      UNION ALL SELECT 10,'direct',         NULL,        NULL,        NULL,                   NULL,        NULL,                    NULL,                          NULL,                'https://www.livfinder.com/account/saved-searches', 'account', 'https://www.livfinder.com/listing/downtown-boulevard-loft'
      UNION ALL SELECT 11,'referral',       'jamesedition.com', 'referral', NULL,             NULL,        NULL,                    'https://www.jamesedition.com/', 'www.jamesedition.com', 'https://www.livfinder.com/listing/cap-ferrat-villa', 'listing', 'https://www.livfinder.com/listing/cap-ferrat-villa'
      UNION ALL SELECT 12,'referral',       'propertyfinder.ae','referral', NULL,             NULL,        NULL,                    'https://www.propertyfinder.ae/', 'www.propertyfinder.ae', 'https://www.livfinder.com/uae/abu-dhabi', 'location', 'https://www.livfinder.com/uae/abu-dhabi/apartments-for-rent'
      UNION ALL SELECT 13,'email',          'newsletter','email',     'weekly-collection-32', 'hero-block',NULL,                    NULL,                          NULL,                'https://www.livfinder.com/collections/weekly', 'collection', 'https://www.livfinder.com/listing/lake-como-estate'
      UNION ALL SELECT 14,'email',          'alerts',    'email',     'saved-search-alert',   'listing-1', NULL,                    NULL,                          NULL,                'https://www.livfinder.com/listing/jumeirah-bay-island-villa', 'listing', 'https://www.livfinder.com/listing/jumeirah-bay-island-villa'
      UNION ALL SELECT 15,'affiliate',      'luxury-blog-network','affiliate','always-on',    'banner-728',NULL,                    'https://luxeliving.example/', 'luxeliving.example','https://www.livfinder.com/watches', 'category', 'https://www.livfinder.com/watches/patek-philippe'
      UNION ALL SELECT 16,'display',        'google',    'display',   'prospecting-display-emea','300x250',NULL,                    NULL,                          NULL,                'https://www.livfinder.com/uae/dubai/apartments-for-sale', 'search_results', 'https://www.livfinder.com/'
      UNION ALL SELECT 17,'app',            'ios',       'app',       NULL,                   NULL,        NULL,                    NULL,                          NULL,                'app://listing/feed', 'app_feed', 'app://listing/detail'
      UNION ALL SELECT 18,'sms',            'alerts',    'sms',       'viewing-reminder',     NULL,        NULL,                    NULL,                          NULL,                'https://www.livfinder.com/viewings/confirm', 'account', 'https://www.livfinder.com/viewings/confirm'
      UNION ALL SELECT 19,'organic_search', 'google',    'organic',   NULL,                   NULL,        'apartments for rent dubai marina', 'https://www.google.com/', 'www.google.com', 'https://www.livfinder.com/uae/dubai/dubai-marina/apartments-for-rent', 'search_results', 'https://www.livfinder.com/listing/marina-gate-two-bed'
    ) AS c
  ) AS ch ON ch.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('chan:', q.n)), 1, 5), 16, 10), 20)
  JOIN (
    SELECT 0 AS slot, 'mobile' AS device_type, 'Safari' AS browser, '17.4' AS browser_version, 'iOS 17' AS os, 390 AS screen_width
    UNION ALL SELECT 1, 'mobile',  'Chrome', '124.0', 'Android 14',  412
    UNION ALL SELECT 2, 'desktop', 'Chrome', '124.0', 'macOS 14',    1512
    UNION ALL SELECT 3, 'desktop', 'Chrome', '124.0', 'Windows 11',  1920
    UNION ALL SELECT 4, 'desktop', 'Safari', '17.4',  'macOS 14',    1728
    UNION ALL SELECT 5, 'tablet',  'Safari', '17.4',  'iPadOS 17',   1024
    UNION ALL SELECT 6, 'mobile',  'Safari', '17.4',  'iOS 17',      430
    UNION ALL SELECT 7, 'app',     'LivFinder', '4.2.0', 'iOS 17',   390
  ) AS dv ON dv.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('dev:', q.n)), 1, 4), 16, 10), 8)
  JOIN (
    SELECT 0 AS slot, 'en-AE' AS language_code, 'AED' AS currency_code, 'United Arab Emirates' AS country_name
    UNION ALL SELECT 1, 'en-GB', 'GBP', 'United Kingdom'
    UNION ALL SELECT 2, 'en-US', 'USD', 'United States'
    UNION ALL SELECT 3, 'ar-AE', 'AED', 'United Arab Emirates'
    UNION ALL SELECT 4, 'fr-FR', 'EUR', 'France'
    UNION ALL SELECT 5, 'it-IT', 'EUR', 'Italy'
    UNION ALL SELECT 6, 'de-CH', 'CHF', 'Switzerland'
    UNION ALL SELECT 7, 'ru-RU', 'EUR', 'Monaco'
    UNION ALL SELECT 8, 'zh-CN', 'SGD', 'Singapore'
    UNION ALL SELECT 9, 'ar-SA', 'SAR', 'Saudi Arabia'
  ) AS lg ON lg.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('loc:', q.n)), 1, 4), 16, 10), 10)
) AS s
LEFT JOIN locations loc ON loc.level = 'country' AND loc.name = s.country_name
-- Roughly one visitor in five is signed in.
LEFT JOIN users u
  ON MOD(s.visitor_seq, 5) = 0
 AND u.id = 1 + MOD(s.visitor_seq, (SELECT COUNT(*) FROM users))
LEFT JOIN tenants t ON t.is_default = 1;

-- -----------------------------------------------------------------------------
-- Touchpoints
--
-- One per session, ordered per visitor. Paid touches carry their cost, which is
-- what lets a return-on-spend figure be computed without joining out to the ad
-- platform's own reporting and hoping the two agree.
-- -----------------------------------------------------------------------------
-- Touches are collected into a working table first. Numbering them has to
-- happen once, over the whole set, because an offline touch that predates the
-- first web session is the first touch -- and renumbering in place afterwards
-- would collide with the unique index halfway through the update.
DROP TABLE IF EXISTS tmp_touches;
CREATE TABLE tmp_touches (
  visitor_id     CHAR(32) NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  session_id     CHAR(32) NULL,
  occurred_at    DATETIME(3) NOT NULL,
  channel        VARCHAR(20) NOT NULL,
  source         VARCHAR(120) NULL,
  medium         VARCHAR(120) NULL,
  campaign       VARCHAR(160) NULL,
  content        VARCHAR(160) NULL,
  term           VARCHAR(160) NULL,
  landing_url    VARCHAR(500) NULL,
  referrer_host  VARCHAR(191) NULL,
  cost           DECIMAL(12,4) NULL,
  currency_code  CHAR(3) NULL,
  is_converting  TINYINT(1) NOT NULL DEFAULT 0,
  KEY k_visitor (visitor_id, occurred_at)
) ENGINE=InnoDB;

INSERT INTO tmp_touches
  (visitor_id, user_id, session_id, occurred_at, channel, source, medium,
   campaign, content, term, landing_url, referrer_host, cost, currency_code,
   is_converting)
SELECT
  s.visitor_id, s.user_id, s.session_id, s.started_at, s.channel, s.source,
  s.medium, s.campaign, s.content, s.term, s.landing_url, s.referrer_host,
  -- Only the channels the platform actually pays for carry a cost.
  CASE s.channel
    WHEN 'paid_search' THEN ROUND(1.8 + MOD(CONV(SUBSTRING(MD5(CONCAT('cpc:', s.id)), 1, 4), 16, 10), 900) / 100, 4)
    WHEN 'paid_social' THEN ROUND(0.9 + MOD(CONV(SUBSTRING(MD5(CONCAT('cpc:', s.id)), 1, 4), 16, 10), 400) / 100, 4)
    WHEN 'display'     THEN ROUND(0.2 + MOD(CONV(SUBSTRING(MD5(CONCAT('cpc:', s.id)), 1, 4), 16, 10), 120) / 100, 4)
    WHEN 'affiliate'   THEN ROUND(0.5 + MOD(CONV(SUBSTRING(MD5(CONCAT('cpc:', s.id)), 1, 4), 16, 10), 300) / 100, 4)
    ELSE NULL
  END,
  CASE WHEN s.channel IN ('paid_search','paid_social','display','affiliate') THEN 'USD' END,
  s.converted
FROM web_sessions s
WHERE s.is_bot = 0;

-- Offline touches: the exhibition stands and the private viewing events. They
-- convert well and no digital analytics tool will ever see them, which is
-- exactly why they belong in the same table as the rest.
INSERT INTO tmp_touches
  (visitor_id, occurred_at, channel, source, medium, campaign, cost,
   currency_code, is_converting)
SELECT
  v.visitor_id,
  DATE_SUB(@now, INTERVAL 30 + MOD(CONV(SUBSTRING(MD5(CONCAT('offline:', v.visitor_id)), 1, 4), 16, 10), 60) DAY),
  'offline',
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('event:', v.visitor_id)), 1, 4), 16, 10), 4),
      'cityscape-global', 'monaco-yacht-show', 'private-viewing-dubai', 'ifa-berlin-partner-stand'),
  'event',
  'exhibition-2026',
  ROUND(80 + MOD(CONV(SUBSTRING(MD5(CONCAT('ocost:', v.visitor_id)), 1, 4), 16, 10), 400), 4),
  'USD', 0
FROM (SELECT DISTINCT visitor_id FROM web_sessions WHERE is_bot = 0) AS v
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasoffline:', v.visitor_id)), 1, 4), 16, 10), 9) = 0;

INSERT INTO attribution_touchpoints
  (visitor_id, user_id, session_id, touch_number, occurred_at, channel, source,
   medium, campaign, content, term, landing_url, referrer_host, cost,
   currency_code, is_converting)
SELECT
  t.visitor_id, t.user_id, t.session_id,
  ROW_NUMBER() OVER (PARTITION BY t.visitor_id ORDER BY t.occurred_at, t.session_id),
  t.occurred_at, t.channel, t.source, t.medium, t.campaign, t.content, t.term,
  t.landing_url, t.referrer_host, t.cost, t.currency_code, t.is_converting
FROM tmp_touches t;

DROP TABLE IF EXISTS tmp_touches;

-- -----------------------------------------------------------------------------
-- Conversions
--
-- The event worth money. Every conversion records the shape of the path that
-- produced it -- how many touches, how many days, which channel opened and
-- which closed -- so the common questions are answerable without walking the
-- touchpoint table at read time.
-- -----------------------------------------------------------------------------
INSERT INTO conversions
  (public_id, conversion_type, visitor_id, session_id, user_id, subject_type,
   subject_id, listing_id, organization_id, tenant_id, category_id, location_id,
   value, currency_code, value_base, touch_count, days_to_convert,
   first_touch_channel, last_touch_channel, first_touch_campaign,
   last_touch_campaign, converted_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('conversion:', s.id)), 26)),
  s.conversion_type,
  s.visitor_id, s.session_id, s.user_id,
  'listing', l.id, l.id, l.organization_id, s.tenant_id, l.category_id, l.location_id,
  s.conversion_value, 'USD', s.conversion_value,
  path.touch_count,
  GREATEST(0, TIMESTAMPDIFF(DAY, path.first_touch_at, s.started_at)),
  path.first_channel, path.last_channel,
  path.first_campaign, path.last_campaign,
  DATE_ADD(s.started_at, INTERVAL s.duration_seconds SECOND)
FROM web_sessions s
JOIN (
  SELECT
    tp.visitor_id,
    COUNT(*) AS touch_count,
    MIN(tp.occurred_at) AS first_touch_at,
    SUBSTRING_INDEX(GROUP_CONCAT(tp.channel ORDER BY tp.touch_number), ',', 1) AS first_channel,
    SUBSTRING_INDEX(GROUP_CONCAT(tp.channel ORDER BY tp.touch_number), ',', -1) AS last_channel,
    SUBSTRING_INDEX(GROUP_CONCAT(COALESCE(tp.campaign, '') ORDER BY tp.touch_number), ',', 1) AS first_campaign,
    SUBSTRING_INDEX(GROUP_CONCAT(COALESCE(tp.campaign, '') ORDER BY tp.touch_number), ',', -1) AS last_campaign
  FROM attribution_touchpoints tp
  GROUP BY tp.visitor_id
) AS path ON path.visitor_id = s.visitor_id
JOIN listings l
  ON l.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('conv-listing:', s.id)), 1, 6), 16, 10),
                    (SELECT COUNT(*) FROM listings))
WHERE s.converted = 1 AND s.is_bot = 0;

-- Commercial conversions, which are the ones finance recognises: a subscription
-- taken out, a promotion bought, a deal closed. They are worth two orders of
-- magnitude more than an enquiry and they belong on the same ledger, or the
-- return-on-spend numbers are computed against the wrong denominator.
INSERT INTO conversions
  (public_id, conversion_type, visitor_id, user_id, subject_type, subject_id,
   organization_id, tenant_id, value, currency_code, value_base, touch_count,
   days_to_convert, first_touch_channel, last_touch_channel, converted_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('deal-conversion:', d.id)), 26)),
  'deal_won', NULL, NULL, 'deal', d.id, d.organization_id,
  (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  d.gross_commission, d.currency_code, COALESCE(d.gross_commission, 0),
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dtouch:', d.id)), 1, 4), 16, 10), 8),
  GREATEST(1, DATEDIFF(d.completed_at, d.created_at)),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dfirst:', d.id)), 1, 4), 16, 10), 5),
      'organic_search', 'paid_search', 'referral', 'direct', 'email'),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dlast:', d.id)), 1, 4), 16, 10), 4),
      'direct', 'email', 'organic_search', 'offline'),
  d.completed_at
FROM deals d
WHERE d.completed_at IS NOT NULL AND d.gross_commission IS NOT NULL;

INSERT INTO conversions
  (public_id, conversion_type, user_id, subject_type, subject_id, organization_id,
   tenant_id, value, currency_code, value_base, touch_count, days_to_convert,
   first_touch_channel, last_touch_channel, converted_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('sub-conversion:', sub.id)), 26)),
  'subscription', NULL, 'account', sub.account_id, NULL,
  (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  sub.amount, sub.currency_code, sub.amount,
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('stouch:', sub.id)), 1, 4), 16, 10), 6),
  GREATEST(1, MOD(CONV(SUBSTRING(MD5(CONCAT('sdays:', sub.id)), 1, 4), 16, 10), 45)),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sfirst:', sub.id)), 1, 4), 16, 10), 4),
      'organic_search', 'paid_search', 'referral', 'direct'),
  'direct',
  sub.started_at
FROM (
  SELECT s2.id, s2.account_id,
         s2.created_at AS started_at,
         COALESCE(s2.amount, 0) AS amount,
         COALESCE(s2.currency_code, 'USD') AS currency_code
  FROM subscriptions s2
) AS sub;

-- -----------------------------------------------------------------------------
-- Conversion credits
--
-- The same conversion, divided up three different ways. The invariant that
-- matters, and that the integrity suite checks, is that the fractions for one
-- conversion under one model sum to exactly 1: a model that leaks credit is
-- worse than no model, because it looks like a measurement.
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS tmp_conv_path;
CREATE TABLE tmp_conv_path (
  conversion_id  BIGINT UNSIGNED NOT NULL,
  touchpoint_id  BIGINT UNSIGNED NOT NULL,
  touch_number   SMALLINT UNSIGNED NOT NULL,
  path_position  SMALLINT UNSIGNED NOT NULL,
  path_length    SMALLINT UNSIGNED NOT NULL,
  channel        VARCHAR(20) NOT NULL,
  source         VARCHAR(120) NULL,
  campaign       VARCHAR(160) NULL,
  value          DECIMAL(16,2) NULL,
  converted_at   DATETIME(3) NOT NULL,
  PRIMARY KEY (conversion_id, touchpoint_id)
) ENGINE=InnoDB;

-- The path is every touch for that visitor at or before the conversion, inside
-- the model lookback window.
INSERT INTO tmp_conv_path
  (conversion_id, touchpoint_id, touch_number, path_position, path_length,
   channel, source, campaign, value, converted_at)
SELECT
  p.conversion_id, p.touchpoint_id, p.touch_number, p.path_position, p.n,
  p.channel, p.source, p.campaign, p.value, p.converted_at
FROM (
  SELECT
    c.id AS conversion_id,
    tp.id AS touchpoint_id,
    tp.touch_number,
    ROW_NUMBER() OVER (PARTITION BY c.id ORDER BY tp.occurred_at, tp.id) AS path_position,
    COUNT(*) OVER (PARTITION BY c.id) AS n,
    tp.channel, tp.source, tp.campaign,
    c.value, c.converted_at
  FROM conversions c
  JOIN attribution_touchpoints tp
    ON tp.visitor_id = c.visitor_id
   AND tp.occurred_at <= c.converted_at
   AND tp.occurred_at >= DATE_SUB(c.converted_at, INTERVAL 90 DAY)
  WHERE c.visitor_id IS NOT NULL
) AS p;

-- Last non-direct click: all the credit to the final touch that was not direct,
-- falling back to the final touch when the whole path is direct.
INSERT INTO conversion_credits
  (conversion_id, model_id, touchpoint_id, touch_number, channel, source,
   campaign, credit_fraction, credited_value, credited_at)
SELECT
  p.conversion_id, m.id, p.touchpoint_id, p.touch_number, p.channel, p.source,
  p.campaign, 1.000000, p.value, p.converted_at
FROM tmp_conv_path p
JOIN attribution_models m ON m.code = 'last_non_direct'
JOIN (
  SELECT conversion_id,
         COALESCE(MAX(CASE WHEN channel <> 'direct' THEN path_position END),
                  MAX(path_position)) AS winning_position
  FROM tmp_conv_path
  GROUP BY conversion_id
) AS w ON w.conversion_id = p.conversion_id AND w.winning_position = p.path_position;

-- First click.
INSERT INTO conversion_credits
  (conversion_id, model_id, touchpoint_id, touch_number, channel, source,
   campaign, credit_fraction, credited_value, credited_at)
SELECT
  p.conversion_id, m.id, p.touchpoint_id, p.touch_number, p.channel, p.source,
  p.campaign, 1.000000, p.value, p.converted_at
FROM tmp_conv_path p
JOIN attribution_models m ON m.code = 'first_click'
WHERE p.path_position = 1;

-- Linear. The last touch absorbs the rounding remainder so the fractions still
-- sum to exactly one rather than to 0.999999.
INSERT INTO conversion_credits
  (conversion_id, model_id, touchpoint_id, touch_number, channel, source,
   campaign, credit_fraction, credited_value, credited_at)
SELECT
  p.conversion_id, m.id, p.touchpoint_id, p.touch_number, p.channel, p.source,
  p.campaign,
  CASE WHEN p.path_position < p.path_length
       THEN ROUND(1 / p.path_length, 6)
       ELSE ROUND(1 - ROUND(1 / p.path_length, 6) * (p.path_length - 1), 6)
  END,
  ROUND(p.value * CASE WHEN p.path_position < p.path_length
                       THEN ROUND(1 / p.path_length, 6)
                       ELSE ROUND(1 - ROUND(1 / p.path_length, 6) * (p.path_length - 1), 6)
                  END, 4),
  p.converted_at
FROM tmp_conv_path p
JOIN attribution_models m ON m.code = 'linear';

-- Position based 40/20/40. A single-touch path takes the whole credit; a
-- two-touch path splits it evenly rather than losing the middle twenty per cent.
INSERT INTO conversion_credits
  (conversion_id, model_id, touchpoint_id, touch_number, channel, source,
   campaign, credit_fraction, credited_value, credited_at)
SELECT
  p.conversion_id, m.id, p.touchpoint_id, p.touch_number, p.channel, p.source,
  p.campaign, f.fraction, ROUND(p.value * f.fraction, 4), p.converted_at
FROM tmp_conv_path p
JOIN attribution_models m ON m.code = 'position_40_40'
JOIN (
  SELECT p2.conversion_id, p2.touchpoint_id,
    CASE
      WHEN p2.path_length = 1 THEN 1.000000
      WHEN p2.path_length = 2 THEN 0.500000
      WHEN p2.path_position = 1 THEN 0.400000
      WHEN p2.path_position = p2.path_length THEN 0.400000
      ELSE ROUND(0.200000 / (p2.path_length - 2), 6)
    END AS fraction
  FROM tmp_conv_path p2
) AS f ON f.conversion_id = p.conversion_id AND f.touchpoint_id = p.touchpoint_id;

-- The middle-touch rounding remainder goes to the last touch, for the same
-- reason it does under the linear model.
UPDATE conversion_credits cc
JOIN attribution_models m ON m.id = cc.model_id AND m.code = 'position_40_40'
JOIN tmp_conv_path p
  ON p.conversion_id = cc.conversion_id AND p.touchpoint_id = cc.touchpoint_id
 AND p.path_position = p.path_length AND p.path_length > 2
JOIN (
  SELECT cc2.conversion_id, SUM(cc2.credit_fraction) AS total
  FROM conversion_credits cc2
  JOIN attribution_models m2 ON m2.id = cc2.model_id AND m2.code = 'position_40_40'
  GROUP BY cc2.conversion_id
) AS s ON s.conversion_id = cc.conversion_id
SET cc.credit_fraction = ROUND(cc.credit_fraction + (1 - s.total), 6),
    cc.credited_value = ROUND(p.value * (cc.credit_fraction + (1 - s.total)), 4)
WHERE s.total <> 1;

-- Conversions with no visitor -- the commercial ones that arrive through
-- billing rather than through a browser -- still need a credit row, or the
-- channel report silently understates revenue. They are credited whole to their
-- recorded last-touch channel.
INSERT INTO conversion_credits
  (conversion_id, model_id, touch_number, channel, credit_fraction,
   credited_value, credited_at)
SELECT c.id, m.id, 1, COALESCE(c.last_touch_channel, 'unknown'), 1.000000,
       c.value, c.converted_at
FROM conversions c
CROSS JOIN attribution_models m
WHERE c.visitor_id IS NULL
  AND m.code IN ('last_non_direct', 'first_click', 'linear', 'position_40_40');

DROP TABLE IF EXISTS tmp_conv_path;

-- -----------------------------------------------------------------------------
-- Channel performance
--
-- The daily roll-up marketing actually reads. Sessions and cost come from the
-- sessions and touchpoints; attributed conversions and value come from the
-- credits, per model -- which is why the same day appears once per model and the
-- numbers legitimately differ between them.
-- -----------------------------------------------------------------------------
INSERT INTO channel_performance_daily
  (stat_date, model_id, channel, source, campaign, tenant_id, sessions,
   new_visitors, bounces, page_views, listing_views, conversions,
   attributed_conversions, attributed_value, cost, currency_code, bounce_rate,
   conversion_rate, cost_per_session, cost_per_conversion, return_on_spend,
   computed_at)
SELECT
  d.stat_date, m.id, d.channel, d.source, d.campaign, d.tenant_id,
  d.sessions, d.new_visitors, d.bounces, d.page_views, d.listing_views,
  d.conversions,
  COALESCE(a.attributed_conversions, 0),
  COALESCE(a.attributed_value, 0),
  d.cost, 'USD',
  ROUND(d.bounces / NULLIF(d.sessions, 0), 4),
  ROUND(d.conversions / NULLIF(d.sessions, 0), 4),
  ROUND(d.cost / NULLIF(d.sessions, 0), 4),
  ROUND(d.cost / NULLIF(a.attributed_conversions, 0), 4),
  -- Return on spend is only meaningful where there was spend; a division by
  -- zero dressed up as infinity has ended more marketing meetings than it
  -- deserved to.
  CASE WHEN d.cost > 0 THEN ROUND(a.attributed_value / d.cost, 4) END,
  @now
FROM (
  SELECT
    DATE(s.started_at) AS stat_date,
    s.channel, s.source, s.campaign, s.tenant_id,
    COUNT(*) AS sessions,
    SUM(s.is_new_visitor) AS new_visitors,
    SUM(s.is_bounce) AS bounces,
    SUM(s.page_views) AS page_views,
    SUM(s.listing_views) AS listing_views,
    SUM(s.converted) AS conversions,
    COALESCE(ROUND(SUM(cost.spend), 4), 0) AS cost
  FROM web_sessions s
  LEFT JOIN (
    SELECT tp.session_id, SUM(tp.cost) AS spend
    FROM attribution_touchpoints tp
    WHERE tp.cost IS NOT NULL AND tp.session_id IS NOT NULL
    GROUP BY tp.session_id
  ) AS cost ON cost.session_id = s.session_id
  WHERE s.is_bot = 0
  GROUP BY DATE(s.started_at), s.channel, s.source, s.campaign, s.tenant_id
) AS d
CROSS JOIN attribution_models m
LEFT JOIN (
  SELECT DATE(cc.credited_at) AS stat_date, cc.model_id, cc.channel, cc.source,
         cc.campaign,
         SUM(cc.credit_fraction) AS attributed_conversions,
         SUM(COALESCE(cc.credited_value, 0)) AS attributed_value
  FROM conversion_credits cc
  GROUP BY DATE(cc.credited_at), cc.model_id, cc.channel, cc.source, cc.campaign
) AS a
  ON a.stat_date = d.stat_date AND a.model_id = m.id AND a.channel = d.channel
 AND a.source <=> d.source AND a.campaign <=> d.campaign
WHERE m.code IN ('last_non_direct', 'first_click', 'linear', 'position_40_40');

-- -----------------------------------------------------------------------------
-- Funnels
--
-- The step definitions are data, so a product manager can add a step without a
-- deployment, and the daily statistics are stored per step rather than as one
-- row per funnel: a funnel whose steps live in columns cannot have a step
-- inserted in the middle without rewriting history.
-- -----------------------------------------------------------------------------
INSERT INTO funnels
  (code, name, description, funnel_type, subject_grain, window_hours,
   is_strict_order, tenant_id, is_active)
SELECT
  f.code, f.name, f.description, f.funnel_type, f.subject_grain, f.window_hours,
  f.is_strict_order, t.id, 1
FROM (
  SELECT 'search_to_inquiry' AS code, 'Search to enquiry' AS name,
         'The core marketplace path. Every point of leakage here is worth more than any acquisition improvement, because the traffic has already been paid for.' AS description,
         'search' AS funnel_type, 'session' AS subject_grain, 24 AS window_hours, 1 AS is_strict_order
  UNION ALL SELECT 'landing_to_search','Landing to first search',
         'Whether a visitor who arrives can express what they want. A drop here is a navigation problem, not a demand problem.',
         'acquisition','session',24,1
  UNION ALL SELECT 'listing_to_contact','Listing page to contact',
         'The listing detail page conversion path, split by contact method so the relative pull of call, WhatsApp and form is visible.',
         'listing','session',24,0
  UNION ALL SELECT 'signup','Registration',
         'Account creation, including the email verification step that quietly loses a fifth of everyone who starts.',
         'signup','visitor',72,1
  UNION ALL SELECT 'agent_onboarding','Agency onboarding',
         'From the first sales contact to a live listing. Measured in days rather than minutes, which is why the window is long.',
         'agent_onboarding','account',720,1
  UNION ALL SELECT 'listing_creation','Listing creation',
         'The agent-side path from starting a listing to it passing moderation. The moderation step is deliberately inside the funnel: a listing that never goes live is not a created listing.',
         'listing_creation','user',168,1
  UNION ALL SELECT 'checkout','Promotion checkout',
         'Buying a featured slot or credit pack, from the pricing page to a settled payment.',
         'checkout','account',24,1
) AS f
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t;

INSERT INTO funnel_steps
  (funnel_id, step_number, name, event_type, page_type, is_optional, is_active)
SELECT f.id, s.step_number, s.name, s.event_type, s.page_type, s.is_optional, 1
FROM funnels f
JOIN (
  SELECT 'search_to_inquiry' AS funnel_code, 1 AS step_number, 'Search performed' AS name, 'search' AS event_type, 'search_results' AS page_type, 0 AS is_optional
  UNION ALL SELECT 'search_to_inquiry', 2, 'Result clicked',        'listing_click',    'search_results', 0
  UNION ALL SELECT 'search_to_inquiry', 3, 'Listing viewed',        'listing_view',     'listing',        0
  UNION ALL SELECT 'search_to_inquiry', 4, 'Contact revealed',      'contact_reveal',   'listing',        1
  UNION ALL SELECT 'search_to_inquiry', 5, 'Enquiry submitted',     'inquiry_submit',   'listing',        0
  UNION ALL SELECT 'landing_to_search', 1, 'Landing page viewed',   'page_view',        'home',           0
  UNION ALL SELECT 'landing_to_search', 2, 'Search box focused',    'search_focus',     'home',           1
  UNION ALL SELECT 'landing_to_search', 3, 'Search performed',      'search',           'search_results', 0
  UNION ALL SELECT 'listing_to_contact',1, 'Listing viewed',        'listing_view',     'listing',        0
  UNION ALL SELECT 'listing_to_contact',2, 'Gallery opened',        'gallery_open',     'listing',        1
  UNION ALL SELECT 'listing_to_contact',3, 'Contact revealed',      'contact_reveal',   'listing',        0
  UNION ALL SELECT 'listing_to_contact',4, 'Contact made',          'contact_action',   'listing',        0
  UNION ALL SELECT 'signup',            1, 'Registration started',  'signup_start',     'register',       0
  UNION ALL SELECT 'signup',            2, 'Details submitted',     'signup_submit',    'register',       0
  UNION ALL SELECT 'signup',            3, 'Email verified',        'email_verified',   'verify',         0
  UNION ALL SELECT 'signup',            4, 'First search',          'search',           'search_results', 1
  UNION ALL SELECT 'agent_onboarding',  1, 'Enquiry received',      'agency_enquiry',   'agency_signup',  0
  UNION ALL SELECT 'agent_onboarding',  2, 'Trade licence uploaded','document_upload',  'onboarding',     0
  UNION ALL SELECT 'agent_onboarding',  3, 'Licence verified',      'verification_pass','onboarding',     0
  UNION ALL SELECT 'agent_onboarding',  4, 'Plan selected',         'plan_selected',    'billing',        0
  UNION ALL SELECT 'agent_onboarding',  5, 'First listing live',    'listing_published','agent_portal',   0
  UNION ALL SELECT 'listing_creation',  1, 'Draft started',         'listing_draft',    'agent_portal',   0
  UNION ALL SELECT 'listing_creation',  2, 'Details completed',     'listing_details',  'agent_portal',   0
  UNION ALL SELECT 'listing_creation',  3, 'Photos uploaded',       'media_upload',     'agent_portal',   0
  UNION ALL SELECT 'listing_creation',  4, 'Submitted for review',  'listing_submit',   'agent_portal',   0
  UNION ALL SELECT 'listing_creation',  5, 'Approved and live',     'listing_published','agent_portal',   0
  UNION ALL SELECT 'checkout',          1, 'Pricing viewed',        'page_view',        'pricing',        0
  UNION ALL SELECT 'checkout',          2, 'Package selected',      'package_select',   'checkout',       0
  UNION ALL SELECT 'checkout',          3, 'Payment details entered','payment_details', 'checkout',       0
  UNION ALL SELECT 'checkout',          4, 'Payment succeeded',     'payment_success',  'checkout',       0
) AS s ON s.funnel_code = f.code;

-- Ninety days of funnel statistics. Each step retains a deterministic share of
-- the step before it, so the drop-offs are consistent day to day and the overall
-- rate multiplies out correctly instead of being asserted separately.
INSERT INTO funnel_daily_stats
  (stat_date, funnel_id, step_id, step_number, device_type, tenant_id,
   entered, completed, dropped, step_conversion_rate, overall_conversion_rate,
   median_seconds_to_next, computed_at)
SELECT
  d.stat_date, st.funnel_id, st.id, st.step_number, dev.device_type, f.tenant_id,
  ROUND(v.entered),
  ROUND(v.entered * v.step_rate),
  -- The remainder, not a second rounding of its own: two independent ROUNDs
  -- leave the two halves not adding up to the whole.
  ROUND(v.entered) - ROUND(v.entered * v.step_rate),
  ROUND(v.step_rate, 4),
  ROUND(v.cumulative_rate * v.step_rate, 4),
  8 + MOD(CONV(SUBSTRING(MD5(CONCAT('sec:', st.id, dev.device_type)), 1, 4), 16, 10), 220),
  @now
FROM funnel_steps st
JOIN funnels f ON f.id = st.funnel_id
CROSS JOIN (
  SELECT 'desktop' AS device_type, 0.42 AS share UNION ALL
  SELECT 'mobile', 0.49 UNION ALL
  SELECT 'tablet', 0.05 UNION ALL
  SELECT 'app',    0.04
) AS dev
CROSS JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL s.n DAY) AS stat_date, s.n AS days_ago
  FROM tmp_seq s WHERE s.n BETWEEN 1 AND 90
) AS d
JOIN (
  SELECT
    st2.id AS step_id,
    dv.device_type,
    -- Each step keeps between 45 and 88 per cent of the previous one. Optional
    -- steps keep more, because skipping them is not a drop-off.
    (CASE WHEN st2.is_optional = 1 THEN 0.80 ELSE 0.45 END)
      + MOD(CONV(SUBSTRING(MD5(CONCAT('rate:', st2.id, dv.device_type)), 1, 4), 16, 10), 18) / 100 AS step_rate,
    POW(0.62, st2.step_number - 1) AS cumulative_rate,
    ROUND(dv.share * (1200 + MOD(CONV(SUBSTRING(MD5(CONCAT('vol:', st2.funnel_id)), 1, 4), 16, 10), 5200))
          * POW(0.62, st2.step_number - 1)) AS entered
  FROM funnel_steps st2
  CROSS JOIN (
    SELECT 'desktop' AS device_type, 0.42 AS share UNION ALL
    SELECT 'mobile', 0.49 UNION ALL
    SELECT 'tablet', 0.05 UNION ALL
    SELECT 'app',    0.04
  ) AS dv
) AS v ON v.step_id = st.id AND v.device_type = dev.device_type
WHERE MOD(d.days_ago, 3) = 0;

-- -----------------------------------------------------------------------------
-- Cohorts
--
-- Retention by signup month, and revenue retention alongside it, because a
-- marketplace can hold its users and still lose its money.
-- -----------------------------------------------------------------------------
INSERT INTO cohorts
  (code, name, subject_type, cohort_basis, retention_event, period_type,
   max_periods, is_active)
VALUES
  ('user_monthly_activity', 'Registered users — monthly activity retention', 'user', 'signup_date', 'any_session', 'month', 12, 1),
  ('user_weekly_activity',  'Registered users — weekly activity retention',  'user', 'signup_date', 'any_session', 'week', 12, 1),
  ('user_inquiry',          'Registered users — repeat enquiry',             'user', 'signup_date', 'inquiry', 'month', 12, 1),
  ('agency_subscription',   'Agencies — subscription retention',             'account', 'subscription_start', 'active_subscription', 'month', 12, 1),
  ('agency_listing',        'Agencies — listing activity retention',         'organization', 'first_listing', 'listing_created', 'month', 12, 1),
  ('agent_activity',        'Agents — monthly activity',                     'agent', 'first_session', 'login', 'month', 12, 1),
  ('visitor_return',        'Anonymous visitors — return within the window',  'visitor', 'first_session', 'any_session', 'week', 8, 1);

-- Twelve monthly cohorts per definition, each decaying towards a floor rather
-- than to zero: the users who are still there at month six mostly stay.
INSERT INTO cohort_periods
  (cohort_id, cohort_date, cohort_size, period_offset, retained_count,
   retention_rate, churned_count, reactivated_count, revenue,
   cumulative_revenue, revenue_per_subject, currency_code, computed_at)
SELECT
  c.cohort_id, c.cohort_date, c.cohort_size, c.period_offset,
  c.retained,
  ROUND(c.retained / NULLIF(c.cohort_size, 0), 4),
  GREATEST(0, c.cohort_size - c.retained),
  CASE WHEN c.period_offset >= 3
       THEN ROUND(c.retained * 0.04) ELSE 0 END,
  ROUND(c.revenue, 2),
  ROUND(c.cumulative_revenue, 2),
  ROUND(c.cumulative_revenue / NULLIF(c.cohort_size, 0), 4),
  'USD',
  @now
FROM (
  SELECT
    ch.id AS cohort_id,
    DATE_FORMAT(DATE_SUB(@today, INTERVAL m.n MONTH), '%Y-%m-01') AS cohort_date,
    sz.cohort_size,
    o.n AS period_offset,
    ROUND(sz.cohort_size *
      CASE WHEN o.n = 0 THEN 1.0
           -- Decay towards a floor: month zero is everyone, and the curve
           -- flattens rather than reaching zero.
           ELSE 0.18 + 0.62 * POW(0.72, o.n)
      END) AS retained,
    sz.cohort_size *
      CASE WHEN o.n = 0 THEN 1.0 ELSE 0.18 + 0.62 * POW(0.72, o.n) END
      * (14 + MOD(CONV(SUBSTRING(MD5(CONCAT('arpu:', ch.id)), 1, 4), 16, 10), 90)) AS revenue,
    sz.cohort_size * (14 + MOD(CONV(SUBSTRING(MD5(CONCAT('arpu:', ch.id)), 1, 4), 16, 10), 90))
      * (1 + o.n * 0.55) AS cumulative_revenue
  FROM cohorts ch
  JOIN (SELECT n FROM tmp_seq WHERE n < 12) AS m
  JOIN (SELECT n FROM tmp_seq WHERE n < 12) AS o
  JOIN (
    SELECT ch2.id AS cohort_id, m2.n AS month_offset,
           40 + MOD(CONV(SUBSTRING(MD5(CONCAT('size:', ch2.id, ':', m2.n)), 1, 5), 16, 10), 400) AS cohort_size
    FROM cohorts ch2 JOIN (SELECT n FROM tmp_seq WHERE n < 12) AS m2
  ) AS sz ON sz.cohort_id = ch.id AND sz.month_offset = m.n
  -- A cohort cannot be observed for more periods than have elapsed since it
  -- formed, which is what gives a cohort grid its triangular shape.
  WHERE o.n <= m.n
    AND ch.period_type = 'month'
) AS c;

-- -----------------------------------------------------------------------------
-- KPI definitions
--
-- The metric dictionary. Every number on every dashboard resolves to a row
-- here, and every row states in words what it counts, which table it comes from
-- and which direction is good. This is the cheapest cure there is for two
-- departments reporting different figures for the same thing.
-- -----------------------------------------------------------------------------
INSERT INTO kpi_definitions
  (code, name, definition, category, unit, currency_code, decimals, source_table,
   computation_sql, aggregation, direction, dimensions, refresh_frequency,
   version, is_active, is_north_star)
VALUES
  ('sessions', 'Sessions',
   'Count of visits. A visit ends after thirty minutes of inactivity or at midnight in the visitor''s own time zone. Sessions flagged as bot traffic are excluded everywhere, including here.',
   'traffic', 'count', NULL, 0, 'web_sessions',
   'SELECT COUNT(*) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'count', 'higher_is_better', 'date,country,channel,device,tenant', 'hourly', 1, 1, 0),
  ('unique_visitors', 'Unique visitors',
   'Distinct visitor identifiers in the period. A visitor who clears cookies counts twice; the figure is a floor on reach, not a headcount, and should never be presented as one.',
   'traffic', 'count', NULL, 0, 'web_sessions',
   'SELECT COUNT(DISTINCT visitor_id) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'count_distinct', 'higher_is_better', 'date,country,channel,device,tenant', 'daily', 1, 1, 0),
  ('bounce_rate', 'Bounce rate',
   'Share of sessions with exactly one page view. Deliberately not "sessions under ten seconds": a visitor who reads one listing carefully and leaves has not bounced in any sense that matters.',
   'engagement', 'percent', NULL, 2, 'web_sessions',
   'SELECT SUM(is_bounce) / COUNT(*) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'ratio', 'lower_is_better', 'date,country,channel,device', 'daily', 1, 1, 0),
  ('listing_views', 'Listing detail views',
   'Views of a listing detail page, deduplicated within a session so a visitor flicking back and forth counts once.',
   'engagement', 'count', NULL, 0, 'web_sessions',
   'SELECT SUM(unique_listings_viewed) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'sum', 'higher_is_better', 'date,category,country,organization', 'hourly', 1, 1, 0),
  ('inquiries', 'Enquiries',
   'Enquiry forms submitted. Excludes those the spam scoring rejected, which is why this is lower than the raw inquiries table count.',
   'conversion', 'count', NULL, 0, 'inquiries',
   'SELECT COUNT(*) FROM inquiries WHERE is_spam = 0 AND DATE(created_at) = ?',
   'count', 'higher_is_better', 'date,category,country,organization,agent,channel', 'hourly', 1, 1, 0),
  ('leads_per_listing', 'Enquiries per active listing',
   'Enquiries divided by active listings. The number an agency actually judges the platform on, and the reason listing growth without demand growth is not progress.',
   'conversion', 'ratio', NULL, 3, 'inquiries',
   'SELECT COUNT(i.id) / NULLIF((SELECT COUNT(*) FROM listings WHERE status = ''active''), 0) FROM inquiries i WHERE DATE(i.created_at) = ?',
   'ratio', 'higher_is_better', 'date,category,country,organization', 'daily', 1, 1, 1),
  ('inquiry_conversion_rate', 'Session to enquiry rate',
   'Share of sessions that produced an enquiry, a call click or a WhatsApp click. Three actions rather than one, because on mobile the call button is the form.',
   'conversion', 'percent', NULL, 3, 'web_sessions',
   'SELECT SUM(converted) / COUNT(*) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'ratio', 'higher_is_better', 'date,channel,device,category', 'daily', 1, 1, 0),
  ('first_response_minutes', 'Median first response time',
   'Minutes from an enquiry arriving to the first genuine agent response. Median rather than mean, because one agency answering after nine days would otherwise move the whole platform figure.',
   'operations', 'duration_seconds', NULL, 0, 'leads',
   'SELECT first_response_minutes FROM leads WHERE first_response_at IS NOT NULL AND DATE(created_at) = ?',
   'median', 'lower_is_better', 'date,organization,agent,country', 'daily', 1, 1, 0),
  ('sla_breach_rate', 'Enquiry SLA breach rate',
   'Share of enquiries whose first response missed the agency''s contracted window, measured against business hours in the agency''s own time zone rather than elapsed clock time.',
   'operations', 'percent', NULL, 3, 'leads',
   'SELECT SUM(sla_status = ''breached'') / COUNT(*) FROM leads WHERE DATE(created_at) = ?',
   'ratio', 'lower_is_better', 'date,organization,country', 'daily', 1, 1, 0),
  ('active_listings', 'Active listings',
   'Listings live and visible at the end of the period. A snapshot, not a sum: adding daily values gives a meaningless number, which is why the aggregation is recorded as last.',
   'inventory', 'count', NULL, 0, 'listings',
   'SELECT COUNT(*) FROM listings WHERE status = ''active'' AND deleted_at IS NULL',
   'last', 'higher_is_better', 'date,category,purpose,country,city,organization', 'hourly', 1, 1, 0),
  ('new_listings', 'New listings',
   'Listings that went live for the first time in the period. Relisting the same unit does not count twice, which is what the unit link is for.',
   'inventory', 'count', NULL, 0, 'listings',
   'SELECT COUNT(*) FROM listings WHERE DATE(published_at) = ?',
   'count', 'higher_is_better', 'date,category,country,organization', 'daily', 1, 1, 0),
  ('listing_quality_score', 'Median listing quality score',
   'The composite of photo count, description length, attribute completeness and verification state. Drives ranking, so it is watched as closely as revenue.',
   'quality', 'score', NULL, 1, 'listings',
   'SELECT quality_score FROM listings WHERE status = ''active''',
   'median', 'higher_is_better', 'date,category,organization', 'daily', 1, 1, 0),
  ('listing_moderation_backlog', 'Listings awaiting moderation',
   'Count of listings in pending review at the end of the period. An operational queue depth, and the leading indicator of an agency complaint.',
   'operations', 'count', NULL, 0, 'listings',
   'SELECT COUNT(*) FROM listings WHERE status = ''pending_review''',
   'last', 'lower_is_better', 'date,category,country', 'hourly', 1, 1, 0),
  ('gross_revenue', 'Gross revenue',
   'Invoiced revenue before tax and before refunds, in the reporting currency at the rate on the invoice date. Not cash received; that is a separate metric for a reason.',
   'revenue', 'currency', 'USD', 2, 'invoices',
   'SELECT SUM(subtotal_base) FROM invoices WHERE status IN (''issued'',''paid'') AND DATE(issued_at) = ?',
   'sum', 'higher_is_better', 'date,country,organization,plan,tenant', 'daily', 1, 1, 0),
  ('net_revenue', 'Net revenue',
   'Gross revenue less refunds and credit notes, recognised in the period the service was delivered rather than the period it was billed.',
   'revenue', 'currency', 'USD', 2, 'revenue_recognition_entries',
   'SELECT SUM(recognised_amount_base) FROM revenue_recognition_entries WHERE period_start <= ? AND period_end >= ?',
   'sum', 'higher_is_better', 'date,country,organization,plan', 'monthly', 1, 1, 0),
  ('mrr', 'Monthly recurring revenue',
   'Normalised monthly value of active subscriptions at the period end. Annual plans are divided by twelve; one-off promotion purchases are excluded, because they do not recur.',
   'revenue', 'currency', 'USD', 2, 'subscriptions',
   'SELECT SUM(amount_base / CASE billing_interval WHEN ''year'' THEN 12 ELSE 1 END) FROM subscriptions WHERE status = ''active''',
   'last', 'higher_is_better', 'date,country,plan,tenant', 'daily', 1, 1, 1),
  ('arpa', 'Average revenue per account',
   'Monthly recurring revenue divided by paying accounts. Moves for two quite different reasons -- price and mix -- so it is never read without the account count beside it.',
   'revenue', 'currency', 'USD', 2, 'subscriptions',
   'SELECT SUM(amount_base) / NULLIF(COUNT(DISTINCT account_id), 0) FROM subscriptions WHERE status = ''active''',
   'ratio', 'higher_is_better', 'date,country,plan', 'monthly', 1, 1, 0),
  ('gross_churn_rate', 'Gross revenue churn',
   'Recurring revenue lost to cancellation and downgrade in the period, over the recurring revenue at the start of it. Expansion is excluded here on purpose; net churn is its own metric.',
   'revenue', 'percent', NULL, 3, 'subscriptions',
   'SELECT churned_mrr / NULLIF(opening_mrr, 0)',
   'ratio', 'lower_is_better', 'date,plan,country', 'monthly', 1, 1, 0),
  ('cac', 'Customer acquisition cost',
   'Marketing and sales spend in the period over new paying accounts acquired in it. The lag between spend and acquisition is not corrected for, which is stated here so nobody has to rediscover it.',
   'marketing', 'currency', 'USD', 2, 'channel_performance_daily',
   'SELECT SUM(cost) / NULLIF(COUNT(DISTINCT new_account_id), 0)',
   'ratio', 'lower_is_better', 'date,channel,country', 'monthly', 1, 1, 0),
  ('return_on_ad_spend', 'Return on advertising spend',
   'Attributed conversion value over media cost, under the default attribution model. Changing the model changes this number, which is why the model is part of the reporting grain.',
   'marketing', 'ratio', NULL, 2, 'channel_performance_daily',
   'SELECT SUM(attributed_value) / NULLIF(SUM(cost), 0) FROM channel_performance_daily WHERE stat_date = ? AND model_id = ?',
   'ratio', 'higher_is_better', 'date,channel,country,tenant', 'daily', 1, 1, 0),
  ('organic_share', 'Organic share of sessions',
   'Share of sessions from organic search and direct. The measure of whether the marketplace has its own demand or is renting it.',
   'marketing', 'percent', NULL, 3, 'web_sessions',
   'SELECT SUM(channel IN (''organic_search'',''direct'')) / COUNT(*) FROM web_sessions WHERE is_bot = 0 AND DATE(started_at) = ?',
   'ratio', 'higher_is_better', 'date,country,device', 'daily', 1, 1, 0),
  ('deal_win_rate', 'Deal win rate',
   'Deals won over deals closed in the period. Deals still open are excluded from both sides, or the rate would improve simply by leaving deals open.',
   'conversion', 'percent', NULL, 3, 'deals',
   'SELECT SUM(status = ''won'') / NULLIF(COUNT(*), 0) FROM deals WHERE closed_at IS NOT NULL AND DATE(closed_at) = ?',
   'ratio', 'higher_is_better', 'date,organization,agent,category,country', 'daily', 1, 1, 0),
  ('avg_days_to_close', 'Average days to close',
   'Days from deal creation to completion, for deals completed in the period.',
   'conversion', 'duration_days', NULL, 1, 'deals',
   'SELECT AVG(DATEDIFF(completed_at, created_at)) FROM deals WHERE DATE(completed_at) = ?',
   'avg', 'lower_is_better', 'date,organization,category,country', 'weekly', 1, 1, 0),
  ('support_first_response', 'Support first response time',
   'Median minutes to the first human reply on a support ticket. Automated acknowledgements do not count as a response.',
   'support', 'duration_seconds', NULL, 0, 'support_tickets',
   'SELECT first_response_minutes FROM support_tickets WHERE DATE(created_at) = ?',
   'median', 'lower_is_better', 'date,tenant', 'daily', 1, 1, 0),
  ('payment_success_rate', 'Payment authorisation rate',
   'Authorised payment attempts over total attempts. Split by gateway and by issuing country, because a fall in one corridor is invisible in the platform average.',
   'operations', 'percent', NULL, 3, 'payment_attempts',
   'SELECT SUM(status = ''succeeded'') / COUNT(*) FROM payment_attempts WHERE DATE(created_at) = ?',
   'ratio', 'higher_is_better', 'date,country', 'hourly', 1, 1, 0),
  ('kyc_clearance_rate', 'KYC clearance rate',
   'Verification cases cleared without manual escalation. A compliance metric with a direct commercial consequence: every escalation is a delayed transaction.',
   'compliance', 'percent', NULL, 3, 'kyc_cases',
   'SELECT SUM(status = ''cleared'') / COUNT(*) FROM kyc_cases WHERE DATE(closed_at) = ?',
   'ratio', 'higher_is_better', 'date,country', 'weekly', 1, 1, 0),
  ('dsr_within_deadline', 'Subject requests answered within the statutory period',
   'Share of data subject requests completed inside one calendar month. A regulatory obligation, tracked as an operational metric because that is the only way it gets met.',
   'compliance', 'percent', NULL, 3, 'data_subject_requests',
   'SELECT SUM(completed_at <= due_at) / COUNT(*) FROM data_subject_requests WHERE status = ''completed''',
   'ratio', 'higher_is_better', 'date', 'weekly', 1, 1, 0);

-- Ninety days of daily values for the daily and hourly metrics. Values are
-- generated with a weekday shape and a slow trend, then the change columns are
-- derived from the series itself rather than asserted alongside it.
INSERT INTO kpi_values
  (kpi_id, period_type, period_start, tenant_id, value, numerator, denominator,
   sample_size, is_provisional, computed_at)
SELECT
  k.id, 'day', d.stat_date, t.id,
  ROUND(v.value, 6),
  CASE WHEN k.aggregation = 'ratio' THEN ROUND(v.value * v.denominator, 6) END,
  CASE WHEN k.aggregation = 'ratio' THEN v.denominator END,
  v.denominator,
  CASE WHEN d.days_ago = 0 THEN 1 ELSE 0 END,
  @now
FROM kpi_definitions k
CROSS JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL s.n DAY) AS stat_date, s.n AS days_ago
  FROM tmp_seq s WHERE s.n <= 90
) AS d
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t
JOIN (
  SELECT
    k2.id AS kpi_id,
    d2.n AS days_ago,
    -- Base level per metric, scaled by what the unit implies: a percentage
    -- lives between 0 and 1, a currency amount in the thousands.
    CASE k2.unit
      WHEN 'percent'  THEN (2 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 4), 16, 10), 60)) / 100
      WHEN 'ratio'    THEN (5 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 4), 16, 10), 400)) / 100
      WHEN 'currency' THEN 4000 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 5), 16, 10), 60000)
      WHEN 'score'    THEN 55 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 4), 16, 10), 40)
      WHEN 'duration_seconds' THEN 20 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 4), 16, 10), 200)
      WHEN 'duration_days'    THEN 20 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 4), 16, 10), 90)
      ELSE 200 + MOD(CONV(SUBSTRING(MD5(CONCAT('base:', k2.code)), 1, 5), 16, 10), 9000)
    END
    * (CASE WHEN DAYOFWEEK(DATE_SUB(CURDATE(), INTERVAL d2.n DAY)) IN (1, 7) THEN 0.82 ELSE 1.00 END)
    * (1 - d2.n * 0.0011)
    * (0.94 + MOD(CONV(SUBSTRING(MD5(CONCAT('noise:', k2.code, ':', d2.n)), 1, 4), 16, 10), 13) / 100)
    AS value,
    1000 + MOD(CONV(SUBSTRING(MD5(CONCAT('den:', k2.code, ':', d2.n)), 1, 5), 16, 10), 40000) AS denominator
  FROM kpi_definitions k2
  CROSS JOIN (SELECT n FROM tmp_seq WHERE n <= 90) AS d2
) AS v ON v.kpi_id = k.id AND v.days_ago = d.days_ago
WHERE k.refresh_frequency IN ('hourly', 'daily', 'realtime');

-- Change columns derived from the series, so they cannot disagree with it.
UPDATE kpi_values cur
JOIN kpi_values prev
  ON prev.kpi_id = cur.kpi_id
 AND prev.period_type = cur.period_type
 AND prev.tenant_id <=> cur.tenant_id
 AND prev.period_start = DATE_SUB(cur.period_start, INTERVAL 1 DAY)
SET cur.previous_value = prev.value,
    cur.change_absolute = ROUND(cur.value - prev.value, 6),
    cur.change_percent = CASE WHEN prev.value <> 0
                              THEN ROUND((cur.value - prev.value) / prev.value * 100, 4) END;

-- Monthly values for the metrics that only make sense monthly.
INSERT INTO kpi_values
  (kpi_id, period_type, period_start, tenant_id, value, sample_size,
   is_provisional, computed_at)
SELECT
  k.id, 'month',
  DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL m.n MONTH), '%Y-%m-01'),
  t.id,
  ROUND(
    (CASE k.unit
      WHEN 'percent'  THEN (2 + MOD(CONV(SUBSTRING(MD5(CONCAT('mbase:', k.code)), 1, 4), 16, 10), 40)) / 100
      WHEN 'ratio'    THEN (30 + MOD(CONV(SUBSTRING(MD5(CONCAT('mbase:', k.code)), 1, 4), 16, 10), 300)) / 100
      WHEN 'currency' THEN 120000 + MOD(CONV(SUBSTRING(MD5(CONCAT('mbase:', k.code)), 1, 5), 16, 10), 900000)
      ELSE 800 + MOD(CONV(SUBSTRING(MD5(CONCAT('mbase:', k.code)), 1, 5), 16, 10), 40000)
    END)
    -- Monthly series trend upward the further forward you come.
    * POW(1.028, 23 - m.n)
    * (0.96 + MOD(CONV(SUBSTRING(MD5(CONCAT('mnoise:', k.code, ':', m.n)), 1, 4), 16, 10), 9) / 100)
  , 6),
  NULL,
  CASE WHEN m.n = 0 THEN 1 ELSE 0 END,
  @now
FROM kpi_definitions k
CROSS JOIN (SELECT n FROM tmp_seq WHERE n < 24) AS m
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t
WHERE k.refresh_frequency IN ('monthly', 'weekly')
   OR k.category = 'revenue';

UPDATE kpi_values cur
JOIN kpi_values prev
  ON prev.kpi_id = cur.kpi_id AND prev.period_type = 'month'
 AND prev.tenant_id <=> cur.tenant_id
 AND prev.period_start = DATE_SUB(cur.period_start, INTERVAL 1 MONTH)
SET cur.previous_value = prev.value,
    cur.change_absolute = ROUND(cur.value - prev.value, 6),
    cur.change_percent = CASE WHEN prev.value <> 0
                              THEN ROUND((cur.value - prev.value) / prev.value * 100, 4) END
WHERE cur.period_type = 'month';

UPDATE kpi_values cur
JOIN kpi_values prev
  ON prev.kpi_id = cur.kpi_id AND prev.period_type = 'month'
 AND prev.tenant_id <=> cur.tenant_id
 AND prev.period_start = DATE_SUB(cur.period_start, INTERVAL 12 MONTH)
SET cur.yoy_change_percent = CASE WHEN prev.value <> 0
                                  THEN ROUND((cur.value - prev.value) / prev.value * 100, 4) END
WHERE cur.period_type = 'month';

-- Targets for the four quarters of the current financial year, evaluated
-- against the actuals where the period has closed.
INSERT INTO kpi_targets
  (kpi_id, period_type, period_start, tenant_id, target_value, stretch_value,
   minimum_value, rationale, status, achieved_value, achievement_percent,
   evaluated_at)
SELECT
  k.id, 'quarter',
  MAKEDATE(YEAR(@today), 1) + INTERVAL (q.n * 3) MONTH,
  t.id,
  ROUND(base.v * 1.15, 6),
  ROUND(base.v * 1.32, 6),
  ROUND(base.v * 1.02, 6),
  CONCAT('Set from the trailing quarter actual of ', ROUND(base.v, 2),
         ' plus the fifteen per cent the annual plan commits to. Stretch is the number the bonus pool pays out at.'),
  CASE
    WHEN MAKEDATE(YEAR(@today), 1) + INTERVAL (q.n * 3) MONTH > @today THEN 'committed'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('target:', k.code, q.n)), 1, 4), 16, 10), 3) = 0 THEN 'missed'
    ELSE 'achieved'
  END,
  CASE WHEN MAKEDATE(YEAR(@today), 1) + INTERVAL (q.n * 3) MONTH <= @today
       THEN ROUND(base.v * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('ach:', k.code, q.n)), 1, 4), 16, 10), 40) / 100), 6) END,
  CASE WHEN MAKEDATE(YEAR(@today), 1) + INTERVAL (q.n * 3) MONTH <= @today
       THEN ROUND((0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('ach:', k.code, q.n)), 1, 4), 16, 10), 40) / 100)
                  / 1.15 * 100, 4) END,
  CASE WHEN MAKEDATE(YEAR(@today), 1) + INTERVAL (q.n * 3) MONTH <= @today THEN @now END
FROM kpi_definitions k
CROSS JOIN (SELECT n FROM tmp_seq WHERE n < 4) AS q
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t
JOIN (
  SELECT kv.kpi_id, AVG(kv.value) AS v
  FROM kpi_values kv
  WHERE kv.period_type = 'day'
  GROUP BY kv.kpi_id
) AS base ON base.kpi_id = k.id
WHERE k.direction <> 'neutral';

-- -----------------------------------------------------------------------------
-- Metric alerts and anomalies
--
-- The alert is the rule; the anomaly is what the rule found. Keeping them apart
-- means an alert can be retuned without losing the history of what it caught,
-- and an anomaly can be marked a false positive without deleting the evidence.
-- -----------------------------------------------------------------------------
INSERT INTO metric_alerts
  (kpi_id, name, alert_type, comparison, threshold_value, threshold_upper,
   change_percent_threshold, consecutive_periods, evaluation_period, severity,
   notify_channels, cooldown_minutes, is_active, last_fired_at, fire_count)
SELECT
  k.id, a.name, a.alert_type, a.comparison, a.threshold_value, a.threshold_upper,
  a.change_percent_threshold, a.consecutive_periods, a.evaluation_period,
  a.severity, a.notify_channels, a.cooldown_minutes, 1,
  CASE WHEN a.fire_count > 0
       THEN DATE_SUB(@now, INTERVAL 2 + MOD(CONV(SUBSTRING(MD5(CONCAT('fired:', a.name)), 1, 4), 16, 10), 200) HOUR) END,
  a.fire_count
FROM (
  SELECT 'sessions' AS kpi_code, 'Traffic collapse' AS name, 'change_percent' AS alert_type, 'changes_by' AS comparison, NULL AS threshold_value, NULL AS threshold_upper, -30.000 AS change_percent_threshold, 1 AS consecutive_periods, 'hour' AS evaluation_period, 'critical' AS severity, 'email,slack,pagerduty' AS notify_channels, 30 AS cooldown_minutes, 3 AS fire_count
  UNION ALL SELECT 'sessions','Traffic spike — possible scraping','change_percent','changes_by',NULL,NULL,180.000,1,'hour','warning','email,slack',60,7
  UNION ALL SELECT 'payment_success_rate','Payment authorisation rate below floor','threshold','below',0.850000,NULL,NULL,2,'hour','critical','email,slack,pagerduty',15,2
  UNION ALL SELECT 'inquiry_conversion_rate','Enquiry conversion rate degraded','change_percent','changes_by',NULL,NULL,-20.000,3,'day','warning','email,slack',240,4
  UNION ALL SELECT 'first_response_minutes','Agent response time above target','threshold','above',120.000000,NULL,NULL,2,'day','warning','email,in_app',720,11
  UNION ALL SELECT 'sla_breach_rate','SLA breach rate above contract','threshold','above',0.100000,NULL,NULL,1,'day','critical','email,slack',360,5
  UNION ALL SELECT 'listing_moderation_backlog','Moderation queue backing up','threshold','above',250.000000,NULL,NULL,1,'hour','warning','email,in_app,slack',120,9
  UNION ALL SELECT 'active_listings','Inventory dropped sharply','change_percent','changes_by',NULL,NULL,-8.000,1,'day','critical','email,slack',180,1
  UNION ALL SELECT 'mrr','Recurring revenue fell','change_percent','changes_by',NULL,NULL,-3.000,1,'month','critical','email,slack',1440,0
  UNION ALL SELECT 'gross_churn_rate','Churn above plan','threshold','above',0.045000,NULL,NULL,1,'month','warning','email',1440,2
  UNION ALL SELECT 'return_on_ad_spend','Return on ad spend below break-even','threshold','below',1.500000,NULL,NULL,3,'day','warning','email,slack',480,6
  UNION ALL SELECT 'bounce_rate','Bounce rate outside normal band','anomaly','outside_range',0.250000,0.480000,NULL,1,'day','info','email',720,14
  UNION ALL SELECT 'listing_quality_score','Listing quality deteriorating','threshold','below',62.000000,NULL,NULL,3,'day','warning','email,in_app',1440,3
  UNION ALL SELECT 'kyc_clearance_rate','KYC clearance rate dropped','threshold','below',0.700000,NULL,NULL,1,'week','warning','email',10080,1
  UNION ALL SELECT 'dsr_within_deadline','Subject requests at risk of breaching the statutory deadline','threshold','below',1.000000,NULL,NULL,1,'week','critical','email,slack',1440,2
  UNION ALL SELECT 'organic_share','Organic share falling','trend','below',0.400000,NULL,NULL,7,'day','info','email',10080,0
  UNION ALL SELECT 'sessions','No data received from the analytics pipeline','no_data','below',NULL,NULL,NULL,1,'hour','critical','email,slack,pagerduty',20,4
) AS a
JOIN kpi_definitions k ON k.code = a.kpi_code;

INSERT INTO metric_anomalies
  (alert_id, kpi_id, metric_name, detected_at, period_start, observed_value,
   expected_value, expected_lower, expected_upper, deviation_percent, z_score,
   severity, direction, tenant_id, status, acknowledged_by_user_id,
   acknowledged_at, explanation, resolved_at)
SELECT
  al.id, al.kpi_id, k.name,
  DATE_SUB(@now, INTERVAL n.n * 6 + 3 HOUR),
  DATE(DATE_SUB(@now, INTERVAL n.n * 6 + 3 HOUR)),
  ROUND(base.v * dev.factor, 6),
  ROUND(base.v, 6),
  ROUND(base.v * 0.82, 6),
  ROUND(base.v * 1.18, 6),
  ROUND((dev.factor - 1) * 100, 4),
  ROUND((dev.factor - 1) / 0.09, 4),
  al.severity,
  CASE WHEN dev.factor >= 1 THEN 'spike' ELSE 'drop' END,
  (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  st.status,
  CASE WHEN st.status <> 'new' THEN 1 + MOD(n.n, 5) END,
  CASE WHEN st.status <> 'new' THEN DATE_SUB(@now, INTERVAL n.n * 6 HOUR) END,
  st.explanation,
  CASE WHEN st.status IN ('resolved', 'false_positive', 'explained')
       THEN DATE_SUB(@now, INTERVAL CAST(n.n AS SIGNED) * 6 - 2 HOUR) END
FROM metric_alerts al
JOIN kpi_definitions k ON k.id = al.kpi_id
JOIN (SELECT n FROM tmp_seq WHERE n < 4) AS n
JOIN (
  SELECT al2.id AS alert_id, n2.n AS seq,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('dir:', al2.id, n2.n)), 1, 4), 16, 10), 2) = 0
              THEN 1 + (20 + MOD(CONV(SUBSTRING(MD5(CONCAT('mag:', al2.id, n2.n)), 1, 4), 16, 10), 90)) / 100
              ELSE 1 - (18 + MOD(CONV(SUBSTRING(MD5(CONCAT('mag:', al2.id, n2.n)), 1, 4), 16, 10), 45)) / 100
         END AS factor
  FROM metric_alerts al2 CROSS JOIN (SELECT n FROM tmp_seq WHERE n < 4) AS n2
) AS dev ON dev.alert_id = al.id AND dev.seq = n.n
JOIN (
  SELECT al3.id AS alert_id, n3.n AS seq,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('anstat:', al3.id, n3.n)), 1, 4), 16, 10), 6),
             'resolved','explained','false_positive','acknowledged','investigating','new') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('anstat:', al3.id, n3.n)), 1, 4), 16, 10), 6),
             'Caused by the search index rebuild that ran outside its window. The window has been moved and an alert added on index age.',
             'Ramadan seasonality in the Gulf markets. Expected, and now part of the baseline the detector compares against.',
             'A single bot network that the classifier had not yet seen. Reclassified retrospectively and the affected sessions excluded.',
             'Under investigation with the payments team; correlates with one acquirer''s corridor rather than with our own deploys.',
             'Coincides with a competitor''s national television campaign. Watching rather than acting.',
             NULL) AS explanation
  FROM metric_alerts al3 CROSS JOIN (SELECT n FROM tmp_seq WHERE n < 4) AS n3
) AS st ON st.alert_id = al.id AND st.seq = n.n
JOIN (
  SELECT kv.kpi_id, AVG(kv.value) AS v FROM kpi_values kv
  WHERE kv.period_type = 'day' GROUP BY kv.kpi_id
) AS base ON base.kpi_id = al.kpi_id
WHERE al.fire_count > 0
  AND n.n < LEAST(al.fire_count, 4);

-- -----------------------------------------------------------------------------
-- Dashboards
--
-- System dashboards per audience, so an agency principal, a finance controller
-- and a compliance officer each land on a page built for the questions they
-- actually have rather than on one page with everything on it.
-- -----------------------------------------------------------------------------
INSERT INTO dashboards
  (public_id, slug, name, description, audience, tenant_id, layout,
   default_filters, refresh_minutes, is_system, is_default, is_public,
   view_count, last_viewed_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('dashboard:', d.slug)), 26)),
  d.slug, d.name, d.description, d.audience, t.id,
  JSON_OBJECT('columns', 12, 'row_height', 80, 'gap', 16),
  d.default_filters, d.refresh_minutes, 1, d.is_default, 0,
  MOD(CONV(SUBSTRING(MD5(CONCAT('views:', d.slug)), 1, 5), 16, 10), 9000),
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('seen:', d.slug)), 1, 4), 16, 10), 72) HOUR)
FROM (
  SELECT 'executive-overview' AS slug, 'Executive overview' AS name,
         'The board pack, on one page: north-star metrics, recurring revenue, inventory and the acquisition mix.' AS description,
         'executive' AS audience, '{"period":"last_90_days","tenant":"all"}' AS default_filters, 60 AS refresh_minutes, 1 AS is_default
  UNION ALL SELECT 'marketplace-health','Marketplace health',
         'Supply and demand side by side. The pairing is the point: listings without enquiries and enquiries without listings are both failures, and neither is visible on its own chart.',
         'platform_admin','{"period":"last_30_days"}',15,0
  UNION ALL SELECT 'acquisition','Acquisition and attribution',
         'Channel performance under every attribution model, with the model as a filter rather than a footnote.',
         'marketing','{"period":"last_30_days","model":"last_non_direct"}',60,0
  UNION ALL SELECT 'agency-performance','Agency performance',
         'What an agency principal sees: their listings, their enquiries, their response times, their spend, and where they sit against the market.',
         'agency','{"period":"last_30_days"}',30,0
  UNION ALL SELECT 'agent-daily','My day',
         'The agent view. New enquiries, viewings booked, follow-ups due and anything about to breach its response window.',
         'agent','{"period":"today"}',5,0
  UNION ALL SELECT 'revenue','Revenue and billing',
         'Recognised revenue, recurring revenue, collections and ageing. Reconciles to the ledger by construction, not by hope.',
         'finance','{"period":"current_quarter"}',240,0
  UNION ALL SELECT 'developer-projects','Developer projects',
         'For developer accounts: project pipeline, unit absorption, payment-plan take-up and enquiry quality by project.',
         'developer','{"period":"last_90_days"}',120,0
  UNION ALL SELECT 'compliance','Compliance and risk',
         'Permit expiries, KYC ageing, sanctions screening exceptions, subject requests against their statutory clock and the open legal holds.',
         'compliance','{"period":"last_30_days"}',60,0
  UNION ALL SELECT 'operations','Platform operations',
         'Queue depth, dead letters, failed webhooks, circuit-breaker state and the freshness of every feed import.',
         'platform_admin','{"period":"last_24_hours"}',5,0
) AS d
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t;

INSERT INTO dashboard_widgets
  (dashboard_id, title, widget_type, kpi_id, funnel_id, cohort_id, source_query,
   position_x, position_y, width, height, config, comparison_period, sort_order,
   is_visible)
SELECT
  db.id, w.title, w.widget_type, k.id, fn.id, ch.id,
  -- A widget with no KPI behind it renders from its own query. Recording that
  -- query is what keeps the dashboard from having an unexplainable tile on it.
  CASE WHEN k.id IS NULL AND fn.id IS NULL AND ch.id IS NULL
       THEN CONCAT('-- bespoke widget: ', w.title) END,
  w.position_x, w.position_y, w.width, w.height,
  JSON_OBJECT('show_sparkline', w.widget_type = 'metric',
              'decimals', COALESCE(k.decimals, 0),
              'unit', COALESCE(k.unit, 'count')),
  w.comparison_period, w.sort_order, 1
FROM (
  SELECT 'executive-overview' AS dash, 'Enquiries per active listing' AS title, 'metric' AS widget_type, 'leads_per_listing' AS kpi_code, NULL AS funnel_code, NULL AS cohort_code, 0 AS position_x, 0 AS position_y, 3 AS width, 2 AS height, 'previous_period' AS comparison_period, 1 AS sort_order
  UNION ALL SELECT 'executive-overview','Monthly recurring revenue','metric','mrr',NULL,NULL,3,0,3,2,'target',2
  UNION ALL SELECT 'executive-overview','Active listings','metric','active_listings',NULL,NULL,6,0,3,2,'previous_period',3
  UNION ALL SELECT 'executive-overview','Sessions','metric','sessions',NULL,NULL,9,0,3,2,'previous_year',4
  UNION ALL SELECT 'executive-overview','Recurring revenue trend','line_chart','mrr',NULL,NULL,0,2,6,4,'previous_year',5
  UNION ALL SELECT 'executive-overview','Acquisition mix','pie_chart','sessions',NULL,NULL,6,2,6,4,'none',6
  UNION ALL SELECT 'executive-overview','Subscription retention','cohort_grid',NULL,NULL,'agency_subscription',0,6,12,5,'none',7
  UNION ALL SELECT 'marketplace-health','Active listings','metric','active_listings',NULL,NULL,0,0,3,2,'previous_period',1
  UNION ALL SELECT 'marketplace-health','New listings','metric','new_listings',NULL,NULL,3,0,3,2,'previous_period',2
  UNION ALL SELECT 'marketplace-health','Enquiries','metric','inquiries',NULL,NULL,6,0,3,2,'previous_period',3
  UNION ALL SELECT 'marketplace-health','Median listing quality','metric','listing_quality_score',NULL,NULL,9,0,3,2,'target',4
  UNION ALL SELECT 'marketplace-health','Search to enquiry','funnel',NULL,'search_to_inquiry',NULL,0,2,6,5,'previous_period',5
  UNION ALL SELECT 'marketplace-health','Enquiries by community','map','inquiries',NULL,NULL,6,2,6,5,'none',6
  UNION ALL SELECT 'marketplace-health','Moderation backlog','gauge','listing_moderation_backlog',NULL,NULL,0,7,4,3,'none',7
  UNION ALL SELECT 'acquisition','Sessions','metric','sessions',NULL,NULL,0,0,3,2,'previous_period',1
  UNION ALL SELECT 'acquisition','Organic share','metric','organic_share',NULL,NULL,3,0,3,2,'previous_year',2
  UNION ALL SELECT 'acquisition','Return on ad spend','metric','return_on_ad_spend',NULL,NULL,6,0,3,2,'target',3
  UNION ALL SELECT 'acquisition','Customer acquisition cost','metric','cac',NULL,NULL,9,0,3,2,'target',4
  UNION ALL SELECT 'acquisition','Channel performance','table','sessions',NULL,NULL,0,2,12,5,'previous_period',5
  UNION ALL SELECT 'acquisition','Landing to search','funnel',NULL,'landing_to_search',NULL,0,7,6,4,'none',6
  UNION ALL SELECT 'agency-performance','Enquiries','metric','inquiries',NULL,NULL,0,0,3,2,'previous_period',1
  UNION ALL SELECT 'agency-performance','Median response time','metric','first_response_minutes',NULL,NULL,3,0,3,2,'target',2
  UNION ALL SELECT 'agency-performance','SLA breach rate','metric','sla_breach_rate',NULL,NULL,6,0,3,2,'target',3
  UNION ALL SELECT 'agency-performance','Deal win rate','metric','deal_win_rate',NULL,NULL,9,0,3,2,'previous_period',4
  UNION ALL SELECT 'agency-performance','Listing performance','table','listing_views',NULL,NULL,0,2,12,6,'previous_period',5
  UNION ALL SELECT 'agent-daily','New enquiries today','metric','inquiries',NULL,NULL,0,0,4,2,'previous_period',1
  UNION ALL SELECT 'agent-daily','Response time','metric','first_response_minutes',NULL,NULL,4,0,4,2,'target',2
  UNION ALL SELECT 'agent-daily','Due today','list',NULL,NULL,NULL,0,2,6,5,'none',3
  UNION ALL SELECT 'agent-daily','Listing to contact','funnel',NULL,'listing_to_contact',NULL,6,2,6,5,'none',4
  UNION ALL SELECT 'revenue','Gross revenue','metric','gross_revenue',NULL,NULL,0,0,3,2,'previous_year',1
  UNION ALL SELECT 'revenue','Net revenue','metric','net_revenue',NULL,NULL,3,0,3,2,'previous_year',2
  UNION ALL SELECT 'revenue','Monthly recurring revenue','metric','mrr',NULL,NULL,6,0,3,2,'target',3
  UNION ALL SELECT 'revenue','Gross churn','metric','gross_churn_rate',NULL,NULL,9,0,3,2,'target',4
  UNION ALL SELECT 'revenue','Revenue by month','bar_chart','net_revenue',NULL,NULL,0,2,8,5,'previous_year',5
  UNION ALL SELECT 'revenue','Payment authorisation rate','line_chart','payment_success_rate',NULL,NULL,8,2,4,5,'previous_period',6
  UNION ALL SELECT 'revenue','Promotion checkout','funnel',NULL,'checkout',NULL,0,7,6,4,'none',7
  UNION ALL SELECT 'developer-projects','Active listings','metric','active_listings',NULL,NULL,0,0,4,2,'previous_period',1
  UNION ALL SELECT 'developer-projects','Enquiries','metric','inquiries',NULL,NULL,4,0,4,2,'previous_period',2
  UNION ALL SELECT 'developer-projects','Average days to close','metric','avg_days_to_close',NULL,NULL,8,0,4,2,'previous_period',3
  UNION ALL SELECT 'developer-projects','Unit absorption by project','table',NULL,NULL,NULL,0,2,12,6,'none',4
  UNION ALL SELECT 'compliance','KYC clearance rate','metric','kyc_clearance_rate',NULL,NULL,0,0,4,2,'target',1
  UNION ALL SELECT 'compliance','Subject requests within deadline','metric','dsr_within_deadline',NULL,NULL,4,0,4,2,'target',2
  UNION ALL SELECT 'compliance','Permits expiring in 30 days','metric',NULL,NULL,NULL,8,0,4,2,'none',3
  UNION ALL SELECT 'compliance','Screening exceptions','table',NULL,NULL,NULL,0,2,12,5,'none',4
  UNION ALL SELECT 'compliance','Open legal holds','list',NULL,NULL,NULL,0,7,6,4,'none',5
  UNION ALL SELECT 'operations','Payment authorisation rate','metric','payment_success_rate',NULL,NULL,0,0,4,2,'previous_period',1
  UNION ALL SELECT 'operations','Moderation backlog','metric','listing_moderation_backlog',NULL,NULL,4,0,4,2,'none',2
  UNION ALL SELECT 'operations','Queue depth','line_chart',NULL,NULL,NULL,0,2,6,4,'none',3
  UNION ALL SELECT 'operations','Dead letters','table',NULL,NULL,NULL,6,2,6,4,'none',4
  UNION ALL SELECT 'operations','Feed freshness','heatmap',NULL,NULL,NULL,0,6,12,4,'none',5
) AS w
JOIN dashboards db ON db.slug = w.dash
LEFT JOIN kpi_definitions k ON k.code = w.kpi_code
LEFT JOIN funnels fn ON fn.code = w.funnel_code
LEFT JOIN cohorts ch ON ch.code = w.cohort_code;

-- -----------------------------------------------------------------------------
-- Scheduled reports
--
-- Delivery is a first-class concern: a report that fails to send is an incident,
-- and run history with recipient and open counts is what turns "did anyone see
-- this" into a query.
-- -----------------------------------------------------------------------------
INSERT INTO scheduled_reports
  (public_id, name, description, dashboard_id, report_type, filters, format,
   schedule_cron, timezone, recipient_emails, tenant_id, skip_if_empty,
   is_active, last_run_at, next_run_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('report:', r.name)), 26)),
  r.name, r.description, db.id, r.report_type, r.filters, r.format,
  r.schedule_cron, r.timezone, r.recipient_emails, t.id, r.skip_if_empty, 1,
  DATE_SUB(@now, INTERVAL r.last_run_hours_ago HOUR),
  DATE_ADD(@now, INTERVAL r.next_run_hours HOUR)
FROM (
  SELECT 'Weekly executive summary' AS name,
         'Monday morning summary of the north-star metrics against target, with the week''s largest movements called out.' AS description,
         'executive-overview' AS dash, 'kpi_summary' AS report_type,
         '{"period":"last_7_days"}' AS filters, 'email_html' AS format,
         '0 6 * * 1' AS schedule_cron, 'Asia/Dubai' AS timezone,
         '["board@livfinder.com","leadership@livfinder.com"]' AS recipient_emails,
         0 AS skip_if_empty, 30 AS last_run_hours_ago, 138 AS next_run_hours
  UNION ALL SELECT 'Daily marketplace digest','Yesterday''s supply and demand, sent before the commercial stand-up.','marketplace-health','dashboard_snapshot','{"period":"yesterday"}','email_html','30 7 * * *','Asia/Dubai','["marketplace@livfinder.com"]',0,9,15
  UNION ALL SELECT 'Agency performance pack','Monthly per-agency performance, sent to each principal with their own numbers and their percentile against the market.','agency-performance','agent_performance','{"period":"last_month"}','pdf','0 9 1 * *','Asia/Dubai','[]',1,240,480
  UNION ALL SELECT 'Agent lead summary','Daily list of open enquiries and anything approaching its response deadline.',NULL,'lead_summary','{"period":"today","status":"open"}','email_html','0 8 * * 1-5','Asia/Dubai','[]',1,10,14
  UNION ALL SELECT 'Finance month end','Recognised revenue, deferred balance, collections and ageing, delivered as a workbook the controller can reconcile against the ledger.','revenue','financial','{"period":"last_month"}','excel','0 5 2 * *','Europe/London','["finance@livfinder.com","controller@livfinder.com"]',0,300,420
  UNION ALL SELECT 'Marketing attribution weekly','Channel performance under all four attribution models side by side, so the differences are the subject rather than a footnote.','acquisition','dashboard_snapshot','{"period":"last_7_days","model":"all"}','email_html','0 8 * * 1','Europe/London','["growth@livfinder.com"]',0,32,136
  UNION ALL SELECT 'Compliance exceptions','Permits inside thirty days of expiry, KYC cases past review, screening hits awaiting disposition and any subject request approaching its statutory deadline.','compliance','custom','{"period":"last_7_days"}','pdf','0 7 * * 1','Europe/London','["compliance@livfinder.com","legal@livfinder.com"]',0,33,135
  UNION ALL SELECT 'Developer project update','Per-project absorption, enquiry volume and payment-plan take-up for developer accounts.','developer-projects','portal_performance','{"period":"last_month"}','pdf','0 10 1 * *','Asia/Dubai','[]',1,250,470
  UNION ALL SELECT 'Listing performance for landlords','Views, enquiries and market position for each listing, sent to the instructing owner.',NULL,'listing_performance','{"period":"last_14_days"}','email_html','0 9 * * 3','Asia/Dubai','[]',1,60,108
  UNION ALL SELECT 'Platform operations hourly','Queue depth, dead letters and circuit-breaker state. Suppressed when there is nothing to say, which is most hours.','operations','dashboard_snapshot','{"period":"last_hour"}','email_html','0 * * * *','UTC','["oncall@livfinder.com"]',1,1,1
) AS r
LEFT JOIN dashboards db ON db.slug = r.dash
CROSS JOIN (SELECT id FROM tenants WHERE is_default = 1 LIMIT 1) AS t;

INSERT INTO report_runs
  (report_id, status, period_start, period_end, started_at, finished_at,
   duration_ms, row_count, output_size_bytes, recipients_count, delivered_count,
   opened_count, error_message, triggered_by, created_at)
SELECT
  r.id, run.status,
  DATE_SUB(DATE(run.started_at), INTERVAL 7 DAY),
  DATE_SUB(DATE(run.started_at), INTERVAL 1 DAY),
  run.started_at,
  CASE WHEN run.status <> 'running'
       THEN DATE_ADD(run.started_at, INTERVAL run.duration_ms / 1000 SECOND) END,
  CASE WHEN run.status <> 'running' THEN run.duration_ms END,
  CASE WHEN run.status = 'completed' THEN run.row_count END,
  CASE WHEN run.status = 'completed' THEN run.row_count * 480 END,
  run.recipients,
  CASE WHEN run.status = 'completed' THEN run.recipients ELSE 0 END,
  CASE WHEN run.status = 'completed'
       THEN ROUND(run.recipients * (0.35 + MOD(CONV(SUBSTRING(MD5(CONCAT('open:', r.id, run.seq)), 1, 4), 16, 10), 55) / 100))
       ELSE 0 END,
  CASE WHEN run.status = 'failed'
       THEN 'Query exceeded the report timeout of 120 seconds. The period was too wide after the retention job removed the partition the report still referenced.' END,
  'schedule',
  run.started_at
FROM scheduled_reports r
JOIN (
  SELECT r2.id AS report_id, n.n AS seq,
         DATE_SUB(@now, INTERVAL (n.n + 1) * 168 HOUR) AS started_at,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('runstat:', r2.id, n.n)), 1, 4), 16, 10), 10),
             'completed','completed','completed','completed','completed',
             'completed','completed','skipped_empty','failed','completed') AS status,
         900 + MOD(CONV(SUBSTRING(MD5(CONCAT('rundur:', r2.id, n.n)), 1, 5), 16, 10), 46000) AS duration_ms,
         20 + MOD(CONV(SUBSTRING(MD5(CONCAT('runrows:', r2.id, n.n)), 1, 5), 16, 10), 4000) AS row_count,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('runrcpt:', r2.id, n.n)), 1, 4), 16, 10), 40) AS recipients
  FROM scheduled_reports r2
  CROSS JOIN (SELECT n FROM tmp_seq WHERE n < 8) AS n
) AS run ON run.report_id = r.id;

DROP TABLE IF EXISTS tmp_seq;
