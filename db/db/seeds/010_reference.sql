-- =============================================================================
-- Liv Finder — seed 010 · Reference data
-- =============================================================================
-- Languages, currencies, FX rates, units, platform settings and feature flags.
--
-- Load this first: the geography seed's translations reference `languages`, and
-- almost everything else references `currencies`.
--
-- AED is the base currency. Every *_base column in the schema is denominated in
-- it, so changing this is a data migration, not a config change.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Languages
--
-- The 12 the platform actually ships UI and content in. Arabic and Farsi are
-- RTL; the `direction` column exists so the frontend never has to hardcode a
-- list of RTL locales.
-- -----------------------------------------------------------------------------
INSERT INTO languages (code, name, native_name, direction, is_active, is_default, sort_order) VALUES
  ('en',    'English',            'English',    'ltr', 1, 1,  1),
  ('ar',    'Arabic',             'العربية',     'rtl', 1, 0,  2),
  ('fr',    'French',             'Français',   'ltr', 1, 0,  3),
  ('de',    'German',             'Deutsch',    'ltr', 1, 0,  4),
  ('es',    'Spanish',            'Español',    'ltr', 1, 0,  5),
  ('it',    'Italian',            'Italiano',   'ltr', 1, 0,  6),
  ('pt',    'Portuguese',         'Português',  'ltr', 1, 0,  7),
  ('ru',    'Russian',            'Русский',    'ltr', 1, 0,  8),
  ('zh',    'Chinese (Simplified)', '简体中文',   'ltr', 1, 0,  9),
  ('tr',    'Turkish',            'Türkçe',     'ltr', 1, 0, 10),
  ('nl',    'Dutch',              'Nederlands', 'ltr', 1, 0, 11),
  ('fa',    'Persian',            'فارسی',      'rtl', 1, 0, 12),
  ('ja',    'Japanese',           '日本語',      'ltr', 0, 0, 13),
  ('ko',    'Korean',             '한국어',      'ltr', 0, 0, 14),
  ('hi',    'Hindi',              'हिन्दी',        'ltr', 0, 0, 15);

-- -----------------------------------------------------------------------------
-- Currencies
--
-- `minor_unit` follows ISO 4217: KWD/BHD/OMR are 3-decimal currencies and JPY
-- has none. Formatting code must read this rather than assuming two.
-- -----------------------------------------------------------------------------
INSERT INTO currencies (code, numeric_code, name, symbol, symbol_native, minor_unit, symbol_position, is_active, is_base, sort_order) VALUES
  ('AED', '784', 'UAE Dirham',           'AED', 'د.إ', 2, 'before', 1, 1,  1),
  ('USD', '840', 'US Dollar',            '$',   '$',   2, 'before', 1, 0,  2),
  ('EUR', '978', 'Euro',                 '€',   '€',   2, 'before', 1, 0,  3),
  ('GBP', '826', 'Pound Sterling',       '£',   '£',   2, 'before', 1, 0,  4),
  ('CHF', '756', 'Swiss Franc',          'CHF', 'Fr.', 2, 'before', 1, 0,  5),
  ('SAR', '682', 'Saudi Riyal',          'SAR', 'ر.س', 2, 'before', 1, 0,  6),
  ('QAR', '634', 'Qatari Riyal',         'QAR', 'ر.ق', 2, 'before', 1, 0,  7),
  ('KWD', '414', 'Kuwaiti Dinar',        'KWD', 'د.ك', 3, 'before', 1, 0,  8),
  ('BHD', '048', 'Bahraini Dinar',       'BHD', 'د.ب', 3, 'before', 1, 0,  9),
  ('OMR', '512', 'Omani Rial',           'OMR', 'ر.ع', 3, 'before', 1, 0, 10),
  ('SGD', '702', 'Singapore Dollar',     'S$',  'S$',  2, 'before', 1, 0, 11),
  ('HKD', '344', 'Hong Kong Dollar',     'HK$', 'HK$', 2, 'before', 1, 0, 12),
  ('AUD', '036', 'Australian Dollar',    'A$',  'A$',  2, 'before', 1, 0, 13),
  ('CAD', '124', 'Canadian Dollar',      'C$',  'C$',  2, 'before', 1, 0, 14),
  ('JPY', '392', 'Japanese Yen',         '¥',   '¥',   0, 'before', 1, 0, 15),
  ('CNY', '156', 'Chinese Yuan',         '¥',   '¥',   2, 'before', 1, 0, 16),
  ('INR', '356', 'Indian Rupee',         '₹',   '₹',   2, 'before', 1, 0, 17),
  ('TRY', '949', 'Turkish Lira',         '₺',   '₺',   2, 'before', 1, 0, 18),
  ('ZAR', '710', 'South African Rand',   'R',   'R',   2, 'before', 1, 0, 19),
  ('BRL', '986', 'Brazilian Real',       'R$',  'R$',  2, 'before', 1, 0, 20),
  ('MXN', '484', 'Mexican Peso',         'MX$', '$',   2, 'before', 1, 0, 21),
  ('THB', '764', 'Thai Baht',            '฿',   '฿',   2, 'before', 1, 0, 22),
  ('EGP', '818', 'Egyptian Pound',       'E£',  'ج.م', 2, 'before', 1, 0, 23),
  ('MAD', '504', 'Moroccan Dirham',      'MAD', 'د.م', 2, 'before', 1, 0, 24);

