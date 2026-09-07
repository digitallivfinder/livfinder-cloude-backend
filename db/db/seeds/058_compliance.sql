-- =============================================================================
-- Liv Finder — seed 058 · Compliance, risk and contracts
-- =============================================================================
-- The regulators, permits and sanctions lists here are real. So are the
-- thresholds: the UAE requires a Trakheesi permit on every advertised property
-- and it expires; the FATF-aligned regimes in these markets require customer
-- due diligence above defined transaction values; and OFAC, the EU consolidated
-- list and the UN list are the three every screening programme starts with.
--
-- Two design points are worth stating plainly, because they are what separate a
-- compliance feature from a compliance liability:
--
-- PERMITS EXPIRE AND THE PLATFORM MUST ACT. `listing_permits` carries an expiry
-- and an enforcement action. A nightly job warns before it lapses and
-- unpublishes on the day, which is the difference between a control and a
-- checkbox.
--
-- SCREENING PRODUCES MOSTLY FALSE POSITIVES. Common names collide constantly.
-- A programme where every alert stays open is a programme nobody reads, so
-- every match carries a disposition and a cleared name is whitelisted so it
-- stops re-alarming — with the decision and its author on the record.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

INSERT INTO regulatory_authorities
  (code, name, short_name, country_id, authority_type, applies_to_categories,
   website_url, has_verification_api, verification_endpoint, notes, is_active,
   created_at, updated_at)
SELECT v.code, v.name, v.short_name,
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       v.authority_type, v.categories, v.website, v.has_api, v.endpoint, v.notes,
       1, NOW(3), NOW(3)
FROM (
  SELECT 'ae-dld' AS code, 'Dubai Land Department' AS name, 'DLD' AS short_name,
         'united-arab-emirates' AS country, 'land_registry' AS authority_type,
         JSON_ARRAY('real-estate') AS categories,
         'https://dubailand.gov.ae' AS website, 1 AS has_api,
         'https://trakheesi.dubailand.example.gov.ae/api/verify' AS endpoint,
         'Issues Trakheesi advertising permits and maintains the property register. Verification is available over API, so permits are machine-checked rather than eyeballed.' AS notes
  UNION ALL SELECT 'ae-rera', 'Real Estate Regulatory Agency', 'RERA',
         'united-arab-emirates', 'property_regulator', JSON_ARRAY('real-estate'),
         'https://dubailand.gov.ae/en/rera', 0, NULL,
         'Licenses brokers and brokerages. A broker card number is mandatory on every Dubai listing.'
  UNION ALL SELECT 'ae-adrec', 'Abu Dhabi Real Estate Centre', 'ADREC',
         'united-arab-emirates', 'property_regulator', JSON_ARRAY('real-estate'),
         NULL, 0, NULL, 'The Abu Dhabi equivalent. Separate permits, separate numbering.'
  UNION ALL SELECT 'sa-rega', 'Real Estate General Authority', 'REGA',
         'saudi-arabia', 'property_regulator', JSON_ARRAY('real-estate'),
         NULL, 0, NULL,
         'Runs the Ejar tenancy registration platform and licenses brokers.'
  UNION ALL SELECT 'qa-mme', 'Ministry of Municipality', 'MME', 'qatar',
         'property_regulator', JSON_ARRAY('real-estate'), NULL, 0, NULL, NULL
  UNION ALL SELECT 'gb-hmlr', 'HM Land Registry', 'HMLR', 'united-kingdom',
         'land_registry', JSON_ARRAY('real-estate'),
         'https://www.gov.uk/government/organisations/land-registry', 1, NULL,
         'Title register and the price paid data that underpins UK market statistics.'
  UNION ALL SELECT 'gb-fca', 'Financial Conduct Authority', 'FCA',
         'united-kingdom', 'financial_regulator', NULL, NULL, 0, NULL,
         'Relevant because mortgage referral is a regulated activity.'
  UNION ALL SELECT 'ae-cb', 'Central Bank of the UAE', 'CBUAE',
         'united-arab-emirates', 'financial_regulator', NULL, NULL, 0, NULL,
         'Anti-money-laundering supervision for the payment and escrow activity.'
  UNION ALL SELECT 'ae-mca', 'Maritime and Coastguard Authority', NULL,
         'united-arab-emirates', 'maritime', JSON_ARRAY('yachts'), NULL, 0, NULL,
         'Vessel registration and flag state.'
  UNION ALL SELECT 'ae-gcaa', 'General Civil Aviation Authority', 'GCAA',
         'united-arab-emirates', 'aviation', JSON_ARRAY('jets','helicopters'),
         NULL, 0, NULL, 'Aircraft registration and airworthiness.'
  UNION ALL SELECT 'eu-edpb', 'European Data Protection Board', 'EDPB', NULL,
         'data_protection', NULL, 'https://edpb.europa.eu', 0, NULL,
         'GDPR guidance. Not a supervisory authority in itself, but where the interpretation comes from.'
  UNION ALL SELECT 'ae-dp', 'UAE Data Office', NULL, 'united-arab-emirates',
         'data_protection', NULL, NULL, 0, NULL,
         'Supervises the federal personal data protection law.'
) v;

INSERT INTO permit_types
  (authority_id, code, name, description, applies_to, country_id, is_mandatory,
   blocks_publishing, validity_days, warn_before_days, must_display_on_listing,
   display_label, number_format_regex, is_active, created_at, updated_at)
SELECT a.id, v.code, v.name, v.description, v.applies_to, a.country_id,
       v.mandatory, v.blocks, v.validity, v.warn_days, v.must_display,
       v.display_label, v.regex, 1, NOW(3), NOW(3)
