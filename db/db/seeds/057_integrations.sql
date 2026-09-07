-- =============================================================================
-- Liv Finder — seed 057 · Feeds, syndication and integrations
-- =============================================================================
-- The provider catalogue is the real one. Every portal listed here is a system
-- an agency in these markets genuinely publishes to, with its actual transport
-- and format — and the differences between them are the whole reason the
-- mapping tables exist:
--
--   Property Finder  JSON over HTTPS, and it pushes leads back
--   Bayut            XML over HTTPS, leads back, Trakheesi permit mandatory
--   Dubizzle         XML, shares Bayut's platform, separate quota
--   JamesEdition     XML over FTP, minimum price threshold, no leads back
--   Rightmove        the ancient Rightmove ADF over FTP, UK only
--   Zillow           RETS, US only, and a schema that predates the web
--   Idealista        JSON, Spain and Portugal
--   YachtWorld       XML, marine only
--   Chrono24         JSON, watches only, commission model
--
-- Inbound, agencies arrive with Reapit, PropSpace, MasterKey or a spreadsheet.
-- The field and value mappings below are what let a new one be onboarded as
-- configuration rather than as a release.
--
-- Nothing here stores a credential. `credential_ref` names a secret in the
-- secrets manager; a schema that keeps the key in a VARCHAR turns one database
-- dump into a breach of every connected agency's portal account.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

INSERT INTO integration_providers
  (code, name, provider_kind, direction, transport, format, auth_type, base_url,
   docs_url, supported_categories, supported_countries, rate_limit_per_minute,
   max_batch_size, min_interval_minutes, returns_leads, returns_stats, status, notes)
VALUES
  ('property_finder', 'Property Finder', 'portal', 'bidirectional', 'http_api',
   'json', 'api_key', 'https://api.propertyfinder.example.com/v2', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('AE','QA','BH','EG'),
   120, 200, 30, 1, 1, 'available',
   'Leads are pushed back over webhook within seconds. The most valuable portal integration in the Gulf for exactly that reason.'),

  ('bayut', 'Bayut', 'portal', 'bidirectional', 'http_api', 'xml', 'basic',
   'https://api.bayut.example.com/v1', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('AE','SA','EG','PK'),
   60, 500, 60, 1, 1, 'available',
   'Rejects any UAE listing without a valid Trakheesi permit number. See the validation rules below.'),

  ('dubizzle', 'Dubizzle', 'portal', 'outbound', 'http_api', 'xml', 'basic',
   'https://api.dubizzle.example.com/v1', NULL,
   JSON_ARRAY('real-estate','cars'), JSON_ARRAY('AE','SA','EG'),
   60, 500, 60, 1, 0, 'available',
   'Shares Bayut''s platform but carries a separate contract and a separate quota.'),

  ('james_edition', 'JamesEdition', 'portal', 'outbound', 'ftp', 'xml',
   'ftp_credentials', NULL, NULL,
   JSON_ARRAY('real-estate','yachts','jets','helicopters','watches','cars'), NULL,
   NULL, 1000, 1440, 0, 0, 'available',
   'Luxury only, with a minimum price threshold enforced by the channel. Daily FTP drop; no lead return.'),

  ('rightmove', 'Rightmove', 'portal', 'outbound', 'ftp', 'xml',
   'ftp_credentials', NULL, NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('GB'),
   NULL, 500, 60, 0, 1, 'available',
   'The Rightmove ADF format, which predates most of the web and shows it. Fixed field ordering, strict length limits.'),

  ('zoopla', 'Zoopla', 'portal', 'outbound', 'ftp', 'xml', 'ftp_credentials',
   NULL, NULL, JSON_ARRAY('real-estate'), JSON_ARRAY('GB'),
   NULL, 500, 60, 1, 1, 'available', NULL),

  ('zillow', 'Zillow', 'portal', 'outbound', 'http_api', 'rets', 'oauth2',
   'https://api.zillow.example.com/v1', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('US'),
   30, 100, 120, 0, 1, 'beta',
   'RETS. Feels like filing a tax return in XML.'),

  ('idealista', 'Idealista', 'portal', 'outbound', 'http_api', 'json', 'oauth2',
   'https://api.idealista.example.com/3.5', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('ES','PT','IT'),
   100, 200, 60, 1, 1, 'available', NULL),

  ('yachtworld', 'YachtWorld', 'portal', 'outbound', 'ftp', 'xml',
   'ftp_credentials', NULL, NULL, JSON_ARRAY('yachts'), NULL,
   NULL, 500, 1440, 0, 1, 'available', NULL),

  ('chrono24', 'Chrono24', 'portal', 'bidirectional', 'http_api', 'json',
   'api_key', 'https://api.chrono24.example.com/v1', NULL,
   JSON_ARRAY('watches'), NULL, 60, 100, 60, 1, 1, 'available',
   'Commission on sale rather than a listing fee, so the economics are inverted relative to every property portal.'),

  ('reapit', 'Reapit', 'crm', 'inbound', 'http_api', 'json', 'oauth2',
   'https://platform.reapit.example.com', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('GB','AE'),
   200, 100, 15, 0, 0, 'available',
   'The dominant UK agency CRM. Well documented, which is not universal in this category.'),

  ('propspace', 'PropSpace', 'crm', 'inbound', 'http_api', 'xml', 'api_key',
   'https://api.propspace.example.com', NULL,
   JSON_ARRAY('real-estate'), JSON_ARRAY('AE','SA','QA'),
   60, 200, 30, 0, 0, 'available', 'Widely used across Gulf brokerages.'),

  ('masterkey', 'MasterKey', 'crm', 'inbound', 'ftp', 'xml', 'ftp_credentials',
   NULL, NULL, JSON_ARRAY('real-estate'), JSON_ARRAY('AE'),
   NULL, 1000, 60, 0, 0, 'available', NULL),

  ('generic_xml', 'Generic XML feed', 'crm', 'inbound', 'http_api', 'xml',
   'none', NULL, NULL, NULL, NULL, NULL, 2000, 60, 0, 0, 'available',
   'The fallback for an agency with a bespoke system. Field mappings are configured per connection.'),

  ('csv_upload', 'Spreadsheet upload', 'crm', 'inbound', 'manual_upload', 'excel',
   'none', NULL, NULL, NULL, NULL, NULL, 5000, NULL, 0, 0, 'available',
   'More agencies than anyone would like to admit run on a spreadsheet.'),

  ('dld_trakheesi', 'Dubai Land Department — Trakheesi', 'mls', 'bidirectional',
   'http_api', 'json', 'api_key', 'https://trakheesi.dubailand.example.gov.ae/api',
   NULL, JSON_ARRAY('real-estate'), JSON_ARRAY('AE'),
   30, 1, 5, 0, 0, 'available',
   'Permit issuance and verification. Not a portal — a regulator.'),

  ('google_maps', 'Google Maps Platform', 'maps', 'outbound', 'http_api', 'json',
   'api_key', 'https://maps.googleapis.example.com/maps/api', NULL, NULL, NULL,
   600, 1, NULL, 0, 0, 'available', 'Geocoding and place detail.'),

  ('docusign', 'DocuSign', 'signature', 'bidirectional', 'http_api', 'json',
   'oauth2', 'https://api.docusign.example.net/restapi', NULL, NULL, NULL,
   100, 1, NULL, 0, 0, 'available', NULL),

  ('xero', 'Xero', 'accounting', 'outbound', 'http_api', 'json', 'oauth2',
   'https://api.xero.example.com/api.xro/2.0', NULL, NULL, NULL,
   60, 50, 60, 0, 0, 'available', 'Invoice and journal export.');

