-- =============================================================================
-- 074_finance_extensions.sql
--
-- The remainder of the finance stack: credit notes, mandates, payment links,
-- split payments, instalment plans, bank feeds and reconciliation, escrow,
-- dunning, metered billing, quotes and purchase orders, budgets and cost
-- centres, the period-close checklist, FX revaluation, tax filings and
-- exemptions, withholding, and the daily revenue and price-index rollups.
--
-- The organising principle is that money leaves an audit trail on the way in and
-- on the way out. A payment that arrives is split before it is paid on, a
-- payout that leaves may have tax withheld from it, a bank line either matches
-- something or becomes an exception somebody owns, and the month does not close
-- until a named person has ticked every task that says it must.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- Credit notes
--
-- A credit note, never an edited invoice. An issued invoice is a legal document
-- and the correction is a second document that references it; editing the first
-- one is how an accounting system loses an audit.
-- -----------------------------------------------------------------------------
INSERT INTO credit_notes
  (public_id, credit_note_number, invoice_id, account_id, amount, currency_code,
   amount_base, reason, status, issued_at, created_by_user_id, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('creditnote:', i.id)), 26)),
  CONCAT('CN-', DATE_FORMAT(i.issued_at, '%Y%m'), '-', LPAD(i.id, 6, '0')),
  i.id, i.account_id,
  ROUND(i.total * c.share, 2), i.currency_code,
  ROUND(COALESCE(i.total_base, i.total) * c.share, 2),
  c.reason, c.status,
  DATE_ADD(i.issued_at, INTERVAL 9 DAY),
  1, DATE_ADD(i.issued_at, INTERVAL 9 DAY)
FROM invoices i
JOIN (
  SELECT i2.id AS invoice_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('cnreason:', i2.id)), 1, 4), 16, 10), 6),
             'Duplicate promotion charged twice in the same billing run.',
             'Listing quota billed at the previous plan rate after a mid-cycle downgrade.',
             'Service credit agreed after a search outage affected the agency''s listings for two days.',
             'Featured slot was not delivered because the listing was withdrawn before the placement ran.',
             'Tax applied at the domestic rate on a supply that qualified for the reverse charge.',
             'Goodwill credit agreed by the account manager to retain the account at renewal.') AS reason,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('cnstat:', i2.id)), 1, 4), 16, 10), 8),
             'applied','applied','applied','applied','applied','issued','issued','void') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('cnshare:', i2.id)), 1, 4), 16, 10), 4),
             1.00, 0.50, 0.25, 0.10) AS share
  FROM invoices i2
) AS c ON c.invoice_id = i.id
WHERE i.status IN ('issued', 'paid')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hascn:', i.id)), 1, 4), 16, 10), 9) = 0;

-- -----------------------------------------------------------------------------
-- Mandates
--
-- The signature evidence is the column that matters. A direct debit taken
-- without a demonstrable mandate is reversed on demand and the burden of proof
-- sits with the collector.
-- -----------------------------------------------------------------------------
INSERT INTO payment_mandates
  (public_id, account_id, payment_method_id, gateway_account_id, mandate_type,
   mandate_reference, provider_mandate_id, scheme, status, signed_at,
   signature_ip, signature_evidence, is_recurring, first_collection_at,
   last_collection_at, cancelled_at, cancellation_reason, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('mandate:', pm.id)), 26)),
  pm.account_id, pm.id, ga.id, m.mandate_type,
  CONCAT('MND-', UPPER(LEFT(MD5(CONCAT('mref:', pm.id)), 12))),
  LEFT(MD5(CONCAT('provmandate:', pm.id)), 24),
  m.scheme, m.status,
  DATE_SUB(@now, INTERVAL m.age_days DAY),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('mip:', pm.id)), 1, 8), 16, 10)), 8, '0')),
  CONCAT('Online mandate accepted at ',
         DATE_FORMAT(DATE_SUB(@now, INTERVAL m.age_days DAY), '%Y-%m-%d %H:%i'),
         ' UTC. Tick-box wording version 3.1, confirmation email sent to the account address.'),
  1,
  DATE(DATE_SUB(@now, INTERVAL m.age_days - 5 DAY)),
  DATE(DATE_SUB(@now, INTERVAL MOD(pm.id, 40) DAY)),
  CASE WHEN m.status = 'cancelled' THEN DATE_SUB(@now, INTERVAL 20 DAY) END,
  CASE WHEN m.status = 'cancelled'
       THEN 'Cancelled by the payer at their bank. A replacement mandate was requested.' END,
  DATE_SUB(@now, INTERVAL m.age_days DAY), @now
FROM payment_methods pm
JOIN gateway_accounts ga
  ON ga.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mga:', pm.id)), 1, 4), 16, 10),
                     (SELECT COUNT(*) FROM gateway_accounts))
JOIN (
  SELECT pm2.id AS method_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mtype:', pm2.id)), 1, 4), 16, 10), 5),
             'sepa_direct_debit','uae_direct_debit','card_on_file','bacs','ach') AS mandate_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mtype:', pm2.id)), 1, 4), 16, 10), 5),
             'CORE','UAEDDS','VISA-SCI','BACS','NACHA') AS scheme,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mstat:', pm2.id)), 1, 4), 16, 10), 10),
             'active','active','active','active','active','active','active',
             'pending','cancelled','failed') AS status,
         30 + MOD(CONV(SUBSTRING(MD5(CONCAT('mage:', pm2.id)), 1, 4), 16, 10), 700) AS age_days
  FROM payment_methods pm2
) AS m ON m.method_id = pm.id;

-- -----------------------------------------------------------------------------
-- Payment links
--
-- How an agent takes a reservation deposit from a buyer in another country
-- without either of them touching an invoice.
-- -----------------------------------------------------------------------------
INSERT INTO payment_links
  (public_id, token, account_id, created_by_user_id, title, description, amount,
   currency_code, allow_custom_amount, minimum_amount, listing_id, max_uses,
   use_count, collect_billing_address, collect_phone, status, expires_at,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('paylink:', l.id)), 26)),
  LOWER(MD5(CONCAT('paylinktoken:', l.id))),
  l.account_id, l.created_by_user_id,
  CONCAT('Reservation deposit — ', LEFT(l.title, 140)),
  'Refundable reservation deposit. Holds the unit for ten working days while the sale and purchase agreement is prepared.',
  ROUND(GREATEST(1000, l.price * 0.02), 2),
  l.currency_code,
  0, NULL, l.id, 1,
  CASE WHEN s.status = 'paid' THEN 1 ELSE 0 END,
  1, 1, s.status,
  DATE_ADD(l.created_at, INTERVAL 30 DAY),
  l.created_at, @now
FROM listings l
JOIN (
  SELECT l2.id AS listing_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('plstat:', l2.id)), 1, 4), 16, 10), 6),
             'paid','paid','active','active','expired','cancelled') AS status
  FROM listings l2
) AS s ON s.listing_id = l.id
WHERE l.account_id IS NOT NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('haspl:', l.id)), 1, 4), 16, 10), 7) = 0;

-- -----------------------------------------------------------------------------
-- Payment splits
--
-- One inbound payment, several beneficiaries. Held as rows so a payout run can
-- pick up exactly what is releasable, and so the platform's own share is a
-- line rather than an inference from the difference.
-- -----------------------------------------------------------------------------
INSERT INTO payment_splits
  (payment_id, beneficiary_type, beneficiary_account_id, organization_id,
   split_type, percentage, amount, currency_code, amount_base, description,
   status, hold_reason, release_after, released_at, created_at, updated_at)
SELECT
  p.id, s.beneficiary_type,
  CASE WHEN s.beneficiary_type = 'organization' THEN p.account_id END,
  CASE WHEN s.beneficiary_type = 'organization' THEN o.id END,
  s.split_type, s.percentage,
  ROUND(p.amount * s.percentage / 100, 2),
  p.currency_code,
  ROUND(COALESCE(p.amount_base, p.amount) * s.percentage / 100, 2),
  s.description,
  CASE
    WHEN s.beneficiary_type = 'platform' THEN 'paid'
    WHEN p.created_at > DATE_SUB(@now, INTERVAL 7 DAY) THEN 'held'
    ELSE 'released'
  END,
  CASE WHEN p.created_at > DATE_SUB(@now, INTERVAL 7 DAY)
       THEN 'Held for the seven-day chargeback window before release to the beneficiary.' END,
  DATE_ADD(p.created_at, INTERVAL 7 DAY),
  CASE WHEN p.created_at <= DATE_SUB(@now, INTERVAL 7 DAY)
       THEN DATE_ADD(p.created_at, INTERVAL 7 DAY) END,
  p.created_at, @now
FROM payments p
JOIN organizations o
  ON o.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('splitorg:', p.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM organizations))
JOIN (
  SELECT 'platform' AS beneficiary_type, 'percentage' AS split_type, 15.0000 AS percentage,
         'Platform commission on the transaction.' AS description
  UNION ALL SELECT 'organization', 'percentage', 80.0000, 'Agency share, released after the chargeback window.'
  UNION ALL SELECT 'tax_authority', 'percentage', 5.0000, 'Value added tax collected on the platform commission and remitted separately.'
) AS s
WHERE p.status = 'succeeded'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hassplit:', p.id)), 1, 4), 16, 10), 4) = 0;

-- -----------------------------------------------------------------------------
-- Instalment plans
--
-- An annual subscription paid in four. The schedule carries principal and
-- interest separately because a plan that charges for the privilege is a credit
-- product and has to be reported as one.
-- -----------------------------------------------------------------------------
INSERT INTO installment_plans
  (public_id, account_id, invoice_id, total_amount, currency_code,
   installment_count, frequency, interest_rate, down_payment, amount_paid,
   status, payment_method_id, started_at, completed_at, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('instplan:', i.id)), 26)),
  i.account_id, i.id, i.total, i.currency_code,
  p.installment_count, p.frequency, p.interest_rate,
  ROUND(i.total * 0.25, 2),
  0.00,
  p.status,
  pm.id,
  DATE(i.issued_at),
  CASE WHEN p.status = 'completed'
       THEN DATE_ADD(DATE(i.issued_at), INTERVAL p.installment_count MONTH) END,
  i.issued_at