FROM regulatory_authorities a
JOIN (
  SELECT 'ae-dld' AS auth, 'trakheesi' AS code,
         'Trakheesi advertising permit' AS name,
         'Required before any Dubai property may be advertised anywhere, including on a portal. Issued per listing, expires, and must be displayed with a QR code on the advert itself. Advertising past expiry is a fineable offence for the agency and for the portal carrying it.' AS description,
         'listing' AS applies_to, 1 AS mandatory, 1 AS blocks, 90 AS validity,
         14 AS warn_days, 1 AS must_display, 'Permit No.' AS display_label,
         '^[0-9]{7,12}$' AS regex
  UNION ALL SELECT 'ae-rera', 'broker-card', 'RERA broker card',
         'Individual broker registration. Every agent advertising in Dubai must hold a current card, and the number appears on the listing.',
         'agent', 1, 1, 365, 30, 1, 'BRN', '^[0-9]{4,8}$'
  UNION ALL SELECT 'ae-rera', 'brokerage-licence', 'RERA brokerage licence',
         'The agency''s own licence. Expiry suspends every listing the agency holds, which is why the warning window is long.',
         'organization', 1, 1, 365, 60, 0, 'ORN', '^[0-9]{3,8}$'
  UNION ALL SELECT 'ae-adrec', 'adrec-permit', 'ADREC advertising permit',
         'The Abu Dhabi equivalent of Trakheesi.', 'listing', 1, 1, 90, 14, 1,
         'Permit No.', NULL
  UNION ALL SELECT 'sa-rega', 'rega-licence', 'REGA broker licence',
         'Saudi broker registration.', 'agent', 1, 1, 365, 30, 1, 'Licence', NULL
  UNION ALL SELECT 'sa-rega', 'ejar-registration', 'Ejar tenancy registration',
         'Saudi tenancy contracts must be registered on the Ejar platform to be enforceable.',
         'deal', 1, 0, NULL, 0, 0, 'Ejar', NULL
  UNION ALL SELECT 'gb-hmlr', 'epc', 'Energy Performance Certificate',
         'A valid EPC is required before a UK property may be marketed. Valid for ten years.',
         'listing', 1, 0, 3650, 90, 1, 'EPC', NULL
  UNION ALL SELECT 'ae-mca', 'vessel-registration', 'Vessel registration',
         'Flag state registration for a yacht.', 'vessel', 1, 0, 365, 30, 0, 'Reg.', NULL
  UNION ALL SELECT 'ae-gcaa', 'aircraft-registration', 'Aircraft registration',
         'Civil aviation registration mark.', 'aircraft', 1, 0, 365, 60, 0, 'Reg.', NULL
) v ON v.auth = a.code;

-- Permits against the listings that need them. One in nine has expired or is
-- about to, which is what the enforcement sweep exists to catch.
INSERT INTO listing_permits
  (permit_type_id, authority_id, subject_type, subject_id, listing_id,
   organization_id, permit_number, qr_code_url, verification_url, issued_at,
   expires_at, status, verification_status, verified_at, enforced_at,
   enforcement_action, warned_at, created_at, updated_at)
SELECT
  pt.id, pt.authority_id, 'listing', l.id, l.id, l.organization_id,
  LPAD(MOD(l.id * 104729, 1000000000), 9, '0'),
  CONCAT('https://trakheesi.dubailand.example.gov.ae/qr/',
         LPAD(MOD(l.id * 104729, 1000000000), 9, '0')),
  CONCAT('https://trakheesi.dubailand.example.gov.ae/verify/',
         LPAD(MOD(l.id * 104729, 1000000000), 9, '0')),
  DATE(COALESCE(l.published_at, l.created_at)),
  DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY),
  CASE WHEN DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY) < CURDATE()
         THEN 'expired'
       WHEN DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY)
            < DATE_ADD(CURDATE(), INTERVAL 14 DAY) THEN 'expiring'
       ELSE 'active' END,
  'api_verified', COALESCE(l.published_at, l.created_at),
  CASE WHEN DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY) < CURDATE()
       THEN DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY)
       ELSE NULL END,
  CASE WHEN DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY) < CURDATE()
       THEN 'unpublished' ELSE 'none' END,
  DATE_SUB(DATE_ADD(DATE(COALESCE(l.published_at, l.created_at)), INTERVAL 90 DAY),
           INTERVAL 14 DAY),
  l.created_at, NOW(3)
FROM listings l
JOIN permit_types pt ON pt.code = 'trakheesi'
JOIN locations c ON c.id = l.country_id
JOIN location_country_profiles cp ON cp.location_id = c.id AND cp.iso2 = 'AE'
WHERE l.deleted_at IS NULL AND l.root_category_id =
      (SELECT id FROM categories WHERE code = 'real-estate' LIMIT 1);

-- Brokerage and broker licences.
INSERT INTO listing_permits
  (permit_type_id, authority_id, subject_type, subject_id, organization_id,
   permit_number, issued_at, expires_at, status, verification_status,
   verified_at, enforcement_action, created_at, updated_at)
SELECT pt.id, pt.authority_id, 'organization', o.id, o.id,
       LPAD(MOD(o.id * 7919, 100000), 5, '0'),
       DATE_SUB(CURDATE(), INTERVAL (200 + MOD(o.id, 150)) DAY),
       DATE_ADD(DATE_SUB(CURDATE(), INTERVAL (200 + MOD(o.id, 150)) DAY), INTERVAL 365 DAY),
       IF(DATE_ADD(DATE_SUB(CURDATE(), INTERVAL (200 + MOD(o.id, 150)) DAY), INTERVAL 365 DAY)
          < DATE_ADD(CURDATE(), INTERVAL 60 DAY), 'expiring', 'active'),
       'document_verified', o.verified_at, 'none', o.created_at, NOW(3)