-- -----------------------------------------------------------------------------
-- Connections
--
-- One per organisation per portal, for the agencies large enough to syndicate.
-- The credential reference points at a secrets manager path; the fingerprint is
-- a hash used only for change detection.
-- -----------------------------------------------------------------------------
INSERT INTO integration_connections
  (public_id, provider_id, organization_id, account_id, name, direction,
   credential_ref, credential_fingerprint, external_account_id, endpoint_url,
   status, last_connected_at, consecutive_failures, is_enabled, schedule_cron,
   next_run_at, last_run_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('conn:', o.id, ':', p.code)), 26)),
  p.id, o.id, o.account_id,
  CONCAT(o.name, ' → ', p.name),
  p.direction,
  CONCAT('secretsmanager://integrations/', p.code, '/org-', o.id),
  SHA2(CONCAT('cred:', o.id, ':', p.code), 256),
  CONCAT(UPPER(LEFT(p.code, 3)), '-', LPAD(o.id, 6, '0')),
  p.base_url, 'connected',
  DATE_SUB(NOW(3), INTERVAL MOD(o.id, 12) HOUR), 0, 1,
  '0 */6 * * *',
  DATE_ADD(NOW(3), INTERVAL (6 - MOD(o.id, 6)) HOUR),
  DATE_SUB(NOW(3), INTERVAL MOD(o.id, 6) HOUR),
  o.created_at, NOW(3)
FROM organizations o
JOIN integration_providers p
  ON p.code IN ('property_finder', 'bayut', 'dubizzle')
WHERE o.deleted_at IS NULL AND o.active_listing_count >= 5;

-- JamesEdition only for the agencies with genuinely luxury inventory, which is
-- what its own contract requires.
INSERT INTO integration_connections
  (public_id, provider_id, organization_id, account_id, name, direction,
   credential_ref, credential_fingerprint, external_account_id, remote_path,
   status, last_connected_at, consecutive_failures, is_enabled, schedule_cron,
   next_run_at, last_run_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('conn:', o.id, ':james_edition')), 26)),
  p.id, o.id, o.account_id, CONCAT(o.name, ' → JamesEdition'), 'outbound',
  CONCAT('secretsmanager://integrations/james_edition/org-', o.id),
  SHA2(CONCAT('cred:', o.id, ':james_edition'), 256),
  CONCAT('JE-', LPAD(o.id, 6, '0')),
  CONCAT('/inbound/livfinder/', LPAD(o.id, 6, '0'), '/'),
  'connected', DATE_SUB(NOW(3), INTERVAL 20 HOUR), 0, 1,
  '0 3 * * *', DATE_ADD(CURDATE(), INTERVAL 27 HOUR),
  DATE_SUB(NOW(3), INTERVAL 20 HOUR), o.created_at, NOW(3)
FROM organizations o
JOIN integration_providers p ON p.code = 'james_edition'
WHERE o.deleted_at IS NULL
  AND EXISTS (SELECT 1 FROM listings l
               WHERE l.organization_id = o.id AND l.price_base >= 10000000
                 AND l.status = 'active');

-- Inbound CRM feeds for a subset of agencies.
INSERT INTO integration_connections
  (public_id, provider_id, organization_id, account_id, name, direction,
   credential_ref, credential_fingerprint, external_account_id, endpoint_url,
   status, last_connected_at, last_error, last_error_at, consecutive_failures,
   is_enabled, schedule_cron, next_run_at, last_run_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('conn:', o.id, ':inbound')), 26)),
  p.id, o.id, o.account_id, CONCAT(p.name, ' → ', o.name), 'inbound',
  CONCAT('secretsmanager://integrations/', p.code, '/org-', o.id),
  SHA2(CONCAT('cred:', o.id, ':', p.code), 256),
  CONCAT(UPPER(LEFT(p.code, 3)), '-IN-', LPAD(o.id, 6, '0')),
  p.base_url,
  -- One connection in nine is failing, which is realistic: credentials expire,
  -- agencies change passwords without telling anyone.
  IF(MOD(o.id, 9) = 0, 'error', 'connected'),
  DATE_SUB(NOW(3), INTERVAL MOD(o.id, 8) HOUR),
  IF(MOD(o.id, 9) = 0,
     '401 Unauthorized — the stored credential was rejected. The agency most likely rotated it.', NULL),
  IF(MOD(o.id, 9) = 0, DATE_SUB(NOW(3), INTERVAL 3 HOUR), NULL),
  IF(MOD(o.id, 9) = 0, 7, 0),
  1, '*/30 * * * *', DATE_ADD(NOW(3), INTERVAL 20 MINUTE),
  DATE_SUB(NOW(3), INTERVAL MOD(o.id, 8) HOUR), o.created_at, NOW(3)
