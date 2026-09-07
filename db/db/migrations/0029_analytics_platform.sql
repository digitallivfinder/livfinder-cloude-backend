-- =============================================================================
-- Liv Finder — 0029 · Analytics platform
-- =============================================================================
-- Migration 0012 gave the raw event stream and a set of daily rollups. That is
-- the data. This is the apparatus for asking questions of it, and the two are
-- genuinely different problems.
--
-- A rollup answers a question somebody already knew to ask. Everything here
-- exists to answer questions nobody has asked yet, and to make the answers
-- consistent when several people ask the same one:
--
-- SESSIONS. The visit is the unit of user behaviour, not the page view. A
-- session ties an anonymous visitor's twenty page views, three searches and one
-- enquiry into a story with an entry point, a path and an outcome.
--
-- ATTRIBUTION. A buyer finds a listing through a Google search, comes back via
-- an email, then converts on a direct visit two weeks later. Which of those
-- gets the credit decides where the marketing budget goes, and the honest
-- answer is that it depends on the model. `attribution_models` makes the model
-- explicit and comparable rather than an unexamined default of last-click.
--
-- FUNNELS AND COHORTS. Conversion is a sequence and retention is a curve;
-- neither is a number. Both are precomputed here because both are expensive and
-- both are looked at daily.
--
-- KPIs. `kpi_definitions` is the metric dictionary — one definition of "active
-- listing", one of "qualified lead", one of "conversion rate", written down.
-- The alternative is what most companies have: four dashboards showing four
-- different numbers for the same metric, and a standing argument about which is
-- right.
--
-- One deliberate constraint: nothing in this migration reads the raw event
-- tables at request time. Every table here is either written by a batch job or
-- read by a dashboard, and the boundary between them is the point.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · SESSIONS AND ATTRIBUTION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- web_sessions
--
-- One visit. Written on first request, updated as it proceeds, closed by
-- inactivity.
--
-- Distinct from `user_sessions` in 0004, which is an authentication artefact
-- holding a token hash and answering "is this person logged in". This one is a
-- behavioural artefact answering "what did this visit consist of", and it exists
-- for anonymous visitors too — who are the overwhelming majority on a property
-- portal.
--
-- The engagement columns are denormalised counters maintained during the
-- session rather than derived afterwards, because the exit-intent and
-- personalisation logic reads them mid-visit.
-- -----------------------------------------------------------------------------
CREATE TABLE web_sessions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  session_id     CHAR(32)        CHARACTER SET ascii NOT NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  -- Entry.
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  ended_at       DATETIME(3)     NULL,
  last_activity_at DATETIME(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  duration_seconds INT UNSIGNED  NULL,
  landing_url    VARCHAR(500)    NULL,
  landing_page_type VARCHAR(40)  NULL,
  exit_url       VARCHAR(500)    NULL,
  referrer_url   VARCHAR(500)    NULL,
  referrer_host  VARCHAR(191)    NULL,
  -- Acquisition, resolved once at session start. Denormalised onto every
  -- session because every acquisition report groups by it.
  channel        ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','unknown') NOT NULL DEFAULT 'unknown',
  source         VARCHAR(120)    NULL,
  medium         VARCHAR(120)    NULL,
  campaign       VARCHAR(160)    NULL,
  content        VARCHAR(160)    NULL,
  term           VARCHAR(160)    NULL,
  gclid          VARCHAR(200)    NULL,
  fbclid         VARCHAR(200)    NULL,
  affiliate_click_token CHAR(32) CHARACTER SET ascii NULL,
  -- Context.
  device_type    ENUM('desktop','mobile','tablet','app','bot','other') NOT NULL DEFAULT 'other',
  browser        VARCHAR(60)     NULL,
  browser_version VARCHAR(30)    NULL,
  os             VARCHAR(60)     NULL,
  screen_width   SMALLINT UNSIGNED NULL,
  language_code  VARCHAR(12)     NULL,
  currency_code  CHAR(3)         NULL,
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  ip_hash        CHAR(64)        NULL,
  -- Engagement. See the table comment on why these are maintained live.
  page_views     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  searches       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  listing_views  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  unique_listings_viewed SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  favourites     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  inquiries      SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  calls          SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  whatsapp_clicks SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Outcome.
  is_bounce      TINYINT(1)      NOT NULL DEFAULT 0,
  converted      TINYINT(1)      NOT NULL DEFAULT 0,
  conversion_type ENUM('inquiry','call','whatsapp','signup','saved_search','favourite','purchase','listing_created','none') NOT NULL DEFAULT 'none',
  conversion_value DECIMAL(14,2) NULL,
  -- Whether this was the visitor's first ever session, which changes how every
  -- engagement number should be read.
  is_new_visitor TINYINT(1)      NOT NULL DEFAULT 1,
  session_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  is_bot         TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_web_sessions_session (session_id),
  KEY ix_web_sessions_visitor (visitor_id, started_at),
  KEY ix_web_sessions_user (user_id, started_at),
  KEY ix_web_sessions_channel (channel, started_at),
  KEY ix_web_sessions_campaign (campaign, started_at),
  KEY ix_web_sessions_converted (converted, started_at),
  -- The session closer: stale sessions with no end time.
  KEY ix_web_sessions_open (ended_at, last_activity_at),
  KEY ix_web_sessions_tenant (tenant_id, started_at),
  CONSTRAINT fk_web_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_web_sessions_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- attribution_models
--
-- How credit is divided between the touchpoints that preceded a conversion.
--
-- Several models coexist deliberately. Last-click flatters paid search;
-- first-click flatters brand and content; position-based splits the difference
-- and is what most marketing teams settle on. Recording which model produced a
-- number is what makes two reports reconcilable — and the lookback window
-- matters as much as the model, because a 90-day window in a market where
-- people take six months to buy is itself a decision.
-- -----------------------------------------------------------------------------
CREATE TABLE attribution_models (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  model_type     ENUM('last_click','first_click','linear','time_decay','position_based','last_non_direct','data_driven','custom') NOT NULL DEFAULT 'last_non_direct',
  -- Position-based weights, for the model that uses them.
  first_touch_weight DECIMAL(5,4) NULL,
  last_touch_weight DECIMAL(5,4) NULL,
  middle_touch_weight DECIMAL(5,4) NULL,
  -- Time decay half-life in days.
  half_life_days SMALLINT UNSIGNED NULL,
  lookback_days  SMALLINT UNSIGNED NOT NULL DEFAULT 90,
  -- Whether a direct visit may take credit. Usually not: "direct" is mostly
  -- untracked traffic and giving it the conversion hides the real source.
  include_direct TINYINT(1)      NOT NULL DEFAULT 0,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  description    VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_attribution_models_code (code),
  KEY ix_attribution_models_active (is_active, is_default)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- attribution_touchpoints
--
-- Every marketing contact a visitor had, in order. The raw material every model
-- reads.
--
-- Kept per visitor rather than per session because the journey crosses sessions
-- by definition — that is the entire problem attribution exists to solve.
-- -----------------------------------------------------------------------------
CREATE TABLE attribution_touchpoints (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  visitor_id     CHAR(32)        CHARACTER SET ascii NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  touch_number   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  channel        ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','offline','unknown') NOT NULL DEFAULT 'unknown',
  source         VARCHAR(120)    NULL,
  medium         VARCHAR(120)    NULL,
  campaign       VARCHAR(160)    NULL,
  content        VARCHAR(160)    NULL,
  term           VARCHAR(160)    NULL,
  landing_url    VARCHAR(500)    NULL,
  referrer_host  VARCHAR(191)    NULL,
  -- Cost of this touch where it is knowable, so cost-per-acquisition can be
  -- computed rather than estimated.
  cost           DECIMAL(12,4)   NULL,
  currency_code  CHAR(3)         NULL,
  ad_campaign_id INT UNSIGNED    NULL,
  affiliate_id   INT UNSIGNED    NULL,
  lead_source_id INT UNSIGNED    NULL,
  -- Whether this touch has been credited to a conversion yet.
  is_converting  TINYINT(1)      NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_touchpoint_sequence (visitor_id, touch_number),
  -- The path reconstruction: this visitor's touches, in order.
  KEY ix_touchpoints_visitor (visitor_id, occurred_at),
  KEY ix_touchpoints_user (user_id, occurred_at),
  KEY ix_touchpoints_campaign (campaign, occurred_at),
  KEY ix_touchpoints_channel (channel, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- conversions
--
-- One row per conversion event, with the attributed credit already computed per
-- model.
--
-- Credit is stored rather than derived at read time because attributing a
-- conversion means walking that visitor's whole touch history, and doing it
-- inside a dashboard query means the dashboard is unusable by the second month.
-- -----------------------------------------------------------------------------
CREATE TABLE conversions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  conversion_type ENUM('inquiry','call','whatsapp','signup','saved_search','favourite','listing_created','subscription','promotion_purchase','credit_purchase','deal_won','mortgage_application') NOT NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  user_id        BIGINT UNSIGNED NULL,
  -- What was converted on.
  subject_type   ENUM('listing','project','agent','organization','account','lead','deal','purchase') NULL,
  subject_id     BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  -- Value, so attribution can be weighted by money rather than by count.
  value          DECIMAL(16,2)   NULL,
  currency_code  CHAR(3)         NULL,
  value_base     DECIMAL(16,2)   NULL,
  -- The journey summary, denormalised so the common report needs no join.
  touch_count    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  days_to_convert SMALLINT UNSIGNED NULL,
  first_touch_channel ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','offline','unknown') NULL,
  last_touch_channel ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','offline','unknown') NULL,
  first_touch_campaign VARCHAR(160) NULL,
  last_touch_campaign VARCHAR(160) NULL,
  converted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversions_public (public_id),
  KEY ix_conversions_type (conversion_type, converted_at),
  KEY ix_conversions_visitor (visitor_id, converted_at),
  KEY ix_conversions_org (organization_id, conversion_type, converted_at),
  KEY ix_conversions_channel (last_touch_channel, converted_at),
  KEY ix_conversions_subject (subject_type, subject_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Fractional credit assigned to each touchpoint under each model. One
-- conversion produces several rows: three touchpoints under two models is six.
CREATE TABLE conversion_credits (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversion_id  BIGINT UNSIGNED NOT NULL,
  model_id       INT UNSIGNED    NOT NULL,
  touchpoint_id  BIGINT UNSIGNED NULL,
  touch_number   SMALLINT UNSIGNED NULL,
  channel        ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','offline','unknown') NOT NULL DEFAULT 'unknown',
  source         VARCHAR(120)    NULL,
  campaign       VARCHAR(160)    NULL,
  -- The fraction of the conversion credited here. Across one conversion and one
  -- model these sum to 1.0 — an invariant the integrity suite checks.
  credit_fraction DECIMAL(7,6)   NOT NULL DEFAULT 0,
  credited_value DECIMAL(16,4)   NULL,
  credited_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversion_credit (conversion_id, model_id, touch_number),
  KEY ix_conversion_credits_model (model_id, channel, credited_at),
  KEY ix_conversion_credits_campaign (model_id, campaign, credited_at),
  CONSTRAINT fk_conversion_credits_conversion FOREIGN KEY (conversion_id) REFERENCES conversions (id) ON DELETE CASCADE,
  CONSTRAINT fk_conversion_credits_model FOREIGN KEY (model_id) REFERENCES attribution_models (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- channel_performance_daily
--
-- Spend, traffic, conversions and attributed value per channel per day, under
-- one named attribution model. The marketing team's home page.
--
-- Carrying `model_id` in the key means the same day can be reported under
-- last-click and position-based side by side, which is how an argument about
-- attribution gets settled rather than repeated.
-- -----------------------------------------------------------------------------
CREATE TABLE channel_performance_daily (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  model_id       INT UNSIGNED    NOT NULL,
  channel        ENUM('organic_search','paid_search','organic_social','paid_social','direct','referral','email','affiliate','display','sms','app','portal','offline','unknown') NOT NULL,
  source         VARCHAR(120)    NULL,
  campaign       VARCHAR(160)    NULL,
  tenant_id      INT UNSIGNED    NULL,
  country_id     BIGINT UNSIGNED NULL,
  sessions       INT UNSIGNED    NOT NULL DEFAULT 0,
  new_visitors   INT UNSIGNED    NOT NULL DEFAULT 0,
  bounces        INT UNSIGNED    NOT NULL DEFAULT 0,
  page_views     INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_views  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Conversions counted two ways, which is the point of the model dimension:
  -- `conversions` is whole conversions last-touched here; `attributed_
  -- conversions` is fractional credit under the model.
  conversions    INT UNSIGNED    NOT NULL DEFAULT 0,
  attributed_conversions DECIMAL(14,4) NOT NULL DEFAULT 0,
  attributed_value DECIMAL(18,4) NOT NULL DEFAULT 0,
  cost           DECIMAL(16,4)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  -- Derived ratios, stored because every row of every report shows them.
  bounce_rate    DECIMAL(7,4)    NULL,
  conversion_rate DECIMAL(7,4)   NULL,
  cost_per_session DECIMAL(12,4) NULL,
  cost_per_conversion DECIMAL(12,4) NULL,
  return_on_spend DECIMAL(10,4)  NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_channel_daily (stat_date, model_id, channel, source, campaign, tenant_id, country_id),
  KEY ix_channel_daily_date (stat_date, model_id),
  KEY ix_channel_daily_campaign (campaign, stat_date),
  CONSTRAINT fk_channel_daily_model FOREIGN KEY (model_id) REFERENCES attribution_models (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · FUNNELS AND COHORTS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- funnels / funnel_steps / funnel_daily_stats
--
-- A named sequence of steps and the count reaching each, per day.
--
-- `window_hours` is what makes a funnel meaningful. Without it, "search →
-- enquiry" counts a person who searched in March and enquired in September as a
-- conversion, which is true and useless. With it, the funnel measures a
-- coherent journey.
-- -----------------------------------------------------------------------------
CREATE TABLE funnels (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(500)    NULL,
  funnel_type    ENUM('acquisition','search','listing','inquiry','signup','checkout','agent_onboarding','listing_creation','custom') NOT NULL DEFAULT 'custom',
  -- The grain the funnel counts. Sessions and visitors give different answers
  -- and both are legitimate, so it is declared rather than assumed.
  subject_grain  ENUM('session','visitor','user','lead','account') NOT NULL DEFAULT 'session',
  window_hours   SMALLINT UNSIGNED NOT NULL DEFAULT 24,
  -- Whether steps must occur in order. A strict funnel is a sequence; a loose
  -- one is a set of milestones.
  is_strict_order TINYINT(1)     NOT NULL DEFAULT 1,
  segment_filter JSON            NULL,
  tenant_id      INT UNSIGNED    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_funnels_code (code),
  KEY ix_funnels_active (is_active, funnel_type),
  CONSTRAINT fk_funnels_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE funnel_steps (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  funnel_id      INT UNSIGNED    NOT NULL,
  step_number    TINYINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  -- What counts as reaching this step, expressed against the event stream.
  event_type     VARCHAR(60)     NULL,
  page_type      VARCHAR(40)     NULL,
  match_condition JSON           NULL,
  -- Optional steps are counted but do not block progression, which is how a
  -- funnel copes with two routes to the same outcome.
  is_optional    TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_funnel_step (funnel_id, step_number),
  CONSTRAINT fk_funnel_steps_funnel FOREIGN KEY (funnel_id) REFERENCES funnels (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE funnel_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  funnel_id      INT UNSIGNED    NOT NULL,
  step_id        INT UNSIGNED    NOT NULL,
  step_number    TINYINT UNSIGNED NOT NULL,
  -- Segment dimensions, NULL meaning "all". Keeping them here rather than in
  -- separate tables lets one query serve the overall funnel and any slice.
  device_type    ENUM('desktop','mobile','tablet','app','all') NOT NULL DEFAULT 'all',
  channel        VARCHAR(40)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  tenant_id      INT UNSIGNED    NULL,
  entered        INT UNSIGNED    NOT NULL DEFAULT 0,
  completed      INT UNSIGNED    NOT NULL DEFAULT 0,
  dropped        INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Conversion from the previous step and from the top, both stored because
  -- both are read and they answer different questions.
  step_conversion_rate DECIMAL(7,4) NULL,
  overall_conversion_rate DECIMAL(7,4) NULL,
  median_seconds_to_next INT UNSIGNED NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_funnel_daily (stat_date, funnel_id, step_id, device_type, channel, country_id, category_id, tenant_id),
  KEY ix_funnel_daily_funnel (funnel_id, stat_date, step_number),
  CONSTRAINT fk_funnel_daily_funnel FOREIGN KEY (funnel_id) REFERENCES funnels (id) ON DELETE CASCADE,
  CONSTRAINT fk_funnel_daily_step FOREIGN KEY (step_id) REFERENCES funnel_steps (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- cohorts / cohort_periods
--
-- Retention as a curve rather than a number.
--
-- "Churn was 4% last month" hides everything: a cohort that acquired badly in
-- January and one that is retaining beautifully from March net out to a figure
-- that describes neither. The cohort table is what makes "our retention is
-- improving" a claim that can be checked.
-- -----------------------------------------------------------------------------
CREATE TABLE cohorts (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  -- What defines membership, and what counts as being retained. Both are
  -- declared because "retained" means something different for a consumer
  -- (came back) and an agency (still paying).
  subject_type   ENUM('user','account','organization','agent','visitor','listing') NOT NULL DEFAULT 'user',
  cohort_basis   ENUM('signup_date','first_purchase','first_listing','first_session','subscription_start') NOT NULL DEFAULT 'signup_date',
  retention_event ENUM('any_session','listing_view','inquiry','listing_created','payment','active_subscription','login') NOT NULL DEFAULT 'any_session',
  period_type    ENUM('day','week','month','quarter') NOT NULL DEFAULT 'month',
  max_periods    TINYINT UNSIGNED NOT NULL DEFAULT 24,
  segment_filter JSON            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_cohorts_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE cohort_periods (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  cohort_id      INT UNSIGNED    NOT NULL,
  -- The cohort itself: everyone who joined in this period.
  cohort_date    DATE            NOT NULL,
  cohort_size    INT UNSIGNED    NOT NULL DEFAULT 0,
  -- How many periods later this row measures. 0 is the cohort's own period.
  period_offset  TINYINT UNSIGNED NOT NULL,
  -- Segment slice, NULL for the whole cohort.
  country_id     BIGINT UNSIGNED NULL,
  channel        VARCHAR(40)     NULL,
  plan_id        INT UNSIGNED    NULL,
  tenant_id      INT UNSIGNED    NULL,
  retained_count INT UNSIGNED    NOT NULL DEFAULT 0,
  retention_rate DECIMAL(7,4)    NULL,
  churned_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Reactivation is real and is invisible in a naive retention curve: someone
  -- who lapsed in month 3 and returned in month 7 is neither retained nor
  -- churned in the simple model.
  reactivated_count INT UNSIGNED NOT NULL DEFAULT 0,
  -- Money, so lifetime value falls out of the same table.
  revenue        DECIMAL(18,2)   NOT NULL DEFAULT 0,
  cumulative_revenue DECIMAL(18,2) NOT NULL DEFAULT 0,
  revenue_per_subject DECIMAL(14,4) NULL,
  currency_code  CHAR(3)         NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_cohort_period (cohort_id, cohort_date, period_offset, country_id, channel, plan_id, tenant_id),
  KEY ix_cohort_periods_read (cohort_id, cohort_date, period_offset),
  CONSTRAINT fk_cohort_periods_cohort FOREIGN KEY (cohort_id) REFERENCES cohorts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · METRICS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- kpi_definitions
--
-- The metric dictionary. One written definition per metric, with the SQL that
-- computes it and the owner who answers for it.
--
-- This is the least glamorous table in the schema and among the most valuable.
-- Every organisation past a certain size has the same failure: three dashboards
-- showing three different values for "active listings", each defensible, none
-- reconcilable, and a recurring meeting about which is right. A single
-- definition, versioned, with the query attached, ends that.
-- -----------------------------------------------------------------------------
CREATE TABLE kpi_definitions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  -- Written for a human, not a developer. If this cannot be stated in a
  -- sentence, the metric is not ready to be on a dashboard.
  definition     VARCHAR(1000)   NOT NULL,
  category       ENUM('traffic','engagement','conversion','revenue','inventory','quality','operations','marketing','support','compliance') NOT NULL DEFAULT 'traffic',
  unit           ENUM('count','currency','percent','ratio','duration_seconds','duration_days','score','rate_per_day') NOT NULL DEFAULT 'count',
  currency_code  CHAR(3)         NULL,
  decimals       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  -- How it is computed. Stored so the number and its derivation travel
  -- together.
  source_table   VARCHAR(64)     NULL,
  computation_sql TEXT           NULL,
  aggregation    ENUM('sum','count','count_distinct','avg','median','p90','p95','min','max','ratio','last') NOT NULL DEFAULT 'sum',
  -- Which way is good. A dashboard that colours a rising churn rate green is
  -- worse than no dashboard.
  direction      ENUM('higher_is_better','lower_is_better','neutral') NOT NULL DEFAULT 'higher_is_better',
  -- Available slicing dimensions, so the UI knows what it may group by.
  dimensions     SET('date','country','city','category','purpose','organization','agent','channel','device','tenant','plan','language') NULL,
  refresh_frequency ENUM('realtime','hourly','daily','weekly','monthly') NOT NULL DEFAULT 'daily',
  owner_user_id  BIGINT UNSIGNED NULL,
  version        SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  -- Superseding rather than editing keeps history interpretable: a number
  -- computed under version 1 stays comparable to other version-1 numbers.
  superseded_by_id INT UNSIGNED  NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_north_star  TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kpi_definitions (code, version),
  KEY ix_kpi_definitions_category (category, is_active),
  CONSTRAINT fk_kpi_definitions_superseded FOREIGN KEY (superseded_by_id) REFERENCES kpi_definitions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- kpi_values
--
-- The computed number, per metric per period per slice.
--
-- One narrow table for every metric rather than a column per metric: adding a
-- KPI is an INSERT into the definition table and rows here, never a migration.
-- The dimension columns are nullable and NULL means "all", so the same table
-- holds the company-wide figure and every breakdown of it.
-- -----------------------------------------------------------------------------
CREATE TABLE kpi_values (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  kpi_id         INT UNSIGNED    NOT NULL,
  period_type    ENUM('hour','day','week','month','quarter','year') NOT NULL DEFAULT 'day',
  period_start   DATE            NOT NULL,
  -- Dimension slice. NULL = all.
  country_id     BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  category_id    INT UNSIGNED    NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  channel        VARCHAR(40)     NULL,
  device_type    VARCHAR(20)     NULL,
  value          DECIMAL(20,6)   NOT NULL DEFAULT 0,
  -- Numerator and denominator kept for ratio metrics, so a rate can be
  -- re-aggregated correctly. Averaging percentages across slices is wrong, and
  -- this is what stops it.
  numerator      DECIMAL(20,6)   NULL,
  denominator    DECIMAL(20,6)   NULL,
  sample_size    INT UNSIGNED    NULL,
  -- Comparisons, stored because every dashboard shows them.
  previous_value DECIMAL(20,6)   NULL,
  change_absolute DECIMAL(20,6)  NULL,
  change_percent DECIMAL(12,4)   NULL,
  yoy_change_percent DECIMAL(12,4) NULL,
  -- Set when the value is provisional because its source is still receiving
  -- late data, so a dashboard can mark it rather than present it as final.
  is_provisional TINYINT(1)      NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kpi_value (kpi_id, period_type, period_start, country_id, city_id, category_id, organization_id, agent_id, tenant_id, channel, device_type),
  KEY ix_kpi_values_series (kpi_id, period_type, period_start),
  KEY ix_kpi_values_org (organization_id, kpi_id, period_start),
  CONSTRAINT fk_kpi_values_kpi FOREIGN KEY (kpi_id) REFERENCES kpi_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- kpi_targets
--
-- What the number is supposed to be. A metric without a target is a
-- measurement; with one it is a commitment, and the difference is whether
-- anybody acts on it.
-- -----------------------------------------------------------------------------
CREATE TABLE kpi_targets (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  kpi_id         INT UNSIGNED    NOT NULL,
  period_type    ENUM('day','week','month','quarter','year') NOT NULL DEFAULT 'month',
  period_start   DATE            NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  target_value   DECIMAL(20,6)   NOT NULL,
  -- Thresholds for the traffic-light, set when the target is set rather than
  -- inferred afterwards from whatever was achieved.
  stretch_value  DECIMAL(20,6)   NULL,
  minimum_value  DECIMAL(20,6)   NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  rationale      VARCHAR(1000)   NULL,
  status         ENUM('draft','committed','revised','achieved','missed','cancelled') NOT NULL DEFAULT 'draft',
  achieved_value DECIMAL(20,6)   NULL,
  achievement_percent DECIMAL(10,4) NULL,
  evaluated_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_kpi_target (kpi_id, period_type, period_start, country_id, organization_id, tenant_id),
  KEY ix_kpi_targets_period (period_start, status),
  CONSTRAINT fk_kpi_targets_kpi FOREIGN KEY (kpi_id) REFERENCES kpi_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- metric_alerts / metric_anomalies
--
-- Watching the numbers so nobody has to. A threshold alert catches what you
-- predicted; anomaly detection catches what you did not, which is where the
-- expensive failures live — a portal feed silently stopping, a payment gateway
-- declining everything from one country, a tracking tag removed in a deploy.
--
-- Every one of those shows up as a metric moving before it shows up as a
-- complaint.
-- -----------------------------------------------------------------------------
CREATE TABLE metric_alerts (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  kpi_id         INT UNSIGNED    NULL,
  name           VARCHAR(200)    NOT NULL,
  alert_type     ENUM('threshold','change_percent','anomaly','no_data','trend','ratio') NOT NULL DEFAULT 'threshold',
  comparison     ENUM('above','below','outside_range','equals','changes_by') NOT NULL DEFAULT 'below',
  threshold_value DECIMAL(20,6)  NULL,
  threshold_upper DECIMAL(20,6)  NULL,
  change_percent_threshold DECIMAL(8,3) NULL,
  -- How many consecutive periods must breach before firing. A single bad hour
  -- is noise; three in a row is a signal.
  consecutive_periods TINYINT UNSIGNED NOT NULL DEFAULT 1,
  evaluation_period ENUM('hour','day','week','month') NOT NULL DEFAULT 'day',
  -- Scope.
  country_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  severity       ENUM('info','warning','critical') NOT NULL DEFAULT 'warning',
  notify_channels SET('email','sms','push','in_app','slack','webhook','pagerduty') NOT NULL DEFAULT 'email',
  notify_user_ids JSON           NULL,
  -- Silence between repeat firings, so one broken feed does not generate four
  -- hundred alerts and train everyone to ignore them.
  cooldown_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 60,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  last_fired_at  DATETIME(3)     NULL,
  fire_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_metric_alerts_active (is_active, evaluation_period),
  KEY ix_metric_alerts_kpi (kpi_id, is_active),
  CONSTRAINT fk_metric_alerts_kpi FOREIGN KEY (kpi_id) REFERENCES kpi_definitions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE metric_anomalies (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  alert_id       INT UNSIGNED    NULL,
  kpi_id         INT UNSIGNED    NULL,
  metric_name    VARCHAR(120)    NOT NULL,
  detected_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  period_start   DATE            NULL,
  observed_value DECIMAL(20,6)   NOT NULL,
  expected_value DECIMAL(20,6)   NULL,
  expected_lower DECIMAL(20,6)   NULL,
  expected_upper DECIMAL(20,6)   NULL,
  deviation_percent DECIMAL(12,4) NULL,
  -- Standard deviations from the expected value, which is what makes
  -- anomalies comparable across metrics of wildly different magnitudes.
  z_score        DECIMAL(10,4)   NULL,
  severity       ENUM('info','warning','critical') NOT NULL DEFAULT 'warning',
  direction      ENUM('spike','drop','flatline','trend_break') NOT NULL DEFAULT 'drop',
  -- Scope of the anomaly, so "conversions dropped" can be narrowed to
  -- "conversions dropped on mobile in Saudi Arabia" — which is usually where
  -- the actual cause is.
  country_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  dimension_slice JSON           NULL,
  status         ENUM('new','acknowledged','investigating','explained','false_positive','resolved') NOT NULL DEFAULT 'new',
  acknowledged_by_user_id BIGINT UNSIGNED NULL,
  acknowledged_at DATETIME(3)    NULL,
  -- The explanation, kept because next quarter somebody will see the same dip
  -- in a chart and ask what happened.
  explanation    VARCHAR(1000)   NULL,
  linked_incident_id BIGINT UNSIGNED NULL,
  resolved_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_anomalies_triage (status, severity, detected_at),
  KEY ix_anomalies_kpi (kpi_id, detected_at),
  KEY ix_anomalies_alert (alert_id, detected_at),
  CONSTRAINT fk_anomalies_alert FOREIGN KEY (alert_id) REFERENCES metric_alerts (id) ON DELETE SET NULL,
  CONSTRAINT fk_anomalies_kpi FOREIGN KEY (kpi_id) REFERENCES kpi_definitions (id) ON DELETE SET NULL,
  CONSTRAINT fk_anomalies_incident FOREIGN KEY (linked_incident_id) REFERENCES compliance_incidents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 4 · DASHBOARDS AND REPORTS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- dashboards / dashboard_widgets
--
-- Saved views, in the database rather than in front-end code, so an agency can
-- build its own and so a change to a chart does not need a deploy.
--
-- `audience` and the sharing table below matter for a multi-tenant platform:
-- an agency's dashboard must never resolve data outside its own organisation,
-- and that boundary belongs in the saved definition, not in the query the
-- browser happens to send.
-- -----------------------------------------------------------------------------
CREATE TABLE dashboards (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  slug           VARCHAR(120)    NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(500)    NULL,
  audience       ENUM('platform_admin','agency','agent','developer','finance','marketing','compliance','executive') NOT NULL DEFAULT 'agency',
  owner_user_id  BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  layout         JSON            NULL,
  -- Default filters applied to every widget, e.g. "last 30 days, this
  -- organisation".
  default_filters JSON           NULL,
  refresh_minutes SMALLINT UNSIGNED NULL,
  is_system      TINYINT(1)      NOT NULL DEFAULT 0,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_public      TINYINT(1)      NOT NULL DEFAULT 0,
  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  last_viewed_at DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_dashboards_public (public_id),
  UNIQUE KEY uq_dashboards_slug (slug, organization_id),
  KEY ix_dashboards_audience (audience, is_system),
  KEY ix_dashboards_org (organization_id, is_default),
  CONSTRAINT fk_dashboards_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_dashboards_tenant FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE dashboard_widgets (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  dashboard_id   INT UNSIGNED    NOT NULL,
  title          VARCHAR(200)    NOT NULL,
  widget_type    ENUM('metric','line_chart','bar_chart','pie_chart','table','funnel','cohort_grid','map','list','heatmap','gauge','text') NOT NULL DEFAULT 'metric',
  -- Where the data comes from. A widget bound to a KPI definition inherits its
  -- meaning; a widget with a bespoke query does not, which is why the first is
  -- preferred and the second is available.
  kpi_id         INT UNSIGNED    NULL,
  funnel_id      INT UNSIGNED    NULL,
  cohort_id      INT UNSIGNED    NULL,
  source_query   TEXT            NULL,
  -- Presentation.
  position_x     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  position_y     TINYINT UNSIGNED NOT NULL DEFAULT 0,
  width          TINYINT UNSIGNED NOT NULL DEFAULT 4,
  height         TINYINT UNSIGNED NOT NULL DEFAULT 3,
  config         JSON            NULL,
  filters        JSON            NULL,
  comparison_period ENUM('none','previous_period','previous_year','target') NOT NULL DEFAULT 'previous_period',
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_visible     TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_dashboard_widgets_dashboard (dashboard_id, sort_order),
  CONSTRAINT fk_widgets_dashboard FOREIGN KEY (dashboard_id) REFERENCES dashboards (id) ON DELETE CASCADE,
  CONSTRAINT fk_widgets_kpi FOREIGN KEY (kpi_id) REFERENCES kpi_definitions (id) ON DELETE SET NULL,
  CONSTRAINT fk_widgets_funnel FOREIGN KEY (funnel_id) REFERENCES funnels (id) ON DELETE SET NULL,
  CONSTRAINT fk_widgets_cohort FOREIGN KEY (cohort_id) REFERENCES cohorts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- scheduled_reports / report_runs
--
-- The Monday-morning email. Unglamorous and the most-read analytics surface a
-- platform has, because most people will never open a dashboard.
--
-- `run_as_user_id` is a security decision, not a convenience: a scheduled
-- report executes with someone's permissions, and if that is not pinned and
-- checked at send time, a report built by an admin and shared with an agency
-- leaks the whole platform's data every Monday.
-- -----------------------------------------------------------------------------
CREATE TABLE scheduled_reports (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(500)    NULL,
  dashboard_id   INT UNSIGNED    NULL,
  report_type    ENUM('dashboard_snapshot','kpi_summary','listing_performance','agent_performance','lead_summary','financial','portal_performance','custom') NOT NULL DEFAULT 'kpi_summary',
  kpi_ids        JSON            NULL,
  filters        JSON            NULL,
  -- Delivery.
  format         ENUM('email_html','pdf','excel','csv','link') NOT NULL DEFAULT 'email_html',
  schedule_cron  VARCHAR(60)     NULL,
  timezone       VARCHAR(64)     NOT NULL DEFAULT 'UTC',
  recipient_user_ids JSON        NULL,
  recipient_emails JSON          NULL,
  organization_id BIGINT UNSIGNED NULL,
  tenant_id      INT UNSIGNED    NULL,
  -- Permissions the report runs under. See the table comment.
  run_as_user_id BIGINT UNSIGNED NULL,
  -- Skip the send when there is nothing to say, which is what stops a weekly
  -- report becoming something everyone filters to a folder.
  skip_if_empty  TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  last_run_at    DATETIME(3)     NULL,
  next_run_at    DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_scheduled_reports_public (public_id),
  KEY ix_scheduled_reports_due (is_active, next_run_at),
  KEY ix_scheduled_reports_org (organization_id, is_active),
  CONSTRAINT fk_scheduled_reports_dashboard FOREIGN KEY (dashboard_id) REFERENCES dashboards (id) ON DELETE CASCADE,
  CONSTRAINT fk_scheduled_reports_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE report_runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  report_id      INT UNSIGNED    NOT NULL,
  status         ENUM('queued','running','completed','failed','skipped_empty','cancelled') NOT NULL DEFAULT 'queued',
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  started_at     DATETIME(3)     NULL,
  finished_at    DATETIME(3)     NULL,
  duration_ms    INT UNSIGNED    NULL,
  row_count      INT UNSIGNED    NULL,
  -- The generated artefact, kept so a recipient can re-download exactly what
  -- they were sent rather than a regenerated version with different numbers.
  output_media_asset_id BIGINT UNSIGNED NULL,
  output_size_bytes BIGINT UNSIGNED NULL,
  recipients_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  delivered_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  opened_count   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  error_message  VARCHAR(1000)   NULL,
  triggered_by   ENUM('schedule','manual','api') NOT NULL DEFAULT 'schedule',
  triggered_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_report_runs_report (report_id, created_at),
  KEY ix_report_runs_status (status, created_at),
  CONSTRAINT fk_report_runs_report FOREIGN KEY (report_id) REFERENCES scheduled_reports (id) ON DELETE CASCADE,
  CONSTRAINT fk_report_runs_asset FOREIGN KEY (output_media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0029', 'analytics_platform');
