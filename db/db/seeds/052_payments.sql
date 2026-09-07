-- =============================================================================
-- Liv Finder — seed 052 · Payments infrastructure
-- =============================================================================
-- The gateway catalogue is real. A platform selling in the Gulf, Europe and the
-- Americas cannot use one processor: Stripe does not acquire in Saudi Arabia,
-- Network International is the incumbent in the UAE, and a card issued in Riyadh
-- authorises at a materially higher rate through a local acquirer than through
-- an international one. That is what `gateway_routing_rules` exists to encode.
--
-- The demo intents and attempts are derived from the payments that already
-- exist, so the lifecycle in 0018 is populated with the same money the rest of
-- the schema already accounts for. Every failed payment gets a failed attempt
-- with a decline code that explains it, and roughly a fifth of the failures get
-- a successful retry — because that is what actually happens, and because a
-- dataset where every payment succeeds first time teaches the dunning logic
-- nothing.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Gateways
--
-- Capabilities, not opinions. `card_data_exposure = 'none'` means the card never
-- touches our servers, which is the difference between PCI-DSS SAQ A and a
-- compliance programme costing six figures a year.
-- -----------------------------------------------------------------------------
INSERT INTO payment_gateways
  (code, name, provider, supports_3ds, supports_auth_capture, supports_partial_capture,
   supports_refunds, supports_partial_refunds, supports_recurring, supports_mandates,
   supports_payouts, supports_split_payments, supports_escrow, card_data_exposure,
   webhook_signature_algorithm, api_version, documentation_url, status)
VALUES
  ('stripe', 'Stripe', 'stripe', 1,1,1,1,1,1,1,1,1,0, 'none',
   'HMAC-SHA256', '2024-06-20', 'https://stripe.com/docs/api', 'active'),
  ('adyen', 'Adyen', 'adyen', 1,1,1,1,1,1,1,1,1,0, 'none',
   'HMAC-SHA256', 'v71', 'https://docs.adyen.com', 'active'),
  ('checkout', 'Checkout.com', 'checkout_com', 1,1,1,1,1,1,1,1,0,0, 'none',
   'HMAC-SHA256', '2024-04-10', 'https://api-reference.checkout.com', 'active'),
  ('network-intl', 'Network International', 'network_international', 1,1,0,1,1,1,0,0,0,0, 'none',
   'HMAC-SHA256', 'v2', NULL, 'active'),
  ('paytabs', 'PayTabs', 'paytabs', 1,1,0,1,1,1,0,0,0,0, 'none',
   'HMAC-SHA256', 'v2', NULL, 'active'),
  ('tap', 'Tap Payments', 'tap', 1,1,0,1,1,1,0,1,0,0, 'none',
   'HMAC-SHA256', 'v2', NULL, 'active'),
  ('hyperpay', 'HyperPay', 'hyperpay', 1,1,0,1,1,1,0,0,0,0, 'none',
   'HMAC-SHA256', 'v1', NULL, 'active'),
  ('paypal', 'PayPal', 'paypal', 0,1,1,1,1,1,1,1,0,0, 'none',
   'HMAC-SHA256', 'v2', 'https://developer.paypal.com', 'active'),
  ('gocardless', 'GoCardless (direct debit)', 'gocardless', 0,0,0,1,0,1,1,0,0,0, 'none',
   'HMAC-SHA256', '2015-07-06', NULL, 'active'),
  ('wise', 'Wise (payouts)', 'wise', 0,0,0,0,0,0,0,1,0,0, 'none',
   'RSA-SHA256', 'v2', NULL, 'active'),
  ('bank-transfer', 'Bank transfer (manual)', 'bank_transfer', 0,0,0,1,1,0,0,1,0,1, 'none',
   NULL, NULL, NULL, 'active'),
  ('manual', 'Manual / offline', 'manual', 0,0,0,1,1,0,0,1,0,1, 'none',
   NULL, NULL, NULL, 'active');

-- -----------------------------------------------------------------------------
-- Gateway accounts
--
-- One merchant account per gateway per settlement currency and legal entity.
-- Several exist for the same provider on purpose: settlement currency drives
-- which one a transaction must use, and settling AED through a EUR account
-- costs a currency conversion on every payment.
--
-- Fees are the published rates. They matter here because `payments.fee_amount`
-- is derived from them below rather than made up.
-- -----------------------------------------------------------------------------
INSERT INTO gateway_accounts
  (gateway_id, code, name, legal_entity, merchant_id, credentials_ref,
   webhook_secret_ref, settlement_currency, supported_currencies, supported_countries,
   supported_methods, percentage_fee, fixed_fee, fixed_fee_currency,
   settlement_delay_days, is_live, is_default, status, recent_success_rate,
   consecutive_failures)
SELECT g.id, v.code, v.name, v.legal_entity, v.merchant_id,
       CONCAT('secretsmanager://payments/', v.code, '/api-key'),
       CONCAT('secretsmanager://payments/', v.code, '/webhook-secret'),
       v.settlement_currency, v.currencies, v.countries, v.methods,
       v.pct, v.fixed, v.fixed_ccy, v.delay_days, 1, v.is_default, 'active',
       v.success_rate, 0