FROM organizations o
JOIN integration_providers p
  ON p.code = ELT(1 + MOD(o.id, 4), 'propspace', 'reapit', 'masterkey', 'generic_xml')
WHERE o.deleted_at IS NULL AND o.active_listing_count >= 8;

-- -----------------------------------------------------------------------------
-- Field mappings
--
-- Ours on the left, theirs on the right. This is what makes onboarding a new
-- portal configuration rather than a release.
-- -----------------------------------------------------------------------------
INSERT INTO feed_field_mappings
  (provider_id, entity_type, direction, internal_path, external_path, transform,
   transform_config, is_required, default_value, max_length, sort_order,
   is_active, notes, created_at, updated_at)
SELECT p.id, 'listing', 'outbound', v.internal_path, v.external_path, v.transform,
       v.config, v.required, v.default_value, v.max_len, v.sort_order, 1, v.notes,
       NOW(3), NOW(3)
FROM integration_providers p
JOIN (
  SELECT 'bayut' AS prov, 'listing.reference' AS internal_path,
         'Property/ReferenceNumber' AS external_path, 'none' AS transform,
         NULL AS config, 1 AS required, NULL AS default_value, NULL AS max_len,
         10 AS sort_order, NULL AS notes
  UNION ALL SELECT 'bayut', 'listing.title', 'Property/Title', 'truncate',
         JSON_OBJECT('length', 70), 1, NULL, 70, 20,
         'Bayut truncates at 70 characters server-side and does not tell you, so we truncate first and keep it readable.'
  UNION ALL SELECT 'bayut', 'listing.description', 'Property/Description', 'strip_html',
         NULL, 1, NULL, 4000, 30, NULL
  UNION ALL SELECT 'bayut', 'listing.price', 'Property/Price', 'number_format',
         JSON_OBJECT('decimals', 0), 1, NULL, NULL, 40, NULL
  UNION ALL SELECT 'bayut', 'listing.permit_number', 'Property/PermitNumber', 'none',
         NULL, 1, NULL, NULL, 50,
         'Trakheesi. The feed is rejected outright without it.'
  UNION ALL SELECT 'bayut', 'real_estate.bedrooms', 'Property/Bedrooms', 'none',
         NULL, 1, '0', NULL, 60, NULL
  UNION ALL SELECT 'bayut', 'real_estate.built_up_area', 'Property/Size', 'unit_convert',
         JSON_OBJECT('from', 'sqm', 'to', 'sqft', 'factor', 10.7639), 1, NULL, NULL, 70,
         'Bayut expects square feet. Sending square metres produces a listing that looks ten times too small.'
  UNION ALL SELECT 'bayut', 'listing.community_id', 'Property/LocationId', 'lookup',
         JSON_OBJECT('mapping_type', 'location'), 1, NULL, NULL, 80,
         'Their proprietary area ids. Resolved through feed_value_mappings.'
  UNION ALL SELECT 'bayut', 'agent.name', 'Property/AgentName', 'none', NULL, 1, NULL, NULL, 90, NULL
  UNION ALL SELECT 'bayut', 'agent.phone', 'Property/AgentPhone', 'none', NULL, 1, NULL, NULL, 100, NULL

  UNION ALL SELECT 'property_finder', 'listing.reference', 'reference', 'none', NULL, 1, NULL, NULL, 10, NULL
  UNION ALL SELECT 'property_finder', 'listing.title', 'title.en', 'truncate',
         JSON_OBJECT('length', 100), 1, NULL, 100, 20, NULL
  UNION ALL SELECT 'property_finder', 'listing.description', 'description.en', 'strip_html',
         NULL, 1, NULL, 5000, 30, NULL
  UNION ALL SELECT 'property_finder', 'listing.price', 'price.value', 'none', NULL, 1, NULL, NULL, 40, NULL
  UNION ALL SELECT 'property_finder', 'listing.currency_code', 'price.currency', 'uppercase',
         NULL, 1, 'AED', 3, 50, NULL
  UNION ALL SELECT 'property_finder', 'listing.permit_number', 'compliance.permit_number',
         'none', NULL, 1, NULL, NULL, 60, NULL
  UNION ALL SELECT 'property_finder', 'real_estate.built_up_area', 'size.value', 'none',
         NULL, 1, NULL, NULL, 70, 'Accepts square metres directly, unlike Bayut.'
  UNION ALL SELECT 'property_finder', 'listing.latitude', 'location.coordinates.lat',
         'round', JSON_OBJECT('decimals', 6), 0, NULL, NULL, 80, NULL
  UNION ALL SELECT 'property_finder', 'listing.longitude', 'location.coordinates.lng',
         'round', JSON_OBJECT('decimals', 6), 0, NULL, NULL, 90, NULL

  UNION ALL SELECT 'rightmove', 'listing.reference', 'agent_ref', 'truncate',
         JSON_OBJECT('length', 20), 1, NULL, 20, 10,
         'Twenty characters, fixed. The ADF format is from another era and enforces it.'
  UNION ALL SELECT 'rightmove', 'listing.description', 'summary', 'truncate',
         JSON_OBJECT('length', 1000), 1, NULL, 1000, 20, NULL
  UNION ALL SELECT 'rightmove', 'listing.price', 'price', 'number_format',
         JSON_OBJECT('decimals', 0), 1, NULL, NULL, 30, NULL
  UNION ALL SELECT 'rightmove', 'listing.postal_code', 'postcode1', 'split',
         JSON_OBJECT('separator', ' ', 'index', 0), 1, NULL, 4, 40,
         'The outward and inward halves of a UK postcode go in separate fields.'

  UNION ALL SELECT 'james_edition', 'listing.title', 'listing/headline', 'none',
         NULL, 1, NULL, 120, 10, NULL
  UNION ALL SELECT 'james_edition', 'listing.price_base', 'listing/price_usd',
         'currency_convert', JSON_OBJECT('to', 'USD'), 1, NULL, NULL, 20,
         'JamesEdition prices everything in US dollars regardless of market.'
  UNION ALL SELECT 'james_edition', 'listing.description', 'listing/full_description',
         'strip_html', NULL, 1, NULL, 8000, 30, NULL

  UNION ALL SELECT 'chrono24', 'listing.reference', 'listing.dealerReference', 'none',
         NULL, 1, NULL, NULL, 10, NULL
  UNION ALL SELECT 'chrono24', 'timepiece.reference_number', 'listing.referenceNumber',
         'none', NULL, 1, NULL, NULL, 20,
         'The manufacturer''s reference, which is how watches are actually searched.'
  UNION ALL SELECT 'chrono24', 'timepiece.year_of_production', 'listing.yearOfProduction',
         'none', NULL, 0, NULL, NULL, 30, NULL
  UNION ALL SELECT 'chrono24', 'listing.price', 'listing.price.amount', 'none', NULL, 1, NULL, NULL, 40, NULL
) v ON v.prov = p.code;

