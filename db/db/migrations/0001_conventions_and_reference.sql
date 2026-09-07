-- =============================================================================
-- Liv Finder — 0001 · Conventions & reference data
-- =============================================================================
-- Target: MySQL 8.0.16+ (primary). MariaDB 10.11+ runs this file unchanged.
--
-- CONVENTIONS USED THROUGHOUT THIS SCHEMA
-- ---------------------------------------
-- Engine        InnoDB everywhere. ROW_FORMAT=DYNAMIC for long-text tables.
-- Charset       utf8mb4 / utf8mb4_unicode_ci. Chosen over utf8mb4_0900_ai_ci so
--               the schema loads on MariaDB too; see docs/PERFORMANCE.md for the
--               one-line switch if you are MySQL-8-only and want the faster
--               collation.
-- PK            `id BIGINT UNSIGNED AUTO_INCREMENT`. Monotonic PKs keep InnoDB's
--               clustered index append-only, which is the single biggest write
--               win at high volume. Never expose these.
-- Public id     `public_id CHAR(26) ASCII` holding a ULID. Sortable by creation
--               time, opaque to clients, 26 bytes, and portable (no dependency
--               on UUID_TO_BIN, which MariaDB lacks). This is what the API and
--               URLs expose.
-- Slug          Human/SEO identifier, unique within its natural parent scope.
-- Timestamps    `created_at` / `updated_at` are UTC DATETIME(3), never TIMESTAMP
--               (TIMESTAMP's 2038 ceiling and implicit TZ conversion are both
--               liabilities for a global marketplace).
-- Soft delete   `deleted_at DATETIME(3) NULL` on user-visible content. All read
--               paths must filter it; the *_active views do this for you.
-- Money         DECIMAL(18,2) for amounts + a separate currency_code. Never
--               FLOAT. Every priced row also stores a base-currency amount so
--               cross-currency sorting and range filters are a single indexed
--               comparison instead of a runtime FX join.
-- Enums         Reference tables, not MySQL ENUM, wherever the set is expected
--               to grow (categories, statuses that admins manage). MySQL ENUM is
--               used only for small, code-coupled, effectively-frozen sets, where
--               it saves a join on the hot path.
-- FKs           Declared everywhere in the transactional core. Omitted only on
--               partitioned analytics tables, where InnoDB forbids them.
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 1;

