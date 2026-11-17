-- =============================================================================
-- 0081_email_programme.sql
--
-- Every email the platform sends now goes through one queue (owner request, 2026-11-17).
--
--   email_messages      one row per email to one address: queued, then sent or failed. It is both
--                       the outbox the worker reads and the log the admin Emails screen shows.
--                       dedupe_key stops the same reminder going twice, across API instances.
--   email_events        what the mail provider reported later: delivered, bounced, complained.
--   email_suppressions  addresses not to mail: hard bounces, complaints, unsubscribes. scope is
--                       'all' or one catalogue category (e.g. 'newsletter').
--   email_campaigns     newsletters written in admin and sent to confirmed subscribers.
--
-- notification_preferences gains email_frequency: instant, daily (one digest a day) or off is
-- email_enabled = 0. Rows are keyed by the catalogue category now ('leads', 'listings', ...);
-- the old per-event keys are folded into their category.
--
-- Safe to run more than once.
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS email_messages (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id       CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  template_key    VARCHAR(80)     CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  category        VARCHAR(40)     CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL,
  to_email        VARCHAR(255)    NOT NULL,
  to_name         VARCHAR(200)    NULL,
  user_id         BIGINT UNSIGNED NULL,
  account_id      BIGINT UNSIGNED NULL,
  campaign_id     BIGINT UNSIGNED NULL,
  data            JSON            NOT NULL,
  reply_to        VARCHAR(255)    NULL,
  subject         VARCHAR(255)    NULL,
  status          ENUM('queued','held','sending','sent','failed','suppressed','skipped','digested') NOT NULL DEFAULT 'queued',
  status_reason   VARCHAR(255)    NULL,
  priority        TINYINT UNSIGNED NOT NULL DEFAULT 5,
  attempts        TINYINT UNSIGNED NOT NULL DEFAULT 0,
  send_after      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  claimed_until   DATETIME(3)     NULL,
  dedupe_key      VARCHAR(191)    CHARACTER SET ascii COLLATE ascii_general_ci NULL,
  provider        VARCHAR(20)     NULL,
  provider_message_id VARCHAR(191) NULL,
  last_error      VARCHAR(500)    NULL,
  sent_at         DATETIME(3)     NULL,
  delivered_at    DATETIME(3)     NULL,
  bounced_at      DATETIME(3)     NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_messages_public_id (public_id),
  UNIQUE KEY uq_email_messages_dedupe (dedupe_key),
  KEY ix_email_messages_due (status, priority, send_after),
  KEY ix_email_messages_to (to_email, created_at),
  KEY ix_email_messages_user (user_id, status, category),
  KEY ix_email_messages_template (template_key, created_at),
  KEY ix_email_messages_provider (provider_message_id),
  KEY ix_email_messages_campaign (campaign_id),
  CONSTRAINT fk_email_messages_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_events (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  message_id      BIGINT UNSIGNED NULL,
  email           VARCHAR(255)    NOT NULL,
  event           ENUM('delivered','bounced','soft_bounced','complained','opened','clicked','unsubscribed','rejected') NOT NULL,
  provider        VARCHAR(20)     NULL,
  detail          VARCHAR(500)    NULL,
  payload         JSON            NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_email_events_message (message_id),
  KEY ix_email_events_email (email, event, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_suppressions (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email           VARCHAR(255)    NOT NULL,
  scope           VARCHAR(40)     CHARACTER SET ascii COLLATE ascii_general_ci NOT NULL DEFAULT 'all',
  reason          ENUM('hard_bounce','soft_bounce','complaint','unsubscribe','manual') NOT NULL,
  detail          VARCHAR(500)    NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_suppressions (email, scope)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS email_campaigns (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id       CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  subject         VARCHAR(200)    NOT NULL,
  preheader       VARCHAR(200)    NULL,
  heading         VARCHAR(200)    NOT NULL,
  body            TEXT            NOT NULL,
  cta_label       VARCHAR(80)     NULL,
  cta_url         VARCHAR(500)    NULL,
  status          ENUM('draft','sending','sent') NOT NULL DEFAULT 'draft',
  recipient_count INT UNSIGNED    NOT NULL DEFAULT 0,
  created_by_user_id BIGINT UNSIGNED NULL,
  sent_at         DATETIME(3)     NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_email_campaigns_public_id (public_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Digest choice per category. Added only when missing, so a re-run does not fail.
SET @has_frequency := (SELECT COUNT(*) FROM information_schema.columns
                        WHERE table_schema = DATABASE() AND table_name = 'notification_preferences' AND column_name = 'email_frequency');
SET @ddl := IF(@has_frequency = 0,
  "ALTER TABLE notification_preferences ADD COLUMN email_frequency ENUM('instant','daily') NOT NULL DEFAULT 'instant' AFTER email_enabled",
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Old per-event keys become catalogue categories. Where a user has both, the category row wins.
UPDATE IGNORE notification_preferences SET notification_type = CASE notification_type
    WHEN 'inquiry.received'   THEN 'leads'
    WHEN 'new_inquiry'        THEN 'leads'
    WHEN 'offer.received'     THEN 'leads'
    WHEN 'offer_received'     THEN 'leads'
    WHEN 'booking.requested'  THEN 'viewings'
    WHEN 'booking_reminder'   THEN 'viewings'
    WHEN 'listing.moderated'  THEN 'listings'
    WHEN 'listing_approved'   THEN 'listings'
    WHEN 'message.received'   THEN 'messages'
    WHEN 'review.received'    THEN 'reviews'
    WHEN 'billing.event'      THEN 'billing'
    WHEN 'product.updates'    THEN 'product'
    WHEN 'saved_search_alert' THEN 'alerts'
    WHEN 'price_drop'         THEN 'alerts'
    ELSE notification_type END
 WHERE notification_type IN ('inquiry.received','new_inquiry','offer.received','offer_received','booking.requested',
                             'booking_reminder','listing.moderated','listing_approved','message.received',
                             'review.received','billing.event','product.updates','saved_search_alert','price_drop');
DELETE FROM notification_preferences
 WHERE notification_type IN ('inquiry.received','new_inquiry','offer.received','offer_received','booking.requested',
                             'booking_reminder','listing.moderated','listing_approved','message.received',
                             'review.received','billing.event','product.updates','saved_search_alert','price_drop');

INSERT INTO schema_migrations (version, name) VALUES ('0081', 'email_programme')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
