-- =============================================================================
-- 061_tenancy_governance.sql
--
-- Multi-tenant brand configuration and the data-governance record set.
--
-- Two subjects share this file because they share a spine: a tenant is the unit
-- a controller publishes under, and almost every governance record is scoped,
-- reported or audited per tenant. Splitting them would mean loading the same
-- joins twice.
--
-- The tenancy half is configuration, so it is written out literally. The
-- governance half is partly configuration (the registry, the rules, the ROPA)
-- and partly evidence derived from rows that already exist -- consent receipts
-- follow real users, erasure records follow real requests, field changes follow
-- real price history. Derived rows are hashed off their source id so a reload
-- reproduces the same database byte for byte.
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

-- -----------------------------------------------------------------------------
-- Tenants
--
-- The primary tenant owns the shared inventory pool. Regional tenants are
-- editorial front doors onto the same pool, differing only in default country,
-- language and currency. White-label tenants are the commercial product: a
-- brokerage runs its own domain over its own listings and the platform takes a
-- revenue share, which is why those rows carry a share percent and a contract
-- end date and the platform-owned ones do not.
-- -----------------------------------------------------------------------------
INSERT INTO tenants
  (code, public_id, name, legal_name, tenant_type, parent_tenant_id,
   owner_organization_id, inventory_scope, default_country_id, default_language_id,
   default_currency_code, supported_language_ids, supported_currency_codes,
   measurement_system, enabled_category_ids, revenue_share_percent, contract_ends_on,
   status, launched_at, is_default, is_indexable)
SELECT
  t.code,
  UPPER(LEFT(MD5(CONCAT('tenant:', t.code)), 26)),
  t.name, t.legal_name, t.tenant_type, NULL,
  o.id, t.inventory_scope,
  c.id, t.language_id, t.currency_code,
  t.language_ids, t.currency_codes,
  t.measurement_system, t.category_ids, t.revenue_share, t.contract_ends,
  t.status,
  CASE WHEN t.status = 'provisioning' THEN NULL
       ELSE TIMESTAMP(DATE_SUB(@today, INTERVAL t.launched_days_ago DAY), '09:00:00') END,
  t.is_default, t.is_indexable
FROM (
  SELECT 'global'          AS code, 'Liv Finder'                     AS name, 'Liv Finder Holdings Ltd'          AS legal_name, 'primary'     AS tenant_type, NULL              AS owner_slug, 'shared'       AS inventory_scope, 'United Arab Emirates' AS country_name, 1 AS language_id, 'USD' AS currency_code, '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]' AS language_ids, '["USD","EUR","GBP","AED","CHF","SGD","SAR","QAR"]' AS currency_codes, 'both'     AS measurement_system, '[1,2,3,4,5,6]' AS category_ids, NULL   AS revenue_share, NULL AS contract_ends, 'active' AS status, 1460 AS launched_days_ago, 1 AS is_default, 1 AS is_indexable
  UNION ALL SELECT 'mena',       'Liv Finder Middle East',        'Liv Finder Holdings Ltd',          'regional',    NULL,                            'shared',       'United Arab Emirates', 2,  'AED', '[1,2,3,8,12]',        '["AED","USD","SAR","QAR","EUR"]',       'metric',   '[1,2,3,4,5,6]', NULL,  NULL,                                      'active',  1180, 0, 1
  UNION ALL SELECT 'europe',     'Liv Finder Europe',             'Liv Finder Europe SARL',           'regional',    NULL,                            'shared',       'United Kingdom',       1,  'EUR', '[1,3,4,5,6,7,11,8]',  '["EUR","GBP","CHF","USD"]',             'metric',   '[1,2,3,4,5,6]', NULL,  NULL,                                      'active',  1180, 0, 1
  UNION ALL SELECT 'americas',   'Liv Finder Americas',           'Liv Finder Americas Inc',          'regional',    NULL,                            'shared',       'United States',        1,  'USD', '[1,5,7]',             '["USD","EUR"]',                          'imperial', '[1,2,3,4,5,6]', NULL,  NULL,                                      'active',  900,  0, 1
  UNION ALL SELECT 'apac',       'Liv Finder Asia Pacific',       'Liv Finder APAC Pte Ltd',          'regional',    NULL,                            'shared',       'Singapore',            1,  'SGD', '[1,9,13,14,15]',      '["SGD","USD","HKD","AUD"]',             'metric',   '[1,2,3,4,5,6]', NULL,  NULL,                                      'active',  620,  0, 1
  UNION ALL SELECT 'prime',      'The Prime Collection',          'Prime Properties LLC',             'white_label', 'prime-properties',              'own',          'United States',        1,  'USD', '[1,5]',               '["USD","EUR"]',                          'imperial', '[1]',           12.500, DATE_ADD(CURDATE(), INTERVAL 512 DAY),     'active',  760,  0, 1
  UNION ALL SELECT 'luxhabitat', 'Luxhabitat Private Office',     'Luxhabitat Real Estate Ltd',       'white_label', 'luxhabitat-real-estate',        'own',          'United Kingdom',       1,  'GBP', '[1,2,8]',             '["GBP","AED","USD"]',                    'metric',   '[1]',           10.000, DATE_ADD(CURDATE(), INTERVAL 290 DAY),     'active',  540,  0, 1
  UNION ALL SELECT 'knight',     'Knight Yachts Marketplace',     'Knight Yachts SAS',                'white_label', 'knight-yachts',                 'own',          'France',               3,  'EUR', '[1,3,6]',             '["EUR","USD"]',                          'metric',   '[3]',           9.000,  DATE_ADD(CURDATE(), INTERVAL 175 DAY),     'active',  430,  0, 1
  UNION ALL SELECT 'aurum',      'Aurum Aviation',                'Aurum Aviation Ltd',               'white_label', 'aurum-aviation',                'own',          'United Kingdom',       1,  'USD', '[1,4]',               '["USD","EUR","CHF"]',                    'imperial', '[4,5]',         8.500,  DATE_ADD(CURDATE(), INTERVAL 96 DAY),      'active',  300,  0, 1
  UNION ALL SELECT 'monaco',     'Monaco Riviera Partners',       'Riviera Partners Monaco SAM',      'partner',     NULL,                            'curated',      'Monaco',               3,  'EUR', '[1,3,6,8]',           '["EUR","CHF"]',                          'metric',   '[1,3]',         15.000, DATE_ADD(CURDATE(), INTERVAL 640 DAY),     'active',  210,  0, 1
  UNION ALL SELECT 'embed',      'Liv Finder Embedded Widgets',   'Liv Finder Holdings Ltd',          'embedded',    NULL,                            'partner_pool', 'United Arab Emirates', 1,  'USD', '[1,2]',               '["USD","AED"]',                          'metric',   '[1,2,3,4,5,6]', NULL,  NULL,                                      'active',  150,  0, 0
  UNION ALL SELECT 'staging',    'Liv Finder Staging',            'Liv Finder Holdings Ltd',          'staging',     NULL,                            'shared',       'United Arab Emirates', 1,  'USD', '[1]',                 '["USD"]',                                'metric',   '[1,2,3,4,5,6]', NULL,  NULL,                                      'provisioning', 0, 0, 0
) AS t
LEFT JOIN organizations o ON o.slug = t.owner_slug
LEFT JOIN locations c ON c.level = 'country' AND c.name = t.country_name;

-- Regional and derivative tenants hang off the primary one. Doing this as an
-- update keeps the insert above free of self-referencing lookups.
UPDATE tenants child
JOIN tenants root ON root.code = 'global'
SET child.parent_tenant_id = root.id
WHERE child.code <> 'global';

-- The owning account is the organization's account where there is one.
UPDATE tenants t
JOIN organizations o ON o.id = t.owner_organization_id
SET t.owner_account_id = o.account_id;

-- -----------------------------------------------------------------------------
-- Tenant domains
--
-- One canonical hostname per tenant, plus the legacy hostnames that redirect
-- into it. Redirects are rows rather than rewrite rules in a config file so the
-- routing layer can answer "where does this host go" with a single indexed
-- lookup, and so an expiring certificate is visible to the same monitoring that
-- watches everything else.
-- -----------------------------------------------------------------------------
INSERT INTO tenant_domains
  (tenant_id, hostname, is_canonical, is_primary, language_id, country_id,
   path_prefix, dns_verified, dns_verified_at, verification_token,
   ssl_status, ssl_issued_at, ssl_expires_at, status)
SELECT
  t.id, d.hostname, d.is_canonical, d.is_primary, d.language_id, c.id, d.path_prefix,
  1, DATE_SUB(@now, INTERVAL d.age_days DAY),
  LEFT(MD5(CONCAT('domain-verify:', d.hostname)), 32),
  'issued',
  DATE_SUB(@now, INTERVAL d.cert_age_days DAY),
  DATE_ADD(@now, INTERVAL (90 - d.cert_age_days) DAY),
  'active'
FROM (
  SELECT 'global' AS tenant_code, 'www.livfinder.com'        AS hostname, 1 AS is_canonical, 1 AS is_primary, 1    AS language_id, NULL AS country_name, NULL AS path_prefix, 1460 AS age_days, 12 AS cert_age_days
  UNION ALL SELECT 'global',     'ar.livfinder.com',          0, 0, 2,    NULL,                   NULL,   1100, 12
  UNION ALL SELECT 'global',     'fr.livfinder.com',          0, 0, 3,    NULL,                   NULL,   1100, 12
  UNION ALL SELECT 'global',     'zh.livfinder.com',          0, 0, 9,    NULL,                   NULL,   700,  12
  UNION ALL SELECT 'mena',       'www.livfinder.ae',          1, 1, 2,    'United Arab Emirates', NULL,   1180, 34
  UNION ALL SELECT 'mena',       'www.livfinder.sa',          0, 0, 2,    'Saudi Arabia',         NULL,   860,  34
  UNION ALL SELECT 'mena',       'www.livfinder.qa',          0, 0, 2,    'Qatar',                NULL,   640,  34
  UNION ALL SELECT 'europe',     'www.livfinder.eu',          1, 1, 1,    NULL,                   NULL,   1180, 51
  UNION ALL SELECT 'europe',     'www.livfinder.co.uk',       0, 0, 1,    'United Kingdom',       NULL,   1180, 51
  UNION ALL SELECT 'europe',     'www.livfinder.fr',          0, 0, 3,    'France',               NULL,   980,  51
  UNION ALL SELECT 'europe',     'www.livfinder.it',          0, 0, 6,    'Italy',                NULL,   760,  51
  UNION ALL SELECT 'europe',     'www.livfinder.es',          0, 0, 5,    'Spain',                NULL,   760,  51
  UNION ALL SELECT 'americas',   'www.livfinder.us',          1, 1, 1,    'United States',        NULL,   900,  18
  UNION ALL SELECT 'apac',       'www.livfinder.sg',          1, 1, 1,    'Singapore',            NULL,   620,  60
  UNION ALL SELECT 'apac',       'www.livfinder.hk',          0, 0, 9,    NULL,                   NULL,   400,  60
  UNION ALL SELECT 'prime',      'collection.primeproperties.com', 1, 1, 1, 'United States',      NULL,   760,  22
  UNION ALL SELECT 'luxhabitat', 'private.luxhabitat.com',    1, 1, 1,    'United Kingdom',       NULL,   540,  41
  UNION ALL SELECT 'luxhabitat', 'ar.luxhabitat.com',         0, 0, 2,    NULL,                   NULL,   300,  41
  UNION ALL SELECT 'knight',     'market.knightyachts.fr',    1, 1, 3,    'France',               NULL,   430,  9
  UNION ALL SELECT 'aurum',      'jets.aurumaviation.com',    1, 1, 1,    'United Kingdom',       NULL,   300,  73
  UNION ALL SELECT 'monaco',     'www.rivierapartners.mc',    1, 1, 3,    'Monaco',               NULL,   210,  30
  UNION ALL SELECT 'embed',      'widgets.livfinder.com',     1, 1, 1,    NULL,                   NULL,   150,  12
  UNION ALL SELECT 'staging',    'staging.livfinder.com',     1, 1, 1,    NULL,                   NULL,   30,   30
) AS d
JOIN tenants t ON t.code = d.tenant_code
LEFT JOIN locations c ON c.level = 'country' AND c.name = d.country_name;

-- Retired hostnames that still receive traffic. They are kept as rows, not
-- deleted, because a 301 that disappears costs the accumulated link equity that
-- the SEO layer spent two years earning.
INSERT INTO tenant_domains
  (tenant_id, hostname, is_canonical, is_primary, redirects_to_domain_id,
   redirect_status, dns_verified, dns_verified_at, ssl_status, ssl_issued_at,
   ssl_expires_at, status)
SELECT
  t.id, r.hostname, 0, 0, canon.id, 301, 1,
  DATE_SUB(@now, INTERVAL 1000 DAY), 'issued',
  DATE_SUB(@now, INTERVAL 20 DAY), DATE_ADD(@now, INTERVAL 70 DAY), 'active'