FROM invoices i
JOIN (
  SELECT i2.id AS invoice_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('instcount:', i2.id)), 1, 4), 16, 10), 3), 3, 4, 6) AS installment_count,
         'monthly' AS frequency,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('instrate:', i2.id)), 1, 4), 16, 10), 3), 0.000, 3.500, 5.900) AS interest_rate,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('inststat:', i2.id)), 1, 4), 16, 10), 8),
             'completed','completed','completed','completed','active','active','defaulted','cancelled') AS status
  FROM invoices i2
) AS p ON p.invoice_id = i.id
LEFT JOIN payment_methods pm ON pm.account_id = i.account_id
  AND pm.id = (SELECT MIN(pm2.id) FROM payment_methods pm2 WHERE pm2.account_id = i.account_id)
WHERE i.status IN ('issued', 'paid') AND i.total > 500
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasinst:', i.id)), 1, 4), 16, 10), 11) = 0;

INSERT INTO installment_schedules
  (installment_plan_id, installment_number, due_date, amount, principal_amount,
   interest_amount, status, paid_at, attempts)
SELECT
  pl.id, n.n + 1,
  DATE_ADD(pl.started_at, INTERVAL n.n MONTH),
  ROUND((pl.total_amount - pl.down_payment) / pl.installment_count
        * (1 + pl.interest_rate / 100), 2),
  ROUND((pl.total_amount - pl.down_payment) / pl.installment_count, 2),
  ROUND((pl.total_amount - pl.down_payment) / pl.installment_count * pl.interest_rate / 100, 2),
  CASE
    WHEN pl.status = 'cancelled' AND DATE_ADD(pl.started_at, INTERVAL n.n MONTH) > @today THEN 'waived'
    WHEN pl.status = 'defaulted' AND n.n >= 2 THEN 'overdue'
    WHEN DATE_ADD(pl.started_at, INTERVAL n.n MONTH) > @today THEN 'scheduled'
    ELSE 'paid'
  END,
  CASE WHEN DATE_ADD(pl.started_at, INTERVAL n.n MONTH) <= @today
            AND NOT (pl.status = 'defaulted' AND n.n >= 2)
            AND pl.status <> 'cancelled'
       THEN TIMESTAMP(DATE_ADD(pl.started_at, INTERVAL n.n MONTH), '02:15:00') END,
  CASE WHEN pl.status = 'defaulted' AND n.n >= 2 THEN 3 ELSE 1 END
FROM installment_plans pl
JOIN tmp_n n ON n.n < pl.installment_count;

UPDATE installment_plans pl
JOIN (
  SELECT installment_plan_id, ROUND(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 2) AS paid
  FROM installment_schedules GROUP BY installment_plan_id
) s ON s.installment_plan_id = pl.id
SET pl.amount_paid = s.paid + pl.down_payment;

-- -----------------------------------------------------------------------------
-- Bank accounts, feeds and reconciliation
--
-- The bank line is the outside world's version of events. Reconciliation is the
-- process of making the ledger agree with it, and every line that will not
-- match becomes an exception with a person's name on it rather than a rounding
-- difference nobody investigates.
-- -----------------------------------------------------------------------------
INSERT INTO bank_accounts
  (code, name, legal_entity, bank_name, account_number_last_four,
   iban_encrypted, swift_bic, currency_code, country_id, chart_account_id,
   account_purpose, current_balance, last_statement_date, feed_provider,
   feed_status, last_synced_at, status, created_at)
SELECT
  b.code, b.name, b.legal_entity, b.bank_name, b.last_four,
  UNHEX(SHA2(CONCAT('iban:', b.code), 256)),
  b.swift, b.currency_code, c.id, ca.id, b.account_purpose,
  b.balance, DATE_SUB(@today, INTERVAL 1 DAY), b.feed_provider, b.feed_status,
  DATE_SUB(@now, INTERVAL b.sync_hours_ago HOUR), 'active',
  DATE_SUB(@now, INTERVAL 900 DAY)
FROM (
  SELECT 'enbd-aed-operating' AS code, 'Operating — AED' AS name, 'Liv Finder Holdings Ltd' AS legal_entity, 'Emirates NBD' AS bank_name, '4821' AS last_four, 'EBILAEAD' AS swift, 'AED' AS currency_code, 'United Arab Emirates' AS country_name, '1110' AS account_code, 'operating' AS account_purpose, 4820441.20 AS balance, 'yapily' AS feed_provider, 'connected' AS feed_status, 2 AS sync_hours_ago
  UNION ALL SELECT 'revolut-eur-operating','Operating — EUR','Liv Finder Europe SARL','Revolut Business','7719','REVOGB21','EUR','France','1120','operating',1911204.55,'truelayer','connected',3
  UNION ALL SELECT 'barclays-gbp-operating','Operating — GBP','Liv Finder Europe SARL','Barclays','3054','BUKBGB22','GBP','United Kingdom','1130','operating',884210.09,'truelayer','connected',4
  UNION ALL SELECT 'svb-usd-operating','Operating — USD','Liv Finder Americas Inc','First Citizens','9188','FCBTUS6S','USD','United States','1140','operating',3122980.71,'plaid','connected',2
  UNION ALL SELECT 'enbd-aed-escrow','Client escrow — AED','Liv Finder Holdings Ltd','Emirates NBD','5560','EBILAEAD','AED','United Arab Emirates','1110','escrow',10402118.00,'yapily','connected',2
  UNION ALL SELECT 'enbd-aed-tax','VAT reserve — AED','Liv Finder Holdings Ltd','Emirates NBD','6203','EBILAEAD','AED','United Arab Emirates','1110','tax',712880.44,'yapily','connected',6
  UNION ALL SELECT 'stripe-settlement-usd','Merchant settlement — USD','Liv Finder Holdings Ltd','Stripe Payments','0000','','USD','United States','1140','merchant_settlement',288104.33,'stripe','connected',1
  UNION ALL SELECT 'hsbc-usd-reserve','Reserve — USD','Liv Finder Holdings Ltd','HSBC','2277','HBUKGB4B','USD','United Kingdom','1140','reserve',5000000.00,'none','disconnected',900
) AS b
LEFT JOIN locations c ON c.level = 'country' AND c.name = b.country_name
LEFT JOIN chart_of_accounts ca ON ca.account_code = b.account_code;

INSERT INTO bank_transactions
  (bank_account_id, transaction_date, value_date, description, reference,
   counterparty, amount, currency_code, balance_after, transaction_type,
   bank_reference, match_status, matched_payment_id, matched_settlement_id,
   matched_by_user_id, matched_at, imported_at)
SELECT
  ba.id,
  s.settlement_date, s.settlement_date,
  CONCAT('SETTLEMENT ', COALESCE(s.provider_settlement_id, s.public_id)),
  COALESCE(s.bank_reference, s.public_id), 'Stripe Payments Europe Ltd',
  s.net_amount, s.currency_code,
  NULL, 'credit',
  CONCAT('BR', UPPER(LEFT(MD5(CONCAT('bankref:', s.id)), 14))),
  'matched', NULL, s.id, NULL,
  TIMESTAMP(DATE_ADD(s.settlement_date, INTERVAL 1 DAY), '09:00:00'),
  TIMESTAMP(s.settlement_date, '06:00:00')
FROM settlements s
JOIN bank_accounts ba ON ba.code = 'stripe-settlement-usd'
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('banksettle:', s.id)), 1, 4), 16, 10), 3) = 0;

-- The operating-account traffic: fees, payroll, transfers and the handful of
-- lines nobody can immediately place.
INSERT INTO bank_transactions
  (bank_account_id, transaction_date, value_date, description, reference,
   counterparty, amount, currency_code, transaction_type, bank_reference,
   match_status, matched_at, imported_at)
SELECT
  ba.id,
  DATE_SUB(@today, INTERVAL d.n DAY),
  DATE_SUB(@today, INTERVAL d.n DAY),
  t.description, CONCAT('REF', LPAD(d.n, 4, '0'), t.suffix), t.counterparty,
  ROUND(t.sign * (t.base + MOD(CONV(SUBSTRING(MD5(CONCAT('bt:', ba.id, d.n, t.suffix)), 1, 5), 16, 10), t.spread)), 2),
  ba.currency_code, t.transaction_type,
  CONCAT('BR', UPPER(LEFT(MD5(CONCAT('bref:', ba.id, d.n, t.suffix)), 14))),
  t.match_status,
  CASE WHEN t.match_status = 'matched' THEN DATE_SUB(@now, INTERVAL d.n DAY) END,
  DATE_SUB(@now, INTERVAL d.n DAY)
FROM bank_accounts ba
JOIN (SELECT n FROM tmp_n WHERE n < 30) AS d
JOIN (
  SELECT 'CARD ACQUIRING FEES' AS description, '-F' AS suffix, 'Stripe Payments' AS counterparty, -1 AS sign, 800 AS base, 2200 AS spread, 'fee' AS transaction_type, 'matched' AS match_status, 3 AS every
  UNION ALL SELECT 'PAYROLL',           '-P', 'Payroll Bureau',        -1, 40000, 22000, 'debit',    'matched',   30
  UNION ALL SELECT 'CLOUD HOSTING',     '-H', 'Cloud Provider',        -1,  9000,  6000, 'debit',    'matched',   7
  UNION ALL SELECT 'INTERNAL TRANSFER', '-T', 'Own account',           -1, 50000, 90000, 'transfer', 'matched',   10
  UNION ALL SELECT 'CUSTOMER PAYMENT',  '-C', 'Various',                1,  1200, 28000, 'credit',   'matched',   2
  UNION ALL SELECT 'FX CONVERSION',     '-X', 'Treasury',              -1,   200,  1800, 'fx',       'matched',   9
  UNION ALL SELECT 'UNIDENTIFIED CREDIT','-U','Unknown remitter',       1,   400,  9000, 'credit',   'unmatched', 11
  UNION ALL SELECT 'BANK CHARGES',      '-B', 'Bank',                  -1,    20,   180, 'fee',      'unmatched', 13
) AS t ON MOD(d.n, t.every) = 0
WHERE ba.account_purpose IN ('operating', 'merchant_settlement');