FROM organizations o
JOIN permit_types pt ON pt.code = 'brokerage-licence'
WHERE o.deleted_at IS NULL;

INSERT INTO listing_permits
  (permit_type_id, authority_id, subject_type, subject_id, organization_id,
   permit_number, issued_at, expires_at, status, verification_status,
   verified_at, enforcement_action, created_at, updated_at)
SELECT pt.id, pt.authority_id, 'agent', a.id, a.organization_id,
       LPAD(MOD(a.id * 6473, 1000000), 6, '0'),
       COALESCE(DATE_SUB(a.license_expires_at, INTERVAL 365 DAY),
                DATE_SUB(CURDATE(), INTERVAL 200 DAY)),
       COALESCE(a.license_expires_at, DATE_ADD(CURDATE(), INTERVAL 165 DAY)),
       CASE WHEN a.license_expires_at < CURDATE() THEN 'expired'
            WHEN a.license_expires_at < DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'expiring'
            ELSE 'active' END,
       'document_verified', a.verified_at,
       IF(a.license_expires_at < CURDATE(), 'suspended', 'none'),
       a.created_at, NOW(3)
FROM agents a
JOIN permit_types pt ON pt.code = 'broker-card'
WHERE a.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Sanctions lists
--
-- Version and freshness are recorded because a screening result means nothing
-- without knowing which edition it ran against, and a list that has silently
-- stopped importing is itself a compliance failure.
-- -----------------------------------------------------------------------------
INSERT INTO sanctions_lists
  (code, name, list_type, issuing_body, country_id, source_url, current_version,
   entry_count, last_imported_at, last_changed_at, import_frequency_hours,
   staleness_alert_hours, is_active, created_at, updated_at)
SELECT v.code, v.name, v.list_type, v.issuer,
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       v.url, v.version, v.entries,
       DATE_SUB(NOW(3), INTERVAL v.hours_ago HOUR),
       DATE_SUB(NOW(3), INTERVAL (v.hours_ago + 40) HOUR),
       v.freq, v.stale_alert, 1, NOW(3), NOW(3)
FROM (
  SELECT 'ofac-sdn' AS code, 'OFAC Specially Designated Nationals' AS name,
         'sanctions' AS list_type, 'US Treasury OFAC' AS issuer,
         'united-states' AS country,
         'https://sanctionslist.ofac.treas.gov' AS url,
         '2026-02-11' AS version, 17842 AS entries, 6 AS hours_ago,
         24 AS freq, 48 AS stale_alert
  UNION ALL SELECT 'eu-consolidated', 'EU Consolidated Financial Sanctions List',
         'sanctions', 'European Commission', NULL, NULL, '2026-02-09', 4211, 14, 24, 48
  UNION ALL SELECT 'un-sc', 'UN Security Council Consolidated List', 'sanctions',
         'United Nations', NULL, NULL, '2026-01-30', 1187, 22, 24, 72
  UNION ALL SELECT 'uk-ofsi', 'UK Sanctions List', 'sanctions',
         'OFSI, HM Treasury', 'united-kingdom', NULL, '2026-02-10', 3894, 10, 24, 48
  UNION ALL SELECT 'uae-local', 'UAE Local Terrorist List', 'sanctions',
         'UAE Cabinet', 'united-arab-emirates', NULL, '2026-01-15', 96, 30, 168, 336
  UNION ALL SELECT 'pep-global', 'Global PEP database', 'pep',
         'Commercial data provider', NULL, NULL, '2026-02-12', 2841000, 4, 12, 24
  UNION ALL SELECT 'adverse-media', 'Adverse media index', 'adverse_media',
         'Commercial data provider', NULL, NULL, '2026-02-12', 18400000, 3, 6, 12
  UNION ALL SELECT 'internal-block', 'Internal blocklist', 'internal_blocklist',
         'Liv Finder', NULL, NULL, 'live', 214, 1, 1, 6
) v;