FROM (
  SELECT 'global' AS tenant_code, 'livfinder.com'          AS hostname, 'www.livfinder.com' AS canonical_host
  UNION ALL SELECT 'global',      'livfinder.net',          'www.livfinder.com'
  UNION ALL SELECT 'mena',        'livfinder.ae',           'www.livfinder.ae'
  UNION ALL SELECT 'europe',      'livfinder.co.uk',        'www.livfinder.eu'
  UNION ALL SELECT 'americas',    'livfinder.us',           'www.livfinder.us'
  UNION ALL SELECT 'prime',       'primecollection.com',    'collection.primeproperties.com'
) AS r
JOIN tenants t ON t.code = r.tenant_code
JOIN tenant_domains canon ON canon.hostname = r.canonical_host;

-- -----------------------------------------------------------------------------
-- Tenant settings
--
-- Key/value rather than a wide table: every white-label deal negotiates one or
-- two settings nobody else uses, and a column per negotiation would leave the
-- table mostly NULL within a year. is_public marks what the front end may read
-- without authentication; is_overridden distinguishes a deliberate tenant choice
-- from a value that merely happens to match the platform default.
-- -----------------------------------------------------------------------------

-- Every tenant gets the baseline set, valued off its own configuration so the
-- brand colour, contact address and title template are coherent per tenant.
INSERT INTO tenant_settings
  (tenant_id, setting_group, setting_key, setting_value, value_type, is_public, is_overridden)
SELECT t.id, s.setting_group, s.setting_key,
  REPLACE(REPLACE(REPLACE(s.template, '{code}', t.code), '{name}', t.name), '{host}',
          COALESCE((SELECT d.hostname FROM tenant_domains d
                    WHERE d.tenant_id = t.id AND d.is_canonical = 1 LIMIT 1),
                   'www.livfinder.com')),
  s.value_type, s.is_public,
  CASE WHEN t.tenant_type IN ('white_label','partner') THEN 1 ELSE 0 END
FROM tenants t
CROSS JOIN (
  SELECT 'branding'     AS setting_group, 'logo_url'                AS setting_key, 'https://cdn.livfinder.com/brand/{code}/logo.svg'      AS template, 'url'     AS value_type, 1 AS is_public
  UNION ALL SELECT 'branding',  'logo_dark_url',           'https://cdn.livfinder.com/brand/{code}/logo-dark.svg', 'url',     1
  UNION ALL SELECT 'branding',  'favicon_url',             'https://cdn.livfinder.com/brand/{code}/favicon.ico',   'url',     1
  UNION ALL SELECT 'branding',  'brand_name',              '{name}',                                                'string',  1
  UNION ALL SELECT 'theme',     'font_family_heading',     'Canela Deck, Georgia, serif',                           'string',  1
  UNION ALL SELECT 'theme',     'font_family_body',        'Inter, Helvetica Neue, sans-serif',                     'string',  1
  UNION ALL SELECT 'theme',     'border_radius_px',        '2',                                                     'integer', 1
  UNION ALL SELECT 'seo',       'title_template',          '%s | {name}',                                           'string',  1
  UNION ALL SELECT 'seo',       'default_og_image',        'https://cdn.livfinder.com/brand/{code}/og.jpg',         'url',     1
  UNION ALL SELECT 'seo',       'robots_default',          'index,follow',                                          'string',  1
  UNION ALL SELECT 'contact',   'support_email',           'support@{host}',                                        'string',  1
  UNION ALL SELECT 'contact',   'press_email',             'press@{host}',                                          'string',  1
  UNION ALL SELECT 'legal',     'terms_url',               'https://{host}/legal/terms',                            'url',     1
  UNION ALL SELECT 'legal',     'privacy_url',             'https://{host}/legal/privacy',                          'url',     1
  UNION ALL SELECT 'legal',     'cookie_policy_url',       'https://{host}/legal/cookies',                          'url',     1
  UNION ALL SELECT 'features',  'saved_searches_enabled',  'true',                                                  'boolean', 1
  UNION ALL SELECT 'features',  'price_history_visible',   'true',                                                  'boolean', 1
  UNION ALL SELECT 'features',  'mortgage_calculator',     'true',                                                  'boolean', 1
  UNION ALL SELECT 'search',    'results_per_page',        '24',                                                    'integer', 1
  UNION ALL SELECT 'search',    'default_sort',            'relevance',                                             'string',  1
  UNION ALL SELECT 'listing',   'enquiry_form_fields',     '["name","email","phone","message"]',                    'json',    1
  UNION ALL SELECT 'listing',   'show_agent_direct_phone', 'true',                                                  'boolean', 1
  UNION ALL SELECT 'email',     'from_name',               '{name}',                                                'string',  0
  UNION ALL SELECT 'email',     'from_address',            'no-reply@{host}',                                       'string',  0
  UNION ALL SELECT 'analytics', 'ga4_measurement_id',      'G-{code}0000000',                                       'string',  0
  UNION ALL SELECT 'commerce',  'invoice_prefix',          'LF-{code}',                                             'string',  0
) AS s;

-- Brand colours differ per tenant, so they are stated per tenant rather than
-- templated from the code.
INSERT INTO tenant_settings
  (tenant_id, setting_group, setting_key, setting_value, value_type, is_public, is_overridden)
SELECT t.id, 'theme', p.setting_key, p.setting_value, 'colour', 1, 1
FROM (
  SELECT 'global'  AS tenant_code, 'colour_primary'   AS setting_key, '#0B1F3A' AS setting_value
  UNION ALL SELECT 'global',       'colour_accent',    '#C9A227'
  UNION ALL SELECT 'mena',         'colour_primary',   '#12433A'
  UNION ALL SELECT 'mena',         'colour_accent',    '#C9A227'
  UNION ALL SELECT 'europe',       'colour_primary',   '#1A1A1A'
  UNION ALL SELECT 'europe',       'colour_accent',    '#8C7853'
  UNION ALL SELECT 'americas',     'colour_primary',   '#12263F'
  UNION ALL SELECT 'americas',     'colour_accent',    '#B08D57'
  UNION ALL SELECT 'apac',         'colour_primary',   '#2B1B2E'
  UNION ALL SELECT 'apac',         'colour_accent',    '#D4AF37'
  UNION ALL SELECT 'prime',        'colour_primary',   '#000000'
  UNION ALL SELECT 'prime',        'colour_accent',    '#D9C7A3'
  UNION ALL SELECT 'luxhabitat',   'colour_primary',   '#14213D'
  UNION ALL SELECT 'luxhabitat',   'colour_accent',    '#FCA311'
  UNION ALL SELECT 'knight',       'colour_primary',   '#003049'
  UNION ALL SELECT 'knight',       'colour_accent',    '#EAE2B7'
  UNION ALL SELECT 'aurum',        'colour_primary',   '#1C1C1C'
  UNION ALL SELECT 'aurum',        'colour_accent',    '#C5A253'
  UNION ALL SELECT 'monaco',       'colour_primary',   '#7B1E3A'
  UNION ALL SELECT 'monaco',       'colour_accent',    '#E8D5B7'
  UNION ALL SELECT 'embed',        'colour_primary',   '#0B1F3A'
  UNION ALL SELECT 'embed',        'colour_accent',    '#C9A227'
  UNION ALL SELECT 'staging',      'colour_primary',   '#7A0F0F'
  UNION ALL SELECT 'staging',      'colour_accent',    '#FFD166'
) AS p
JOIN tenants t ON t.code = p.tenant_code;

-- Settings that only some tenants carry: the white-label contracts and the
-- staging environment's suppressions.
INSERT INTO tenant_settings
  (tenant_id, setting_group, setting_key, setting_value, value_type, is_public, is_overridden)
SELECT t.id, x.setting_group, x.setting_key, x.setting_value, x.value_type, x.is_public, 1
FROM (
  SELECT 'prime'      AS tenant_code, 'listing'      AS setting_group, 'min_display_price_usd' AS setting_key, '2500000'                         AS setting_value, 'integer' AS value_type, 0 AS is_public
  UNION ALL SELECT 'prime',      'features',     'show_platform_credit',   'false',                                 'boolean', 1
  UNION ALL SELECT 'luxhabitat', 'listing',      'min_display_price_usd',  '1000000',                               'integer', 0
  UNION ALL SELECT 'luxhabitat', 'integrations', 'crm_webhook_url',        'https://private.luxhabitat.com/hooks/leads', 'url', 0
  UNION ALL SELECT 'knight',     'listing',      'length_unit',            'metres',                                'string',  1
  UNION ALL SELECT 'aurum',      'listing',      'range_unit',             'nautical_miles',                        'string',  1
  UNION ALL SELECT 'aurum',      'features',     'charter_quote_enabled',  'true',                                  'boolean', 1
  UNION ALL SELECT 'monaco',     'features',     'invitation_only',        'true',                                  'boolean', 1
  UNION ALL SELECT 'monaco',     'listing',      'hide_exact_address',     'true',                                  'boolean', 1
  UNION ALL SELECT 'embed',      'features',     'saved_searches_enabled', 'false',                                 'boolean', 1
  UNION ALL SELECT 'embed',      'seo',          'robots_default',         'noindex,nofollow',                      'string',  1
  UNION ALL SELECT 'staging',    'email',        'suppress_all_outbound',  'true',                                  'boolean', 0
  UNION ALL SELECT 'staging',    'seo',          'robots_default',         'noindex,nofollow',                      'string',  1
) AS x
JOIN tenants t ON t.code = x.tenant_code
ON DUPLICATE KEY UPDATE
  setting_value = VALUES(setting_value),
  value_type    = VALUES(value_type),
  is_public     = VALUES(is_public),
  is_overridden = 1;

-- -----------------------------------------------------------------------------
-- Tenant visibility rules
--
-- Evaluated highest priority first; an exclude beats an include at the same
-- priority. A white-label tenant is expressed as one include on its own
-- organization, which is why the rule set stays this small even though the
-- inventory pool is shared.
-- -----------------------------------------------------------------------------
INSERT INTO tenant_visibility_rules
  (tenant_id, rule_type, dimension, value_ids, min_price_base, max_price_base,
   priority, is_active, notes)
SELECT t.id, 'include', 'organization',
  CONCAT('[', o.id, ']'), NULL, NULL, 10, 1,
  'White-label site shows only its own inventory.'
FROM tenants t
JOIN organizations o ON o.id = t.owner_organization_id
WHERE t.tenant_type = 'white_label';

INSERT INTO tenant_visibility_rules
  (tenant_id, rule_type, dimension, value_ids, min_price_base, max_price_base,
   priority, is_active, notes)
SELECT t.id, 'include', 'country', CONCAT('[', GROUP_CONCAT(c.id ORDER BY c.id), ']'),
  NULL, NULL, 20, 1, CONCAT('Geographic scope: ', t.name, '.')
FROM tenants t
JOIN (
  SELECT 'mena'     AS tenant_code, 'United Arab Emirates' AS country_name
  UNION ALL SELECT 'mena',     'Saudi Arabia'
  UNION ALL SELECT 'mena',     'Qatar'
  UNION ALL SELECT 'mena',     'Kuwait'
  UNION ALL SELECT 'mena',     'Bahrain'
  UNION ALL SELECT 'mena',     'Oman'
  UNION ALL SELECT 'mena',     'Egypt'
  UNION ALL SELECT 'europe',   'United Kingdom'
  UNION ALL SELECT 'europe',   'France'
  UNION ALL SELECT 'europe',   'Italy'
  UNION ALL SELECT 'europe',   'Spain'
  UNION ALL SELECT 'europe',   'Portugal'
  UNION ALL SELECT 'europe',   'Switzerland'
  UNION ALL SELECT 'europe',   'Monaco'
  UNION ALL SELECT 'europe',   'Germany'
  UNION ALL SELECT 'europe',   'Greece'
  UNION ALL SELECT 'europe',   'Netherlands'
  UNION ALL SELECT 'americas', 'United States'
  UNION ALL SELECT 'americas', 'Canada'
  UNION ALL SELECT 'americas', 'Mexico'
  UNION ALL SELECT 'americas', 'Brazil'
  UNION ALL SELECT 'americas', 'Bahamas'
  UNION ALL SELECT 'apac',     'Singapore'
  UNION ALL SELECT 'apac',     'Thailand'
  UNION ALL SELECT 'apac',     'Japan'
  UNION ALL SELECT 'apac',     'Australia'
  UNION ALL SELECT 'apac',     'Indonesia'
  UNION ALL SELECT 'apac',     'India'
  UNION ALL SELECT 'monaco',   'Monaco'
  UNION ALL SELECT 'monaco',   'France'
  UNION ALL SELECT 'monaco',   'Italy'
) AS r ON r.tenant_code = t.code
JOIN locations c ON c.level = 'country' AND c.name = r.country_name
GROUP BY t.id, t.name;

INSERT INTO tenant_visibility_rules
  (tenant_id, rule_type, dimension, value_ids, min_price_base, max_price_base,
   priority, is_active, notes)
