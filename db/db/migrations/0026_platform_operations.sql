-- =============================================================================
-- Liv Finder — 0026 · Platform operations and workflow
-- =============================================================================
-- Everything so far describes what the business knows. This describes how the
-- system keeps its promises when parts of it are failing, which at scale is
-- always.
--
-- Migration 0013 gave `jobs` and `job_runs`: a registry of scheduled work and
-- its history. That answers "did the nightly rollup run". It does not answer
-- the harder questions, and those are what this migration is for.
--
-- THE OUTBOX. `outbox_events` exists because of one specific, ubiquitous bug:
-- a listing is published in a transaction, then a message is posted to a queue
-- to reindex it and notify subscribers. If the process dies between the commit
-- and the publish, the listing is live and nothing downstream knows. Writing
-- the event into the same transaction as the data, and relaying it afterwards,
-- is the only construction that makes those two facts atomic without a
-- distributed transaction.
--
-- THE QUEUE. `queue_messages` is a durable work queue with visibility timeouts,
-- attempt counts and a dead-letter path. A worker claims a message for a
-- bounded period; if it dies, the claim lapses and another worker takes it.
-- Work is never silently lost, and poison messages stop after N attempts
-- instead of retrying forever.
--
-- IDEMPOTENCY. `idempotency_keys` stores the *response* to a completed
-- operation, not merely the fact of it. A retried payment must return the
-- original result, not a second charge and not an error.
--
-- LOCKS. `distributed_locks` prevents two schedulers running the same nightly
-- job. Every lock has an expiry, because a lock without one is an outage
-- waiting for a process to crash while holding it.
--
-- WORKFLOW. The approval engine at the end generalises what would otherwise be
-- six bespoke review flows — listing moderation, account upgrades, refunds,
-- campaign approval, contract sign-off, high-risk KYC — into one auditable
-- mechanism with steps, delegation and expiry.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · TRANSACTIONAL OUTBOX
-- =============================================================================

