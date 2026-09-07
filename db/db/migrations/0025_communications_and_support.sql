-- =============================================================================
-- Liv Finder — 0025 · Communications, deliverability and support
-- =============================================================================
-- Migration 0011 gave notifications a template, a preference and a delivery
-- row. That is enough to send. It is nowhere near enough to keep sending.
--
-- A marketplace at scale sends millions of messages a month — alerts, lead
-- notifications, receipts, saved-search digests, campaign broadcasts — and the
-- thing that actually decides whether they arrive is reputation. Get it wrong
-- and the failure mode is silent and total: mail stops reaching inboxes, nobody
-- gets an error, and the first symptom is a mysterious drop in leads three
-- weeks later.
--
-- So the deliverability half of this migration is not administrative
-- decoration:
--
-- SUPPRESSION IS ABSOLUTE. `suppressions` is checked before every send, and it
-- outranks every preference, template and campaign. A hard bounce, a spam
-- complaint or an unsubscribe means we do not send again — full stop. Sending
-- to a known-bad address is precisely what destroys a sending domain.
--
-- AUTHENTICATION IS TRACKED. `sending_domains` holds SPF, DKIM and DMARC state
-- with verification timestamps, because an expired DKIM key looks like nothing
-- until every message starts landing in spam.
--
-- COMPLAINTS ARE COUNTED. `sender_reputation_daily` keeps bounce and complaint
-- rates per domain per day against the thresholds the mailbox providers
-- actually enforce (a complaint rate above 0.3% is where Gmail starts
-- throttling). A number you cannot see is a number you cannot defend.
--
-- The support half is smaller but shares one thing with the CRM in 0020: SLA
-- clocks. Support tickets reuse `sla_policies` and `sla_clocks` rather than
-- growing a parallel set — the policy table was built with `applies_to =
-- support_ticket` for exactly this reason.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · SENDING INFRASTRUCTURE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- messaging_providers
--
-- Who physically delivers. Multiple providers per channel is normal and
-- deliberate: transactional mail and marketing mail should never share a
-- sending reputation, and a provider outage should be survivable by failing
-- over rather than by waiting.
-- -----------------------------------------------------------------------------
CREATE TABLE messaging_providers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  channel        ENUM('email','sms','whatsapp','push','voice','in_app','webhook') NOT NULL DEFAULT 'email',
  provider_type  ENUM('sendgrid','ses','mailgun','postmark','sparkpost','twilio','messagebird','infobip','unifonic','firebase','apns','onesignal','meta_whatsapp','internal','other') NOT NULL DEFAULT 'other',
  -- Which traffic class this provider carries. Mixing them is the classic
  -- deliverability mistake.
  traffic_class  ENUM('transactional','marketing','both') NOT NULL DEFAULT 'transactional',
  credential_ref VARCHAR(255)    NULL,
  region         VARCHAR(60)     NULL,
  -- Failover order. Lower is tried first.
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 10,
  -- Throughput limits, so the sender paces rather than being throttled.
  max_per_second SMALLINT UNSIGNED NULL,
  max_per_day    INT UNSIGNED    NULL,
  sent_today     INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Cost, so channel choice can be an economic decision. WhatsApp is many
  -- times the price of SMS in some markets and the reverse in others.
  cost_per_message DECIMAL(10,6) NULL,
  currency_code  CHAR(3)         NULL,
  status         ENUM('active','degraded','paused','failed','disabled') NOT NULL DEFAULT 'active',
  last_health_check_at DATETIME(3) NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  supports_templates TINYINT(1)  NOT NULL DEFAULT 1,
  supports_scheduling TINYINT(1) NOT NULL DEFAULT 0,
  webhook_secret_ref VARCHAR(255) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_messaging_providers_code (code),
  KEY ix_messaging_providers_select (channel, traffic_class, status, priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- sending_domains
--
-- One domain we send mail from, with its authentication state.
--
-- Separating transactional and marketing subdomains
-- (mail.example.com vs news.example.com) means a campaign that generates
-- complaints cannot damage delivery of password resets and lead alerts. This is
-- the single most valuable structural decision in email deliverability and it
-- has to be made in the data, not at send time.
-- -----------------------------------------------------------------------------
CREATE TABLE sending_domains (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  domain         VARCHAR(191)    NOT NULL,
  provider_id    INT UNSIGNED    NULL,
  traffic_class  ENUM('transactional','marketing','both') NOT NULL DEFAULT 'transactional',
  organization_id BIGINT UNSIGNED NULL,
  -- Authentication. Each has its own verified-at, because they are configured
  -- separately and fail separately.
  spf_status     ENUM('unverified','valid','invalid','missing') NOT NULL DEFAULT 'unverified',
  spf_verified_at DATETIME(3)    NULL,
  dkim_selector  VARCHAR(60)     NULL,
  dkim_status    ENUM('unverified','valid','invalid','missing','expiring') NOT NULL DEFAULT 'unverified',
  dkim_verified_at DATETIME(3)   NULL,
  dkim_rotated_at DATETIME(3)    NULL,
  dmarc_status   ENUM('unverified','none','quarantine','reject','missing') NOT NULL DEFAULT 'unverified',
  dmarc_verified_at DATETIME(3)  NULL,
  dmarc_reports_to VARCHAR(255)  NULL,
  -- A dedicated IP has its own reputation and needs warming; a shared pool
  -- inherits the provider's. Which one this domain uses changes how aggressively
  -- volume may ramp.
  ip_pool        VARCHAR(60)     NULL,
  is_dedicated_ip TINYINT(1)     NOT NULL DEFAULT 0,
  warmup_stage   TINYINT UNSIGNED NULL,
  warmup_daily_cap INT UNSIGNED  NULL,
  -- Custom tracking domain, so click-tracking links carry our brand instead of
  -- the provider's — which also stops one customer's spam trap poisoning a
  -- shared tracking domain.
  tracking_domain VARCHAR(191)   NULL,
  tracking_domain_verified TINYINT(1) NOT NULL DEFAULT 0,
  status         ENUM('pending','verifying','active','degraded','suspended','retired') NOT NULL DEFAULT 'pending',
  reputation_score TINYINT UNSIGNED NULL,
  last_checked_at DATETIME(3)    NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sending_domains_domain (domain),
  KEY ix_sending_domains_status (status, traffic_class),
  KEY ix_sending_domains_checks (status, last_checked_at),
  CONSTRAINT fk_sending_domains_provider FOREIGN KEY (provider_id) REFERENCES messaging_providers (id) ON DELETE SET NULL,
  CONSTRAINT fk_sending_domains_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- sender_identities
--
-- The From addresses and their display names, per domain and per purpose.
-- `reply_to` is separate because replies to a lead alert should reach the
-- agent, not a no-reply black hole — and a no-reply address is itself a
-- deliverability negative with several mailbox providers.
-- -----------------------------------------------------------------------------
CREATE TABLE sender_identities (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  domain_id      INT UNSIGNED    NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  from_email     VARCHAR(255)    NOT NULL,
  from_name      VARCHAR(120)    NOT NULL,
  reply_to_email VARCHAR(255)    NULL,
  -- Where bounces are collected. A distinct return-path is what makes bounce
  -- processing reliable.
  return_path    VARCHAR(255)    NULL,
  purpose        ENUM('transactional','lead_alert','digest','marketing','billing','support','system','agent_relay') NOT NULL DEFAULT 'transactional',
  organization_id BIGINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NULL,
  signature_html MEDIUMTEXT      NULL,
  is_verified    TINYINT(1)      NOT NULL DEFAULT 0,
  verified_at    DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sender_identities_code (code, organization_id),
  UNIQUE KEY uq_sender_identities_email (from_email, organization_id),
  KEY ix_sender_identities_purpose (purpose, is_active),
  CONSTRAINT fk_sender_identities_domain FOREIGN KEY (domain_id) REFERENCES sending_domains (id) ON DELETE CASCADE,
  CONSTRAINT fk_sender_identities_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 2 · SUPPRESSION AND CONSENT
-- =============================================================================

-- -----------------------------------------------------------------------------
-- suppressions
--
-- The do-not-send list, and the most important table in this migration.
--
-- Checked before every send, ahead of preferences, templates and campaigns. Its
-- unique key is on the normalised destination so a lookup is one index dive on
-- the hot path.
--
-- `scope` distinguishes a global suppression (this address is dead everywhere)
-- from one limited to marketing (they unsubscribed from the newsletter but must
-- still receive their receipt). Conflating those either keeps mailing people
-- who asked you to stop, or stops sending people the transactional mail they
-- are entitled to — both are failures, in opposite directions.
-- -----------------------------------------------------------------------------
CREATE TABLE suppressions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  channel        ENUM('email','sms','whatsapp','push','voice','all') NOT NULL DEFAULT 'email',
  -- Lowercased email or E.164 phone. The unique key lives here.
  destination    VARCHAR(255)    NOT NULL,
  destination_hash CHAR(64)      NOT NULL,
  scope          ENUM('global','marketing','digest','alerts','organization') NOT NULL DEFAULT 'global',
  organization_id BIGINT UNSIGNED NULL,
  reason         ENUM('hard_bounce','soft_bounce_repeated','spam_complaint','unsubscribe','manual','list_unsubscribe','invalid_address','blocked','role_address','spam_trap','gdpr_erasure','account_closed') NOT NULL,
  reason_detail  VARCHAR(500)    NULL,
  source         ENUM('provider_webhook','user_action','admin','import','preference_centre','feedback_loop','system') NOT NULL DEFAULT 'provider_webhook',
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  -- Soft bounces get a cooling-off rather than a permanent block; a full
  -- mailbox is temporary. `expires_at` NULL means permanent.
  expires_at     DATETIME(3)     NULL,
  bounce_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_bounce_at DATETIME(3)     NULL,
  -- Removal is possible but must be attributable: someone re-subscribing is
  -- fine, an operator clearing the list to "fix" deliverability is not.
  removed_at     DATETIME(3)     NULL,
  removed_by_user_id BIGINT UNSIGNED NULL,
  removal_reason VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_suppression (channel, destination_hash, scope, organization_id),
  -- The pre-send check.
  KEY ix_suppressions_lookup (destination_hash, channel, removed_at),
  KEY ix_suppressions_reason (reason, created_at),
  KEY ix_suppressions_expiry (expires_at),
  KEY ix_suppressions_contact (contact_id),
  CONSTRAINT fk_suppressions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_suppressions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_suppressions_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- unsubscribe_tokens
--
-- One-click unsubscribe, as RFC 8058 requires and as Gmail and Yahoo now
-- enforce for bulk senders. The token must work without a login and without a
-- confirmation step, so it is a long random value hashed at rest.
--
-- Scoped tokens let the link unsubscribe from *this* digest rather than
-- everything, which is what keeps a mildly annoyed reader instead of losing
-- them entirely.
-- -----------------------------------------------------------------------------
CREATE TABLE unsubscribe_tokens (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  token_hash     CHAR(64)        NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  destination    VARCHAR(255)    NOT NULL,
  channel        ENUM('email','sms','whatsapp','push') NOT NULL DEFAULT 'email',
  scope          ENUM('global','marketing','digest','alerts','campaign','organization') NOT NULL DEFAULT 'marketing',
  campaign_id    BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  used_at        DATETIME(3)     NULL,
  use_count      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_unsubscribe_token (token_hash),
  KEY ix_unsubscribe_tokens_user (user_id, scope),
  KEY ix_unsubscribe_tokens_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · DELIVERY AND FEEDBACK
-- =============================================================================

-- -----------------------------------------------------------------------------
-- message_delivery_events
--
-- The provider event stream: accepted, delivered, opened, clicked, bounced,
-- complained, unsubscribed. Month-partitioned and unjoined, like the other
-- high-volume logs.
--
-- Two notes on honesty. `opened` is unreliable — Apple Mail Privacy Protection
-- pre-fetches every tracking pixel, so open rates from Apple clients are close
-- to fiction; `is_machine_open` marks what we can detect so the reporting can
-- exclude it rather than quietly inflating. And `bounce_class` separates hard
-- from soft, because treating them alike either suppresses recoverable
-- addresses or keeps hammering dead ones.
-- -----------------------------------------------------------------------------
CREATE TABLE message_delivery_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  event_type     ENUM('queued','sent','delivered','deferred','opened','clicked','bounced','complained','unsubscribed','failed','rejected','dropped') NOT NULL,
  channel        ENUM('email','sms','whatsapp','push','voice','in_app') NOT NULL DEFAULT 'email',
  -- Correlation back to what we sent. No FK: this table must never join.
  delivery_id    BIGINT UNSIGNED NULL,
  notification_id BIGINT UNSIGNED NULL,
  campaign_id    BIGINT UNSIGNED NULL,
  campaign_recipient_id BIGINT UNSIGNED NULL,
  enrolment_delivery_id BIGINT UNSIGNED NULL,
  provider_id    INT UNSIGNED    NULL,
  provider_message_id VARCHAR(191) NULL,
  domain_id      INT UNSIGNED    NULL,
  sender_identity_id INT UNSIGNED NULL,
  template_id    INT UNSIGNED    NULL,
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  destination_hash CHAR(64)      NULL,
  -- Recipient mailbox provider, so "we are being throttled by Gmail
  -- specifically" is visible rather than inferred.
  recipient_domain VARCHAR(120)  NULL,
  -- Bounce and failure detail.
  bounce_class   ENUM('hard','soft','block','technical','suppressed','unknown') NULL,
  smtp_code      VARCHAR(12)     NULL,
  reason         VARCHAR(500)    NULL,
  -- Engagement detail.
  clicked_url    VARCHAR(1000)   NULL,
  is_machine_open TINYINT(1)     NOT NULL DEFAULT 0,
  device_type    ENUM('desktop','mobile','tablet','app','unknown') NOT NULL DEFAULT 'unknown',
  client_name    VARCHAR(80)     NULL,
  ip_address     VARBINARY(16)   NULL,
  country_id     BIGINT UNSIGNED NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_delivery_events_delivery (delivery_id, occurred_at),
  KEY ix_delivery_events_campaign (campaign_id, event_type, occurred_at),
  KEY ix_delivery_events_type (event_type, occurred_at),
  KEY ix_delivery_events_domain (domain_id, event_type, occurred_at),
  KEY ix_delivery_events_recipient (destination_hash, occurred_at),
  KEY ix_delivery_events_provider_msg (provider_message_id)
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
-- sender_reputation_daily
--
-- Per domain, per recipient mailbox provider, per day.
--
-- The thresholds this table exists to watch are not arbitrary: mailbox
-- providers begin throttling around a 0.3% complaint rate and a bounce rate
-- above roughly 2% marks a sender as careless. Both are computable only if the
-- numerator and denominator are kept per provider — an overall complaint rate
-- of 0.1% can hide 1.5% at Gmail, which is where most of the audience is.
-- -----------------------------------------------------------------------------
CREATE TABLE sender_reputation_daily (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  domain_id      INT UNSIGNED    NOT NULL,
  provider_id    INT UNSIGNED    NULL,
  -- 'gmail.com', 'outlook.com', 'all'.
  recipient_domain VARCHAR(120)  NOT NULL DEFAULT 'all',
  traffic_class  ENUM('transactional','marketing','all') NOT NULL DEFAULT 'all',
  sent           INT UNSIGNED    NOT NULL DEFAULT 0,
  delivered      INT UNSIGNED    NOT NULL DEFAULT 0,
  deferred       INT UNSIGNED    NOT NULL DEFAULT 0,
  hard_bounces   INT UNSIGNED    NOT NULL DEFAULT 0,
  soft_bounces   INT UNSIGNED    NOT NULL DEFAULT 0,
  blocks         INT UNSIGNED    NOT NULL DEFAULT 0,
  complaints     INT UNSIGNED    NOT NULL DEFAULT 0,
  unsubscribes   INT UNSIGNED    NOT NULL DEFAULT 0,
  opens          INT UNSIGNED    NOT NULL DEFAULT 0,
  machine_opens  INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_opens   INT UNSIGNED    NOT NULL DEFAULT 0,
  clicks         INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_clicks  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Rates stored because every alert compares against them and recomputing
  -- them per check is waste.
  delivery_rate  DECIMAL(7,4)    NULL,
  bounce_rate    DECIMAL(7,4)    NULL,
  complaint_rate DECIMAL(7,4)    NULL,
  open_rate      DECIMAL(7,4)    NULL,
  click_rate     DECIMAL(7,4)    NULL,
  -- Set when a rate crossed the provider's tolerance, so a bad day is on the
  -- record rather than reconstructed later.
  threshold_breached SET('bounce','complaint','block','delivery') NULL,
  alerted_at     DATETIME(3)     NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_sender_reputation (stat_date, domain_id, provider_id, recipient_domain, traffic_class),
  KEY ix_sender_reputation_domain (domain_id, stat_date),
  KEY ix_sender_reputation_breach (threshold_breached, stat_date),
  CONSTRAINT fk_sender_reputation_domain FOREIGN KEY (domain_id) REFERENCES sending_domains (id) ON DELETE CASCADE,
  CONSTRAINT fk_sender_reputation_provider FOREIGN KEY (provider_id) REFERENCES messaging_providers (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · CAMPAIGNS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- broadcast_campaigns
--
-- One-off sends to a segment: a new-development launch, a market report, a
-- price-drop digest. Distinct from `nurture_campaigns` in 0020, which are
-- per-lead drip sequences — a broadcast has one audience, one moment and one
-- set of results.
--
-- `approval_status` exists because a broadcast is irreversible. Sending 80,000
-- emails with the wrong link is not something an undo button fixes, and a
-- second pair of eyes is the only control that works.
-- -----------------------------------------------------------------------------
CREATE TABLE broadcast_campaigns (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  name           VARCHAR(200)    NOT NULL,
  campaign_type  ENUM('newsletter','announcement','listing_digest','market_report','event','promotion','re_engagement','transactional_bulk','survey') NOT NULL DEFAULT 'newsletter',
  channel        ENUM('email','sms','whatsapp','push','multi') NOT NULL DEFAULT 'email',
  sender_identity_id INT UNSIGNED NULL,
  provider_id    INT UNSIGNED    NULL,
  template_id    INT UNSIGNED    NULL,
  subject        VARCHAR(255)    NULL,
  preheader      VARCHAR(255)    NULL,
  body_html      LONGTEXT        NULL,
  body_text      MEDIUMTEXT      NULL,
  language_id    SMALLINT UNSIGNED NULL,
  -- Audience. The segment definition is kept alongside the resolved count so
  -- "who did this actually go to" is answerable after the fact.
  segment_definition JSON        NULL,
  segment_snapshot_at DATETIME(3) NULL,
  audience_size  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Scheduling. Timezone-aware sending means "9am local" rather than one
  -- global blast at 9am UTC.
  scheduled_at   DATETIME(3)     NULL,
  send_in_recipient_timezone TINYINT(1) NOT NULL DEFAULT 0,
  throttle_per_hour INT UNSIGNED NULL,
  -- Approval. See the table comment.
  approval_status ENUM('not_required','pending','approved','rejected') NOT NULL DEFAULT 'pending',
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  rejection_reason VARCHAR(500)  NULL,
  status         ENUM('draft','scheduled','sending','paused','sent','cancelled','failed') NOT NULL DEFAULT 'draft',
  started_at     DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  -- Results, refreshed from the delivery events.
  queued_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  sent_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  delivered_count INT UNSIGNED   NOT NULL DEFAULT 0,
  bounced_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  opened_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  clicked_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unsubscribed_count INT UNSIGNED NOT NULL DEFAULT 0,
  complained_count INT UNSIGNED  NOT NULL DEFAULT 0,
  suppressed_count INT UNSIGNED  NOT NULL DEFAULT 0,
  -- Attributed outcomes, which is what justifies the next campaign.
  leads_generated INT UNSIGNED   NOT NULL DEFAULT 0,
  revenue_attributed DECIMAL(16,2) NOT NULL DEFAULT 0,
  -- A/B subject-line testing on a holdout before the main send.
  ab_test_enabled TINYINT(1)     NOT NULL DEFAULT 0,
  ab_test_percent TINYINT UNSIGNED NULL,
  ab_winning_variant VARCHAR(40) NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_broadcast_campaigns_public (public_id),
  KEY ix_broadcast_campaigns_schedule (status, scheduled_at),
  KEY ix_broadcast_campaigns_org (organization_id, status, created_at),
  KEY ix_broadcast_campaigns_approval (approval_status, created_at),
  CONSTRAINT fk_broadcast_campaigns_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_broadcast_campaigns_sender FOREIGN KEY (sender_identity_id) REFERENCES sender_identities (id) ON DELETE SET NULL,
  CONSTRAINT fk_broadcast_campaigns_provider FOREIGN KEY (provider_id) REFERENCES messaging_providers (id) ON DELETE SET NULL,
  CONSTRAINT fk_broadcast_campaigns_template FOREIGN KEY (template_id) REFERENCES notification_templates (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- campaign_recipients
--
-- The resolved send list with per-recipient state. Materialised at send time
-- rather than re-evaluated, so a campaign that is paused and resumed does not
-- re-send to people who already received it, and so the suppression decision
-- for each address is recorded rather than recomputed.
-- -----------------------------------------------------------------------------
CREATE TABLE campaign_recipients (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  campaign_id    BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  subscriber_id  BIGINT UNSIGNED NULL,
  destination    VARCHAR(255)    NOT NULL,
  destination_hash CHAR(64)      NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  timezone       VARCHAR(64)     NULL,
  ab_variant     VARCHAR(40)     NULL,
  -- Personalisation resolved at send time, kept so the exact message can be
  -- reconstructed when someone asks what they were sent.
  merge_data     JSON            NULL,
  status         ENUM('pending','suppressed','queued','sent','delivered','bounced','failed','opened','clicked','unsubscribed','complained') NOT NULL DEFAULT 'pending',
  suppression_reason VARCHAR(120) NULL,
  provider_message_id VARCHAR(191) NULL,
  scheduled_for  DATETIME(3)     NULL,
  sent_at        DATETIME(3)     NULL,
  delivered_at   DATETIME(3)     NULL,
  opened_at      DATETIME(3)     NULL,
  clicked_at     DATETIME(3)     NULL,
  bounced_at     DATETIME(3)     NULL,
  failure_reason VARCHAR(500)    NULL,
  open_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  click_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_campaign_recipient (campaign_id, destination_hash),
  -- The sender's queue.
  KEY ix_campaign_recipients_send (campaign_id, status, scheduled_for),
  KEY ix_campaign_recipients_user (user_id, campaign_id),
  KEY ix_campaign_recipients_contact (contact_id),
  KEY ix_campaign_recipients_provider_msg (provider_message_id),
  CONSTRAINT fk_campaign_recipients_campaign FOREIGN KEY (campaign_id) REFERENCES broadcast_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_campaign_recipients_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_campaign_recipients_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Trackable links inside a campaign, so click-through is per link rather than
-- per message — "which of the six properties did they click" is the useful
-- question, and it feeds straight back into the affinity profile from 0022.
CREATE TABLE campaign_links (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  campaign_id    BIGINT UNSIGNED NOT NULL,
  link_key       VARCHAR(60)     NOT NULL,
  destination_url VARCHAR(1000)  NOT NULL,
  label          VARCHAR(200)    NULL,
  listing_id     BIGINT UNSIGNED NULL,
  position       SMALLINT UNSIGNED NULL,
  click_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_click_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_campaign_link (campaign_id, link_key),
  KEY ix_campaign_links_listing (listing_id),
  CONSTRAINT fk_campaign_links_campaign FOREIGN KEY (campaign_id) REFERENCES broadcast_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_campaign_links_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- push_devices
--
-- Device tokens for mobile and web push. Tokens rotate and expire constantly;
-- `status` and `last_seen_at` are what stop the platform pushing to a hundred
-- thousand dead tokens and being rate-limited for it.
-- -----------------------------------------------------------------------------
CREATE TABLE push_devices (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  platform       ENUM('ios','android','web','huawei') NOT NULL,
  token_hash     CHAR(64)        NOT NULL,
  token_ref      VARCHAR(255)    NULL,
  provider_id    INT UNSIGNED    NULL,
  app_version    VARCHAR(40)     NULL,
  os_version     VARCHAR(40)     NULL,
  device_model   VARCHAR(80)     NULL,
  language_id    SMALLINT UNSIGNED NULL,
  timezone       VARCHAR(64)     NULL,
  status         ENUM('active','stale','unregistered','revoked','failed') NOT NULL DEFAULT 'active',
  failure_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_seen_at   DATETIME(3)     NULL,
  last_push_at   DATETIME(3)     NULL,
  registered_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_push_devices_token (token_hash),
  KEY ix_push_devices_user (user_id, status),
  KEY ix_push_devices_stale (status, last_seen_at),
  CONSTRAINT fk_push_devices_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_push_devices_provider FOREIGN KEY (provider_id) REFERENCES messaging_providers (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 5 · SUPPORT
-- =============================================================================

-- -----------------------------------------------------------------------------
-- support_queues
--
-- Where tickets land and who owns them. Separate queues for agency support,
-- consumer support, billing and compliance, because those are different teams
-- with different hours and very different urgency.
--
-- SLA is by reference to `sla_policies` from 0020 rather than duplicated here —
-- that table was written with `applies_to = 'support_ticket'` for this.
-- -----------------------------------------------------------------------------
CREATE TABLE support_queues (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  audience       ENUM('consumer','agency','developer','internal','partner','all') NOT NULL DEFAULT 'all',
  sla_policy_id  INT UNSIGNED    NULL,
  default_assignee_user_id BIGINT UNSIGNED NULL,
  routing_email  VARCHAR(255)    NULL,
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  business_hours_only TINYINT(1) NOT NULL DEFAULT 0,
  auto_close_after_days SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_support_queues_code (code),
  KEY ix_support_queues_active (is_active, audience),
  CONSTRAINT fk_support_queues_sla FOREIGN KEY (sla_policy_id) REFERENCES sla_policies (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- support_tickets
--
-- `first_response_at` and `resolved_at` are stored rather than derived because
-- every support metric that matters is built from them, and because the SLA
-- clock in 0020 stops against them.
-- -----------------------------------------------------------------------------
CREATE TABLE support_tickets (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  queue_id       INT UNSIGNED    NOT NULL,
  subject        VARCHAR(255)    NOT NULL,
  description    MEDIUMTEXT      NULL,
  -- Who asked. Requesters are frequently not registered users, so identity is
  -- captured directly as well as by reference.
  requester_user_id BIGINT UNSIGNED NULL,
  requester_contact_id BIGINT UNSIGNED NULL,
  requester_name VARCHAR(200)    NULL,
  requester_email VARCHAR(255)   NULL,
  requester_phone VARCHAR(32)    NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  -- What it is about, so a ticket can be opened straight from the object.
  subject_type   ENUM('listing','account','payment','subscription','lead','agent','organization','media','feed','other') NOT NULL DEFAULT 'other',
  subject_id     BIGINT UNSIGNED NULL,
  ticket_type    ENUM('question','problem','bug','feature_request','billing','complaint','abuse_report','verification','data_request','other') NOT NULL DEFAULT 'question',
  category       VARCHAR(80)     NULL,
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  status         ENUM('new','open','pending_customer','pending_internal','on_hold','resolved','closed','merged','spam') NOT NULL DEFAULT 'new',
  channel        ENUM('web_form','email','chat','phone','whatsapp','in_app','api','internal') NOT NULL DEFAULT 'web_form',
  assigned_to_user_id BIGINT UNSIGNED NULL,
  assigned_at    DATETIME(3)     NULL,
  -- Timing, for the SLA and for every report.
  first_response_at DATETIME(3)  NULL,
  first_response_minutes INT UNSIGNED NULL,
  last_customer_reply_at DATETIME(3) NULL,
  last_agent_reply_at DATETIME(3) NULL,
  resolved_at    DATETIME(3)     NULL,
  resolution_minutes INT UNSIGNED NULL,
  closed_at      DATETIME(3)     NULL,
  reopened_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  -- Reopening is the honest measure of whether it was really resolved.
  last_reopened_at DATETIME(3)   NULL,
  merged_into_ticket_id BIGINT UNSIGNED NULL,
  resolution_note TEXT           NULL,
  resolution_code ENUM('resolved','workaround','duplicate','not_reproducible','by_design','wont_fix','no_response','spam') NULL,
  language_id    SMALLINT UNSIGNED NULL,
  message_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Satisfaction, asked once on resolution.
  satisfaction_rating TINYINT UNSIGNED NULL,
  satisfaction_comment VARCHAR(1000) NULL,
  satisfaction_at DATETIME(3)    NULL,
  tags           JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_support_tickets_public (public_id),
  UNIQUE KEY uq_support_tickets_reference (reference),
  -- The agent's working view.
  KEY ix_tickets_queue (queue_id, status, priority, created_at),
  KEY ix_tickets_assignee (assigned_to_user_id, status, updated_at),
  KEY ix_tickets_requester (requester_user_id, created_at),
  KEY ix_tickets_org (organization_id, status, created_at),
  KEY ix_tickets_subject (subject_type, subject_id),
  KEY ix_tickets_email (requester_email, created_at),
  CONSTRAINT fk_tickets_queue FOREIGN KEY (queue_id) REFERENCES support_queues (id),
  CONSTRAINT fk_tickets_user FOREIGN KEY (requester_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_tickets_contact FOREIGN KEY (requester_contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_tickets_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_tickets_merged FOREIGN KEY (merged_into_ticket_id) REFERENCES support_tickets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE support_ticket_messages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  ticket_id      BIGINT UNSIGNED NOT NULL,
  sequence_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  author_type    ENUM('customer','agent','system','automation') NOT NULL DEFAULT 'customer',
  author_user_id BIGINT UNSIGNED NULL,
  author_name    VARCHAR(200)    NULL,
  author_email   VARCHAR(255)    NULL,
  body           MEDIUMTEXT      NOT NULL,
  body_html      MEDIUMTEXT      NULL,
  -- Internal notes are invisible to the customer. The single most important
  -- flag on this table, and the one most often got wrong.
  is_internal_note TINYINT(1)    NOT NULL DEFAULT 0,
  channel        ENUM('web','email','chat','phone','whatsapp','api','internal') NOT NULL DEFAULT 'web',
  -- Inbound email correlation, so replies thread instead of opening new
  -- tickets.
  email_message_id VARCHAR(255)  NULL,
  email_in_reply_to VARCHAR(255) NULL,
  attachment_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  delivered_at   DATETIME(3)     NULL,
  read_at        DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ticket_message_seq (ticket_id, sequence_number),
  KEY ix_ticket_messages_ticket (ticket_id, created_at),
  KEY ix_ticket_messages_email (email_message_id),
  CONSTRAINT fk_ticket_messages_ticket FOREIGN KEY (ticket_id) REFERENCES support_tickets (id) ON DELETE CASCADE,
  CONSTRAINT fk_ticket_messages_user FOREIGN KEY (author_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Reusable replies. Tracked usage so the most-used ones reveal what the product
-- keeps failing to explain — a canned response used 4,000 times is a design
-- brief, not a support win.
CREATE TABLE canned_responses (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  queue_id       INT UNSIGNED    NULL,
  code           VARCHAR(60)     NOT NULL,
  title          VARCHAR(200)    NOT NULL,
  body           MEDIUMTEXT      NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  category       VARCHAR(80)     NULL,
  merge_fields   JSON            NULL,
  usage_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  last_used_at   DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_canned_responses_code (code, language_id),
  KEY ix_canned_responses_queue (queue_id, is_active),
  CONSTRAINT fk_canned_responses_queue FOREIGN KEY (queue_id) REFERENCES support_queues (id) ON DELETE CASCADE,
  CONSTRAINT fk_canned_responses_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 6 · KNOWLEDGE BASE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- kb_categories / kb_articles / kb_article_translations
--
-- Help content, with the same i18n and SEO discipline as the rest of the
-- schema — help pages are heavily indexed and frequently a market's first
-- organic entry point, so they get a slug history, meta and hreflang like any
-- other public URL.
--
-- `helpful_count` / `unhelpful_count` on the article and `kb_article_feedback`
-- behind them mean the worst articles are findable, which is the only way a
-- knowledge base improves rather than accumulating.
-- -----------------------------------------------------------------------------
CREATE TABLE kb_categories (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  parent_id      INT UNSIGNED    NULL,
  slug           VARCHAR(120)    NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  icon           VARCHAR(60)     NULL,
  audience       ENUM('consumer','agency','developer','internal','all') NOT NULL DEFAULT 'all',
  depth          TINYINT UNSIGNED NOT NULL DEFAULT 0,
  path           VARCHAR(500)    NULL,
  article_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_visible     TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kb_categories_slug (parent_id, slug),
  KEY ix_kb_categories_visible (is_visible, audience, sort_order),
  CONSTRAINT fk_kb_categories_parent FOREIGN KEY (parent_id) REFERENCES kb_categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE kb_articles (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  category_id    INT UNSIGNED    NULL,
  slug           VARCHAR(200)    NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  summary        VARCHAR(500)    NULL,
  body           LONGTEXT        NOT NULL,
  audience       ENUM('consumer','agency','developer','internal','all') NOT NULL DEFAULT 'all',
  article_type   ENUM('how_to','faq','troubleshooting','policy','glossary','release_note','announcement') NOT NULL DEFAULT 'how_to',
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  status         ENUM('draft','in_review','published','outdated','archived') NOT NULL DEFAULT 'draft',
  published_at   DATETIME(3)     NULL,
  -- Content rots. A review date makes staleness visible instead of implicit.
  last_reviewed_at DATETIME(3)   NULL,
  next_review_due DATE           NULL,
  author_user_id BIGINT UNSIGNED NULL,
  reviewer_user_id BIGINT UNSIGNED NULL,
  -- Engagement and, more usefully, deflection: how often reading this stopped
  -- a ticket being opened.
  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  helpful_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unhelpful_count INT UNSIGNED   NOT NULL DEFAULT 0,
  ticket_deflection_count INT UNSIGNED NOT NULL DEFAULT 0,
  linked_ticket_count INT UNSIGNED NOT NULL DEFAULT 0,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  related_article_ids JSON       NULL,
  keywords       JSON            NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_kb_articles_public (public_id),
  UNIQUE KEY uq_kb_articles_slug (slug, language_id),
  KEY ix_kb_articles_category (category_id, status, published_at),
  KEY ix_kb_articles_review (status, next_review_due),
  KEY ix_kb_articles_popular (status, view_count),
  CONSTRAINT fk_kb_articles_category FOREIGN KEY (category_id) REFERENCES kb_categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_kb_articles_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE kb_article_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  article_id     BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  slug           VARCHAR(200)    NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  summary        VARCHAR(500)    NULL,
  body           LONGTEXT        NOT NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  translation_status ENUM('machine','human_reviewed','professional','outdated') NOT NULL DEFAULT 'machine',
  -- Set when the source article changed after this translation was made, so
  -- stale translations are visible rather than silently wrong.
  source_version SMALLINT UNSIGNED NULL,
  is_outdated    TINYINT(1)      NOT NULL DEFAULT 0,
  translated_at  DATETIME(3)     NULL,
  translated_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kb_translation (article_id, language_id),
  UNIQUE KEY uq_kb_translation_slug (language_id, slug),
  KEY ix_kb_translations_outdated (is_outdated, language_id),
  CONSTRAINT fk_kb_translations_article FOREIGN KEY (article_id) REFERENCES kb_articles (id) ON DELETE CASCADE,
  CONSTRAINT fk_kb_translations_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE kb_article_feedback (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  article_id     BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  was_helpful    TINYINT(1)      NOT NULL,
  comment        VARCHAR(1000)   NULL,
  -- What they were trying to do, when they tell us. This is where the next
  -- article comes from.
  search_query   VARCHAR(300)    NULL,
  -- Set if they opened a ticket anyway, which is the clearest signal that the
  -- article failed.
  resulted_in_ticket_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_kb_feedback_article (article_id, was_helpful, created_at),
  KEY ix_kb_feedback_unhelpful (was_helpful, created_at),
  CONSTRAINT fk_kb_feedback_article FOREIGN KEY (article_id) REFERENCES kb_articles (id) ON DELETE CASCADE,
  CONSTRAINT fk_kb_feedback_ticket FOREIGN KEY (resulted_in_ticket_id) REFERENCES support_tickets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0025', 'communications_and_support');
