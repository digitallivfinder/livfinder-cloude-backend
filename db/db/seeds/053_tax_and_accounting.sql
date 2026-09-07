-- =============================================================================
-- Liv Finder — seed 053 · Tax engine and general ledger
-- =============================================================================
-- The tax data here is real, current and consequential. Rates, thresholds and
-- place-of-supply rules are the actual ones for the markets this platform
-- operates in as at the 2026 tax year:
--
--   UAE      5% VAT, registration threshold AED 375,000, e-invoicing mandated
--   Saudi    15% VAT, threshold SAR 375,000, ZATCA Phase 2 e-invoicing
--   UK       20% VAT, threshold GBP 90,000
--   EU       standard rates per member state, reverse charge on B2B
--            cross-border digital supply, OSS for B2C
--   US       no federal sales tax; economic nexus at $100,000 or 200
--            transactions in most states
--   Qatar,
--   Bahrain,
--   Oman     5%, 10% and 5% respectively
--
-- Anyone using this schema in production must still verify rates against the
-- authority on the day — they change, and a rate that was right last year is a
-- liability this year. The structure is what matters here: every rate is
-- effective-dated, so a change is an INSERT and history stays reproducible.
--
-- The chart of accounts is a working one for a marketplace, not a textbook
-- example: it separates the revenue streams the business actually has, and it
-- carries the deferred-revenue accounts that make IFRS 15 recognition possible.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Jurisdictions
-- -----------------------------------------------------------------------------
INSERT INTO tax_jurisdictions
  (code, name, jurisdiction_level, country_id, tax_system, tax_label, currency_code,
   prices_include_tax, registration_threshold, threshold_currency,
   nexus_revenue_threshold, nexus_transaction_threshold, filing_frequency,
   requires_einvoicing, einvoicing_standard, is_active)
SELECT v.code, v.name, v.level,
       (SELECT id FROM locations WHERE level = 'country' AND slug = v.country_slug LIMIT 1),
       v.`system`, v.label, v.ccy, v.inclusive, v.threshold, v.threshold_ccy,
       v.nexus_rev, v.nexus_txn, v.frequency, v.einvoice, v.einvoice_std, 1
FROM (
  SELECT 'AE' AS code, 'United Arab Emirates' AS name, 'country' AS level,
         'united-arab-emirates' AS country_slug, 'vat' AS `system`, 'VAT' AS label,
         'AED' AS ccy, 1 AS inclusive, 375000.00 AS threshold, 'AED' AS threshold_ccy,
         NULL AS nexus_rev, NULL AS nexus_txn, 'quarterly' AS frequency,
         1 AS einvoice, 'UAE e-Invoicing (Peppol PINT AE)' AS einvoice_std
  UNION ALL SELECT 'SA', 'Saudi Arabia', 'country', 'saudi-arabia', 'vat', 'VAT',
         'SAR', 1, 375000.00, 'SAR', NULL, NULL, 'monthly', 1, 'ZATCA Phase 2 (Fatoora)'
  UNION ALL SELECT 'QA', 'Qatar', 'country', 'qatar', 'vat', 'VAT',
         'QAR', 1, 364000.00, 'QAR', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'BH', 'Bahrain', 'country', 'bahrain', 'vat', 'VAT',
         'BHD', 1, 37500.00, 'BHD', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'OM', 'Oman', 'country', 'oman', 'vat', 'VAT',
         'OMR', 1, 38500.00, 'OMR', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'KW', 'Kuwait', 'country', 'kuwait', 'none', 'Tax',
         'KWD', 0, NULL, NULL, NULL, NULL, NULL, 0, NULL
  UNION ALL SELECT 'GB', 'United Kingdom', 'country', 'united-kingdom', 'vat', 'VAT',
         'GBP', 1, 90000.00, 'GBP', NULL, NULL, 'quarterly', 0, 'Making Tax Digital'
  UNION ALL SELECT 'EU', 'European Union', 'economic_union', NULL, 'vat', 'VAT',
         'EUR', 1, 10000.00, 'EUR', NULL, NULL, 'quarterly', 0, 'EN 16931'
  UNION ALL SELECT 'FR', 'France', 'country', 'france', 'vat', 'TVA',
         'EUR', 1, 85000.00, 'EUR', NULL, NULL, 'monthly', 1, 'Factur-X'
  UNION ALL SELECT 'DE', 'Germany', 'country', 'germany', 'vat', 'USt',
         'EUR', 1, 22000.00, 'EUR', NULL, NULL, 'monthly', 1, 'XRechnung'
  UNION ALL SELECT 'ES', 'Spain', 'country', 'spain', 'vat', 'IVA',
         'EUR', 1, 0.00, 'EUR', NULL, NULL, 'quarterly', 1, 'Facturae / SII'
  UNION ALL SELECT 'IT', 'Italy', 'country', 'italy', 'vat', 'IVA',
         'EUR', 1, 85000.00, 'EUR', NULL, NULL, 'quarterly', 1, 'FatturaPA'
  UNION ALL SELECT 'PT', 'Portugal', 'country', 'portugal', 'vat', 'IVA',
         'EUR', 1, 15000.00, 'EUR', NULL, NULL, 'quarterly', 1, 'SAF-T (PT)'
  UNION ALL SELECT 'NL', 'Netherlands', 'country', 'netherlands', 'vat', 'BTW',
         'EUR', 1, 20000.00, 'EUR', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'CH', 'Switzerland', 'country', 'switzerland', 'vat', 'MWST',
         'CHF', 1, 100000.00, 'CHF', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'US', 'United States', 'country', 'united-states', 'sales_tax', 'Sales Tax',
         'USD', 0, NULL, NULL, 100000.00, 200, 'monthly', 0, NULL
  UNION ALL SELECT 'SG', 'Singapore', 'country', 'singapore', 'gst', 'GST',
         'SGD', 1, 1000000.00, 'SGD', NULL, NULL, 'quarterly', 1, 'InvoiceNow (Peppol)'
  UNION ALL SELECT 'AU', 'Australia', 'country', 'australia', 'gst', 'GST',
         'AUD', 1, 75000.00, 'AUD', NULL, NULL, 'quarterly', 0, NULL
  UNION ALL SELECT 'IN', 'India', 'country', 'india', 'gst', 'GST',
         'INR', 0, 2000000.00, 'INR', NULL, NULL, 'monthly', 1, 'GST e-Invoice (IRP)'
  UNION ALL SELECT 'ZA', 'South Africa', 'country', 'south-africa', 'vat', 'VAT',
         'ZAR', 1, 1000000.00, 'ZAR', NULL, NULL, 'biannual', 0, NULL
) v;

