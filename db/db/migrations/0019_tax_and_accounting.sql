-- =============================================================================
-- Liv Finder — 0019 · Tax engine and general ledger
-- =============================================================================
-- Selling in forty countries means forty tax regimes, and getting them wrong is
-- not a bug — it is a liability that accrues silently and is discovered at
-- audit, with interest.
--
-- Concretely, this platform has to handle at once:
--
--   · UAE VAT at 5%, with zero-rating for exports of services outside the GCC.
--   · UK VAT at 20%, with the place-of-supply rules that decide whether a
--     Dubai agency advertising to UK buyers is even in scope.
--   · EU VAT with the reverse charge, where a validated VAT number moves the
--     liability to the customer and we charge nothing — but only if the number
--     was valid on the invoice date, which is why validations are timestamped
--     and kept.
--   · US sales tax, which is not a national tax at all but thousands of
--     overlapping state, county and city jurisdictions with economic nexus
--     thresholds.
--   · Saudi VAT at 15%, with mandatory e-invoicing and QR codes.
--   · Withholding tax deducted at source on payouts in several markets.
--
-- Below the tax engine sits a real general ledger. Migration 0009's
-- `ledger_entries` gave double-entry postings; this adds what makes them an
-- accounting system: a chart of accounts, journals, closable periods, and
-- revenue recognition — because a yearly subscription collected in January is
-- one twelfth of a month's revenue, not a year's, and the difference between
-- cash and recognised revenue is most of what a finance team does.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- tax_jurisdictions
--
-- Hierarchical, because US sales tax is genuinely nested: a sale in Los Angeles
-- attracts California state tax, LA County tax, and a city district tax, all at
-- once and all remitted separately.
-- -----------------------------------------------------------------------------
CREATE TABLE tax_jurisdictions (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  parent_id      INT UNSIGNED    NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  jurisdiction_level ENUM('country','state','county','city','district','special','economic_union') NOT NULL DEFAULT 'country',
  country_id     BIGINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  tax_system     ENUM('vat','gst','sales_tax','consumption_tax','none') NOT NULL DEFAULT 'vat',
  -- What the tax is called on the invoice. Getting this wrong is a compliance
  -- failure in itself: an Indian invoice must say GST, a UAE one VAT.
  tax_label      VARCHAR(40)     NOT NULL DEFAULT 'VAT',
  currency_code  CHAR(3)         NULL,
  -- Whether displayed prices include tax. B2C in the EU must show gross; B2B in
  -- the US shows net. This single flag drives most of the pricing display logic.
  prices_include_tax TINYINT(1)  NOT NULL DEFAULT 0,
  -- Registration is only required past a turnover threshold, and tracking
  -- against it is how you know when you must register in a new market.
  registration_threshold DECIMAL(18,2) NULL,
  threshold_currency CHAR(3)     NULL,
  -- US economic nexus: registration is triggered by revenue or transaction
  -- count in the state, independent of physical presence.
  nexus_revenue_threshold DECIMAL(18,2) NULL,
  nexus_transaction_threshold INT UNSIGNED NULL,
  filing_frequency ENUM('monthly','quarterly','biannual','annual','on_demand') NULL,
  requires_einvoicing TINYINT(1) NOT NULL DEFAULT 0,
  einvoicing_standard VARCHAR(60) NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_jurisdictions_code (code),
  KEY ix_tax_jurisdictions_parent (parent_id),
  KEY ix_tax_jurisdictions_country (country_id, jurisdiction_level),
  KEY ix_tax_jurisdictions_active (is_active, jurisdiction_level),
  CONSTRAINT fk_tax_jurisdictions_parent FOREIGN KEY (parent_id) REFERENCES tax_jurisdictions (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_jurisdictions_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_jurisdictions_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- tax_rates — versioned by effective date
--
-- Rates change, and an invoice must be recalculable at the rate that applied on
-- its issue date, not today's. Every rate therefore carries a validity window
-- and old rows are never edited.
-- -----------------------------------------------------------------------------
CREATE TABLE tax_rates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  jurisdiction_id INT UNSIGNED   NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  rate_type      ENUM('standard','reduced','super_reduced','zero','exempt','out_of_scope','reverse_charge','withholding') NOT NULL DEFAULT 'standard',
  percentage     DECIMAL(7,4)    NOT NULL DEFAULT 0,
  -- Some jurisdictions levy a flat amount rather than a percentage.
  fixed_amount   DECIMAL(12,4)   NULL,
  -- Which supplies this rate applies to. Digital advertising, agency
  -- commission and listing subscriptions are not always treated the same way.
  applies_to_categories JSON     NULL,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  -- Only meaningful for compound systems (Canada PST on top of GST). Most
  -- jurisdictions are non-compound and this stays 0.
  is_compound    TINYINT(1)      NOT NULL DEFAULT 0,
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  legal_reference VARCHAR(255)   NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_rates (jurisdiction_id, code, effective_from),
  -- The lookup the tax engine makes on every line: jurisdiction plus date.
  KEY ix_tax_rates_lookup (jurisdiction_id, rate_type, effective_from, effective_to),
  KEY ix_tax_rates_active (is_active, effective_from),
  CONSTRAINT fk_tax_rates_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- tax_rules — place of supply and taxability
--
-- Which rate applies is not just "where is the customer". It depends on whether
-- the customer is a business, whether they supplied a valid tax number, whether
-- the supply is digital, and where the supplier is established. These rules
-- encode that decision so it is auditable rather than buried in code.
-- -----------------------------------------------------------------------------
CREATE TABLE tax_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  -- Match conditions. NULL means any.
  supplier_country_id BIGINT UNSIGNED NULL,
  customer_country_id BIGINT UNSIGNED NULL,
  customer_type  ENUM('b2c','b2b','any') NOT NULL DEFAULT 'any',
  -- The decisive input for EU reverse charge.
  requires_valid_tax_id TINYINT(1) NOT NULL DEFAULT 0,
  supply_type    ENUM('digital_service','physical_goods','professional_service','advertising','commission','subscription','any') NOT NULL DEFAULT 'any',
  product_tax_category VARCHAR(60) NULL,
  -- The outcome.
  place_of_supply ENUM('supplier_country','customer_country','property_location','use_and_enjoyment') NOT NULL DEFAULT 'customer_country',
  resolved_rate_type ENUM('standard','reduced','super_reduced','zero','exempt','out_of_scope','reverse_charge') NOT NULL DEFAULT 'standard',
  jurisdiction_id INT UNSIGNED   NULL,
  -- Text that must appear on the invoice when this rule fires, e.g. "Reverse
  -- charge: VAT to be accounted for by the recipient". Omitting it invalidates
  -- the invoice in several jurisdictions.
  invoice_note   VARCHAR(500)    NULL,
  legal_reference VARCHAR(255)   NULL,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_tax_rules_eval (is_active, priority, effective_from),
  KEY ix_tax_rules_countries (supplier_country_id, customer_country_id, customer_type),
  CONSTRAINT fk_tax_rules_supplier FOREIGN KEY (supplier_country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_rules_customer FOREIGN KEY (customer_country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_rules_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Our own registrations. You may only charge tax in a jurisdiction where you are
-- registered, and the registration number must appear on the invoice.
CREATE TABLE tax_registrations (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  jurisdiction_id INT UNSIGNED   NOT NULL,
  legal_entity   VARCHAR(200)    NOT NULL,
  brand_id       INT UNSIGNED    NULL,
  registration_number VARCHAR(80) NOT NULL,
  registration_type ENUM('vat','gst','sales_tax','oss','ioss','moss','withholding') NOT NULL DEFAULT 'vat',
  registered_from DATE           NOT NULL,
  registered_to  DATE            NULL,
  filing_frequency ENUM('monthly','quarterly','biannual','annual') NULL,
  -- Which day of the following period the return is due, driving the filing
  -- reminder.
  filing_due_day TINYINT UNSIGNED NULL,
  status         ENUM('active','pending','deregistered','suspended') NOT NULL DEFAULT 'active',
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_registrations (jurisdiction_id, legal_entity, registration_type),
  KEY ix_tax_registrations_status (status, registered_from),
  CONSTRAINT fk_tax_registrations_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The customer's tax number. Validation is stored with a timestamp because
-- reverse charge is only defensible if the number was valid *when the invoice
-- was issued* — a number that lapses later does not retroactively invalidate it,
-- and one that was never checked leaves the liability with us.
CREATE TABLE customer_tax_ids (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  tax_id_type    ENUM('eu_vat','gb_vat','ae_trn','sa_vat','us_ein','in_gst','au_abn','ca_bn','za_vat','other') NOT NULL,
  tax_id_value   VARCHAR(60)     NOT NULL,
  legal_name     VARCHAR(255)    NULL,
  validation_status ENUM('unvalidated','valid','invalid','unavailable','expired') NOT NULL DEFAULT 'unvalidated',
  validated_at   DATETIME(3)     NULL,
  validation_source VARCHAR(60)  NULL,
  -- The service's response, retained as evidence. VIES returns a consultation
  -- number that proves the check was made, which is exactly what an auditor asks
  -- for.
  validation_response JSON       NULL,
  validation_reference VARCHAR(120) NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_customer_tax_ids (account_id, tax_id_type, tax_id_value),
  KEY ix_customer_tax_ids_validation (validation_status, validated_at),
  KEY ix_customer_tax_ids_value (tax_id_value),
  CONSTRAINT fk_customer_tax_ids_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_customer_tax_ids_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE tax_exemptions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  jurisdiction_id INT UNSIGNED   NULL,
  exemption_type ENUM('resale','government','non_profit','diplomatic','export','free_zone','other') NOT NULL,
  certificate_number VARCHAR(120) NULL,
  document_id    BIGINT UNSIGNED NULL,
  valid_from     DATE            NOT NULL,
  valid_to       DATE            NULL,
  status         ENUM('pending','approved','rejected','expired','revoked') NOT NULL DEFAULT 'pending',
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_tax_exemptions_account (account_id, status, valid_to),
  CONSTRAINT fk_tax_exemptions_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_exemptions_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_exemptions_document FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_exemptions_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- tax_transactions — the calculated tax on every line, kept forever
--
-- Not derivable after the fact: rates change, rules change, and the customer's
-- tax number may lapse. What was charged, under which rule, at which rate, on
-- which date, is a permanent record — and it is what a return is built from.
-- -----------------------------------------------------------------------------
CREATE TABLE tax_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_type  ENUM('invoice','credit_note','refund','payout','quote') NOT NULL DEFAULT 'invoice',
  invoice_id     BIGINT UNSIGNED NULL,
  invoice_line_id BIGINT UNSIGNED NULL,
  credit_note_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NOT NULL,

  jurisdiction_id INT UNSIGNED   NOT NULL,
  tax_rate_id    INT UNSIGNED    NULL,
  tax_rule_id    INT UNSIGNED    NULL,
  -- Snapshotted, not joined, so the record stands even if the rate row is later
  -- superseded.
  rate_percentage DECIMAL(7,4)   NOT NULL DEFAULT 0,
  rate_type      VARCHAR(40)     NOT NULL DEFAULT 'standard',
  tax_label      VARCHAR(40)     NOT NULL DEFAULT 'VAT',

  taxable_amount DECIMAL(18,2)   NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL,
  exchange_rate  DECIMAL(24,10)  NULL,
  tax_amount_base DECIMAL(18,2)  NULL,
  -- The reporting currency of the jurisdiction, which is frequently neither the
  -- transaction currency nor our base. A UK return must be filed in GBP.
  tax_amount_jurisdiction DECIMAL(18,2) NULL,
  jurisdiction_currency CHAR(3)  NULL,

  is_reverse_charge TINYINT(1)   NOT NULL DEFAULT 0,
  is_exempt      TINYINT(1)      NOT NULL DEFAULT 0,
  exemption_id   BIGINT UNSIGNED NULL,
  customer_tax_id VARCHAR(60)    NULL,
  place_of_supply_country_id BIGINT UNSIGNED NULL,
  -- The evidence used to determine the customer's location, which EU rules
  -- require to be two non-contradictory pieces.
  location_evidence JSON         NULL,

  transaction_date DATE          NOT NULL,
  tax_period     CHAR(7)         NOT NULL,
  filing_id      BIGINT UNSIGNED NULL,
  is_filed       TINYINT(1)      NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  KEY ix_tax_transactions_invoice (invoice_id),
  -- The query a VAT return is built from.
  KEY ix_tax_transactions_return (jurisdiction_id, tax_period, is_filed),
  KEY ix_tax_transactions_account (account_id, transaction_date),
  KEY ix_tax_transactions_period (tax_period, jurisdiction_id),
  KEY ix_tax_transactions_filing (filing_id),
  CONSTRAINT fk_tax_tx_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_tx_line FOREIGN KEY (invoice_line_id) REFERENCES invoice_lines (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_tx_credit_note FOREIGN KEY (credit_note_id) REFERENCES credit_notes (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_tx_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_tax_tx_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_tax_tx_rate FOREIGN KEY (tax_rate_id) REFERENCES tax_rates (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_tx_rule FOREIGN KEY (tax_rule_id) REFERENCES tax_rules (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_tx_exemption FOREIGN KEY (exemption_id) REFERENCES tax_exemptions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE tax_filings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  registration_id INT UNSIGNED   NOT NULL,
  jurisdiction_id INT UNSIGNED   NOT NULL,
  tax_period     CHAR(7)         NOT NULL,
  period_start   DATE            NOT NULL,
  period_end     DATE            NOT NULL,
  due_date       DATE            NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- Output tax collected, input tax reclaimable, and the net payable. The three
  -- numbers every VAT return reduces to.
  output_tax     DECIMAL(18,2)   NOT NULL DEFAULT 0,
  input_tax      DECIMAL(18,2)   NOT NULL DEFAULT 0,
  net_payable    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  taxable_sales  DECIMAL(18,2)   NOT NULL DEFAULT 0,
  zero_rated_sales DECIMAL(18,2) NOT NULL DEFAULT 0,
  exempt_sales   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  reverse_charge_sales DECIMAL(18,2) NOT NULL DEFAULT 0,
  transaction_count INT UNSIGNED NOT NULL DEFAULT 0,
  status         ENUM('draft','under_review','approved','submitted','accepted','rejected','amended','paid') NOT NULL DEFAULT 'draft',
  submitted_at   DATETIME(3)     NULL,
  submission_reference VARCHAR(120) NULL,
  paid_at        DATETIME(3)     NULL,
  payment_reference VARCHAR(120) NULL,
  prepared_by_user_id BIGINT UNSIGNED NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_tax_filings (registration_id, tax_period),
  -- The compliance calendar: what is due and when.
  KEY ix_tax_filings_due (status, due_date),
  KEY ix_tax_filings_jurisdiction (jurisdiction_id, tax_period),
  CONSTRAINT fk_tax_filings_registration FOREIGN KEY (registration_id) REFERENCES tax_registrations (id) ON DELETE CASCADE,
  CONSTRAINT fk_tax_filings_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE RESTRICT,
  CONSTRAINT fk_tax_filings_preparer FOREIGN KEY (prepared_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_tax_filings_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE tax_transactions
  ADD CONSTRAINT fk_tax_tx_filing FOREIGN KEY (filing_id) REFERENCES tax_filings (id) ON DELETE SET NULL;

-- Withholding tax deducted at source on payouts. Common across the Gulf and
-- much of Asia; the payer is liable for getting it right.
CREATE TABLE withholding_taxes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payout_id      BIGINT UNSIGNED NULL,
  payment_split_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  jurisdiction_id INT UNSIGNED   NOT NULL,
  gross_amount   DECIMAL(18,2)   NOT NULL,
  withholding_rate DECIMAL(7,4)  NOT NULL,
  withheld_amount DECIMAL(18,2)  NOT NULL,
  net_amount     DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- A treaty between the two countries commonly reduces the rate, but only if
  -- the recipient supplies a residency certificate.
  treaty_applied TINYINT(1)      NOT NULL DEFAULT 0,
  treaty_country_id BIGINT UNSIGNED NULL,
  certificate_reference VARCHAR(120) NULL,
  certificate_issued_at DATE     NULL,
  tax_period     CHAR(7)         NOT NULL,
  remitted_at    DATE            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_withholding_account (account_id, tax_period),
  KEY ix_withholding_period (jurisdiction_id, tax_period, remitted_at),
  CONSTRAINT fk_withholding_payout FOREIGN KEY (payout_id) REFERENCES payouts (id) ON DELETE SET NULL,
  CONSTRAINT fk_withholding_split FOREIGN KEY (payment_split_id) REFERENCES payment_splits (id) ON DELETE SET NULL,
  CONSTRAINT fk_withholding_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_withholding_jurisdiction FOREIGN KEY (jurisdiction_id) REFERENCES tax_jurisdictions (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- GENERAL LEDGER
-- =============================================================================

-- -----------------------------------------------------------------------------
-- chart_of_accounts
--
-- 0009's `ledger_entries.ledger_account` was a free-text code, which is fine for
-- a handful of postings and untenable for a real ledger. This is the account
-- master: typed, hierarchical, with the normal balance side recorded so the
-- system can tell a legitimate credit to a revenue account from a mistake.
-- -----------------------------------------------------------------------------
CREATE TABLE chart_of_accounts (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  parent_id      INT UNSIGNED    NULL,
  account_code   VARCHAR(20)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(500)    NULL,
  account_type   ENUM('asset','liability','equity','revenue','expense','contra_asset','contra_revenue') NOT NULL,
  account_subtype ENUM('current_asset','non_current_asset','cash','receivable','prepaid','inventory','fixed_asset','current_liability','non_current_liability','payable','deferred_revenue','tax_payable','equity','retained_earnings','operating_revenue','other_revenue','cost_of_sales','operating_expense','financial_expense','tax_expense') NULL,
  -- Which side increases this account. Every posting is validated against it,
  -- which catches sign errors at write time rather than at close.
  normal_balance ENUM('debit','credit') NOT NULL,
  currency_code  CHAR(3)         NULL,
  -- Only leaf accounts may be posted to; parents exist for reporting rollups.
  is_postable    TINYINT(1)      NOT NULL DEFAULT 1,
  requires_cost_center TINYINT(1) NOT NULL DEFAULT 0,
  -- Which line of the statements this rolls into.
  statement      ENUM('balance_sheet','income_statement','cash_flow','none') NOT NULL DEFAULT 'balance_sheet',
  statement_line VARCHAR(120)    NULL,
  is_reconcilable TINYINT(1)     NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_chart_of_accounts_code (account_code),
  KEY ix_chart_of_accounts_parent (parent_id, sort_order),
  KEY ix_chart_of_accounts_type (account_type, is_active),
  KEY ix_chart_of_accounts_statement (statement, statement_line),
  CONSTRAINT fk_chart_of_accounts_parent FOREIGN KEY (parent_id) REFERENCES chart_of_accounts (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE cost_centers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  parent_id      INT UNSIGNED    NULL,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  center_type    ENUM('department','brand','region','product','project','entity') NOT NULL DEFAULT 'department',
  brand_id       INT UNSIGNED    NULL,
  country_id     BIGINT UNSIGNED NULL,
  manager_user_id BIGINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_cost_centers_code (code),
  KEY ix_cost_centers_parent (parent_id),
  CONSTRAINT fk_cost_centers_parent FOREIGN KEY (parent_id) REFERENCES cost_centers (id) ON DELETE RESTRICT,
  CONSTRAINT fk_cost_centers_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_cost_centers_manager FOREIGN KEY (manager_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- accounting_periods
--
-- Once a period is closed, no posting may be made into it. Without that, last
-- quarter's reported numbers change under your feet — which is exactly the thing
-- an audit is looking for.
-- -----------------------------------------------------------------------------
CREATE TABLE accounting_periods (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  fiscal_year    SMALLINT UNSIGNED NOT NULL,
  period_number  TINYINT UNSIGNED NOT NULL,
  period_code    CHAR(7)         NOT NULL,
  start_date     DATE            NOT NULL,
  end_date       DATE            NOT NULL,
  status         ENUM('future','open','closing','closed','locked') NOT NULL DEFAULT 'future',
  -- 'closed' can be reopened by a controller; 'locked' cannot, and is applied
  -- once the year is audited.
  closed_by_user_id BIGINT UNSIGNED NULL,
  closed_at      DATETIME(3)     NULL,
  locked_at      DATETIME(3)     NULL,
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_accounting_periods (fiscal_year, period_number),
  UNIQUE KEY uq_accounting_periods_code (period_code),
  KEY ix_accounting_periods_status (status, start_date),
  KEY ix_accounting_periods_dates (start_date, end_date),
  CONSTRAINT fk_accounting_periods_user FOREIGN KEY (closed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- journals — the posting batch
--
-- 0009's `ledger_entries` records individual postings grouped by
-- `transaction_group`. A journal is the formal document above them: it is what
-- gets approved, posted, and if necessary reversed as a whole.
-- -----------------------------------------------------------------------------
CREATE TABLE journals (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  journal_number VARCHAR(40)     NOT NULL,
  period_id      INT UNSIGNED    NOT NULL,
  journal_type   ENUM('sales','purchase','cash_receipt','cash_payment','general','adjusting','closing','reversing','accrual','recurring','fx_revaluation','opening_balance') NOT NULL DEFAULT 'general',
  description    VARCHAR(500)    NOT NULL,
  posting_date   DATE            NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- Both sides, so the balanced check is a column comparison rather than an
  -- aggregate over lines.
  total_debit    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  total_credit   DECIMAL(18,2)   NOT NULL DEFAULT 0,
  total_debit_base DECIMAL(18,2) NOT NULL DEFAULT 0,
  total_credit_base DECIMAL(18,2) NOT NULL DEFAULT 0,
  exchange_rate  DECIMAL(24,10)  NULL,
  status         ENUM('draft','pending_approval','posted','reversed','void') NOT NULL DEFAULT 'draft',
  source_type    VARCHAR(60)     NULL,
  source_id      BIGINT UNSIGNED NULL,
  -- Automatic journals come from invoices and payments; manual ones are the
  -- ones an auditor will want to look at.
  is_manual      TINYINT(1)      NOT NULL DEFAULT 0,
  is_recurring   TINYINT(1)      NOT NULL DEFAULT 0,
  reverses_journal_id BIGINT UNSIGNED NULL,
  reversed_by_journal_id BIGINT UNSIGNED NULL,
  prepared_by_user_id BIGINT UNSIGNED NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  posted_at      DATETIME(3)     NULL,
  attachment_document_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_journals_number (journal_number),
  KEY ix_journals_period (period_id, status),
  KEY ix_journals_date (posting_date, status),
  KEY ix_journals_source (source_type, source_id),
  KEY ix_journals_manual (is_manual, status, posting_date),
  CONSTRAINT fk_journals_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE RESTRICT,
  CONSTRAINT fk_journals_reverses FOREIGN KEY (reverses_journal_id) REFERENCES journals (id) ON DELETE SET NULL,
  CONSTRAINT fk_journals_reversed_by FOREIGN KEY (reversed_by_journal_id) REFERENCES journals (id) ON DELETE SET NULL,
  CONSTRAINT fk_journals_preparer FOREIGN KEY (prepared_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_journals_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_journals_document FOREIGN KEY (attachment_document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Bring 0009's ledger entries under the journal and account master.
ALTER TABLE ledger_entries
  ADD COLUMN journal_id BIGINT UNSIGNED NULL AFTER transaction_group,
  ADD COLUMN chart_account_id INT UNSIGNED NULL AFTER ledger_account,
  ADD COLUMN period_id INT UNSIGNED NULL AFTER occurred_at,
  ADD COLUMN cost_center_id INT UNSIGNED NULL AFTER chart_account_id,
  ADD COLUMN line_number SMALLINT UNSIGNED NULL AFTER journal_id,
  ADD COLUMN exchange_rate DECIMAL(24,10) NULL AFTER currency_code,
  ADD COLUMN counterparty_type VARCHAR(60) NULL AFTER source_id,
  ADD COLUMN counterparty_id BIGINT UNSIGNED NULL AFTER counterparty_type,
  -- Set when the line has been matched during bank or sub-ledger
  -- reconciliation, so open items are findable.
  ADD COLUMN is_reconciled TINYINT(1) NOT NULL DEFAULT 0 AFTER counterparty_id,
  ADD COLUMN reconciled_at DATETIME(3) NULL AFTER is_reconciled,
  ADD KEY ix_ledger_journal (journal_id, line_number),
  ADD KEY ix_ledger_chart_account (chart_account_id, occurred_at),
  ADD KEY ix_ledger_period (period_id, chart_account_id),
  ADD KEY ix_ledger_cost_center (cost_center_id, occurred_at),
  ADD KEY ix_ledger_open_items (is_reconciled, chart_account_id),
  ADD CONSTRAINT fk_ledger_journal FOREIGN KEY (journal_id) REFERENCES journals (id) ON DELETE CASCADE,
  ADD CONSTRAINT fk_ledger_chart_account FOREIGN KEY (chart_account_id) REFERENCES chart_of_accounts (id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_ledger_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE RESTRICT,
  ADD CONSTRAINT fk_ledger_cost_center FOREIGN KEY (cost_center_id) REFERENCES cost_centers (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- Revenue recognition
--
-- The difference between cash and revenue. A 12-month subscription billed in
-- January is one month of revenue and eleven months of deferred revenue — a
-- liability, not income. Under IFRS 15 and ASC 606 this is mandatory for
-- anything with a term, and it is the single most common thing a subscription
-- business gets wrong before its first audit.
-- -----------------------------------------------------------------------------
CREATE TABLE revenue_recognition_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  applies_to     ENUM('subscription','one_time','usage','setup_fee','featured_placement','lead_purchase','commission','any') NOT NULL DEFAULT 'any',
  plan_id        INT UNSIGNED    NULL,
  -- 'point_in_time' recognises immediately; 'ratable' spreads evenly over the
  -- term; 'milestone' recognises as obligations are satisfied.
  method         ENUM('point_in_time','ratable_daily','ratable_monthly','milestone','usage_based','percentage_complete') NOT NULL DEFAULT 'ratable_monthly',
  recognition_start ENUM('invoice_date','service_start','payment_date','delivery_date') NOT NULL DEFAULT 'service_start',
  deferred_account_id INT UNSIGNED NULL,
  revenue_account_id INT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_rev_rec_rules_code (code),
  KEY ix_rev_rec_rules_applies (applies_to, is_active),
  CONSTRAINT fk_rev_rec_rules_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE,
  CONSTRAINT fk_rev_rec_rules_deferred FOREIGN KEY (deferred_account_id) REFERENCES chart_of_accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_rev_rec_rules_revenue FOREIGN KEY (revenue_account_id) REFERENCES chart_of_accounts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One schedule per revenue-bearing invoice line, holding the total to be
-- recognised and how far through it is.
CREATE TABLE revenue_schedules (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  invoice_id     BIGINT UNSIGNED NULL,
  invoice_line_id BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  rule_id        INT UNSIGNED    NULL,
  total_amount   DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  total_amount_base DECIMAL(18,2) NULL,
  recognized_amount DECIMAL(18,2) NOT NULL DEFAULT 0,
  deferred_amount DECIMAL(18,2)  NOT NULL DEFAULT 0,
  service_start_date DATE        NOT NULL,
  service_end_date DATE          NOT NULL,
  method         VARCHAR(40)     NOT NULL DEFAULT 'ratable_monthly',
  status         ENUM('active','completed','cancelled','on_hold') NOT NULL DEFAULT 'active',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_rev_schedules_account (account_id, status),
  KEY ix_rev_schedules_dates (service_start_date, service_end_date),
  KEY ix_rev_schedules_invoice (invoice_id),
  KEY ix_rev_schedules_status (status, service_end_date),
  CONSTRAINT fk_rev_schedules_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE CASCADE,
  CONSTRAINT fk_rev_schedules_line FOREIGN KEY (invoice_line_id) REFERENCES invoice_lines (id) ON DELETE CASCADE,
  CONSTRAINT fk_rev_schedules_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL,
  CONSTRAINT fk_rev_schedules_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE RESTRICT,
  CONSTRAINT fk_rev_schedules_rule FOREIGN KEY (rule_id) REFERENCES revenue_recognition_rules (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The month-by-month plan, written when the schedule is created so that future
-- recognised revenue is forecastable, and marked off as each period posts.
CREATE TABLE revenue_recognition_entries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  schedule_id    BIGINT UNSIGNED NOT NULL,
  period_id      INT UNSIGNED    NULL,
  recognition_date DATE          NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  amount_base    DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL,
  status         ENUM('scheduled','recognized','reversed','skipped') NOT NULL DEFAULT 'scheduled',
  journal_id     BIGINT UNSIGNED NULL,
  recognized_at  DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_rev_entries (schedule_id, recognition_date),
  -- The month-end job: everything scheduled up to today that has not posted.
  KEY ix_rev_entries_due (status, recognition_date),
  KEY ix_rev_entries_period (period_id, status),
  CONSTRAINT fk_rev_entries_schedule FOREIGN KEY (schedule_id) REFERENCES revenue_schedules (id) ON DELETE CASCADE,
  CONSTRAINT fk_rev_entries_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE SET NULL,
  CONSTRAINT fk_rev_entries_journal FOREIGN KEY (journal_id) REFERENCES journals (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Balances, trial balance and close
-- -----------------------------------------------------------------------------
CREATE TABLE account_balances (
  chart_account_id INT UNSIGNED  NOT NULL,
  period_id      INT UNSIGNED    NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  opening_balance DECIMAL(20,2)  NOT NULL DEFAULT 0,
  period_debit   DECIMAL(20,2)   NOT NULL DEFAULT 0,
  period_credit  DECIMAL(20,2)   NOT NULL DEFAULT 0,
  closing_balance DECIMAL(20,2)  NOT NULL DEFAULT 0,
  opening_balance_base DECIMAL(20,2) NOT NULL DEFAULT 0,
  closing_balance_base DECIMAL(20,2) NOT NULL DEFAULT 0,
  cost_center_id INT UNSIGNED    NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (chart_account_id, period_id, currency_code),
  KEY ix_account_balances_period (period_id),
  KEY ix_account_balances_cost_center (cost_center_id, period_id),
  CONSTRAINT fk_account_balances_account FOREIGN KEY (chart_account_id) REFERENCES chart_of_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_account_balances_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE CASCADE,
  CONSTRAINT fk_account_balances_cost_center FOREIGN KEY (cost_center_id) REFERENCES cost_centers (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- The month-end checklist. Close is a process with owners and dependencies, and
-- treating it as one is what makes a five-day close achievable.
CREATE TABLE period_close_tasks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  period_id      INT UNSIGNED    NOT NULL,
  task_code      VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  task_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  category       ENUM('reconciliation','accrual','revenue','tax','fx','review','reporting','other') NOT NULL DEFAULT 'other',
  status         ENUM('pending','in_progress','completed','blocked','skipped','failed') NOT NULL DEFAULT 'pending',
  is_blocking    TINYINT(1)      NOT NULL DEFAULT 1,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  completed_by_user_id BIGINT UNSIGNED NULL,
  completed_at   DATETIME(3)     NULL,
  notes          VARCHAR(1000)   NULL,
  due_at         DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_period_close_tasks (period_id, task_code),
  KEY ix_period_close_status (period_id, status, task_order),
  CONSTRAINT fk_period_close_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE CASCADE,
  CONSTRAINT fk_period_close_assignee FOREIGN KEY (assigned_to_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_period_close_completer FOREIGN KEY (completed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- FX revaluation
--
-- Foreign-currency balances have to be restated at period-end rates, and the
-- difference is a real gain or loss that hits the income statement. With
-- receivables in eight currencies this is not optional.
-- -----------------------------------------------------------------------------
CREATE TABLE fx_revaluations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  period_id      INT UNSIGNED    NOT NULL,
  chart_account_id INT UNSIGNED  NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  foreign_balance DECIMAL(20,2)  NOT NULL,
  -- The rate the balance was originally booked at, and the period-end rate.
  historical_rate DECIMAL(24,10) NOT NULL,
  closing_rate   DECIMAL(24,10)  NOT NULL,
  base_balance_before DECIMAL(20,2) NOT NULL,
  base_balance_after DECIMAL(20,2) NOT NULL,
  -- Positive is a gain, negative a loss.
  revaluation_amount DECIMAL(20,2) NOT NULL,
  journal_id     BIGINT UNSIGNED NULL,
  status         ENUM('calculated','posted','reversed') NOT NULL DEFAULT 'calculated',
  calculated_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_fx_revaluations (period_id, chart_account_id, currency_code),
  KEY ix_fx_revaluations_status (status, period_id),
  CONSTRAINT fk_fx_reval_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE CASCADE,
  CONSTRAINT fk_fx_reval_account FOREIGN KEY (chart_account_id) REFERENCES chart_of_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_fx_reval_journal FOREIGN KEY (journal_id) REFERENCES journals (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Bank accounts and reconciliation
-- -----------------------------------------------------------------------------
CREATE TABLE bank_accounts (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  legal_entity   VARCHAR(200)    NULL,
  bank_name      VARCHAR(200)    NOT NULL,
  account_number_last_four CHAR(4) NULL,
  iban_encrypted VARBINARY(512)  NULL,
  swift_bic      VARCHAR(20)     NULL,
  currency_code  CHAR(3)         NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  chart_account_id INT UNSIGNED  NULL,
  account_purpose ENUM('operating','escrow','payroll','tax','reserve','merchant_settlement') NOT NULL DEFAULT 'operating',
  current_balance DECIMAL(20,2)  NOT NULL DEFAULT 0,
  last_statement_date DATE       NULL,
  -- Open banking / statement feed, so reconciliation is not a manual CSV import.
  feed_provider  VARCHAR(60)     NULL,
  feed_status    ENUM('none','connected','error','disconnected') NOT NULL DEFAULT 'none',
  last_synced_at DATETIME(3)     NULL,
  status         ENUM('active','dormant','closed') NOT NULL DEFAULT 'active',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_bank_accounts_code (code),
  KEY ix_bank_accounts_status (status, currency_code),
  CONSTRAINT fk_bank_accounts_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_accounts_chart FOREIGN KEY (chart_account_id) REFERENCES chart_of_accounts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE bank_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bank_account_id INT UNSIGNED   NOT NULL,
  transaction_date DATE          NOT NULL,
  value_date     DATE            NULL,
  description    VARCHAR(500)    NOT NULL,
  reference      VARCHAR(191)    NULL,
  counterparty   VARCHAR(255)    NULL,
  -- Signed: positive is money in.
  amount         DECIMAL(20,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  balance_after  DECIMAL(20,2)   NULL,
  transaction_type ENUM('credit','debit','fee','interest','transfer','fx','reversal','unknown') NOT NULL DEFAULT 'unknown',
  -- The bank's own unique id for the line, which is what makes repeated
  -- statement imports idempotent.
  bank_reference VARCHAR(191)    NULL,
  -- Reconciliation state against our ledger.
  match_status   ENUM('unmatched','matched','partial','ignored','manual') NOT NULL DEFAULT 'unmatched',
  matched_journal_id BIGINT UNSIGNED NULL,
  matched_payment_id BIGINT UNSIGNED NULL,
  matched_payout_id BIGINT UNSIGNED NULL,
  matched_settlement_id BIGINT UNSIGNED NULL,
  matched_by_user_id BIGINT UNSIGNED NULL,
  matched_at     DATETIME(3)     NULL,
  imported_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_bank_transactions (bank_account_id, bank_reference),
  KEY ix_bank_transactions_date (bank_account_id, transaction_date),
  KEY ix_bank_transactions_unmatched (match_status, transaction_date),
  KEY ix_bank_transactions_amount (amount, transaction_date),
  CONSTRAINT fk_bank_tx_account FOREIGN KEY (bank_account_id) REFERENCES bank_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_bank_tx_journal FOREIGN KEY (matched_journal_id) REFERENCES journals (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_tx_payment FOREIGN KEY (matched_payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_tx_payout FOREIGN KEY (matched_payout_id) REFERENCES payouts (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_tx_settlement FOREIGN KEY (matched_settlement_id) REFERENCES settlements (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_tx_user FOREIGN KEY (matched_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE bank_reconciliations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  bank_account_id INT UNSIGNED   NOT NULL,
  period_id      INT UNSIGNED    NULL,
  statement_date DATE            NOT NULL,
  statement_balance DECIMAL(20,2) NOT NULL,
  ledger_balance DECIMAL(20,2)   NOT NULL,
  -- Timing differences: cheques written but not presented, deposits in transit.
  outstanding_deposits DECIMAL(20,2) NOT NULL DEFAULT 0,
  outstanding_payments DECIMAL(20,2) NOT NULL DEFAULT 0,
  adjusted_balance DECIMAL(20,2) NOT NULL DEFAULT 0,
  -- Must be zero before the reconciliation can be marked complete.
  variance       DECIMAL(20,2)   NOT NULL DEFAULT 0,
  matched_count  INT UNSIGNED    NOT NULL DEFAULT 0,
  unmatched_count INT UNSIGNED   NOT NULL DEFAULT 0,
  status         ENUM('in_progress','balanced','variance','completed','reopened') NOT NULL DEFAULT 'in_progress',
  reconciled_by_user_id BIGINT UNSIGNED NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  completed_at   DATETIME(3)     NULL,
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_bank_reconciliations (bank_account_id, statement_date),
  KEY ix_bank_recon_status (status, statement_date),
  CONSTRAINT fk_bank_recon_account FOREIGN KEY (bank_account_id) REFERENCES bank_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_bank_recon_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_recon_user FOREIGN KEY (reconciled_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_bank_recon_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Budgets
-- -----------------------------------------------------------------------------
CREATE TABLE budgets (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(200)    NOT NULL,
  fiscal_year    SMALLINT UNSIGNED NOT NULL,
  budget_type    ENUM('operating','capital','revenue','headcount','marketing') NOT NULL DEFAULT 'operating',
  cost_center_id INT UNSIGNED    NULL,
  currency_code  CHAR(3)         NOT NULL,
  -- A budget is agreed once and then compared against; a forecast is revised.
  budget_version ENUM('original','revised','forecast') NOT NULL DEFAULT 'original',
  version_number TINYINT UNSIGNED NOT NULL DEFAULT 1,
  status         ENUM('draft','submitted','approved','active','closed') NOT NULL DEFAULT 'draft',
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_budgets (fiscal_year, budget_type, cost_center_id, budget_version, version_number),
  KEY ix_budgets_status (status, fiscal_year),
  CONSTRAINT fk_budgets_cost_center FOREIGN KEY (cost_center_id) REFERENCES cost_centers (id) ON DELETE SET NULL,
  CONSTRAINT fk_budgets_approver FOREIGN KEY (approved_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE budget_lines (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  budget_id      INT UNSIGNED    NOT NULL,
  chart_account_id INT UNSIGNED  NOT NULL,
  period_id      INT UNSIGNED    NULL,
  period_number  TINYINT UNSIGNED NULL,
  budgeted_amount DECIMAL(20,2)  NOT NULL DEFAULT 0,
  -- Maintained from the ledger, so variance is a column subtraction rather than
  -- a report-time aggregate.
  actual_amount  DECIMAL(20,2)   NOT NULL DEFAULT 0,
  variance_amount DECIMAL(20,2)  NOT NULL DEFAULT 0,
  variance_percentage DECIMAL(8,2) NULL,
  notes          VARCHAR(500)    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_budget_lines (budget_id, chart_account_id, period_number),
  KEY ix_budget_lines_account (chart_account_id, period_id),
  CONSTRAINT fk_budget_lines_budget FOREIGN KEY (budget_id) REFERENCES budgets (id) ON DELETE CASCADE,
  CONSTRAINT fk_budget_lines_account FOREIGN KEY (chart_account_id) REFERENCES chart_of_accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_budget_lines_period FOREIGN KEY (period_id) REFERENCES accounting_periods (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0019', 'tax_and_accounting');