SELECT t.id, v.rule_type, v.dimension, v.value_ids, v.min_price, v.max_price,
  v.priority, 1, v.notes
FROM (
  SELECT 'prime'  AS tenant_code, 'exclude' AS rule_type, 'price_band' AS dimension, NULL AS value_ids, 0 AS min_price, 2500000 AS max_price, 5 AS priority, 'Collection floor: nothing under USD 2.5m.' AS notes
  UNION ALL SELECT 'luxhabitat', 'exclude', 'price_band', NULL,      0, 1000000, 5,  'Private office floor: nothing under USD 1m.'
  UNION ALL SELECT 'knight',     'include', 'category',   '[3]',  NULL,    NULL, 15, 'Yachts only.'
  UNION ALL SELECT 'aurum',      'include', 'category',   '[4,5]',NULL,    NULL, 15, 'Jets and helicopters only.'
  UNION ALL SELECT 'prime',      'include', 'category',   '[1]',  NULL,    NULL, 15, 'Real estate only.'
  UNION ALL SELECT 'luxhabitat', 'include', 'category',   '[1]',  NULL,    NULL, 15, 'Real estate only.'
  UNION ALL SELECT 'monaco',     'exclude', 'price_band', NULL,      0, 5000000, 5,  'Curated partner floor: nothing under EUR 5m equivalent.'
  UNION ALL SELECT 'monaco',     'include', 'category',   '[1,3]',NULL,    NULL, 15, 'Riviera property and yachts.'
  UNION ALL SELECT 'embed',      'exclude', 'attribute',  NULL,   NULL,    NULL, 30, 'Off-market inventory never appears in third-party widgets.'
  UNION ALL SELECT 'staging',    'include', 'all',        NULL,   NULL,    NULL, 90, 'Staging mirrors production inventory.'
) AS v
JOIN tenants t ON t.code = v.tenant_code;

UPDATE tenant_visibility_rules
SET attribute_code = 'off_market', attribute_value = 'true'
WHERE dimension = 'attribute' AND attribute_code IS NULL;

-- -----------------------------------------------------------------------------
-- Tenant daily statistics
--
-- Ninety days of per-tenant traffic and revenue. The shape is deliberate: the
-- primary tenant carries most of the traffic, regionals a slice each, and the
-- white-label sites a small but high-converting trickle. Weekends dip. Revenue
-- share is only non-zero where the tenant contract sets one.
-- -----------------------------------------------------------------------------

-- How much inventory each tenant can actually show, evaluated once rather than
-- once per day. The primary and staging tenants see everything active; a
-- tenant with a country include rule sees the listings in those countries; a
-- white-label tenant sees its own organization's.
DROP TABLE IF EXISTS tmp_tenant_visible;
CREATE TABLE tmp_tenant_visible (
  tenant_id  INT UNSIGNED NOT NULL PRIMARY KEY,
  visible    INT UNSIGNED NOT NULL
) ENGINE=InnoDB;

INSERT INTO tmp_tenant_visible (tenant_id, visible)
SELECT t.id, (SELECT COUNT(*) FROM listings l WHERE l.status = 'active')
FROM tenants t
WHERE t.tenant_type IN ('primary','staging','embedded');

INSERT INTO tmp_tenant_visible (tenant_id, visible)
SELECT t.id, COUNT(DISTINCT l.id)
FROM tenants t
JOIN tenant_visibility_rules r ON r.tenant_id = t.id AND r.dimension = 'country'
JOIN locations c ON JSON_CONTAINS(r.value_ids, CAST(c.id AS CHAR))
JOIN listings l ON l.country_id = c.id AND l.status = 'active'
GROUP BY t.id;

INSERT INTO tmp_tenant_visible (tenant_id, visible)
SELECT t.id, COUNT(l.id)
FROM tenants t
JOIN listings l ON l.organization_id = t.owner_organization_id AND l.status = 'active'
WHERE t.tenant_type IN ('white_label','partner')
  AND NOT EXISTS (SELECT 1 FROM tmp_tenant_visible v WHERE v.tenant_id = t.id)
GROUP BY t.id;

-- Tenants with no matching inventory still need a row so the join below is total.
INSERT INTO tmp_tenant_visible (tenant_id, visible)
SELECT t.id, 0 FROM tenants t
WHERE NOT EXISTS (SELECT 1 FROM tmp_tenant_visible v WHERE v.tenant_id = t.id);

INSERT INTO tenant_daily_stats
  (stat_date, tenant_id, sessions, unique_visitors, page_views, searches,
   listing_views, inquiries, calls, signups, visible_listings,
   gross_revenue, revenue_share, currency_code)
SELECT
  x.stat_date, x.tenant_id,
  x.sessions,
  GREATEST(1, ROUND(x.sessions * 0.74)),
  ROUND(x.sessions * (3.8 + MOD(x.tenant_id, 6) * 0.25)),
  ROUND(x.sessions * 0.62),
  ROUND(x.sessions * 1.9),
  ROUND(x.sessions * x.inquiry_rate),
  ROUND(x.sessions * x.inquiry_rate * 0.38),
  ROUND(x.sessions * 0.006),
  x.visible,
  ROUND(x.sessions * x.revenue_per_session, 2),
  ROUND(x.sessions * x.revenue_per_session * COALESCE(x.revenue_share_percent, 0) / 100, 2),
  COALESCE(x.default_currency_code, 'USD')
FROM (
  SELECT
    d.stat_date,
    t.id AS tenant_id,
    t.revenue_share_percent,
    t.default_currency_code,
    v.visible,
    -- White-label and partner audiences are small but pre-qualified, so they
    -- enquire at three to five times the rate of the open marketplace.
    CASE t.tenant_type
      WHEN 'white_label' THEN 0.042
      WHEN 'partner'     THEN 0.055
      WHEN 'embedded'    THEN 0.004
      ELSE 0.011
    END AS inquiry_rate,
    CASE t.tenant_type
      WHEN 'primary'     THEN 0.51
      WHEN 'regional'    THEN 0.44
      WHEN 'white_label' THEN 1.85
      WHEN 'partner'     THEN 3.40
      WHEN 'embedded'    THEN 0.09
      ELSE 0.00
    END AS revenue_per_session,
    GREATEST(1, ROUND(
        CASE t.tenant_type
          WHEN 'primary'     THEN 42000
          WHEN 'regional'    THEN 9500
          WHEN 'white_label' THEN 1400
          WHEN 'partner'     THEN 620
          WHEN 'embedded'    THEN 3100
          ELSE 40
        END
        -- Weekends run about a quarter below weekdays across every market.
        * (CASE WHEN DAYOFWEEK(d.stat_date) IN (1, 7) THEN 0.74 ELSE 1.00 END)
        -- A slow upward trend: older days sit below today.
        * (1 - d.days_ago * 0.0016)
        -- Deterministic daily noise, +/- 12 per cent.
        * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('tds:', t.id, ':', d.stat_date)), 1, 4), 16, 10), 25) / 100)
    )) AS sessions
  FROM tenants t
  JOIN tmp_tenant_visible v ON v.tenant_id = t.id
  CROSS JOIN (
    SELECT DATE_SUB(CURDATE(), INTERVAL s.n DAY) AS stat_date, s.n AS days_ago
    FROM (
      SELECT (u.n + tn.n * 10) AS n
      FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) u
      CROSS JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
                  UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tn
    ) s
    WHERE s.n BETWEEN 1 AND 90
  ) d
  -- The staging tenant never launched, so it has no traffic to record.
  WHERE t.status = 'active'
) AS x;

DROP TABLE IF EXISTS tmp_tenant_visible;

-- =============================================================================
-- Data governance
--
-- Everything from here down is the evidence a regulator or an auditor asks for:
-- what personal data is held, why, on what lawful basis, for how long, who else
-- touches it, and what happened when a subject asked for it to go away. It is
-- deliberately expressed as data rather than as documentation, because a policy
-- that lives in a wiki cannot be joined to the rows it governs.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Anonymization rules
--
-- Referenced by the field registry. Deterministic hashing is separated from
-- random tokenisation because the two answer different questions: a hash keeps
-- joins working after erasure, a random token deliberately breaks them.
-- -----------------------------------------------------------------------------
INSERT INTO anonymization_rules
  (code, name, strategy, replacement_value, keep_prefix_chars, keep_suffix_chars,
   generalize_to, preserves_uniqueness, preserves_format, is_reversible, description)
VALUES
  ('null_out',          'Null the field',                 'nullify',            NULL,                      NULL, NULL, NULL,        0, 0, 0, 'Sets the column to NULL. Only valid where the column is nullable and nothing downstream requires it.'),
  ('redacted_constant', 'Replace with a constant',        'constant',           '[redacted]',              NULL, NULL, NULL,        0, 0, 0, 'For NOT NULL text columns that must keep a value but must not keep the content.'),
  ('email_hash',        'Deterministic email hash',       'deterministic_hash', NULL,                      NULL, NULL, NULL,        1, 0, 0, 'SHA-256 of the normalised address with a per-environment pepper. Duplicate detection and suppression matching keep working; the address itself does not survive.'),
  ('email_mask',        'Mask the local part',            'partial_mask',       NULL,                      2,    0,    NULL,        0, 1, 0, 'a***@domain.com. Used in support views where an agent needs to confirm which address, not read it.'),
  ('phone_hash',        'Deterministic phone hash',       'deterministic_hash', NULL,                      NULL, NULL, NULL,        1, 0, 0, 'SHA-256 of the E.164 form. Preserves the ability to detect that two records share a number.'),
  ('phone_mask',        'Keep the last four digits',      'partial_mask',       NULL,                      0,    4,    NULL,        0, 1, 0, '*******1234. The standard callback-confirmation format.'),
  ('name_token',        'Random person token',            'random_token',       NULL,                      NULL, NULL, NULL,        1, 0, 0, 'Replaces a name with Subject-XXXXXX. Unlinkable across erasure runs by design.'),
  ('address_generalize','Generalise to the city',         'generalize',         NULL,                      NULL, NULL, 'city',      0, 0, 0, 'Street and building are dropped, the city is retained so aggregate market statistics survive erasure.'),
  ('geo_generalize',    'Round coordinates to 2 decimals','generalize',         NULL,                      NULL, NULL, 'grid_1km', 0, 1, 0, 'Roughly a one-kilometre grid cell. Enough for a heat map, not enough to identify a household.'),
  ('dob_year_only',     'Keep the birth year',            'generalize',         NULL,                      NULL, NULL, 'year',      0, 0, 0, 'Age banding for analytics without holding an identifying date.'),
  ('date_shift',        'Shift dates by a subject offset','date_shift',         NULL,                      NULL, NULL, NULL,        0, 1, 0, 'Every date for one subject moves by the same number of days, so intervals stay analysable while absolute dates stop matching external records.'),
  ('ip_truncate',       'Truncate the host portion',      'truncate',           NULL,                      NULL, NULL, NULL,        0, 1, 0, 'Last octet of IPv4, last 80 bits of IPv6. The accepted analytics compromise.'),
  ('card_token',        'Replace with a gateway token',   'tokenize',           NULL,                      0,    4,    NULL,        1, 1, 1, 'The pan never lands here in the first place; this rule exists for imported legacy rows.'),
  ('free_text_purge',   'Delete free text entirely',      'nullify',            NULL,                      NULL, NULL, NULL,        0, 0, 0, 'Notes and message bodies cannot be safely anonymised in place, because the identifying content is unstructured. They are removed.');

-- -----------------------------------------------------------------------------
-- Data field registry
--
-- The column-level inventory. This is what makes a subject access request
-- answerable by query rather than by memory: export the columns flagged
-- include_in_export, apply the erasure_action of every column flagged
-- is_personal_data, and the request is discharged.
-- -----------------------------------------------------------------------------
INSERT INTO data_field_registry
  (table_name, column_name, data_class, is_personal_data, is_special_category,
   pii_type, lawful_basis, purpose, erasure_action, anonymization_rule_id,
   retention_days, retention_anchor, retention_basis, include_in_export,
   export_label, is_encrypted, is_masked_in_logs, shared_with_processors,
   reviewed_at, notes)
SELECT
  f.table_name, f.column_name, f.data_class, f.is_personal_data, f.is_special_category,
  f.pii_type, f.lawful_basis, f.purpose, f.erasure_action, r.id,
  f.retention_days, f.retention_anchor, f.retention_basis, f.include_in_export,
  f.export_label, f.is_encrypted, f.is_masked_in_logs, f.processors,
  DATE_SUB(@now, INTERVAL MOD(CRC32(CONCAT(f.table_name, f.column_name)), 120) DAY),
  f.notes