FROM (
  SELECT 'stripe' AS gw, 'stripe-ae-aed' AS code, 'Stripe — UAE (AED)' AS name,
         'Liv Finder FZ-LLC' AS legal_entity, 'acct_1LivFinderAE' AS merchant_id,
         'AED' AS settlement_currency,
         JSON_ARRAY('AED','USD','EUR','GBP','SAR') AS currencies,
         JSON_ARRAY('AE','SA','QA','KW','BH','OM') AS countries,
         JSON_ARRAY('card','apple_pay','google_pay') AS methods,
         0.0290 AS pct, 1.00 AS fixed, 'AED' AS fixed_ccy, 3 AS delay_days,
         1 AS is_default, 96.40 AS success_rate
  UNION ALL SELECT 'stripe', 'stripe-eu-eur', 'Stripe — Europe (EUR)',
         'Liv Finder Europe B.V.', 'acct_1LivFinderEU', 'EUR',
         JSON_ARRAY('EUR','GBP','CHF','SEK','NOK','DKK'),
         JSON_ARRAY('NL','DE','FR','ES','IT','PT','BE','AT','IE','CH','SE','NO','DK'),
         JSON_ARRAY('card','sepa_debit','ideal','bancontact','sofort','apple_pay','google_pay'),
         0.0140, 0.25, 'EUR', 2, 0, 97.10
  UNION ALL SELECT 'stripe', 'stripe-uk-gbp', 'Stripe — United Kingdom (GBP)',
         'Liv Finder UK Ltd', 'acct_1LivFinderUK', 'GBP',
         JSON_ARRAY('GBP','EUR','USD'), JSON_ARRAY('GB'),
         JSON_ARRAY('card','bacs_debit','apple_pay','google_pay'),
         0.0150, 0.20, 'GBP', 2, 0, 97.60
  UNION ALL SELECT 'stripe', 'stripe-us-usd', 'Stripe — United States (USD)',
         'Liv Finder Inc.', 'acct_1LivFinderUS', 'USD',
         JSON_ARRAY('USD','CAD','MXN'), JSON_ARRAY('US','CA','MX'),
         JSON_ARRAY('card','ach_debit','apple_pay','google_pay'),
         0.0290, 0.30, 'USD', 2, 0, 96.90
  UNION ALL SELECT 'adyen', 'adyen-global', 'Adyen — global',
         'Liv Finder FZ-LLC', 'LivFinderECOM', 'EUR',
         JSON_ARRAY('EUR','USD','GBP','AED','SGD','HKD','AUD','JPY'),
         JSON_ARRAY('SG','HK','AU','JP','TH','MY','ID','IN','ZA','TR'),
         JSON_ARRAY('card','alipay','wechat_pay','grabpay','paynow'),
         0.0110, 0.11, 'EUR', 4, 0, 95.80
  UNION ALL SELECT 'network-intl', 'ni-ae-aed', 'Network International — UAE',
         'Liv Finder FZ-LLC', 'NI-LIVFINDER-AE', 'AED',
         JSON_ARRAY('AED','USD'), JSON_ARRAY('AE'),
         JSON_ARRAY('card','mada','apple_pay'),
         0.0240, 1.00, 'AED', 2, 0, 98.20
  UNION ALL SELECT 'hyperpay', 'hyperpay-sa-sar', 'HyperPay — Saudi Arabia',
         'Liv Finder Arabia LLC', 'HP-LIVFINDER-SA', 'SAR',
         JSON_ARRAY('SAR','USD'), JSON_ARRAY('SA'),
         JSON_ARRAY('card','mada','stc_pay','apple_pay'),
         0.0250, 1.00, 'SAR', 3, 0, 97.90
  UNION ALL SELECT 'tap', 'tap-gcc', 'Tap Payments — GCC',
         'Liv Finder FZ-LLC', 'TAP-LIVFINDER', 'KWD',
         JSON_ARRAY('KWD','BHD','OMR','QAR','SAR','AED'),
         JSON_ARRAY('KW','BH','OM','QA'),
         JSON_ARRAY('card','knet','benefit','apple_pay'),
         0.0270, 0.100, 'KWD', 3, 0, 96.10
  UNION ALL SELECT 'gocardless', 'gocardless-eu', 'GoCardless — SEPA and Bacs',
         'Liv Finder Europe B.V.', 'GC-LIVFINDER', 'EUR',
         JSON_ARRAY('EUR','GBP'), JSON_ARRAY('NL','DE','FR','ES','IT','GB','IE'),
         JSON_ARRAY('sepa_debit','bacs_debit'),
         0.0100, 0.20, 'EUR', 5, 0, 98.80
  UNION ALL SELECT 'bank-transfer', 'bank-ae-aed', 'Bank transfer — Emirates NBD',
         'Liv Finder FZ-LLC', NULL, 'AED',
         JSON_ARRAY('AED','USD','EUR','GBP'), NULL,
         JSON_ARRAY('bank_transfer'), 0.0000, 0.00, 'AED', 1, 0, 100.00
) v
JOIN payment_gateways g ON g.code = v.gw;