-- -----------------------------------------------------------------------------
-- KYC
--
-- Every business account gets a profile. Risk rating drives how much evidence
-- is required and how often it is refreshed, which is why the review date is a
-- function of the rating rather than a fixed year.
-- -----------------------------------------------------------------------------
INSERT INTO kyc_profiles
  (public_id, subject_type, subject_id, account_id, organization_id, entity_type,
   legal_name, nationality_country_id, residence_country_id,
   incorporation_country_id, registration_number, status, diligence_level,
   risk_rating, risk_score, risk_factors, risk_rated_at, is_pep, is_sanctioned,
   is_adverse_media, approved_at, last_reviewed_at, next_review_due,
   review_count, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('kyc:', a.id)), 26)),
  'account', a.id, a.id, o.id,
  IF(o.id IS NULL, 'individual', 'company'),
  COALESCE(o.legal_name, a.name), NULL, a.country_id, a.country_id,
  IF(o.id IS NULL, NULL, LPAD(MOD(a.id * 4441, 1000000), 6, '0')),
  CASE WHEN a.verification_status = 'verified' THEN 'approved'
       WHEN a.verification_status = 'rejected' THEN 'rejected'
       WHEN a.verification_status = 'pending' THEN 'pending_review'
       ELSE 'in_progress' END,
  -- Enhanced diligence for high-risk jurisdictions and high-value activity;
  -- simplified for small individual accounts.
  CASE WHEN MOD(a.id, 23) = 0 THEN 'enhanced'
       WHEN o.id IS NULL THEN 'simplified' ELSE 'standard' END,
  CASE WHEN MOD(a.id, 23) = 0 THEN 'high'
       WHEN MOD(a.id, 5) = 0 THEN 'low' ELSE 'medium' END,
  MOD(CONV(SUBSTRING(MD5(CONCAT('risk:', a.id)),1,3),16,10), 100),
  JSON_ARRAY(
    JSON_OBJECT('factor', 'jurisdiction', 'weight',
                IF(MOD(a.id, 23) = 0, 'high', 'low')),
    JSON_OBJECT('factor', 'entity_type', 'weight',
                IF(o.id IS NULL, 'low', 'medium')),
    JSON_OBJECT('factor', 'transaction_volume', 'weight', 'medium')),
  a.created_at,
  MOD(a.id, 61) = 0, 0, MOD(a.id, 47) = 0,
  IF(a.verification_status = 'verified', a.verified_at, NULL),
  a.verified_at,
  -- High risk reviewed annually, medium every two years, low every three. The
  -- review queue is an index scan over this column.
  DATE_ADD(DATE(COALESCE(a.verified_at, a.created_at)),
           INTERVAL CASE WHEN MOD(a.id, 23) = 0 THEN 365
                         WHEN MOD(a.id, 5) = 0 THEN 1095
                         ELSE 730 END DAY),
  1, a.created_at, NOW(3)
FROM accounts a
LEFT JOIN organizations o ON o.account_id = a.id
WHERE a.deleted_at IS NULL;

INSERT INTO kyc_checks
  (profile_id, check_type, provider, provider_reference, status, result_summary,
   confidence, cost, currency_code, requested_at, completed_at, expires_at)
SELECT k.id, v.check_type, v.provider,
       CONCAT(UPPER(LEFT(v.provider, 3)), '-', LPAD(MOD(k.id * v.salt, 100000000), 8, '0')),
       IF(k.status = 'approved', 'passed',
          IF(k.status = 'rejected', 'failed', 'pending')),
       IF(k.status = 'approved', v.pass_summary, v.fail_summary),
       ROUND(88 + MOD(k.id * v.salt, 12), 2),
       v.cost, 'USD', k.created_at,
       IF(k.status IN ('approved','rejected'), k.created_at, NULL),
       DATE_ADD(k.created_at, INTERVAL 730 DAY)
FROM kyc_profiles k
JOIN (
  SELECT 'identity_document' AS check_type, 'onfido' AS provider, 7 AS salt,
         'Document authenticated. MRZ consistent with the printed data.' AS pass_summary,
         'Document could not be authenticated. Image quality insufficient.' AS fail_summary,
         1.5000 AS cost
  UNION ALL SELECT 'liveness', 'onfido', 11,
         'Liveness confirmed.', 'Liveness check failed — possible presentation attack.', 0.8000
  UNION ALL SELECT 'face_match', 'onfido', 13,
         'Selfie matches the document photograph.',
         'Face match below threshold.', 0.9000
  UNION ALL SELECT 'sanctions', 'comply-advantage', 17,
         'No sanctions match.', 'Potential sanctions match requires review.', 0.4000
  UNION ALL SELECT 'pep', 'comply-advantage', 19,
         'No politically exposed person match.', 'PEP match requires enhanced diligence.', 0.4000
) v
WHERE k.status IN ('approved', 'rejected');

-- Company registry and beneficial-ownership checks, for corporate customers only.
INSERT INTO kyc_checks
  (profile_id, check_type, provider, provider_reference, status, result_summary,
   confidence, cost, currency_code, requested_at, completed_at, expires_at)
SELECT k.id, 'company_registry', 'creditsafe',
       CONCAT('CS-', LPAD(MOD(k.id * 23, 100000000), 8, '0')),
       'passed',
       'Company confirmed active on the register. Directors and shareholding retrieved.',
       97.00, 3.2000, 'USD', k.created_at, k.created_at,
       DATE_ADD(k.created_at, INTERVAL 365 DAY)
FROM kyc_profiles k
WHERE k.entity_type = 'company' AND k.status = 'approved';

INSERT INTO beneficial_owners
  (profile_id, depth, owner_type, full_name, nationality_country_id,
   residence_country_id, ownership_percent, control_type, is_ultimate, is_pep,
   is_sanctioned, source, verified_at, created_at, updated_at)
SELECT k.id, 0, 'individual',
       CONCAT('Beneficial owner of ', LEFT(k.legal_name, 60)),
       k.nationality_country_id, k.residence_country_id,
       ROUND(51 + MOD(k.id, 49), 3), 'shareholding', 1,
       k.is_pep, 0, 'registry', k.approved_at, k.created_at, NOW(3)
FROM kyc_profiles k
WHERE k.entity_type = 'company' AND k.status = 'approved';

-- -----------------------------------------------------------------------------
-- Screening
--
-- Onboarding screening for every approved profile. Most are clear; the ones
-- with matches are overwhelmingly name collisions, which is the honest ratio
-- and the reason dispositions exist.
-- -----------------------------------------------------------------------------
INSERT INTO screening_runs
  (profile_id, subject_type, subject_id, run_type, searched_name,
   searched_country_id, lists_screened, provider, provider_reference,
   match_count, true_positive_count, status, started_at, completed_at)
