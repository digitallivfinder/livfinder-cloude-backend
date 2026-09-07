-- =============================================================================
-- Liv Finder — 0020 · CRM, lead lifecycle and call tracking
-- =============================================================================
-- Migration 0008 gave us `inquiries`: one row per "someone pressed the button".
-- That is an *event*, and it is the wrong grain to run a sales floor on.
--
-- A serious marketplace has to answer a different question: who is this person,
-- what are they actually looking for, who owns them, how long have they been
-- waiting, and what is the next thing someone has to do about it. The same
-- buyer enquires on four penthouses over three weeks from two email addresses
-- and one phone number. That is one *lead*, four inquiries, one contact, and —
-- if it goes well — one deal. Conflating those is why portal CRMs are hated:
-- the agent sees four cards, calls the person four times, and the person books
-- with somebody else.
--
-- So this migration separates four grains that most schemas collapse into one:
--
--   crm_contacts   the person. Deduplicated across identifiers, permanent.
--   leads          the person's intent at a point in time. Has a pipeline
--                  stage, an owner, a score and an SLA clock.
--   inquiries      the individual touch (0008). Many attach to one lead.
--   deals          the transaction. Has money, parties and commission.
--
-- Two further things here are not decoration:
--
-- ROUTING. Whoever is fastest wins the lead — the industry rule of thumb is
-- that response inside five minutes converts an order of magnitude better than
-- inside an hour. `lead_routing_rules` decide who gets it, `lead_assignments`
-- record the offer and whether it was accepted, and if it is not accepted the
-- rule's fallback reassigns it. Round-robin state lives on the pool member row
-- so distribution is fair rather than "whoever refreshes first".
--
-- SLA. `sla_clocks` is a running clock per lead, with pause semantics for
-- out-of-hours, because a breach recorded against an agent who was asleep at
-- 03:00 local is a metric nobody trusts and therefore nobody uses.
--
-- CALL TRACKING. Portals rent numbers per listing or per agent so a call can be
-- attributed to the listing that produced it. `call_tracking_numbers` are pooled
-- and leased, `calls` are the CDRs, and every call is joined back to the lead —
-- which is the only way "we sent you 300 leads" survives a client's audit.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · CONTACTS — the person, deduplicated
-- =============================================================================

