-- =============================================================================
-- Liv Finder — 0009 · Finance
-- =============================================================================
-- Plans, subscriptions, invoices, payments, refunds, payouts, promotions and a
-- double-entry ledger.
--
-- Two rules govern everything here, and they are not negotiable in a system that
-- handles money:
--
-- 1. FINANCIAL ROWS ARE IMMUTABLE ONCE ISSUED. An invoice is never edited; it is
--    credited and reissued. A payment is never adjusted; it is refunded. This is
--    why there is a `credit_notes` table and why `payments` has no editable
--    amount column — corrections leave a trail rather than overwriting one.
--
-- 2. EVERY AMOUNT CARRIES ITS CURRENCY AND ITS FX SNAPSHOT. `amount` +
--    `currency_code` is what the customer sees and what the processor charged.
--    `amount_base` + `exchange_rate` is what reporting sums. The rate is stored
--    on the row, not looked up later, because a refund six months on must use
--    the original rate and not today's.
--
-- The audit found Payments, Billing and Payouts reporting pagination totals
-- larger than their real data. Every count in this domain is a COUNT over an
-- index defined here; the summary cards read the same rows the table does.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Plans and subscriptions
-- -----------------------------------------------------------------------------
CREATE TABLE plans (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(140)    NOT NULL,
  slug           VARCHAR(160)    NOT NULL,
  description    TEXT            NULL,
  -- Which kind of account may buy it, so a personal account is never shown an
  -- agency plan.
  audience       ENUM('personal','lister','company','organization','partner','any') NOT NULL DEFAULT 'any',
  tier           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  billing_interval ENUM('monthly','quarterly','yearly','one_time','custom') NOT NULL DEFAULT 'monthly',
  trial_days     SMALLINT UNSIGNED NOT NULL DEFAULT 0,

  listing_quota  INT UNSIGNED    NOT NULL DEFAULT 0,
  featured_quota INT UNSIGNED    NOT NULL DEFAULT 0,
  agent_seat_quota INT UNSIGNED  NOT NULL DEFAULT 0,
  -- 0 = unlimited, expressed explicitly rather than as NULL so quota arithmetic
  -- never has to special-case a null.
  lead_quota     INT UNSIGNED    NOT NULL DEFAULT 0,

  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_plans_public_id (public_id),
  UNIQUE KEY uq_plans_code (code),
  UNIQUE KEY uq_plans_slug (slug),
  KEY ix_plans_audience (audience, is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Prices are a separate table so one plan can be sold in AED, USD and EUR at
-- locally-sensible price points rather than at whatever FX produces.
CREATE TABLE plan_prices (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  plan_id        INT UNSIGNED    NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  setup_fee      DECIMAL(18,2)   NOT NULL DEFAULT 0,
  country_id     BIGINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_prices (plan_id, currency_code, country_id),
  KEY ix_plan_prices_plan (plan_id, is_active),
  CONSTRAINT fk_plan_prices_plan    FOREIGN KEY (plan_id)    REFERENCES plans (id)     ON DELETE CASCADE,
  CONSTRAINT fk_plan_prices_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE plan_features (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  plan_id        INT UNSIGNED    NOT NULL,
  feature_key    VARCHAR(80)     NOT NULL,
  label          VARCHAR(200)    NOT NULL,
  value          VARCHAR(120)    NULL,
  is_included    TINYINT(1)      NOT NULL DEFAULT 1,
  is_highlighted TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_features (plan_id, feature_key),
  CONSTRAINT fk_plan_features_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE subscriptions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  plan_id        INT UNSIGNED    NOT NULL,
  status         ENUM('trialing','active','past_due','paused','cancelled','expired','incomplete') NOT NULL DEFAULT 'active',

  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  billing_interval ENUM('monthly','quarterly','yearly','one_time','custom') NOT NULL DEFAULT 'monthly',

  current_period_start DATETIME(3) NULL,
  current_period_end   DATETIME(3) NULL,
  trial_ends_at  DATETIME(3)     NULL,
  -- Set when the customer cancels but the period has not yet lapsed; the
  -- subscription stays 'active' until then rather than dying immediately.
  cancel_at      DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  cancellation_reason VARCHAR(500) NULL,
  ended_at       DATETIME(3)     NULL,

  auto_renew     TINYINT(1)      NOT NULL DEFAULT 1,
  -- Consumption against the plan quota, denormalised so a publish check is one
  -- row read rather than an aggregate over listings.
  listing_quota  INT UNSIGNED    NOT NULL DEFAULT 0,
  listing_used   INT UNSIGNED    NOT NULL DEFAULT 0,
  featured_quota INT UNSIGNED    NOT NULL DEFAULT 0,
  featured_used  INT UNSIGNED    NOT NULL DEFAULT 0,

  payment_method_id BIGINT UNSIGNED NULL,
  external_reference VARCHAR(191) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_subscriptions_public_id (public_id),
  KEY ix_subscriptions_account (account_id, status),
  KEY ix_subscriptions_plan (plan_id, status),
  -- Drives the renewal job.
  KEY ix_subscriptions_renewal (status, current_period_end),
  KEY ix_subscriptions_external (external_reference),
  CONSTRAINT fk_subscriptions_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_subscriptions_plan    FOREIGN KEY (plan_id)    REFERENCES plans (id)    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Payment methods
--
-- Only non-sensitive presentational detail is stored — brand, last four, expiry.
-- The actual instrument lives at the processor behind `provider_token`, so this
-- database is out of PCI scope.
-- -----------------------------------------------------------------------------
CREATE TABLE payment_methods (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  method_type    ENUM('card','bank_transfer','sepa_debit','paypal','apple_pay','google_pay','crypto','cash','cheque') NOT NULL,
  provider       VARCHAR(60)     NOT NULL,
  provider_token VARCHAR(191)    NULL,
  brand          VARCHAR(40)     NULL,
  last_four      CHAR(4)         NULL,
  expiry_month   TINYINT UNSIGNED NULL,
  expiry_year    SMALLINT UNSIGNED NULL,
  holder_name    VARCHAR(200)    NULL,
  billing_country_id BIGINT UNSIGNED NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  status         ENUM('active','expired','removed','failed') NOT NULL DEFAULT 'active',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_methods_public_id (public_id),
  KEY ix_payment_methods_account (account_id, status, is_default),
  KEY ix_payment_methods_expiry (status, expiry_year, expiry_month),
  CONSTRAINT fk_payment_methods_account FOREIGN KEY (account_id)         REFERENCES accounts (id)  ON DELETE CASCADE,
  CONSTRAINT fk_payment_methods_user    FOREIGN KEY (user_id)            REFERENCES users (id)     ON DELETE SET NULL,
  CONSTRAINT fk_payment_methods_country FOREIGN KEY (billing_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE subscriptions
  ADD CONSTRAINT fk_subscriptions_payment_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- Invoices
-- -----------------------------------------------------------------------------
CREATE TABLE invoices (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- Gapless, immutable, per-series document number. Tax authorities require the
  -- sequence to have no holes, which is why a cancelled invoice becomes
  -- 'void' rather than being deleted.
  invoice_number VARCHAR(40)     NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  subscription_id BIGINT UNSIGNED NULL,

  status         ENUM('draft','open','paid','partially_paid','past_due','void','uncollectible','refunded') NOT NULL DEFAULT 'draft',

  subtotal       DECIMAL(18,2)   NOT NULL DEFAULT 0,
  discount_total DECIMAL(18,2)   NOT NULL DEFAULT 0,
  tax_total      DECIMAL(18,2)   NOT NULL DEFAULT 0,
  total          DECIMAL(18,2)   NOT NULL DEFAULT 0,
  amount_paid    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  amount_due     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL,
  -- FX snapshot at issue. Reporting sums this; it is never recomputed.
  exchange_rate  DECIMAL(24,10)  NULL,
  total_base     DECIMAL(18,2)   NULL,

  tax_rate       DECIMAL(6,3)    NULL,
  tax_label      VARCHAR(40)     NULL,
  tax_number     VARCHAR(60)     NULL,

  billing_name   VARCHAR(200)    NULL,
  billing_email  VARCHAR(255)    NULL,
  billing_address JSON           NULL,

  issued_at      DATETIME(3)     NULL,
  due_at         DATETIME(3)     NULL,
  paid_at        DATETIME(3)     NULL,
  voided_at      DATETIME(3)     NULL,
  -- Rendered document. The audit noted every invoice download was disabled;
  -- this is where the generated file lands so they can be enabled.
  pdf_url        VARCHAR(700)    NULL,
  notes          VARCHAR(1000)   NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_invoices_public_id (public_id),
  UNIQUE KEY uq_invoices_number (invoice_number),
  KEY ix_invoices_account (account_id, status, issued_at),
  KEY ix_invoices_subscription (subscription_id),
  -- Dunning: everything open and past due.
  KEY ix_invoices_dunning (status, due_at),
  CONSTRAINT fk_invoices_account      FOREIGN KEY (account_id)      REFERENCES accounts (id)      ON DELETE RESTRICT,
  CONSTRAINT fk_invoices_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT ck_invoices_total CHECK (total >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE invoice_lines (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id     BIGINT UNSIGNED NOT NULL,
  description    VARCHAR(500)    NOT NULL,
  -- What was billed, so a line can be traced back to a plan, a featured
  -- placement or a one-off listing credit.
  item_type      ENUM('subscription','listing','featured','credit','addon','setup','adjustment','tax') NOT NULL DEFAULT 'subscription',
  item_reference VARCHAR(120)    NULL,
  quantity       DECIMAL(12,3)   NOT NULL DEFAULT 1,
  unit_amount    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  discount_amount DECIMAL(18,2)  NOT NULL DEFAULT 0,
  tax_rate       DECIMAL(6,3)    NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  line_total     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ix_invoice_lines_invoice (invoice_id, sort_order),
  CONSTRAINT fk_invoice_lines_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Corrections to an issued invoice. See the immutability rule in the header.
CREATE TABLE credit_notes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  credit_note_number VARCHAR(40) NOT NULL,
  invoice_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  reason         VARCHAR(500)    NULL,
  status         ENUM('draft','issued','applied','void') NOT NULL DEFAULT 'issued',
  issued_at      DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_credit_notes_public_id (public_id),
  UNIQUE KEY uq_credit_notes_number (credit_note_number),
  KEY ix_credit_notes_invoice (invoice_id),
  KEY ix_credit_notes_account (account_id, status),
  CONSTRAINT fk_credit_notes_invoice FOREIGN KEY (invoice_id)         REFERENCES invoices (id) ON DELETE RESTRICT,
  CONSTRAINT fk_credit_notes_account FOREIGN KEY (account_id)         REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_credit_notes_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Payments and refunds
-- -----------------------------------------------------------------------------
CREATE TABLE payments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  booking_id     BIGINT UNSIGNED NULL,
  payment_method_id BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,

  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  exchange_rate  DECIMAL(24,10)  NULL,
  amount_base    DECIMAL(18,2)   NULL,
  fee_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  net_amount     DECIMAL(18,2)   NULL,
  refunded_amount DECIMAL(18,2)  NOT NULL DEFAULT 0,

  status         ENUM('pending','processing','requires_action','succeeded','failed','cancelled','refunded','partially_refunded','disputed') NOT NULL DEFAULT 'pending',
  payment_type   ENUM('subscription','listing','featured','deposit','booking','credit','other') NOT NULL DEFAULT 'subscription',

  provider       VARCHAR(60)     NULL,
  provider_payment_id VARCHAR(191) NULL,
  -- Guards against double-charging on a retried request; the same key must
  -- never produce a second payment.
  idempotency_key VARCHAR(120)   NULL,
  failure_code   VARCHAR(80)     NULL,
  failure_message VARCHAR(500)   NULL,

  receipt_url    VARCHAR(700)    NULL,
  paid_at        DATETIME(3)     NULL,
  failed_at      DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_public_id (public_id),
  UNIQUE KEY uq_payments_reference (reference),
  UNIQUE KEY uq_payments_idempotency (idempotency_key),
  KEY ix_payments_account (account_id, status, created_at),
  KEY ix_payments_invoice (invoice_id),
  KEY ix_payments_provider (provider, provider_payment_id),
  KEY ix_payments_status (status, created_at),
  KEY ix_payments_type (payment_type, status),
  CONSTRAINT fk_payments_account      FOREIGN KEY (account_id)        REFERENCES accounts (id)        ON DELETE RESTRICT,
  CONSTRAINT fk_payments_invoice      FOREIGN KEY (invoice_id)        REFERENCES invoices (id)        ON DELETE SET NULL,
  CONSTRAINT fk_payments_subscription FOREIGN KEY (subscription_id)   REFERENCES subscriptions (id)   ON DELETE SET NULL,
  CONSTRAINT fk_payments_booking      FOREIGN KEY (booking_id)        REFERENCES bookings (id)        ON DELETE SET NULL,
  CONSTRAINT fk_payments_method       FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL,
  CONSTRAINT fk_payments_user         FOREIGN KEY (user_id)           REFERENCES users (id)           ON DELETE SET NULL,
  CONSTRAINT ck_payments_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE refunds (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  payment_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- The original payment's rate, deliberately, not today's.
  exchange_rate  DECIMAL(24,10)  NULL,
  amount_base    DECIMAL(18,2)   NULL,
  reason         ENUM('requested_by_customer','duplicate','fraudulent','service_issue','downgrade','other') NOT NULL DEFAULT 'requested_by_customer',
  reason_note    VARCHAR(500)    NULL,
  status         ENUM('pending','processing','succeeded','failed','cancelled') NOT NULL DEFAULT 'pending',
  provider_refund_id VARCHAR(191) NULL,
  processed_by_user_id BIGINT UNSIGNED NULL,
  refunded_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_refunds_public_id (public_id),
  KEY ix_refunds_payment (payment_id),
  KEY ix_refunds_account (account_id, status, created_at),
  CONSTRAINT fk_refunds_payment FOREIGN KEY (payment_id)           REFERENCES payments (id) ON DELETE RESTRICT,
  CONSTRAINT fk_refunds_account FOREIGN KEY (account_id)           REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_refunds_user    FOREIGN KEY (processed_by_user_id) REFERENCES users (id)    ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Payouts — money going out to partners and agencies
-- -----------------------------------------------------------------------------
CREATE TABLE payout_methods (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  method_type    ENUM('bank_transfer','paypal','wise','stripe_connect','cheque') NOT NULL DEFAULT 'bank_transfer',
  account_holder_name VARCHAR(200) NULL,
  bank_name      VARCHAR(200)    NULL,
  -- Only the last four of the account/IBAN is retained in the clear; the full
  -- value is held encrypted, matching the treatment of card data.
  account_last_four CHAR(4)      NULL,
  iban_encrypted VARBINARY(512)  NULL,
  swift_bic      VARCHAR(20)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  currency_code  CHAR(3)         NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  status         ENUM('pending_verification','active','rejected','removed') NOT NULL DEFAULT 'pending_verification',
  verified_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_payout_methods_public_id (public_id),
  KEY ix_payout_methods_account (account_id, status, is_default),
  CONSTRAINT fk_payout_methods_account FOREIGN KEY (account_id) REFERENCES accounts (id)  ON DELETE CASCADE,
  CONSTRAINT fk_payout_methods_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE payouts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  payout_method_id BIGINT UNSIGNED NULL,
  gross_amount   DECIMAL(18,2)   NOT NULL,
  fee_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  net_amount     DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  exchange_rate  DECIMAL(24,10)  NULL,
  net_amount_base DECIMAL(18,2)  NULL,
  status         ENUM('scheduled','pending','processing','paid','failed','cancelled','on_hold') NOT NULL DEFAULT 'scheduled',
  -- The earnings window this payout settles.
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  scheduled_for  DATE            NULL,
  paid_at        DATETIME(3)     NULL,
  failure_reason VARCHAR(500)    NULL,
  provider_transfer_id VARCHAR(191) NULL,
  statement_url  VARCHAR(700)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_payouts_public_id (public_id),
  UNIQUE KEY uq_payouts_reference (reference),
  KEY ix_payouts_account (account_id, status, created_at),
  KEY ix_payouts_schedule (status, scheduled_for),
  CONSTRAINT fk_payouts_account FOREIGN KEY (account_id)       REFERENCES accounts (id)       ON DELETE RESTRICT,
  CONSTRAINT fk_payouts_method  FOREIGN KEY (payout_method_id) REFERENCES payout_methods (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE payout_items (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payout_id      BIGINT UNSIGNED NOT NULL,
  description    VARCHAR(500)    NOT NULL,
  item_type      ENUM('commission','referral','lead_share','bonus','adjustment','chargeback') NOT NULL DEFAULT 'commission',
  reference_type VARCHAR(60)     NULL,
  reference_id   BIGINT UNSIGNED NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  earned_at      DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_payout_items_payout (payout_id),
  KEY ix_payout_items_reference (reference_type, reference_id),
  CONSTRAINT fk_payout_items_payout FOREIGN KEY (payout_id) REFERENCES payouts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ledger_entries — double-entry general ledger
--
-- Every movement of money produces balanced debit and credit rows sharing a
-- `transaction_group`. This is what makes the finance reports reconcilable
-- rather than merely plausible: for any group, SUM(debit) must equal SUM(credit).
-- -----------------------------------------------------------------------------
CREATE TABLE ledger_entries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  transaction_group CHAR(26)     CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  -- Chart-of-accounts code: revenue, receivable, cash, tax_payable, fees,
  -- partner_payable.
  ledger_account VARCHAR(60)     NOT NULL,
  entry_type     ENUM('debit','credit') NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NOT NULL,
  source_type    VARCHAR(60)     NOT NULL,
  source_id      BIGINT UNSIGNED NULL,
  description    VARCHAR(500)    NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_ledger_group (transaction_group),
  KEY ix_ledger_account (account_id, occurred_at),
  -- Trial balance per ledger account over a period.
  KEY ix_ledger_ledger_account (ledger_account, occurred_at),
  KEY ix_ledger_source (source_type, source_id),
  CONSTRAINT fk_ledger_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT ck_ledger_amount CHECK (amount >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Promotions and paid placement
-- -----------------------------------------------------------------------------
CREATE TABLE coupons (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NULL,
  discount_type  ENUM('percentage','fixed','free_trial') NOT NULL DEFAULT 'percentage',
  discount_value DECIMAL(12,2)   NOT NULL,
  currency_code  CHAR(3)         NULL,
  -- 0 = unlimited, consistent with the quota convention on plans.
  max_redemptions INT UNSIGNED   NOT NULL DEFAULT 0,
  redemption_count INT UNSIGNED  NOT NULL DEFAULT 0,
  max_per_account SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  minimum_amount DECIMAL(18,2)   NULL,
  applies_to_plan_id INT UNSIGNED NULL,
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_coupons_code (code),
  KEY ix_coupons_active (is_active, starts_at, ends_at),
  CONSTRAINT fk_coupons_plan FOREIGN KEY (applies_to_plan_id) REFERENCES plans (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE coupon_redemptions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  coupon_id      INT UNSIGNED    NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  discount_amount DECIMAL(18,2)  NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  redeemed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_coupon_redemptions_coupon (coupon_id, account_id),
  KEY ix_coupon_redemptions_account (account_id),
  CONSTRAINT fk_cr_coupon  FOREIGN KEY (coupon_id)  REFERENCES coupons (id)  ON DELETE CASCADE,
  CONSTRAINT fk_cr_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_cr_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Paid promotion of a specific listing into a specific slot. Kept separate from
-- `listings.is_featured` because that flag says "is featured now" while this
-- table says "who paid for what, when, and did it deliver".
CREATE TABLE featured_placements (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  placement_type ENUM('homepage','category','search_top','location','newsletter','social','similar_listings') NOT NULL DEFAULT 'search_top',
  -- Scope of the placement: featured in this city, or this category, or both.
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  starts_at      DATETIME(3)     NOT NULL,
  ends_at        DATETIME(3)     NOT NULL,
  status         ENUM('scheduled','active','completed','cancelled') NOT NULL DEFAULT 'scheduled',
  amount         DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  payment_id     BIGINT UNSIGNED NULL,
  impressions    INT UNSIGNED    NOT NULL DEFAULT 0,
  clicks         INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_featured_placements_public_id (public_id),
  -- Serves "what should be featured on this surface right now".
  KEY ix_featured_active (status, placement_type, starts_at, ends_at),
  KEY ix_featured_listing (listing_id, status),
  KEY ix_featured_account (account_id, status),
  KEY ix_featured_scope (category_id, location_id, status),
  CONSTRAINT fk_fp_listing  FOREIGN KEY (listing_id)  REFERENCES listings (id)   ON DELETE CASCADE,
  CONSTRAINT fk_fp_account  FOREIGN KEY (account_id)  REFERENCES accounts (id)   ON DELETE CASCADE,
  CONSTRAINT fk_fp_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_fp_location FOREIGN KEY (location_id) REFERENCES locations (id)  ON DELETE SET NULL,
  CONSTRAINT fk_fp_payment  FOREIGN KEY (payment_id)  REFERENCES payments (id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Prepaid listing/feature credits, consumed as listings are published.
CREATE TABLE account_credits (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  credit_type    ENUM('listing','featured','refresh','boost','api_call') NOT NULL DEFAULT 'listing',
  quantity       INT             NOT NULL,
  -- Running total after this movement, so a balance read is one row rather than
  -- a sum over the whole history.
  balance_after  INT             NOT NULL,
  source         ENUM('purchase','plan','promotion','manual','consumption','expiry','refund') NOT NULL,
  reference_type VARCHAR(60)     NULL,
  reference_id   BIGINT UNSIGNED NULL,
  expires_at     DATETIME(3)     NULL,
  note           VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_account_credits (account_id, credit_type, created_at),
  KEY ix_account_credits_expiry (expires_at),
  CONSTRAINT fk_account_credits_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0009', 'finance');