SELECT k.id, 'kyc_profile', k.id, 'onboarding', k.legal_name, k.residence_country_id,
       JSON_ARRAY('ofac-sdn', 'eu-consolidated', 'un-sc', 'uk-ofsi', 'pep-global'),
       'comply-advantage',
       CONCAT('CA-', LPAD(MOD(k.id * 3391, 1000000000), 9, '0')),
       IF(MOD(k.id, 8) = 0, 1 + MOD(k.id, 3), 0), 0,
       IF(MOD(k.id, 8) = 0, 'matches_cleared', 'clear'),
       k.created_at, DATE_ADD(k.created_at, INTERVAL 4 SECOND)
FROM kyc_profiles k;

-- Periodic re-screening. The half of the programme most organisations skip, and
-- the half that catches somebody who was clean at onboarding and is not now.
INSERT INTO screening_runs
  (profile_id, subject_type, subject_id, run_type, searched_name,
   searched_country_id, lists_screened, provider, provider_reference,
   match_count, true_positive_count, status, started_at, completed_at)
SELECT k.id, 'kyc_profile', k.id, 'list_update', k.legal_name,
       k.residence_country_id,
       JSON_ARRAY('ofac-sdn', 'eu-consolidated', 'uk-ofsi'),
       'comply-advantage',
       CONCAT('CA-RE-', LPAD(MOD(k.id * 6737, 1000000000), 9, '0')),
       0, 0, 'clear',
       DATE_SUB(NOW(3), INTERVAL 2 DAY), DATE_SUB(NOW(3), INTERVAL 2 DAY)
FROM kyc_profiles k WHERE k.status = 'approved';

INSERT INTO screening_matches
  (run_id, profile_id, list_id, list_entry_id, matched_name, match_type,
   match_score, entity_type, categories, entry_details, disposition,
   disposition_reason, reviewed_at, is_whitelisted, whitelisted_until, created_at)
SELECT r.id, r.profile_id, sl.id,
       CONCAT('SDN-', LPAD(MOD(r.id * 977, 100000), 5, '0')),
       CONCAT(SUBSTRING_INDEX(r.searched_name, ' ', 1), ' ',
              ELT(1 + MOD(r.id, 4), 'Al-Hassan', 'Khan', 'Ivanov', 'Silva')),
       'fuzzy',
       ROUND(72 + MOD(r.id, 20), 2), 'individual',
       JSON_ARRAY('sanctions'),
       JSON_OBJECT('programme', 'SDGT', 'listed_on', '2019-06-12',
                   'nationality', 'Unspecified',
                   'date_of_birth', 'Unknown'),
       -- Name collision, cleared and whitelisted so the same alert does not
       -- reappear every night for the next two years.
       'false_positive',
       'Surname match only. Date of birth, nationality and residence all differ from the listed individual. No further identifiers in common.',
       DATE_ADD(r.started_at, INTERVAL 2 HOUR),
       1, DATE_ADD(CURDATE(), INTERVAL 365 DAY), r.started_at
FROM screening_runs r
JOIN sanctions_lists sl ON sl.code = 'ofac-sdn'
WHERE r.match_count > 0;

-- -----------------------------------------------------------------------------
-- Contracts
-- -----------------------------------------------------------------------------
INSERT INTO contract_templates
  (public_id, code, name, contract_type, version, country_id, language_id,
   signing_order, governing_law, jurisdiction, default_term_months, auto_renews,
   notice_period_days, status, approved_at, effective_from, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('tmpl:', v.code)), 26)), v.code, v.name, v.type, 1,
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       (SELECT id FROM languages WHERE code = 'en'),
       v.signing_order, v.law, v.jurisdiction, v.term_months, v.auto_renews,
       v.notice_days, 'active', DATE_SUB(NOW(3), INTERVAL 300 DAY),
       DATE_SUB(CURDATE(), INTERVAL 300 DAY), NOW(3), NOW(3)
FROM (
  SELECT 'listing-agreement-ae' AS code, 'Listing agreement — UAE' AS name,
         'listing_agreement' AS type, 'united-arab-emirates' AS country,
         'parallel' AS signing_order, 'Laws of the United Arab Emirates' AS law,
         'Courts of Dubai' AS jurisdiction, 6 AS term_months, 0 AS auto_renews,
         30 AS notice_days
  UNION ALL SELECT 'exclusive-mandate-ae', 'Exclusive mandate — UAE (Form A)',
         'exclusive_mandate', 'united-arab-emirates', 'sequential',
         'Laws of the United Arab Emirates', 'Courts of Dubai', 6, 0, 30
  UNION ALL SELECT 'tenancy-ae', 'Tenancy contract — Dubai (Ejari)', 'tenancy',
         'united-arab-emirates', 'parallel', 'Law No. 26 of 2007 as amended',
         'Rental Disputes Centre, Dubai', 12, 1, 90
  UNION ALL SELECT 'sale-mou-ae', 'Memorandum of understanding — UAE (Form F)',
         'sale_mou', 'united-arab-emirates', 'sequential',
         'Laws of the United Arab Emirates', 'Dubai Land Department', NULL, 0, NULL
  UNION ALL SELECT 'agency-terms', 'Agency terms of business', 'agency_terms',
         NULL, 'parallel', 'Laws of the United Arab Emirates', 'Courts of Dubai',
         12, 1, 60
  UNION ALL SELECT 'commission-agreement', 'Commission sharing agreement',
         'commission_agreement', NULL, 'parallel',
         'Laws of the United Arab Emirates', 'Courts of Dubai', NULL, 0, NULL
  UNION ALL SELECT 'nda-standard', 'Non-disclosure agreement', 'nda', NULL,
         'parallel', 'Laws of England and Wales', 'Courts of England and Wales',
         24, 0, NULL
  UNION ALL SELECT 'dpa-standard', 'Data processing agreement', 'data_processing',
         NULL, 'parallel', 'Laws of the Netherlands', 'Courts of Amsterdam',
         NULL, 1, 30
  UNION ALL SELECT 'tenancy-gb', 'Assured shorthold tenancy — England', 'tenancy',
         'united-kingdom', 'parallel', 'Housing Act 1988', 'Courts of England and Wales',
         12, 0, 60
  UNION ALL SELECT 'charter-agreement', 'Yacht charter agreement', 'charter', NULL,
         'sequential', 'Laws of England and Wales', 'London Maritime Arbitrators Association',
         NULL, 0, NULL
) v;

