-- =============================================================================
-- Liv Finder — 0005 · Organizations, agents and partners
-- =============================================================================
-- The public-facing business layer: agencies, brokerages, dealerships, yacht
-- brokers, aviation traders, watch dealers, developers and service partners —
-- and the individual agents who work for them.
--
-- An `organization` is the public profile and compliance record attached to an
-- `account` (0004). The account owns listings, money and members; the
-- organisation owns the brand page, licences and service areas. Splitting them
-- means a personal account can be upgraded to an agency by adding an
-- organisation row, without migrating everything it already owns.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- organizations
-- -----------------------------------------------------------------------------
CREATE TABLE organizations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,

  -- What kind of business this is. Drives which categories it may list in,
  -- which licence types are demanded, and which directory it appears in.
  kind           ENUM('agency','brokerage','dealership','developer','yacht_broker','aviation_broker','watch_dealer','marketing_partner','service_partner','media_partner') NOT NULL DEFAULT 'agency',

  name           VARCHAR(200)    NOT NULL,
  legal_name     VARCHAR(255)    NULL,
  slug           VARCHAR(220)    NOT NULL,
  tagline        VARCHAR(255)    NULL,
  description    MEDIUMTEXT      NULL,

  logo_url       VARCHAR(500)    NULL,
  cover_image_url VARCHAR(500)   NULL,

  email          VARCHAR(255)    NULL,
  phone          VARCHAR(40)     NULL,
  -- Kept distinct from `phone`: the audit found dead Call/WhatsApp buttons
  -- because contact channels were never modelled separately. They are different
  -- numbers in practice and both need to exist as data.
  whatsapp       VARCHAR(40)     NULL,
  website_url    VARCHAR(500)    NULL,

  address_line1  VARCHAR(255)    NULL,
  address_line2  VARCHAR(255)    NULL,
  postal_code    VARCHAR(30)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  state_id       BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,

  founded_year   SMALLINT UNSIGNED NULL,
  employee_count INT UNSIGNED    NULL,

  status         ENUM('draft','pending','active','suspended','archived') NOT NULL DEFAULT 'draft',
  verification_status ENUM('unverified','pending','verified','rejected','expired') NOT NULL DEFAULT 'unverified',
  verified_at    DATETIME(3)     NULL,
  -- Independent of status: an admin can pull an organisation from public
  -- listings without suspending its ability to log in and fix the problem.
  is_publicly_visible TINYINT(1) NOT NULL DEFAULT 0,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  featured_until DATETIME(3)     NULL,

  -- Rollups for the directory cards; maintained by the stats job.
  listing_count        INT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,
  agent_count          INT UNSIGNED NOT NULL DEFAULT 0,
  review_count         INT UNSIGNED NOT NULL DEFAULT 0,
  rating_avg           DECIMAL(3,2) NULL,
  -- Median first-response time to leads, in minutes. Shown on the profile and
  -- used to rank agencies in the directory.
  response_time_minutes INT UNSIGNED NULL,

  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  social_links   JSON            NULL,
  settings       JSON            NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_organizations_public_id (public_id),
  UNIQUE KEY uq_organizations_slug (slug),
  UNIQUE KEY uq_organizations_account (account_id),
  KEY ix_organizations_kind_status (kind, status, is_publicly_visible),
  -- Serves the public directory: visible orgs in a city, best-stocked first.
  KEY ix_organizations_directory (is_publicly_visible, status, city_id, active_listing_count),
  KEY ix_organizations_country (country_id, status),
  KEY ix_organizations_city (city_id, status),
  KEY ix_organizations_verification (verification_status, status),
  KEY ix_organizations_featured (is_featured, featured_until),
  KEY ix_organizations_name (name),
  KEY ix_organizations_deleted (deleted_at),
  CONSTRAINT fk_organizations_account   FOREIGN KEY (account_id)   REFERENCES accounts (id)  ON DELETE CASCADE,
  CONSTRAINT fk_organizations_country   FOREIGN KEY (country_id)   REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_organizations_state     FOREIGN KEY (state_id)     REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_organizations_city      FOREIGN KEY (city_id)      REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_organizations_community FOREIGN KEY (community_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT ck_organizations_rating CHECK (rating_avg IS NULL OR rating_avg BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE organizations ADD FULLTEXT KEY ft_organizations (name, legal_name, description);

CREATE TABLE organization_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  tagline        VARCHAR(255)    NULL,
  description    MEDIUMTEXT      NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_organization_translations (organization_id, language_id),
  CONSTRAINT fk_org_translations_org  FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_org_translations_lang FOREIGN KEY (language_id)     REFERENCES languages (id)     ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- organization_licenses
--
-- Regulatory registration, which is market-specific and genuinely load-bearing:
-- Dubai brokerages need RERA/ORN and a DED trade licence, UK agents need
-- Propertymark/redress-scheme membership, US brokers need a state licence.
-- `expires_at` is indexed because the compliance job's whole purpose is finding
-- what lapses this month and un-publishing it.
-- -----------------------------------------------------------------------------
CREATE TABLE organization_licenses (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  license_type   ENUM('trade_license','rera','orn','ded','broker_license','dtcm','maritime','aviation','vat','other') NOT NULL,
  license_number VARCHAR(120)    NOT NULL,
  issuing_authority VARCHAR(160) NULL,
  country_id     BIGINT UNSIGNED NULL,
  issued_at      DATE            NULL,
  expires_at     DATE            NULL,
  document_url   VARCHAR(500)    NULL,
  status         ENUM('pending','valid','expired','revoked','rejected') NOT NULL DEFAULT 'pending',
  verified_at    DATETIME(3)     NULL,
  verified_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_org_licenses (organization_id, license_type, license_number),
  KEY ix_org_licenses_org (organization_id, status),
  KEY ix_org_licenses_expiry (status, expires_at),
  KEY ix_org_licenses_number (license_number),
  CONSTRAINT fk_org_licenses_org      FOREIGN KEY (organization_id)     REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_org_licenses_country  FOREIGN KEY (country_id)          REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_org_licenses_verifier FOREIGN KEY (verified_by_user_id) REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Branch offices. A Dubai agency with offices in Marina, Downtown and London
-- needs each to have its own address, phone and catchment.
CREATE TABLE organization_branches (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(180)    NOT NULL,
  is_headquarters TINYINT(1)     NOT NULL DEFAULT 0,
  email          VARCHAR(255)    NULL,
  phone          VARCHAR(40)     NULL,
  whatsapp       VARCHAR(40)     NULL,
  address_line1  VARCHAR(255)    NULL,
  postal_code    VARCHAR(30)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,
  status         ENUM('active','inactive') NOT NULL DEFAULT 'active',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_org_branches_org (organization_id, status),
  KEY ix_org_branches_city (city_id),
  CONSTRAINT fk_org_branches_org       FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_org_branches_country   FOREIGN KEY (country_id)      REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_org_branches_city      FOREIGN KEY (city_id)         REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_org_branches_community FOREIGN KEY (community_id)    REFERENCES locations (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- organization_category_access — backs the admin CategoriesAccessPanel
--
-- Which asset classes an organisation is cleared to list in. A yacht brokerage
-- should not be able to publish property, and a property agency should have to
-- apply before listing jets. `status` carries the application workflow, so the
-- portal's "category requests" surface has a real backing store.
-- -----------------------------------------------------------------------------
CREATE TABLE organization_category_access (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  category_id    INT UNSIGNED    NOT NULL,
  status         ENUM('requested','approved','rejected','revoked','suspended') NOT NULL DEFAULT 'requested',
  listing_quota  INT UNSIGNED    NULL,
  listing_used   INT UNSIGNED    NOT NULL DEFAULT 0,
  requested_at   DATETIME(3)     NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_org_category_access (organization_id, category_id),
  KEY ix_org_category_access_cat (category_id, status),
  KEY ix_org_category_access_queue (status, requested_at),
  CONSTRAINT fk_oca_org      FOREIGN KEY (organization_id)     REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_oca_category FOREIGN KEY (category_id)         REFERENCES categories (id)    ON DELETE CASCADE,
  CONSTRAINT fk_oca_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_oca_requester FOREIGN KEY (requested_by_user_id) REFERENCES users (id)       ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Where an organisation actually operates. Drives "agencies in Palm Jumeirah"
-- and lead routing; `is_primary` marks the market it is known for.
CREATE TABLE organization_service_areas (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  location_id    BIGINT UNSIGNED NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_org_service_areas (organization_id, location_id),
  KEY ix_org_service_areas_location (location_id, is_primary),
  CONSTRAINT fk_osa_org      FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_osa_location FOREIGN KEY (location_id)     REFERENCES locations (id)     ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- agents
--
-- An agent is a public professional profile. `user_id` is nullable on purpose:
-- agencies routinely publish agent profiles before those people ever create a
-- login, and profiles must survive an agent leaving.
-- -----------------------------------------------------------------------------
CREATE TABLE agents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  branch_id      BIGINT UNSIGNED NULL,

  first_name     VARCHAR(120)    NOT NULL,
  last_name      VARCHAR(120)    NOT NULL,
  display_name   VARCHAR(200)    NOT NULL,
  -- The audit found the "Offered By" link resolving to href="#" on every listing
  -- because agent.slug was never populated. It is NOT NULL and unique here so
  -- an agent without a working profile URL cannot be created.
  slug           VARCHAR(220)    NOT NULL,

  title          VARCHAR(120)    NULL,
  bio            MEDIUMTEXT      NULL,
  photo_url      VARCHAR(500)    NULL,

  email          VARCHAR(255)    NULL,
  phone          VARCHAR(40)     NULL,
  whatsapp       VARCHAR(40)     NULL,
  -- Optional per-agent tracking number for attributing calls to listings.
  call_tracking_number VARCHAR(40) NULL,

  -- Broker registration number (BRN in Dubai, licence no. elsewhere).
  license_number VARCHAR(120)    NULL,
  license_expires_at DATE        NULL,
  experience_years TINYINT UNSIGNED NULL,

  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,

  status         ENUM('draft','pending','active','inactive','suspended') NOT NULL DEFAULT 'draft',
  verification_status ENUM('unverified','pending','verified','rejected','expired') NOT NULL DEFAULT 'unverified',
  verified_at    DATETIME(3)     NULL,
  -- Public visibility additionally requires the parent organisation to be
  -- publicly eligible. The audit confirmed the frontend enforces that rule; the
  -- `v_public_agents` view in 0016 encodes it so it cannot be forgotten.
  is_publicly_visible TINYINT(1) NOT NULL DEFAULT 0,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,

  listing_count        INT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count INT UNSIGNED NOT NULL DEFAULT 0,
  review_count         INT UNSIGNED NOT NULL DEFAULT 0,
  rating_avg           DECIMAL(3,2) NULL,
  response_time_minutes INT UNSIGNED NULL,
  -- Percentage of leads answered within the platform SLA; drives directory sort.
  response_rate        DECIMAL(5,2) NULL,

  joined_at      DATE            NULL,
  left_at        DATE            NULL,

  social_links   JSON            NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_agents_public_id (public_id),
  UNIQUE KEY uq_agents_slug (slug),
  KEY ix_agents_org (organization_id, status, is_publicly_visible),
  KEY ix_agents_user (user_id),
  KEY ix_agents_directory (is_publicly_visible, status, city_id, active_listing_count),
  KEY ix_agents_name (last_name, first_name),
  KEY ix_agents_verification (verification_status, status),
  KEY ix_agents_branch (branch_id),
  KEY ix_agents_deleted (deleted_at),
  CONSTRAINT fk_agents_user    FOREIGN KEY (user_id)         REFERENCES users (id)                 ON DELETE SET NULL,
  CONSTRAINT fk_agents_org     FOREIGN KEY (organization_id) REFERENCES organizations (id)         ON DELETE SET NULL,
  CONSTRAINT fk_agents_branch  FOREIGN KEY (branch_id)       REFERENCES organization_branches (id) ON DELETE SET NULL,
  CONSTRAINT fk_agents_country FOREIGN KEY (country_id)      REFERENCES locations (id)             ON DELETE SET NULL,
  CONSTRAINT fk_agents_city    FOREIGN KEY (city_id)         REFERENCES locations (id)             ON DELETE SET NULL,
  CONSTRAINT ck_agents_rating CHECK (rating_avg IS NULL OR rating_avg BETWEEN 0 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE agents ADD FULLTEXT KEY ft_agents (display_name, bio);

-- Spoken languages. A meaningful filter in Dubai, Marbella and Miami, where
-- buyers actively search for an agent who speaks Russian, Mandarin or Arabic.
CREATE TABLE agent_languages (
  agent_id       BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  proficiency    ENUM('basic','conversational','fluent','native') NOT NULL DEFAULT 'fluent',
  PRIMARY KEY (agent_id, language_id),
  KEY ix_agent_languages_language (language_id),
  CONSTRAINT fk_agent_languages_agent    FOREIGN KEY (agent_id)    REFERENCES agents (id)    ON DELETE CASCADE,
  CONSTRAINT fk_agent_languages_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE agent_service_areas (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  agent_id       BIGINT UNSIGNED NOT NULL,
  location_id    BIGINT UNSIGNED NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_agent_service_areas (agent_id, location_id),
  KEY ix_agent_service_areas_location (location_id, is_primary),
  CONSTRAINT fk_asa_agent    FOREIGN KEY (agent_id)    REFERENCES agents (id)    ON DELETE CASCADE,
  CONSTRAINT fk_asa_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE agent_specialties (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  agent_id       BIGINT UNSIGNED NOT NULL,
  category_id    INT UNSIGNED    NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_agent_specialties (agent_id, category_id),
  KEY ix_agent_specialties_category (category_id),
  CONSTRAINT fk_agent_specialties_agent    FOREIGN KEY (agent_id)    REFERENCES agents (id)     ON DELETE CASCADE,
  CONSTRAINT fk_agent_specialties_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- verification_requests
--
-- The audit noted verification is "static deny/verified flags only — no live
-- verification pipeline". This is the pipeline: one queue covering organisations,
-- agents, listings and accounts, so moderators work a single list.
-- -----------------------------------------------------------------------------
CREATE TABLE verification_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject_type   ENUM('organization','agent','account','listing','user') NOT NULL,
  -- Polymorphic by design: a single moderation queue is worth more than the FK
  -- this gives up. Integrity is enforced by the application and by the nightly
  -- orphan check in tools/.
  subject_id     BIGINT UNSIGNED NOT NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  status         ENUM('pending','in_review','approved','rejected','expired','withdrawn') NOT NULL DEFAULT 'pending',
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  submitted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  assigned_to_user_id BIGINT UNSIGNED NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  decision_notes VARCHAR(1000)   NULL,
  rejection_reason VARCHAR(500)  NULL,
  -- Verification is not permanent; licences lapse. The compliance job demotes
  -- subjects past this date back to `unverified`.
  expires_at     DATETIME(3)     NULL,
  payload        JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_verification_public_id (public_id),
  KEY ix_verification_subject (subject_type, subject_id, status),
  KEY ix_verification_queue (status, priority, submitted_at),
  KEY ix_verification_assignee (assigned_to_user_id, status),
  KEY ix_verification_expiry (status, expires_at),
  CONSTRAINT fk_verification_requester FOREIGN KEY (requested_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_verification_assignee  FOREIGN KEY (assigned_to_user_id)  REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_verification_reviewer  FOREIGN KEY (reviewed_by_user_id)  REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE verification_documents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  verification_request_id BIGINT UNSIGNED NOT NULL,
  document_type  VARCHAR(80)     NOT NULL,
  file_url       VARCHAR(500)    NOT NULL,
  file_name      VARCHAR(255)    NULL,
  mime_type      VARCHAR(120)    NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  status         ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  notes          VARCHAR(500)    NULL,
  uploaded_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_verification_documents_request (verification_request_id),
  CONSTRAINT fk_verification_documents_request FOREIGN KEY (verification_request_id) REFERENCES verification_requests (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- access_requests — "let me join this organisation"
--
-- Backs the portal's access-requests surface. Distinct from an invitation: here
-- the agent asks the agency, rather than the agency asking the agent.
-- -----------------------------------------------------------------------------
CREATE TABLE access_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  requested_role ENUM('manager','agent','viewer','accountant') NOT NULL DEFAULT 'agent',
  status         ENUM('pending','approved','rejected','cancelled','expired') NOT NULL DEFAULT 'pending',
  message        VARCHAR(1000)   NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  response_note  VARCHAR(500)    NULL,
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_access_requests_public_id (public_id),
  KEY ix_access_requests_org (organization_id, status, created_at),
  KEY ix_access_requests_user (user_id, status),
  CONSTRAINT fk_access_requests_org      FOREIGN KEY (organization_id)     REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_access_requests_user     FOREIGN KEY (user_id)             REFERENCES users (id)         ON DELETE CASCADE,
  CONSTRAINT fk_access_requests_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- api_clients — backs the admin ApiAccessModal and partner feed integrations
-- -----------------------------------------------------------------------------
CREATE TABLE api_clients (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  -- Public identifier shown in the UI; the secret is stored only as a hash.
  client_id      VARCHAR(64)     NOT NULL,
  secret_hash    BINARY(32)      NOT NULL,
  -- Last four characters, so the UI can show `••••a3f9` for identification.
  secret_hint    VARCHAR(8)      NULL,
  scopes         JSON            NULL,
  rate_limit_per_minute INT UNSIGNED NOT NULL DEFAULT 60,
  allowed_ips    JSON            NULL,
  status         ENUM('active','suspended','revoked') NOT NULL DEFAULT 'active',
  last_used_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  revoked_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_api_clients_public_id (public_id),
  UNIQUE KEY uq_api_clients_client_id (client_id),
  KEY ix_api_clients_account (account_id, status),
  KEY ix_api_clients_org (organization_id, status),
  CONSTRAINT fk_api_clients_account FOREIGN KEY (account_id)         REFERENCES accounts (id)      ON DELETE CASCADE,
  CONSTRAINT fk_api_clients_org     FOREIGN KEY (organization_id)    REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_api_clients_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0005', 'organizations_and_agents');