-- The running balance is a consequence of the lines, computed once they are all
-- in rather than asserted line by line.
UPDATE bank_transactions bt
JOIN (
  SELECT b.id AS txn_id,
         (SELECT ba.current_balance FROM bank_accounts ba WHERE ba.id = b.bank_account_id)
         - COALESCE((SELECT SUM(b2.amount) FROM bank_transactions b2
                      WHERE b2.bank_account_id = b.bank_account_id AND b2.id > b.id), 0) AS running
  FROM bank_transactions b
) r ON r.txn_id = bt.id
SET bt.balance_after = ROUND(r.running, 2);

INSERT INTO bank_reconciliations
  (bank_account_id, period_id, statement_date, statement_balance, ledger_balance,
   outstanding_deposits, outstanding_payments, adjusted_balance, variance,
   matched_count, unmatched_count, status, reconciled_by_user_id,
   reviewed_by_user_id, completed_at, notes, created_at)
SELECT
  ba.id, p.id, p.end_date,
  ROUND(ba.current_balance, 2),
  ROUND(ba.current_balance - v.variance, 2),
  ROUND(v.deposits, 2), ROUND(v.payments, 2),
  ROUND(ba.current_balance - v.variance + v.deposits - v.payments, 2),
  ROUND(v.variance, 2),
  v.matched, v.unmatched,
  CASE WHEN ABS(v.variance) < 0.01 THEN 'completed' ELSE 'variance' END,
  1, 2,
  CASE WHEN ABS(v.variance) < 0.01 THEN TIMESTAMP(p.end_date, '17:30:00') END,
  CASE WHEN ABS(v.variance) >= 0.01
       THEN 'Variance traced to two unidentified credits awaiting remitter confirmation. Carried forward and tracked as reconciliation exceptions.' END,
  TIMESTAMP(p.end_date, '09:00:00')
FROM bank_accounts ba
JOIN accounting_periods p ON p.status IN ('closed', 'locked')
JOIN (
  SELECT ba2.id AS bank_account_id, p2.id AS period_id,
         MOD(CONV(SUBSTRING(MD5(CONCAT('recmatch:', ba2.id, p2.id)), 1, 4), 16, 10), 300) AS matched,
         MOD(CONV(SUBSTRING(MD5(CONCAT('recunmatch:', ba2.id, p2.id)), 1, 4), 16, 10), 6) AS unmatched,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('recvar:', ba2.id, p2.id)), 1, 4), 16, 10), 7) = 0
              THEN MOD(CONV(SUBSTRING(MD5(CONCAT('recamt:', ba2.id, p2.id)), 1, 4), 16, 10), 4000) / 100
              ELSE 0 END AS variance,
         MOD(CONV(SUBSTRING(MD5(CONCAT('recdep:', ba2.id, p2.id)), 1, 5), 16, 10), 90000) AS deposits,
         MOD(CONV(SUBSTRING(MD5(CONCAT('recpay:', ba2.id, p2.id)), 1, 5), 16, 10), 60000) AS payments
  FROM bank_accounts ba2 CROSS JOIN accounting_periods p2
) AS v ON v.bank_account_id = ba.id AND v.period_id = p.id
WHERE ba.feed_status = 'connected';

INSERT INTO reconciliation_exceptions
  (settlement_id, payment_id, exception_type, expected_amount, actual_amount,
   variance, currency_code, details, severity, status, resolution,
   assigned_to_user_id, resolved_by_user_id, resolved_at, created_at)
SELECT
  s.id, NULL, e.exception_type,
  ROUND(s.gross_amount, 2),
  ROUND(s.gross_amount + e.delta, 2),
  ROUND(e.delta, 2),
  s.currency_code, e.details, e.severity, e.status,
  CASE WHEN e.status IN ('resolved', 'written_off') THEN e.resolution END,
  1 + MOD(s.id, 4),
  CASE WHEN e.status IN ('resolved', 'written_off') THEN 1 + MOD(s.id, 4) END,
  CASE WHEN e.status IN ('resolved', 'written_off')
       THEN TIMESTAMP(DATE_ADD(s.settlement_date, INTERVAL 6 DAY), '11:00:00') END,
  TIMESTAMP(DATE_ADD(s.settlement_date, INTERVAL 1 DAY), '08:30:00')
FROM settlements s
JOIN (
  SELECT s2.id AS settlement_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('exctype:', s2.id)), 1, 4), 16, 10), 6),
             'amount_mismatch','unexpected_fee','missing_in_ledger','date_mismatch',
             'orphan_refund','duplicate_match') AS exception_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('exctype:', s2.id)), 1, 4), 16, 10), 6),
             'Settlement net is short by an amount matching one refund that had not yet reached the ledger when the batch closed.',
             'An interchange adjustment appeared on the settlement that no fee schedule accounts for. Raised with the acquirer.',
             'A payment present in the settlement has no corresponding ledger entry. Likely a webhook that was never processed.',
             'The settlement date falls one day after the ledger date, which straddles the period boundary.',
             'A refund settled against a payment the platform has no record of taking.',
             'Two ledger entries matched the same settlement line; one is a duplicate created during the webhook replay.') AS details,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('excsev:', s2.id)), 1, 4), 16, 10), 4),
             'low','medium','high','critical') AS severity,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('excstat:', s2.id)), 1, 4), 16, 10), 6),
             'resolved','resolved','resolved','written_off','investigating','open') AS status,
         'Traced, corrected in the ledger and the matching rule adjusted so the same shape reconciles automatically next time.' AS resolution,
         (MOD(CONV(SUBSTRING(MD5(CONCAT('excdelta:', s2.id)), 1, 4), 16, 10), 12000) - 6000) / 100 AS delta
  FROM settlements s2
) AS e ON e.settlement_id = s.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasexc:', s.id)), 1, 4), 16, 10), 12) = 0;

-- -----------------------------------------------------------------------------
-- Escrow
--
-- Off-plan money is not the developer's and is not the platform's. The regulator
-- reference on the account is the point: an escrow account without a named
-- regulator is a bank account with an optimistic label.
-- -----------------------------------------------------------------------------
INSERT INTO escrow_accounts
  (public_id, organization_id, project_id, name, escrow_type, regulator,
   regulator_reference, bank_name, account_number_last_four, iban_encrypted,
   currency_code, balance, held_balance, available_balance, status, opened_at,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('escrow:', p.id)), 26)),
  p.organization_id, p.id,
  CONCAT(p.name, ' — project escrow'),
  'project_escrow',
  'Dubai Land Department — Real Estate Regulatory Agency',
  CONCAT('ESC-', LPAD(p.id, 5, '0'), '-', YEAR(COALESCE(p.launch_date, @today))),
  'Emirates NBD',
  LPAD(MOD(CONV(SUBSTRING(MD5(CONCAT('escacc:', p.id)), 1, 4), 16, 10), 10000), 4, '0'),
  UNHEX(SHA2(CONCAT('escrowiban:', p.id), 256)),
  COALESCE(p.currency_code, 'AED'),
  ROUND(b.balance, 2),
  ROUND(b.balance * 0.72, 2),
  ROUND(b.balance * 0.28, 2),
  CASE WHEN p.status = 'completed' THEN 'closing' ELSE 'active' END,
  DATE(COALESCE(p.launch_date, DATE_SUB(@today, INTERVAL 600 DAY))),
  @now, @now
FROM projects p
JOIN (
  SELECT p2.id AS project_id,
         2000000 + MOD(CONV(SUBSTRING(MD5(CONCAT('escbal:', p2.id)), 1, 6), 16, 10), 180000000) AS balance
  FROM projects p2
) AS b ON b.project_id = p.id;

INSERT INTO escrow_transactions
  (escrow_account_id, transaction_type, amount, currency_code, balance_after,
   counterparty_name, reference, description, status, requested_by_user_id,
   approved_by_user_id, approved_at, occurred_at, created_at)
SELECT
  ea.id, t.transaction_type,
  ROUND(t.amount, 2), ea.currency_code,
  ROUND(t.running, 2),
  t.counterparty,
  CONCAT('ESCTX-', UPPER(LEFT(MD5(CONCAT('esctx:', ea.id, ':', t.seq)), 10))),
  t.description,
  CASE WHEN t.seq = 0 THEN 'completed'
       WHEN t.transaction_type = 'release' AND t.seq >= 8 THEN 'awaiting_approval'
       ELSE 'completed' END,
  1,
  CASE WHEN NOT (t.transaction_type = 'release' AND t.seq >= 8) THEN 2 END,
  CASE WHEN NOT (t.transaction_type = 'release' AND t.seq >= 8)
       THEN DATE_SUB(@now, INTERVAL (10 - t.seq) * 30 DAY) END,
  DATE_SUB(@now, INTERVAL (10 - t.seq) * 30 DAY),
  DATE_SUB(@now, INTERVAL (10 - t.seq) * 30 DAY)
FROM escrow_accounts ea
JOIN (
  SELECT ea2.id AS escrow_account_id, n.n AS seq,
         CASE WHEN MOD(n.n, 3) = 2 THEN 'release' ELSE 'deposit' END AS transaction_type,
         CASE WHEN MOD(n.n, 3) = 2
              THEN -1 * (ea2.balance * 0.06)
              ELSE ea2.balance * 0.11 END AS amount,
         ea2.balance * (n.n + 1) / 10 AS running,
         CASE WHEN MOD(n.n, 3) = 2 THEN 'Developer — construction drawdown'
              ELSE 'Purchaser instalment' END AS counterparty,
         CASE WHEN MOD(n.n, 3) = 2
              THEN 'Drawdown released against an engineer-certified construction milestone.'
              ELSE 'Purchaser instalment received under the registered sale and purchase agreement.' END AS description
  FROM escrow_accounts ea2 CROSS JOIN (SELECT n FROM tmp_n WHERE n < 10) n
) AS t ON t.escrow_account_id = ea.id;


