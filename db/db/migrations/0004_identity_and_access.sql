-- =============================================================================
-- Liv Finder — 0004 · Identity, accounts and access control
-- =============================================================================
-- THE USER/ACCOUNT SPLIT
-- ---------------------
-- The audit found two related gaps: organisation roles (owner/manager/viewer)
-- existed only as unused function signatures, and there was no way for anyone to
-- change account type after signup — "that choice is made once, at signup, and is
-- permanent thereafter".
--
-- Both are symptoms of the same modelling mistake: treating account type as a
-- property of the person. It is not. A person is a `user` — one set of
-- credentials, one identity. What they can do is a property of the `account`
-- they are acting as, and the two are many-to-many through `account_members`:
--
--     users ──< account_members >── accounts ──> account_types
--
-- That one change makes both gaps ordinary:
--
--   · One person can be a private buyer, an agent at Acme Realty, and the owner
--     of their own brokerage, switching between them the way Google switches
--     accounts. `account_members.role` differs per membership, so owner/manager/
--     agent/viewer finally has somewhere real to live and something to enforce
--     against.
--   · Changing type is `account_type_change_requests` — a reviewable workflow
--     with an audit trail, not a destructive edit — because upgrading personal →
--     organisation genuinely needs licence checks and admin approval.
--
-- Sessions are server-side rows here, not client-set cookies. The audit's
-- security section flags the current `document.cookie` approach as "a hard
-- requirement once real auth lands"; `user_sessions` is that requirement. The
-- cookie carries only an opaque token whose SHA-256 is stored — a database leak
-- does not hand over live sessions.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- users — one row per human, credentials only
-- -----------------------------------------------------------------------------
CREATE TABLE users (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,

  email          VARCHAR(255)    NOT NULL,
  -- Lower-cased, dot/plus-normalised form. Uniqueness is enforced on this, not
  -- on `email`, so User+tag@gmail.com cannot register twice against
  -- user@gmail.com while the display form still shows what they typed.
  email_normalized VARCHAR(255)  NOT NULL,
  email_verified_at DATETIME(3)  NULL,

  phone_country_code VARCHAR(8)  NULL,
  phone_number   VARCHAR(32)     NULL,
  -- E.164, generated so it is always consistent with its parts and can be
  -- indexed for uniqueness without the app remembering to build it.
  phone_e164     VARCHAR(40)     GENERATED ALWAYS AS (
                   CASE WHEN phone_country_code IS NULL OR phone_number IS NULL THEN NULL
                        ELSE CONCAT('+', phone_country_code, phone_number) END
                 ) STORED,
  phone_verified_at DATETIME(3)  NULL,

  -- Argon2id/bcrypt digest. NULL for accounts created purely through OAuth, who
  -- have no password to check.
  password_hash  VARCHAR(255)    NULL,
  password_updated_at DATETIME(3) NULL,
  -- Bumped on password change or forced logout; every session carrying an older
  -- value is invalid. Global sign-out without deleting rows.
  session_epoch  INT UNSIGNED    NOT NULL DEFAULT 0,

  status         ENUM('pending_verification','active','suspended','banned','closed') NOT NULL DEFAULT 'pending_verification',
  suspended_reason VARCHAR(255)  NULL,
  suspended_until DATETIME(3)    NULL,

  first_name     VARCHAR(120)    NULL,
  last_name      VARCHAR(120)    NULL,
  display_name   VARCHAR(200)    NULL,
  avatar_url     VARCHAR(500)    NULL,

  -- Presentation preferences. Denormalised onto the user because every single
  -- page render needs all four and none of them justify a join.
  preferred_language_id SMALLINT UNSIGNED NULL,
  preferred_currency_id SMALLINT UNSIGNED NULL,
  preferred_area_unit VARCHAR(20) NOT NULL DEFAULT 'sqft',
  timezone       VARCHAR(64)     NOT NULL DEFAULT 'UTC',

  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,

  -- The account this user lands in after login, when they belong to several.
  default_account_id BIGINT UNSIGNED NULL,

  last_login_at  DATETIME(3)     NULL,
  last_seen_at   DATETIME(3)     NULL,
  last_login_ip  VARBINARY(16)   NULL,
  login_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  failed_login_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  locked_until   DATETIME(3)     NULL,

  mfa_enabled    TINYINT(1)      NOT NULL DEFAULT 0,
  marketing_opt_in TINYINT(1)    NOT NULL DEFAULT 0,
  terms_accepted_at DATETIME(3)  NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_users_public_id (public_id),
  UNIQUE KEY uq_users_email_normalized (email_normalized),
  UNIQUE KEY uq_users_phone (phone_e164),
  KEY ix_users_status (status, created_at),
  KEY ix_users_name (last_name, first_name),
  KEY ix_users_country (country_id),
  KEY ix_users_last_seen (last_seen_at),
  KEY ix_users_deleted (deleted_at),
  CONSTRAINT fk_users_language FOREIGN KEY (preferred_language_id) REFERENCES languages (id)  ON DELETE SET NULL,
  CONSTRAINT fk_users_currency FOREIGN KEY (preferred_currency_id) REFERENCES currencies (id) ON DELETE SET NULL,
  CONSTRAINT fk_users_country  FOREIGN KEY (country_id)            REFERENCES locations (id)  ON DELETE SET NULL,
  CONSTRAINT fk_users_city     FOREIGN KEY (city_id)               REFERENCES locations (id)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- account_types — personal, lister, company, organization, partner
--
-- A table rather than an ENUM because these carry behaviour (quotas, whether
-- they may hold members, whether they need verification) that admins tune, and
-- because `account_type_transitions` needs to reference them as rows.
-- -----------------------------------------------------------------------------
CREATE TABLE account_types (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(100)    NOT NULL,
  description    VARCHAR(500)    NULL,
  -- Can this type hold more than one member? Personal accounts cannot; agencies
  -- and organisations can. This is what makes the role model meaningful.
  supports_members TINYINT(1)    NOT NULL DEFAULT 0,
  -- Does it get an `organizations` row (branding, licences, public profile)?
  requires_organization TINYINT(1) NOT NULL DEFAULT 0,
  requires_verification TINYINT(1) NOT NULL DEFAULT 0,
  can_list       TINYINT(1)      NOT NULL DEFAULT 0,
  default_listing_quota INT UNSIGNED NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_account_types_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which type changes are permitted, and what each one costs the requester in
-- process. Data, not `if` statements, so product can open or close an upgrade
-- path without a deploy.
CREATE TABLE account_type_transitions (
  from_type_id   SMALLINT UNSIGNED NOT NULL,
  to_type_id     SMALLINT UNSIGNED NOT NULL,
  is_allowed     TINYINT(1)      NOT NULL DEFAULT 1,
  requires_approval TINYINT(1)   NOT NULL DEFAULT 1,
  requires_documents TINYINT(1)  NOT NULL DEFAULT 0,
  -- Free-text warning shown before confirming, e.g. what stops being available
  -- when downgrading an organisation to a personal account.
  notice         VARCHAR(500)    NULL,
  PRIMARY KEY (from_type_id, to_type_id),
  KEY ix_account_type_transitions_to (to_type_id),
  CONSTRAINT fk_att_from FOREIGN KEY (from_type_id) REFERENCES account_types (id) ON DELETE CASCADE,
  CONSTRAINT fk_att_to   FOREIGN KEY (to_type_id)   REFERENCES account_types (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- accounts — the entity that owns listings, leads, money and members
-- -----------------------------------------------------------------------------
CREATE TABLE accounts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_type_id SMALLINT UNSIGNED NOT NULL,
  -- Whoever currently holds the owner role. Denormalised from account_members
  -- for cheap "who do I chase about this account" lookups in admin.
  owner_user_id  BIGINT UNSIGNED NULL,

  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NOT NULL,

  status         ENUM('pending','active','suspended','closed') NOT NULL DEFAULT 'pending',
  verification_status ENUM('unverified','pending','verified','rejected','expired') NOT NULL DEFAULT 'unverified',
  verified_at    DATETIME(3)     NULL,

  -- Quota/consumption, kept on the account because every publish attempt checks
  -- it and it must not require aggregating `listings`.
  listing_quota  INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_used   INT UNSIGNED    NOT NULL DEFAULT 0,
  featured_quota INT UNSIGNED    NOT NULL DEFAULT 0,
  featured_used  INT UNSIGNED    NOT NULL DEFAULT 0,

  billing_email  VARCHAR(255)    NULL,
  billing_currency_id SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,

  settings       JSON            NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_accounts_public_id (public_id),
  UNIQUE KEY uq_accounts_slug (slug),
  KEY ix_accounts_type_status (account_type_id, status),
  KEY ix_accounts_owner (owner_user_id),
  KEY ix_accounts_verification (verification_status, status),
  KEY ix_accounts_country (country_id),
  KEY ix_accounts_deleted (deleted_at),
  CONSTRAINT fk_accounts_type     FOREIGN KEY (account_type_id)     REFERENCES account_types (id) ON DELETE RESTRICT,
  CONSTRAINT fk_accounts_owner    FOREIGN KEY (owner_user_id)       REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_accounts_currency FOREIGN KEY (billing_currency_id) REFERENCES currencies (id)    ON DELETE SET NULL,
  CONSTRAINT fk_accounts_country  FOREIGN KEY (country_id)          REFERENCES locations (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE users
  ADD CONSTRAINT fk_users_default_account FOREIGN KEY (default_account_id) REFERENCES accounts (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- account_members — the org role model, with somewhere to actually live
--
-- `role` is the owner/manager/agent/viewer distinction the audit found defined
-- but unenforced. Storing it per membership (not per user) is what lets the same
-- person be an owner of one agency and a viewer at another.
--
-- The permission flags are denormalised alongside it deliberately: authorisation
-- is checked on essentially every authenticated request, and resolving it
-- through role → role_permissions → permissions on each one is a join nobody
-- should pay for. `role` remains the source of truth; the flags are a cache the
-- application recomputes whenever role changes, and they also allow per-member
-- exceptions ("a viewer who may nonetheless export leads").
-- -----------------------------------------------------------------------------
CREATE TABLE account_members (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  role           ENUM('owner','manager','agent','viewer','accountant') NOT NULL DEFAULT 'viewer',
  status         ENUM('invited','active','suspended','removed') NOT NULL DEFAULT 'invited',
  title          VARCHAR(120)    NULL,

  can_manage_organization TINYINT(1) NOT NULL DEFAULT 0,
  can_manage_members      TINYINT(1) NOT NULL DEFAULT 0,
  can_manage_listings     TINYINT(1) NOT NULL DEFAULT 0,
  can_publish_listings    TINYINT(1) NOT NULL DEFAULT 0,
  can_manage_leads        TINYINT(1) NOT NULL DEFAULT 0,
  can_view_integrations   TINYINT(1) NOT NULL DEFAULT 0,
  can_manage_billing      TINYINT(1) NOT NULL DEFAULT 0,

  invited_by_user_id BIGINT UNSIGNED NULL,
  invited_at     DATETIME(3)     NULL,
  joined_at      DATETIME(3)     NULL,
  removed_at     DATETIME(3)     NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_account_members (account_id, user_id),
  KEY ix_account_members_user (user_id, status),
  KEY ix_account_members_role (account_id, role, status),
  CONSTRAINT fk_account_members_account FOREIGN KEY (account_id)         REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_account_members_user    FOREIGN KEY (user_id)            REFERENCES users (id)    ON DELETE CASCADE,
  CONSTRAINT fk_account_members_inviter FOREIGN KEY (invited_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- account_type_change_requests — the switching flow that did not exist
--
-- The audit: "no code path anywhere lets an existing user convert between
-- personal, lister, company, organization, or partner account types". This is
-- the backing store for that flow. It is a request with a review lifecycle
-- rather than an UPDATE because a personal → organisation upgrade means trade
-- licences and RERA numbers that someone has to actually look at.
-- -----------------------------------------------------------------------------
CREATE TABLE account_type_change_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  requested_by_user_id BIGINT UNSIGNED NOT NULL,
  from_type_id   SMALLINT UNSIGNED NOT NULL,
  to_type_id     SMALLINT UNSIGNED NOT NULL,
  status         ENUM('draft','submitted','under_review','approved','rejected','cancelled') NOT NULL DEFAULT 'draft',
  -- Details supplied for the target type (company name, licence numbers) held
  -- as JSON until approval, so a pending request never half-mutates the account.
  payload        JSON            NULL,
  reason         VARCHAR(1000)   NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  review_notes   VARCHAR(1000)   NULL,
  rejection_reason VARCHAR(500)  NULL,
  applied_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_atcr_public_id (public_id),
  KEY ix_atcr_account (account_id, status),
  KEY ix_atcr_queue (status, created_at),
  KEY ix_atcr_reviewer (reviewed_by_user_id),
  CONSTRAINT fk_atcr_account   FOREIGN KEY (account_id)           REFERENCES accounts (id)      ON DELETE CASCADE,
  CONSTRAINT fk_atcr_requester FOREIGN KEY (requested_by_user_id) REFERENCES users (id)         ON DELETE CASCADE,
  CONSTRAINT fk_atcr_from      FOREIGN KEY (from_type_id)         REFERENCES account_types (id) ON DELETE RESTRICT,
  CONSTRAINT fk_atcr_to        FOREIGN KEY (to_type_id)           REFERENCES account_types (id) ON DELETE RESTRICT,
  CONSTRAINT fk_atcr_reviewer  FOREIGN KEY (reviewed_by_user_id)  REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Uploaded evidence for a change request (trade licence, Emirates ID, RERA card).
CREATE TABLE account_type_change_documents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     BIGINT UNSIGNED NOT NULL,
  document_type  VARCHAR(80)     NOT NULL,
  file_url       VARCHAR(500)    NOT NULL,
  file_name      VARCHAR(255)    NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  mime_type      VARCHAR(120)    NULL,
  status         ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
  notes          VARCHAR(500)    NULL,
  uploaded_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_atcd_request (request_id),
  CONSTRAINT fk_atcd_request FOREIGN KEY (request_id) REFERENCES account_type_change_requests (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Platform RBAC — staff roles, separate from account membership
--
-- `account_members.role` governs "what can you do inside this agency".
-- `roles`/`user_roles` govern "are you Liv Finder staff, and of what kind".
-- Conflating them is how support engineers end up able to edit invoices.
-- -----------------------------------------------------------------------------
CREATE TABLE permissions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(100)    NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  -- Coarse grouping for the admin permission matrix UI: listings, users,
  -- moderation, finance, content, system.
  domain         VARCHAR(60)     NOT NULL,
  description    VARCHAR(500)    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_permissions_code (code),
  KEY ix_permissions_domain (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(500)    NULL,
  scope          ENUM('platform','account') NOT NULL DEFAULT 'platform',
  -- Built-in roles the system depends on; admins may not delete them.
  is_system      TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_code (code),
  KEY ix_roles_scope (scope)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE role_permissions (
  role_id        INT UNSIGNED    NOT NULL,
  permission_id  INT UNSIGNED    NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  KEY ix_role_permissions_permission (permission_id),
  CONSTRAINT fk_role_permissions_role       FOREIGN KEY (role_id)       REFERENCES roles (id)       ON DELETE CASCADE,
  CONSTRAINT fk_role_permissions_permission FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_roles (
  user_id        BIGINT UNSIGNED NOT NULL,
  role_id        INT UNSIGNED    NOT NULL,
  granted_by_user_id BIGINT UNSIGNED NULL,
  granted_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- Time-boxed elevation for contractors and incident response.
  expires_at     DATETIME(3)     NULL,
  PRIMARY KEY (user_id, role_id),
  KEY ix_user_roles_role (role_id),
  KEY ix_user_roles_expiry (expires_at),
  CONSTRAINT fk_user_roles_user    FOREIGN KEY (user_id)            REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_role    FOREIGN KEY (role_id)            REFERENCES roles (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_roles_granter FOREIGN KEY (granted_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- user_sessions — server-side sessions
--
-- The cookie holds a random token; only its SHA-256 is stored, so read access to
-- this table does not yield usable sessions. `active_account_id` is what makes
-- account switching work: the same session points at a different account after a
-- switch, with no re-login.
-- -----------------------------------------------------------------------------
CREATE TABLE user_sessions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  token_hash     BINARY(32)      NOT NULL,
  -- Session is void if this no longer matches users.session_epoch.
  session_epoch  INT UNSIGNED    NOT NULL DEFAULT 0,
  active_account_id BIGINT UNSIGNED NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,
  device_type    ENUM('desktop','mobile','tablet','bot','other') NOT NULL DEFAULT 'other',
  -- Set when staff assume a user's identity for support, so every action taken
  -- during it is attributable to a real person in the audit log.
  impersonated_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_used_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NOT NULL,
  revoked_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_sessions_public_id (public_id),
  UNIQUE KEY uq_user_sessions_token (token_hash),
  KEY ix_user_sessions_user (user_id, revoked_at, expires_at),
  -- Supports the cleanup job that reaps expired rows in bounded batches.
  KEY ix_user_sessions_expiry (expires_at),
  CONSTRAINT fk_user_sessions_user    FOREIGN KEY (user_id)                 REFERENCES users (id)    ON DELETE CASCADE,
  CONSTRAINT fk_user_sessions_account FOREIGN KEY (active_account_id)       REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_user_sessions_imp     FOREIGN KEY (impersonated_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- OAuth / social identities (Google, Apple, LinkedIn).
CREATE TABLE user_identities (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  provider       VARCHAR(40)     NOT NULL,
  provider_uid   VARCHAR(191)    NOT NULL,
  email          VARCHAR(255)    NULL,
  raw_profile    JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_used_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_identities (provider, provider_uid),
  KEY ix_user_identities_user (user_id),
  CONSTRAINT fk_user_identities_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- user_tokens — password reset, email/phone verification, invitations
--
-- One table rather than four near-identical ones. Only the hash is stored, and
-- single-use is enforced by `consumed_at` rather than by deletion, so a replayed
-- link can be distinguished from an unknown one in the logs.
-- -----------------------------------------------------------------------------
CREATE TABLE user_tokens (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NULL,
  purpose        ENUM('password_reset','email_verification','phone_verification','magic_link','invitation','mfa_recovery') NOT NULL,
  token_hash     BINARY(32)      NOT NULL,
  -- The address the token was issued against, so changing the email mid-flight
  -- cannot be used to verify an address the user does not control.
  target         VARCHAR(255)    NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ip_address     VARBINARY(16)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NOT NULL,
  consumed_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_tokens_hash (token_hash),
  KEY ix_user_tokens_user (user_id, purpose, consumed_at),
  KEY ix_user_tokens_expiry (expires_at),
  CONSTRAINT fk_user_tokens_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_mfa_factors (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  factor_type    ENUM('totp','sms','email','webauthn','recovery_code') NOT NULL,
  -- Encrypted at the application layer before it reaches the database.
  secret_encrypted VARBINARY(512) NULL,
  label          VARCHAR(120)    NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  confirmed_at   DATETIME(3)     NULL,
  last_used_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_user_mfa_user (user_id, factor_type),
  CONSTRAINT fk_user_mfa_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Privacy / GDPR — backs the client portal's Privacy Center
-- -----------------------------------------------------------------------------
CREATE TABLE user_consents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  consent_type   ENUM('terms','privacy_policy','marketing_email','marketing_sms','marketing_whatsapp','cookies_analytics','cookies_marketing','data_sharing') NOT NULL,
  is_granted     TINYINT(1)      NOT NULL,
  -- Version of the document consented to, so a policy change can be detected
  -- and re-consent requested rather than assumed.
  policy_version VARCHAR(40)     NULL,
  source         VARCHAR(80)     NULL,
  ip_address     VARBINARY(16)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_user_consents_user (user_id, consent_type, created_at),
  CONSTRAINT fk_user_consents_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE data_subject_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  request_type   ENUM('export','deletion','rectification','restriction','objection') NOT NULL,
  status         ENUM('pending','in_progress','completed','rejected','cancelled') NOT NULL DEFAULT 'pending',
  notes          VARCHAR(1000)   NULL,
  result_url     VARCHAR(500)    NULL,
  -- Statutory deadline (30 days under GDPR); lets the queue sort by urgency.
  due_at         DATETIME(3)     NULL,
  handled_by_user_id BIGINT UNSIGNED NULL,
  completed_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_dsr_public_id (public_id),
  KEY ix_dsr_user (user_id, status),
  KEY ix_dsr_queue (status, due_at),
  CONSTRAINT fk_dsr_user    FOREIGN KEY (user_id)            REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_dsr_handler FOREIGN KEY (handled_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0004', 'identity_and_access');