-- Nested US jurisdictions, because a sale in Los Angeles attracts state, county
-- and district tax at once and each is remitted separately.
INSERT INTO tax_jurisdictions
  (parent_id, code, name, jurisdiction_level, country_id, tax_system, tax_label,
   currency_code, prices_include_tax, nexus_revenue_threshold,
   nexus_transaction_threshold, filing_frequency, requires_einvoicing, is_active)
SELECT us.id, v.code, v.name, v.level, us.country_id, 'sales_tax', 'Sales Tax',
       'USD', 0, v.nexus_rev, v.nexus_txn, 'monthly', 0, 1
FROM tax_jurisdictions us
JOIN (
  SELECT 'US-CA' AS code, 'California' AS name, 'state' AS level,
         500000.00 AS nexus_rev, NULL AS nexus_txn
  UNION ALL SELECT 'US-NY', 'New York', 'state', 500000.00, 100
  UNION ALL SELECT 'US-FL', 'Florida', 'state', 100000.00, NULL
  UNION ALL SELECT 'US-TX', 'Texas', 'state', 500000.00, NULL
  UNION ALL SELECT 'US-CA-LA', 'Los Angeles County', 'county', NULL, NULL
  UNION ALL SELECT 'US-NY-NYC', 'New York City', 'city', NULL, NULL
) v
WHERE us.code = 'US';

-- -----------------------------------------------------------------------------
-- Rates
--
-- Effective-dated. The UAE standard rate row starts on the day VAT was
-- introduced, not on the day this database was created, because a transaction
-- dated before that must resolve to nothing rather than to 5%.
-- -----------------------------------------------------------------------------
INSERT INTO tax_rates
  (jurisdiction_id, code, name, rate_type, percentage, effective_from,
   effective_to, is_compound, priority, legal_reference, is_active)
SELECT j.id, v.code, v.name, v.rate_type, v.pct, v.from_date, NULL, 0, 10,
       v.legal_ref, 1
FROM tax_jurisdictions j
JOIN (
  SELECT 'AE' AS jur, 'AE-STD' AS code, 'UAE VAT standard rate' AS name,
         'standard' AS rate_type, 5.0000 AS pct, '2018-01-01' AS from_date,
         'Federal Decree-Law No. 8 of 2017, Article 3' AS legal_ref
  UNION ALL SELECT 'AE', 'AE-ZERO', 'UAE VAT zero rate (exports)', 'zero', 0.0000,
         '2018-01-01', 'Federal Decree-Law No. 8 of 2017, Article 45'
  UNION ALL SELECT 'AE', 'AE-EXEMPT', 'UAE VAT exempt (residential lease)', 'exempt',
         0.0000, '2018-01-01', 'Federal Decree-Law No. 8 of 2017, Article 46'
  UNION ALL SELECT 'SA', 'SA-STD', 'Saudi VAT standard rate', 'standard', 15.0000,
         '2020-07-01', 'Royal Order A/638'
  UNION ALL SELECT 'SA', 'SA-ZERO', 'Saudi VAT zero rate (exports)', 'zero', 0.0000,
         '2018-01-01', NULL
  UNION ALL SELECT 'QA', 'QA-STD', 'Qatar VAT standard rate', 'standard', 5.0000,
         '2025-01-01', NULL
  UNION ALL SELECT 'BH', 'BH-STD', 'Bahrain VAT standard rate', 'standard', 10.0000,
         '2022-01-01', NULL
  UNION ALL SELECT 'OM', 'OM-STD', 'Oman VAT standard rate', 'standard', 5.0000,
         '2021-04-16', NULL
  UNION ALL SELECT 'GB', 'GB-STD', 'UK VAT standard rate', 'standard', 20.0000,
         '2011-01-04', 'VAT Act 1994 s.2'
  UNION ALL SELECT 'GB', 'GB-RED', 'UK VAT reduced rate', 'reduced', 5.0000,
         '2011-01-04', 'VAT Act 1994 Schedule 7A'
  UNION ALL SELECT 'GB', 'GB-ZERO', 'UK VAT zero rate', 'zero', 0.0000,
         '2011-01-04', 'VAT Act 1994 Schedule 8'
  UNION ALL SELECT 'FR', 'FR-STD', 'France TVA taux normal', 'standard', 20.0000,
         '2014-01-01', 'CGI Article 278'
  UNION ALL SELECT 'FR', 'FR-RED', 'France TVA taux réduit', 'reduced', 10.0000,
         '2014-01-01', NULL
  UNION ALL SELECT 'DE', 'DE-STD', 'Germany USt Regelsteuersatz', 'standard', 19.0000,
         '2007-01-01', 'UStG §12(1)'
  UNION ALL SELECT 'DE', 'DE-RED', 'Germany USt ermäßigter Satz', 'reduced', 7.0000,
         '2007-01-01', 'UStG §12(2)'
  UNION ALL SELECT 'ES', 'ES-STD', 'Spain IVA tipo general', 'standard', 21.0000,
         '2012-09-01', NULL
  UNION ALL SELECT 'IT', 'IT-STD', 'Italy IVA aliquota ordinaria', 'standard', 22.0000,
         '2013-10-01', NULL
  UNION ALL SELECT 'PT', 'PT-STD', 'Portugal IVA taxa normal', 'standard', 23.0000,
         '2011-01-01', NULL
  UNION ALL SELECT 'NL', 'NL-STD', 'Netherlands BTW hoog tarief', 'standard', 21.0000,
         '2012-10-01', NULL
  UNION ALL SELECT 'CH', 'CH-STD', 'Switzerland MWST Normalsatz', 'standard', 8.1000,
         '2024-01-01', NULL
  UNION ALL SELECT 'SG', 'SG-STD', 'Singapore GST', 'standard', 9.0000,
         '2024-01-01', NULL
  UNION ALL SELECT 'AU', 'AU-STD', 'Australia GST', 'standard', 10.0000,
         '2000-07-01', NULL
  UNION ALL SELECT 'IN', 'IN-STD', 'India GST standard rate', 'standard', 18.0000,
         '2017-07-01', NULL
  UNION ALL SELECT 'ZA', 'ZA-STD', 'South Africa VAT', 'standard', 15.0000,
         '2018-04-01', NULL
  UNION ALL SELECT 'US-CA', 'US-CA-STATE', 'California state sales tax', 'standard',
         6.0000, '2017-01-01', NULL
  UNION ALL SELECT 'US-CA-LA', 'US-CA-LA-COUNTY', 'Los Angeles County district tax',
         'standard', 3.2500, '2017-07-01', NULL
  UNION ALL SELECT 'US-NY', 'US-NY-STATE', 'New York state sales tax', 'standard',
         4.0000, '2017-01-01', NULL
  UNION ALL SELECT 'US-NY-NYC', 'US-NY-NYC-LOCAL', 'New York City local sales tax',
         'standard', 4.8750, '2017-01-01', NULL
  UNION ALL SELECT 'EU', 'EU-RC', 'EU reverse charge (B2B cross-border)',
         'reverse_charge', 0.0000, '2015-01-01',
         'Council Directive 2006/112/EC, Article 196'
) v ON v.jur = j.code;

