-- =============================================================================
-- Liv Finder — seed 059 · Communications, deliverability and support
-- =============================================================================
-- The sending architecture here is the one that keeps mail arriving: separate
-- subdomains for transactional and marketing traffic, so a campaign that
-- generates complaints cannot damage delivery of password resets and lead
-- alerts. That single decision is worth more than every other deliverability
-- measure combined, and it has to be made in the data before the first send.
--
-- The reputation thresholds are the real ones. Mailbox providers begin
-- throttling around a 0.3% complaint rate; a bounce rate above roughly 2% marks
-- a sender as careless. Both are computable only per recipient domain, which is
-- why `sender_reputation_daily` carries that dimension — an overall complaint
-- rate of 0.1% can hide 1.5% at Gmail, which is where the audience is.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

INSERT INTO messaging_providers
  (code, name, channel, provider_type, traffic_class, credential_ref, region,
   priority, max_per_second, max_per_day, cost_per_message, currency_code,
   status, last_health_check_at, consecutive_failures, supports_templates,
   supports_scheduling, webhook_secret_ref, created_at, updated_at)
VALUES
  ('ses-transactional', 'Amazon SES — transactional', 'email', 'ses',
   'transactional', 'secretsmanager://messaging/ses-tx', 'me-central-1',
   1, 50, 500000, 0.000100, 'USD', 'active', NOW(3), 0, 1, 0,
   'secretsmanager://messaging/ses-tx/webhook', NOW(3), NOW(3)),
  ('sendgrid-marketing', 'SendGrid — marketing', 'email', 'sendgrid', 'marketing',
   'secretsmanager://messaging/sendgrid', 'eu-west-1', 1, 100, 2000000,
   0.000850, 'USD', 'active', NOW(3), 0, 1, 1,
   'secretsmanager://messaging/sendgrid/webhook', NOW(3), NOW(3)),
  ('postmark-failover', 'Postmark — transactional failover', 'email', 'postmark',
   'transactional', 'secretsmanager://messaging/postmark', 'us-east-1',
   2, 30, 100000, 0.001250, 'USD', 'active', NOW(3), 0, 1, 0, NULL, NOW(3), NOW(3)),
  ('unifonic-sms', 'Unifonic — Gulf SMS', 'sms', 'unifonic', 'transactional',
   'secretsmanager://messaging/unifonic', 'me-central-1', 1, 20, 100000,
   0.024000, 'USD', 'active', NOW(3), 0, 1, 0, NULL, NOW(3), NOW(3)),
  ('twilio-sms', 'Twilio — international SMS', 'sms', 'twilio', 'transactional',
   'secretsmanager://messaging/twilio', 'global', 2, 30, 200000, 0.045000,
   'USD', 'active', NOW(3), 0, 1, 1, NULL, NOW(3), NOW(3)),
  ('meta-whatsapp', 'WhatsApp Business Platform', 'whatsapp', 'meta_whatsapp',
   'transactional', 'secretsmanager://messaging/whatsapp', 'global', 1, 80,
   1000000, 0.032000, 'USD', 'active', NOW(3), 0, 1, 0,
   'secretsmanager://messaging/whatsapp/webhook', NOW(3), NOW(3)),
  ('fcm-push', 'Firebase Cloud Messaging', 'push', 'firebase', 'both',
   'secretsmanager://messaging/fcm', 'global', 1, 500, NULL, 0.000000, 'USD',
   'active', NOW(3), 0, 1, 0, NULL, NOW(3), NOW(3)),
  ('apns-push', 'Apple Push Notification service', 'push', 'apns', 'both',
   'secretsmanager://messaging/apns', 'global', 1, 500, NULL, 0.000000, 'USD',
   'active', NOW(3), 0, 0, 0, NULL, NOW(3), NOW(3));

-- -----------------------------------------------------------------------------
-- Sending domains
--
-- Separate subdomains by traffic class. This is the single most valuable
-- structural decision in email deliverability.
-- -----------------------------------------------------------------------------
INSERT INTO sending_domains
  (domain, provider_id, traffic_class, spf_status, spf_verified_at, dkim_selector,
   dkim_status, dkim_verified_at, dkim_rotated_at, dmarc_status, dmarc_verified_at,
   dmarc_reports_to, ip_pool, is_dedicated_ip, warmup_stage, warmup_daily_cap,
   tracking_domain, tracking_domain_verified, status, reputation_score,
   last_checked_at, notes, created_at, updated_at)
SELECT v.domain,
       (SELECT id FROM messaging_providers WHERE code = v.provider LIMIT 1),
       v.traffic_class, 'valid', NOW(3), v.selector, v.dkim_status, NOW(3),
       DATE_SUB(NOW(3), INTERVAL 120 DAY), v.dmarc, NOW(3),
       'dmarc-reports@livfinder.com', v.pool, v.dedicated, v.warmup_stage,
       v.warmup_cap, v.tracking_domain, 1, v.status, v.reputation, NOW(3),
       v.notes, NOW(3), NOW(3)