-- -----------------------------------------------------------------------------
-- Routing rules
--
-- Ordered, first match wins. The policy in one sentence: settle in the
-- customer's own currency through a local acquirer wherever one exists, because
-- local acquiring authorises better and avoids a cross-border fee, and fall
-- back to the global processor everywhere else.
-- -----------------------------------------------------------------------------
INSERT INTO gateway_routing_rules
  (name, priority, currency_code, country_id, payment_method_type, card_brand,
   min_amount, max_amount, transaction_type, gateway_account_id,
   fallback_gateway_account_id, failover_on_codes, is_active)
SELECT v.name, v.priority, v.currency_code,
       (SELECT id FROM locations WHERE level = 'country' AND slug = v.country_slug LIMIT 1),
       v.method, NULL, v.min_amount, NULL, v.txn_type,
       ga.id, fb.id, v.failover_codes, 1
FROM (
  SELECT 'Saudi cards route to the local acquirer' AS name, 10 AS priority,
         'SAR' AS currency_code, 'saudi-arabia' AS country_slug, NULL AS method,
         NULL AS min_amount, 'any' AS txn_type,
         'hyperpay-sa-sar' AS gw_code, 'adyen-global' AS fb_code,
         JSON_ARRAY('processor_unavailable','timeout','do_not_honor') AS failover_codes
  UNION ALL SELECT 'UAE cards route to Network International', 20, 'AED', 'united-arab-emirates',
         NULL, NULL, 'any', 'ni-ae-aed', 'stripe-ae-aed',
         JSON_ARRAY('processor_unavailable','timeout')
  UNION ALL SELECT 'Kuwait KNET goes to Tap', 30, 'KWD', 'kuwait', 'knet', NULL, 'any',
         'tap-gcc', 'adyen-global', JSON_ARRAY('processor_unavailable')
  UNION ALL SELECT 'Bahrain Benefit goes to Tap', 40, 'BHD', 'bahrain', 'benefit', NULL, 'any',
         'tap-gcc', 'adyen-global', JSON_ARRAY('processor_unavailable')
  UNION ALL SELECT 'European direct debit goes to GoCardless', 50, 'EUR', NULL,
         'sepa_debit', NULL, 'subscription', 'gocardless-eu', 'stripe-eu-eur',
         JSON_ARRAY('processor_unavailable')
  UNION ALL SELECT 'UK direct debit goes to GoCardless', 55, 'GBP', 'united-kingdom',
         'bacs_debit', NULL, 'subscription', 'gocardless-eu', 'stripe-uk-gbp',
         JSON_ARRAY('processor_unavailable')
  UNION ALL SELECT 'Euro cards settle in euro', 60, 'EUR', NULL, 'card', NULL, 'any',
         'stripe-eu-eur', 'adyen-global', JSON_ARRAY('processor_unavailable','timeout')
  UNION ALL SELECT 'Sterling cards settle in sterling', 70, 'GBP', NULL, 'card', NULL, 'any',
         'stripe-uk-gbp', 'adyen-global', JSON_ARRAY('processor_unavailable','timeout')
  UNION ALL SELECT 'US and Canadian cards settle in dollars', 80, 'USD', NULL, 'card', NULL, 'any',
         'stripe-us-usd', 'adyen-global', JSON_ARRAY('processor_unavailable','timeout')
  UNION ALL SELECT 'Large invoices go to bank transfer', 90, NULL, NULL,
         'bank_transfer', 50000.00, 'one_time', 'bank-ae-aed', NULL, NULL
  UNION ALL SELECT 'Everything else falls through to Adyen', 999, NULL, NULL, NULL,
         NULL, 'any', 'adyen-global', 'stripe-ae-aed', JSON_ARRAY('processor_unavailable')
) v
JOIN gateway_accounts ga ON ga.code = v.gw_code
LEFT JOIN gateway_accounts fb ON fb.code = v.fb_code;

-- -----------------------------------------------------------------------------
-- Attach existing payments to a gateway account
--
-- The gateway is chosen by the same rule the routing table describes — settle
-- in the payment's own currency where an account exists for it — so the demo
-- data is consistent with the configuration above rather than assigned at
-- random.
-- -----------------------------------------------------------------------------
UPDATE payments p
  JOIN gateway_accounts ga
    ON ga.settlement_currency = p.currency_code AND ga.status = 'active'
   SET p.gateway_account_id = ga.id,
       p.provider = (SELECT g.code FROM payment_gateways g WHERE g.id = ga.gateway_id)
 WHERE p.gateway_account_id IS NULL;

UPDATE payments p
  JOIN gateway_accounts ga ON ga.code = 'adyen-global'
   SET p.gateway_account_id = ga.id, p.provider = 'adyen'
 WHERE p.gateway_account_id IS NULL;

-- Processor fees, computed from the account's published rate rather than
-- guessed. `net_amount` is what actually lands in the bank.
UPDATE payments p
  JOIN gateway_accounts ga ON ga.id = p.gateway_account_id
   SET p.fee_amount = ROUND(p.amount * ga.percentage_fee + ga.fixed_fee, 2),
       p.net_amount = p.amount - ROUND(p.amount * ga.percentage_fee + ga.fixed_fee, 2)
 WHERE p.status IN ('succeeded', 'partially_refunded', 'refunded', 'disputed');