-- Inbound mappings for the CRMs.
INSERT INTO feed_field_mappings
  (provider_id, entity_type, direction, internal_path, external_path, transform,
   transform_config, is_required, sort_order, is_active, notes, created_at, updated_at)
SELECT p.id, 'listing', 'inbound', v.internal_path, v.external_path, v.transform,
       v.config, v.required, v.sort_order, 1, v.notes, NOW(3), NOW(3)
FROM integration_providers p
JOIN (
  SELECT 'propspace' AS prov, 'listing.source_reference' AS internal_path,
         'Listing/@id' AS external_path, 'none' AS transform, NULL AS config,
         1 AS required, 10 AS sort_order, NULL AS notes
  UNION ALL SELECT 'propspace', 'listing.title', 'Listing/Title', 'none', NULL, 1, 20, NULL
  UNION ALL SELECT 'propspace', 'listing.description', 'Listing/Description', 'strip_html', NULL, 0, 30, NULL
  UNION ALL SELECT 'propspace', 'listing.price', 'Listing/Price', 'number_format',
         JSON_OBJECT('decimals', 2), 1, 40, NULL
  UNION ALL SELECT 'propspace', 'real_estate.bedrooms', 'Listing/Bedrooms', 'none', NULL, 0, 50, NULL
  UNION ALL SELECT 'propspace', 'real_estate.built_up_area', 'Listing/AreaSqFt', 'unit_convert',
         JSON_OBJECT('from', 'sqft', 'to', 'sqm', 'factor', 0.092903), 0, 60,
         'Arrives in square feet; stored in square metres, because the schema stores one canonical unit and converts for display.'
  UNION ALL SELECT 'propspace', 'listing.community_id', 'Listing/Community', 'lookup',
         JSON_OBJECT('mapping_type', 'location'), 0, 70, NULL
  UNION ALL SELECT 'reapit', 'listing.source_reference', 'id', 'none', NULL, 1, 10, NULL
  UNION ALL SELECT 'reapit', 'listing.title', 'description', 'truncate',
         JSON_OBJECT('length', 200), 1, 20,
         'Reapit has no title field. The first two hundred characters of the description are the least bad substitute.'
  UNION ALL SELECT 'reapit', 'listing.price', 'pricing.price', 'none', NULL, 1, 30, NULL
  UNION ALL SELECT 'reapit', 'real_estate.bedrooms', 'bedrooms', 'none', NULL, 0, 40, NULL
) v ON v.prov = p.code;

-- -----------------------------------------------------------------------------
-- Value mappings
--
-- Vocabulary translation. The unmapped rows at the end are the work queue: a
-- value seen on the wire that we have no rule for, which is the commonest
-- silent data-loss bug in syndication.
-- -----------------------------------------------------------------------------
INSERT INTO feed_value_mappings
  (provider_id, mapping_type, direction, internal_id, internal_value,
   external_value, external_label, is_unmapped, seen_count, last_seen_at,
   is_active, created_at, updated_at)
SELECT p.id, 'category', 'both', c.id, c.slug, v.external_value, v.external_label,
       0, 0, NULL, 1, NOW(3), NOW(3)
FROM integration_providers p
JOIN (
  SELECT 'bayut' AS prov, 'apartments' AS cat_slug, 'RES-APT' AS external_value,
         'Apartment' AS external_label
  UNION ALL SELECT 'bayut', 'villas', 'RES-VIL', 'Villa'
  UNION ALL SELECT 'bayut', 'townhouses', 'RES-TWN', 'Townhouse'
  UNION ALL SELECT 'bayut', 'penthouses', 'RES-PEN', 'Penthouse'
  UNION ALL SELECT 'bayut', 'offices', 'COM-OFF', 'Office'
  UNION ALL SELECT 'property_finder', 'apartments', 'APARTMENT', 'Apartment'
  UNION ALL SELECT 'property_finder', 'villas', 'VILLA', 'Villa'
  UNION ALL SELECT 'property_finder', 'townhouses', 'TOWNHOUSE', 'Townhouse'
  UNION ALL SELECT 'property_finder', 'penthouses', 'PENTHOUSE', 'Penthouse'
  UNION ALL SELECT 'rightmove', 'apartments', '9', 'Flat'
  UNION ALL SELECT 'rightmove', 'villas', '3', 'Detached'
  UNION ALL SELECT 'rightmove', 'townhouses', '2', 'Terraced'
  UNION ALL SELECT 'zillow', 'apartments', 'CONDO', 'Condo'
  UNION ALL SELECT 'zillow', 'villas', 'SINGLE_FAMILY', 'Single Family'
  UNION ALL SELECT 'idealista', 'apartments', 'flat', 'Piso'
  UNION ALL SELECT 'idealista', 'villas', 'chalet', 'Chalet'
) v ON v.prov = p.code
JOIN categories c ON c.slug = v.cat_slug;

-- Location mappings: their proprietary area ids against our community tree.
INSERT INTO feed_value_mappings
  (provider_id, mapping_type, direction, internal_id, internal_value,
   external_value, external_label, scope_key, is_unmapped, seen_count,
   is_active, created_at, updated_at)
SELECT p.id, 'location', 'both', loc.id, loc.slug,
       CONCAT(UPPER(LEFT(p.code, 2)), '-', LPAD(loc.id % 100000, 5, '0')),
       loc.name, 'dubai', 0, 0, 1, NOW(3), NOW(3)