FROM (
  SELECT 'mail.livfinder.com' AS domain, 'ses-transactional' AS provider,
         'transactional' AS traffic_class, 'lf2026a' AS selector,
         'valid' AS dkim_status, 'reject' AS dmarc, 'tx-dedicated-1' AS pool,
         1 AS dedicated, NULL AS warmup_stage, NULL AS warmup_cap,
         'links.livfinder.com' AS tracking_domain, 'active' AS status,
         96 AS reputation,
         'Password resets, lead alerts, receipts. Dedicated IP, DMARC at reject. Nothing marketing ever goes through here.' AS notes
  UNION ALL SELECT 'news.livfinder.com', 'sendgrid-marketing', 'marketing',
         'lf2026m', 'valid', 'quarantine', 'mkt-shared-eu', 0, NULL, NULL,
         'go.livfinder.com', 'active', 88,
         'Newsletters and campaigns. Shared pool, DMARC at quarantine rather than reject while the domain matures.'
  UNION ALL SELECT 'alerts.livfinder.com', 'ses-transactional', 'transactional',
         'lf2026s', 'valid', 'reject', 'tx-dedicated-1', 1, NULL, NULL,
         'links.livfinder.com', 'active', 94,
         'Saved-search alerts. Separated from mail. so a spike in alert unsubscribes does not touch password resets.'
  UNION ALL SELECT 'billing.livfinder.com', 'postmark-failover', 'transactional',
         'lf2026b', 'valid', 'reject', 'tx-shared', 0, NULL, NULL,
         'links.livfinder.com', 'active', 98,
         'Invoices and payment notices. Postmark because transactional-only providers get the best inbox placement.'
  UNION ALL SELECT 'go.livfinder.ae', 'sendgrid-marketing', 'marketing',
         'lf2026ae', 'expiring', 'none', 'mkt-shared-me', 0, 3, 25000,
         'go.livfinder.ae', 'degraded', 61,
         'New regional marketing domain, mid-warmup at stage 3. DKIM key is due for rotation and DMARC is not yet published — both are why the reputation score is low and why volume is capped.'
) v;

INSERT INTO sender_identities
  (domain_id, code, from_email, from_name, reply_to_email, return_path, purpose,
   language_id, is_verified, verified_at, is_active, is_default, created_at, updated_at)
SELECT d.id, v.code, v.from_email, v.from_name, v.reply_to, v.return_path,
       v.purpose, (SELECT id FROM languages WHERE code = 'en'), 1, NOW(3), 1,
       v.is_default, NOW(3), NOW(3)
FROM sending_domains d
JOIN (
  SELECT 'mail.livfinder.com' AS domain, 'system' AS code,
         'no-reply@mail.livfinder.com' AS from_email, 'Liv Finder' AS from_name,
         'support@livfinder.com' AS reply_to,
         'bounces@mail.livfinder.com' AS return_path,
         'transactional' AS purpose, 1 AS is_default
  UNION ALL SELECT 'mail.livfinder.com', 'lead-alert', 'leads@mail.livfinder.com',
         'Liv Finder Leads', NULL, 'bounces@mail.livfinder.com', 'lead_alert', 0
  UNION ALL SELECT 'alerts.livfinder.com', 'saved-search',
         'alerts@alerts.livfinder.com', 'Liv Finder Alerts',
         'support@livfinder.com', 'bounces@alerts.livfinder.com', 'digest', 0
  UNION ALL SELECT 'news.livfinder.com', 'newsletter', 'hello@news.livfinder.com',
         'Liv Finder', 'hello@livfinder.com', 'bounces@news.livfinder.com',
         'marketing', 0
  UNION ALL SELECT 'billing.livfinder.com', 'billing',
         'billing@billing.livfinder.com', 'Liv Finder Billing',
         'accounts@livfinder.com', 'bounces@billing.livfinder.com', 'billing', 0
  UNION ALL SELECT 'mail.livfinder.com', 'support', 'support@mail.livfinder.com',
         'Liv Finder Support', 'support@livfinder.com',
         'bounces@mail.livfinder.com', 'support', 0
) v ON v.domain = d.domain;

-- -----------------------------------------------------------------------------
-- Suppressions
--
-- Checked before every send, ahead of preferences, templates and campaigns.
-- Derived from the users who unsubscribed and from a deterministic hard-bounce
-- sample, because a suppression list with nothing on it teaches the sending
-- path nothing.
-- -----------------------------------------------------------------------------
INSERT INTO suppressions
  (channel, destination, destination_hash, scope, reason, reason_detail, source,
   user_id, expires_at, bounce_count, last_bounce_at, created_at, updated_at)
SELECT 'email', u.email_normalized, SHA2(u.email_normalized, 256), 'marketing',
       'unsubscribe', 'Unsubscribed through the one-click link in a newsletter.',
       'user_action', u.id, NULL, 0, NULL, u.updated_at, u.updated_at
FROM users u
WHERE u.deleted_at IS NULL AND u.marketing_opt_in = 0 AND MOD(u.id, 3) = 0;

INSERT INTO suppressions
  (channel, destination, destination_hash, scope, reason, reason_detail, source,
   user_id, expires_at, bounce_count, last_bounce_at, created_at, updated_at)
SELECT 'email', u.email_normalized, SHA2(u.email_normalized, 256), 'global',
       'hard_bounce',
       '550 5.1.1 The email account that you tried to reach does not exist.',
       'provider_webhook', u.id, NULL, 1, DATE_SUB(NOW(3), INTERVAL 20 DAY),
       DATE_SUB(NOW(3), INTERVAL 20 DAY), NOW(3)
FROM users u
WHERE u.deleted_at IS NULL AND MOD(u.id, 41) = 0;

-- A soft bounce gets a cooling-off rather than a permanent block. A full
-- mailbox is temporary and blocking it forever loses a real customer.
INSERT INTO suppressions
  (channel, destination, destination_hash, scope, reason, reason_detail, source,
   user_id, expires_at, bounce_count, last_bounce_at, created_at, updated_at)
SELECT 'email', u.email_normalized, SHA2(u.email_normalized, 256), 'digest',
       'soft_bounce_repeated',
       '452 4.2.2 The recipient mailbox is over quota. Four consecutive attempts.',
       'provider_webhook', u.id, DATE_ADD(NOW(3), INTERVAL 14 DAY), 4,
       DATE_SUB(NOW(3), INTERVAL 2 DAY), DATE_SUB(NOW(3), INTERVAL 9 DAY), NOW(3)
