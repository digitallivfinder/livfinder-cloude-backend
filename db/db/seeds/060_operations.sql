-- =============================================================================
-- Liv Finder — seed 060 · Platform operations and workflow
-- =============================================================================
-- The queue definitions here are the ones this platform actually needs, and
-- their settings carry an argument. A rendition job may legitimately run for
-- four minutes, so its visibility timeout is 600 seconds; an email send takes
-- two, so its is 60. Getting that wrong in either direction is expensive: too
-- short and slow work is processed twice, too long and a crashed worker's
-- messages sit idle for a quarter of an hour.
--
-- The workflow definitions replace what would otherwise be six bespoke approval
-- flows — listing moderation, account upgrades, refunds, campaign sign-off,
-- contract approval and high-risk KYC. Each one has an expiry behaviour that is
-- stated rather than assumed, because auto-approving on timeout is a reasonable
-- choice for a listing and a catastrophic one for a refund.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

INSERT INTO queue_definitions
  (code, name, description, max_workers, max_per_minute, visibility_timeout_seconds,
   max_attempts, retry_strategy, retry_base_seconds, retry_max_seconds,
   dead_letter_enabled, depth_alert_threshold, age_alert_seconds, is_paused,
   created_at, updated_at)
VALUES
  ('default', 'Default', 'Anything without a queue of its own.', 8, NULL, 300, 5,
   'exponential_jitter', 30, 3600, 1, 5000, 900, 0, NOW(3), NOW(3)),
  ('media', 'Media processing',
   'Renditions, hashing, EXIF extraction. Long-running and CPU-bound, hence the six-hundred-second visibility timeout: a 6000x4000 source can legitimately take four minutes.',
   16, NULL, 600, 3, 'exponential', 60, 1800, 1, 20000, 3600, 0, NOW(3), NOW(3)),
  ('search-index', 'Search indexing',
   'Drains the index outbox. High volume, short jobs, and the queue whose depth most directly shows up as stale results.',
   12, NULL, 60, 5, 'exponential_jitter', 10, 300, 1, 50000, 300, 0, NOW(3), NOW(3)),
  ('email', 'Email delivery', 'Transactional sends. Paced to stay inside the provider limit.',
   6, 3000, 60, 4, 'exponential_jitter', 30, 900, 1, 10000, 600, 0, NOW(3), NOW(3)),
  ('sms', 'SMS and WhatsApp', 'Costly per message, so retries are conservative.',
   4, 1200, 60, 3, 'linear', 60, 600, 1, 5000, 600, 0, NOW(3), NOW(3)),
  ('feed-export', 'Portal feed export',
   'Whole-catalogue pushes. Few, large and slow. One worker per channel so two runs cannot race on the same quota.',
   2, NULL, 1800, 2, 'fixed', 600, 600, 1, 200, 7200, 0, NOW(3), NOW(3)),
  ('feed-import', 'Portal and CRM import', 'Inbound feeds. Same shape as export.',
   4, NULL, 1800, 2, 'fixed', 900, 900, 1, 200, 7200, 0, NOW(3), NOW(3)),
  ('webhook', 'Outbound webhooks',
   'Customer endpoints, which fail constantly and recover. Long backoff and a high attempt count.',
   8, NULL, 120, 8, 'exponential_jitter', 15, 3600, 1, 20000, 1800, 0, NOW(3), NOW(3)),
  ('payments', 'Payment operations',
   'Captures, refunds, payouts. Money, so attempts are few and failures go to a human rather than round the loop again.',
   4, NULL, 180, 2, 'fixed', 300, 300, 1, 500, 300, 0, NOW(3), NOW(3)),
  ('analytics', 'Analytics rollups',
   'Nightly aggregation. Tolerant of delay, intolerant of duplication.',
   4, NULL, 3600, 2, 'fixed', 1800, 1800, 1, 100, 14400, 0, NOW(3), NOW(3)),
  ('scoring', 'Lead scoring and matching', 'Recomputes scores and requirement matches.',
   6, NULL, 120, 3, 'exponential', 30, 600, 1, 10000, 600, 0, NOW(3), NOW(3)),
  ('compliance', 'Screening and verification',
   'Sanctions screening, permit verification, document checks. Never dropped — a message that dies here is a control that did not run.',
   4, NULL, 300, 6, 'exponential', 60, 3600, 1, 1000, 1800, 0, NOW(3), NOW(3));