-- -----------------------------------------------------------------------------
-- Dunning
--
-- A failed card is a churn event that has not happened yet. The campaign is a
-- sequence of attempts and messages with a defined end, and the end has to be
-- an action -- suspending, downgrading or writing off -- because a dunning
-- process with no terminus never actually recovers or releases anything.
-- -----------------------------------------------------------------------------
INSERT INTO dunning_campaigns
  (code, name, trigger_reason, applies_to_plan_id, max_attempts, final_action,
   grace_period_days, is_active, created_at)
SELECT
  c.code, c.name, c.trigger_reason, NULL, c.max_attempts, c.final_action,
  c.grace_period_days, 1, @now
FROM (
  SELECT 'card_failed_standard' AS code, 'Card failed — standard recovery' AS name,
         'payment_failed' AS trigger_reason, 4 AS max_attempts,
         'downgrade_to_free' AS final_action, 21 AS grace_period_days
  UNION ALL SELECT 'card_expiring','Card expiring — pre-emptive update request','card_expiring',0,'none',30
  UNION ALL SELECT 'card_expired','Card expired','card_expired',3,'suspend_account',14
  UNION ALL SELECT 'insufficient_funds','Insufficient funds — smart retry','insufficient_funds',5,'downgrade_to_free',28
  UNION ALL SELECT 'invoice_overdue_enterprise','Enterprise invoice overdue','invoice_overdue',2,'unpublish_listings',45
  UNION ALL SELECT 'mandate_failed','Direct debit mandate failed','mandate_failed',3,'suspend_account',21
  UNION ALL SELECT 'past_due_final','Subscription past due — final notice','subscription_past_due',1,'cancel_subscription',7
) AS c;

INSERT INTO dunning_steps
  (campaign_id, step_number, delay_days, delay_hours, action,
   notification_template_id, retry_strategy)
SELECT
  c.id, s.step_number, s.delay_days, s.delay_hours, s.action, nt.id, s.retry_strategy
FROM dunning_campaigns c
JOIN (
  SELECT 'card_failed_standard' AS code, 1 AS step_number, 0 AS delay_days, 0 AS delay_hours, 'send_email' AS action, 'same_method' AS retry_strategy
  UNION ALL SELECT 'card_failed_standard', 2, 1,  0, 'retry_payment',   'same_method'
  UNION ALL SELECT 'card_failed_standard', 3, 3,  0, 'send_email',      'same_method'
  UNION ALL SELECT 'card_failed_standard', 4, 3,  0, 'retry_payment',   'smart_timing'
  UNION ALL SELECT 'card_failed_standard', 5, 7,  0, 'in_app_notice',   'same_method'
  UNION ALL SELECT 'card_failed_standard', 6, 10, 0, 'retry_payment',   'alternate_method'
  UNION ALL SELECT 'card_failed_standard', 7, 14, 0, 'restrict_features','same_method'
  UNION ALL SELECT 'card_failed_standard', 8, 21, 0, 'final_action',    'same_method'
  UNION ALL SELECT 'card_expiring',        1, 0,  0, 'send_email',      'updated_method_only'
  UNION ALL SELECT 'card_expiring',        2, 14, 0, 'send_email',      'updated_method_only'
  UNION ALL SELECT 'card_expiring',        3, 25, 0, 'send_sms',        'updated_method_only'
  UNION ALL SELECT 'card_expired',         1, 0,  0, 'send_email',      'updated_method_only'
  UNION ALL SELECT 'card_expired',         2, 2,  0, 'send_sms',        'updated_method_only'
  UNION ALL SELECT 'card_expired',         3, 7,  0, 'in_app_notice',   'updated_method_only'
  UNION ALL SELECT 'card_expired',         4, 14, 0, 'final_action',    'updated_method_only'
  UNION ALL SELECT 'insufficient_funds',   1, 0,  4, 'retry_payment',   'smart_timing'
  UNION ALL SELECT 'insufficient_funds',   2, 1,  0, 'retry_payment',   'smart_timing'
  UNION ALL SELECT 'insufficient_funds',   3, 3,  0, 'send_email',      'same_method'
  UNION ALL SELECT 'insufficient_funds',   4, 7,  0, 'retry_payment',   'smart_timing'
  UNION ALL SELECT 'insufficient_funds',   5, 14, 0, 'retry_payment',   'alternate_method'
  UNION ALL SELECT 'insufficient_funds',   6, 28, 0, 'final_action',    'same_method'
  UNION ALL SELECT 'invoice_overdue_enterprise', 1, 3,  0, 'send_email', 'same_method'
  UNION ALL SELECT 'invoice_overdue_enterprise', 2, 10, 0, 'notify_account_manager', 'same_method'
  UNION ALL SELECT 'invoice_overdue_enterprise', 3, 30, 0, 'send_email', 'same_method'
  UNION ALL SELECT 'invoice_overdue_enterprise', 4, 45, 0, 'final_action','same_method'
  UNION ALL SELECT 'mandate_failed',       1, 0,  0, 'send_email',      'updated_method_only'
  UNION ALL SELECT 'mandate_failed',       2, 5,  0, 'send_whatsapp',   'updated_method_only'
  UNION ALL SELECT 'mandate_failed',       3, 21, 0, 'final_action',    'updated_method_only'
  UNION ALL SELECT 'past_due_final',       1, 0,  0, 'send_email',      'same_method'
  UNION ALL SELECT 'past_due_final',       2, 7,  0, 'final_action',    'same_method'
) AS s ON s.code = c.code
LEFT JOIN notification_templates nt
  ON nt.id = 1 + MOD(s.step_number, (SELECT COUNT(*) FROM notification_templates));

INSERT INTO dunning_runs
  (campaign_id, account_id, subscription_id, invoice_id, current_step, status,
   amount_at_risk, currency_code, next_action_at, recovered_at,
   recovered_payment_id, final_action_taken, started_at, ended_at)
SELECT
  c.id, sub.account_id, sub.id, NULL, r.current_step, r.status,
  sub.amount, sub.currency_code,
  CASE WHEN r.status = 'active' THEN DATE_ADD(@now, INTERVAL 1 DAY) END,
  CASE WHEN r.status = 'recovered'
       THEN DATE_ADD(r.started_at, INTERVAL r.current_step DAY) END,
  NULL,
  CASE WHEN r.status = 'failed' THEN c.final_action END,
  r.started_at,
  CASE WHEN r.status IN ('recovered', 'failed', 'cancelled')
       THEN DATE_ADD(r.started_at, INTERVAL r.current_step + 2 DAY) END
FROM subscriptions sub
JOIN dunning_campaigns c
  ON c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dcamp:', sub.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM dunning_campaigns))
JOIN (
  SELECT s2.id AS subscription_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dstat:', s2.id)), 1, 4), 16, 10), 8),
             'recovered','recovered','recovered','recovered','recovered',
             'failed','active','cancelled') AS status,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dstep:', s2.id)), 1, 4), 16, 10), 6) AS current_step,
         DATE_SUB(NOW(3), INTERVAL 5 + MOD(CONV(SUBSTRING(MD5(CONCAT('dstart:', s2.id)), 1, 4), 16, 10), 200) DAY) AS started_at
  FROM subscriptions s2
) AS r ON r.subscription_id = sub.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasdun:', sub.id)), 1, 4), 16, 10), 3) = 0;

INSERT INTO dunning_attempts
  (dunning_run_id, step_number, action, outcome, payment_intent_id,
   notification_delivery_id, error_message, attempted_at)
SELECT
  r.id, st.step_number, st.action,
  CASE
    WHEN st.step_number < r.current_step THEN
      CASE WHEN st.action = 'retry_payment' THEN 'failed' ELSE 'succeeded' END
    WHEN st.step_number = r.current_step AND r.status = 'recovered' THEN 'succeeded'
    WHEN st.step_number = r.current_step THEN 'pending'
    ELSE 'skipped'
  END,
  NULL, NULL,
  CASE WHEN st.action = 'retry_payment' AND st.step_number < r.current_step
       THEN 'do_not_honor: the issuer declined without a reason code. Smart retry rescheduled for the payer''s local morning.' END,
  DATE_ADD(r.started_at, INTERVAL st.delay_days DAY)
FROM dunning_runs r
JOIN dunning_steps st ON st.campaign_id = r.campaign_id
WHERE st.step_number <= r.current_step;

-- -----------------------------------------------------------------------------
-- Coupon redemptions and subscription changes
-- -----------------------------------------------------------------------------
INSERT INTO coupon_redemptions
  (coupon_id, account_id, invoice_id, discount_amount, currency_code, redeemed_at)
SELECT
  c.id, i.account_id, i.id,
  ROUND(i.total * 0.15, 2), i.currency_code, i.issued_at
FROM invoices i
JOIN coupons c
  ON c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('coupon:', i.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM coupons))
WHERE i.status IN ('issued', 'paid')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hascoupon:', i.id)), 1, 4), 16, 10), 6) = 0;

INSERT INTO subscription_changes
  (subscription_id, change_type, from_plan_id, to_plan_id, from_amount,
   to_amount, currency_code, effective_timing, effective_at, proration_behavior,
   proration_credit, proration_charge, proration_days_remaining, reason,
   requested_by_user_id, status, applied_at, created_at)
SELECT
  s.id, ch.change_type, s.plan_id, ch.to_plan_id, s.amount, ch.to_amount,
  s.currency_code, ch.effective_timing,
  ch.effective_at, ch.proration_behavior,
  ROUND(ch.proration_credit, 2), ROUND(ch.proration_charge, 2),
  ch.days_remaining, ch.reason, 1, ch.status,
  CASE WHEN ch.status = 'applied' THEN ch.effective_at END,
  DATE_SUB(ch.effective_at, INTERVAL 1 DAY)