-- -----------------------------------------------------------------------------
-- crm_contacts
--
-- Distinct from `users` (someone with a login) and from `contacts` (a website
-- contact-form submission). A CRM contact is a person an organisation has a
-- relationship with, whether or not they ever registered.
--
-- Scoped to an organisation: contact records are commercially sensitive and are
-- not shared between agencies. The same human legitimately exists as separate
-- rows under two agencies, and `master_contact_id` optionally links them for
-- platform-level analytics without leaking either agency's notes to the other.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_contacts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  -- Set when the contact has (or later creates) a platform login.
  user_id        BIGINT UNSIGNED NULL,
  -- Platform-wide identity, for cross-agency analytics only.
  master_contact_id BIGINT UNSIGNED NULL,
  contact_type   ENUM('buyer','seller','tenant','landlord','investor','developer','broker','vendor','other') NOT NULL DEFAULT 'buyer',
  salutation     VARCHAR(20)     NULL,
  first_name     VARCHAR(120)    NULL,
  last_name      VARCHAR(120)    NULL,
  display_name   VARCHAR(240)    NOT NULL,
  -- Folded for dedupe matching: lowercase, diacritics stripped, spaces removed.
  name_normalized VARCHAR(240)   NOT NULL,
  company_name   VARCHAR(200)    NULL,
  job_title      VARCHAR(160)    NULL,
  -- Primary identifiers are denormalised onto the contact for the list view;
  -- the full set (a person may have four numbers) lives in
  -- crm_contact_identifiers, which is what dedupe actually matches on.
  primary_email  VARCHAR(255)    NULL,
  primary_email_normalized VARCHAR(255) NULL,
  primary_phone_e164 VARCHAR(20) NULL,
  preferred_language_id SMALLINT UNSIGNED NULL,
  preferred_currency_code CHAR(3) NULL,
  timezone       VARCHAR(64)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  nationality_country_id BIGINT UNSIGNED NULL,
  address_line1  VARCHAR(255)    NULL,
  postal_code    VARCHAR(24)     NULL,
  -- How rich the record is. Drives "complete this profile" prompts and is a
  -- fair proxy for how sellable the lead is.
  completeness_score TINYINT UNSIGNED NOT NULL DEFAULT 0,
  lifecycle_stage ENUM('subscriber','lead','marketing_qualified','sales_qualified','opportunity','customer','evangelist','other') NOT NULL DEFAULT 'lead',
  -- Contact preferences. These are hard gates, not suggestions: the messaging
  -- layer in 0025 refuses to send when the channel flag is 0.
  allow_email    TINYINT(1)      NOT NULL DEFAULT 1,
  allow_sms      TINYINT(1)      NOT NULL DEFAULT 1,
  allow_call     TINYINT(1)      NOT NULL DEFAULT 1,
  allow_whatsapp TINYINT(1)      NOT NULL DEFAULT 1,
  marketing_opt_in TINYINT(1)    NOT NULL DEFAULT 0,
  marketing_opt_in_at DATETIME(3) NULL,
  -- Do-not-contact overrides everything above, including transactional sends
  -- that are not legally required. Separate from the channel flags because it
  -- carries a reason and must survive a re-import that resets preferences.
  do_not_contact TINYINT(1)      NOT NULL DEFAULT 0,
  do_not_contact_reason VARCHAR(200) NULL,
  do_not_contact_at DATETIME(3)  NULL,
  owner_agent_id BIGINT UNSIGNED NULL,
  source_id      INT UNSIGNED    NULL,
  -- Denormalised activity summary so the contact list sorts by recency without
  -- touching the activity table. Maintained by sp_crm_refresh_contact_rollups.
  lead_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  deal_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  activity_count INT UNSIGNED    NOT NULL DEFAULT 0,
  last_activity_at DATETIME(3)   NULL,
  last_contacted_at DATETIME(3)  NULL,
  next_action_at DATETIME(3)     NULL,
  total_deal_value_base DECIMAL(20,2) NOT NULL DEFAULT 0,
  notes          TEXT            NULL,
  custom_fields  JSON            NULL,
  is_vip         TINYINT(1)      NOT NULL DEFAULT 0,
  is_blacklisted TINYINT(1)      NOT NULL DEFAULT 0,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_crm_contacts_public (public_id),
  -- The dedupe key that matters in practice. Nullable columns in a unique key
  -- permit repeated NULLs in InnoDB, so contacts with no email are unconstrained
  -- here and fall through to phone matching in crm_contact_identifiers.
  UNIQUE KEY uq_crm_contacts_org_email (organization_id, primary_email_normalized),
  KEY ix_crm_contacts_org_updated (organization_id, deleted_at, updated_at),
  KEY ix_crm_contacts_org_owner (organization_id, owner_agent_id, lifecycle_stage),
  KEY ix_crm_contacts_phone (organization_id, primary_phone_e164),
  KEY ix_crm_contacts_name (organization_id, name_normalized),
  KEY ix_crm_contacts_user (user_id),
  KEY ix_crm_contacts_master (master_contact_id),
  KEY ix_crm_contacts_next_action (organization_id, next_action_at),
  KEY ix_crm_contacts_dnc (do_not_contact, organization_id),
  CONSTRAINT fk_crm_contacts_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_contacts_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_master FOREIGN KEY (master_contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_owner FOREIGN KEY (owner_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_lang FOREIGN KEY (preferred_language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_city FOREIGN KEY (city_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_contacts_nationality FOREIGN KEY (nationality_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- crm_contact_identifiers
--
-- Every way we know how to reach a person, one row each, with the normalised
-- form indexed. This is the table dedupe joins on: an inbound enquiry from
-- +971 50 123 4567 has to find the contact stored as 00971501234567.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_contact_identifiers (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contact_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  identifier_type ENUM('email','phone','whatsapp','wechat','telegram','linkedin','instagram','passport','national_id','other') NOT NULL,
  value_raw      VARCHAR(255)    NOT NULL,
  -- Lowercased for email, E.164 for phone. The unique key is on this.
  value_normalized VARCHAR(255)  NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  is_verified    TINYINT(1)      NOT NULL DEFAULT 0,
  verified_at    DATETIME(3)     NULL,
  -- Set when a send to this address hard-bounced or the number is unreachable,
  -- so the next campaign skips it instead of damaging sender reputation.
  is_bounced     TINYINT(1)      NOT NULL DEFAULT 0,
  bounced_at     DATETIME(3)     NULL,
  bounce_reason  VARCHAR(200)    NULL,
  label          VARCHAR(60)     NULL,
  source         VARCHAR(60)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_contact_identifier (organization_id, identifier_type, value_normalized),
  KEY ix_contact_identifiers_contact (contact_id, identifier_type, is_primary),
  KEY ix_contact_identifiers_lookup (identifier_type, value_normalized),
  CONSTRAINT fk_contact_identifiers_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE CASCADE,
  CONSTRAINT fk_contact_identifiers_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- crm_contact_merges
--
-- Merging is destructive and users get it wrong, so it is recorded rather than
-- performed silently. `field_resolutions` holds which value won for each
-- conflicting field, which is what makes an un-merge possible.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_contact_merges (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  surviving_contact_id BIGINT UNSIGNED NOT NULL,
  merged_contact_id BIGINT UNSIGNED NOT NULL,
  -- Snapshot of the losing row before it was folded in. Without this an
  -- incorrect merge is unrecoverable.
  merged_snapshot JSON           NOT NULL,
  field_resolutions JSON         NULL,
  match_method   ENUM('email','phone','name_and_phone','manual','fuzzy','import') NOT NULL DEFAULT 'manual',
  match_confidence DECIMAL(5,2)  NULL,
  moved_leads    INT UNSIGNED    NOT NULL DEFAULT 0,
  moved_activities INT UNSIGNED  NOT NULL DEFAULT 0,
  moved_deals    INT UNSIGNED    NOT NULL DEFAULT 0,
  performed_by_user_id BIGINT UNSIGNED NULL,
  reverted_at    DATETIME(3)     NULL,
  reverted_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_contact_merges_surviving (surviving_contact_id, created_at),
  KEY ix_contact_merges_org (organization_id, created_at),
  CONSTRAINT fk_contact_merges_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_contact_merges_surviving FOREIGN KEY (surviving_contact_id) REFERENCES crm_contacts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- crm_tags / crm_tag_assignments
--
-- Free-form segmentation an agency controls itself. Polymorphic on purpose —
-- the same tag ("Ramadan campaign 2026", "Golden visa") applies to contacts,
-- leads and deals alike.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_tags (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(80)     NOT NULL,
  slug           VARCHAR(90)     NOT NULL,
  colour         CHAR(7)         NULL,
  description    VARCHAR(255)    NULL,
  tag_group      VARCHAR(60)     NULL,
  usage_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_crm_tags_org_slug (organization_id, slug),
  KEY ix_crm_tags_group (organization_id, tag_group, is_active),
  CONSTRAINT fk_crm_tags_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE crm_tag_assignments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tag_id         INT UNSIGNED    NOT NULL,
  subject_type   ENUM('contact','lead','deal','listing','viewing') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  assigned_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tag_assignment (tag_id, subject_type, subject_id),
  KEY ix_tag_assignments_subject (subject_type, subject_id),
  CONSTRAINT fk_tag_assignments_tag FOREIGN KEY (tag_id) REFERENCES crm_tags (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · PIPELINES AND LEADS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- lead_sources
--
-- The canonical attribution registry. UTM strings are free text written by
-- whoever built the campaign; this is the controlled vocabulary they are mapped
-- onto, with the cost model attached so cost-per-lead is computable rather than
-- estimated in a spreadsheet.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_sources (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  channel        ENUM('organic_search','paid_search','paid_social','organic_social','direct','referral','email','portal','partner','offline','call','walk_in','api','import','other') NOT NULL DEFAULT 'other',
  medium         VARCHAR(60)     NULL,
  -- Set when the source is another portal we syndicate to, so imported leads
  -- carry their true origin rather than showing as "direct".
  external_portal VARCHAR(60)    NULL,
  cost_model     ENUM('none','cpc','cpm','cpl','cpa','flat','commission') NOT NULL DEFAULT 'none',
  default_cost_per_lead DECIMAL(12,2) NULL,
  cost_currency_code CHAR(3)     NULL,
  -- Rolling quality signal maintained from conversion outcomes, so budget can
  -- be moved off sources that deliver volume without deals.
  lead_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  qualified_count INT UNSIGNED   NOT NULL DEFAULT 0,
  deal_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  quality_score  DECIMAL(5,2)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_sources_code (organization_id, code),
  KEY ix_lead_sources_channel (channel, is_active),
  CONSTRAINT fk_lead_sources_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_pipelines / lead_pipeline_stages
--
-- Agencies do not share a sales process. A developer's off-plan pipeline and a
-- brokerage's secondary-market pipeline have different stages, and forcing both
-- through one hardcoded enum is the reason most portal CRMs go unused.
--
-- `probability` on a stage is what makes a weighted forecast possible without
-- asking anyone to guess per deal.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_pipelines (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(400)    NULL,
  pipeline_type  ENUM('lead','deal','both') NOT NULL DEFAULT 'lead',
  -- Restricting a pipeline to a category lets a multi-asset agency run separate
  -- processes for yachts and apartments, which genuinely differ.
  root_category_id INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_pipelines_code (organization_id, code),
  KEY ix_lead_pipelines_active (organization_id, is_active, sort_order),
  CONSTRAINT fk_lead_pipelines_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_pipelines_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_pipelines_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_pipeline_stages (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  pipeline_id    INT UNSIGNED    NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  -- The semantic role of the stage, so reporting ("conversion rate", "time to
  -- qualification") works across differently-named custom pipelines.
  stage_type     ENUM('new','contacted','qualified','nurturing','proposal','negotiation','won','lost','disqualified') NOT NULL DEFAULT 'new',
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  probability    DECIMAL(5,2)    NOT NULL DEFAULT 0,
  colour         CHAR(7)         NULL,
  -- Hours after entering this stage at which the lead is flagged stale. This is
  -- the rot detector: leads do not fail loudly, they just sit.
  stale_after_hours SMALLINT UNSIGNED NULL,
  -- Hours in which first contact must happen while in this stage. Feeds
  -- sla_targets when the policy does not override it.
  response_target_minutes SMALLINT UNSIGNED NULL,
  requires_reason_on_exit TINYINT(1) NOT NULL DEFAULT 0,
  is_closed      TINYINT(1)      NOT NULL DEFAULT 0,
  is_won         TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_pipeline_stage_code (pipeline_id, code),
  KEY ix_pipeline_stages_order (pipeline_id, sort_order),
  CONSTRAINT fk_pipeline_stages_pipeline FOREIGN KEY (pipeline_id) REFERENCES lead_pipelines (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_lost_reasons
--
-- A controlled vocabulary, because "lost — other" written 4,000 times teaches
-- nobody anything. `is_recoverable` separates "bought elsewhere" (gone) from
-- "timing wrong" (re-engage in six months), which is what nurture keys on.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_lost_reasons (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  reason_group   ENUM('price','timing','product','competitor','financing','unresponsive','not_qualified','duplicate','spam','other') NOT NULL DEFAULT 'other',
  is_recoverable TINYINT(1)      NOT NULL DEFAULT 0,
  recontact_after_days SMALLINT UNSIGNED NULL,
  requires_note  TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lost_reasons_code (organization_id, code),
  CONSTRAINT fk_lost_reasons_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- leads
--
-- The working unit of the sales floor.
--
-- The index list is longer than usual and each entry earns its place: the lead
-- board is filtered by owner and stage, the manager view by stage and age, the
-- SLA sweeper by due time, the nurture job by next_action_at, and the dedupe
-- path by contact. All of those are hot, all of them concurrent.
-- -----------------------------------------------------------------------------
CREATE TABLE leads (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  branch_id      BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  pipeline_id    INT UNSIGNED    NOT NULL,
  stage_id       INT UNSIGNED    NOT NULL,
  -- Denormalised from the stage so the board can group without a join and the
  -- reporting layer keeps working when a stage is renamed.
  stage_type     ENUM('new','contacted','qualified','nurturing','proposal','negotiation','won','lost','disqualified') NOT NULL DEFAULT 'new',
  status         ENUM('open','won','lost','disqualified','archived') NOT NULL DEFAULT 'open',
  -- Denormalised contact fields. A lead must remain readable when the contact
  -- record is later merged or redacted under a data-subject request.
  name           VARCHAR(240)    NOT NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  preferred_language_id SMALLINT UNSIGNED NULL,
  -- What they want.
  intent         ENUM('buy','rent','sell','let','invest','charter','valuation','finance','other') NOT NULL DEFAULT 'buy',
  category_id    INT UNSIGNED    NULL,
  root_category_id INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  primary_listing_id BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  budget_min     DECIMAL(18,2)   NULL,
  budget_max     DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  -- Base-currency copy so a multi-market pipeline sorts and sums by value in
  -- one indexed comparison. Same rule as `listings.price_base`.
  budget_max_base DECIMAL(18,2)  NULL,
  timeframe      ENUM('immediate','within_1_month','within_3_months','within_6_months','within_12_months','exploring','unknown') NOT NULL DEFAULT 'unknown',
  financing      ENUM('cash','mortgage_approved','mortgage_needed','unknown') NOT NULL DEFAULT 'unknown',
  -- Ownership and routing.
  owner_agent_id BIGINT UNSIGNED NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  assigned_at    DATETIME(3)     NULL,
  assignment_method ENUM('manual','round_robin','load_balanced','skill_based','territory','listing_owner','shark_tank','import','api') NULL,
  reassignment_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Scoring and priority.
  score          SMALLINT        NOT NULL DEFAULT 0,
  score_band     ENUM('cold','warm','hot','on_fire') NOT NULL DEFAULT 'cold',
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  is_qualified   TINYINT(1)      NOT NULL DEFAULT 0,
  qualified_at   DATETIME(3)     NULL,
  -- Response and SLA. `first_response_minutes` is stored rather than derived
  -- because the dashboards read it constantly and the inputs never change once
  -- set.
  first_response_at DATETIME(3)  NULL,
  first_response_minutes INT UNSIGNED NULL,
  response_due_at DATETIME(3)    NULL,
  sla_status     ENUM('pending','met','breached','paused','not_applicable') NOT NULL DEFAULT 'pending',
  last_contacted_at DATETIME(3)  NULL,
  last_activity_at DATETIME(3)   NULL,
  next_action_at DATETIME(3)     NULL,
  next_action_note VARCHAR(255)  NULL,
  stage_entered_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  is_stale       TINYINT(1)      NOT NULL DEFAULT 0,
  -- Attribution.
  source_id      INT UNSIGNED    NULL,
  channel        ENUM('web_form','phone','whatsapp','email','chat','walk_in','portal','partner','referral','api','import','social','other') NOT NULL DEFAULT 'web_form',
  utm_source     VARCHAR(120)    NULL,
  utm_medium     VARCHAR(120)    NULL,
  utm_campaign   VARCHAR(160)    NULL,
  utm_content    VARCHAR(160)    NULL,
  utm_term       VARCHAR(160)    NULL,
  gclid          VARCHAR(200)    NULL,
  fbclid         VARCHAR(200)    NULL,
  landing_url    VARCHAR(500)    NULL,
  referrer_url   VARCHAR(500)    NULL,
  -- Cost carried on the lead at creation, from lead_sources or an ad campaign,
  -- so cost-per-acquisition survives the campaign being edited later.
  acquisition_cost DECIMAL(12,2) NULL,
  acquisition_cost_currency CHAR(3) NULL,
  -- Outcome.
  lost_reason_id INT UNSIGNED    NULL,
  lost_note      VARCHAR(500)    NULL,
  closed_at      DATETIME(3)     NULL,
  deal_id        BIGINT UNSIGNED NULL,
  -- Quality and dedupe.
  is_duplicate   TINYINT(1)      NOT NULL DEFAULT 0,
  duplicate_of_lead_id BIGINT UNSIGNED NULL,
  spam_score     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  is_spam        TINYINT(1)      NOT NULL DEFAULT 0,
  inquiry_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  activity_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  viewing_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  custom_fields  JSON            NULL,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_leads_public (public_id),
  UNIQUE KEY uq_leads_reference (reference),
  KEY ix_leads_board (organization_id, status, stage_id, updated_at),
  KEY ix_leads_owner (owner_agent_id, status, next_action_at),
  KEY ix_leads_org_created (organization_id, created_at),
  KEY ix_leads_contact (contact_id, created_at),
  KEY ix_leads_listing (primary_listing_id, created_at),
  KEY ix_leads_project (project_id, status),
  -- The SLA sweeper: "open leads whose response is due before now".
  KEY ix_leads_sla (sla_status, response_due_at),
  KEY ix_leads_stale (organization_id, is_stale, stage_entered_at),
  KEY ix_leads_source (source_id, created_at),
  KEY ix_leads_score (organization_id, score_band, score),
  KEY ix_leads_email (organization_id, email),
  KEY ix_leads_phone (organization_id, phone_e164),
  KEY ix_leads_campaign (organization_id, utm_campaign, created_at),
  CONSTRAINT fk_leads_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_leads_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_branch FOREIGN KEY (branch_id) REFERENCES organization_branches (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_pipeline FOREIGN KEY (pipeline_id) REFERENCES lead_pipelines (id),
  CONSTRAINT fk_leads_stage FOREIGN KEY (stage_id) REFERENCES lead_pipeline_stages (id),
  CONSTRAINT fk_leads_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_root_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_listing FOREIGN KEY (primary_listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_owner_agent FOREIGN KEY (owner_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_owner_user FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_source FOREIGN KEY (source_id) REFERENCES lead_sources (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_lost_reason FOREIGN KEY (lost_reason_id) REFERENCES lead_lost_reasons (id) ON DELETE SET NULL,
  CONSTRAINT fk_leads_duplicate FOREIGN KEY (duplicate_of_lead_id) REFERENCES leads (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- lead_inquiries
--
-- The join that makes the two grains coexist: many inquiries (0008) roll up to
-- one lead. `is_primary` marks the enquiry that created it.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_inquiries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  inquiry_id     BIGINT UNSIGNED NOT NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  attached_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  attached_by    ENUM('system','agent','import','api') NOT NULL DEFAULT 'system',
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_inquiry (inquiry_id),
  KEY ix_lead_inquiries_lead (lead_id, attached_at),
  CONSTRAINT fk_lead_inquiries_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_inquiries_inquiry FOREIGN KEY (inquiry_id) REFERENCES inquiries (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_listings
--
-- Everything the lead has shown interest in, with why. Distinct from favourites
-- (0008), which are the buyer's own list — this is the agent's shortlist and it
-- records the outcome per property, which is how "shown 12, offered on 2" comes
-- out of the data rather than out of a conversation.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_listings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  relation       ENUM('enquired','shortlisted','sent','viewed','offered','rejected','purchased') NOT NULL DEFAULT 'enquired',
  interest_level ENUM('unknown','low','medium','high') NOT NULL DEFAULT 'unknown',
  sent_at        DATETIME(3)     NULL,
  viewed_at      DATETIME(3)     NULL,
  feedback       VARCHAR(1000)   NULL,
  rejection_reason VARCHAR(200)  NULL,
  added_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_listing (lead_id, listing_id),
  KEY ix_lead_listings_listing (listing_id, relation),
  CONSTRAINT fk_lead_listings_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_listings_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_requirements
--
-- The buyer brief, structured. Free-text "wants a 3-bed in Marina under 5M"
-- cannot be matched against inventory; this can, and the matching job writes
-- lead_listings rows from it.
--
-- One row per lead is the norm, but a lead genuinely can carry two briefs
-- ("either a villa in Emirates Hills or a penthouse on the Palm"), so the key
-- is not unique.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_requirements (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  label          VARCHAR(120)    NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  price_min      DECIMAL(18,2)   NULL,
  price_max      DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  price_max_base DECIMAL(18,2)   NULL,
  bedrooms_min   TINYINT UNSIGNED NULL,
  bedrooms_max   TINYINT UNSIGNED NULL,
  bathrooms_min  TINYINT UNSIGNED NULL,
  area_min       DECIMAL(12,2)   NULL,
  area_max       DECIMAL(12,2)   NULL,
  area_unit_id   SMALLINT UNSIGNED NULL,
  -- Category-specific requirements that do not deserve a column on every brief:
  -- yacht length, watch reference, car mileage ceiling. Keyed by attribute code
  -- from the 0003 registry so it stays machine-matchable.
  attribute_criteria JSON        NULL,
  required_feature_ids JSON      NULL,
  furnishing     ENUM('any','furnished','unfurnished','part_furnished') NOT NULL DEFAULT 'any',
  completion     ENUM('any','ready','off_plan') NOT NULL DEFAULT 'any',
  move_in_by     DATE            NULL,
  notes          VARCHAR(1000)   NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  match_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  last_matched_at DATETIME(3)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_lead_requirements_lead (lead_id, is_active),
  KEY ix_lead_requirements_match (is_active, last_matched_at),
  CONSTRAINT fk_lead_requirements_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_requirements_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_requirements_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_requirements_unit FOREIGN KEY (area_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Which locations a brief covers. Separate rather than a JSON array because
-- matching joins it against location_closure to catch descendants: "Dubai
-- Marina" must match a tower inside it.
CREATE TABLE lead_requirement_locations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  requirement_id BIGINT UNSIGNED NOT NULL,
  location_id    BIGINT UNSIGNED NOT NULL,
  -- Excluding an area is a real requirement ("anywhere in Dubai except JVC").
  is_excluded    TINYINT(1)      NOT NULL DEFAULT 0,
  weight         TINYINT UNSIGNED NOT NULL DEFAULT 100,
  PRIMARY KEY (id),
  UNIQUE KEY uq_requirement_location (requirement_id, location_id),
  KEY ix_requirement_locations_location (location_id, is_excluded),
  CONSTRAINT fk_requirement_locations_req FOREIGN KEY (requirement_id) REFERENCES lead_requirements (id) ON DELETE CASCADE,
  CONSTRAINT fk_requirement_locations_loc FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_stage_history
--
-- Append-only. Every funnel report, every "average days in negotiation", every
-- dispute about who dropped the ball is answered from here, so `duration_seconds`
-- is written on exit rather than computed by self-joining the table at read time.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_stage_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  from_stage_id  INT UNSIGNED    NULL,
  to_stage_id    INT UNSIGNED    NOT NULL,
  from_stage_type ENUM('new','contacted','qualified','nurturing','proposal','negotiation','won','lost','disqualified') NULL,
  to_stage_type  ENUM('new','contacted','qualified','nurturing','proposal','negotiation','won','lost','disqualified') NOT NULL,
  -- Seconds spent in the stage being left. NULL on the first row.
  duration_seconds INT UNSIGNED  NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  changed_by     ENUM('user','system','automation','import','api') NOT NULL DEFAULT 'user',
  reason         VARCHAR(300)    NULL,
  lost_reason_id INT UNSIGNED    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_lead_stage_history_lead (lead_id, created_at),
  KEY ix_lead_stage_history_stage (to_stage_id, created_at),
  CONSTRAINT fk_lead_stage_history_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_stage_history_to FOREIGN KEY (to_stage_id) REFERENCES lead_pipeline_stages (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · SCORING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- lead_scoring_models / lead_scoring_rules / lead_score_events
--
-- Scores are versioned by model, not overwritten in place. When the model is
-- retuned every historical lead's score would otherwise silently change and
-- last quarter's "hot leads converted at 30%" becomes unreproducible.
--
-- lead_score_events is the audit trail: which rule fired, what it added, when.
-- A score with no explanation is not actionable, and agents ignore what they
-- cannot interrogate.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_scoring_models (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  description    VARCHAR(400)    NULL,
  model_type     ENUM('rule_based','weighted','ml_scored','hybrid') NOT NULL DEFAULT 'rule_based',
  max_score      SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- Band thresholds live on the model so re-banding is a settings change, not a
  -- deploy, and so historical bands remain interpretable against their model.
  warm_threshold SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  hot_threshold  SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  on_fire_threshold SMALLINT UNSIGNED NOT NULL DEFAULT 85,
  -- Points decay if nothing happens, otherwise a lead that was hot in March is
  -- still hot in September.
  decay_per_day  DECIMAL(6,2)    NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  activated_at   DATETIME(3)     NULL,
  retired_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_scoring_models_code (organization_id, code, version),
  KEY ix_scoring_models_active (organization_id, is_active),
  CONSTRAINT fk_scoring_models_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_scoring_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  model_id       INT UNSIGNED    NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  rule_type      ENUM('demographic','firmographic','behavioural','engagement','source_quality','recency','negative') NOT NULL DEFAULT 'behavioural',
  -- What is being tested. `field_path` is a dotted path into the lead and its
  -- related rows ("lead.budget_max_base", "activity.count.call_7d"), evaluated
  -- by the scoring job rather than by SQL, so a new signal does not need DDL.
  field_path     VARCHAR(160)    NOT NULL,
  operator       ENUM('eq','neq','gt','gte','lt','lte','in','not_in','between','contains','starts_with','is_null','is_not_null','regex') NOT NULL DEFAULT 'eq',
  comparison_value JSON          NULL,
  points         SMALLINT        NOT NULL DEFAULT 0,
  -- A rule may fire more than once (three viewings booked); cap the damage.
  max_applications SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_scoring_rules_code (model_id, code),
  KEY ix_scoring_rules_model (model_id, is_active, sort_order),
  CONSTRAINT fk_scoring_rules_model FOREIGN KEY (model_id) REFERENCES lead_scoring_models (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_score_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  model_id       INT UNSIGNED    NOT NULL,
  rule_id        INT UNSIGNED    NULL,
  points_delta   SMALLINT        NOT NULL,
  score_before   SMALLINT        NOT NULL,
  score_after    SMALLINT        NOT NULL,
  band_before    ENUM('cold','warm','hot','on_fire') NULL,
  band_after     ENUM('cold','warm','hot','on_fire') NULL,
  trigger_type   ENUM('rule','manual','decay','recalculation','import') NOT NULL DEFAULT 'rule',
  explanation    VARCHAR(300)    NULL,
  triggered_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_lead_score_events_lead (lead_id, created_at),
  KEY ix_lead_score_events_rule (rule_id, created_at),
  CONSTRAINT fk_lead_score_events_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_score_events_model FOREIGN KEY (model_id) REFERENCES lead_scoring_models (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_score_events_rule FOREIGN KEY (rule_id) REFERENCES lead_scoring_rules (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · ROUTING AND SLA
-- =============================================================================

-- -----------------------------------------------------------------------------
-- lead_routing_pools / lead_routing_pool_members
--
-- A pool is a set of agents a lead can be routed to, plus the state needed to
-- distribute fairly. Round-robin position lives on the member row
-- (`last_assigned_at`, `assigned_count`) rather than in a counter on the pool,
-- because a single cursor breaks the moment somebody goes on leave.
--
-- `daily_cap` and `concurrent_cap` are what stop the top performer being handed
-- everything until they drown — a real failure mode of naive load balancing.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_routing_pools (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  strategy       ENUM('round_robin','load_balanced','weighted','performance','skill_based','first_to_claim','broadcast','least_busy') NOT NULL DEFAULT 'round_robin',
  branch_id      BIGINT UNSIGNED NULL,
  -- With first_to_claim ("shark tank") the lead is offered to everyone and the
  -- first acceptance wins; the rest are expired. Fast, and brutal.
  claim_window_seconds SMALLINT UNSIGNED NULL,
  -- How long an offered assignment may sit unaccepted before it is pulled and
  -- re-routed. The single most important number for response time.
  accept_timeout_seconds SMALLINT UNSIGNED NOT NULL DEFAULT 300,
  max_reassignments TINYINT UNSIGNED NOT NULL DEFAULT 3,
  -- Where a lead goes when everyone declined or the pool is empty. Without this
  -- leads fall into a hole and are found weeks later.
  fallback_agent_id BIGINT UNSIGNED NULL,
  fallback_pool_id INT UNSIGNED   NULL,
  respect_working_hours TINYINT(1) NOT NULL DEFAULT 1,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_routing_pools_code (organization_id, code),
  KEY ix_routing_pools_active (organization_id, is_active),
  CONSTRAINT fk_routing_pools_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_pools_branch FOREIGN KEY (branch_id) REFERENCES organization_branches (id) ON DELETE SET NULL,
  CONSTRAINT fk_routing_pools_fallback_agent FOREIGN KEY (fallback_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_routing_pools_fallback_pool FOREIGN KEY (fallback_pool_id) REFERENCES lead_routing_pools (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_routing_pool_members (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  pool_id        INT UNSIGNED    NOT NULL,
  agent_id       BIGINT UNSIGNED NOT NULL,
  weight         SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- Availability. `is_available` is the agent's own toggle; `paused_until`
  -- covers leave. Both are checked before an offer is made.
  is_available   TINYINT(1)      NOT NULL DEFAULT 1,
  paused_until   DATETIME(3)     NULL,
  daily_cap      SMALLINT UNSIGNED NULL,
  concurrent_cap SMALLINT UNSIGNED NULL,
  -- Round-robin state and fairness counters.
  assigned_count INT UNSIGNED    NOT NULL DEFAULT 0,
  assigned_today SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  open_lead_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_assigned_at DATETIME(3)   NULL,
  -- Performance inputs for the `performance` strategy, refreshed nightly.
  accept_rate    DECIMAL(5,2)    NULL,
  avg_response_minutes SMALLINT UNSIGNED NULL,
  conversion_rate DECIMAL(5,2)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_pool_member (pool_id, agent_id),
  -- The selection index for round-robin: available members of a pool, oldest
  -- assignment first.
  KEY ix_pool_members_next (pool_id, is_available, last_assigned_at),
  KEY ix_pool_members_agent (agent_id),
  CONSTRAINT fk_pool_members_pool FOREIGN KEY (pool_id) REFERENCES lead_routing_pools (id) ON DELETE CASCADE,
  CONSTRAINT fk_pool_members_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_routing_rules / lead_routing_rule_conditions
--
-- Ordered rules, first match wins. Conditions are rows rather than one JSON
-- blob so a rule can be indexed, reported on ("which rule sends leads to Dubai
-- Marina?") and edited field by field in an admin UI.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_routing_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(400)    NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- The target. Exactly one of these should be set; which one is enforced by
  -- the application because MySQL CHECK support across MariaDB is uneven.
  target_type    ENUM('pool','agent','listing_owner','branch','queue','round_robin_org') NOT NULL DEFAULT 'pool',
  target_pool_id INT UNSIGNED    NULL,
  target_agent_id BIGINT UNSIGNED NULL,
  target_branch_id BIGINT UNSIGNED NULL,
  -- Overrides applied to the lead when this rule matches.
  set_priority   ENUM('low','normal','high','urgent') NULL,
  set_pipeline_id INT UNSIGNED   NULL,
  sla_policy_id  INT UNSIGNED    NULL,
  -- Stop evaluating further rules on a match. Off by default so a rule can add
  -- a tag or an SLA and let a later rule do the assignment.
  stop_processing TINYINT(1)     NOT NULL DEFAULT 1,
  match_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  last_matched_at DATETIME(3)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  effective_from DATETIME(3)     NULL,
  effective_to   DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_routing_rules_eval (organization_id, is_active, priority),
  CONSTRAINT fk_routing_rules_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_pool FOREIGN KEY (target_pool_id) REFERENCES lead_routing_pools (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_agent FOREIGN KEY (target_agent_id) REFERENCES agents (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_branch FOREIGN KEY (target_branch_id) REFERENCES organization_branches (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_pipeline FOREIGN KEY (set_pipeline_id) REFERENCES lead_pipelines (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_routing_rule_conditions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  rule_id        INT UNSIGNED    NOT NULL,
  -- Conditions in the same group are ORed; groups are ANDed. Two integers give
  -- the whole of the boolean expressiveness anyone actually uses.
  condition_group TINYINT UNSIGNED NOT NULL DEFAULT 1,
  field          ENUM('category','root_category','purpose','location','country','city','community','budget','budget_base','language','channel','source','intent','listing_agent','listing_organization','project','timeframe','score','utm_campaign','is_repeat_contact','hour_of_day','day_of_week','custom') NOT NULL,
  custom_field_path VARCHAR(160) NULL,
  operator       ENUM('eq','neq','gt','gte','lt','lte','in','not_in','between','contains','starts_with','is_null','is_not_null','descendant_of') NOT NULL DEFAULT 'eq',
  value_text     VARCHAR(500)    NULL,
  value_number_min DECIMAL(18,2) NULL,
  value_number_max DECIMAL(18,2) NULL,
  value_ids      JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_rule_conditions_rule (rule_id, condition_group),
  CONSTRAINT fk_rule_conditions_rule FOREIGN KEY (rule_id) REFERENCES lead_routing_rules (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_assignments
--
-- One row per *offer*, not per accepted assignment. Declines and timeouts are
-- the data you need to fix a routing configuration, and they are exactly what
-- gets thrown away by schemas that only store `leads.owner_agent_id`.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_assignments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  lead_id        BIGINT UNSIGNED NOT NULL,
  agent_id       BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  pool_id        INT UNSIGNED    NULL,
  rule_id        INT UNSIGNED    NULL,
  assignment_method ENUM('manual','round_robin','load_balanced','skill_based','territory','listing_owner','shark_tank','escalation','reassignment','import','api') NOT NULL DEFAULT 'manual',
  sequence_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  status         ENUM('offered','accepted','declined','expired','revoked','superseded') NOT NULL DEFAULT 'offered',
  offered_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NULL,
  responded_at   DATETIME(3)     NULL,
  response_seconds INT UNSIGNED  NULL,
  decline_reason VARCHAR(200)    NULL,
  -- Set when the assignment ends, so "how long did this agent hold it" is a
  -- subtraction rather than a window function over the whole table.
  released_at    DATETIME(3)     NULL,
  assigned_by_user_id BIGINT UNSIGNED NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_assignment_seq (lead_id, sequence_number),
  KEY ix_lead_assignments_agent (agent_id, status, offered_at),
  -- The expiry sweeper.
  KEY ix_lead_assignments_expiry (status, expires_at),
  KEY ix_lead_assignments_pool (pool_id, offered_at),
  CONSTRAINT fk_lead_assignments_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_assignments_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_assignments_pool FOREIGN KEY (pool_id) REFERENCES lead_routing_pools (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_assignments_rule FOREIGN KEY (rule_id) REFERENCES lead_routing_rules (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- business_hours
--
-- Needed by SLA pausing and by routing's `respect_working_hours`. Modelled per
-- organisation and optionally per branch, with a timezone, because a Dubai
-- office works Monday–Friday while its Riyadh branch works Sunday–Thursday and
-- an SLA that ignores that is meaningless.
-- -----------------------------------------------------------------------------
CREATE TABLE business_hours (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NOT NULL,
  branch_id      BIGINT UNSIGNED NULL,
  timezone       VARCHAR(64)     NOT NULL DEFAULT 'UTC',
  -- 0 = Sunday .. 6 = Saturday. Sunday-based because the Gulf working week
  -- starts there and this schema's primary market is the Gulf.
  day_of_week    TINYINT UNSIGNED NOT NULL,
  opens_at       TIME            NULL,
  closes_at      TIME            NULL,
  is_closed      TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_business_hours (organization_id, branch_id, day_of_week),
  CONSTRAINT fk_business_hours_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_business_hours_branch FOREIGN KEY (branch_id) REFERENCES organization_branches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Public and company holidays, which are the other half of a credible SLA.
CREATE TABLE business_holidays (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  holiday_date   DATE            NOT NULL,
  is_half_day    TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_business_holidays (organization_id, country_id, holiday_date),
  KEY ix_business_holidays_date (holiday_date),
  CONSTRAINT fk_business_holidays_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_business_holidays_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- sla_policies / sla_targets
--
-- A policy is a named promise; targets are the individual clocks inside it
-- (first response, qualification, first viewing). Each target has its own
-- escalation chain, because "nobody answered in 15 minutes" and "nobody
-- qualified in 3 days" call for different people.
-- -----------------------------------------------------------------------------
CREATE TABLE sla_policies (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(400)    NULL,
  applies_to     ENUM('lead','inquiry','deal','support_ticket','all') NOT NULL DEFAULT 'lead',
  -- When set, the clock only runs during business_hours and pauses overnight.
  business_hours_only TINYINT(1) NOT NULL DEFAULT 0,
  exclude_holidays TINYINT(1)    NOT NULL DEFAULT 1,
  -- Scope: a premium policy for high-value leads, a default for the rest.
  min_budget_base DECIMAL(18,2)  NULL,
  priority_filter ENUM('low','normal','high','urgent') NULL,
  root_category_id INT UNSIGNED    NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sla_policies_code (organization_id, code),
  KEY ix_sla_policies_active (organization_id, is_active, is_default),
  CONSTRAINT fk_sla_policies_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_sla_policies_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sla_targets (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  policy_id      INT UNSIGNED    NOT NULL,
  metric         ENUM('first_response','first_call','qualification','first_viewing','proposal','resolution','next_action','follow_up') NOT NULL,
  target_minutes INT UNSIGNED    NOT NULL,
  -- Warn before you breach. A dashboard that only shows failures is a
  -- post-mortem tool, not an operational one.
  warning_at_percent TINYINT UNSIGNED NOT NULL DEFAULT 75,
  escalate_after_minutes INT UNSIGNED NULL,
  escalate_to_user_id BIGINT UNSIGNED NULL,
  escalate_to_pool_id INT UNSIGNED NULL,
  -- Reassigning on breach is the only escalation that actually recovers the
  -- lead; notifying a manager who is in a meeting does not.
  reassign_on_breach TINYINT(1)  NOT NULL DEFAULT 0,
  notify_channels SET('email','sms','push','in_app','webhook','slack') NOT NULL DEFAULT 'in_app',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sla_target (policy_id, metric),
  CONSTRAINT fk_sla_targets_policy FOREIGN KEY (policy_id) REFERENCES sla_policies (id) ON DELETE CASCADE,
  CONSTRAINT fk_sla_targets_pool FOREIGN KEY (escalate_to_pool_id) REFERENCES lead_routing_pools (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- sla_clocks
--
-- One running clock per subject per metric. `elapsed_seconds` accumulates only
-- while the clock is running, and `due_at` is recomputed on every resume — so a
-- lead that arrives at 22:00 under a business-hours policy is due at 09:15 the
-- next morning, not at 22:15 that night.
--
-- Indexed on (state, due_at) because the sweeper's only question is "what is
-- about to breach", asked every minute against a large table.
-- -----------------------------------------------------------------------------
CREATE TABLE sla_clocks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  policy_id      INT UNSIGNED    NOT NULL,
  target_id      INT UNSIGNED    NOT NULL,
  subject_type   ENUM('lead','inquiry','deal','support_ticket') NOT NULL DEFAULT 'lead',
  subject_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  metric         ENUM('first_response','first_call','qualification','first_viewing','proposal','resolution','next_action','follow_up') NOT NULL,
  state          ENUM('running','paused','met','breached','cancelled') NOT NULL DEFAULT 'running',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  due_at         DATETIME(3)     NOT NULL,
  warning_at     DATETIME(3)     NULL,
  paused_at      DATETIME(3)     NULL,
  paused_seconds INT UNSIGNED    NOT NULL DEFAULT 0,
  elapsed_seconds INT UNSIGNED   NOT NULL DEFAULT 0,
  completed_at   DATETIME(3)     NULL,
  breached_at    DATETIME(3)     NULL,
  breach_seconds INT UNSIGNED    NULL,
  owner_agent_id BIGINT UNSIGNED NULL,
  escalation_level TINYINT UNSIGNED NOT NULL DEFAULT 0,
  last_escalated_at DATETIME(3)  NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sla_clock (subject_type, subject_id, target_id),
  KEY ix_sla_clocks_sweeper (state, due_at),
  KEY ix_sla_clocks_org (organization_id, state, due_at),
  KEY ix_sla_clocks_agent (owner_agent_id, state),
  CONSTRAINT fk_sla_clocks_policy FOREIGN KEY (policy_id) REFERENCES sla_policies (id) ON DELETE CASCADE,
  CONSTRAINT fk_sla_clocks_target FOREIGN KEY (target_id) REFERENCES sla_targets (id) ON DELETE CASCADE,
  CONSTRAINT fk_sla_clocks_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Breaches are kept after the clock is cleaned up, because the SLA report is a
-- contractual artefact with a longer retention than the operational table.
CREATE TABLE sla_breaches (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  clock_id       BIGINT UNSIGNED NULL,
  policy_id      INT UNSIGNED    NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  subject_type   ENUM('lead','inquiry','deal','support_ticket') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  metric         ENUM('first_response','first_call','qualification','first_viewing','proposal','resolution','next_action','follow_up') NOT NULL,
  target_minutes INT UNSIGNED    NOT NULL,
  actual_minutes INT UNSIGNED    NOT NULL,
  overdue_minutes INT UNSIGNED   NOT NULL,
  owner_agent_id BIGINT UNSIGNED NULL,
  branch_id      BIGINT UNSIGNED NULL,
  breached_at    DATETIME(3)     NOT NULL,
  breach_date    DATE            NOT NULL,
  -- A breach can be excused (the client asked us to call back Monday); an
  -- excused breach stays visible but leaves the numerator.
  is_excused     TINYINT(1)      NOT NULL DEFAULT 0,
  excuse_reason  VARCHAR(300)    NULL,
  excused_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_sla_breaches_org_date (organization_id, breach_date, metric),
  KEY ix_sla_breaches_agent (owner_agent_id, breach_date),
  KEY ix_sla_breaches_subject (subject_type, subject_id),
  CONSTRAINT fk_sla_breaches_policy FOREIGN KEY (policy_id) REFERENCES sla_policies (id) ON DELETE CASCADE,
  CONSTRAINT fk_sla_breaches_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 5 · ACTIVITIES, TASKS AND VIEWINGS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- activities
--
-- The single timeline. Calls, emails, WhatsApp messages, notes, meetings,
-- stage changes and system events all land here, so "show me everything about
-- this lead" is one indexed range scan instead of a union of nine tables.
--
-- Polymorphic subject with no FK — deliberate, and the integrity suite checks
-- it for orphans nightly. The alternative (nine nullable FK columns) costs more
-- in index space and still needs the same check.
-- -----------------------------------------------------------------------------
CREATE TABLE activities (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  subject_type   ENUM('lead','contact','deal','listing','inquiry','viewing','organization','agent','project') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  -- Denormalised so the lead timeline and the contact timeline are each a
  -- single index range, without a subject_type predicate on every query.
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  activity_type  ENUM('note','call','email','sms','whatsapp','meeting','viewing','task','stage_change','assignment','document','offer','payment','system','import','other') NOT NULL DEFAULT 'note',
  direction      ENUM('inbound','outbound','internal') NOT NULL DEFAULT 'internal',
  subject_line   VARCHAR(255)    NULL,
  body           MEDIUMTEXT      NULL,
  -- Stripped preview for list rendering, so the timeline does not pull
  -- MEDIUMTEXT off-page for 50 rows.
  preview        VARCHAR(300)    NULL,
  outcome        ENUM('completed','no_answer','left_message','busy','wrong_number','not_interested','follow_up','scheduled','cancelled','failed') NULL,
  duration_seconds INT UNSIGNED  NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  agent_id       BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  -- Set when the row was produced by automation rather than a person, so
  -- "activity per agent" is not inflated by the system's own writes.
  is_automated   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Private notes are visible only to the author's own organisation members
  -- with the right permission; the read path filters on this.
  is_private     TINYINT(1)      NOT NULL DEFAULT 0,
  is_pinned      TINYINT(1)      NOT NULL DEFAULT 0,
  -- Links to the detail row when the activity is backed by one.
  call_id        BIGINT UNSIGNED NULL,
  message_id     BIGINT UNSIGNED NULL,
  viewing_id     BIGINT UNSIGNED NULL,
  metadata       JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_activities_public (public_id),
  KEY ix_activities_subject (subject_type, subject_id, occurred_at),
  KEY ix_activities_lead (lead_id, occurred_at),
  KEY ix_activities_contact (contact_id, occurred_at),
  KEY ix_activities_deal (deal_id, occurred_at),
  KEY ix_activities_agent (agent_id, occurred_at),
  KEY ix_activities_org_type (organization_id, activity_type, occurred_at),
  CONSTRAINT fk_activities_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_activities_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_activities_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_activities_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_activities_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- crm_tasks
--
-- Named crm_tasks rather than tasks because 0026 introduces a platform job
-- queue and the collision would be genuinely confusing at 2am.
--
-- The hot query is "my overdue and today's tasks", which is why the owner index
-- leads with completion state.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_tasks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  subject_type   ENUM('lead','contact','deal','listing','viewing','none') NOT NULL DEFAULT 'lead',
  subject_id     BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  title          VARCHAR(255)    NOT NULL,
  description    TEXT            NULL,
  task_type      ENUM('call','email','whatsapp','meeting','viewing','follow_up','document','valuation','other') NOT NULL DEFAULT 'follow_up',
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  status         ENUM('open','in_progress','completed','cancelled','deferred') NOT NULL DEFAULT 'open',
  due_at         DATETIME(3)     NULL,
  -- Kept separate from due_at so "reminders due" and "tasks due" are different
  -- sweeps with different indexes and different failure modes.
  remind_at      DATETIME(3)     NULL,
  reminder_sent_at DATETIME(3)   NULL,
  started_at     DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  completed_by_user_id BIGINT UNSIGNED NULL,
  completion_note VARCHAR(500)   NULL,
  assigned_to_agent_id BIGINT UNSIGNED NULL,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  -- Recurrence as an RFC 5545 RRULE string. Storing the rule rather than
  -- materialising a thousand rows keeps "every Monday until the deal closes"
  -- editable in one place.
  recurrence_rule VARCHAR(255)   NULL,
  parent_task_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_crm_tasks_public (public_id),
  KEY ix_crm_tasks_owner (assigned_to_agent_id, status, due_at),
  KEY ix_crm_tasks_user (assigned_to_user_id, status, due_at),
  KEY ix_crm_tasks_org_due (organization_id, status, due_at),
  KEY ix_crm_tasks_lead (lead_id, status),
  KEY ix_crm_tasks_subject (subject_type, subject_id),
  KEY ix_crm_tasks_reminder (status, remind_at),
  CONSTRAINT fk_crm_tasks_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_tasks_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_tasks_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_tasks_agent FOREIGN KEY (assigned_to_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_crm_tasks_parent FOREIGN KEY (parent_task_id) REFERENCES crm_tasks (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- viewings
--
-- Physical or virtual property visits. This is where a real-estate CRM diverges
-- hardest from a generic one: the viewing is the conversion event, feedback on
-- it is the single most valuable data the agency owns, and the seller expects a
-- report on it.
--
-- `access_notes` deliberately holds key-safe codes and concierge instructions,
-- and is therefore excluded from every export and portal feed.
-- -----------------------------------------------------------------------------
CREATE TABLE viewings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  viewing_type   ENUM('in_person','virtual','video_call','open_house','sea_trial','test_drive','private_showing') NOT NULL DEFAULT 'in_person',
  status         ENUM('requested','proposed','confirmed','rescheduled','completed','no_show','cancelled','declined') NOT NULL DEFAULT 'requested',
  scheduled_at   DATETIME(3)     NOT NULL,
  scheduled_end_at DATETIME(3)   NULL,
  timezone       VARCHAR(64)     NULL,
  duration_minutes SMALLINT UNSIGNED NULL,
  -- Where. Usually the listing's address, but an open house at a sales centre
  -- or a yacht viewing at a different berth is common enough to store.
  location_id    BIGINT UNSIGNED NULL,
  meeting_address VARCHAR(500)   NULL,
  meeting_url    VARCHAR(500)    NULL,
  access_notes   VARCHAR(500)    NULL,
  attendee_count TINYINT UNSIGNED NOT NULL DEFAULT 1,
  -- Outcome.
  checked_in_at  DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  cancelled_by   ENUM('client','agent','owner','system') NULL,
  cancellation_reason VARCHAR(300) NULL,
  rescheduled_from_id BIGINT UNSIGNED NULL,
  outcome        ENUM('interested','very_interested','offer_made','not_interested','needs_second_viewing','no_show','undecided') NULL,
  interest_level TINYINT UNSIGNED NULL,
  -- Whether the seller has been sent the feedback. Chasing this is most of a
  -- property manager's week, so it is a column and not a convention.
  feedback_sent_to_owner_at DATETIME(3) NULL,
  reminder_sent_at DATETIME(3)  NULL,
  confirmation_sent_at DATETIME(3) NULL,
  notes          TEXT            NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_viewings_public (public_id),
  UNIQUE KEY uq_viewings_reference (reference),
  -- The agent's diary: their confirmed viewings in date order.
  KEY ix_viewings_agent_schedule (agent_id, status, scheduled_at),
  KEY ix_viewings_listing (listing_id, scheduled_at),
  KEY ix_viewings_lead (lead_id, scheduled_at),
  KEY ix_viewings_org_schedule (organization_id, scheduled_at, status),
  KEY ix_viewings_reminder (status, scheduled_at, reminder_sent_at),
  KEY ix_viewings_contact (contact_id, scheduled_at),
  CONSTRAINT fk_viewings_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_viewings_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewings_rescheduled FOREIGN KEY (rescheduled_from_id) REFERENCES viewings (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE viewing_attendees (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  viewing_id     BIGINT UNSIGNED NOT NULL,
  contact_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  attendee_role  ENUM('buyer','partner','agent','co_agent','owner','surveyor','architect','interpreter','other') NOT NULL DEFAULT 'buyer',
  name           VARCHAR(200)    NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  rsvp_status    ENUM('pending','accepted','declined','tentative') NOT NULL DEFAULT 'pending',
  attended       TINYINT(1)      NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_viewing_attendees_viewing (viewing_id, attendee_role),
  KEY ix_viewing_attendees_contact (contact_id),
  CONSTRAINT fk_viewing_attendees_viewing FOREIGN KEY (viewing_id) REFERENCES viewings (id) ON DELETE CASCADE,
  CONSTRAINT fk_viewing_attendees_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_viewing_attendees_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- viewing_feedback
--
-- Structured, not a free-text box. Aggregated across viewings this is the
-- evidence that persuades a seller to reduce a price — "nine of eleven viewers
-- said the price was too high" is an argument; "buyers seem hesitant" is not.
-- -----------------------------------------------------------------------------
CREATE TABLE viewing_feedback (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  viewing_id     BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  submitted_by   ENUM('client','agent','owner') NOT NULL DEFAULT 'agent',
  overall_rating TINYINT UNSIGNED NULL,
  price_opinion  ENUM('too_low','fair','slightly_high','too_high') NULL,
  condition_rating TINYINT UNSIGNED NULL,
  location_rating TINYINT UNSIGNED NULL,
  layout_rating  TINYINT UNSIGNED NULL,
  likes          VARCHAR(1000)   NULL,
  dislikes       VARCHAR(1000)   NULL,
  objections     JSON            NULL,
  would_offer    TINYINT(1)      NULL,
  indicative_offer DECIMAL(18,2) NULL,
  currency_code  CHAR(3)         NULL,
  next_step      ENUM('offer','second_viewing','other_properties','not_proceeding','undecided') NULL,
  -- Sellers see a curated version; the internal note stays internal.
  is_shareable_with_owner TINYINT(1) NOT NULL DEFAULT 1,
  internal_note  VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_viewing_feedback_viewing (viewing_id),
  KEY ix_viewing_feedback_listing (listing_id, created_at),
  CONSTRAINT fk_viewing_feedback_viewing FOREIGN KEY (viewing_id) REFERENCES viewings (id) ON DELETE CASCADE,
  CONSTRAINT fk_viewing_feedback_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 6 · CALL TRACKING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- call_tracking_numbers
--
-- Rented numbers that forward to a real destination while recording who called
-- and from where. Two allocation models coexist:
--
--   static  — one number pinned to a listing, agent or campaign for months.
--             Cheap, and it survives being written on a billboard.
--   pooled  — a number leased to a single web session for a few minutes so a
--             call can be attributed to the exact visit and keyword. This is
--             what makes "which campaign produced this call" answerable, and
--             it is why `session_id` and `lease_expires_at` exist.
--
-- The cost columns are here because number rental is a real line item — a
-- thousand pooled numbers is a monthly invoice somebody has to justify.
-- -----------------------------------------------------------------------------
CREATE TABLE call_tracking_numbers (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  provider       ENUM('twilio','vonage','messagebird','plivo','telnyx','infobip','internal','other') NOT NULL DEFAULT 'twilio',
  provider_number_sid VARCHAR(120) NULL,
  phone_e164     VARCHAR(20)     NOT NULL,
  display_number VARCHAR(32)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  number_type    ENUM('local','national','mobile','toll_free','shared_cost') NOT NULL DEFAULT 'local',
  allocation     ENUM('static','pooled','vanity') NOT NULL DEFAULT 'static',
  -- What this number is attributed to when it is static.
  attribution_type ENUM('listing','agent','organization','branch','campaign','portal','print','billboard','session','none') NOT NULL DEFAULT 'none',
  listing_id     BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  branch_id      BIGINT UNSIGNED NULL,
  campaign_code  VARCHAR(80)     NULL,
  source_id      INT UNSIGNED    NULL,
  -- Where calls actually go.
  forward_to_e164 VARCHAR(20)    NULL,
  fallback_forward_e164 VARCHAR(20) NULL,
  whisper_message VARCHAR(255)   NULL,
  record_calls   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Recording consent is jurisdictional: two-party-consent regions require an
  -- announcement before the recording starts, and shipping without this is a
  -- legal problem rather than a feature gap.
  recording_announcement_required TINYINT(1) NOT NULL DEFAULT 1,
  transcribe_calls TINYINT(1)    NOT NULL DEFAULT 0,
  -- Pooled-number lease state.
  pool_id        INT UNSIGNED    NULL,
  leased_to_session_id CHAR(36)  NULL,
  lease_expires_at DATETIME(3)   NULL,
  status         ENUM('available','assigned','leased','suspended','released') NOT NULL DEFAULT 'available',
  monthly_cost   DECIMAL(10,2)   NULL,
  per_minute_cost DECIMAL(10,4)  NULL,
  cost_currency_code CHAR(3)     NULL,
  call_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  total_seconds  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  last_call_at   DATETIME(3)     NULL,
  provisioned_at DATETIME(3)     NULL,
  released_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tracking_numbers_e164 (phone_e164),
  KEY ix_tracking_numbers_listing (listing_id, status),
  KEY ix_tracking_numbers_agent (agent_id, status),
  -- The lease allocator: "give me a free number from this pool", and the
  -- reaper: "expire leases past their time".
  KEY ix_tracking_numbers_pool (pool_id, status, lease_expires_at),
  KEY ix_tracking_numbers_session (leased_to_session_id),
  KEY ix_tracking_numbers_org (organization_id, status),
  CONSTRAINT fk_tracking_numbers_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_tracking_numbers_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_tracking_numbers_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_tracking_numbers_branch FOREIGN KEY (branch_id) REFERENCES organization_branches (id) ON DELETE SET NULL,
  CONSTRAINT fk_tracking_numbers_source FOREIGN KEY (source_id) REFERENCES lead_sources (id) ON DELETE SET NULL,
  CONSTRAINT fk_tracking_numbers_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE call_tracking_pools (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  -- Minutes a number stays reserved to a visitor after the page view. Too short
  -- and a caller who rings back an hour later is misattributed; too long and
  -- the pool exhausts. Fifteen to thirty is typical.
  lease_minutes  SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  number_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  available_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- When the pool runs dry the visitor sees this instead of a broken number.
  overflow_number_e164 VARCHAR(20) NULL,
  exhaustion_count INT UNSIGNED  NOT NULL DEFAULT 0,
  last_exhausted_at DATETIME(3)  NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_call_pools_code (organization_id, code),
  CONSTRAINT fk_call_pools_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE call_tracking_numbers
  ADD CONSTRAINT fk_tracking_numbers_pool FOREIGN KEY (pool_id)
      REFERENCES call_tracking_pools (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- calls
--
-- The CDR, one row per call leg-set, joined to whatever it produced.
--
-- `billable_seconds` is separate from `duration_seconds` because carriers bill
-- in 60-second increments and reconciling a provider invoice against `duration`
-- fails every month. `is_qualified_call` is the commercial definition — longer
-- than the threshold, answered, not a repeat within the window — and it is
-- stored because it is what gets invoiced when the client pays per call.
-- -----------------------------------------------------------------------------
CREATE TABLE calls (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  provider       ENUM('twilio','vonage','messagebird','plivo','telnyx','infobip','internal','manual','other') NOT NULL DEFAULT 'twilio',
  provider_call_sid VARCHAR(120) NULL,
  tracking_number_id BIGINT UNSIGNED NULL,
  direction      ENUM('inbound','outbound','internal') NOT NULL DEFAULT 'inbound',
  from_e164      VARCHAR(20)     NULL,
  to_e164        VARCHAR(20)     NULL,
  -- The number the caller actually dialled, which is the tracking number on an
  -- inbound call and therefore the whole basis of attribution.
  dialled_e164   VARCHAR(20)     NULL,
  forwarded_to_e164 VARCHAR(20)  NULL,
  caller_name    VARCHAR(160)    NULL,
  caller_country_id BIGINT UNSIGNED NULL,
  status         ENUM('queued','ringing','in_progress','completed','busy','no_answer','failed','cancelled','voicemail') NOT NULL DEFAULT 'completed',
  started_at     DATETIME(3)     NOT NULL,
  answered_at    DATETIME(3)     NULL,
  ended_at       DATETIME(3)     NULL,
  ring_seconds   SMALLINT UNSIGNED NULL,
  duration_seconds INT UNSIGNED  NOT NULL DEFAULT 0,
  billable_seconds INT UNSIGNED  NOT NULL DEFAULT 0,
  -- Attribution.
  listing_id     BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  source_id      INT UNSIGNED    NULL,
  session_id     CHAR(36)        NULL,
  utm_campaign   VARCHAR(160)    NULL,
  landing_url    VARCHAR(500)    NULL,
  -- Commercial classification.
  is_first_time_caller TINYINT(1) NOT NULL DEFAULT 0,
  is_qualified_call TINYINT(1)   NOT NULL DEFAULT 0,
  is_billable    TINYINT(1)      NOT NULL DEFAULT 0,
  disposition_id INT UNSIGNED    NULL,
  outcome_note   VARCHAR(500)    NULL,
  -- Recording and transcription.
  recording_url  VARCHAR(500)    NULL,
  recording_media_asset_id BIGINT UNSIGNED NULL,
  recording_seconds INT UNSIGNED NULL,
  recording_consent_given TINYINT(1) NULL,
  transcript_status ENUM('none','pending','completed','failed') NOT NULL DEFAULT 'none',
  -- Quality signals derived by the speech pipeline. Sentiment is stored as a
  -- signed hundredth so it sorts without a cast.
  sentiment_score SMALLINT       NULL,
  talk_ratio_percent TINYINT UNSIGNED NULL,
  cost           DECIMAL(10,4)   NULL,
  cost_currency_code CHAR(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_calls_public (public_id),
  UNIQUE KEY uq_calls_provider_sid (provider, provider_call_sid),
  KEY ix_calls_org_started (organization_id, started_at),
  KEY ix_calls_agent (agent_id, started_at),
  KEY ix_calls_listing (listing_id, started_at),
  KEY ix_calls_lead (lead_id, started_at),
  KEY ix_calls_number (tracking_number_id, started_at),
  KEY ix_calls_from (from_e164, started_at),
  KEY ix_calls_billable (organization_id, is_billable, started_at),
  CONSTRAINT fk_calls_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_calls_number FOREIGN KEY (tracking_number_id) REFERENCES call_tracking_numbers (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_inquiry FOREIGN KEY (inquiry_id) REFERENCES inquiries (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_source FOREIGN KEY (source_id) REFERENCES lead_sources (id) ON DELETE SET NULL,
  CONSTRAINT fk_calls_recording FOREIGN KEY (recording_media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Per-leg telephony events (ringing, answered, transferred, hung up). Kept
-- apart from `calls` so the summary row stays narrow and hot while the event
-- detail, which is only read during an investigation, does not bloat it.
CREATE TABLE call_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  call_id        BIGINT UNSIGNED NOT NULL,
  sequence_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  event_type     ENUM('initiated','ringing','answered','transferred','held','resumed','dtmf','voicemail_start','voicemail_end','completed','failed','whisper_played','consent_played') NOT NULL,
  leg            ENUM('inbound','outbound','conference') NOT NULL DEFAULT 'inbound',
  target_e164    VARCHAR(20)     NULL,
  target_agent_id BIGINT UNSIGNED NULL,
  dtmf_digits    VARCHAR(32)     NULL,
  error_code     VARCHAR(40)     NULL,
  error_message  VARCHAR(300)    NULL,
  payload        JSON            NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_call_event_seq (call_id, sequence_number),
  KEY ix_call_events_type (event_type, occurred_at),
  CONSTRAINT fk_call_events_call FOREIGN KEY (call_id) REFERENCES calls (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- call_transcripts
--
-- Separated from `calls` because a transcript is large text that is almost
-- never read alongside the CDR row, and because it carries its own retention:
-- recordings and transcripts of a call are personal data with a shorter legal
-- life than the call metadata.
-- -----------------------------------------------------------------------------
CREATE TABLE call_transcripts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  call_id        BIGINT UNSIGNED NOT NULL,
  language_code  VARCHAR(12)     NULL,
  engine         VARCHAR(60)     NULL,
  confidence     DECIMAL(5,4)    NULL,
  full_text      MEDIUMTEXT      NULL,
  -- Speaker-labelled segments with offsets, so the player can jump to "the bit
  -- where they mention the budget".
  segments       JSON            NULL,
  summary        VARCHAR(2000)   NULL,
  detected_intents JSON          NULL,
  detected_keywords JSON         NULL,
  -- Compliance scoring: did the agent give the required disclosure, did they
  -- quote a rate they should not have.
  compliance_flags JSON          NULL,
  redacted_at    DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_call_transcripts_call (call_id),
  KEY ix_call_transcripts_expiry (expires_at),
  CONSTRAINT fk_call_transcripts_call FOREIGN KEY (call_id) REFERENCES calls (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Outcome codes an agent picks after a call. A controlled list because "call
-- outcomes" typed freehand cannot be reported on, and because `counts_as_contact`
-- is what decides whether the SLA clock stops.
CREATE TABLE call_dispositions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  category       ENUM('connected','not_connected','follow_up','disqualified','wrong_number','spam','other') NOT NULL DEFAULT 'connected',
  counts_as_contact TINYINT(1)   NOT NULL DEFAULT 1,
  advances_stage_id INT UNSIGNED NULL,
  requires_note  TINYINT(1)      NOT NULL DEFAULT 0,
  schedules_follow_up_hours SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_call_dispositions_code (organization_id, code),
  CONSTRAINT fk_call_dispositions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_call_dispositions_stage FOREIGN KEY (advances_stage_id) REFERENCES lead_pipeline_stages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE calls
  ADD CONSTRAINT fk_calls_disposition FOREIGN KEY (disposition_id)
      REFERENCES call_dispositions (id) ON DELETE SET NULL;

-- =============================================================================
-- SECTION 7 · DEALS AND COMMISSION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- deals
--
-- Where money is. A deal is created when a lead reaches an offer, and it
-- outlives the lead: conveyancing, mortgage conditions and handover can run for
-- a year after the lead is "won".
--
-- The gross/net commission split is not cosmetic. Gross is what the client
-- pays, net is what the agency keeps after the referring portal, the co-broke
-- and the agent's share — and every one of those is a separate payable, which
-- is why deal_commissions exists as rows rather than columns.
-- -----------------------------------------------------------------------------
CREATE TABLE deals (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  branch_id      BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  root_category_id INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  pipeline_id    INT UNSIGNED    NULL,
  stage_id       INT UNSIGNED    NULL,
  deal_type      ENUM('sale','purchase','rental','lease','charter','management','valuation','referral','other') NOT NULL DEFAULT 'sale',
  status         ENUM('open','under_offer','agreed','contracts_exchanged','completed','lost','cancelled','fallen_through') NOT NULL DEFAULT 'open',
  -- Money. `*_base` mirrors the listing convention so cross-market pipeline
  -- value is a single sum.
  asking_price   DECIMAL(18,2)   NULL,
  offer_amount   DECIMAL(18,2)   NULL,
  agreed_amount  DECIMAL(18,2)   NULL,
  final_amount   DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  agreed_amount_base DECIMAL(18,2) NULL,
  fx_rate_to_base DECIMAL(20,10) NULL,
  -- Commission summary, itemised in deal_commissions.
  commission_rate DECIMAL(7,4)   NULL,
  gross_commission DECIMAL(18,2) NULL,
  gross_commission_base DECIMAL(18,2) NULL,
  net_commission DECIMAL(18,2)   NULL,
  commission_scheme_id INT UNSIGNED NULL,
  -- Forecasting.
  probability    DECIMAL(5,2)    NULL,
  weighted_value_base DECIMAL(18,2) NULL,
  expected_close_date DATE       NULL,
  -- Rental terms, only meaningful for lets.
  rental_period_months SMALLINT UNSIGNED NULL,
  annual_rent    DECIMAL(18,2)   NULL,
  cheques_count  TINYINT UNSIGNED NULL,
  tenancy_start_date DATE        NULL,
  tenancy_end_date DATE          NULL,
  -- Lifecycle dates. Every one of these is a milestone somebody chases.
  offer_made_at  DATETIME(3)     NULL,
  offer_accepted_at DATETIME(3)  NULL,
  contract_signed_at DATETIME(3) NULL,
  deposit_received_at DATETIME(3) NULL,
  completed_at   DATETIME(3)     NULL,
  lost_at        DATETIME(3)     NULL,
  lost_reason_id INT UNSIGNED    NULL,
  lost_note      VARCHAR(500)    NULL,
  -- Ownership. Two agents split a deal often enough that both are first-class,
  -- with the rest in deal_parties.
  owner_agent_id BIGINT UNSIGNED NULL,
  co_agent_id    BIGINT UNSIGNED NULL,
  -- The other side. A co-broke with an outside agency is normal and its
  -- commission share is a real liability.
  external_agency_name VARCHAR(200) NULL,
  external_agent_name VARCHAR(200) NULL,
  is_co_brokered TINYINT(1)      NOT NULL DEFAULT 0,
  -- Compliance hooks resolved in 0024: transaction permits, AML clearance.
  permit_number  VARCHAR(80)     NULL,
  compliance_status ENUM('not_started','pending','cleared','flagged','blocked') NOT NULL DEFAULT 'not_started',
  invoice_id     BIGINT UNSIGNED NULL,
  custom_fields  JSON            NULL,
  notes          TEXT            NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_deals_public (public_id),
  UNIQUE KEY uq_deals_reference (reference),
  KEY ix_deals_org_status (organization_id, status, expected_close_date),
  KEY ix_deals_agent (owner_agent_id, status, expected_close_date),
  KEY ix_deals_stage (pipeline_id, stage_id, updated_at),
  KEY ix_deals_lead (lead_id),
  KEY ix_deals_listing (listing_id, status),
  KEY ix_deals_contact (contact_id, status),
  KEY ix_deals_completed (organization_id, completed_at),
  KEY ix_deals_compliance (compliance_status, organization_id),
  CONSTRAINT fk_deals_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_deals_branch FOREIGN KEY (branch_id) REFERENCES organization_branches (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_pipeline FOREIGN KEY (pipeline_id) REFERENCES lead_pipelines (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_stage FOREIGN KEY (stage_id) REFERENCES lead_pipeline_stages (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_owner FOREIGN KEY (owner_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_co_agent FOREIGN KEY (co_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_scheme FOREIGN KEY (commission_scheme_id) REFERENCES commission_schemes (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_lost_reason FOREIGN KEY (lost_reason_id) REFERENCES lead_lost_reasons (id) ON DELETE SET NULL,
  CONSTRAINT fk_deals_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE leads
  ADD CONSTRAINT fk_leads_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL;

ALTER TABLE viewings
  ADD CONSTRAINT fk_viewings_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL;

ALTER TABLE activities
  ADD CONSTRAINT fk_activities_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_activities_call FOREIGN KEY (call_id) REFERENCES calls (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_activities_viewing FOREIGN KEY (viewing_id) REFERENCES viewings (id) ON DELETE SET NULL;

ALTER TABLE crm_tasks
  ADD CONSTRAINT fk_crm_tasks_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- deal_stage_history — same rationale as lead_stage_history, kept separate
-- because deal cycles are measured in months and the two are never queried
-- together.
-- -----------------------------------------------------------------------------
CREATE TABLE deal_stage_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  deal_id        BIGINT UNSIGNED NOT NULL,
  from_stage_id  INT UNSIGNED    NULL,
  to_stage_id    INT UNSIGNED    NULL,
  from_status    ENUM('open','under_offer','agreed','contracts_exchanged','completed','lost','cancelled','fallen_through') NULL,
  to_status      ENUM('open','under_offer','agreed','contracts_exchanged','completed','lost','cancelled','fallen_through') NOT NULL,
  amount_at_change DECIMAL(18,2) NULL,
  duration_seconds INT UNSIGNED  NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  reason         VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_deal_stage_history_deal (deal_id, created_at),
  CONSTRAINT fk_deal_stage_history_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Everyone with a stake: buyer, seller, both agencies, the mortgage broker,
-- the conveyancer. Rows rather than columns because the cast varies by market
-- and by deal type.
CREATE TABLE deal_parties (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  deal_id        BIGINT UNSIGNED NOT NULL,
  party_role     ENUM('buyer','seller','tenant','landlord','buyer_agent','seller_agent','co_agent','referrer','mortgage_broker','conveyancer','lawyer','surveyor','developer','property_manager','other') NOT NULL,
  contact_id     BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  external_name  VARCHAR(200)    NULL,
  external_company VARCHAR(200)  NULL,
  external_email VARCHAR(255)    NULL,
  external_phone VARCHAR(32)     NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_deal_parties_deal (deal_id, party_role),
  KEY ix_deal_parties_contact (contact_id),
  KEY ix_deal_parties_agent (agent_id),
  CONSTRAINT fk_deal_parties_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE CASCADE,
  CONSTRAINT fk_deal_parties_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_deal_parties_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- deal_commissions
--
-- One row per share of the commission, each with its own payee, calculation and
-- payment state. This is the table finance actually works from: the agency's
-- share, the agent's cut under their scheme, the referrer's slice and the
-- co-broke split are four different payables with four different due dates.
--
-- `is_clawed_back` matters — a deal that falls through after the agent was paid
-- is common, and a schema with no representation for it forces a negative
-- invoice and an argument.
-- -----------------------------------------------------------------------------
CREATE TABLE deal_commissions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  deal_id        BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  commission_type ENUM('agency','agent','co_agent','referrer','co_broke','platform','override','bonus') NOT NULL DEFAULT 'agency',
  payee_type     ENUM('organization','agent','user','external','platform') NOT NULL DEFAULT 'agent',
  payee_agent_id BIGINT UNSIGNED NULL,
  payee_user_id  BIGINT UNSIGNED NULL,
  payee_organization_id BIGINT UNSIGNED NULL,
  payee_external_name VARCHAR(200) NULL,
  scheme_id      INT UNSIGNED    NULL,
  tier_id        INT UNSIGNED    NULL,
  calculation    ENUM('percentage_of_sale','percentage_of_commission','fixed','tiered','per_unit') NOT NULL DEFAULT 'percentage_of_commission',
  rate           DECIMAL(7,4)    NULL,
  base_amount    DECIMAL(18,2)   NULL,
  amount         DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  amount_base    DECIMAL(18,2)   NULL,
  tax_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  withholding_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  net_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  status         ENUM('projected','accrued','approved','invoiced','paid','disputed','cancelled','clawed_back') NOT NULL DEFAULT 'projected',
  due_date       DATE            NULL,
  approved_at    DATETIME(3)     NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  paid_at        DATETIME(3)     NULL,
  payout_id      BIGINT UNSIGNED NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  is_clawed_back TINYINT(1)      NOT NULL DEFAULT 0,
  clawed_back_at DATETIME(3)     NULL,
  clawback_reason VARCHAR(300)   NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_deal_commissions_deal (deal_id, commission_type),
  KEY ix_deal_commissions_agent (payee_agent_id, status, due_date),
  KEY ix_deal_commissions_org_status (organization_id, status, due_date),
  KEY ix_deal_commissions_payout (payout_id),
  CONSTRAINT fk_deal_commissions_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE CASCADE,
  CONSTRAINT fk_deal_commissions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_deal_commissions_agent FOREIGN KEY (payee_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_deal_commissions_scheme FOREIGN KEY (scheme_id) REFERENCES commission_schemes (id) ON DELETE SET NULL,
  CONSTRAINT fk_deal_commissions_tier FOREIGN KEY (tier_id) REFERENCES commission_tiers (id) ON DELETE SET NULL,
  CONSTRAINT fk_deal_commissions_payout FOREIGN KEY (payout_id) REFERENCES payouts (id) ON DELETE SET NULL,
  CONSTRAINT fk_deal_commissions_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 8 · NURTURE, FORMS AND LEAD SHARING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- nurture_campaigns / nurture_campaign_steps / nurture_enrolments
--
-- Most leads are not lost, they are early. A drip sequence is how a "not for
-- six months" lead is still ours in six months.
--
-- Steps are relative (`delay_hours` from the previous step) rather than
-- absolute, so a sequence can be edited without recomputing every enrolment,
-- and enrolments carry their own `next_step_at` so the sender is one indexed
-- sweep rather than a join across the whole campaign.
-- -----------------------------------------------------------------------------
CREATE TABLE nurture_campaigns (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  campaign_type  ENUM('nurture','onboarding','re_engagement','post_viewing','price_drop','new_listing_match','seasonal','win_back','transactional') NOT NULL DEFAULT 'nurture',
  -- Entry criteria, evaluated by the enrolment job. Same condition grammar as
  -- routing rules; stored as JSON here because a campaign's criteria are
  -- authored once and never queried field-by-field.
  entry_criteria JSON            NULL,
  -- Exit is more important than entry: a lead that books a viewing must stop
  -- receiving "are you still looking?" emails immediately.
  exit_criteria  JSON            NULL,
  exit_on_reply  TINYINT(1)      NOT NULL DEFAULT 1,
  exit_on_stage_change TINYINT(1) NOT NULL DEFAULT 1,
  -- Respect the recipient's local time. Sending at 03:00 is how a domain gets
  -- marked as spam.
  send_window_start TIME         NULL,
  send_window_end TIME           NULL,
  respect_business_hours TINYINT(1) NOT NULL DEFAULT 1,
  max_sends_per_week TINYINT UNSIGNED NULL,
  status         ENUM('draft','active','paused','archived') NOT NULL DEFAULT 'draft',
  enrolled_count INT UNSIGNED    NOT NULL DEFAULT 0,
  active_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  completed_count INT UNSIGNED   NOT NULL DEFAULT 0,
  converted_count INT UNSIGNED   NOT NULL DEFAULT 0,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_nurture_campaigns_public (public_id),
  UNIQUE KEY uq_nurture_campaigns_code (organization_id, code),
  KEY ix_nurture_campaigns_status (organization_id, status),
  CONSTRAINT fk_nurture_campaigns_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE nurture_campaign_steps (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  campaign_id    INT UNSIGNED    NOT NULL,
  step_number    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NULL,
  channel        ENUM('email','sms','whatsapp','push','in_app','task','call','webhook') NOT NULL DEFAULT 'email',
  -- Hours after the previous step completes (or after enrolment for step 1).
  delay_hours    SMALLINT UNSIGNED NOT NULL DEFAULT 24,
  notification_template_id INT UNSIGNED NULL,
  subject_line   VARCHAR(255)    NULL,
  body_template  MEDIUMTEXT      NULL,
  -- Steps that create work for a human rather than sending a message.
  creates_task   TINYINT(1)      NOT NULL DEFAULT 0,
  task_title     VARCHAR(200)    NULL,
  task_type      ENUM('call','email','whatsapp','meeting','viewing','follow_up','other') NULL,
  -- Skip this step unless the condition holds — how one sequence serves both
  -- buyers and renters without duplicating it.
  condition_json JSON            NULL,
  sent_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  opened_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  clicked_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  replied_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_campaign_step (campaign_id, step_number),
  CONSTRAINT fk_campaign_steps_campaign FOREIGN KEY (campaign_id) REFERENCES nurture_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_campaign_steps_template FOREIGN KEY (notification_template_id) REFERENCES notification_templates (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE nurture_enrolments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  campaign_id    INT UNSIGNED    NOT NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  status         ENUM('active','paused','completed','exited','failed','suppressed') NOT NULL DEFAULT 'active',
  current_step   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- The sweeper index. Everything about the sender's performance depends on
  -- (status, next_step_at) being a covering range scan.
  next_step_at   DATETIME(3)     NULL,
  enrolled_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  exited_at      DATETIME(3)     NULL,
  exit_reason    ENUM('completed','replied','stage_changed','converted','unsubscribed','bounced','manual','criteria_no_longer_met','suppressed') NULL,
  sends_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  opens_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  clicks_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  replies_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  converted      TINYINT(1)      NOT NULL DEFAULT 0,
  converted_at   DATETIME(3)     NULL,
  enrolled_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- A lead is in a given campaign once. Re-enrolment is a new campaign or a
  -- reset, never a second concurrent row racing the first.
  UNIQUE KEY uq_enrolment_lead (campaign_id, lead_id),
  KEY ix_enrolments_sweeper (status, next_step_at),
  KEY ix_enrolments_contact (contact_id, status),
  KEY ix_enrolments_org (organization_id, campaign_id, status),
  CONSTRAINT fk_enrolments_campaign FOREIGN KEY (campaign_id) REFERENCES nurture_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_enrolments_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_enrolments_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE CASCADE,
  CONSTRAINT fk_enrolments_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE nurture_step_deliveries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  enrolment_id   BIGINT UNSIGNED NOT NULL,
  step_id        INT UNSIGNED    NOT NULL,
  channel        ENUM('email','sms','whatsapp','push','in_app','task','call','webhook') NOT NULL,
  status         ENUM('scheduled','sent','delivered','opened','clicked','replied','bounced','failed','skipped','suppressed') NOT NULL DEFAULT 'scheduled',
  scheduled_at   DATETIME(3)     NULL,
  sent_at        DATETIME(3)     NULL,
  delivered_at   DATETIME(3)     NULL,
  opened_at      DATETIME(3)     NULL,
  clicked_at     DATETIME(3)     NULL,
  replied_at     DATETIME(3)     NULL,
  -- Set when the step was skipped, so a gap in the sequence is explained
  -- rather than looking like a bug.
  skip_reason    VARCHAR(200)    NULL,
  failure_reason VARCHAR(300)    NULL,
  notification_delivery_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_step_delivery (enrolment_id, step_id),
  KEY ix_step_deliveries_step (step_id, status),
  KEY ix_step_deliveries_scheduled (status, scheduled_at),
  CONSTRAINT fk_step_deliveries_enrolment FOREIGN KEY (enrolment_id) REFERENCES nurture_enrolments (id) ON DELETE CASCADE,
  CONSTRAINT fk_step_deliveries_step FOREIGN KEY (step_id) REFERENCES nurture_campaign_steps (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_forms / lead_form_fields / lead_form_submissions
--
-- Marketing needs new forms weekly — a landing page for an off-plan launch, a
-- valuation request, a mortgage pre-qualification. Making each one a code
-- change is why marketing ends up using a third-party form tool and the leads
-- arrive by email.
--
-- Submissions are stored raw *and* mapped: the raw payload survives a field
-- being renamed, and the mapped columns are what created the lead.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_forms (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  form_type      ENUM('inquiry','valuation','viewing_request','callback','mortgage','newsletter','contact','list_property','custom') NOT NULL DEFAULT 'inquiry',
  -- What happens to a submission.
  pipeline_id    INT UNSIGNED    NULL,
  source_id      INT UNSIGNED    NULL,
  routing_pool_id INT UNSIGNED   NULL,
  sla_policy_id  INT UNSIGNED    NULL,
  nurture_campaign_id INT UNSIGNED NULL,
  auto_create_lead TINYINT(1)    NOT NULL DEFAULT 1,
  auto_reply_template_id INT UNSIGNED NULL,
  -- Anti-abuse. A public form without these is a spam pipe within a week.
  requires_captcha TINYINT(1)    NOT NULL DEFAULT 1,
  honeypot_field VARCHAR(60)     NULL,
  min_fill_seconds SMALLINT UNSIGNED NOT NULL DEFAULT 3,
  rate_limit_per_hour SMALLINT UNSIGNED NOT NULL DEFAULT 10,
  -- Consent capture. The wording shown at the time is stored on the submission,
  -- because "they agreed to marketing" is only defensible with the text.
  consent_text   VARCHAR(1000)   NULL,
  consent_required TINYINT(1)    NOT NULL DEFAULT 0,
  redirect_url   VARCHAR(500)    NULL,
  success_message VARCHAR(500)   NULL,
  submission_count INT UNSIGNED  NOT NULL DEFAULT 0,
  spam_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  conversion_count INT UNSIGNED  NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_forms_public (public_id),
  UNIQUE KEY uq_lead_forms_code (organization_id, code),
  KEY ix_lead_forms_active (organization_id, is_active),
  CONSTRAINT fk_lead_forms_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_forms_pipeline FOREIGN KEY (pipeline_id) REFERENCES lead_pipelines (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_forms_source FOREIGN KEY (source_id) REFERENCES lead_sources (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_forms_pool FOREIGN KEY (routing_pool_id) REFERENCES lead_routing_pools (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_forms_sla FOREIGN KEY (sla_policy_id) REFERENCES sla_policies (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_forms_campaign FOREIGN KEY (nurture_campaign_id) REFERENCES nurture_campaigns (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_form_fields (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  form_id        INT UNSIGNED    NOT NULL,
  field_key      VARCHAR(60)     NOT NULL,
  label          VARCHAR(200)    NOT NULL,
  field_type     ENUM('text','textarea','email','phone','number','select','multiselect','radio','checkbox','date','location','budget','hidden','consent','file') NOT NULL DEFAULT 'text',
  -- Where the value lands on the lead. NULL means it stays in custom_fields.
  maps_to        ENUM('name','first_name','last_name','email','phone','message','budget_min','budget_max','currency','timeframe','financing','category','location','intent','language','consent','custom') NULL,
  placeholder    VARCHAR(200)    NULL,
  help_text      VARCHAR(300)    NULL,
  options        JSON            NULL,
  default_value  VARCHAR(255)    NULL,
  is_required    TINYINT(1)      NOT NULL DEFAULT 0,
  validation_regex VARCHAR(300)  NULL,
  min_length     SMALLINT UNSIGNED NULL,
  max_length     SMALLINT UNSIGNED NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_form_field_key (form_id, field_key),
  KEY ix_form_fields_order (form_id, sort_order),
  CONSTRAINT fk_form_fields_form FOREIGN KEY (form_id) REFERENCES lead_forms (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE lead_form_submissions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  form_id        INT UNSIGNED    NOT NULL,
  lead_id        BIGINT UNSIGNED NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  -- The submission exactly as received. Never edited.
  payload        JSON            NOT NULL,
  status         ENUM('received','processed','rejected_spam','rejected_validation','duplicate','failed') NOT NULL DEFAULT 'received',
  rejection_reason VARCHAR(300)  NULL,
  -- Anti-abuse evidence, kept because a spam classification that cannot be
  -- explained will eventually be overridden by someone who does not trust it.
  spam_score     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  fill_seconds   SMALLINT UNSIGNED NULL,
  honeypot_triggered TINYINT(1)  NOT NULL DEFAULT 0,
  captcha_score  DECIMAL(4,3)    NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,
  -- Consent as shown and as given.
  consent_given  TINYINT(1)      NULL,
  consent_text_snapshot VARCHAR(1000) NULL,
  session_id     CHAR(36)        NULL,
  landing_url    VARCHAR(500)    NULL,
  referrer_url   VARCHAR(500)    NULL,
  utm_source     VARCHAR(120)    NULL,
  utm_medium     VARCHAR(120)    NULL,
  utm_campaign   VARCHAR(160)    NULL,
  processed_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_form_submissions_form (form_id, created_at),
  KEY ix_form_submissions_status (status, created_at),
  KEY ix_form_submissions_lead (lead_id),
  KEY ix_form_submissions_ip (ip_address, created_at),
  CONSTRAINT fk_form_submissions_form FOREIGN KEY (form_id) REFERENCES lead_forms (id) ON DELETE CASCADE,
  CONSTRAINT fk_form_submissions_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_form_submissions_inquiry FOREIGN KEY (inquiry_id) REFERENCES inquiries (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- lead_shares
--
-- A lead handed to, or sold to, another organisation: referrals between
-- branches, a developer passing an enquiry to its appointed brokers, or the
-- platform selling a lead under a pay-per-lead plan.
--
-- `exclusivity` is the commercial crux. A lead sold exclusively is worth many
-- times one sold to five agencies, and the buyer must be able to see which they
-- bought. `accepted_at` and `rejected_at` support a return window — a lead with
-- a dead phone number is refundable, and disputes about that are constant.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_shares (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  lead_id        BIGINT UNSIGNED NOT NULL,
  from_organization_id BIGINT UNSIGNED NULL,
  to_organization_id BIGINT UNSIGNED NOT NULL,
  to_agent_id    BIGINT UNSIGNED NULL,
  share_type     ENUM('referral','sale','broadcast','branch_transfer','partner') NOT NULL DEFAULT 'referral',
  exclusivity    ENUM('exclusive','shared','open') NOT NULL DEFAULT 'shared',
  -- How many buyers this lead may be sold to in total, for `shared`.
  max_recipients TINYINT UNSIGNED NULL,
  recipient_index TINYINT UNSIGNED NULL,
  status         ENUM('offered','accepted','rejected','expired','refunded','withdrawn') NOT NULL DEFAULT 'offered',
  offered_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NULL,
  accepted_at    DATETIME(3)     NULL,
  rejected_at    DATETIME(3)     NULL,
  rejection_reason ENUM('invalid_contact','out_of_area','out_of_budget','duplicate','not_qualified','capacity','other') NULL,
  -- Commercials. Credits are the usual currency; `price` records the cash
  -- equivalent for revenue reporting.
  price          DECIMAL(12,2)   NULL,
  currency_code  CHAR(3)         NULL,
  credits_charged INT UNSIGNED   NULL,
  refunded_at    DATETIME(3)     NULL,
  refund_reason  VARCHAR(300)    NULL,
  -- Referral fee owed back to the sender if the lead converts. Settled through
  -- deal_commissions when the deal completes.
  referral_fee_percent DECIMAL(6,3) NULL,
  resulting_deal_id BIGINT UNSIGNED NULL,
  -- Whether the recipient may see the contact's details before accepting. The
  -- usual answer is no: masked until paid for.
  contact_revealed TINYINT(1)    NOT NULL DEFAULT 0,
  contact_revealed_at DATETIME(3) NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lead_shares_public (public_id),
  UNIQUE KEY uq_lead_share_recipient (lead_id, to_organization_id),
  KEY ix_lead_shares_to_org (to_organization_id, status, offered_at),
  KEY ix_lead_shares_from_org (from_organization_id, status, offered_at),
  KEY ix_lead_shares_expiry (status, expires_at),
  CONSTRAINT fk_lead_shares_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_shares_from FOREIGN KEY (from_organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_shares_to FOREIGN KEY (to_organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_shares_agent FOREIGN KEY (to_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_lead_shares_deal FOREIGN KEY (resulting_deal_id) REFERENCES deals (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- crm_daily_stats
--
-- The nightly rollup. Every CRM dashboard reads this and nothing else: without
-- it, "leads by stage this month per agent" scans the lead table and its
-- history on every page load, for every manager, all day.
--
-- Grain is (organisation, date, agent, source) with NULL meaning "all", so the
-- same table serves the agency total and the per-agent breakdown.
-- -----------------------------------------------------------------------------
CREATE TABLE crm_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  organization_id BIGINT UNSIGNED NOT NULL,
  agent_id       BIGINT UNSIGNED NULL,
  source_id      INT UNSIGNED    NULL,
  root_category_id INT UNSIGNED    NULL,
  leads_created  INT UNSIGNED    NOT NULL DEFAULT 0,
  leads_assigned INT UNSIGNED    NOT NULL DEFAULT 0,
  leads_contacted INT UNSIGNED   NOT NULL DEFAULT 0,
  leads_qualified INT UNSIGNED   NOT NULL DEFAULT 0,
  leads_won      INT UNSIGNED    NOT NULL DEFAULT 0,
  leads_lost     INT UNSIGNED    NOT NULL DEFAULT 0,
  calls_made     INT UNSIGNED    NOT NULL DEFAULT 0,
  calls_answered INT UNSIGNED    NOT NULL DEFAULT 0,
  call_seconds   INT UNSIGNED    NOT NULL DEFAULT 0,
  viewings_booked INT UNSIGNED   NOT NULL DEFAULT 0,
  viewings_completed INT UNSIGNED NOT NULL DEFAULT 0,
  activities_logged INT UNSIGNED NOT NULL DEFAULT 0,
  tasks_completed INT UNSIGNED   NOT NULL DEFAULT 0,
  deals_created  INT UNSIGNED    NOT NULL DEFAULT 0,
  deals_won      INT UNSIGNED    NOT NULL DEFAULT 0,
  deal_value_base DECIMAL(20,2)  NOT NULL DEFAULT 0,
  commission_base DECIMAL(20,2)  NOT NULL DEFAULT 0,
  -- Service quality. Median matters more than mean here: one lead answered
  -- three days late destroys an average that is otherwise fine.
  avg_first_response_minutes INT UNSIGNED NULL,
  median_first_response_minutes INT UNSIGNED NULL,
  sla_met_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  sla_breached_count INT UNSIGNED NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_crm_daily (stat_date, organization_id, agent_id, source_id, root_category_id),
  KEY ix_crm_daily_org (organization_id, stat_date),
  KEY ix_crm_daily_agent (agent_id, stat_date),
  CONSTRAINT fk_crm_daily_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_crm_daily_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0020', 'crm_and_leads');