FROM integration_providers p
JOIN locations loc
  ON loc.level = 'community'
 AND loc.slug IN ('dubai-marina', 'downtown-dubai', 'palm-jumeirah',
                  'jumeirah-lakes-towers', 'business-bay', 'jumeirah-village-circle',
                  'emirates-hills', 'arabian-ranches', 'dubai-hills-estate',
                  'jumeirah-beach-residence')
WHERE p.code IN ('bayut', 'property_finder', 'dubizzle');

-- The work queue: values seen inbound that nothing maps to. Left unmapped
-- deliberately, because a silently dropped field is worse than a visible gap.
INSERT INTO feed_value_mappings
  (provider_id, mapping_type, direction, internal_id, internal_value,
   external_value, external_label, is_unmapped, seen_count, last_seen_at,
   is_active, created_at, updated_at)
SELECT p.id, v.mapping_type, 'inbound', NULL, NULL, v.external_value,
       v.external_label, 1, v.seen_count, DATE_SUB(NOW(3), INTERVAL 2 DAY), 1,
       NOW(3), NOW(3)
FROM integration_providers p
JOIN (
  SELECT 'propspace' AS prov, 'category' AS mapping_type,
         'RES-LOFT' AS external_value, 'Loft Apartment' AS external_label,
         34 AS seen_count
  UNION ALL SELECT 'propspace', 'category', 'RES-BUNG', 'Bungalow', 12
  UNION ALL SELECT 'propspace', 'furnishing', 'SEMI', 'Semi-furnished', 87
  UNION ALL SELECT 'reapit', 'category', 'maisonette', 'Maisonette', 9
  UNION ALL SELECT 'masterkey', 'location', 'AREA-8842', 'Al Barsha South 4', 51
  UNION ALL SELECT 'masterkey', 'amenity', 'AMN-PADEL', 'Padel court', 23
) v ON v.prov = p.code;

-- -----------------------------------------------------------------------------
-- Validation rules
--
-- What each portal will reject, encoded so we fail locally with a message the
-- agency can act on rather than remotely with "error 4021".
-- -----------------------------------------------------------------------------
INSERT INTO feed_validation_rules
  (provider_id, entity_type, field_path, rule_type, rule_value, severity,
   message, is_active, created_at)
SELECT p.id, 'listing', v.field_path, v.rule_type, v.rule_value, v.severity,
       v.message, 1, NOW(3)
FROM integration_providers p
JOIN (
  SELECT 'bayut' AS prov, 'listing.permit_number' AS field_path,
         'required' AS rule_type, NULL AS rule_value, 'error' AS severity,
         'Bayut requires a valid Trakheesi permit number on every UAE listing. Add the permit before this listing can be syndicated.' AS message
  UNION ALL SELECT 'bayut', 'media.image_count', 'min_count', '4', 'error',
         'Bayut requires at least four photographs. Listings with fewer are rejected at upload.'
  UNION ALL SELECT 'bayut', 'listing.description', 'no_contact_details', NULL, 'error',
         'Phone numbers and email addresses are not permitted in the description. Bayut strips them and penalises the account.'
  UNION ALL SELECT 'bayut', 'listing.title', 'max_length', '70', 'warning',
         'Titles longer than 70 characters are truncated by Bayut mid-word. Shorten it so it reads properly.'
  UNION ALL SELECT 'property_finder', 'listing.permit_number', 'required', NULL, 'error',
         'Property Finder requires a Trakheesi permit number for UAE listings.'
  UNION ALL SELECT 'property_finder', 'media.image_count', 'min_count', '3', 'error',
         'At least three photographs are required.'
  UNION ALL SELECT 'property_finder', 'media.image_dimensions', 'image_dimensions',
         '1200x800', 'warning',
         'Images below 1200x800 are upscaled by Property Finder and look poor. Supply larger originals.'
  UNION ALL SELECT 'rightmove', 'listing.postal_code', 'required', NULL, 'error',
         'Rightmove will not accept a UK listing without a postcode.'
  UNION ALL SELECT 'rightmove', 'listing.description', 'max_length', '1000', 'error',
         'The Rightmove ADF summary field is capped at 1,000 characters.'
  UNION ALL SELECT 'james_edition', 'listing.price_base', 'min_value', '1000000', 'error',
         'JamesEdition only accepts listings above one million US dollars. This one is below the threshold and will be rejected.'
  UNION ALL SELECT 'james_edition', 'media.image_count', 'min_count', '8', 'error',
         'JamesEdition requires at least eight photographs on a luxury listing.'
  UNION ALL SELECT 'chrono24', 'timepiece.reference_number', 'required', NULL, 'error',
         'Chrono24 requires the manufacturer reference number. It is how their entire catalogue is keyed.'
  UNION ALL SELECT 'zillow', 'listing.latitude', 'required', NULL, 'error',
         'Zillow requires coordinates on every listing.'
) v ON v.prov = p.code;

-- -----------------------------------------------------------------------------
-- Syndication channels and subscriptions
-- -----------------------------------------------------------------------------
INSERT INTO syndication_channels
  (public_id, connection_id, provider_id, organization_id, name, listing_quota,
   quota_used, featured_quota, featured_used, contract_starts_at,
   contract_ends_at, monthly_cost, currency_code, auto_publish, min_price_base,
   exclude_exclusive, allow_price_override, status, last_export_at,
   next_export_at, live_count, error_count, leads_received, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('channel:', c.id)), 26)),
  c.id, c.provider_id, c.organization_id,
  CONCAT(o.name, ' on ', p.name),
  -- Quota scaled to the agency's inventory, which is how portal contracts are
  -- actually sized.
  GREATEST(20, ROUND(o.active_listing_count * 1.4)),
  0,
  GREATEST(2, ROUND(o.active_listing_count * 0.1)), 0,
  DATE_SUB(CURDATE(), INTERVAL 200 DAY),
  DATE_ADD(CURDATE(), INTERVAL 165 DAY),
  CASE p.code WHEN 'property_finder' THEN 12500.00
              WHEN 'bayut' THEN 9800.00
              WHEN 'dubizzle' THEN 4200.00
              WHEN 'james_edition' THEN 7500.00
              ELSE 3000.00 END,
  'AED', 1,
  IF(p.code = 'james_edition', 3670000.00, NULL),
  0, 0, 'active',
  c.last_run_at, c.next_run_at, 0, 0, 0, c.created_at, NOW(3)