FROM users u
WHERE u.deleted_at IS NULL AND MOD(u.id, 67) = 0;

-- A spam complaint. Permanent and global — a recipient who pressed "this is
-- spam" must never be emailed again, whatever their stored preferences say.
INSERT INTO suppressions
  (channel, destination, destination_hash, scope, reason, reason_detail, source,
   user_id, bounce_count, created_at, updated_at)
SELECT 'email', u.email_normalized, SHA2(u.email_normalized, 256), 'global',
       'spam_complaint',
       'Feedback loop complaint received from the mailbox provider.',
       'feedback_loop', u.id, 0, DATE_SUB(NOW(3), INTERVAL 35 DAY), NOW(3)
FROM users u
WHERE u.deleted_at IS NULL AND MOD(u.id, 89) = 0;

INSERT INTO unsubscribe_tokens
  (token_hash, user_id, destination, channel, scope, expires_at, created_at)
SELECT SHA2(CONCAT('unsub:', u.id), 256), u.id, u.email_normalized, 'email',
       'marketing', DATE_ADD(NOW(3), INTERVAL 365 DAY), u.created_at
FROM users u WHERE u.deleted_at IS NULL AND u.email_normalized IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Reputation
--
-- Per domain, per recipient mailbox provider, per day. The dimension is what
-- makes a threshold breach visible before it becomes an outage.
-- -----------------------------------------------------------------------------
INSERT INTO sender_reputation_daily
  (stat_date, domain_id, provider_id, recipient_domain, traffic_class, sent,
   delivered, deferred, hard_bounces, soft_bounces, blocks, complaints,
   unsubscribes, opens, machine_opens, unique_opens, clicks, unique_clicks,
   delivery_rate, bounce_rate, complaint_rate, open_rate, click_rate,
   threshold_breached, alerted_at, computed_at)
SELECT
  d.stat_date, sd.id, sd.provider_id, rd.recipient_domain,
  IF(sd.traffic_class = 'both', 'all', sd.traffic_class),
  vol.sent,
  ROUND(vol.sent * rd.delivery_rate),
  ROUND(vol.sent * 0.004),
  ROUND(vol.sent * rd.hard_bounce_rate),
  ROUND(vol.sent * 0.006),
  ROUND(vol.sent * rd.block_rate),
  ROUND(vol.sent * rd.complaint_rate),
  ROUND(vol.sent * 0.0018),
  ROUND(vol.sent * rd.delivery_rate * rd.open_rate),
  -- Apple Mail Privacy Protection pre-fetches every tracking pixel, so opens
  -- from Apple clients are close to fiction. Counted separately so the
  -- reporting can exclude them rather than quietly inflate.
  ROUND(vol.sent * rd.delivery_rate * rd.open_rate * rd.machine_share),
  ROUND(vol.sent * rd.delivery_rate * rd.open_rate * 0.78),
  ROUND(vol.sent * rd.delivery_rate * rd.open_rate * 0.16),
  ROUND(vol.sent * rd.delivery_rate * rd.open_rate * 0.12),
  ROUND(rd.delivery_rate, 4),
  ROUND(rd.hard_bounce_rate + 0.006, 4),
  ROUND(rd.complaint_rate, 4),
  ROUND(rd.open_rate, 4),
  ROUND(rd.open_rate * 0.16, 4),
  -- Gmail's tolerance is the binding one because that is where the audience is.
  IF(rd.complaint_rate > 0.003, 'complaint', NULL),
  IF(rd.complaint_rate > 0.003, DATE_ADD(d.stat_date, INTERVAL 9 HOUR), NULL),
  NOW(3)
FROM sending_domains sd
JOIN (
  SELECT 'gmail.com' AS recipient_domain, 0.9820 AS delivery_rate,
         0.0021 AS hard_bounce_rate, 0.0009 AS block_rate,
         0.0011 AS complaint_rate, 0.3400 AS open_rate, 0.4200 AS machine_share
  UNION ALL SELECT 'outlook.com', 0.9710, 0.0024, 0.0018, 0.0014, 0.2900, 0.0500
  UNION ALL SELECT 'hotmail.com', 0.9650, 0.0031, 0.0022, 0.0019, 0.2600, 0.0500
  UNION ALL SELECT 'yahoo.com', 0.9580, 0.0038, 0.0029, 0.0032, 0.2400, 0.0400
  UNION ALL SELECT 'icloud.com', 0.9890, 0.0014, 0.0004, 0.0006, 0.4100, 0.8600
  UNION ALL SELECT 'all', 0.9740, 0.0026, 0.0016, 0.0015, 0.3100, 0.3300
) rd
JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL n DAY) AS stat_date
  FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13
        UNION ALL SELECT 14) days
) d
JOIN (SELECT 4200 AS sent) vol
WHERE sd.status IN ('active', 'degraded');

-- -----------------------------------------------------------------------------
-- Campaigns
-- -----------------------------------------------------------------------------
INSERT INTO broadcast_campaigns
  (public_id, name, campaign_type, channel, sender_identity_id, provider_id,
   subject, preheader, language_id, segment_definition, segment_snapshot_at,
   audience_size, scheduled_at, send_in_recipient_timezone, throttle_per_hour,
   approval_status, approved_at, status, started_at, completed_at,
   ab_test_enabled, ab_test_percent, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('bcast:', v.code)), 26)), v.name, v.type, 'email',
       si.id, mp.id, v.subject, v.preheader,
       (SELECT id FROM languages WHERE code = 'en'),
       v.segment, DATE_SUB(NOW(3), INTERVAL v.days_ago DAY), 0,
       DATE_SUB(NOW(3), INTERVAL v.days_ago DAY), 1, 20000,
       'approved', DATE_SUB(NOW(3), INTERVAL (v.days_ago + 1) DAY),
       IF(v.days_ago > 0, 'sent', 'scheduled'),
       IF(v.days_ago > 0, DATE_SUB(NOW(3), INTERVAL v.days_ago DAY), NULL),
       IF(v.days_ago > 0, DATE_SUB(NOW(3), INTERVAL v.days_ago DAY) + INTERVAL 3 HOUR, NULL),
       v.ab, v.ab_pct,
       DATE_SUB(NOW(3), INTERVAL (v.days_ago + 3) DAY), NOW(3)