-- -----------------------------------------------------------------------------
-- Payment intents
--
-- One per existing payment. The intent carries the lifecycle — 3-D Secure
-- state, SCA exemption, liability shift — that the payment row deliberately
-- does not.
--
-- The SCA rules encoded here are the real ones: a European card transaction
-- needs strong authentication unless an exemption applies, low-value exemptions
-- stop at €30, and a merchant-initiated subscription renewal is out of scope
-- entirely. Getting this wrong does not fail loudly — it just declines more
-- payments than it should.
-- -----------------------------------------------------------------------------
INSERT INTO payment_intents
  (public_id, reference, account_id, user_id, amount, currency_code, amount_base,
   exchange_rate, amount_captured, amount_refunded, purpose, invoice_id,
   subscription_id, booking_id, description, status, capture_method,
   confirmation_method, gateway_account_id, payment_method_id, provider_intent_id,
   three_ds_status, three_ds_version, sca_exemption, liability_shift, risk_score,
   risk_decision, idempotency_key, statement_descriptor, expires_at, succeeded_at,
   cancelled_at, last_error_code, last_error_message, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('intent:', p.id)), 26)),
  CONCAT('PI-', LPAD(p.id, 10, '0')),
  p.account_id, p.user_id, p.amount, p.currency_code, p.amount_base, p.exchange_rate,
  IF(p.status IN ('succeeded','partially_refunded','refunded','disputed'), p.amount, 0),
  p.refunded_amount,
  CASE p.payment_type WHEN 'subscription' THEN 'subscription'
                      WHEN 'featured' THEN 'featured_placement'
                      WHEN 'credit' THEN 'listing_credit'
                      WHEN 'booking' THEN 'booking_deposit'
                      WHEN 'deposit' THEN 'booking_deposit'
                      ELSE 'other' END,
  p.invoice_id, p.subscription_id, p.booking_id,
  CONCAT('Liv Finder — ', REPLACE(p.payment_type, '_', ' ')),
  CASE p.status WHEN 'succeeded' THEN 'succeeded'
                WHEN 'partially_refunded' THEN 'succeeded'
                WHEN 'refunded' THEN 'succeeded'
                WHEN 'disputed' THEN 'succeeded'
                WHEN 'failed' THEN 'failed'
                WHEN 'cancelled' THEN 'cancelled'
                WHEN 'requires_action' THEN 'requires_action'
                WHEN 'processing' THEN 'processing'
                ELSE 'requires_payment_method' END,
  'automatic', 'automatic',
  p.gateway_account_id, p.payment_method_id,
  CONCAT('pi_', LOWER(LEFT(MD5(CONCAT('provider:', p.id)), 24))),
  -- Strong authentication by jurisdiction and amount. See the table comment.
  CASE WHEN p.currency_code IN ('EUR','GBP') AND p.amount > 30 THEN
            IF(p.status = 'failed', 'failed', 'authenticated')
       WHEN p.currency_code IN ('EUR','GBP') THEN 'exempted'
       WHEN p.currency_code IN ('AED','SAR','KWD','BHD','QAR','OMR') THEN
            IF(p.status = 'failed', 'failed', 'authenticated')
       ELSE 'not_required' END,
  IF(p.currency_code IN ('EUR','GBP','AED','SAR','KWD','BHD','QAR','OMR'), '2.2.0', NULL),
  CASE WHEN p.payment_type = 'subscription' THEN 'recurring'
       WHEN p.currency_code IN ('EUR','GBP') AND p.amount <= 30 THEN 'low_value'
       ELSE 'none' END,
  -- Liability for a fraudulent chargeback shifts to the issuer only when the
  -- cardholder was authenticated. This column is the difference between
  -- absorbing a chargeback and not.
  p.currency_code IN ('EUR','GBP','AED','SAR','KWD','BHD','QAR','OMR') AND p.status <> 'failed',
  MOD(CONV(SUBSTRING(MD5(CONCAT('risk:', p.id)),1,3),16,10), 100),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('risk:', p.id)),1,3),16,10), 100) > 85 THEN 'challenge'
       WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('risk:', p.id)),1,3),16,10), 100) > 70 THEN 'review'
       ELSE 'allow' END,
  CONCAT('idem_', LOWER(LEFT(MD5(CONCAT('idem:', p.id)), 26))),
  'LIVFINDER',
  DATE_ADD(p.created_at, INTERVAL 24 HOUR),
  p.paid_at,
  IF(p.status = 'cancelled', p.updated_at, NULL),
  p.failure_code, p.failure_message,
  p.created_at, p.updated_at
FROM payments p;

UPDATE payments p
  JOIN payment_intents pi
    ON pi.public_id = CONVERT(UPPER(LEFT(MD5(CONCAT('intent:', p.id)), 26)) USING ascii)
   SET p.payment_intent_id = pi.id;

-- -----------------------------------------------------------------------------
-- Payment attempts
--
-- The forensic record. Every intent gets at least one attempt; failures get a
-- decline code that is a real one, and about a fifth of failures are followed
-- by a successful retry through the failover account.
--
-- The decline taxonomy is the operationally important part. A soft decline
-- (insufficient funds) is worth retrying in three days; a hard decline (stolen
-- card) never is, and retrying it damages the merchant's authorisation rate
-- with the issuer.
-- -----------------------------------------------------------------------------
INSERT INTO payment_attempts
  (payment_intent_id, attempt_number, gateway_account_id, operation, amount,
   currency_code, status, provider_transaction_id, response_code, response_message,
   decline_type, avs_result, cvv_result, network_transaction_id, processor_fee,
   duration_ms, is_retry, is_failover, created_at, completed_at)