-- -----------------------------------------------------------------------------
-- Outbox
--
-- Written in the same transaction as the data it describes, then relayed. The
-- events here are derived from what actually happened: every published listing
-- and every completed deal produced one.
-- -----------------------------------------------------------------------------
INSERT INTO outbox_events
  (event_id, event_type, event_version, aggregate_type, aggregate_id,
   sequence_number, payload, correlation_id, organization_id, status,
   destination, attempts, published_at, occurred_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('outbox:listing:', l.id)), 26)),
  'listing.published', 1, 'listing', l.id, 1,
  JSON_OBJECT('listing_id', l.id, 'public_id', CONVERT(l.public_id USING utf8mb4) COLLATE utf8mb4_unicode_ci,
              'organization_id', l.organization_id,
              'category_id', l.category_id, 'community_id', l.community_id,
              'price', l.price, 'currency', l.currency_code),
  LOWER(LEFT(MD5(CONCAT('corr:', l.id)), 32)), l.organization_id,
  'published', 'platform-events', 1, l.published_at, l.published_at
FROM listings l
WHERE l.published_at IS NOT NULL AND l.deleted_at IS NULL;

INSERT INTO outbox_events
  (event_id, event_type, event_version, aggregate_type, aggregate_id,
   sequence_number, payload, correlation_id, organization_id, status,
   destination, attempts, published_at, occurred_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('outbox:deal:', d.id)), 26)),
  'deal.completed', 1, 'deal', d.id, 1,
  JSON_OBJECT('deal_id', d.id, 'reference', d.reference,
              'amount', d.final_amount, 'currency', d.currency_code,
              'organization_id', d.organization_id,
              'listing_id', d.listing_id),
  LOWER(LEFT(MD5(CONCAT('corr:deal:', d.id)), 32)), d.organization_id,
  'published', 'platform-events', 1, d.completed_at, d.completed_at
FROM deals d WHERE d.completed_at IS NOT NULL;

-- A handful still pending, which is what an outbox looks like at any given
-- moment, plus one that has failed and is backing off.
INSERT INTO outbox_events
  (event_id, event_type, event_version, aggregate_type, aggregate_id,
   sequence_number, payload, correlation_id, organization_id, status,
   destination, attempts, available_at, last_error, occurred_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('outbox:pending:', ld.id)), 26)),
  'lead.created', 1, 'lead', ld.id, 1,
  JSON_OBJECT('lead_id', ld.id, 'reference', ld.reference,
              'organization_id', ld.organization_id, 'score', ld.score),
  LOWER(LEFT(MD5(CONCAT('corr:lead:', ld.id)), 32)), ld.organization_id,
  IF(MOD(ld.id, 40) = 0, 'failed', 'pending'), 'platform-events',
  IF(MOD(ld.id, 40) = 0, 3, 0),
  IF(MOD(ld.id, 40) = 0, DATE_ADD(NOW(3), INTERVAL 4 MINUTE), NOW(3)),
  IF(MOD(ld.id, 40) = 0,
     'Kafka producer timed out after 30s. Broker unreachable from this availability zone.', NULL),
  ld.created_at
FROM leads ld
WHERE ld.created_at >= DATE_SUB(NOW(3), INTERVAL 2 DAY);

-- -----------------------------------------------------------------------------
-- Queue messages
--
-- A working queue: some pending, some in flight, some completed, one stuck
-- because its worker died mid-job and its visibility has not yet lapsed.
-- -----------------------------------------------------------------------------
INSERT INTO queue_messages
  (queue_id, message_type, payload, priority, status, attempts, available_at,
   visible_at, claimed_by, claimed_at, started_at, completed_at, duration_ms,
   dedupe_key, correlation_id, organization_id, created_at)