FROM (
  SELECT 'weekly-digest' AS code, 'Weekly property digest' AS name,
         'listing_digest' AS type,
         'New this week in your saved areas' AS subject,
         '12 new listings matching your searches' AS preheader,
         JSON_OBJECT('marketing_opt_in', true, 'has_saved_search', true) AS segment,
         3 AS days_ago, 1 AS ab, 20 AS ab_pct
  UNION ALL SELECT 'market-report-q1', 'Q1 market report', 'market_report',
         'Dubai Q1 2026: prices, volumes and what changed',
         'Transaction data through March, by community',
         JSON_OBJECT('marketing_opt_in', true), 14, 0, NULL
  UNION ALL SELECT 'off-plan-launch', 'Marina Heights launch announcement',
         'announcement', 'Marina Heights — registration now open',
         'Waterfront residences, handover 2028',
         JSON_OBJECT('marketing_opt_in', true, 'interest', 'off_plan'), 21, 1, 25
  UNION ALL SELECT 'reengagement', 'Re-engagement — dormant six months',
         're_engagement', 'Still looking? The market has moved',
         'What has changed in your areas since you last visited',
         JSON_OBJECT('last_session_days_ago_min', 180), 30, 0, NULL
  UNION ALL SELECT 'agency-newsletter', 'Agency newsletter — March', 'newsletter',
         'Product updates, and what is coming next',
         'New syndication channels and a faster listing editor',
         JSON_OBJECT('account_type', 'company'), 7, 0, NULL
  UNION ALL SELECT 'spring-promo', 'Spring promotion — 20% off featured',
         'promotion', '20% off featured placements until the end of the month',
         'Get your listings in front of more buyers',
         JSON_OBJECT('account_type', 'company', 'has_active_listings', true),
         0, 0, NULL
) v
JOIN sender_identities si ON si.code = IF(v.type IN ('listing_digest'), 'saved-search', 'newsletter')
JOIN messaging_providers mp ON mp.code = 'sendgrid-marketing';

INSERT INTO campaign_recipients
  (campaign_id, user_id, destination, destination_hash, language_id, timezone,
   ab_variant, status, suppression_reason, scheduled_for, sent_at, delivered_at,
   opened_at, clicked_at, open_count, click_count)
SELECT
  c.id, u.id, u.email_normalized, SHA2(u.email_normalized, 256),
  u.preferred_language_id, u.timezone,
  IF(c.ab_test_enabled, IF(MOD(u.id, 2) = 0, 'a', 'b'), NULL),
  -- Suppression is checked here, and a suppressed recipient is recorded as
  -- such rather than silently dropped.
  CASE WHEN s.id IS NOT NULL THEN 'suppressed'
       WHEN c.status <> 'sent' THEN 'pending'
       WHEN MOD(u.id + c.id, 43) = 0 THEN 'bounced'
       WHEN MOD(u.id + c.id, 4) = 0 THEN 'clicked'
       WHEN MOD(u.id + c.id, 3) = 0 THEN 'opened'
       ELSE 'delivered' END,
  IF(s.id IS NOT NULL, CONCAT('Suppressed: ', s.reason), NULL),
  c.scheduled_at,
  IF(s.id IS NULL AND c.status = 'sent', c.started_at, NULL),
  IF(s.id IS NULL AND c.status = 'sent', c.started_at + INTERVAL 40 SECOND, NULL),
  IF(s.id IS NULL AND c.status = 'sent' AND MOD(u.id + c.id, 3) = 0,
     c.started_at + INTERVAL 3 HOUR, NULL),
  IF(s.id IS NULL AND c.status = 'sent' AND MOD(u.id + c.id, 4) = 0,
     c.started_at + INTERVAL 4 HOUR, NULL),
  IF(MOD(u.id + c.id, 3) = 0, 1, 0),
  IF(MOD(u.id + c.id, 4) = 0, 1, 0)
FROM broadcast_campaigns c
JOIN users u ON u.deleted_at IS NULL AND u.email_normalized IS NOT NULL
LEFT JOIN suppressions s
  ON s.destination_hash = SHA2(u.email_normalized, 256)
 AND s.channel = 'email' AND s.removed_at IS NULL
 AND s.scope IN ('global', 'marketing')
WHERE MOD(u.id, 2) = 0;

INSERT INTO campaign_links
  (campaign_id, link_key, destination_url, label, position, click_count,
   unique_click_count, created_at)
SELECT c.id, CONCAT('cta-', n.i),
       CONCAT('https://livfinder.com/?utm_source=newsletter&utm_medium=email&utm_campaign=',
              LOWER(REPLACE(c.name, ' ', '-')), '&link=', n.i),
       ELT(n.i, 'Primary call to action', 'Browse listings', 'View market report'),
       n.i, 0, 0, c.created_at
FROM broadcast_campaigns c
JOIN (SELECT 1 AS i UNION ALL SELECT 2 UNION ALL SELECT 3) n;

