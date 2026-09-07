-- =============================================================================
-- Liv Finder — 0018 · Payment infrastructure
-- =============================================================================
-- Migration 0009 modelled the commercial outcomes: plans, invoices, payments,
-- payouts, a balanced ledger. What it did not model is the machinery that
-- actually moves money, and that machinery is where the hard problems live.
--
-- Five realities this layer exists to handle:
--
--   1. ONE PROCESSOR IS NEVER ENOUGH. A platform selling in AED, GBP and EUR
--      needs local acquiring in each — Stripe does not process Mada, Network
--      International does not serve the UK well, and a single processor going
--      down should degrade revenue, not stop it. So: multiple gateways, multiple
--      merchant accounts, and declarative routing with failover.
--
--   2. A PAYMENT IS A CONVERSATION, NOT AN EVENT. Intent, then 3-D Secure
--      challenge, then authorisation, then capture — possibly days later,
--      possibly partial. Each step can fail and be retried. A single `payments`
--      row cannot express that, so `payment_intents` owns the lifecycle and
--      `payments` records the settled outcome.
--
--   3. WEBHOOKS ARRIVE TWICE, OUT OF ORDER, AND SOMETIMES NEVER. Every
--      processor documents this. `gateway_webhook_events` stores the raw payload
--      with a unique provider event id so replays are idempotent, keeps the
--      signature for verification, and can be re-processed after a bug fix.
--
--   4. THE MONEY MUST RECONCILE. What the processor says it paid out has to
--      match what our ledger says it collected, to the cent, every day.
--      Settlements, settlement lines and reconciliation exceptions are how
--      that becomes a daily report rather than a quarterly crisis.
--
--   5. MARKETPLACES SPLIT PAYMENTS. A booking deposit is partly commission and
--      partly the agency's money held in escrow. Escrow for property deposits is
--      a legal requirement in several of the markets here, not a feature.
--
-- Tax and the general ledger are large enough to warrant their own migration and
-- live in 0019.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- payment_gateways / gateway_accounts
-- -----------------------------------------------------------------------------
CREATE TABLE payment_gateways (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  provider       ENUM('stripe','adyen','checkout_com','network_international','telr','payfort','paytabs','braintree','paypal','worldpay','razorpay','tap','hyperpay','mollie','gocardless','wise','bank_transfer','manual') NOT NULL,
  -- What this gateway can actually do. Routing reads these rather than
  -- hardcoding provider names, so adding a processor is configuration.
  supports_3ds   TINYINT(1)      NOT NULL DEFAULT 1,
  supports_auth_capture TINYINT(1) NOT NULL DEFAULT 1,
  supports_partial_capture TINYINT(1) NOT NULL DEFAULT 0,
  supports_refunds TINYINT(1)    NOT NULL DEFAULT 1,
  supports_partial_refunds TINYINT(1) NOT NULL DEFAULT 1,
  supports_recurring TINYINT(1)  NOT NULL DEFAULT 1,
  supports_mandates TINYINT(1)   NOT NULL DEFAULT 0,
  supports_payouts TINYINT(1)    NOT NULL DEFAULT 0,
  supports_split_payments TINYINT(1) NOT NULL DEFAULT 0,
  supports_escrow TINYINT(1)     NOT NULL DEFAULT 0,
  -- Whether the platform ever sees raw card data. Anything other than 'none'
  -- pulls this database into PCI scope, which is a decision, not an accident.
  card_data_exposure ENUM('none','tokenised','full') NOT NULL DEFAULT 'none',
  webhook_signature_algorithm VARCHAR(40) NULL,
  api_version    VARCHAR(40)     NULL,
  documentation_url VARCHAR(500) NULL,
  status         ENUM('active','testing','deprecated','disabled') NOT NULL DEFAULT 'testing',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_gateways_code (code),
  KEY ix_payment_gateways_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- A merchant account at a gateway. Separate from the gateway because a single
-- processor commonly holds several: one per settlement currency, one per legal
-- entity, one per brand in a white-label deployment.
CREATE TABLE gateway_accounts (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  gateway_id     SMALLINT UNSIGNED NOT NULL,
  code           VARCHAR(80)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  brand_id       INT UNSIGNED    NULL,
  legal_entity   VARCHAR(200)    NULL,
  merchant_id    VARCHAR(191)    NULL,
  -- Credentials are held in a secret manager; this is the reference, never the
  -- value. A database backup must not be a credential leak.
  credentials_ref VARCHAR(191)   NULL,
  webhook_secret_ref VARCHAR(191) NULL,
  settlement_currency CHAR(3)    NOT NULL DEFAULT 'AED',
  -- Which currencies this account can charge in, and which countries it may
  -- serve. Routing matches against both.
  supported_currencies JSON      NULL,
  supported_countries JSON       NULL,
  supported_methods JSON         NULL,
  -- Commercials, so the cheapest viable route can be preferred and so payment
  -- costs can be attributed rather than appearing as one opaque monthly figure.
  percentage_fee DECIMAL(6,4)    NULL,
  fixed_fee      DECIMAL(10,2)   NULL,
  fixed_fee_currency CHAR(3)     NULL,
  settlement_delay_days TINYINT UNSIGNED NULL,
  is_live        TINYINT(1)      NOT NULL DEFAULT 0,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  status         ENUM('active','suspended','closed') NOT NULL DEFAULT 'active',
  -- Health, maintained from recent attempts, so routing can shed load from a
  -- degraded processor automatically.
  recent_success_rate DECIMAL(5,2) NULL,
  last_failure_at DATETIME(3)    NULL,
  consecutive_failures SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_gateway_accounts_code (code),
  KEY ix_gateway_accounts_gateway (gateway_id, status, is_live),
  KEY ix_gateway_accounts_currency (settlement_currency, status),
  CONSTRAINT fk_gateway_accounts_gateway FOREIGN KEY (gateway_id) REFERENCES payment_gateways (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Declarative routing. Evaluated in priority order, first match wins, with a
-- fallback account for when the primary is failing.
CREATE TABLE gateway_routing_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(160)    NOT NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- Match conditions; NULL means any.
  currency_code  CHAR(3)         NULL,
  country_id     BIGINT UNSIGNED NULL,
  payment_method_type VARCHAR(40) NULL,
  card_brand     VARCHAR(40)     NULL,
  min_amount     DECIMAL(18,2)   NULL,
  max_amount     DECIMAL(18,2)   NULL,
  account_type_id SMALLINT UNSIGNED NULL,
  transaction_type ENUM('subscription','one_time','deposit','booking','payout','any') NOT NULL DEFAULT 'any',
  gateway_account_id INT UNSIGNED NOT NULL,
  fallback_gateway_account_id INT UNSIGNED NULL,
  -- Retry the fallback only for failures that a different processor might
  -- actually succeed at. A hard decline is a decline everywhere; a gateway
  -- timeout is worth retrying elsewhere.
  failover_on_codes JSON         NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_routing_rules_eval (is_active, priority),
  KEY ix_routing_rules_currency (currency_code, country_id),
  CONSTRAINT fk_routing_rules_account FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_fallback FOREIGN KEY (fallback_gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_routing_rules_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_routing_rules_acct_type FOREIGN KEY (account_type_id) REFERENCES account_types (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- payment_intents — the lifecycle owner
--
-- One intent per thing the customer is trying to pay for. It may produce several
-- attempts across several gateways before it succeeds, and exactly one
-- `payments` row when it does.
-- -----------------------------------------------------------------------------
CREATE TABLE payment_intents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,

  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  exchange_rate  DECIMAL(24,10)  NULL,
  -- Captured separately because an authorisation can be captured in part: a
  -- deposit taken now, the balance on completion.
  amount_captured DECIMAL(18,2)  NOT NULL DEFAULT 0,
  amount_refunded DECIMAL(18,2)  NOT NULL DEFAULT 0,

  purpose        ENUM('subscription','listing_credit','featured_placement','booking_deposit','lead_purchase','commission','service_fee','wallet_topup','other') NOT NULL DEFAULT 'other',
  invoice_id     BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  booking_id     BIGINT UNSIGNED NULL,
  order_reference VARCHAR(120)   NULL,
  description    VARCHAR(500)    NULL,

  status         ENUM('created','requires_payment_method','requires_confirmation','requires_action','processing','requires_capture','succeeded','partially_captured','cancelled','failed','expired') NOT NULL DEFAULT 'created',
  -- Manual capture is how a deposit is held without being taken: authorise now,
  -- capture only when the viewing actually happens.
  capture_method ENUM('automatic','manual') NOT NULL DEFAULT 'automatic',
  confirmation_method ENUM('automatic','manual') NOT NULL DEFAULT 'automatic',
  -- An authorisation expires, typically in 7 days. After that the funds are
  -- released whether or not anyone captured them.
  authorization_expires_at DATETIME(3) NULL,

  gateway_account_id INT UNSIGNED NULL,
  payment_method_id BIGINT UNSIGNED NULL,
  provider_intent_id VARCHAR(191) NULL,
  -- Returned to the browser to complete the payment. Short-lived and
  -- single-purpose; never a credential.
  client_secret_ref VARCHAR(191) NULL,

  -- Strong Customer Authentication. In the EU and UK an exemption that is
  -- claimed and then challenged still has to be recorded, because liability for
  -- a fraudulent transaction turns on exactly this.
  three_ds_status ENUM('not_required','required','pending','authenticated','attempted','failed','rejected','exempted') NOT NULL DEFAULT 'not_required',
  three_ds_version VARCHAR(12)   NULL,
  sca_exemption  ENUM('none','low_value','trusted_beneficiary','recurring','corporate','transaction_risk_analysis','merchant_initiated') NULL,
  liability_shift TINYINT(1)     NULL,

  -- Fraud screening outcome, kept on the intent because it decides whether the
  -- attempt is even made.
  risk_score     TINYINT UNSIGNED NULL,
  risk_decision  ENUM('allow','review','challenge','block') NULL,

  idempotency_key VARCHAR(120)   NULL,
  return_url     VARCHAR(700)    NULL,
  statement_descriptor VARCHAR(60) NULL,
  metadata       JSON            NULL,

  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,

  expires_at     DATETIME(3)     NULL,
  succeeded_at   DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  cancellation_reason VARCHAR(255) NULL,
  last_error_code VARCHAR(80)    NULL,
  last_error_message VARCHAR(500) NULL,

  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_intents_public_id (public_id),
  UNIQUE KEY uq_payment_intents_reference (reference),
  UNIQUE KEY uq_payment_intents_idempotency (idempotency_key),
  KEY ix_payment_intents_account (account_id, status, created_at),
  KEY ix_payment_intents_provider (provider_intent_id),
  KEY ix_payment_intents_status (status, created_at),
  KEY ix_payment_intents_invoice (invoice_id),
  -- Drives the sweeper that cancels intents whose authorisation is about to
  -- lapse, so funds are not left held on a customer's card.
  KEY ix_payment_intents_auth_expiry (status, authorization_expires_at),
  KEY ix_payment_intents_gateway (gateway_account_id, status),
  CONSTRAINT fk_payment_intents_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_payment_intents_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_intents_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_intents_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_intents_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_intents_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_intents_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL,
  CONSTRAINT ck_payment_intents_amount CHECK (amount >= 0 AND amount_captured >= 0 AND amount_refunded >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Every call made to a processor for an intent. The forensic record: which
-- gateway, what it said, how long it took, and whether the retry that followed
-- was a different processor or the same one.
CREATE TABLE payment_attempts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_intent_id BIGINT UNSIGNED NOT NULL,
  attempt_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  gateway_account_id INT UNSIGNED NULL,
  operation      ENUM('authorize','capture','sale','void','refund','verify','tokenize','three_ds_init','three_ds_complete') NOT NULL DEFAULT 'sale',
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  status         ENUM('pending','succeeded','failed','timeout','cancelled') NOT NULL DEFAULT 'pending',
  provider_transaction_id VARCHAR(191) NULL,
  -- The processor's own codes, kept raw. Normalised codes lose the detail that
  -- matters when arguing with an acquirer about a decline pattern.
  response_code  VARCHAR(40)     NULL,
  response_message VARCHAR(500)  NULL,
  -- Our normalised classification, which is what retry logic keys on.
  decline_type   ENUM('none','soft','hard','fraud','technical','authentication','insufficient_funds','expired_card','do_not_honor','processor_unavailable') NULL,
  avs_result     VARCHAR(10)     NULL,
  cvv_result     VARCHAR(10)     NULL,
  network_transaction_id VARCHAR(191) NULL,
  processor_fee  DECIMAL(12,4)   NULL,
  duration_ms    INT UNSIGNED    NULL,
  is_retry       TINYINT(1)      NOT NULL DEFAULT 0,
  is_failover    TINYINT(1)      NOT NULL DEFAULT 0,
  request_payload JSON           NULL,
  response_payload JSON          NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_attempts (payment_intent_id, attempt_number, operation),
  KEY ix_payment_attempts_intent (payment_intent_id, created_at),
  KEY ix_payment_attempts_provider (provider_transaction_id),
  KEY ix_payment_attempts_decline (decline_type, created_at),
  KEY ix_payment_attempts_gateway (gateway_account_id, status, created_at),
  CONSTRAINT fk_payment_attempts_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_attempts_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Link the settled payment back to the intent that produced it.
ALTER TABLE payments
  ADD COLUMN payment_intent_id BIGINT UNSIGNED NULL AFTER account_id,
  ADD COLUMN gateway_account_id INT UNSIGNED NULL AFTER provider,
  ADD COLUMN captured_at DATETIME(3) NULL AFTER paid_at,
  ADD COLUMN settlement_id BIGINT UNSIGNED NULL AFTER captured_at,
  ADD COLUMN settled_at DATETIME(3) NULL AFTER settlement_id,
  -- Set once the processor's statement has been matched to this row. An
  -- unreconciled payment older than the settlement window is a problem.
  ADD COLUMN is_reconciled TINYINT(1) NOT NULL DEFAULT 0 AFTER settled_at,
  ADD COLUMN disputed_amount DECIMAL(18,2) NOT NULL DEFAULT 0 AFTER refunded_amount,
  ADD KEY ix_payments_intent (payment_intent_id),
  ADD KEY ix_payments_reconcile (is_reconciled, paid_at),
  ADD KEY ix_payments_settlement (settlement_id),
  ADD CONSTRAINT fk_payments_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_payments_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- gateway_webhook_events — the inbound edge
--
-- Processors send events at-least-once, out of order, and occasionally not at
-- all. The unique index on (gateway, provider_event_id) is what makes replay
-- harmless. The raw payload is kept because a processing bug found next month
-- must be fixable by re-running history, not by asking the processor to resend.
-- -----------------------------------------------------------------------------
CREATE TABLE gateway_webhook_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  gateway_id     SMALLINT UNSIGNED NOT NULL,
  gateway_account_id INT UNSIGNED NULL,
  provider_event_id VARCHAR(191) NOT NULL,
  event_type     VARCHAR(120)    NOT NULL,
  api_version    VARCHAR(40)     NULL,
  -- The processor's own creation timestamp, which is what event ordering must
  -- use — arrival order is not causal order.
  provider_created_at DATETIME(3) NULL,
  payload        JSON            NOT NULL,
  signature      VARCHAR(500)    NULL,
  signature_verified TINYINT(1)  NOT NULL DEFAULT 0,
  -- Resolved links, populated on processing so the event is queryable by the
  -- thing it concerns.
  payment_intent_id BIGINT UNSIGNED NULL,
  payment_id     BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  dispute_id     BIGINT UNSIGNED NULL,
  status         ENUM('received','processing','processed','ignored','failed','duplicate') NOT NULL DEFAULT 'received',
  processing_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  error_message  VARCHAR(1000)   NULL,
  received_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  processed_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_gateway_webhook_events (gateway_id, provider_event_id),
  KEY ix_gateway_webhooks_status (status, received_at),
  KEY ix_gateway_webhooks_type (event_type, received_at),
  KEY ix_gateway_webhooks_intent (payment_intent_id),
  KEY ix_gateway_webhooks_payment (payment_id),
  CONSTRAINT fk_gateway_webhooks_gateway FOREIGN KEY (gateway_id) REFERENCES payment_gateways (id) ON DELETE CASCADE,
  CONSTRAINT fk_gateway_webhooks_account FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_gateway_webhooks_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE SET NULL,
  CONSTRAINT fk_gateway_webhooks_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Disputes and chargebacks
--
-- A dispute has a deadline, and missing it forfeits the money automatically. The
-- deadline is therefore indexed and drives an alert, not a calendar reminder.
-- -----------------------------------------------------------------------------
CREATE TABLE disputes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  payment_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  gateway_account_id INT UNSIGNED NULL,
  provider_dispute_id VARCHAR(191) NULL,
  dispute_type   ENUM('chargeback','inquiry','retrieval_request','pre_arbitration','arbitration','fraud_alert') NOT NULL DEFAULT 'chargeback',
  reason_code    VARCHAR(40)     NULL,
  reason         ENUM('fraudulent','duplicate','product_not_received','product_unacceptable','subscription_cancelled','unrecognised','credit_not_processed','incorrect_amount','general','other') NOT NULL DEFAULT 'general',
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  -- Levied by the acquirer whether or not the dispute is won. Frequently
  -- exceeds the transaction value on small payments, which changes whether
  -- fighting it is worth doing.
  dispute_fee    DECIMAL(12,2)   NULL,
  status         ENUM('needs_response','under_review','won','lost','accepted','expired','withdrawn') NOT NULL DEFAULT 'needs_response',
  -- Hard deadline. Silence past it is an automatic loss.
  evidence_due_at DATETIME(3)    NULL,
  submitted_at   DATETIME(3)     NULL,
  resolved_at    DATETIME(3)     NULL,
  outcome_note   VARCHAR(1000)   NULL,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  -- Whether the funds have been pulled back already. Most schemes debit
  -- immediately and refund on a win, so cash flow is affected before the outcome.
  is_funds_withdrawn TINYINT(1)  NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_disputes_public_id (public_id),
  KEY ix_disputes_payment (payment_id),
  KEY ix_disputes_account (account_id, status),
  -- The queue that matters: open disputes ordered by how soon they expire.
  KEY ix_disputes_deadline (status, evidence_due_at),
  KEY ix_disputes_provider (provider_dispute_id),
  CONSTRAINT fk_disputes_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE RESTRICT,
  CONSTRAINT fk_disputes_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_disputes_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_disputes_assignee FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE gateway_webhook_events
  ADD CONSTRAINT fk_gateway_webhooks_dispute FOREIGN KEY (dispute_id) REFERENCES disputes (id) ON DELETE SET NULL;

CREATE TABLE dispute_evidence (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dispute_id     BIGINT UNSIGNED NOT NULL,
  evidence_type  ENUM('receipt','invoice','customer_communication','service_documentation','shipping_documentation','refund_policy','terms_of_service','access_log','duplicate_charge_documentation','cancellation_policy','uncategorised') NOT NULL,
  description    VARCHAR(1000)   NULL,
  document_id    BIGINT UNSIGNED NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  text_content   TEXT            NULL,
  submitted_at   DATETIME(3)     NULL,
  added_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_dispute_evidence (dispute_id, evidence_type),
  CONSTRAINT fk_dispute_evidence_dispute FOREIGN KEY (dispute_id) REFERENCES disputes (id) ON DELETE CASCADE,
  CONSTRAINT fk_dispute_evidence_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_dispute_evidence_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL,
  CONSTRAINT fk_dispute_evidence_user FOREIGN KEY (added_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE dispute_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dispute_id     BIGINT UNSIGNED NOT NULL,
  event_type     ENUM('opened','evidence_requested','evidence_submitted','status_changed','escalated','won','lost','accepted','expired','note_added','funds_withdrawn','funds_reinstated') NOT NULL,
  from_status    VARCHAR(40)     NULL,
  to_status      VARCHAR(40)     NULL,
  note           VARCHAR(1000)   NULL,
  actor_user_id  BIGINT UNSIGNED NULL,
  actor_type     ENUM('user','system','gateway') NOT NULL DEFAULT 'system',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_dispute_events (dispute_id, created_at),
  CONSTRAINT fk_dispute_events_dispute FOREIGN KEY (dispute_id) REFERENCES disputes (id) ON DELETE CASCADE,
  CONSTRAINT fk_dispute_events_user FOREIGN KEY (actor_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Settlement and reconciliation
--
-- The processor pays out a net figure covering hundreds of transactions minus
-- fees, refunds and chargebacks. Matching that lump against our own records,
-- daily, is what makes the finance function trustworthy — and what catches a
-- processor's error, which does happen.
-- -----------------------------------------------------------------------------
CREATE TABLE settlements (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  gateway_account_id INT UNSIGNED NOT NULL,
  provider_settlement_id VARCHAR(191) NULL,
  settlement_date DATE           NOT NULL,
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- The breakdown the processor reports.
  gross_amount   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  refund_amount  DECIMAL(18,2)   NOT NULL DEFAULT 0,
  chargeback_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  fee_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  adjustment_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  reserve_amount DECIMAL(18,2)   NOT NULL DEFAULT 0,
  net_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  transaction_count INT UNSIGNED NOT NULL DEFAULT 0,
  bank_reference VARCHAR(191)    NULL,
  status         ENUM('expected','received','reconciling','reconciled','discrepancy','disputed') NOT NULL DEFAULT 'expected',
  -- Difference between what the processor paid and what our ledger expected.
  -- Anything non-zero opens a reconciliation exception.
  variance_amount DECIMAL(18,2)  NOT NULL DEFAULT 0,
  matched_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unmatched_count INT UNSIGNED   NOT NULL DEFAULT 0,
  statement_url  VARCHAR(700)    NULL,
  reconciled_by_user_id BIGINT UNSIGNED NULL,
  reconciled_at  DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_settlements_public_id (public_id),
  UNIQUE KEY uq_settlements_provider (gateway_account_id, provider_settlement_id),
  KEY ix_settlements_date (settlement_date, status),
  KEY ix_settlements_status (status, variance_amount),
  CONSTRAINT fk_settlements_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_settlements_user FOREIGN KEY (reconciled_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE payments
  ADD CONSTRAINT fk_payments_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE SET NULL;

CREATE TABLE settlement_lines (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  settlement_id  BIGINT UNSIGNED NOT NULL,
  line_type      ENUM('charge','refund','chargeback','chargeback_reversal','fee','adjustment','reserve','reserve_release','payout','transfer') NOT NULL,
  provider_transaction_id VARCHAR(191) NULL,
  gross_amount   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  fee_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  net_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL,
  transaction_date DATE          NULL,
  description    VARCHAR(500)    NULL,
  -- Our side of the match, filled by the reconciliation job.
  payment_id     BIGINT UNSIGNED NULL,
  refund_id      BIGINT UNSIGNED NULL,
  dispute_id     BIGINT UNSIGNED NULL,
  match_status   ENUM('unmatched','matched','partial','ambiguous','manual') NOT NULL DEFAULT 'unmatched',
  match_confidence DECIMAL(5,4)  NULL,
  matched_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_settlement_lines_settlement (settlement_id, match_status),
  KEY ix_settlement_lines_provider (provider_transaction_id),
  KEY ix_settlement_lines_payment (payment_id),
  KEY ix_settlement_lines_unmatched (match_status, transaction_date),
  CONSTRAINT fk_settlement_lines_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE,
  CONSTRAINT fk_settlement_lines_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_settlement_lines_refund FOREIGN KEY (refund_id) REFERENCES refunds (id) ON DELETE SET NULL,
  CONSTRAINT fk_settlement_lines_dispute FOREIGN KEY (dispute_id) REFERENCES disputes (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Where the two sides disagree. Every exception must be closed by a human with a
-- reason; an unexplained variance is how fraud and integration bugs hide.
CREATE TABLE reconciliation_exceptions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  settlement_id  BIGINT UNSIGNED NULL,
  settlement_line_id BIGINT UNSIGNED NULL,
  payment_id     BIGINT UNSIGNED NULL,
  exception_type ENUM('missing_in_ledger','missing_in_settlement','amount_mismatch','currency_mismatch','duplicate_match','date_mismatch','unexpected_fee','orphan_refund','unknown') NOT NULL,
  expected_amount DECIMAL(18,2)  NULL,
  actual_amount  DECIMAL(18,2)   NULL,
  variance       DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  details        VARCHAR(1000)   NULL,
  severity       ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
  status         ENUM('open','investigating','resolved','written_off','escalated') NOT NULL DEFAULT 'open',
  resolution     VARCHAR(1000)   NULL,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  resolved_by_user_id BIGINT UNSIGNED NULL,
  resolved_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_recon_exceptions_status (status, severity, created_at),
  KEY ix_recon_exceptions_settlement (settlement_id),
  CONSTRAINT fk_recon_exceptions_settlement FOREIGN KEY (settlement_id) REFERENCES settlements (id) ON DELETE CASCADE,
  CONSTRAINT fk_recon_exceptions_line FOREIGN KEY (settlement_line_id) REFERENCES settlement_lines (id) ON DELETE CASCADE,
  CONSTRAINT fk_recon_exceptions_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_recon_exceptions_assignee FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_recon_exceptions_resolver FOREIGN KEY (resolved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- payment_splits — marketplace commission
--
-- A single charge that belongs partly to the platform and partly to an agency.
-- Modelled explicitly so the agency's share is a tracked liability from the
-- moment it is collected, rather than something worked out at payout time.
-- -----------------------------------------------------------------------------
CREATE TABLE payment_splits (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_id     BIGINT UNSIGNED NOT NULL,
  payment_intent_id BIGINT UNSIGNED NULL,
  beneficiary_type ENUM('platform','organization','agent','partner','referrer','tax_authority','escrow') NOT NULL,
  beneficiary_account_id BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  split_type     ENUM('percentage','fixed','remainder') NOT NULL DEFAULT 'percentage',
  percentage     DECIMAL(7,4)    NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  description    VARCHAR(255)    NULL,
  -- Held until a condition clears — a viewing completing, a cooling-off period
  -- lapsing — then released into the next payout run.
  status         ENUM('pending','held','released','paid','reversed','cancelled') NOT NULL DEFAULT 'pending',
  hold_reason    VARCHAR(255)    NULL,
  release_after  DATETIME(3)     NULL,
  released_at    DATETIME(3)     NULL,
  payout_id      BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_payment_splits_payment (payment_id),
  KEY ix_payment_splits_beneficiary (beneficiary_account_id, status),
  KEY ix_payment_splits_release (status, release_after),
  KEY ix_payment_splits_payout (payout_id),
  CONSTRAINT fk_payment_splits_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_splits_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_splits_account FOREIGN KEY (beneficiary_account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_splits_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_splits_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_splits_payout FOREIGN KEY (payout_id) REFERENCES payouts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Commission structures, so the split is computed from a rule rather than hard
-- coded. Tiered rates are normal: a higher-volume agency keeps a larger share.
CREATE TABLE commission_schemes (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  applies_to     ENUM('subscription','lead_purchase','featured_placement','booking','transaction','referral') NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_type_id SMALLINT UNSIGNED NULL,
  calculation    ENUM('flat_percentage','tiered_percentage','flat_fee','tiered_fee','hybrid') NOT NULL DEFAULT 'flat_percentage',
  base_percentage DECIMAL(7,4)   NULL,
  base_fee       DECIMAL(12,2)   NULL,
  currency_code  CHAR(3)         NULL,
  minimum_fee    DECIMAL(12,2)   NULL,
  maximum_fee    DECIMAL(12,2)   NULL,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_schemes_code (code),
  KEY ix_commission_schemes_scope (applies_to, organization_id, is_active),
  KEY ix_commission_schemes_dates (effective_from, effective_to),
  CONSTRAINT fk_commission_schemes_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_commission_schemes_acct_type FOREIGN KEY (account_type_id) REFERENCES account_types (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE commission_tiers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  scheme_id      INT UNSIGNED    NOT NULL,
  tier_order     TINYINT UNSIGNED NOT NULL,
  threshold_from DECIMAL(18,2)   NOT NULL DEFAULT 0,
  threshold_to   DECIMAL(18,2)   NULL,
  percentage     DECIMAL(7,4)    NULL,
  fixed_fee      DECIMAL(12,2)   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_commission_tiers (scheme_id, tier_order),
  CONSTRAINT fk_commission_tiers_scheme FOREIGN KEY (scheme_id) REFERENCES commission_schemes (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Escrow
--
-- In the UAE, property deposits must sit in a regulated escrow account, not the
-- broker's operating account. Several other markets here have equivalent rules.
-- Modelling it explicitly is a compliance requirement, not a convenience.
-- -----------------------------------------------------------------------------
CREATE TABLE escrow_accounts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  name           VARCHAR(200)    NOT NULL,
  escrow_type    ENUM('project_escrow','deposit_holding','transaction_escrow','service_charge','security_deposit') NOT NULL DEFAULT 'deposit_holding',
  -- The regulator and account number, which is what an audit asks for first.
  regulator      VARCHAR(160)    NULL,
  regulator_reference VARCHAR(120) NULL,
  bank_name      VARCHAR(200)    NULL,
  account_number_last_four CHAR(4) NULL,
  iban_encrypted VARBINARY(512)  NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- Balance maintained from escrow_transactions, never written directly.
  balance        DECIMAL(18,2)   NOT NULL DEFAULT 0,
  held_balance   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  available_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
  status         ENUM('active','frozen','closing','closed') NOT NULL DEFAULT 'active',
  opened_at      DATE            NULL,
  closed_at      DATE            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_escrow_accounts_public_id (public_id),
  KEY ix_escrow_accounts_owner (account_id, status),
  KEY ix_escrow_accounts_project (project_id),
  CONSTRAINT fk_escrow_accounts_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_accounts_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_accounts_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE escrow_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  escrow_account_id BIGINT UNSIGNED NOT NULL,
  transaction_type ENUM('deposit','release','refund','forfeit','fee','interest','adjustment','transfer_in','transfer_out') NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- Running balance after this movement, so a statement is a range scan rather
  -- than a cumulative sum over history.
  balance_after  DECIMAL(18,2)   NOT NULL,
  payment_id     BIGINT UNSIGNED NULL,
  booking_id     BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  counterparty_name VARCHAR(200) NULL,
  reference      VARCHAR(120)    NULL,
  description    VARCHAR(500)    NULL,
  -- Releases from escrow usually require two-person authorisation.
  status         ENUM('pending','awaiting_approval','completed','rejected','reversed') NOT NULL DEFAULT 'pending',
  requested_by_user_id BIGINT UNSIGNED NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_escrow_transactions (escrow_account_id, occurred_at),
  KEY ix_escrow_transactions_status (status, occurred_at),
  KEY ix_escrow_transactions_payment (payment_id),
  CONSTRAINT fk_escrow_tx_account FOREIGN KEY (escrow_account_id) REFERENCES escrow_accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_escrow_tx_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_tx_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_tx_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_tx_requester FOREIGN KEY (requested_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_escrow_tx_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Wallets — stored balance
--
-- Agencies pre-fund an account and draw down against it for lead purchases and
-- boosts. Cheaper than a card charge per transaction, and it is what makes
-- micro-billing (a few dirhams per lead) economic at all.
-- -----------------------------------------------------------------------------
CREATE TABLE wallets (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  balance        DECIMAL(18,2)   NOT NULL DEFAULT 0,
  -- Reserved against pending operations, so two concurrent spends cannot both
  -- succeed against the same funds.
  held_balance   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  available_balance DECIMAL(18,2) NOT NULL DEFAULT 0,
  -- Negative balance allowance for trusted enterprise accounts.
  credit_limit   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  auto_topup_enabled TINYINT(1)  NOT NULL DEFAULT 0,
  auto_topup_threshold DECIMAL(18,2) NULL,
  auto_topup_amount DECIMAL(18,2) NULL,
  auto_topup_payment_method_id BIGINT UNSIGNED NULL,
  status         ENUM('active','frozen','closed') NOT NULL DEFAULT 'active',
  -- Optimistic-locking counter. A wallet is the most contended row in this
  -- schema; a version check is cheaper than holding a lock across a gateway call.
  version        INT UNSIGNED    NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_wallets_public_id (public_id),
  UNIQUE KEY uq_wallets_account_currency (account_id, currency_code),
  KEY ix_wallets_topup (auto_topup_enabled, available_balance),
  CONSTRAINT fk_wallets_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_wallets_method FOREIGN KEY (auto_topup_payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE wallet_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  wallet_id      BIGINT UNSIGNED NOT NULL,
  transaction_type ENUM('topup','spend','refund','adjustment','bonus','expiry','transfer_in','transfer_out','hold','release','chargeback') NOT NULL,
  -- Signed: positive credits the wallet, negative debits it. The sign carries
  -- the direction so a running balance is a simple sum.
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  balance_after  DECIMAL(18,2)   NOT NULL,
  reference_type VARCHAR(60)     NULL,
  reference_id   BIGINT UNSIGNED NULL,
  payment_id     BIGINT UNSIGNED NULL,
  description    VARCHAR(500)    NULL,
  -- Idempotency at the wallet level: a retried spend must not debit twice.
  idempotency_key VARCHAR(120)   NULL,
  expires_at     DATETIME(3)     NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_wallet_tx_idempotency (idempotency_key),
  KEY ix_wallet_tx_wallet (wallet_id, created_at),
  KEY ix_wallet_tx_reference (reference_type, reference_id),
  KEY ix_wallet_tx_expiry (expires_at),
  CONSTRAINT fk_wallet_tx_wallet FOREIGN KEY (wallet_id) REFERENCES wallets (id) ON DELETE CASCADE,
  CONSTRAINT fk_wallet_tx_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_wallet_tx_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- payment_mandates — direct debit and stored-credential authority
--
-- SEPA, BACS and UAE Direct Debit all require a signed mandate with a reference
-- that must appear on every collection. Card-on-file for recurring use is the
-- same concept under a different name, and the scheme rules require the
-- agreement to be evidenced.
-- -----------------------------------------------------------------------------
CREATE TABLE payment_mandates (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  payment_method_id BIGINT UNSIGNED NULL,
  gateway_account_id INT UNSIGNED NULL,
  mandate_type   ENUM('sepa_direct_debit','bacs','ach','uae_direct_debit','card_on_file','open_banking') NOT NULL,
  mandate_reference VARCHAR(60)  NOT NULL,
  provider_mandate_id VARCHAR(191) NULL,
  scheme         VARCHAR(40)     NULL,
  status         ENUM('pending','active','suspended','cancelled','expired','failed') NOT NULL DEFAULT 'pending',
  signed_at      DATETIME(3)     NULL,
  signature_ip   VARBINARY(16)   NULL,
  signature_evidence VARCHAR(500) NULL,
  -- One-off versus recurring changes the scheme rules that apply and the
  -- notice period owed to the payer.
  is_recurring   TINYINT(1)      NOT NULL DEFAULT 1,
  first_collection_at DATE       NULL,
  last_collection_at DATE        NULL,
  cancelled_at   DATETIME(3)     NULL,
  cancellation_reason VARCHAR(255) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mandates_public_id (public_id),
  UNIQUE KEY uq_mandates_reference (mandate_reference),
  KEY ix_mandates_account (account_id, status),
  KEY ix_mandates_provider (provider_mandate_id),
  CONSTRAINT fk_mandates_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_mandates_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL,
  CONSTRAINT fk_mandates_gateway FOREIGN KEY (gateway_account_id) REFERENCES gateway_accounts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Dunning
--
-- Involuntary churn — subscriptions lost to an expired card rather than a
-- decision — is typically the largest single source of churn in a subscription
-- business, and almost all of it is recoverable with a decent retry schedule.
-- -----------------------------------------------------------------------------
CREATE TABLE dunning_campaigns (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  -- Different failure classes deserve different treatment: an expired card
  -- needs the customer to act, a temporary decline just needs retrying.
  trigger_reason ENUM('payment_failed','card_expiring','card_expired','insufficient_funds','subscription_past_due','invoice_overdue','mandate_failed') NOT NULL,
  applies_to_plan_id INT UNSIGNED NULL,
  account_type_id SMALLINT UNSIGNED NULL,
  max_attempts   TINYINT UNSIGNED NOT NULL DEFAULT 4,
  -- What happens when the schedule is exhausted.
  final_action   ENUM('cancel_subscription','downgrade_to_free','suspend_account','unpublish_listings','write_off','none') NOT NULL DEFAULT 'downgrade_to_free',
  grace_period_days SMALLINT UNSIGNED NOT NULL DEFAULT 7,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_dunning_campaigns_code (code),
  KEY ix_dunning_campaigns_trigger (trigger_reason, is_active),
  CONSTRAINT fk_dunning_campaigns_plan FOREIGN KEY (applies_to_plan_id) REFERENCES plans (id) ON DELETE CASCADE,
  CONSTRAINT fk_dunning_campaigns_acct_type FOREIGN KEY (account_type_id) REFERENCES account_types (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE dunning_steps (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  campaign_id    INT UNSIGNED    NOT NULL,
  step_number    TINYINT UNSIGNED NOT NULL,
  -- Offset from the original failure. Retrying immediately mostly fails again;
  -- 3, 5 and 7 days out is the shape that recovers most.
  delay_days     SMALLINT UNSIGNED NOT NULL DEFAULT 3,
  delay_hours    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  action         ENUM('retry_payment','send_email','send_sms','send_whatsapp','in_app_notice','restrict_features','notify_account_manager','final_action') NOT NULL DEFAULT 'retry_payment',
  notification_template_id INT UNSIGNED NULL,
  -- Retrying at a moment more likely to succeed — payday, or a different day of
  -- the month — measurably improves recovery.
  retry_strategy ENUM('same_method','alternate_method','updated_method_only','smart_timing') NOT NULL DEFAULT 'same_method',
  PRIMARY KEY (id),
  UNIQUE KEY uq_dunning_steps (campaign_id, step_number),
  CONSTRAINT fk_dunning_steps_campaign FOREIGN KEY (campaign_id) REFERENCES dunning_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_dunning_steps_template FOREIGN KEY (notification_template_id) REFERENCES notification_templates (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE dunning_runs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  campaign_id    INT UNSIGNED    NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  subscription_id BIGINT UNSIGNED NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  current_step   TINYINT UNSIGNED NOT NULL DEFAULT 0,
  status         ENUM('active','recovered','failed','cancelled','paused') NOT NULL DEFAULT 'active',
  amount_at_risk DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  next_action_at DATETIME(3)     NULL,
  recovered_at   DATETIME(3)     NULL,
  recovered_payment_id BIGINT UNSIGNED NULL,
  final_action_taken VARCHAR(60) NULL,
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  ended_at       DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_dunning_runs_due (status, next_action_at),
  KEY ix_dunning_runs_account (account_id, status),
  KEY ix_dunning_runs_subscription (subscription_id),
  CONSTRAINT fk_dunning_runs_campaign FOREIGN KEY (campaign_id) REFERENCES dunning_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_dunning_runs_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_dunning_runs_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT fk_dunning_runs_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL,
  CONSTRAINT fk_dunning_runs_payment FOREIGN KEY (recovered_payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE dunning_attempts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  dunning_run_id BIGINT UNSIGNED NOT NULL,
  step_number    TINYINT UNSIGNED NOT NULL,
  action         VARCHAR(60)     NOT NULL,
  outcome        ENUM('pending','succeeded','failed','skipped','bounced') NOT NULL DEFAULT 'pending',
  payment_intent_id BIGINT UNSIGNED NULL,
  notification_delivery_id BIGINT UNSIGNED NULL,
  error_message  VARCHAR(500)    NULL,
  attempted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_dunning_attempts_run (dunning_run_id, step_number),
  CONSTRAINT fk_dunning_attempts_run FOREIGN KEY (dunning_run_id) REFERENCES dunning_runs (id) ON DELETE CASCADE,
  CONSTRAINT fk_dunning_attempts_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Subscription changes and proration
--
-- Upgrading mid-cycle means crediting the unused portion of the old plan and
-- charging the remainder of the new one. Recording the arithmetic is what makes
-- the resulting invoice line explicable to a customer who queries it.
-- -----------------------------------------------------------------------------
CREATE TABLE subscription_changes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  subscription_id BIGINT UNSIGNED NOT NULL,
  change_type    ENUM('upgrade','downgrade','quantity_change','plan_change','pause','resume','cancel','reactivate','trial_extend','price_change') NOT NULL,
  from_plan_id   INT UNSIGNED    NULL,
  to_plan_id     INT UNSIGNED    NULL,
  from_amount    DECIMAL(18,2)   NULL,
  to_amount      DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  -- 'immediate' prorates now; 'period_end' defers. Downgrades almost always
  -- defer, upgrades almost always do not.
  effective_timing ENUM('immediate','period_end','specific_date') NOT NULL DEFAULT 'immediate',
  effective_at   DATETIME(3)     NULL,
  proration_behavior ENUM('create_prorations','none','always_invoice') NOT NULL DEFAULT 'create_prorations',
  proration_credit DECIMAL(18,2) NULL,
  proration_charge DECIMAL(18,2) NULL,
  proration_days_remaining SMALLINT UNSIGNED NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  reason         VARCHAR(500)    NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  status         ENUM('scheduled','applied','cancelled','failed') NOT NULL DEFAULT 'scheduled',
  applied_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_subscription_changes_sub (subscription_id, created_at),
  KEY ix_subscription_changes_scheduled (status, effective_at),
  CONSTRAINT fk_sub_changes_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE CASCADE,
  CONSTRAINT fk_sub_changes_from_plan FOREIGN KEY (from_plan_id) REFERENCES plans (id) ON DELETE SET NULL,
  CONSTRAINT fk_sub_changes_to_plan FOREIGN KEY (to_plan_id) REFERENCES plans (id) ON DELETE SET NULL,
  CONSTRAINT fk_sub_changes_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL,
  CONSTRAINT fk_sub_changes_user FOREIGN KEY (requested_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Metered billing
--
-- Lead purchases, API calls, boosts, media bandwidth — anything charged by
-- consumption rather than by subscription.
-- -----------------------------------------------------------------------------
CREATE TABLE billable_meters (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  unit_label     VARCHAR(40)     NOT NULL,
  aggregation    ENUM('sum','max','last','unique_count') NOT NULL DEFAULT 'sum',
  -- How the price is derived from the quantity. Graduated charges each band at
  -- its own rate; volume charges everything at the rate of the band reached.
  pricing_model  ENUM('per_unit','tiered_graduated','tiered_volume','package','free') NOT NULL DEFAULT 'per_unit',
  unit_price     DECIMAL(12,4)   NULL,
  currency_code  CHAR(3)         NULL,
  included_quantity BIGINT UNSIGNED NOT NULL DEFAULT 0,
  package_size   INT UNSIGNED    NULL,
  reset_period   ENUM('never','daily','monthly','billing_period') NOT NULL DEFAULT 'billing_period',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_billable_meters_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE meter_tiers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  meter_id       INT UNSIGNED    NOT NULL,
  tier_order     TINYINT UNSIGNED NOT NULL,
  up_to_quantity BIGINT UNSIGNED NULL,
  unit_price     DECIMAL(12,4)   NULL,
  flat_price     DECIMAL(12,2)   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_meter_tiers (meter_id, tier_order),
  CONSTRAINT fk_meter_tiers_meter FOREIGN KEY (meter_id) REFERENCES billable_meters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usage_records (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  meter_id       INT UNSIGNED    NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  subscription_id BIGINT UNSIGNED NULL,
  quantity       BIGINT          NOT NULL,
  -- Bucketed to the billing period so aggregation is a range scan.
  usage_date     DATE            NOT NULL,
  reference_type VARCHAR(60)     NULL,
  reference_id   BIGINT UNSIGNED NULL,
  -- Guards against a retried API call being billed twice.
  idempotency_key VARCHAR(120)   NULL,
  is_billed      TINYINT(1)      NOT NULL DEFAULT 0,
  invoice_line_id BIGINT UNSIGNED NULL,
  recorded_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_usage_records_idempotency (idempotency_key),
  KEY ix_usage_records_billing (account_id, meter_id, usage_date, is_billed),
  KEY ix_usage_records_unbilled (is_billed, usage_date),
  CONSTRAINT fk_usage_records_meter FOREIGN KEY (meter_id) REFERENCES billable_meters (id) ON DELETE CASCADE,
  CONSTRAINT fk_usage_records_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_usage_records_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT fk_usage_records_line FOREIGN KEY (invoice_line_id) REFERENCES invoice_lines (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Pre-aggregated so a mid-period usage display does not scan the raw records.
CREATE TABLE usage_summaries (
  account_id     BIGINT UNSIGNED NOT NULL,
  meter_id       INT UNSIGNED    NOT NULL,
  period_start   DATE            NOT NULL,
  period_end     DATE            NOT NULL,
  total_quantity BIGINT          NOT NULL DEFAULT 0,
  included_quantity BIGINT UNSIGNED NOT NULL DEFAULT 0,
  billable_quantity BIGINT       NOT NULL DEFAULT 0,
  computed_amount DECIMAL(18,2)  NULL,
  currency_code  CHAR(3)         NULL,
  is_finalised   TINYINT(1)      NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (account_id, meter_id, period_start),
  KEY ix_usage_summaries_period (period_start, is_finalised),
  CONSTRAINT fk_usage_summaries_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_usage_summaries_meter FOREIGN KEY (meter_id) REFERENCES billable_meters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Quotes, purchase orders and installments — the enterprise sales motion
--
-- Enterprise agency deals are not self-serve checkouts. They are quoted,
-- approved, raised against a purchase order, and paid on terms.
-- -----------------------------------------------------------------------------
CREATE TABLE quotes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  quote_number   VARCHAR(40)     NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  contact_name   VARCHAR(200)    NULL,
  contact_email  VARCHAR(255)    NULL,
  currency_code  CHAR(3)         NOT NULL,
  subtotal       DECIMAL(18,2)   NOT NULL DEFAULT 0,
  discount_total DECIMAL(18,2)   NOT NULL DEFAULT 0,
  tax_total      DECIMAL(18,2)   NOT NULL DEFAULT 0,
  total          DECIMAL(18,2)   NOT NULL DEFAULT 0,
  status         ENUM('draft','sent','viewed','accepted','rejected','expired','converted','superseded') NOT NULL DEFAULT 'draft',
  valid_until    DATE            NULL,
  payment_terms  VARCHAR(120)    NULL,
  notes          TEXT            NULL,
  -- Discounts beyond a threshold need sign-off, which is why the approval is
  -- part of the record rather than an email.
  requires_approval TINYINT(1)   NOT NULL DEFAULT 0,
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  owner_user_id  BIGINT UNSIGNED NULL,
  sent_at        DATETIME(3)     NULL,
  viewed_at      DATETIME(3)     NULL,
  accepted_at    DATETIME(3)     NULL,
  converted_invoice_id BIGINT UNSIGNED NULL,
  pdf_url        VARCHAR(700)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_quotes_public_id (public_id),
  UNIQUE KEY uq_quotes_number (quote_number),
  KEY ix_quotes_account (account_id, status),
  KEY ix_quotes_status (status, valid_until),
  KEY ix_quotes_owner (owner_user_id, status),
  CONSTRAINT fk_quotes_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_quotes_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_quotes_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_quotes_owner FOREIGN KEY (owner_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_quotes_invoice FOREIGN KEY (converted_invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE quote_lines (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  quote_id       BIGINT UNSIGNED NOT NULL,
  plan_id        INT UNSIGNED    NULL,
  description    VARCHAR(500)    NOT NULL,
  quantity       DECIMAL(12,3)   NOT NULL DEFAULT 1,
  unit_amount    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  discount_percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(18,2)  NOT NULL DEFAULT 0,
  tax_rate       DECIMAL(6,3)    NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  line_total     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  billing_period ENUM('one_time','monthly','quarterly','yearly') NOT NULL DEFAULT 'monthly',
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ix_quote_lines_quote (quote_id, sort_order),
  CONSTRAINT fk_quote_lines_quote FOREIGN KEY (quote_id) REFERENCES quotes (id) ON DELETE CASCADE,
  CONSTRAINT fk_quote_lines_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE purchase_orders (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  po_number      VARCHAR(80)     NOT NULL,
  -- Many corporate customers will not pay an invoice that does not quote their
  -- PO number, so it has to travel onto the invoice.
  issued_by      VARCHAR(200)    NULL,
  amount         DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  amount_consumed DECIMAL(18,2)  NOT NULL DEFAULT 0,
  valid_from     DATE            NULL,
  valid_until    DATE            NULL,
  status         ENUM('active','exhausted','expired','cancelled') NOT NULL DEFAULT 'active',
  document_id    BIGINT UNSIGNED NULL,
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_purchase_orders (account_id, po_number),
  KEY ix_purchase_orders_status (status, valid_until),
  CONSTRAINT fk_purchase_orders_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_purchase_orders_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE installment_plans (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  total_amount   DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  installment_count TINYINT UNSIGNED NOT NULL,
  frequency      ENUM('weekly','biweekly','monthly','quarterly') NOT NULL DEFAULT 'monthly',
  interest_rate  DECIMAL(6,3)    NOT NULL DEFAULT 0,
  down_payment   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  amount_paid    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  status         ENUM('active','completed','defaulted','cancelled') NOT NULL DEFAULT 'active',
  payment_method_id BIGINT UNSIGNED NULL,
  started_at     DATE            NULL,
  completed_at   DATE            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_installment_plans_public_id (public_id),
  KEY ix_installment_plans_account (account_id, status),
  CONSTRAINT fk_installment_plans_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_installment_plans_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL,
  CONSTRAINT fk_installment_plans_method FOREIGN KEY (payment_method_id) REFERENCES payment_methods (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE installment_schedules (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  installment_plan_id BIGINT UNSIGNED NOT NULL,
  installment_number TINYINT UNSIGNED NOT NULL,
  due_date       DATE            NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  principal_amount DECIMAL(18,2) NULL,
  interest_amount DECIMAL(18,2)  NULL,
  status         ENUM('scheduled','due','paid','overdue','failed','waived') NOT NULL DEFAULT 'scheduled',
  payment_id     BIGINT UNSIGNED NULL,
  paid_at        DATETIME(3)     NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_installment_schedules (installment_plan_id, installment_number),
  KEY ix_installment_schedules_due (status, due_date),
  CONSTRAINT fk_installment_schedules_plan FOREIGN KEY (installment_plan_id) REFERENCES installment_plans (id) ON DELETE CASCADE,
  CONSTRAINT fk_installment_schedules_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Fraud and risk
-- -----------------------------------------------------------------------------
CREATE TABLE fraud_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  rule_type      ENUM('velocity','amount_threshold','geo_mismatch','bin_country_mismatch','email_domain','device_fingerprint','card_testing','proxy_vpn','blacklist','ml_score','custom') NOT NULL,
  conditions     JSON            NOT NULL,
  -- Points added to the intent's risk score. Rules compose rather than each
  -- deciding independently, so one signal alone cannot block a good customer.
  score_delta    SMALLINT        NOT NULL DEFAULT 0,
  action         ENUM('score_only','review','challenge_3ds','block','allow_override') NOT NULL DEFAULT 'score_only',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- Recorded so a rule that fires constantly but never on real fraud can be
  -- identified and retired.
  trigger_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  true_positive_count INT UNSIGNED NOT NULL DEFAULT 0,
  false_positive_count INT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_fraud_rules_code (code),
  KEY ix_fraud_rules_active (is_active, priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE fraud_assessments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_intent_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  assessment_type ENUM('payment','signup','listing','login','payout','refund') NOT NULL DEFAULT 'payment',
  total_score    SMALLINT        NOT NULL DEFAULT 0,
  decision       ENUM('allow','review','challenge','block') NOT NULL DEFAULT 'allow',
  -- Which rules fired, so a declined customer can be given an answer and a
  -- false positive can be traced to its cause.
  triggered_rules JSON           NULL,
  provider       VARCHAR(60)     NULL,
  provider_score DECIMAL(6,3)    NULL,
  device_fingerprint VARCHAR(191) NULL,
  ip_address     VARBINARY(16)   NULL,
  ip_country_id  BIGINT UNSIGNED NULL,
  is_proxy       TINYINT(1)      NULL,
  bin_country    CHAR(2)         NULL,
  -- Set once the outcome is known, so rule precision is measurable.
  outcome        ENUM('unknown','legitimate','fraudulent','disputed') NOT NULL DEFAULT 'unknown',
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_fraud_assessments_intent (payment_intent_id),
  KEY ix_fraud_assessments_decision (decision, created_at),
  KEY ix_fraud_assessments_account (account_id, created_at),
  KEY ix_fraud_assessments_device (device_fingerprint),
  KEY ix_fraud_assessments_outcome (outcome, decision),
  CONSTRAINT fk_fraud_assessments_intent FOREIGN KEY (payment_intent_id) REFERENCES payment_intents (id) ON DELETE CASCADE,
  CONSTRAINT fk_fraud_assessments_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_fraud_assessments_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_fraud_assessments_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- payment_links — send someone a URL and get paid
--
-- How an agent takes a deposit from a client who is not in the app, which in
-- this industry is most of them.
-- -----------------------------------------------------------------------------
CREATE TABLE payment_links (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  token          CHAR(32)        CHARACTER SET ascii NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  title          VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  amount         DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- Open-amount links let the payer choose, which suits deposits and part
  -- payments.
  allow_custom_amount TINYINT(1) NOT NULL DEFAULT 0,
  minimum_amount DECIMAL(18,2)   NULL,
  listing_id     BIGINT UNSIGNED NULL,
  booking_id     BIGINT UNSIGNED NULL,
  max_uses       INT UNSIGNED    NULL,
  use_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  collect_billing_address TINYINT(1) NOT NULL DEFAULT 0,
  collect_phone  TINYINT(1)      NOT NULL DEFAULT 1,
  status         ENUM('active','paid','expired','cancelled') NOT NULL DEFAULT 'active',
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_links_public_id (public_id),
  UNIQUE KEY uq_payment_links_token (token),
  KEY ix_payment_links_account (account_id, status),
  KEY ix_payment_links_expiry (status, expires_at),
  CONSTRAINT fk_payment_links_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_links_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_links_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_payment_links_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0018', 'payments_infrastructure');