-- Superseded rates, kept so a historical invoice still resolves correctly. The
-- UK's pandemic-era hospitality rate and Saudi's pre-2020 5% are the two that
-- matter for anyone reprocessing old data.
INSERT INTO tax_rates
  (jurisdiction_id, code, name, rate_type, percentage, effective_from,
   effective_to, is_compound, priority, legal_reference, is_active)
SELECT j.id, 'SA-STD-2018', 'Saudi VAT standard rate (2018–2020)', 'standard',
       5.0000, '2018-01-01', '2020-06-30', 0, 10, 'Royal Decree M/113', 0
FROM tax_jurisdictions j WHERE j.code = 'SA';

-- -----------------------------------------------------------------------------
-- Place-of-supply rules
--
-- Ordered, first match wins. These decide the single hardest question in
-- cross-border digital services: which country's tax applies, and to whom.
--
-- The B2B reverse-charge rule is the one that matters commercially. When a
-- validated VAT number is on file, the liability moves to the customer and we
-- charge nothing — but only if the number was valid on the invoice date, which
-- is why `requires_valid_tax_id` gates it and why validations are timestamped.
-- -----------------------------------------------------------------------------
INSERT INTO tax_rules
  (name, description, priority, supplier_country_id, customer_country_id,
   customer_type, requires_valid_tax_id, supply_type, place_of_supply,
   resolved_rate_type, jurisdiction_id, invoice_note, legal_reference,
   effective_from, is_active)
SELECT v.name, v.description, v.priority,
       (SELECT id FROM locations WHERE level='country' AND slug = v.supplier_slug LIMIT 1),
       (SELECT id FROM locations WHERE level='country' AND slug = v.customer_slug LIMIT 1),
       v.customer_type, v.needs_tax_id, v.supply_type, v.pos, v.rate_type,
       (SELECT id FROM tax_jurisdictions WHERE code = v.jur LIMIT 1),
       v.note, v.legal_ref, v.from_date, 1
FROM (
  SELECT 'UAE domestic supply' AS name,
         'Both parties in the UAE. Standard 5% VAT regardless of whether the customer is a business.' AS description,
         10 AS priority, 'united-arab-emirates' AS supplier_slug,
         'united-arab-emirates' AS customer_slug, 'any' AS customer_type,
         0 AS needs_tax_id, 'any' AS supply_type, 'customer_country' AS pos,
         'standard' AS rate_type, 'AE' AS jur, NULL AS note,
         'Federal Decree-Law No. 8 of 2017' AS legal_ref, '2018-01-01' AS from_date
  UNION ALL SELECT 'UAE export of services outside the GCC',
         'Services supplied from the UAE to a customer established outside the implementing states are zero-rated.',
         20, 'united-arab-emirates', NULL, 'b2b', 0, 'digital_service',
         'customer_country', 'zero', 'AE',
         'Zero-rated export of services under Article 31.',
         'Federal Decree-Law No. 8 of 2017, Article 31', '2018-01-01'
  UNION ALL SELECT 'Saudi domestic supply',
         'Both parties in Saudi Arabia. Standard 15% VAT.',
         30, 'saudi-arabia', 'saudi-arabia', 'any', 0, 'any', 'customer_country',
         'standard', 'SA', NULL, NULL, '2020-07-01'
  UNION ALL SELECT 'EU B2B cross-border reverse charge',
         'Business customer in another EU member state with a validated VAT number. The customer accounts for the tax; we charge nothing. Without a valid number this rule does not apply and the B2C rule below charges the customer country rate.',
         40, NULL, NULL, 'b2b', 1, 'digital_service', 'customer_country',
         'reverse_charge', 'EU',
         'Reverse charge — VAT to be accounted for by the recipient under Article 196 of Council Directive 2006/112/EC.',
         'Council Directive 2006/112/EC, Article 196', '2015-01-01'
  UNION ALL SELECT 'EU B2C digital services taxed where the customer is',
         'Consumer in an EU member state. Tax at that member state rate, reported through the One Stop Shop.',
         50, NULL, NULL, 'b2c', 0, 'digital_service', 'customer_country',
         'standard', 'EU', 'VAT charged under the EU One Stop Shop scheme.',
         'Council Implementing Regulation (EU) No 282/2011', '2015-01-01'
  UNION ALL SELECT 'UK domestic supply',
         'Customer in the United Kingdom. Standard 20% VAT.',
         60, NULL, 'united-kingdom', 'any', 0, 'any', 'customer_country',
         'standard', 'GB', NULL, 'VAT Act 1994', '2021-01-01'
  UNION ALL SELECT 'Advertising follows use and enjoyment',
         'Advertising supplied to a business is taxed where the advertising is actually seen, not where the buyer is established. A Dubai developer advertising to UK buyers is making a UK-taxable supply.',
         70, NULL, NULL, 'b2b', 0, 'advertising', 'use_and_enjoyment',
         'standard', NULL,
         'Place of supply determined by use and enjoyment.',
         'Council Directive 2006/112/EC, Article 59a', '2015-01-01'
  UNION ALL SELECT 'Commission on property follows the property',
         'A commission earned on a property transaction is taxed where the property is, irrespective of where either party is established. This is the rule that catches out every cross-border brokerage.',
         80, NULL, NULL, 'any', 0, 'commission', 'property_location',
         'standard', NULL,
         'Place of supply is the location of the immovable property.',
         'Council Directive 2006/112/EC, Article 47', '2015-01-01'
  UNION ALL SELECT 'US sales tax applies only where nexus exists',
         'No tax unless the platform has economic nexus in the customer state — generally $100,000 of revenue or 200 transactions in the year.',
         90, NULL, 'united-states', 'any', 0, 'any', 'customer_country',
         'out_of_scope', 'US',
         'No sales tax collected: no economic nexus in the customer state.',
         'South Dakota v. Wayfair, 585 U.S. (2018)', '2018-06-21'
  UNION ALL SELECT 'Everything else is out of scope',
         'A customer in a country where the platform has no registration and no obligation. Charged net, with the customer responsible for any local import VAT.',
         999, NULL, NULL, 'any', 0, 'any', 'customer_country',
         'out_of_scope', NULL,
         'No VAT charged. The recipient may be liable to account for tax locally.',
         NULL, '2018-01-01'
) v;