FROM integration_connections c
JOIN integration_providers p ON p.id = c.provider_id
JOIN organizations o ON o.id = c.organization_id
WHERE c.direction = 'outbound' OR p.provider_kind = 'portal';

INSERT INTO syndication_subscriptions
  (channel_id, listing_id, organization_id, status, is_featured_remotely,
   external_id, external_url, rejection_code, rejection_message,
   first_published_at, last_pushed_at, last_success_at, push_count, error_count,
   remote_views, remote_leads, created_at, updated_at)
SELECT
  ch.id, l.id, l.organization_id,
  -- A listing without a permit is rejected by the Gulf portals, which is
  -- exactly what the validation rules above predict.
  CASE WHEN p.code IN ('bayut','property_finder') AND MOD(l.id, 13) = 0 THEN 'rejected'
       WHEN ch.min_price_base IS NOT NULL AND l.price_base < ch.min_price_base THEN 'ineligible'
       ELSE 'live' END,
  l.is_featured,
  CONCAT(UPPER(LEFT(p.code, 2)), '-', LPAD(l.id * 7 % 9999999, 7, '0')),
  CONCAT(COALESCE(p.base_url, 'https://example.com'), '/listing/',
         LPAD(l.id * 7 % 9999999, 7, '0')),
  CASE WHEN p.code IN ('bayut','property_finder') AND MOD(l.id, 13) = 0
       THEN 'PERMIT_MISSING' ELSE NULL END,
  CASE WHEN p.code IN ('bayut','property_finder') AND MOD(l.id, 13) = 0
       THEN 'Rejected: no valid Trakheesi permit number was supplied for this listing.'
       ELSE NULL END,
  l.published_at, ch.last_export_at, ch.last_export_at,
  1 + MOD(l.id, 20),
  IF(MOD(l.id, 13) = 0, 3, 0),
  -- Remote views scale with our own, which is the only defensible basis for a
  -- demo number here.
  ROUND(l.view_count * 0.6), ROUND(l.inquiry_count * 0.4),
  l.created_at, NOW(3)
FROM syndication_channels ch
JOIN integration_providers p ON p.id = ch.provider_id
JOIN listings l
  ON l.organization_id = ch.organization_id
 AND l.status = 'active' AND l.deleted_at IS NULL
 AND (ch.min_price_base IS NULL OR l.price_base IS NOT NULL);

UPDATE syndication_channels ch
  LEFT JOIN (SELECT channel_id, COUNT(*) n,
                    SUM(status = 'live') live,
                    SUM(is_featured_remotely) feat,
                    SUM(error_count > 0) errs,
                    SUM(remote_leads) leads
               FROM syndication_subscriptions GROUP BY channel_id) s
    ON s.channel_id = ch.id
   SET ch.quota_used = LEAST(COALESCE(ch.listing_quota, 65535), COALESCE(s.live, 0)),
       ch.live_count = COALESCE(s.live, 0),
       ch.featured_used = COALESCE(s.feat, 0),
       ch.error_count = COALESCE(s.errs, 0),
       ch.leads_received = COALESCE(s.leads, 0),
       -- A channel over its contracted quota stops publishing rather than
       -- having the whole feed rejected.
       ch.status = IF(COALESCE(s.live, 0) > COALESCE(ch.listing_quota, 65535),
                      'quota_exceeded', ch.status);

-- Identity mapping, both ways. Without it the second run of any feed creates
-- duplicates, which is the commonest integration failure there is.
INSERT INTO external_references
  (provider_id, connection_id, entity_type, entity_id, external_id, external_url,
   remote_status, payload_hash, first_synced_at, last_synced_at, last_success_at,
   sync_count, error_count, created_at, updated_at)
SELECT ch.provider_id, ch.connection_id, 'listing', ss.listing_id,
       ss.external_id, ss.external_url,
       CASE ss.status WHEN 'live' THEN 'live' WHEN 'rejected' THEN 'rejected'
                      WHEN 'ineligible' THEN 'unknown' ELSE 'pending' END,
       LOWER(LEFT(MD5(CONCAT('payload:', ss.listing_id, ':', ch.provider_id)), 32)),
       ss.first_published_at, ss.last_pushed_at, ss.last_success_at,
       ss.push_count, ss.error_count, ss.created_at, NOW(3)
FROM syndication_subscriptions ss
JOIN syndication_channels ch ON ch.id = ss.channel_id;

-- -----------------------------------------------------------------------------
-- Export runs
-- -----------------------------------------------------------------------------
INSERT INTO feed_exports
  (public_id, channel_id, connection_id, provider_id, organization_id,
   export_type, trigger_source, status, started_at, finished_at, duration_ms,
   total_items, sent_items, accepted_items, rejected_items, skipped_items,
   removed_items, unchanged_items, output_size_bytes, output_checksum,
   destination_path, http_status, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('export:', ch.id, ':', d.n)), 26)),
  ch.id, ch.connection_id, ch.provider_id, ch.organization_id,
  IF(d.n = 0, 'incremental', 'full'), 'schedule',
  IF(s.rejected > 0, 'partial', 'completed'),
  DATE_SUB(NOW(3), INTERVAL (d.n * 6 + 1) HOUR),
  DATE_SUB(NOW(3), INTERVAL (d.n * 6) HOUR),
  40000 + MOD(ch.id * 977, 200000),
  s.total, s.total - s.ineligible, s.live, s.rejected, s.ineligible, 0,
  ROUND(s.total * 0.7),
  s.total * 4200,
  SHA2(CONCAT('feed:', ch.id, ':', d.n), 256),
  CONCAT('/inbound/livfinder/', LPAD(ch.organization_id, 6, '0'), '/feed-',
         DATE_FORMAT(DATE_SUB(NOW(3), INTERVAL (d.n * 6) HOUR), '%Y%m%d%H'), '.xml'),
  200, DATE_SUB(NOW(3), INTERVAL (d.n * 6 + 1) HOUR)