FROM (
  SELECT 'users' AS table_name, 'email' AS column_name, 'confidential' AS data_class, 1 AS is_personal_data, 0 AS is_special_category, 'email' AS pii_type, 'contract' AS lawful_basis, 'Account identity and transactional messaging.' AS purpose, 'anonymize' AS erasure_action, 'email_hash' AS rule_code, 2555 AS retention_days, 'deleted_at' AS retention_anchor, 'Retained seven years after closure where a transaction exists, for tax and dispute evidence.' AS retention_basis, 1 AS include_in_export, 'Email address' AS export_label, 0 AS is_encrypted, 1 AS is_masked_in_logs, '["email_delivery","support_desk","analytics"]' AS processors, NULL AS notes
  UNION ALL SELECT 'users','email_normalized','confidential',1,0,'email','contract','Duplicate detection and login.','anonymize','email_hash',2555,'deleted_at',NULL,0,NULL,0,1,'[]','Lower-cased and dot-stripped form; never shown to the subject.'
  UNION ALL SELECT 'users','phone_e164','confidential',1,0,'phone','contract','Verification and agent callback.','anonymize','phone_hash',2555,'deleted_at',NULL,1,'Phone number',0,1,'["sms_gateway","support_desk"]',NULL
  UNION ALL SELECT 'users','phone_number','confidential',1,0,'phone','contract','Display form of the number.','anonymize','phone_mask',2555,'deleted_at',NULL,1,'Phone number',0,1,'["sms_gateway"]',NULL
  UNION ALL SELECT 'users','first_name','confidential',1,0,'name','contract','Personalisation and correspondence.','anonymize','name_token',2555,'deleted_at',NULL,1,'First name',0,0,'["email_delivery","crm","support_desk"]',NULL
  UNION ALL SELECT 'users','last_name','confidential',1,0,'name','contract','Personalisation and correspondence.','anonymize','name_token',2555,'deleted_at',NULL,1,'Last name',0,0,'["email_delivery","crm","support_desk"]',NULL
  UNION ALL SELECT 'users','display_name','internal',1,0,'name','contract','Public-facing name.','anonymize','name_token',2555,'deleted_at',NULL,1,'Display name',0,0,'[]',NULL
  UNION ALL SELECT 'users','password_hash','restricted',0,0,NULL,'contract','Authentication.','delete_row',NULL,NULL,NULL,NULL,0,NULL,1,1,'[]','Argon2id. Never exported under a subject access request: it is a credential, not the subject''s data in any useful sense.'
  UNION ALL SELECT 'users','last_login_ip','confidential',1,0,'ip_address','legitimate_interests','Fraud and account-takeover detection.','anonymize','ip_truncate',180,'last_login_at','Security logging necessity, balanced against the intrusiveness of a full address.',0,NULL,0,1,'[]',NULL
  UNION ALL SELECT 'users','avatar_url','internal',1,0,'photo','consent','Profile image supplied by the subject.','null_field','null_out',2555,'deleted_at',NULL,1,'Profile photo',0,0,'["object_storage","cdn"]',NULL
  UNION ALL SELECT 'users','timezone','internal',1,0,'location','legitimate_interests','Rendering local times.','null_field','null_out',2555,'deleted_at',NULL,1,'Time zone',0,0,'[]',NULL
  UNION ALL SELECT 'users','marketing_opt_in','internal',1,0,'other','consent','Marketing permission state.','retain_legal_obligation',NULL,NULL,NULL,'Proof of consent state must outlive the account to defend a complaint.',1,'Marketing preference',0,0,'["email_delivery"]',NULL
  UNION ALL SELECT 'accounts','legal_name','confidential',1,0,'name','contract','Contracting party identity.','retain_legal_obligation',NULL,3650,'closed_at','Commercial records retained ten years under the platform''s longest applicable statute of limitations.',1,'Legal name',0,0,'["payment_gateway","accounting"]',NULL
  UNION ALL SELECT 'accounts','tax_id','restricted',1,0,'national_id','legal_obligation','Tax invoicing and reverse-charge validation.','retain_legal_obligation',NULL,3650,'closed_at','Required on every invoice issued; cannot be erased while invoices stand.',1,'Tax identification number',1,1,'["accounting","tax_validation"]',NULL
  UNION ALL SELECT 'crm_contacts','email','confidential',1,0,'email','legitimate_interests','Contacting an enquirer about the property they enquired on.','anonymize','email_hash',1095,'last_activity_at','Three years from last activity, being the point at which a property enquiry stops being live in practice.',1,'Email address',0,1,'["crm","email_delivery"]',NULL
  UNION ALL SELECT 'crm_contacts','phone_e164','confidential',1,0,'phone','legitimate_interests','Agent callback.','anonymize','phone_hash',1095,'last_activity_at',NULL,1,'Phone number',0,1,'["crm","call_tracking"]',NULL
  UNION ALL SELECT 'crm_contacts','first_name','confidential',1,0,'name','legitimate_interests','Addressing the enquirer.','anonymize','name_token',1095,'last_activity_at',NULL,1,'First name',0,0,'["crm"]',NULL
  UNION ALL SELECT 'crm_contacts','last_name','confidential',1,0,'name','legitimate_interests','Addressing the enquirer.','anonymize','name_token',1095,'last_activity_at',NULL,1,'Last name',0,0,'["crm"]',NULL
  UNION ALL SELECT 'crm_contacts','date_of_birth','restricted',1,0,'date_of_birth','legal_obligation','Identity verification where a transaction requires it.','anonymize','dob_year_only',1825,'last_activity_at','Five years from the end of the business relationship under anti-money-laundering rules.',1,'Date of birth',1,1,'["kyc_provider"]',NULL
  UNION ALL SELECT 'crm_contacts','nationality_country_id','confidential',1,0,'other','legal_obligation','Sanctions and residency screening.','retain_legal_obligation',NULL,1825,'last_activity_at',NULL,1,'Nationality',0,0,'["kyc_provider","sanctions_screening"]',NULL
  UNION ALL SELECT 'crm_contacts','notes','confidential',1,0,'other','legitimate_interests','Agent working notes.','null_field','free_text_purge',1095,'last_activity_at','Unstructured; cannot be reliably anonymised, so it is purged.',1,'Agent notes',0,0,'["crm"]',NULL
  UNION ALL SELECT 'leads','source_url','internal',1,0,'other','legitimate_interests','Attribution of the enquiry.','anonymize','redacted_constant',1095,'created_at',NULL,0,NULL,0,0,'["analytics"]','Can carry query parameters that identify a session.'
  UNION ALL SELECT 'inquiries','message','confidential',1,0,'other','legitimate_interests','The enquiry itself.','null_field','free_text_purge',1095,'created_at',NULL,1,'Enquiry message',0,0,'["crm","email_delivery"]',NULL
  UNION ALL SELECT 'inquiries','ip_address','confidential',1,0,'ip_address','legitimate_interests','Spam and abuse detection.','anonymize','ip_truncate',180,'created_at',NULL,0,NULL,0,1,'[]',NULL
  UNION ALL SELECT 'messages','body','confidential',1,0,'other','contract','Conversation between a buyer and an agent.','null_field','free_text_purge',1095,'created_at',NULL,1,'Message body',0,1,'["messaging"]',NULL
  UNION ALL SELECT 'web_sessions','ip_address','confidential',1,0,'ip_address','legitimate_interests','Bot detection and geolocation.','anonymize','ip_truncate',90,'started_at','Ninety days is the operational window for abuse investigation.',0,NULL,0,1,'["analytics"]',NULL
  UNION ALL SELECT 'web_sessions','user_agent','internal',1,0,'device_id','legitimate_interests','Device and browser breakdown.','anonymize','redacted_constant',90,'started_at',NULL,0,NULL,0,0,'["analytics"]',NULL
  UNION ALL SELECT 'analytics_events','visitor_id','confidential',1,0,'device_id','consent','Cross-session behavioural analytics.','anonymize','name_token',395,'occurred_at','Thirteen months, matching the maximum cookie lifetime the consent notice states.',0,NULL,0,0,'["analytics"]',NULL
  UNION ALL SELECT 'consent_receipts','ip_address','confidential',1,0,'ip_address','legal_obligation','Evidence of where and when consent was given.','retain_legal_obligation',NULL,NULL,NULL,'The receipt is the defence to a complaint; truncating it would defeat its purpose.',1,'Consent IP address',0,1,'[]',NULL
  UNION ALL SELECT 'payment_methods','last_four','confidential',1,0,'financial','contract','Letting the payer recognise their own card.','retain_legal_obligation',NULL,2555,'created_at',NULL,1,'Card last four digits',0,0,'["payment_gateway"]',NULL
  UNION ALL SELECT 'payment_methods','billing_postal_code','confidential',1,0,'address','contract','Address verification at the gateway.','anonymize','address_generalize',2555,'created_at',NULL,1,'Billing postcode',0,1,'["payment_gateway"]',NULL
  UNION ALL SELECT 'kyc_cases','document_number','restricted',1,0,'passport','legal_obligation','Identity verification under anti-money-laundering obligations.','retain_legal_obligation',NULL,1825,'closed_at','Five years from the end of the business relationship. Erasure is refused while this stands.',1,'Identity document number',1,1,'["kyc_provider"]',NULL
  UNION ALL SELECT 'kyc_cases','pep_status','restricted',1,1,'other','legal_obligation','Politically exposed person screening.','retain_legal_obligation',NULL,1825,'closed_at','Special category by association with political opinion; held only because the obligation requires it.',0,NULL,1,1,'["sanctions_screening"]',NULL
  UNION ALL SELECT 'listings','latitude','public',0,0,'location','legitimate_interests','Map placement of the asset.','no_action',NULL,NULL,NULL,NULL,0,NULL,0,0,'["search_index","cdn"]','Property location, not subject location. Included so the registry answers the question rather than staying silent on it.'
  UNION ALL SELECT 'saved_searches','criteria','internal',1,0,'other','contract','Restoring the subject''s own saved search.','delete_row',NULL,730,'last_run_at',NULL,1,'Saved search criteria',0,0,'[]',NULL
  UNION ALL SELECT 'call_records','recording_url','restricted',1,0,'biometric','consent','Quality assurance and dispute evidence, where both parties consented.','delete_row',NULL,180,'started_at','Voice is biometric in several jurisdictions; the retention window is deliberately short.',1,'Call recording',1,1,'["call_tracking","object_storage"]',NULL
  UNION ALL SELECT 'signature_events','signer_ip','confidential',1,0,'ip_address','legal_obligation','Evidence of execution.','retain_legal_obligation',NULL,NULL,NULL,'Part of the signature evidence trail; erasing it would void the contract''s enforceability.',1,'Signing IP address',0,1,'["e_signature"]',NULL
) AS f
LEFT JOIN anonymization_rules r ON r.code = f.rule_code;

-- -----------------------------------------------------------------------------
-- Processing activities (the Article 30 record)
-- -----------------------------------------------------------------------------
INSERT INTO processing_activities
  (code, name, description, role, purpose, lawful_basis, legitimate_interest_assessment,
   data_subject_categories, data_categories, special_categories, recipient_categories,
   transfers_outside_region, transfer_countries, transfer_safeguard, retention_summary,
   security_measures, dpia_required, dpia_completed_at, last_reviewed_at, next_review_due, is_active)
SELECT
  a.code, a.name, a.description, a.role, a.purpose, a.lawful_basis, a.lia,
  a.subject_categories, a.data_categories, a.special_categories, a.recipients,
  a.transfers, a.transfer_countries, a.safeguard, a.retention_summary,
  a.security, a.dpia_required,
  CASE WHEN a.dpia_required = 1 THEN DATE_SUB(@today, INTERVAL a.reviewed_days_ago + 30 DAY) END,
  DATE_SUB(@today, INTERVAL a.reviewed_days_ago DAY),
  DATE_ADD(DATE_SUB(@today, INTERVAL a.reviewed_days_ago DAY), INTERVAL 365 DAY),
  1