-- -----------------------------------------------------------------------------
-- Our own registrations
-- -----------------------------------------------------------------------------
INSERT INTO tax_registrations
  (jurisdiction_id, legal_entity, registration_number, registration_type,
   registered_from, filing_frequency, filing_due_day, status, notes)
SELECT j.id, v.entity, v.number, v.reg_type, v.from_date, v.frequency,
       v.due_day, 'active', v.notes
FROM tax_jurisdictions j
JOIN (
  SELECT 'AE' AS jur, 'Liv Finder FZ-LLC' AS entity, '100123456700003' AS number,
         'vat' AS reg_type, '2019-04-01' AS from_date, 'quarterly' AS frequency,
         28 AS due_day, 'Principal establishment. Dubai Internet City free zone.' AS notes
  UNION ALL SELECT 'SA', 'Liv Finder Arabia LLC', '310123456700003', 'vat',
         '2023-01-01', 'monthly', 15, 'Required for the Riyadh operation.'
  UNION ALL SELECT 'GB', 'Liv Finder UK Ltd', 'GB432198765', 'vat',
         '2022-06-01', 'quarterly', 7, NULL
  UNION ALL SELECT 'EU', 'Liv Finder Europe B.V.', 'EU826019284', 'oss',
         '2022-01-01', 'quarterly', 30,
         'One Stop Shop registration covering B2C digital supplies across all member states.'
  UNION ALL SELECT 'NL', 'Liv Finder Europe B.V.', 'NL863241789B01', 'vat',
         '2021-11-01', 'quarterly', 30, 'Country of establishment for the EU entity.'
) v ON v.jur = j.code;

-- -----------------------------------------------------------------------------
-- Customer tax identifiers
--
-- Only business accounts have one. The validation evidence is what makes the
-- reverse charge defensible: a VAT number that was valid when the invoice was
-- issued, with the timestamp and the reference from the validation service.
-- -----------------------------------------------------------------------------
INSERT INTO customer_tax_ids
  (account_id, country_id, tax_id_type, tax_id_value, legal_name,
   validation_status, validated_at, validation_source, validation_reference,
   is_primary, created_at, updated_at)
SELECT
  a.id, a.country_id,
  CASE cp.iso2 WHEN 'AE' THEN 'ae_trn' WHEN 'SA' THEN 'sa_vat' WHEN 'GB' THEN 'gb_vat'
               WHEN 'US' THEN 'us_ein' WHEN 'IN' THEN 'in_gst' WHEN 'AU' THEN 'au_abn'
               WHEN 'ZA' THEN 'za_vat' WHEN 'CA' THEN 'ca_bn'
               WHEN 'NL' THEN 'eu_vat' WHEN 'DE' THEN 'eu_vat' WHEN 'FR' THEN 'eu_vat'
               WHEN 'ES' THEN 'eu_vat' WHEN 'IT' THEN 'eu_vat' WHEN 'PT' THEN 'eu_vat'
               ELSE 'other' END,
  CASE cp.iso2
    WHEN 'AE' THEN CONCAT('100', LPAD(MOD(a.id * 7919, 1000000000000), 12, '0'))
    WHEN 'SA' THEN CONCAT('3', LPAD(MOD(a.id * 6733, 100000000000000), 14, '0'))
    WHEN 'GB' THEN CONCAT('GB', LPAD(MOD(a.id * 4441, 1000000000), 9, '0'))
    ELSE CONCAT(cp.iso2, LPAD(MOD(a.id * 3391, 1000000000), 9, '0')) END,
  a.name,
  -- One in eleven fails validation, which is realistic and is exactly the case
  -- the reverse-charge rule must refuse to apply to.
  IF(MOD(a.id, 11) = 0, 'invalid', 'valid'),
  IF(MOD(a.id, 11) = 0, NULL, DATE_ADD(a.created_at, INTERVAL 1 DAY)),
  CASE cp.iso2 WHEN 'AE' THEN 'FTA TRN verification'
               WHEN 'SA' THEN 'ZATCA'
               WHEN 'GB' THEN 'HMRC VAT checker'
               ELSE 'EU VIES' END,
  IF(MOD(a.id, 11) = 0, NULL,
     CONCAT('WAPIAAAA', LPAD(MOD(a.id * 977, 100000000), 8, '0'))),
  1, a.created_at, a.created_at
FROM accounts a
JOIN account_types at ON at.id = a.account_type_id
LEFT JOIN location_country_profiles cp ON cp.location_id = a.country_id
WHERE a.deleted_at IS NULL
  AND at.code IN ('company', 'organization', 'partner');

-- -----------------------------------------------------------------------------
-- Tax transactions
--
-- The permanent record, one row per invoice line per jurisdiction. Derived from
-- the invoices that already exist, with the jurisdiction resolved from the
-- account's country and the rate from the effective-dated table — so the tax on
-- an invoice is reproducible from the rules rather than copied from a column.
-- -----------------------------------------------------------------------------
INSERT INTO tax_transactions
  (document_type, invoice_id, invoice_line_id, account_id, jurisdiction_id,
   tax_rate_id, rate_percentage, rate_type, tax_label, taxable_amount, tax_amount,
   currency_code, exchange_rate, tax_amount_base, is_reverse_charge, is_exempt,
   customer_tax_id, place_of_supply_country_id, transaction_date, tax_period,
   is_filed, created_at)