-- -----------------------------------------------------------------------------
-- FX rates
--
-- Indicative mid-market rates against AED. The Gulf pegs (SAR, QAR, BHD, OMR,
-- and AED itself against USD) are fixed by policy and effectively constant; the
-- floating pairs are a snapshot and are refreshed by the `fx_refresh` job.
--
-- Seeded so that price_base is computable from day one — without at least one
-- rate per active currency, cross-currency sorting silently produces NULLs.
-- -----------------------------------------------------------------------------
INSERT INTO fx_rates (base_code, quote_code, rate, as_of_date, source) VALUES
  ('AED', 'AED', 1.0000000000,   '2026-08-01', 'seed'),
  ('AED', 'USD', 0.2722500000,   '2026-08-01', 'seed'),
  ('AED', 'EUR', 0.2510000000,   '2026-08-01', 'seed'),
  ('AED', 'GBP', 0.2140000000,   '2026-08-01', 'seed'),
  ('AED', 'CHF', 0.2380000000,   '2026-08-01', 'seed'),
  ('AED', 'SAR', 1.0210000000,   '2026-08-01', 'seed'),
  ('AED', 'QAR', 0.9910000000,   '2026-08-01', 'seed'),
  ('AED', 'KWD', 0.0834000000,   '2026-08-01', 'seed'),
  ('AED', 'BHD', 0.1026000000,   '2026-08-01', 'seed'),
  ('AED', 'OMR', 0.1048000000,   '2026-08-01', 'seed'),
  ('AED', 'SGD', 0.3630000000,   '2026-08-01', 'seed'),
  ('AED', 'HKD', 2.1240000000,   '2026-08-01', 'seed'),
  ('AED', 'AUD', 0.4180000000,   '2026-08-01', 'seed'),
  ('AED', 'CAD', 0.3760000000,   '2026-08-01', 'seed'),
  ('AED', 'JPY', 40.9500000000,  '2026-08-01', 'seed'),
  ('AED', 'CNY', 1.9560000000,   '2026-08-01', 'seed'),
  ('AED', 'INR', 23.7500000000,  '2026-08-01', 'seed'),
  ('AED', 'TRY', 9.2800000000,   '2026-08-01', 'seed'),
  ('AED', 'ZAR', 4.9600000000,   '2026-08-01', 'seed'),
  ('AED', 'BRL', 1.5100000000,   '2026-08-01', 'seed'),
  ('AED', 'MXN', 5.1200000000,   '2026-08-01', 'seed'),
  ('AED', 'THB', 8.8600000000,   '2026-08-01', 'seed'),
  ('AED', 'EGP', 13.2400000000,  '2026-08-01', 'seed'),
  ('AED', 'MAD', 2.6700000000,   '2026-08-01', 'seed');