SELECT q.id, 'search.reindex',
       JSON_OBJECT('subject_type', 'listing', 'subject_id', l.id,
                   'operation', 'upsert'),
       3,
       CASE WHEN MOD(l.id, 30) = 0 THEN 'pending'
            WHEN MOD(l.id, 29) = 0 THEN 'processing'
            ELSE 'completed' END,
       1, l.updated_at,
       -- Claiming a message pushes visible_at forward by the visibility
       -- timeout; leaving it at the enqueue time would make a live in-flight
       -- claim look like a worker that died.
       IF(MOD(l.id, 29) = 0, DATE_ADD(NOW(3), INTERVAL 5 MINUTE), l.updated_at),
       IF(MOD(l.id, 29) = 0, CONCAT('index-worker-', 1 + MOD(l.id, 12)), NULL),
       IF(MOD(l.id, 29) = 0, DATE_SUB(NOW(3), INTERVAL 30 SECOND), NULL),
       IF(MOD(l.id, 30) = 0, NULL, l.updated_at),
       IF(MOD(l.id, 30) = 0 OR MOD(l.id, 29) = 0, NULL, l.updated_at),
       IF(MOD(l.id, 30) = 0 OR MOD(l.id, 29) = 0, NULL, 40 + MOD(l.id, 300)),
       CONCAT('listing:', l.id),
       LOWER(LEFT(MD5(CONCAT('corr:', l.id)), 32)),
       l.organization_id, l.updated_at
FROM listings l
JOIN queue_definitions q ON q.code = 'search-index'
WHERE l.deleted_at IS NULL;

-- A message whose worker died. The claim has lapsed, so the reaper will pick it
-- up — which is exactly what the visibility timeout is for.
INSERT INTO queue_messages
  (queue_id, message_type, payload, priority, status, attempts, available_at,
   visible_at, claimed_by, claimed_at, started_at, last_error, error_class,
   dedupe_key, created_at)
SELECT q.id, 'media.rendition',
       JSON_OBJECT('media_asset_id', ma.id, 'preset', 'gallery-1200'),
       5, 'processing', 2,
       DATE_SUB(NOW(3), INTERVAL 40 MINUTE),
       DATE_SUB(NOW(3), INTERVAL 30 MINUTE),
       'media-worker-3', DATE_SUB(NOW(3), INTERVAL 40 MINUTE),
       DATE_SUB(NOW(3), INTERVAL 40 MINUTE),
       'Worker terminated without releasing the claim. Visibility has lapsed and the message is eligible for redelivery.',
       'WorkerLost',
       CONCAT('rendition:', ma.id, ':gallery-1200'), DATE_SUB(NOW(3), INTERVAL 40 MINUTE)
FROM media_assets ma
JOIN queue_definitions q ON q.code = 'media'
WHERE MOD(ma.id, 997) = 0;

INSERT INTO dead_letter_messages
  (queue_id, message_type, payload, attempts, first_failed_at, last_failed_at,
   error_class, last_error, organization_id, status, created_at)
SELECT q.id, 'feed.export',
       JSON_OBJECT('channel_id', ch.id, 'export_type', 'full'),
       2, DATE_SUB(NOW(3), INTERVAL 3 DAY), DATE_SUB(NOW(3), INTERVAL 3 DAY),
       'FtpConnectionError',
       'FTP connection refused by the portal after three attempts. Their credentials were rotated without notice, which is the usual cause.',
       ch.organization_id, 'new', DATE_SUB(NOW(3), INTERVAL 3 DAY)
FROM syndication_channels ch
JOIN queue_definitions q ON q.code = 'feed-export'
WHERE MOD(ch.id, 47) = 0;

-- -----------------------------------------------------------------------------
-- Idempotency
--
-- The stored *response*, not merely the fact of the operation. A retried
-- payment must return the original confirmation, not a second charge and not an
-- error.
-- -----------------------------------------------------------------------------
INSERT INTO idempotency_keys
  (idempotency_key, scope, account_id, endpoint, request_method, request_hash,
   status, response_status, response_body, resource_type, resource_id,
   created_at, completed_at, expires_at)
SELECT p.idempotency_key, 'payments', p.account_id, '/v1/payments', 'POST',
       SHA2(CONCAT('req:', p.id), 256), 'completed', 201,
       JSON_OBJECT('id', CONVERT(p.public_id USING utf8mb4) COLLATE utf8mb4_unicode_ci,
                   'status', p.status, 'amount', p.amount,
                   'currency', p.currency_code, 'reference', p.reference),
       'payment', p.id, p.created_at, p.created_at,
       DATE_ADD(p.created_at, INTERVAL 24 HOUR)
FROM payments p WHERE p.idempotency_key IS NOT NULL;

INSERT INTO distributed_locks
  (lock_name, holder, fencing_token, acquired_at, expires_at, renewed_at,
   renewal_count, purpose, metadata)