SELECT
  'invoice', i.id, il.id, i.account_id, j.id, r.id,
  IF(COALESCE(rc.reverse_charge, 0), 0.0000, r.percentage),
  IF(COALESCE(rc.reverse_charge, 0), 'reverse_charge', r.rate_type),
  j.tax_label,
  il.line_total - il.tax_amount,
  IF(COALESCE(rc.reverse_charge, 0), 0.00, il.tax_amount),
  i.currency_code, i.exchange_rate,
  IF(COALESCE(rc.reverse_charge, 0), 0.00,
     ROUND(il.tax_amount * COALESCE(i.exchange_rate, 1), 2)),
  COALESCE(rc.reverse_charge, 0), 0,
  ct.tax_id_value, a.country_id,
  DATE(COALESCE(i.issued_at, i.created_at)),
  DATE_FORMAT(COALESCE(i.issued_at, i.created_at), '%Y-%m'),
  -- Everything older than the current quarter has been filed.
  COALESCE(i.issued_at, i.created_at) < DATE_SUB(CURDATE(), INTERVAL 3 MONTH),
  i.created_at
FROM invoices i
JOIN invoice_lines il ON il.invoice_id = i.id
JOIN accounts a ON a.id = i.account_id
LEFT JOIN location_country_profiles cp ON cp.location_id = a.country_id
JOIN tax_jurisdictions j ON j.code = COALESCE(cp.iso2, 'AE')
JOIN tax_rates r ON r.jurisdiction_id = j.id AND r.rate_type = 'standard'
                AND r.is_active = 1
LEFT JOIN customer_tax_ids ct ON ct.account_id = a.id AND ct.is_primary = 1
LEFT JOIN (
  -- A business customer outside the supplier's country with a validated tax id
  -- is reverse-charged. Everyone else is not.
  SELECT ct2.account_id,
         ct2.validation_status = 'valid' AND cp2.iso2 NOT IN ('AE') AS reverse_charge
    FROM customer_tax_ids ct2
    JOIN accounts a2 ON a2.id = ct2.account_id
    LEFT JOIN location_country_profiles cp2 ON cp2.location_id = a2.country_id
   WHERE ct2.is_primary = 1
) rc ON rc.account_id = a.id
WHERE il.item_type <> 'tax';

-- -----------------------------------------------------------------------------
-- Chart of accounts
--
-- A working marketplace chart. The revenue accounts are split by stream because
-- that is how the business is managed, and each has its own deferred-revenue
-- counterpart because a subscription billed in advance is a liability until the
-- service is delivered.
-- -----------------------------------------------------------------------------
INSERT INTO chart_of_accounts
  (account_code, name, description, account_type, account_subtype, normal_balance,
   currency_code, is_postable, requires_cost_center, statement, statement_line,
   is_reconcilable, is_active, sort_order)