-- -----------------------------------------------------------------------------
-- Migration bookkeeping
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_migrations (
  version        VARCHAR(64)     NOT NULL,
  name           VARCHAR(255)    NOT NULL,
  checksum       CHAR(64)        NULL,
  applied_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  execution_ms   INT UNSIGNED    NULL,
  PRIMARY KEY (version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Languages
--
-- Drives the i18n tables (*_translations) and the user's content locale.
-- `code` is BCP-47 (en, ar, fr, pt-BR).
-- -----------------------------------------------------------------------------
CREATE TABLE languages (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(12)     NOT NULL,
  name           VARCHAR(80)     NOT NULL,
  native_name    VARCHAR(80)     NOT NULL,
  direction      ENUM('ltr','rtl') NOT NULL DEFAULT 'ltr',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_languages_code (code),
  KEY ix_languages_active (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Currencies
--
-- `minor_unit` is the ISO 4217 exponent (2 for AED/USD/EUR, 0 for JPY, 3 for KWD).
-- Presentation code must use it; storing DECIMAL(18,2) is a storage decision, not
-- a formatting one.
-- -----------------------------------------------------------------------------
CREATE TABLE currencies (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           CHAR(3)         NOT NULL,
  numeric_code   CHAR(3)         NULL,
  name           VARCHAR(80)     NOT NULL,
  symbol         VARCHAR(12)     NOT NULL,
  symbol_native  VARCHAR(12)     NULL,
  minor_unit     TINYINT UNSIGNED NOT NULL DEFAULT 2,
  symbol_position ENUM('before','after') NOT NULL DEFAULT 'before',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Exactly one row must have is_base = 1. Every *_base_amount column in the
  -- schema is denominated in it. Changing it is a backfill, not a config edit.
  is_base        TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_currencies_code (code),
  KEY ix_currencies_active (is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- FX rates
--
-- Append-only history: one row per (base, quote, as_of_date). The application
-- reads `fx_rates_latest`, never this table directly, on any hot path.
-- rate = how many `quote` units one `base` unit buys.
-- -----------------------------------------------------------------------------
CREATE TABLE fx_rates (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  base_code      CHAR(3)         NOT NULL,
  quote_code     CHAR(3)         NOT NULL,
  rate           DECIMAL(24,10)  NOT NULL,
  as_of_date     DATE            NOT NULL,
  source         VARCHAR(60)     NOT NULL DEFAULT 'manual',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_fx_rates_pair_date (base_code, quote_code, as_of_date),
  KEY ix_fx_rates_lookup (base_code, quote_code, as_of_date DESC),
  CONSTRAINT ck_fx_rates_rate_positive CHECK (rate > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Current rate per pair. Maintained by the FX refresh job; a plain table rather
-- than a view so the hot path is a single-row PK lookup with no window function.
CREATE TABLE fx_rates_latest (
  base_code      CHAR(3)         NOT NULL,
  quote_code     CHAR(3)         NOT NULL,
  rate           DECIMAL(24,10)  NOT NULL,
  as_of_date     DATE            NOT NULL,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (base_code, quote_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Unit systems
--
-- A global portal shows sqft in Dubai and m² in Milan. Areas/lengths are stored
-- once in a canonical unit (m² for area, metres for length) and converted for
-- display; these rows define the conversions and the per-market default.
-- -----------------------------------------------------------------------------
CREATE TABLE measurement_units (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(20)     NOT NULL,
  dimension      ENUM('area','length','weight','volume','speed','distance','power') NOT NULL,
  name           VARCHAR(60)     NOT NULL,
  symbol         VARCHAR(16)     NOT NULL,
  -- Multiply a value in this unit by `to_canonical` to get the canonical unit
  -- for its dimension (m², m, kg, l, km/h, km, kW).
  to_canonical   DECIMAL(24,12)  NOT NULL,
  is_canonical   TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_measurement_units_code (code),
  KEY ix_measurement_units_dimension (dimension)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Settings
--
-- Backs the admin portal's General / Payment / SEO & Analytics settings screens.
-- Typed by `value_type` so the app can parse without guessing; `is_secret`
-- marks rows that must never be serialised to a public endpoint.
-- -----------------------------------------------------------------------------
CREATE TABLE settings (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  group_key      VARCHAR(60)     NOT NULL,
  setting_key    VARCHAR(120)    NOT NULL,
  value          TEXT            NULL,
  value_type     ENUM('string','integer','decimal','boolean','json','text') NOT NULL DEFAULT 'string',
  label          VARCHAR(160)    NULL,
  description    VARCHAR(500)    NULL,
  is_public      TINYINT(1)      NOT NULL DEFAULT 0,
  is_secret      TINYINT(1)      NOT NULL DEFAULT 0,
  updated_by     BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_settings_key (group_key, setting_key),
  KEY ix_settings_public (is_public)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Feature flags
--
-- `rollout_percentage` is evaluated against a stable hash of the actor id, so a
-- given user stays on the same side of a partial rollout between requests.
-- -----------------------------------------------------------------------------
CREATE TABLE feature_flags (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  flag_key       VARCHAR(120)    NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(500)    NULL,
  is_enabled     TINYINT(1)      NOT NULL DEFAULT 0,
  rollout_percentage TINYINT UNSIGNED NOT NULL DEFAULT 0,
  conditions     JSON            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_feature_flags_key (flag_key),
  CONSTRAINT ck_feature_flags_rollout CHECK (rollout_percentage BETWEEN 0 AND 100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0001', 'conventions_and_reference');