VALUES
  ('job:analytics-daily-rollup', 'scheduler-2', 4471,
   DATE_SUB(NOW(3), INTERVAL 4 MINUTE), DATE_ADD(NOW(3), INTERVAL 26 MINUTE),
   DATE_SUB(NOW(3), INTERVAL 1 MINUTE), 3,
   'Nightly analytics rollup. One runner only, or the daily stats double-count.',
   JSON_OBJECT('started_at', DATE_SUB(NOW(3), INTERVAL 4 MINUTE))),
  ('job:permit-expiry-sweep', 'scheduler-1', 8812,
   DATE_SUB(NOW(3), INTERVAL 1 MINUTE), DATE_ADD(NOW(3), INTERVAL 9 MINUTE),
   NULL, 0,
   'Unpublishes listings whose advertising permit has lapsed. Compliance-critical.',
   NULL),
  ('feed:export:channel-lock', 'feed-worker-1', 231,
   DATE_SUB(NOW(3), INTERVAL 12 MINUTE), DATE_ADD(NOW(3), INTERVAL 18 MINUTE),
   DATE_SUB(NOW(3), INTERVAL 2 MINUTE), 6,
   'One export per channel at a time, so two runs cannot race on the same portal quota.',
   NULL),
  ('job:sanctions-list-import', 'scheduler-1', 1290,
   DATE_SUB(NOW(3), INTERVAL 90 MINUTE), DATE_SUB(NOW(3), INTERVAL 30 MINUTE),
   NULL, 0,
   'Expired without release — the holder crashed. The reaper will clear it, which is what the expiry is for.',
   NULL);

INSERT INTO circuit_breakers
  (breaker_key, service_name, state, failure_count, success_count,
   failure_threshold, success_threshold, cooldown_seconds, opened_at,
   half_open_at, closed_at, last_failure_at, last_failure_reason, trip_count,
   updated_at)
VALUES
  ('gateway:stripe-ae-aed', 'Stripe (AED)', 'closed', 0, 0, 5, 2, 60, NULL,
   NULL, DATE_SUB(NOW(3), INTERVAL 6 DAY), DATE_SUB(NOW(3), INTERVAL 6 DAY),
   'Timeout on authorise', 3, NOW(3)),
  ('portal:rightmove-ftp', 'Rightmove FTP', 'open', 7, 0, 5, 2, 300,
   DATE_SUB(NOW(3), INTERVAL 4 MINUTE), DATE_ADD(NOW(3), INTERVAL 1 MINUTE),
   NULL, DATE_SUB(NOW(3), INTERVAL 4 MINUTE),
   'Connection refused. Seven consecutive failures — continuing to call would make both systems worse.',
   12, NOW(3)),
  ('geocoder:google-maps', 'Google Maps geocoding', 'half_open', 2, 1, 5, 2, 60,
   DATE_SUB(NOW(3), INTERVAL 3 MINUTE), DATE_SUB(NOW(3), INTERVAL 1 MINUTE),
   NULL, DATE_SUB(NOW(3), INTERVAL 3 MINUTE),
   'HTTP 429 — daily quota exhausted. One probe request is being allowed through.',
   8, NOW(3)),
  ('sms:unifonic', 'Unifonic SMS', 'closed', 0, 0, 5, 2, 120, NULL, NULL,
   DATE_SUB(NOW(3), INTERVAL 20 DAY), NULL, NULL, 1, NOW(3)),
  ('screening:comply-advantage', 'ComplyAdvantage screening', 'closed', 1, 0, 3,
   2, 180, NULL, NULL, DATE_SUB(NOW(3), INTERVAL 2 DAY),
   DATE_SUB(NOW(3), INTERVAL 40 MINUTE), 'HTTP 503 on one request', 2, NOW(3));

-- -----------------------------------------------------------------------------
-- Workflows
--
-- `on_expiry` is the consequential setting. Auto-approving a listing that
-- nobody looked at within four hours is a reasonable trade for a marketplace
-- that needs inventory live; auto-approving a refund on the same basis is how
-- money leaves the building.
-- -----------------------------------------------------------------------------
INSERT INTO workflow_definitions
  (code, name, description, version, subject_type, trigger_conditions,
   requires_all_steps, allow_self_approval, allow_delegation, expires_after_hours,
   on_expiry, status, created_at, updated_at)
