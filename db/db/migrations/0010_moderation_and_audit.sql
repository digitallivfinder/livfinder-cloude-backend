-- =============================================================================
-- Liv Finder — 0010 · Moderation, reports and audit
-- =============================================================================
-- The audit was explicit that this layer does not exist yet: "there is no
-- production admin API, persistent moderation, or audit store", and the report
-- action modals mutate React state only. These tables are that store.
--
-- `audit_logs` is append-only and time-partitioned. It is the one table in the
-- schema with no foreign keys, deliberately: an audit record must survive the
-- deletion of everything it refers to, or it is not an audit record.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- report_reasons — the taxonomy behind the "report this" flow
-- -----------------------------------------------------------------------------
CREATE TABLE report_reasons (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  -- Which kinds of thing this reason can be filed against, so the report form
  -- offers "Wrong price" for listings but not for reviews.
  applies_to     SET('listing','agent','organization','review','message','user','project') NOT NULL,
  -- Reasons that skip triage and go straight to the urgent queue (fraud,
  -- impersonation, illegal content).
  is_severe      TINYINT(1)      NOT NULL DEFAULT 0,
  auto_hide_threshold SMALLINT UNSIGNED NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_report_reasons_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- reports — user-submitted content reports
-- -----------------------------------------------------------------------------
CREATE TABLE reports (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(32)     NOT NULL,

  subject_type   ENUM('listing','agent','organization','review','message','user','project') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  -- Snapshot of what was reported. The reported content is frequently edited or
  -- deleted between report and review; without this the moderator is judging
  -- something they cannot see.
  subject_snapshot JSON          NULL,

  reason_id      SMALLINT UNSIGNED NULL,
  details        TEXT            NULL,

  reporter_user_id BIGINT UNSIGNED NULL,
  reporter_email VARCHAR(255)    NULL,
  reporter_ip    VARBINARY(16)   NULL,

  status         ENUM('new','triaged','in_review','escalated','resolved','dismissed','duplicate') NOT NULL DEFAULT 'new',
  priority       ENUM('low','normal','high','urgent') NOT NULL DEFAULT 'normal',
  assigned_to_user_id BIGINT UNSIGNED NULL,
  assigned_at    DATETIME(3)     NULL,

  resolution     ENUM('no_action','content_removed','content_edited','listing_unpublished','account_warned','account_suspended','account_banned','escalated_legal') NULL,
  resolution_note VARCHAR(1000)  NULL,
  resolved_by_user_id BIGINT UNSIGNED NULL,
  resolved_at    DATETIME(3)     NULL,

  duplicate_of_id BIGINT UNSIGNED NULL,
  -- Number of independent reports against the same subject, kept on the first
  -- report so the queue can sort by "how many people complained".
  report_count   INT UNSIGNED    NOT NULL DEFAULT 1,

  -- Statutory clock for jurisdictions with mandated takedown windows (DSA).
  due_at         DATETIME(3)     NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_reports_public_id (public_id),
  UNIQUE KEY uq_reports_reference (reference),
  -- The moderation queue's default ordering.
  KEY ix_reports_queue (status, priority, created_at),
  KEY ix_reports_subject (subject_type, subject_id, status),
  KEY ix_reports_assignee (assigned_to_user_id, status),
  KEY ix_reports_reporter (reporter_user_id),
  KEY ix_reports_reason (reason_id, status),
  KEY ix_reports_sla (status, due_at),
  CONSTRAINT fk_reports_reason    FOREIGN KEY (reason_id)           REFERENCES report_reasons (id) ON DELETE SET NULL,
  CONSTRAINT fk_reports_reporter  FOREIGN KEY (reporter_user_id)    REFERENCES users (id)          ON DELETE SET NULL,
  CONSTRAINT fk_reports_assignee  FOREIGN KEY (assigned_to_user_id) REFERENCES users (id)          ON DELETE SET NULL,
  CONSTRAINT fk_reports_resolver  FOREIGN KEY (resolved_by_user_id) REFERENCES users (id)          ON DELETE SET NULL,
  CONSTRAINT fk_reports_duplicate FOREIGN KEY (duplicate_of_id)     REFERENCES reports (id)        ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Every moderator action on a report. The audit found six report action modals
-- (assign, change status, add note, escalate, resolve, dismiss) that persisted
-- nothing; each writes a row here.
CREATE TABLE report_actions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  report_id      BIGINT UNSIGNED NOT NULL,
  action_type    ENUM('created','assigned','unassigned','status_changed','priority_changed','note_added','escalated','resolved','dismissed','reopened','content_actioned') NOT NULL,
  from_value     VARCHAR(80)     NULL,
  to_value       VARCHAR(80)     NULL,
  note           TEXT            NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  -- Internal notes are invisible to the reporter; the rest may appear in the
  -- "what happened to my report" response.
  is_internal    TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_report_actions_report (report_id, created_at),
  KEY ix_report_actions_actor (actor_user_id, created_at),
  CONSTRAINT fk_report_actions_report FOREIGN KEY (report_id)     REFERENCES reports (id) ON DELETE CASCADE,
  CONSTRAINT fk_report_actions_actor  FOREIGN KEY (actor_user_id) REFERENCES users (id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- moderation_queue — proactive review, distinct from user reports
--
-- Fed by automated checks (duplicate detection, price anomalies, banned terms,
-- image similarity) rather than by complaints. Separate table because the
-- lifecycle and the triage criteria genuinely differ.
-- -----------------------------------------------------------------------------
CREATE TABLE moderation_queue (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subject_type   ENUM('listing','agent','organization','review','user','media','project') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  queue_reason   ENUM('new_submission','edited','flagged_automatic','duplicate_suspected','price_anomaly','banned_terms','image_check','identity_check','random_audit') NOT NULL,
  -- 0–100 from the automated classifier; drives ordering within the queue.
  risk_score     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  signals        JSON            NULL,
  status         ENUM('pending','in_review','approved','rejected','skipped') NOT NULL DEFAULT 'pending',
  assigned_to_user_id BIGINT UNSIGNED NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  decision_note  VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_moderation_queue (status, risk_score, created_at),
  KEY ix_moderation_subject (subject_type, subject_id, status),
  KEY ix_moderation_assignee (assigned_to_user_id, status),
  CONSTRAINT fk_mq_assignee FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_mq_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- audit_logs — append-only, partitioned, no foreign keys
--
-- Partitioned by month so retention is a DROP PARTITION (instant) rather than a
-- DELETE over hundreds of millions of rows (hours, and a bloated tablespace).
-- FKs are intentionally absent: InnoDB forbids them on partitioned tables, and
-- more importantly an audit row must outlive its subject.
--
-- Add partitions ahead of time — see tools/maintain_partitions.sql. Rows whose
-- date exceeds the last defined partition land in `p_max`.
-- -----------------------------------------------------------------------------
CREATE TABLE audit_logs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  actor_user_id  BIGINT UNSIGNED NULL,
  actor_type     ENUM('user','admin','system','api','job','anonymous') NOT NULL DEFAULT 'user',
  actor_label    VARCHAR(200)    NULL,
  -- Set when the action was taken while impersonating; without it, support
  -- actions are indistinguishable from the customer's own.
  impersonator_user_id BIGINT UNSIGNED NULL,

  action         VARCHAR(80)     NOT NULL,
  subject_type   VARCHAR(60)     NOT NULL,
  subject_id     BIGINT UNSIGNED NULL,
  subject_label  VARCHAR(255)    NULL,

  -- Field-level before/after. Storing both, rather than only the new value, is
  -- what lets a dispute be settled from the log alone.
  changes        JSON            NULL,
  metadata       JSON            NULL,

  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,
  request_id     CHAR(26)        CHARACTER SET ascii NULL,
  session_id     BIGINT UNSIGNED NULL,

  -- The PK must include the partitioning column: MySQL requires every unique
  -- index to contain it.
  PRIMARY KEY (id, occurred_at),
  KEY ix_audit_subject (subject_type, subject_id, occurred_at),
  KEY ix_audit_actor (actor_user_id, occurred_at),
  KEY ix_audit_action (action, occurred_at),
  KEY ix_audit_request (request_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_01 VALUES LESS THAN (TO_DAYS('2026-02-01')),
  PARTITION p2026_02 VALUES LESS THAN (TO_DAYS('2026-03-01')),
  PARTITION p2026_03 VALUES LESS THAN (TO_DAYS('2026-04-01')),
  PARTITION p2026_04 VALUES LESS THAN (TO_DAYS('2026-05-01')),
  PARTITION p2026_05 VALUES LESS THAN (TO_DAYS('2026-06-01')),
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p2027_01 VALUES LESS THAN (TO_DAYS('2027-02-01')),
  PARTITION p2027_02 VALUES LESS THAN (TO_DAYS('2027-03-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- system_logs — the admin System Logs screen
--
-- Application/infrastructure events, kept apart from `audit_logs` because they
-- answer a different question ("is the system healthy") and have a much shorter
-- retention.
-- -----------------------------------------------------------------------------
CREATE TABLE system_logs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  level          ENUM('debug','info','notice','warning','error','critical','alert','emergency') NOT NULL DEFAULT 'info',
  channel        VARCHAR(60)     NOT NULL DEFAULT 'app',
  message        VARCHAR(1000)   NOT NULL,
  context        JSON            NULL,
  exception_class VARCHAR(191)   NULL,
  stack_trace    MEDIUMTEXT      NULL,
  request_id     CHAR(26)        CHARACTER SET ascii NULL,
  user_id        BIGINT UNSIGNED NULL,
  ip_address     VARBINARY(16)   NULL,
  url            VARCHAR(700)    NULL,
  http_method    VARCHAR(10)     NULL,
  http_status    SMALLINT UNSIGNED NULL,
  duration_ms    INT UNSIGNED    NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_system_logs_level (level, occurred_at),
  KEY ix_system_logs_channel (channel, occurred_at),
  KEY ix_system_logs_request (request_id),
  KEY ix_system_logs_user (user_id, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- Abuse controls
-- -----------------------------------------------------------------------------
CREATE TABLE user_blocks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  blocker_user_id BIGINT UNSIGNED NOT NULL,
  blocked_user_id BIGINT UNSIGNED NOT NULL,
  reason         VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_user_blocks (blocker_user_id, blocked_user_id),
  KEY ix_user_blocks_blocked (blocked_user_id),
  CONSTRAINT fk_user_blocks_blocker FOREIGN KEY (blocker_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_blocks_blocked FOREIGN KEY (blocked_user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Platform-level bans on identifiers rather than accounts, so a banned actor
-- cannot simply register again from the same email domain or IP range.
CREATE TABLE blocklist_entries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  entry_type     ENUM('email','email_domain','ip','ip_range','phone','device','keyword') NOT NULL,
  value          VARCHAR(255)    NOT NULL,
  reason         VARCHAR(500)    NULL,
  -- 'flag' quarantines for review; 'block' refuses outright. Starting at 'flag'
  -- for a new rule avoids locking out real customers on a bad pattern.
  action         ENUM('block','flag','throttle') NOT NULL DEFAULT 'block',
  hit_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_blocklist (entry_type, value),
  KEY ix_blocklist_expiry (expires_at),
  CONSTRAINT fk_blocklist_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Backs rate limiting where it must survive a process restart (login attempts,
-- enquiry submissions, API calls). Hot counters belong in Redis; this is the
-- durable record and the source for abuse investigation.
CREATE TABLE rate_limit_counters (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  -- Composite of scope and identity: "login:203.0.113.7", "inquiry:user:5512".
  bucket_key     VARCHAR(191)    NOT NULL,
  window_start   DATETIME(3)     NOT NULL,
  window_seconds INT UNSIGNED    NOT NULL,
  hit_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  blocked_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rate_limit (bucket_key, window_start),
  KEY ix_rate_limit_expiry (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0010', 'moderation_and_audit');