FROM subscriptions s
JOIN (
  SELECT s2.id AS subscription_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chtype:', s2.id)), 1, 4), 16, 10), 8),
             'upgrade','upgrade','upgrade','downgrade','quantity_change',
             'pause','cancel','reactivate') AS change_type,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chplan:', s2.id)), 1, 4), 16, 10),
                 (SELECT COUNT(*) FROM plans)) AS to_plan_id,
         ROUND(s2.amount * ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chamt:', s2.id)), 1, 4), 16, 10), 4),
                               1.75, 2.40, 0.55, 1.00), 2) AS to_amount,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chtime:', s2.id)), 1, 4), 16, 10), 3),
             'immediate','period_end','immediate') AS effective_timing,
         DATE_SUB(NOW(3), INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('cheff:', s2.id)), 1, 4), 16, 10), 300) DAY) AS effective_at,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chpro:', s2.id)), 1, 4), 16, 10), 3),
             'create_prorations','none','always_invoice') AS proration_behavior,
         s2.amount * MOD(CONV(SUBSTRING(MD5(CONCAT('chdays:', s2.id)), 1, 4), 16, 10), 28) / 30 AS proration_credit,
         s2.amount * 1.4 * MOD(CONV(SUBSTRING(MD5(CONCAT('chdays:', s2.id)), 1, 4), 16, 10), 28) / 30 AS proration_charge,
         MOD(CONV(SUBSTRING(MD5(CONCAT('chdays:', s2.id)), 1, 4), 16, 10), 28) AS days_remaining,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chreason:', s2.id)), 1, 4), 16, 10), 6),
             'Listing quota exhausted mid-cycle; upgraded to the next tier.',
             'Added five agent seats after a hire.',
             'Reduced to the smaller plan after a quiet quarter.',
             'Paused for the summer at the account manager''s suggestion rather than losing them entirely.',
             'Cancelled at renewal; the agency was acquired and moved to the buyer''s contract.',
             'Reactivated after three months away.') AS reason,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chstat:', s2.id)), 1, 4), 16, 10), 6),
             'applied','applied','applied','applied','scheduled','cancelled') AS status
  FROM subscriptions s2
) AS ch ON ch.subscription_id = s.id;

-- -----------------------------------------------------------------------------
-- Metered billing
--
-- Usage that is charged for: extra listings, lead credits, API calls. The
-- summary is derived from the records rather than accumulated separately, so a
-- disputed bill can be decomposed to the events behind it.
-- -----------------------------------------------------------------------------
INSERT INTO billable_meters
  (code, name, unit_label, aggregation, pricing_model, unit_price,
   currency_code, included_quantity, package_size, reset_period, is_active, created_at)
VALUES
  ('listings_active',  'Active listings',        'listing',    'max',           'tiered_graduated', NULL,   'USD',  50, NULL, 'billing_period', 1, NOW(3)),
  ('featured_slots',   'Featured placements',    'placement',  'sum',           'per_unit',        45.0000, 'USD',   2, NULL, 'billing_period', 1, NOW(3)),
  ('lead_credits',     'Lead credits consumed',  'credit',     'sum',           'package',          1.9000, 'USD', 100,  100, 'billing_period', 1, NOW(3)),
  ('api_calls',        'API calls',              'call',       'sum',           'tiered_volume',   NULL,    'USD', 10000, NULL,'monthly',       1, NOW(3)),
  ('agent_seats',      'Agent seats',            'seat',       'max',           'per_unit',        29.0000, 'USD',   3, NULL, 'billing_period', 1, NOW(3)),
  ('media_storage_gb', 'Media storage',          'GB',         'max',           'per_unit',         0.1200, 'USD',  25, NULL, 'monthly',        1, NOW(3)),
  ('sms_sent',         'SMS notifications sent', 'message',    'sum',           'per_unit',         0.0450, 'USD', 200, NULL, 'monthly',        1, NOW(3)),
  ('valuation_reports','Automated valuations',   'report',     'sum',           'per_unit',         3.5000, 'USD',  20, NULL, 'billing_period', 1, NOW(3)),
  ('unique_viewers',   'Unique listing viewers', 'viewer',     'unique_count',  'free',            NULL,    'USD',   0, NULL, 'monthly',        1, NOW(3));

INSERT INTO meter_tiers (meter_id, tier_order, up_to_quantity, unit_price, flat_price)
SELECT m.id, t.tier_order, t.up_to_quantity, t.unit_price, t.flat_price
FROM billable_meters m
JOIN (
  SELECT 'listings_active' AS code, 1 AS tier_order, 50 AS up_to_quantity, 0.0000 AS unit_price, NULL AS flat_price
  UNION ALL SELECT 'listings_active', 2, 200,   6.5000, NULL
  UNION ALL SELECT 'listings_active', 3, 1000,  4.2000, NULL
  UNION ALL SELECT 'listings_active', 4, NULL,  2.8000, NULL
  UNION ALL SELECT 'api_calls',       1, 10000, 0.0000, NULL
  UNION ALL SELECT 'api_calls',       2, 100000,0.0009, NULL
  UNION ALL SELECT 'api_calls',       3, 1000000,0.0005,NULL
  UNION ALL SELECT 'api_calls',       4, NULL,  0.0002, NULL
) AS t ON t.code = m.code;

INSERT INTO usage_records
  (meter_id, account_id, subscription_id, quantity, usage_date, reference_type,
   reference_id, idempotency_key, is_billed, recorded_at)
SELECT
  m.id, s.account_id, s.id,
  GREATEST(1, ROUND(u.base * (0.7 + MOD(CONV(SUBSTRING(MD5(CONCAT('uq:', s.id, m.id, d.n)), 1, 4), 16, 10), 61) / 100))),
  DATE_SUB(@today, INTERVAL d.n DAY),
  'subscription', s.id,
  LEFT(MD5(CONCAT('usage:', s.id, ':', m.id, ':', d.n)), 40),
  CASE WHEN d.n > 30 THEN 1 ELSE 0 END,
  TIMESTAMP(DATE_SUB(@today, INTERVAL d.n DAY), '23:50:00')
FROM subscriptions s
JOIN billable_meters m ON m.code IN ('featured_slots', 'lead_credits', 'api_calls', 'sms_sent')
JOIN (SELECT n FROM tmp_n WHERE n < 45) AS d
JOIN (
  SELECT 'featured_slots' AS code, 2 AS base
  UNION ALL SELECT 'lead_credits', 14
  UNION ALL SELECT 'api_calls', 2400
  UNION ALL SELECT 'sms_sent', 9
) AS u ON u.code = m.code
WHERE s.status = 'active'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasusage:', s.id)), 1, 4), 16, 10), 4) = 0;

INSERT INTO usage_summaries
  (account_id, meter_id, period_start, period_end, total_quantity,
   included_quantity, billable_quantity, computed_amount, currency_code,
   is_finalised, computed_at)
SELECT
  r.account_id, r.meter_id,
  DATE_FORMAT(r.usage_month, '%Y-%m-01'),
  LAST_DAY(r.usage_month),
  r.total,
  m.included_quantity,
  GREATEST(0, r.total - m.included_quantity),
  ROUND(GREATEST(0, r.total - m.included_quantity) * COALESCE(m.unit_price, 0), 2),
  COALESCE(m.currency_code, 'USD'),
  CASE WHEN LAST_DAY(r.usage_month) < @today THEN 1 ELSE 0 END,
  @now
FROM (
  SELECT account_id, meter_id,
         DATE_FORMAT(usage_date, '%Y-%m-01') AS usage_month,
         SUM(quantity) AS total
  FROM usage_records
  GROUP BY account_id, meter_id, DATE_FORMAT(usage_date, '%Y-%m-01')
) AS r
JOIN billable_meters m ON m.id = r.meter_id;

-- -----------------------------------------------------------------------------
-- Quotes and purchase orders
--
-- Enterprise agencies do not put a card in. They want a quote, they raise a
-- purchase order against it, and the invoice has to carry the order number or
-- their accounts payable will not pay it.
-- -----------------------------------------------------------------------------
INSERT INTO quotes
  (public_id, quote_number, account_id, organization_id, contact_name,
   contact_email, currency_code, subtotal, discount_total, tax_total, total,
   status, valid_until, payment_terms, notes, requires_approval,
   approved_by_user_id, approved_at, owner_user_id, sent_at, viewed_at,
   accepted_at, converted_invoice_id, pdf_url, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('quote:', o.id)), 26)),
  CONCAT('Q-', YEAR(@today), '-', LPAD(o.id, 5, '0')),
  o.account_id, o.id,
  COALESCE(o.name, 'Accounts contact'),
  COALESCE(o.email, CONCAT('accounts@', REPLACE(o.slug, '-', ''), '.com')),
  'USD',
  ROUND(q.subtotal, 2),
  ROUND(q.subtotal * q.discount_rate, 2),
  ROUND((q.subtotal - q.subtotal * q.discount_rate) * 0.05, 2),
  ROUND((q.subtotal - q.subtotal * q.discount_rate) * 1.05, 2),
  q.status,
  DATE_ADD(q.created_at, INTERVAL 30 DAY),
  'Net 30 from the date of invoice.',
  'Annual commitment. Listing quota and agent seats as scheduled below; overage billed monthly in arrears at the rates in the schedule.',
  CASE WHEN q.subtotal > 40000 THEN 1 ELSE 0 END,
  CASE WHEN q.subtotal > 40000 AND q.status <> 'draft' THEN 1 END,
  CASE WHEN q.subtotal > 40000 AND q.status <> 'draft'
       THEN DATE_ADD(q.created_at, INTERVAL 1 DAY) END,
  1 + MOD(o.id, 5),
  CASE WHEN q.status <> 'draft' THEN DATE_ADD(q.created_at, INTERVAL 2 DAY) END,
  CASE WHEN q.status IN ('viewed', 'accepted', 'converted', 'rejected')
       THEN DATE_ADD(q.created_at, INTERVAL 3 DAY) END,
  CASE WHEN q.status IN ('accepted', 'converted')
       THEN DATE_ADD(q.created_at, INTERVAL 9 DAY) END,
  NULL,
  CONCAT('https://secure.livfinder.com/quotes/', LEFT(MD5(CONCAT('quotepdf:', o.id)), 20), '.pdf'),
  q.created_at, @now
FROM organizations o
JOIN (
  SELECT o2.id AS org_id,
         12000 + MOD(CONV(SUBSTRING(MD5(CONCAT('qsub:', o2.id)), 1, 5), 16, 10), 140000) AS subtotal,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('qdisc:', o2.id)), 1, 4), 16, 10), 4),
             0.00, 0.05, 0.10, 0.15) AS discount_rate,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('qstat:', o2.id)), 1, 4), 16, 10), 8),
             'converted','converted','accepted','sent','viewed','rejected','expired','draft') AS status,
         DATE_SUB(NOW(3), INTERVAL 20 + MOD(CONV(SUBSTRING(MD5(CONCAT('qage:', o2.id)), 1, 4), 16, 10), 300) DAY) AS created_at
  FROM organizations o2
) AS q ON q.org_id = o.id;