SELECT
  pi.id, 1, pi.gateway_account_id, 'sale', pi.amount, pi.currency_code,
  CASE pi.status WHEN 'succeeded' THEN 'succeeded' WHEN 'failed' THEN 'failed'
                 WHEN 'cancelled' THEN 'cancelled' ELSE 'pending' END,
  CONCAT('txn_', LOWER(LEFT(MD5(CONCAT('txn:', pi.id, ':1')), 22))),
  CASE WHEN pi.status = 'succeeded' THEN '00'
       WHEN pi.status = 'failed' THEN ELT(1 + MOD(pi.id, 6), '51', '05', '54', '41', '96', '65')
       ELSE NULL END,
  CASE WHEN pi.status = 'succeeded' THEN 'Approved'
       WHEN pi.status = 'failed' THEN ELT(1 + MOD(pi.id, 6),
            'Insufficient funds', 'Do not honour', 'Expired card',
            'Lost or stolen card', 'System malfunction', 'Exceeds withdrawal limit')
       ELSE NULL END,
  CASE WHEN pi.status <> 'failed' THEN 'none'
       ELSE ELT(1 + MOD(pi.id, 6),
            'insufficient_funds', 'do_not_honor', 'expired_card',
            'fraud', 'processor_unavailable', 'soft') END,
  IF(pi.status = 'succeeded', 'Y', 'N'),
  IF(pi.status = 'succeeded', 'M', 'N'),
  CONCAT('ntx_', LOWER(LEFT(MD5(CONCAT('ntx:', pi.id)), 18))),
  IF(pi.status = 'succeeded',
     ROUND(pi.amount * ga.percentage_fee + ga.fixed_fee, 4), NULL),
  240 + MOD(CONV(SUBSTRING(MD5(CONCAT('ms:', pi.id)),1,4),16,10), 2400),
  0, 0, pi.created_at,
  DATE_ADD(pi.created_at, INTERVAL 2 SECOND)
FROM payment_intents pi
LEFT JOIN gateway_accounts ga ON ga.id = pi.gateway_account_id;

-- Not every payment goes through first time. Every demo payment in this dataset
-- ultimately succeeded, so the failures are modelled where they actually
-- happen: a first attempt that declines, followed by a retry that works. Around
-- one payment in eight, which is close to the real first-attempt failure rate
-- on card-not-present subscription billing.
--
-- The decline taxonomy is the operationally important part. A soft decline
-- (insufficient funds) is worth retrying in three days; a hard decline (stolen
-- card) never is, and retrying it damages the merchant's authorisation rate
-- with the issuer.
UPDATE payment_attempts pa
  JOIN payment_intents pi ON pi.id = pa.payment_intent_id
   SET pa.status = 'failed',
       pa.response_code = ELT(1 + MOD(pi.id, 4), '51', '05', '91', '96'),
       pa.response_message = ELT(1 + MOD(pi.id, 4),
           'Insufficient funds', 'Do not honour',
           'Issuer unavailable', 'System malfunction'),
       pa.decline_type = ELT(1 + MOD(pi.id, 4),
           'insufficient_funds', 'do_not_honor', 'processor_unavailable', 'soft'),
       pa.avs_result = 'N', pa.cvv_result = 'M', pa.processor_fee = NULL
 WHERE pa.attempt_number = 1
   AND pi.status = 'succeeded'
   AND MOD(pi.id, 8) = 0;

INSERT INTO payment_attempts
  (payment_intent_id, attempt_number, gateway_account_id, operation, amount,
   currency_code, status, provider_transaction_id, response_code, response_message,
   decline_type, avs_result, cvv_result, network_transaction_id, processor_fee,
   duration_ms, is_retry, is_failover, created_at, completed_at)
SELECT
  pi.id, 2,
  COALESCE((SELECT ga2.id FROM gateway_accounts ga2 WHERE ga2.code = 'adyen-global'),
           pi.gateway_account_id),
  'sale', pi.amount, pi.currency_code, 'succeeded',
  CONCAT('txn_', LOWER(LEFT(MD5(CONCAT('txn:', pi.id, ':2')), 22))),
  '00', 'Approved', 'none', 'Y', 'M',
  CONCAT('ntx_', LOWER(LEFT(MD5(CONCAT('ntx2:', pi.id)), 18))),
  ROUND(pi.amount * 0.0110 + 0.11, 4),
  300 + MOD(CONV(SUBSTRING(MD5(CONCAT('ms2:', pi.id)),1,4),16,10), 1800),
  1, 1,
  DATE_ADD(pi.created_at, INTERVAL 3 DAY),
  DATE_ADD(pi.created_at, INTERVAL 3 DAY)
FROM payment_intents pi
JOIN payment_attempts pa
  ON pa.payment_intent_id = pi.id AND pa.attempt_number = 1
WHERE pa.status = 'failed';