FROM (
  SELECT 'account_management' AS code, 'Account registration and management' AS name,
         'Creating and maintaining user accounts, authentication, and the account settings a subject controls.' AS description,
         'controller' AS role, 'To provide the marketplace account the subject asked for.' AS purpose, 'contract' AS lawful_basis, NULL AS lia,
         '["registered_users","agents","administrators"]' AS subject_categories,
         '["identity","contact","authentication","preferences"]' AS data_categories, NULL AS special_categories,
         '["cloud_hosting","email_delivery","support_desk"]' AS recipients,
         1 AS transfers, '["United States","Ireland"]' AS transfer_countries, 'sccs' AS safeguard,
         'Seven years after closure where a transaction exists, otherwise thirty days.' AS retention_summary,
         'Argon2id password hashing, TLS 1.3 in transit, AES-256 at rest, role-based access, MFA for staff.' AS security,
         0 AS dpia_required, 40 AS reviewed_days_ago
  UNION ALL SELECT 'listing_publication','Listing publication','Publishing asset listings supplied by agents, dealers and brokers, including agent contact details shown to the public.','controller','To operate the marketplace.','contract',NULL,'["agents","sellers"]','["identity","contact","professional_licence","photography"]',NULL,'["cloud_hosting","cdn","search_index","syndication_partners"]',1,'["United States","Singapore"]','sccs','For the life of the listing plus two years of price-history archive.','Signed upload URLs, moderation queue, per-organization row scoping.',0,55
  UNION ALL SELECT 'enquiry_handling','Enquiry and lead handling','Receiving buyer enquiries and routing them to the responsible agent, including the enquiry text and the enquirer''s contact details.','controller','To connect a prospective buyer with the seller''s agent.','legitimate_interests','The enquirer initiates contact and expects a reply; the data used is the minimum needed to reply. Balancing test recorded in DPIA-2024-03. Objection is honoured immediately and suppresses further contact.','["prospective_buyers","tenants"]','["identity","contact","enquiry_content","behavioural"]',NULL,'["crm","email_delivery","sms_gateway","agencies"]',1,'["United States"]','sccs','Three years from last activity.','Field-level access control, agent-scoped visibility, audit trail on every read of a contact record.',1,20
  UNION ALL SELECT 'payment_processing','Payment processing','Taking payment for subscriptions, listing credits and promotions.','controller','To charge for services purchased.','contract',NULL,'["paying_customers"]','["identity","billing_address","payment_token","transaction_history"]',NULL,'["payment_gateway","accounting","banks"]',1,'["United States","United Kingdom"]','sccs','Ten years, being the longest applicable accounting-record obligation.','Card data never touches platform storage; gateway tokenisation only; PCI DSS SAQ-A scope.',0,70
  UNION ALL SELECT 'aml_kyc','Anti-money-laundering and know-your-customer checks','Verifying the identity of counterparties to high-value transactions, screening against sanctions and politically-exposed-person lists.','controller','To meet statutory anti-money-laundering obligations.','legal_obligation',NULL,'["sellers","buyers","beneficial_owners","directors"]','["identity","government_identifiers","source_of_funds","screening_results"]','["political_exposure"]','["kyc_provider","sanctions_screening","regulators","financial_intelligence_unit"]',1,'["United Kingdom","United Arab Emirates"]','sccs','Five years from the end of the business relationship, extended where an investigation is open.','Restricted-role access, separate encryption key, every access logged and reviewed monthly.',1,15
  UNION ALL SELECT 'marketing_email','Direct marketing by email','Sending newsletters, saved-search alerts and property recommendations.','controller','To market relevant listings to subjects who asked to hear from us.','consent',NULL,'["registered_users","newsletter_subscribers"]','["contact","preferences","engagement_history"]',NULL,'["email_delivery","marketing_automation"]',1,'["United States"]','sccs','Until consent is withdrawn, plus a permanent suppression record.','Double opt-in, one-click unsubscribe, suppression list checked before every send.',0,35
  UNION ALL SELECT 'behavioural_analytics','Behavioural analytics','Measuring how visitors move through search and listing pages in order to improve them.','controller','To understand and improve product performance.','consent',NULL,'["visitors","registered_users"]','["behavioural","device","approximate_location"]',NULL,'["analytics"]',1,'["United States"]','sccs','Thirteen months from collection.','Consent gate before any analytics cookie is set; IP truncated on ingest.',0,60
  UNION ALL SELECT 'advertising_targeting','Advertising and remarketing','Building audiences for paid promotion of listings.','joint_controller','To promote listings to audiences likely to be interested.','consent',NULL,'["visitors","registered_users"]','["behavioural","device","inferred_interests"]',NULL,'["advertising_networks"]',1,'["United States"]','sccs','Ninety days from the last interaction.','Consent gate; audiences hashed before transmission; joint-controller arrangement documented.',1,25
  UNION ALL SELECT 'fraud_prevention','Fraud and abuse prevention','Detecting fraudulent listings, account takeover and payment fraud.','controller','To protect the marketplace and its users from fraud.','legitimate_interests','Fraud prevention is expressly recognised as a legitimate interest. Automated scoring is never the sole basis of a decision affecting a subject; every suspension is reviewed by a person.','["registered_users","visitors","agents"]','["identity","device","behavioural","payment_signals"]',NULL,'["fraud_scoring","payment_gateway"]',1,'["United States"]','sccs','Two years, or the life of an open investigation.','Human review before suspension, appeal route, decision rationale recorded.',1,10
  UNION ALL SELECT 'call_recording','Call recording','Recording calls between enquirers and agents on tracked numbers, where both parties have been notified.','controller','Quality assurance, training and dispute evidence.','consent',NULL,'["prospective_buyers","agents"]','["voice","contact","call_metadata"]','["voice_biometric"]','["call_tracking","object_storage"]',1,'["United States"]','sccs','One hundred and eighty days.','Pre-call announcement, opt-out routes to an unrecorded number, recordings encrypted with a separate key.',1,45
  UNION ALL SELECT 'support_operations','Customer support','Handling support tickets, including whatever the subject chooses to tell us in them.','controller','To answer support requests.','contract',NULL,'["registered_users","agents","visitors"]','["identity","contact","ticket_content"]',NULL,'["support_desk","email_delivery"]',1,'["United States"]','sccs','Three years from ticket closure.','Agent-scoped access, PII redaction in attachments, audit trail.',0,80
  UNION ALL SELECT 'employment_records','Staff and agent records','Records of platform staff and of agents whose licences the platform verifies.','controller','Employment administration and professional licence verification.','legal_obligation',NULL,'["employees","contractors","licensed_agents"]','["identity","contact","licence","payroll_reference"]',NULL,'["payroll","hr_system","regulators"]',0,NULL,NULL,'Six years after the relationship ends.','HR system access limited to the people team; separate database.',0,95
  UNION ALL SELECT 'syndication_outbound','Outbound listing syndication','Sending listing and agent-contact data to portal partners under contract.','joint_controller','To distribute inventory to partner portals.','contract',NULL,'["agents","sellers"]','["identity","contact","listing_content"]',NULL,'["syndication_partners"]',1,'["United Kingdom","United Arab Emirates","Singapore"]','sccs','Per partner contract; deletion requested on termination.','Per-partner credentials, field-level mapping restricting what leaves, transfer logs.',0,50
  UNION ALL SELECT 'ai_content_assist','AI-assisted listing content','Generating draft listing descriptions and translations from structured listing attributes.','controller','To help agents produce listing copy faster.','legitimate_interests','Inputs are property attributes, not personal data; agent identity is not sent. The interest is operational efficiency, the impact on subjects is negligible, and no automated decision affects anyone.','["agents"]','["listing_content"]',NULL,'["ai_service"]',1,'["United States"]','sccs','Prompts and completions retained thirty days for quality review.','No personal data in prompts by contract and by input filter; zero-retention agreement with the provider.',0,5
) AS a;

-- -----------------------------------------------------------------------------
-- Data processors
--
-- Every third party that touches personal data, with the state of its contract
-- and its audit cycle. risk_rating drives how often the audit comes round.
-- -----------------------------------------------------------------------------
INSERT INTO data_processors
  (code, name, processor_type, service_description, data_categories,
   hosting_country_id, processing_countries, dpa_signed, dpa_signed_at,
   sccs_in_place, sub_processors_permitted, certifications, last_audit_at,
   next_audit_due, risk_rating, breach_notification_hours, status)
SELECT
  p.code, p.name, p.processor_type, p.service_description, p.data_categories,
  c.id, p.processing_countries, 1,
  DATE_SUB(@today, INTERVAL p.dpa_age_days DAY),
  p.sccs, p.sub_processors, p.certifications,
  DATE_SUB(@today, INTERVAL p.audit_age_days DAY),
  DATE_ADD(DATE_SUB(@today, INTERVAL p.audit_age_days DAY),
           INTERVAL CASE p.risk_rating WHEN 'high' THEN 182 WHEN 'medium' THEN 365 ELSE 730 END DAY),
  p.risk_rating, p.breach_hours, 'active'
FROM (
  SELECT 'cloud_hosting' AS code, 'Primary cloud infrastructure provider' AS name, 'infrastructure' AS processor_type, 'Compute, managed database and object storage for the whole platform.' AS service_description, '["identity","contact","behavioural","transaction","content"]' AS data_categories, 'Ireland' AS hosting_country, '["Ireland","Germany","United States"]' AS processing_countries, 400 AS dpa_age_days, 1 AS sccs, 1 AS sub_processors, '["ISO 27001","SOC 2 Type II","ISO 27018"]' AS certifications, 120 AS audit_age_days, 'high' AS risk_rating, 24 AS breach_hours
  UNION ALL SELECT 'cdn','Content delivery network','infrastructure','Edge delivery of listing imagery and static assets.','["ip_address","device","content"]','United States','["United States","Ireland","Singapore","United Arab Emirates"]',400,1,1,'["ISO 27001","SOC 2 Type II"]',150,'medium',24
  UNION ALL SELECT 'object_storage','Object storage and media archive','storage','Original media, renditions, contract PDFs and call recordings.','["content","voice","documents"]','Ireland','["Ireland","United States"]',400,1,0,'["ISO 27001","SOC 2 Type II"]',120,'high',24
  UNION ALL SELECT 'search_index','Search infrastructure provider','infrastructure','Hosted search index over the listing read model.','["content","behavioural"]','Ireland','["Ireland"]',330,1,0,'["ISO 27001"]',200,'low',48
  UNION ALL SELECT 'payment_gateway','Primary payment gateway','payment','Card acquiring, tokenisation, 3-D Secure and settlement.','["identity","billing_address","payment_token","transaction"]','United States','["United States","Ireland"]',620,1,1,'["PCI DSS Level 1","SOC 2 Type II","ISO 27001"]',95,'high',24
  UNION ALL SELECT 'payment_gateway_mena','Regional payment gateway','payment','Card acquiring for Gulf currencies and local payment methods.','["identity","billing_address","payment_token","transaction"]','United Arab Emirates','["United Arab Emirates","Saudi Arabia"]',380,0,0,'["PCI DSS Level 1"]',110,'high',24
  UNION ALL SELECT 'accounting','Accounting and revenue system','other','General ledger, invoicing and tax reporting.','["identity","tax_identifiers","transaction"]','United Kingdom','["United Kingdom"]',700,0,0,'["ISO 27001"]',240,'medium',72
  UNION ALL SELECT 'email_delivery','Transactional and marketing email','messaging','Delivery of transactional mail, alerts and campaigns; bounce and complaint feedback.','["identity","contact","engagement"]','United States','["United States","Ireland"]',540,1,1,'["SOC 2 Type II","ISO 27001"]',140,'medium',48
  UNION ALL SELECT 'sms_gateway','SMS and WhatsApp delivery','messaging','One-time codes, alerts and agent notifications.','["contact","message_content"]','United States','["United States","Singapore","United Arab Emirates"]',420,1,1,'["ISO 27001","SOC 2 Type II"]',180,'medium',48
  UNION ALL SELECT 'call_tracking','Call tracking and recording','messaging','Pooled numbers, call routing, recording and transcription.','["contact","voice","call_metadata"]','United Kingdom','["United Kingdom","United States"]',300,1,1,'["ISO 27001"]',75,'high',24
  UNION ALL SELECT 'crm','Agency CRM integration','crm','Two-way synchronisation of contacts, leads and deals with partner agency systems.','["identity","contact","enquiry_content"]','Ireland','["Ireland","United Arab Emirates"]',260,1,0,'["ISO 27001"]',160,'medium',48
  UNION ALL SELECT 'support_desk','Support ticketing platform','support','Ticketing, live chat and the knowledge base.','["identity","contact","ticket_content"]','Ireland','["Ireland","United States"]',480,1,1,'["ISO 27001","SOC 2 Type II"]',210,'medium',72
  UNION ALL SELECT 'analytics','Product analytics platform','analytics','Event ingestion, funnels and cohort reporting.','["behavioural","device","approximate_location"]','Germany','["Germany","United States"]',350,1,1,'["ISO 27001","SOC 2 Type II"]',130,'medium',48
  UNION ALL SELECT 'advertising_networks','Advertising networks','marketing','Audience upload and conversion measurement for paid promotion.','["hashed_contact","behavioural"]','United States','["United States"]',290,1,1,'["ISO 27001"]',85,'high',72
  UNION ALL SELECT 'kyc_provider','Identity verification provider','identity','Document authentication, liveness checks and identity matching.','["identity","government_identifiers","biometric"]','United Kingdom','["United Kingdom","Ireland"]',520,1,0,'["ISO 27001","SOC 2 Type II","eIDAS"]',60,'high',24
  UNION ALL SELECT 'sanctions_screening','Sanctions and PEP screening','identity','Screening counterparties against consolidated sanctions and PEP lists.','["identity","screening_results"]','United Kingdom','["United Kingdom"]',520,1,0,'["ISO 27001"]',60,'high',24
  UNION ALL SELECT 'e_signature','Electronic signature provider','other','Contract execution, signature evidence and audit certificates.','["identity","contact","ip_address","signature"]','Ireland','["Ireland","United States"]',440,1,0,'["ISO 27001","SOC 2 Type II","eIDAS"]',100,'high',24
  UNION ALL SELECT 'fraud_scoring','Fraud scoring service','other','Device fingerprinting and risk scoring at signup and checkout.','["device","behavioural","ip_address"]','United States','["United States"]',270,1,1,'["SOC 2 Type II"]',170,'medium',48
  UNION ALL SELECT 'ai_service','AI content generation provider','ai_service','Listing description drafting and translation from structured attributes.','["listing_content"]','United States','["United States"]',120,1,0,'["SOC 2 Type II","ISO 27001"]',90,'medium',72
  UNION ALL SELECT 'marketing_automation','Marketing automation platform','marketing','Campaign orchestration, journeys and audience segmentation.','["contact","engagement","preferences"]','United States','["United States","Ireland"]',310,1,1,'["ISO 27001"]',190,'medium',48
  UNION ALL SELECT 'payroll','Payroll and HR system','other','Employee records and payroll processing.','["identity","contact","payroll"]','United Kingdom','["United Kingdom"]',900,0,0,'["ISO 27001"]',280,'medium',72
  UNION ALL SELECT 'syndication_partners','Portal syndication partners','other','Receiving listing and agent-contact feeds under distribution contracts.','["identity","contact","listing_content"]','United Arab Emirates','["United Arab Emirates","United Kingdom","Singapore"]',360,1,1,'[]',220,'medium',72
) AS p
LEFT JOIN locations c ON c.level = 'country' AND c.name = p.hosting_country;