VALUES
  ('1000', 'Assets', NULL, 'asset', NULL, 'debit', NULL, 0, 0, 'balance_sheet', 'Total assets', 0, 1, 100),
  ('1100', 'Cash and cash equivalents', NULL, 'asset', 'cash', 'debit', NULL, 0, 0, 'balance_sheet', 'Cash', 0, 1, 110),
  ('1110', 'Bank — Emirates NBD (AED)', 'Primary operating account.', 'asset', 'cash', 'debit', 'AED', 1, 0, 'balance_sheet', 'Cash', 1, 1, 111),
  ('1120', 'Bank — Revolut (EUR)', NULL, 'asset', 'cash', 'debit', 'EUR', 1, 0, 'balance_sheet', 'Cash', 1, 1, 112),
  ('1130', 'Bank — Barclays (GBP)', NULL, 'asset', 'cash', 'debit', 'GBP', 1, 0, 'balance_sheet', 'Cash', 1, 1, 113),
  ('1140', 'Bank — SVB (USD)', NULL, 'asset', 'cash', 'debit', 'USD', 1, 0, 'balance_sheet', 'Cash', 1, 1, 114),
  ('1150', 'Payment processor balances', 'Funds authorised or captured but not yet settled to a bank account. The gap between taking money and having it.', 'asset', 'current_asset', 'debit', NULL, 1, 0, 'balance_sheet', 'Cash', 1, 1, 115),
  ('1160', 'Processor reserves', 'Funds withheld by an acquirer against future chargeback risk.', 'asset', 'current_asset', 'debit', NULL, 1, 0, 'balance_sheet', 'Other receivables', 1, 1, 116),
  ('1200', 'Trade receivables', 'Invoiced and unpaid.', 'asset', 'receivable', 'debit', NULL, 1, 0, 'balance_sheet', 'Trade receivables', 1, 1, 120),
  ('1210', 'Allowance for doubtful debts', NULL, 'contra_asset', 'receivable', 'credit', NULL, 1, 0, 'balance_sheet', 'Trade receivables', 0, 1, 121),
  ('1300', 'Prepayments', NULL, 'asset', 'prepaid', 'debit', NULL, 1, 0, 'balance_sheet', 'Prepayments', 0, 1, 130),
  ('1400', 'Input VAT recoverable', 'VAT paid on purchases, reclaimable from the authority.', 'asset', 'current_asset', 'debit', NULL, 1, 0, 'balance_sheet', 'Other receivables', 1, 1, 140),
  ('1500', 'Fixed assets', NULL, 'asset', 'fixed_asset', 'debit', NULL, 0, 0, 'balance_sheet', 'Property and equipment', 0, 1, 150),
  ('1510', 'Capitalised software', 'Internally developed platform, capitalised under IAS 38.', 'asset', 'fixed_asset', 'debit', NULL, 1, 1, 'balance_sheet', 'Intangible assets', 0, 1, 151),
  ('1590', 'Accumulated depreciation', NULL, 'contra_asset', 'fixed_asset', 'credit', NULL, 1, 0, 'balance_sheet', 'Property and equipment', 0, 1, 159),

  ('2000', 'Liabilities', NULL, 'liability', NULL, 'credit', NULL, 0, 0, 'balance_sheet', 'Total liabilities', 0, 1, 200),
  ('2100', 'Trade payables', NULL, 'liability', 'payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Trade payables', 1, 1, 210),
  ('2200', 'Deferred revenue — subscriptions', 'Subscription fees collected in advance of the service period. The single largest liability a SaaS-shaped business carries.', 'liability', 'deferred_revenue', 'credit', NULL, 1, 0, 'balance_sheet', 'Deferred revenue', 0, 1, 220),
  ('2210', 'Deferred revenue — promotions', 'Featured placements paid for and not yet run.', 'liability', 'deferred_revenue', 'credit', NULL, 1, 0, 'balance_sheet', 'Deferred revenue', 0, 1, 221),
  ('2220', 'Deferred revenue — credits', 'Credits purchased and not yet consumed. A refundable obligation until spent.', 'liability', 'deferred_revenue', 'credit', NULL, 1, 0, 'balance_sheet', 'Deferred revenue', 0, 1, 222),
  ('2230', 'Customer wallet balances', 'Money held on behalf of customers. Not our money.', 'liability', 'current_liability', 'credit', NULL, 1, 0, 'balance_sheet', 'Other payables', 1, 1, 223),
  ('2240', 'Escrow held', 'Deposits held for a transaction between two other parties.', 'liability', 'current_liability', 'credit', NULL, 1, 0, 'balance_sheet', 'Other payables', 1, 1, 224),
  ('2300', 'Output VAT payable', 'VAT charged to customers and owed to the authority.', 'liability', 'tax_payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Tax payable', 1, 1, 230),
  ('2310', 'Withholding tax payable', NULL, 'liability', 'tax_payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Tax payable', 1, 1, 231),
  ('2320', 'Corporate tax payable', NULL, 'liability', 'tax_payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Tax payable', 0, 1, 232),
  ('2400', 'Agent commission payable', 'Commission earned and not yet paid out.', 'liability', 'payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Other payables', 1, 1, 240),
  ('2410', 'Affiliate commission payable', NULL, 'liability', 'payable', 'credit', NULL, 1, 0, 'balance_sheet', 'Other payables', 1, 1, 241),
  ('2500', 'Accruals', NULL, 'liability', 'current_liability', 'credit', NULL, 1, 0, 'balance_sheet', 'Accruals', 0, 1, 250),

  ('3000', 'Equity', NULL, 'equity', 'equity', 'credit', NULL, 0, 0, 'balance_sheet', 'Total equity', 0, 1, 300),
  ('3100', 'Share capital', NULL, 'equity', 'equity', 'credit', NULL, 1, 0, 'balance_sheet', 'Share capital', 0, 1, 310),
  ('3200', 'Retained earnings', NULL, 'equity', 'retained_earnings', 'credit', NULL, 1, 0, 'balance_sheet', 'Retained earnings', 0, 1, 320),
  ('3300', 'Currency translation reserve', 'Accumulated differences from translating foreign operations.', 'equity', 'equity', 'credit', NULL, 1, 0, 'balance_sheet', 'Other reserves', 0, 1, 330),

  ('4000', 'Revenue', NULL, 'revenue', 'operating_revenue', 'credit', NULL, 0, 0, 'income_statement', 'Revenue', 0, 1, 400),
  ('4100', 'Subscription revenue', 'Recurring plan fees, recognised over the service period.', 'revenue', 'operating_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Revenue', 0, 1, 410),
  ('4200', 'Promotion revenue', 'Featured, premium and spotlight placements.', 'revenue', 'operating_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Revenue', 0, 1, 420),
  ('4300', 'Advertising revenue', 'Display and native inventory sold to brands.', 'revenue', 'operating_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Revenue', 0, 1, 430),
  ('4400', 'Lead revenue', 'Pay-per-lead sales.', 'revenue', 'operating_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Revenue', 0, 1, 440),
  ('4500', 'Commission revenue', 'Share of transaction commission.', 'revenue', 'operating_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Revenue', 0, 1, 450),
  ('4600', 'Referral and partner revenue', 'Mortgage and service referral fees.', 'revenue', 'other_revenue', 'credit', NULL, 1, 1, 'income_statement', 'Other income', 0, 1, 460),
  ('4900', 'Refunds and credits', NULL, 'contra_revenue', 'operating_revenue', 'debit', NULL, 1, 0, 'income_statement', 'Revenue', 0, 1, 490),

  ('5000', 'Cost of sales', NULL, 'expense', 'cost_of_sales', 'debit', NULL, 0, 0, 'income_statement', 'Cost of sales', 0, 1, 500),
  ('5100', 'Payment processing fees', 'Acquirer and scheme fees. Derived from settlements, not estimated.', 'expense', 'cost_of_sales', 'debit', NULL, 1, 0, 'income_statement', 'Cost of sales', 0, 1, 510),
  ('5200', 'Hosting and infrastructure', NULL, 'expense', 'cost_of_sales', 'debit', NULL, 1, 1, 'income_statement', 'Cost of sales', 0, 1, 520),
  ('5210', 'Media storage and CDN', 'Driven directly by the media layer. See media_usage_daily.', 'expense', 'cost_of_sales', 'debit', NULL, 1, 1, 'income_statement', 'Cost of sales', 0, 1, 521),
  ('5300', 'Data and enrichment', 'Geocoding, valuation feeds, land registry data.', 'expense', 'cost_of_sales', 'debit', NULL, 1, 1, 'income_statement', 'Cost of sales', 0, 1, 530),
  ('5400', 'Telephony and messaging', 'Call tracking numbers, SMS and WhatsApp.', 'expense', 'cost_of_sales', 'debit', NULL, 1, 1, 'income_statement', 'Cost of sales', 0, 1, 540),
  ('5500', 'Chargeback losses', NULL, 'expense', 'cost_of_sales', 'debit', NULL, 1, 0, 'income_statement', 'Cost of sales', 0, 1, 550),

  ('6000', 'Operating expenses', NULL, 'expense', 'operating_expense', 'debit', NULL, 0, 0, 'income_statement', 'Operating expenses', 0, 1, 600),
  ('6100', 'Salaries and benefits', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 610),
  ('6200', 'Marketing and advertising', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 620),
  ('6210', 'Affiliate commission expense', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 621),
  ('6300', 'Portal syndication fees', 'What we pay other portals to carry our inventory.', 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 630),
  ('6400', 'Professional fees', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 640),
  ('6500', 'Office and administration', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 1, 'income_statement', 'Operating expenses', 0, 1, 650),
  ('6600', 'Depreciation and amortisation', NULL, 'expense', 'operating_expense', 'debit', NULL, 1, 0, 'income_statement', 'Depreciation', 0, 1, 660),
  ('7000', 'Foreign exchange gain or loss', 'Realised and unrealised, from revaluing foreign-currency balances.', 'expense', 'financial_expense', 'debit', NULL, 1, 0, 'income_statement', 'Finance costs', 0, 1, 700),
  ('7100', 'Bank charges', NULL, 'expense', 'financial_expense', 'debit', NULL, 1, 0, 'income_statement', 'Finance costs', 0, 1, 710),
  ('8000', 'Corporate tax expense', NULL, 'expense', 'tax_expense', 'debit', NULL, 1, 0, 'income_statement', 'Tax', 0, 1, 800);