UPDATE broadcast_campaigns c
  LEFT JOIN (
    SELECT campaign_id, COUNT(*) AS total,
           SUM(status <> 'suppressed' AND status <> 'pending') AS sent,
           SUM(status IN ('delivered','opened','clicked')) AS delivered,
           SUM(status = 'bounced') AS bounced,
           SUM(open_count > 0) AS opened,
           SUM(click_count > 0) AS clicked,
           SUM(status = 'suppressed') AS suppressed
      FROM campaign_recipients GROUP BY campaign_id
  ) r ON r.campaign_id = c.id
   SET c.audience_size = COALESCE(r.total, 0),
       c.queued_count = COALESCE(r.total, 0),
       c.sent_count = COALESCE(r.sent, 0),
       c.delivered_count = COALESCE(r.delivered, 0),
       c.bounced_count = COALESCE(r.bounced, 0),
       c.opened_count = COALESCE(r.opened, 0),
       c.clicked_count = COALESCE(r.clicked, 0),
       c.suppressed_count = COALESCE(r.suppressed, 0);

INSERT INTO push_devices
  (user_id, platform, token_hash, app_version, os_version, device_model,
   language_id, timezone, status, failure_count, last_seen_at, last_push_at,
   registered_at, updated_at)
SELECT u.id,
       ELT(1 + MOD(u.id, 3), 'ios', 'android', 'web'),
       SHA2(CONCAT('device:', u.id), 256),
       ELT(1 + MOD(u.id, 3), '4.12.0', '4.11.2', NULL),
       ELT(1 + MOD(u.id, 3), 'iOS 18.3', 'Android 15', NULL),
       ELT(1 + MOD(u.id, 3), 'iPhone16,2', 'SM-S928B', NULL),
       u.preferred_language_id, u.timezone,
       -- Tokens rot. A fifth are stale, which is why the sender must check
       -- rather than push to everything it has ever seen.
       IF(MOD(u.id, 5) = 0, 'stale', 'active'),
       IF(MOD(u.id, 5) = 0, 3, 0),
       IF(MOD(u.id, 5) = 0, DATE_SUB(NOW(3), INTERVAL 120 DAY), u.last_seen_at),
       u.last_login_at, u.created_at, NOW(3)
FROM users u
WHERE u.deleted_at IS NULL AND MOD(u.id, 2) = 0;

-- =============================================================================
-- SUPPORT
-- =============================================================================

INSERT INTO support_queues
  (code, name, description, sla_policy_id, routing_email, language_id,
   business_hours_only, auto_close_after_days, is_active, sort_order,
   created_at, updated_at)
SELECT v.code, v.name, v.description,
       (SELECT id FROM sla_policies WHERE code = v.sla LIMIT 1),
       v.email, (SELECT id FROM languages WHERE code = 'en'),
       v.business_hours, v.auto_close, 1, v.sort_order, NOW(3), NOW(3)
FROM (
  SELECT 'consumer' AS code, 'Consumer support' AS name,
         'Buyers and renters. High volume, mostly account and search questions.' AS description,
         'support-standard' AS sla, 'help@livfinder.com' AS email,
         1 AS business_hours, 14 AS auto_close, 10 AS sort_order
  UNION ALL SELECT 'agency', 'Agency support',
         'Paying customers. Listing problems, feed failures and quota questions. Tighter SLA because these are the people who churn.',
         'support-agency', 'agency-support@livfinder.com', 1, 7, 20
  UNION ALL SELECT 'billing', 'Billing and payments',
         'Invoices, failed payments, refunds and disputes.',
         'support-agency', 'billing@livfinder.com', 1, 21, 30
  UNION ALL SELECT 'compliance', 'Compliance and verification',
         'Permit questions, verification submissions and data-subject requests. Handled by the compliance team rather than support.',
         'support-agency', 'compliance@livfinder.com', 1, 30, 40
  UNION ALL SELECT 'abuse', 'Trust and safety',
         'Reports of fraudulent listings, scams and impersonation. Prioritised above everything else.',
         'urgent', 'report@livfinder.com', 0, 7, 50
  UNION ALL SELECT 'developer', 'API and integrations',
         'Partner and developer support.', 'support-agency',
         'api@livfinder.com', 1, 14, 60
) v;

INSERT INTO support_tickets
  (public_id, reference, queue_id, subject, description, requester_user_id,
   requester_name, requester_email, organization_id, account_id, subject_type,
   subject_id, ticket_type, category, priority, status, channel,
   first_response_at, first_response_minutes, resolved_at, resolution_minutes,
   closed_at, resolution_code, resolution_note, language_id, message_count,
   satisfaction_rating, satisfaction_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('ticket:', c.id)), 26)),
  CONCAT('SUP-', LPAD(c.id, 8, '0')),
  q.id, c.subject,
  COALESCE(c.message, 'No description supplied.'),
  NULL, c.name, c.email, NULL, NULL, 'other', NULL,
  CASE c.contact_type WHEN 'support' THEN 'problem'
                      WHEN 'billing' THEN 'billing'
                      WHEN 'complaint' THEN 'complaint'
                      ELSE 'question' END,
  c.contact_type,
  IF(c.contact_type = 'complaint', 'high', 'normal'),
  CASE c.status WHEN 'resolved' THEN 'resolved' WHEN 'closed' THEN 'closed'
                WHEN 'in_progress' THEN 'open' ELSE 'new' END,
  'web_form',
  c.responded_at,
  IF(c.responded_at IS NULL, NULL,
     GREATEST(0, TIMESTAMPDIFF(MINUTE, c.created_at, c.responded_at))),
  IF(c.status IN ('resolved','closed'), c.updated_at, NULL),
  IF(c.status IN ('resolved','closed'),
     GREATEST(0, TIMESTAMPDIFF(MINUTE, c.created_at, c.updated_at)), NULL),
  IF(c.status = 'closed', c.updated_at, NULL),
  IF(c.status IN ('resolved','closed'), 'resolved', NULL),
  IF(c.status IN ('resolved','closed'),
     'Resolved and confirmed with the customer.', NULL),
  (SELECT id FROM languages WHERE code = 'en'),
  0,
  IF(c.status IN ('resolved','closed'), 3 + MOD(c.id, 3), NULL),
  IF(c.status IN ('resolved','closed'), c.updated_at, NULL),
  c.created_at, c.updated_at