-- One processor is being wound down. The row stays so the ROPA can still explain
-- where data went last year, and data_deletion_confirmed_at is the evidence that
-- the wind-down completed.
INSERT INTO data_processors
  (code, name, processor_type, service_description, data_categories,
   hosting_country_id, processing_countries, dpa_signed, dpa_signed_at, sccs_in_place,
   sub_processors_permitted, last_audit_at, risk_rating, breach_notification_hours,
   status, terminated_at, data_deletion_confirmed_at)
SELECT 'legacy_mailer', 'Legacy bulk mail provider', 'messaging',
  'Replaced by the current email delivery processor during the platform migration.',
  '["contact","engagement"]',
  (SELECT id FROM locations WHERE level = 'country' AND name = 'United States' LIMIT 1),
  '["United States"]', 1, DATE_SUB(@today, INTERVAL 1200 DAY), 1, 1,
  DATE_SUB(@today, INTERVAL 500 DAY), 'medium', 72,
  'terminated', DATE_SUB(@today, INTERVAL 420 DAY), DATE_SUB(@today, INTERVAL 390 DAY);

-- -----------------------------------------------------------------------------
-- Consent purposes and receipts
--
-- A purpose is versioned: changing the notice text means a new version, and a
-- receipt records which version the subject actually saw. Without that, a
-- consent record proves nothing.
-- -----------------------------------------------------------------------------
INSERT INTO consent_purposes
  (code, name, description, purpose_type, is_required, default_state,
   processing_activity_id, version, effective_from, expires_after_months, is_active)
SELECT
  p.code, p.name, p.description, p.purpose_type, p.is_required, p.default_state,
  pa.id, p.version, DATE_SUB(@today, INTERVAL p.effective_days_ago DAY),
  p.expires_after_months, 1
FROM (
  SELECT 'terms_of_service' AS code, 'Terms of service' AS name, 'Acceptance of the marketplace terms. Required to hold an account.' AS description, 'terms' AS purpose_type, 1 AS is_required, 'unset' AS default_state, 'account_management' AS activity_code, 3 AS version, 210 AS effective_days_ago, NULL AS expires_after_months
  UNION ALL SELECT 'privacy_notice','Privacy notice','Acknowledgement of the privacy notice describing how personal data is handled.','privacy_policy',1,'unset','account_management',4,120,NULL
  UNION ALL SELECT 'marketing_email','Marketing email','Newsletters, curated collections and market reports by email.','marketing_email',0,'opt_out','marketing_email',2,300,24
  UNION ALL SELECT 'marketing_sms','Marketing SMS','Promotional messages by text.','marketing_sms',0,'opt_out','marketing_email',1,300,12
  UNION ALL SELECT 'marketing_whatsapp','Marketing on WhatsApp','Promotional messages on WhatsApp, where the channel is available.','marketing_whatsapp',0,'opt_out','marketing_email',1,180,12
  UNION ALL SELECT 'saved_search_alerts','Saved search alerts','Email when a new listing matches a search the subject saved.','marketing_email',0,'opt_in','marketing_email',2,300,24
  UNION ALL SELECT 'profiling_recommendations','Personalised recommendations','Building a profile of browsing behaviour in order to recommend listings.','profiling',0,'opt_out','behavioural_analytics',2,150,13
  UNION ALL SELECT 'cookies_functional','Functional cookies','Cookies needed for the site to work: session, language, currency.','cookies_functional',1,'opt_in','account_management',1,400,12
  UNION ALL SELECT 'cookies_analytics','Analytics cookies','Cookies that measure how the site is used.','cookies_analytics',0,'opt_out','behavioural_analytics',2,150,13
  UNION ALL SELECT 'cookies_marketing','Advertising cookies','Cookies used to build advertising audiences and measure campaigns.','cookies_marketing',0,'opt_out','advertising_targeting',2,150,13
  UNION ALL SELECT 'third_party_agents','Sharing with agents','Passing enquiry contact details to the agent responsible for the listing.','third_party_sharing',0,'opt_in','enquiry_handling',1,400,NULL
  UNION ALL SELECT 'call_recording','Call recording','Recording calls placed through tracked numbers.','data_processing',0,'opt_out','call_recording',1,260,12
  UNION ALL SELECT 'kyc_processing','Identity verification','Processing identity documents to satisfy anti-money-laundering obligations.','data_processing',1,'unset','aml_kyc',1,400,NULL
) AS p
LEFT JOIN processing_activities pa ON pa.code = p.activity_code;

-- Receipts for the mandatory purposes: every user who accepted the terms has a
-- receipt, dated at the moment they accepted.
INSERT INTO consent_receipts
  (public_id, purpose_id, purpose_version, user_id, subject_identifier, action,
   notice_version, notice_url, language_id, mechanism, ip_address, user_agent,
   page_url, tenant_id, granted_at, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('consent:', u.id, ':', cp.code)), 26)),
  cp.id, cp.version, u.id, LEFT(SHA2(CONCAT('subject:', u.email), 256), 64), 'granted',
  CONCAT('v', cp.version, '.0'),
  CONCAT('https://www.livfinder.com/legal/', REPLACE(cp.code, '_', '-')),
  COALESCE(u.preferred_language_id, 1),
  'checkbox',
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('ip:', u.id)), 1, 8), 16, 10)), 8, '0')),
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  'https://www.livfinder.com/register',
  (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  u.terms_accepted_at, u.terms_accepted_at
FROM users u
JOIN consent_purposes cp ON cp.code IN ('terms_of_service', 'privacy_notice')
WHERE u.terms_accepted_at IS NOT NULL;

-- Marketing receipts follow the flag the user actually carries, so the receipt
-- table and the preference agree. Users who opted in through the double opt-in
-- flow carry the confirmation timestamp that makes the consent defensible.
INSERT INTO consent_receipts
  (public_id, purpose_id, purpose_version, user_id, subject_identifier, action,
   notice_version, notice_url, language_id, mechanism, double_opt_in_confirmed_at,
   ip_address, page_url, tenant_id, granted_at, withdrawn_at, expires_at, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('consent:', u.id, ':marketing_email')), 26)),
  cp.id, cp.version, u.id, LEFT(SHA2(CONCAT('subject:', u.email), 256), 64),
  CASE WHEN u.marketing_opt_in = 1 THEN 'granted' ELSE 'withdrawn' END,
  CONCAT('v', cp.version, '.0'),
  'https://www.livfinder.com/legal/marketing-email',
  COALESCE(u.preferred_language_id, 1),
  CASE WHEN u.marketing_opt_in = 1 THEN 'double_opt_in' ELSE 'toggle' END,
  CASE WHEN u.marketing_opt_in = 1
       THEN DATE_ADD(u.created_at, INTERVAL 1 + MOD(u.id, 3) HOUR) END,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('ip:', u.id)), 1, 8), 16, 10)), 8, '0')),
  CASE WHEN u.marketing_opt_in = 1
       THEN 'https://www.livfinder.com/register'
       ELSE 'https://www.livfinder.com/account/notifications' END,
  (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  CASE WHEN u.marketing_opt_in = 1 THEN u.created_at END,
  CASE WHEN u.marketing_opt_in = 0
       THEN DATE_ADD(u.created_at, INTERVAL 30 + MOD(u.id, 200) DAY) END,
  CASE WHEN u.marketing_opt_in = 1
       THEN DATE_ADD(u.created_at, INTERVAL cp.expires_after_months MONTH) END,
  u.created_at
FROM users u
JOIN consent_purposes cp ON cp.code = 'marketing_email'
WHERE u.deleted_at IS NULL;

-- Cookie banner receipts. These are anonymous: a visitor identifier, no user.
-- Roughly two in three visitors accept analytics, fewer accept advertising,
-- which is what the consent rates in the analytics layer have to reconcile to.
INSERT INTO consent_receipts
  (public_id, purpose_id, purpose_version, visitor_id, action, notice_version,
   notice_url, language_id, mechanism, ip_address, page_url, tenant_id,
   granted_at, withdrawn_at, expires_at, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('cookie-consent:', v.visitor_id, ':', cp.code)), 26)),
  cp.id, cp.version, v.visitor_id,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT(v.visitor_id, cp.code)), 1, 4), 16, 10), 100) < cp.accept_rate
       THEN 'granted' ELSE 'withdrawn' END,
  CONCAT('v', cp.version, '.0'),
  'https://www.livfinder.com/legal/cookies', 1, 'button_click',
  UNHEX(LPAD(HEX(CONV(SUBSTRING(v.visitor_id, 1, 8), 16, 10)), 8, '0')),
  'https://www.livfinder.com/', (SELECT t.id FROM tenants t WHERE t.is_default = 1 LIMIT 1),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT(v.visitor_id, cp.code)), 1, 4), 16, 10), 100) < cp.accept_rate
       THEN v.seen_at END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT(v.visitor_id, cp.code)), 1, 4), 16, 10), 100) >= cp.accept_rate
       THEN v.seen_at END,
  DATE_ADD(v.seen_at, INTERVAL 13 MONTH), v.seen_at
FROM (
  SELECT LOWER(MD5(CONCAT('visitor:', u.id))) AS visitor_id,
         DATE_SUB(@now, INTERVAL MOD(u.id, 120) DAY) AS seen_at
  FROM users u
  WHERE MOD(u.id, 2) = 0
) AS v
JOIN (
  SELECT id, code, version,
         CASE code WHEN 'cookies_analytics' THEN 64 ELSE 38 END AS accept_rate
  FROM consent_purposes
  WHERE code IN ('cookies_analytics', 'cookies_marketing')
) AS cp;

-- -----------------------------------------------------------------------------
-- Subject requests and erasure records
--
-- The request is the ask; the erasure record is the proof of what was done about
-- it, kept separately and keyed by a hash rather than by the subject, so it
-- survives the erasure it documents.
-- -----------------------------------------------------------------------------
INSERT INTO data_subject_requests
  (public_id, user_id, request_type, status, notes, result_url, due_at,
   handled_by_user_id, completed_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('dsr:', u.id)), 26)),
  u.id,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dsr-type:', u.id)), 1, 4), 16, 10), 5),
      'export', 'deletion', 'rectification', 'restriction', 'objection'),
  r.status,
  r.notes,
  CASE WHEN r.status = 'completed'
            AND ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dsr-type:', u.id)), 1, 4), 16, 10), 5),
                    'export','deletion','rectification','restriction','objection') = 'export'
       THEN CONCAT('https://exports.livfinder.com/dsr/',
                   UPPER(LEFT(MD5(CONCAT('dsr:', u.id)), 26)), '.zip')
  END,
  -- One calendar month from receipt, the statutory deadline.
  DATE_ADD(r.requested_at, INTERVAL 1 MONTH),
  CASE WHEN r.status <> 'pending' THEN staff.id END,
  CASE WHEN r.status IN ('completed', 'rejected') THEN r.resolved_at END,
  r.requested_at,
  COALESCE(CASE WHEN r.status IN ('completed','rejected') THEN r.resolved_at END, r.requested_at)
