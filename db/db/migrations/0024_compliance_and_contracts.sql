-- =============================================================================
-- Liv Finder — 0024 · Compliance, risk and contracts
-- =============================================================================
-- Luxury property, yachts, jets and watches are, from a regulator's point of
-- view, the four asset classes most used to move money that should not be
-- moving. A marketplace in these categories is not an ordinary classifieds
-- site; it is a business with obligations, and those obligations are
-- structural, not a checkbox somebody ticks at signup.
--
-- Four bodies of requirement are modelled here:
--
-- 1. LISTING AUTHORISATION. In Dubai every advertised property needs a
--    Trakheesi permit; the permit has an expiry, and advertising past it is a
--    fineable offence for the agency and for us. Other markets have analogues —
--    a UK EPC, a Spanish nota simple, a French Loi Carrez survey. Modelled
--    generically as `listing_permits` against `regulatory_authorities`, because
--    the shape is the same everywhere even though the names are not.
--
-- 2. KNOW YOUR CUSTOMER. Identity, verification evidence, and the timestamp of
--    each — because a check is only defensible if you can show when it was
--    done and what it saw. Re-verification is scheduled, since a passport that
--    was valid in 2024 may not be now.
--
-- 3. ANTI-MONEY-LAUNDERING. Sanctions and PEP screening with recorded matches
--    and their disposition. Two design points matter: a screening result is
--    kept even when it is a false positive (so the same name does not
--    re-alarm forever, and so a regulator can see it was considered), and
--    ongoing monitoring re-screens existing customers when the lists change —
--    which is where most programmes fail, because they only screen at onboarding.
--
-- 4. CONTRACTS AND SIGNATURES. Listing agreements, tenancy contracts, sale
--    MOUs and agency terms, with version history and a signature audit trail
--    detailed enough to stand up if the document is ever disputed.
--
-- A note on `suspicious_activity_reports`: its existence is itself sensitive.
-- In most jurisdictions telling the customer that a report was filed is a
-- criminal offence ("tipping off"), which is why the table carries an explicit
-- disclosure flag and why nothing in it may ever surface through a normal
-- account view.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · REGULATORY REGISTRATION AND PERMITS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- regulatory_authorities
--
-- The bodies whose rules apply, per market. Data rather than code because the
-- platform operates in forty countries and each new market brings its own.
-- -----------------------------------------------------------------------------
CREATE TABLE regulatory_authorities (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  short_name     VARCHAR(60)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  authority_type ENUM('property_regulator','land_registry','financial_regulator','maritime','aviation','consumer_protection','data_protection','tax','chamber_of_commerce','professional_body') NOT NULL DEFAULT 'property_regulator',
  -- Which asset classes fall under it. RERA covers property; the GCAA covers
  -- aircraft; neither covers watches.
  applies_to_categories JSON     NULL,
  website_url    VARCHAR(500)    NULL,
  -- Whether we can machine-verify a permit or licence with them. Where we can,
  -- verification is a job; where we cannot, it is a document review.
  has_verification_api TINYINT(1) NOT NULL DEFAULT 0,
  verification_endpoint VARCHAR(500) NULL,
  notes          TEXT            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_regulatory_authorities_code (code),
  KEY ix_regulatory_authorities_country (country_id, authority_type, is_active),
  CONSTRAINT fk_reg_authorities_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_reg_authorities_state FOREIGN KEY (state_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- permit_types
--
-- What kinds of authorisation exist and what each requires. `blocks_publishing`
-- is the consequential flag: a missing Trakheesi permit must prevent
-- publication, while a missing EPC in some markets is a warning.
-- -----------------------------------------------------------------------------
CREATE TABLE permit_types (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  authority_id   INT UNSIGNED    NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(500)    NULL,
  applies_to     ENUM('listing','project','organization','agent','deal','vessel','aircraft') NOT NULL DEFAULT 'listing',
  root_category_id INT UNSIGNED  NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  -- Enforcement.
  is_mandatory   TINYINT(1)      NOT NULL DEFAULT 1,
  blocks_publishing TINYINT(1)   NOT NULL DEFAULT 1,
  -- Expiry handling. Permits lapse and the platform must stop advertising
  -- before they do, not after.
  validity_days  SMALLINT UNSIGNED NULL,
  warn_before_days SMALLINT UNSIGNED NOT NULL DEFAULT 14,
  -- Display: many regulators require the permit number and a QR code to be
  -- shown on the advert itself.
  must_display_on_listing TINYINT(1) NOT NULL DEFAULT 0,
  display_label  VARCHAR(80)     NULL,
  number_format_regex VARCHAR(200) NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_permit_types_code (authority_id, code),
  KEY ix_permit_types_scope (applies_to, country_id, is_active),
  CONSTRAINT fk_permit_types_authority FOREIGN KEY (authority_id) REFERENCES regulatory_authorities (id) ON DELETE CASCADE,
  CONSTRAINT fk_permit_types_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_permit_types_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_permits
--
-- One authorisation held against one subject. The index on
-- (status, expires_at) is the whole operational point: a nightly job takes
-- every permit about to lapse, warns the agency, and unpublishes on the day it
-- does — which is the difference between a compliance feature and a compliance
-- liability.
-- -----------------------------------------------------------------------------
CREATE TABLE listing_permits (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  permit_type_id INT UNSIGNED    NOT NULL,
  authority_id   INT UNSIGNED    NOT NULL,
  subject_type   ENUM('listing','project','organization','agent','deal') NOT NULL DEFAULT 'listing',
  subject_id     BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  permit_number  VARCHAR(80)     NOT NULL,
  -- Some regulators issue a QR that must be rendered on the advert.
  qr_code_url    VARCHAR(500)    NULL,
  verification_url VARCHAR(500)  NULL,
  issued_at      DATE            NULL,
  expires_at     DATE            NULL,
  status         ENUM('pending','submitted','active','expiring','expired','rejected','revoked','not_required') NOT NULL DEFAULT 'pending',
  -- Verification evidence: how we know the number is real.
  verification_status ENUM('unverified','api_verified','document_verified','manually_verified','failed') NOT NULL DEFAULT 'unverified',
  verified_at    DATETIME(3)     NULL,
  verified_by_user_id BIGINT UNSIGNED NULL,
  verification_response JSON     NULL,
  document_id    BIGINT UNSIGNED NULL,
  rejection_reason VARCHAR(500)  NULL,
  -- Set when the platform acted on a lapse, so enforcement is auditable.
  enforced_at    DATETIME(3)     NULL,
  enforcement_action ENUM('none','warned','unpublished','suspended') NOT NULL DEFAULT 'none',
  warned_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_listing_permit (permit_type_id, subject_type, subject_id, permit_number),
  -- The expiry sweeper.
  KEY ix_listing_permits_expiry (status, expires_at),
  KEY ix_listing_permits_subject (subject_type, subject_id),
  KEY ix_listing_permits_listing (listing_id, status),
  KEY ix_listing_permits_org (organization_id, status, expires_at),
  KEY ix_listing_permits_number (permit_number),
  CONSTRAINT fk_listing_permits_type FOREIGN KEY (permit_type_id) REFERENCES permit_types (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_permits_authority FOREIGN KEY (authority_id) REFERENCES regulatory_authorities (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_permits_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_permits_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_permits_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · KYC
-- =============================================================================

-- -----------------------------------------------------------------------------
-- kyc_profiles
--
-- The customer-due-diligence record for one subject — an account, a user, or a
-- counterparty on a deal.
--
-- `risk_rating` drives everything downstream: how much evidence is required,
-- how often it is refreshed, and whether enhanced due diligence applies. It is
-- recomputed rather than set once, because risk changes when behaviour does.
-- -----------------------------------------------------------------------------
CREATE TABLE kyc_profiles (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  subject_type   ENUM('account','user','organization','contact','deal_party') NOT NULL DEFAULT 'account',
  subject_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- Who they are, as verified rather than as claimed.
  entity_type    ENUM('individual','company','trust','partnership','fund','government','other') NOT NULL DEFAULT 'individual',
  legal_name     VARCHAR(255)    NULL,
  date_of_birth  DATE            NULL,
  nationality_country_id BIGINT UNSIGNED NULL,
  residence_country_id BIGINT UNSIGNED NULL,
  incorporation_country_id BIGINT UNSIGNED NULL,
  registration_number VARCHAR(80) NULL,
  -- Due diligence outcome.
  status         ENUM('not_started','in_progress','pending_review','approved','rejected','expired','suspended') NOT NULL DEFAULT 'not_started',
  diligence_level ENUM('simplified','standard','enhanced') NOT NULL DEFAULT 'standard',
  risk_rating    ENUM('low','medium','high','prohibited') NOT NULL DEFAULT 'medium',
  risk_score     SMALLINT UNSIGNED NULL,
  risk_factors   JSON            NULL,
  risk_rated_at  DATETIME(3)     NULL,
  -- Politically exposed persons need enhanced diligence and senior sign-off.
  is_pep         TINYINT(1)      NOT NULL DEFAULT 0,
  pep_category   VARCHAR(120)    NULL,
  is_sanctioned  TINYINT(1)      NOT NULL DEFAULT 0,
  is_adverse_media TINYINT(1)    NOT NULL DEFAULT 0,
  -- Approval trail. Enhanced-diligence cases require a named approver, and
  -- "who signed this off" is the first question in any inspection.
  approved_at    DATETIME(3)     NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  approval_note  VARCHAR(1000)   NULL,
  rejected_at    DATETIME(3)     NULL,
  rejection_reason VARCHAR(500)  NULL,
  -- Periodic refresh. High risk is reviewed annually, low risk every three
  -- years — the interval is a function of the rating, and the due date is
  -- stored so the review queue is an index scan.
  last_reviewed_at DATETIME(3)   NULL,
  next_review_due DATE           NULL,
  review_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Data-protection: identity evidence has its own, shorter retention than the
  -- account it belongs to.
  data_expires_at DATE           NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kyc_profiles_public (public_id),
  UNIQUE KEY uq_kyc_profile_subject (subject_type, subject_id),
  -- The review queue.
  KEY ix_kyc_profiles_review (status, next_review_due),
  KEY ix_kyc_profiles_risk (risk_rating, status),
  KEY ix_kyc_profiles_account (account_id),
  KEY ix_kyc_profiles_flags (is_pep, is_sanctioned, status),
  CONSTRAINT fk_kyc_profiles_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_kyc_profiles_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_kyc_profiles_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_kyc_profiles_nationality FOREIGN KEY (nationality_country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_kyc_profiles_residence FOREIGN KEY (residence_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- kyc_checks
--
-- One verification performed by one provider. Kept as separate rows rather than
-- flags on the profile because a customer is typically checked several times by
-- several providers over several years, and the history is the evidence.
--
-- `provider_reference` is what an auditor asks for: the id that lets the
-- provider reproduce exactly what was returned on the day.
-- -----------------------------------------------------------------------------
CREATE TABLE kyc_checks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  profile_id     BIGINT UNSIGNED NOT NULL,
  check_type     ENUM('identity_document','liveness','face_match','address_proof','company_registry','ubo_discovery','bank_account','tax_id','source_of_funds','sanctions','pep','adverse_media','credit') NOT NULL,
  provider       VARCHAR(60)     NULL,
  provider_reference VARCHAR(191) NULL,
  status         ENUM('pending','processing','passed','failed','review_required','expired','cancelled') NOT NULL DEFAULT 'pending',
  result_summary VARCHAR(500)    NULL,
  confidence     DECIMAL(5,2)    NULL,
  -- Structured findings. Redacted of raw document images, which live in the
  -- document store with their own access control.
  result_payload JSON            NULL,
  failure_reasons JSON           NULL,
  document_id    BIGINT UNSIGNED NULL,
  -- Manual override, which happens and must be attributable.
  overridden     TINYINT(1)      NOT NULL DEFAULT 0,
  overridden_by_user_id BIGINT UNSIGNED NULL,
  override_reason VARCHAR(500)   NULL,
  cost           DECIMAL(10,4)   NULL,
  currency_code  CHAR(3)         NULL,
  requested_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_kyc_checks_profile (profile_id, check_type, requested_at),
  KEY ix_kyc_checks_status (status, requested_at),
  KEY ix_kyc_checks_provider (provider, provider_reference),
  CONSTRAINT fk_kyc_checks_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_kyc_checks_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- identity_documents
--
-- Passports, national ids, residence permits, trade licences.
--
-- Note the absence of a full document number column: `number_last4` plus a hash
-- is enough to match and to display, and storing a complete passport number in
-- a queryable column is a liability with no operational upside. The image
-- itself lives in the document store under access control, referenced here.
-- -----------------------------------------------------------------------------
CREATE TABLE identity_documents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  profile_id     BIGINT UNSIGNED NOT NULL,
  document_type  ENUM('passport','national_id','drivers_licence','residence_permit','visa','trade_licence','certificate_of_incorporation','utility_bill','bank_statement','tenancy_contract','tax_certificate','other') NOT NULL,
  issuing_country_id BIGINT UNSIGNED NULL,
  -- See the table comment on why the full number is not stored.
  number_hash    CHAR(64)        NULL,
  number_last4   VARCHAR(8)      NULL,
  holder_name    VARCHAR(255)    NULL,
  issued_on      DATE            NULL,
  expires_on     DATE            NULL,
  -- Machine-readable-zone parse result, when the document had one. Kept
  -- because an MRZ that disagrees with the printed data is a strong forgery
  -- signal.
  mrz_valid      TINYINT(1)      NULL,
  mrz_mismatch_fields JSON       NULL,
  document_id    BIGINT UNSIGNED NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  status         ENUM('pending','verified','rejected','expired','superseded') NOT NULL DEFAULT 'pending',
  verified_at    DATETIME(3)     NULL,
  verified_by_user_id BIGINT UNSIGNED NULL,
  rejection_reason VARCHAR(300)  NULL,
  -- Retention: identity images are deleted well before the account is.
  purge_after    DATE            NULL,
  purged_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_identity_documents_profile (profile_id, document_type, status),
  KEY ix_identity_documents_expiry (status, expires_on),
  KEY ix_identity_documents_purge (purge_after, purged_at),
  CONSTRAINT fk_identity_documents_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_identity_documents_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_identity_documents_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- beneficial_owners
--
-- Who ultimately owns and controls a corporate customer. The obligation is to
-- look through the structure, not to record the first company you meet, so
-- `depth` and `parent_owner_id` model the chain rather than flattening it.
-- -----------------------------------------------------------------------------
CREATE TABLE beneficial_owners (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  profile_id     BIGINT UNSIGNED NOT NULL,
  parent_owner_id BIGINT UNSIGNED NULL,
  depth          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  owner_type     ENUM('individual','company','trust','foundation','nominee','government','unknown') NOT NULL DEFAULT 'individual',
  full_name      VARCHAR(255)    NOT NULL,
  date_of_birth  DATE            NULL,
  nationality_country_id BIGINT UNSIGNED NULL,
  residence_country_id BIGINT UNSIGNED NULL,
  registration_number VARCHAR(80) NULL,
  ownership_percent DECIMAL(6,3) NULL,
  -- Control can exist without ownership — a nominee director, a golden share.
  control_type   ENUM('shareholding','voting_rights','board_control','significant_influence','trustee','beneficiary','other') NULL,
  is_ultimate    TINYINT(1)      NOT NULL DEFAULT 0,
  is_pep         TINYINT(1)      NOT NULL DEFAULT 0,
  is_sanctioned  TINYINT(1)      NOT NULL DEFAULT 0,
  own_profile_id BIGINT UNSIGNED NULL,
  source         ENUM('declared','registry','provider','document','manual') NOT NULL DEFAULT 'declared',
  verified_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_beneficial_owners_profile (profile_id, depth),
  KEY ix_beneficial_owners_parent (parent_owner_id),
  KEY ix_beneficial_owners_flags (is_pep, is_sanctioned),
  CONSTRAINT fk_beneficial_owners_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_beneficial_owners_parent FOREIGN KEY (parent_owner_id) REFERENCES beneficial_owners (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- source_of_funds_declarations
--
-- Where the money for a transaction came from, with the evidence. Required
-- above threshold in every market this platform operates in, and the single
-- most-requested document in any inspection of a property transaction.
-- -----------------------------------------------------------------------------
CREATE TABLE source_of_funds_declarations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  profile_id     BIGINT UNSIGNED NOT NULL,
  deal_id        BIGINT UNSIGNED NULL,
  payment_id     BIGINT UNSIGNED NULL,
  source_type    ENUM('employment','business_income','sale_of_property','sale_of_investments','inheritance','gift','loan','mortgage','savings','dividends','crypto','lottery','compensation','other') NOT NULL,
  description    VARCHAR(1000)   NULL,
  amount         DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  amount_base    DECIMAL(18,2)   NULL,
  origin_country_id BIGINT UNSIGNED NULL,
  -- The originating institution, which matters as much as the amount: funds
  -- routed through a high-risk jurisdiction change the assessment.
  institution_name VARCHAR(200)  NULL,
  institution_country_id BIGINT UNSIGNED NULL,
  evidence_document_ids JSON     NULL,
  status         ENUM('declared','evidence_pending','under_review','accepted','rejected','escalated') NOT NULL DEFAULT 'declared',
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  review_note    VARCHAR(1000)   NULL,
  declared_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_sof_profile (profile_id, declared_at),
  KEY ix_sof_deal (deal_id),
  KEY ix_sof_status (status, declared_at),
  CONSTRAINT fk_sof_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_sof_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  CONSTRAINT fk_sof_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · SCREENING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- sanctions_lists
--
-- The lists we screen against and, critically, their version. A screening
-- result means nothing without knowing which edition of the OFAC SDN list it
-- was run against — and `last_imported_at` going stale is itself a compliance
-- failure worth alerting on.
-- -----------------------------------------------------------------------------
CREATE TABLE sanctions_lists (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  list_type      ENUM('sanctions','pep','adverse_media','watchlist','internal_blocklist','law_enforcement') NOT NULL DEFAULT 'sanctions',
  issuing_body   VARCHAR(160)    NULL,
  country_id     BIGINT UNSIGNED NULL,
  source_url     VARCHAR(500)    NULL,
  -- Version tracking.
  current_version VARCHAR(60)    NULL,
  entry_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  last_imported_at DATETIME(3)   NULL,
  last_changed_at DATETIME(3)    NULL,
  import_frequency_hours SMALLINT UNSIGNED NOT NULL DEFAULT 24,
  -- How stale is too stale before we raise an operational alarm.
  staleness_alert_hours SMALLINT UNSIGNED NOT NULL DEFAULT 48,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sanctions_lists_code (code),
  KEY ix_sanctions_lists_stale (is_active, last_imported_at),
  CONSTRAINT fk_sanctions_lists_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- screening_runs / screening_matches
--
-- A run is one screening of one subject against the lists at a moment in time.
-- Matches are what came back, each with its own disposition.
--
-- The disposition is the important part. Sanctions screening produces mostly
-- false positives — common names collide constantly — and a programme where
-- every alert stays open is a programme nobody reads. `disposition` plus
-- `is_whitelisted` means a name cleared once stops re-alarming, while the
-- decision and its author remain on the record.
-- -----------------------------------------------------------------------------
CREATE TABLE screening_runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  profile_id     BIGINT UNSIGNED NULL,
  subject_type   ENUM('kyc_profile','beneficial_owner','deal_party','organization','user','contact','payment') NOT NULL DEFAULT 'kyc_profile',
  subject_id     BIGINT UNSIGNED NOT NULL,
  run_type       ENUM('onboarding','periodic','transaction','list_update','manual','bulk') NOT NULL DEFAULT 'onboarding',
  -- The query as screened, and the list versions it was screened against.
  searched_name  VARCHAR(255)    NULL,
  searched_dob   DATE            NULL,
  searched_country_id BIGINT UNSIGNED NULL,
  lists_screened JSON            NULL,
  provider       VARCHAR(60)     NULL,
  provider_reference VARCHAR(191) NULL,
  match_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  true_positive_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  status         ENUM('running','clear','matches_pending','matches_cleared','hit_confirmed','failed') NOT NULL DEFAULT 'running',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  error_message  VARCHAR(500)    NULL,
  PRIMARY KEY (id),
  KEY ix_screening_runs_profile (profile_id, started_at),
  KEY ix_screening_runs_subject (subject_type, subject_id, started_at),
  KEY ix_screening_runs_status (status, started_at),
  CONSTRAINT fk_screening_runs_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE screening_matches (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  run_id         BIGINT UNSIGNED NOT NULL,
  profile_id     BIGINT UNSIGNED NULL,
  list_id        INT UNSIGNED    NULL,
  list_entry_id  VARCHAR(120)    NULL,
  matched_name   VARCHAR(255)    NOT NULL,
  match_type     ENUM('exact','fuzzy','phonetic','alias','partial') NOT NULL DEFAULT 'fuzzy',
  match_score    DECIMAL(5,2)    NULL,
  entity_type    ENUM('individual','entity','vessel','aircraft','unknown') NOT NULL DEFAULT 'individual',
  categories     JSON            NULL,
  -- Enough of the list entry to make a decision without a second API call.
  entry_details  JSON            NULL,
  -- Disposition. See the table comment.
  disposition    ENUM('pending','false_positive','true_positive','possible_match','escalated','discounted') NOT NULL DEFAULT 'pending',
  disposition_reason VARCHAR(1000) NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  -- A cleared name is remembered, so the next run does not re-raise it.
  is_whitelisted TINYINT(1)      NOT NULL DEFAULT 0,
  whitelisted_until DATE         NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_screening_matches_run (run_id, disposition),
  KEY ix_screening_matches_profile (profile_id, disposition),
  -- The reviewer's queue.
  KEY ix_screening_matches_pending (disposition, match_score, created_at),
  CONSTRAINT fk_screening_matches_run FOREIGN KEY (run_id) REFERENCES screening_runs (id) ON DELETE CASCADE,
  CONSTRAINT fk_screening_matches_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE CASCADE,
  CONSTRAINT fk_screening_matches_list FOREIGN KEY (list_id) REFERENCES sanctions_lists (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- suspicious_activity_reports
--
-- Internal escalations and, where filed, reports to the financial intelligence
-- unit.
--
-- This table is confidential in a way nothing else in the schema is. In most
-- jurisdictions disclosing to a customer that a report concerning them exists
-- is a criminal offence — "tipping off" — so `customer_disclosed` exists to
-- record a breach if one ever occurs, and nothing here may be joined into any
-- customer-facing view. Access is expected to be restricted at the database
-- role level, not merely in the application.
-- -----------------------------------------------------------------------------
CREATE TABLE suspicious_activity_reports (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  profile_id     BIGINT UNSIGNED NULL,
  subject_type   ENUM('account','user','organization','deal','payment','listing','contact') NOT NULL DEFAULT 'account',
  subject_id     BIGINT UNSIGNED NOT NULL,
  report_type    ENUM('internal_escalation','sar','str','ctr','regulatory_notification') NOT NULL DEFAULT 'internal_escalation',
  trigger_reason ENUM('sanctions_hit','pep_exposure','structuring','unusual_value','rapid_movement','third_party_payment','high_risk_jurisdiction','source_of_funds_unclear','identity_concern','behavioural','staff_report','other') NOT NULL,
  narrative      TEXT            NOT NULL,
  amount_involved DECIMAL(18,2)  NULL,
  currency_code  CHAR(3)         NULL,
  amount_base    DECIMAL(18,2)   NULL,
  status         ENUM('draft','under_investigation','escalated','filed','closed_no_action','closed_reported') NOT NULL DEFAULT 'draft',
  raised_by_user_id BIGINT UNSIGNED NULL,
  raised_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- The money-laundering reporting officer is a named individual with a
  -- personal legal duty; their decision is the one that counts.
  mlro_user_id   BIGINT UNSIGNED NULL,
  mlro_decision  ENUM('pending','file','do_not_file','more_information') NOT NULL DEFAULT 'pending',
  mlro_decided_at DATETIME(3)    NULL,
  mlro_rationale TEXT            NULL,
  -- Filing detail.
  filed_at       DATETIME(3)     NULL,
  filed_with     VARCHAR(160)    NULL,
  filing_reference VARCHAR(120)  NULL,
  -- Whether the relationship was frozen or exited as a result.
  action_taken   ENUM('none','monitoring','restricted','frozen','terminated') NOT NULL DEFAULT 'none',
  -- Tipping-off control. See the table comment.
  customer_disclosed TINYINT(1)  NOT NULL DEFAULT 0,
  disclosure_incident_note VARCHAR(500) NULL,
  -- Long retention, typically five years past the relationship ending.
  retain_until   DATE            NULL,
  closed_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sar_public (public_id),
  UNIQUE KEY uq_sar_reference (reference),
  KEY ix_sar_status (status, raised_at),
  KEY ix_sar_subject (subject_type, subject_id),
  KEY ix_sar_profile (profile_id),
  CONSTRAINT fk_sar_profile FOREIGN KEY (profile_id) REFERENCES kyc_profiles (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 4 · CONTRACTS AND SIGNATURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- contract_templates
--
-- The master documents: listing agreements, tenancy contracts, agency terms,
-- NDAs. Versioned, because a contract executed under version 3 must always
-- render as version 3 no matter how many times the template is revised
-- afterwards.
-- -----------------------------------------------------------------------------
CREATE TABLE contract_templates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  contract_type  ENUM('listing_agreement','exclusive_mandate','tenancy','sale_mou','purchase_agreement','agency_terms','commission_agreement','nda','data_processing','charter','management','service','other') NOT NULL DEFAULT 'listing_agreement',
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  organization_id BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  -- The body, with merge fields. Stored rather than referenced because the
  -- exact text at execution time is the legally operative artefact.
  body_template  LONGTEXT        NULL,
  merge_fields   JSON            NULL,
  -- Which signatures are needed and in what order.
  required_signers JSON          NULL,
  signing_order  ENUM('any','sequential','parallel') NOT NULL DEFAULT 'parallel',
  -- Governing law and jurisdiction, which vary by market and must be recorded.
  governing_law  VARCHAR(160)    NULL,
  jurisdiction   VARCHAR(160)    NULL,
  default_term_months SMALLINT UNSIGNED NULL,
  auto_renews    TINYINT(1)      NOT NULL DEFAULT 0,
  notice_period_days SMALLINT UNSIGNED NULL,
  status         ENUM('draft','under_review','approved','active','superseded','retired') NOT NULL DEFAULT 'draft',
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  effective_from DATE            NULL,
  superseded_by_id INT UNSIGNED  NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_contract_templates_public (public_id),
  UNIQUE KEY uq_contract_templates_version (code, version, organization_id),
  KEY ix_contract_templates_active (contract_type, status, country_id),
  CONSTRAINT fk_contract_templates_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_contract_templates_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_contract_templates_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_contract_templates_superseded FOREIGN KEY (superseded_by_id) REFERENCES contract_templates (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- contracts
--
-- One executed or in-flight agreement.
--
-- `content_hash` is the tamper seal: the SHA-256 of the exact rendered document
-- that was signed. If the stored file is ever altered, the hash no longer
-- matches the one recorded at signature, and the alteration is provable rather
-- than suspected.
-- -----------------------------------------------------------------------------
CREATE TABLE contracts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  template_id    INT UNSIGNED    NULL,
  template_version SMALLINT UNSIGNED NULL,
  contract_type  ENUM('listing_agreement','exclusive_mandate','tenancy','sale_mou','purchase_agreement','agency_terms','commission_agreement','nda','data_processing','charter','management','service','other') NOT NULL DEFAULT 'listing_agreement',
  title          VARCHAR(255)    NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  -- What it concerns.
  listing_id     BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  -- The document. `document_id` points at the stored file; `content_hash` seals
  -- it. `rendered_body` is kept for contracts generated from a template so the
  -- text survives independently of the file store.
  document_id    BIGINT UNSIGNED NULL,
  rendered_body  LONGTEXT        NULL,
  content_hash   CHAR(64)        NULL,
  -- Commercial terms, extracted so they are queryable — "which mandates expire
  -- next month" is a question somebody asks weekly.
  value_amount   DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  commission_rate DECIMAL(7,4)   NULL,
  starts_on      DATE            NULL,
  ends_on        DATE            NULL,
  auto_renews    TINYINT(1)      NOT NULL DEFAULT 0,
  renewal_notice_days SMALLINT UNSIGNED NULL,
  notice_due_on  DATE            NULL,
  status         ENUM('draft','pending_review','out_for_signature','partially_signed','executed','active','expiring','expired','terminated','cancelled','superseded') NOT NULL DEFAULT 'draft',
  executed_at    DATETIME(3)     NULL,
  terminated_at  DATETIME(3)     NULL,
  termination_reason VARCHAR(500) NULL,
  terminated_by_user_id BIGINT UNSIGNED NULL,
  superseded_by_id BIGINT UNSIGNED NULL,
  governing_law  VARCHAR(160)    NULL,
  jurisdiction   VARCHAR(160)    NULL,
  language_id    SMALLINT UNSIGNED NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_contracts_public (public_id),
  UNIQUE KEY uq_contracts_reference (reference),
  -- The renewal and expiry watch.
  KEY ix_contracts_expiry (status, ends_on),
  KEY ix_contracts_notice (status, notice_due_on),
  KEY ix_contracts_org (organization_id, contract_type, status),
  KEY ix_contracts_listing (listing_id, status),
  KEY ix_contracts_deal (deal_id),
  KEY ix_contracts_contact (contact_id, status),
  CONSTRAINT fk_contracts_template FOREIGN KEY (template_id) REFERENCES contract_templates (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_contracts_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_contracts_superseded FOREIGN KEY (superseded_by_id) REFERENCES contracts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- contract_parties
--
-- Who is bound, and who must sign. External parties are stored by name and
-- contact rather than forced into a user record, because most counterparties to
-- a tenancy contract will never have a platform login.
-- -----------------------------------------------------------------------------
CREATE TABLE contract_parties (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id    BIGINT UNSIGNED NOT NULL,
  party_role     ENUM('landlord','tenant','seller','buyer','agency','agent','platform','guarantor','witness','broker','developer','other') NOT NULL,
  party_type     ENUM('individual','company','platform') NOT NULL DEFAULT 'individual',
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  legal_name     VARCHAR(255)    NOT NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  identity_reference VARCHAR(80) NULL,
  address        VARCHAR(500)    NULL,
  must_sign      TINYINT(1)      NOT NULL DEFAULT 1,
  signing_order  TINYINT UNSIGNED NULL,
  kyc_profile_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_contract_parties_contract (contract_id, party_role),
  KEY ix_contract_parties_contact (contact_id),
  KEY ix_contract_parties_user (user_id),
  CONSTRAINT fk_contract_parties_contract FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE,
  CONSTRAINT fk_contract_parties_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_contract_parties_kyc FOREIGN KEY (kyc_profile_id) REFERENCES kyc_profiles (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- contract_versions
--
-- Every revision, with a diff summary and its own hash. Negotiation is
-- iterative and "which version did they actually agree to" is the question a
-- dispute turns on.
-- -----------------------------------------------------------------------------
CREATE TABLE contract_versions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contract_id    BIGINT UNSIGNED NOT NULL,
  version_number SMALLINT UNSIGNED NOT NULL,
  document_id    BIGINT UNSIGNED NULL,
  content_hash   CHAR(64)        NULL,
  rendered_body  LONGTEXT        NULL,
  change_summary VARCHAR(1000)   NULL,
  changed_clauses JSON           NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_by_party_id BIGINT UNSIGNED NULL,
  is_current     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_contract_version (contract_id, version_number),
  KEY ix_contract_versions_current (contract_id, is_current),
  CONSTRAINT fk_contract_versions_contract FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE,
  CONSTRAINT fk_contract_versions_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- signature_requests / signature_signers / signature_events
--
-- The e-signature envelope, its signers and its audit trail.
--
-- `signature_events` is not logging for its own sake. Under eIDAS, the ESIGN
-- Act and the UAE's electronic transactions law, what makes a signature
-- enforceable is the evidence around it: that this person, at this address, saw
-- this document, at this time, and acted. An envelope without that trail is a
-- picture of a signature.
-- -----------------------------------------------------------------------------
CREATE TABLE signature_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  contract_id    BIGINT UNSIGNED NULL,
  document_id    BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  provider       ENUM('internal','docusign','adobe_sign','dropbox_sign','signnow','uae_pass','other') NOT NULL DEFAULT 'internal',
  provider_envelope_id VARCHAR(191) NULL,
  title          VARCHAR(255)    NOT NULL,
  message        VARCHAR(2000)   NULL,
  signing_order  ENUM('any','sequential','parallel') NOT NULL DEFAULT 'parallel',
  status         ENUM('draft','sent','viewed','partially_signed','completed','declined','expired','voided','failed') NOT NULL DEFAULT 'draft',
  -- What was actually sent, sealed. If the file changes after sending, the
  -- signatures no longer attest to it.
  document_hash  CHAR(64)        NULL,
  signed_document_id BIGINT UNSIGNED NULL,
  signed_document_hash CHAR(64)  NULL,
  -- Certificate of completion from the provider: the portable evidence bundle.
  certificate_document_id BIGINT UNSIGNED NULL,
  sent_at        DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  voided_at      DATETIME(3)     NULL,
  void_reason    VARCHAR(500)    NULL,
  reminder_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  last_reminder_at DATETIME(3)   NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_signature_requests_public (public_id),
  KEY ix_signature_requests_contract (contract_id, status),
  KEY ix_signature_requests_status (status, expires_at),
  KEY ix_signature_requests_provider (provider, provider_envelope_id),
  CONSTRAINT fk_signature_requests_contract FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE CASCADE,
  CONSTRAINT fk_signature_requests_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_signature_requests_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE signature_signers (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     BIGINT UNSIGNED NOT NULL,
  party_id       BIGINT UNSIGNED NULL,
  signer_order   TINYINT UNSIGNED NOT NULL DEFAULT 1,
  role           ENUM('signer','approver','witness','cc','certified_recipient') NOT NULL DEFAULT 'signer',
  name           VARCHAR(255)    NOT NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  user_id        BIGINT UNSIGNED NULL,
  -- Identity assurance applied before signing. An SMS code is weak; UAE Pass
  -- or a government eID is strong, and the difference determines what the
  -- signature is worth in a dispute.
  authentication_method ENUM('email_link','sms_otp','email_otp','id_document','knowledge_based','government_eid','biometric','none') NOT NULL DEFAULT 'email_link',
  authenticated_at DATETIME(3)   NULL,
  status         ENUM('pending','sent','viewed','signed','declined','expired','bounced') NOT NULL DEFAULT 'pending',
  -- The signature artefact and where it was applied.
  signature_image_asset_id BIGINT UNSIGNED NULL,
  signature_type ENUM('drawn','typed','uploaded','digital_certificate','click_to_sign') NULL,
  signed_at      DATETIME(3)     NULL,
  declined_at    DATETIME(3)     NULL,
  decline_reason VARCHAR(500)    NULL,
  -- Evidence captured at signing.
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(300)    NULL,
  geo_country_id BIGINT UNSIGNED NULL,
  access_token_hash CHAR(64)     NULL,
  viewed_at      DATETIME(3)     NULL,
  view_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_signature_signer_order (request_id, signer_order, role),
  KEY ix_signature_signers_request (request_id, status),
  KEY ix_signature_signers_email (email),
  CONSTRAINT fk_signature_signers_request FOREIGN KEY (request_id) REFERENCES signature_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_signature_signers_party FOREIGN KEY (party_id) REFERENCES contract_parties (id) ON DELETE SET NULL,
  CONSTRAINT fk_signature_signers_asset FOREIGN KEY (signature_image_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE signature_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     BIGINT UNSIGNED NOT NULL,
  signer_id      BIGINT UNSIGNED NULL,
  event_type     ENUM('created','sent','delivered','opened','viewed','authenticated','auth_failed','signed','declined','completed','reminded','expired','voided','downloaded','bounced','error') NOT NULL,
  actor_name     VARCHAR(255)    NULL,
  actor_email    VARCHAR(255)    NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(300)    NULL,
  detail         VARCHAR(1000)   NULL,
  provider_payload JSON          NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_signature_events_request (request_id, occurred_at),
  KEY ix_signature_events_signer (signer_id, occurred_at),
  CONSTRAINT fk_signature_events_request FOREIGN KEY (request_id) REFERENCES signature_requests (id) ON DELETE CASCADE,
  CONSTRAINT fk_signature_events_signer FOREIGN KEY (signer_id) REFERENCES signature_signers (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 5 · OBLIGATIONS AND INCIDENTS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- compliance_obligations
--
-- The recurring duties: file a VAT return, renew a trade licence, re-screen
-- customers, submit a regulatory return, run a penetration test. Each with an
-- owner and a due date, because an obligation with neither is a hope.
-- -----------------------------------------------------------------------------
CREATE TABLE compliance_obligations (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  obligation_type ENUM('filing','renewal','review','training','audit','assessment','report','screening','retention','notification') NOT NULL DEFAULT 'filing',
  authority_id   INT UNSIGNED    NULL,
  country_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  frequency      ENUM('once','daily','weekly','monthly','quarterly','biannual','annual','biennial','on_event') NOT NULL DEFAULT 'annual',
  -- Days before the due date at which the owner is warned, and after which it
  -- escalates. Both are needed: a reminder nobody acts on is not a control.
  warn_before_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  escalate_after_days SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  owner_user_id  BIGINT UNSIGNED NULL,
  escalation_user_id BIGINT UNSIGNED NULL,
  penalty_description VARCHAR(500) NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_compliance_obligations_code (code, organization_id),
  KEY ix_compliance_obligations_org (organization_id, is_active),
  CONSTRAINT fk_obligations_authority FOREIGN KEY (authority_id) REFERENCES regulatory_authorities (id) ON DELETE SET NULL,
  CONSTRAINT fk_obligations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_obligations_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One occurrence of an obligation: this quarter's VAT return, this year's
-- licence renewal. The obligation is the rule; this is the instance that is
-- either done or overdue.
CREATE TABLE compliance_obligation_instances (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  obligation_id  INT UNSIGNED    NOT NULL,
  period_label   VARCHAR(60)     NULL,
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  due_on         DATE            NOT NULL,
  status         ENUM('not_started','in_progress','submitted','completed','overdue','waived','failed') NOT NULL DEFAULT 'not_started',
  owner_user_id  BIGINT UNSIGNED NULL,
  completed_at   DATETIME(3)     NULL,
  completed_by_user_id BIGINT UNSIGNED NULL,
  evidence_document_ids JSON     NULL,
  reference      VARCHAR(120)    NULL,
  notes          VARCHAR(1000)   NULL,
  warned_at      DATETIME(3)     NULL,
  escalated_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_obligation_instance (obligation_id, period_label),
  -- The compliance calendar.
  KEY ix_obligation_instances_due (status, due_on),
  KEY ix_obligation_instances_owner (owner_user_id, status, due_on),
  CONSTRAINT fk_obligation_instances_obligation FOREIGN KEY (obligation_id) REFERENCES compliance_obligations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- compliance_incidents
--
-- Things that went wrong: a data breach, an advert published without a permit,
-- a payment taken from a sanctioned party, a licence that lapsed unnoticed.
--
-- `regulator_notified_at` and `notification_deadline` are here because most
-- data-protection regimes impose a 72-hour clock from awareness, and missing it
-- converts an incident into a separate offence.
-- -----------------------------------------------------------------------------
CREATE TABLE compliance_incidents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  incident_type  ENUM('data_breach','unauthorised_access','permit_violation','sanctions_breach','misleading_advert','licence_lapse','payment_incident','fraud','complaint','regulatory_enquiry','system_outage','other') NOT NULL,
  severity       ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  title          VARCHAR(255)    NOT NULL,
  description    TEXT            NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  authority_id   INT UNSIGNED    NULL,
  -- Scope of harm.
  affected_records INT UNSIGNED  NULL,
  affected_users INT UNSIGNED    NULL,
  data_categories JSON           NULL,
  financial_impact DECIMAL(16,2) NULL,
  currency_code  CHAR(3)         NULL,
  -- The clock.
  occurred_at    DATETIME(3)     NULL,
  detected_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  contained_at   DATETIME(3)     NULL,
  notification_deadline DATETIME(3) NULL,
  regulator_notified_at DATETIME(3) NULL,
  subjects_notified_at DATETIME(3) NULL,
  notification_reference VARCHAR(120) NULL,
  status         ENUM('open','investigating','contained','remediating','closed','reported') NOT NULL DEFAULT 'open',
  root_cause     TEXT            NULL,
  remediation    TEXT            NULL,
  preventive_actions TEXT        NULL,
  reported_by_user_id BIGINT UNSIGNED NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  closed_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_incidents_public (public_id),
  UNIQUE KEY uq_incidents_reference (reference),
  -- The notification clock, which is the one that must never be missed.
  KEY ix_incidents_deadline (status, notification_deadline),
  KEY ix_incidents_severity (severity, status, detected_at),
  KEY ix_incidents_org (organization_id, detected_at),
  CONSTRAINT fk_incidents_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_incidents_authority FOREIGN KEY (authority_id) REFERENCES regulatory_authorities (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0024', 'compliance_and_contracts');