FROM contacts c
JOIN support_queues q ON q.code = 'consumer';

-- Agency tickets from the integrations that are failing, which is where agency
-- support volume genuinely comes from.
INSERT INTO support_tickets
  (public_id, reference, queue_id, subject, description, organization_id,
   subject_type, subject_id, ticket_type, category, priority, status, channel,
   first_response_at, first_response_minutes, language_id, message_count,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('ticket:feed:', ic.id)), 26)),
  CONCAT('SUP-F', LPAD(ic.id, 7, '0')),
  q.id,
  CONCAT('Feed failing — ', p.name),
  CONCAT('The scheduled import from ', p.name, ' has failed ',
         ic.consecutive_failures, ' times in a row. Last error: ', ic.last_error),
  ic.organization_id, 'feed', ic.id, 'problem', 'integration', 'high', 'open',
  'api',
  DATE_ADD(ic.last_error_at, INTERVAL 40 MINUTE), 40,
  (SELECT id FROM languages WHERE code = 'en'), 0,
  ic.last_error_at, NOW(3)
FROM integration_connections ic
JOIN integration_providers p ON p.id = ic.provider_id
JOIN support_queues q ON q.code = 'agency'
WHERE ic.status = 'error';

INSERT INTO support_ticket_messages
  (ticket_id, sequence_number, author_type, author_name, author_email, body,
   is_internal_note, channel, created_at)
SELECT t.id, 1, 'customer', t.requester_name, t.requester_email, t.description,
       0, IF(t.channel = 'api', 'api', 'web'), t.created_at
FROM support_tickets t;

INSERT INTO support_ticket_messages
  (ticket_id, sequence_number, author_type, author_name, body, is_internal_note,
   channel, created_at)
SELECT t.id, 2, 'agent', 'Liv Finder Support',
       'Thank you for getting in touch. I have looked into this and will come back to you shortly.',
       0, 'email', t.first_response_at
FROM support_tickets t WHERE t.first_response_at IS NOT NULL;

-- Internal notes are invisible to the customer. The single most important flag
-- on the table, and the one most often got wrong.
INSERT INTO support_ticket_messages
  (ticket_id, sequence_number, author_type, author_name, body, is_internal_note,
   channel, created_at)
SELECT t.id, 3, 'agent', 'Liv Finder Support',
       'Internal: reproduced on staging. The root cause is the value mapping for this provider, not the customer''s data. Passing to integrations.',
       1, 'internal', DATE_ADD(t.first_response_at, INTERVAL 20 MINUTE)
FROM support_tickets t
WHERE t.first_response_at IS NOT NULL AND t.category = 'integration';

UPDATE support_tickets t
  JOIN (SELECT ticket_id, COUNT(*) n FROM support_ticket_messages GROUP BY ticket_id) m
    ON m.ticket_id = t.id
   SET t.message_count = m.n;

INSERT INTO canned_responses
  (queue_id, code, title, body, language_id, category, usage_count, is_active,
   created_at, updated_at)
SELECT q.id, v.code, v.title, v.body,
       (SELECT id FROM languages WHERE code = 'en'), v.category, 0, 1,
       NOW(3), NOW(3)
FROM support_queues q
JOIN (
  SELECT 'consumer' AS queue, 'listing-removed' AS code,
         'Why has a listing disappeared?' AS title,
         'A listing usually disappears for one of three reasons: the property has been sold or let, the agency has withdrawn it, or the advertising permit has expired and we have unpublished it automatically. I can tell you which applies here if you send me the reference number.' AS body,
         'listings' AS category
  UNION ALL SELECT 'consumer', 'agent-no-response', 'Agent has not responded',
         'I am sorry — that should not happen. I have flagged this to the agency and their response time is recorded against them. In the meantime, here are three comparable properties from agencies with a response rate above 90%.',
         'agents'
  UNION ALL SELECT 'consumer', 'suspected-scam', 'Suspected fraudulent listing',
         'Thank you for reporting this. The listing has been unpublished while we investigate, and the agency''s account is under review. Please do not send money or documents to anyone who contacted you about it. If you already have, contact your bank immediately.',
         'safety'
  UNION ALL SELECT 'agency', 'feed-mapping-error', 'Feed rejected — unmapped value',
         'Your feed contains a value we have no mapping for, so those listings were skipped rather than imported incorrectly. I have added the mapping and re-run the import. You should see the listings within the hour.',
         'integration'
  UNION ALL SELECT 'agency', 'permit-required', 'Listing blocked — permit missing',
         'This listing cannot be published because it has no valid Trakheesi permit number. That is a regulatory requirement rather than our policy — we are not permitted to carry the advert without it. Add the permit number to the listing and it will publish automatically.',
         'compliance'
  UNION ALL SELECT 'agency', 'quota-exceeded', 'Portal quota exceeded',
         'Your contracted quota on this portal is fully used, so newer listings are queued rather than published. You can either free a slot by removing a listing, or increase the quota with the portal directly.',
         'syndication'
  UNION ALL SELECT 'billing', 'payment-failed', 'Payment failed',
         'The payment was declined by your bank rather than by us — the code returned suggests insufficient funds. We will retry automatically in three days. You can also update the card on file and we will retry immediately.',
         'billing'
  UNION ALL SELECT 'compliance', 'dsr-acknowledgement', 'Data request received',
         'We have received your request and will respond within one month, as required. If the request is complex we may extend that by a further two months, and we will tell you if so. You do not need to do anything further for now.',
         'privacy'
) v ON v.queue = q.code;