FROM users u
JOIN (
  SELECT u2.id AS user_id,
         -- A request still open has to be inside its statutory month, or the
         -- operational alert that watches for exactly that fires on seed data.
         CASE WHEN MOD(u2.id, 10) IN (0, 1)
              THEN DATE_SUB(@now, INTERVAL 2 + MOD(u2.id, 18) DAY)
              ELSE DATE_SUB(@now, INTERVAL 5 + MOD(u2.id * 7, 400) DAY)
         END AS requested_at,
         DATE_SUB(@now, INTERVAL MOD(u2.id * 7, 400) DAY) AS resolved_at,
         CASE MOD(u2.id, 10)
           WHEN 0 THEN 'pending'
           WHEN 1 THEN 'in_progress'
           WHEN 2 THEN 'rejected'
           WHEN 3 THEN 'cancelled'
           ELSE 'completed'
         END AS status,
         CASE MOD(u2.id, 10)
           WHEN 2 THEN 'Refused in part: an open anti-money-laundering file requires the identity records to be retained. The subject was told which records are retained and why.'
           WHEN 3 THEN 'Withdrawn by the subject after the scope was explained.'
           WHEN 0 THEN 'Awaiting identity verification before the request can be actioned.'
           ELSE 'Actioned within the statutory period.'
         END AS notes
  FROM users u2
  WHERE MOD(u2.id, 7) = 0 AND u2.deleted_at IS NULL
) AS r ON r.user_id = u.id
LEFT JOIN users staff ON staff.id = 1 + MOD(u.id, 5);

INSERT INTO erasure_records
  (request_id, subject_hash, subject_type, erasure_type, tables_affected,
   rows_deleted, rows_anonymized, retained_tables, retention_justification,
   processors_notified, processors_confirmed_at, backups_scheduled_for,
   performed_by_user_id, performed_at, verification_hash)
SELECT
  d.id,
  LEFT(SHA2(CONCAT('subject:', u.email), 256), 64),
  'user',
  CASE WHEN MOD(d.id, 4) = 0 THEN 'full_deletion' ELSE 'anonymization' END,
  '["users","crm_contacts","inquiries","messages","saved_searches","consent_receipts","web_sessions","call_records"]',
  CASE WHEN MOD(d.id, 4) = 0 THEN 9 + MOD(d.id, 30) ELSE 2 + MOD(d.id, 6) END,
  CASE WHEN MOD(d.id, 4) = 0 THEN 0 ELSE 12 + MOD(d.id, 40) END,
  '["invoices","payments","journal_entries","kyc_cases","contracts"]',
  'Financial and anti-money-laundering records are retained under legal obligation. The subject was given the list of retained tables, the obligation relied on, and the date each retention expires.',
  '["email_delivery","crm","analytics","support_desk","cdn"]',
  DATE_ADD(d.completed_at, INTERVAL 2 DAY),
  -- Backups are not rewritten; the erasure is replayed when the backup rotates.
  DATE_ADD(DATE(d.completed_at), INTERVAL 35 DAY),
  d.handled_by_user_id,
  d.completed_at,
  LEFT(SHA2(CONCAT('erasure-verify:', d.id, ':', d.completed_at), 256), 64)
FROM data_subject_requests d
JOIN users u ON u.id = d.user_id
WHERE d.request_type = 'deletion' AND d.status = 'completed';

-- -----------------------------------------------------------------------------
-- Retention policies and runs
--
-- Each policy names a table, an anchor column and a window. Nothing is enabled
-- for real deletion until it has been through dry runs long enough to trust the
-- eligible-row count, which is why is_dry_run_only starts true and is cleared
-- deliberately.
-- -----------------------------------------------------------------------------
INSERT INTO retention_policies
  (code, name, table_name, anchor_column, filter_condition, retention_days,
   action, affected_columns, legal_basis, max_rows_per_run, requires_approval,
   is_dry_run_only, schedule_cron, is_active, last_run_at)
SELECT
  p.code, p.name, p.table_name, p.anchor_column, p.filter_condition, p.retention_days,
  p.action, p.affected_columns, p.legal_basis, p.max_rows_per_run, p.requires_approval,
  p.is_dry_run_only, p.schedule_cron, p.is_active,
  CASE WHEN p.is_active = 1 THEN DATE_SUB(@now, INTERVAL MOD(CRC32(p.code), 7) DAY) END
FROM (
  SELECT 'analytics_events_13m' AS code, 'Analytics events beyond thirteen months' AS name, 'analytics_events' AS table_name, 'occurred_at' AS anchor_column, NULL AS filter_condition, 395 AS retention_days, 'drop_partition' AS action, NULL AS affected_columns, 'Consent notice states a maximum thirteen-month analytics window.' AS legal_basis, 1000000 AS max_rows_per_run, 0 AS requires_approval, 0 AS is_dry_run_only, '0 3 1 * *' AS schedule_cron, 1 AS is_active
  UNION ALL SELECT 'web_sessions_90d','Web sessions beyond ninety days','web_sessions','started_at',NULL,90,'anonymize','["ip_address","user_agent"]','Operational abuse-investigation window.',200000,0,0,'0 3 * * *',1
  UNION ALL SELECT 'api_logs_30d','API request logs beyond thirty days','api_request_logs','occurred_at',NULL,30,'drop_partition',NULL,'Operational debugging only; no business need beyond a month.',1000000,0,0,'0 4 1 * *',1
  UNION ALL SELECT 'search_events_180d','Search result events beyond six months','search_result_events','occurred_at',NULL,180,'drop_partition',NULL,'Ranking evaluation window.',1000000,0,0,'0 4 1 * *',1
  UNION ALL SELECT 'call_recordings_180d','Call recordings beyond one hundred and eighty days','call_records','started_at','recording_url IS NOT NULL',180,'null_fields','["recording_url","transcript"]','Voice is treated as biometric; the window is set to the shortest that still supports dispute resolution.',50000,1,0,'0 2 * * *',1
  UNION ALL SELECT 'inquiries_3y','Enquiries beyond three years of inactivity','inquiries','created_at',"status IN ('closed','lost','spam')",1095,'anonymize','["name","email","phone","message","ip_address"]','Legitimate-interest window for enquiry handling.',50000,1,1,'0 2 * * 0',0
  UNION ALL SELECT 'contacts_3y','CRM contacts beyond three years of inactivity','crm_contacts','last_activity_at','do_not_contact = 0',1095,'anonymize','["first_name","last_name","email","phone_e164","notes"]','Legitimate-interest window; contacts who asked not to be contacted are excluded so the suppression survives.',50000,1,1,'0 2 * * 0',0
  UNION ALL SELECT 'leads_3y','Leads beyond three years','leads','created_at',"status IN ('lost','disqualified','closed')",1095,'anonymize','["source_url","landing_url"]','Matches the contact retention window.',50000,1,1,'0 2 * * 0',0
  UNION ALL SELECT 'deleted_users_30d','Closed accounts with no transaction','users','deleted_at','deleted_at IS NOT NULL',30,'anonymize','["email","email_normalized","phone_e164","phone_number","first_name","last_name","display_name","avatar_url","last_login_ip"]','Thirty days of reversal grace, then anonymisation. Accounts with a transaction fall under the seven-year policy instead.',10000,1,0,'0 1 * * *',1
  UNION ALL SELECT 'closed_accounts_7y','Closed accounts with a transaction history','users','deleted_at','deleted_at IS NOT NULL',2555,'anonymize','["email","phone_e164","first_name","last_name"]','Seven years for tax and dispute evidence.',10000,1,1,'0 1 1 * *',0
  UNION ALL SELECT 'auth_sessions_90d','Expired authentication sessions','sessions','expires_at',NULL,90,'delete',NULL,'No purpose once expired.',200000,0,0,'0 5 * * *',1
  UNION ALL SELECT 'audit_logs_7y','Audit log beyond seven years','audit_logs','occurred_at',NULL,2555,'drop_partition',NULL,'Retained for the longest applicable limitation period, then dropped.',1000000,1,1,'0 3 1 1 *',0
  UNION ALL SELECT 'notifications_180d','Read notifications beyond six months','notifications','created_at','read_at IS NOT NULL',180,'delete',NULL,'No purpose once read and stale.',200000,0,0,'0 5 * * *',1
  UNION ALL SELECT 'email_events_1y','Email delivery events beyond one year','message_delivery_events','occurred_at',NULL,365,'drop_partition',NULL,'Deliverability analysis window.',1000000,0,0,'0 4 1 * *',1
  UNION ALL SELECT 'ad_impressions_90d','Advertising impressions beyond ninety days','ad_impressions','occurred_at',NULL,90,'drop_partition',NULL,'Billing reconciliation window plus a margin.',1000000,0,0,'0 4 1 * *',1
  UNION ALL SELECT 'idempotency_keys_7d','Idempotency keys beyond seven days','idempotency_keys','created_at',NULL,7,'delete',NULL,'Retry windows never exceed twenty-four hours.',100000,0,0,'0 * * * *',1
  UNION ALL SELECT 'queue_messages_7d','Completed queue messages beyond seven days','queue_messages','completed_at',"status = 'completed'",7,'delete',NULL,'Operational only.',500000,0,0,'0 * * * *',1
  UNION ALL SELECT 'outbox_7d','Dispatched outbox events beyond seven days','outbox_events','dispatched_at',"status = 'dispatched'",7,'delete',NULL,'Operational only.',500000,0,0,'0 * * * *',1
  UNION ALL SELECT 'media_orphans_30d','Orphaned media beyond thirty days','media_assets','created_at','id NOT IN (SELECT asset_id FROM media_attachments)',30,'archive',NULL,'Uploads abandoned mid-form. Archived rather than deleted so a support request can still recover them.',20000,1,1,'0 6 * * 0',0
  UNION ALL SELECT 'kyc_5y','Closed KYC cases beyond five years','kyc_cases','closed_at',"status = 'closed'",1825,'archive','["document_number","document_image_url"]','Five years from the end of the business relationship under anti-money-laundering rules; archived, not destroyed, while any related contract stands.',10000,1,1,'0 3 1 * *',0
) AS p;

-- Run history: the policies that are live have been running on their schedule.
-- affected_rows equals eligible_rows minus what a legal hold blocked, which is
-- the arithmetic an auditor checks first.
INSERT INTO retention_runs
  (policy_id, was_dry_run, status, cutoff_date, eligible_rows, affected_rows,
   skipped_rows, held_rows, started_at, finished_at, duration_ms,
   error_message, triggered_by_user_id)
SELECT
  p.id,
  CASE WHEN p.is_dry_run_only = 1 THEN 1 ELSE 0 END,
  CASE
    WHEN r.n = 3 AND MOD(p.id, 6) = 0 THEN 'failed'
    WHEN held.rows_held > 0 AND p.is_dry_run_only = 0 AND r.n = 1 THEN 'blocked_by_hold'
    ELSE 'completed'
  END,
  DATE_SUB(DATE_SUB(@now, INTERVAL r.n * 7 DAY), INTERVAL p.retention_days DAY),
  elig.rows_eligible,
  CASE
    WHEN p.is_dry_run_only = 1 THEN 0
    WHEN r.n = 3 AND MOD(p.id, 6) = 0 THEN 0
    ELSE GREATEST(0, elig.rows_eligible - held.rows_held - MOD(p.id * r.n, 5))
  END,
  MOD(p.id * r.n, 5),
  held.rows_held,
  DATE_SUB(@now, INTERVAL r.n * 7 DAY),
  DATE_ADD(DATE_SUB(@now, INTERVAL r.n * 7 DAY), INTERVAL 1 + MOD(p.id * 13, 900) SECOND),
  (1 + MOD(p.id * 13, 900)) * 1000,
  CASE WHEN r.n = 3 AND MOD(p.id, 6) = 0
       THEN 'Lock wait timeout exceeded on the anchor index; the run was abandoned and retried on the next schedule.' END,
  NULL
FROM retention_policies p
CROSS JOIN (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) AS r
JOIN (
  SELECT p2.id AS policy_id,
         MOD(CONV(SUBSTRING(MD5(CONCAT('retention:', p2.code)), 1, 6), 16, 10), 48000) AS rows_eligible
  FROM retention_policies p2
) AS elig ON elig.policy_id = p.id
JOIN (
  SELECT p3.id AS policy_id,
         CASE WHEN p3.table_name IN ('users','crm_contacts','inquiries','kyc_cases','audit_logs','call_records')
              THEN MOD(CONV(SUBSTRING(MD5(CONCAT('hold:', p3.code)), 1, 4), 16, 10), 40)
              ELSE 0 END AS rows_held
  FROM retention_policies p3
) AS held ON held.policy_id = p.id;

-- -----------------------------------------------------------------------------
-- Legal holds
--
-- A hold overrides every retention policy and refuses every erasure request that
-- touches the rows it names. That is the whole point of it, which is why the
-- retention runs above report held_rows separately rather than quietly deleting
-- fewer rows.
-- -----------------------------------------------------------------------------
INSERT INTO legal_holds
  (public_id, reference, name, description, hold_type, subject_type, subject_ids,
   affected_tables, date_range_start, date_range_end, status, issued_by_user_id,
   issued_at, expected_release_date, released_at, released_by_user_id,
   release_reason, legal_reference)