INSERT INTO quote_lines
  (quote_id, plan_id, description, quantity, unit_amount, discount_percentage,
   discount_amount, tax_rate, tax_amount, line_total, billing_period, sort_order)
SELECT
  q.id, p.plan_id, p.description, p.quantity, p.unit_amount,
  p.discount_percentage,
  ROUND(p.quantity * p.unit_amount * p.discount_percentage / 100, 2),
  5.000,
  ROUND(p.quantity * p.unit_amount * (1 - p.discount_percentage / 100) * 0.05, 2),
  ROUND(p.quantity * p.unit_amount * (1 - p.discount_percentage / 100) * 1.05, 2),
  p.billing_period, p.sort_order
FROM quotes q
JOIN (
  SELECT 1 AS plan_id, 'Professional plan — annual commitment' AS description, 1 AS quantity, 9600.00 AS unit_amount, 10.00 AS discount_percentage, 'yearly' AS billing_period, 1 AS sort_order
  UNION ALL SELECT NULL, 'Additional agent seats',                    12,  348.00,  0.00, 'yearly',   2
  UNION ALL SELECT NULL, 'Featured placement package — 24 slots',      1, 1080.00, 15.00, 'yearly',   3
  UNION ALL SELECT NULL, 'Lead credit bundle — 5,000 credits',         1, 8500.00, 20.00, 'one_time', 4
  UNION ALL SELECT NULL, 'API access and feed integration — setup',     1, 2500.00,  0.00, 'one_time', 5
) AS p;

UPDATE quotes q
JOIN (
  SELECT quote_id,
         ROUND(SUM(quantity * unit_amount), 2) AS subtotal,
         ROUND(SUM(discount_amount), 2) AS discount_total,
         ROUND(SUM(tax_amount), 2) AS tax_total,
         ROUND(SUM(line_total), 2) AS total
  FROM quote_lines GROUP BY quote_id
) l ON l.quote_id = q.id
SET q.subtotal = l.subtotal,
    q.discount_total = l.discount_total,
    q.tax_total = l.tax_total,
    q.total = l.total;

INSERT INTO purchase_orders
  (account_id, po_number, issued_by, amount, currency_code, amount_consumed,
   valid_from, valid_until, status, notes, created_at)
SELECT
  q.account_id,
  CONCAT('PO-', YEAR(q.created_at), '-', LPAD(q.id, 6, '0')),
  COALESCE(o.legal_name, o.name),
  ROUND(q.total * 1.10, 2), q.currency_code,
  ROUND(q.total * po.consumed_share, 2),
  DATE(q.created_at),
  DATE_ADD(DATE(q.created_at), INTERVAL 365 DAY),
  po.status,
  'Raised against the accepted quote. Every invoice must quote this order number or accounts payable will reject it.',
  q.created_at
FROM quotes q
JOIN organizations o ON o.id = q.organization_id
JOIN (
  SELECT q2.id AS quote_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('postat:', q2.id)), 1, 4), 16, 10), 6),
             'active','active','active','exhausted','expired','cancelled') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('poshare:', q2.id)), 1, 4), 16, 10), 4),
             0.25, 0.60, 0.90, 1.00) AS consumed_share
  FROM quotes q2
) AS po ON po.quote_id = q.id
WHERE q.status IN ('accepted', 'converted');


-- -----------------------------------------------------------------------------
-- Cost centres, budgets and account balances
--
-- Budget against actual per account per period. The variance is derived rather
-- than typed, because a budget report where the variance disagrees with the
-- arithmetic is worse than no budget report.
-- -----------------------------------------------------------------------------
INSERT INTO cost_centers
  (parent_id, code, name, center_type, country_id, manager_user_id, is_active, created_at)
SELECT
  NULL, c.code, c.name, c.center_type, l.id, 1 + MOD(CRC32(c.code), 4), 1, @now
FROM (
  SELECT 'GRP' AS code, 'Group' AS name, 'entity' AS center_type, NULL AS country_name
  UNION ALL SELECT 'ENG',    'Engineering',            'department', NULL
  UNION ALL SELECT 'PROD',   'Product and design',     'department', NULL
  UNION ALL SELECT 'MKT',    'Marketing',              'department', NULL
  UNION ALL SELECT 'SALES',  'Sales',                  'department', NULL
  UNION ALL SELECT 'CS',     'Customer success',       'department', NULL
  UNION ALL SELECT 'OPS',    'Operations and support', 'department', NULL
  UNION ALL SELECT 'FIN',    'Finance',                'department', NULL
  UNION ALL SELECT 'LEGAL',  'Legal and compliance',   'department', NULL
  UNION ALL SELECT 'PEOPLE', 'People',                 'department', NULL
  UNION ALL SELECT 'REG-ME', 'Middle East',            'region',     'United Arab Emirates'
  UNION ALL SELECT 'REG-EU', 'Europe',                 'region',     'United Kingdom'
  UNION ALL SELECT 'REG-AM', 'Americas',               'region',     'United States'
  UNION ALL SELECT 'REG-AP', 'Asia Pacific',           'region',     'Singapore'
  UNION ALL SELECT 'PROD-RE','Real estate vertical',   'product',    NULL
  UNION ALL SELECT 'PROD-MOB','Motoring and marine',   'product',    NULL
  UNION ALL SELECT 'PROD-AV','Aviation',               'product',    NULL
  UNION ALL SELECT 'PROD-WT','Watches',                'product',    NULL
) AS c
LEFT JOIN locations l ON l.level = 'country' AND l.name = c.country_name;

UPDATE cost_centers c
JOIN cost_centers g ON g.code = 'GRP'
SET c.parent_id = g.id
WHERE c.code <> 'GRP';

INSERT INTO budgets
  (name, fiscal_year, budget_type, cost_center_id, currency_code, budget_version,
   version_number, status, approved_by_user_id, approved_at, created_at)
SELECT
  CONCAT(cc.name, ' — ', v.budget_version, ' ', y.fiscal_year),
  y.fiscal_year, b.budget_type, cc.id, 'USD', v.budget_version, v.version_number,
  CASE WHEN y.fiscal_year < YEAR(@today) THEN 'closed'
       WHEN v.budget_version = 'forecast' THEN 'draft'
       ELSE 'active' END,
  CASE WHEN v.budget_version <> 'forecast' THEN 1 END,
  CASE WHEN v.budget_version <> 'forecast'
       THEN TIMESTAMP(MAKEDATE(y.fiscal_year, 15), '10:00:00') END,
  TIMESTAMP(MAKEDATE(y.fiscal_year, 1), '09:00:00')
FROM cost_centers cc
JOIN (SELECT YEAR(CURDATE()) - 1 AS fiscal_year UNION ALL SELECT YEAR(CURDATE())) AS y
JOIN (
  SELECT 'original' AS budget_version, 1 AS version_number
  UNION ALL SELECT 'revised', 2
  UNION ALL SELECT 'forecast', 3
) AS v
JOIN (SELECT 'operating' AS budget_type) AS b
WHERE cc.center_type = 'department';

INSERT INTO budget_lines
  (budget_id, chart_account_id, period_id, period_number, budgeted_amount,
   actual_amount, variance_amount, variance_percentage, notes)
SELECT
  b.id, ca.id, p.id, p.period_number,
  ROUND(v.budgeted, 2),
  -- A future period has no actual yet, so the column holds zero rather than a
  -- null the variance arithmetic would have to special-case.
  CASE WHEN p.end_date < @today THEN ROUND(v.actual, 2) ELSE 0.00 END,
  CASE WHEN p.end_date < @today THEN ROUND(v.actual - v.budgeted, 2) ELSE 0.00 END,
  CASE WHEN p.end_date < @today AND v.budgeted <> 0
       THEN ROUND((v.actual - v.budgeted) / v.budgeted * 100, 2) END,
  CASE WHEN p.end_date < @today AND ABS(v.actual - v.budgeted) / NULLIF(v.budgeted, 0) > 0.15
       THEN 'Variance above the fifteen per cent threshold; explanation required at the monthly review.' END
FROM budgets b
JOIN accounting_periods p ON p.fiscal_year = b.fiscal_year
JOIN chart_of_accounts ca ON ca.is_postable = 1 AND ca.account_type = 'expense'
JOIN (
  SELECT b2.id AS budget_id, p2.id AS period_id, ca2.id AS chart_account_id,
         8000 + MOD(CONV(SUBSTRING(MD5(CONCAT('bud:', b2.id, p2.id, ca2.id)), 1, 5), 16, 10), 90000) AS budgeted,
         (8000 + MOD(CONV(SUBSTRING(MD5(CONCAT('bud:', b2.id, p2.id, ca2.id)), 1, 5), 16, 10), 90000))
           * (0.82 + MOD(CONV(SUBSTRING(MD5(CONCAT('act:', b2.id, p2.id, ca2.id)), 1, 4), 16, 10), 40) / 100) AS actual
  FROM budgets b2
  JOIN accounting_periods p2 ON p2.fiscal_year = b2.fiscal_year
  JOIN chart_of_accounts ca2 ON ca2.is_postable = 1 AND ca2.account_type = 'expense'
) AS v ON v.budget_id = b.id AND v.period_id = p.id AND v.chart_account_id = ca.id
WHERE b.budget_version = 'original'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('budline:', b.id, ca.id)), 1, 4), 16, 10), 4) = 0;

INSERT INTO account_balances
  (chart_account_id, period_id, currency_code, opening_balance, period_debit,
   period_credit, closing_balance, opening_balance_base, closing_balance_base,
   computed_at)
SELECT
  ca.id, p.id, 'USD',
  ROUND(v.opening, 2), ROUND(v.debit, 2), ROUND(v.credit, 2),
  ROUND(v.opening + v.debit - v.credit, 2),
  ROUND(v.opening, 2),
  ROUND(v.opening + v.debit - v.credit, 2),
  @now