VALUES
  ('listing-moderation', 'Listing moderation',
   'Every listing from an unverified agency, and any listing flagged by the automated checks. Auto-approves on expiry because inventory going live matters more than a four-hour review backlog, and anything wrong can be unpublished afterwards.',
   1, 'listing', JSON_OBJECT('organization_verified', false), 1, 0, 1, 4,
   'approve', 'active', NOW(3), NOW(3)),

  ('account-upgrade', 'Account type change',
   'A personal account asking to become an agency. Requires document review, because the upgrade grants listing rights.',
   1, 'account', NULL, 1, 0, 1, 72, 'escalate', 'active', NOW(3), NOW(3)),

  ('refund-approval', 'Refund approval',
   'Any refund above 1,000 AED. Never auto-approves — an unattended refund queue that approves itself is a way to lose money quietly.',
   1, 'refund', JSON_OBJECT('min_amount_base', 1000), 1, 0, 1, 168,
   'remain_pending', 'active', NOW(3), NOW(3)),

  ('payout-approval', 'Payout approval',
   'Agent commission and affiliate payouts above 10,000 AED. Two approvals, and the requester may not be one of them.',
   1, 'payout', JSON_OBJECT('min_amount_base', 10000), 1, 0, 1, 168,
   'remain_pending', 'active', NOW(3), NOW(3)),

  ('campaign-approval', 'Broadcast campaign approval',
   'Any send above 5,000 recipients. Irreversible: eighty thousand emails with the wrong link is not something an undo button fixes.',
   1, 'campaign', JSON_OBJECT('min_recipients', 5000), 1, 0, 0, 48,
   'reject', 'active', NOW(3), NOW(3)),

  ('kyc-enhanced', 'Enhanced due diligence sign-off',
   'High-risk or politically exposed customers. Requires the money-laundering reporting officer personally — a duty that cannot be delegated.',
   1, 'kyc_profile', JSON_OBJECT('risk_rating', 'high'), 1, 0, 0, 120,
   'remain_pending', 'active', NOW(3), NOW(3)),

  ('contract-approval', 'Non-standard contract approval',
   'Any contract that departs from the approved template.', 1, 'contract',
   JSON_OBJECT('template_modified', true), 1, 0, 1, 120, 'escalate', 'active',
   NOW(3), NOW(3)),

  ('media-appeal', 'Media rejection appeal',
   'An agency contesting an automated media rejection. Fast, because the listing is blocked while it waits.',
   1, 'media', NULL, 1, 0, 1, 24, 'escalate', 'active', NOW(3), NOW(3));

INSERT INTO workflow_steps
  (workflow_id, step_number, name, step_type, approver_type, required_approvals,
   is_parallel, sla_hours, requires_comment, requires_document, is_active, created_at)
SELECT w.id, v.step_number, v.name, v.step_type, v.approver_type, v.required,
       v.parallel, v.sla_hours, v.needs_comment, v.needs_doc, 1, NOW(3)
FROM workflow_definitions w
JOIN (
  SELECT 'listing-moderation' AS wf, 1 AS step_number, 'Automated checks' AS name,
         'automated_check' AS step_type, 'system' AS approver_type,
         1 AS required, 0 AS parallel, NULL AS sla_hours, 0 AS needs_comment,
         0 AS needs_doc
  UNION ALL SELECT 'listing-moderation', 2, 'Moderator review', 'approval',
         'role', 1, 0, 4, 0, 0
  UNION ALL SELECT 'account-upgrade', 1, 'Document check', 'review', 'role', 1, 0, 24, 0, 1
  UNION ALL SELECT 'account-upgrade', 2, 'Approval', 'approval', 'role', 1, 0, 48, 1, 0
  UNION ALL SELECT 'refund-approval', 1, 'Support review', 'review', 'role', 1, 0, 24, 1, 0
  UNION ALL SELECT 'refund-approval', 2, 'Finance approval', 'approval', 'role', 1, 0, 48, 1, 0
  UNION ALL SELECT 'payout-approval', 1, 'Finance preparation', 'review', 'role', 1, 0, 24, 0, 0
  UNION ALL SELECT 'payout-approval', 2, 'Dual authorisation', 'approval', 'role', 2, 1, 48, 1, 0
  UNION ALL SELECT 'campaign-approval', 1, 'Content review', 'review', 'role', 1, 0, 12, 1, 0
  UNION ALL SELECT 'campaign-approval', 2, 'Marketing sign-off', 'approval', 'role', 1, 0, 24, 0, 0
  UNION ALL SELECT 'kyc-enhanced', 1, 'Compliance analyst review', 'review', 'role', 1, 0, 48, 1, 1
  UNION ALL SELECT 'kyc-enhanced', 2, 'MLRO sign-off', 'approval', 'user', 1, 0, 72, 1, 0
  UNION ALL SELECT 'contract-approval', 1, 'Legal review', 'review', 'role', 1, 0, 72, 1, 0
  UNION ALL SELECT 'contract-approval', 2, 'Commercial approval', 'approval', 'role', 1, 0, 48, 1, 0
  UNION ALL SELECT 'media-appeal', 1, 'Human review', 'approval', 'role', 1, 0, 24, 1, 0
) v ON v.wf = w.code;