-- -----------------------------------------------------------------------------
-- outbox_events
--
-- Written inside the business transaction; relayed to the message bus
-- afterwards by a poller. See the header for why.
--
-- `aggregate_type` + `aggregate_id` + `sequence_number` give per-entity
-- ordering: two edits to the same listing must be relayed in order, while
-- edits to different listings may be relayed in parallel. Global ordering
-- would be correct and unusably slow.
--
-- Relay is at-least-once, so consumers must be idempotent — `event_id` is the
-- deduplication key they use.
-- -----------------------------------------------------------------------------
CREATE TABLE outbox_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id       CHAR(26)        NOT NULL,
  event_type     VARCHAR(120)    NOT NULL,
  event_version  SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  aggregate_type VARCHAR(60)     NOT NULL,
  aggregate_id   BIGINT UNSIGNED NOT NULL,
  sequence_number BIGINT UNSIGNED NULL,
  payload        JSON            NOT NULL,
  -- Trace and causation, so an event can be followed back to the request that
  -- caused it and forward to everything it triggered. Without these, debugging
  -- an event-driven system is archaeology.
  correlation_id CHAR(32)        CHARACTER SET ascii NULL,
  causation_id   CHAR(26)        NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- Relay state.
  status         ENUM('pending','publishing','published','failed','skipped') NOT NULL DEFAULT 'pending',
  destination    VARCHAR(80)     NULL,
  attempts       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  available_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  published_at   DATETIME(3)     NULL,
  last_error     VARCHAR(500)    NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_outbox_event_id (event_id),
  -- The relay poller's only query: pending events that are due, in insertion
  -- order. Kept first in the index list because it runs constantly.
  KEY ix_outbox_relay (status, available_at, id),
  KEY ix_outbox_aggregate (aggregate_type, aggregate_id, sequence_number),
  KEY ix_outbox_correlation (correlation_id),
  -- Retention sweep: published events are pruned, not kept forever.
  KEY ix_outbox_cleanup (status, published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 2 · WORK QUEUE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- queue_definitions
--
-- Named queues with their own concurrency and retry policy, because a queue
-- that mixes "send an email" with "transcode a 4K video" either starves the
-- fast work or over-provisions for the slow.
-- -----------------------------------------------------------------------------
CREATE TABLE queue_definitions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(400)    NULL,
  -- Concurrency and pacing.
  max_workers    SMALLINT UNSIGNED NOT NULL DEFAULT 4,
  max_per_minute INT UNSIGNED    NULL,
  -- How long a worker may hold a message before the claim lapses. Too short
  -- and slow work is processed twice; too long and a crashed worker's messages
  -- sit idle. It belongs per queue, not globally.
  visibility_timeout_seconds INT UNSIGNED NOT NULL DEFAULT 300,
  max_attempts   TINYINT UNSIGNED NOT NULL DEFAULT 5,
  retry_strategy ENUM('immediate','fixed','linear','exponential','exponential_jitter') NOT NULL DEFAULT 'exponential_jitter',
  retry_base_seconds INT UNSIGNED NOT NULL DEFAULT 30,
  retry_max_seconds INT UNSIGNED NOT NULL DEFAULT 3600,
  -- Whether exhausted messages go to the dead-letter table or are discarded.
  dead_letter_enabled TINYINT(1) NOT NULL DEFAULT 1,
  -- Alert when the queue is backing up. A depth threshold nobody watches is
  -- how a backlog becomes an incident.
  depth_alert_threshold INT UNSIGNED NULL,
  age_alert_seconds INT UNSIGNED NULL,
  is_paused      TINYINT(1)      NOT NULL DEFAULT 0,
  paused_reason  VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_queue_definitions_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- queue_messages
--
-- One unit of work.
--
-- The claim is `UPDATE ... SET status='processing', claimed_by=?,
-- visible_at=NOW()+timeout WHERE status='pending' AND visible_at<=NOW()
-- ORDER BY priority, available_at LIMIT n` — which is exactly what
-- ix_queue_claim serves. Getting that index right is the difference between a
-- queue that scales and one that becomes the database's hottest lock.
--
-- `dedupe_key` prevents the same work being enqueued twice while it is still
-- pending: reindexing one listing five times because it was edited five times
-- in a minute is waste the queue should absorb, not the worker.
-- -----------------------------------------------------------------------------
CREATE TABLE queue_messages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  queue_id       INT UNSIGNED    NOT NULL,
  message_type   VARCHAR(120)    NOT NULL,
  payload        JSON            NOT NULL,
  -- Lower runs first. Deliberately narrow so the index stays small.
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 5,
  status         ENUM('pending','processing','completed','failed','dead_lettered','cancelled') NOT NULL DEFAULT 'pending',
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts   TINYINT UNSIGNED NULL,
  -- Scheduling and claim state.
  available_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  visible_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  claimed_by     VARCHAR(80)     NULL,
  claimed_at     DATETIME(3)     NULL,
  started_at     DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  -- Deduplication while pending. See the table comment.
  dedupe_key     VARCHAR(191)    NULL,
  -- Correlation back to the outbox event or request that produced this work.
  correlation_id CHAR(32)        CHARACTER SET ascii NULL,
  outbox_event_id CHAR(26)       NULL,
  organization_id BIGINT UNSIGNED NULL,
  last_error     VARCHAR(1000)   NULL,
  error_class    VARCHAR(120)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- The claim query. Everything else on this table is secondary to it.
  KEY ix_queue_claim (queue_id, status, visible_at, priority, available_at),
  UNIQUE KEY uq_queue_dedupe (queue_id, dedupe_key, status),
  -- Reaping messages whose worker died.
  KEY ix_queue_stuck (status, visible_at),
  KEY ix_queue_correlation (correlation_id),
  KEY ix_queue_cleanup (status, completed_at),
  CONSTRAINT fk_queue_messages_queue FOREIGN KEY (queue_id) REFERENCES queue_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- dead_letter_messages
--
-- Work that exhausted its attempts. Kept with the full payload and the last
-- error so it can be diagnosed and replayed rather than discovered missing.
--
-- A dead-letter queue nobody looks at is the same as no dead-letter queue,
-- which is why `reviewed_at` exists and why the operational dashboard should
-- surface the unreviewed count.
-- -----------------------------------------------------------------------------
CREATE TABLE dead_letter_messages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  queue_id       INT UNSIGNED    NOT NULL,
  original_message_id BIGINT UNSIGNED NULL,
  message_type   VARCHAR(120)    NOT NULL,
  payload        JSON            NOT NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  first_failed_at DATETIME(3)    NULL,
  last_failed_at DATETIME(3)     NULL,
  error_class    VARCHAR(120)    NULL,
  last_error     TEXT            NULL,
  correlation_id CHAR(32)        CHARACTER SET ascii NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- Triage.
  status         ENUM('new','investigating','replayed','discarded','ignored') NOT NULL DEFAULT 'new',
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  resolution_note VARCHAR(1000)  NULL,
  replayed_at    DATETIME(3)     NULL,
  replayed_message_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_dead_letter_triage (status, created_at),
  KEY ix_dead_letter_queue (queue_id, message_type, created_at),
  CONSTRAINT fk_dead_letter_queue FOREIGN KEY (queue_id) REFERENCES queue_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 3 · IDEMPOTENCY AND LOCKING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- idempotency_keys
--
-- The stored result of a completed operation, keyed by the client's
-- idempotency key.
--
-- The important detail is `response_body`. Recording only that an operation
-- happened lets a retry return "duplicate request", which the client cannot
-- act on. Storing the original response means a retry returns the same payment
-- confirmation it would have received the first time, which is what the
-- semantics actually require.
--
-- `request_hash` guards against key reuse with different parameters — a client
-- that reuses a key for a different request has a bug, and returning the old
-- response would hide it. That case returns a conflict instead.
-- -----------------------------------------------------------------------------
CREATE TABLE idempotency_keys (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  idempotency_key VARCHAR(191)   NOT NULL,
  scope          VARCHAR(80)     NOT NULL DEFAULT 'default',
  api_client_id  BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  endpoint       VARCHAR(191)    NULL,
  request_method VARCHAR(10)     NULL,
  request_hash   CHAR(64)        NOT NULL,
  status         ENUM('in_progress','completed','failed') NOT NULL DEFAULT 'in_progress',
  -- The stored result. See the table comment.
  response_status SMALLINT UNSIGNED NULL,
  response_body  MEDIUMTEXT      NULL,
  -- What the operation produced, so a retry can be reconciled against reality.
  resource_type  VARCHAR(60)     NULL,
  resource_id    BIGINT UNSIGNED NULL,
  -- Locking: a second request arriving while the first is still running waits
  -- or is rejected rather than executing concurrently.
  locked_at      DATETIME(3)     NULL,
  locked_by      VARCHAR(80)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_idempotency_key (scope, idempotency_key),
  KEY ix_idempotency_expiry (expires_at),
  KEY ix_idempotency_resource (resource_type, resource_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- distributed_locks
--
-- Mutual exclusion across processes: one scheduler runs the nightly rollup, one
-- worker rebuilds the location tree, one process reconciles a settlement file.
--
-- Every lock carries an expiry. A lock without one survives the death of its
-- holder and blocks the job forever — the classic self-inflicted outage. The
-- fencing token exists so a holder that pauses past its expiry, then wakes and
-- writes, can be detected and rejected by the resource it is writing to.
-- -----------------------------------------------------------------------------
CREATE TABLE distributed_locks (
  lock_name      VARCHAR(191)    NOT NULL,
  holder         VARCHAR(120)    NOT NULL,
  -- Monotonically increasing per acquisition. See the table comment.
  fencing_token  BIGINT UNSIGNED NOT NULL DEFAULT 1,
  acquired_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NOT NULL,
  renewed_at     DATETIME(3)     NULL,
  renewal_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  purpose        VARCHAR(200)    NULL,
  metadata       JSON            NULL,
  PRIMARY KEY (lock_name),
  -- The reaper: expired locks whose holder never released them.
  KEY ix_locks_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- circuit_breakers
--
-- State for the calls we make outward: payment gateways, portals, SMS
-- providers, geocoders.
--
-- When a dependency is failing, continuing to call it makes both systems worse
-- and turns a partial outage into a total one. The breaker opens after
-- `failure_threshold` failures, rejects immediately while open, and lets a
-- single probe through when `half_open_at` arrives. Holding this in the
-- database rather than per-process memory means every worker shares one view of
-- whether the dependency is up.
-- -----------------------------------------------------------------------------
CREATE TABLE circuit_breakers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  breaker_key    VARCHAR(191)    NOT NULL,
  service_name   VARCHAR(120)    NOT NULL,
  state          ENUM('closed','open','half_open') NOT NULL DEFAULT 'closed',
  failure_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  success_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  failure_threshold SMALLINT UNSIGNED NOT NULL DEFAULT 5,
  success_threshold SMALLINT UNSIGNED NOT NULL DEFAULT 2,
  cooldown_seconds INT UNSIGNED  NOT NULL DEFAULT 60,
  opened_at      DATETIME(3)     NULL,
  half_open_at   DATETIME(3)     NULL,
  closed_at      DATETIME(3)     NULL,
  last_failure_at DATETIME(3)    NULL,
  last_failure_reason VARCHAR(500) NULL,
  trip_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_circuit_breakers_key (breaker_key),
  KEY ix_circuit_breakers_state (state, half_open_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · WORKFLOW AND APPROVALS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- workflow_definitions
--
-- One reviewable process, defined in data. Listing moderation, account
-- upgrades, refunds above a threshold, campaign sign-off, contract approval and
-- high-risk KYC are the same shape: something is proposed, one or more people
-- must agree, and the outcome must be attributable years later.
--
-- Building six bespoke versions of that is how approval logic ends up
-- inconsistent — one flow that expires, one that does not, one that lets the
-- requester approve their own request.
-- -----------------------------------------------------------------------------
CREATE TABLE workflow_definitions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  subject_type   ENUM('listing','account','organization','agent','payment','refund','payout','campaign','contract','kyc_profile','promotion','deal','media','content','settings') NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- When this workflow is required. A refund under 500 may be auto-approved
  -- while one over 50,000 needs two signatures.
  trigger_conditions JSON        NULL,
  -- Governance defaults, applied to every instance.
  requires_all_steps TINYINT(1)  NOT NULL DEFAULT 1,
  allow_self_approval TINYINT(1) NOT NULL DEFAULT 0,
  allow_delegation TINYINT(1)    NOT NULL DEFAULT 1,
  expires_after_hours SMALLINT UNSIGNED NULL,
  -- What happens on expiry. Auto-approving on timeout is a real choice some
  -- processes make and a catastrophic one for others, so it is explicit.
  on_expiry      ENUM('reject','approve','escalate','remain_pending') NOT NULL DEFAULT 'escalate',
  status         ENUM('draft','active','superseded','retired') NOT NULL DEFAULT 'draft',
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_workflow_definitions (code, version, organization_id),
  KEY ix_workflow_definitions_subject (subject_type, status),
  CONSTRAINT fk_workflow_definitions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE workflow_steps (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  workflow_id    INT UNSIGNED    NOT NULL,
  step_number    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  step_type      ENUM('approval','review','notification','automated_check','wait','condition') NOT NULL DEFAULT 'approval',
  -- Who may act. A role, a specific user, or anyone holding a permission —
  -- naming a role rather than a person is what keeps the workflow working when
  -- somebody leaves.
  approver_type  ENUM('role','permission','user','manager','queue','any_admin','owner','system') NOT NULL DEFAULT 'role',
  approver_role_id INT UNSIGNED  NULL,
  approver_permission_id INT UNSIGNED NULL,
  approver_user_id BIGINT UNSIGNED NULL,
  -- Quorum. Two of three compliance officers, or all of them.
  required_approvals TINYINT UNSIGNED NOT NULL DEFAULT 1,
  -- Parallel steps run together; sequential ones wait for the previous.
  is_parallel    TINYINT(1)      NOT NULL DEFAULT 0,
  -- Skip this step when the condition does not hold, so one workflow serves
  -- both the routine and the exceptional case.
  skip_condition JSON            NULL,
  sla_hours      SMALLINT UNSIGNED NULL,
  escalate_to_user_id BIGINT UNSIGNED NULL,
  requires_comment TINYINT(1)    NOT NULL DEFAULT 0,
  requires_document TINYINT(1)   NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_workflow_step (workflow_id, step_number),
  CONSTRAINT fk_workflow_steps_workflow FOREIGN KEY (workflow_id) REFERENCES workflow_definitions (id) ON DELETE CASCADE,
  CONSTRAINT fk_workflow_steps_role FOREIGN KEY (approver_role_id) REFERENCES roles (id) ON DELETE SET NULL,
  CONSTRAINT fk_workflow_steps_permission FOREIGN KEY (approver_permission_id) REFERENCES permissions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- workflow_instances
--
-- One running or finished process.
--
-- `snapshot_before` and `snapshot_after` capture what was being changed. An
-- approval record that says "approved" without saying what was approved is
-- worthless the moment the underlying row is edited again — and the edit that
-- matters is usually the one made after approval.
-- -----------------------------------------------------------------------------
CREATE TABLE workflow_instances (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  workflow_id    INT UNSIGNED    NOT NULL,
  workflow_version SMALLINT UNSIGNED NULL,
  subject_type   ENUM('listing','account','organization','agent','payment','refund','payout','campaign','contract','kyc_profile','promotion','deal','media','content','settings') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  title          VARCHAR(255)    NOT NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  request_reason VARCHAR(1000)   NULL,
  -- What is being changed. See the table comment.
  proposed_changes JSON          NULL,
  snapshot_before JSON           NULL,
  snapshot_after JSON            NULL,
  -- Amount at stake, where there is one, so approvals can be prioritised and
  -- thresholds enforced.
  amount         DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  amount_base    DECIMAL(18,2)   NULL,
  status         ENUM('pending','in_progress','approved','rejected','cancelled','expired','escalated','auto_approved') NOT NULL DEFAULT 'pending',
  current_step   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  due_at         DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  decided_by_user_id BIGINT UNSIGNED NULL,
  decision_note  VARCHAR(1000)   NULL,
  -- Set when the outcome was applied to the subject, which is a distinct event
  -- from the decision and can fail on its own.
  applied_at     DATETIME(3)     NULL,
  apply_error    VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_workflow_instances_public (public_id),
  -- The approver's inbox and the expiry sweeper.
  KEY ix_workflow_instances_pending (status, due_at, priority),
  KEY ix_workflow_instances_subject (subject_type, subject_id),
  KEY ix_workflow_instances_requester (requested_by_user_id, status),
  KEY ix_workflow_instances_org (organization_id, status, started_at),
  CONSTRAINT fk_workflow_instances_workflow FOREIGN KEY (workflow_id) REFERENCES workflow_definitions (id),
  CONSTRAINT fk_workflow_instances_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- workflow_actions
--
-- Every decision taken on an instance, append-only.
--
-- `delegated_from_user_id` matters more than it looks: an approval given by a
-- deputy while the approver is on leave is legitimate, but only if the chain is
-- recorded. An audit that cannot distinguish "the CFO approved this" from "the
-- CFO's assistant approved this using the CFO's login" is not an audit.
-- -----------------------------------------------------------------------------
CREATE TABLE workflow_actions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  instance_id    BIGINT UNSIGNED NOT NULL,
  step_id        INT UNSIGNED    NULL,
  step_number    SMALLINT UNSIGNED NULL,
  action         ENUM('submitted','approved','rejected','commented','requested_changes','delegated','reassigned','escalated','cancelled','expired','auto_approved','reminded') NOT NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  actor_role     VARCHAR(80)     NULL,
  delegated_from_user_id BIGINT UNSIGNED NULL,
  comment        VARCHAR(2000)   NULL,
  document_id    BIGINT UNSIGNED NULL,
  -- Evidence of who acted and from where, for the same reason signatures carry
  -- it in 0024.
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(300)    NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_workflow_actions_instance (instance_id, occurred_at),
  KEY ix_workflow_actions_actor (actor_user_id, occurred_at),
  CONSTRAINT fk_workflow_actions_instance FOREIGN KEY (instance_id) REFERENCES workflow_instances (id) ON DELETE CASCADE,
  CONSTRAINT fk_workflow_actions_step FOREIGN KEY (step_id) REFERENCES workflow_steps (id) ON DELETE SET NULL,
  CONSTRAINT fk_workflow_actions_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- approval_delegations
--
-- Standing authority for one person to act for another over a period. Bounded
-- in time and scope on purpose: an open-ended delegation is a permission
-- escalation that nobody remembers granting.
-- -----------------------------------------------------------------------------
CREATE TABLE approval_delegations (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  from_user_id   BIGINT UNSIGNED NOT NULL,
  to_user_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  workflow_id    INT UNSIGNED    NULL,
  -- Cap what may be approved under delegation, which is the usual condition of
  -- granting it.
  max_amount     DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  reason         VARCHAR(300)    NULL,
  starts_at      DATETIME(3)     NOT NULL,
  ends_at        DATETIME(3)     NOT NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  revoked_at     DATETIME(3)     NULL,
  revoked_by_user_id BIGINT UNSIGNED NULL,
  used_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_delegations_active (to_user_id, is_active, starts_at, ends_at),
  KEY ix_delegations_from (from_user_id, is_active),
  CONSTRAINT fk_delegations_from FOREIGN KEY (from_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_delegations_to FOREIGN KEY (to_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_delegations_workflow FOREIGN KEY (workflow_id) REFERENCES workflow_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 5 · OPERATIONAL HEALTH
-- =============================================================================

-- -----------------------------------------------------------------------------
-- service_health_checks
--
-- The current state of every dependency, one row each, updated in place. Not a
-- log — the log is `system_logs` — but the answer to "what is broken right
-- now", which a status page and an on-call engineer both need in one query.
-- -----------------------------------------------------------------------------
CREATE TABLE service_health_checks (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  service_code   VARCHAR(80)     NOT NULL,
  service_name   VARCHAR(160)    NOT NULL,
  service_type   ENUM('database','cache','search','storage','queue','payment','email','sms','geocoding','portal','cdn','internal_api','external_api') NOT NULL,
  -- Whether the platform can serve without it. A degraded geocoder is
  -- annoying; a degraded database is an outage, and the status page must say so
  -- differently.
  is_critical    TINYINT(1)      NOT NULL DEFAULT 0,
  status         ENUM('healthy','degraded','unhealthy','maintenance','unknown') NOT NULL DEFAULT 'unknown',
  last_check_at  DATETIME(3)     NULL,
  last_healthy_at DATETIME(3)    NULL,
  response_time_ms INT UNSIGNED  NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  error_message  VARCHAR(500)    NULL,
  -- Rolling availability, so an SLA claim is computed rather than asserted.
  uptime_24h_percent DECIMAL(6,3) NULL,
  uptime_30d_percent DECIMAL(6,3) NULL,
  check_interval_seconds SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  is_enabled     TINYINT(1)      NOT NULL DEFAULT 1,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_health_checks_code (service_code),
  KEY ix_health_checks_status (status, is_critical)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- maintenance_windows
--
-- Planned downtime and degradation, announced in advance. Present in the schema
-- because it has to be visible to the status page, the API's Retry-After
-- headers, the alerting suppression and the customer notification — and if it
-- lives in someone's calendar instead, alerting pages the on-call engineer at
-- 02:00 for work that was scheduled.
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_windows (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  title          VARCHAR(200)    NOT NULL,
  description    TEXT            NULL,
  window_type    ENUM('scheduled','emergency','degraded','migration') NOT NULL DEFAULT 'scheduled',
  affected_services JSON         NULL,
  impact         ENUM('none','minor','partial_outage','full_outage') NOT NULL DEFAULT 'minor',
  starts_at      DATETIME(3)     NOT NULL,
  ends_at        DATETIME(3)     NOT NULL,
  actual_started_at DATETIME(3)  NULL,
  actual_ended_at DATETIME(3)    NULL,
  status         ENUM('planned','notified','in_progress','completed','cancelled','extended') NOT NULL DEFAULT 'planned',
  -- Customer communication.
  notify_customers TINYINT(1)    NOT NULL DEFAULT 1,
  notified_at    DATETIME(3)     NULL,
  status_page_published TINYINT(1) NOT NULL DEFAULT 0,
  -- Suppress alerting for the affected services during the window.
  suppress_alerts TINYINT(1)     NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_maintenance_windows_public (public_id),
  KEY ix_maintenance_windows_schedule (status, starts_at, ends_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0026', 'platform_operations');