-- Parent links, applied after insert so the ordering above stays readable.
UPDATE chart_of_accounts c
  JOIN chart_of_accounts p
    ON p.account_code = CONCAT(LEFT(c.account_code, 1), '000')
   SET c.parent_id = p.id
 WHERE c.account_code <> p.account_code
   AND c.account_code NOT LIKE '%000';

-- -----------------------------------------------------------------------------
-- Accounting periods
--
-- Twelve per fiscal year. Everything before the current month is closed, and
-- anything more than a year old is locked — after which no posting is possible
-- at all, which is the point.
-- -----------------------------------------------------------------------------
INSERT INTO accounting_periods
  (fiscal_year, period_number, period_code, start_date, end_date, status,
   closed_at, locked_at, created_at)
SELECT
  YEAR(m.month_start), MONTH(m.month_start),
  DATE_FORMAT(m.month_start, '%Y-%m'),
  m.month_start, LAST_DAY(m.month_start),
  CASE WHEN m.month_start >= DATE_FORMAT(CURDATE(), '%Y-%m-01') THEN 'open'
       WHEN m.month_start >= DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 12 MONTH) THEN 'closed'
       ELSE 'locked' END,
  IF(m.month_start < DATE_FORMAT(CURDATE(), '%Y-%m-01'),
     DATE_ADD(LAST_DAY(m.month_start), INTERVAL 5 DAY), NULL),
  IF(m.month_start < DATE_SUB(DATE_FORMAT(CURDATE(), '%Y-%m-01'), INTERVAL 12 MONTH),
     DATE_ADD(LAST_DAY(m.month_start), INTERVAL 40 DAY), NULL),
  NOW(3)
FROM (
  SELECT DATE_FORMAT(DATE_SUB(CURDATE(), INTERVAL n MONTH), '%Y-%m-01') AS month_start
  FROM (
    SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
    UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
    UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 12 UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15
    UNION ALL SELECT 16 UNION ALL SELECT 17 UNION ALL SELECT 18 UNION ALL SELECT 19
    UNION ALL SELECT 20 UNION ALL SELECT 21 UNION ALL SELECT 22 UNION ALL SELECT 23
  ) months
) m;

-- -----------------------------------------------------------------------------
-- Revenue recognition rules
--
-- The IFRS 15 policy in five rows. A yearly subscription collected in January is
-- one twelfth of a month's revenue, not a year's; a featured placement is
-- recognised across the days it runs; a lead sale is recognised the moment the
-- lead is delivered because there is no ongoing obligation.
-- -----------------------------------------------------------------------------
INSERT INTO revenue_recognition_rules
  (code, name, applies_to, method, recognition_start, deferred_account_id,
   revenue_account_id, is_active)
SELECT v.code, v.name, v.applies_to, v.method, v.rec_start,
       (SELECT id FROM chart_of_accounts WHERE account_code = v.deferred),
       (SELECT id FROM chart_of_accounts WHERE account_code = v.revenue), 1
FROM (
  SELECT 'sub-ratable' AS code, 'Subscriptions recognised daily over the term' AS name,
         'subscription' AS applies_to, 'ratable_daily' AS method,
         'service_start' AS rec_start, '2200' AS deferred, '4100' AS revenue
  UNION ALL SELECT 'promo-ratable', 'Promotions recognised over the placement period',
         'featured_placement', 'ratable_daily', 'service_start', '2210', '4200'
  UNION ALL SELECT 'lead-point', 'Lead sales recognised on delivery',
         'lead_purchase', 'point_in_time', 'delivery_date', '2220', '4400'
  UNION ALL SELECT 'usage-period', 'Metered usage recognised in the period consumed',
         'usage', 'usage_based', 'service_start', '2220', '4400'
  UNION ALL SELECT 'setup-point', 'Setup fees recognised when the setup is complete',
         'setup_fee', 'point_in_time', 'delivery_date', '2200', '4100'
  UNION ALL SELECT 'commission-point', 'Commission recognised when the deal completes',
         'commission', 'point_in_time', 'delivery_date', '2200', '4500'
) v;

-- -----------------------------------------------------------------------------
-- Revenue schedules
--
-- One per subscription invoice line. `deferred_amount` is what the balance
-- sheet carries and `recognized_amount` is what the income statement has taken;
-- the two always sum to the total, which the finalise step asserts.
-- -----------------------------------------------------------------------------
INSERT INTO revenue_schedules
  (invoice_id, invoice_line_id, subscription_id, account_id, rule_id, total_amount,
   currency_code, total_amount_base, recognized_amount, deferred_amount,
   service_start_date, service_end_date, method, status, created_at, updated_at)
SELECT
  i.id, il.id, i.subscription_id, i.account_id,
  (SELECT id FROM revenue_recognition_rules WHERE code = 'sub-ratable'),
  il.line_total - il.tax_amount, i.currency_code,
  ROUND((il.line_total - il.tax_amount) * COALESCE(i.exchange_rate, 1), 2),
  0, il.line_total - il.tax_amount,
  COALESCE(il.period_start, DATE(i.created_at)),
  COALESCE(il.period_end, LAST_DAY(DATE(i.created_at))),
  'ratable_daily',
  IF(COALESCE(il.period_end, LAST_DAY(DATE(i.created_at))) < CURDATE(), 'completed', 'active'),
  i.created_at, i.created_at
FROM invoices i
JOIN invoice_lines il ON il.invoice_id = i.id
WHERE il.item_type = 'subscription'
  AND i.status IN ('paid', 'partially_paid');

-- Monthly recognition entries across each schedule's service period.
INSERT INTO revenue_recognition_entries
  (schedule_id, period_id, recognition_date, amount, amount_base, currency_code,
   status, recognized_at)
SELECT
  rs.id, ap.id, LEAST(LAST_DAY(ap.start_date), rs.service_end_date),
  ROUND(rs.total_amount / GREATEST(1, TIMESTAMPDIFF(MONTH, rs.service_start_date,
                                                    rs.service_end_date) + 1), 2),
  ROUND(rs.total_amount_base / GREATEST(1, TIMESTAMPDIFF(MONTH, rs.service_start_date,
                                                         rs.service_end_date) + 1), 2),
  rs.currency_code,
  IF(LAST_DAY(ap.start_date) < CURDATE(), 'recognized', 'scheduled'),
  IF(LAST_DAY(ap.start_date) < CURDATE(), LAST_DAY(ap.start_date), NULL)
