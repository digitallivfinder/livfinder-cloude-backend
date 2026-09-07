-- =============================================================================
-- Liv Finder — 0008 · Engagement
-- =============================================================================
-- Inquiries (leads), messaging, favourites, saved searches, bookings, offers,
-- reviews and notifications.
--
-- A note on counters, because the audit was specific about this. It found tab
-- and summary counts across Inquiries, Offers, Bookings, Reviews, Payments,
-- Billing and Payouts to be "hardcoded numbers that don't match the real
-- underlying fixture data", so a tab labelled "New (12)" showed two rows. The
-- schema's answer is that every such number has exactly one source: either it is
-- a live `COUNT(*)` served by an index designed for it (which is why the status
-- columns lead the composite indexes below), or it is a maintained counter on a
-- parent row updated in the same transaction as the fact it counts. There is no
-- third category, and no place for a literal.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- inquiries — the lead
--
-- `user_id` is nullable: most high-value enquiries come from people who have not
-- registered, and forcing signup before contact is how a marketplace loses its
-- leads. Contact details are therefore captured on the row itself.
-- -----------------------------------------------------------------------------
CREATE TABLE inquiries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(32)     NOT NULL,

  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  -- Denormalised from the listing so the agency inbox filters without a join,
  -- and so a lead survives its listing being deleted.
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,

  user_id        BIGINT UNSIGNED NULL,
  name           VARCHAR(200)    NOT NULL,
  email          VARCHAR(255)    NULL,
  phone          VARCHAR(40)     NULL,
  preferred_language_id SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,

  -- Which button produced this lead. The audit found Call and WhatsApp inert;
  -- once wired, attribution by channel is how their value gets proven.
  channel        ENUM('form','email','phone','whatsapp','chat','api','import','walk_in') NOT NULL DEFAULT 'form',
  inquiry_type   ENUM('general','viewing','callback','brochure','floor_plan','price','availability','offer','valuation','charter') NOT NULL DEFAULT 'general',
  subject        VARCHAR(255)    NULL,
  message        TEXT            NULL,

  status         ENUM('new','contacted','qualified','viewing_scheduled','negotiating','won','lost','closed','spam') NOT NULL DEFAULT 'new',
  -- Kept separate from `status` so an unqualified-but-urgent lead can still sort
  -- to the top of the queue.
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  -- Populated when status becomes 'lost'/'closed'; feeds the conversion reports.
  outcome_reason VARCHAR(255)    NULL,

  assigned_to_agent_id BIGINT UNSIGNED NULL,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  assigned_at    DATETIME(3)     NULL,

  -- Response-time SLA tracking. `first_response_at` minus `created_at` is the
  -- metric shown on agent and agency profiles, so it is stored rather than
  -- recomputed from the message log.
  first_response_at DATETIME(3)  NULL,
  first_response_minutes INT UNSIGNED NULL,
  last_activity_at DATETIME(3)   NULL,
  closed_at      DATETIME(3)     NULL,

  -- Marketing attribution, captured at submission.
  source_url     VARCHAR(700)    NULL,
  referrer_url   VARCHAR(700)    NULL,
  utm_source     VARCHAR(120)    NULL,
  utm_medium     VARCHAR(120)    NULL,
  utm_campaign   VARCHAR(160)    NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,

  -- Anti-abuse. Scored on submission; anything above threshold is quarantined
  -- rather than deleted, so false positives are recoverable.
  spam_score     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  is_spam        TINYINT(1)      NOT NULL DEFAULT 0,
  is_duplicate   TINYINT(1)      NOT NULL DEFAULT 0,
  duplicate_of_id BIGINT UNSIGNED NULL,

  budget_min     DECIMAL(18,2)   NULL,
  budget_max     DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_inquiries_public_id (public_id),
  UNIQUE KEY uq_inquiries_reference (reference),
  -- Status leads these composites because every inbox view is scoped by status,
  -- and because the tab counts are served straight off the index prefix.
  KEY ix_inquiries_org_status (organization_id, status, created_at),
  KEY ix_inquiries_account_status (account_id, status, created_at),
  KEY ix_inquiries_agent_status (assigned_to_agent_id, status, created_at),
  KEY ix_inquiries_listing (listing_id, status),
  KEY ix_inquiries_user (user_id, created_at),
  KEY ix_inquiries_email (email),
  KEY ix_inquiries_phone (phone),
  KEY ix_inquiries_queue (status, priority, created_at),
  KEY ix_inquiries_channel (channel, created_at),
  KEY ix_inquiries_spam (is_spam, created_at),
  KEY ix_inquiries_campaign (utm_source, utm_campaign, created_at),
  KEY ix_inquiries_deleted (deleted_at),
  CONSTRAINT fk_inquiries_listing   FOREIGN KEY (listing_id)           REFERENCES listings (id)      ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_project   FOREIGN KEY (project_id)           REFERENCES projects (id)      ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_account   FOREIGN KEY (account_id)           REFERENCES accounts (id)      ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_org       FOREIGN KEY (organization_id)      REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_agent     FOREIGN KEY (agent_id)             REFERENCES agents (id)        ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_assignee  FOREIGN KEY (assigned_to_agent_id) REFERENCES agents (id)        ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_assignee_user FOREIGN KEY (assigned_to_user_id) REFERENCES users (id)      ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_user      FOREIGN KEY (user_id)              REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_category  FOREIGN KEY (category_id)          REFERENCES categories (id)    ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_location  FOREIGN KEY (location_id)          REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_country   FOREIGN KEY (country_id)           REFERENCES locations (id)     ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_duplicate FOREIGN KEY (duplicate_of_id)      REFERENCES inquiries (id)     ON DELETE SET NULL,
  CONSTRAINT fk_inquiries_language  FOREIGN KEY (preferred_language_id) REFERENCES languages (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE inquiry_notes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  inquiry_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  note           TEXT            NOT NULL,
  -- Internal notes are never exposed to the enquirer; customer-visible ones are.
  is_internal    TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_inquiry_notes (inquiry_id, created_at),
  CONSTRAINT fk_inquiry_notes_inquiry FOREIGN KEY (inquiry_id) REFERENCES inquiries (id) ON DELETE CASCADE,
  CONSTRAINT fk_inquiry_notes_user    FOREIGN KEY (user_id)    REFERENCES users (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE inquiry_status_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  inquiry_id     BIGINT UNSIGNED NOT NULL,
  from_status    VARCHAR(40)     NULL,
  to_status      VARCHAR(40)     NOT NULL,
  reason         VARCHAR(500)    NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  changed_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_inquiry_status_history (inquiry_id, changed_at),
  CONSTRAINT fk_ish_inquiry FOREIGN KEY (inquiry_id)         REFERENCES inquiries (id) ON DELETE CASCADE,
  CONSTRAINT fk_ish_user    FOREIGN KEY (changed_by_user_id) REFERENCES users (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Messaging
--
-- Conversations are separate from inquiries: an enquiry is a lead record with a
-- sales lifecycle, a conversation is a thread. A conversation may originate from
-- an enquiry (`inquiry_id`) or stand alone.
-- -----------------------------------------------------------------------------
CREATE TABLE conversations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject        VARCHAR(255)    NULL,
  listing_id     BIGINT UNSIGNED NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  status         ENUM('open','archived','closed','blocked') NOT NULL DEFAULT 'open',
  -- Denormalised thread summary so an inbox list renders from this table alone,
  -- without a correlated subquery per row for "last message".
  last_message_at DATETIME(3)    NULL,
  last_message_preview VARCHAR(255) NULL,
  last_message_by_user_id BIGINT UNSIGNED NULL,
  message_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversations_public_id (public_id),
  KEY ix_conversations_listing (listing_id),
  KEY ix_conversations_inquiry (inquiry_id),
  KEY ix_conversations_org (organization_id, status, last_message_at),
  KEY ix_conversations_recent (status, last_message_at),
  CONSTRAINT fk_conversations_listing FOREIGN KEY (listing_id)      REFERENCES listings (id)      ON DELETE SET NULL,
  CONSTRAINT fk_conversations_inquiry FOREIGN KEY (inquiry_id)      REFERENCES inquiries (id)     ON DELETE SET NULL,
  CONSTRAINT fk_conversations_org     FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE conversation_participants (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  role           ENUM('buyer','seller','agent','admin','observer') NOT NULL DEFAULT 'buyer',
  -- Per-participant unread count, maintained on write. The alternative —
  -- counting messages newer than last_read_at on every inbox render — is a scan
  -- per thread per page load.
  unread_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  last_read_at   DATETIME(3)     NULL,
  is_muted       TINYINT(1)      NOT NULL DEFAULT 0,
  joined_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  left_at        DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversation_participants (conversation_id, user_id),
  KEY ix_conversation_participants_user (user_id, unread_count),
  KEY ix_conversation_participants_agent (agent_id),
  CONSTRAINT fk_cp_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_cp_user         FOREIGN KEY (user_id)         REFERENCES users (id)         ON DELETE CASCADE,
  CONSTRAINT fk_cp_agent        FOREIGN KEY (agent_id)        REFERENCES agents (id)        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE messages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  conversation_id BIGINT UNSIGNED NOT NULL,
  sender_user_id BIGINT UNSIGNED NULL,
  -- System messages (status changes, automated follow-ups) have no sender.
  sender_type    ENUM('user','agent','system','bot') NOT NULL DEFAULT 'user',
  body           TEXT            NOT NULL,
  body_format    ENUM('plain','html','markdown') NOT NULL DEFAULT 'plain',
  status         ENUM('sent','delivered','read','failed','deleted') NOT NULL DEFAULT 'sent',
  -- How it was actually delivered, so a WhatsApp reply and an in-app reply live
  -- in one thread.
  channel        ENUM('in_app','email','whatsapp','sms') NOT NULL DEFAULT 'in_app',
  is_flagged     TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  edited_at      DATETIME(3)     NULL,
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_messages_public_id (public_id),
  -- Thread rendering is always "newest N in this conversation".
  KEY ix_messages_conversation (conversation_id, created_at),
  KEY ix_messages_sender (sender_user_id, created_at),
  KEY ix_messages_flagged (is_flagged, created_at),
  CONSTRAINT fk_messages_conversation FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE,
  CONSTRAINT fk_messages_sender       FOREIGN KEY (sender_user_id)  REFERENCES users (id)         ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE message_attachments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  message_id     BIGINT UNSIGNED NOT NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  file_name      VARCHAR(255)    NOT NULL,
  file_url       VARCHAR(700)    NOT NULL,
  mime_type      VARCHAR(120)    NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_message_attachments (message_id),
  CONSTRAINT fk_message_attachments_message FOREIGN KEY (message_id)     REFERENCES messages (id)     ON DELETE CASCADE,
  CONSTRAINT fk_message_attachments_asset   FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Favourites and collections
--
-- `favourites` is the heart toggle; `collections` are named lists ("Palm villas
-- shortlist"), which is also what the admin portal's Collections surface curates
-- for editorial use.
-- -----------------------------------------------------------------------------
CREATE TABLE favourites (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  -- Snapshot of the price when favourited, so the UI can say "reduced by AED
  -- 500,000 since you saved it" without reading the price-history table.
  price_at_save  DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_favourites (user_id, listing_id),
  -- Reverse lookup drives the favourite_count rollup and "N people saved this".
  KEY ix_favourites_listing (listing_id, created_at),
  KEY ix_favourites_user_recent (user_id, created_at),
  CONSTRAINT fk_favourites_user    FOREIGN KEY (user_id)    REFERENCES users (id)    ON DELETE CASCADE,
  CONSTRAINT fk_favourites_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE collections (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  -- Editorial collections ("The 10 finest Palm Jumeirah villas") have no owner
  -- and are curated by staff; user collections are private shortlists.
  collection_type ENUM('user','editorial','campaign') NOT NULL DEFAULT 'user',
  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NULL,
  description    TEXT            NULL,
  cover_image_url VARCHAR(500)   NULL,
  visibility     ENUM('private','shared','public') NOT NULL DEFAULT 'private',
  -- Share token for "send my shortlist to my wife" without requiring her to
  -- have an account.
  share_token    CHAR(32)        CHARACTER SET ascii NULL,
  item_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     INT             NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_collections_public_id (public_id),
  UNIQUE KEY uq_collections_share_token (share_token),
  UNIQUE KEY uq_collections_slug (slug),
  KEY ix_collections_user (user_id, created_at),
  KEY ix_collections_type (collection_type, visibility, is_featured),
  CONSTRAINT fk_collections_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE collection_items (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  collection_id  BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  note           VARCHAR(500)    NULL,
  sort_order     INT             NOT NULL DEFAULT 0,
  added_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_collection_items (collection_id, listing_id),
  KEY ix_collection_items_order (collection_id, sort_order),
  KEY ix_collection_items_listing (listing_id),
  CONSTRAINT fk_collection_items_collection FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
  CONSTRAINT fk_collection_items_listing    FOREIGN KEY (listing_id)    REFERENCES listings (id)    ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- saved_searches — stored filter sets with alerting
--
-- `criteria` is JSON because the filter set is genuinely open-ended and varies
-- per category; it is replayed through the same query builder the live search
-- uses, so a saved search cannot drift from what the UI produces.
-- `canonical_url` stores the equivalent public URL, which is what the alert
-- email links to.
-- -----------------------------------------------------------------------------
CREATE TABLE saved_searches (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  criteria       JSON            NOT NULL,
  canonical_url  VARCHAR(700)    NULL,

  alerts_enabled TINYINT(1)      NOT NULL DEFAULT 1,
  alert_frequency ENUM('instant','daily','weekly','never') NOT NULL DEFAULT 'daily',
  alert_channels JSON            NULL,
  last_alert_at  DATETIME(3)     NULL,
  -- Watermark for "what's new since we last told you", so an alert never
  -- re-sends listings the user already saw.
  last_result_max_listing_id BIGINT UNSIGNED NULL,
  last_result_count INT UNSIGNED NOT NULL DEFAULT 0,
  new_result_count INT UNSIGNED  NOT NULL DEFAULT 0,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_saved_searches_public_id (public_id),
  KEY ix_saved_searches_user (user_id, created_at),
  -- Drives the alert dispatcher: everything due for a given frequency.
  KEY ix_saved_searches_alerts (alerts_enabled, alert_frequency, last_alert_at),
  CONSTRAINT fk_saved_searches_user     FOREIGN KEY (user_id)     REFERENCES users (id)      ON DELETE CASCADE,
  CONSTRAINT fk_saved_searches_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_saved_searches_purpose  FOREIGN KEY (purpose_id)  REFERENCES purposes (id)   ON DELETE SET NULL,
  CONSTRAINT fk_saved_searches_location FOREIGN KEY (location_id) REFERENCES locations (id)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- bookings — viewings, test drives, charter dates, inspections
-- -----------------------------------------------------------------------------
CREATE TABLE bookings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,

  booking_type   ENUM('viewing','virtual_viewing','test_drive','sea_trial','inspection','charter','rental','valuation','meeting') NOT NULL DEFAULT 'viewing',
  status         ENUM('requested','confirmed','rescheduled','in_progress','completed','cancelled','no_show','declined') NOT NULL DEFAULT 'requested',

  -- Stored in UTC with the originating timezone alongside, so a Dubai viewing
  -- booked from London renders correctly for both parties.
  scheduled_start DATETIME(3)    NOT NULL,
  scheduled_end  DATETIME(3)     NULL,
  timezone       VARCHAR(64)     NOT NULL DEFAULT 'UTC',
  -- Multi-day charter/rental bookings.
  end_date       DATE            NULL,
  guest_count    SMALLINT UNSIGNED NULL,

  contact_name   VARCHAR(200)    NULL,
  contact_email  VARCHAR(255)    NULL,
  contact_phone  VARCHAR(40)     NULL,
  notes          TEXT            NULL,
  internal_notes TEXT            NULL,

  meeting_location VARCHAR(500)  NULL,
  meeting_url    VARCHAR(700)    NULL,

  total_amount   DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  deposit_amount DECIMAL(18,2)   NULL,
  payment_status ENUM('not_required','pending','paid','partially_paid','refunded') NOT NULL DEFAULT 'not_required',

  confirmed_at   DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  cancellation_reason VARCHAR(500) NULL,
  reminder_sent_at DATETIME(3)   NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_bookings_public_id (public_id),
  UNIQUE KEY uq_bookings_reference (reference),
  KEY ix_bookings_user (user_id, status, scheduled_start),
  KEY ix_bookings_org (organization_id, status, scheduled_start),
  KEY ix_bookings_agent (agent_id, status, scheduled_start),
  KEY ix_bookings_listing (listing_id, scheduled_start),
  -- Calendar/agenda view and the reminder dispatcher.
  KEY ix_bookings_schedule (status, scheduled_start),
  KEY ix_bookings_reminders (status, scheduled_start, reminder_sent_at),
  KEY ix_bookings_deleted (deleted_at),
  CONSTRAINT fk_bookings_listing FOREIGN KEY (listing_id)      REFERENCES listings (id)      ON DELETE SET NULL,
  CONSTRAINT fk_bookings_inquiry FOREIGN KEY (inquiry_id)      REFERENCES inquiries (id)     ON DELETE SET NULL,
  CONSTRAINT fk_bookings_user    FOREIGN KEY (user_id)         REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_bookings_account FOREIGN KEY (account_id)      REFERENCES accounts (id)      ON DELETE SET NULL,
  CONSTRAINT fk_bookings_org     FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_bookings_agent   FOREIGN KEY (agent_id)        REFERENCES agents (id)        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE booking_status_history (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id     BIGINT UNSIGNED NOT NULL,
  from_status    VARCHAR(40)     NULL,
  to_status      VARCHAR(40)     NOT NULL,
  -- Rescheduling keeps the original slot, which matters for no-show disputes.
  previous_start DATETIME(3)     NULL,
  new_start      DATETIME(3)     NULL,
  reason         VARCHAR(500)    NULL,
  changed_by_user_id BIGINT UNSIGNED NULL,
  changed_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_booking_status_history (booking_id, changed_at),
  CONSTRAINT fk_bsh_booking FOREIGN KEY (booking_id)          REFERENCES bookings (id) ON DELETE CASCADE,
  CONSTRAINT fk_bsh_user    FOREIGN KEY (changed_by_user_id)  REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- offers — formal price offers with a counter-offer chain
--
-- `parent_offer_id` makes the negotiation a linked list, so the full
-- offer/counter history is reconstructable and "who moved last" is unambiguous.
-- -----------------------------------------------------------------------------
CREATE TABLE offers (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  parent_offer_id BIGINT UNSIGNED NULL,

  buyer_user_id  BIGINT UNSIGNED NULL,
  buyer_name     VARCHAR(200)    NULL,
  buyer_email    VARCHAR(255)    NULL,
  buyer_phone    VARCHAR(40)     NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,

  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  -- Cash vs mortgage vs part-exchange materially changes how an offer is
  -- weighed, so it is structured rather than buried in the message.
  payment_method ENUM('cash','mortgage','finance','part_exchange','crypto','other') NULL,
  is_subject_to_finance TINYINT(1) NOT NULL DEFAULT 0,
  is_subject_to_survey TINYINT(1) NOT NULL DEFAULT 0,
  conditions     TEXT            NULL,
  message        TEXT            NULL,

  status         ENUM('draft','submitted','under_review','countered','accepted','declined','withdrawn','expired','completed') NOT NULL DEFAULT 'submitted',
  -- Offers lapse; without this an old offer stays "open" forever.
  expires_at     DATETIME(3)     NULL,
  responded_at   DATETIME(3)     NULL,
  responded_by_user_id BIGINT UNSIGNED NULL,
  response_note  VARCHAR(1000)   NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_offers_public_id (public_id),
  UNIQUE KEY uq_offers_reference (reference),
  KEY ix_offers_listing (listing_id, status, amount_base),
  KEY ix_offers_buyer (buyer_user_id, status, created_at),
  KEY ix_offers_org (organization_id, status, created_at),
  KEY ix_offers_agent (agent_id, status, created_at),
  KEY ix_offers_parent (parent_offer_id),
  KEY ix_offers_expiry (status, expires_at),
  CONSTRAINT fk_offers_listing FOREIGN KEY (listing_id)            REFERENCES listings (id)      ON DELETE CASCADE,
  CONSTRAINT fk_offers_inquiry FOREIGN KEY (inquiry_id)            REFERENCES inquiries (id)     ON DELETE SET NULL,
  CONSTRAINT fk_offers_parent  FOREIGN KEY (parent_offer_id)       REFERENCES offers (id)        ON DELETE SET NULL,
  CONSTRAINT fk_offers_buyer   FOREIGN KEY (buyer_user_id)         REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_offers_account FOREIGN KEY (account_id)            REFERENCES accounts (id)      ON DELETE SET NULL,
  CONSTRAINT fk_offers_org     FOREIGN KEY (organization_id)       REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_offers_agent   FOREIGN KEY (agent_id)              REFERENCES agents (id)        ON DELETE SET NULL,
  CONSTRAINT fk_offers_responder FOREIGN KEY (responded_by_user_id) REFERENCES users (id)        ON DELETE SET NULL,
  CONSTRAINT ck_offers_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE offer_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  offer_id       BIGINT UNSIGNED NOT NULL,
  event_type     ENUM('created','submitted','viewed','countered','accepted','declined','withdrawn','expired','note_added') NOT NULL,
  from_status    VARCHAR(40)     NULL,
  to_status      VARCHAR(40)     NULL,
  amount         DECIMAL(18,2)   NULL,
  note           VARCHAR(1000)   NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_offer_events (offer_id, created_at),
  CONSTRAINT fk_offer_events_offer FOREIGN KEY (offer_id)       REFERENCES offers (id) ON DELETE CASCADE,
  CONSTRAINT fk_offer_events_actor FOREIGN KEY (actor_user_id)  REFERENCES users (id)  ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- reviews
--
-- Polymorphic subject (agent, organisation, listing) with a single moderation
-- pipeline. `is_verified_transaction` is what separates a review from noise —
-- only reviews tied to a real booking or completed deal carry the badge.
-- -----------------------------------------------------------------------------
CREATE TABLE reviews (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject_type   ENUM('agent','organization','listing','platform') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  -- Denormalised for the "reviews for agents at this agency" rollup.
  organization_id BIGINT UNSIGNED NULL,

  author_user_id BIGINT UNSIGNED NULL,
  author_name    VARCHAR(200)    NULL,
  author_email   VARCHAR(255)    NULL,

  rating         TINYINT UNSIGNED NOT NULL,
  -- Sub-scores; all nullable because not every review form asks for all of them.
  rating_communication TINYINT UNSIGNED NULL,
  rating_knowledge TINYINT UNSIGNED NULL,
  rating_professionalism TINYINT UNSIGNED NULL,
  rating_responsiveness TINYINT UNSIGNED NULL,

  title          VARCHAR(255)    NULL,
  body           TEXT            NULL,

  status         ENUM('pending','published','rejected','hidden','flagged') NOT NULL DEFAULT 'pending',
  moderation_note VARCHAR(500)   NULL,
  moderated_by_user_id BIGINT UNSIGNED NULL,
  moderated_at   DATETIME(3)     NULL,

  booking_id     BIGINT UNSIGNED NULL,
  is_verified_transaction TINYINT(1) NOT NULL DEFAULT 0,
  helpful_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  report_count   INT UNSIGNED    NOT NULL DEFAULT 0,

  published_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_reviews_public_id (public_id),
  -- Serves both the public "reviews for X" list and its rating aggregate.
  KEY ix_reviews_subject (subject_type, subject_id, status, published_at),
  KEY ix_reviews_org (organization_id, status),
  KEY ix_reviews_author (author_user_id, created_at),
  KEY ix_reviews_moderation (status, created_at),
  KEY ix_reviews_rating (subject_type, subject_id, rating),
  CONSTRAINT fk_reviews_author    FOREIGN KEY (author_user_id)      REFERENCES users (id)         ON DELETE SET NULL,
  CONSTRAINT fk_reviews_org       FOREIGN KEY (organization_id)     REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_reviews_booking   FOREIGN KEY (booking_id)          REFERENCES bookings (id)      ON DELETE SET NULL,
  CONSTRAINT fk_reviews_moderator FOREIGN KEY (moderated_by_user_id) REFERENCES users (id)        ON DELETE SET NULL,
  CONSTRAINT ck_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE review_responses (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  review_id      BIGINT UNSIGNED NOT NULL,
  responder_user_id BIGINT UNSIGNED NULL,
  body           TEXT            NOT NULL,
  status         ENUM('pending','published','rejected') NOT NULL DEFAULT 'published',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- One official response per review; further discussion belongs in messages.
  UNIQUE KEY uq_review_responses (review_id),
  CONSTRAINT fk_review_responses_review FOREIGN KEY (review_id)         REFERENCES reviews (id) ON DELETE CASCADE,
  CONSTRAINT fk_review_responses_user   FOREIGN KEY (responder_user_id) REFERENCES users (id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- contacts — the admin portal's Contacts surface
--
-- General-enquiry and partnership submissions from the public site, which are
-- not listing leads and should not pollute the agency inbox.
-- -----------------------------------------------------------------------------
CREATE TABLE contacts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  email          VARCHAR(255)    NOT NULL,
  phone          VARCHAR(40)     NULL,
  company        VARCHAR(200)    NULL,
  subject        VARCHAR(255)    NULL,
  message        TEXT            NOT NULL,
  contact_type   ENUM('general','support','partnership','press','advertising','careers','complaint','api_access') NOT NULL DEFAULT 'general',
  status         ENUM('new','in_progress','responded','closed','spam') NOT NULL DEFAULT 'new',
  assigned_to_user_id BIGINT UNSIGNED NULL,
  responded_at   DATETIME(3)     NULL,
  source_url     VARCHAR(700)    NULL,
  ip_address     VARBINARY(16)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_contacts_public_id (public_id),
  KEY ix_contacts_status (status, created_at),
  KEY ix_contacts_type (contact_type, status),
  KEY ix_contacts_assignee (assigned_to_user_id, status),
  KEY ix_contacts_email (email),
  CONSTRAINT fk_contacts_assignee FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Notifications
-- -----------------------------------------------------------------------------
CREATE TABLE notification_templates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(100)    NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  channel        ENUM('email','sms','push','whatsapp','in_app') NOT NULL,
  subject        VARCHAR(255)    NULL,
  body_html      MEDIUMTEXT      NULL,
  body_text      MEDIUMTEXT      NULL,
  -- Declared placeholders ({{listing.title}}), so the template editor can
  -- validate before saving instead of failing at send time.
  variables      JSON            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Transactional messages ignore marketing opt-out; promotional ones must not.
  is_transactional TINYINT(1)    NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_notification_templates (code, channel),
  KEY ix_notification_templates_active (is_active, channel)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE notifications (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NOT NULL,
  type           VARCHAR(80)     NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  body           VARCHAR(1000)   NULL,
  action_url     VARCHAR(700)    NULL,
  icon           VARCHAR(80)     NULL,
  -- What this is about, for deep-linking and for bulk-dismissing everything
  -- related to a deleted entity.
  subject_type   VARCHAR(60)     NULL,
  subject_id     BIGINT UNSIGNED NULL,
  data           JSON            NULL,
  read_at        DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_notifications_public_id (public_id),
  -- The unread badge is a COUNT over this index prefix, not a stored literal.
  KEY ix_notifications_user_unread (user_id, read_at, created_at),
  KEY ix_notifications_subject (subject_type, subject_id),
  CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE notification_preferences (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        BIGINT UNSIGNED NOT NULL,
  -- Coarse buckets the settings screen renders as rows: new_inquiry,
  -- listing_approved, saved_search_alert, price_drop, booking_reminder…
  notification_type VARCHAR(80)  NOT NULL,
  email_enabled  TINYINT(1)      NOT NULL DEFAULT 1,
  push_enabled   TINYINT(1)      NOT NULL DEFAULT 1,
  sms_enabled    TINYINT(1)      NOT NULL DEFAULT 0,
  whatsapp_enabled TINYINT(1)    NOT NULL DEFAULT 0,
  in_app_enabled TINYINT(1)      NOT NULL DEFAULT 1,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_notification_preferences (user_id, notification_type),
  CONSTRAINT fk_notification_preferences_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Delivery log. Separate from `notifications` because one logical notification
-- can be delivered over several channels with independent outcomes, and because
-- bounce/complaint handling needs provider message ids.
CREATE TABLE notification_deliveries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  notification_id BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  template_id    INT UNSIGNED    NULL,
  channel        ENUM('email','sms','push','whatsapp','in_app') NOT NULL,
  recipient      VARCHAR(255)    NOT NULL,
  subject        VARCHAR(255)    NULL,
  status         ENUM('queued','sent','delivered','opened','clicked','bounced','failed','complained','unsubscribed') NOT NULL DEFAULT 'queued',
  provider       VARCHAR(60)     NULL,
  provider_message_id VARCHAR(191) NULL,
  error_message  VARCHAR(500)    NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  sent_at        DATETIME(3)     NULL,
  delivered_at   DATETIME(3)     NULL,
  opened_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_notification_deliveries_user (user_id, created_at),
  KEY ix_notification_deliveries_status (status, created_at),
  KEY ix_notification_deliveries_provider (provider_message_id),
  CONSTRAINT fk_nd_notification FOREIGN KEY (notification_id) REFERENCES notifications (id)         ON DELETE SET NULL,
  CONSTRAINT fk_nd_user         FOREIGN KEY (user_id)         REFERENCES users (id)                 ON DELETE CASCADE,
  CONSTRAINT fk_nd_template     FOREIGN KEY (template_id)     REFERENCES notification_templates (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0008', 'engagement');