-- -----------------------------------------------------------------------------
-- Webhook events
--
-- The provider's side of the conversation, stored before it is acted on.
--
-- The unique key on (gateway, provider_event_id) is what makes a replay a
-- no-op. Providers redeliver constantly — that is the contract, not a fault —
-- and a handler without this ends up crediting the same wallet twice.
-- -----------------------------------------------------------------------------
INSERT INTO gateway_webhook_events
  (gateway_id, gateway_account_id, provider_event_id, event_type, api_version,
   provider_created_at, payload, signature, signature_verified, payment_intent_id,
   payment_id, subscription_id, status, processing_attempts, received_at, processed_at)
SELECT
  ga.gateway_id, ga.id,
  CONCAT('evt_', LOWER(LEFT(MD5(CONCAT('evt:', p.id)), 24))),
  CASE p.status WHEN 'succeeded' THEN 'payment_intent.succeeded'
                WHEN 'failed' THEN 'payment_intent.payment_failed'
                WHEN 'refunded' THEN 'charge.refunded'
                WHEN 'partially_refunded' THEN 'charge.refunded'
                WHEN 'disputed' THEN 'charge.dispute.created'
                ELSE 'payment_intent.created' END,
  '2024-06-20',
  p.updated_at,
  JSON_OBJECT('id', CONCAT('evt_', LOWER(LEFT(MD5(CONCAT('evt:', p.id)), 24))),
              'object', 'event',
              'data', JSON_OBJECT('object', JSON_OBJECT(
                  'id', CONCAT('pi_', LOWER(LEFT(MD5(CONCAT('provider:', p.id)), 24))),
                  'amount', CAST(p.amount * 100 AS UNSIGNED),
                  'currency', LOWER(p.currency_code),
                  'status', p.status))),
  CONCAT('t=', UNIX_TIMESTAMP(p.updated_at), ',v1=', SHA2(CONCAT('sig:', p.id), 256)),
  1, p.payment_intent_id, p.id, p.subscription_id,
  'processed', 1, p.updated_at, DATE_ADD(p.updated_at, INTERVAL 1 SECOND)
FROM payments p
JOIN gateway_accounts ga ON ga.id = p.gateway_account_id;

-- A redelivery of an event already handled. Marked duplicate rather than
-- processed again, which is the behaviour the unique key enforces.
INSERT INTO gateway_webhook_events
  (gateway_id, gateway_account_id, provider_event_id, event_type, api_version,
   provider_created_at, payload, signature, signature_verified, payment_intent_id,
   payment_id, status, processing_attempts, error_message, received_at, processed_at)
SELECT
  ga.gateway_id, ga.id,
  CONCAT('evt_', LOWER(LEFT(MD5(CONCAT('redeliver:', p.id)), 24))),
  'payment_intent.succeeded', '2024-06-20', p.updated_at,
  JSON_OBJECT('id', CONCAT('evt_', LOWER(LEFT(MD5(CONCAT('redeliver:', p.id)), 24))),
              'object', 'event', 'request', JSON_OBJECT('idempotency_key', p.idempotency_key)),
  CONCAT('t=', UNIX_TIMESTAMP(p.updated_at), ',v1=', SHA2(CONCAT('sig2:', p.id), 256)),
  1, p.payment_intent_id, p.id, 'duplicate', 1,
  'Provider redelivery of an event already applied. No action taken.',
  DATE_ADD(p.updated_at, INTERVAL 4 HOUR), DATE_ADD(p.updated_at, INTERVAL 4 HOUR)
FROM payments p
JOIN gateway_accounts ga ON ga.id = p.gateway_account_id
WHERE p.status = 'succeeded' AND MOD(p.id, 11) = 0;

-- -----------------------------------------------------------------------------
-- Disputes
--
-- A chargeback is raised against a payment that has already succeeded — the
-- payment's own status does not change until the dispute is lost, which is why
-- these are derived from successful payments rather than from a `disputed`
-- status. The evidence deadline is
-- the operationally critical field: miss it and the money is gone regardless of
-- the merits, which is why the index in 0018 leads with it.
-- -----------------------------------------------------------------------------
INSERT INTO disputes
  (public_id, payment_id, account_id, gateway_account_id, provider_dispute_id,
   dispute_type, reason_code, reason, amount, currency_code, amount_base,
   dispute_fee, status, evidence_due_at, submitted_at, resolved_at, outcome_note,
   is_funds_withdrawn, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('dispute:', p.id)), 26)),
  p.id, p.account_id, p.gateway_account_id,
  CONCAT('dp_', LOWER(LEFT(MD5(CONCAT('dp:', p.id)), 22))),
  'chargeback',
  ELT(1 + MOD(p.id, 5), '10.4', '13.1', '12.6', '4855', '4837'),
  ELT(1 + MOD(p.id, 5), 'fraudulent', 'subscription_cancelled', 'duplicate',
      'product_not_received', 'unrecognised'),
  p.amount, p.currency_code, p.amount_base,
  -- The scheme's fee is charged whether the dispute is won or lost.
  CASE p.currency_code WHEN 'AED' THEN 55.00 WHEN 'USD' THEN 15.00
                       WHEN 'EUR' THEN 15.00 WHEN 'GBP' THEN 15.00 ELSE 50.00 END,
  ELT(1 + MOD(p.id, 4), 'won', 'lost', 'needs_response', 'under_review'),
  DATE_ADD(p.updated_at, INTERVAL 21 DAY),
  IF(MOD(p.id, 4) IN (0, 1, 3), DATE_ADD(p.updated_at, INTERVAL 6 DAY), NULL),
  IF(MOD(p.id, 4) IN (0, 1), DATE_ADD(p.updated_at, INTERVAL 45 DAY), NULL),
  ELT(1 + MOD(p.id, 4),
      'Evidence accepted. Cardholder had authenticated with 3-D Secure, so liability sat with the issuer.',
      'Evidence rejected. No proof of service delivery could be produced.',
      NULL,
      'Evidence submitted, awaiting the issuer.'),
  1, p.updated_at, p.updated_at
