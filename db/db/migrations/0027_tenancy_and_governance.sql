-- =============================================================================
-- Liv Finder — 0027 · Multi-brand tenancy, data governance and change history
-- =============================================================================
-- Three separate concerns share this migration because they share one property:
-- each one is far cheaper to build in from the start than to retrofit, and each
-- one is routinely deferred until it cannot be.
--
-- TENANCY. One database, several front-ends. A luxury brand at
-- livfinder.com, a white-labelled site for a large developer, a
-- region-specific brand, a partner's embedded search. They share inventory and
-- infrastructure but differ in domain, theme, currency, language, category mix
-- and — critically — in which listings they may show. Retrofitting a tenant
-- dimension onto a live schema means touching every query in the system, so the
-- dimension exists from the outset even while only one brand uses it.
--
-- DATA GOVERNANCE. GDPR Article 30 requires a written record of processing
-- activities; Article 15 requires that a person can be told what is held about
-- them; Article 17 requires it can be erased. None of those is satisfiable by
-- inspecting code. They need a registry: which tables hold personal data, which
-- category, under which lawful basis, for how long, and who it is shared with.
-- `data_field_registry` is that registry, and `retention_policies` is what acts
-- on it.
--
-- Note what erasure means here. Financial records must be kept for tax purposes
-- for years after a person asks to be forgotten; a booking cannot be deleted
-- without destroying the ledger that balances against it. The resolution is
-- anonymisation with the transaction preserved, and `anonymization_rules`
-- encodes per field which of the two applies.
--
-- CHANGE HISTORY. `audit_logs` in 0013 records that something changed and holds
-- a JSON diff. That is right for an audit trail and wrong for the question
-- "show me every price change on this listing" — which needs a queryable,
-- indexed, per-field record. `field_change_log` is that, month-partitioned.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · TENANCY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- tenants
--
-- One brand or white-label front-end.
--
-- `is_default` marks the primary marketplace, which owns all inventory and is
-- what every existing query implicitly targets. A tenant with
-- `inventory_scope = 'shared'` shows the whole pool; one with 'own' shows only
-- listings from its own organisations. That distinction is the entire
-- commercial difference between a brand and a silo.
-- -----------------------------------------------------------------------------
CREATE TABLE tenants (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  legal_name     VARCHAR(200)    NULL,
  tenant_type    ENUM('primary','brand','white_label','partner','regional','embedded','staging') NOT NULL DEFAULT 'brand',
  parent_tenant_id INT UNSIGNED  NULL,
  -- Ownership, when the tenant belongs to a customer rather than to us.
  owner_organization_id BIGINT UNSIGNED NULL,
  owner_account_id BIGINT UNSIGNED NULL,
  -- Inventory scope. See the table comment.
  inventory_scope ENUM('shared','own','curated','partner_pool') NOT NULL DEFAULT 'shared',
  -- Market and presentation defaults.
  default_country_id BIGINT UNSIGNED NULL,
  default_language_id SMALLINT UNSIGNED NULL,
  default_currency_code CHAR(3)  NULL,
  supported_language_ids JSON    NULL,
  supported_currency_codes JSON  NULL,
  measurement_system ENUM('metric','imperial','both') NOT NULL DEFAULT 'metric',
  -- Which categories this brand sells. A watch-only white label should not
  -- render a bedrooms filter.
  enabled_category_ids JSON      NULL,
  -- Commercial arrangement for a white label.
  revenue_share_percent DECIMAL(6,3) NULL,
  contract_ends_on DATE          NULL,
  status         ENUM('provisioning','active','suspended','archived') NOT NULL DEFAULT 'provisioning',
  launched_at    DATETIME(3)     NULL,
  suspended_reason VARCHAR(300)  NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  -- Whether this brand's pages may be indexed. A staging or partner tenant
  -- serving the same inventory on a different domain is a duplicate-content
  -- problem the moment it is indexable; the SEO layer in 0017 reads this.
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenants_code (code),
  UNIQUE KEY uq_tenants_public (public_id),
  KEY ix_tenants_status (status, tenant_type),
  KEY ix_tenants_owner (owner_organization_id),
  CONSTRAINT fk_tenants_parent FOREIGN KEY (parent_tenant_id) REFERENCES tenants (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenants_org FOREIGN KEY (owner_organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenants_country FOREIGN KEY (default_country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenants_language FOREIGN KEY (default_language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- tenant_domains
--
-- Hostnames routed to a tenant. Several per tenant is normal — an apex, a www,
-- per-language domains, and a legacy domain kept alive for redirects — so the
-- canonical one is flagged and the rest redirect to it.
--
-- Certificate state lives here because an expiring certificate on a white-label
-- domain is an outage for that customer alone, which means nobody else notices
-- until they call.
-- -----------------------------------------------------------------------------
CREATE TABLE tenant_domains (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  tenant_id      INT UNSIGNED    NOT NULL,
  hostname       VARCHAR(191)    NOT NULL,
  is_canonical   TINYINT(1)      NOT NULL DEFAULT 0,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  -- A domain bound to one language serves that locale directly rather than
  -- through a path prefix, which is what hreflang in 0017 expects.
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  path_prefix    VARCHAR(60)     NULL,
  -- Redirect target when this domain is retired but still receiving traffic.
  redirects_to_domain_id INT UNSIGNED NULL,
  redirect_status SMALLINT UNSIGNED NULL,
  -- DNS and TLS state.
  dns_verified   TINYINT(1)      NOT NULL DEFAULT 0,
  dns_verified_at DATETIME(3)    NULL,
  verification_token VARCHAR(120) NULL,
  ssl_status     ENUM('none','pending','issued','expiring','expired','failed') NOT NULL DEFAULT 'none',
  ssl_issued_at  DATETIME(3)     NULL,
  ssl_expires_at DATETIME(3)     NULL,
  status         ENUM('pending','active','suspended','retired') NOT NULL DEFAULT 'pending',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenant_domains_hostname (hostname),
  KEY ix_tenant_domains_tenant (tenant_id, status, is_canonical),
  -- The certificate-expiry watch.
  KEY ix_tenant_domains_ssl (ssl_status, ssl_expires_at),
  CONSTRAINT fk_tenant_domains_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
  CONSTRAINT fk_tenant_domains_redirect FOREIGN KEY (redirects_to_domain_id) REFERENCES tenant_domains (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- tenant_settings
--
-- Per-tenant configuration as key/value rows rather than a hundred columns.
-- `settings` in 0001 is the platform-wide equivalent; this overrides it per
-- brand, and the resolution order is tenant → platform default.
--
-- Rows rather than one JSON blob because a single setting must be readable and
-- writable without rewriting the whole document, and because `is_public`
-- controls what may be shipped to the browser — a secret in a settings blob
-- that gets serialised into a page is a real and common leak.
-- -----------------------------------------------------------------------------
CREATE TABLE tenant_settings (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  tenant_id      INT UNSIGNED    NOT NULL,
  setting_group  ENUM('branding','theme','seo','contact','legal','features','integrations','email','search','listing','commerce','analytics') NOT NULL DEFAULT 'branding',
  setting_key    VARCHAR(120)    NOT NULL,
  setting_value  TEXT            NULL,
  value_type     ENUM('string','integer','decimal','boolean','json','url','colour','html') NOT NULL DEFAULT 'string',
  -- Whether this value may be exposed to the client. See the table comment.
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  is_overridden  TINYINT(1)      NOT NULL DEFAULT 1,
  updated_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenant_setting (tenant_id, setting_key),
  KEY ix_tenant_settings_group (tenant_id, setting_group, is_public),
  CONSTRAINT fk_tenant_settings_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- tenant_visibility_rules
--
-- Which inventory a non-primary tenant may show.
--
-- Rules rather than a membership table because the useful statements are broad:
-- "everything above 10M", "only these three developers", "nothing in this
-- country". Materialising those as per-listing rows would mean re-deriving
-- millions of rows every time a price changes.
-- -----------------------------------------------------------------------------
CREATE TABLE tenant_visibility_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  tenant_id      INT UNSIGNED    NOT NULL,
  rule_type      ENUM('include','exclude') NOT NULL DEFAULT 'include',
  dimension      ENUM('organization','agent','category','purpose','location','country','price_band','project','brand','attribute','promotion','all') NOT NULL,
  value_ids      JSON            NULL,
  min_price_base DECIMAL(18,2)   NULL,
  max_price_base DECIMAL(18,2)   NULL,
  attribute_code VARCHAR(60)     NULL,
  attribute_value VARCHAR(200)   NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  notes          VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_tenant_visibility (tenant_id, is_active, priority),
  CONSTRAINT fk_tenant_visibility_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- tenant_daily_stats
--
-- Traffic and revenue per brand per day. A white-label contract with a revenue
-- share is unsettleable without it, and "how is the partner site doing" is
-- otherwise a question nobody can answer.
-- -----------------------------------------------------------------------------
CREATE TABLE tenant_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  tenant_id      INT UNSIGNED    NOT NULL,
  sessions       INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_visitors INT UNSIGNED   NOT NULL DEFAULT 0,
  page_views     INT UNSIGNED    NOT NULL DEFAULT 0,
  searches       INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  calls          INT UNSIGNED    NOT NULL DEFAULT 0,
  signups        INT UNSIGNED    NOT NULL DEFAULT 0,
  visible_listings INT UNSIGNED  NOT NULL DEFAULT 0,
  gross_revenue  DECIMAL(16,2)   NOT NULL DEFAULT 0,
  revenue_share  DECIMAL(16,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenant_daily (stat_date, tenant_id),
  KEY ix_tenant_daily_tenant (tenant_id, stat_date),
  CONSTRAINT fk_tenant_daily_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · DATA GOVERNANCE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- data_field_registry
--
-- Which column in which table holds what kind of personal data, under what
-- lawful basis, for how long.
--
-- This is the table that makes every other privacy obligation mechanical rather
-- than archaeological. A subject-access request becomes a query over this
-- registry; an erasure becomes a walk of it; a retention run becomes an
-- iteration of it. Without it, each of those is a developer reading code and
-- hoping they found everything — and they never do, because the field they miss
-- is always the one in the table somebody added last quarter.
-- -----------------------------------------------------------------------------
CREATE TABLE data_field_registry (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  table_name     VARCHAR(64)     NOT NULL,
  column_name    VARCHAR(64)     NOT NULL,
  -- Classification.
  data_class     ENUM('public','internal','confidential','restricted') NOT NULL DEFAULT 'internal',
  is_personal_data TINYINT(1)    NOT NULL DEFAULT 0,
  -- Article 9 special categories carry stricter rules. Passport nationality
  -- and biometric liveness checks both land here.
  is_special_category TINYINT(1) NOT NULL DEFAULT 0,
  pii_type       ENUM('name','email','phone','address','national_id','passport','date_of_birth','financial','biometric','location','ip_address','device_id','photo','signature','health','other') NULL,
  -- Lawful basis, per GDPR Article 6. Recorded per field because the same
  -- record can hold data collected under different bases.
  lawful_basis   ENUM('consent','contract','legal_obligation','vital_interests','public_task','legitimate_interests','not_applicable') NOT NULL DEFAULT 'not_applicable',
  purpose        VARCHAR(300)    NULL,
  -- What happens on erasure. See the migration header on why deletion is often
  -- the wrong answer.
  erasure_action ENUM('delete_row','null_field','anonymize','pseudonymize','hash','retain_legal_obligation','no_action') NOT NULL DEFAULT 'no_action',
  anonymization_rule_id INT UNSIGNED NULL,
  -- Retention, in days from the record's own anchor date.
  retention_days INT UNSIGNED    NULL,
  retention_anchor VARCHAR(64)   NULL,
  retention_basis VARCHAR(300)   NULL,
  -- Whether it must appear in a subject-access export.
  include_in_export TINYINT(1)   NOT NULL DEFAULT 0,
  export_label   VARCHAR(160)    NULL,
  -- Storage protections expected on this field.
  is_encrypted   TINYINT(1)      NOT NULL DEFAULT 0,
  is_masked_in_logs TINYINT(1)   NOT NULL DEFAULT 0,
  shared_with_processors JSON    NULL,
  reviewed_at    DATETIME(3)     NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_data_field (table_name, column_name),
  KEY ix_data_field_personal (is_personal_data, data_class),
  KEY ix_data_field_erasure (erasure_action, is_personal_data),
  KEY ix_data_field_retention (retention_days)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- anonymization_rules
--
-- How to make a field non-identifying while keeping the row useful. A deleted
-- inquiry breaks the counters it feeds; an inquiry whose name becomes
-- "Redacted" and whose email becomes a stable hash keeps every aggregate intact
-- and identifies nobody.
--
-- `preserves_uniqueness` matters: replacing every email with the same constant
-- collapses distinct-user counts, so a deterministic hash is used where a
-- distinct count depends on it.
-- -----------------------------------------------------------------------------
CREATE TABLE anonymization_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  strategy       ENUM('constant','deterministic_hash','random_token','partial_mask','generalize','date_shift','nullify','tokenize','truncate') NOT NULL,
  replacement_value VARCHAR(255) NULL,
  -- e.g. keep the last 4 of a phone, or the domain of an email.
  keep_prefix_chars TINYINT UNSIGNED NULL,
  keep_suffix_chars TINYINT UNSIGNED NULL,
  -- Generalisation: a date of birth becomes a year, a coordinate becomes a
  -- community centroid.
  generalize_to  VARCHAR(60)     NULL,
  preserves_uniqueness TINYINT(1) NOT NULL DEFAULT 0,
  preserves_format TINYINT(1)    NOT NULL DEFAULT 0,
  -- Whether the original can ever be recovered. Pseudonymisation is reversible
  -- and is therefore still personal data; anonymisation is not and is not.
  is_reversible  TINYINT(1)      NOT NULL DEFAULT 0,
  description    VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_anonymization_rules_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE data_field_registry
  ADD CONSTRAINT fk_data_field_anon_rule FOREIGN KEY (anonymization_rule_id)
      REFERENCES anonymization_rules (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- processing_activities
--
-- The Article 30 record: for each thing we do with personal data, why, on what
-- basis, whose data, who we share it with, where it goes and how long we keep
-- it. Regulators ask for this document by name, and maintaining it as a table
-- rather than a spreadsheet is what keeps it true.
-- -----------------------------------------------------------------------------
CREATE TABLE processing_activities (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    TEXT            NULL,
  -- Are we deciding why and how (controller), or acting for someone else
  -- (processor)? The obligations differ substantially.
  role           ENUM('controller','processor','joint_controller') NOT NULL DEFAULT 'controller',
  purpose        VARCHAR(500)    NOT NULL,
  lawful_basis   ENUM('consent','contract','legal_obligation','vital_interests','public_task','legitimate_interests') NOT NULL,
  -- Required where the basis is legitimate interests: the balancing test.
  legitimate_interest_assessment TEXT NULL,
  data_subject_categories JSON   NULL,
  data_categories JSON           NULL,
  special_categories JSON        NULL,
  recipient_categories JSON      NULL,
  -- Cross-border transfers and their safeguard.
  transfers_outside_region TINYINT(1) NOT NULL DEFAULT 0,
  transfer_countries JSON        NULL,
  transfer_safeguard ENUM('adequacy','sccs','bcrs','derogation','none') NULL,
  retention_summary VARCHAR(500) NULL,
  security_measures TEXT         NULL,
  -- A DPIA is mandatory for high-risk processing; recording whether one was
  -- done and when is itself an obligation.
  dpia_required  TINYINT(1)      NOT NULL DEFAULT 0,
  dpia_completed_at DATE         NULL,
  dpia_document_id BIGINT UNSIGNED NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  last_reviewed_at DATE          NULL,
  next_review_due DATE           NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_processing_activities_code (code),
  KEY ix_processing_activities_review (is_active, next_review_due)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- data_processors
--
-- Every third party that touches personal data on our behalf, with the state of
-- the contract that permits it. A sub-processor without a signed agreement is a
-- breach of Article 28 regardless of how well the integration works.
-- -----------------------------------------------------------------------------
CREATE TABLE data_processors (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  processor_type ENUM('infrastructure','analytics','payment','messaging','crm','support','identity','storage','ai_service','marketing','other') NOT NULL DEFAULT 'other',
  service_description VARCHAR(500) NULL,
  data_categories JSON           NULL,
  -- Where the data physically sits, which decides which transfer rules apply.
  hosting_country_id BIGINT UNSIGNED NULL,
  processing_countries JSON      NULL,
  -- Contractual position.
  dpa_signed     TINYINT(1)      NOT NULL DEFAULT 0,
  dpa_signed_at  DATE            NULL,
  dpa_document_id BIGINT UNSIGNED NULL,
  sccs_in_place  TINYINT(1)      NOT NULL DEFAULT 0,
  sub_processors_permitted TINYINT(1) NOT NULL DEFAULT 0,
  -- Assurance.
  certifications JSON            NULL,
  last_audit_at  DATE            NULL,
  next_audit_due DATE            NULL,
  risk_rating    ENUM('low','medium','high') NOT NULL DEFAULT 'medium',
  breach_notification_hours SMALLINT UNSIGNED NULL,
  status         ENUM('proposed','approved','active','under_review','terminated') NOT NULL DEFAULT 'proposed',
  terminated_at  DATE            NULL,
  data_deletion_confirmed_at DATE NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_data_processors_code (code),
  KEY ix_data_processors_status (status, risk_rating),
  KEY ix_data_processors_audit (status, next_audit_due),
  CONSTRAINT fk_data_processors_country FOREIGN KEY (hosting_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- retention_policies / retention_runs
--
-- What gets deleted or anonymised, when, and the evidence that it happened.
--
-- `dry_run` is not a convenience. A retention job with a wrong anchor date
-- deletes live data irreversibly, so every policy is expected to run in dry-run
-- first and the affected count is recorded before anything is touched.
-- -----------------------------------------------------------------------------
CREATE TABLE retention_policies (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  table_name     VARCHAR(64)     NOT NULL,
  -- The column whose age decides eligibility, and any additional filter.
  anchor_column  VARCHAR(64)     NOT NULL,
  filter_condition VARCHAR(500)  NULL,
  retention_days INT UNSIGNED    NOT NULL,
  action         ENUM('delete','anonymize','archive','drop_partition','null_fields') NOT NULL DEFAULT 'delete',
  affected_columns JSON          NULL,
  legal_basis    VARCHAR(300)    NULL,
  -- Safety.
  max_rows_per_run INT UNSIGNED  NOT NULL DEFAULT 10000,
  requires_approval TINYINT(1)   NOT NULL DEFAULT 0,
  is_dry_run_only TINYINT(1)     NOT NULL DEFAULT 1,
  schedule_cron  VARCHAR(60)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 0,
  last_run_at    DATETIME(3)     NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_retention_policies_code (code),
  KEY ix_retention_policies_active (is_active, last_run_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE retention_runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  policy_id      INT UNSIGNED    NOT NULL,
  was_dry_run    TINYINT(1)      NOT NULL DEFAULT 1,
  status         ENUM('running','completed','failed','cancelled','blocked_by_hold') NOT NULL DEFAULT 'running',
  cutoff_date    DATETIME(3)     NULL,
  eligible_rows  INT UNSIGNED    NOT NULL DEFAULT 0,
  affected_rows  INT UNSIGNED    NOT NULL DEFAULT 0,
  skipped_rows   INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Rows a legal hold protected from deletion. See legal_holds below.
  held_rows      INT UNSIGNED    NOT NULL DEFAULT 0,
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finished_at    DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  error_message  VARCHAR(1000)   NULL,
  triggered_by_user_id BIGINT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_retention_runs_policy (policy_id, started_at),
  KEY ix_retention_runs_status (status, started_at),
  CONSTRAINT fk_retention_runs_policy FOREIGN KEY (policy_id) REFERENCES retention_policies (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- legal_holds
--
-- A suspension of deletion. When litigation, an investigation or a regulatory
-- enquiry is reasonably anticipated, destroying relevant records — even on a
-- lawful retention schedule, even in response to an erasure request — is
-- spoliation.
--
-- Every retention run and every erasure must consult this table first, and the
-- checked-against evidence is why `retention_runs.held_rows` exists.
-- -----------------------------------------------------------------------------
CREATE TABLE legal_holds (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    TEXT            NULL,
  hold_type      ENUM('litigation','regulatory','investigation','audit','dispute','tax','other') NOT NULL DEFAULT 'litigation',
  -- Scope. A hold can name specific subjects or a whole class of records.
  subject_type   ENUM('user','account','organization','listing','deal','payment','contract','all') NULL,
  subject_ids    JSON            NULL,
  affected_tables JSON           NULL,
  date_range_start DATE          NULL,
  date_range_end DATE            NULL,
  status         ENUM('active','released','expired') NOT NULL DEFAULT 'active',
  issued_by_user_id BIGINT UNSIGNED NULL,
  issued_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expected_release_date DATE     NULL,
  released_at    DATETIME(3)     NULL,
  released_by_user_id BIGINT UNSIGNED NULL,
  release_reason VARCHAR(500)    NULL,
  legal_reference VARCHAR(200)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_legal_holds_public (public_id),
  UNIQUE KEY uq_legal_holds_reference (reference),
  -- Consulted before every deletion, so it must be a fast lookup.
  KEY ix_legal_holds_active (status, subject_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- erasure_records
--
-- Proof that an erasure happened, kept after the data is gone.
--
-- This is not a contradiction. What is retained is a record *that* data
-- concerning a pseudonymous subject reference was erased, when, and under what
-- request — with no personal data in it. Without that, the platform cannot
-- demonstrate compliance, and cannot detect a system that later re-imports the
-- same person from a backup or a portal feed.
-- -----------------------------------------------------------------------------
CREATE TABLE erasure_records (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  request_id     BIGINT UNSIGNED NULL,
  -- A one-way hash of the identifier, so a re-import can be detected without
  -- storing the identifier itself.
  subject_hash   CHAR(64)        NOT NULL,
  subject_type   ENUM('user','contact','lead','account','visitor') NOT NULL DEFAULT 'user',
  erasure_type   ENUM('full_deletion','anonymization','pseudonymization','partial') NOT NULL DEFAULT 'anonymization',
  tables_affected JSON           NULL,
  rows_deleted   INT UNSIGNED    NOT NULL DEFAULT 0,
  rows_anonymized INT UNSIGNED   NOT NULL DEFAULT 0,
  -- What was kept and why. "We deleted everything except your invoices,
  -- because tax law requires them for seven years" is the honest answer and it
  -- must be recorded.
  retained_tables JSON           NULL,
  retention_justification VARCHAR(1000) NULL,
  -- Downstream propagation. Erasure is not complete while a processor still
  -- holds a copy.
  processors_notified JSON       NULL,
  processors_confirmed_at DATETIME(3) NULL,
  backups_scheduled_for DATE     NULL,
  performed_by_user_id BIGINT UNSIGNED NULL,
  performed_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  verification_hash CHAR(64)     NULL,
  PRIMARY KEY (id),
  KEY ix_erasure_records_subject (subject_hash),
  KEY ix_erasure_records_request (request_id),
  KEY ix_erasure_records_date (performed_at),
  CONSTRAINT fk_erasure_records_request FOREIGN KEY (request_id) REFERENCES data_subject_requests (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- consent_purposes / consent_receipts
--
-- `user_consents` in 0011 records that a user agreed to something. That is
-- sufficient until a regulator asks what exactly they were shown, in which
-- language, on which version of the notice — at which point a boolean is not
-- evidence.
--
-- A receipt is an immutable snapshot of one consent event: the wording, the
-- version, the mechanism, the timestamp. Consent that cannot be evidenced is
-- consent that does not exist.
-- -----------------------------------------------------------------------------
CREATE TABLE consent_purposes (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  purpose_type   ENUM('marketing_email','marketing_sms','marketing_whatsapp','profiling','analytics','advertising','third_party_sharing','cookies_functional','cookies_analytics','cookies_marketing','terms','privacy_policy','data_processing') NOT NULL,
  -- Whether the service can be provided without it. Bundling non-essential
  -- consent into a service requirement is precisely what invalidates it.
  is_required    TINYINT(1)      NOT NULL DEFAULT 0,
  -- Pre-ticked boxes are not consent. Recorded so the UI cannot quietly
  -- default one to on.
  default_state  ENUM('opt_in','opt_out','unset') NOT NULL DEFAULT 'unset',
  processing_activity_id INT UNSIGNED NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  effective_from DATE            NULL,
  expires_after_months SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_consent_purposes (code, version),
  KEY ix_consent_purposes_active (is_active, purpose_type),
  CONSTRAINT fk_consent_purposes_activity FOREIGN KEY (processing_activity_id) REFERENCES processing_activities (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE consent_receipts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  purpose_id     INT UNSIGNED    NOT NULL,
  purpose_version SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  subject_identifier VARCHAR(255) NULL,
  action         ENUM('granted','withdrawn','updated','expired','refreshed') NOT NULL,
  -- The immutable snapshot. See the table comment.
  notice_text    TEXT            NULL,
  notice_version VARCHAR(40)     NULL,
  notice_url     VARCHAR(500)    NULL,
  language_id    SMALLINT UNSIGNED NULL,
  -- How it was given, which decides how strong the evidence is.
  mechanism      ENUM('checkbox','toggle','button_click','api','import','verbal','written','double_opt_in','implied') NOT NULL DEFAULT 'checkbox',
  double_opt_in_confirmed_at DATETIME(3) NULL,
  -- Circumstantial evidence.
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(300)    NULL,
  page_url       VARCHAR(500)    NULL,
  tenant_id      INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NULL,
  granted_at     DATETIME(3)     NULL,
  withdrawn_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_consent_receipts_public (public_id),
  -- "What is this person's current consent state" and "prove it".
  KEY ix_consent_receipts_user (user_id, purpose_id, created_at),
  KEY ix_consent_receipts_contact (contact_id, purpose_id, created_at),
  KEY ix_consent_receipts_visitor (visitor_id, purpose_id),
  KEY ix_consent_receipts_expiry (expires_at),
  CONSTRAINT fk_consent_receipts_purpose FOREIGN KEY (purpose_id) REFERENCES consent_purposes (id),
  CONSTRAINT fk_consent_receipts_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_consent_receipts_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE CASCADE,
  CONSTRAINT fk_consent_receipts_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 3 · FIELD-LEVEL CHANGE HISTORY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- field_change_log
--
-- One row per field per change, month-partitioned.
--
-- `audit_logs` in 0013 answers "what did this user do" and holds a JSON diff.
-- This answers the other question — "what happened to this field" — which a
-- JSON diff cannot serve without scanning every audit row and parsing it.
--
-- The two coexist deliberately: the audit log is actor-centric and complete;
-- this is entity-centric and selective. Only fields marked `track_changes` in
-- `data_field_registry` are written here, because logging every field of every
-- write would be larger than the database it describes.
--
-- Price history is the obvious case — `listing_price_history` in 0007 exists
-- precisely because that one field needed this treatment before this table
-- existed, and it stays because the price chart on a listing page should not
-- query a partitioned log.
-- -----------------------------------------------------------------------------
CREATE TABLE field_change_log (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  entity_type    VARCHAR(60)     NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  field_name     VARCHAR(64)     NOT NULL,
  -- Values as text, truncated. A change log is for seeing what changed, not for
  -- storing a second copy of the database — long text fields record that they
  -- changed and by how much, not their full before and after.
  old_value      VARCHAR(1000)   NULL,
  new_value      VARCHAR(1000)   NULL,
  value_truncated TINYINT(1)     NOT NULL DEFAULT 0,
  -- Numeric deltas, populated for numeric fields so "price reductions over 10%"
  -- is an indexed range rather than a cast over text.
  old_numeric    DECIMAL(20,4)   NULL,
  new_numeric    DECIMAL(20,4)   NULL,
  delta_numeric  DECIMAL(20,4)   NULL,
  delta_percent  DECIMAL(10,4)   NULL,
  change_type    ENUM('create','update','delete','restore','bulk_update','import','system') NOT NULL DEFAULT 'update',
  -- Attribution.
  actor_type     ENUM('user','system','import','api','automation','admin','integration') NOT NULL DEFAULT 'user',
  actor_user_id  BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  source         VARCHAR(60)     NULL,
  request_id     CHAR(32)        CHARACTER SET ascii NULL,
  correlation_id CHAR(32)        CHARACTER SET ascii NULL,
  PRIMARY KEY (id, occurred_at),
  -- The entity timeline, which is the reason this table exists.
  KEY ix_field_changes_entity (entity_type, entity_id, occurred_at),
  KEY ix_field_changes_field (entity_type, field_name, occurred_at),
  KEY ix_field_changes_actor (actor_user_id, occurred_at),
  KEY ix_field_changes_org (organization_id, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p2027_01 VALUES LESS THAN (TO_DAYS('2027-02-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- entity_snapshots
--
-- A full copy of a row at a moment that mattered: when a listing was published,
-- when a contract was executed, when a deal completed, when an approval was
-- given.
--
-- Reconstructing state by replaying a change log works in theory and fails in
-- practice — the log starts after the row was created, fields get added,
-- retention prunes the early entries. A snapshot at the moments that carry
-- legal or commercial weight is cheap and unambiguous.
-- -----------------------------------------------------------------------------
CREATE TABLE entity_snapshots (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entity_type    VARCHAR(60)     NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  snapshot_reason ENUM('created','published','approved','executed','completed','suspended','deleted','pre_migration','pre_bulk_update','dispute','legal_hold','manual') NOT NULL,
  -- The row, and any child rows that are part of its meaning.
  payload        JSON            NOT NULL,
  related_payload JSON           NULL,
  content_hash   CHAR(64)        NULL,
  schema_version VARCHAR(20)     NULL,
  -- What caused the snapshot, so it can be tied to the workflow, contract or
  -- incident it belongs to.
  trigger_type   ENUM('workflow','contract','deal','incident','retention','migration','manual','system') NULL,
  trigger_id     BIGINT UNSIGNED NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- Snapshots taken for legal reasons outlive ordinary retention.
  retain_until   DATE            NULL,
  is_legal_record TINYINT(1)     NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_entity_snapshots_entity (entity_type, entity_id, created_at),
  KEY ix_entity_snapshots_reason (snapshot_reason, created_at),
  KEY ix_entity_snapshots_trigger (trigger_type, trigger_id),
  KEY ix_entity_snapshots_retention (is_legal_record, retain_until)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0027', 'tenancy_and_governance');