FROM chart_of_accounts ca
JOIN accounting_periods p ON p.status IN ('closed', 'locked')
JOIN (
  SELECT ca2.id AS chart_account_id, p2.id AS period_id,
         MOD(CONV(SUBSTRING(MD5(CONCAT('open:', ca2.id, p2.id)), 1, 6), 16, 10), 4000000) AS opening,
         MOD(CONV(SUBSTRING(MD5(CONCAT('dr:', ca2.id, p2.id)), 1, 5), 16, 10), 900000) AS debit,
         MOD(CONV(SUBSTRING(MD5(CONCAT('cr:', ca2.id, p2.id)), 1, 5), 16, 10), 900000) AS credit
  FROM chart_of_accounts ca2 CROSS JOIN accounting_periods p2
) AS v ON v.chart_account_id = ca.id AND v.period_id = p.id
WHERE ca.is_postable = 1;

-- -----------------------------------------------------------------------------
-- Period close
--
-- The checklist. Blocking tasks are what stop a period being locked while a
-- reconciliation is still open, which is the control that makes the closed
-- flag mean something.
-- -----------------------------------------------------------------------------
INSERT INTO period_close_tasks
  (period_id, task_code, name, description, task_order, category, status,
   is_blocking, assigned_to_user_id, completed_by_user_id, completed_at,
   notes, due_at)
SELECT
  p.id, t.task_code, t.name, t.description, t.task_order, t.category,
  CASE WHEN p.status IN ('closed', 'locked') THEN 'completed'
       WHEN t.task_order <= 3 THEN 'completed'
       WHEN t.task_order = 4 THEN 'in_progress'
       ELSE 'pending' END,
  t.is_blocking,
  1 + MOD(t.task_order, 4),
  CASE WHEN p.status IN ('closed', 'locked') OR t.task_order <= 3 THEN 1 + MOD(t.task_order, 4) END,
  CASE WHEN p.status IN ('closed', 'locked') OR t.task_order <= 3
       THEN TIMESTAMP(DATE_ADD(p.end_date, INTERVAL t.task_order DAY), '16:00:00') END,
  NULL,
  TIMESTAMP(DATE_ADD(p.end_date, INTERVAL 10 DAY), '17:00:00')
FROM accounting_periods p
JOIN (
  SELECT 'bank_rec' AS task_code, 'Reconcile all bank accounts' AS name,
         'Every connected account reconciled to the statement, with any variance raised as an exception before the period is closed.' AS description,
         1 AS task_order, 'reconciliation' AS category, 1 AS is_blocking
  UNION ALL SELECT 'gateway_rec','Reconcile gateway settlements','Every settlement matched to its payments, with fees agreed to the fee schedule.',2,'reconciliation',1
  UNION ALL SELECT 'ar_ageing','Review receivables ageing','Anything over ninety days either provided against or escalated to collections.',3,'review',0
  UNION ALL SELECT 'revenue_rec','Post revenue recognition','Deferred balance released for the period in line with the recognition rules.',4,'revenue',1
  UNION ALL SELECT 'accruals','Post accruals and prepayments','Accrue for services received and not invoiced; release prepayments due in the period.',5,'accrual',1
  UNION ALL SELECT 'fx_reval','Revalue foreign currency balances','Retranslate monetary balances at the closing rate and post the difference.',6,'fx',1
  UNION ALL SELECT 'intercompany','Agree intercompany balances','Balances between the entities agreed and eliminated on consolidation.',7,'reconciliation',1
  UNION ALL SELECT 'tax_provision','Post the tax provision','Corporate tax and irrecoverable input tax accrued for the period.',8,'tax',1
  UNION ALL SELECT 'payroll','Post payroll journal','Payroll bureau file agreed to the ledger, including employer costs.',9,'accrual',1
  UNION ALL SELECT 'depreciation','Post depreciation and amortisation','Fixed asset and capitalised development amortisation for the period.',10,'accrual',0
  UNION ALL SELECT 'variance_review','Review budget variances','Any line more than fifteen per cent from budget explained by the owning cost centre.',11,'review',0
  UNION ALL SELECT 'flash_report','Issue the flash report','Preliminary numbers to the leadership team within four working days.',12,'reporting',0
  UNION ALL SELECT 'management_accounts','Issue the management accounts','Full pack including the commentary and the KPI appendix.',13,'reporting',0
  UNION ALL SELECT 'lock_period','Lock the period','No further postings without a reopening approved by the controller.',14,'other',1
) AS t;

-- -----------------------------------------------------------------------------
-- FX revaluation
--
-- The unrealised difference between what a foreign balance was booked at and
-- what it is worth at the closing rate. Posted as a journal so the profit and
-- loss carries it rather than the balance sheet quietly drifting.
-- -----------------------------------------------------------------------------
INSERT INTO fx_revaluations
  (period_id, chart_account_id, currency_code, foreign_balance, historical_rate,
   closing_rate, base_balance_before, base_balance_after, revaluation_amount,
   status, calculated_at)
SELECT
  p.id, ca.id, c.currency_code,
  ROUND(v.foreign_balance, 2),
  ROUND(c.historical_rate, 10),
  ROUND(c.historical_rate * (1 + v.drift), 10),
  ROUND(v.foreign_balance * c.historical_rate, 2),
  ROUND(v.foreign_balance * c.historical_rate * (1 + v.drift), 2),
  ROUND(v.foreign_balance * c.historical_rate * v.drift, 2),
  CASE WHEN p.status = 'locked' THEN 'posted' ELSE 'calculated' END,
  TIMESTAMP(DATE_ADD(p.end_date, INTERVAL 6 DAY), '11:00:00')
FROM accounting_periods p
JOIN chart_of_accounts ca ON ca.is_reconcilable = 1 AND ca.is_postable = 1
JOIN (
  SELECT 'EUR' AS currency_code, 1.0850000000 AS historical_rate
  UNION ALL SELECT 'GBP', 1.2650000000
  UNION ALL SELECT 'AED', 0.2722600000
  UNION ALL SELECT 'CHF', 1.1120000000
  UNION ALL SELECT 'SGD', 0.7410000000
) AS c
JOIN (
  SELECT p2.id AS period_id, ca2.id AS chart_account_id, c2.currency_code,
         MOD(CONV(SUBSTRING(MD5(CONCAT('fxbal:', p2.id, ca2.id, c2.currency_code)), 1, 6), 16, 10), 3000000) AS foreign_balance,
         (MOD(CONV(SUBSTRING(MD5(CONCAT('fxdrift:', p2.id, ca2.id, c2.currency_code)), 1, 4), 16, 10), 700) - 350) / 10000 AS drift
  FROM accounting_periods p2
  CROSS JOIN chart_of_accounts ca2
  CROSS JOIN (SELECT 'EUR' AS currency_code UNION ALL SELECT 'GBP' UNION ALL SELECT 'AED'
              UNION ALL SELECT 'CHF' UNION ALL SELECT 'SGD') c2
) AS v ON v.period_id = p.id AND v.chart_account_id = ca.id AND v.currency_code = c.currency_code
WHERE p.status IN ('closed', 'locked')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasfx:', p.id, ca.id)), 1, 4), 16, 10), 6) = 0;

-- -----------------------------------------------------------------------------
-- Tax filings, exemptions and withholding
-- -----------------------------------------------------------------------------
INSERT INTO tax_filings
  (registration_id, jurisdiction_id, tax_period, period_start, period_end,
   due_date, currency_code, output_tax, input_tax, net_payable, taxable_sales,
   zero_rated_sales, exempt_sales, reverse_charge_sales, transaction_count,
   status, submitted_at, submission_reference, paid_at, payment_reference,
   prepared_by_user_id, approved_by_user_id, notes, created_at, updated_at)
SELECT
  r.id, r.jurisdiction_id,
  -- CHAR(7): a quarter reads as 2026-Q1, never as a formatted month name.
  CONCAT(YEAR(DATE_SUB(@today, INTERVAL q.n QUARTER)), '-Q',
         QUARTER(DATE_SUB(@today, INTERVAL q.n QUARTER))),
  DATE_SUB(MAKEDATE(YEAR(DATE_SUB(@today, INTERVAL q.n QUARTER)), 1)
           + INTERVAL (QUARTER(DATE_SUB(@today, INTERVAL q.n QUARTER)) - 1) QUARTER, INTERVAL 0 DAY),
  LAST_DAY(MAKEDATE(YEAR(DATE_SUB(@today, INTERVAL q.n QUARTER)), 1)
           + INTERVAL (QUARTER(DATE_SUB(@today, INTERVAL q.n QUARTER)) * 3 - 1) MONTH),
  DATE_ADD(LAST_DAY(MAKEDATE(YEAR(DATE_SUB(@today, INTERVAL q.n QUARTER)), 1)
           + INTERVAL (QUARTER(DATE_SUB(@today, INTERVAL q.n QUARTER)) * 3 - 1) MONTH), INTERVAL 28 DAY),
  'USD',
  ROUND(f.output_tax, 2), ROUND(f.input_tax, 2),
  ROUND(f.output_tax - f.input_tax, 2),
  ROUND(f.taxable_sales, 2),
  ROUND(f.taxable_sales * 0.08, 2),
  ROUND(f.taxable_sales * 0.03, 2),
  ROUND(f.taxable_sales * 0.22, 2),
  f.transaction_count,
  f.status,
  CASE WHEN f.status IN ('submitted', 'accepted', 'paid')
       THEN TIMESTAMP(DATE_ADD(@today, INTERVAL -q.n * 90 + 20 DAY), '14:00:00') END,
  CASE WHEN f.status IN ('submitted', 'accepted', 'paid')
       THEN CONCAT('SUB-', UPPER(LEFT(MD5(CONCAT('filing:', r.id, q.n)), 12))) END,
  CASE WHEN f.status = 'paid'
       THEN TIMESTAMP(DATE_ADD(@today, INTERVAL -q.n * 90 + 26 DAY), '10:00:00') END,
  CASE WHEN f.status = 'paid'
       THEN CONCAT('PAY-', UPPER(LEFT(MD5(CONCAT('filingpay:', r.id, q.n)), 12))) END,
  1, 2,
  CASE WHEN f.status = 'amended'
       THEN 'Amended after a reverse-charge supply was reclassified following a customer VAT-number revalidation.' END,
  @now, @now