-- The hot-path table the application actually reads.
INSERT INTO fx_rates_latest (base_code, quote_code, rate, as_of_date)
SELECT base_code, quote_code, rate, as_of_date FROM fx_rates;

-- Inverse direction, so converting *to* AED is also a single lookup rather than
-- a division the caller has to remember to do.
INSERT INTO fx_rates_latest (base_code, quote_code, rate, as_of_date)
SELECT quote_code, base_code, 1 / rate, as_of_date
  FROM fx_rates
 WHERE quote_code <> 'AED';

-- -----------------------------------------------------------------------------
-- Measurement units
--
-- Canonical unit per dimension has to_canonical = 1. Areas are stored in m²,
-- lengths in metres, speeds in km/h, distances in km.
-- -----------------------------------------------------------------------------
INSERT INTO measurement_units (code, dimension, name, symbol, to_canonical, is_canonical) VALUES
  ('sqm',       'area',     'Square metre',      'm²',    1.000000000000, 1),
  ('sqft',      'area',     'Square foot',       'sqft',  0.092903040000, 0),
  ('acre',      'area',     'Acre',              'ac',    4046.856422400, 0),
  ('hectare',   'area',     'Hectare',           'ha',    10000.00000000, 0),
  ('dunam',     'area',     'Dunam',             'dunam', 1000.000000000, 0),
  ('m',         'length',   'Metre',             'm',     1.000000000000, 1),
  ('ft',        'length',   'Foot',              'ft',    0.304800000000, 0),
  ('mm',        'length',   'Millimetre',        'mm',    0.001000000000, 0),
  ('km',        'distance', 'Kilometre',         'km',    1.000000000000, 1),
  ('mi',        'distance', 'Mile',              'mi',    1.609344000000, 0),
  ('nm',        'distance', 'Nautical mile',     'NM',    1.852000000000, 0),
  ('kmh',       'speed',    'Kilometres / hour', 'km/h',  1.000000000000, 1),
  ('mph',       'speed',    'Miles / hour',      'mph',   1.609344000000, 0),
  ('knot',      'speed',    'Knot',              'kn',    1.852000000000, 0),
  ('kw',        'power',    'Kilowatt',          'kW',    1.000000000000, 1),
  ('hp',        'power',    'Horsepower',        'hp',    0.745699872000, 0),
  ('l',         'volume',   'Litre',             'L',     1.000000000000, 1),
  ('gal_us',    'volume',   'US gallon',         'gal',   3.785411784000, 0),
  ('kg',        'weight',   'Kilogram',          'kg',    1.000000000000, 1),
  ('tonne',     'weight',   'Tonne',             't',     1000.000000000, 0);