-- Listing agreements for the properties under mandate, and tenancy contracts
-- for the completed rentals.
INSERT INTO contracts
  (public_id, reference, template_id, template_version, contract_type, title,
   organization_id, account_id, listing_id, deal_id, contact_id, content_hash,
   value_amount, currency_code, commission_rate, starts_on, ends_on, auto_renews,
   renewal_notice_days, notice_due_on, status, executed_at, governing_law,
   jurisdiction, language_id, created_by_user_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('contract:', d.id)), 26)),
  CONCAT('CT-', LPAD(d.id, 8, '0')),
  t.id, t.version,
  IF(d.deal_type = 'rental', 'tenancy', 'sale_mou'),
  CONCAT(IF(d.deal_type = 'rental', 'Tenancy contract', 'Memorandum of understanding'),
         ' — ', d.reference),
  d.organization_id, NULL, d.listing_id, d.id, d.contact_id,
  SHA2(CONCAT('contract-body:', d.id), 256),
  COALESCE(d.agreed_amount, d.offer_amount), d.currency_code, d.commission_rate,
  DATE(COALESCE(d.contract_signed_at, d.offer_made_at)),
  DATE_ADD(DATE(COALESCE(d.contract_signed_at, d.offer_made_at)),
           INTERVAL IF(d.deal_type = 'rental', 365, 90) DAY),
  d.deal_type = 'rental', IF(d.deal_type = 'rental', 90, NULL),
  IF(d.deal_type = 'rental',
     DATE_SUB(DATE_ADD(DATE(COALESCE(d.contract_signed_at, d.offer_made_at)),
                       INTERVAL 365 DAY), INTERVAL 90 DAY), NULL),
  CASE d.status WHEN 'completed' THEN 'executed'
                WHEN 'agreed' THEN 'partially_signed'
                WHEN 'lost' THEN 'cancelled'
                ELSE 'out_for_signature' END,
  d.contract_signed_at, t.governing_law, t.jurisdiction, t.language_id,
  d.created_by_user_id, d.created_at, NOW(3)
FROM deals d
JOIN contract_templates t
  ON t.code = IF(d.deal_type = 'rental', 'tenancy-ae', 'sale-mou-ae')
WHERE d.offer_made_at IS NOT NULL;

INSERT INTO contract_parties
  (contract_id, party_role, party_type, contact_id, legal_name, email,
   phone_e164, must_sign, signing_order, created_at)
SELECT c.id, IF(c.contract_type = 'tenancy', 'tenant', 'buyer'), 'individual',
       c.contact_id, ct.display_name, ct.primary_email, ct.primary_phone_e164,
       1, 1, c.created_at
FROM contracts c JOIN crm_contacts ct ON ct.id = c.contact_id;

INSERT INTO contract_parties
  (contract_id, party_role, party_type, organization_id, legal_name, email,
   must_sign, signing_order, created_at)
SELECT c.id, 'agency', 'company', c.organization_id,
       COALESCE(o.legal_name, o.name), o.email, 1, 2, c.created_at
FROM contracts c JOIN organizations o ON o.id = c.organization_id;

INSERT INTO signature_requests
  (public_id, contract_id, organization_id, provider, provider_envelope_id,
   title, message, signing_order, status, document_hash, sent_at, expires_at,
   completed_at, reminder_count, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('sigreq:', c.id)), 26)), c.id, c.organization_id,
       'docusign', CONCAT('env-', LOWER(LEFT(MD5(CONCAT('env:', c.id)), 24))),
       c.title,
       'Please review and sign. The document is legally binding once all parties have signed.',
       'parallel',
       CASE c.status WHEN 'executed' THEN 'completed'
                     WHEN 'partially_signed' THEN 'partially_signed'
                     WHEN 'cancelled' THEN 'voided'
                     ELSE 'sent' END,
       c.content_hash, c.created_at,
       DATE_ADD(c.created_at, INTERVAL 14 DAY), c.executed_at,
       IF(c.status = 'executed', 0, 2), c.created_at, NOW(3)
FROM contracts c;

INSERT INTO signature_signers
  (request_id, party_id, signer_order, role, name, email, authentication_method,
   authenticated_at, status, signature_type, signed_at, ip_address, user_agent,
   viewed_at, view_count, created_at, updated_at)
SELECT sr.id, p.id, p.signing_order, 'signer', p.legal_name, p.email,
       -- SMS one-time password. Stronger than an email link and weaker than a
       -- government eID, which is the trade-off most transactions settle on.
       'sms_otp',
       IF(sr.status = 'completed', sr.completed_at, NULL),
       CASE WHEN sr.status = 'completed' THEN 'signed'
            WHEN sr.status = 'partially_signed' AND p.signing_order = 1 THEN 'signed'
            WHEN sr.status = 'voided' THEN 'expired'
            ELSE 'sent' END,
       IF(sr.status IN ('completed','partially_signed'), 'drawn', NULL),
       IF(sr.status = 'completed', sr.completed_at, NULL),
       UNHEX('C0A80001'),
       'Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15',
       sr.sent_at, 1 + MOD(p.id, 4), sr.created_at, NOW(3)
