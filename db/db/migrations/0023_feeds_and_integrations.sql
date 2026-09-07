-- =============================================================================
-- Liv Finder — 0023 · Feeds, syndication and integrations
-- =============================================================================
-- No marketplace is an island. Inventory arrives from somewhere and is pushed
-- somewhere else, and for most agencies this platform is one of five places
-- their listings live simultaneously.
--
-- INBOUND. Agencies do not retype their stock. They run Reapit, PropSpace,
-- MasterKey, Salesforce or a spreadsheet, and they expect to point a feed at us
-- and see their properties appear. Every one of those feeds has different field
-- names, different property-type vocabulary, different units, different image
-- conventions and at least one field that is a lie.
--
-- OUTBOUND. The same listings syndicate to Property Finder, Bayut, Dubizzle,
-- JamesEdition, Rightmove, Zillow, Idealista, YachtWorld and Chrono24. Each
-- wants a different schema, enforces a different quota, and rejects rows for
-- reasons that must get back to the agency in a form they can act on.
--
-- The design commitments here:
--
-- MAPPINGS ARE DATA. `feed_field_mappings` and `feed_value_mappings` mean
-- onboarding a new partner is configuration, not a release. A platform that
-- needs a deploy per portal integration stops adding portals.
--
-- EVERY ROW'S FATE IS RECORDED. `feed_import_items` and `feed_export_items`
-- hold per-listing outcomes with the reason. "The feed ran" is not an answer to
-- "why is my villa not on Bayut" — this is.
--
-- IDENTITY IS MAPPED BOTH WAYS. `external_references` is the correspondence
-- between our ids and theirs. Without it, the second run of any feed creates
-- duplicates, which is the single most common integration failure.
--
-- CREDENTIALS ARE REFERENCED, NEVER STORED. `integration_connections` holds a
-- pointer into a secrets manager plus non-secret metadata. A schema that holds
-- a partner's API key in a VARCHAR turns one database leak into a breach of
-- every connected system.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · PARTNERS AND CONNECTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- integration_providers
--
-- The catalogue of systems we can talk to, inbound or outbound. Kept as data so
-- the admin can show what is available and what each one needs, and so a
-- provider can be disabled globally when its API is down without editing every
-- connection.
-- -----------------------------------------------------------------------------
CREATE TABLE integration_providers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  provider_kind  ENUM('portal','crm','erp','mls','developer','photography','signature','accounting','messaging','maps','valuation','analytics','payment','storage','other') NOT NULL DEFAULT 'portal',
  direction      ENUM('inbound','outbound','bidirectional') NOT NULL DEFAULT 'outbound',
  -- What the wire actually looks like. `format` and `transport` together are
  -- enough for the runner to pick a driver.
  transport      ENUM('http_api','ftp','sftp','s3','email','webhook','manual_upload','scrape') NOT NULL DEFAULT 'http_api',
  format         ENUM('xml','json','csv','tsv','excel','rets','fixed_width','graphql') NOT NULL DEFAULT 'xml',
  auth_type      ENUM('none','api_key','basic','oauth2','jwt','hmac','ftp_credentials','mtls') NOT NULL DEFAULT 'api_key',
  base_url       VARCHAR(500)    NULL,
  docs_url       VARCHAR(500)    NULL,
  -- Which asset classes this provider is relevant to. JamesEdition takes all
  -- six; Rightmove takes property only; Chrono24 takes watches only.
  supported_categories JSON      NULL,
  supported_countries JSON       NULL,
  -- Operational limits, so the runner paces itself rather than being rate
  -- limited into a backoff spiral.
  rate_limit_per_minute SMALLINT UNSIGNED NULL,
  max_batch_size SMALLINT UNSIGNED NULL,
  min_interval_minutes SMALLINT UNSIGNED NULL,
  -- Whether the provider sends leads back to us. Portals that do are worth far
  -- more than portals that do not, and the difference belongs in the data.
  returns_leads  TINYINT(1)      NOT NULL DEFAULT 0,
  returns_stats  TINYINT(1)      NOT NULL DEFAULT 0,
  logo_url       VARCHAR(500)    NULL,
  status         ENUM('available','beta','deprecated','disabled') NOT NULL DEFAULT 'available',
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_integration_providers_code (code),
  KEY ix_integration_providers_kind (provider_kind, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- integration_connections
--
-- One organisation's link to one provider.
--
-- Note what is absent: there is no column holding a password, token or private
-- key. `credential_ref` names a secret in the platform's secrets manager and
-- `credential_fingerprint` is a hash for change detection. A schema that stores
-- the key itself turns a single dump of this table into a compromise of every
-- connected agency's portal account.
-- -----------------------------------------------------------------------------
CREATE TABLE integration_connections (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  direction      ENUM('inbound','outbound','bidirectional') NOT NULL DEFAULT 'outbound',
  -- Secret handling. See the table comment.
  credential_ref VARCHAR(255)    NULL,
  credential_fingerprint CHAR(64) NULL,
  credential_expires_at DATETIME(3) NULL,
  -- Non-secret connection detail: the account id at the far end, the FTP path,
  -- the branch code the portal knows us by.
  external_account_id VARCHAR(160) NULL,
  endpoint_url   VARCHAR(500)    NULL,
  remote_path    VARCHAR(500)    NULL,
  settings       JSON            NULL,
  status         ENUM('pending','connected','error','expired','revoked','disabled') NOT NULL DEFAULT 'pending',
  last_connected_at DATETIME(3)  NULL,
  last_error     VARCHAR(500)    NULL,
  last_error_at  DATETIME(3)     NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Scheduling.
  is_enabled     TINYINT(1)      NOT NULL DEFAULT 1,
  schedule_cron  VARCHAR(60)     NULL,
  next_run_at    DATETIME(3)     NULL,
  last_run_at    DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_integration_connections_public (public_id),
  UNIQUE KEY uq_integration_connection (provider_id, organization_id, direction),
  -- The scheduler's query.
  KEY ix_connections_due (is_enabled, status, next_run_at),
  KEY ix_connections_org (organization_id, status),
  KEY ix_connections_failing (consecutive_failures, status),
  CONSTRAINT fk_connections_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_connections_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_connections_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- external_references
--
-- The two-way identity map. Our listing 8842 is Bayut's "BY-4471991" and
-- Property Finder's "pf-listing-90210", and every subsequent sync must find
-- that correspondence or it will create a duplicate.
--
-- Deliberately generic across entity kinds, because the same problem exists for
-- agents, branches and projects, and three near-identical tables would drift.
-- -----------------------------------------------------------------------------
CREATE TABLE external_references (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provider_id    INT UNSIGNED    NOT NULL,
  connection_id  INT UNSIGNED    NULL,
  entity_type    ENUM('listing','project','agent','organization','branch','contact','lead','deal','media','category','location','brand') NOT NULL,
  entity_id      BIGINT UNSIGNED NOT NULL,
  external_id    VARCHAR(191)    NOT NULL,
  external_url   VARCHAR(500)    NULL,
  -- Live state at the far end, so "is it actually on Bayut right now" is a
  -- column read rather than an API call.
  remote_status  ENUM('unknown','live','pending','rejected','removed','expired','archived') NOT NULL DEFAULT 'unknown',
  remote_status_detail VARCHAR(500) NULL,
  -- Hash of the payload last sent, so an unchanged listing is skipped instead
  -- of re-pushed. On a 20,000-listing feed this is the difference between a
  -- two-minute run and a two-hour one.
  payload_hash   CHAR(32)        CHARACTER SET ascii NULL,
  first_synced_at DATETIME(3)    NULL,
  last_synced_at DATETIME(3)     NULL,
  last_success_at DATETIME(3)    NULL,
  sync_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  error_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- Both directions must be unique: one of ours maps to one of theirs per
  -- connection, and one of theirs maps back to exactly one of ours.
  UNIQUE KEY uq_external_ref_ours (provider_id, connection_id, entity_type, entity_id),
  UNIQUE KEY uq_external_ref_theirs (provider_id, connection_id, entity_type, external_id),
  KEY ix_external_refs_entity (entity_type, entity_id),
  KEY ix_external_refs_status (provider_id, remote_status),
  CONSTRAINT fk_external_refs_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_external_refs_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · MAPPINGS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- feed_field_mappings
--
-- How one field on one side becomes a field on the other. `transform` covers
-- the mechanical differences — units, dates, currency, HTML stripping — and
-- `transform_config` parameterises it.
--
-- `is_required` and `default_value` matter because most portal rejections are
-- a missing mandatory field, and it is far better to fail validation locally
-- with a clear message than to be rejected remotely with "error 4021".
-- -----------------------------------------------------------------------------
CREATE TABLE feed_field_mappings (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  provider_id    INT UNSIGNED    NOT NULL,
  connection_id  INT UNSIGNED    NULL,
  entity_type    ENUM('listing','project','agent','organization','branch','media','lead') NOT NULL DEFAULT 'listing',
  direction      ENUM('inbound','outbound') NOT NULL DEFAULT 'outbound',
  -- Our side. A dotted path so nested detail tables and attributes are
  -- reachable: "listing.price", "real_estate.bedrooms", "attribute.hull_material".
  internal_path  VARCHAR(160)    NOT NULL,
  -- Their side. An XPath, a JSON pointer or a column header depending on the
  -- provider's format.
  external_path  VARCHAR(255)    NOT NULL,
  transform      ENUM('none','uppercase','lowercase','title_case','strip_html','truncate','date_format','number_format','currency_convert','unit_convert','concat','split','lookup','constant','template','boolean_map','round') NOT NULL DEFAULT 'none',
  transform_config JSON          NULL,
  is_required    TINYINT(1)      NOT NULL DEFAULT 0,
  default_value  VARCHAR(500)    NULL,
  max_length     SMALLINT UNSIGNED NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  notes          VARCHAR(400)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_field_mapping (provider_id, connection_id, entity_type, direction, external_path),
  KEY ix_field_mappings_provider (provider_id, entity_type, direction, sort_order),
  CONSTRAINT fk_field_mappings_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_field_mappings_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- feed_value_mappings
--
-- Vocabulary translation. Our category "Apartment" is Rightmove's "Flat" and
-- Bayut's "RES-APT"; our location tree has to reach their proprietary area ids;
-- our features map onto their amenity codes.
--
-- Unmapped values are the commonest silent data-loss bug in syndication, so
-- `is_unmapped` marks a value seen on the wire that we have no rule for, and
-- the operations screen lists them. Seen-but-unmapped is a work queue, not an
-- error to swallow.
-- -----------------------------------------------------------------------------
CREATE TABLE feed_value_mappings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provider_id    INT UNSIGNED    NOT NULL,
  connection_id  INT UNSIGNED    NULL,
  mapping_type   ENUM('category','purpose','location','feature','amenity','condition','furnishing','completion','currency','unit','media_type','agent','status','custom') NOT NULL,
  direction      ENUM('inbound','outbound','both') NOT NULL DEFAULT 'both',
  -- Our value, as an id where the concept has one and as text otherwise.
  internal_id    BIGINT UNSIGNED NULL,
  internal_value VARCHAR(191)    NULL,
  -- Their value.
  external_value VARCHAR(191)    NOT NULL,
  external_label VARCHAR(255)    NULL,
  -- Parent context, because portal area codes are frequently only unique
  -- within a city, and property types only within a purpose.
  scope_key      VARCHAR(120)    NULL,
  is_unmapped    TINYINT(1)      NOT NULL DEFAULT 0,
  seen_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  last_seen_at   DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_value_mapping (provider_id, connection_id, mapping_type, external_value, scope_key),
  KEY ix_value_mappings_internal (provider_id, mapping_type, internal_id),
  -- The unmapped work queue.
  KEY ix_value_mappings_unmapped (is_unmapped, provider_id, seen_count),
  CONSTRAINT fk_value_mappings_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_value_mappings_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- feed_validation_rules
--
-- What a portal will reject, encoded so we can fail locally with a message the
-- agency can act on. "Bayut requires at least four images and a Trakheesi
-- permit number" is a rule, and enforcing it before the push saves a rejection
-- round trip measured in hours.
-- -----------------------------------------------------------------------------
CREATE TABLE feed_validation_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  provider_id    INT UNSIGNED    NOT NULL,
  entity_type    ENUM('listing','project','agent','organization','media') NOT NULL DEFAULT 'listing',
  field_path     VARCHAR(160)    NOT NULL,
  rule_type      ENUM('required','min_length','max_length','min_value','max_value','regex','enum','min_count','max_count','image_dimensions','no_contact_details','no_html','required_if') NOT NULL,
  rule_value     VARCHAR(500)    NULL,
  condition_path VARCHAR(160)    NULL,
  condition_value VARCHAR(200)   NULL,
  severity       ENUM('error','warning','info') NOT NULL DEFAULT 'error',
  -- The text the agency sees. Written for them, not for a developer.
  message        VARCHAR(500)    NOT NULL,
  help_url       VARCHAR(500)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_validation_rules_provider (provider_id, entity_type, is_active),
  CONSTRAINT fk_validation_rules_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · OUTBOUND SYNDICATION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- syndication_channels
--
-- One organisation publishing to one portal, with the commercial reality
-- attached: the quota their contract allows and how much of it is used.
--
-- Portal contracts are quota-based almost universally — "120 listings, 10
-- featured" — and a channel that pushes past the quota gets the whole feed
-- rejected. `quota_used` is derived from live syndicated listings, not
-- incremented, for the usual reason.
-- -----------------------------------------------------------------------------
CREATE TABLE syndication_channels (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  connection_id  INT UNSIGNED    NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  -- Contract.
  listing_quota  SMALLINT UNSIGNED NULL,
  quota_used     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  featured_quota SMALLINT UNSIGNED NULL,
  featured_used  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  contract_starts_at DATE        NULL,
  contract_ends_at DATE          NULL,
  monthly_cost   DECIMAL(12,2)   NULL,
  currency_code  CHAR(3)         NULL,
  -- Selection. `auto_publish` sends everything eligible; otherwise an agent
  -- opts each listing in.
  auto_publish   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Eligibility filter, so a channel can carry only what it should: minimum
  -- price for JamesEdition, one category for Chrono24, one country for
  -- Rightmove.
  min_price_base DECIMAL(18,2)   NULL,
  allowed_category_ids JSON      NULL,
  allowed_location_ids JSON      NULL,
  allowed_purpose_ids JSON       NULL,
  exclude_exclusive TINYINT(1)   NOT NULL DEFAULT 0,
  -- Whether the portal's price and description may differ from ours. Some
  -- agencies deliberately publish a different price externally; the platform
  -- should know rather than assume.
  allow_price_override TINYINT(1) NOT NULL DEFAULT 0,
  status         ENUM('draft','active','paused','quota_exceeded','contract_expired','suspended') NOT NULL DEFAULT 'draft',
  last_export_at DATETIME(3)     NULL,
  next_export_at DATETIME(3)     NULL,
  live_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  error_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Return on the channel, so renewal is a decision rather than a habit.
  leads_received INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_syndication_channels_public (public_id),
  UNIQUE KEY uq_syndication_channel (connection_id, organization_id),
  KEY ix_syndication_channels_due (status, next_export_at),
  KEY ix_syndication_channels_org (organization_id, status),
  CONSTRAINT fk_syndication_channels_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE,
  CONSTRAINT fk_syndication_channels_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_syndication_channels_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- syndication_subscriptions
--
-- Which listings are opted in to which channel, and whether the agency has
-- overridden anything for that channel. One row per (listing, channel).
-- -----------------------------------------------------------------------------
CREATE TABLE syndication_subscriptions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  channel_id     INT UNSIGNED    NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  status         ENUM('pending','queued','live','rejected','removed','paused','quota_blocked','ineligible') NOT NULL DEFAULT 'pending',
  is_featured_remotely TINYINT(1) NOT NULL DEFAULT 0,
  -- Per-channel overrides.
  price_override DECIMAL(18,2)   NULL,
  title_override VARCHAR(255)    NULL,
  description_override MEDIUMTEXT NULL,
  -- Outcome from the far end.
  external_id    VARCHAR(191)    NULL,
  external_url   VARCHAR(500)    NULL,
  rejection_code VARCHAR(60)     NULL,
  rejection_message VARCHAR(500) NULL,
  first_published_at DATETIME(3) NULL,
  last_pushed_at DATETIME(3)     NULL,
  last_success_at DATETIME(3)    NULL,
  removed_at     DATETIME(3)     NULL,
  push_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  error_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Performance reported back by the portal, where it reports any.
  remote_views   INT UNSIGNED    NOT NULL DEFAULT 0,
  remote_leads   INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_syndication_subscription (channel_id, listing_id),
  KEY ix_syndication_subs_listing (listing_id, status),
  -- The push queue and the rejection report.
  KEY ix_syndication_subs_pending (channel_id, status, last_pushed_at),
  KEY ix_syndication_subs_org (organization_id, status),
  CONSTRAINT fk_syndication_subs_channel FOREIGN KEY (channel_id) REFERENCES syndication_channels (id) ON DELETE CASCADE,
  CONSTRAINT fk_syndication_subs_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_syndication_subs_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- feed_exports
--
-- One run. Counters are the operational summary; `output_media_asset_id` keeps
-- the exact file that was sent, which is the only way to settle "we never got
-- that listing" three days later.
-- -----------------------------------------------------------------------------
CREATE TABLE feed_exports (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  channel_id     INT UNSIGNED    NULL,
  connection_id  INT UNSIGNED    NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  export_type    ENUM('full','incremental','single','removal','retry') NOT NULL DEFAULT 'incremental',
  trigger_source ENUM('schedule','manual','listing_change','quota_change','api','retry') NOT NULL DEFAULT 'schedule',
  status         ENUM('queued','running','completed','partial','failed','cancelled','timed_out') NOT NULL DEFAULT 'queued',
  started_at     DATETIME(3)     NULL,
  finished_at    DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  total_items    INT UNSIGNED    NOT NULL DEFAULT 0,
  sent_items     INT UNSIGNED    NOT NULL DEFAULT 0,
  accepted_items INT UNSIGNED    NOT NULL DEFAULT 0,
  rejected_items INT UNSIGNED    NOT NULL DEFAULT 0,
  skipped_items  INT UNSIGNED    NOT NULL DEFAULT 0,
  removed_items  INT UNSIGNED    NOT NULL DEFAULT 0,
  unchanged_items INT UNSIGNED   NOT NULL DEFAULT 0,
  -- The artefact actually transmitted, and where it went.
  output_media_asset_id BIGINT UNSIGNED NULL,
  output_size_bytes BIGINT UNSIGNED NULL,
  output_checksum CHAR(64)       NULL,
  destination_path VARCHAR(500)  NULL,
  http_status    SMALLINT UNSIGNED NULL,
  error_message  VARCHAR(1000)   NULL,
  triggered_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_feed_exports_public (public_id),
  KEY ix_feed_exports_channel (channel_id, created_at),
  KEY ix_feed_exports_status (status, created_at),
  KEY ix_feed_exports_org (organization_id, created_at),
  CONSTRAINT fk_feed_exports_channel FOREIGN KEY (channel_id) REFERENCES syndication_channels (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_exports_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_exports_asset FOREIGN KEY (output_media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Per-listing outcome within a run. This is what turns "the feed ran" into
-- "your villa was rejected because the permit number is expired".
CREATE TABLE feed_export_items (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  export_id      BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  operation      ENUM('create','update','delete','skip','unchanged') NOT NULL DEFAULT 'update',
  status         ENUM('sent','accepted','rejected','skipped','failed') NOT NULL DEFAULT 'sent',
  external_id    VARCHAR(191)    NULL,
  -- Local validation failures, before anything was transmitted.
  validation_errors JSON         NULL,
  -- What the far end said.
  error_code     VARCHAR(60)     NULL,
  error_message  VARCHAR(1000)   NULL,
  payload_hash   CHAR(32)        CHARACTER SET ascii NULL,
  processed_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_export_items_export (export_id, status),
  KEY ix_export_items_listing (listing_id, processed_at),
  CONSTRAINT fk_export_items_export FOREIGN KEY (export_id) REFERENCES feed_exports (id) ON DELETE CASCADE,
  CONSTRAINT fk_export_items_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · INBOUND IMPORT
-- =============================================================================

-- -----------------------------------------------------------------------------
-- feed_imports
--
-- One inbound run.
--
-- `deletion_mode` deserves attention. A full feed implies "anything not in this
-- file is gone", which is correct until the day the agency's CRM exports an
-- empty file and the platform dutifully unpublishes their entire stock. Hence
-- `max_deletion_percent`: a run that would remove more than the threshold stops
-- and asks. This is not hypothetical — it is the single most damaging feed
-- failure there is.
-- -----------------------------------------------------------------------------
CREATE TABLE feed_imports (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  connection_id  INT UNSIGNED    NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  import_type    ENUM('full','incremental','single','manual_upload','api_push') NOT NULL DEFAULT 'full',
  entity_type    ENUM('listing','project','agent','contact','lead','media') NOT NULL DEFAULT 'listing',
  -- Safety valve. See the table comment.
  deletion_mode  ENUM('none','mark_unavailable','unpublish','delete') NOT NULL DEFAULT 'mark_unavailable',
  max_deletion_percent TINYINT UNSIGNED NOT NULL DEFAULT 20,
  status         ENUM('queued','downloading','validating','running','completed','partial','failed','cancelled','held_for_review') NOT NULL DEFAULT 'queued',
  hold_reason    VARCHAR(300)    NULL,
  source_url     VARCHAR(500)    NULL,
  source_media_asset_id BIGINT UNSIGNED NULL,
  source_size_bytes BIGINT UNSIGNED NULL,
  source_checksum CHAR(64)       NULL,
  -- Skip a byte-identical re-run, which is most runs on a daily feed.
  is_duplicate_of_id BIGINT UNSIGNED NULL,
  started_at     DATETIME(3)     NULL,
  finished_at    DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  total_rows     INT UNSIGNED    NOT NULL DEFAULT 0,
  created_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  updated_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unchanged_count INT UNSIGNED   NOT NULL DEFAULT 0,
  skipped_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  failed_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  deleted_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  media_downloaded INT UNSIGNED  NOT NULL DEFAULT 0,
  media_failed   INT UNSIGNED    NOT NULL DEFAULT 0,
  unmapped_values_count INT UNSIGNED NOT NULL DEFAULT 0,
  error_message  VARCHAR(1000)   NULL,
  triggered_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_feed_imports_public (public_id),
  KEY ix_feed_imports_connection (connection_id, created_at),
  KEY ix_feed_imports_status (status, created_at),
  KEY ix_feed_imports_org (organization_id, created_at),
  KEY ix_feed_imports_checksum (connection_id, source_checksum),
  CONSTRAINT fk_feed_imports_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_imports_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_imports_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_feed_imports_asset FOREIGN KEY (source_media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- feed_import_items
--
-- Per-row outcome, with the raw payload retained on anything that did not
-- succeed cleanly. Storing the raw row is what makes a failure diagnosable
-- without asking the agency to resend the file.
-- -----------------------------------------------------------------------------
CREATE TABLE feed_import_items (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  import_id      BIGINT UNSIGNED NOT NULL,
  source_row     INT UNSIGNED    NULL,
  external_id    VARCHAR(191)    NULL,
  entity_type    ENUM('listing','project','agent','contact','lead','media') NOT NULL DEFAULT 'listing',
  entity_id      BIGINT UNSIGNED NULL,
  operation      ENUM('create','update','unchanged','skip','delete','fail') NOT NULL DEFAULT 'create',
  status         ENUM('success','warning','failed','skipped') NOT NULL DEFAULT 'success',
  -- Kept for failures and warnings; nulled on clean success to keep the table
  -- from growing to the size of every feed ever received.
  raw_payload    JSON            NULL,
  changed_fields JSON            NULL,
  errors         JSON            NULL,
  warnings       JSON            NULL,
  error_message  VARCHAR(1000)   NULL,
  processed_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_import_items_import (import_id, status),
  KEY ix_import_items_entity (entity_type, entity_id),
  KEY ix_import_items_external (import_id, external_id),
  CONSTRAINT fk_import_items_import FOREIGN KEY (import_id) REFERENCES feed_imports (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- inbound_leads
--
-- Leads pushed back to us by a portal or partner, landing raw before they are
-- turned into a `lead`. Two reasons this is not written straight into `leads`:
--
--   1. The payload frequently fails validation — no phone, a masked email, a
--      listing reference we do not recognise — and a failed parse must not
--      lose the lead. It sits here until someone fixes the mapping.
--   2. Portals resend. `dedupe_hash` plus a unique index makes a replayed
--      delivery a no-op rather than a duplicate charge to the agency.
-- -----------------------------------------------------------------------------
CREATE TABLE inbound_leads (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  connection_id  INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NULL,
  external_lead_id VARCHAR(191)  NULL,
  external_listing_ref VARCHAR(191) NULL,
  -- Resolved references, filled in when the payload could be matched.
  listing_id     BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  -- The payload exactly as received, never edited.
  raw_payload    JSON            NOT NULL,
  -- Parsed fields, best effort.
  name           VARCHAR(240)    NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  message        TEXT            NULL,
  channel        ENUM('form','call','whatsapp','email','chat','sms','unknown') NOT NULL DEFAULT 'form',
  received_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  status         ENUM('received','processed','duplicate','unmatched','invalid','failed','rejected') NOT NULL DEFAULT 'received',
  failure_reason VARCHAR(500)    NULL,
  processed_at   DATETIME(3)     NULL,
  retry_count    TINYINT UNSIGNED NOT NULL DEFAULT 0,
  -- Replay protection.
  dedupe_hash    CHAR(32)        CHARACTER SET ascii NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_inbound_leads_public (public_id),
  UNIQUE KEY uq_inbound_leads_dedupe (provider_id, dedupe_hash),
  KEY ix_inbound_leads_status (status, received_at),
  KEY ix_inbound_leads_org (organization_id, received_at),
  KEY ix_inbound_leads_listing (listing_id, received_at),
  CONSTRAINT fk_inbound_leads_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_inbound_leads_connection FOREIGN KEY (connection_id) REFERENCES integration_connections (id) ON DELETE SET NULL,
  CONSTRAINT fk_inbound_leads_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_inbound_leads_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_inbound_leads_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- portal_performance_daily
--
-- What each portal actually delivered, per day, per organisation. This is the
-- table that decides next year's marketing spend, and it is why every portal
-- integration should report views and leads back even when it is inconvenient.
-- -----------------------------------------------------------------------------
CREATE TABLE portal_performance_daily (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  provider_id    INT UNSIGNED    NOT NULL,
  channel_id     INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  live_listings  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  impressions    INT UNSIGNED    NOT NULL DEFAULT 0,
  detail_views   INT UNSIGNED    NOT NULL DEFAULT 0,
  leads          INT UNSIGNED    NOT NULL DEFAULT 0,
  calls          INT UNSIGNED    NOT NULL DEFAULT 0,
  whatsapp       INT UNSIGNED    NOT NULL DEFAULT 0,
  emails         INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Cost apportioned from the channel's contract, so cost-per-lead per portal
  -- is a division rather than a spreadsheet.
  apportioned_cost DECIMAL(12,2) NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  cost_per_lead  DECIMAL(12,2)   NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_portal_performance (stat_date, provider_id, channel_id, organization_id),
  KEY ix_portal_performance_org (organization_id, stat_date),
  KEY ix_portal_performance_provider (provider_id, stat_date),
  CONSTRAINT fk_portal_performance_provider FOREIGN KEY (provider_id) REFERENCES integration_providers (id) ON DELETE CASCADE,
  CONSTRAINT fk_portal_performance_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 5 · API TRAFFIC
-- =============================================================================

-- -----------------------------------------------------------------------------
-- api_request_logs
--
-- Every call to our public API, and every call we make outbound. One table for
-- both because the operational questions are identical — who called what, how
-- long did it take, what came back — and because a partner integration is a
-- conversation whose two halves belong side by side when it goes wrong.
--
-- Month-partitioned, unjoined, no foreign keys: same discipline as the other
-- high-volume logs. Request and response bodies are truncated and stored only
-- on errors, because logging every payload of a busy API is both a storage
-- problem and a data-protection one.
-- -----------------------------------------------------------------------------
CREATE TABLE api_request_logs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  direction      ENUM('inbound','outbound') NOT NULL DEFAULT 'inbound',
  api_client_id  BIGINT UNSIGNED NULL,
  provider_id    INT UNSIGNED    NULL,
  connection_id  INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  method         ENUM('GET','POST','PUT','PATCH','DELETE','HEAD','OPTIONS') NOT NULL DEFAULT 'GET',
  -- Templated, not literal: "/v1/listings/{id}" rather than "/v1/listings/8842",
  -- so grouping by endpoint is possible without a regex over millions of rows.
  endpoint       VARCHAR(255)    NOT NULL,
  full_path      VARCHAR(500)    NULL,
  api_version    VARCHAR(20)     NULL,
  status_code    SMALLINT UNSIGNED NULL,
  duration_ms    INT UNSIGNED    NULL,
  request_bytes  INT UNSIGNED    NULL,
  response_bytes INT UNSIGNED    NULL,
  -- Retained only for non-2xx responses.
  request_body_excerpt VARCHAR(2000) NULL,
  response_body_excerpt VARCHAR(2000) NULL,
  error_code     VARCHAR(60)     NULL,
  error_message  VARCHAR(500)    NULL,
  -- Rate limiting and quota, so a 429 is explainable to the partner.
  rate_limit_remaining SMALLINT UNSIGNED NULL,
  was_rate_limited TINYINT(1)    NOT NULL DEFAULT 0,
  retry_attempt  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  idempotency_key VARCHAR(120)   NULL,
  -- Distributed trace id, so one request can be followed across services.
  trace_id       CHAR(32)        CHARACTER SET ascii NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(300)    NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_api_logs_client (api_client_id, occurred_at),
  KEY ix_api_logs_endpoint (endpoint, occurred_at),
  KEY ix_api_logs_errors (status_code, occurred_at),
  KEY ix_api_logs_provider (provider_id, occurred_at),
  KEY ix_api_logs_trace (trace_id)
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
-- api_usage_daily
--
-- Per-client, per-endpoint daily rollup. Serves the partner's usage dashboard,
-- the rate-limit tier decision and metered billing, none of which should ever
-- aggregate the partitioned log table at read time.
-- -----------------------------------------------------------------------------
CREATE TABLE api_usage_daily (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  api_client_id  BIGINT UNSIGNED NULL,
  provider_id    INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NULL,
  direction      ENUM('inbound','outbound') NOT NULL DEFAULT 'inbound',
  endpoint       VARCHAR(255)    NOT NULL DEFAULT 'all',
  request_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  success_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  client_error_count INT UNSIGNED NOT NULL DEFAULT 0,
  server_error_count INT UNSIGNED NOT NULL DEFAULT 0,
  rate_limited_count INT UNSIGNED NOT NULL DEFAULT 0,
  total_duration_ms BIGINT UNSIGNED NOT NULL DEFAULT 0,
  avg_duration_ms INT UNSIGNED   NULL,
  p95_duration_ms INT UNSIGNED   NULL,
  max_duration_ms INT UNSIGNED   NULL,
  request_bytes  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  response_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
  billable_units INT UNSIGNED    NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_api_usage_daily (stat_date, api_client_id, provider_id, direction, endpoint),
  KEY ix_api_usage_client (api_client_id, stat_date),
  KEY ix_api_usage_org (organization_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0023', 'feeds_and_integrations');