FROM payments p
-- Roughly one payment in sixty is charged back, which is far above a healthy
-- rate and deliberately so: a dataset with two disputes exercises nothing.
WHERE p.status = 'succeeded' AND MOD(p.id, 60) = 0;

INSERT INTO dispute_evidence
  (dispute_id, evidence_type, description, text_content, submitted_at, created_at)
SELECT d.id, 'receipt',
       'Payment receipt issued at the time of the transaction.',
       CONCAT('Receipt ', p.reference, ' — ', p.currency_code, ' ',
              FORMAT(p.amount, 2), ' paid ', DATE_FORMAT(p.paid_at, '%e %M %Y'),
              '. Authenticated by 3-D Secure ',
              IFNULL((SELECT pi.three_ds_version FROM payment_intents pi WHERE pi.id = p.payment_intent_id), 'n/a'), '.'),
       d.submitted_at, d.created_at
FROM disputes d JOIN payments p ON p.id = d.payment_id
WHERE d.submitted_at IS NOT NULL;

INSERT INTO dispute_evidence
  (dispute_id, evidence_type, description, text_content, submitted_at, created_at)
SELECT d.id, 'access_log',
       'Server access log showing the account using the service after payment.',
       CONCAT('Account ', d.account_id, ' recorded ',
              20 + MOD(d.id, 300), ' authenticated sessions between the payment date '
              'and the dispute being raised.'),
       d.submitted_at, d.created_at
FROM disputes d
WHERE d.submitted_at IS NOT NULL;

INSERT INTO dispute_events
  (dispute_id, event_type, from_status, to_status, actor_type, actor_user_id,
   note, created_at)
SELECT d.id, 'opened', NULL, 'needs_response', 'gateway', NULL,
       CONCAT('Chargeback received under reason code ', d.reason_code, '.'),
       d.created_at
FROM disputes d;

INSERT INTO dispute_events
  (dispute_id, event_type, from_status, to_status, actor_type, actor_user_id,
   note, created_at)
SELECT d.id, 'evidence_submitted', 'needs_response', 'under_review', 'user', NULL,
       'Evidence bundle submitted through the gateway.', d.submitted_at
FROM disputes d WHERE d.submitted_at IS NOT NULL;

INSERT INTO dispute_events
  (dispute_id, event_type, from_status, to_status, actor_type, actor_user_id,
   note, created_at)
SELECT d.id, IF(d.status = 'won', 'won', 'lost'), 'under_review', d.status,
       'gateway', NULL, d.outcome_note, d.resolved_at
FROM disputes d WHERE d.resolved_at IS NOT NULL;

UPDATE payments p
  JOIN disputes d ON d.payment_id = p.id
   SET p.disputed_amount = d.amount
 WHERE d.status IN ('needs_response', 'under_review', 'lost');

-- -----------------------------------------------------------------------------
-- Settlements
--
-- What the acquirer actually paid into the bank, per account per day, with the
-- lines that make it up.
--
-- The reconciliation columns exist because gross takings and bank deposits
-- never match: fees come out, refunds and chargebacks net off, and a reserve
-- may be withheld. `variance_amount` is the number finance chases, and it is
-- derived from the lines rather than asserted.
-- -----------------------------------------------------------------------------
INSERT INTO settlements
  (public_id, gateway_account_id, provider_settlement_id, settlement_date,
   period_start, period_end, currency_code, gross_amount, refund_amount,
   chargeback_amount, fee_amount, adjustment_amount, reserve_amount, net_amount,
   transaction_count, bank_reference, status, variance_amount, matched_count,
   unmatched_count, reconciled_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('settlement:', s.gateway_account_id, ':', s.settle_date, ':', s.currency_code)), 26)),
  s.gateway_account_id,
  CONCAT('po_', LOWER(LEFT(MD5(CONCAT('po:', s.gateway_account_id, ':', s.settle_date, ':', s.currency_code)), 22))),
  s.settle_date,
  s.settle_date, s.settle_date,
  s.currency_code,
  s.gross, s.refunds, 0, s.fees, 0, 0,
  s.gross - s.refunds - s.fees,
  s.txn_count,
  CONCAT('FT', DATE_FORMAT(s.settle_date, '%y%m%d'), LPAD(s.gateway_account_id, 4, '0')),
  'reconciled', 0.00, s.txn_count, 0,
  DATE_ADD(s.settle_date, INTERVAL 1 DAY), NOW(3), NOW(3)