-- -----------------------------------------------------------------------------
-- Knowledge base
-- -----------------------------------------------------------------------------
INSERT INTO kb_categories
  (parent_id, slug, name, description, icon, audience, depth, path,
   article_count, sort_order, is_visible, created_at, updated_at)
VALUES
  (NULL, 'getting-started', 'Getting started', 'Accounts, searching and saving.', 'rocket', 'consumer', 0, '/getting-started', 0, 10, 1, NOW(3), NOW(3)),
  (NULL, 'buying', 'Buying a property', 'From first search to handover.', 'key', 'consumer', 0, '/buying', 0, 20, 1, NOW(3), NOW(3)),
  (NULL, 'renting', 'Renting', 'Tenancy contracts, deposits and renewals.', 'home', 'consumer', 0, '/renting', 0, 30, 1, NOW(3), NOW(3)),
  (NULL, 'safety', 'Staying safe', 'How to spot a fraudulent listing.', 'shield', 'consumer', 0, '/safety', 0, 40, 1, NOW(3), NOW(3)),
  (NULL, 'for-agencies', 'For agencies', 'Listing, syndication and billing.', 'briefcase', 'agency', 0, '/for-agencies', 0, 50, 1, NOW(3), NOW(3)),
  (NULL, 'developers', 'API and developers', 'Integrating with the platform.', 'code', 'developer', 0, '/developers', 0, 60, 1, NOW(3), NOW(3));

INSERT INTO kb_articles
  (public_id, category_id, slug, title, summary, body, audience, article_type,
   language_id, status, published_at, last_reviewed_at, next_review_due,
   view_count, helpful_count, unhelpful_count, ticket_deflection_count,
   is_indexable, version, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('kb:', v.slug)), 26)),
       (SELECT id FROM kb_categories WHERE slug = v.cat LIMIT 1),
       v.slug, v.title, v.summary, v.body, v.audience, v.type,
       (SELECT id FROM languages WHERE code = 'en'),
       'published', DATE_SUB(NOW(3), INTERVAL v.days_ago DAY),
       DATE_SUB(NOW(3), INTERVAL v.days_ago DAY),
       DATE_ADD(CURDATE(), INTERVAL (365 - v.days_ago) DAY),
       v.views, ROUND(v.views * 0.09), ROUND(v.views * 0.012),
       ROUND(v.views * 0.06), 1, 1,
       DATE_SUB(NOW(3), INTERVAL (v.days_ago + 5) DAY), NOW(3)