-- -----------------------------------------------------------------------------
-- Settings
--
-- Backs the admin portal's General / Payment / SEO & Analytics screens.
-- `is_public` marks rows safe to serialise to the browser; `is_secret` marks
-- rows that must never leave the server even to an admin UI.
-- -----------------------------------------------------------------------------
INSERT INTO settings (group_key, setting_key, value, value_type, label, is_public, is_secret) VALUES
  ('general', 'site_name',              'Liv Finder',                    'string',  'Site name',                 1, 0),
  ('general', 'site_tagline',           'The global luxury marketplace', 'string',  'Tagline',                   1, 0),
  ('general', 'site_url',               'https://livfinder.com',         'string',  'Canonical site URL',        1, 0),
  ('general', 'support_email',          'support@livfinder.com',         'string',  'Support email',             1, 0),
  ('general', 'support_phone',          '+971 4 000 0000',               'string',  'Support phone',             1, 0),
  ('general', 'default_language',       'en',                            'string',  'Default language',          1, 0),
  ('general', 'default_currency',       'AED',                           'string',  'Default currency',          1, 0),
  ('general', 'default_country',        'AE',                            'string',  'Default country',           1, 0),
  ('general', 'default_area_unit',      'sqft',                          'string',  'Default area unit',         1, 0),
  ('general', 'timezone',               'Asia/Dubai',                    'string',  'Platform timezone',         1, 0),
  ('general', 'maintenance_mode',       '0',                             'boolean', 'Maintenance mode',          0, 0),

  ('listings', 'default_expiry_days',   '90',                            'integer', 'Listing expiry (days)',     0, 0),
  ('listings', 'require_moderation',    '1',                             'boolean', 'Moderate before publish',   0, 0),
  ('listings', 'max_images',            '40',                            'integer', 'Max images per listing',    1, 0),
  ('listings', 'max_image_mb',          '12',                            'integer', 'Max image size (MB)',       1, 0),
  ('listings', 'min_images_to_publish', '3',                             'integer', 'Min images to publish',     1, 0),
  ('listings', 'refresh_cooldown_hours','24',                            'integer', 'Refresh cooldown (hours)',  0, 0),
  -- The audit found Call/WhatsApp buttons dead site-wide. These flags let the
  -- channels be enabled per-platform once the data is in place.
  ('listings', 'enable_call_button',    '1',                             'boolean', 'Enable Call button',        1, 0),
  ('listings', 'enable_whatsapp_button','1',                             'boolean', 'Enable WhatsApp button',    1, 0),

  ('payment', 'provider',               'stripe',                        'string',  'Payment provider',          0, 0),
  ('payment', 'currency',               'AED',                           'string',  'Billing currency',          0, 0),
  ('payment', 'tax_rate',               '5.000',                         'decimal', 'VAT rate (%)',              0, 0),
  ('payment', 'tax_label',              'VAT',                           'string',  'Tax label',                 1, 0),
  ('payment', 'invoice_prefix',         'LF-INV',                        'string',  'Invoice number prefix',     0, 0),
  ('payment', 'payout_minimum',         '500.00',                        'decimal', 'Minimum payout',            0, 0),
  ('payment', 'payout_schedule',        'monthly',                       'string',  'Payout schedule',           0, 0),

  ('seo', 'default_title_suffix',       ' | Liv Finder',                 'string',  'Title suffix',              1, 0),
  ('seo', 'default_meta_description',   'Discover the world''s finest property, cars, yachts, jets, helicopters and watches.', 'text', 'Default meta description', 1, 0),
  ('seo', 'robots_allow_indexing',      '1',                             'boolean', 'Allow indexing',            0, 0),
  ('seo', 'sitemap_max_urls',           '45000',                         'integer', 'Max URLs per sitemap file', 0, 0),
  ('seo', 'google_analytics_id',        '',                              'string',  'GA4 measurement ID',        1, 0),
  ('seo', 'google_tag_manager_id',      '',                              'string',  'GTM container ID',          1, 0),

  ('security', 'session_lifetime_days', '30',                            'integer', 'Session lifetime (days)',   0, 0),
  ('security', 'max_login_attempts',    '5',                             'integer', 'Max login attempts',        0, 0),
  ('security', 'lockout_minutes',       '15',                            'integer', 'Lockout duration (min)',    0, 0),
  ('security', 'password_min_length',   '8',                             'integer', 'Minimum password length',   1, 0),
  ('security', 'require_mfa_for_admin', '1',                             'boolean', 'Require MFA for staff',     0, 0),
  ('security', 'inquiry_rate_limit',    '10',                            'integer', 'Enquiries per hour per IP', 0, 0);

