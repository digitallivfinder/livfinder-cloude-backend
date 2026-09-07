-- =============================================================================
-- Liv Finder — 0012 · Analytics
-- =============================================================================
-- Raw events, and the rollups that every dashboard actually reads.
--
-- THE RULE: NO DASHBOARD EVER QUERIES `analytics_events`.
-- -------------------------------------------------------
-- The raw event stream is write-optimised and enormous — one row per listing
-- view, per search, per contact click. Aggregating it at request time is what
-- turns a dashboard into an outage. Everything user-facing reads a `*_daily`
-- rollup, which is small, pre-aggregated and indexed for exactly the query the
-- dashboard makes.
--
-- The audit found every dashboard number in the product to be either hardcoded
-- or decorative — "Total Views 1.2M", "Conversion Rate 2.45%", inquiry
-- breakdowns that did not match the data. These tables are where those numbers
-- come from instead.
--
-- Design notes:
--   · No foreign keys on the event tables. InnoDB forbids them on partitioned
--     tables, and a view event must not be blocked by a lock on `listings`.
--     Referential drift is acceptable here and is reconciled by the rollup job.
--   · Partitioned by month; retention is DROP PARTITION, not DELETE.
--   · Counters on `listings`/`agents`/`organizations` are refreshed from these
--     rollups on a schedule, never incremented on the request path — a hot
--     listing would otherwise serialise every viewer behind one row lock.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- analytics_events — the raw stream
-- -----------------------------------------------------------------------------
CREATE TABLE analytics_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  event_type     ENUM('page_view','listing_view','listing_impression','search','filter_applied','contact_view','call_click','whatsapp_click','email_click','inquiry_submit','favourite_add','favourite_remove','share','brochure_request','video_play','virtual_tour_open','map_open','signup','login','listing_publish','agent_profile_view','organization_profile_view','post_view','outbound_click') NOT NULL,

  -- What was interacted with. Untyped id + string type because events cover a
  -- dozen subject kinds and this table must never join.
  subject_type   VARCHAR(40)     NULL,
  subject_id     BIGINT UNSIGNED NULL,

  -- Denormalised dimensions, captured at write time. Rollups group by these
  -- without joining anything, which is the entire point.
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,

  user_id        BIGINT UNSIGNED NULL,
  -- Anonymous visitor identifier, so unique-view counts work without a login.
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,

  device_type    ENUM('desktop','mobile','tablet','bot','other') NOT NULL DEFAULT 'other',
  browser        VARCHAR(60)     NULL,
  os             VARCHAR(60)     NULL,
  ip_country_id  BIGINT UNSIGNED NULL,
  referrer_host  VARCHAR(191)    NULL,
  utm_source     VARCHAR(120)    NULL,
  utm_medium     VARCHAR(120)    NULL,
  utm_campaign   VARCHAR(160)    NULL,
  url_path       VARCHAR(500)    NULL,

  -- Event-specific payload: the query and filters for a search, the position in
  -- results for an impression.
  properties     JSON            NULL,
  value          DECIMAL(18,2)   NULL,

  PRIMARY KEY (id, occurred_at),
  KEY ix_events_subject (subject_type, subject_id, occurred_at),
  KEY ix_events_type (event_type, occurred_at),
  KEY ix_events_org (organization_id, event_type, occurred_at),
  KEY ix_events_agent (agent_id, event_type, occurred_at),
  KEY ix_events_visitor (visitor_id, occurred_at),
  KEY ix_events_campaign (utm_source, utm_campaign, occurred_at)
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
-- listing_daily_stats — the rollup behind every listing performance chart
-- -----------------------------------------------------------------------------
CREATE TABLE listing_daily_stats (
  listing_id     BIGINT UNSIGNED NOT NULL,
  stat_date      DATE            NOT NULL,
  -- Impressions are appearances in a result list; views are detail-page opens.
  -- Keeping them apart is what makes a meaningful click-through rate possible.
  impressions    INT UNSIGNED    NOT NULL DEFAULT 0,
  views          INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_views   INT UNSIGNED    NOT NULL DEFAULT 0,
  contact_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  call_clicks    INT UNSIGNED    NOT NULL DEFAULT 0,
  whatsapp_clicks INT UNSIGNED   NOT NULL DEFAULT 0,
  email_clicks   INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  favourites     INT UNSIGNED    NOT NULL DEFAULT 0,
  shares         INT UNSIGNED    NOT NULL DEFAULT 0,
  brochure_requests INT UNSIGNED NOT NULL DEFAULT 0,
  avg_time_on_page_seconds INT UNSIGNED NULL,
  -- Denormalised so the agency dashboard can aggregate by org/agent without
  -- joining back to `listings` for 50,000 rows.
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  -- Date-first PK: every read is a date range for one listing, and this makes
  -- that range contiguous in the clustered index.
  PRIMARY KEY (listing_id, stat_date),
  KEY ix_lds_date (stat_date),
  KEY ix_lds_org (organization_id, stat_date),
  KEY ix_lds_agent (agent_id, stat_date),
  KEY ix_lds_category (category_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- organization_daily_stats / agent_daily_stats
-- -----------------------------------------------------------------------------
CREATE TABLE organization_daily_stats (
  organization_id BIGINT UNSIGNED NOT NULL,
  stat_date      DATE            NOT NULL,
  profile_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_impressions INT UNSIGNED NOT NULL DEFAULT 0,
  listing_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  calls          INT UNSIGNED    NOT NULL DEFAULT 0,
  whatsapp_clicks INT UNSIGNED   NOT NULL DEFAULT 0,
  bookings       INT UNSIGNED    NOT NULL DEFAULT 0,
  offers         INT UNSIGNED    NOT NULL DEFAULT 0,
  active_listings INT UNSIGNED   NOT NULL DEFAULT 0,
  new_listings   INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Median rather than mean: one agent on holiday should not wreck the number.
  median_response_minutes INT UNSIGNED NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (organization_id, stat_date),
  KEY ix_ods_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE agent_daily_stats (
  agent_id       BIGINT UNSIGNED NOT NULL,
  stat_date      DATE            NOT NULL,
  profile_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries_responded INT UNSIGNED NOT NULL DEFAULT 0,
  calls          INT UNSIGNED    NOT NULL DEFAULT 0,
  whatsapp_clicks INT UNSIGNED   NOT NULL DEFAULT 0,
  bookings       INT UNSIGNED    NOT NULL DEFAULT 0,
  active_listings INT UNSIGNED   NOT NULL DEFAULT 0,
  median_response_minutes INT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (agent_id, stat_date),
  KEY ix_ads_date (stat_date),
  KEY ix_ads_org (organization_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- platform_daily_stats — the admin dashboard's KPI row
--
-- One row per day. Every "vs last 30 days" delta on the admin dashboard is a
-- comparison of two windows over this table.
-- -----------------------------------------------------------------------------
CREATE TABLE platform_daily_stats (
  stat_date      DATE            NOT NULL,
  total_listings INT UNSIGNED    NOT NULL DEFAULT 0,
  active_listings INT UNSIGNED   NOT NULL DEFAULT 0,
  new_listings   INT UNSIGNED    NOT NULL DEFAULT 0,
  pending_listings INT UNSIGNED  NOT NULL DEFAULT 0,
  sold_rented_listings INT UNSIGNED NOT NULL DEFAULT 0,
  total_users    INT UNSIGNED    NOT NULL DEFAULT 0,
  new_users      INT UNSIGNED    NOT NULL DEFAULT 0,
  active_users   INT UNSIGNED    NOT NULL DEFAULT 0,
  total_agents   INT UNSIGNED    NOT NULL DEFAULT 0,
  active_agents  INT UNSIGNED    NOT NULL DEFAULT 0,
  total_organizations INT UNSIGNED NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  bookings       INT UNSIGNED    NOT NULL DEFAULT 0,
  offers         INT UNSIGNED    NOT NULL DEFAULT 0,
  page_views     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  unique_visitors BIGINT UNSIGNED NOT NULL DEFAULT 0,
  -- Sales volume is summed in the base currency; per-currency detail lives in
  -- the ledger.
  sales_volume_base DECIMAL(20,2) NOT NULL DEFAULT 0,
  revenue_base   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- search_queries — what people actually look for
--
-- Two jobs: powering the "popular searches" module and, more valuably, exposing
-- demand the inventory does not meet. A high-volume query with `result_count`
-- consistently at zero is a market-expansion signal.
-- -----------------------------------------------------------------------------
CREATE TABLE search_queries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  query_text     VARCHAR(255)    NOT NULL,
  -- Lower-cased, trimmed, accent-folded, so "Palm Jumeirah " and "palm jumeirah"
  -- aggregate into one row instead of two.
  query_normalized VARCHAR(255)  NOT NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  filters        JSON            NULL,
  result_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  clicked_listing_id BIGINT UNSIGNED NULL,
  click_position SMALLINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  searched_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_search_queries_normalized (query_normalized, searched_at),
  -- Finds unmet demand.
  KEY ix_search_queries_zero (result_count, searched_at),
  KEY ix_search_queries_date (searched_at),
  KEY ix_search_queries_user (user_id, searched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Pre-aggregated popular searches, so the homepage module is a small indexed
-- read rather than a GROUP BY over the raw log.
CREATE TABLE search_query_daily_stats (
  query_normalized VARCHAR(191)  NOT NULL,
  stat_date      DATE            NOT NULL,
  search_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  click_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  zero_result_count INT UNSIGNED NOT NULL DEFAULT 0,
  avg_result_count INT UNSIGNED  NULL,
  category_id    INT UNSIGNED    NULL,
  PRIMARY KEY (query_normalized, stat_date),
  KEY ix_sqds_top (stat_date, search_count)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- price_index_daily — market analytics
--
-- Median price per area, per (location, category, purpose), per day. Feeds
-- market reports, the "priced below area average" badge, and valuation tooling.
-- -----------------------------------------------------------------------------
CREATE TABLE price_index_daily (
  location_id    BIGINT UNSIGNED NOT NULL,
  category_id    INT UNSIGNED    NOT NULL,
  purpose_id     SMALLINT UNSIGNED NOT NULL,
  stat_date      DATE            NOT NULL,
  listing_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Median, not mean: one AED 500m penthouse should not move the index for a
  -- community of AED 3m apartments.
  median_price_base DECIMAL(18,2) NULL,
  avg_price_base DECIMAL(18,2)   NULL,
  min_price_base DECIMAL(18,2)   NULL,
  max_price_base DECIMAL(18,2)   NULL,
  median_price_per_sqft DECIMAL(14,2) NULL,
  avg_days_on_market SMALLINT UNSIGNED NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (location_id, category_id, purpose_id, stat_date),
  KEY ix_pid_date (stat_date),
  KEY ix_pid_category (category_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- jobs / job_runs — the scheduled work this schema depends on
--
-- Every rollup, counter refresh, FX update, alert dispatch and partition
-- maintenance task is registered here, so "why is this number stale?" has an
-- answer visible in the admin portal rather than in a server's crontab.
-- -----------------------------------------------------------------------------
CREATE TABLE jobs (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(80)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  schedule_cron  VARCHAR(60)     NULL,
  is_enabled     TINYINT(1)      NOT NULL DEFAULT 1,
  last_run_at    DATETIME(3)     NULL,
  last_status    ENUM('never','running','success','failed','skipped') NOT NULL DEFAULT 'never',
  next_run_at    DATETIME(3)     NULL,
  -- Alerting threshold: a job that has not succeeded within this window is
  -- surfaced as unhealthy.
  max_staleness_minutes INT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_jobs_code (code),
  KEY ix_jobs_schedule (is_enabled, next_run_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE job_runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  job_id         INT UNSIGNED    NOT NULL,
  status         ENUM('running','success','failed','cancelled','timeout') NOT NULL DEFAULT 'running',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  finished_at    DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  rows_processed BIGINT UNSIGNED NULL,
  error_message  VARCHAR(1000)   NULL,
  output         JSON            NULL,
  PRIMARY KEY (id),
  KEY ix_job_runs_job (job_id, started_at),
  KEY ix_job_runs_status (status, started_at),
  CONSTRAINT fk_job_runs_job FOREIGN KEY (job_id) REFERENCES jobs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- webhooks — outbound integrations
-- -----------------------------------------------------------------------------
CREATE TABLE webhooks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  api_client_id  BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  target_url     VARCHAR(700)    NOT NULL,
  -- Subscribed event names: ["listing.published","inquiry.created"].
  events         JSON            NOT NULL,
  -- Shared secret for the HMAC signature header, so the receiver can verify the
  -- payload really came from us.
  secret_hash    BINARY(32)      NULL,
  status         ENUM('active','paused','failing','disabled') NOT NULL DEFAULT 'active',
  -- Auto-disable after sustained failure, rather than retrying a dead endpoint
  -- forever.
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_success_at DATETIME(3)    NULL,
  last_failure_at DATETIME(3)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_webhooks_public_id (public_id),
  KEY ix_webhooks_account (account_id, status),
  CONSTRAINT fk_webhooks_account FOREIGN KEY (account_id)    REFERENCES accounts (id)    ON DELETE CASCADE,
  CONSTRAINT fk_webhooks_client  FOREIGN KEY (api_client_id) REFERENCES api_clients (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE webhook_deliveries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  webhook_id     BIGINT UNSIGNED NOT NULL,
  event_type     VARCHAR(80)     NOT NULL,
  payload        JSON            NOT NULL,
  status         ENUM('pending','delivered','failed','abandoned') NOT NULL DEFAULT 'pending',
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  response_status SMALLINT UNSIGNED NULL,
  response_body  VARCHAR(2000)   NULL,
  duration_ms    INT UNSIGNED    NULL,
  -- Exponential backoff target for the retry worker.
  next_retry_at  DATETIME(3)     NULL,
  delivered_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_webhook_deliveries_webhook (webhook_id, created_at),
  KEY ix_webhook_deliveries_retry (status, next_retry_at),
  CONSTRAINT fk_webhook_deliveries_webhook FOREIGN KEY (webhook_id) REFERENCES webhooks (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0012', 'analytics');