FROM (
  SELECT 'safety' AS cat, 'spotting-a-fraudulent-listing' AS slug,
         'How to spot a fraudulent listing' AS title,
         'The six signals that a listing is not what it claims to be, and what to do about it.' AS summary,
         'Fraudulent property listings follow a small number of patterns.\n\n**The price is well below the market.** A villa on the Palm at a third of the going rate is not a bargain, it is bait.\n\n**The photographs do not match.** We check the location metadata on uploaded images against the stated address, and flag listings where they disagree by more than a few hundred metres — but a fraudster who strips the metadata will pass that check. Reverse image search is the reader''s version of the same test.\n\n**Contact is pushed off the platform immediately.** A legitimate agent has no reason to insist on WhatsApp before you have seen the property.\n\n**A deposit is requested before a viewing.** No reputable agency asks for money before you have seen the property and signed something.\n\n**The permit number is missing or does not verify.** Every Dubai listing must display a Trakheesi permit. You can verify it yourself on the Dubai Land Department site.\n\n**The story is urgent.** "Another buyer is coming this afternoon" is the oldest pressure tactic there is.\n\nIf a listing shows any of these, report it. We unpublish while we investigate, and the agency''s account goes under review.' AS body,
         'consumer' AS audience, 'how_to' AS type, 200 AS days_ago, 18400 AS views
  UNION ALL SELECT 'buying', 'understanding-trakheesi-permits',
         'What is a Trakheesi permit and why does it matter?',
         'Every advertised property in Dubai needs one. Here is what it means for a buyer.',
         'A Trakheesi permit is an advertising permit issued by the Dubai Land Department. It is required before any property may be advertised — on a portal, on social media, or on a billboard.\n\nFor a buyer it is a useful signal. A permit means the agency has demonstrated to the regulator that they hold a genuine instruction to sell the property. A listing without one may still be genuine, but it has skipped a step that exists precisely to stop the thing you are worried about.\n\nEvery listing on this site displays its permit number and a QR code linking to the regulator''s own verification page. If a permit has expired we unpublish the listing automatically — which is why a property you saw yesterday may not be there today.',
         'consumer', 'faq', 180, 12100
  UNION ALL SELECT 'renting', 'ejari-registration-explained',
         'Ejari registration explained',
         'Why your tenancy contract has to be registered, and what happens if it is not.',
         'Ejari is the Dubai Land Department''s tenancy registration system. A tenancy contract that is not registered on it is not enforceable, which matters at exactly the moment you need it to be.\n\nRegistration is normally handled by the agency or the landlord. You will need it to connect utilities, to obtain a residence visa for a family member, and to bring any dispute to the Rental Disputes Centre.\n\nThe ninety-day rule is the other thing worth knowing. A landlord who wants to increase the rent must give notice ninety days before the contract ends. If they do not, the rent cannot be increased for that renewal — and that is a right, not a courtesy.',
         'consumer', 'how_to', 160, 9800
  UNION ALL SELECT 'for-agencies', 'why-my-listing-was-rejected',
         'Why was my listing rejected by a portal?',
         'The four rejection reasons that account for most of them, and how to fix each.',
         'Portal rejections come back with a code that is rarely self-explanatory. These four cover most of them.\n\n**PERMIT_MISSING.** No valid Trakheesi permit number. Add it to the listing; the feed will retry on the next run.\n\n**IMAGE_COUNT.** Below the portal''s minimum. Bayut wants four photographs, JamesEdition wants eight. Our validation catches this before the push, so if you are seeing it remotely the images were removed after publication.\n\n**CONTACT_IN_DESCRIPTION.** A phone number or email address in the listing text. Portals strip these and penalise the account, because it routes around their lead capture.\n\n**QUOTA_EXCEEDED.** Your contracted slot count on that portal is full. Nothing is wrong with the listing; there is nowhere to put it.',
         'agency', 'troubleshooting', 120, 7400
  UNION ALL SELECT 'for-agencies', 'setting-up-a-feed',
         'Setting up an inbound feed from your CRM',
         'What we need from you, and what happens on the first import.',
         'We can import from Reapit, PropSpace, MasterKey, most generic XML feeds, and a spreadsheet.\n\nThe first import is always a dry run. We show you what would be created, updated and skipped before anything is written, because the first run of any feed reveals mapping problems that are far cheaper to fix before four hundred listings exist than after.\n\nUnmapped values are the usual issue. If your system uses a property type or an area name we do not recognise, those records are skipped and listed for you rather than guessed at. Send us the list and we will add the mappings.\n\nOne safety measure worth knowing about: if an import would remove more than a fifth of your live listings, we stop and ask. A truncated export is far more likely than an agency withdrawing everything overnight.',
         'agency', 'how_to', 100, 5200
  UNION ALL SELECT 'getting-started', 'saved-searches-and-alerts',
         'Saved searches and alerts',
         'How to be told when something matching your criteria appears.',
         'Save any search and you will be told when new listings match it. Alerts can be immediate, daily or weekly.\n\nImmediate is worth using in a fast market — in Dubai a well-priced property in a popular community can be under offer within days, and a weekly digest arrives after the fact.\n\nYou will also be told when a property already in your saved search drops in price, which is often the more useful signal.',
         'consumer', 'how_to', 90, 6100
  UNION ALL SELECT 'developers', 'api-authentication',
         'API authentication',
         'How to authenticate, and how rate limits work.',
         'The API uses OAuth 2.0 client credentials. Request a token from the token endpoint and present it as a bearer token.\n\nRate limits are per client and are returned on every response in the standard headers. A 429 includes a Retry-After. Do not retry faster than it says — the limit is per client, so hammering it delays your own subsequent requests rather than anybody else''s.\n\nEvery write endpoint accepts an Idempotency-Key header. Use it. A retried request with the same key returns the original response rather than performing the operation twice, which matters most on the endpoints that cost money.',
         'developer', 'how_to', 70, 2300
  UNION ALL SELECT 'safety', 'reporting-a-listing',
         'How to report a listing',
         'What happens after you report something, and how long it takes.',
         'Every listing has a report link. Choose the reason that fits best — the reason routes the report, and a fraud report goes to a different queue with a different response time than a "photographs are wrong" report.\n\nFraud and safety reports are looked at within the hour, around the clock. The listing is unpublished while we investigate rather than after, because the cost of being wrong in that direction is much lower.\n\nYou will be told the outcome. If we do not act, we will tell you why.',
         'consumer', 'how_to', 60, 3400
) v;

INSERT INTO kb_article_translations
  (article_id, language_id, slug, title, summary, body, translation_status,
   source_version, is_outdated, translated_at, created_at, updated_at)
SELECT a.id, l.id, CONCAT(a.slug, '-ar'),
       CONCAT('[AR] ', a.title), CONCAT('[AR] ', a.summary), a.body,
       -- Machine-translated and not yet reviewed, which is the honest state of
       -- most help content in a second language.
       'machine', a.version, 0, DATE_ADD(a.published_at, INTERVAL 2 DAY),
       NOW(3), NOW(3)
FROM kb_articles a
JOIN languages l ON l.code = 'ar'
WHERE a.status = 'published';

INSERT INTO kb_article_feedback
  (article_id, language_id, user_id, was_helpful, comment, search_query, created_at)
SELECT a.id, a.language_id, u.id, MOD(u.id + a.id, 9) <> 0,
       IF(MOD(u.id + a.id, 9) = 0,
          'This did not answer my question — I wanted to know about the deposit, not the contract.', NULL),
       IF(MOD(u.id + a.id, 9) = 0, 'deposit refund how long', NULL),
       DATE_SUB(NOW(3), INTERVAL MOD(u.id, 60) DAY)
FROM kb_articles a
JOIN users u ON MOD(u.id, 17) = MOD(a.id, 17)
WHERE a.status = 'published' AND u.deleted_at IS NULL;

UPDATE kb_articles a
  LEFT JOIN (SELECT article_id, SUM(was_helpful) h, SUM(NOT was_helpful) u
               FROM kb_article_feedback GROUP BY article_id) f
    ON f.article_id = a.id
   SET a.helpful_count = COALESCE(f.h, 0), a.unhelpful_count = COALESCE(f.u, 0);

UPDATE kb_categories c
  LEFT JOIN (SELECT category_id, COUNT(*) n FROM kb_articles
              WHERE status = 'published' AND deleted_at IS NULL
              GROUP BY category_id) a ON a.category_id = c.id
   SET c.article_count = COALESCE(a.n, 0);