FROM syndication_channels ch
JOIN (
  SELECT channel_id, COUNT(*) total, SUM(status = 'live') live,
         SUM(status = 'rejected') rejected, SUM(status = 'ineligible') ineligible
    FROM syndication_subscriptions GROUP BY channel_id
) s ON s.channel_id = ch.id
JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) d;

-- Per-listing outcome. This is what turns "the feed ran" into "your villa was
-- rejected because the permit number is missing".
INSERT INTO feed_export_items
  (export_id, listing_id, subscription_id, operation, status, external_id,
   error_code, error_message, payload_hash, processed_at)
SELECT ex.id, ss.listing_id, ss.id,
       IF(ss.push_count <= 1, 'create', 'update'),
       CASE ss.status WHEN 'live' THEN 'accepted' WHEN 'rejected' THEN 'rejected'
                      WHEN 'ineligible' THEN 'skipped' ELSE 'sent' END,
       ss.external_id, ss.rejection_code, ss.rejection_message,
       LOWER(LEFT(MD5(CONCAT('item:', ss.id)), 32)), ex.finished_at
FROM feed_exports ex
JOIN syndication_subscriptions ss ON ss.channel_id = ex.channel_id
WHERE ex.export_type = 'incremental';

-- -----------------------------------------------------------------------------
-- Import runs
--
-- `max_deletion_percent` is the safety valve. A full feed implies "anything not
-- in this file is gone", which is correct until the day the agency's CRM
-- exports an empty file. The held run below is exactly that case caught.
-- -----------------------------------------------------------------------------
INSERT INTO feed_imports
  (public_id, connection_id, provider_id, organization_id, account_id,
   import_type, entity_type, deletion_mode, max_deletion_percent, status,
   hold_reason, source_url, source_size_bytes, source_checksum, started_at,
   finished_at, duration_ms, total_rows, created_count, updated_count,
   unchanged_count, skipped_count, failed_count, deleted_count,
   media_downloaded, media_failed, unmapped_values_count, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('import:', c.id, ':', d.n)), 26)),
  c.id, c.provider_id, c.organization_id, c.account_id,
  'full', 'listing', 'mark_unavailable', 20,
  CASE WHEN d.n = 0 AND MOD(c.id, 17) = 0 THEN 'held_for_review'
       WHEN c.status = 'error' THEN 'failed'
       ELSE 'completed' END,
  CASE WHEN d.n = 0 AND MOD(c.id, 17) = 0
       THEN 'The feed would have removed 94% of this agency''s live listings. Held pending confirmation — an empty or truncated export is far more likely than the agency having withdrawn everything overnight.'
       ELSE NULL END,
  c.endpoint_url,
  180000 + MOD(c.id * 331, 900000),
  SHA2(CONCAT('src:', c.id, ':', d.n), 256),
  DATE_SUB(NOW(3), INTERVAL (d.n * 12 + 1) HOUR),
  DATE_SUB(NOW(3), INTERVAL (d.n * 12) HOUR),
  30000 + MOD(c.id * 733, 120000),
  o.active_listing_count,
  IF(d.n = 3, o.active_listing_count, MOD(c.id, 4)),
  IF(d.n = 3, 0, MOD(c.id, 9)),
  IF(d.n = 3, 0, GREATEST(0, CAST(o.active_listing_count AS SIGNED)
                            - CAST(MOD(c.id, 4) AS SIGNED)
                            - CAST(MOD(c.id, 9) AS SIGNED))),
  MOD(c.id, 3), IF(c.status = 'error', MOD(c.id, 5), 0), 0,
  MOD(c.id, 12) * 3, 0, MOD(c.id, 3),
  DATE_SUB(NOW(3), INTERVAL (d.n * 12 + 1) HOUR)
FROM integration_connections c
JOIN organizations o ON o.id = c.organization_id
JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) d
WHERE c.direction = 'inbound';

INSERT INTO feed_import_items
  (import_id, source_row, external_id, entity_type, entity_id, operation,
   status, raw_payload, errors, error_message, processed_at)
SELECT
  im.id, ROW_NUMBER() OVER (PARTITION BY im.id ORDER BY l.id),
  CONCAT('EXT-', LPAD(l.id, 8, '0')), 'listing', l.id,
  'update', 'success', NULL, NULL, NULL, im.finished_at
FROM feed_imports im
JOIN listings l ON l.organization_id = im.organization_id
                AND l.status = 'active' AND l.deleted_at IS NULL
WHERE im.status = 'completed'
  AND im.started_at = (SELECT MAX(i2.started_at) FROM feed_imports i2
                        WHERE i2.connection_id = im.connection_id);

-- Failures keep their raw payload, which is what makes them diagnosable without
-- asking the agency to resend the file.
INSERT INTO feed_import_items
  (import_id, source_row, external_id, entity_type, entity_id, operation,
   status, raw_payload, errors, error_message, processed_at)
SELECT im.id, 9001, CONCAT('EXT-BAD-', im.id), 'listing', NULL, 'fail', 'failed',
       JSON_OBJECT('id', CONCAT('EXT-BAD-', im.id),
                   'Title', 'Spacious 2BR',
                   'Price', 'AED 1,450,000',
                   'Community', 'AREA-8842',
                   'Bedrooms', '2'),
       JSON_ARRAY(JSON_OBJECT('field', 'Price',
                              'error', 'Not numeric: currency symbol and thousands separators present'),
                  JSON_OBJECT('field', 'Community',
                              'error', 'No mapping for external location AREA-8842')),
       'Two field errors. The price needs a number_format transform and the community needs a value mapping.',
       im.finished_at
FROM feed_imports im
WHERE im.status = 'completed' AND MOD(im.id, 5) = 0;

-- -----------------------------------------------------------------------------
-- Inbound leads
--
-- Portals push leads back. They arrive raw and are only then turned into a
-- lead, because the payload frequently fails validation and a failed parse must
-- not lose the enquiry.
-- -----------------------------------------------------------------------------
INSERT INTO inbound_leads
  (public_id, provider_id, connection_id, organization_id, external_lead_id,
   external_listing_ref, listing_id, lead_id, raw_payload, name, email,
   phone_e164, message, channel, received_at, status, processed_at, dedupe_hash)