FROM tax_registrations r
JOIN (SELECT n FROM tmp_n WHERE n BETWEEN 1 AND 8) AS q
JOIN (
  SELECT r2.id AS registration_id, q2.n AS quarter_offset,
         120000 + MOD(CONV(SUBSTRING(MD5(CONCAT('outtax:', r2.id, q2.n)), 1, 5), 16, 10), 400000) AS output_tax,
         40000 + MOD(CONV(SUBSTRING(MD5(CONCAT('intax:', r2.id, q2.n)), 1, 5), 16, 10), 150000) AS input_tax,
         2000000 + MOD(CONV(SUBSTRING(MD5(CONCAT('sales:', r2.id, q2.n)), 1, 6), 16, 10), 9000000) AS taxable_sales,
         800 + MOD(CONV(SUBSTRING(MD5(CONCAT('txncount:', r2.id, q2.n)), 1, 4), 16, 10), 4000) AS transaction_count,
         CASE WHEN q2.n = 1 THEN 'draft'
              WHEN q2.n = 2 THEN 'approved'
              WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('filestat:', r2.id, q2.n)), 1, 4), 16, 10), 9) = 0 THEN 'amended'
              ELSE 'paid' END AS status
  FROM tax_registrations r2 CROSS JOIN (SELECT n FROM tmp_n WHERE n BETWEEN 1 AND 8) q2
) AS f ON f.registration_id = r.id AND f.quarter_offset = q.n;

INSERT INTO tax_exemptions
  (account_id, jurisdiction_id, exemption_type, certificate_number, valid_from,
   valid_to, status, approved_by_user_id, approved_at, notes, created_at)
SELECT
  a.id, j.id, e.exemption_type,
  CONCAT(e.prefix, '-', UPPER(LEFT(MD5(CONCAT('exempt:', a.id, e.exemption_type)), 12))),
  DATE_SUB(@today, INTERVAL 200 DAY),
  DATE_ADD(@today, INTERVAL e.validity_days DAY),
  e.status,
  CASE WHEN e.status = 'approved' THEN 1 END,
  CASE WHEN e.status = 'approved' THEN DATE_SUB(@now, INTERVAL 195 DAY) END,
  e.notes,
  DATE_SUB(@now, INTERVAL 200 DAY)
FROM accounts a
JOIN tax_jurisdictions j
  ON j.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('exjur:', a.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM tax_jurisdictions))
JOIN (
  SELECT 'free_zone' AS exemption_type, 'FZ' AS prefix, 365 AS validity_days, 'approved' AS status,
         'Designated free zone entity. Supplies outside the zone remain taxable and are charged normally.' AS notes, 0 AS slot
  UNION ALL SELECT 'export',     'EX',  730, 'approved', 'Services supplied to a customer established outside the jurisdiction; zero-rated on evidence of export.', 1
  UNION ALL SELECT 'government', 'GOV', 1095,'approved', 'Government entity with a standing exemption certificate on file.', 2
  UNION ALL SELECT 'non_profit', 'NP',  365, 'pending',  'Charitable status claimed; awaiting the certificate before the exemption is applied.', 3
  UNION ALL SELECT 'resale',     'RS',  365, 'expired',  'Reseller certificate lapsed. Tax charged at the standard rate until it is renewed.', 4
) AS e ON e.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('extype:', a.id)), 1, 4), 16, 10), 5)
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasexempt:', a.id)), 1, 4), 16, 10), 8) = 0;

INSERT INTO withholding_taxes
  (payout_id, account_id, jurisdiction_id, gross_amount, withholding_rate,
   withheld_amount, net_amount, currency_code, treaty_applied, treaty_country_id,
   certificate_reference, certificate_issued_at, tax_period, remitted_at, created_at)
SELECT
  p.id, p.account_id, j.id,
  ROUND(p.gross_amount, 2), w.rate,
  ROUND(p.gross_amount * w.rate / 100, 2),
  ROUND(p.gross_amount * (1 - w.rate / 100), 2),
  p.currency_code,
  w.treaty_applied,
  CASE WHEN w.treaty_applied = 1 THEN tc.id END,
  CONCAT('WHT-', UPPER(LEFT(MD5(CONCAT('wht:', p.id)), 12))),
  DATE_ADD(DATE(p.created_at), INTERVAL 30 DAY),
  DATE_FORMAT(p.created_at, '%Y-%m'),
  DATE_ADD(DATE(p.created_at), INTERVAL 45 DAY),
  p.created_at
FROM payouts p
JOIN tax_jurisdictions j
  ON j.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('whtjur:', p.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM tax_jurisdictions))
LEFT JOIN locations tc ON tc.level = 'country' AND tc.name = 'United Kingdom'
JOIN (
  SELECT p2.id AS payout_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('whtrate:', p2.id)), 1, 4), 16, 10), 4),
             5.0000, 10.0000, 15.0000, 20.0000) AS rate,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('whttreaty:', p2.id)), 1, 4), 16, 10), 2) = 0
              THEN 1 ELSE 0 END AS treaty_applied
  FROM payouts p2
) AS w ON w.payout_id = p.id;

-- -----------------------------------------------------------------------------
-- Daily revenue and price index
--
-- Two rollups the front page and the market pages read directly, kept as tables
-- rather than views because both are asked for by every dashboard at once.
-- -----------------------------------------------------------------------------
INSERT INTO revenue_daily_stats
  (stat_date, country_id, root_category_id, currency_code, subscription_revenue,
   promotion_revenue, credit_revenue, advertising_revenue, lead_revenue,
   commission_revenue, other_revenue, gross_revenue, refunds, chargebacks,
   net_revenue, net_revenue_base, affiliate_cost, payment_fees, paying_accounts,
   new_paying_accounts, churned_accounts, computed_at)
SELECT
  d.stat_date, c.id, cat.id, 'USD',
  ROUND(v.base * 0.52, 2), ROUND(v.base * 0.18, 2), ROUND(v.base * 0.09, 2),
  ROUND(v.base * 0.11, 2), ROUND(v.base * 0.05, 2), ROUND(v.base * 0.04, 2),
  ROUND(v.base * 0.01, 2),
  ROUND(v.base, 2),
  ROUND(v.base * 0.021, 2), ROUND(v.base * 0.003, 2),
  ROUND(v.base * 0.976, 2), ROUND(v.base * 0.976, 2),
  ROUND(v.base * 0.012, 2), ROUND(v.base * 0.026, 2),
  v.paying, GREATEST(0, ROUND(v.paying * 0.03)), GREATEST(0, ROUND(v.paying * 0.015)),
  @now
FROM (
  SELECT DATE_SUB(CURDATE(), INTERVAL n.n DAY) AS stat_date, n.n AS days_ago
  FROM tmp_n n WHERE n.n BETWEEN 1 AND 90
) AS d
JOIN (
  SELECT id, name FROM locations
  WHERE level = 'country'
    AND name IN ('United Arab Emirates', 'United Kingdom', 'United States', 'France', 'Singapore')
) AS c
JOIN categories cat ON cat.parent_id IS NULL
JOIN (
  SELECT n2.n AS days_ago, c2.id AS country_id, cat2.id AS category_id,
         GREATEST(200, ROUND(
           (CASE cat2.code WHEN 'real-estate' THEN 26000 WHEN 'cars' THEN 7000
                           WHEN 'yachts' THEN 5200 WHEN 'jets' THEN 4100
                           WHEN 'helicopters' THEN 1800 ELSE 2600 END)
           * (CASE WHEN DAYOFWEEK(DATE_SUB(CURDATE(), INTERVAL n2.n DAY)) IN (1, 7) THEN 0.55 ELSE 1.00 END)
           * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('rev:', c2.id, cat2.id, n2.n)), 1, 4), 16, 10), 25) / 100)
           / 5)) AS base,
         GREATEST(1, ROUND(
           (CASE cat2.code WHEN 'real-estate' THEN 240 ELSE 60 END)
           * (0.9 + MOD(CONV(SUBSTRING(MD5(CONCAT('pay:', c2.id, cat2.id, n2.n)), 1, 4), 16, 10), 20) / 100)
           / 5)) AS paying
  FROM tmp_n n2
  CROSS JOIN (SELECT id FROM locations WHERE level = 'country'
               AND name IN ('United Arab Emirates','United Kingdom','United States','France','Singapore')) c2
  CROSS JOIN (SELECT id, code FROM categories WHERE parent_id IS NULL) cat2
  WHERE n2.n BETWEEN 1 AND 90
) AS v ON v.days_ago = d.days_ago AND v.country_id = c.id AND v.category_id = cat.id;

INSERT INTO price_index_daily
  (location_id, category_id, purpose_id, stat_date, listing_count,
   median_price_base, avg_price_base, min_price_base, max_price_base,
   median_price_per_sqft, avg_days_on_market, computed_at)
SELECT
  s.community_id, s.root_category_id, s.purpose_id,
  DATE_SUB(@today, INTERVAL d.n DAY),
  s.listing_count,
  ROUND(s.avg_price * 0.94, 2),
  ROUND(s.avg_price, 2),
  ROUND(s.min_price, 2),
  ROUND(s.max_price, 2),
  ROUND(s.avg_ppa, 2),
  30 + MOD(CONV(SUBSTRING(MD5(CONCAT('dom:', s.community_id, s.root_category_id, d.n)), 1, 4), 16, 10), 90),
  @now
FROM (
  SELECT l.community_id, l.root_category_id, l.purpose_id,
         COUNT(*) AS listing_count,
         AVG(l.price_base) AS avg_price,
         MIN(l.price_base) AS min_price,
         MAX(l.price_base) AS max_price,
         AVG(l.price_per_area) AS avg_ppa
  FROM listings l
  WHERE l.status = 'active' AND l.community_id IS NOT NULL
  GROUP BY l.community_id, l.root_category_id, l.purpose_id
) AS s
JOIN (SELECT n FROM tmp_n WHERE n < 14) AS d;

DROP TABLE IF EXISTS tmp_n;