SELECT
  UPPER(LEFT(MD5(CONCAT('hold:', h.reference)), 26)),
  h.reference, h.name, h.description, h.hold_type, h.subject_type,
  h.subject_ids, h.affected_tables,
  DATE_SUB(@today, INTERVAL h.range_start_days_ago DAY),
  CASE WHEN h.range_end_days_ago IS NOT NULL
       THEN DATE_SUB(@today, INTERVAL h.range_end_days_ago DAY) END,
  h.status,
  (SELECT id FROM users ORDER BY id LIMIT 1),
  DATE_SUB(@now, INTERVAL h.issued_days_ago DAY),
  DATE_ADD(@today, INTERVAL h.expected_release_in_days DAY),
  CASE WHEN h.status = 'released'
       THEN DATE_SUB(@now, INTERVAL h.issued_days_ago - 60 DAY) END,
  CASE WHEN h.status = 'released' THEN (SELECT id FROM users ORDER BY id LIMIT 1) END,
  CASE WHEN h.status = 'released' THEN h.release_reason END,
  h.legal_reference
FROM (
  SELECT 'LH-2024-0001' AS reference, 'Dubai Marina penthouse commission dispute' AS name,
         'Two agencies claim the introducing commission on a single completed sale. Every record touching the deal, the contract and the enquiry trail is held until the dispute resolves.' AS description,
         'dispute' AS hold_type, 'deal' AS subject_type, '[14,27,58]' AS subject_ids,
         '["deals","deal_commissions","contracts","inquiries","messages","call_records","audit_logs"]' AS affected_tables,
         420 AS range_start_days_ago, NULL AS range_end_days_ago, 'active' AS status,
         180 AS issued_days_ago, 240 AS expected_release_in_days,
         NULL AS release_reason, 'DIFC Courts claim CFI-2024-0518' AS legal_reference
  UNION ALL SELECT 'LH-2024-0002','Suspicious activity report follow-up',
         'A report was filed with the financial intelligence unit. The file, the counterparty identity records and the payment trail are held pending the unit''s response. Nobody outside the compliance team may be told the hold exists or why.',
         'regulatory','account','[31,44]',
         '["kyc_cases","kyc_documents","sanctions_screenings","payments","invoices","accounts","beneficial_owners"]',
         300,NULL,'active',150,365,NULL,'FIU reference SAR-2024-1177'
  UNION ALL SELECT 'LH-2023-0007','Former agent employment claim',
         'A former agent claims unpaid commission. Their user record, deal history and internal messages are held.',
         'litigation','user','[112]',
         '["users","deals","deal_commissions","messages","audit_logs","field_change_log"]',
         900,NULL,'released',700,0,'Claim settled and discontinued; the hold was released on written confirmation from counsel.','Employment Tribunal case 2311447/2023'
  UNION ALL SELECT 'LH-2025-0001','Tax authority audit, financial year 2023',
         'A routine audit of the 2023 financial year. All accounting records for the period are held for the duration.',
         'tax','all',NULL,
         '["invoices","invoice_lines","payments","refunds","journal_entries","journal_lines","tax_rates","tax_transactions"]',
         960,600,'active',95,180,NULL,'Audit notice 2025/FTA/00931'
  UNION ALL SELECT 'LH-2025-0002','Listing misrepresentation investigation',
         'A regulator is investigating whether a set of listings misrepresented completion dates. The listings, their revision history and the moderation decisions are held.',
         'investigation','listing','[41,88,153,204,311]',
         '["listings","listing_revisions","media_assets","moderation_decisions","field_change_log","entity_snapshots"]',
         240,NULL,'active',60,270,NULL,'RERA enquiry 2025-Q2-0044'
  UNION ALL SELECT 'LH-2022-0003','Data breach at a former processor',
         'The legacy bulk mail provider disclosed an incident. Records of what had been shared with them were held while the notification obligations were assessed.',
         'investigation','all',NULL,
         '["consent_receipts","suppressions","messages","message_delivery_events"]',
         1300,1100,'expired',1200,0,NULL,'Supervisory authority reference DPC-2022-8841'
) AS h;

-- -----------------------------------------------------------------------------
-- Field change log
--
-- The append-only record of what changed on the fields anyone later argues
-- about. Price is the obvious one -- a portal that cannot prove what a listing
-- was advertised at loses every dispute -- so it is derived from the real price
-- history rather than invented.
-- -----------------------------------------------------------------------------
INSERT INTO field_change_log
  (occurred_at, entity_type, entity_id, field_name, old_value, new_value,
   old_numeric, new_numeric, delta_numeric, delta_percent, change_type,
   actor_type, actor_user_id, organization_id, source, request_id, correlation_id)
SELECT
  h.changed_at, 'listing', h.listing_id, 'price',
  CAST(h.old_price AS CHAR), CAST(h.new_price AS CHAR),
  h.old_price, h.new_price, h.new_price - h.old_price,
  CASE WHEN h.old_price > 0
       THEN ROUND((h.new_price - h.old_price) / h.old_price * 100, 4) END,
  'update',
  CASE WHEN h.changed_by_user_id IS NULL THEN 'import' ELSE 'user' END,
  h.changed_by_user_id, l.organization_id,
  CASE WHEN h.changed_by_user_id IS NULL THEN 'feed_import' ELSE 'agent_portal' END,
  LEFT(MD5(CONCAT('req:', h.id)), 32),
  LEFT(MD5(CONCAT('corr:', h.listing_id)), 32)
FROM listing_price_history h
JOIN listings l ON l.id = h.listing_id;

-- Status transitions on the same listings. Every publication and withdrawal is
-- a fact somebody eventually asks about.
INSERT INTO field_change_log
  (occurred_at, entity_type, entity_id, field_name, old_value, new_value,
   change_type, actor_type, actor_user_id, organization_id, source,
   request_id, correlation_id)
SELECT
  COALESCE(l.published_at, l.created_at), 'listing', l.id, 'status',
  'pending_review', 'active', 'update', 'admin', mod_user.id, l.organization_id,
  'moderation_queue',
  LEFT(MD5(CONCAT('req-status:', l.id)), 32),
  LEFT(MD5(CONCAT('corr:', l.id)), 32)
FROM listings l
LEFT JOIN users mod_user ON mod_user.id = 1 + MOD(l.id, 5)
WHERE l.status = 'active' AND l.published_at IS NOT NULL;

INSERT INTO field_change_log
  (occurred_at, entity_type, entity_id, field_name, old_value, new_value,
   change_type, actor_type, actor_user_id, organization_id, source,
   request_id, correlation_id)
SELECT
  l.updated_at, 'listing', l.id, 'status', 'active', l.status,
  'update',
  CASE WHEN l.status = 'expired' THEN 'system' ELSE 'user' END,
  CASE WHEN l.status = 'expired' THEN NULL ELSE l.created_by_user_id END,
  l.organization_id,
  CASE WHEN l.status = 'expired' THEN 'expiry_job' ELSE 'agent_portal' END,
  LEFT(MD5(CONCAT('req-status2:', l.id)), 32),
  LEFT(MD5(CONCAT('corr:', l.id)), 32)
FROM listings l
WHERE l.status IN ('expired', 'sold', 'rented', 'withdrawn');

-- Deal stage movement, which is what a commission dispute is argued from.
INSERT INTO field_change_log
  (occurred_at, entity_type, entity_id, field_name, old_value, new_value,
   old_numeric, new_numeric, delta_numeric, change_type, actor_type,
   actor_user_id, organization_id, source, request_id, correlation_id)
SELECT
  COALESCE(d.offer_accepted_at, d.offer_made_at, d.created_at), 'deal', d.id,
  'agreed_amount',
  CAST(d.offer_amount AS CHAR), CAST(d.agreed_amount AS CHAR),
  d.offer_amount, d.agreed_amount, d.agreed_amount - d.offer_amount,
  'update', 'user', d.owner_agent_id, d.organization_id, 'deal_desk',
  LEFT(MD5(CONCAT('req-deal:', d.id)), 32),
  LEFT(MD5(CONCAT('corr-deal:', d.id)), 32)
FROM deals d
WHERE d.agreed_amount IS NOT NULL AND d.offer_amount IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Entity snapshots
--
-- A full copy of an entity at a moment that matters. The point is not backup --
-- that is a different mechanism -- but evidence: what exactly did this contract
-- say when it was signed, what exactly did this listing claim when it was
-- published. content_hash seals it.
-- -----------------------------------------------------------------------------
INSERT INTO entity_snapshots
  (entity_type, entity_id, snapshot_reason, payload, content_hash, schema_version,
   trigger_type, trigger_id, actor_user_id, organization_id, retain_until,
   is_legal_record, created_at)
SELECT
  'contract', c.id, 'executed',
  JSON_OBJECT(
    'reference', c.reference,
    'contract_type', c.contract_type,
    'title', c.title,
    'organization_id', c.organization_id,
    'listing_id', c.listing_id,
    'deal_id', c.deal_id,
    'value_amount', c.value_amount,
    'currency_code', c.currency_code,
    'commission_rate', c.commission_rate,
    'starts_on', c.starts_on,
    'ends_on', c.ends_on,
    'governing_law', c.governing_law,
    'jurisdiction', c.jurisdiction,
    'body_hash', c.content_hash,
    'executed_at', c.executed_at
  ),
  LEFT(SHA2(CONCAT('snapshot:contract:', c.id, ':', COALESCE(c.content_hash, '')), 256), 64),
  '1.0', 'contract', c.id, c.created_by_user_id, c.organization_id,
  DATE_ADD(DATE(COALESCE(c.executed_at, c.created_at)), INTERVAL 10 YEAR),
  1, COALESCE(c.executed_at, c.created_at)
FROM contracts c
WHERE c.status IN ('executed', 'active', 'completed', 'terminated', 'expired');

INSERT INTO entity_snapshots
  (entity_type, entity_id, snapshot_reason, payload, content_hash, schema_version,
   trigger_type, trigger_id, actor_user_id, organization_id, retain_until,
   is_legal_record, created_at)
SELECT
  'listing', l.id, 'published',
  JSON_OBJECT(
    'title', l.title,
    'slug', l.slug,
    'category_id', l.category_id,
    'purpose_id', l.purpose_id,
    'price', l.price,
    'currency_code', l.currency_code,
    'price_base', l.price_base,
    'country_id', l.country_id,
    'city_id', l.city_id,
    'community_id', l.community_id,
    'organization_id', l.organization_id,
    'agent_id', l.agent_id,
    'published_at', l.published_at
  ),
  LEFT(SHA2(CONCAT('snapshot:listing:', l.id, ':', COALESCE(l.published_at, '')), 256), 64),
  '1.0', 'system', NULL, l.created_by_user_id, l.organization_id,
  DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 7 YEAR),
  0, COALESCE(l.published_at, l.created_at)
FROM listings l
WHERE l.published_at IS NOT NULL;

INSERT INTO entity_snapshots
  (entity_type, entity_id, snapshot_reason, payload, content_hash, schema_version,
   trigger_type, trigger_id, actor_user_id, organization_id, retain_until,
   is_legal_record, created_at)
SELECT
  'deal', d.id, 'completed',
  JSON_OBJECT(
    'reference', d.reference,
    'deal_type', d.deal_type,
    'listing_id', d.listing_id,
    'contact_id', d.contact_id,
    'agreed_amount', d.agreed_amount,
    'final_amount', d.final_amount,
    'currency_code', d.currency_code,
    'gross_commission', d.gross_commission,
    'net_commission', d.net_commission,
    'owner_agent_id', d.owner_agent_id,
    'is_co_brokered', d.is_co_brokered,
    'permit_number', d.permit_number,
    'completed_at', d.completed_at
  ),
  LEFT(SHA2(CONCAT('snapshot:deal:', d.id, ':', COALESCE(d.completed_at, '')), 256), 64),
  '1.0', 'deal', d.id, d.owner_agent_id, d.organization_id,
  DATE_ADD(DATE(d.completed_at), INTERVAL 10 YEAR),
  1, d.completed_at
FROM deals d
WHERE d.completed_at IS NOT NULL;

-- Snapshots taken because a legal hold landed on the record. These carry the
-- hold as the trigger, so releasing the hold can find everything it froze.
INSERT INTO entity_snapshots
  (entity_type, entity_id, snapshot_reason, payload, content_hash, schema_version,
   trigger_type, trigger_id, actor_user_id, organization_id, retain_until,
   is_legal_record, created_at)
SELECT
  'listing', l.id, 'legal_hold',
  JSON_OBJECT(
    'hold_reference', h.reference,
    'title', l.title,
    'status', l.status,
    'price', l.price,
    'currency_code', l.currency_code,
    'organization_id', l.organization_id,
    'frozen_at', h.issued_at
  ),
  LEFT(SHA2(CONCAT('snapshot:hold:', h.id, ':', l.id), 256), 64),
  '1.0', 'incident', h.id, h.issued_by_user_id, l.organization_id,
  DATE_ADD(@today, INTERVAL 10 YEAR), 1, h.issued_at
FROM legal_holds h
JOIN listings l ON JSON_CONTAINS(h.subject_ids, CAST(l.id AS CHAR))
WHERE h.subject_type = 'listing' AND h.status = 'active';