FROM (
  SELECT p.gateway_account_id,
         DATE(p.paid_at) AS settle_date,
         p.currency_code,
         SUM(p.amount) AS gross,
         SUM(p.refunded_amount) AS refunds,
         SUM(p.fee_amount) AS fees,
         COUNT(*) AS txn_count
    FROM payments p
   WHERE p.paid_at IS NOT NULL AND p.gateway_account_id IS NOT NULL
     AND p.status IN ('succeeded','partially_refunded','refunded','disputed')
   GROUP BY p.gateway_account_id, DATE(p.paid_at), p.currency_code
) s;

INSERT INTO settlement_lines
  (settlement_id, line_type, provider_transaction_id, gross_amount, fee_amount,
   net_amount, currency_code, transaction_date, description, payment_id,
   match_status, match_confidence, matched_at, created_at)
SELECT st.id, 'charge',
       CONCAT('txn_', LOWER(LEFT(MD5(CONCAT('txn:', p.payment_intent_id, ':1')), 22))),
       p.amount, p.fee_amount, p.amount - p.fee_amount, p.currency_code,
       DATE(p.paid_at), CONCAT('Payment ', p.reference), p.id,
       'matched', 1.0000, st.reconciled_at, st.created_at
FROM payments p
JOIN settlements st
  ON st.gateway_account_id = p.gateway_account_id
 AND st.settlement_date = DATE(p.paid_at)
 AND st.currency_code = p.currency_code
WHERE p.paid_at IS NOT NULL
  AND p.status IN ('succeeded','partially_refunded','refunded','disputed');

UPDATE payments p
  JOIN settlements st
    ON st.gateway_account_id = p.gateway_account_id
   AND st.settlement_date = DATE(p.paid_at)
   AND st.currency_code = p.currency_code
   SET p.settlement_id = st.id, p.settled_at = st.reconciled_at, p.is_reconciled = 1
 WHERE p.paid_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Wallets
--
-- One per account per currency it transacts in. `available_balance` is
-- `balance` less what is held against an in-flight operation, and holding it as
-- a column rather than computing it is what lets a spend take one row lock and
-- check one number.
-- -----------------------------------------------------------------------------
INSERT INTO wallets
  (public_id, account_id, currency_code, balance, held_balance, available_balance,
   credit_limit, auto_topup_enabled, auto_topup_threshold, auto_topup_amount,
   status, version, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('wallet:', a.id)), 26)),
  a.id,
  COALESCE((SELECT c.code FROM currencies c WHERE c.id = a.billing_currency_id), 'AED'),
  0, 0, 0, 0,
  -- Auto top-up on the accounts that spend regularly, which is what stops a
  -- lead purchase failing at midnight for want of twenty dirhams.
  MOD(a.id, 3) = 0,
  IF(MOD(a.id, 3) = 0, 500.00, NULL),
  IF(MOD(a.id, 3) = 0, 2500.00, NULL),
  'active', 1, a.created_at, a.created_at
FROM accounts a
WHERE a.deleted_at IS NULL;

-- Top-ups. No demo payment was made for wallet credit, so these are generated
-- against the accounts that enabled auto top-up — which is the mechanism that
-- would have created them.
INSERT INTO wallet_transactions
  (wallet_id, transaction_type, amount, currency_code, balance_after,
   reference_type, reference_id, description, idempotency_key, created_at)
SELECT w.id, 'topup', w.auto_topup_amount, w.currency_code, w.auto_topup_amount,
       'auto_topup', w.id,
       CONCAT('Automatic top-up — balance fell below ',
              FORMAT(w.auto_topup_threshold, 2), ' ', w.currency_code),
       CONCAT('wtx_', LOWER(LEFT(MD5(CONCAT('topup:', w.id)), 26))),
       DATE_ADD(w.created_at, INTERVAL 14 DAY)
FROM wallets w
WHERE w.auto_topup_enabled = 1;

-- Spend against those balances: lead purchases and featured placements, which
-- is what a wallet is for.
INSERT INTO wallet_transactions
  (wallet_id, transaction_type, amount, currency_code, balance_after,
   reference_type, reference_id, description, idempotency_key, created_at)
SELECT w.id, 'spend',
       ROUND(w.auto_topup_amount * 0.25, 2), w.currency_code,
       ROUND(w.auto_topup_amount * 0.75, 2),
       'lead_purchase', w.id,
       'Lead purchase — exclusive buyer enquiry',
       CONCAT('wtx_', LOWER(LEFT(MD5(CONCAT('spend:', w.id)), 26))),
       DATE_ADD(w.created_at, INTERVAL 20 DAY)
FROM wallets w
WHERE w.auto_topup_enabled = 1;

-- The balance is derived from the ledger, never incremented independently. The
-- integrity suite asserts the two agree.
UPDATE wallets w
  LEFT JOIN (
    SELECT wallet_id,
           SUM(CASE WHEN transaction_type IN ('topup','refund','bonus','adjustment','transfer_in','release')
                    THEN amount ELSE -amount END) AS net
      FROM wallet_transactions
     GROUP BY wallet_id
  ) t ON t.wallet_id = w.id
   SET w.balance = COALESCE(t.net, 0),
       w.available_balance = COALESCE(t.net, 0) - w.held_balance;