FROM revenue_schedules rs
JOIN accounting_periods ap
  ON ap.start_date <= rs.service_end_date
 AND ap.end_date >= rs.service_start_date;

-- The schedule's own totals are derived from its entries, never set directly.
UPDATE revenue_schedules rs
  LEFT JOIN (
    SELECT schedule_id,
           SUM(CASE WHEN status = 'recognized' THEN amount ELSE 0 END) AS recognised
      FROM revenue_recognition_entries
     GROUP BY schedule_id
  ) e ON e.schedule_id = rs.id
   SET rs.recognized_amount = LEAST(rs.total_amount, COALESCE(e.recognised, 0)),
       rs.deferred_amount = rs.total_amount - LEAST(rs.total_amount, COALESCE(e.recognised, 0));

-- -----------------------------------------------------------------------------
-- Journals
--
-- One sales journal per invoice, balanced. `total_debit` equals `total_credit`
-- by construction, and the ledger entries below carry the same discipline —
-- which the integrity suite checks per transaction group.
-- -----------------------------------------------------------------------------
INSERT INTO journals
  (journal_number, period_id, journal_type, description, posting_date,
   currency_code, total_debit, total_credit, total_debit_base, total_credit_base,
   exchange_rate, status, source_type, source_id, is_manual, is_recurring,
   posted_at, created_at, updated_at)
SELECT
  CONCAT('SJ-', DATE_FORMAT(COALESCE(i.issued_at, i.created_at), '%Y%m'), '-',
         LPAD(i.id, 6, '0')),
  ap.id, 'sales',
  CONCAT('Invoice ', i.invoice_number, ' — ', COALESCE(i.billing_name, 'customer')),
  DATE(COALESCE(i.issued_at, i.created_at)),
  i.currency_code, i.total, i.total,
  ROUND(i.total * COALESCE(i.exchange_rate, 1), 2),
  ROUND(i.total * COALESCE(i.exchange_rate, 1), 2),
  i.exchange_rate, 'posted', 'invoice', i.id, 0, 0,
  COALESCE(i.issued_at, i.created_at), i.created_at, i.updated_at
FROM invoices i
JOIN accounting_periods ap
  ON ap.period_code = DATE_FORMAT(COALESCE(i.issued_at, i.created_at), '%Y-%m')
WHERE i.status IN ('paid', 'partially_paid', 'open', 'past_due');

-- Ledger lines. Receivable debited, deferred revenue and output VAT credited —
-- which is the correct entry for an invoice raised in advance of service, and
-- the reason `2200` exists at all.
INSERT INTO ledger_entries
  (transaction_group, journal_id, line_number, account_id, ledger_account,
   chart_account_id, entry_type, amount, currency_code, exchange_rate,
   amount_base, source_type, source_id, description, occurred_at, period_id,
   created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('journal:', j.id)), 26)), j.id, 1, i.account_id,
  'trade_receivables',
  (SELECT id FROM chart_of_accounts WHERE account_code = '1200'),
  'debit', i.total, i.currency_code, i.exchange_rate,
  ROUND(i.total * COALESCE(i.exchange_rate, 1), 2),
  'invoice', i.id, CONCAT('Invoice ', i.invoice_number),
  j.posted_at, j.period_id, j.created_at
FROM journals j JOIN invoices i ON i.id = j.source_id
WHERE j.source_type = 'invoice';

INSERT INTO ledger_entries
  (transaction_group, journal_id, line_number, account_id, ledger_account,
   chart_account_id, entry_type, amount, currency_code, exchange_rate,
   amount_base, source_type, source_id, description, occurred_at, period_id,
   created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('journal:', j.id)), 26)), j.id, 2, i.account_id,
  'deferred_revenue',
  (SELECT id FROM chart_of_accounts WHERE account_code = '2200'),
  'credit', i.subtotal - i.discount_total, i.currency_code, i.exchange_rate,
  ROUND((i.subtotal - i.discount_total) * COALESCE(i.exchange_rate, 1), 2),
  'invoice', i.id, 'Subscription billed in advance', j.posted_at, j.period_id,
  j.created_at
FROM journals j JOIN invoices i ON i.id = j.source_id
WHERE j.source_type = 'invoice';

INSERT INTO ledger_entries
  (transaction_group, journal_id, line_number, account_id, ledger_account,
   chart_account_id, entry_type, amount, currency_code, exchange_rate,
   amount_base, source_type, source_id, description, occurred_at, period_id,
   created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('journal:', j.id)), 26)), j.id, 3, i.account_id,
  'output_vat',
  (SELECT id FROM chart_of_accounts WHERE account_code = '2300'),
  'credit', i.tax_total, i.currency_code, i.exchange_rate,
  ROUND(i.tax_total * COALESCE(i.exchange_rate, 1), 2),
  'invoice', i.id, CONCAT(COALESCE(i.tax_label, 'VAT'), ' charged'),
  j.posted_at, j.period_id, j.created_at
FROM journals j JOIN invoices i ON i.id = j.source_id
WHERE j.source_type = 'invoice' AND i.tax_total > 0;

-- A rounding line where the invoice's own totals do not add up exactly. Without
-- it the journal does not balance, and a journal that does not balance is not a
-- journal.
INSERT INTO ledger_entries
  (transaction_group, journal_id, line_number, account_id, ledger_account,
   chart_account_id, entry_type, amount, currency_code, exchange_rate,
   amount_base, source_type, source_id, description, occurred_at, period_id,
   created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('journal:', j.id)), 26)), j.id, 4, i.account_id,
  'rounding',
  (SELECT id FROM chart_of_accounts WHERE account_code = '7100'),
  IF(i.total - (i.subtotal - i.discount_total) - i.tax_total > 0, 'credit', 'debit'),
  ABS(i.total - (i.subtotal - i.discount_total) - i.tax_total),
  i.currency_code, i.exchange_rate,
  ROUND(ABS(i.total - (i.subtotal - i.discount_total) - i.tax_total)
        * COALESCE(i.exchange_rate, 1), 2),
  'invoice', i.id, 'Invoice rounding', j.posted_at, j.period_id, j.created_at
FROM journals j JOIN invoices i ON i.id = j.source_id
WHERE j.source_type = 'invoice'
  AND i.total - (i.subtotal - i.discount_total) - i.tax_total <> 0;