SELECT
  UPPER(LEFT(MD5(CONCAT('inbound-lead:', ld.id)), 26)),
  ch.provider_id, ch.connection_id, ld.organization_id,
  CONCAT('PFL-', LPAD(ld.id, 9, '0')),
  ss.external_id, ld.primary_listing_id, ld.id,
  JSON_OBJECT('lead_id', CONCAT('PFL-', LPAD(ld.id, 9, '0')),
              'property_reference', ss.external_id,
              'name', ld.name, 'email', ld.email, 'phone', ld.phone_e164,
              'message', 'I am interested in this property. Please call me.',
              'source', 'property_finder', 'received', ld.created_at),
  ld.name, ld.email, ld.phone_e164,
  'I am interested in this property. Please call me.',
  'form', ld.created_at, 'processed', ld.created_at,
  LOWER(LEFT(MD5(CONCAT('dedupe:', ld.id)), 32))
FROM leads ld
JOIN syndication_subscriptions ss
  ON ss.listing_id = ld.primary_listing_id AND ss.status = 'live'
JOIN syndication_channels ch ON ch.id = ss.channel_id
JOIN integration_providers p ON p.id = ch.provider_id AND p.returns_leads = 1
WHERE ld.primary_listing_id IS NOT NULL
GROUP BY ld.id;

-- A payload that could not be matched. Kept rather than dropped, which is the
-- entire reason this table sits in front of `leads`.
INSERT INTO inbound_leads
  (public_id, provider_id, connection_id, organization_id, external_lead_id,
   external_listing_ref, raw_payload, name, email, phone_e164, message,
   channel, received_at, status, failure_reason, retry_count, dedupe_hash)
SELECT
  UPPER(LEFT(MD5(CONCAT('inbound-unmatched:', ch.id)), 26)),
  ch.provider_id, ch.connection_id, ch.organization_id,
  CONCAT('PFL-UNMATCHED-', ch.id), CONCAT('REF-', ch.id, '-DELETED'),
  JSON_OBJECT('lead_id', CONCAT('PFL-UNMATCHED-', ch.id),
              'property_reference', CONCAT('REF-', ch.id, '-DELETED'),
              'name', 'Unknown', 'email', NULL,
              'phone', '+9715000000000',
              'message', 'Called about a property'),
  'Unknown', NULL, '+9715000000000', 'Called about a property',
  'call', DATE_SUB(NOW(3), INTERVAL 6 HOUR), 'unmatched',
  'The property reference in the payload does not correspond to any listing we have syndicated. Most likely the listing was withdrawn before the lead arrived.',
  2, LOWER(LEFT(MD5(CONCAT('dedupe-unmatched:', ch.id)), 32))
FROM syndication_channels ch
WHERE MOD(ch.id, 11) = 0;

-- -----------------------------------------------------------------------------
-- Portal performance
--
-- What each portal actually delivered. The table that decides next year's
-- marketing spend, which is why cost-per-lead is derived rather than estimated.
-- -----------------------------------------------------------------------------
INSERT INTO portal_performance_daily
  (stat_date, provider_id, channel_id, organization_id, live_listings,
   impressions, detail_views, leads, calls, whatsapp, emails,
   apportioned_cost, currency_code, cost_per_lead, computed_at)
SELECT
  d.stat_date, ch.provider_id, ch.id, ch.organization_id, ch.live_count,
  ch.live_count * 140, ch.live_count * 12,
  GREATEST(0, ROUND(ch.live_count * 0.09)),
  GREATEST(0, ROUND(ch.live_count * 0.04)),
  GREATEST(0, ROUND(ch.live_count * 0.03)),
  GREATEST(0, ROUND(ch.live_count * 0.02)),
  ROUND(ch.monthly_cost / 30, 2), ch.currency_code,
  ROUND(ch.monthly_cost / 30 / GREATEST(1, ROUND(ch.live_count * 0.09)), 2),
  NOW(3)
FROM syndication_channels ch
JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL n DAY) AS stat_date
  FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7) days
) d
WHERE ch.status IN ('active', 'quota_exceeded');

-- -----------------------------------------------------------------------------
-- API usage
-- -----------------------------------------------------------------------------
INSERT INTO api_usage_daily
  (stat_date, api_client_id, provider_id, organization_id, direction, endpoint,
   request_count, success_count, client_error_count, server_error_count,
   rate_limited_count, total_duration_ms, avg_duration_ms, p95_duration_ms,
   max_duration_ms, request_bytes, response_bytes, billable_units, computed_at)
SELECT
  d.stat_date, ac.id, NULL, ac.account_id, 'inbound', v.endpoint,
  v.base_requests + MOD(ac.id * 13, 400),
  ROUND((v.base_requests + MOD(ac.id * 13, 400)) * 0.972),
  ROUND((v.base_requests + MOD(ac.id * 13, 400)) * 0.021),
  ROUND((v.base_requests + MOD(ac.id * 13, 400)) * 0.004),
  ROUND((v.base_requests + MOD(ac.id * 13, 400)) * 0.003),
  (v.base_requests + MOD(ac.id * 13, 400)) * v.avg_ms,
  v.avg_ms, ROUND(v.avg_ms * 2.8), ROUND(v.avg_ms * 9),
  (v.base_requests + MOD(ac.id * 13, 400)) * 900,
  (v.base_requests + MOD(ac.id * 13, 400)) * 12000,
  v.base_requests + MOD(ac.id * 13, 400),
  NOW(3)
FROM api_clients ac
JOIN (
  SELECT '/v1/listings' AS endpoint, 1200 AS base_requests, 68 AS avg_ms
  UNION ALL SELECT '/v1/listings/{id}', 3400, 24
  UNION ALL SELECT '/v1/search', 2800, 112
  UNION ALL SELECT '/v1/locations', 400, 18
  UNION ALL SELECT '/v1/leads', 260, 46
) v
JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL n DAY) AS stat_date
  FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7) days
) d;