-- Instances from the moderation queue that already exists.
INSERT INTO workflow_instances
  (public_id, workflow_id, workflow_version, subject_type, subject_id,
   organization_id, title, request_reason, status, current_step, priority,
   started_at, due_at, completed_at, decision_note, applied_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('wf:listing:', l.id)), 26)),
  w.id, w.version, 'listing', l.id, l.organization_id,
  CONCAT('Moderation — ', LEFT(l.title, 120)),
  'Listing submitted by an agency without a completed verification.',
  CASE l.moderation_status WHEN 'approved' THEN 'approved'
                           WHEN 'rejected' THEN 'rejected'
                           ELSE 'pending' END,
  IF(l.moderation_status = 'pending', 2, 2), 'normal',
  l.created_at, DATE_ADD(l.created_at, INTERVAL 4 HOUR),
  IF(l.moderation_status IN ('approved','rejected'), l.updated_at, NULL),
  CASE l.moderation_status
    WHEN 'approved' THEN 'Checks passed. Photographs, permit and price all consistent.'
    WHEN 'rejected' THEN COALESCE(l.rejection_reason, 'Did not meet listing standards.')
    ELSE NULL END,
  IF(l.moderation_status = 'approved', l.updated_at, NULL),
  l.created_at, l.updated_at
FROM listings l
JOIN workflow_definitions w ON w.code = 'listing-moderation'
WHERE l.deleted_at IS NULL AND l.moderation_status IS NOT NULL;

INSERT INTO workflow_actions
  (instance_id, step_number, action, actor_role, comment, occurred_at)
SELECT wi.id, 1, 'submitted', 'system',
       'Submitted for moderation on publication.', wi.started_at
FROM workflow_instances wi;

INSERT INTO workflow_actions
  (instance_id, step_number, action, actor_role, comment, occurred_at)
SELECT wi.id, 2,
       IF(wi.status = 'approved', 'approved', 'rejected'),
       'moderator', wi.decision_note, wi.completed_at
FROM workflow_instances wi WHERE wi.completed_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Health and maintenance
-- -----------------------------------------------------------------------------
INSERT INTO service_health_checks
  (service_code, service_name, service_type, is_critical, status, last_check_at,
   last_healthy_at, response_time_ms, consecutive_failures, error_message,
   uptime_24h_percent, uptime_30d_percent, check_interval_seconds, is_enabled,
   updated_at)