FROM signature_requests sr
JOIN contract_parties p ON p.contract_id = sr.contract_id AND p.must_sign = 1;

INSERT INTO signature_events
  (request_id, signer_id, event_type, actor_name, actor_email, ip_address,
   detail, occurred_at)
SELECT s.request_id, s.id, 'sent', s.name, s.email, NULL,
       'Envelope sent to the signer.', sr.sent_at
FROM signature_signers s JOIN signature_requests sr ON sr.id = s.request_id;

INSERT INTO signature_events
  (request_id, signer_id, event_type, actor_name, actor_email, ip_address,
   user_agent, detail, occurred_at)
SELECT s.request_id, s.id, 'signed', s.name, s.email, s.ip_address, s.user_agent,
       'Signature applied after SMS one-time-password authentication.', s.signed_at
FROM signature_signers s WHERE s.signed_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Obligations
--
-- The compliance calendar. An obligation with no owner and no due date is a
-- hope, which is why both are mandatory here.
-- -----------------------------------------------------------------------------
INSERT INTO compliance_obligations
  (code, name, description, obligation_type, authority_id, country_id,
   frequency, warn_before_days, escalate_after_days, penalty_description,
   is_active, created_at, updated_at)
SELECT v.code, v.name, v.description, v.type,
       (SELECT id FROM regulatory_authorities WHERE code = v.auth LIMIT 1),
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       v.frequency, v.warn_days, v.escalate_days, v.penalty, 1, NOW(3), NOW(3)
FROM (
  SELECT 'vat-return-ae' AS code, 'UAE VAT return' AS name,
         'Quarterly VAT return to the Federal Tax Authority, due 28 days after the period ends.' AS description,
         'filing' AS type, NULL AS auth, 'united-arab-emirates' AS country,
         'quarterly' AS frequency, 14 AS warn_days, 3 AS escalate_days,
         'AED 1,000 for a first late filing, AED 2,000 for a repeat within 24 months.' AS penalty
  UNION ALL SELECT 'vat-return-sa', 'Saudi VAT return',
         'Monthly VAT return to ZATCA, due by the 15th.', 'filing', NULL,
         'saudi-arabia', 'monthly', 7, 2,
         '5% of the unpaid tax per month of delay.'
  UNION ALL SELECT 'vat-return-gb', 'UK VAT return',
         'Quarterly return under Making Tax Digital.', 'filing', NULL,
         'united-kingdom', 'quarterly', 14, 3,
         'Points-based penalty regime; a financial penalty at the fourth point.'
  UNION ALL SELECT 'oss-return-eu', 'EU One Stop Shop return',
         'Quarterly OSS return covering B2C digital supplies across all member states.',
         'filing', NULL, NULL, 'quarterly', 14, 3, 'Exclusion from OSS for persistent failure.'
  UNION ALL SELECT 'trade-licence-ae', 'Trade licence renewal',
         'Annual renewal of the free zone trade licence. Trading on an expired licence is prohibited.',
         'renewal', NULL, 'united-arab-emirates', 'annual', 60, 14,
         'Fines accrue daily, and the licence is cancelled after six months.'
  UNION ALL SELECT 'rera-licence', 'RERA brokerage licence renewal',
         'Annual renewal. Expiry suspends every listing the agency holds.',
         'renewal', 'ae-rera', 'united-arab-emirates', 'annual', 60, 14,
         'All advertising must cease. Listings are removed by the portal.'
  UNION ALL SELECT 'kyc-periodic-review', 'Periodic customer due diligence review',
         'Re-verification of customer identity and risk rating on the cycle set by the rating.',
         'review', NULL, NULL, 'monthly', 7, 14,
         'A supervisory finding, and in the Gulf a personal liability for the compliance officer.'
  UNION ALL SELECT 'sanctions-list-refresh', 'Sanctions list refresh',
         'Daily import of every screening list. A stale list means screening against yesterday''s world.',
         'screening', NULL, NULL, 'daily', 0, 1,
         'Screening performed against a stale list is treated as not performed.'
  UNION ALL SELECT 'aml-training', 'Anti-money-laundering training',
         'Annual training for every member of staff in a customer-facing or transaction-handling role.',
         'training', NULL, NULL, 'annual', 30, 30,
         'A supervisory finding and a mitigating-factor loss if an incident occurs.'
  UNION ALL SELECT 'pentest', 'Penetration test',
         'Annual third-party penetration test of the platform.', 'audit', NULL,
         NULL, 'annual', 60, 30, 'A finding under PCI-DSS and under most enterprise contracts.'
  UNION ALL SELECT 'dpia-review', 'Data protection impact assessment review',
         'Annual review of every DPIA against the processing it covers.', 'assessment',
         NULL, NULL, 'annual', 30, 30, 'A GDPR Article 35 finding.'
  UNION ALL SELECT 'ropa-review', 'Record of processing activities review',
         'Article 30 record reviewed and confirmed accurate.', 'review', NULL, NULL,
         'biannual', 30, 30, 'Produced on demand to a supervisory authority; inaccuracy is itself a breach.'
) v;

INSERT INTO compliance_obligation_instances
  (obligation_id, period_label, period_start, period_end, due_on, status,
   completed_at, reference, warned_at, created_at, updated_at)