-- -----------------------------------------------------------------------------
-- Feature flags
--
-- Everything the audit listed as "designed but not built" is represented here as
-- an explicitly-off flag, so the capability is discoverable rather than implied.
-- -----------------------------------------------------------------------------
INSERT INTO feature_flags (flag_key, name, description, is_enabled, rollout_percentage) VALUES
  ('account_type_switching', 'Account type switching',
   'Lets an existing account request a change between personal, lister, company, organisation and partner types.', 0, 0),
  ('organization_roles',     'Organisation role enforcement',
   'Enforces owner/manager/agent/viewer permissions inside an organisation account.', 0, 0),
  ('whatsapp_contact',       'WhatsApp contact button',
   'Renders the WhatsApp lead-generation button on listing detail pages.', 1, 100),
  ('saved_search_alerts',    'Saved search alerts',
   'Sends email/push alerts when a saved search gains matching listings.', 1, 100),
  ('price_history',          'Price history on detail pages',
   'Shows the price-change chart and "reduced by" badge.', 1, 100),
  ('map_search',             'Map / radius search',
   'Draw-on-map and within-radius search. Requires migration 0015 on MySQL 8.', 0, 0),
  ('multi_currency_display', 'Multi-currency display',
   'Lets a visitor switch the displayed currency using live FX rates.', 1, 100),
  ('machine_translation',    'Machine translation of listings',
   'Auto-translates listing titles and descriptions into the visitor locale.', 0, 0),
  ('virtual_tours',          'Virtual tours', 'Embedded 360/Matterport tours.', 1, 100),
  ('offers_module',          'Offers and counter-offers',
   'Structured offer submission and negotiation on listings.', 0, 25),
  ('partner_api',            'Partner API access',
   'Third-party API clients and outbound webhooks.', 0, 0);

-- -----------------------------------------------------------------------------
-- Scheduled jobs
--
-- Registered here rather than only in a crontab, so the admin portal can show
-- what is meant to run, when it last succeeded, and whether its output is stale.
-- Every derived structure in this schema has a job that maintains it.
-- -----------------------------------------------------------------------------
INSERT INTO jobs (code, name, description, schedule_cron, is_enabled, max_staleness_minutes) VALUES
  ('fx_refresh',            'Refresh FX rates',
   'Pulls mid-market rates and updates fx_rates + fx_rates_latest.', '0 */6 * * *', 1, 720),
  ('listing_search_refresh','Reconcile search projection',
   'Calls sp_refresh_listing_search for rows whose source_updated_at lags listings.updated_at.', '*/5 * * * *', 1, 30),
  ('entity_counters',       'Recompute entity counters',
   'Calls sp_refresh_entity_counters. Bounds drift on all denormalised counts.', '15 2 * * *', 1, 2880),
  ('location_counts',       'Recompute location listing counts',
   'Calls sp_location_refresh_counts, rolling counts up the location subtree.', '30 2 * * *', 1, 2880),
  ('analytics_rollup',      'Roll up analytics events',
   'Aggregates analytics_events into the *_daily_stats tables.', '10 * * * *', 1, 180),
  ('listing_expiry',        'Expire lapsed listings',
   'Moves listings past expires_at to status=expired and drops them from the projection.', '5 * * * *', 1, 120),
  ('saved_search_alerts',   'Dispatch saved-search alerts',
   'Runs due saved searches and queues alerts for new matches.', '0 7 * * *', 1, 1440),
  ('sitemap_rebuild',       'Rebuild sitemap entries',
   'Regenerates sitemap_entries from resolvable canonical paths and verifies them.', '0 3 * * *', 1, 2880),
  ('partition_maintenance', 'Maintain time partitions',
   'Adds next month partitions and drops those past retention on the event tables.', '0 4 1 * *', 1, 44640),
  ('session_cleanup',       'Reap expired sessions and tokens',
   'Deletes expired user_sessions and user_tokens in bounded batches.', '20 4 * * *', 1, 2880),
  ('license_expiry_check',  'Check licence expiry',
   'Demotes organisations and agents whose licences or verifications have lapsed.', '0 5 * * *', 1, 2880),
  ('price_index',           'Recompute price index',
   'Rebuilds price_index_daily per location/category/purpose.', '45 3 * * *', 1, 2880);