VALUES
  ('db-primary', 'MySQL primary', 'database', 1, 'healthy', NOW(3), NOW(3), 2, 0,
   NULL, 100.000, 99.990, 30, 1, NOW(3)),
  ('db-replica-1', 'MySQL read replica 1', 'database', 0, 'healthy', NOW(3),
   NOW(3), 3, 0, NULL, 100.000, 99.970, 30, 1, NOW(3)),
  ('cache-redis', 'Redis', 'cache', 1, 'healthy', NOW(3), NOW(3), 1, 0, NULL,
   100.000, 99.995, 30, 1, NOW(3)),
  ('search-opensearch', 'OpenSearch cluster', 'search', 1, 'degraded', NOW(3),
   DATE_SUB(NOW(3), INTERVAL 12 MINUTE), 340, 2,
   'One data node is unresponsive. The cluster is serving from two of three replicas — queries are slower but correct.',
   98.400, 99.820, 30, 1, NOW(3)),
  ('storage-s3', 'S3 media storage', 'storage', 1, 'healthy', NOW(3), NOW(3), 28,
   0, NULL, 100.000, 99.999, 60, 1, NOW(3)),
  ('cdn-cloudfront', 'CDN', 'cdn', 1, 'healthy', NOW(3), NOW(3), 14, 0, NULL,
   100.000, 99.998, 60, 1, NOW(3)),
  ('queue-sqs', 'Message queue', 'queue', 1, 'healthy', NOW(3), NOW(3), 9, 0,
   NULL, 100.000, 99.990, 30, 1, NOW(3)),
  ('gw-stripe', 'Stripe', 'payment', 1, 'healthy', NOW(3), NOW(3), 210, 0, NULL,
   100.000, 99.940, 60, 1, NOW(3)),
  ('gw-network-intl', 'Network International', 'payment', 0, 'healthy', NOW(3),
   NOW(3), 380, 0, NULL, 99.900, 99.700, 60, 1, NOW(3)),
  ('email-ses', 'Amazon SES', 'email', 1, 'healthy', NOW(3), NOW(3), 96, 0, NULL,
   100.000, 99.980, 60, 1, NOW(3)),
  ('sms-unifonic', 'Unifonic', 'sms', 0, 'healthy', NOW(3), NOW(3), 240, 0, NULL,
   100.000, 99.600, 120, 1, NOW(3)),
  ('geocoder-google', 'Google geocoding', 'geocoding', 0, 'unhealthy', NOW(3),
   DATE_SUB(NOW(3), INTERVAL 3 MINUTE), NULL, 6,
   'HTTP 429 — daily quota exhausted. Not customer-facing: new listings queue for geocoding until the quota resets.',
   96.200, 99.100, 120, 1, NOW(3)),
  ('portal-property-finder', 'Property Finder API', 'portal', 0, 'healthy',
   NOW(3), NOW(3), 420, 0, NULL, 100.000, 99.300, 300, 1, NOW(3)),
  ('portal-rightmove', 'Rightmove FTP', 'portal', 0, 'unhealthy', NOW(3),
   DATE_SUB(NOW(3), INTERVAL 4 MINUTE), NULL, 7,
   'Connection refused. The circuit breaker is open.', 92.000, 98.400, 300, 1, NOW(3));

INSERT INTO maintenance_windows
  (public_id, title, description, window_type, affected_services, impact,
   starts_at, ends_at, actual_started_at, actual_ended_at, status,
   notify_customers, notified_at, status_page_published, suppress_alerts,
   created_at, updated_at)
VALUES
  (UPPER(LEFT(MD5('mw:1'), 26)), 'Database version upgrade',
   'Rolling upgrade of the primary and replicas. Reads are served throughout; writes pause for approximately ninety seconds during the failover.',
   'scheduled', JSON_ARRAY('db-primary', 'db-replica-1'), 'minor',
   DATE_ADD(CURDATE(), INTERVAL 9 DAY) + INTERVAL 2 HOUR,
   DATE_ADD(CURDATE(), INTERVAL 9 DAY) + INTERVAL 4 HOUR,
   NULL, NULL, 'notified', 1, DATE_SUB(NOW(3), INTERVAL 2 DAY), 1, 1,
   DATE_SUB(NOW(3), INTERVAL 5 DAY), NOW(3)),
  (UPPER(LEFT(MD5('mw:2'), 26)), 'Search index rebuild',
   'Full reindex following the ranking profile change. Search remains available on the existing index while the new one builds.',
   'migration', JSON_ARRAY('search-opensearch'), 'none',
   DATE_SUB(NOW(3), INTERVAL 20 DAY), DATE_SUB(NOW(3), INTERVAL 20 DAY) + INTERVAL 6 HOUR,
   DATE_SUB(NOW(3), INTERVAL 20 DAY), DATE_SUB(NOW(3), INTERVAL 20 DAY) + INTERVAL 7 HOUR,
   'completed', 0, NULL, 0, 1, DATE_SUB(NOW(3), INTERVAL 25 DAY), NOW(3)),
  (UPPER(LEFT(MD5('mw:3'), 26)), 'Emergency: payment gateway failover',
   'Primary acquirer returned elevated declines. Traffic was moved to the failover account while the acquirer investigated.',
   'emergency', JSON_ARRAY('gw-network-intl'), 'partial_outage',
   DATE_SUB(NOW(3), INTERVAL 6 DAY), DATE_SUB(NOW(3), INTERVAL 6 DAY) + INTERVAL 2 HOUR,
   DATE_SUB(NOW(3), INTERVAL 6 DAY), DATE_SUB(NOW(3), INTERVAL 6 DAY) + INTERVAL 100 MINUTE,
   'completed', 1, DATE_SUB(NOW(3), INTERVAL 6 DAY), 1, 0,
   DATE_SUB(NOW(3), INTERVAL 6 DAY), NOW(3));