SELECT o.id,
       CONCAT(YEAR(q.period_start), '-Q', QUARTER(q.period_start)),
       q.period_start, LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)),
       DATE_ADD(LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)), INTERVAL 28 DAY),
       CASE WHEN DATE_ADD(LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)), INTERVAL 28 DAY) < CURDATE()
            THEN 'completed' ELSE 'not_started' END,
       IF(DATE_ADD(LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)), INTERVAL 28 DAY) < CURDATE(),
          DATE_ADD(LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)), INTERVAL 20 DAY), NULL),
       CONCAT('FTA-', DATE_FORMAT(q.period_start, '%Y%m'), '-', LPAD(o.id, 3, '0')),
       DATE_SUB(DATE_ADD(LAST_DAY(DATE_ADD(q.period_start, INTERVAL 2 MONTH)), INTERVAL 28 DAY),
                INTERVAL 14 DAY),
       NOW(3), NOW(3)
FROM compliance_obligations o
JOIN (
  SELECT DATE_SUB(MAKEDATE(YEAR(CURDATE()), 1) + INTERVAL (QUARTER(CURDATE()) - 1) * 3 MONTH,
                  INTERVAL n QUARTER) AS period_start
  FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5) quarters
) q
WHERE o.frequency = 'quarterly';

-- -----------------------------------------------------------------------------
-- Incidents
--
-- The notification deadline is the clock that must never be missed: most
-- data-protection regimes impose 72 hours from awareness, and missing it turns
-- an incident into a separate offence.
-- -----------------------------------------------------------------------------
INSERT INTO compliance_incidents
  (public_id, reference, incident_type, severity, title, description,
   country_id, affected_records, affected_users, data_categories,
   occurred_at, detected_at, contained_at, notification_deadline,
   regulator_notified_at, subjects_notified_at, status, root_cause,
   remediation, preventive_actions, closed_at, created_at, updated_at)
VALUES
  (UPPER(LEFT(MD5('incident:1'), 26)), 'INC-2026-0001', 'permit_violation', 'medium',
   'Listings advertised past permit expiry',
   'A scheduled job failure meant the Trakheesi expiry sweep did not run for four days. Fourteen listings remained publicly visible after their permits had lapsed.',
   (SELECT id FROM locations WHERE level='country' AND slug='united-arab-emirates' LIMIT 1),
   14, NULL, NULL,
   DATE_SUB(NOW(3), INTERVAL 40 DAY), DATE_SUB(NOW(3), INTERVAL 36 DAY),
   DATE_SUB(NOW(3), INTERVAL 36 DAY), NULL, NULL, NULL, 'closed',
   'The expiry sweep is scheduled through the job runner and its failures were logged but not alerted. Nobody was watching a job that had never failed before.',
   'The fourteen listings were unpublished within an hour of detection. The agencies were notified and permits renewed.',
   'The sweep now writes a heartbeat and a missed run raises a page. Every compliance-critical job has been given the same treatment.',
   DATE_SUB(NOW(3), INTERVAL 30 DAY), DATE_SUB(NOW(3), INTERVAL 36 DAY), NOW(3)),

  (UPPER(LEFT(MD5('incident:2'), 26)), 'INC-2026-0002', 'unauthorised_access', 'high',
   'Agency account accessed from an unrecognised device',
   'A brokerage account was accessed from an IP address in a country the account had never been used from, and 340 contact records were exported before the session was terminated.',
   (SELECT id FROM locations WHERE level='country' AND slug='united-arab-emirates' LIMIT 1),
   340, 340, JSON_ARRAY('name', 'email', 'phone'),
   DATE_SUB(NOW(3), INTERVAL 12 DAY), DATE_SUB(NOW(3), INTERVAL 12 DAY),
   DATE_SUB(NOW(3), INTERVAL 12 DAY),
   -- The 72-hour clock from awareness.
   DATE_ADD(DATE_SUB(NOW(3), INTERVAL 12 DAY), INTERVAL 72 HOUR),
   DATE_ADD(DATE_SUB(NOW(3), INTERVAL 12 DAY), INTERVAL 31 HOUR),
   DATE_ADD(DATE_SUB(NOW(3), INTERVAL 12 DAY), INTERVAL 4 DAY),
   'closed',
   'Credential reuse. The account password matched one in a public breach corpus and multi-factor authentication was not enabled.',
   'Session terminated, credentials rotated, the export recalled where it had not been opened, and the 340 data subjects notified.',
   'Multi-factor authentication is now mandatory for every account with contact export rights. Passwords are checked against the breach corpus at set time.',
   DATE_SUB(NOW(3), INTERVAL 5 DAY), DATE_SUB(NOW(3), INTERVAL 12 DAY), NOW(3)),

  (UPPER(LEFT(MD5('incident:3'), 26)), 'INC-2026-0003', 'misleading_advert', 'low',
   'Listing photographs did not depict the advertised property',
   'The EXIF location check flagged a listing whose photographs were taken 41 kilometres from the stated address. Investigation confirmed the images were of a different building.',
   (SELECT id FROM locations WHERE level='country' AND slug='united-arab-emirates' LIMIT 1),
   1, NULL, NULL,
   DATE_SUB(NOW(3), INTERVAL 6 DAY), DATE_SUB(NOW(3), INTERVAL 6 DAY),
   DATE_SUB(NOW(3), INTERVAL 6 DAY), NULL, NULL, NULL, 'investigating',
   'Agency reused imagery from a comparable unit. Whether deliberately is the open question.',
   'Listing unpublished pending replacement photographs.',
   NULL, NULL, DATE_SUB(NOW(3), INTERVAL 6 DAY), NOW(3));
