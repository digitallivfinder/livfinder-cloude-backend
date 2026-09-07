-- =============================================================================
-- Liv Finder — demo seed · subscriptions, invoices, payments, payouts and the ledger
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
-- Regenerate with:  python3 db/tools/build_demo_seed.py
--
-- Commercial data for the portal's Payments, Billing and Payouts screens
-- and the admin Transactions view.
-- 
-- The audit found all three reporting pagination totals larger than their
-- real data, so page 2 rendered empty. Here the rows are the total: no
-- pageInfo figure is stored anywhere, and the screens COUNT what exists.
-- 
-- Every payment and payout also writes balanced debit/credit rows to
-- ledger_entries, so SUM(debit) = SUM(credit) per transaction_group.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(1, '01K2F2DKG071SZ2TKQKEEQ5WF9', 1, 11, 'card', 'stripe', 'pm_01k2f2dkg0vtb9kdd1s26g8zzc', 'mastercard', '6738', 7, 2031, 'Prime Properties', 1, 'active', '2025-12-02 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(1, '01K2F2DKG01S0N8Q8R612T65FE', 1, 6, 'active', 149000.0, 'USD', 547202.5, 'yearly', '2026-05-14 09:00:00', '2027-05-14 09:00:00', NULL, NULL, 1, 1, 'sub_01k2f2dkg0nkxs2e92zf8gk83m', '2025-02-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(1, '01K2F2DKG0EXF31CNQFRE76M4F', 'LF-INV-2026000001', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2025-05-14 09:00:00', '2025-05-28 09:00:00', '2025-05-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000001.pdf', '2025-05-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(1, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-05-14', '2026-05-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(1, '01K2F2DKG0QTRR9S1DE6MK9NSD', 'PAY-60001', 1, 1, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0e2th6vjr3zqrv2gc', 'idem-01K2F2DKG0C6X3H9VEHHBMK761', 'https://cdn.livfinder.com/receipts/PAY-60001.pdf', '2025-05-17 09:00:00', '2025-05-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG058CXKZYHS6XC9QHV', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 1, 'Subscription payment 1', '2025-05-20 09:00:00'),
('01K2F2DKG058CXKZYHS6XC9QHV', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 1, 'Subscription payment 1', '2025-05-16 09:00:00'),
('01K2F2DKG058CXKZYHS6XC9QHV', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 1, 'Subscription payment 1', '2025-05-15 09:00:00'),
('01K2F2DKG058CXKZYHS6XC9QHV', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 1, 'Subscription payment 1', '2025-05-21 09:00:00'),
('01K2F2DKG058CXKZYHS6XC9QHV', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 1, 'Subscription payment 1', '2025-05-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(2, '01K2F2DKG026JYPY1WQ75XDP5A', 'LF-INV-2026000002', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2024-05-14 09:00:00', '2024-05-28 09:00:00', '2024-05-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000002.pdf', '2024-05-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(2, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-05-14', '2025-05-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(2, '01K2F2DKG0DWAR5H31NZ9TZNFN', 'PAY-60002', 1, 2, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0w1wsmcee0yb19s71', 'idem-01K2F2DKG060TXV09235S63ANV', 'https://cdn.livfinder.com/receipts/PAY-60002.pdf', '2024-05-19 09:00:00', '2024-05-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG001HA85ZAS0S7AJJQ', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 2, 'Subscription payment 2', '2024-05-16 09:00:00'),
('01K2F2DKG001HA85ZAS0S7AJJQ', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 2, 'Subscription payment 2', '2024-05-22 09:00:00'),
('01K2F2DKG001HA85ZAS0S7AJJQ', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 2, 'Subscription payment 2', '2024-05-16 09:00:00'),
('01K2F2DKG001HA85ZAS0S7AJJQ', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 2, 'Subscription payment 2', '2024-05-24 09:00:00'),
('01K2F2DKG001HA85ZAS0S7AJJQ', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 2, 'Subscription payment 2', '2024-05-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(3, '01K2F2DKG0KNQ460BWEVTR1BKY', 'LF-INV-2026000003', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2023-05-15 09:00:00', '2023-05-29 09:00:00', '2023-05-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000003.pdf', '2023-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(3, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-05-15', '2024-05-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(3, '01K2F2DKG0XSM6SN61FYW09HX1', 'PAY-60003', 1, 3, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0k2r7e276mt7xqrhx', 'idem-01K2F2DKG0KFH7708RC4KHDJ9M', 'https://cdn.livfinder.com/receipts/PAY-60003.pdf', '2023-05-20 09:00:00', '2023-05-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0C4BC4FWQ919JR4R1', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 3, 'Subscription payment 3', '2023-05-18 09:00:00'),
('01K2F2DKG0C4BC4FWQ919JR4R1', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 3, 'Subscription payment 3', '2023-05-25 09:00:00'),
('01K2F2DKG0C4BC4FWQ919JR4R1', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 3, 'Subscription payment 3', '2023-05-25 09:00:00'),
('01K2F2DKG0C4BC4FWQ919JR4R1', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 3, 'Subscription payment 3', '2023-05-21 09:00:00'),
('01K2F2DKG0C4BC4FWQ919JR4R1', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 3, 'Subscription payment 3', '2023-05-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(4, '01K2F2DKG0EBDQYYH5FMF5VT7W', 'LF-INV-2026000004', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2022-05-15 09:00:00', '2022-05-29 09:00:00', '2022-05-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000004.pdf', '2022-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(4, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-05-15', '2023-05-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(4, '01K2F2DKG0BK8EY0TX27KPJ8JE', 'PAY-60004', 1, 4, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02vtq924qjt9e0zbc', 'idem-01K2F2DKG0YP8MBZTVR586ZADD', 'https://cdn.livfinder.com/receipts/PAY-60004.pdf', '2022-05-15 09:00:00', '2022-05-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG057VFC37E5PYB1E0M', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 4, 'Subscription payment 4', '2022-05-15 09:00:00'),
('01K2F2DKG057VFC37E5PYB1E0M', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 4, 'Subscription payment 4', '2022-05-23 09:00:00'),
('01K2F2DKG057VFC37E5PYB1E0M', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 4, 'Subscription payment 4', '2022-05-27 09:00:00'),
('01K2F2DKG057VFC37E5PYB1E0M', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 4, 'Subscription payment 4', '2022-05-24 09:00:00'),
('01K2F2DKG057VFC37E5PYB1E0M', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 4, 'Subscription payment 4', '2022-05-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(5, '01K2F2DKG0WH2HWR97Q06A1DYV', 'LF-INV-2026000005', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2021-05-15 09:00:00', '2021-05-29 09:00:00', '2021-05-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000005.pdf', '2021-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(5, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-05-15', '2022-05-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(5, '01K2F2DKG0WHMK5AYP07RABTJ4', 'PAY-60005', 1, 5, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qm290kbqnabhftzx', 'idem-01K2F2DKG0GJPVJ1RA300MJG3D', 'https://cdn.livfinder.com/receipts/PAY-60005.pdf', '2021-05-15 09:00:00', '2021-05-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GF3WJNHABSZTEG4N', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 5, 'Subscription payment 5', '2021-05-15 09:00:00'),
('01K2F2DKG0GF3WJNHABSZTEG4N', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 5, 'Subscription payment 5', '2021-05-18 09:00:00'),
('01K2F2DKG0GF3WJNHABSZTEG4N', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 5, 'Subscription payment 5', '2021-05-20 09:00:00'),
('01K2F2DKG0GF3WJNHABSZTEG4N', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 5, 'Subscription payment 5', '2021-05-24 09:00:00'),
('01K2F2DKG0GF3WJNHABSZTEG4N', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 5, 'Subscription payment 5', '2021-05-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(6, '01K2F2DKG0CDZQ1S2VD34VM9JX', 'LF-INV-2026000006', 1, 1, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Prime Properties', 'billing@example.com', '2020-05-15 09:00:00', '2020-05-29 09:00:00', '2020-05-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000006.pdf', '2020-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(6, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-05-15', '2021-05-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(6, '01K2F2DKG05PG19ZARFM94EDC3', 'PAY-60006', 1, 6, 1, 1, 11, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0nfsqx80xsm88mrjx', 'idem-01K2F2DKG0A8Y8PRS2ZQZDQ8HG', 'https://cdn.livfinder.com/receipts/PAY-60006.pdf', '2020-05-24 09:00:00', '2020-05-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08XNZC5T0RGN17AY1', 1, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 6, 'Subscription payment 6', '2020-05-24 09:00:00'),
('01K2F2DKG08XNZC5T0RGN17AY1', 1, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 6, 'Subscription payment 6', '2020-05-15 09:00:00'),
('01K2F2DKG08XNZC5T0RGN17AY1', 1, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 6, 'Subscription payment 6', '2020-05-25 09:00:00'),
('01K2F2DKG08XNZC5T0RGN17AY1', 1, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 6, 'Subscription payment 6', '2020-05-23 09:00:00'),
('01K2F2DKG08XNZC5T0RGN17AY1', 1, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 6, 'Subscription payment 6', '2020-05-21 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(1, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-08-07 09:00:00'),
(1, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-10 09:00:00'),
(1, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-08-10 09:00:00'),
(1, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-07 09:00:00'),
(1, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-13 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(2, '01K2F2DKG0SCXJBTN4TKXTY6Y1', 2, 15, 'card', 'stripe', 'pm_01k2f2dkg0110x62rj08bghg4p', 'visa', '7639', 11, 2027, 'Luxhabitat Real Estate', 1, 'active', '2025-03-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(2, '01K2F2DKG0Z9PGM11P9V0KJP9N', 2, 4, 'past_due', 2499.0, 'GBP', 11677.58, 'monthly', '2026-08-15 09:00:00', '2026-09-14 09:00:00', NULL, NULL, 1, 2, 'sub_01k2f2dkg05ktvx91fgmtv6nv4', '2025-02-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(7, '01K2F2DKG0RE2GCS6RJSHH2Q6S', 'LF-INV-2026000007', 2, 2, 'open', 2499.0, 0, 124.95, 2623.95, 0, 2623.95, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-07-16 09:00:00', '2026-07-30 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000007.pdf', '2026-07-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(7, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-16', '2026-08-15', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(8, '01K2F2DKG0F5X52562S9KB1TNY', 'LF-INV-2026000008', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-06-16 09:00:00', '2026-06-30 09:00:00', '2026-06-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000008.pdf', '2026-06-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(8, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-16', '2026-07-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(7, '01K2F2DKG0G3H7HFH1SKTV2KNK', 'PAY-60007', 2, 8, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dszmzgnrpnwxvp6e', 'idem-01K2F2DKG0X9ZNJZWYBM8N86YH', 'https://cdn.livfinder.com/receipts/PAY-60007.pdf', '2026-06-18 09:00:00', '2026-06-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0SRTPS1PS7Z6XT7R6', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 7, 'Subscription payment 8', '2026-06-19 09:00:00'),
('01K2F2DKG0SRTPS1PS7Z6XT7R6', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 7, 'Subscription payment 8', '2026-06-24 09:00:00'),
('01K2F2DKG0SRTPS1PS7Z6XT7R6', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 7, 'Subscription payment 8', '2026-06-17 09:00:00'),
('01K2F2DKG0SRTPS1PS7Z6XT7R6', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 7, 'Subscription payment 8', '2026-06-17 09:00:00'),
('01K2F2DKG0SRTPS1PS7Z6XT7R6', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 7, 'Subscription payment 8', '2026-06-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(9, '01K2F2DKG0QQJCQZHWJ7BJ87RR', 'LF-INV-2026000009', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-05-17 09:00:00', '2026-05-31 09:00:00', '2026-05-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000009.pdf', '2026-05-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(9, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-17', '2026-06-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(8, '01K2F2DKG0GATX8V339EYR6DSN', 'PAY-60008', 2, 9, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0px5z9xbvwdj3ke74', 'idem-01K2F2DKG0YHHCN7ZS5HG4C3QY', 'https://cdn.livfinder.com/receipts/PAY-60008.pdf', '2026-05-18 09:00:00', '2026-05-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RHHN7YD2FET6XHTP', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 8, 'Subscription payment 9', '2026-05-27 09:00:00'),
('01K2F2DKG0RHHN7YD2FET6XHTP', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 8, 'Subscription payment 9', '2026-05-25 09:00:00'),
('01K2F2DKG0RHHN7YD2FET6XHTP', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 8, 'Subscription payment 9', '2026-05-27 09:00:00'),
('01K2F2DKG0RHHN7YD2FET6XHTP', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 8, 'Subscription payment 9', '2026-05-27 09:00:00'),
('01K2F2DKG0RHHN7YD2FET6XHTP', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 8, 'Subscription payment 9', '2026-05-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(10, '01K2F2DKG0YQQNB9Q9VV8VPAGJ', 'LF-INV-2026000010', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-04-17 09:00:00', '2026-05-01 09:00:00', '2026-04-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000010.pdf', '2026-04-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(10, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-17', '2026-05-17', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(9, '01K2F2DKG0EKHGKYQ73FXA1S01', 'PAY-60009', 2, 10, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg08px7tgkdq928jxc0', 'idem-01K2F2DKG0BFJWV501XGPG7793', 'https://cdn.livfinder.com/receipts/PAY-60009.pdf', '2026-04-19 09:00:00', '2026-04-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XWCSKHQP45V2QB6G', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 9, 'Subscription payment 10', '2026-04-18 09:00:00'),
('01K2F2DKG0XWCSKHQP45V2QB6G', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 9, 'Subscription payment 10', '2026-04-25 09:00:00'),
('01K2F2DKG0XWCSKHQP45V2QB6G', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 9, 'Subscription payment 10', '2026-04-17 09:00:00'),
('01K2F2DKG0XWCSKHQP45V2QB6G', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 9, 'Subscription payment 10', '2026-04-29 09:00:00'),
('01K2F2DKG0XWCSKHQP45V2QB6G', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 9, 'Subscription payment 10', '2026-04-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(11, '01K2F2DKG0MZF25YPRTJMF2VSZ', 'LF-INV-2026000011', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-03-18 09:00:00', '2026-04-01 09:00:00', '2026-03-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000011.pdf', '2026-03-18 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(11, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-18', '2026-04-17', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(10, '01K2F2DKG0Y2FMPRRXX3YD1JGR', 'PAY-60010', 2, 11, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0nnzpx0g34rf9bh0m', 'idem-01K2F2DKG0TZZP2DQBSQ8BDPQA', 'https://cdn.livfinder.com/receipts/PAY-60010.pdf', '2026-03-28 09:00:00', '2026-03-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CQYREXVAX5J7ERTP', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 10, 'Subscription payment 11', '2026-03-28 09:00:00'),
('01K2F2DKG0CQYREXVAX5J7ERTP', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 10, 'Subscription payment 11', '2026-03-25 09:00:00'),
('01K2F2DKG0CQYREXVAX5J7ERTP', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 10, 'Subscription payment 11', '2026-03-26 09:00:00'),
('01K2F2DKG0CQYREXVAX5J7ERTP', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 10, 'Subscription payment 11', '2026-03-23 09:00:00'),
('01K2F2DKG0CQYREXVAX5J7ERTP', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 10, 'Subscription payment 11', '2026-03-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(12, '01K2F2DKG08CX4KHYGH8X4VV2A', 'LF-INV-2026000012', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-02-16 09:00:00', '2026-03-02 09:00:00', '2026-02-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000012.pdf', '2026-02-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(12, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-16', '2026-03-18', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(11, '01K2F2DKG054X7EY9KDF4BDWJ0', 'PAY-60011', 2, 12, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06jpjga6ghgr2c900', 'idem-01K2F2DKG01V8Y4YHJXHVHJBN4', 'https://cdn.livfinder.com/receipts/PAY-60011.pdf', '2026-02-17 09:00:00', '2026-02-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZBXEJWJB7F878F6C', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 11, 'Subscription payment 12', '2026-02-16 09:00:00'),
('01K2F2DKG0ZBXEJWJB7F878F6C', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 11, 'Subscription payment 12', '2026-02-24 09:00:00'),
('01K2F2DKG0ZBXEJWJB7F878F6C', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 11, 'Subscription payment 12', '2026-02-26 09:00:00'),
('01K2F2DKG0ZBXEJWJB7F878F6C', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 11, 'Subscription payment 12', '2026-02-27 09:00:00'),
('01K2F2DKG0ZBXEJWJB7F878F6C', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 11, 'Subscription payment 12', '2026-02-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(13, '01K2F2DKG0V61SZR58JV5VVG76', 'LF-INV-2026000013', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2026-01-17 09:00:00', '2026-01-31 09:00:00', '2026-01-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000013.pdf', '2026-01-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(13, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-17', '2026-02-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(12, '01K2F2DKG00GYEGE040X7JC9DA', 'PAY-60012', 2, 13, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg00pqzvf1t23hksty2', 'idem-01K2F2DKG0AQRW0SXEXKWX4JSV', 'https://cdn.livfinder.com/receipts/PAY-60012.pdf', '2026-01-23 09:00:00', '2026-01-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0PQ1W72Q1BZNEZRRR', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 12, 'Subscription payment 13', '2026-01-20 09:00:00'),
('01K2F2DKG0PQ1W72Q1BZNEZRRR', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 12, 'Subscription payment 13', '2026-01-18 09:00:00'),
('01K2F2DKG0PQ1W72Q1BZNEZRRR', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 12, 'Subscription payment 13', '2026-01-22 09:00:00'),
('01K2F2DKG0PQ1W72Q1BZNEZRRR', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 12, 'Subscription payment 13', '2026-01-20 09:00:00'),
('01K2F2DKG0PQ1W72Q1BZNEZRRR', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 12, 'Subscription payment 13', '2026-01-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(14, '01K2F2DKG00X45ASZE78Z7X13B', 'LF-INV-2026000014', 2, 2, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'GBP', 4.6729, 12261.46, 5.0, 'VAT', 'Luxhabitat Real Estate', 'billing@example.com', '2025-12-18 09:00:00', '2026-01-01 09:00:00', '2025-12-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000014.pdf', '2025-12-18 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(14, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-18', '2026-01-17', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(13, '01K2F2DKG06CCRQCM51GWK37AF', 'PAY-60013', 2, 14, 2, 2, 15, 2623.95, 'GBP', 4.6729, 12261.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg078h9xh07g0s4h5xe', 'idem-01K2F2DKG06XP40ZYKB98JR5PN', 'https://cdn.livfinder.com/receipts/PAY-60013.pdf', '2025-12-21 09:00:00', '2025-12-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V66C3JB0TN4BTJWT', 2, 'cash', 'debit', 2623.95, 'GBP', 12261.46, 'payment', 13, 'Subscription payment 14', '2025-12-21 09:00:00'),
('01K2F2DKG0V66C3JB0TN4BTJWT', 2, 'revenue.subscription', 'credit', 2499.0, 'GBP', 11677.58, 'payment', 13, 'Subscription payment 14', '2025-12-20 09:00:00'),
('01K2F2DKG0V66C3JB0TN4BTJWT', 2, 'tax_payable', 'credit', 124.95, 'GBP', 583.88, 'payment', 13, 'Subscription payment 14', '2025-12-25 09:00:00'),
('01K2F2DKG0V66C3JB0TN4BTJWT', 2, 'expense.processor_fees', 'debit', 77.09, 'GBP', 360.23, 'payment', 13, 'Subscription payment 14', '2025-12-23 09:00:00'),
('01K2F2DKG0V66C3JB0TN4BTJWT', 2, 'cash', 'credit', 77.09, 'GBP', 360.23, 'payment', 13, 'Subscription payment 14', '2025-12-24 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(2, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-02-05 09:00:00'),
(2, 'listing', 20, 19, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-27 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(3, '01K2F2DKG0AYC3SAFN7FZ3V3BS', 3, 19, 'card', 'stripe', 'pm_01k2f2dkg0bqammbezqfnb15fj', 'mastercard', '2711', 2, 2028, 'Driven Estates', 1, 'active', '2026-03-20 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(3, '01K2F2DKG0QHQCCFWERY7A0MKQ', 3, 4, 'active', 2499.0, 'USD', 9177.58, 'monthly', '2026-07-25 09:00:00', '2026-08-24 09:00:00', NULL, NULL, 1, 3, 'sub_01k2f2dkg00sdmc5czw1hqv22y', '2025-10-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(15, '01K2F2DKG0MSBYAPA2KSSH9DDG', 'LF-INV-2026000015', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-06-25 09:00:00', '2026-07-09 09:00:00', '2026-07-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000015.pdf', '2026-06-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(15, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-25', '2026-07-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(14, '01K2F2DKG0RNYYQKMTVEA9CM9Y', 'PAY-60014', 3, 15, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0sxe8610dd0wrdz6e', 'idem-01K2F2DKG0Q83W0MQGQ922CERP', 'https://cdn.livfinder.com/receipts/PAY-60014.pdf', '2026-06-30 09:00:00', '2026-07-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0G97VMGGCSR4YFTDJ', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 14, 'Subscription payment 15', '2026-07-07 09:00:00'),
('01K2F2DKG0G97VMGGCSR4YFTDJ', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 14, 'Subscription payment 15', '2026-06-25 09:00:00'),
('01K2F2DKG0G97VMGGCSR4YFTDJ', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 14, 'Subscription payment 15', '2026-06-30 09:00:00'),
('01K2F2DKG0G97VMGGCSR4YFTDJ', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 14, 'Subscription payment 15', '2026-06-29 09:00:00'),
('01K2F2DKG0G97VMGGCSR4YFTDJ', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 14, 'Subscription payment 15', '2026-06-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(16, '01K2F2DKG0WNTCMHX1VJW82B59', 'LF-INV-2026000016', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-05-26 09:00:00', '2026-06-09 09:00:00', '2026-06-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000016.pdf', '2026-05-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(16, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-26', '2026-06-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(15, '01K2F2DKG0GGKMQKTNCE8MV4KR', 'PAY-60015', 3, 16, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02a5dk5tpbzvycsep', 'idem-01K2F2DKG0FPGR0NW4VKBZ08WT', 'https://cdn.livfinder.com/receipts/PAY-60015.pdf', '2026-05-28 09:00:00', '2026-06-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0BDZ3EA6DTYP52CFQ', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 15, 'Subscription payment 16', '2026-06-06 09:00:00'),
('01K2F2DKG0BDZ3EA6DTYP52CFQ', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 15, 'Subscription payment 16', '2026-06-02 09:00:00'),
('01K2F2DKG0BDZ3EA6DTYP52CFQ', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 15, 'Subscription payment 16', '2026-06-07 09:00:00'),
('01K2F2DKG0BDZ3EA6DTYP52CFQ', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 15, 'Subscription payment 16', '2026-06-03 09:00:00'),
('01K2F2DKG0BDZ3EA6DTYP52CFQ', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 15, 'Subscription payment 16', '2026-05-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(17, '01K2F2DKG05YC7YC7Q3MTVRZ0M', 'LF-INV-2026000017', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-04-26 09:00:00', '2026-05-10 09:00:00', '2026-05-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000017.pdf', '2026-04-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(17, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-26', '2026-05-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(16, '01K2F2DKG068MJ2K2MCK5D18MA', 'PAY-60016', 3, 17, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0wkm0n86sgydwxrkn', 'idem-01K2F2DKG0Y9523819FN97NTG9', 'https://cdn.livfinder.com/receipts/PAY-60016.pdf', '2026-05-05 09:00:00', '2026-04-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YE09ZC67YSFNFE1Z', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 16, 'Subscription payment 17', '2026-05-08 09:00:00'),
('01K2F2DKG0YE09ZC67YSFNFE1Z', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 16, 'Subscription payment 17', '2026-05-08 09:00:00'),
('01K2F2DKG0YE09ZC67YSFNFE1Z', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 16, 'Subscription payment 17', '2026-04-28 09:00:00'),
('01K2F2DKG0YE09ZC67YSFNFE1Z', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 16, 'Subscription payment 17', '2026-05-07 09:00:00'),
('01K2F2DKG0YE09ZC67YSFNFE1Z', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 16, 'Subscription payment 17', '2026-04-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(18, '01K2F2DKG08X4DGJ8KAX10KJ66', 'LF-INV-2026000018', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-03-27 09:00:00', '2026-04-10 09:00:00', '2026-04-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000018.pdf', '2026-03-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(18, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-27', '2026-04-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(17, '01K2F2DKG011M50YT1WW92AFTK', 'PAY-60017', 3, 18, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0c6t54nc7gspp9927', 'idem-01K2F2DKG09K4YCWQSYP09E3B1', 'https://cdn.livfinder.com/receipts/PAY-60017.pdf', '2026-04-04 09:00:00', '2026-04-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V79SBAQ084BBEMKC', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 17, 'Subscription payment 18', '2026-03-30 09:00:00'),
('01K2F2DKG0V79SBAQ084BBEMKC', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 17, 'Subscription payment 18', '2026-04-06 09:00:00'),
('01K2F2DKG0V79SBAQ084BBEMKC', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 17, 'Subscription payment 18', '2026-04-04 09:00:00'),
('01K2F2DKG0V79SBAQ084BBEMKC', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 17, 'Subscription payment 18', '2026-04-04 09:00:00'),
('01K2F2DKG0V79SBAQ084BBEMKC', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 17, 'Subscription payment 18', '2026-04-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(19, '01K2F2DKG0CXJ9HMW75NDRE8KA', 'LF-INV-2026000019', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-02-25 09:00:00', '2026-03-11 09:00:00', '2026-03-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000019.pdf', '2026-02-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(19, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-25', '2026-03-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(18, '01K2F2DKG0MVB4B9GXAG4KPZ68', 'PAY-60018', 3, 19, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0g173hvwq6ewr81xx', 'idem-01K2F2DKG047NWFRKZ2NBRHYD8', 'https://cdn.livfinder.com/receipts/PAY-60018.pdf', '2026-03-08 09:00:00', '2026-03-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09NHG5AMKJQ8HV4MA', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 18, 'Subscription payment 19', '2026-02-27 09:00:00'),
('01K2F2DKG09NHG5AMKJQ8HV4MA', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 18, 'Subscription payment 19', '2026-02-27 09:00:00'),
('01K2F2DKG09NHG5AMKJQ8HV4MA', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 18, 'Subscription payment 19', '2026-02-28 09:00:00'),
('01K2F2DKG09NHG5AMKJQ8HV4MA', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 18, 'Subscription payment 19', '2026-02-27 09:00:00'),
('01K2F2DKG09NHG5AMKJQ8HV4MA', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 18, 'Subscription payment 19', '2026-02-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(20, '01K2F2DKG0GSQ8TT7YYBN2YNRW', 'LF-INV-2026000020', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2026-01-26 09:00:00', '2026-02-09 09:00:00', '2026-01-31 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000020.pdf', '2026-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(20, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-26', '2026-02-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(19, '01K2F2DKG03WZAE8TW9TCN25J8', 'PAY-60019', 3, 20, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg053z39ncb2kmbpxsv', 'idem-01K2F2DKG08TH0VVAH98FFJH2R', 'https://cdn.livfinder.com/receipts/PAY-60019.pdf', '2026-02-06 09:00:00', '2026-01-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T0B0FDJY0N9V3E0N', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 19, 'Subscription payment 20', '2026-01-28 09:00:00'),
('01K2F2DKG0T0B0FDJY0N9V3E0N', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 19, 'Subscription payment 20', '2026-01-28 09:00:00'),
('01K2F2DKG0T0B0FDJY0N9V3E0N', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 19, 'Subscription payment 20', '2026-01-31 09:00:00'),
('01K2F2DKG0T0B0FDJY0N9V3E0N', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 19, 'Subscription payment 20', '2026-01-26 09:00:00'),
('01K2F2DKG0T0B0FDJY0N9V3E0N', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 19, 'Subscription payment 20', '2026-02-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(21, '01K2F2DKG0BAP6CBBEQKRQ94GC', 'LF-INV-2026000021', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2025-12-27 09:00:00', '2026-01-10 09:00:00', '2025-12-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000021.pdf', '2025-12-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(21, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-27', '2026-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(20, '01K2F2DKG0V1T9NHV821G9DNXX', 'PAY-60020', 3, 21, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rs1thb61prsht526', 'idem-01K2F2DKG0H2YANZCEQNYGARQJ', 'https://cdn.livfinder.com/receipts/PAY-60020.pdf', '2026-01-08 09:00:00', '2025-12-29 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0KJBP9G7H5RG59G2Y', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 20, 'Subscription payment 21', '2026-01-01 09:00:00'),
('01K2F2DKG0KJBP9G7H5RG59G2Y', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 20, 'Subscription payment 21', '2025-12-28 09:00:00'),
('01K2F2DKG0KJBP9G7H5RG59G2Y', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 20, 'Subscription payment 21', '2025-12-29 09:00:00'),
('01K2F2DKG0KJBP9G7H5RG59G2Y', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 20, 'Subscription payment 21', '2026-01-01 09:00:00'),
('01K2F2DKG0KJBP9G7H5RG59G2Y', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 20, 'Subscription payment 21', '2026-01-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(22, '01K2F2DKG0DXRW0WHMNMWV9VAX', 'LF-INV-2026000022', 3, 3, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Driven Estates', 'billing@example.com', '2025-11-27 09:00:00', '2025-12-11 09:00:00', '2025-12-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000022.pdf', '2025-11-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(22, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-11-27', '2025-12-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(21, '01K2F2DKG0BGBXF5CDXYX374XA', 'PAY-60021', 3, 22, 3, 3, 19, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg08k123kn2rfkxe3np', 'idem-01K2F2DKG0CR46ND7K8TRBGQAV', 'https://cdn.livfinder.com/receipts/PAY-60021.pdf', '2025-11-29 09:00:00', '2025-12-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0S0TGBFRRDT64ZSA0', 3, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 21, 'Subscription payment 22', '2025-12-03 09:00:00'),
('01K2F2DKG0S0TGBFRRDT64ZSA0', 3, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 21, 'Subscription payment 22', '2025-11-28 09:00:00'),
('01K2F2DKG0S0TGBFRRDT64ZSA0', 3, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 21, 'Subscription payment 22', '2025-12-01 09:00:00'),
('01K2F2DKG0S0TGBFRRDT64ZSA0', 3, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 21, 'Subscription payment 22', '2025-12-05 09:00:00'),
('01K2F2DKG0S0TGBFRRDT64ZSA0', 3, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 21, 'Subscription payment 22', '2025-12-01 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(3, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-05-14 09:00:00'),
(3, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2026-03-16 09:00:00'),
(3, 'listing', 50, 59, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-23 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(4, '01K2F2DKG0ZTD1XDQ7TXRK9PHJ', 4, 23, 'card', 'stripe', 'pm_01k2f2dkg0agd3grkqbka1py93', 'amex', '6712', 9, 2029, 'Sotheby''s International Motors', 1, 'active', '2024-03-04 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(4, '01K2F2DKG04V4FZH7670R3X1M9', 4, 6, 'cancelled', 149000.0, 'SAR', 145930.6, 'yearly', '2026-03-05 09:00:00', '2027-03-05 09:00:00', NULL, '2026-08-09 09:00:00', 0, 4, 'sub_01k2f2dkg0svec8sf4xcdvekfp', '2025-10-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(23, '01K2F2DKG0SMA78Q540DC53HDA', 'LF-INV-2026000023', 4, 4, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'SAR', 0.9794, 153227.13, 5.0, 'VAT', 'Sotheby''s International Motors', 'billing@example.com', '2025-03-05 09:00:00', '2025-03-19 09:00:00', '2025-03-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000023.pdf', '2025-03-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(23, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-03-05', '2026-03-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(22, '01K2F2DKG0SRF5WA4QABA6FZWY', 'PAY-60022', 4, 23, 4, 4, 23, 156450.0, 'SAR', 0.9794, 153227.13, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0m3yhnsqa68v4at1s', 'idem-01K2F2DKG0NT34XEN1ZA89PQN2', 'https://cdn.livfinder.com/receipts/PAY-60022.pdf', '2025-03-12 09:00:00', '2025-03-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06ERN973X1K5AN9KN', 4, 'cash', 'debit', 156450.0, 'SAR', 153227.13, 'payment', 22, 'Subscription payment 23', '2025-03-11 09:00:00'),
('01K2F2DKG06ERN973X1K5AN9KN', 4, 'revenue.subscription', 'credit', 149000.0, 'SAR', 145930.6, 'payment', 22, 'Subscription payment 23', '2025-03-17 09:00:00'),
('01K2F2DKG06ERN973X1K5AN9KN', 4, 'tax_payable', 'credit', 7450.0, 'SAR', 7296.53, 'payment', 22, 'Subscription payment 23', '2025-03-08 09:00:00'),
('01K2F2DKG06ERN973X1K5AN9KN', 4, 'expense.processor_fees', 'debit', 4538.05, 'SAR', 4444.57, 'payment', 22, 'Subscription payment 23', '2025-03-05 09:00:00'),
('01K2F2DKG06ERN973X1K5AN9KN', 4, 'cash', 'credit', 4538.05, 'SAR', 4444.57, 'payment', 22, 'Subscription payment 23', '2025-03-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(24, '01K2F2DKG0Z2XY2WS2T80QH62T', 'LF-INV-2026000024', 4, 4, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'SAR', 0.9794, 153227.13, 5.0, 'VAT', 'Sotheby''s International Motors', 'billing@example.com', '2024-03-05 09:00:00', '2024-03-19 09:00:00', '2024-03-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000024.pdf', '2024-03-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(24, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-03-05', '2025-03-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(23, '01K2F2DKG0TM0WBPWGJX8ABNYY', 'PAY-60023', 4, 24, 4, 4, 23, 156450.0, 'SAR', 0.9794, 153227.13, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bpgdwzxdh33d7azv', 'idem-01K2F2DKG0FAFQK0KZAJKDGT61', 'https://cdn.livfinder.com/receipts/PAY-60023.pdf', '2024-03-07 09:00:00', '2024-03-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Q282TN81TFNN583D', 4, 'cash', 'debit', 156450.0, 'SAR', 153227.13, 'payment', 23, 'Subscription payment 24', '2024-03-13 09:00:00'),
('01K2F2DKG0Q282TN81TFNN583D', 4, 'revenue.subscription', 'credit', 149000.0, 'SAR', 145930.6, 'payment', 23, 'Subscription payment 24', '2024-03-17 09:00:00'),
('01K2F2DKG0Q282TN81TFNN583D', 4, 'tax_payable', 'credit', 7450.0, 'SAR', 7296.53, 'payment', 23, 'Subscription payment 24', '2024-03-17 09:00:00'),
('01K2F2DKG0Q282TN81TFNN583D', 4, 'expense.processor_fees', 'debit', 4538.05, 'SAR', 4444.57, 'payment', 23, 'Subscription payment 24', '2024-03-09 09:00:00'),
('01K2F2DKG0Q282TN81TFNN583D', 4, 'cash', 'credit', 4538.05, 'SAR', 4444.57, 'payment', 23, 'Subscription payment 24', '2024-03-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(25, '01K2F2DKG0VFSMMKVB2BMKB6CJ', 'LF-INV-2026000025', 4, 4, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'SAR', 0.9794, 153227.13, 5.0, 'VAT', 'Sotheby''s International Motors', 'billing@example.com', '2023-03-06 09:00:00', '2023-03-20 09:00:00', '2023-03-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000025.pdf', '2023-03-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(25, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-03-06', '2024-03-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(24, '01K2F2DKG033FP85XF96R6NQ65', 'PAY-60024', 4, 25, 4, 4, 23, 156450.0, 'SAR', 0.9794, 153227.13, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0y5zhh4nac7zjnq6v', 'idem-01K2F2DKG0E92H4B01VFTZCKB5', 'https://cdn.livfinder.com/receipts/PAY-60024.pdf', '2023-03-12 09:00:00', '2023-03-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0G22PZMVTY7SX5W99', 4, 'cash', 'debit', 156450.0, 'SAR', 153227.13, 'payment', 24, 'Subscription payment 25', '2023-03-18 09:00:00'),
('01K2F2DKG0G22PZMVTY7SX5W99', 4, 'revenue.subscription', 'credit', 149000.0, 'SAR', 145930.6, 'payment', 24, 'Subscription payment 25', '2023-03-13 09:00:00'),
('01K2F2DKG0G22PZMVTY7SX5W99', 4, 'tax_payable', 'credit', 7450.0, 'SAR', 7296.53, 'payment', 24, 'Subscription payment 25', '2023-03-13 09:00:00'),
('01K2F2DKG0G22PZMVTY7SX5W99', 4, 'expense.processor_fees', 'debit', 4538.05, 'SAR', 4444.57, 'payment', 24, 'Subscription payment 25', '2023-03-07 09:00:00'),
('01K2F2DKG0G22PZMVTY7SX5W99', 4, 'cash', 'credit', 4538.05, 'SAR', 4444.57, 'payment', 24, 'Subscription payment 25', '2023-03-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(26, '01K2F2DKG098HNX8YB0K5VAF59', 'LF-INV-2026000026', 4, 4, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'SAR', 0.9794, 153227.13, 5.0, 'VAT', 'Sotheby''s International Motors', 'billing@example.com', '2022-03-06 09:00:00', '2022-03-20 09:00:00', '2022-03-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000026.pdf', '2022-03-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(26, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-03-06', '2023-03-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(25, '01K2F2DKG0134A210Z87R5QHYT', 'PAY-60025', 4, 26, 4, 4, 23, 156450.0, 'SAR', 0.9794, 153227.13, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0w5qz65dxpy07z4tv', 'idem-01K2F2DKG03MBXG18KH2CY0Q4S', 'https://cdn.livfinder.com/receipts/PAY-60025.pdf', '2022-03-09 09:00:00', '2022-03-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JGA929W9KZC9PDVV', 4, 'cash', 'debit', 156450.0, 'SAR', 153227.13, 'payment', 25, 'Subscription payment 26', '2022-03-10 09:00:00'),
('01K2F2DKG0JGA929W9KZC9PDVV', 4, 'revenue.subscription', 'credit', 149000.0, 'SAR', 145930.6, 'payment', 25, 'Subscription payment 26', '2022-03-15 09:00:00'),
('01K2F2DKG0JGA929W9KZC9PDVV', 4, 'tax_payable', 'credit', 7450.0, 'SAR', 7296.53, 'payment', 25, 'Subscription payment 26', '2022-03-18 09:00:00'),
('01K2F2DKG0JGA929W9KZC9PDVV', 4, 'expense.processor_fees', 'debit', 4538.05, 'SAR', 4444.57, 'payment', 25, 'Subscription payment 26', '2022-03-09 09:00:00'),
('01K2F2DKG0JGA929W9KZC9PDVV', 4, 'cash', 'credit', 4538.05, 'SAR', 4444.57, 'payment', 25, 'Subscription payment 26', '2022-03-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(27, '01K2F2DKG0TSYVV0XABSSGJ8VG', 'LF-INV-2026000027', 4, 4, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'SAR', 0.9794, 153227.13, 5.0, 'VAT', 'Sotheby''s International Motors', 'billing@example.com', '2021-03-06 09:00:00', '2021-03-20 09:00:00', '2021-03-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000027.pdf', '2021-03-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(27, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-03-06', '2022-03-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(26, '01K2F2DKG0C04AG0FG20ZYXNVW', 'PAY-60026', 4, 27, 4, 4, 23, 156450.0, 'SAR', 0.9794, 153227.13, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qrga98spynk0v2jd', 'idem-01K2F2DKG0030729VBDGDWW5C9', 'https://cdn.livfinder.com/receipts/PAY-60026.pdf', '2021-03-17 09:00:00', '2021-03-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG079E1T7WWDNQX6S5Z', 4, 'cash', 'debit', 156450.0, 'SAR', 153227.13, 'payment', 26, 'Subscription payment 27', '2021-03-12 09:00:00'),
('01K2F2DKG079E1T7WWDNQX6S5Z', 4, 'revenue.subscription', 'credit', 149000.0, 'SAR', 145930.6, 'payment', 26, 'Subscription payment 27', '2021-03-08 09:00:00'),
('01K2F2DKG079E1T7WWDNQX6S5Z', 4, 'tax_payable', 'credit', 7450.0, 'SAR', 7296.53, 'payment', 26, 'Subscription payment 27', '2021-03-07 09:00:00'),
('01K2F2DKG079E1T7WWDNQX6S5Z', 4, 'expense.processor_fees', 'debit', 4538.05, 'SAR', 4444.57, 'payment', 26, 'Subscription payment 27', '2021-03-09 09:00:00'),
('01K2F2DKG079E1T7WWDNQX6S5Z', 4, 'cash', 'credit', 4538.05, 'SAR', 4444.57, 'payment', 26, 'Subscription payment 27', '2021-03-17 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(4, 'listing', 50, 50, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-30 09:00:00'),
(4, 'listing', 20, 70, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-04 09:00:00'),
(4, 'listing', -1, 69, 'consumption', 'listing', NULL, 'Listing published', '2025-10-28 09:00:00'),
(4, 'listing', -1, 68, 'consumption', 'listing', NULL, 'Listing published', '2026-06-21 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(5, '01K2F2DKG0TEZ6KK1VCENDFH8J', 5, 27, 'card', 'stripe', 'pm_01k2f2dkg03pa1kyvnj4r5b2bv', 'amex', '9610', 11, 2029, 'Christie''s International Automotive', 1, 'active', '2026-05-02 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(5, '01K2F2DKG0Q0PMB969PD1B2JDM', 5, 4, 'active', 2499.0, 'EUR', 9956.27, 'monthly', '2026-08-15 09:00:00', '2026-09-14 09:00:00', NULL, NULL, 1, 5, 'sub_01k2f2dkg0aza15z4ea76n555q', '2025-05-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(28, '01K2F2DKG0N33WQ1CFKYM8P1J1', 'LF-INV-2026000028', 5, 5, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Automotive', 'billing@example.com', '2026-07-16 09:00:00', '2026-07-30 09:00:00', '2026-07-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000028.pdf', '2026-07-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(28, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-16', '2026-08-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(27, '01K2F2DKG0T1FGVHF4KQGMPP59', 'PAY-60027', 5, 28, 5, 5, 27, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0hcgq15k75kmzpc37', 'idem-01K2F2DKG0867XSM2ED0WQV9DP', 'https://cdn.livfinder.com/receipts/PAY-60027.pdf', '2026-07-24 09:00:00', '2026-07-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG069ZJPWDXXYPF6PN4', 5, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 27, 'Subscription payment 28', '2026-07-24 09:00:00'),
('01K2F2DKG069ZJPWDXXYPF6PN4', 5, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 27, 'Subscription payment 28', '2026-07-25 09:00:00'),
('01K2F2DKG069ZJPWDXXYPF6PN4', 5, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 27, 'Subscription payment 28', '2026-07-25 09:00:00'),
('01K2F2DKG069ZJPWDXXYPF6PN4', 5, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 27, 'Subscription payment 28', '2026-07-21 09:00:00'),
('01K2F2DKG069ZJPWDXXYPF6PN4', 5, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 27, 'Subscription payment 28', '2026-07-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(29, '01K2F2DKG02DQ5AC28F6RK8WER', 'LF-INV-2026000029', 5, 5, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Automotive', 'billing@example.com', '2026-06-16 09:00:00', '2026-06-30 09:00:00', '2026-06-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000029.pdf', '2026-06-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(29, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-16', '2026-07-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(28, '01K2F2DKG0BMTEBT837ZBKGB7M', 'PAY-60028', 5, 29, 5, 5, 27, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg037776fxkxvxkx7rj', 'idem-01K2F2DKG0ZJDY126TNHSRSHHF', 'https://cdn.livfinder.com/receipts/PAY-60028.pdf', '2026-06-24 09:00:00', '2026-06-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0P5NKRRH241J5C8VG', 5, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 28, 'Subscription payment 29', '2026-06-21 09:00:00'),
('01K2F2DKG0P5NKRRH241J5C8VG', 5, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 28, 'Subscription payment 29', '2026-06-20 09:00:00'),
('01K2F2DKG0P5NKRRH241J5C8VG', 5, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 28, 'Subscription payment 29', '2026-06-23 09:00:00'),
('01K2F2DKG0P5NKRRH241J5C8VG', 5, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 28, 'Subscription payment 29', '2026-06-26 09:00:00'),
('01K2F2DKG0P5NKRRH241J5C8VG', 5, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 28, 'Subscription payment 29', '2026-06-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(30, '01K2F2DKG0VJTAE583920YSCT1', 'LF-INV-2026000030', 5, 5, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Automotive', 'billing@example.com', '2026-05-17 09:00:00', '2026-05-31 09:00:00', '2026-05-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000030.pdf', '2026-05-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(30, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-17', '2026-06-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(29, '01K2F2DKG02J3J9MM7RB25R53H', 'PAY-60029', 5, 30, 5, 5, 27, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0j3n5ymq1fqqannx9', 'idem-01K2F2DKG0GAS19CKJBCQS4NN8', 'https://cdn.livfinder.com/receipts/PAY-60029.pdf', '2026-05-19 09:00:00', '2026-05-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0H313JVG913FY2WD4', 5, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 29, 'Subscription payment 30', '2026-05-26 09:00:00'),
('01K2F2DKG0H313JVG913FY2WD4', 5, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 29, 'Subscription payment 30', '2026-05-24 09:00:00'),
('01K2F2DKG0H313JVG913FY2WD4', 5, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 29, 'Subscription payment 30', '2026-05-29 09:00:00'),
('01K2F2DKG0H313JVG913FY2WD4', 5, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 29, 'Subscription payment 30', '2026-05-26 09:00:00'),
('01K2F2DKG0H313JVG913FY2WD4', 5, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 29, 'Subscription payment 30', '2026-05-17 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(5, 'listing', 50, 50, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-07 09:00:00'),
(5, 'listing', -1, 49, 'consumption', 'listing', NULL, 'Listing published', '2026-06-17 09:00:00'),
(5, 'listing', -1, 48, 'consumption', 'listing', NULL, 'Listing published', '2025-11-21 09:00:00'),
(5, 'listing', 20, 68, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-11 09:00:00'),
(5, 'listing', -2, 66, 'consumption', 'listing', NULL, 'Listing published', '2026-05-14 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(6, '01K2F2DKG0WY5KXPZ9XG0SS34M', 6, 31, 'card', 'stripe', 'pm_01k2f2dkg01gcm5zqvhg3dzyw9', 'amex', '1343', 8, 2030, 'Knight Yachts', 1, 'active', '2024-12-11 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(6, '01K2F2DKG07DH73RDV78K5BMSN', 6, 4, 'past_due', 2499.0, 'EUR', 9956.27, 'monthly', '2026-07-22 09:00:00', '2026-08-21 09:00:00', NULL, NULL, 1, 6, 'sub_01k2f2dkg0m2088x05rhdzr33b', '2024-07-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(31, '01K2F2DKG0QZN02D8MK450350P', 'LF-INV-2026000031', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-06-22 09:00:00', '2026-07-06 09:00:00', '2026-07-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000031.pdf', '2026-06-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(31, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-22', '2026-07-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(30, '01K2F2DKG0R75RQE8SMQE1913K', 'PAY-60030', 6, 31, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02yxhqz1zsq1yjpz9', 'idem-01K2F2DKG0AYE12HGZ37ZGMX1R', 'https://cdn.livfinder.com/receipts/PAY-60030.pdf', '2026-07-04 09:00:00', '2026-06-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YA700YC740R26VEV', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 30, 'Subscription payment 31', '2026-07-04 09:00:00'),
('01K2F2DKG0YA700YC740R26VEV', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 30, 'Subscription payment 31', '2026-07-02 09:00:00'),
('01K2F2DKG0YA700YC740R26VEV', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 30, 'Subscription payment 31', '2026-06-27 09:00:00'),
('01K2F2DKG0YA700YC740R26VEV', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 30, 'Subscription payment 31', '2026-06-22 09:00:00'),
('01K2F2DKG0YA700YC740R26VEV', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 30, 'Subscription payment 31', '2026-06-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(32, '01K2F2DKG0RH607AK05S7M7N8D', 'LF-INV-2026000032', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-05-23 09:00:00', '2026-06-06 09:00:00', '2026-05-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000032.pdf', '2026-05-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(32, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-23', '2026-06-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(31, '01K2F2DKG055ZYY6QH04VGR39S', 'PAY-60031', 6, 32, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ytpkfrs3b0m56dqj', 'idem-01K2F2DKG0FDCXZW9WXX61MDBD', 'https://cdn.livfinder.com/receipts/PAY-60031.pdf', '2026-05-24 09:00:00', '2026-05-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00TRSHN25698XPZF9', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 31, 'Subscription payment 32', '2026-05-26 09:00:00'),
('01K2F2DKG00TRSHN25698XPZF9', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 31, 'Subscription payment 32', '2026-05-25 09:00:00'),
('01K2F2DKG00TRSHN25698XPZF9', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 31, 'Subscription payment 32', '2026-06-01 09:00:00'),
('01K2F2DKG00TRSHN25698XPZF9', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 31, 'Subscription payment 32', '2026-05-27 09:00:00'),
('01K2F2DKG00TRSHN25698XPZF9', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 31, 'Subscription payment 32', '2026-05-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(33, '01K2F2DKG0JHK2N2VWZK5HH0Q4', 'LF-INV-2026000033', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-04-23 09:00:00', '2026-05-07 09:00:00', '2026-04-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000033.pdf', '2026-04-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(33, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-23', '2026-05-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(32, '01K2F2DKG01PXXYY4FAJY8H4ZF', 'PAY-60032', 6, 33, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gxjfeyqz9zpq9151', 'idem-01K2F2DKG0S2KVPBQ3B2M0D1S2', 'https://cdn.livfinder.com/receipts/PAY-60032.pdf', '2026-04-29 09:00:00', '2026-04-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CKMD4J34W1X3YVK3', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 32, 'Subscription payment 33', '2026-04-25 09:00:00'),
('01K2F2DKG0CKMD4J34W1X3YVK3', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 32, 'Subscription payment 33', '2026-05-02 09:00:00'),
('01K2F2DKG0CKMD4J34W1X3YVK3', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 32, 'Subscription payment 33', '2026-04-30 09:00:00'),
('01K2F2DKG0CKMD4J34W1X3YVK3', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 32, 'Subscription payment 33', '2026-04-23 09:00:00'),
('01K2F2DKG0CKMD4J34W1X3YVK3', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 32, 'Subscription payment 33', '2026-04-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(34, '01K2F2DKG0V3QVTQ7FSVB09K2N', 'LF-INV-2026000034', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-03-24 09:00:00', '2026-04-07 09:00:00', '2026-04-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000034.pdf', '2026-03-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(34, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-24', '2026-04-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(33, '01K2F2DKG01DEP314DWFHWQBM2', 'PAY-60033', 6, 34, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0vxj1147zykrxc9an', 'idem-01K2F2DKG046W7ZGF46G090JVJ', 'https://cdn.livfinder.com/receipts/PAY-60033.pdf', '2026-03-30 09:00:00', '2026-04-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG02ES0JZNJZHK3PEA4', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 33, 'Subscription payment 34', '2026-04-03 09:00:00'),
('01K2F2DKG02ES0JZNJZHK3PEA4', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 33, 'Subscription payment 34', '2026-04-04 09:00:00'),
('01K2F2DKG02ES0JZNJZHK3PEA4', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 33, 'Subscription payment 34', '2026-03-27 09:00:00'),
('01K2F2DKG02ES0JZNJZHK3PEA4', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 33, 'Subscription payment 34', '2026-03-27 09:00:00'),
('01K2F2DKG02ES0JZNJZHK3PEA4', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 33, 'Subscription payment 34', '2026-04-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(35, '01K2F2DKG08WKPPFN3XBKTF9V4', 'LF-INV-2026000035', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-02-22 09:00:00', '2026-03-08 09:00:00', '2026-03-06 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000035.pdf', '2026-02-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(35, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-22', '2026-03-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(34, '01K2F2DKG0Z4ZBTY0FVGA8A3K8', 'PAY-60034', 6, 35, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rm5dtydj4aww24v3', 'idem-01K2F2DKG09F28FXB78G5QZP46', 'https://cdn.livfinder.com/receipts/PAY-60034.pdf', '2026-03-06 09:00:00', '2026-03-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZGJFJDECSANTMSF7', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 34, 'Subscription payment 35', '2026-02-23 09:00:00'),
('01K2F2DKG0ZGJFJDECSANTMSF7', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 34, 'Subscription payment 35', '2026-03-05 09:00:00'),
('01K2F2DKG0ZGJFJDECSANTMSF7', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 34, 'Subscription payment 35', '2026-02-25 09:00:00'),
('01K2F2DKG0ZGJFJDECSANTMSF7', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 34, 'Subscription payment 35', '2026-03-03 09:00:00'),
('01K2F2DKG0ZGJFJDECSANTMSF7', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 34, 'Subscription payment 35', '2026-03-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(36, '01K2F2DKG0KVWPDQJ8KVX4BMNW', 'LF-INV-2026000036', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2026-01-23 09:00:00', '2026-02-06 09:00:00', '2026-01-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000036.pdf', '2026-01-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(36, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-23', '2026-02-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(35, '01K2F2DKG02YCZJNZV1EEAQNEB', 'PAY-60035', 6, 36, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gy68tpw1tk5w6kz0', 'idem-01K2F2DKG01V18EPM2CSP95D5R', 'https://cdn.livfinder.com/receipts/PAY-60035.pdf', '2026-01-23 09:00:00', '2026-01-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00YJXJF4ZK3CTWJ8S', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 35, 'Subscription payment 36', '2026-01-27 09:00:00'),
('01K2F2DKG00YJXJF4ZK3CTWJ8S', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 35, 'Subscription payment 36', '2026-02-01 09:00:00'),
('01K2F2DKG00YJXJF4ZK3CTWJ8S', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 35, 'Subscription payment 36', '2026-01-29 09:00:00'),
('01K2F2DKG00YJXJF4ZK3CTWJ8S', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 35, 'Subscription payment 36', '2026-02-04 09:00:00'),
('01K2F2DKG00YJXJF4ZK3CTWJ8S', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 35, 'Subscription payment 36', '2026-01-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(37, '01K2F2DKG0R6VK2RFG8QH5M54D', 'LF-INV-2026000037', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2025-12-24 09:00:00', '2026-01-07 09:00:00', '2025-12-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000037.pdf', '2025-12-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(37, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-24', '2026-01-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(36, '01K2F2DKG0PERC6KMZT12E5Y35', 'PAY-60036', 6, 37, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0vvpdqe0bffbjzrz5', 'idem-01K2F2DKG0CH53Z9KBZRJD32CA', 'https://cdn.livfinder.com/receipts/PAY-60036.pdf', '2026-01-04 09:00:00', '2025-12-29 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0896PGXA8V0GV7P5B', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 36, 'Subscription payment 37', '2026-01-01 09:00:00'),
('01K2F2DKG0896PGXA8V0GV7P5B', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 36, 'Subscription payment 37', '2025-12-28 09:00:00'),
('01K2F2DKG0896PGXA8V0GV7P5B', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 36, 'Subscription payment 37', '2025-12-28 09:00:00'),
('01K2F2DKG0896PGXA8V0GV7P5B', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 36, 'Subscription payment 37', '2025-12-25 09:00:00'),
('01K2F2DKG0896PGXA8V0GV7P5B', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 36, 'Subscription payment 37', '2025-12-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(38, '01K2F2DKG0AECCY385SBGWN491', 'LF-INV-2026000038', 6, 6, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Yachts', 'billing@example.com', '2025-11-24 09:00:00', '2025-12-08 09:00:00', '2025-11-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000038.pdf', '2025-11-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(38, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-11-24', '2025-12-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(37, '01K2F2DKG0BZ2BD1XWQHR6G458', 'PAY-60037', 6, 38, 6, 6, 31, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0d2yttygz3f1nk6y8', 'idem-01K2F2DKG0HB1BMJKW77447612', 'https://cdn.livfinder.com/receipts/PAY-60037.pdf', '2025-12-01 09:00:00', '2025-11-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08PD7CCP3AE3E4WVG', 6, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 37, 'Subscription payment 38', '2025-11-27 09:00:00'),
('01K2F2DKG08PD7CCP3AE3E4WVG', 6, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 37, 'Subscription payment 38', '2025-12-04 09:00:00'),
('01K2F2DKG08PD7CCP3AE3E4WVG', 6, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 37, 'Subscription payment 38', '2025-12-01 09:00:00'),
('01K2F2DKG08PD7CCP3AE3E4WVG', 6, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 37, 'Subscription payment 38', '2025-12-04 09:00:00'),
('01K2F2DKG08PD7CCP3AE3E4WVG', 6, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 37, 'Subscription payment 38', '2025-11-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(6, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-10 09:00:00'),
(6, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-09 09:00:00'),
(6, 'listing', 50, 99, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-24 09:00:00'),
(6, 'listing', -1, 98, 'consumption', 'listing', NULL, 'Listing published', '2025-11-22 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(7, '01K2F2DKG011ZBB81F4TTHR0BV', 7, 35, 'card', 'stripe', 'pm_01k2f2dkg0q8zks1a606qvga26', 'visa', '5870', 1, 2030, 'Halcyon Marine', 1, 'active', '2025-10-24 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(7, '01K2F2DKG0609TAZYJJGD52T99', 7, 6, 'active', 149000.0, 'AED', 149000.0, 'yearly', '2026-05-30 09:00:00', '2027-05-30 09:00:00', NULL, NULL, 1, 7, 'sub_01k2f2dkg0g7z3ph5c8ebyzy1s', '2024-01-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(39, '01K2F2DKG038H17DHSSE13C1XX', 'LF-INV-2026000039', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2025-05-30 09:00:00', '2025-06-13 09:00:00', '2025-06-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000039.pdf', '2025-05-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(39, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-05-30', '2026-05-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(38, '01K2F2DKG0FJSFMA4C3P9KM7SC', 'PAY-60038', 7, 39, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0q5n0hdx7mbpekc0a', 'idem-01K2F2DKG0QMY35SMQ90SKK7MJ', 'https://cdn.livfinder.com/receipts/PAY-60038.pdf', '2025-06-11 09:00:00', '2025-05-31 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0405HE14HB2J1N8SS', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 38, 'Subscription payment 39', '2025-06-10 09:00:00'),
('01K2F2DKG0405HE14HB2J1N8SS', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 38, 'Subscription payment 39', '2025-06-09 09:00:00'),
('01K2F2DKG0405HE14HB2J1N8SS', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 38, 'Subscription payment 39', '2025-06-07 09:00:00'),
('01K2F2DKG0405HE14HB2J1N8SS', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 38, 'Subscription payment 39', '2025-06-10 09:00:00'),
('01K2F2DKG0405HE14HB2J1N8SS', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 38, 'Subscription payment 39', '2025-05-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(40, '01K2F2DKG0JGQAC6AQD5H7WD07', 'LF-INV-2026000040', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2024-05-30 09:00:00', '2024-06-13 09:00:00', '2024-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000040.pdf', '2024-05-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(40, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-05-30', '2025-05-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(39, '01K2F2DKG0F8ZN580GN2SBK1YV', 'PAY-60039', 7, 40, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ejah2w4qrhv0kbmg', 'idem-01K2F2DKG0G5TDR0YB880S0TBH', 'https://cdn.livfinder.com/receipts/PAY-60039.pdf', '2024-05-30 09:00:00', '2024-06-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06M93V57GJMQBHTAT', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 39, 'Subscription payment 40', '2024-06-07 09:00:00'),
('01K2F2DKG06M93V57GJMQBHTAT', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 39, 'Subscription payment 40', '2024-06-01 09:00:00'),
('01K2F2DKG06M93V57GJMQBHTAT', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 39, 'Subscription payment 40', '2024-06-03 09:00:00'),
('01K2F2DKG06M93V57GJMQBHTAT', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 39, 'Subscription payment 40', '2024-06-05 09:00:00'),
('01K2F2DKG06M93V57GJMQBHTAT', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 39, 'Subscription payment 40', '2024-05-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(41, '01K2F2DKG0QS3YQSPEV74RGK2T', 'LF-INV-2026000041', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2023-05-31 09:00:00', '2023-06-14 09:00:00', '2023-06-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000041.pdf', '2023-05-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(41, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-05-31', '2024-05-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(40, '01K2F2DKG0K4X1MGNFTJAV54C4', 'PAY-60040', 7, 41, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02wvv207xh0b4ja1v', 'idem-01K2F2DKG04VDT79H2YHN4DPAP', 'https://cdn.livfinder.com/receipts/PAY-60040.pdf', '2023-06-12 09:00:00', '2023-06-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG091JZM49EPGQAAPKT', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 40, 'Subscription payment 41', '2023-06-01 09:00:00'),
('01K2F2DKG091JZM49EPGQAAPKT', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 40, 'Subscription payment 41', '2023-06-06 09:00:00'),
('01K2F2DKG091JZM49EPGQAAPKT', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 40, 'Subscription payment 41', '2023-06-09 09:00:00'),
('01K2F2DKG091JZM49EPGQAAPKT', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 40, 'Subscription payment 41', '2023-06-10 09:00:00'),
('01K2F2DKG091JZM49EPGQAAPKT', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 40, 'Subscription payment 41', '2023-06-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(42, '01K2F2DKG0W2VW9T9HX3MX13PC', 'LF-INV-2026000042', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2022-05-31 09:00:00', '2022-06-14 09:00:00', '2022-06-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000042.pdf', '2022-05-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(42, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-05-31', '2023-05-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(41, '01K2F2DKG0YADM5SSGHCKQYGKH', 'PAY-60041', 7, 42, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0nj6naz7rwvrgaxhm', 'idem-01K2F2DKG0J4KW0EGJSFTW5DRJ', 'https://cdn.livfinder.com/receipts/PAY-60041.pdf', '2022-06-10 09:00:00', '2022-06-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00EGW544ANDD56AEG', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 41, 'Subscription payment 42', '2022-05-31 09:00:00'),
('01K2F2DKG00EGW544ANDD56AEG', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 41, 'Subscription payment 42', '2022-06-02 09:00:00'),
('01K2F2DKG00EGW544ANDD56AEG', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 41, 'Subscription payment 42', '2022-06-04 09:00:00'),
('01K2F2DKG00EGW544ANDD56AEG', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 41, 'Subscription payment 42', '2022-06-03 09:00:00'),
('01K2F2DKG00EGW544ANDD56AEG', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 41, 'Subscription payment 42', '2022-06-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(43, '01K2F2DKG09HBJ971WFHAS4ZNG', 'LF-INV-2026000043', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2021-05-31 09:00:00', '2021-06-14 09:00:00', '2021-06-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000043.pdf', '2021-05-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(43, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-05-31', '2022-05-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(42, '01K2F2DKG0XQES05HWP570BMFX', 'PAY-60042', 7, 43, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg077j5dr2fbyt3zesp', 'idem-01K2F2DKG0TBSQBNTCPS6D532N', 'https://cdn.livfinder.com/receipts/PAY-60042.pdf', '2021-06-11 09:00:00', '2021-06-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NEE11B6G00S6Y69E', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 42, 'Subscription payment 43', '2021-06-09 09:00:00'),
('01K2F2DKG0NEE11B6G00S6Y69E', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 42, 'Subscription payment 43', '2021-06-01 09:00:00'),
('01K2F2DKG0NEE11B6G00S6Y69E', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 42, 'Subscription payment 43', '2021-06-01 09:00:00'),
('01K2F2DKG0NEE11B6G00S6Y69E', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 42, 'Subscription payment 43', '2021-06-08 09:00:00'),
('01K2F2DKG0NEE11B6G00S6Y69E', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 42, 'Subscription payment 43', '2021-06-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(44, '01K2F2DKG0SC8HA5C0KA2M0VHH', 'LF-INV-2026000044', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2020-05-31 09:00:00', '2020-06-14 09:00:00', '2020-06-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000044.pdf', '2020-05-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(44, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-05-31', '2021-05-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(43, '01K2F2DKG0H7YEQSV88C5CHAF8', 'PAY-60043', 7, 44, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0az4nkxxmzncp9fwx', 'idem-01K2F2DKG0SE1HTS97N5R7NM2A', 'https://cdn.livfinder.com/receipts/PAY-60043.pdf', '2020-06-10 09:00:00', '2020-06-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WDYYVBY35Y7271NY', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 43, 'Subscription payment 44', '2020-06-09 09:00:00'),
('01K2F2DKG0WDYYVBY35Y7271NY', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 43, 'Subscription payment 44', '2020-06-11 09:00:00'),
('01K2F2DKG0WDYYVBY35Y7271NY', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 43, 'Subscription payment 44', '2020-06-03 09:00:00'),
('01K2F2DKG0WDYYVBY35Y7271NY', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 43, 'Subscription payment 44', '2020-06-09 09:00:00'),
('01K2F2DKG0WDYYVBY35Y7271NY', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 43, 'Subscription payment 44', '2020-05-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(45, '01K2F2DKG02187P2GTNM9PWYVS', 'LF-INV-2026000045', 7, 7, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Halcyon Marine', 'billing@example.com', '2019-06-01 09:00:00', '2019-06-15 09:00:00', '2019-06-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000045.pdf', '2019-06-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(45, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2019-06-01', '2020-05-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(44, '01K2F2DKG0YXSMR1PX3BM58CVS', 'PAY-60044', 7, 45, 7, 7, 35, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tj6nsxdpv735dryx', 'idem-01K2F2DKG0P48HN9DB4M1WEK9H', 'https://cdn.livfinder.com/receipts/PAY-60044.pdf', '2019-06-03 09:00:00', '2019-06-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XZ40GCZQC174YS2X', 7, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 44, 'Subscription payment 45', '2019-06-13 09:00:00'),
('01K2F2DKG0XZ40GCZQC174YS2X', 7, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 44, 'Subscription payment 45', '2019-06-08 09:00:00'),
('01K2F2DKG0XZ40GCZQC174YS2X', 7, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 44, 'Subscription payment 45', '2019-06-01 09:00:00'),
('01K2F2DKG0XZ40GCZQC174YS2X', 7, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 44, 'Subscription payment 45', '2019-06-06 09:00:00'),
('01K2F2DKG0XZ40GCZQC174YS2X', 7, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 44, 'Subscription payment 45', '2019-06-06 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(7, 'listing', 20, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-05 09:00:00'),
(7, 'listing', -1, 19, 'consumption', 'listing', NULL, 'Listing published', '2026-08-12 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(8, '01K2F2DKG0C96M8CZ5WPC6NR4T', 8, 39, 'card', 'stripe', 'pm_01k2f2dkg09atj36xzxyn9nym3', 'visa', '5575', 11, 2029, 'Aurum Aviation', 1, 'active', '2025-06-23 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(8, '01K2F2DKG0MPXD8JPG8Q24RD1H', 8, 4, 'active', 2499.0, 'AUD', 5978.36, 'monthly', '2026-07-21 09:00:00', '2026-08-20 09:00:00', NULL, NULL, 1, 8, 'sub_01k2f2dkg0xvqajfgtqs7txb14', '2024-04-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(46, '01K2F2DKG0WBJSG5J0DVPGS8VQ', 'LF-INV-2026000046', 8, 8, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Aurum Aviation', 'billing@example.com', '2026-06-21 09:00:00', '2026-07-05 09:00:00', '2026-06-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000046.pdf', '2026-06-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(46, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-21', '2026-07-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(45, '01K2F2DKG0S7J9W4JDM9MHHAMN', 'PAY-60045', 8, 46, 8, 8, 39, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03xstx1vf1tqscfxh', 'idem-01K2F2DKG0ZT2690CK37CWDM7G', 'https://cdn.livfinder.com/receipts/PAY-60045.pdf', '2026-06-27 09:00:00', '2026-06-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG005X7V7T67E18GJ3R', 8, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 45, 'Subscription payment 46', '2026-06-29 09:00:00'),
('01K2F2DKG005X7V7T67E18GJ3R', 8, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 45, 'Subscription payment 46', '2026-07-02 09:00:00'),
('01K2F2DKG005X7V7T67E18GJ3R', 8, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 45, 'Subscription payment 46', '2026-06-25 09:00:00'),
('01K2F2DKG005X7V7T67E18GJ3R', 8, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 45, 'Subscription payment 46', '2026-07-01 09:00:00'),
('01K2F2DKG005X7V7T67E18GJ3R', 8, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 45, 'Subscription payment 46', '2026-06-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(47, '01K2F2DKG0JY90445EBZQ1M69F', 'LF-INV-2026000047', 8, 8, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Aurum Aviation', 'billing@example.com', '2026-05-22 09:00:00', '2026-06-05 09:00:00', '2026-05-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000047.pdf', '2026-05-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(47, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-22', '2026-06-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(46, '01K2F2DKG04VBCX9NBKY6QDZS8', 'PAY-60046', 8, 47, 8, 8, 39, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0r382h16sr68vtsp9', 'idem-01K2F2DKG00T09C8VHH2GX4SWN', 'https://cdn.livfinder.com/receipts/PAY-60046.pdf', '2026-05-22 09:00:00', '2026-05-29 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG01X02QM284SEQNBW8', 8, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 46, 'Subscription payment 47', '2026-05-27 09:00:00'),
('01K2F2DKG01X02QM284SEQNBW8', 8, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 46, 'Subscription payment 47', '2026-06-02 09:00:00'),
('01K2F2DKG01X02QM284SEQNBW8', 8, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 46, 'Subscription payment 47', '2026-06-02 09:00:00'),
('01K2F2DKG01X02QM284SEQNBW8', 8, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 46, 'Subscription payment 47', '2026-05-29 09:00:00'),
('01K2F2DKG01X02QM284SEQNBW8', 8, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 46, 'Subscription payment 47', '2026-06-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(48, '01K2F2DKG0VF0VG55GN1NB8HYP', 'LF-INV-2026000048', 8, 8, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Aurum Aviation', 'billing@example.com', '2026-04-22 09:00:00', '2026-05-06 09:00:00', '2026-04-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000048.pdf', '2026-04-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(48, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-22', '2026-05-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(47, '01K2F2DKG043T5E25XHMDSD7WE', 'PAY-60047', 8, 48, 8, 8, 39, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg00cxznvwfc136w9p7', 'idem-01K2F2DKG04V838CZY25F16NB6', 'https://cdn.livfinder.com/receipts/PAY-60047.pdf', '2026-04-27 09:00:00', '2026-04-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04NDHB4EYAA9N47NM', 8, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 47, 'Subscription payment 48', '2026-04-22 09:00:00'),
('01K2F2DKG04NDHB4EYAA9N47NM', 8, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 47, 'Subscription payment 48', '2026-05-02 09:00:00'),
('01K2F2DKG04NDHB4EYAA9N47NM', 8, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 47, 'Subscription payment 48', '2026-04-27 09:00:00'),
('01K2F2DKG04NDHB4EYAA9N47NM', 8, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 47, 'Subscription payment 48', '2026-04-23 09:00:00'),
('01K2F2DKG04NDHB4EYAA9N47NM', 8, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 47, 'Subscription payment 48', '2026-04-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(49, '01K2F2DKG01PYN205CT742TWBV', 'LF-INV-2026000049', 8, 8, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Aurum Aviation', 'billing@example.com', '2026-03-23 09:00:00', '2026-04-06 09:00:00', '2026-04-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000049.pdf', '2026-03-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(49, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-23', '2026-04-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(48, '01K2F2DKG02T5QFYXD8WWE1C1G', 'PAY-60048', 8, 49, 8, 8, 39, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg07s7zm1wtc0sywbej', 'idem-01K2F2DKG0W170VT3VRKPWQCHK', 'https://cdn.livfinder.com/receipts/PAY-60048.pdf', '2026-03-27 09:00:00', '2026-03-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0SJ27SGHVKAB23C6P', 8, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 48, 'Subscription payment 49', '2026-04-01 09:00:00'),
('01K2F2DKG0SJ27SGHVKAB23C6P', 8, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 48, 'Subscription payment 49', '2026-04-02 09:00:00'),
('01K2F2DKG0SJ27SGHVKAB23C6P', 8, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 48, 'Subscription payment 49', '2026-03-26 09:00:00'),
('01K2F2DKG0SJ27SGHVKAB23C6P', 8, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 48, 'Subscription payment 49', '2026-04-02 09:00:00'),
('01K2F2DKG0SJ27SGHVKAB23C6P', 8, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 48, 'Subscription payment 49', '2026-04-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(50, '01K2F2DKG0W91DDH82R5FQH5YK', 'LF-INV-2026000050', 8, 8, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Aurum Aviation', 'billing@example.com', '2026-02-21 09:00:00', '2026-03-07 09:00:00', '2026-02-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000050.pdf', '2026-02-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(50, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-21', '2026-03-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(49, '01K2F2DKG029B4K3F1PDVKS9S6', 'PAY-60049', 8, 50, 8, 8, 39, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0raemwbrnpy1avnqw', 'idem-01K2F2DKG0VDHJNSEZNACHA426', 'https://cdn.livfinder.com/receipts/PAY-60049.pdf', '2026-02-28 09:00:00', '2026-02-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V5D5H6DTYDPGXY0N', 8, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 49, 'Subscription payment 50', '2026-03-03 09:00:00'),
('01K2F2DKG0V5D5H6DTYDPGXY0N', 8, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 49, 'Subscription payment 50', '2026-03-01 09:00:00'),
('01K2F2DKG0V5D5H6DTYDPGXY0N', 8, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 49, 'Subscription payment 50', '2026-03-02 09:00:00'),
('01K2F2DKG0V5D5H6DTYDPGXY0N', 8, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 49, 'Subscription payment 50', '2026-03-03 09:00:00'),
('01K2F2DKG0V5D5H6DTYDPGXY0N', 8, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 49, 'Subscription payment 50', '2026-02-27 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(8, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-04-09 09:00:00'),
(8, 'listing', 20, 19, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-20 09:00:00'),
(8, 'listing', 10, 29, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-05-12 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(9, '01K2F2DKG0XPZ82RXPFX8H4C5Y', 9, 43, 'card', 'stripe', 'pm_01k2f2dkg0hmxc3nah8jgcv30e', 'mastercard', '5133', 1, 2031, 'Meridian Timepieces', 1, 'active', '2024-05-19 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(9, '01K2F2DKG061ZM9D6TNHTDVK1S', 9, 4, 'active', 2499.0, 'HKD', 1176.53, 'monthly', '2026-08-10 09:00:00', '2026-09-09 09:00:00', NULL, NULL, 1, 9, 'sub_01k2f2dkg0bd0j21k6vcb0dv59', '2024-09-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(51, '01K2F2DKG0Q7G0C62KWAJGTCKV', 'LF-INV-2026000051', 9, 9, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'HKD', 0.4708, 1235.36, 5.0, 'VAT', 'Meridian Timepieces', 'billing@example.com', '2026-07-11 09:00:00', '2026-07-25 09:00:00', '2026-07-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000051.pdf', '2026-07-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(51, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-11', '2026-08-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(50, '01K2F2DKG01MEK2NDEECS27Z60', 'PAY-60050', 9, 51, 9, 9, 43, 2623.95, 'HKD', 0.4708, 1235.36, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0028tm8azf35cqymz', 'idem-01K2F2DKG00M3DW01SW8368ZBH', 'https://cdn.livfinder.com/receipts/PAY-60050.pdf', '2026-07-14 09:00:00', '2026-07-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0FQSKR556H4RYMQNH', 9, 'cash', 'debit', 2623.95, 'HKD', 1235.36, 'payment', 50, 'Subscription payment 51', '2026-07-17 09:00:00'),
('01K2F2DKG0FQSKR556H4RYMQNH', 9, 'revenue.subscription', 'credit', 2499.0, 'HKD', 1176.53, 'payment', 50, 'Subscription payment 51', '2026-07-13 09:00:00'),
('01K2F2DKG0FQSKR556H4RYMQNH', 9, 'tax_payable', 'credit', 124.95, 'HKD', 58.83, 'payment', 50, 'Subscription payment 51', '2026-07-19 09:00:00'),
('01K2F2DKG0FQSKR556H4RYMQNH', 9, 'expense.processor_fees', 'debit', 77.09, 'HKD', 36.29, 'payment', 50, 'Subscription payment 51', '2026-07-18 09:00:00'),
('01K2F2DKG0FQSKR556H4RYMQNH', 9, 'cash', 'credit', 77.09, 'HKD', 36.29, 'payment', 50, 'Subscription payment 51', '2026-07-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(52, '01K2F2DKG048D1DYVXBK5368DJ', 'LF-INV-2026000052', 9, 9, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'HKD', 0.4708, 1235.36, 5.0, 'VAT', 'Meridian Timepieces', 'billing@example.com', '2026-06-11 09:00:00', '2026-06-25 09:00:00', '2026-06-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000052.pdf', '2026-06-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(52, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-11', '2026-07-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(51, '01K2F2DKG0C3M2DFQ8F1G993GK', 'PAY-60051', 9, 52, 9, 9, 43, 2623.95, 'HKD', 0.4708, 1235.36, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0t0n0n161gcx6pts1', 'idem-01K2F2DKG08ZEFT72FB92TAHJR', 'https://cdn.livfinder.com/receipts/PAY-60051.pdf', '2026-06-15 09:00:00', '2026-06-15 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Q2MB0X24CX77Q84Z', 9, 'cash', 'debit', 2623.95, 'HKD', 1235.36, 'payment', 51, 'Subscription payment 52', '2026-06-11 09:00:00'),
('01K2F2DKG0Q2MB0X24CX77Q84Z', 9, 'revenue.subscription', 'credit', 2499.0, 'HKD', 1176.53, 'payment', 51, 'Subscription payment 52', '2026-06-17 09:00:00'),
('01K2F2DKG0Q2MB0X24CX77Q84Z', 9, 'tax_payable', 'credit', 124.95, 'HKD', 58.83, 'payment', 51, 'Subscription payment 52', '2026-06-12 09:00:00'),
('01K2F2DKG0Q2MB0X24CX77Q84Z', 9, 'expense.processor_fees', 'debit', 77.09, 'HKD', 36.29, 'payment', 51, 'Subscription payment 52', '2026-06-18 09:00:00'),
('01K2F2DKG0Q2MB0X24CX77Q84Z', 9, 'cash', 'credit', 77.09, 'HKD', 36.29, 'payment', 51, 'Subscription payment 52', '2026-06-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(53, '01K2F2DKG08C7J15W0ZNA01FFF', 'LF-INV-2026000053', 9, 9, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'HKD', 0.4708, 1235.36, 5.0, 'VAT', 'Meridian Timepieces', 'billing@example.com', '2026-05-12 09:00:00', '2026-05-26 09:00:00', '2026-05-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000053.pdf', '2026-05-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(53, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-12', '2026-06-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(52, '01K2F2DKG0TH65DJ4W6M38CK4B', 'PAY-60052', 9, 53, 9, 9, 43, 2623.95, 'HKD', 0.4708, 1235.36, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0shsvhqe69g224kfb', 'idem-01K2F2DKG0SME06K7DYZDSHH8A', 'https://cdn.livfinder.com/receipts/PAY-60052.pdf', '2026-05-24 09:00:00', '2026-05-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WENQAH2K2MJS0M1M', 9, 'cash', 'debit', 2623.95, 'HKD', 1235.36, 'payment', 52, 'Subscription payment 53', '2026-05-14 09:00:00'),
('01K2F2DKG0WENQAH2K2MJS0M1M', 9, 'revenue.subscription', 'credit', 2499.0, 'HKD', 1176.53, 'payment', 52, 'Subscription payment 53', '2026-05-23 09:00:00'),
('01K2F2DKG0WENQAH2K2MJS0M1M', 9, 'tax_payable', 'credit', 124.95, 'HKD', 58.83, 'payment', 52, 'Subscription payment 53', '2026-05-18 09:00:00'),
('01K2F2DKG0WENQAH2K2MJS0M1M', 9, 'expense.processor_fees', 'debit', 77.09, 'HKD', 36.29, 'payment', 52, 'Subscription payment 53', '2026-05-17 09:00:00'),
('01K2F2DKG0WENQAH2K2MJS0M1M', 9, 'cash', 'credit', 77.09, 'HKD', 36.29, 'payment', 52, 'Subscription payment 53', '2026-05-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(54, '01K2F2DKG0PGFXMQQDPWN08Z4X', 'LF-INV-2026000054', 9, 9, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'HKD', 0.4708, 1235.36, 5.0, 'VAT', 'Meridian Timepieces', 'billing@example.com', '2026-04-12 09:00:00', '2026-04-26 09:00:00', '2026-04-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000054.pdf', '2026-04-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(54, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-12', '2026-05-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(53, '01K2F2DKG09W7H9932XMW7QKDX', 'PAY-60053', 9, 54, 9, 9, 43, 2623.95, 'HKD', 0.4708, 1235.36, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kmh4acyemgrtvvqp', 'idem-01K2F2DKG09YKCHE0BCJ41RQ77', 'https://cdn.livfinder.com/receipts/PAY-60053.pdf', '2026-04-20 09:00:00', '2026-04-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Y4MXE6253KPXV02H', 9, 'cash', 'debit', 2623.95, 'HKD', 1235.36, 'payment', 53, 'Subscription payment 54', '2026-04-12 09:00:00'),
('01K2F2DKG0Y4MXE6253KPXV02H', 9, 'revenue.subscription', 'credit', 2499.0, 'HKD', 1176.53, 'payment', 53, 'Subscription payment 54', '2026-04-18 09:00:00'),
('01K2F2DKG0Y4MXE6253KPXV02H', 9, 'tax_payable', 'credit', 124.95, 'HKD', 58.83, 'payment', 53, 'Subscription payment 54', '2026-04-19 09:00:00'),
('01K2F2DKG0Y4MXE6253KPXV02H', 9, 'expense.processor_fees', 'debit', 77.09, 'HKD', 36.29, 'payment', 53, 'Subscription payment 54', '2026-04-24 09:00:00'),
('01K2F2DKG0Y4MXE6253KPXV02H', 9, 'cash', 'credit', 77.09, 'HKD', 36.29, 'payment', 53, 'Subscription payment 54', '2026-04-20 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(9, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-04-21 09:00:00'),
(9, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-11-13 09:00:00'),
(9, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-02 09:00:00'),
(9, 'listing', 20, 17, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-09 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(10, '01K2F2DKG0Z954EY9A93WRRHE7', 10, 47, 'card', 'stripe', 'pm_01k2f2dkg05v5kxeg0jg5sf3ja', 'mastercard', '1730', 2, 2028, 'Blackstone Development', 1, 'active', '2024-05-06 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(10, '01K2F2DKG0822J5AX58BNT96RQ', 10, 6, 'active', 149000.0, 'EUR', 593630.9, 'yearly', '2026-06-10 09:00:00', '2027-06-10 09:00:00', NULL, NULL, 1, 10, 'sub_01k2f2dkg04cc5mgh9yyhmpn3k', '2025-06-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(55, '01K2F2DKG0X0MT67MTN1P30YSZ', 'LF-INV-2026000055', 10, 10, 'past_due', 149000.0, 0, 7450.0, 156450.0, 0, 156450.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Development', 'billing@example.com', '2025-06-10 09:00:00', '2025-06-24 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000055.pdf', '2025-06-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(55, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-06-10', '2026-06-10', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(56, '01K2F2DKG0V477ECSQEVHYY30Z', 'LF-INV-2026000056', 10, 10, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Development', 'billing@example.com', '2024-06-10 09:00:00', '2024-06-24 09:00:00', '2024-06-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000056.pdf', '2024-06-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(56, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-06-10', '2025-06-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(54, '01K2F2DKG0WMJKE0VJXQBTBE7W', 'PAY-60054', 10, 56, 10, 10, 47, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09gmbxztacnse7fs5', 'idem-01K2F2DKG0YA7HV93E4SDWSKDN', 'https://cdn.livfinder.com/receipts/PAY-60054.pdf', '2024-06-12 09:00:00', '2024-06-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0W05TDW0YX35XMS2W', 10, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 54, 'Subscription payment 56', '2024-06-13 09:00:00'),
('01K2F2DKG0W05TDW0YX35XMS2W', 10, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 54, 'Subscription payment 56', '2024-06-20 09:00:00'),
('01K2F2DKG0W05TDW0YX35XMS2W', 10, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 54, 'Subscription payment 56', '2024-06-16 09:00:00'),
('01K2F2DKG0W05TDW0YX35XMS2W', 10, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 54, 'Subscription payment 56', '2024-06-14 09:00:00'),
('01K2F2DKG0W05TDW0YX35XMS2W', 10, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 54, 'Subscription payment 56', '2024-06-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(57, '01K2F2DKG0VGG097BYY9Z1NJ0X', 'LF-INV-2026000057', 10, 10, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Development', 'billing@example.com', '2023-06-11 09:00:00', '2023-06-25 09:00:00', '2023-06-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000057.pdf', '2023-06-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(57, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-06-11', '2024-06-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(55, '01K2F2DKG0R80JB95XE3ZVPYD8', 'PAY-60055', 10, 57, 10, 10, 47, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gvapwv0k2hzbe058', 'idem-01K2F2DKG0FV09N82DWJA8JDZW', 'https://cdn.livfinder.com/receipts/PAY-60055.pdf', '2023-06-19 09:00:00', '2023-06-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0E7RGEEB8N8H0V0BM', 10, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 55, 'Subscription payment 57', '2023-06-12 09:00:00'),
('01K2F2DKG0E7RGEEB8N8H0V0BM', 10, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 55, 'Subscription payment 57', '2023-06-22 09:00:00'),
('01K2F2DKG0E7RGEEB8N8H0V0BM', 10, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 55, 'Subscription payment 57', '2023-06-23 09:00:00'),
('01K2F2DKG0E7RGEEB8N8H0V0BM', 10, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 55, 'Subscription payment 57', '2023-06-18 09:00:00'),
('01K2F2DKG0E7RGEEB8N8H0V0BM', 10, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 55, 'Subscription payment 57', '2023-06-12 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(10, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-29 09:00:00'),
(10, 'listing', 50, 60, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-17 09:00:00'),
(10, 'listing', -2, 58, 'consumption', 'listing', NULL, 'Listing published', '2026-03-24 09:00:00'),
(10, 'listing', 20, 78, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-18 09:00:00'),
(10, 'listing', -2, 76, 'consumption', 'listing', NULL, 'Listing published', '2026-06-30 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(11, '01K2F2DKG0FT6EM5ED0554R8A0', 11, 51, 'card', 'stripe', 'pm_01k2f2dkg0dp4yd9qzn72kth3r', 'amex', '3935', 4, 2031, 'Crown Partners', 1, 'active', '2024-07-16 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(11, '01K2F2DKG02KXTWTZGRVPNBNDC', 11, 7, 'active', 89000.0, 'AED', 89000.0, 'yearly', '2026-08-12 09:00:00', '2027-08-12 09:00:00', NULL, NULL, 1, 11, 'sub_01k2f2dkg02e5tc58z2cge4dky', '2026-06-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(58, '01K2F2DKG0Y2FYAM4VH8WF9EGM', 'LF-INV-2026000058', 11, 11, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Crown Partners', 'billing@example.com', '2025-08-12 09:00:00', '2025-08-26 09:00:00', '2025-08-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000058.pdf', '2025-08-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(58, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2025-08-12', '2026-08-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(56, '01K2F2DKG0AGV8V66R55JFM4V1', 'PAY-60056', 11, 58, 11, 11, 51, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0f7p8mzkdpv2kmejt', 'idem-01K2F2DKG0PZ7SHTAYMC762RGV', 'https://cdn.livfinder.com/receipts/PAY-60056.pdf', '2025-08-24 09:00:00', '2025-08-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GD3J0KMENNF3D57M', 11, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 56, 'Subscription payment 58', '2025-08-22 09:00:00'),
('01K2F2DKG0GD3J0KMENNF3D57M', 11, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 56, 'Subscription payment 58', '2025-08-15 09:00:00'),
('01K2F2DKG0GD3J0KMENNF3D57M', 11, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 56, 'Subscription payment 58', '2025-08-12 09:00:00'),
('01K2F2DKG0GD3J0KMENNF3D57M', 11, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 56, 'Subscription payment 58', '2025-08-16 09:00:00'),
('01K2F2DKG0GD3J0KMENNF3D57M', 11, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 56, 'Subscription payment 58', '2025-08-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(59, '01K2F2DKG0FFRTHQP8QYXXDDAM', 'LF-INV-2026000059', 11, 11, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Crown Partners', 'billing@example.com', '2024-08-12 09:00:00', '2024-08-26 09:00:00', '2024-08-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000059.pdf', '2024-08-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(59, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2024-08-12', '2025-08-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(57, '01K2F2DKG0F2J2QAAR97DAE2W6', 'PAY-60057', 11, 59, 11, 11, 51, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0n9ahw1x5kg42drsr', 'idem-01K2F2DKG0R1QVAJZMYZN4165F', 'https://cdn.livfinder.com/receipts/PAY-60057.pdf', '2024-08-21 09:00:00', '2024-08-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YNYEBF220TDV18ZK', 11, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 57, 'Subscription payment 59', '2024-08-15 09:00:00'),
('01K2F2DKG0YNYEBF220TDV18ZK', 11, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 57, 'Subscription payment 59', '2024-08-16 09:00:00'),
('01K2F2DKG0YNYEBF220TDV18ZK', 11, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 57, 'Subscription payment 59', '2024-08-21 09:00:00'),
('01K2F2DKG0YNYEBF220TDV18ZK', 11, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 57, 'Subscription payment 59', '2024-08-24 09:00:00'),
('01K2F2DKG0YNYEBF220TDV18ZK', 11, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 57, 'Subscription payment 59', '2024-08-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(60, '01K2F2DKG031GDBSWQ157WSBEN', 'LF-INV-2026000060', 11, 11, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Crown Partners', 'billing@example.com', '2023-08-13 09:00:00', '2023-08-27 09:00:00', '2023-08-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000060.pdf', '2023-08-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(60, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2023-08-13', '2024-08-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(58, '01K2F2DKG0SZ0D08RP2NCNENM8', 'PAY-60058', 11, 60, 11, 11, 51, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03w545c6by8y35ezn', 'idem-01K2F2DKG0Z078ZDYCZJ8MMGMZ', 'https://cdn.livfinder.com/receipts/PAY-60058.pdf', '2023-08-22 09:00:00', '2023-08-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TMQCQQHFSVQ95FPJ', 11, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 58, 'Subscription payment 60', '2023-08-16 09:00:00'),
('01K2F2DKG0TMQCQQHFSVQ95FPJ', 11, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 58, 'Subscription payment 60', '2023-08-21 09:00:00'),
('01K2F2DKG0TMQCQQHFSVQ95FPJ', 11, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 58, 'Subscription payment 60', '2023-08-25 09:00:00'),
('01K2F2DKG0TMQCQQHFSVQ95FPJ', 11, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 58, 'Subscription payment 60', '2023-08-25 09:00:00'),
('01K2F2DKG0TMQCQQHFSVQ95FPJ', 11, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 58, 'Subscription payment 60', '2023-08-23 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(11, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-30 09:00:00'),
(11, 'listing', 10, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-08-15 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(12, '01K2F2DKG0J0GXBXAR9AAG6MK3', 12, 55, 'card', 'stripe', 'pm_01k2f2dkg0w2frvgbk85zjpye4', 'visa', '9082', 10, 2028, 'Azure Properties', 1, 'active', '2025-07-16 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(12, '01K2F2DKG0B6QQT0C7XZ078KMW', 12, 4, 'active', 2499.0, 'SAR', 2447.52, 'monthly', '2026-08-11 09:00:00', '2026-09-10 09:00:00', NULL, NULL, 1, 12, 'sub_01k2f2dkg0vy37rxk3jh352x2q', '2025-03-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(61, '01K2F2DKG0W55GF0P479G12909', 'LF-INV-2026000061', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-07-12 09:00:00', '2026-07-26 09:00:00', '2026-07-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000061.pdf', '2026-07-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(61, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-12', '2026-08-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(59, '01K2F2DKG0E2QX420YJSE5MCKX', 'PAY-60059', 12, 61, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0x2dt6exmag03nmyy', 'idem-01K2F2DKG0KBKQ454AY9WCTKB5', 'https://cdn.livfinder.com/receipts/PAY-60059.pdf', '2026-07-13 09:00:00', '2026-07-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0A8MWHT4104CBXG5M', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 59, 'Subscription payment 61', '2026-07-19 09:00:00'),
('01K2F2DKG0A8MWHT4104CBXG5M', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 59, 'Subscription payment 61', '2026-07-17 09:00:00'),
('01K2F2DKG0A8MWHT4104CBXG5M', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 59, 'Subscription payment 61', '2026-07-15 09:00:00'),
('01K2F2DKG0A8MWHT4104CBXG5M', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 59, 'Subscription payment 61', '2026-07-15 09:00:00'),
('01K2F2DKG0A8MWHT4104CBXG5M', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 59, 'Subscription payment 61', '2026-07-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(62, '01K2F2DKG0YXMF5XCGY5S91JGV', 'LF-INV-2026000062', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-06-12 09:00:00', '2026-06-26 09:00:00', '2026-06-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000062.pdf', '2026-06-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(62, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-12', '2026-07-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(60, '01K2F2DKG0BB88PX47ZVJNFDVA', 'PAY-60060', 12, 62, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0sztpqfgqfne2jw82', 'idem-01K2F2DKG01SVQHW0A6NJHCB4H', 'https://cdn.livfinder.com/receipts/PAY-60060.pdf', '2026-06-24 09:00:00', '2026-06-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG009HZ4AH79HNPKR14', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 60, 'Subscription payment 62', '2026-06-18 09:00:00'),
('01K2F2DKG009HZ4AH79HNPKR14', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 60, 'Subscription payment 62', '2026-06-17 09:00:00'),
('01K2F2DKG009HZ4AH79HNPKR14', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 60, 'Subscription payment 62', '2026-06-18 09:00:00'),
('01K2F2DKG009HZ4AH79HNPKR14', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 60, 'Subscription payment 62', '2026-06-12 09:00:00'),
('01K2F2DKG009HZ4AH79HNPKR14', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 60, 'Subscription payment 62', '2026-06-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(63, '01K2F2DKG0PYS8AC6GJ8H1MHB4', 'LF-INV-2026000063', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-05-13 09:00:00', '2026-05-27 09:00:00', '2026-05-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000063.pdf', '2026-05-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(63, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-13', '2026-06-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(61, '01K2F2DKG0HD557K5JZW8PYQWV', 'PAY-60061', 12, 63, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0b002c1qhe5nhtsda', 'idem-01K2F2DKG03SRE30BZ2S77AV77', 'https://cdn.livfinder.com/receipts/PAY-60061.pdf', '2026-05-20 09:00:00', '2026-05-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08ADFK29DHF2GRTC2', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 61, 'Subscription payment 63', '2026-05-16 09:00:00'),
('01K2F2DKG08ADFK29DHF2GRTC2', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 61, 'Subscription payment 63', '2026-05-24 09:00:00'),
('01K2F2DKG08ADFK29DHF2GRTC2', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 61, 'Subscription payment 63', '2026-05-15 09:00:00'),
('01K2F2DKG08ADFK29DHF2GRTC2', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 61, 'Subscription payment 63', '2026-05-21 09:00:00'),
('01K2F2DKG08ADFK29DHF2GRTC2', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 61, 'Subscription payment 63', '2026-05-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(64, '01K2F2DKG0W98X2CTXJHJJ5B5Y', 'LF-INV-2026000064', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-04-13 09:00:00', '2026-04-27 09:00:00', '2026-04-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000064.pdf', '2026-04-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(64, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-13', '2026-05-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(62, '01K2F2DKG0D3NPYKCZH0N3V7C6', 'PAY-60062', 12, 64, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0zb3tpqek5dygr6wn', 'idem-01K2F2DKG0BBYM5WSNCAN5656T', 'https://cdn.livfinder.com/receipts/PAY-60062.pdf', '2026-04-18 09:00:00', '2026-04-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0N6XZRS7VYCJ2XXNK', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 62, 'Subscription payment 64', '2026-04-25 09:00:00'),
('01K2F2DKG0N6XZRS7VYCJ2XXNK', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 62, 'Subscription payment 64', '2026-04-23 09:00:00'),
('01K2F2DKG0N6XZRS7VYCJ2XXNK', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 62, 'Subscription payment 64', '2026-04-15 09:00:00'),
('01K2F2DKG0N6XZRS7VYCJ2XXNK', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 62, 'Subscription payment 64', '2026-04-16 09:00:00'),
('01K2F2DKG0N6XZRS7VYCJ2XXNK', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 62, 'Subscription payment 64', '2026-04-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(65, '01K2F2DKG0VR546385J64168N6', 'LF-INV-2026000065', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-03-14 09:00:00', '2026-03-28 09:00:00', '2026-03-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000065.pdf', '2026-03-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(65, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-14', '2026-04-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(63, '01K2F2DKG0KQ3APGNQMGDG27T0', 'PAY-60063', 12, 65, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0wf4wtnbt8hcrkf7n', 'idem-01K2F2DKG0BNSCF8ZH4JNVH6FT', 'https://cdn.livfinder.com/receipts/PAY-60063.pdf', '2026-03-24 09:00:00', '2026-03-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06DZ8ZWVH7BZVZH18', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 63, 'Subscription payment 65', '2026-03-15 09:00:00'),
('01K2F2DKG06DZ8ZWVH7BZVZH18', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 63, 'Subscription payment 65', '2026-03-22 09:00:00'),
('01K2F2DKG06DZ8ZWVH7BZVZH18', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 63, 'Subscription payment 65', '2026-03-14 09:00:00'),
('01K2F2DKG06DZ8ZWVH7BZVZH18', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 63, 'Subscription payment 65', '2026-03-22 09:00:00'),
('01K2F2DKG06DZ8ZWVH7BZVZH18', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 63, 'Subscription payment 65', '2026-03-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(66, '01K2F2DKG00MJ5T2M2YTRXKGTE', 'LF-INV-2026000066', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-02-12 09:00:00', '2026-02-26 09:00:00', '2026-02-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000066.pdf', '2026-02-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(66, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-12', '2026-03-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(64, '01K2F2DKG09SJRR4X4EYDED2Y6', 'PAY-60064', 12, 66, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pmap3hkesdha8djq', 'idem-01K2F2DKG012RFWZE1STZTTJDW', 'https://cdn.livfinder.com/receipts/PAY-60064.pdf', '2026-02-16 09:00:00', '2026-02-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00DCT97N9R08S74CC', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 64, 'Subscription payment 66', '2026-02-20 09:00:00'),
('01K2F2DKG00DCT97N9R08S74CC', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 64, 'Subscription payment 66', '2026-02-16 09:00:00'),
('01K2F2DKG00DCT97N9R08S74CC', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 64, 'Subscription payment 66', '2026-02-18 09:00:00'),
('01K2F2DKG00DCT97N9R08S74CC', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 64, 'Subscription payment 66', '2026-02-19 09:00:00'),
('01K2F2DKG00DCT97N9R08S74CC', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 64, 'Subscription payment 66', '2026-02-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(67, '01K2F2DKG089WJNQPGGHMKH4EH', 'LF-INV-2026000067', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2026-01-13 09:00:00', '2026-01-27 09:00:00', '2026-01-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000067.pdf', '2026-01-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(67, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-13', '2026-02-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(65, '01K2F2DKG0V7261G8C28ZVYEXE', 'PAY-60065', 12, 67, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0eyxs45mmm9gxt60t', 'idem-01K2F2DKG0DN93SQ69JHCK5Z3W', 'https://cdn.livfinder.com/receipts/PAY-60065.pdf', '2026-01-23 09:00:00', '2026-01-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0E86CAYAMAW08J4BS', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 65, 'Subscription payment 67', '2026-01-15 09:00:00'),
('01K2F2DKG0E86CAYAMAW08J4BS', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 65, 'Subscription payment 67', '2026-01-20 09:00:00'),
('01K2F2DKG0E86CAYAMAW08J4BS', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 65, 'Subscription payment 67', '2026-01-16 09:00:00'),
('01K2F2DKG0E86CAYAMAW08J4BS', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 65, 'Subscription payment 67', '2026-01-16 09:00:00'),
('01K2F2DKG0E86CAYAMAW08J4BS', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 65, 'Subscription payment 67', '2026-01-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(68, '01K2F2DKG0H1N3AD7DMSRKZPAD', 'LF-INV-2026000068', 12, 12, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Azure Properties', 'billing@example.com', '2025-12-14 09:00:00', '2025-12-28 09:00:00', '2025-12-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000068.pdf', '2025-12-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(68, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-14', '2026-01-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(66, '01K2F2DKG0DJYP8TJR5W130QG5', 'PAY-60066', 12, 68, 12, 12, 55, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bb5rbdx0mkq6ede3', 'idem-01K2F2DKG08GR3R1613ZPMH9E4', 'https://cdn.livfinder.com/receipts/PAY-60066.pdf', '2025-12-20 09:00:00', '2025-12-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0DQ3GBHJNK0EYNPW5', 12, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 66, 'Subscription payment 68', '2025-12-25 09:00:00'),
('01K2F2DKG0DQ3GBHJNK0EYNPW5', 12, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 66, 'Subscription payment 68', '2025-12-22 09:00:00'),
('01K2F2DKG0DQ3GBHJNK0EYNPW5', 12, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 66, 'Subscription payment 68', '2025-12-14 09:00:00'),
('01K2F2DKG0DQ3GBHJNK0EYNPW5', 12, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 66, 'Subscription payment 68', '2025-12-19 09:00:00'),
('01K2F2DKG0DQ3GBHJNK0EYNPW5', 12, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 66, 'Subscription payment 68', '2025-12-26 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(12, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-11-28 09:00:00'),
(12, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-10-29 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(13, '01K2F2DKG0D2RZWWAMRJR7NTJ6', 13, 59, 'card', 'stripe', 'pm_01k2f2dkg0fsqnw5zxzrgk1v8s', 'mastercard', '4062', 9, 2030, 'Palladium Real Estate', 1, 'active', '2026-05-31 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(13, '01K2F2DKG0VPKCE64ME3QR7YKB', 13, 6, 'active', 149000.0, 'AED', 149000.0, 'yearly', '2026-06-30 09:00:00', '2027-06-30 09:00:00', NULL, NULL, 1, 13, 'sub_01k2f2dkg03zsrqgsx5gwrt8ah', '2024-05-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(69, '01K2F2DKG0ACC4VW785FK58KT9', 'LF-INV-2026000069', 13, 13, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Palladium Real Estate', 'billing@example.com', '2025-06-30 09:00:00', '2025-07-14 09:00:00', '2025-07-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000069.pdf', '2025-06-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(69, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-06-30', '2026-06-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(67, '01K2F2DKG0SHW48HVN4VHQYW2N', 'PAY-60067', 13, 69, 13, 13, 59, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ebk176a9e1hf3ykw', 'idem-01K2F2DKG0151GF1CTVXKY4RHD', 'https://cdn.livfinder.com/receipts/PAY-60067.pdf', '2025-07-09 09:00:00', '2025-07-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NDVHN7V8W0PECA1G', 13, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 67, 'Subscription payment 69', '2025-07-01 09:00:00'),
('01K2F2DKG0NDVHN7V8W0PECA1G', 13, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 67, 'Subscription payment 69', '2025-07-08 09:00:00'),
('01K2F2DKG0NDVHN7V8W0PECA1G', 13, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 67, 'Subscription payment 69', '2025-07-06 09:00:00'),
('01K2F2DKG0NDVHN7V8W0PECA1G', 13, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 67, 'Subscription payment 69', '2025-06-30 09:00:00'),
('01K2F2DKG0NDVHN7V8W0PECA1G', 13, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 67, 'Subscription payment 69', '2025-07-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(70, '01K2F2DKG0847Z7JJS5STJKS0H', 'LF-INV-2026000070', 13, 13, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Palladium Real Estate', 'billing@example.com', '2024-06-30 09:00:00', '2024-07-14 09:00:00', '2024-07-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000070.pdf', '2024-06-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(70, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-06-30', '2025-06-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(68, '01K2F2DKG0JVXH6BWC31AVTXB4', 'PAY-60068', 13, 70, 13, 13, 59, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kyj5kjrqkzrcnsnd', 'idem-01K2F2DKG0MZ2BRJAVYZ72A47Z', 'https://cdn.livfinder.com/receipts/PAY-60068.pdf', '2024-06-30 09:00:00', '2024-07-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04M151001Z4F3WECA', 13, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 68, 'Subscription payment 70', '2024-07-01 09:00:00'),
('01K2F2DKG04M151001Z4F3WECA', 13, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 68, 'Subscription payment 70', '2024-07-06 09:00:00'),
('01K2F2DKG04M151001Z4F3WECA', 13, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 68, 'Subscription payment 70', '2024-07-11 09:00:00'),
('01K2F2DKG04M151001Z4F3WECA', 13, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 68, 'Subscription payment 70', '2024-07-08 09:00:00'),
('01K2F2DKG04M151001Z4F3WECA', 13, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 68, 'Subscription payment 70', '2024-07-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(71, '01K2F2DKG0RZVK8Z1QSH0GNW0R', 'LF-INV-2026000071', 13, 13, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Palladium Real Estate', 'billing@example.com', '2023-07-01 09:00:00', '2023-07-15 09:00:00', '2023-07-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000071.pdf', '2023-07-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(71, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-07-01', '2024-06-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(69, '01K2F2DKG0CESRXYJQMKSWXWHG', 'PAY-60069', 13, 71, 13, 13, 59, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dx9bh0ke4qr5w6ns', 'idem-01K2F2DKG0RFN1QSF74ZWVDY00', 'https://cdn.livfinder.com/receipts/PAY-60069.pdf', '2023-07-02 09:00:00', '2023-07-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0BVHVFM5XE1R94W52', 13, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 69, 'Subscription payment 71', '2023-07-04 09:00:00'),
('01K2F2DKG0BVHVFM5XE1R94W52', 13, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 69, 'Subscription payment 71', '2023-07-08 09:00:00'),
('01K2F2DKG0BVHVFM5XE1R94W52', 13, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 69, 'Subscription payment 71', '2023-07-09 09:00:00'),
('01K2F2DKG0BVHVFM5XE1R94W52', 13, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 69, 'Subscription payment 71', '2023-07-04 09:00:00'),
('01K2F2DKG0BVHVFM5XE1R94W52', 13, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 69, 'Subscription payment 71', '2023-07-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(72, '01K2F2DKG0E8X959D46HWFSSVC', 'LF-INV-2026000072', 13, 13, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'AED', 1.0, 156450.0, 5.0, 'VAT', 'Palladium Real Estate', 'billing@example.com', '2022-07-01 09:00:00', '2022-07-15 09:00:00', '2022-07-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000072.pdf', '2022-07-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(72, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-07-01', '2023-07-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(70, '01K2F2DKG0RPY0EZP2HKS87J86', 'PAY-60070', 13, 72, 13, 13, 59, 156450.0, 'AED', 1.0, 156450.0, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0g6v8kpjekp04v0es', 'idem-01K2F2DKG0PVY4S1YEGTBGFZM5', 'https://cdn.livfinder.com/receipts/PAY-60070.pdf', '2022-07-01 09:00:00', '2022-07-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RTQM6C5WDZJYJRQ6', 13, 'cash', 'debit', 156450.0, 'AED', 156450.0, 'payment', 70, 'Subscription payment 72', '2022-07-04 09:00:00'),
('01K2F2DKG0RTQM6C5WDZJYJRQ6', 13, 'revenue.subscription', 'credit', 149000.0, 'AED', 149000.0, 'payment', 70, 'Subscription payment 72', '2022-07-04 09:00:00'),
('01K2F2DKG0RTQM6C5WDZJYJRQ6', 13, 'tax_payable', 'credit', 7450.0, 'AED', 7450.0, 'payment', 70, 'Subscription payment 72', '2022-07-11 09:00:00'),
('01K2F2DKG0RTQM6C5WDZJYJRQ6', 13, 'expense.processor_fees', 'debit', 4538.05, 'AED', 4538.05, 'payment', 70, 'Subscription payment 72', '2022-07-01 09:00:00'),
('01K2F2DKG0RTQM6C5WDZJYJRQ6', 13, 'cash', 'credit', 4538.05, 'AED', 4538.05, 'payment', 70, 'Subscription payment 72', '2022-07-06 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(13, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-14 09:00:00'),
(13, 'listing', 50, 48, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-14 09:00:00'),
(13, 'listing', -1, 47, 'consumption', 'listing', NULL, 'Listing published', '2025-11-20 09:00:00'),
(13, 'listing', -1, 46, 'consumption', 'listing', NULL, 'Listing published', '2025-11-03 09:00:00'),
(13, 'listing', 20, 66, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-21 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(14, '01K2F2DKG0CCFP8R6DNX71DDJE', 14, 63, 'card', 'stripe', 'pm_01k2f2dkg0t6xkwmyzzgdqwhyx', 'mastercard', '1632', 8, 2030, 'Sovereign Estates', 1, 'active', '2024-11-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(14, '01K2F2DKG07W1SA9B9N3KMAP8S', 14, 4, 'active', 2499.0, 'EUR', 9956.27, 'monthly', '2026-08-13 09:00:00', '2026-09-12 09:00:00', NULL, NULL, 1, 14, 'sub_01k2f2dkg06v9ny69j2b14w6gc', '2025-12-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(73, '01K2F2DKG07FETPABN65DNN23Q', 'LF-INV-2026000073', 14, 14, 'open', 2499.0, 0, 124.95, 2623.95, 0, 2623.95, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-07-14 09:00:00', '2026-07-28 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000073.pdf', '2026-07-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(73, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-14', '2026-08-13', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(74, '01K2F2DKG0R4XVZP140SC1X1ZG', 'LF-INV-2026000074', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-06-14 09:00:00', '2026-06-28 09:00:00', '2026-06-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000074.pdf', '2026-06-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(74, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-14', '2026-07-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(71, '01K2F2DKG0A8XJ4A184J53Q7W1', 'PAY-60071', 14, 74, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rxaepeqm053qet0a', 'idem-01K2F2DKG0XAPSWA5GCM1VQV2W', 'https://cdn.livfinder.com/receipts/PAY-60071.pdf', '2026-06-25 09:00:00', '2026-06-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0DQXW5GBCE2VVT2G1', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 71, 'Subscription payment 74', '2026-06-21 09:00:00'),
('01K2F2DKG0DQXW5GBCE2VVT2G1', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 71, 'Subscription payment 74', '2026-06-19 09:00:00'),
('01K2F2DKG0DQXW5GBCE2VVT2G1', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 71, 'Subscription payment 74', '2026-06-22 09:00:00'),
('01K2F2DKG0DQXW5GBCE2VVT2G1', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 71, 'Subscription payment 74', '2026-06-16 09:00:00'),
('01K2F2DKG0DQXW5GBCE2VVT2G1', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 71, 'Subscription payment 74', '2026-06-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(75, '01K2F2DKG00M2DZWPMRS99ENDP', 'LF-INV-2026000075', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-05-15 09:00:00', '2026-05-29 09:00:00', '2026-05-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000075.pdf', '2026-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(75, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-15', '2026-06-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(72, '01K2F2DKG072K60M88P9S4H08W', 'PAY-60072', 14, 75, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0fwmmqf1m3x6npdkh', 'idem-01K2F2DKG019JJ8J4H91CTNXYT', 'https://cdn.livfinder.com/receipts/PAY-60072.pdf', '2026-05-24 09:00:00', '2026-05-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YPA8FMDFK1569CWQ', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 72, 'Subscription payment 75', '2026-05-22 09:00:00'),
('01K2F2DKG0YPA8FMDFK1569CWQ', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 72, 'Subscription payment 75', '2026-05-22 09:00:00'),
('01K2F2DKG0YPA8FMDFK1569CWQ', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 72, 'Subscription payment 75', '2026-05-24 09:00:00'),
('01K2F2DKG0YPA8FMDFK1569CWQ', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 72, 'Subscription payment 75', '2026-05-17 09:00:00'),
('01K2F2DKG0YPA8FMDFK1569CWQ', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 72, 'Subscription payment 75', '2026-05-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(76, '01K2F2DKG0XF78B225X3JPGJM6', 'LF-INV-2026000076', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-04-15 09:00:00', '2026-04-29 09:00:00', '2026-04-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000076.pdf', '2026-04-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(76, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-15', '2026-05-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(73, '01K2F2DKG0X61NF6WX0ZQV1SWM', 'PAY-60073', 14, 76, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0yq2dhgqdd1tt8hvp', 'idem-01K2F2DKG0MCKPYK4ECZ2QV1VH', 'https://cdn.livfinder.com/receipts/PAY-60073.pdf', '2026-04-22 09:00:00', '2026-04-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0SC2C0W05X2WP79Z7', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 73, 'Subscription payment 76', '2026-04-24 09:00:00'),
('01K2F2DKG0SC2C0W05X2WP79Z7', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 73, 'Subscription payment 76', '2026-04-20 09:00:00'),
('01K2F2DKG0SC2C0W05X2WP79Z7', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 73, 'Subscription payment 76', '2026-04-22 09:00:00'),
('01K2F2DKG0SC2C0W05X2WP79Z7', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 73, 'Subscription payment 76', '2026-04-23 09:00:00'),
('01K2F2DKG0SC2C0W05X2WP79Z7', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 73, 'Subscription payment 76', '2026-04-27 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(77, '01K2F2DKG0EV6J52JRSW87XD9Y', 'LF-INV-2026000077', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-03-16 09:00:00', '2026-03-30 09:00:00', '2026-03-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000077.pdf', '2026-03-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(77, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-16', '2026-04-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(74, '01K2F2DKG0CCS4ZT2H41GA1XEC', 'PAY-60074', 14, 77, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dcfn5bv7eqkgcewa', 'idem-01K2F2DKG0AXYJR504E0BR7DEA', 'https://cdn.livfinder.com/receipts/PAY-60074.pdf', '2026-03-25 09:00:00', '2026-03-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00FPSWPJ2C6E3Z3VY', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 74, 'Subscription payment 77', '2026-03-28 09:00:00'),
('01K2F2DKG00FPSWPJ2C6E3Z3VY', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 74, 'Subscription payment 77', '2026-03-23 09:00:00'),
('01K2F2DKG00FPSWPJ2C6E3Z3VY', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 74, 'Subscription payment 77', '2026-03-26 09:00:00'),
('01K2F2DKG00FPSWPJ2C6E3Z3VY', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 74, 'Subscription payment 77', '2026-03-24 09:00:00'),
('01K2F2DKG00FPSWPJ2C6E3Z3VY', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 74, 'Subscription payment 77', '2026-03-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(78, '01K2F2DKG0N8BW6QXEBAZYA95R', 'LF-INV-2026000078', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-02-14 09:00:00', '2026-02-28 09:00:00', '2026-02-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000078.pdf', '2026-02-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(78, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-14', '2026-03-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(75, '01K2F2DKG0MD3H0KY9W5C8KJFW', 'PAY-60075', 14, 78, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0nktmgeeahs0fveq6', 'idem-01K2F2DKG0PM3GJ19R83PEEV4Q', 'https://cdn.livfinder.com/receipts/PAY-60075.pdf', '2026-02-17 09:00:00', '2026-02-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0A5XPD43VG8MRHHRS', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 75, 'Subscription payment 78', '2026-02-14 09:00:00'),
('01K2F2DKG0A5XPD43VG8MRHHRS', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 75, 'Subscription payment 78', '2026-02-14 09:00:00'),
('01K2F2DKG0A5XPD43VG8MRHHRS', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 75, 'Subscription payment 78', '2026-02-18 09:00:00'),
('01K2F2DKG0A5XPD43VG8MRHHRS', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 75, 'Subscription payment 78', '2026-02-14 09:00:00'),
('01K2F2DKG0A5XPD43VG8MRHHRS', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 75, 'Subscription payment 78', '2026-02-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(79, '01K2F2DKG0MBQQAW3RR7M2BXG7', 'LF-INV-2026000079', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2026-01-15 09:00:00', '2026-01-29 09:00:00', '2026-01-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000079.pdf', '2026-01-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(79, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-15', '2026-02-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(76, '01K2F2DKG0XEQG33KQ7DBRPWS0', 'PAY-60076', 14, 79, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg05mdfdz6evsta1c7x', 'idem-01K2F2DKG08V5AYMQ91BSVPZZG', 'https://cdn.livfinder.com/receipts/PAY-60076.pdf', '2026-01-16 09:00:00', '2026-01-15 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG05JJKPCJPH99N82DW', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 76, 'Subscription payment 79', '2026-01-19 09:00:00'),
('01K2F2DKG05JJKPCJPH99N82DW', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 76, 'Subscription payment 79', '2026-01-24 09:00:00'),
('01K2F2DKG05JJKPCJPH99N82DW', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 76, 'Subscription payment 79', '2026-01-16 09:00:00'),
('01K2F2DKG05JJKPCJPH99N82DW', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 76, 'Subscription payment 79', '2026-01-27 09:00:00'),
('01K2F2DKG05JJKPCJPH99N82DW', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 76, 'Subscription payment 79', '2026-01-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(80, '01K2F2DKG0ZE9GK3FJ4GBQQQSN', 'LF-INV-2026000080', 14, 14, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Sovereign Estates', 'billing@example.com', '2025-12-16 09:00:00', '2025-12-30 09:00:00', '2025-12-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000080.pdf', '2025-12-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(80, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-16', '2026-01-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(77, '01K2F2DKG0AFC71DNT03W9Q369', 'PAY-60077', 14, 80, 14, 14, 63, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bpcw4b23827wy2sm', 'idem-01K2F2DKG02BRKW1VSXVD1WWGZ', 'https://cdn.livfinder.com/receipts/PAY-60077.pdf', '2025-12-27 09:00:00', '2025-12-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XW25H3A83RG27EB2', 14, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 77, 'Subscription payment 80', '2025-12-22 09:00:00'),
('01K2F2DKG0XW25H3A83RG27EB2', 14, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 77, 'Subscription payment 80', '2025-12-20 09:00:00'),
('01K2F2DKG0XW25H3A83RG27EB2', 14, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 77, 'Subscription payment 80', '2025-12-16 09:00:00'),
('01K2F2DKG0XW25H3A83RG27EB2', 14, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 77, 'Subscription payment 80', '2025-12-22 09:00:00'),
('01K2F2DKG0XW25H3A83RG27EB2', 14, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 77, 'Subscription payment 80', '2025-12-23 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(14, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-04 09:00:00'),
(14, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-04 09:00:00'),
(14, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-28 09:00:00'),
(14, 'listing', 10, 5, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-01 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(15, '01K2F2DKG0GSDKKZCCB4V4E9RZ', 15, 67, 'card', 'stripe', 'pm_01k2f2dkg0swvn31f6jm8bq287', 'visa', '8713', 1, 2029, 'Beaufort Motors', 1, 'active', '2026-04-30 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(15, '01K2F2DKG0Z5EN7FTVERRKSAY7', 15, 4, 'cancelled', 2499.0, 'SAR', 2447.52, 'monthly', '2026-08-10 09:00:00', '2026-09-09 09:00:00', NULL, '2026-08-04 09:00:00', 0, 15, 'sub_01k2f2dkg0njnmz283kyb3bhks', '2024-07-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(81, '01K2F2DKG0EAJY4XCA386XN4MS', 'LF-INV-2026000081', 15, 15, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Beaufort Motors', 'billing@example.com', '2026-07-11 09:00:00', '2026-07-25 09:00:00', '2026-07-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000081.pdf', '2026-07-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(81, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-11', '2026-08-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(78, '01K2F2DKG0JQB61E4RP521YS9Q', 'PAY-60078', 15, 81, 15, 15, 67, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0g30z6mf21hwkqrsp', 'idem-01K2F2DKG0Q2282G7CFMRG4DVM', 'https://cdn.livfinder.com/receipts/PAY-60078.pdf', '2026-07-22 09:00:00', '2026-07-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TAYVQMDY4C17CJKX', 15, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 78, 'Subscription payment 81', '2026-07-23 09:00:00'),
('01K2F2DKG0TAYVQMDY4C17CJKX', 15, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 78, 'Subscription payment 81', '2026-07-11 09:00:00'),
('01K2F2DKG0TAYVQMDY4C17CJKX', 15, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 78, 'Subscription payment 81', '2026-07-13 09:00:00'),
('01K2F2DKG0TAYVQMDY4C17CJKX', 15, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 78, 'Subscription payment 81', '2026-07-11 09:00:00'),
('01K2F2DKG0TAYVQMDY4C17CJKX', 15, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 78, 'Subscription payment 81', '2026-07-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(82, '01K2F2DKG0ZZ2B7PPTY92KT4QW', 'LF-INV-2026000082', 15, 15, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Beaufort Motors', 'billing@example.com', '2026-06-11 09:00:00', '2026-06-25 09:00:00', '2026-06-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000082.pdf', '2026-06-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(82, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-11', '2026-07-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(79, '01K2F2DKG0103TY4NBXX9Y68HT', 'PAY-60079', 15, 82, 15, 15, 67, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0h333ww1n70srj3fp', 'idem-01K2F2DKG01G7S2KYFGB238NXQ', 'https://cdn.livfinder.com/receipts/PAY-60079.pdf', '2026-06-11 09:00:00', '2026-06-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RX8VTF7Q9D72B7Y9', 15, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 79, 'Subscription payment 82', '2026-06-23 09:00:00'),
('01K2F2DKG0RX8VTF7Q9D72B7Y9', 15, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 79, 'Subscription payment 82', '2026-06-15 09:00:00'),
('01K2F2DKG0RX8VTF7Q9D72B7Y9', 15, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 79, 'Subscription payment 82', '2026-06-21 09:00:00'),
('01K2F2DKG0RX8VTF7Q9D72B7Y9', 15, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 79, 'Subscription payment 82', '2026-06-18 09:00:00'),
('01K2F2DKG0RX8VTF7Q9D72B7Y9', 15, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 79, 'Subscription payment 82', '2026-06-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(83, '01K2F2DKG0A8ENZA5MG7ED03S0', 'LF-INV-2026000083', 15, 15, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Beaufort Motors', 'billing@example.com', '2026-05-12 09:00:00', '2026-05-26 09:00:00', '2026-05-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000083.pdf', '2026-05-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(83, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-12', '2026-06-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(80, '01K2F2DKG00166AB2XW5F4BF9E', 'PAY-60080', 15, 83, 15, 15, 67, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09ba0v0tyy9t9pwas', 'idem-01K2F2DKG0HKKZSSGCAR3YSK72', 'https://cdn.livfinder.com/receipts/PAY-60080.pdf', '2026-05-13 09:00:00', '2026-05-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06J9QMGW5ATWF0A3M', 15, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 80, 'Subscription payment 83', '2026-05-24 09:00:00'),
('01K2F2DKG06J9QMGW5ATWF0A3M', 15, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 80, 'Subscription payment 83', '2026-05-14 09:00:00'),
('01K2F2DKG06J9QMGW5ATWF0A3M', 15, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 80, 'Subscription payment 83', '2026-05-21 09:00:00'),
('01K2F2DKG06J9QMGW5ATWF0A3M', 15, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 80, 'Subscription payment 83', '2026-05-13 09:00:00'),
('01K2F2DKG06J9QMGW5ATWF0A3M', 15, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 80, 'Subscription payment 83', '2026-05-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(84, '01K2F2DKG03W3G4M7RY0PWK198', 'LF-INV-2026000084', 15, 15, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'SAR', 0.9794, 2569.9, 5.0, 'VAT', 'Beaufort Motors', 'billing@example.com', '2026-04-12 09:00:00', '2026-04-26 09:00:00', '2026-04-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000084.pdf', '2026-04-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(84, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-12', '2026-05-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(81, '01K2F2DKG0CQSRPHH9WK8MVTTC', 'PAY-60081', 15, 84, 15, 15, 67, 2623.95, 'SAR', 0.9794, 2569.9, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0f8c0z4m3akew93hb', 'idem-01K2F2DKG02RMJDRACZPBHFJNH', 'https://cdn.livfinder.com/receipts/PAY-60081.pdf', '2026-04-23 09:00:00', '2026-04-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HSGM3A1KS79KWHWT', 15, 'cash', 'debit', 2623.95, 'SAR', 2569.9, 'payment', 81, 'Subscription payment 84', '2026-04-21 09:00:00'),
('01K2F2DKG0HSGM3A1KS79KWHWT', 15, 'revenue.subscription', 'credit', 2499.0, 'SAR', 2447.52, 'payment', 81, 'Subscription payment 84', '2026-04-14 09:00:00'),
('01K2F2DKG0HSGM3A1KS79KWHWT', 15, 'tax_payable', 'credit', 124.95, 'SAR', 122.38, 'payment', 81, 'Subscription payment 84', '2026-04-24 09:00:00'),
('01K2F2DKG0HSGM3A1KS79KWHWT', 15, 'expense.processor_fees', 'debit', 77.09, 'SAR', 75.5, 'payment', 81, 'Subscription payment 84', '2026-04-23 09:00:00'),
('01K2F2DKG0HSGM3A1KS79KWHWT', 15, 'cash', 'credit', 77.09, 'SAR', 75.5, 'payment', 81, 'Subscription payment 84', '2026-04-15 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(15, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-05 09:00:00'),
(15, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-25 09:00:00'),
(15, 'listing', -1, 48, 'consumption', 'listing', NULL, 'Listing published', '2026-03-28 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(16, '01K2F2DKG0HSDE5ZJM3GH2CXJD', 16, 71, 'card', 'stripe', 'pm_01k2f2dkg00yxp4wv382df7hm0', 'visa', '5559', 3, 2028, 'Cavendish Automotive', 1, 'active', '2026-05-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(16, '01K2F2DKG0YK9SPEKSVN51RVQ8', 16, 6, 'active', 149000.0, 'USD', 547202.5, 'yearly', '2026-04-13 09:00:00', '2027-04-13 09:00:00', NULL, NULL, 1, 16, 'sub_01k2f2dkg0cx4yysqx4r40qdtq', '2024-01-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(85, '01K2F2DKG0SJVZRCSF19Y40TAW', 'LF-INV-2026000085', 16, 16, 'open', 149000.0, 0, 7450.0, 156450.0, 0, 156450.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Cavendish Automotive', 'billing@example.com', '2025-04-13 09:00:00', '2025-04-27 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000085.pdf', '2025-04-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(85, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-04-13', '2026-04-13', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(86, '01K2F2DKG0RKV1JZDBKFRMQ49R', 'LF-INV-2026000086', 16, 16, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Cavendish Automotive', 'billing@example.com', '2024-04-13 09:00:00', '2024-04-27 09:00:00', '2024-04-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000086.pdf', '2024-04-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(86, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-04-13', '2025-04-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(82, '01K2F2DKG0EGY8VCNAS6KNEASY', 'PAY-60082', 16, 86, 16, 16, 71, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03bavjbg2ba0kknre', 'idem-01K2F2DKG0KHDT7QEPBY32DJ66', 'https://cdn.livfinder.com/receipts/PAY-60082.pdf', '2024-04-22 09:00:00', '2024-04-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YB7SNFQ39A3S31SG', 16, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 82, 'Subscription payment 86', '2024-04-19 09:00:00'),
('01K2F2DKG0YB7SNFQ39A3S31SG', 16, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 82, 'Subscription payment 86', '2024-04-18 09:00:00'),
('01K2F2DKG0YB7SNFQ39A3S31SG', 16, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 82, 'Subscription payment 86', '2024-04-21 09:00:00'),
('01K2F2DKG0YB7SNFQ39A3S31SG', 16, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 82, 'Subscription payment 86', '2024-04-16 09:00:00'),
('01K2F2DKG0YB7SNFQ39A3S31SG', 16, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 82, 'Subscription payment 86', '2024-04-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(87, '01K2F2DKG0JJARV7CZ0W5QTYFT', 'LF-INV-2026000087', 16, 16, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Cavendish Automotive', 'billing@example.com', '2023-04-14 09:00:00', '2023-04-28 09:00:00', '2023-04-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000087.pdf', '2023-04-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(87, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-04-14', '2024-04-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(83, '01K2F2DKG0MTVCRNYNREZBET9H', 'PAY-60083', 16, 87, 16, 16, 71, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg092xya8kfmpkqghs9', 'idem-01K2F2DKG0GW4GR6Z22HNQH1CM', 'https://cdn.livfinder.com/receipts/PAY-60083.pdf', '2023-04-14 09:00:00', '2023-04-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0019PQCDC8FXC30X1', 16, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 83, 'Subscription payment 87', '2023-04-17 09:00:00'),
('01K2F2DKG0019PQCDC8FXC30X1', 16, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 83, 'Subscription payment 87', '2023-04-21 09:00:00'),
('01K2F2DKG0019PQCDC8FXC30X1', 16, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 83, 'Subscription payment 87', '2023-04-15 09:00:00'),
('01K2F2DKG0019PQCDC8FXC30X1', 16, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 83, 'Subscription payment 87', '2023-04-17 09:00:00'),
('01K2F2DKG0019PQCDC8FXC30X1', 16, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 83, 'Subscription payment 87', '2023-04-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(88, '01K2F2DKG0ZF323MFRR3JW9PDY', 'LF-INV-2026000088', 16, 16, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Cavendish Automotive', 'billing@example.com', '2022-04-14 09:00:00', '2022-04-28 09:00:00', '2022-04-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000088.pdf', '2022-04-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(88, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-04-14', '2023-04-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(84, '01K2F2DKG07WEYX2SZPVGMF65A', 'PAY-60084', 16, 88, 16, 16, 71, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg057qrm3q9cz8q0136', 'idem-01K2F2DKG0JR0A0AAPQA2AYFY1', 'https://cdn.livfinder.com/receipts/PAY-60084.pdf', '2022-04-25 09:00:00', '2022-04-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JV3K4CFKX7YC69D4', 16, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 84, 'Subscription payment 88', '2022-04-18 09:00:00'),
('01K2F2DKG0JV3K4CFKX7YC69D4', 16, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 84, 'Subscription payment 88', '2022-04-17 09:00:00'),
('01K2F2DKG0JV3K4CFKX7YC69D4', 16, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 84, 'Subscription payment 88', '2022-04-15 09:00:00'),
('01K2F2DKG0JV3K4CFKX7YC69D4', 16, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 84, 'Subscription payment 88', '2022-04-20 09:00:00'),
('01K2F2DKG0JV3K4CFKX7YC69D4', 16, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 84, 'Subscription payment 88', '2022-04-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(89, '01K2F2DKG0KJ16E73SZXPY0Y7S', 'LF-INV-2026000089', 16, 16, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'USD', 3.6725, 574562.62, 5.0, 'VAT', 'Cavendish Automotive', 'billing@example.com', '2021-04-14 09:00:00', '2021-04-28 09:00:00', '2021-04-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000089.pdf', '2021-04-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(89, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-04-14', '2022-04-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(85, '01K2F2DKG0JVF9K87TPN37W31F', 'PAY-60085', 16, 89, 16, 16, 71, 156450.0, 'USD', 3.6725, 574562.62, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0vn4a2a53fyw34d24', 'idem-01K2F2DKG0GMVC36V78AXQ9G3J', 'https://cdn.livfinder.com/receipts/PAY-60085.pdf', '2021-04-19 09:00:00', '2021-04-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CCKNHQ1ZVDNY0FH1', 16, 'cash', 'debit', 156450.0, 'USD', 574562.62, 'payment', 85, 'Subscription payment 89', '2021-04-21 09:00:00'),
('01K2F2DKG0CCKNHQ1ZVDNY0FH1', 16, 'revenue.subscription', 'credit', 149000.0, 'USD', 547202.5, 'payment', 85, 'Subscription payment 89', '2021-04-24 09:00:00'),
('01K2F2DKG0CCKNHQ1ZVDNY0FH1', 16, 'tax_payable', 'credit', 7450.0, 'USD', 27360.12, 'payment', 85, 'Subscription payment 89', '2021-04-22 09:00:00'),
('01K2F2DKG0CCKNHQ1ZVDNY0FH1', 16, 'expense.processor_fees', 'debit', 4538.05, 'USD', 16665.99, 'payment', 85, 'Subscription payment 89', '2021-04-16 09:00:00'),
('01K2F2DKG0CCKNHQ1ZVDNY0FH1', 16, 'cash', 'credit', 4538.05, 'USD', 16665.99, 'payment', 85, 'Subscription payment 89', '2021-04-21 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(16, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-06 09:00:00'),
(16, 'listing', 10, 9, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-12 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(17, '01K2F2DKG0706ZDTGKCVC191CH', 17, 75, 'card', 'stripe', 'pm_01k2f2dkg0hcafbptpm41hrazt', 'mastercard', '9239', 4, 2029, 'Marchmont Yachts', 1, 'active', '2025-06-14 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(17, '01K2F2DKG0V0TSQFE9J2QYBNGT', 17, 4, 'active', 2499.0, 'MXN', 488.05, 'monthly', '2026-07-25 09:00:00', '2026-08-24 09:00:00', NULL, NULL, 1, 17, 'sub_01k2f2dkg0b6bx6gead4p0h5bw', '2024-10-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(90, '01K2F2DKG0VPKB25QNMHS3CBC6', 'LF-INV-2026000090', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-06-25 09:00:00', '2026-07-09 09:00:00', '2026-07-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000090.pdf', '2026-06-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(90, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-25', '2026-07-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(86, '01K2F2DKG00F19G9YD9M6162FR', 'PAY-60086', 17, 90, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg07d9et8ztd8gme94z', 'idem-01K2F2DKG0SMX49VB3FY5QH4PX', 'https://cdn.livfinder.com/receipts/PAY-60086.pdf', '2026-07-02 09:00:00', '2026-06-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WPR5STZG1NDSSGPW', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 86, 'Subscription payment 90', '2026-07-03 09:00:00'),
('01K2F2DKG0WPR5STZG1NDSSGPW', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 86, 'Subscription payment 90', '2026-07-05 09:00:00'),
('01K2F2DKG0WPR5STZG1NDSSGPW', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 86, 'Subscription payment 90', '2026-07-07 09:00:00'),
('01K2F2DKG0WPR5STZG1NDSSGPW', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 86, 'Subscription payment 90', '2026-07-03 09:00:00'),
('01K2F2DKG0WPR5STZG1NDSSGPW', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 86, 'Subscription payment 90', '2026-07-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(91, '01K2F2DKG0Q2WAMGW4WAXB30XJ', 'LF-INV-2026000091', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-05-26 09:00:00', '2026-06-09 09:00:00', '2026-05-27 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000091.pdf', '2026-05-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(91, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-26', '2026-06-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(87, '01K2F2DKG0NQ1AE19QH6WP6F58', 'PAY-60087', 17, 91, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tt9rakc7j1q7ac0n', 'idem-01K2F2DKG0HRTJ6219MB0VQT8V', 'https://cdn.livfinder.com/receipts/PAY-60087.pdf', '2026-06-06 09:00:00', '2026-06-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG043ZZ7CA84DTM2P9W', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 87, 'Subscription payment 91', '2026-06-05 09:00:00'),
('01K2F2DKG043ZZ7CA84DTM2P9W', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 87, 'Subscription payment 91', '2026-06-05 09:00:00'),
('01K2F2DKG043ZZ7CA84DTM2P9W', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 87, 'Subscription payment 91', '2026-05-31 09:00:00'),
('01K2F2DKG043ZZ7CA84DTM2P9W', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 87, 'Subscription payment 91', '2026-05-27 09:00:00'),
('01K2F2DKG043ZZ7CA84DTM2P9W', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 87, 'Subscription payment 91', '2026-06-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(92, '01K2F2DKG0DANH7JF452J71E0P', 'LF-INV-2026000092', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-04-26 09:00:00', '2026-05-10 09:00:00', '2026-05-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000092.pdf', '2026-04-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(92, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-26', '2026-05-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(88, '01K2F2DKG0AB3VQBS4YJHHG7X2', 'PAY-60088', 17, 92, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0zs503ywjx7r9dgaa', 'idem-01K2F2DKG0G51FEFTP3RAQZQYW', 'https://cdn.livfinder.com/receipts/PAY-60088.pdf', '2026-04-26 09:00:00', '2026-04-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG05PMGKPQ95EQ2MSVS', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 88, 'Subscription payment 92', '2026-05-05 09:00:00'),
('01K2F2DKG05PMGKPQ95EQ2MSVS', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 88, 'Subscription payment 92', '2026-05-04 09:00:00'),
('01K2F2DKG05PMGKPQ95EQ2MSVS', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 88, 'Subscription payment 92', '2026-05-03 09:00:00'),
('01K2F2DKG05PMGKPQ95EQ2MSVS', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 88, 'Subscription payment 92', '2026-05-02 09:00:00'),
('01K2F2DKG05PMGKPQ95EQ2MSVS', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 88, 'Subscription payment 92', '2026-05-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(93, '01K2F2DKG0WQM2PC1ZDNVY9H4Q', 'LF-INV-2026000093', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-03-27 09:00:00', '2026-04-10 09:00:00', '2026-04-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000093.pdf', '2026-03-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(93, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-27', '2026-04-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(89, '01K2F2DKG096WVR3RW0RN8SF4P', 'PAY-60089', 17, 93, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0hpd7nmqw9adcg6zx', 'idem-01K2F2DKG0MAV73DG8KP767S6A', 'https://cdn.livfinder.com/receipts/PAY-60089.pdf', '2026-04-06 09:00:00', '2026-04-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NSTA12QPBQZSY95V', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 89, 'Subscription payment 93', '2026-04-07 09:00:00'),
('01K2F2DKG0NSTA12QPBQZSY95V', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 89, 'Subscription payment 93', '2026-04-07 09:00:00'),
('01K2F2DKG0NSTA12QPBQZSY95V', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 89, 'Subscription payment 93', '2026-03-28 09:00:00'),
('01K2F2DKG0NSTA12QPBQZSY95V', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 89, 'Subscription payment 93', '2026-04-05 09:00:00'),
('01K2F2DKG0NSTA12QPBQZSY95V', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 89, 'Subscription payment 93', '2026-04-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(94, '01K2F2DKG0TWNMBNY9FSVSKWSK', 'LF-INV-2026000094', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-02-25 09:00:00', '2026-03-11 09:00:00', '2026-03-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000094.pdf', '2026-02-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(94, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-25', '2026-03-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(90, '01K2F2DKG010P7M2750DJY90EW', 'PAY-60090', 17, 94, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0afya361nv6nc8907', 'idem-01K2F2DKG0R25JC2RKP6QSQH3Z', 'https://cdn.livfinder.com/receipts/PAY-60090.pdf', '2026-02-25 09:00:00', '2026-02-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CKDV73X5KJGCC9XW', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 90, 'Subscription payment 94', '2026-03-08 09:00:00'),
('01K2F2DKG0CKDV73X5KJGCC9XW', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 90, 'Subscription payment 94', '2026-03-07 09:00:00'),
('01K2F2DKG0CKDV73X5KJGCC9XW', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 90, 'Subscription payment 94', '2026-02-27 09:00:00'),
('01K2F2DKG0CKDV73X5KJGCC9XW', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 90, 'Subscription payment 94', '2026-02-28 09:00:00'),
('01K2F2DKG0CKDV73X5KJGCC9XW', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 90, 'Subscription payment 94', '2026-02-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(95, '01K2F2DKG0AQ53JCX9C76BWCX7', 'LF-INV-2026000095', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2026-01-26 09:00:00', '2026-02-09 09:00:00', '2026-01-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000095.pdf', '2026-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(95, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-26', '2026-02-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(91, '01K2F2DKG06QWBFJQ5HAPGEMG0', 'PAY-60091', 17, 95, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0twnbjjykjtw8czxp', 'idem-01K2F2DKG0VG4062KQKV0PNP2C', 'https://cdn.livfinder.com/receipts/PAY-60091.pdf', '2026-02-06 09:00:00', '2026-02-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG068YW2NRGXGTXDAPW', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 91, 'Subscription payment 95', '2026-02-02 09:00:00'),
('01K2F2DKG068YW2NRGXGTXDAPW', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 91, 'Subscription payment 95', '2026-01-26 09:00:00'),
('01K2F2DKG068YW2NRGXGTXDAPW', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 91, 'Subscription payment 95', '2026-02-01 09:00:00'),
('01K2F2DKG068YW2NRGXGTXDAPW', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 91, 'Subscription payment 95', '2026-02-06 09:00:00'),
('01K2F2DKG068YW2NRGXGTXDAPW', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 91, 'Subscription payment 95', '2026-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(96, '01K2F2DKG0V8F3WMNT3K61RZXF', 'LF-INV-2026000096', 17, 17, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'MXN', 0.1953, 512.46, 5.0, 'VAT', 'Marchmont Yachts', 'billing@example.com', '2025-12-27 09:00:00', '2026-01-10 09:00:00', '2026-01-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000096.pdf', '2025-12-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(96, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-27', '2026-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(92, '01K2F2DKG0N59GMNMH3X2N7YG5', 'PAY-60092', 17, 96, 17, 17, 75, 2623.95, 'MXN', 0.1953, 512.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0q0cwbm89h99fqacb', 'idem-01K2F2DKG0HN3MF7BGVH3PNZ3X', 'https://cdn.livfinder.com/receipts/PAY-60092.pdf', '2026-01-02 09:00:00', '2026-01-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06QDBFECTN07E1MF9', 17, 'cash', 'debit', 2623.95, 'MXN', 512.46, 'payment', 92, 'Subscription payment 96', '2025-12-28 09:00:00'),
('01K2F2DKG06QDBFECTN07E1MF9', 17, 'revenue.subscription', 'credit', 2499.0, 'MXN', 488.05, 'payment', 92, 'Subscription payment 96', '2026-01-05 09:00:00'),
('01K2F2DKG06QDBFECTN07E1MF9', 17, 'tax_payable', 'credit', 124.95, 'MXN', 24.4, 'payment', 92, 'Subscription payment 96', '2026-01-02 09:00:00'),
('01K2F2DKG06QDBFECTN07E1MF9', 17, 'expense.processor_fees', 'debit', 77.09, 'MXN', 15.06, 'payment', 92, 'Subscription payment 96', '2025-12-28 09:00:00'),
('01K2F2DKG06QDBFECTN07E1MF9', 17, 'cash', 'credit', 77.09, 'MXN', 15.06, 'payment', 92, 'Subscription payment 96', '2025-12-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(17, 'listing', 20, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-08-12 09:00:00'),
(17, 'listing', -1, 19, 'consumption', 'listing', NULL, 'Listing published', '2026-06-19 09:00:00'),
(17, 'listing', -2, 17, 'consumption', 'listing', NULL, 'Listing published', '2026-01-06 09:00:00'),
(17, 'listing', 50, 67, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-14 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(18, '01K2F2DKG06TR8591QVAEMFDR2', 18, 79, 'card', 'stripe', 'pm_01k2f2dkg0d7zf82zvxzh4b9c6', 'amex', '3809', 3, 2027, 'Lumina Marine', 1, 'active', '2024-08-10 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(18, '01K2F2DKG02HDRJPEW97VZG04A', 18, 4, 'cancelled', 2499.0, 'AED', 2499.0, 'monthly', '2026-08-09 09:00:00', '2026-09-08 09:00:00', NULL, '2026-07-11 09:00:00', 0, 18, 'sub_01k2f2dkg0w5zntve5dhp630x2', '2025-10-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(97, '01K2F2DKG0915DEBHWXXE14DQE', 'LF-INV-2026000097', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-07-10 09:00:00', '2026-07-24 09:00:00', '2026-07-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000097.pdf', '2026-07-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(97, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-10', '2026-08-09', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(93, '01K2F2DKG02DBW4P4CAKDPTAYQ', 'PAY-60093', 18, 97, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ds8gpegvggpzj9m7', 'idem-01K2F2DKG0RMP8DW0YGQZG4GRX', 'https://cdn.livfinder.com/receipts/PAY-60093.pdf', '2026-07-18 09:00:00', '2026-07-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XJSS704VVEW8A2CM', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 93, 'Subscription payment 97', '2026-07-11 09:00:00'),
('01K2F2DKG0XJSS704VVEW8A2CM', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 93, 'Subscription payment 97', '2026-07-16 09:00:00'),
('01K2F2DKG0XJSS704VVEW8A2CM', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 93, 'Subscription payment 97', '2026-07-21 09:00:00'),
('01K2F2DKG0XJSS704VVEW8A2CM', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 93, 'Subscription payment 97', '2026-07-15 09:00:00'),
('01K2F2DKG0XJSS704VVEW8A2CM', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 93, 'Subscription payment 97', '2026-07-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(98, '01K2F2DKG0YHS63D1598CCGNZD', 'LF-INV-2026000098', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-06-10 09:00:00', '2026-06-24 09:00:00', '2026-06-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000098.pdf', '2026-06-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(98, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-10', '2026-07-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(94, '01K2F2DKG0HVGSWSZVYHX75VB6', 'PAY-60094', 18, 98, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0z9hj7g63x8mcq54h', 'idem-01K2F2DKG065Z8AK8TXDGH9MR0', 'https://cdn.livfinder.com/receipts/PAY-60094.pdf', '2026-06-16 09:00:00', '2026-06-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YY9YJZM1ZRGFQ33T', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 94, 'Subscription payment 98', '2026-06-11 09:00:00'),
('01K2F2DKG0YY9YJZM1ZRGFQ33T', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 94, 'Subscription payment 98', '2026-06-12 09:00:00'),
('01K2F2DKG0YY9YJZM1ZRGFQ33T', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 94, 'Subscription payment 98', '2026-06-11 09:00:00'),
('01K2F2DKG0YY9YJZM1ZRGFQ33T', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 94, 'Subscription payment 98', '2026-06-11 09:00:00'),
('01K2F2DKG0YY9YJZM1ZRGFQ33T', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 94, 'Subscription payment 98', '2026-06-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(99, '01K2F2DKG0M3EVD0SPXDJT57PF', 'LF-INV-2026000099', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-05-11 09:00:00', '2026-05-25 09:00:00', '2026-05-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000099.pdf', '2026-05-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(99, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-11', '2026-06-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(95, '01K2F2DKG06F99CRBZGCHJXPH8', 'PAY-60095', 18, 99, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02pga9053ypexvegm', 'idem-01K2F2DKG023ABW90GJQH3H6M5', 'https://cdn.livfinder.com/receipts/PAY-60095.pdf', '2026-05-17 09:00:00', '2026-05-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG05W99G3SPQDFK0FCG', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 95, 'Subscription payment 99', '2026-05-12 09:00:00'),
('01K2F2DKG05W99G3SPQDFK0FCG', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 95, 'Subscription payment 99', '2026-05-17 09:00:00'),
('01K2F2DKG05W99G3SPQDFK0FCG', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 95, 'Subscription payment 99', '2026-05-23 09:00:00'),
('01K2F2DKG05W99G3SPQDFK0FCG', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 95, 'Subscription payment 99', '2026-05-22 09:00:00'),
('01K2F2DKG05W99G3SPQDFK0FCG', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 95, 'Subscription payment 99', '2026-05-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(100, '01K2F2DKG09D4TJ14CKJHKX3F5', 'LF-INV-2026000100', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-04-11 09:00:00', '2026-04-25 09:00:00', '2026-04-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000100.pdf', '2026-04-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(100, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-11', '2026-05-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(96, '01K2F2DKG0QEPF0BVPB39B378A', 'PAY-60096', 18, 100, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06gw20r8qthj2aga9', 'idem-01K2F2DKG0FBD3R51VF9MK0E23', 'https://cdn.livfinder.com/receipts/PAY-60096.pdf', '2026-04-17 09:00:00', '2026-04-18 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HFC59FTQ06EYEQDV', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 96, 'Subscription payment 100', '2026-04-18 09:00:00'),
('01K2F2DKG0HFC59FTQ06EYEQDV', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 96, 'Subscription payment 100', '2026-04-16 09:00:00'),
('01K2F2DKG0HFC59FTQ06EYEQDV', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 96, 'Subscription payment 100', '2026-04-13 09:00:00'),
('01K2F2DKG0HFC59FTQ06EYEQDV', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 96, 'Subscription payment 100', '2026-04-23 09:00:00'),
('01K2F2DKG0HFC59FTQ06EYEQDV', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 96, 'Subscription payment 100', '2026-04-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(101, '01K2F2DKG086A392DJ5D9K6REK', 'LF-INV-2026000101', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-03-12 09:00:00', '2026-03-26 09:00:00', '2026-03-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000101.pdf', '2026-03-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(101, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-12', '2026-04-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(97, '01K2F2DKG0QRK5PZEAHBJTBWCJ', 'PAY-60097', 18, 101, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0th765ckanfb065kv', 'idem-01K2F2DKG04N0H03YNMT0Q9Z2R', 'https://cdn.livfinder.com/receipts/PAY-60097.pdf', '2026-03-23 09:00:00', '2026-03-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CP9A0MDXWQPRYKBX', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 97, 'Subscription payment 101', '2026-03-13 09:00:00'),
('01K2F2DKG0CP9A0MDXWQPRYKBX', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 97, 'Subscription payment 101', '2026-03-12 09:00:00'),
('01K2F2DKG0CP9A0MDXWQPRYKBX', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 97, 'Subscription payment 101', '2026-03-23 09:00:00'),
('01K2F2DKG0CP9A0MDXWQPRYKBX', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 97, 'Subscription payment 101', '2026-03-18 09:00:00'),
('01K2F2DKG0CP9A0MDXWQPRYKBX', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 97, 'Subscription payment 101', '2026-03-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(102, '01K2F2DKG0WQZ1CA5JTS4S0PQR', 'LF-INV-2026000102', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-02-10 09:00:00', '2026-02-24 09:00:00', '2026-02-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000102.pdf', '2026-02-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(102, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-10', '2026-03-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(98, '01K2F2DKG0TEA3B7RA09M5SFT5', 'PAY-60098', 18, 102, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0hhev1n7kz0ja8vkh', 'idem-01K2F2DKG0KQB10V1B5D4HDRN9', 'https://cdn.livfinder.com/receipts/PAY-60098.pdf', '2026-02-12 09:00:00', '2026-02-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Y2R2XX4KR4DVPJ3T', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 98, 'Subscription payment 102', '2026-02-19 09:00:00'),
('01K2F2DKG0Y2R2XX4KR4DVPJ3T', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 98, 'Subscription payment 102', '2026-02-17 09:00:00'),
('01K2F2DKG0Y2R2XX4KR4DVPJ3T', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 98, 'Subscription payment 102', '2026-02-11 09:00:00'),
('01K2F2DKG0Y2R2XX4KR4DVPJ3T', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 98, 'Subscription payment 102', '2026-02-20 09:00:00'),
('01K2F2DKG0Y2R2XX4KR4DVPJ3T', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 98, 'Subscription payment 102', '2026-02-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(103, '01K2F2DKG07TNVJY3SR2C86TPC', 'LF-INV-2026000103', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2026-01-11 09:00:00', '2026-01-25 09:00:00', '2026-01-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000103.pdf', '2026-01-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(103, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-11', '2026-02-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(99, '01K2F2DKG0TMK1F84F56FJY968', 'PAY-60099', 18, 103, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0db0bayktv016apyd', 'idem-01K2F2DKG0VDNHY2VQ1GKG2RVW', 'https://cdn.livfinder.com/receipts/PAY-60099.pdf', '2026-01-21 09:00:00', '2026-01-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YGP37HH3CYA12FJ3', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 99, 'Subscription payment 103', '2026-01-11 09:00:00'),
('01K2F2DKG0YGP37HH3CYA12FJ3', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 99, 'Subscription payment 103', '2026-01-15 09:00:00'),
('01K2F2DKG0YGP37HH3CYA12FJ3', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 99, 'Subscription payment 103', '2026-01-18 09:00:00'),
('01K2F2DKG0YGP37HH3CYA12FJ3', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 99, 'Subscription payment 103', '2026-01-13 09:00:00'),
('01K2F2DKG0YGP37HH3CYA12FJ3', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 99, 'Subscription payment 103', '2026-01-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(104, '01K2F2DKG0127AV0RJX3SGEKNZ', 'LF-INV-2026000104', 18, 18, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Lumina Marine', 'billing@example.com', '2025-12-12 09:00:00', '2025-12-26 09:00:00', '2025-12-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000104.pdf', '2025-12-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(104, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-12', '2026-01-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(100, '01K2F2DKG076DZBT545HPQWN3S', 'PAY-60100', 18, 104, 18, 18, 79, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg097h44cm7e68ftv8a', 'idem-01K2F2DKG0HEBVPBFW9BTN3TC3', 'https://cdn.livfinder.com/receipts/PAY-60100.pdf', '2025-12-12 09:00:00', '2025-12-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZQR6PRX0KGSQ0YGA', 18, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 100, 'Subscription payment 104', '2025-12-19 09:00:00'),
('01K2F2DKG0ZQR6PRX0KGSQ0YGA', 18, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 100, 'Subscription payment 104', '2025-12-13 09:00:00'),
('01K2F2DKG0ZQR6PRX0KGSQ0YGA', 18, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 100, 'Subscription payment 104', '2025-12-14 09:00:00'),
('01K2F2DKG0ZQR6PRX0KGSQ0YGA', 18, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 100, 'Subscription payment 104', '2025-12-16 09:00:00'),
('01K2F2DKG0ZQR6PRX0KGSQ0YGA', 18, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 100, 'Subscription payment 104', '2025-12-21 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(18, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-07-31 09:00:00'),
(18, 'listing', 10, 9, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-28 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(19, '01K2F2DKG06VD1EWWFMGF9NVG5', 19, 83, 'card', 'stripe', 'pm_01k2f2dkg0mgngmc4nd3pk7xf2', 'visa', '9816', 12, 2028, 'Veritas Aviation', 1, 'active', '2025-07-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(19, '01K2F2DKG0NR5J75JYKMYP71F3', 19, 6, 'trialing', 149000.0, 'EUR', 593630.9, 'yearly', '2026-07-31 09:00:00', '2027-07-31 09:00:00', '2026-08-14 09:00:00', NULL, 1, 19, 'sub_01k2f2dkg0yfnaw1r5k19615x9', '2025-02-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(105, '01K2F2DKG07T8VDEN0CRGG4JN4', 'LF-INV-2026000105', 19, 19, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Veritas Aviation', 'billing@example.com', '2025-07-31 09:00:00', '2025-08-14 09:00:00', '2025-08-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000105.pdf', '2025-07-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(105, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-07-31', '2026-07-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(101, '01K2F2DKG0HR6MNKJRP2HCHE1Y', 'PAY-60101', 19, 105, 19, 19, 83, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gymmkt5a0k33q5qf', 'idem-01K2F2DKG0DYGNHZ8A4ZB846QJ', 'https://cdn.livfinder.com/receipts/PAY-60101.pdf', '2025-08-08 09:00:00', '2025-08-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04QG6BVF2A2BERV6H', 19, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 101, 'Subscription payment 105', '2025-08-03 09:00:00'),
('01K2F2DKG04QG6BVF2A2BERV6H', 19, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 101, 'Subscription payment 105', '2025-08-08 09:00:00'),
('01K2F2DKG04QG6BVF2A2BERV6H', 19, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 101, 'Subscription payment 105', '2025-08-07 09:00:00'),
('01K2F2DKG04QG6BVF2A2BERV6H', 19, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 101, 'Subscription payment 105', '2025-08-06 09:00:00'),
('01K2F2DKG04QG6BVF2A2BERV6H', 19, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 101, 'Subscription payment 105', '2025-08-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(106, '01K2F2DKG0P3VY7QYPGDFCKK9N', 'LF-INV-2026000106', 19, 19, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Veritas Aviation', 'billing@example.com', '2024-07-31 09:00:00', '2024-08-14 09:00:00', '2024-07-31 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000106.pdf', '2024-07-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(106, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-07-31', '2025-07-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(102, '01K2F2DKG08CMH9WFPPDKBJ0GE', 'PAY-60102', 19, 106, 19, 19, 83, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06ytt0qbd4yj1nw8k', 'idem-01K2F2DKG0T7DZFSKRF9NJZPCD', 'https://cdn.livfinder.com/receipts/PAY-60102.pdf', '2024-08-05 09:00:00', '2024-08-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0P2YE0QNBATCYMXFZ', 19, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 102, 'Subscription payment 106', '2024-07-31 09:00:00'),
('01K2F2DKG0P2YE0QNBATCYMXFZ', 19, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 102, 'Subscription payment 106', '2024-08-06 09:00:00'),
('01K2F2DKG0P2YE0QNBATCYMXFZ', 19, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 102, 'Subscription payment 106', '2024-08-05 09:00:00'),
('01K2F2DKG0P2YE0QNBATCYMXFZ', 19, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 102, 'Subscription payment 106', '2024-08-05 09:00:00'),
('01K2F2DKG0P2YE0QNBATCYMXFZ', 19, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 102, 'Subscription payment 106', '2024-08-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(107, '01K2F2DKG0HQ0Q93MBMYW7VZRQ', 'LF-INV-2026000107', 19, 19, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Veritas Aviation', 'billing@example.com', '2023-08-01 09:00:00', '2023-08-15 09:00:00', '2023-08-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000107.pdf', '2023-08-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(107, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-08-01', '2024-07-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(103, '01K2F2DKG0T80FHM5QGFTV6WZA', 'PAY-60103', 19, 107, 19, 19, 83, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bs7kzbc571hy32km', 'idem-01K2F2DKG0ADKDVMB88WRYKSR1', 'https://cdn.livfinder.com/receipts/PAY-60103.pdf', '2023-08-12 09:00:00', '2023-08-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RF90YTGAADX7ZBRS', 19, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 103, 'Subscription payment 107', '2023-08-11 09:00:00'),
('01K2F2DKG0RF90YTGAADX7ZBRS', 19, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 103, 'Subscription payment 107', '2023-08-13 09:00:00'),
('01K2F2DKG0RF90YTGAADX7ZBRS', 19, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 103, 'Subscription payment 107', '2023-08-01 09:00:00'),
('01K2F2DKG0RF90YTGAADX7ZBRS', 19, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 103, 'Subscription payment 107', '2023-08-06 09:00:00'),
('01K2F2DKG0RF90YTGAADX7ZBRS', 19, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 103, 'Subscription payment 107', '2023-08-02 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(19, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-03 09:00:00'),
(19, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-10-31 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(20, '01K2F2DKG0Q26149Y1G57ETCVP', 20, 87, 'card', 'stripe', 'pm_01k2f2dkg02cbvcsves7pksrzx', 'amex', '5502', 3, 2027, 'Onyx Timepieces', 1, 'active', '2024-03-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(20, '01K2F2DKG0P1YCVRTYFA5GYSDH', 20, 4, 'active', 2499.0, 'EUR', 9956.27, 'monthly', '2026-07-30 09:00:00', '2026-08-29 09:00:00', NULL, NULL, 1, 20, 'sub_01k2f2dkg02r6s5kfxpds5jhrr', '2026-01-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(108, '01K2F2DKG0E039W79QYVPB20K8', 'LF-INV-2026000108', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-06-30 09:00:00', '2026-07-14 09:00:00', '2026-07-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000108.pdf', '2026-06-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(108, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-30', '2026-07-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(104, '01K2F2DKG02K5BRQX7TMCJ728Z', 'PAY-60104', 20, 108, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg08nxw3k217srj37sj', 'idem-01K2F2DKG0KNVQMQKV54ZJGDTX', 'https://cdn.livfinder.com/receipts/PAY-60104.pdf', '2026-07-12 09:00:00', '2026-07-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0FV4EZQGKV7RSS3WR', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 104, 'Subscription payment 108', '2026-07-05 09:00:00'),
('01K2F2DKG0FV4EZQGKV7RSS3WR', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 104, 'Subscription payment 108', '2026-07-05 09:00:00'),
('01K2F2DKG0FV4EZQGKV7RSS3WR', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 104, 'Subscription payment 108', '2026-07-02 09:00:00'),
('01K2F2DKG0FV4EZQGKV7RSS3WR', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 104, 'Subscription payment 108', '2026-07-02 09:00:00'),
('01K2F2DKG0FV4EZQGKV7RSS3WR', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 104, 'Subscription payment 108', '2026-07-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(109, '01K2F2DKG037XK8Y86ANNWX6Q3', 'LF-INV-2026000109', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-05-31 09:00:00', '2026-06-14 09:00:00', '2026-06-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000109.pdf', '2026-05-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(109, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-31', '2026-06-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(105, '01K2F2DKG0D0DA92XRDBQT3Q8K', 'PAY-60105', 20, 109, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0j3tdztyj3geh84mc', 'idem-01K2F2DKG0V1WRSMSZWEC8YM37', 'https://cdn.livfinder.com/receipts/PAY-60105.pdf', '2026-06-11 09:00:00', '2026-06-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0QTMA1TKRJR8HNN7F', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 105, 'Subscription payment 109', '2026-06-08 09:00:00'),
('01K2F2DKG0QTMA1TKRJR8HNN7F', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 105, 'Subscription payment 109', '2026-06-05 09:00:00'),
('01K2F2DKG0QTMA1TKRJR8HNN7F', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 105, 'Subscription payment 109', '2026-06-03 09:00:00'),
('01K2F2DKG0QTMA1TKRJR8HNN7F', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 105, 'Subscription payment 109', '2026-06-03 09:00:00'),
('01K2F2DKG0QTMA1TKRJR8HNN7F', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 105, 'Subscription payment 109', '2026-06-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(110, '01K2F2DKG0W58PM9E1Q40CE4Z1', 'LF-INV-2026000110', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-05-01 09:00:00', '2026-05-15 09:00:00', '2026-05-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000110.pdf', '2026-05-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(110, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-01', '2026-05-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(106, '01K2F2DKG0RN9V044HJ6W3YDWB', 'PAY-60106', 20, 110, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0a4rv2qar6pes2rbz', 'idem-01K2F2DKG09MKQG9HZSYR0DRRM', 'https://cdn.livfinder.com/receipts/PAY-60106.pdf', '2026-05-02 09:00:00', '2026-05-11 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0AT06RDSC8CGPZE03', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 106, 'Subscription payment 110', '2026-05-02 09:00:00'),
('01K2F2DKG0AT06RDSC8CGPZE03', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 106, 'Subscription payment 110', '2026-05-02 09:00:00'),
('01K2F2DKG0AT06RDSC8CGPZE03', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 106, 'Subscription payment 110', '2026-05-01 09:00:00'),
('01K2F2DKG0AT06RDSC8CGPZE03', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 106, 'Subscription payment 110', '2026-05-08 09:00:00'),
('01K2F2DKG0AT06RDSC8CGPZE03', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 106, 'Subscription payment 110', '2026-05-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(111, '01K2F2DKG011DQYM8RZ6G7PCGJ', 'LF-INV-2026000111', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-04-01 09:00:00', '2026-04-15 09:00:00', '2026-04-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000111.pdf', '2026-04-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(111, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-01', '2026-05-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(107, '01K2F2DKG09WJYCBHJFETYR4JK', 'PAY-60107', 20, 111, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kt9ggr3q9rnjtfp9', 'idem-01K2F2DKG0ZAX08Q3MB38C93SW', 'https://cdn.livfinder.com/receipts/PAY-60107.pdf', '2026-04-01 09:00:00', '2026-04-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04MHSHPHN8XTPD4RC', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 107, 'Subscription payment 111', '2026-04-13 09:00:00'),
('01K2F2DKG04MHSHPHN8XTPD4RC', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 107, 'Subscription payment 111', '2026-04-04 09:00:00'),
('01K2F2DKG04MHSHPHN8XTPD4RC', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 107, 'Subscription payment 111', '2026-04-02 09:00:00'),
('01K2F2DKG04MHSHPHN8XTPD4RC', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 107, 'Subscription payment 111', '2026-04-10 09:00:00'),
('01K2F2DKG04MHSHPHN8XTPD4RC', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 107, 'Subscription payment 111', '2026-04-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(112, '01K2F2DKG0NZEBGDA4K5D9NDAE', 'LF-INV-2026000112', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-03-02 09:00:00', '2026-03-16 09:00:00', '2026-03-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000112.pdf', '2026-03-02 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(112, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-02', '2026-04-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(108, '01K2F2DKG0B3JBZA23DMJ3YW18', 'PAY-60108', 20, 112, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0k6eheqwn5a2a1xy7', 'idem-01K2F2DKG0PK4K9QVC5HAEF33Z', 'https://cdn.livfinder.com/receipts/PAY-60108.pdf', '2026-03-10 09:00:00', '2026-03-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0EWKZ47ZF3675ZH5M', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 108, 'Subscription payment 112', '2026-03-03 09:00:00'),
('01K2F2DKG0EWKZ47ZF3675ZH5M', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 108, 'Subscription payment 112', '2026-03-06 09:00:00'),
('01K2F2DKG0EWKZ47ZF3675ZH5M', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 108, 'Subscription payment 112', '2026-03-05 09:00:00'),
('01K2F2DKG0EWKZ47ZF3675ZH5M', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 108, 'Subscription payment 112', '2026-03-08 09:00:00'),
('01K2F2DKG0EWKZ47ZF3675ZH5M', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 108, 'Subscription payment 112', '2026-03-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(113, '01K2F2DKG0NP99PY5GTDQR8WTN', 'LF-INV-2026000113', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-01-31 09:00:00', '2026-02-14 09:00:00', '2026-02-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000113.pdf', '2026-01-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(113, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-31', '2026-03-02', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(109, '01K2F2DKG0HJ59P2TGE9F8894J', 'PAY-60109', 20, 113, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0jsbe43yjpxyv7jh1', 'idem-01K2F2DKG0J837QPR36SRYY8V7', 'https://cdn.livfinder.com/receipts/PAY-60109.pdf', '2026-01-31 09:00:00', '2026-01-31 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YHMTXQ8WNE9B5DAD', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 109, 'Subscription payment 113', '2026-02-06 09:00:00'),
('01K2F2DKG0YHMTXQ8WNE9B5DAD', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 109, 'Subscription payment 113', '2026-02-11 09:00:00'),
('01K2F2DKG0YHMTXQ8WNE9B5DAD', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 109, 'Subscription payment 113', '2026-01-31 09:00:00'),
('01K2F2DKG0YHMTXQ8WNE9B5DAD', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 109, 'Subscription payment 113', '2026-02-07 09:00:00'),
('01K2F2DKG0YHMTXQ8WNE9B5DAD', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 109, 'Subscription payment 113', '2026-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(114, '01K2F2DKG03P8Q10WBB40E1VMR', 'LF-INV-2026000114', 20, 20, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Onyx Timepieces', 'billing@example.com', '2026-01-01 09:00:00', '2026-01-15 09:00:00', '2026-01-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000114.pdf', '2026-01-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(114, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-01', '2026-01-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(110, '01K2F2DKG0J2AJM31XVAYQSH5Y', 'PAY-60110', 20, 114, 20, 20, 87, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pssx49eywxp8hfye', 'idem-01K2F2DKG0CNW153N2MEAF5YJN', 'https://cdn.livfinder.com/receipts/PAY-60110.pdf', '2026-01-04 09:00:00', '2026-01-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TSFQ6TBQRGXQAGQA', 20, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 110, 'Subscription payment 114', '2026-01-01 09:00:00'),
('01K2F2DKG0TSFQ6TBQRGXQAGQA', 20, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 110, 'Subscription payment 114', '2026-01-03 09:00:00'),
('01K2F2DKG0TSFQ6TBQRGXQAGQA', 20, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 110, 'Subscription payment 114', '2026-01-07 09:00:00'),
('01K2F2DKG0TSFQ6TBQRGXQAGQA', 20, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 110, 'Subscription payment 114', '2026-01-08 09:00:00'),
('01K2F2DKG0TSFQ6TBQRGXQAGQA', 20, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 110, 'Subscription payment 114', '2026-01-02 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(20, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-24 09:00:00'),
(20, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-04-04 09:00:00'),
(20, 'listing', 10, 7, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-18 09:00:00'),
(20, 'listing', -2, 5, 'consumption', 'listing', NULL, 'Listing published', '2026-04-10 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(21, '01K2F2DKG0W4QAQRS3WTSVPC9X', 21, 91, 'card', 'stripe', 'pm_01k2f2dkg0yphc37vddx9kv37x', 'visa', '7131', 6, 2031, 'Kingsley Development', 1, 'active', '2024-02-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(21, '01K2F2DKG0F3W1BE361P9DGAYP', 21, 7, 'active', 89000.0, 'EUR', 354584.9, 'yearly', '2026-03-15 09:00:00', '2027-03-15 09:00:00', NULL, NULL, 1, 21, 'sub_01k2f2dkg0y898f2tb5mhpa0sz', '2025-09-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(115, '01K2F2DKG0DFJTX4NZC6ZSB289', 'LF-INV-2026000115', 21, 21, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Kingsley Development', 'billing@example.com', '2025-03-15 09:00:00', '2025-03-29 09:00:00', '2025-03-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000115.pdf', '2025-03-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(115, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2025-03-15', '2026-03-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(111, '01K2F2DKG02QBHAY0CHEHMMAK8', 'PAY-60111', 21, 115, 21, 21, 91, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg07dsn303s90sv96wz', 'idem-01K2F2DKG04VFEV034XRKDV9FA', 'https://cdn.livfinder.com/receipts/PAY-60111.pdf', '2025-03-26 09:00:00', '2025-03-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04P4BFAZMYVK0GK8K', 21, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 111, 'Subscription payment 115', '2025-03-18 09:00:00'),
('01K2F2DKG04P4BFAZMYVK0GK8K', 21, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 111, 'Subscription payment 115', '2025-03-27 09:00:00'),
('01K2F2DKG04P4BFAZMYVK0GK8K', 21, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 111, 'Subscription payment 115', '2025-03-25 09:00:00'),
('01K2F2DKG04P4BFAZMYVK0GK8K', 21, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 111, 'Subscription payment 115', '2025-03-21 09:00:00'),
('01K2F2DKG04P4BFAZMYVK0GK8K', 21, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 111, 'Subscription payment 115', '2025-03-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(116, '01K2F2DKG0AXY6CHJJTMN0QVT7', 'LF-INV-2026000116', 21, 21, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Kingsley Development', 'billing@example.com', '2024-03-15 09:00:00', '2024-03-29 09:00:00', '2024-03-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000116.pdf', '2024-03-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(116, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2024-03-15', '2025-03-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(112, '01K2F2DKG0NS9YZ0AT01M36V9G', 'PAY-60112', 21, 116, 21, 21, 91, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0s3fwe7980mrz230k', 'idem-01K2F2DKG0XW9NGXFH0XNY6KBS', 'https://cdn.livfinder.com/receipts/PAY-60112.pdf', '2024-03-22 09:00:00', '2024-03-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TPA3P004F9ATHYDB', 21, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 112, 'Subscription payment 116', '2024-03-20 09:00:00'),
('01K2F2DKG0TPA3P004F9ATHYDB', 21, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 112, 'Subscription payment 116', '2024-03-20 09:00:00'),
('01K2F2DKG0TPA3P004F9ATHYDB', 21, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 112, 'Subscription payment 116', '2024-03-16 09:00:00'),
('01K2F2DKG0TPA3P004F9ATHYDB', 21, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 112, 'Subscription payment 116', '2024-03-27 09:00:00'),
('01K2F2DKG0TPA3P004F9ATHYDB', 21, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 112, 'Subscription payment 116', '2024-03-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(117, '01K2F2DKG0FR6C50TD6EXDBV44', 'LF-INV-2026000117', 21, 21, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Kingsley Development', 'billing@example.com', '2023-03-16 09:00:00', '2023-03-30 09:00:00', '2023-03-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000117.pdf', '2023-03-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(117, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2023-03-16', '2024-03-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(113, '01K2F2DKG0XY7WEND8TXA5DFAH', 'PAY-60113', 21, 117, 21, 21, 91, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bs6ctxwy336fjw0h', 'idem-01K2F2DKG0KWQDA1YBKGA2QZJD', 'https://cdn.livfinder.com/receipts/PAY-60113.pdf', '2023-03-19 09:00:00', '2023-03-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG02B7PXH5NKA88T32V', 21, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 113, 'Subscription payment 117', '2023-03-26 09:00:00'),
('01K2F2DKG02B7PXH5NKA88T32V', 21, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 113, 'Subscription payment 117', '2023-03-19 09:00:00'),
('01K2F2DKG02B7PXH5NKA88T32V', 21, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 113, 'Subscription payment 117', '2023-03-20 09:00:00'),
('01K2F2DKG02B7PXH5NKA88T32V', 21, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 113, 'Subscription payment 117', '2023-03-26 09:00:00'),
('01K2F2DKG02B7PXH5NKA88T32V', 21, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 113, 'Subscription payment 117', '2023-03-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(118, '01K2F2DKG028CM8JG4QWC8J6JX', 'LF-INV-2026000118', 21, 21, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Kingsley Development', 'billing@example.com', '2022-03-16 09:00:00', '2022-03-30 09:00:00', '2022-03-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000118.pdf', '2022-03-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(118, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2022-03-16', '2023-03-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(114, '01K2F2DKG07K6PYD8D715WE1PX', 'PAY-60114', 21, 118, 21, 21, 91, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0y1rxb9jt8jnzgyyc', 'idem-01K2F2DKG0PPQHSZ7FM50FJR70', 'https://cdn.livfinder.com/receipts/PAY-60114.pdf', '2022-03-23 09:00:00', '2022-03-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JR3PMA5D68EQKYCH', 21, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 114, 'Subscription payment 118', '2022-03-26 09:00:00'),
('01K2F2DKG0JR3PMA5D68EQKYCH', 21, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 114, 'Subscription payment 118', '2022-03-21 09:00:00'),
('01K2F2DKG0JR3PMA5D68EQKYCH', 21, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 114, 'Subscription payment 118', '2022-03-18 09:00:00'),
('01K2F2DKG0JR3PMA5D68EQKYCH', 21, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 114, 'Subscription payment 118', '2022-03-21 09:00:00'),
('01K2F2DKG0JR3PMA5D68EQKYCH', 21, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 114, 'Subscription payment 118', '2022-03-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(119, '01K2F2DKG04W8JVW2KP037XDDJ', 'LF-INV-2026000119', 21, 21, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Kingsley Development', 'billing@example.com', '2021-03-16 09:00:00', '2021-03-30 09:00:00', '2021-03-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000119.pdf', '2021-03-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(119, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2021-03-16', '2022-03-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(115, '01K2F2DKG0TY078JV2CVKCM093', 'PAY-60115', 21, 119, 21, 21, 91, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0j9qbht7d5m2fhxcz', 'idem-01K2F2DKG0JBWHD6GF5HN1DBCZ', 'https://cdn.livfinder.com/receipts/PAY-60115.pdf', '2021-03-23 09:00:00', '2021-03-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RASGFSR9NMYTYS91', 21, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 115, 'Subscription payment 119', '2021-03-26 09:00:00'),
('01K2F2DKG0RASGFSR9NMYTYS91', 21, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 115, 'Subscription payment 119', '2021-03-18 09:00:00'),
('01K2F2DKG0RASGFSR9NMYTYS91', 21, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 115, 'Subscription payment 119', '2021-03-26 09:00:00'),
('01K2F2DKG0RASGFSR9NMYTYS91', 21, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 115, 'Subscription payment 119', '2021-03-21 09:00:00'),
('01K2F2DKG0RASGFSR9NMYTYS91', 21, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 115, 'Subscription payment 119', '2021-03-17 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(21, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-11-27 09:00:00'),
(21, 'listing', 20, 18, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-30 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(22, '01K2F2DKG0A1Y09AM57HZ7NXFP', 22, 95, 'card', 'stripe', 'pm_01k2f2dkg0n3fkf6pyzb2da67p', 'mastercard', '8481', 10, 2027, 'Ridgeline Partners', 1, 'active', '2024-10-27 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(22, '01K2F2DKG0E64KX8RKG4DJSK0N', 22, 6, 'active', 149000.0, 'GBP', 696262.1, 'yearly', '2026-07-29 09:00:00', '2027-07-29 09:00:00', NULL, NULL, 1, 22, 'sub_01k2f2dkg0syy1nerg04eb1dv8', '2025-11-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(120, '01K2F2DKG06KNZXPG73W4QAW40', 'LF-INV-2026000120', 22, 22, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'GBP', 4.6729, 731075.21, 5.0, 'VAT', 'Ridgeline Partners', 'billing@example.com', '2025-07-29 09:00:00', '2025-08-12 09:00:00', '2025-07-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000120.pdf', '2025-07-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(120, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-07-29', '2026-07-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(116, '01K2F2DKG0P2RCC8WW3HW6931H', 'PAY-60116', 22, 120, 22, 22, 95, 156450.0, 'GBP', 4.6729, 731075.21, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09pdcvfj8jgwd1n2h', 'idem-01K2F2DKG00X7F13935RAX63ZE', 'https://cdn.livfinder.com/receipts/PAY-60116.pdf', '2025-08-06 09:00:00', '2025-08-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG065ACVFP4ETKYVN3J', 22, 'cash', 'debit', 156450.0, 'GBP', 731075.21, 'payment', 116, 'Subscription payment 120', '2025-08-09 09:00:00'),
('01K2F2DKG065ACVFP4ETKYVN3J', 22, 'revenue.subscription', 'credit', 149000.0, 'GBP', 696262.1, 'payment', 116, 'Subscription payment 120', '2025-08-08 09:00:00'),
('01K2F2DKG065ACVFP4ETKYVN3J', 22, 'tax_payable', 'credit', 7450.0, 'GBP', 34813.11, 'payment', 116, 'Subscription payment 120', '2025-07-31 09:00:00'),
('01K2F2DKG065ACVFP4ETKYVN3J', 22, 'expense.processor_fees', 'debit', 4538.05, 'GBP', 21205.85, 'payment', 116, 'Subscription payment 120', '2025-07-29 09:00:00'),
('01K2F2DKG065ACVFP4ETKYVN3J', 22, 'cash', 'credit', 4538.05, 'GBP', 21205.85, 'payment', 116, 'Subscription payment 120', '2025-08-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(121, '01K2F2DKG036J7H9C0GP7GHZ1A', 'LF-INV-2026000121', 22, 22, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'GBP', 4.6729, 731075.21, 5.0, 'VAT', 'Ridgeline Partners', 'billing@example.com', '2024-07-29 09:00:00', '2024-08-12 09:00:00', '2024-07-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000121.pdf', '2024-07-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(121, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-07-29', '2025-07-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(117, '01K2F2DKG0VSCKQRCBNJ8VGSFV', 'PAY-60117', 22, 121, 22, 22, 95, 156450.0, 'GBP', 4.6729, 731075.21, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0z2znpbjqcp1cyqyb', 'idem-01K2F2DKG0PR68VNFC397EHY0R', 'https://cdn.livfinder.com/receipts/PAY-60117.pdf', '2024-07-30 09:00:00', '2024-08-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08C90W1S79AD03M9G', 22, 'cash', 'debit', 156450.0, 'GBP', 731075.21, 'payment', 117, 'Subscription payment 121', '2024-08-03 09:00:00'),
('01K2F2DKG08C90W1S79AD03M9G', 22, 'revenue.subscription', 'credit', 149000.0, 'GBP', 696262.1, 'payment', 117, 'Subscription payment 121', '2024-08-05 09:00:00'),
('01K2F2DKG08C90W1S79AD03M9G', 22, 'tax_payable', 'credit', 7450.0, 'GBP', 34813.11, 'payment', 117, 'Subscription payment 121', '2024-08-04 09:00:00'),
('01K2F2DKG08C90W1S79AD03M9G', 22, 'expense.processor_fees', 'debit', 4538.05, 'GBP', 21205.85, 'payment', 117, 'Subscription payment 121', '2024-08-05 09:00:00'),
('01K2F2DKG08C90W1S79AD03M9G', 22, 'cash', 'credit', 4538.05, 'GBP', 21205.85, 'payment', 117, 'Subscription payment 121', '2024-08-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(122, '01K2F2DKG02Z640X7TV35JHSK2', 'LF-INV-2026000122', 22, 22, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'GBP', 4.6729, 731075.21, 5.0, 'VAT', 'Ridgeline Partners', 'billing@example.com', '2023-07-30 09:00:00', '2023-08-13 09:00:00', '2023-08-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000122.pdf', '2023-07-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(122, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-07-30', '2024-07-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(118, '01K2F2DKG0T8ZZDMQ4Q72NAD36', 'PAY-60118', 22, 122, 22, 22, 95, 156450.0, 'GBP', 4.6729, 731075.21, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03by1rv5363edh9wx', 'idem-01K2F2DKG0YX1VKVE7H1HSVEWY', 'https://cdn.livfinder.com/receipts/PAY-60118.pdf', '2023-08-11 09:00:00', '2023-08-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG085W8QB51ABE962EN', 22, 'cash', 'debit', 156450.0, 'GBP', 731075.21, 'payment', 118, 'Subscription payment 122', '2023-08-11 09:00:00'),
('01K2F2DKG085W8QB51ABE962EN', 22, 'revenue.subscription', 'credit', 149000.0, 'GBP', 696262.1, 'payment', 118, 'Subscription payment 122', '2023-08-01 09:00:00'),
('01K2F2DKG085W8QB51ABE962EN', 22, 'tax_payable', 'credit', 7450.0, 'GBP', 34813.11, 'payment', 118, 'Subscription payment 122', '2023-07-31 09:00:00'),
('01K2F2DKG085W8QB51ABE962EN', 22, 'expense.processor_fees', 'debit', 4538.05, 'GBP', 21205.85, 'payment', 118, 'Subscription payment 122', '2023-08-09 09:00:00'),
('01K2F2DKG085W8QB51ABE962EN', 22, 'cash', 'credit', 4538.05, 'GBP', 21205.85, 'payment', 118, 'Subscription payment 122', '2023-08-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(123, '01K2F2DKG0GB6N5SJ2HF5HQ7QF', 'LF-INV-2026000123', 22, 22, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'GBP', 4.6729, 731075.21, 5.0, 'VAT', 'Ridgeline Partners', 'billing@example.com', '2022-07-30 09:00:00', '2022-08-13 09:00:00', '2022-07-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000123.pdf', '2022-07-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(123, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-07-30', '2023-07-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(119, '01K2F2DKG0ZF5HPCAMP25T95D7', 'PAY-60119', 22, 123, 22, 22, 95, 156450.0, 'GBP', 4.6729, 731075.21, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0r97krrmcz0tgj19x', 'idem-01K2F2DKG0HCC7YB07Y55MZQMD', 'https://cdn.livfinder.com/receipts/PAY-60119.pdf', '2022-08-02 09:00:00', '2022-08-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WHCTERPHDAP5T0NE', 22, 'cash', 'debit', 156450.0, 'GBP', 731075.21, 'payment', 119, 'Subscription payment 123', '2022-07-30 09:00:00'),
('01K2F2DKG0WHCTERPHDAP5T0NE', 22, 'revenue.subscription', 'credit', 149000.0, 'GBP', 696262.1, 'payment', 119, 'Subscription payment 123', '2022-08-01 09:00:00'),
('01K2F2DKG0WHCTERPHDAP5T0NE', 22, 'tax_payable', 'credit', 7450.0, 'GBP', 34813.11, 'payment', 119, 'Subscription payment 123', '2022-07-30 09:00:00'),
('01K2F2DKG0WHCTERPHDAP5T0NE', 22, 'expense.processor_fees', 'debit', 4538.05, 'GBP', 21205.85, 'payment', 119, 'Subscription payment 123', '2022-08-07 09:00:00'),
('01K2F2DKG0WHCTERPHDAP5T0NE', 22, 'cash', 'credit', 4538.05, 'GBP', 21205.85, 'payment', 119, 'Subscription payment 123', '2022-07-31 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(22, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-03 09:00:00'),
(22, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-15 09:00:00'),
(22, 'listing', -2, 47, 'consumption', 'listing', NULL, 'Listing published', '2026-03-08 09:00:00'),
(22, 'listing', 10, 57, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-05 09:00:00'),
(22, 'listing', 10, 67, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-21 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(23, '01K2F2DKG01J8ETFPVCZQ611SA', 23, 99, 'card', 'stripe', 'pm_01k2f2dkg08xk1y6q1wt2w46sx', 'visa', '7202', 5, 2029, 'Vantage Properties', 1, 'active', '2025-07-13 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(23, '01K2F2DKG0KWSS7BYAWH9CN3GW', 23, 4, 'past_due', 2499.0, 'USD', 9177.58, 'monthly', '2026-07-29 09:00:00', '2026-08-28 09:00:00', NULL, NULL, 1, 23, 'sub_01k2f2dkg0jg8pfhgx0banfjxb', '2025-08-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(124, '01K2F2DKG0109EV53JS8A83PKY', 'LF-INV-2026000124', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-06-29 09:00:00', '2026-07-13 09:00:00', '2026-07-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000124.pdf', '2026-06-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(124, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-29', '2026-07-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(120, '01K2F2DKG0WSP5DKFV7WFD4W31', 'PAY-60120', 23, 124, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dyrvjgw7v0dbvsfj', 'idem-01K2F2DKG0J2BGESB6YAZZJVV8', 'https://cdn.livfinder.com/receipts/PAY-60120.pdf', '2026-07-01 09:00:00', '2026-07-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WF95MNCSC21GZAFH', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 120, 'Subscription payment 124', '2026-07-08 09:00:00'),
('01K2F2DKG0WF95MNCSC21GZAFH', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 120, 'Subscription payment 124', '2026-07-07 09:00:00'),
('01K2F2DKG0WF95MNCSC21GZAFH', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 120, 'Subscription payment 124', '2026-07-11 09:00:00'),
('01K2F2DKG0WF95MNCSC21GZAFH', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 120, 'Subscription payment 124', '2026-06-29 09:00:00'),
('01K2F2DKG0WF95MNCSC21GZAFH', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 120, 'Subscription payment 124', '2026-07-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(125, '01K2F2DKG0E4V6S237W2768JCB', 'LF-INV-2026000125', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-05-30 09:00:00', '2026-06-13 09:00:00', '2026-06-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000125.pdf', '2026-05-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(125, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-30', '2026-06-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(121, '01K2F2DKG07GQR0X4JHNTR2TCZ', 'PAY-60121', 23, 125, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg08zk6pww8d6dxq4gv', 'idem-01K2F2DKG0940EKGNAFYFCTG0Z', 'https://cdn.livfinder.com/receipts/PAY-60121.pdf', '2026-06-07 09:00:00', '2026-06-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HNY3SW6B6H36C3DQ', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 121, 'Subscription payment 125', '2026-06-05 09:00:00'),
('01K2F2DKG0HNY3SW6B6H36C3DQ', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 121, 'Subscription payment 125', '2026-06-06 09:00:00'),
('01K2F2DKG0HNY3SW6B6H36C3DQ', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 121, 'Subscription payment 125', '2026-06-06 09:00:00'),
('01K2F2DKG0HNY3SW6B6H36C3DQ', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 121, 'Subscription payment 125', '2026-06-02 09:00:00'),
('01K2F2DKG0HNY3SW6B6H36C3DQ', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 121, 'Subscription payment 125', '2026-06-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(126, '01K2F2DKG0YYXKBED6TY9NTK4A', 'LF-INV-2026000126', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-04-30 09:00:00', '2026-05-14 09:00:00', '2026-05-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000126.pdf', '2026-04-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(126, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-30', '2026-05-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(122, '01K2F2DKG02Q0EKW2P83GT3YR9', 'PAY-60122', 23, 126, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg01pycx0x4wyksjawe', 'idem-01K2F2DKG0SVTPBWH42KA8KBST', 'https://cdn.livfinder.com/receipts/PAY-60122.pdf', '2026-04-30 09:00:00', '2026-05-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0F23FPM7GPQ8TC1QT', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 122, 'Subscription payment 126', '2026-05-08 09:00:00'),
('01K2F2DKG0F23FPM7GPQ8TC1QT', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 122, 'Subscription payment 126', '2026-05-11 09:00:00'),
('01K2F2DKG0F23FPM7GPQ8TC1QT', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 122, 'Subscription payment 126', '2026-05-07 09:00:00'),
('01K2F2DKG0F23FPM7GPQ8TC1QT', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 122, 'Subscription payment 126', '2026-05-08 09:00:00'),
('01K2F2DKG0F23FPM7GPQ8TC1QT', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 122, 'Subscription payment 126', '2026-05-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(127, '01K2F2DKG0P9KX9F5SPH21DCMZ', 'LF-INV-2026000127', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-03-31 09:00:00', '2026-04-14 09:00:00', '2026-04-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000127.pdf', '2026-03-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(127, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-31', '2026-04-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(123, '01K2F2DKG0QJ4BGQWYW72KV87R', 'PAY-60123', 23, 127, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0q0x929dhrbceccdx', 'idem-01K2F2DKG062F6QGRX2HFAZC9N', 'https://cdn.livfinder.com/receipts/PAY-60123.pdf', '2026-03-31 09:00:00', '2026-04-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0EZTEJ8HPE86MSZT5', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 123, 'Subscription payment 127', '2026-04-02 09:00:00'),
('01K2F2DKG0EZTEJ8HPE86MSZT5', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 123, 'Subscription payment 127', '2026-03-31 09:00:00'),
('01K2F2DKG0EZTEJ8HPE86MSZT5', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 123, 'Subscription payment 127', '2026-04-10 09:00:00'),
('01K2F2DKG0EZTEJ8HPE86MSZT5', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 123, 'Subscription payment 127', '2026-04-08 09:00:00'),
('01K2F2DKG0EZTEJ8HPE86MSZT5', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 123, 'Subscription payment 127', '2026-04-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(128, '01K2F2DKG0SYA3ZQNMNBB0DBHP', 'LF-INV-2026000128', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-03-01 09:00:00', '2026-03-15 09:00:00', '2026-03-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000128.pdf', '2026-03-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(128, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-01', '2026-03-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(124, '01K2F2DKG0QBNB2ATAMTHT58HX', 'PAY-60124', 23, 128, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09zqeb2bx3y87vh8k', 'idem-01K2F2DKG09TDWMDM6Y8MZ2M5T', 'https://cdn.livfinder.com/receipts/PAY-60124.pdf', '2026-03-09 09:00:00', '2026-03-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NZXH30MK7PV2W69D', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 124, 'Subscription payment 128', '2026-03-12 09:00:00'),
('01K2F2DKG0NZXH30MK7PV2W69D', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 124, 'Subscription payment 128', '2026-03-13 09:00:00'),
('01K2F2DKG0NZXH30MK7PV2W69D', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 124, 'Subscription payment 128', '2026-03-01 09:00:00'),
('01K2F2DKG0NZXH30MK7PV2W69D', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 124, 'Subscription payment 128', '2026-03-03 09:00:00'),
('01K2F2DKG0NZXH30MK7PV2W69D', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 124, 'Subscription payment 128', '2026-03-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(129, '01K2F2DKG0B7NX80DXDTYR3KSN', 'LF-INV-2026000129', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2026-01-30 09:00:00', '2026-02-13 09:00:00', '2026-02-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000129.pdf', '2026-01-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(129, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-30', '2026-03-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(125, '01K2F2DKG0V90485DHWFFQ7J1Q', 'PAY-60125', 23, 129, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg080dd84xa8y8r0mf0', 'idem-01K2F2DKG03PHDXV71AB0PGW4N', 'https://cdn.livfinder.com/receipts/PAY-60125.pdf', '2026-02-01 09:00:00', '2026-02-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06N3P3E284EMEP17V', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 125, 'Subscription payment 129', '2026-01-30 09:00:00'),
('01K2F2DKG06N3P3E284EMEP17V', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 125, 'Subscription payment 129', '2026-02-04 09:00:00'),
('01K2F2DKG06N3P3E284EMEP17V', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 125, 'Subscription payment 129', '2026-01-30 09:00:00'),
('01K2F2DKG06N3P3E284EMEP17V', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 125, 'Subscription payment 129', '2026-02-02 09:00:00'),
('01K2F2DKG06N3P3E284EMEP17V', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 125, 'Subscription payment 129', '2026-02-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(130, '01K2F2DKG07B3RJS28A4E2KX26', 'LF-INV-2026000130', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2025-12-31 09:00:00', '2026-01-14 09:00:00', '2026-01-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000130.pdf', '2025-12-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(130, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-31', '2026-01-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(126, '01K2F2DKG0YW82P8T514Q2KC7F', 'PAY-60126', 23, 130, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0hnfjzhx3dhbmwsez', 'idem-01K2F2DKG0K5K5MF2BC9F4HAN2', 'https://cdn.livfinder.com/receipts/PAY-60126.pdf', '2026-01-05 09:00:00', '2026-01-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0D1DR4HZKPSEZ77KY', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 126, 'Subscription payment 130', '2026-01-12 09:00:00'),
('01K2F2DKG0D1DR4HZKPSEZ77KY', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 126, 'Subscription payment 130', '2026-01-07 09:00:00'),
('01K2F2DKG0D1DR4HZKPSEZ77KY', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 126, 'Subscription payment 130', '2026-01-12 09:00:00'),
('01K2F2DKG0D1DR4HZKPSEZ77KY', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 126, 'Subscription payment 130', '2026-01-01 09:00:00'),
('01K2F2DKG0D1DR4HZKPSEZ77KY', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 126, 'Subscription payment 130', '2026-01-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(131, '01K2F2DKG04TJGH4HVRQBPKSXV', 'LF-INV-2026000131', 23, 23, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Vantage Properties', 'billing@example.com', '2025-12-01 09:00:00', '2025-12-15 09:00:00', '2025-12-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000131.pdf', '2025-12-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(131, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-01', '2025-12-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(127, '01K2F2DKG0RK02YCPQJF9X5JR6', 'PAY-60127', 23, 131, 23, 23, 99, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gka1821448jw7pd0', 'idem-01K2F2DKG02GV0SRZPCW1WMBQF', 'https://cdn.livfinder.com/receipts/PAY-60127.pdf', '2025-12-10 09:00:00', '2025-12-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RA6QBFG29G21AB06', 23, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 127, 'Subscription payment 131', '2025-12-03 09:00:00'),
('01K2F2DKG0RA6QBFG29G21AB06', 23, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 127, 'Subscription payment 131', '2025-12-12 09:00:00'),
('01K2F2DKG0RA6QBFG29G21AB06', 23, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 127, 'Subscription payment 131', '2025-12-06 09:00:00'),
('01K2F2DKG0RA6QBFG29G21AB06', 23, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 127, 'Subscription payment 131', '2025-12-12 09:00:00'),
('01K2F2DKG0RA6QBFG29G21AB06', 23, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 127, 'Subscription payment 131', '2025-12-02 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(23, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-01 09:00:00'),
(23, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-07-23 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(24, '01K2F2DKG0YZDXNMMVCP2PZWRW', 24, 103, 'card', 'stripe', 'pm_01k2f2dkg0z6mdzzg98f8c13se', 'mastercard', '8949', 2, 2027, 'Solstice Real Estate', 1, 'active', '2024-05-30 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(24, '01K2F2DKG0NWTW93P9K952TG5M', 24, 4, 'active', 2499.0, 'AED', 2499.0, 'monthly', '2026-08-09 09:00:00', '2026-09-08 09:00:00', NULL, NULL, 1, 24, 'sub_01k2f2dkg0r6y74cxgqxnd05pr', '2025-06-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(132, '01K2F2DKG015DBTV6VGBQDTRHF', 'LF-INV-2026000132', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-07-10 09:00:00', '2026-07-24 09:00:00', '2026-07-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000132.pdf', '2026-07-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(132, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-10', '2026-08-09', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(128, '01K2F2DKG0K1GY64V9T48QVRFD', 'PAY-60128', 24, 132, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0z7hxz5bswa78zrwy', 'idem-01K2F2DKG02371Z47HWQ7Q7EJR', 'https://cdn.livfinder.com/receipts/PAY-60128.pdf', '2026-07-20 09:00:00', '2026-07-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WHFF4915SV9BZ969', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 128, 'Subscription payment 132', '2026-07-18 09:00:00'),
('01K2F2DKG0WHFF4915SV9BZ969', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 128, 'Subscription payment 132', '2026-07-11 09:00:00'),
('01K2F2DKG0WHFF4915SV9BZ969', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 128, 'Subscription payment 132', '2026-07-20 09:00:00'),
('01K2F2DKG0WHFF4915SV9BZ969', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 128, 'Subscription payment 132', '2026-07-10 09:00:00'),
('01K2F2DKG0WHFF4915SV9BZ969', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 128, 'Subscription payment 132', '2026-07-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(133, '01K2F2DKG07G2YP0TDGNT55FVK', 'LF-INV-2026000133', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-06-10 09:00:00', '2026-06-24 09:00:00', '2026-06-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000133.pdf', '2026-06-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(133, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-10', '2026-07-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(129, '01K2F2DKG0YADZ7C16MVHHE50Z', 'PAY-60129', 24, 133, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0jwxjm4p2ytyacb70', 'idem-01K2F2DKG0HBCF98W4N95N7KZH', 'https://cdn.livfinder.com/receipts/PAY-60129.pdf', '2026-06-17 09:00:00', '2026-06-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TRY5GPGAPQQRNH4P', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 129, 'Subscription payment 133', '2026-06-12 09:00:00'),
('01K2F2DKG0TRY5GPGAPQQRNH4P', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 129, 'Subscription payment 133', '2026-06-19 09:00:00'),
('01K2F2DKG0TRY5GPGAPQQRNH4P', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 129, 'Subscription payment 133', '2026-06-17 09:00:00'),
('01K2F2DKG0TRY5GPGAPQQRNH4P', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 129, 'Subscription payment 133', '2026-06-12 09:00:00'),
('01K2F2DKG0TRY5GPGAPQQRNH4P', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 129, 'Subscription payment 133', '2026-06-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(134, '01K2F2DKG0R4N1DQEH2C3AM10P', 'LF-INV-2026000134', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-05-11 09:00:00', '2026-05-25 09:00:00', '2026-05-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000134.pdf', '2026-05-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(134, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-11', '2026-06-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(130, '01K2F2DKG0BW435QYYZS02SDQK', 'PAY-60130', 24, 134, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg031xhsjhrjpj6p2ps', 'idem-01K2F2DKG0PB940W13NY7X587G', 'https://cdn.livfinder.com/receipts/PAY-60130.pdf', '2026-05-21 09:00:00', '2026-05-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06V43Z2P1JGD73NCT', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 130, 'Subscription payment 134', '2026-05-20 09:00:00'),
('01K2F2DKG06V43Z2P1JGD73NCT', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 130, 'Subscription payment 134', '2026-05-17 09:00:00'),
('01K2F2DKG06V43Z2P1JGD73NCT', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 130, 'Subscription payment 134', '2026-05-11 09:00:00'),
('01K2F2DKG06V43Z2P1JGD73NCT', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 130, 'Subscription payment 134', '2026-05-18 09:00:00'),
('01K2F2DKG06V43Z2P1JGD73NCT', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 130, 'Subscription payment 134', '2026-05-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(135, '01K2F2DKG01DM2ZE321HNDV1GE', 'LF-INV-2026000135', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-04-11 09:00:00', '2026-04-25 09:00:00', '2026-04-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000135.pdf', '2026-04-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(135, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-11', '2026-05-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(131, '01K2F2DKG018REQ0Z58WE121AZ', 'PAY-60131', 24, 135, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06krewgct3we59vxt', 'idem-01K2F2DKG03W46R7NT3CJESCAD', 'https://cdn.livfinder.com/receipts/PAY-60131.pdf', '2026-04-11 09:00:00', '2026-04-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0J21JXWQHV75NBN15', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 131, 'Subscription payment 135', '2026-04-11 09:00:00'),
('01K2F2DKG0J21JXWQHV75NBN15', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 131, 'Subscription payment 135', '2026-04-20 09:00:00'),
('01K2F2DKG0J21JXWQHV75NBN15', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 131, 'Subscription payment 135', '2026-04-15 09:00:00'),
('01K2F2DKG0J21JXWQHV75NBN15', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 131, 'Subscription payment 135', '2026-04-23 09:00:00'),
('01K2F2DKG0J21JXWQHV75NBN15', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 131, 'Subscription payment 135', '2026-04-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(136, '01K2F2DKG0HPWP4DZ4FZZ6PS36', 'LF-INV-2026000136', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-03-12 09:00:00', '2026-03-26 09:00:00', '2026-03-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000136.pdf', '2026-03-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(136, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-12', '2026-04-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(132, '01K2F2DKG06QHMDE7JARX1CN0A', 'PAY-60132', 24, 136, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qan3pmbs4mensv5j', 'idem-01K2F2DKG0YKXDZPMTP3Y40RR7', 'https://cdn.livfinder.com/receipts/PAY-60132.pdf', '2026-03-18 09:00:00', '2026-03-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0PBB5X11KJ3SJ5ESA', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 132, 'Subscription payment 136', '2026-03-14 09:00:00'),
('01K2F2DKG0PBB5X11KJ3SJ5ESA', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 132, 'Subscription payment 136', '2026-03-19 09:00:00'),
('01K2F2DKG0PBB5X11KJ3SJ5ESA', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 132, 'Subscription payment 136', '2026-03-24 09:00:00'),
('01K2F2DKG0PBB5X11KJ3SJ5ESA', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 132, 'Subscription payment 136', '2026-03-19 09:00:00'),
('01K2F2DKG0PBB5X11KJ3SJ5ESA', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 132, 'Subscription payment 136', '2026-03-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(137, '01K2F2DKG0XFD1RSGT9HY1X6FV', 'LF-INV-2026000137', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-02-10 09:00:00', '2026-02-24 09:00:00', '2026-02-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000137.pdf', '2026-02-10 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(137, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-10', '2026-03-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(133, '01K2F2DKG0ZXCMGW7BPNAA1ZHE', 'PAY-60133', 24, 137, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0c6xc0wt8ta77ven6', 'idem-01K2F2DKG0FCKZ8WRX29VP3GE5', 'https://cdn.livfinder.com/receipts/PAY-60133.pdf', '2026-02-22 09:00:00', '2026-02-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG069TM9BW41DR1N7S9', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 133, 'Subscription payment 137', '2026-02-22 09:00:00'),
('01K2F2DKG069TM9BW41DR1N7S9', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 133, 'Subscription payment 137', '2026-02-21 09:00:00'),
('01K2F2DKG069TM9BW41DR1N7S9', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 133, 'Subscription payment 137', '2026-02-11 09:00:00'),
('01K2F2DKG069TM9BW41DR1N7S9', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 133, 'Subscription payment 137', '2026-02-14 09:00:00'),
('01K2F2DKG069TM9BW41DR1N7S9', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 133, 'Subscription payment 137', '2026-02-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(138, '01K2F2DKG0A1JGJHH64K2EMS23', 'LF-INV-2026000138', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2026-01-11 09:00:00', '2026-01-25 09:00:00', '2026-01-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000138.pdf', '2026-01-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(138, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-11', '2026-02-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(134, '01K2F2DKG086XN6A1B8J8A5JED', 'PAY-60134', 24, 138, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0v7f6vwr0bp9316zm', 'idem-01K2F2DKG0NJW0Z5BMPBGSWSQH', 'https://cdn.livfinder.com/receipts/PAY-60134.pdf', '2026-01-17 09:00:00', '2026-01-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T7RHA84MEJA1JY7N', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 134, 'Subscription payment 138', '2026-01-20 09:00:00'),
('01K2F2DKG0T7RHA84MEJA1JY7N', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 134, 'Subscription payment 138', '2026-01-23 09:00:00'),
('01K2F2DKG0T7RHA84MEJA1JY7N', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 134, 'Subscription payment 138', '2026-01-20 09:00:00'),
('01K2F2DKG0T7RHA84MEJA1JY7N', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 134, 'Subscription payment 138', '2026-01-14 09:00:00'),
('01K2F2DKG0T7RHA84MEJA1JY7N', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 134, 'Subscription payment 138', '2026-01-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(139, '01K2F2DKG00YZV4PDQV6M8WD3F', 'LF-INV-2026000139', 24, 24, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Solstice Real Estate', 'billing@example.com', '2025-12-12 09:00:00', '2025-12-26 09:00:00', '2025-12-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000139.pdf', '2025-12-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(139, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-12', '2026-01-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(135, '01K2F2DKG0NR7WJJGR9SMM05QP', 'PAY-60135', 24, 139, 24, 24, 103, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0a5rmnface31jxyk5', 'idem-01K2F2DKG0KNKBMSS6N5VBQ1ZA', 'https://cdn.livfinder.com/receipts/PAY-60135.pdf', '2025-12-12 09:00:00', '2025-12-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XVRFDQ02SMJMPKPA', 24, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 135, 'Subscription payment 139', '2025-12-17 09:00:00'),
('01K2F2DKG0XVRFDQ02SMJMPKPA', 24, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 135, 'Subscription payment 139', '2025-12-14 09:00:00'),
('01K2F2DKG0XVRFDQ02SMJMPKPA', 24, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 135, 'Subscription payment 139', '2025-12-13 09:00:00'),
('01K2F2DKG0XVRFDQ02SMJMPKPA', 24, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 135, 'Subscription payment 139', '2025-12-21 09:00:00'),
('01K2F2DKG0XVRFDQ02SMJMPKPA', 24, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 135, 'Subscription payment 139', '2025-12-14 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(24, 'listing', 50, 50, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-26 09:00:00'),
(24, 'listing', -1, 49, 'consumption', 'listing', NULL, 'Listing published', '2025-11-11 09:00:00'),
(24, 'listing', -1, 48, 'consumption', 'listing', NULL, 'Listing published', '2026-06-29 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(25, '01K2F2DKG0D1EYPAFN1XP2HQ4B', 25, 107, 'card', 'stripe', 'pm_01k2f2dkg05q2d4nrac4gd6x70', 'amex', '8981', 12, 2028, 'Arcadia Estates', 1, 'active', '2026-06-06 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(25, '01K2F2DKG06YTT11BAVTV0859J', 25, 6, 'active', 149000.0, 'EUR', 593630.9, 'yearly', '2025-10-24 09:00:00', '2026-10-24 09:00:00', NULL, NULL, 1, 25, 'sub_01k2f2dkg06ep09gwjmnbpbpe1', '2024-03-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(140, '01K2F2DKG0YFX13TTRGSY7MDRW', 'LF-INV-2026000140', 25, 25, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Arcadia Estates', 'billing@example.com', '2024-10-24 09:00:00', '2024-11-07 09:00:00', '2024-11-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000140.pdf', '2024-10-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(140, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-10-24', '2025-10-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(136, '01K2F2DKG0NDXRK7M7EVRZC2RX', 'PAY-60136', 25, 140, 25, 25, 107, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pcdrwaybe8hf1x1g', 'idem-01K2F2DKG027Y59MN4MVPYBN21', 'https://cdn.livfinder.com/receipts/PAY-60136.pdf', '2024-11-05 09:00:00', '2024-11-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HA04Y1Z2D08SQT61', 25, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 136, 'Subscription payment 140', '2024-11-05 09:00:00'),
('01K2F2DKG0HA04Y1Z2D08SQT61', 25, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 136, 'Subscription payment 140', '2024-11-03 09:00:00'),
('01K2F2DKG0HA04Y1Z2D08SQT61', 25, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 136, 'Subscription payment 140', '2024-10-28 09:00:00'),
('01K2F2DKG0HA04Y1Z2D08SQT61', 25, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 136, 'Subscription payment 140', '2024-10-27 09:00:00'),
('01K2F2DKG0HA04Y1Z2D08SQT61', 25, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 136, 'Subscription payment 140', '2024-10-27 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(141, '01K2F2DKG07SBGP1RKQK2QNJPS', 'LF-INV-2026000141', 25, 25, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Arcadia Estates', 'billing@example.com', '2023-10-25 09:00:00', '2023-11-08 09:00:00', '2023-11-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000141.pdf', '2023-10-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(141, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-10-25', '2024-10-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(137, '01K2F2DKG0M12W1DQGMHKN6QYN', 'PAY-60137', 25, 141, 25, 25, 107, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0q28fra4jcjy5ht7z', 'idem-01K2F2DKG0958R6PN2CYE1J3Y8', 'https://cdn.livfinder.com/receipts/PAY-60137.pdf', '2023-11-05 09:00:00', '2023-10-25 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0C3NJMV0FNMJWEA4E', 25, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 137, 'Subscription payment 141', '2023-10-27 09:00:00'),
('01K2F2DKG0C3NJMV0FNMJWEA4E', 25, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 137, 'Subscription payment 141', '2023-11-02 09:00:00'),
('01K2F2DKG0C3NJMV0FNMJWEA4E', 25, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 137, 'Subscription payment 141', '2023-11-03 09:00:00'),
('01K2F2DKG0C3NJMV0FNMJWEA4E', 25, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 137, 'Subscription payment 141', '2023-11-03 09:00:00'),
('01K2F2DKG0C3NJMV0FNMJWEA4E', 25, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 137, 'Subscription payment 141', '2023-10-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(142, '01K2F2DKG05MAFPP8BA0K8QEYR', 'LF-INV-2026000142', 25, 25, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Arcadia Estates', 'billing@example.com', '2022-10-25 09:00:00', '2022-11-08 09:00:00', '2022-10-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000142.pdf', '2022-10-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(142, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-10-25', '2023-10-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(138, '01K2F2DKG0YNN76KAKS4H0NEAM', 'PAY-60138', 25, 142, 25, 25, 107, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mj2rnjmy70w2vjmn', 'idem-01K2F2DKG0STEEFTKRG6PKFG7W', 'https://cdn.livfinder.com/receipts/PAY-60138.pdf', '2022-11-03 09:00:00', '2022-11-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NHWEEN9VGQYBZPTQ', 25, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 138, 'Subscription payment 142', '2022-11-05 09:00:00'),
('01K2F2DKG0NHWEEN9VGQYBZPTQ', 25, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 138, 'Subscription payment 142', '2022-11-06 09:00:00'),
('01K2F2DKG0NHWEEN9VGQYBZPTQ', 25, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 138, 'Subscription payment 142', '2022-10-26 09:00:00'),
('01K2F2DKG0NHWEEN9VGQYBZPTQ', 25, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 138, 'Subscription payment 142', '2022-10-26 09:00:00'),
('01K2F2DKG0NHWEEN9VGQYBZPTQ', 25, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 138, 'Subscription payment 142', '2022-11-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(143, '01K2F2DKG02DV7D1K7T0R2QRFV', 'LF-INV-2026000143', 25, 25, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Arcadia Estates', 'billing@example.com', '2021-10-25 09:00:00', '2021-11-08 09:00:00', '2021-11-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000143.pdf', '2021-10-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(143, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-10-25', '2022-10-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(139, '01K2F2DKG0E68HWEM01BNEA401', 'PAY-60139', 25, 143, 25, 25, 107, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mkp3crzzgy696fzp', 'idem-01K2F2DKG0AZGSF37YY2X5T0BS', 'https://cdn.livfinder.com/receipts/PAY-60139.pdf', '2021-11-05 09:00:00', '2021-10-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CKAR3D2TE9SD5RW2', 25, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 139, 'Subscription payment 143', '2021-11-01 09:00:00'),
('01K2F2DKG0CKAR3D2TE9SD5RW2', 25, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 139, 'Subscription payment 143', '2021-10-27 09:00:00'),
('01K2F2DKG0CKAR3D2TE9SD5RW2', 25, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 139, 'Subscription payment 143', '2021-10-28 09:00:00'),
('01K2F2DKG0CKAR3D2TE9SD5RW2', 25, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 139, 'Subscription payment 143', '2021-10-26 09:00:00'),
('01K2F2DKG0CKAR3D2TE9SD5RW2', 25, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 139, 'Subscription payment 143', '2021-11-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(144, '01K2F2DKG0ZNVHF54W0S35DJCW', 'LF-INV-2026000144', 25, 25, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Arcadia Estates', 'billing@example.com', '2020-10-25 09:00:00', '2020-11-08 09:00:00', '2020-10-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000144.pdf', '2020-10-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(144, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-10-25', '2021-10-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(140, '01K2F2DKG0CSFSRT1MHRYXD0HQ', 'PAY-60140', 25, 144, 25, 25, 107, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0d3eaehkv2bw75p1a', 'idem-01K2F2DKG0WN3JJDX0573RYGJX', 'https://cdn.livfinder.com/receipts/PAY-60140.pdf', '2020-11-05 09:00:00', '2020-11-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0PPP7YAW6EY8TA52V', 25, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 140, 'Subscription payment 144', '2020-11-03 09:00:00'),
('01K2F2DKG0PPP7YAW6EY8TA52V', 25, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 140, 'Subscription payment 144', '2020-10-29 09:00:00'),
('01K2F2DKG0PPP7YAW6EY8TA52V', 25, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 140, 'Subscription payment 144', '2020-10-25 09:00:00'),
('01K2F2DKG0PPP7YAW6EY8TA52V', 25, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 140, 'Subscription payment 144', '2020-10-26 09:00:00'),
('01K2F2DKG0PPP7YAW6EY8TA52V', 25, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 140, 'Subscription payment 144', '2020-10-26 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(25, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-09 09:00:00'),
(25, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2025-12-04 09:00:00'),
(25, 'listing', 10, 19, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-15 09:00:00'),
(25, 'listing', -1, 18, 'consumption', 'listing', NULL, 'Listing published', '2026-01-26 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(26, '01K2F2DKG0MT5FMMFPFHNC22ZV', 26, 111, 'card', 'stripe', 'pm_01k2f2dkg03gaac7nccj6qe7k5', 'mastercard', '5057', 1, 2028, 'Belmont Motors', 1, 'active', '2026-01-11 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(26, '01K2F2DKG0HFM5GPA5ZDTWYQ5K', 26, 4, 'active', 2499.0, 'AUD', 5978.36, 'monthly', '2026-08-10 09:00:00', '2026-09-09 09:00:00', NULL, NULL, 1, 26, 'sub_01k2f2dkg0wq4qb42hy0x6srew', '2024-12-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(145, '01K2F2DKG0M0BV457FG1BS82EE', 'LF-INV-2026000145', 26, 26, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Belmont Motors', 'billing@example.com', '2026-07-11 09:00:00', '2026-07-25 09:00:00', '2026-07-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000145.pdf', '2026-07-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(145, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-11', '2026-08-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(141, '01K2F2DKG0P0MMTFRYDKS0FCPW', 'PAY-60141', 26, 145, 26, 26, 111, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rnxsd5jf6ms06f46', 'idem-01K2F2DKG0XN209226AD5HFAHM', 'https://cdn.livfinder.com/receipts/PAY-60141.pdf', '2026-07-22 09:00:00', '2026-07-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08W4XWT6VC6MQB52A', 26, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 141, 'Subscription payment 145', '2026-07-14 09:00:00'),
('01K2F2DKG08W4XWT6VC6MQB52A', 26, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 141, 'Subscription payment 145', '2026-07-18 09:00:00'),
('01K2F2DKG08W4XWT6VC6MQB52A', 26, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 141, 'Subscription payment 145', '2026-07-11 09:00:00'),
('01K2F2DKG08W4XWT6VC6MQB52A', 26, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 141, 'Subscription payment 145', '2026-07-15 09:00:00'),
('01K2F2DKG08W4XWT6VC6MQB52A', 26, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 141, 'Subscription payment 145', '2026-07-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(146, '01K2F2DKG0Y7QYEFQWQ4F4GQQ4', 'LF-INV-2026000146', 26, 26, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Belmont Motors', 'billing@example.com', '2026-06-11 09:00:00', '2026-06-25 09:00:00', '2026-06-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000146.pdf', '2026-06-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(146, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-11', '2026-07-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(142, '01K2F2DKG0YX23JW9PRESK8VP9', 'PAY-60142', 26, 146, 26, 26, 111, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03729d7xsfyezh80s', 'idem-01K2F2DKG08NA0WKATSHC979JA', 'https://cdn.livfinder.com/receipts/PAY-60142.pdf', '2026-06-21 09:00:00', '2026-06-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0K8CV249CKWCF32FP', 26, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 142, 'Subscription payment 146', '2026-06-11 09:00:00'),
('01K2F2DKG0K8CV249CKWCF32FP', 26, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 142, 'Subscription payment 146', '2026-06-17 09:00:00'),
('01K2F2DKG0K8CV249CKWCF32FP', 26, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 142, 'Subscription payment 146', '2026-06-15 09:00:00'),
('01K2F2DKG0K8CV249CKWCF32FP', 26, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 142, 'Subscription payment 146', '2026-06-17 09:00:00'),
('01K2F2DKG0K8CV249CKWCF32FP', 26, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 142, 'Subscription payment 146', '2026-06-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(147, '01K2F2DKG0WF413DP2CS849EPS', 'LF-INV-2026000147', 26, 26, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Belmont Motors', 'billing@example.com', '2026-05-12 09:00:00', '2026-05-26 09:00:00', '2026-05-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000147.pdf', '2026-05-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(147, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-12', '2026-06-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(143, '01K2F2DKG06938XV6JE2VRMVJ3', 'PAY-60143', 26, 147, 26, 26, 111, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0apr8rehkcthrf74b', 'idem-01K2F2DKG03FYSDZ90E116MT3S', 'https://cdn.livfinder.com/receipts/PAY-60143.pdf', '2026-05-14 09:00:00', '2026-05-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG03A5Y16N19426MG41', 26, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 143, 'Subscription payment 147', '2026-05-18 09:00:00'),
('01K2F2DKG03A5Y16N19426MG41', 26, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 143, 'Subscription payment 147', '2026-05-13 09:00:00'),
('01K2F2DKG03A5Y16N19426MG41', 26, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 143, 'Subscription payment 147', '2026-05-14 09:00:00'),
('01K2F2DKG03A5Y16N19426MG41', 26, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 143, 'Subscription payment 147', '2026-05-14 09:00:00'),
('01K2F2DKG03A5Y16N19426MG41', 26, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 143, 'Subscription payment 147', '2026-05-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(148, '01K2F2DKG0PF29Y5XWJSPCC889', 'LF-INV-2026000148', 26, 26, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Belmont Motors', 'billing@example.com', '2026-04-12 09:00:00', '2026-04-26 09:00:00', '2026-04-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000148.pdf', '2026-04-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(148, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-12', '2026-05-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(144, '01K2F2DKG083SX9J7X292FVC1B', 'PAY-60144', 26, 148, 26, 26, 111, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg001fpgw95v8c038eh', 'idem-01K2F2DKG0P44V7WGVQXPW6W8B', 'https://cdn.livfinder.com/receipts/PAY-60144.pdf', '2026-04-14 09:00:00', '2026-04-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RMQG33J81W299YXJ', 26, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 144, 'Subscription payment 148', '2026-04-19 09:00:00'),
('01K2F2DKG0RMQG33J81W299YXJ', 26, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 144, 'Subscription payment 148', '2026-04-24 09:00:00'),
('01K2F2DKG0RMQG33J81W299YXJ', 26, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 144, 'Subscription payment 148', '2026-04-18 09:00:00'),
('01K2F2DKG0RMQG33J81W299YXJ', 26, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 144, 'Subscription payment 148', '2026-04-24 09:00:00'),
('01K2F2DKG0RMQG33J81W299YXJ', 26, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 144, 'Subscription payment 148', '2026-04-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(149, '01K2F2DKG0M0964YDGQJZBT00P', 'LF-INV-2026000149', 26, 26, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AUD', 2.3923, 6277.28, 5.0, 'VAT', 'Belmont Motors', 'billing@example.com', '2026-03-13 09:00:00', '2026-03-27 09:00:00', '2026-03-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000149.pdf', '2026-03-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(149, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-13', '2026-04-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(145, '01K2F2DKG02PNJQ1867A2CE344', 'PAY-60145', 26, 149, 26, 26, 111, 2623.95, 'AUD', 2.3923, 6277.28, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0967s6xbj8ny0nqwd', 'idem-01K2F2DKG006G9AFH6MA8DVWBZ', 'https://cdn.livfinder.com/receipts/PAY-60145.pdf', '2026-03-25 09:00:00', '2026-03-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0BG5JH0QXN1X04D0N', 26, 'cash', 'debit', 2623.95, 'AUD', 6277.28, 'payment', 145, 'Subscription payment 149', '2026-03-25 09:00:00'),
('01K2F2DKG0BG5JH0QXN1X04D0N', 26, 'revenue.subscription', 'credit', 2499.0, 'AUD', 5978.36, 'payment', 145, 'Subscription payment 149', '2026-03-13 09:00:00'),
('01K2F2DKG0BG5JH0QXN1X04D0N', 26, 'tax_payable', 'credit', 124.95, 'AUD', 298.92, 'payment', 145, 'Subscription payment 149', '2026-03-19 09:00:00'),
('01K2F2DKG0BG5JH0QXN1X04D0N', 26, 'expense.processor_fees', 'debit', 77.09, 'AUD', 184.42, 'payment', 145, 'Subscription payment 149', '2026-03-20 09:00:00'),
('01K2F2DKG0BG5JH0QXN1X04D0N', 26, 'cash', 'credit', 77.09, 'AUD', 184.42, 'payment', 145, 'Subscription payment 149', '2026-03-16 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(26, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-04-16 09:00:00'),
(26, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-05 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(27, '01K2F2DKG0HVW4WCR4PJS344ZJ', 27, 115, 'card', 'stripe', 'pm_01k2f2dkg0qtagqrvevx5c5mpa', 'mastercard', '7168', 10, 2031, 'Cortona Automotive', 1, 'active', '2024-11-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(27, '01K2F2DKG0BCBTC8JS2M0JXRKW', 27, 4, 'past_due', 2499.0, 'AED', 2499.0, 'monthly', '2026-07-21 09:00:00', '2026-08-20 09:00:00', NULL, NULL, 1, 27, 'sub_01k2f2dkg01a3rtzte5r42h5fc', '2023-12-29 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(150, '01K2F2DKG03YNKBRX5T18XFAK9', 'LF-INV-2026000150', 27, 27, 'past_due', 2499.0, 0, 124.95, 2623.95, 0, 2623.95, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-06-21 09:00:00', '2026-07-05 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000150.pdf', '2026-06-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(150, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-21', '2026-07-21', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(151, '01K2F2DKG0GTKVHBCEK5QA628F', 'LF-INV-2026000151', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-05-22 09:00:00', '2026-06-05 09:00:00', '2026-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000151.pdf', '2026-05-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(151, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-22', '2026-06-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(146, '01K2F2DKG05TVC63RTB56KQBC3', 'PAY-60146', 27, 151, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg05zwmn3a1y81nw4qe', 'idem-01K2F2DKG0XHQY3PAHKF5ASPN0', 'https://cdn.livfinder.com/receipts/PAY-60146.pdf', '2026-06-02 09:00:00', '2026-05-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09B0JM2QEXB63EEHF', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 146, 'Subscription payment 151', '2026-05-22 09:00:00'),
('01K2F2DKG09B0JM2QEXB63EEHF', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 146, 'Subscription payment 151', '2026-05-24 09:00:00'),
('01K2F2DKG09B0JM2QEXB63EEHF', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 146, 'Subscription payment 151', '2026-05-22 09:00:00'),
('01K2F2DKG09B0JM2QEXB63EEHF', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 146, 'Subscription payment 151', '2026-05-28 09:00:00'),
('01K2F2DKG09B0JM2QEXB63EEHF', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 146, 'Subscription payment 151', '2026-06-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(152, '01K2F2DKG0S7F7QW4A6R2BVAF3', 'LF-INV-2026000152', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-04-22 09:00:00', '2026-05-06 09:00:00', '2026-05-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000152.pdf', '2026-04-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(152, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-22', '2026-05-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(147, '01K2F2DKG090X6YGJJ4F7TKK0M', 'PAY-60147', 27, 152, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06qzry8kh34ahbh17', 'idem-01K2F2DKG0EKAQBBGQXPT59B8E', 'https://cdn.livfinder.com/receipts/PAY-60147.pdf', '2026-04-25 09:00:00', '2026-04-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09ZNKQGTF3A38GDD3', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 147, 'Subscription payment 152', '2026-04-22 09:00:00'),
('01K2F2DKG09ZNKQGTF3A38GDD3', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 147, 'Subscription payment 152', '2026-04-27 09:00:00'),
('01K2F2DKG09ZNKQGTF3A38GDD3', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 147, 'Subscription payment 152', '2026-04-28 09:00:00'),
('01K2F2DKG09ZNKQGTF3A38GDD3', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 147, 'Subscription payment 152', '2026-04-28 09:00:00'),
('01K2F2DKG09ZNKQGTF3A38GDD3', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 147, 'Subscription payment 152', '2026-04-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(153, '01K2F2DKG0N3VPJGQ4V59SHV2K', 'LF-INV-2026000153', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-03-23 09:00:00', '2026-04-06 09:00:00', '2026-04-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000153.pdf', '2026-03-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(153, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-23', '2026-04-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(148, '01K2F2DKG074VDJJSGN5YP48Z1', 'PAY-60148', 27, 153, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0z10pzresmacktr2p', 'idem-01K2F2DKG0GP14RR9K530R12HS', 'https://cdn.livfinder.com/receipts/PAY-60148.pdf', '2026-03-26 09:00:00', '2026-03-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CZK0VD5Z82SMT8Y3', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 148, 'Subscription payment 153', '2026-03-31 09:00:00'),
('01K2F2DKG0CZK0VD5Z82SMT8Y3', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 148, 'Subscription payment 153', '2026-04-04 09:00:00'),
('01K2F2DKG0CZK0VD5Z82SMT8Y3', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 148, 'Subscription payment 153', '2026-03-28 09:00:00'),
('01K2F2DKG0CZK0VD5Z82SMT8Y3', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 148, 'Subscription payment 153', '2026-03-26 09:00:00'),
('01K2F2DKG0CZK0VD5Z82SMT8Y3', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 148, 'Subscription payment 153', '2026-03-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(154, '01K2F2DKG09MT2BK4015G2N88S', 'LF-INV-2026000154', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-02-21 09:00:00', '2026-03-07 09:00:00', '2026-02-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000154.pdf', '2026-02-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(154, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-21', '2026-03-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(149, '01K2F2DKG0CZESZP89TQNMZKA9', 'PAY-60149', 27, 154, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0khzz6ej96bqejhtv', 'idem-01K2F2DKG04PCQ8PNB5J17GH15', 'https://cdn.livfinder.com/receipts/PAY-60149.pdf', '2026-02-26 09:00:00', '2026-02-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JT05YXMEMQKFD1GX', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 149, 'Subscription payment 154', '2026-02-26 09:00:00'),
('01K2F2DKG0JT05YXMEMQKFD1GX', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 149, 'Subscription payment 154', '2026-02-24 09:00:00'),
('01K2F2DKG0JT05YXMEMQKFD1GX', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 149, 'Subscription payment 154', '2026-03-02 09:00:00'),
('01K2F2DKG0JT05YXMEMQKFD1GX', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 149, 'Subscription payment 154', '2026-02-24 09:00:00'),
('01K2F2DKG0JT05YXMEMQKFD1GX', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 149, 'Subscription payment 154', '2026-02-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(155, '01K2F2DKG0FX1K4N27ZD4W5PET', 'LF-INV-2026000155', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2026-01-22 09:00:00', '2026-02-05 09:00:00', '2026-02-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000155.pdf', '2026-01-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(155, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-22', '2026-02-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(150, '01K2F2DKG04AK80MB2ABHX88P6', 'PAY-60150', 27, 155, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mwya0b3nwx6psn8v', 'idem-01K2F2DKG0041NWRRX8CBV6GKW', 'https://cdn.livfinder.com/receipts/PAY-60150.pdf', '2026-01-29 09:00:00', '2026-02-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08FSG4JN52AEJX2NS', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 150, 'Subscription payment 155', '2026-01-31 09:00:00'),
('01K2F2DKG08FSG4JN52AEJX2NS', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 150, 'Subscription payment 155', '2026-01-30 09:00:00'),
('01K2F2DKG08FSG4JN52AEJX2NS', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 150, 'Subscription payment 155', '2026-02-02 09:00:00'),
('01K2F2DKG08FSG4JN52AEJX2NS', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 150, 'Subscription payment 155', '2026-01-26 09:00:00'),
('01K2F2DKG08FSG4JN52AEJX2NS', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 150, 'Subscription payment 155', '2026-02-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(156, '01K2F2DKG0RYGRA4QAM295XZSA', 'LF-INV-2026000156', 27, 27, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'AED', 1.0, 2623.95, 5.0, 'VAT', 'Cortona Automotive', 'billing@example.com', '2025-12-23 09:00:00', '2026-01-06 09:00:00', '2026-01-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000156.pdf', '2025-12-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(156, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-23', '2026-01-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(151, '01K2F2DKG0NFHNQ0877ACPFCKQ', 'PAY-60151', 27, 156, 27, 27, 115, 2623.95, 'AED', 1.0, 2623.95, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09gm797hqxg5h6bsc', 'idem-01K2F2DKG0QNJ2WFVN1MRYFV73', 'https://cdn.livfinder.com/receipts/PAY-60151.pdf', '2025-12-26 09:00:00', '2025-12-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG03FT1RJ4MWN99XXHK', 27, 'cash', 'debit', 2623.95, 'AED', 2623.95, 'payment', 151, 'Subscription payment 156', '2025-12-28 09:00:00'),
('01K2F2DKG03FT1RJ4MWN99XXHK', 27, 'revenue.subscription', 'credit', 2499.0, 'AED', 2499.0, 'payment', 151, 'Subscription payment 156', '2026-01-01 09:00:00'),
('01K2F2DKG03FT1RJ4MWN99XXHK', 27, 'tax_payable', 'credit', 124.95, 'AED', 124.95, 'payment', 151, 'Subscription payment 156', '2025-12-31 09:00:00'),
('01K2F2DKG03FT1RJ4MWN99XXHK', 27, 'expense.processor_fees', 'debit', 77.09, 'AED', 77.09, 'payment', 151, 'Subscription payment 156', '2025-12-24 09:00:00'),
('01K2F2DKG03FT1RJ4MWN99XXHK', 27, 'cash', 'credit', 77.09, 'AED', 77.09, 'payment', 151, 'Subscription payment 156', '2025-12-23 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(27, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-11 09:00:00'),
(27, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2026-04-03 09:00:00'),
(27, 'listing', -1, 8, 'consumption', 'listing', NULL, 'Listing published', '2026-01-26 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(28, '01K2F2DKG0N00EJRQZR186EHEM', 28, 119, 'card', 'stripe', 'pm_01k2f2dkg0bwrhcdc1snrxfcy9', 'mastercard', '9878', 5, 2027, 'Delmar Yachts', 1, 'active', '2026-01-20 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(28, '01K2F2DKG0VXJMCB8QF3ZND9R7', 28, 6, 'cancelled', 149000.0, 'EUR', 593630.9, 'yearly', '2026-03-21 09:00:00', '2027-03-21 09:00:00', NULL, '2026-07-10 09:00:00', 0, 28, 'sub_01k2f2dkg0g3qna6qbxpqafhmq', '2024-04-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(157, '01K2F2DKG0EG3P7YYXF04D4H32', 'LF-INV-2026000157', 28, 28, 'past_due', 149000.0, 0, 7450.0, 156450.0, 0, 156450.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2025-03-21 09:00:00', '2025-04-04 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000157.pdf', '2025-03-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(157, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-03-21', '2026-03-21', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(158, '01K2F2DKG0TEDAQM2SE5REVP13', 'LF-INV-2026000158', 28, 28, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2024-03-21 09:00:00', '2024-04-04 09:00:00', '2024-03-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000158.pdf', '2024-03-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(158, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-03-21', '2025-03-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(152, '01K2F2DKG02GF48FK0EY17R2VS', 'PAY-60152', 28, 158, 28, 28, 119, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0f7n3yb95v1jdp8t6', 'idem-01K2F2DKG0YVCF76MXAKNFC07G', 'https://cdn.livfinder.com/receipts/PAY-60152.pdf', '2024-03-23 09:00:00', '2024-03-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0H0PQ6F9A059TWT9W', 28, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 152, 'Subscription payment 158', '2024-03-23 09:00:00'),
('01K2F2DKG0H0PQ6F9A059TWT9W', 28, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 152, 'Subscription payment 158', '2024-03-25 09:00:00'),
('01K2F2DKG0H0PQ6F9A059TWT9W', 28, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 152, 'Subscription payment 158', '2024-03-22 09:00:00'),
('01K2F2DKG0H0PQ6F9A059TWT9W', 28, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 152, 'Subscription payment 158', '2024-03-26 09:00:00'),
('01K2F2DKG0H0PQ6F9A059TWT9W', 28, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 152, 'Subscription payment 158', '2024-03-27 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(159, '01K2F2DKG0CZ5HZ8DNPQDG21T5', 'LF-INV-2026000159', 28, 28, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2023-03-22 09:00:00', '2023-04-05 09:00:00', '2023-03-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000159.pdf', '2023-03-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(159, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-03-22', '2024-03-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(153, '01K2F2DKG0RFVM1AMZPMAK6FFR', 'PAY-60153', 28, 159, 28, 28, 119, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ytasm8905ztvz9w3', 'idem-01K2F2DKG0D5ZSJC5TXRBGS4VH', 'https://cdn.livfinder.com/receipts/PAY-60153.pdf', '2023-03-27 09:00:00', '2023-03-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0J0ZNJR8ZS8HFJRCT', 28, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 153, 'Subscription payment 159', '2023-04-03 09:00:00'),
('01K2F2DKG0J0ZNJR8ZS8HFJRCT', 28, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 153, 'Subscription payment 159', '2023-04-01 09:00:00'),
('01K2F2DKG0J0ZNJR8ZS8HFJRCT', 28, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 153, 'Subscription payment 159', '2023-03-27 09:00:00'),
('01K2F2DKG0J0ZNJR8ZS8HFJRCT', 28, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 153, 'Subscription payment 159', '2023-03-26 09:00:00'),
('01K2F2DKG0J0ZNJR8ZS8HFJRCT', 28, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 153, 'Subscription payment 159', '2023-04-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(160, '01K2F2DKG0C3ZE6WMNQB4CQM3P', 'LF-INV-2026000160', 28, 28, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2022-03-22 09:00:00', '2022-04-05 09:00:00', '2022-04-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000160.pdf', '2022-03-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(160, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-03-22', '2023-03-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(154, '01K2F2DKG0DT3HCX9DS2AS48R8', 'PAY-60154', 28, 160, 28, 28, 119, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qbg4b47v75k1pb3e', 'idem-01K2F2DKG0XWSHF7AB3K1M3MMA', 'https://cdn.livfinder.com/receipts/PAY-60154.pdf', '2022-03-27 09:00:00', '2022-04-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZRRTEEAXRAAE1PET', 28, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 154, 'Subscription payment 160', '2022-03-29 09:00:00'),
('01K2F2DKG0ZRRTEEAXRAAE1PET', 28, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 154, 'Subscription payment 160', '2022-03-23 09:00:00'),
('01K2F2DKG0ZRRTEEAXRAAE1PET', 28, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 154, 'Subscription payment 160', '2022-03-25 09:00:00'),
('01K2F2DKG0ZRRTEEAXRAAE1PET', 28, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 154, 'Subscription payment 160', '2022-03-24 09:00:00'),
('01K2F2DKG0ZRRTEEAXRAAE1PET', 28, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 154, 'Subscription payment 160', '2022-04-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(161, '01K2F2DKG0WXN4W3RMH2ZXQKEJ', 'LF-INV-2026000161', 28, 28, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2021-03-22 09:00:00', '2021-04-05 09:00:00', '2021-03-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000161.pdf', '2021-03-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(161, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-03-22', '2022-03-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(155, '01K2F2DKG0DJB4GBQ55QXV4T0F', 'PAY-60155', 28, 161, 28, 28, 119, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg086mx0zrrmzjap1df', 'idem-01K2F2DKG0KCKSEFARA9Y4VXAF', 'https://cdn.livfinder.com/receipts/PAY-60155.pdf', '2021-03-24 09:00:00', '2021-03-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NZ4B78V27JHKXY41', 28, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 155, 'Subscription payment 161', '2021-03-24 09:00:00'),
('01K2F2DKG0NZ4B78V27JHKXY41', 28, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 155, 'Subscription payment 161', '2021-03-27 09:00:00'),
('01K2F2DKG0NZ4B78V27JHKXY41', 28, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 155, 'Subscription payment 161', '2021-03-28 09:00:00'),
('01K2F2DKG0NZ4B78V27JHKXY41', 28, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 155, 'Subscription payment 161', '2021-04-03 09:00:00'),
('01K2F2DKG0NZ4B78V27JHKXY41', 28, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 155, 'Subscription payment 161', '2021-03-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(162, '01K2F2DKG0A8A8WMPWNNDH11CZ', 'LF-INV-2026000162', 28, 28, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Delmar Yachts', 'billing@example.com', '2020-03-22 09:00:00', '2020-04-05 09:00:00', '2020-03-26 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000162.pdf', '2020-03-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(162, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-03-22', '2021-03-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(156, '01K2F2DKG0MFE9JCWQQPKRH29Y', 'PAY-60156', 28, 162, 28, 28, 119, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0k2qtrktr0ptz8xpr', 'idem-01K2F2DKG0WSEJYMN96XK98F0V', 'https://cdn.livfinder.com/receipts/PAY-60156.pdf', '2020-03-26 09:00:00', '2020-03-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZB9K070VD75F4ADM', 28, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 156, 'Subscription payment 162', '2020-03-23 09:00:00'),
('01K2F2DKG0ZB9K070VD75F4ADM', 28, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 156, 'Subscription payment 162', '2020-03-27 09:00:00'),
('01K2F2DKG0ZB9K070VD75F4ADM', 28, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 156, 'Subscription payment 162', '2020-04-02 09:00:00'),
('01K2F2DKG0ZB9K070VD75F4ADM', 28, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 156, 'Subscription payment 162', '2020-03-30 09:00:00'),
('01K2F2DKG0ZB9K070VD75F4ADM', 28, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 156, 'Subscription payment 162', '2020-03-23 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(28, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-02 09:00:00'),
(28, 'listing', 20, 19, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-02 09:00:00'),
(28, 'listing', -1, 18, 'consumption', 'listing', NULL, 'Listing published', '2026-02-16 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(29, '01K2F2DKG0TNEATG2H688Z6KW7', 29, 123, 'card', 'stripe', 'pm_01k2f2dkg0vhmwv59g6hqz2q60', 'visa', '9503', 3, 2028, 'Everline Marine', 1, 'active', '2024-08-01 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(29, '01K2F2DKG041BEWQX61KFGCPJW', 29, 4, 'past_due', 2499.0, 'EUR', 9956.27, 'monthly', '2026-07-26 09:00:00', '2026-08-25 09:00:00', NULL, NULL, 1, 29, 'sub_01k2f2dkg0ex7kn8yf6507091d', '2023-12-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(163, '01K2F2DKG0TNMRHFC9VYVFEKAE', 'LF-INV-2026000163', 29, 29, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Everline Marine', 'billing@example.com', '2026-06-26 09:00:00', '2026-07-10 09:00:00', '2026-07-06 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000163.pdf', '2026-06-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(163, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-26', '2026-07-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(157, '01K2F2DKG0X1FXMFYQF28RARR7', 'PAY-60157', 29, 163, 29, 29, 123, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06b5h6af9nysj6cgj', 'idem-01K2F2DKG0YSN31W10M5TCD8KH', 'https://cdn.livfinder.com/receipts/PAY-60157.pdf', '2026-07-07 09:00:00', '2026-07-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0786NHNCZEED136VD', 29, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 157, 'Subscription payment 163', '2026-06-29 09:00:00'),
('01K2F2DKG0786NHNCZEED136VD', 29, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 157, 'Subscription payment 163', '2026-07-08 09:00:00'),
('01K2F2DKG0786NHNCZEED136VD', 29, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 157, 'Subscription payment 163', '2026-07-03 09:00:00'),
('01K2F2DKG0786NHNCZEED136VD', 29, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 157, 'Subscription payment 163', '2026-06-28 09:00:00'),
('01K2F2DKG0786NHNCZEED136VD', 29, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 157, 'Subscription payment 163', '2026-07-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(164, '01K2F2DKG0ASK7HAPQQ6KC2388', 'LF-INV-2026000164', 29, 29, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Everline Marine', 'billing@example.com', '2026-05-27 09:00:00', '2026-06-10 09:00:00', '2026-05-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000164.pdf', '2026-05-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(164, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-27', '2026-06-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(158, '01K2F2DKG0JDSR8DY4QTWTXTPJ', 'PAY-60158', 29, 164, 29, 29, 123, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dj6qyysk3s809ydp', 'idem-01K2F2DKG0RE6V5JS7VQF4M001', 'https://cdn.livfinder.com/receipts/PAY-60158.pdf', '2026-05-31 09:00:00', '2026-05-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04M4MCM09HAZ03KEA', 29, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 158, 'Subscription payment 164', '2026-05-31 09:00:00'),
('01K2F2DKG04M4MCM09HAZ03KEA', 29, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 158, 'Subscription payment 164', '2026-05-27 09:00:00'),
('01K2F2DKG04M4MCM09HAZ03KEA', 29, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 158, 'Subscription payment 164', '2026-05-27 09:00:00'),
('01K2F2DKG04M4MCM09HAZ03KEA', 29, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 158, 'Subscription payment 164', '2026-06-03 09:00:00'),
('01K2F2DKG04M4MCM09HAZ03KEA', 29, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 158, 'Subscription payment 164', '2026-06-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(165, '01K2F2DKG0X030VMWT1KEQ89CJ', 'LF-INV-2026000165', 29, 29, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Everline Marine', 'billing@example.com', '2026-04-27 09:00:00', '2026-05-11 09:00:00', '2026-04-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000165.pdf', '2026-04-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(165, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-27', '2026-05-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(159, '01K2F2DKG0J8RYEH836DV3PJ86', 'PAY-60159', 29, 165, 29, 29, 123, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0fx0aj92hwadrf5rv', 'idem-01K2F2DKG06MHZDPZ7WXR7ZGVJ', 'https://cdn.livfinder.com/receipts/PAY-60159.pdf', '2026-05-07 09:00:00', '2026-04-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0MC7CBX1VQWY97NWC', 29, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 159, 'Subscription payment 165', '2026-05-02 09:00:00'),
('01K2F2DKG0MC7CBX1VQWY97NWC', 29, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 159, 'Subscription payment 165', '2026-05-05 09:00:00'),
('01K2F2DKG0MC7CBX1VQWY97NWC', 29, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 159, 'Subscription payment 165', '2026-05-09 09:00:00'),
('01K2F2DKG0MC7CBX1VQWY97NWC', 29, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 159, 'Subscription payment 165', '2026-04-27 09:00:00'),
('01K2F2DKG0MC7CBX1VQWY97NWC', 29, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 159, 'Subscription payment 165', '2026-04-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(29, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-03 09:00:00'),
(29, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-10 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(30, '01K2F2DKG0P0Q7TV5V96K0B74V', 30, 127, 'card', 'stripe', 'pm_01k2f2dkg0jv4yt9h382aw4z9q', 'visa', '8055', 2, 2029, 'Foxhall Aviation', 1, 'active', '2024-03-08 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(30, '01K2F2DKG04905N5160G097B8G', 30, 4, 'active', 2499.0, 'USD', 9177.58, 'monthly', '2026-08-04 09:00:00', '2026-09-03 09:00:00', NULL, NULL, 1, 30, 'sub_01k2f2dkg00jhamgyw0ghtmbn7', '2024-09-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(166, '01K2F2DKG0J7Y1XZGBNPHEF5YB', 'LF-INV-2026000166', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-07-05 09:00:00', '2026-07-19 09:00:00', '2026-07-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000166.pdf', '2026-07-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(166, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-05', '2026-08-04', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(160, '01K2F2DKG0D4HBGY38FQMC7XEV', 'PAY-60160', 30, 166, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0h2n1384tch0k9ntm', 'idem-01K2F2DKG0KA2VDZMY5ZTZA2CA', 'https://cdn.livfinder.com/receipts/PAY-60160.pdf', '2026-07-05 09:00:00', '2026-07-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZPWT7YVYZ8KG89VZ', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 160, 'Subscription payment 166', '2026-07-10 09:00:00'),
('01K2F2DKG0ZPWT7YVYZ8KG89VZ', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 160, 'Subscription payment 166', '2026-07-08 09:00:00'),
('01K2F2DKG0ZPWT7YVYZ8KG89VZ', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 160, 'Subscription payment 166', '2026-07-11 09:00:00'),
('01K2F2DKG0ZPWT7YVYZ8KG89VZ', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 160, 'Subscription payment 166', '2026-07-08 09:00:00'),
('01K2F2DKG0ZPWT7YVYZ8KG89VZ', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 160, 'Subscription payment 166', '2026-07-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(167, '01K2F2DKG0Q0JCDF0130NTASFD', 'LF-INV-2026000167', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-06-05 09:00:00', '2026-06-19 09:00:00', '2026-06-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000167.pdf', '2026-06-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(167, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-05', '2026-07-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(161, '01K2F2DKG0J33S8M45RP0R86A1', 'PAY-60161', 30, 167, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0wwztxy5anydqmsz9', 'idem-01K2F2DKG0Y8P14D58HV84F23B', 'https://cdn.livfinder.com/receipts/PAY-60161.pdf', '2026-06-17 09:00:00', '2026-06-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0R2AB1JCM76YFKFQZ', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 161, 'Subscription payment 167', '2026-06-06 09:00:00'),
('01K2F2DKG0R2AB1JCM76YFKFQZ', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 161, 'Subscription payment 167', '2026-06-17 09:00:00'),
('01K2F2DKG0R2AB1JCM76YFKFQZ', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 161, 'Subscription payment 167', '2026-06-10 09:00:00'),
('01K2F2DKG0R2AB1JCM76YFKFQZ', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 161, 'Subscription payment 167', '2026-06-12 09:00:00'),
('01K2F2DKG0R2AB1JCM76YFKFQZ', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 161, 'Subscription payment 167', '2026-06-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(168, '01K2F2DKG0TMVG1K2N0CBJS4RH', 'LF-INV-2026000168', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-05-06 09:00:00', '2026-05-20 09:00:00', '2026-05-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000168.pdf', '2026-05-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(168, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-06', '2026-06-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(162, '01K2F2DKG0BTEKDTCS5Y7GM325', 'PAY-60162', 30, 168, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg068ths1nrxtnvc1zd', 'idem-01K2F2DKG0D509DFCKQFBYQ7A1', 'https://cdn.livfinder.com/receipts/PAY-60162.pdf', '2026-05-11 09:00:00', '2026-05-18 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG01RHHVKZ9K0P34431', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 162, 'Subscription payment 168', '2026-05-08 09:00:00'),
('01K2F2DKG01RHHVKZ9K0P34431', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 162, 'Subscription payment 168', '2026-05-17 09:00:00'),
('01K2F2DKG01RHHVKZ9K0P34431', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 162, 'Subscription payment 168', '2026-05-15 09:00:00'),
('01K2F2DKG01RHHVKZ9K0P34431', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 162, 'Subscription payment 168', '2026-05-17 09:00:00'),
('01K2F2DKG01RHHVKZ9K0P34431', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 162, 'Subscription payment 168', '2026-05-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(169, '01K2F2DKG05PWJQXZVYK23RBKR', 'LF-INV-2026000169', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-04-06 09:00:00', '2026-04-20 09:00:00', '2026-04-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000169.pdf', '2026-04-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(169, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-06', '2026-05-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(163, '01K2F2DKG0MP6C0PSN898RRB3D', 'PAY-60163', 30, 169, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg07r3tm8wsvtdqwzch', 'idem-01K2F2DKG0EB3D6XEJ6JRDTC8G', 'https://cdn.livfinder.com/receipts/PAY-60163.pdf', '2026-04-18 09:00:00', '2026-04-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZHNZ5NN9870YZZ72', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 163, 'Subscription payment 169', '2026-04-18 09:00:00'),
('01K2F2DKG0ZHNZ5NN9870YZZ72', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 163, 'Subscription payment 169', '2026-04-06 09:00:00'),
('01K2F2DKG0ZHNZ5NN9870YZZ72', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 163, 'Subscription payment 169', '2026-04-18 09:00:00'),
('01K2F2DKG0ZHNZ5NN9870YZZ72', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 163, 'Subscription payment 169', '2026-04-08 09:00:00'),
('01K2F2DKG0ZHNZ5NN9870YZZ72', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 163, 'Subscription payment 169', '2026-04-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(170, '01K2F2DKG05N6Q49XRZYX3K1VF', 'LF-INV-2026000170', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-03-07 09:00:00', '2026-03-21 09:00:00', '2026-03-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000170.pdf', '2026-03-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(170, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-07', '2026-04-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(164, '01K2F2DKG0Q4C71R0M2TR8S7DA', 'PAY-60164', 30, 170, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0cqck6eg4n1nvq2k9', 'idem-01K2F2DKG01ADMDWNRZD2N0EEW', 'https://cdn.livfinder.com/receipts/PAY-60164.pdf', '2026-03-15 09:00:00', '2026-03-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JWKJMER6FHD0N20N', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 164, 'Subscription payment 170', '2026-03-11 09:00:00'),
('01K2F2DKG0JWKJMER6FHD0N20N', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 164, 'Subscription payment 170', '2026-03-08 09:00:00'),
('01K2F2DKG0JWKJMER6FHD0N20N', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 164, 'Subscription payment 170', '2026-03-16 09:00:00'),
('01K2F2DKG0JWKJMER6FHD0N20N', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 164, 'Subscription payment 170', '2026-03-11 09:00:00'),
('01K2F2DKG0JWKJMER6FHD0N20N', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 164, 'Subscription payment 170', '2026-03-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(171, '01K2F2DKG0YDK0SB39GENK1N9J', 'LF-INV-2026000171', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-02-05 09:00:00', '2026-02-19 09:00:00', '2026-02-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000171.pdf', '2026-02-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(171, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-05', '2026-03-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(165, '01K2F2DKG0SM63TDK9D94JEDZ7', 'PAY-60165', 30, 171, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qmye54a0cfy52k6p', 'idem-01K2F2DKG0T2KMG39KYJ51TN0J', 'https://cdn.livfinder.com/receipts/PAY-60165.pdf', '2026-02-13 09:00:00', '2026-02-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG087JSKQH9M0QHVX2S', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 165, 'Subscription payment 171', '2026-02-06 09:00:00'),
('01K2F2DKG087JSKQH9M0QHVX2S', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 165, 'Subscription payment 171', '2026-02-09 09:00:00'),
('01K2F2DKG087JSKQH9M0QHVX2S', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 165, 'Subscription payment 171', '2026-02-15 09:00:00'),
('01K2F2DKG087JSKQH9M0QHVX2S', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 165, 'Subscription payment 171', '2026-02-10 09:00:00'),
('01K2F2DKG087JSKQH9M0QHVX2S', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 165, 'Subscription payment 171', '2026-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(172, '01K2F2DKG0B4CN93YABKT55HV9', 'LF-INV-2026000172', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2026-01-06 09:00:00', '2026-01-20 09:00:00', '2026-01-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000172.pdf', '2026-01-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(172, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-06', '2026-02-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(166, '01K2F2DKG078P5EPDQE7QDGTSZ', 'PAY-60166', 30, 172, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg082q8qh3jrk0sjz43', 'idem-01K2F2DKG0NR1NBBP6G9GWEZVF', 'https://cdn.livfinder.com/receipts/PAY-60166.pdf', '2026-01-07 09:00:00', '2026-01-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VY28T11MKESBPPGG', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 166, 'Subscription payment 172', '2026-01-08 09:00:00'),
('01K2F2DKG0VY28T11MKESBPPGG', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 166, 'Subscription payment 172', '2026-01-16 09:00:00'),
('01K2F2DKG0VY28T11MKESBPPGG', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 166, 'Subscription payment 172', '2026-01-16 09:00:00'),
('01K2F2DKG0VY28T11MKESBPPGG', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 166, 'Subscription payment 172', '2026-01-13 09:00:00'),
('01K2F2DKG0VY28T11MKESBPPGG', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 166, 'Subscription payment 172', '2026-01-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(173, '01K2F2DKG0SMMYANR0NQS73X25', 'LF-INV-2026000173', 30, 30, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Foxhall Aviation', 'billing@example.com', '2025-12-07 09:00:00', '2025-12-21 09:00:00', '2025-12-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000173.pdf', '2025-12-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(173, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-07', '2026-01-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(167, '01K2F2DKG0M43SEW8DCYTAH6CY', 'PAY-60167', 30, 173, 30, 30, 127, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06hh0zm0fqxgz6g10', 'idem-01K2F2DKG02CX6F0EMCTNGN2H7', 'https://cdn.livfinder.com/receipts/PAY-60167.pdf', '2025-12-15 09:00:00', '2025-12-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HV0VD6S7CN1P9KZW', 30, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 167, 'Subscription payment 173', '2025-12-16 09:00:00'),
('01K2F2DKG0HV0VD6S7CN1P9KZW', 30, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 167, 'Subscription payment 173', '2025-12-07 09:00:00'),
('01K2F2DKG0HV0VD6S7CN1P9KZW', 30, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 167, 'Subscription payment 173', '2025-12-08 09:00:00'),
('01K2F2DKG0HV0VD6S7CN1P9KZW', 30, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 167, 'Subscription payment 173', '2025-12-08 09:00:00'),
('01K2F2DKG0HV0VD6S7CN1P9KZW', 30, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 167, 'Subscription payment 173', '2025-12-08 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(30, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-06 09:00:00'),
(30, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-27 09:00:00'),
(30, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-03 09:00:00'),
(30, 'listing', 10, 7, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-20 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(31, '01K2F2DKG0EY72VXCDSQKRZGAG', 31, 131, 'card', 'stripe', 'pm_01k2f2dkg08hk5k32ba6s0p8br', 'mastercard', '7941', 12, 2029, 'Prime Timepieces', 1, 'active', '2024-11-09 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(31, '01K2F2DKG0ZMWW9CWWGXNNVMYK', 31, 6, 'active', 149000.0, 'CHF', 626053.3, 'yearly', '2026-01-24 09:00:00', '2027-01-24 09:00:00', NULL, NULL, 1, 31, 'sub_01k2f2dkg0360w00280q1csfm4', '2026-04-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(174, '01K2F2DKG0DJ88QF78SHTWQ4B9', 'LF-INV-2026000174', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2025-01-24 09:00:00', '2025-02-07 09:00:00', '2025-02-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000174.pdf', '2025-01-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(174, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-01-24', '2026-01-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(168, '01K2F2DKG08J9385GCRSA069J0', 'PAY-60168', 31, 174, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0yarjp5g5d22s2eae', 'idem-01K2F2DKG0CHHRB51AF2PCWMDF', 'https://cdn.livfinder.com/receipts/PAY-60168.pdf', '2025-02-02 09:00:00', '2025-01-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0EKHGA2NWMKQYQT3Z', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 168, 'Subscription payment 174', '2025-01-26 09:00:00'),
('01K2F2DKG0EKHGA2NWMKQYQT3Z', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 168, 'Subscription payment 174', '2025-01-24 09:00:00'),
('01K2F2DKG0EKHGA2NWMKQYQT3Z', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 168, 'Subscription payment 174', '2025-01-27 09:00:00'),
('01K2F2DKG0EKHGA2NWMKQYQT3Z', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 168, 'Subscription payment 174', '2025-01-31 09:00:00'),
('01K2F2DKG0EKHGA2NWMKQYQT3Z', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 168, 'Subscription payment 174', '2025-02-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(175, '01K2F2DKG0TDKDQ7HVD2SF19N7', 'LF-INV-2026000175', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2024-01-25 09:00:00', '2024-02-08 09:00:00', '2024-02-06 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000175.pdf', '2024-01-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(175, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-01-25', '2025-01-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(169, '01K2F2DKG09KSBZM7D2RP2VDGZ', 'PAY-60169', 31, 175, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kzv96x80yxf0v7a6', 'idem-01K2F2DKG08P2TMHM0JB5ZQAAM', 'https://cdn.livfinder.com/receipts/PAY-60169.pdf', '2024-01-30 09:00:00', '2024-01-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Z6K3W86EF6JBX7HJ', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 169, 'Subscription payment 175', '2024-01-25 09:00:00'),
('01K2F2DKG0Z6K3W86EF6JBX7HJ', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 169, 'Subscription payment 175', '2024-01-27 09:00:00'),
('01K2F2DKG0Z6K3W86EF6JBX7HJ', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 169, 'Subscription payment 175', '2024-02-06 09:00:00'),
('01K2F2DKG0Z6K3W86EF6JBX7HJ', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 169, 'Subscription payment 175', '2024-01-26 09:00:00'),
('01K2F2DKG0Z6K3W86EF6JBX7HJ', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 169, 'Subscription payment 175', '2024-01-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(176, '01K2F2DKG0F40EXNGB4MD2K78C', 'LF-INV-2026000176', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2023-01-25 09:00:00', '2023-02-08 09:00:00', '2023-02-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000176.pdf', '2023-01-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(176, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-01-25', '2024-01-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(170, '01K2F2DKG0567T2E626W68TDNK', 'PAY-60170', 31, 176, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mvx2przwtzf42rez', 'idem-01K2F2DKG0YNRT7FSXHNR097FD', 'https://cdn.livfinder.com/receipts/PAY-60170.pdf', '2023-02-04 09:00:00', '2023-01-29 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0PPD0GCYXH1XSZYM7', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 170, 'Subscription payment 176', '2023-02-01 09:00:00'),
('01K2F2DKG0PPD0GCYXH1XSZYM7', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 170, 'Subscription payment 176', '2023-01-26 09:00:00'),
('01K2F2DKG0PPD0GCYXH1XSZYM7', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 170, 'Subscription payment 176', '2023-01-31 09:00:00'),
('01K2F2DKG0PPD0GCYXH1XSZYM7', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 170, 'Subscription payment 176', '2023-01-26 09:00:00'),
('01K2F2DKG0PPD0GCYXH1XSZYM7', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 170, 'Subscription payment 176', '2023-02-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(177, '01K2F2DKG0P07DB1FFNDYD1QVH', 'LF-INV-2026000177', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2022-01-25 09:00:00', '2022-02-08 09:00:00', '2022-02-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000177.pdf', '2022-01-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(177, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-01-25', '2023-01-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(171, '01K2F2DKG08R7CGM3V3M4BVE0D', 'PAY-60171', 31, 177, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09hwf11rej3dxbh6c', 'idem-01K2F2DKG06SDS75Q43EBNMBAX', 'https://cdn.livfinder.com/receipts/PAY-60171.pdf', '2022-02-03 09:00:00', '2022-01-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CP4GHVEPEVKERF6Y', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 171, 'Subscription payment 177', '2022-01-28 09:00:00'),
('01K2F2DKG0CP4GHVEPEVKERF6Y', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 171, 'Subscription payment 177', '2022-01-30 09:00:00'),
('01K2F2DKG0CP4GHVEPEVKERF6Y', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 171, 'Subscription payment 177', '2022-02-06 09:00:00'),
('01K2F2DKG0CP4GHVEPEVKERF6Y', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 171, 'Subscription payment 177', '2022-01-31 09:00:00'),
('01K2F2DKG0CP4GHVEPEVKERF6Y', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 171, 'Subscription payment 177', '2022-02-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(178, '01K2F2DKG0HRF3MD85V2N353RQ', 'LF-INV-2026000178', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2021-01-25 09:00:00', '2021-02-08 09:00:00', '2021-02-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000178.pdf', '2021-01-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(178, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-01-25', '2022-01-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(172, '01K2F2DKG0S0YB6HWZWXXYT0D6', 'PAY-60172', 31, 178, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0w8ymd6nd2kav67m7', 'idem-01K2F2DKG0E4N4KZRYNM65N5WG', 'https://cdn.livfinder.com/receipts/PAY-60172.pdf', '2021-02-03 09:00:00', '2021-01-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG07YTSZ47D8999QQTG', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 172, 'Subscription payment 178', '2021-01-30 09:00:00'),
('01K2F2DKG07YTSZ47D8999QQTG', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 172, 'Subscription payment 178', '2021-02-04 09:00:00'),
('01K2F2DKG07YTSZ47D8999QQTG', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 172, 'Subscription payment 178', '2021-01-25 09:00:00'),
('01K2F2DKG07YTSZ47D8999QQTG', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 172, 'Subscription payment 178', '2021-01-28 09:00:00'),
('01K2F2DKG07YTSZ47D8999QQTG', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 172, 'Subscription payment 178', '2021-01-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(179, '01K2F2DKG0TTC15Q0S2CXQ3BXG', 'LF-INV-2026000179', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2020-01-26 09:00:00', '2020-02-09 09:00:00', '2020-01-27 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000179.pdf', '2020-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(179, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-01-26', '2021-01-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(173, '01K2F2DKG04NRXSDC9K3PQPB3D', 'PAY-60173', 31, 179, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tjcdeqx2fad52m2z', 'idem-01K2F2DKG0BP4P34GZF79X31MZ', 'https://cdn.livfinder.com/receipts/PAY-60173.pdf', '2020-01-30 09:00:00', '2020-01-31 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XR8V6WXGY3E7GXG7', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 173, 'Subscription payment 179', '2020-01-26 09:00:00'),
('01K2F2DKG0XR8V6WXGY3E7GXG7', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 173, 'Subscription payment 179', '2020-02-07 09:00:00'),
('01K2F2DKG0XR8V6WXGY3E7GXG7', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 173, 'Subscription payment 179', '2020-02-05 09:00:00'),
('01K2F2DKG0XR8V6WXGY3E7GXG7', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 173, 'Subscription payment 179', '2020-02-05 09:00:00'),
('01K2F2DKG0XR8V6WXGY3E7GXG7', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 173, 'Subscription payment 179', '2020-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(180, '01K2F2DKG014GCMCSX7AA0174C', 'LF-INV-2026000180', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2019-01-26 09:00:00', '2019-02-09 09:00:00', '2019-01-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000180.pdf', '2019-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(180, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2019-01-26', '2020-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(174, '01K2F2DKG0Q6CDZRF1BN7JEAPY', 'PAY-60174', 31, 180, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0vmcq4fssvwjzfm00', 'idem-01K2F2DKG02XR7571HPFV42Z2V', 'https://cdn.livfinder.com/receipts/PAY-60174.pdf', '2019-02-01 09:00:00', '2019-01-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CGS80T0GJMZ054PE', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 174, 'Subscription payment 180', '2019-01-28 09:00:00'),
('01K2F2DKG0CGS80T0GJMZ054PE', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 174, 'Subscription payment 180', '2019-01-26 09:00:00'),
('01K2F2DKG0CGS80T0GJMZ054PE', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 174, 'Subscription payment 180', '2019-02-02 09:00:00'),
('01K2F2DKG0CGS80T0GJMZ054PE', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 174, 'Subscription payment 180', '2019-01-27 09:00:00'),
('01K2F2DKG0CGS80T0GJMZ054PE', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 174, 'Subscription payment 180', '2019-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(181, '01K2F2DKG0AHAMQ849PS4V1J6K', 'LF-INV-2026000181', 31, 31, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Prime Timepieces', 'billing@example.com', '2018-01-26 09:00:00', '2018-02-09 09:00:00', '2018-02-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000181.pdf', '2018-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(181, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2018-01-26', '2019-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(175, '01K2F2DKG0V2GF6YX9Q7HMTS3E', 'PAY-60175', 31, 181, 31, 31, 131, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0td0e26cn9pcw3azq', 'idem-01K2F2DKG0QXTQTJPBNWP7ZWVZ', 'https://cdn.livfinder.com/receipts/PAY-60175.pdf', '2018-02-03 09:00:00', '2018-01-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0QVB84XW0RY3J4WKR', 31, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 175, 'Subscription payment 181', '2018-02-06 09:00:00'),
('01K2F2DKG0QVB84XW0RY3J4WKR', 31, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 175, 'Subscription payment 181', '2018-01-30 09:00:00'),
('01K2F2DKG0QVB84XW0RY3J4WKR', 31, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 175, 'Subscription payment 181', '2018-02-03 09:00:00'),
('01K2F2DKG0QVB84XW0RY3J4WKR', 31, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 175, 'Subscription payment 181', '2018-02-02 09:00:00'),
('01K2F2DKG0QVB84XW0RY3J4WKR', 31, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 175, 'Subscription payment 181', '2018-02-01 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(31, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-31 09:00:00'),
(31, 'listing', 50, 60, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-11 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(32, '01K2F2DKG0T5DHN5JEC92B29K4', 32, 135, 'card', 'stripe', 'pm_01k2f2dkg04rvsn1f5wf2ypj2n', 'amex', '3879', 1, 2028, 'Luxhabitat Development', 1, 'active', '2025-09-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(32, '01K2F2DKG0D8EDGGY85MTRV2JV', 32, 7, 'active', 89000.0, 'EUR', 354584.9, 'yearly', '2026-01-14 09:00:00', '2027-01-14 09:00:00', NULL, NULL, 1, 32, 'sub_01k2f2dkg07046jdcx36cnzrq4', '2025-09-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(182, '01K2F2DKG0WXEPZAN4MDGXYF9H', 'LF-INV-2026000182', 32, 32, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Luxhabitat Development', 'billing@example.com', '2025-01-14 09:00:00', '2025-01-28 09:00:00', '2025-01-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000182.pdf', '2025-01-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(182, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2025-01-14', '2026-01-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(176, '01K2F2DKG0WDF2039FH67YMSZE', 'PAY-60176', 32, 182, 32, 32, 135, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0y5yt4kqfk1ghxy89', 'idem-01K2F2DKG00QZJKT8BPMKR5FB1', 'https://cdn.livfinder.com/receipts/PAY-60176.pdf', '2025-01-21 09:00:00', '2025-01-15 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09G1NEVH3KP7XFM1H', 32, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 176, 'Subscription payment 182', '2025-01-17 09:00:00'),
('01K2F2DKG09G1NEVH3KP7XFM1H', 32, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 176, 'Subscription payment 182', '2025-01-23 09:00:00'),
('01K2F2DKG09G1NEVH3KP7XFM1H', 32, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 176, 'Subscription payment 182', '2025-01-20 09:00:00'),
('01K2F2DKG09G1NEVH3KP7XFM1H', 32, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 176, 'Subscription payment 182', '2025-01-21 09:00:00'),
('01K2F2DKG09G1NEVH3KP7XFM1H', 32, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 176, 'Subscription payment 182', '2025-01-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(183, '01K2F2DKG0409CZA08GAYGGYEY', 'LF-INV-2026000183', 32, 32, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Luxhabitat Development', 'billing@example.com', '2024-01-15 09:00:00', '2024-01-29 09:00:00', '2024-01-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000183.pdf', '2024-01-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(183, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2024-01-15', '2025-01-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(177, '01K2F2DKG084YXXCNDKWCBYRTR', 'PAY-60177', 32, 183, 32, 32, 135, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg04z0sb4xsb4dxn0ba', 'idem-01K2F2DKG006VG2B4YE7GTVGSA', 'https://cdn.livfinder.com/receipts/PAY-60177.pdf', '2024-01-23 09:00:00', '2024-01-18 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0FNFT6TNY8DN31N3S', 32, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 177, 'Subscription payment 183', '2024-01-27 09:00:00'),
('01K2F2DKG0FNFT6TNY8DN31N3S', 32, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 177, 'Subscription payment 183', '2024-01-22 09:00:00'),
('01K2F2DKG0FNFT6TNY8DN31N3S', 32, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 177, 'Subscription payment 183', '2024-01-18 09:00:00'),
('01K2F2DKG0FNFT6TNY8DN31N3S', 32, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 177, 'Subscription payment 183', '2024-01-19 09:00:00'),
('01K2F2DKG0FNFT6TNY8DN31N3S', 32, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 177, 'Subscription payment 183', '2024-01-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(184, '01K2F2DKG0E5GT6VDM3BRE5W4V', 'LF-INV-2026000184', 32, 32, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Luxhabitat Development', 'billing@example.com', '2023-01-15 09:00:00', '2023-01-29 09:00:00', '2023-01-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000184.pdf', '2023-01-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(184, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2023-01-15', '2024-01-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(178, '01K2F2DKG0Q88KA0WE3A9RV77R', 'PAY-60178', 32, 184, 32, 32, 135, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0wz61rvdkmhtnqrrs', 'idem-01K2F2DKG05EVMGVSAE6F371KX', 'https://cdn.livfinder.com/receipts/PAY-60178.pdf', '2023-01-24 09:00:00', '2023-01-23 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0DPJD3P9ANF6ZVDHF', 32, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 178, 'Subscription payment 184', '2023-01-16 09:00:00'),
('01K2F2DKG0DPJD3P9ANF6ZVDHF', 32, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 178, 'Subscription payment 184', '2023-01-17 09:00:00'),
('01K2F2DKG0DPJD3P9ANF6ZVDHF', 32, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 178, 'Subscription payment 184', '2023-01-18 09:00:00'),
('01K2F2DKG0DPJD3P9ANF6ZVDHF', 32, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 178, 'Subscription payment 184', '2023-01-19 09:00:00'),
('01K2F2DKG0DPJD3P9ANF6ZVDHF', 32, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 178, 'Subscription payment 184', '2023-01-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(185, '01K2F2DKG0TZANKYYV5JY4MTTA', 'LF-INV-2026000185', 32, 32, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'EUR', 3.9841, 372314.15, 5.0, 'VAT', 'Luxhabitat Development', 'billing@example.com', '2022-01-15 09:00:00', '2022-01-29 09:00:00', '2022-01-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000185.pdf', '2022-01-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(185, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2022-01-15', '2023-01-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(179, '01K2F2DKG0A9E6ZVCPE284C9SE', 'PAY-60179', 32, 185, 32, 32, 135, 93450.0, 'EUR', 3.9841, 372314.15, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tc58s6135h59twwp', 'idem-01K2F2DKG0GFT2RKEMKPCDNBB1', 'https://cdn.livfinder.com/receipts/PAY-60179.pdf', '2022-01-21 09:00:00', '2022-01-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CQSZFRD6AZ3HF5MJ', 32, 'cash', 'debit', 93450.0, 'EUR', 372314.15, 'payment', 179, 'Subscription payment 185', '2022-01-19 09:00:00'),
('01K2F2DKG0CQSZFRD6AZ3HF5MJ', 32, 'revenue.subscription', 'credit', 89000.0, 'EUR', 354584.9, 'payment', 179, 'Subscription payment 185', '2022-01-20 09:00:00'),
('01K2F2DKG0CQSZFRD6AZ3HF5MJ', 32, 'tax_payable', 'credit', 4450.0, 'EUR', 17729.25, 'payment', 179, 'Subscription payment 185', '2022-01-26 09:00:00'),
('01K2F2DKG0CQSZFRD6AZ3HF5MJ', 32, 'expense.processor_fees', 'debit', 2711.05, 'EUR', 10801.09, 'payment', 179, 'Subscription payment 185', '2022-01-20 09:00:00'),
('01K2F2DKG0CQSZFRD6AZ3HF5MJ', 32, 'cash', 'credit', 2711.05, 'EUR', 10801.09, 'payment', 179, 'Subscription payment 185', '2022-01-22 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(32, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-10 09:00:00'),
(32, 'listing', 10, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-04 09:00:00'),
(32, 'listing', -1, 19, 'consumption', 'listing', NULL, 'Listing published', '2026-07-27 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(33, '01K2F2DKG0F9XNEFGFNZSCT9E4', 33, 139, 'card', 'stripe', 'pm_01k2f2dkg0egphf8ge76t4tdfw', 'amex', '4064', 1, 2028, 'Driven Partners', 1, 'active', '2026-01-11 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(33, '01K2F2DKG0NZSWXH7R0R5ZK5SE', 33, 7, 'trialing', 89000.0, 'AED', 89000.0, 'yearly', '2025-10-29 09:00:00', '2026-10-29 09:00:00', '2025-11-12 09:00:00', NULL, 1, 33, 'sub_01k2f2dkg0b1a71x6gqzb40q56', '2024-08-29 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(186, '01K2F2DKG0H1187NM9V9H28SYV', 'LF-INV-2026000186', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2024-10-29 09:00:00', '2024-11-12 09:00:00', '2024-10-31 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000186.pdf', '2024-10-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(186, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2024-10-29', '2025-10-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(180, '01K2F2DKG0TEAG2CNPJF35THP5', 'PAY-60180', 33, 186, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rfzcq38av45neq5t', 'idem-01K2F2DKG05X0CR6H2H1MA0SYD', 'https://cdn.livfinder.com/receipts/PAY-60180.pdf', '2024-10-31 09:00:00', '2024-11-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG00C17W9DNRVC7SBQE', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 180, 'Subscription payment 186', '2024-11-06 09:00:00'),
('01K2F2DKG00C17W9DNRVC7SBQE', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 180, 'Subscription payment 186', '2024-11-02 09:00:00'),
('01K2F2DKG00C17W9DNRVC7SBQE', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 180, 'Subscription payment 186', '2024-11-08 09:00:00'),
('01K2F2DKG00C17W9DNRVC7SBQE', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 180, 'Subscription payment 186', '2024-11-10 09:00:00'),
('01K2F2DKG00C17W9DNRVC7SBQE', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 180, 'Subscription payment 186', '2024-11-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(187, '01K2F2DKG0239VY6RHAX0S39X4', 'LF-INV-2026000187', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2023-10-30 09:00:00', '2023-11-13 09:00:00', '2023-11-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000187.pdf', '2023-10-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(187, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2023-10-30', '2024-10-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(181, '01K2F2DKG0BRK555EQRGZNPDPH', 'PAY-60181', 33, 187, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0myygxgqvsmy9wa3m', 'idem-01K2F2DKG0M877101XHS40NK8X', 'https://cdn.livfinder.com/receipts/PAY-60181.pdf', '2023-11-03 09:00:00', '2023-11-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T2WEVBKMY3510F0N', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 181, 'Subscription payment 187', '2023-11-03 09:00:00'),
('01K2F2DKG0T2WEVBKMY3510F0N', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 181, 'Subscription payment 187', '2023-11-08 09:00:00'),
('01K2F2DKG0T2WEVBKMY3510F0N', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 181, 'Subscription payment 187', '2023-10-31 09:00:00'),
('01K2F2DKG0T2WEVBKMY3510F0N', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 181, 'Subscription payment 187', '2023-11-02 09:00:00'),
('01K2F2DKG0T2WEVBKMY3510F0N', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 181, 'Subscription payment 187', '2023-10-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(188, '01K2F2DKG0CPAPE2A45YNHR01A', 'LF-INV-2026000188', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2022-10-30 09:00:00', '2022-11-13 09:00:00', '2022-11-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000188.pdf', '2022-10-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(188, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2022-10-30', '2023-10-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(182, '01K2F2DKG0TKPA0C615TQT26M4', 'PAY-60182', 33, 188, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg01575n0t5dp5npcr9', 'idem-01K2F2DKG0TWZJSZQFNFRK2BQE', 'https://cdn.livfinder.com/receipts/PAY-60182.pdf', '2022-11-11 09:00:00', '2022-11-11 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08H0VXZXEHRXXF2DW', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 182, 'Subscription payment 188', '2022-10-30 09:00:00'),
('01K2F2DKG08H0VXZXEHRXXF2DW', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 182, 'Subscription payment 188', '2022-11-05 09:00:00'),
('01K2F2DKG08H0VXZXEHRXXF2DW', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 182, 'Subscription payment 188', '2022-10-31 09:00:00'),
('01K2F2DKG08H0VXZXEHRXXF2DW', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 182, 'Subscription payment 188', '2022-11-02 09:00:00'),
('01K2F2DKG08H0VXZXEHRXXF2DW', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 182, 'Subscription payment 188', '2022-10-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(189, '01K2F2DKG09QK5SK9PMKA97T0G', 'LF-INV-2026000189', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2021-10-30 09:00:00', '2021-11-13 09:00:00', '2021-11-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000189.pdf', '2021-10-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(189, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2021-10-30', '2022-10-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(183, '01K2F2DKG0SSB1RTMWNJFXCDED', 'PAY-60183', 33, 189, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg05vk8h5v1zjx5ynd9', 'idem-01K2F2DKG0AVA53766RHWTQK32', 'https://cdn.livfinder.com/receipts/PAY-60183.pdf', '2021-11-02 09:00:00', '2021-11-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04C7TZ2QFX47D8GGE', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 183, 'Subscription payment 189', '2021-11-10 09:00:00'),
('01K2F2DKG04C7TZ2QFX47D8GGE', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 183, 'Subscription payment 189', '2021-11-06 09:00:00'),
('01K2F2DKG04C7TZ2QFX47D8GGE', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 183, 'Subscription payment 189', '2021-11-06 09:00:00'),
('01K2F2DKG04C7TZ2QFX47D8GGE', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 183, 'Subscription payment 189', '2021-11-06 09:00:00'),
('01K2F2DKG04C7TZ2QFX47D8GGE', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 183, 'Subscription payment 189', '2021-11-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(190, '01K2F2DKG081202A7A48S4N9MR', 'LF-INV-2026000190', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2020-10-30 09:00:00', '2020-11-13 09:00:00', '2020-11-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000190.pdf', '2020-10-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(190, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2020-10-30', '2021-10-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(184, '01K2F2DKG0XW6M9R1YS0FZG1GZ', 'PAY-60184', 33, 190, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0jt4qdmkp118h40e5', 'idem-01K2F2DKG09QKWHG1XS9821EJX', 'https://cdn.livfinder.com/receipts/PAY-60184.pdf', '2020-11-05 09:00:00', '2020-11-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0SVDPA98DJQDRHC6P', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 184, 'Subscription payment 190', '2020-11-09 09:00:00'),
('01K2F2DKG0SVDPA98DJQDRHC6P', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 184, 'Subscription payment 190', '2020-11-10 09:00:00'),
('01K2F2DKG0SVDPA98DJQDRHC6P', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 184, 'Subscription payment 190', '2020-11-11 09:00:00'),
('01K2F2DKG0SVDPA98DJQDRHC6P', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 184, 'Subscription payment 190', '2020-11-11 09:00:00'),
('01K2F2DKG0SVDPA98DJQDRHC6P', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 184, 'Subscription payment 190', '2020-11-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(191, '01K2F2DKG0P0ZMGGA5VSBY4KE0', 'LF-INV-2026000191', 33, 33, 'paid', 89000.0, 0, 4450.0, 93450.0, 93450.0, 0.0, 'AED', 1.0, 93450.0, 5.0, 'VAT', 'Driven Partners', 'billing@example.com', '2019-10-31 09:00:00', '2019-11-14 09:00:00', '2019-11-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000191.pdf', '2019-10-31 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(191, 'Subscription — yearly plan', 'subscription', 'plan:7', 1, 89000.0, 5.0, 4450.0, 93450.0, '2019-10-31', '2020-10-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(185, '01K2F2DKG0SS2EWV02CT247JHR', 'PAY-60185', 33, 191, 33, 33, 139, 93450.0, 'AED', 1.0, 93450.0, 2711.05, 90738.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0s745dfzdhx7qjmmt', 'idem-01K2F2DKG0VKFB8Q9FXRPP1520', 'https://cdn.livfinder.com/receipts/PAY-60185.pdf', '2019-11-08 09:00:00', '2019-11-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG02WB7RX7CNPBFD36M', 33, 'cash', 'debit', 93450.0, 'AED', 93450.0, 'payment', 185, 'Subscription payment 191', '2019-11-09 09:00:00'),
('01K2F2DKG02WB7RX7CNPBFD36M', 33, 'revenue.subscription', 'credit', 89000.0, 'AED', 89000.0, 'payment', 185, 'Subscription payment 191', '2019-11-08 09:00:00'),
('01K2F2DKG02WB7RX7CNPBFD36M', 33, 'tax_payable', 'credit', 4450.0, 'AED', 4450.0, 'payment', 185, 'Subscription payment 191', '2019-11-05 09:00:00'),
('01K2F2DKG02WB7RX7CNPBFD36M', 33, 'expense.processor_fees', 'debit', 2711.05, 'AED', 2711.05, 'payment', 185, 'Subscription payment 191', '2019-11-10 09:00:00'),
('01K2F2DKG02WB7RX7CNPBFD36M', 33, 'cash', 'credit', 2711.05, 'AED', 2711.05, 'payment', 185, 'Subscription payment 191', '2019-11-04 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(33, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-10-25 09:00:00'),
(33, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-07-07 09:00:00'),
(33, 'listing', 50, 48, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-03 09:00:00'),
(33, 'listing', -2, 46, 'consumption', 'listing', NULL, 'Listing published', '2025-11-18 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(34, '01K2F2DKG0MX0HVG89PJKB504V', 34, 143, 'card', 'stripe', 'pm_01k2f2dkg0h18pz52te4f2tdby', 'amex', '9849', 2, 2028, 'Sotheby''s International Properties', 1, 'active', '2025-08-04 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(34, '01K2F2DKG0MABR7D3AACKF8S01', 34, 6, 'active', 149000.0, 'EUR', 593630.9, 'yearly', '2026-03-06 09:00:00', '2027-03-06 09:00:00', NULL, NULL, 1, 34, 'sub_01k2f2dkg0xr6e6e02zrbbja26', '2023-11-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(192, '01K2F2DKG003Z566P9P1E5DEED', 'LF-INV-2026000192', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2025-03-06 09:00:00', '2025-03-20 09:00:00', '2025-03-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000192.pdf', '2025-03-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(192, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-03-06', '2026-03-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(186, '01K2F2DKG094FSCK8MF9FDVSTA', 'PAY-60186', 34, 192, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xg91qv32amhva0xt', 'idem-01K2F2DKG03J0A85M55TKHV35P', 'https://cdn.livfinder.com/receipts/PAY-60186.pdf', '2025-03-08 09:00:00', '2025-03-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08FNAS87KFPC44TZB', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 186, 'Subscription payment 192', '2025-03-13 09:00:00'),
('01K2F2DKG08FNAS87KFPC44TZB', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 186, 'Subscription payment 192', '2025-03-13 09:00:00'),
('01K2F2DKG08FNAS87KFPC44TZB', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 186, 'Subscription payment 192', '2025-03-09 09:00:00'),
('01K2F2DKG08FNAS87KFPC44TZB', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 186, 'Subscription payment 192', '2025-03-15 09:00:00'),
('01K2F2DKG08FNAS87KFPC44TZB', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 186, 'Subscription payment 192', '2025-03-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(193, '01K2F2DKG050YQFCW1PD65ZXGR', 'LF-INV-2026000193', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2024-03-06 09:00:00', '2024-03-20 09:00:00', '2024-03-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000193.pdf', '2024-03-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(193, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-03-06', '2025-03-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(187, '01K2F2DKG0C1QHSYNC3NQE40E1', 'PAY-60187', 34, 193, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tf6a8k9hb86nhaas', 'idem-01K2F2DKG0PF1ERBCDJQ9TABMY', 'https://cdn.livfinder.com/receipts/PAY-60187.pdf', '2024-03-09 09:00:00', '2024-03-11 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CBBZV2Q03M5ET8WY', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 187, 'Subscription payment 193', '2024-03-18 09:00:00'),
('01K2F2DKG0CBBZV2Q03M5ET8WY', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 187, 'Subscription payment 193', '2024-03-12 09:00:00'),
('01K2F2DKG0CBBZV2Q03M5ET8WY', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 187, 'Subscription payment 193', '2024-03-08 09:00:00'),
('01K2F2DKG0CBBZV2Q03M5ET8WY', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 187, 'Subscription payment 193', '2024-03-13 09:00:00'),
('01K2F2DKG0CBBZV2Q03M5ET8WY', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 187, 'Subscription payment 193', '2024-03-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(194, '01K2F2DKG0VF6J9G3XJS0P6QBH', 'LF-INV-2026000194', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2023-03-07 09:00:00', '2023-03-21 09:00:00', '2023-03-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000194.pdf', '2023-03-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(194, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-03-07', '2024-03-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(188, '01K2F2DKG0Z1MS8F6PJ6ABFPWA', 'PAY-60188', 34, 194, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0j76vj2as3edy8m1v', 'idem-01K2F2DKG0VNWZ1HFMPQ8201VV', 'https://cdn.livfinder.com/receipts/PAY-60188.pdf', '2023-03-16 09:00:00', '2023-03-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TCGZPE751JZ17BA3', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 188, 'Subscription payment 194', '2023-03-10 09:00:00'),
('01K2F2DKG0TCGZPE751JZ17BA3', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 188, 'Subscription payment 194', '2023-03-14 09:00:00'),
('01K2F2DKG0TCGZPE751JZ17BA3', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 188, 'Subscription payment 194', '2023-03-08 09:00:00'),
('01K2F2DKG0TCGZPE751JZ17BA3', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 188, 'Subscription payment 194', '2023-03-07 09:00:00'),
('01K2F2DKG0TCGZPE751JZ17BA3', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 188, 'Subscription payment 194', '2023-03-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(195, '01K2F2DKG0HRXSJH442H2FJ29H', 'LF-INV-2026000195', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2022-03-07 09:00:00', '2022-03-21 09:00:00', '2022-03-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000195.pdf', '2022-03-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(195, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-03-07', '2023-03-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(189, '01K2F2DKG0RSX08E487EF1JKHE', 'PAY-60189', 34, 195, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06hz20gmdp7bwdd9c', 'idem-01K2F2DKG0923TN8P0B0VVZZT4', 'https://cdn.livfinder.com/receipts/PAY-60189.pdf', '2022-03-18 09:00:00', '2022-03-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG096T81149AASZBE5S', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 189, 'Subscription payment 195', '2022-03-11 09:00:00'),
('01K2F2DKG096T81149AASZBE5S', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 189, 'Subscription payment 195', '2022-03-09 09:00:00'),
('01K2F2DKG096T81149AASZBE5S', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 189, 'Subscription payment 195', '2022-03-19 09:00:00'),
('01K2F2DKG096T81149AASZBE5S', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 189, 'Subscription payment 195', '2022-03-15 09:00:00'),
('01K2F2DKG096T81149AASZBE5S', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 189, 'Subscription payment 195', '2022-03-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(196, '01K2F2DKG0RJSEB5HT2807W1R4', 'LF-INV-2026000196', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2021-03-07 09:00:00', '2021-03-21 09:00:00', '2021-03-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000196.pdf', '2021-03-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(196, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-03-07', '2022-03-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(190, '01K2F2DKG0T5FY10WTH23XWTH0', 'PAY-60190', 34, 196, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02afaez2by4g93mq5', 'idem-01K2F2DKG00A3WBZPPWW2HX1GE', 'https://cdn.livfinder.com/receipts/PAY-60190.pdf', '2021-03-08 09:00:00', '2021-03-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RZ4QC2QTDA7RBGWE', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 190, 'Subscription payment 196', '2021-03-17 09:00:00'),
('01K2F2DKG0RZ4QC2QTDA7RBGWE', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 190, 'Subscription payment 196', '2021-03-11 09:00:00'),
('01K2F2DKG0RZ4QC2QTDA7RBGWE', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 190, 'Subscription payment 196', '2021-03-18 09:00:00'),
('01K2F2DKG0RZ4QC2QTDA7RBGWE', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 190, 'Subscription payment 196', '2021-03-16 09:00:00'),
('01K2F2DKG0RZ4QC2QTDA7RBGWE', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 190, 'Subscription payment 196', '2021-03-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(197, '01K2F2DKG03YWHM2W28Y0NJWJB', 'LF-INV-2026000197', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2020-03-07 09:00:00', '2020-03-21 09:00:00', '2020-03-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000197.pdf', '2020-03-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(197, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-03-07', '2021-03-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(191, '01K2F2DKG02EQHRB7D8NQR5N9W', 'PAY-60191', 34, 197, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0f0sn4p2y563gbx14', 'idem-01K2F2DKG0AZETNCQ8Q874BNTV', 'https://cdn.livfinder.com/receipts/PAY-60191.pdf', '2020-03-19 09:00:00', '2020-03-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0EJAQ8VHCGP44M2Y1', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 191, 'Subscription payment 197', '2020-03-19 09:00:00'),
('01K2F2DKG0EJAQ8VHCGP44M2Y1', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 191, 'Subscription payment 197', '2020-03-13 09:00:00'),
('01K2F2DKG0EJAQ8VHCGP44M2Y1', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 191, 'Subscription payment 197', '2020-03-14 09:00:00'),
('01K2F2DKG0EJAQ8VHCGP44M2Y1', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 191, 'Subscription payment 197', '2020-03-18 09:00:00'),
('01K2F2DKG0EJAQ8VHCGP44M2Y1', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 191, 'Subscription payment 197', '2020-03-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(198, '01K2F2DKG0AC8EN4GXEFKJFFBS', 'LF-INV-2026000198', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2019-03-08 09:00:00', '2019-03-22 09:00:00', '2019-03-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000198.pdf', '2019-03-08 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(198, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2019-03-08', '2020-03-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(192, '01K2F2DKG0N3DJYMDWQG760V22', 'PAY-60192', 34, 198, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0vqdsx11sq2hg9r2w', 'idem-01K2F2DKG0B0405YADKHJDF3ZV', 'https://cdn.livfinder.com/receipts/PAY-60192.pdf', '2019-03-20 09:00:00', '2019-03-18 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0CNEY3F46RWC7R2JS', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 192, 'Subscription payment 198', '2019-03-10 09:00:00'),
('01K2F2DKG0CNEY3F46RWC7R2JS', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 192, 'Subscription payment 198', '2019-03-16 09:00:00'),
('01K2F2DKG0CNEY3F46RWC7R2JS', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 192, 'Subscription payment 198', '2019-03-16 09:00:00'),
('01K2F2DKG0CNEY3F46RWC7R2JS', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 192, 'Subscription payment 198', '2019-03-17 09:00:00'),
('01K2F2DKG0CNEY3F46RWC7R2JS', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 192, 'Subscription payment 198', '2019-03-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(199, '01K2F2DKG0VAKGK9C1XBNZVS1F', 'LF-INV-2026000199', 34, 34, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Sotheby''s International Properties', 'billing@example.com', '2018-03-08 09:00:00', '2018-03-22 09:00:00', '2018-03-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000199.pdf', '2018-03-08 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(199, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2018-03-08', '2019-03-08', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(193, '01K2F2DKG0NKTYHASTT01J9MVQ', 'PAY-60193', 34, 199, 34, 34, 143, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0j2d4zxk82eaztdzq', 'idem-01K2F2DKG0ESZ56811YVXTM6B0', 'https://cdn.livfinder.com/receipts/PAY-60193.pdf', '2018-03-12 09:00:00', '2018-03-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG01E2P83FDMH9HC3H5', 34, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 193, 'Subscription payment 199', '2018-03-14 09:00:00'),
('01K2F2DKG01E2P83FDMH9HC3H5', 34, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 193, 'Subscription payment 199', '2018-03-11 09:00:00'),
('01K2F2DKG01E2P83FDMH9HC3H5', 34, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 193, 'Subscription payment 199', '2018-03-16 09:00:00'),
('01K2F2DKG01E2P83FDMH9HC3H5', 34, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 193, 'Subscription payment 199', '2018-03-20 09:00:00'),
('01K2F2DKG01E2P83FDMH9HC3H5', 34, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 193, 'Subscription payment 199', '2018-03-11 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(34, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-08 09:00:00'),
(34, 'listing', 10, 9, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-08 09:00:00'),
(34, 'listing', 20, 29, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-02 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(35, '01K2F2DKG09DR55AF8BFHYPDJP', 35, 147, 'card', 'stripe', 'pm_01k2f2dkg029eyjf6gskpdw8fw', 'mastercard', '6176', 12, 2029, 'Christie''s International Real Estate', 1, 'active', '2024-12-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(35, '01K2F2DKG0R87PJ4MT0CAFAFEJ', 35, 4, 'active', 2499.0, 'EUR', 9956.27, 'monthly', '2026-07-25 09:00:00', '2026-08-24 09:00:00', NULL, NULL, 1, 35, 'sub_01k2f2dkg0q1j8vb3nva2pkb08', '2026-06-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(200, '01K2F2DKG0YW8B9A61SM07EY63', 'LF-INV-2026000200', 35, 35, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Real Estate', 'billing@example.com', '2026-06-25 09:00:00', '2026-07-09 09:00:00', '2026-07-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000200.pdf', '2026-06-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(200, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-25', '2026-07-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(194, '01K2F2DKG0JNJ29NG7WDJBNVD6', 'PAY-60194', 35, 200, 35, 35, 147, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg033jqbary7tbyv7vh', 'idem-01K2F2DKG0T4KGHQ41D86BJ27Y', 'https://cdn.livfinder.com/receipts/PAY-60194.pdf', '2026-07-01 09:00:00', '2026-07-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09653R0753HNAD0Z3', 35, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 194, 'Subscription payment 200', '2026-07-02 09:00:00'),
('01K2F2DKG09653R0753HNAD0Z3', 35, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 194, 'Subscription payment 200', '2026-07-03 09:00:00'),
('01K2F2DKG09653R0753HNAD0Z3', 35, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 194, 'Subscription payment 200', '2026-07-07 09:00:00'),
('01K2F2DKG09653R0753HNAD0Z3', 35, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 194, 'Subscription payment 200', '2026-06-29 09:00:00'),
('01K2F2DKG09653R0753HNAD0Z3', 35, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 194, 'Subscription payment 200', '2026-06-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(201, '01K2F2DKG0JHVMZB31NQBFGZFW', 'LF-INV-2026000201', 35, 35, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Real Estate', 'billing@example.com', '2026-05-26 09:00:00', '2026-06-09 09:00:00', '2026-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000201.pdf', '2026-05-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(201, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-26', '2026-06-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(195, '01K2F2DKG0FVW2AEHW3FCCAVE4', 'PAY-60195', 35, 201, 35, 35, 147, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0r0whex2pfs4hfy8x', 'idem-01K2F2DKG0A9V1EY66GRA2VK0R', 'https://cdn.livfinder.com/receipts/PAY-60195.pdf', '2026-05-27 09:00:00', '2026-06-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0KMGMA5PJ2GZYVM0P', 35, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 195, 'Subscription payment 201', '2026-06-05 09:00:00'),
('01K2F2DKG0KMGMA5PJ2GZYVM0P', 35, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 195, 'Subscription payment 201', '2026-05-29 09:00:00'),
('01K2F2DKG0KMGMA5PJ2GZYVM0P', 35, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 195, 'Subscription payment 201', '2026-05-31 09:00:00'),
('01K2F2DKG0KMGMA5PJ2GZYVM0P', 35, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 195, 'Subscription payment 201', '2026-06-06 09:00:00'),
('01K2F2DKG0KMGMA5PJ2GZYVM0P', 35, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 195, 'Subscription payment 201', '2026-06-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(202, '01K2F2DKG0AD92Y9P5C27DQNFT', 'LF-INV-2026000202', 35, 35, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Real Estate', 'billing@example.com', '2026-04-26 09:00:00', '2026-05-10 09:00:00', '2026-05-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000202.pdf', '2026-04-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(202, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-26', '2026-05-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(196, '01K2F2DKG0VR4VRR3YQ87GHASW', 'PAY-60196', 35, 202, 35, 35, 147, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qpb4kp6q2b7s8f4w', 'idem-01K2F2DKG0BCRBM18ZVP2R7XGH', 'https://cdn.livfinder.com/receipts/PAY-60196.pdf', '2026-05-08 09:00:00', '2026-05-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VANSD10G5AK87SEV', 35, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 196, 'Subscription payment 202', '2026-05-05 09:00:00'),
('01K2F2DKG0VANSD10G5AK87SEV', 35, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 196, 'Subscription payment 202', '2026-05-05 09:00:00'),
('01K2F2DKG0VANSD10G5AK87SEV', 35, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 196, 'Subscription payment 202', '2026-05-02 09:00:00'),
('01K2F2DKG0VANSD10G5AK87SEV', 35, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 196, 'Subscription payment 202', '2026-05-06 09:00:00'),
('01K2F2DKG0VANSD10G5AK87SEV', 35, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 196, 'Subscription payment 202', '2026-05-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(203, '01K2F2DKG0JECEB0QNBWTCZYJG', 'LF-INV-2026000203', 35, 35, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Real Estate', 'billing@example.com', '2026-03-27 09:00:00', '2026-04-10 09:00:00', '2026-03-31 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000203.pdf', '2026-03-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(203, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-27', '2026-04-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(197, '01K2F2DKG0KF6TAC4Y5CET2Q5F', 'PAY-60197', 35, 203, 35, 35, 147, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg04bzt79k3y504vzve', 'idem-01K2F2DKG02JB60756CBV0KH35', 'https://cdn.livfinder.com/receipts/PAY-60197.pdf', '2026-03-29 09:00:00', '2026-03-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NSJNK1QJH4MN0EAP', 35, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 197, 'Subscription payment 203', '2026-04-03 09:00:00'),
('01K2F2DKG0NSJNK1QJH4MN0EAP', 35, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 197, 'Subscription payment 203', '2026-04-04 09:00:00'),
('01K2F2DKG0NSJNK1QJH4MN0EAP', 35, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 197, 'Subscription payment 203', '2026-03-31 09:00:00'),
('01K2F2DKG0NSJNK1QJH4MN0EAP', 35, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 197, 'Subscription payment 203', '2026-04-08 09:00:00'),
('01K2F2DKG0NSJNK1QJH4MN0EAP', 35, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 197, 'Subscription payment 203', '2026-03-29 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(204, '01K2F2DKG0ZW8AA56PCH6JXQ98', 'LF-INV-2026000204', 35, 35, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Christie''s International Real Estate', 'billing@example.com', '2026-02-25 09:00:00', '2026-03-11 09:00:00', '2026-03-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000204.pdf', '2026-02-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(204, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-25', '2026-03-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(198, '01K2F2DKG0H7YVM9QBT3KQM2RZ', 'PAY-60198', 35, 204, 35, 35, 147, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0x28v0k5x3bs0j16d', 'idem-01K2F2DKG0JHKZACS2FRSS1W69', 'https://cdn.livfinder.com/receipts/PAY-60198.pdf', '2026-03-05 09:00:00', '2026-03-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0D21CED4XGXC7XYW8', 35, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 198, 'Subscription payment 204', '2026-03-03 09:00:00'),
('01K2F2DKG0D21CED4XGXC7XYW8', 35, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 198, 'Subscription payment 204', '2026-02-27 09:00:00'),
('01K2F2DKG0D21CED4XGXC7XYW8', 35, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 198, 'Subscription payment 204', '2026-02-26 09:00:00'),
('01K2F2DKG0D21CED4XGXC7XYW8', 35, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 198, 'Subscription payment 204', '2026-03-08 09:00:00'),
('01K2F2DKG0D21CED4XGXC7XYW8', 35, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 198, 'Subscription payment 204', '2026-03-04 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(35, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-03 09:00:00'),
(35, 'listing', 10, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-22 09:00:00'),
(35, 'listing', -2, 18, 'consumption', 'listing', NULL, 'Listing published', '2026-04-08 09:00:00'),
(35, 'listing', 50, 68, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-04 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(36, '01K2F2DKG01VGPQ9Q2ZDQQ4BEM', 36, 151, 'card', 'stripe', 'pm_01k2f2dkg0pk2bqh7syeta6ak5', 'amex', '7849', 2, 2028, 'Knight Estates', 1, 'active', '2026-06-07 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(36, '01K2F2DKG0Z69ZZQ7JZZZX6CZ1', 36, 4, 'active', 2499.0, 'EUR', 9956.27, 'monthly', '2026-08-14 09:00:00', '2026-09-13 09:00:00', NULL, NULL, 1, 36, 'sub_01k2f2dkg0zymv4a700t1y7epq', '2024-02-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(205, '01K2F2DKG06C8Y5GGVG0AFBDBJ', 'LF-INV-2026000205', 36, 36, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Estates', 'billing@example.com', '2026-07-15 09:00:00', '2026-07-29 09:00:00', '2026-07-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000205.pdf', '2026-07-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(205, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-15', '2026-08-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(199, '01K2F2DKG0EQF56GBAS0GXCKJK', 'PAY-60199', 36, 205, 36, 36, 151, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ed05pvq7654y9vyy', 'idem-01K2F2DKG0HJ91KBN4W8GJAD8S', 'https://cdn.livfinder.com/receipts/PAY-60199.pdf', '2026-07-15 09:00:00', '2026-07-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0R477RP4HMRJD69XC', 36, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 199, 'Subscription payment 205', '2026-07-21 09:00:00'),
('01K2F2DKG0R477RP4HMRJD69XC', 36, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 199, 'Subscription payment 205', '2026-07-24 09:00:00'),
('01K2F2DKG0R477RP4HMRJD69XC', 36, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 199, 'Subscription payment 205', '2026-07-20 09:00:00'),
('01K2F2DKG0R477RP4HMRJD69XC', 36, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 199, 'Subscription payment 205', '2026-07-27 09:00:00'),
('01K2F2DKG0R477RP4HMRJD69XC', 36, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 199, 'Subscription payment 205', '2026-07-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(206, '01K2F2DKG0VBAA05Z3DD53RCMD', 'LF-INV-2026000206', 36, 36, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Estates', 'billing@example.com', '2026-06-15 09:00:00', '2026-06-29 09:00:00', '2026-06-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000206.pdf', '2026-06-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(206, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-15', '2026-07-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(200, '01K2F2DKG0Y11JPZHHAS5J9CCB', 'PAY-60200', 36, 206, 36, 36, 151, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ff2wh1tqcx26ewsy', 'idem-01K2F2DKG0JMTMFV9WZQSTXFYZ', 'https://cdn.livfinder.com/receipts/PAY-60200.pdf', '2026-06-25 09:00:00', '2026-06-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VH1MF59D3GS9ZDF0', 36, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 200, 'Subscription payment 206', '2026-06-21 09:00:00'),
('01K2F2DKG0VH1MF59D3GS9ZDF0', 36, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 200, 'Subscription payment 206', '2026-06-15 09:00:00'),
('01K2F2DKG0VH1MF59D3GS9ZDF0', 36, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 200, 'Subscription payment 206', '2026-06-19 09:00:00'),
('01K2F2DKG0VH1MF59D3GS9ZDF0', 36, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 200, 'Subscription payment 206', '2026-06-20 09:00:00'),
('01K2F2DKG0VH1MF59D3GS9ZDF0', 36, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 200, 'Subscription payment 206', '2026-06-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(207, '01K2F2DKG0T2XZQMBRRHQJMPN0', 'LF-INV-2026000207', 36, 36, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'EUR', 3.9841, 10454.08, 5.0, 'VAT', 'Knight Estates', 'billing@example.com', '2026-05-16 09:00:00', '2026-05-30 09:00:00', '2026-05-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000207.pdf', '2026-05-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(207, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-16', '2026-06-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(201, '01K2F2DKG042Y9ZZG22WN6WX77', 'PAY-60201', 36, 207, 36, 36, 151, 2623.95, 'EUR', 3.9841, 10454.08, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pf8swprb047vawv7', 'idem-01K2F2DKG0C72432NV8NQYG9G1', 'https://cdn.livfinder.com/receipts/PAY-60201.pdf', '2026-05-27 09:00:00', '2026-05-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0G3ZNH5CT5R94NV0E', 36, 'cash', 'debit', 2623.95, 'EUR', 10454.08, 'payment', 201, 'Subscription payment 207', '2026-05-25 09:00:00'),
('01K2F2DKG0G3ZNH5CT5R94NV0E', 36, 'revenue.subscription', 'credit', 2499.0, 'EUR', 9956.27, 'payment', 201, 'Subscription payment 207', '2026-05-16 09:00:00'),
('01K2F2DKG0G3ZNH5CT5R94NV0E', 36, 'tax_payable', 'credit', 124.95, 'EUR', 497.81, 'payment', 201, 'Subscription payment 207', '2026-05-23 09:00:00'),
('01K2F2DKG0G3ZNH5CT5R94NV0E', 36, 'expense.processor_fees', 'debit', 77.09, 'EUR', 307.13, 'payment', 201, 'Subscription payment 207', '2026-05-16 09:00:00'),
('01K2F2DKG0G3ZNH5CT5R94NV0E', 36, 'cash', 'credit', 77.09, 'EUR', 307.13, 'payment', 201, 'Subscription payment 207', '2026-05-27 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(36, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-06 09:00:00'),
(36, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-08-03 09:00:00'),
(36, 'listing', 50, 46, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-11 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(37, '01K2F2DKG0JRTP2SW81YGEP404', 37, 155, 'card', 'stripe', 'pm_01k2f2dkg0eadt1w69ep5npc2k', 'visa', '8067', 1, 2031, 'Halcyon Motors', 1, 'active', '2026-05-16 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(37, '01K2F2DKG0CT6ENJFK15QRW91R', 37, 6, 'trialing', 149000.0, 'CHF', 626053.3, 'yearly', '2025-12-08 09:00:00', '2026-12-08 09:00:00', '2025-12-22 09:00:00', NULL, 1, 37, 'sub_01k2f2dkg0vs8e2tdgq57hr2r1', '2025-04-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(208, '01K2F2DKG0PW4B3D8673PQVS4S', 'LF-INV-2026000208', 37, 37, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Halcyon Motors', 'billing@example.com', '2024-12-08 09:00:00', '2024-12-22 09:00:00', '2024-12-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000208.pdf', '2024-12-08 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(208, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-12-08', '2025-12-08', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(202, '01K2F2DKG0CDA8TWR2QC4BNPH3', 'PAY-60202', 37, 208, 37, 37, 155, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg013r1exxfa56f2p9b', 'idem-01K2F2DKG0FYHY0832GNZ55WCX', 'https://cdn.livfinder.com/receipts/PAY-60202.pdf', '2024-12-08 09:00:00', '2024-12-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TKXHM793EPNH5F7W', 37, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 202, 'Subscription payment 208', '2024-12-17 09:00:00'),
('01K2F2DKG0TKXHM793EPNH5F7W', 37, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 202, 'Subscription payment 208', '2024-12-20 09:00:00'),
('01K2F2DKG0TKXHM793EPNH5F7W', 37, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 202, 'Subscription payment 208', '2024-12-20 09:00:00'),
('01K2F2DKG0TKXHM793EPNH5F7W', 37, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 202, 'Subscription payment 208', '2024-12-16 09:00:00'),
('01K2F2DKG0TKXHM793EPNH5F7W', 37, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 202, 'Subscription payment 208', '2024-12-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(209, '01K2F2DKG06KMM22KRWY4REC3T', 'LF-INV-2026000209', 37, 37, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Halcyon Motors', 'billing@example.com', '2023-12-09 09:00:00', '2023-12-23 09:00:00', '2023-12-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000209.pdf', '2023-12-09 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(209, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-12-09', '2024-12-08', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(203, '01K2F2DKG052ATN4CY0YYJ5ZZQ', 'PAY-60203', 37, 209, 37, 37, 155, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kf3jnsn66wn3d00h', 'idem-01K2F2DKG02ZRX9HBFF7NBANMY', 'https://cdn.livfinder.com/receipts/PAY-60203.pdf', '2023-12-15 09:00:00', '2023-12-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0DRC4WH60MJ2K713W', 37, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 203, 'Subscription payment 209', '2023-12-17 09:00:00'),
('01K2F2DKG0DRC4WH60MJ2K713W', 37, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 203, 'Subscription payment 209', '2023-12-17 09:00:00'),
('01K2F2DKG0DRC4WH60MJ2K713W', 37, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 203, 'Subscription payment 209', '2023-12-16 09:00:00'),
('01K2F2DKG0DRC4WH60MJ2K713W', 37, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 203, 'Subscription payment 209', '2023-12-20 09:00:00'),
('01K2F2DKG0DRC4WH60MJ2K713W', 37, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 203, 'Subscription payment 209', '2023-12-12 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(210, '01K2F2DKG0V5N1W321075X9RQ3', 'LF-INV-2026000210', 37, 37, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Halcyon Motors', 'billing@example.com', '2022-12-09 09:00:00', '2022-12-23 09:00:00', '2022-12-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000210.pdf', '2022-12-09 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(210, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-12-09', '2023-12-09', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(204, '01K2F2DKG0K6Y51QBPV0W9D68N', 'PAY-60204', 37, 210, 37, 37, 155, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06x5brg3caphawtdp', 'idem-01K2F2DKG0SB0PD98JGV88HR3B', 'https://cdn.livfinder.com/receipts/PAY-60204.pdf', '2022-12-20 09:00:00', '2022-12-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NYKDXYY0CKD1TSEB', 37, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 204, 'Subscription payment 210', '2022-12-10 09:00:00'),
('01K2F2DKG0NYKDXYY0CKD1TSEB', 37, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 204, 'Subscription payment 210', '2022-12-16 09:00:00'),
('01K2F2DKG0NYKDXYY0CKD1TSEB', 37, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 204, 'Subscription payment 210', '2022-12-13 09:00:00'),
('01K2F2DKG0NYKDXYY0CKD1TSEB', 37, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 204, 'Subscription payment 210', '2022-12-17 09:00:00'),
('01K2F2DKG0NYKDXYY0CKD1TSEB', 37, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 204, 'Subscription payment 210', '2022-12-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(211, '01K2F2DKG0QSY5NR71SCF3VJPD', 'LF-INV-2026000211', 37, 37, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Halcyon Motors', 'billing@example.com', '2021-12-09 09:00:00', '2021-12-23 09:00:00', '2021-12-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000211.pdf', '2021-12-09 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(211, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2021-12-09', '2022-12-09', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(205, '01K2F2DKG0C9RGZ7260QKX67EG', 'PAY-60205', 37, 211, 37, 37, 155, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0g6ttq9w3ect7bef6', 'idem-01K2F2DKG0S1TWMMKCW8V9J0BS', 'https://cdn.livfinder.com/receipts/PAY-60205.pdf', '2021-12-14 09:00:00', '2021-12-15 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WMW7CJ4AQDTE01M1', 37, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 205, 'Subscription payment 211', '2021-12-11 09:00:00'),
('01K2F2DKG0WMW7CJ4AQDTE01M1', 37, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 205, 'Subscription payment 211', '2021-12-19 09:00:00'),
('01K2F2DKG0WMW7CJ4AQDTE01M1', 37, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 205, 'Subscription payment 211', '2021-12-18 09:00:00'),
('01K2F2DKG0WMW7CJ4AQDTE01M1', 37, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 205, 'Subscription payment 211', '2021-12-13 09:00:00'),
('01K2F2DKG0WMW7CJ4AQDTE01M1', 37, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 205, 'Subscription payment 211', '2021-12-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(212, '01K2F2DKG08ZEEGGN136RJ79RC', 'LF-INV-2026000212', 37, 37, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'CHF', 4.2017, 657355.96, 5.0, 'VAT', 'Halcyon Motors', 'billing@example.com', '2020-12-09 09:00:00', '2020-12-23 09:00:00', '2020-12-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000212.pdf', '2020-12-09 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(212, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2020-12-09', '2021-12-09', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(206, '01K2F2DKG049RDY4G3797N80KM', 'PAY-60206', 37, 212, 37, 37, 155, 156450.0, 'CHF', 4.2017, 657355.96, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0jbkgbsned2cka7gm', 'idem-01K2F2DKG05SGQQT9DHZEJ4GM9', 'https://cdn.livfinder.com/receipts/PAY-60206.pdf', '2020-12-16 09:00:00', '2020-12-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T84JNAGN9CVC3XW5', 37, 'cash', 'debit', 156450.0, 'CHF', 657355.96, 'payment', 206, 'Subscription payment 212', '2020-12-10 09:00:00'),
('01K2F2DKG0T84JNAGN9CVC3XW5', 37, 'revenue.subscription', 'credit', 149000.0, 'CHF', 626053.3, 'payment', 206, 'Subscription payment 212', '2020-12-20 09:00:00'),
('01K2F2DKG0T84JNAGN9CVC3XW5', 37, 'tax_payable', 'credit', 7450.0, 'CHF', 31302.66, 'payment', 206, 'Subscription payment 212', '2020-12-10 09:00:00'),
('01K2F2DKG0T84JNAGN9CVC3XW5', 37, 'expense.processor_fees', 'debit', 4538.05, 'CHF', 19067.52, 'payment', 206, 'Subscription payment 212', '2020-12-13 09:00:00'),
('01K2F2DKG0T84JNAGN9CVC3XW5', 37, 'cash', 'credit', 4538.05, 'CHF', 19067.52, 'payment', 206, 'Subscription payment 212', '2020-12-11 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(37, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-14 09:00:00'),
(37, 'listing', 20, 18, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-07-04 09:00:00'),
(37, 'listing', 50, 68, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-22 09:00:00'),
(37, 'listing', 10, 78, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-08-15 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(38, '01K2F2DKG0B8XGVPXQ68ZSK499', 38, 159, 'card', 'stripe', 'pm_01k2f2dkg05b5aqdn4jgtpac4g', 'mastercard', '5083', 4, 2031, 'Aurum Automotive', 1, 'active', '2024-04-27 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(38, '01K2F2DKG0XCDJ580S8R7AVMJP', 38, 4, 'active', 2499.0, 'USD', 9177.58, 'monthly', '2026-07-21 09:00:00', '2026-08-20 09:00:00', NULL, NULL, 1, 38, 'sub_01k2f2dkg04n8k2826sppz2njv', '2024-09-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(213, '01K2F2DKG0N01CMJB3J6NSPMPC', 'LF-INV-2026000213', 38, 38, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Aurum Automotive', 'billing@example.com', '2026-06-21 09:00:00', '2026-07-05 09:00:00', '2026-06-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000213.pdf', '2026-06-21 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(213, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-21', '2026-07-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(207, '01K2F2DKG0VA28PP077KH07VFW', 'PAY-60207', 38, 213, 38, 38, 159, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0fwt5bvp6r879wc4v', 'idem-01K2F2DKG0KHQQQZ9MAGRMBNY5', 'https://cdn.livfinder.com/receipts/PAY-60207.pdf', '2026-06-29 09:00:00', '2026-07-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T6AQJFAMGTHWJBNG', 38, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 207, 'Subscription payment 213', '2026-06-30 09:00:00'),
('01K2F2DKG0T6AQJFAMGTHWJBNG', 38, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 207, 'Subscription payment 213', '2026-06-25 09:00:00'),
('01K2F2DKG0T6AQJFAMGTHWJBNG', 38, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 207, 'Subscription payment 213', '2026-07-03 09:00:00'),
('01K2F2DKG0T6AQJFAMGTHWJBNG', 38, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 207, 'Subscription payment 213', '2026-06-28 09:00:00'),
('01K2F2DKG0T6AQJFAMGTHWJBNG', 38, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 207, 'Subscription payment 213', '2026-06-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(214, '01K2F2DKG0J0PFFDM95GZVXDP2', 'LF-INV-2026000214', 38, 38, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Aurum Automotive', 'billing@example.com', '2026-05-22 09:00:00', '2026-06-05 09:00:00', '2026-05-24 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000214.pdf', '2026-05-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(214, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-22', '2026-06-21', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(208, '01K2F2DKG0SWH5PA43V3G6WETW', 'PAY-60208', 38, 214, 38, 38, 159, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0a83dzb896z4avh52', 'idem-01K2F2DKG0ES9WJ89E6M188JSH', 'https://cdn.livfinder.com/receipts/PAY-60208.pdf', '2026-05-23 09:00:00', '2026-05-31 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0X52W8687AMZQ5JP9', 38, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 208, 'Subscription payment 214', '2026-05-27 09:00:00'),
('01K2F2DKG0X52W8687AMZQ5JP9', 38, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 208, 'Subscription payment 214', '2026-06-01 09:00:00'),
('01K2F2DKG0X52W8687AMZQ5JP9', 38, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 208, 'Subscription payment 214', '2026-05-27 09:00:00'),
('01K2F2DKG0X52W8687AMZQ5JP9', 38, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 208, 'Subscription payment 214', '2026-05-27 09:00:00'),
('01K2F2DKG0X52W8687AMZQ5JP9', 38, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 208, 'Subscription payment 214', '2026-05-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(215, '01K2F2DKG08S2V5K20HX29DNNA', 'LF-INV-2026000215', 38, 38, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Aurum Automotive', 'billing@example.com', '2026-04-22 09:00:00', '2026-05-06 09:00:00', '2026-04-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000215.pdf', '2026-04-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(215, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-22', '2026-05-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(209, '01K2F2DKG04RXW8BHR1SH34ZQE', 'PAY-60209', 38, 215, 38, 38, 159, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0nw7we0kvpjspw35y', 'idem-01K2F2DKG03QNYDDCME9EETS8K', 'https://cdn.livfinder.com/receipts/PAY-60209.pdf', '2026-04-26 09:00:00', '2026-05-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XBEDJZNN2JHW6WN1', 38, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 209, 'Subscription payment 215', '2026-04-28 09:00:00'),
('01K2F2DKG0XBEDJZNN2JHW6WN1', 38, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 209, 'Subscription payment 215', '2026-04-27 09:00:00'),
('01K2F2DKG0XBEDJZNN2JHW6WN1', 38, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 209, 'Subscription payment 215', '2026-04-25 09:00:00'),
('01K2F2DKG0XBEDJZNN2JHW6WN1', 38, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 209, 'Subscription payment 215', '2026-04-22 09:00:00'),
('01K2F2DKG0XBEDJZNN2JHW6WN1', 38, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 209, 'Subscription payment 215', '2026-05-01 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(38, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-05 09:00:00'),
(38, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-07 09:00:00'),
(38, 'listing', 10, 8, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-02 09:00:00'),
(38, 'listing', 50, 58, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-27 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(39, '01K2F2DKG08VCQQFMKFQN4JCYP', 39, 163, 'card', 'stripe', 'pm_01k2f2dkg052ypj6gxan8h9es8', 'mastercard', '9142', 11, 2028, 'Meridian Yachts', 1, 'active', '2024-11-26 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(39, '01K2F2DKG0Z29NT9FEKHT3XAB7', 39, 4, 'active', 2499.0, 'CHF', 10500.05, 'monthly', '2026-08-06 09:00:00', '2026-09-05 09:00:00', NULL, NULL, 1, 39, 'sub_01k2f2dkg08tg18qfqza8qr029', '2025-03-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(216, '01K2F2DKG02M9FR0Q41JEPFSYM', 'LF-INV-2026000216', 39, 39, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CHF', 4.2017, 11025.05, 5.0, 'VAT', 'Meridian Yachts', 'billing@example.com', '2026-07-07 09:00:00', '2026-07-21 09:00:00', '2026-07-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000216.pdf', '2026-07-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(216, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-07', '2026-08-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(210, '01K2F2DKG0E5ZBWAVWJAR9E0SQ', 'PAY-60210', 39, 216, 39, 39, 163, 2623.95, 'CHF', 4.2017, 11025.05, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0hc6ckd7m301td9b8', 'idem-01K2F2DKG0MGDCQGHJ47V8WCPX', 'https://cdn.livfinder.com/receipts/PAY-60210.pdf', '2026-07-09 09:00:00', '2026-07-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZJDRNTZB2YJAHDWQ', 39, 'cash', 'debit', 2623.95, 'CHF', 11025.05, 'payment', 210, 'Subscription payment 216', '2026-07-16 09:00:00'),
('01K2F2DKG0ZJDRNTZB2YJAHDWQ', 39, 'revenue.subscription', 'credit', 2499.0, 'CHF', 10500.05, 'payment', 210, 'Subscription payment 216', '2026-07-18 09:00:00'),
('01K2F2DKG0ZJDRNTZB2YJAHDWQ', 39, 'tax_payable', 'credit', 124.95, 'CHF', 525.0, 'payment', 210, 'Subscription payment 216', '2026-07-09 09:00:00'),
('01K2F2DKG0ZJDRNTZB2YJAHDWQ', 39, 'expense.processor_fees', 'debit', 77.09, 'CHF', 323.91, 'payment', 210, 'Subscription payment 216', '2026-07-19 09:00:00'),
('01K2F2DKG0ZJDRNTZB2YJAHDWQ', 39, 'cash', 'credit', 77.09, 'CHF', 323.91, 'payment', 210, 'Subscription payment 216', '2026-07-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(217, '01K2F2DKG0Z0J9753G5QHNWQCD', 'LF-INV-2026000217', 39, 39, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CHF', 4.2017, 11025.05, 5.0, 'VAT', 'Meridian Yachts', 'billing@example.com', '2026-06-07 09:00:00', '2026-06-21 09:00:00', '2026-06-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000217.pdf', '2026-06-07 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(217, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-07', '2026-07-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(211, '01K2F2DKG0M3SWC0P766T5RGSG', 'PAY-60211', 39, 217, 39, 39, 163, 2623.95, 'CHF', 4.2017, 11025.05, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pcdnne1gm246fa03', 'idem-01K2F2DKG0G55DMGNM6GJ6REXB', 'https://cdn.livfinder.com/receipts/PAY-60211.pdf', '2026-06-07 09:00:00', '2026-06-11 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V059SXV2DH22WVAW', 39, 'cash', 'debit', 2623.95, 'CHF', 11025.05, 'payment', 211, 'Subscription payment 217', '2026-06-07 09:00:00'),
('01K2F2DKG0V059SXV2DH22WVAW', 39, 'revenue.subscription', 'credit', 2499.0, 'CHF', 10500.05, 'payment', 211, 'Subscription payment 217', '2026-06-17 09:00:00'),
('01K2F2DKG0V059SXV2DH22WVAW', 39, 'tax_payable', 'credit', 124.95, 'CHF', 525.0, 'payment', 211, 'Subscription payment 217', '2026-06-12 09:00:00'),
('01K2F2DKG0V059SXV2DH22WVAW', 39, 'expense.processor_fees', 'debit', 77.09, 'CHF', 323.91, 'payment', 211, 'Subscription payment 217', '2026-06-09 09:00:00'),
('01K2F2DKG0V059SXV2DH22WVAW', 39, 'cash', 'credit', 77.09, 'CHF', 323.91, 'payment', 211, 'Subscription payment 217', '2026-06-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(218, '01K2F2DKG0T1S1AA9CPMMWAC8K', 'LF-INV-2026000218', 39, 39, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CHF', 4.2017, 11025.05, 5.0, 'VAT', 'Meridian Yachts', 'billing@example.com', '2026-05-08 09:00:00', '2026-05-22 09:00:00', '2026-05-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000218.pdf', '2026-05-08 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(218, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-08', '2026-06-07', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(212, '01K2F2DKG01G9A9SMNT9CGQY3B', 'PAY-60212', 39, 218, 39, 39, 163, 2623.95, 'CHF', 4.2017, 11025.05, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0q5d05cbvx2w5efp5', 'idem-01K2F2DKG029V3WVMBNHM7YEMB', 'https://cdn.livfinder.com/receipts/PAY-60212.pdf', '2026-05-10 09:00:00', '2026-05-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V2QAHCRZ5XBY0TVX', 39, 'cash', 'debit', 2623.95, 'CHF', 11025.05, 'payment', 212, 'Subscription payment 218', '2026-05-10 09:00:00'),
('01K2F2DKG0V2QAHCRZ5XBY0TVX', 39, 'revenue.subscription', 'credit', 2499.0, 'CHF', 10500.05, 'payment', 212, 'Subscription payment 218', '2026-05-13 09:00:00'),
('01K2F2DKG0V2QAHCRZ5XBY0TVX', 39, 'tax_payable', 'credit', 124.95, 'CHF', 525.0, 'payment', 212, 'Subscription payment 218', '2026-05-10 09:00:00'),
('01K2F2DKG0V2QAHCRZ5XBY0TVX', 39, 'expense.processor_fees', 'debit', 77.09, 'CHF', 323.91, 'payment', 212, 'Subscription payment 218', '2026-05-09 09:00:00'),
('01K2F2DKG0V2QAHCRZ5XBY0TVX', 39, 'cash', 'credit', 77.09, 'CHF', 323.91, 'payment', 212, 'Subscription payment 218', '2026-05-08 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(39, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-03 09:00:00'),
(39, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2026-06-04 09:00:00'),
(39, 'listing', -2, 7, 'consumption', 'listing', NULL, 'Listing published', '2026-02-11 09:00:00'),
(39, 'listing', -1, 6, 'consumption', 'listing', NULL, 'Listing published', '2026-02-15 09:00:00'),
(39, 'listing', -1, 5, 'consumption', 'listing', NULL, 'Listing published', '2025-12-07 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(40, '01K2F2DKG07NZ1SEJWVARYGQ2G', 40, 167, 'card', 'stripe', 'pm_01k2f2dkg0hs7z63sgdqkd8qk8', 'mastercard', '3357', 1, 2030, 'Blackstone Marine', 1, 'active', '2025-12-14 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(40, '01K2F2DKG0JQGPCFQDSGR4Z53N', 40, 6, 'active', 149000.0, 'EUR', 593630.9, 'yearly', '2026-01-29 09:00:00', '2027-01-29 09:00:00', NULL, NULL, 1, 40, 'sub_01k2f2dkg0a83hpya1ttrp6v8b', '2024-03-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(219, '01K2F2DKG096Z86JWAHY311YXA', 'LF-INV-2026000219', 40, 40, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Marine', 'billing@example.com', '2025-01-29 09:00:00', '2025-02-12 09:00:00', '2025-02-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000219.pdf', '2025-01-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(219, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2025-01-29', '2026-01-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(213, '01K2F2DKG0SDPA0KXZP0VNNZ5C', 'PAY-60213', 40, 219, 40, 40, 167, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0na5m5t9zb8sds6qx', 'idem-01K2F2DKG0KXQ1EJDAJ3VHTAW1', 'https://cdn.livfinder.com/receipts/PAY-60213.pdf', '2025-01-29 09:00:00', '2025-02-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZTZF8JA6T8V474H7', 40, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 213, 'Subscription payment 219', '2025-02-10 09:00:00'),
('01K2F2DKG0ZTZF8JA6T8V474H7', 40, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 213, 'Subscription payment 219', '2025-02-05 09:00:00'),
('01K2F2DKG0ZTZF8JA6T8V474H7', 40, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 213, 'Subscription payment 219', '2025-02-04 09:00:00'),
('01K2F2DKG0ZTZF8JA6T8V474H7', 40, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 213, 'Subscription payment 219', '2025-02-07 09:00:00'),
('01K2F2DKG0ZTZF8JA6T8V474H7', 40, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 213, 'Subscription payment 219', '2025-02-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(220, '01K2F2DKG04RYHBAKMY547PP6V', 'LF-INV-2026000220', 40, 40, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Marine', 'billing@example.com', '2024-01-30 09:00:00', '2024-02-13 09:00:00', '2024-02-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000220.pdf', '2024-01-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(220, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2024-01-30', '2025-01-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(214, '01K2F2DKG0J9A6RVA8J8H1QCYR', 'PAY-60214', 40, 220, 40, 40, 167, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg068aasch3atn2atnm', 'idem-01K2F2DKG0GMFA4RYWDZGY438A', 'https://cdn.livfinder.com/receipts/PAY-60214.pdf', '2024-01-30 09:00:00', '2024-02-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0X0N8SNB8VCTRRA66', 40, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 214, 'Subscription payment 220', '2024-02-11 09:00:00'),
('01K2F2DKG0X0N8SNB8VCTRRA66', 40, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 214, 'Subscription payment 220', '2024-01-31 09:00:00'),
('01K2F2DKG0X0N8SNB8VCTRRA66', 40, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 214, 'Subscription payment 220', '2024-02-06 09:00:00'),
('01K2F2DKG0X0N8SNB8VCTRRA66', 40, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 214, 'Subscription payment 220', '2024-02-05 09:00:00'),
('01K2F2DKG0X0N8SNB8VCTRRA66', 40, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 214, 'Subscription payment 220', '2024-02-03 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(221, '01K2F2DKG0KSQM57TEYNA2RJNH', 'LF-INV-2026000221', 40, 40, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Marine', 'billing@example.com', '2023-01-30 09:00:00', '2023-02-13 09:00:00', '2023-02-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000221.pdf', '2023-01-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(221, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2023-01-30', '2024-01-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(215, '01K2F2DKG0RZRRPEHDGSB9XFX1', 'PAY-60215', 40, 221, 40, 40, 167, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03p8nk947w6mf0dqq', 'idem-01K2F2DKG0PKD64DBZFVWYZ0RA', 'https://cdn.livfinder.com/receipts/PAY-60215.pdf', '2023-02-08 09:00:00', '2023-02-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09AMD0JD3NQMJMYW8', 40, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 215, 'Subscription payment 221', '2023-01-30 09:00:00'),
('01K2F2DKG09AMD0JD3NQMJMYW8', 40, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 215, 'Subscription payment 221', '2023-02-11 09:00:00'),
('01K2F2DKG09AMD0JD3NQMJMYW8', 40, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 215, 'Subscription payment 221', '2023-02-10 09:00:00'),
('01K2F2DKG09AMD0JD3NQMJMYW8', 40, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 215, 'Subscription payment 221', '2023-02-09 09:00:00'),
('01K2F2DKG09AMD0JD3NQMJMYW8', 40, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 215, 'Subscription payment 221', '2023-02-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(222, '01K2F2DKG06XDZBC9TXVWRCXZD', 'LF-INV-2026000222', 40, 40, 'paid', 149000.0, 0, 7450.0, 156450.0, 156450.0, 0.0, 'EUR', 3.9841, 623312.45, 5.0, 'VAT', 'Blackstone Marine', 'billing@example.com', '2022-01-30 09:00:00', '2022-02-13 09:00:00', '2022-02-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000222.pdf', '2022-01-30 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(222, 'Subscription — yearly plan', 'subscription', 'plan:6', 1, 149000.0, 5.0, 7450.0, 156450.0, '2022-01-30', '2023-01-30', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(216, '01K2F2DKG0TTKCXXMATVWDTT0M', 'PAY-60216', 40, 222, 40, 40, 167, 156450.0, 'EUR', 3.9841, 623312.45, 4538.05, 151911.95, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02kybxgnzetx2e423', 'idem-01K2F2DKG0GCC1SDY2H000MBZ5', 'https://cdn.livfinder.com/receipts/PAY-60216.pdf', '2022-01-31 09:00:00', '2022-02-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04CME89YVNDGTJY2E', 40, 'cash', 'debit', 156450.0, 'EUR', 623312.45, 'payment', 216, 'Subscription payment 222', '2022-01-30 09:00:00'),
('01K2F2DKG04CME89YVNDGTJY2E', 40, 'revenue.subscription', 'credit', 149000.0, 'EUR', 593630.9, 'payment', 216, 'Subscription payment 222', '2022-02-01 09:00:00'),
('01K2F2DKG04CME89YVNDGTJY2E', 40, 'tax_payable', 'credit', 7450.0, 'EUR', 29681.55, 'payment', 216, 'Subscription payment 222', '2022-02-06 09:00:00'),
('01K2F2DKG04CME89YVNDGTJY2E', 40, 'expense.processor_fees', 'debit', 4538.05, 'EUR', 18080.05, 'payment', 216, 'Subscription payment 222', '2022-02-10 09:00:00'),
('01K2F2DKG04CME89YVNDGTJY2E', 40, 'cash', 'credit', 4538.05, 'EUR', 18080.05, 'payment', 216, 'Subscription payment 222', '2022-01-31 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(40, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-11 09:00:00'),
(40, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-17 09:00:00'),
(40, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-06-18 09:00:00'),
(40, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-08 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(41, '01K2F2DKG0CG9W8TZDGXHZA680', 41, 171, 'card', 'stripe', 'pm_01k2f2dkg0c3pxsfzyp2k7a8mp', 'visa', '8402', 6, 2031, 'Crown Aviation', 1, 'active', '2024-06-14 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(41, '01K2F2DKG0847KH66K465G44C6', 41, 4, 'cancelled', 2499.0, 'USD', 9177.58, 'monthly', '2026-08-13 09:00:00', '2026-09-12 09:00:00', NULL, '2026-07-22 09:00:00', 0, 41, 'sub_01k2f2dkg093n4cap9kafpaxsj', '2024-05-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(223, '01K2F2DKG02VB44YR37ZT0C1YA', 'LF-INV-2026000223', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-07-14 09:00:00', '2026-07-28 09:00:00', '2026-07-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000223.pdf', '2026-07-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(223, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-14', '2026-08-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(217, '01K2F2DKG0C2J75P6GEF2BDVE0', 'PAY-60217', 41, 223, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0aaq3rcx27vwzb856', 'idem-01K2F2DKG06PBYWK3CT4FJQXEV', 'https://cdn.livfinder.com/receipts/PAY-60217.pdf', '2026-07-14 09:00:00', '2026-07-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HNX2G404166KX9RZ', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 217, 'Subscription payment 223', '2026-07-14 09:00:00'),
('01K2F2DKG0HNX2G404166KX9RZ', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 217, 'Subscription payment 223', '2026-07-23 09:00:00'),
('01K2F2DKG0HNX2G404166KX9RZ', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 217, 'Subscription payment 223', '2026-07-24 09:00:00'),
('01K2F2DKG0HNX2G404166KX9RZ', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 217, 'Subscription payment 223', '2026-07-18 09:00:00'),
('01K2F2DKG0HNX2G404166KX9RZ', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 217, 'Subscription payment 223', '2026-07-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(224, '01K2F2DKG0RH00XX20ZC4RK0KT', 'LF-INV-2026000224', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-06-14 09:00:00', '2026-06-28 09:00:00', '2026-06-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000224.pdf', '2026-06-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(224, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-14', '2026-07-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(218, '01K2F2DKG0J942103YMKPWAF8S', 'PAY-60218', 41, 224, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xt6chq64jp1n0p7r', 'idem-01K2F2DKG009HM6JPHB7AD25SJ', 'https://cdn.livfinder.com/receipts/PAY-60218.pdf', '2026-06-18 09:00:00', '2026-06-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG01VR5AAH9HKFBSDFH', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 218, 'Subscription payment 224', '2026-06-22 09:00:00'),
('01K2F2DKG01VR5AAH9HKFBSDFH', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 218, 'Subscription payment 224', '2026-06-21 09:00:00'),
('01K2F2DKG01VR5AAH9HKFBSDFH', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 218, 'Subscription payment 224', '2026-06-26 09:00:00'),
('01K2F2DKG01VR5AAH9HKFBSDFH', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 218, 'Subscription payment 224', '2026-06-17 09:00:00'),
('01K2F2DKG01VR5AAH9HKFBSDFH', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 218, 'Subscription payment 224', '2026-06-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(225, '01K2F2DKG0R2DBQYJT4B9C2Y5B', 'LF-INV-2026000225', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-05-15 09:00:00', '2026-05-29 09:00:00', '2026-05-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000225.pdf', '2026-05-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(225, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-15', '2026-06-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(219, '01K2F2DKG0CK06C7WX5SNS3CD1', 'PAY-60219', 41, 225, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03b1vtdcdehgqtsmt', 'idem-01K2F2DKG0C4QVQ2ECKTSCKNB4', 'https://cdn.livfinder.com/receipts/PAY-60219.pdf', '2026-05-20 09:00:00', '2026-05-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0K8CXYEENTC7HHQ0A', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 219, 'Subscription payment 225', '2026-05-16 09:00:00'),
('01K2F2DKG0K8CXYEENTC7HHQ0A', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 219, 'Subscription payment 225', '2026-05-26 09:00:00'),
('01K2F2DKG0K8CXYEENTC7HHQ0A', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 219, 'Subscription payment 225', '2026-05-22 09:00:00'),
('01K2F2DKG0K8CXYEENTC7HHQ0A', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 219, 'Subscription payment 225', '2026-05-26 09:00:00'),
('01K2F2DKG0K8CXYEENTC7HHQ0A', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 219, 'Subscription payment 225', '2026-05-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(226, '01K2F2DKG0R8ZF6PDK3JBBGTDN', 'LF-INV-2026000226', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-04-15 09:00:00', '2026-04-29 09:00:00', '2026-04-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000226.pdf', '2026-04-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(226, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-15', '2026-05-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(220, '01K2F2DKG0X7TQKMH2DBZE7GC0', 'PAY-60220', 41, 226, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0akqtsm1gq1wbw8cw', 'idem-01K2F2DKG06C6BRKZHEJKRWB3Y', 'https://cdn.livfinder.com/receipts/PAY-60220.pdf', '2026-04-18 09:00:00', '2026-04-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V9Z5T79A5YXEDG39', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 220, 'Subscription payment 226', '2026-04-20 09:00:00'),
('01K2F2DKG0V9Z5T79A5YXEDG39', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 220, 'Subscription payment 226', '2026-04-16 09:00:00'),
('01K2F2DKG0V9Z5T79A5YXEDG39', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 220, 'Subscription payment 226', '2026-04-15 09:00:00'),
('01K2F2DKG0V9Z5T79A5YXEDG39', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 220, 'Subscription payment 226', '2026-04-18 09:00:00'),
('01K2F2DKG0V9Z5T79A5YXEDG39', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 220, 'Subscription payment 226', '2026-04-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(227, '01K2F2DKG08SD6R2Y10P06V34Z', 'LF-INV-2026000227', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-03-16 09:00:00', '2026-03-30 09:00:00', '2026-03-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000227.pdf', '2026-03-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(227, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-03-16', '2026-04-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(221, '01K2F2DKG0TKNDBXHVG4GX46RB', 'PAY-60221', 41, 227, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dhgyc6jre0j1rjaa', 'idem-01K2F2DKG0E64AZZET034MYDB8', 'https://cdn.livfinder.com/receipts/PAY-60221.pdf', '2026-03-27 09:00:00', '2026-03-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0QCZK3FSW4GQGRVSS', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 221, 'Subscription payment 227', '2026-03-21 09:00:00'),
('01K2F2DKG0QCZK3FSW4GQGRVSS', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 221, 'Subscription payment 227', '2026-03-24 09:00:00'),
('01K2F2DKG0QCZK3FSW4GQGRVSS', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 221, 'Subscription payment 227', '2026-03-25 09:00:00'),
('01K2F2DKG0QCZK3FSW4GQGRVSS', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 221, 'Subscription payment 227', '2026-03-25 09:00:00'),
('01K2F2DKG0QCZK3FSW4GQGRVSS', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 221, 'Subscription payment 227', '2026-03-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(228, '01K2F2DKG0HG0BXD0PSQX9CGR7', 'LF-INV-2026000228', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-02-14 09:00:00', '2026-02-28 09:00:00', '2026-02-21 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000228.pdf', '2026-02-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(228, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-02-14', '2026-03-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(222, '01K2F2DKG007B6ESMB5MQ8RZWB', 'PAY-60222', 41, 228, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xetea4nzmg9rr9c7', 'idem-01K2F2DKG0KFMJ9D8EJXG4E87D', 'https://cdn.livfinder.com/receipts/PAY-60222.pdf', '2026-02-16 09:00:00', '2026-02-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0M97BP6D2N1T65X3K', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 222, 'Subscription payment 228', '2026-02-15 09:00:00'),
('01K2F2DKG0M97BP6D2N1T65X3K', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 222, 'Subscription payment 228', '2026-02-23 09:00:00'),
('01K2F2DKG0M97BP6D2N1T65X3K', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 222, 'Subscription payment 228', '2026-02-16 09:00:00'),
('01K2F2DKG0M97BP6D2N1T65X3K', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 222, 'Subscription payment 228', '2026-02-17 09:00:00'),
('01K2F2DKG0M97BP6D2N1T65X3K', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 222, 'Subscription payment 228', '2026-02-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(229, '01K2F2DKG0MA969P0GD8CTZWMX', 'LF-INV-2026000229', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2026-01-15 09:00:00', '2026-01-29 09:00:00', '2026-01-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000229.pdf', '2026-01-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(229, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-01-15', '2026-02-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(223, '01K2F2DKG0E70X9QJ0JQ2DJ46K', 'PAY-60223', 41, 229, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03gmys2j29stmmssm', 'idem-01K2F2DKG0WJ366ESRJQ5PSAPB', 'https://cdn.livfinder.com/receipts/PAY-60223.pdf', '2026-01-24 09:00:00', '2026-01-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0E92P1RC3FHPNDQA5', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 223, 'Subscription payment 229', '2026-01-23 09:00:00'),
('01K2F2DKG0E92P1RC3FHPNDQA5', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 223, 'Subscription payment 229', '2026-01-24 09:00:00'),
('01K2F2DKG0E92P1RC3FHPNDQA5', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 223, 'Subscription payment 229', '2026-01-25 09:00:00'),
('01K2F2DKG0E92P1RC3FHPNDQA5', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 223, 'Subscription payment 229', '2026-01-21 09:00:00'),
('01K2F2DKG0E92P1RC3FHPNDQA5', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 223, 'Subscription payment 229', '2026-01-18 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(230, '01K2F2DKG0Z82NQW44772V2GC9', 'LF-INV-2026000230', 41, 41, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'USD', 3.6725, 9636.46, 5.0, 'VAT', 'Crown Aviation', 'billing@example.com', '2025-12-16 09:00:00', '2025-12-30 09:00:00', '2025-12-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000230.pdf', '2025-12-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(230, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2025-12-16', '2026-01-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(224, '01K2F2DKG0KHZRBGCMY2R3YNB5', 'PAY-60224', 41, 230, 41, 41, 171, 2623.95, 'USD', 3.6725, 9636.46, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xgpbm47r4fn97tt6', 'idem-01K2F2DKG0HZCSR89E12RE4HEW', 'https://cdn.livfinder.com/receipts/PAY-60224.pdf', '2025-12-22 09:00:00', '2025-12-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T1MACC4QD0GV7TMS', 41, 'cash', 'debit', 2623.95, 'USD', 9636.46, 'payment', 224, 'Subscription payment 230', '2025-12-25 09:00:00'),
('01K2F2DKG0T1MACC4QD0GV7TMS', 41, 'revenue.subscription', 'credit', 2499.0, 'USD', 9177.58, 'payment', 224, 'Subscription payment 230', '2025-12-16 09:00:00'),
('01K2F2DKG0T1MACC4QD0GV7TMS', 41, 'tax_payable', 'credit', 124.95, 'USD', 458.88, 'payment', 224, 'Subscription payment 230', '2025-12-18 09:00:00'),
('01K2F2DKG0T1MACC4QD0GV7TMS', 41, 'expense.processor_fees', 'debit', 77.09, 'USD', 283.11, 'payment', 224, 'Subscription payment 230', '2025-12-27 09:00:00'),
('01K2F2DKG0T1MACC4QD0GV7TMS', 41, 'cash', 'credit', 77.09, 'USD', 283.11, 'payment', 224, 'Subscription payment 230', '2025-12-26 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(41, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-11 09:00:00'),
(41, 'listing', 20, 30, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-03 09:00:00'),
(41, 'listing', 20, 50, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-03 09:00:00'),
(41, 'listing', 10, 60, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-19 09:00:00'),
(41, 'listing', -2, 58, 'consumption', 'listing', NULL, 'Listing published', '2025-11-22 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(42, '01K2F2DKG0DR1V9PB4AWN1PH0G', 42, 175, 'card', 'stripe', 'pm_01k2f2dkg01qn6j43bbjkrtr01', 'visa', '2440', 9, 2027, 'Azure Timepieces', 1, 'active', '2024-05-04 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(42, '01K2F2DKG0HX8JQMTR7RMR8DGA', 42, 4, 'cancelled', 2499.0, 'CAD', 6646.34, 'monthly', '2026-08-02 09:00:00', '2026-09-01 09:00:00', NULL, '2026-07-10 09:00:00', 0, 42, 'sub_01k2f2dkg083pjegyde74c45vr', '2025-06-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(231, '01K2F2DKG0WNQ3JMPG8V96JYRH', 'LF-INV-2026000231', 42, 42, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CAD', 2.6596, 6978.66, 5.0, 'VAT', 'Azure Timepieces', 'billing@example.com', '2026-07-03 09:00:00', '2026-07-17 09:00:00', '2026-07-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000231.pdf', '2026-07-03 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(231, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-07-03', '2026-08-02', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(225, '01K2F2DKG03YTHVV57XWT571B4', 'PAY-60225', 42, 231, 42, 42, 175, 2623.95, 'CAD', 2.6596, 6978.66, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0922jhc8pzpjf8se6', 'idem-01K2F2DKG090QSM9R5RZVGEF9H', 'https://cdn.livfinder.com/receipts/PAY-60225.pdf', '2026-07-10 09:00:00', '2026-07-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HYFA1EJSJAFGBRC1', 42, 'cash', 'debit', 2623.95, 'CAD', 6978.66, 'payment', 225, 'Subscription payment 231', '2026-07-07 09:00:00'),
('01K2F2DKG0HYFA1EJSJAFGBRC1', 42, 'revenue.subscription', 'credit', 2499.0, 'CAD', 6646.34, 'payment', 225, 'Subscription payment 231', '2026-07-03 09:00:00'),
('01K2F2DKG0HYFA1EJSJAFGBRC1', 42, 'tax_payable', 'credit', 124.95, 'CAD', 332.32, 'payment', 225, 'Subscription payment 231', '2026-07-13 09:00:00'),
('01K2F2DKG0HYFA1EJSJAFGBRC1', 42, 'expense.processor_fees', 'debit', 77.09, 'CAD', 205.03, 'payment', 225, 'Subscription payment 231', '2026-07-10 09:00:00'),
('01K2F2DKG0HYFA1EJSJAFGBRC1', 42, 'cash', 'credit', 77.09, 'CAD', 205.03, 'payment', 225, 'Subscription payment 231', '2026-07-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(232, '01K2F2DKG0ATSSQFDQ13E4GQDH', 'LF-INV-2026000232', 42, 42, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CAD', 2.6596, 6978.66, 5.0, 'VAT', 'Azure Timepieces', 'billing@example.com', '2026-06-03 09:00:00', '2026-06-17 09:00:00', '2026-06-10 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000232.pdf', '2026-06-03 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(232, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-06-03', '2026-07-03', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(226, '01K2F2DKG08Y7SVCW6F3Q4DAR4', 'PAY-60226', 42, 232, 42, 42, 175, 2623.95, 'CAD', 2.6596, 6978.66, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kbd43s4rs4jgyvw7', 'idem-01K2F2DKG0ZWJ6RCAN6W5XD3E7', 'https://cdn.livfinder.com/receipts/PAY-60226.pdf', '2026-06-06 09:00:00', '2026-06-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG06VCRBZTPVG4W9F27', 42, 'cash', 'debit', 2623.95, 'CAD', 6978.66, 'payment', 226, 'Subscription payment 232', '2026-06-06 09:00:00'),
('01K2F2DKG06VCRBZTPVG4W9F27', 42, 'revenue.subscription', 'credit', 2499.0, 'CAD', 6646.34, 'payment', 226, 'Subscription payment 232', '2026-06-05 09:00:00'),
('01K2F2DKG06VCRBZTPVG4W9F27', 42, 'tax_payable', 'credit', 124.95, 'CAD', 332.32, 'payment', 226, 'Subscription payment 232', '2026-06-11 09:00:00'),
('01K2F2DKG06VCRBZTPVG4W9F27', 42, 'expense.processor_fees', 'debit', 77.09, 'CAD', 205.03, 'payment', 226, 'Subscription payment 232', '2026-06-14 09:00:00'),
('01K2F2DKG06VCRBZTPVG4W9F27', 42, 'cash', 'credit', 77.09, 'CAD', 205.03, 'payment', 226, 'Subscription payment 232', '2026-06-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(233, '01K2F2DKG0AKKAZ69H9G1CAXFY', 'LF-INV-2026000233', 42, 42, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CAD', 2.6596, 6978.66, 5.0, 'VAT', 'Azure Timepieces', 'billing@example.com', '2026-05-04 09:00:00', '2026-05-18 09:00:00', '2026-05-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000233.pdf', '2026-05-04 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(233, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-05-04', '2026-06-03', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(227, '01K2F2DKG0GYZZVDFASRX8G36P', 'PAY-60227', 42, 233, 42, 42, 175, 2623.95, 'CAD', 2.6596, 6978.66, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ddkf5fvcg2tskp7e', 'idem-01K2F2DKG0A4NBYEWT4YPNP78V', 'https://cdn.livfinder.com/receipts/PAY-60227.pdf', '2026-05-09 09:00:00', '2026-05-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VGDEWBXP6TBYAY4Y', 42, 'cash', 'debit', 2623.95, 'CAD', 6978.66, 'payment', 227, 'Subscription payment 233', '2026-05-16 09:00:00'),
('01K2F2DKG0VGDEWBXP6TBYAY4Y', 42, 'revenue.subscription', 'credit', 2499.0, 'CAD', 6646.34, 'payment', 227, 'Subscription payment 233', '2026-05-08 09:00:00'),
('01K2F2DKG0VGDEWBXP6TBYAY4Y', 42, 'tax_payable', 'credit', 124.95, 'CAD', 332.32, 'payment', 227, 'Subscription payment 233', '2026-05-12 09:00:00'),
('01K2F2DKG0VGDEWBXP6TBYAY4Y', 42, 'expense.processor_fees', 'debit', 77.09, 'CAD', 205.03, 'payment', 227, 'Subscription payment 233', '2026-05-04 09:00:00'),
('01K2F2DKG0VGDEWBXP6TBYAY4Y', 42, 'cash', 'credit', 77.09, 'CAD', 205.03, 'payment', 227, 'Subscription payment 233', '2026-05-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(234, '01K2F2DKG0BPC4S32RYA22PG87', 'LF-INV-2026000234', 42, 42, 'paid', 2499.0, 0, 124.95, 2623.95, 2623.95, 0.0, 'CAD', 2.6596, 6978.66, 5.0, 'VAT', 'Azure Timepieces', 'billing@example.com', '2026-04-04 09:00:00', '2026-04-18 09:00:00', '2026-04-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000234.pdf', '2026-04-04 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(234, 'Subscription — monthly plan', 'subscription', 'plan:4', 1, 2499.0, 5.0, 124.95, 2623.95, '2026-04-04', '2026-05-04', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(228, '01K2F2DKG0X8WC35YTJNBPZBEW', 'PAY-60228', 42, 234, 42, 42, 175, 2623.95, 'CAD', 2.6596, 6978.66, 77.09, 2546.86, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0qmx82bxw4x8mqgvn', 'idem-01K2F2DKG0YR4KSTTERRQAD86Z', 'https://cdn.livfinder.com/receipts/PAY-60228.pdf', '2026-04-15 09:00:00', '2026-04-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0BPZY786GRNXR6V4Y', 42, 'cash', 'debit', 2623.95, 'CAD', 6978.66, 'payment', 228, 'Subscription payment 234', '2026-04-10 09:00:00'),
('01K2F2DKG0BPZY786GRNXR6V4Y', 42, 'revenue.subscription', 'credit', 2499.0, 'CAD', 6646.34, 'payment', 228, 'Subscription payment 234', '2026-04-04 09:00:00'),
('01K2F2DKG0BPZY786GRNXR6V4Y', 42, 'tax_payable', 'credit', 124.95, 'CAD', 332.32, 'payment', 228, 'Subscription payment 234', '2026-04-11 09:00:00'),
('01K2F2DKG0BPZY786GRNXR6V4Y', 42, 'expense.processor_fees', 'debit', 77.09, 'CAD', 205.03, 'payment', 228, 'Subscription payment 234', '2026-04-13 09:00:00'),
('01K2F2DKG0BPZY786GRNXR6V4Y', 42, 'cash', 'credit', 77.09, 'CAD', 205.03, 'payment', 228, 'Subscription payment 234', '2026-04-06 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(42, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-16 09:00:00'),
(42, 'listing', 20, 18, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-03 09:00:00'),
(42, 'listing', -1, 17, 'consumption', 'listing', NULL, 'Listing published', '2026-02-08 09:00:00'),
(42, 'listing', -1, 16, 'consumption', 'listing', NULL, 'Listing published', '2026-07-09 09:00:00'),
(42, 'listing', 10, 26, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-07 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(43, '01K2F2DKG03JFBKABJ77F8ASJN', 43, 179, 'card', 'stripe', 'pm_01k2f2dkg01xdtr4zk36qmaanh', 'mastercard', '6331', 10, 2031, 'Card Holder', 1, 'active', '2025-12-26 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(43, '01K2F2DKG0FTV2298NSATDVHZP', 43, 2, 'past_due', 299.0, 'AED', 299.0, 'monthly', '2026-07-23 09:00:00', '2026-08-22 09:00:00', NULL, NULL, 1, 43, 'sub_01k2f2dkg023pwm509gzv4repq', '2024-01-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(235, '01K2F2DKG0HNB68J4AGZQ986KM', 'LF-INV-2026000235', 43, 43, 'past_due', 299.0, 0, 14.95, 313.95, 0, 313.95, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-23 09:00:00', '2026-07-07 09:00:00', NULL, 'https://cdn.livfinder.com/invoices/LF-INV-2026000235.pdf', '2026-06-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(235, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-23', '2026-07-23', 0);

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(236, '01K2F2DKG04RK9F59NZKYAGWK8', 'LF-INV-2026000236', 43, 43, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-24 09:00:00', '2026-06-07 09:00:00', '2026-06-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000236.pdf', '2026-05-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(236, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-24', '2026-06-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(229, '01K2F2DKG08FJG3V66RVK4GQH6', 'PAY-60229', 43, 236, 43, 43, 179, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg049y7tpvtd1mf864g', 'idem-01K2F2DKG0DA4A8PHJ81S8X86V', 'https://cdn.livfinder.com/receipts/PAY-60229.pdf', '2026-06-02 09:00:00', '2026-05-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG043C52BCDRKP0KD4P', 43, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 229, 'Subscription payment 236', '2026-05-27 09:00:00'),
('01K2F2DKG043C52BCDRKP0KD4P', 43, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 229, 'Subscription payment 236', '2026-05-30 09:00:00'),
('01K2F2DKG043C52BCDRKP0KD4P', 43, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 229, 'Subscription payment 236', '2026-05-27 09:00:00'),
('01K2F2DKG043C52BCDRKP0KD4P', 43, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 229, 'Subscription payment 236', '2026-05-29 09:00:00'),
('01K2F2DKG043C52BCDRKP0KD4P', 43, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 229, 'Subscription payment 236', '2026-05-29 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(237, '01K2F2DKG0EFZQ83KFC4K7DJQK', 'LF-INV-2026000237', 43, 43, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-24 09:00:00', '2026-05-08 09:00:00', '2026-05-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000237.pdf', '2026-04-24 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(237, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-24', '2026-05-24', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(230, '01K2F2DKG0P4EGBKD88CVXPNVB', 'PAY-60230', 43, 237, 43, 43, 179, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03qwbme56c0sypwd5', 'idem-01K2F2DKG0A5BXG0TZ2Q4WX6RW', 'https://cdn.livfinder.com/receipts/PAY-60230.pdf', '2026-05-05 09:00:00', '2026-05-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HEZGRGKASJPGKAWT', 43, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 230, 'Subscription payment 237', '2026-05-03 09:00:00'),
('01K2F2DKG0HEZGRGKASJPGKAWT', 43, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 230, 'Subscription payment 237', '2026-04-26 09:00:00'),
('01K2F2DKG0HEZGRGKASJPGKAWT', 43, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 230, 'Subscription payment 237', '2026-05-05 09:00:00'),
('01K2F2DKG0HEZGRGKASJPGKAWT', 43, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 230, 'Subscription payment 237', '2026-04-27 09:00:00'),
('01K2F2DKG0HEZGRGKASJPGKAWT', 43, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 230, 'Subscription payment 237', '2026-05-06 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(43, 'listing', 20, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-12 09:00:00'),
(43, 'listing', 10, 30, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-24 09:00:00'),
(43, 'listing', -1, 29, 'consumption', 'listing', NULL, 'Listing published', '2026-05-12 09:00:00'),
(43, 'listing', 20, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-27 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(44, '01K2F2DKG07HQG1AMJ29YRQE0W', 56, 192, 'card', 'stripe', 'pm_01k2f2dkg0cxp0cjxx17dyt2dm', 'mastercard', '2895', 11, 2030, 'Card Holder', 1, 'active', '2024-04-29 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(44, '01K2F2DKG0DG85P43R156T79T8', 56, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-07-31 09:00:00', '2026-08-30 09:00:00', NULL, NULL, 1, 44, 'sub_01k2f2dkg0esf3ynx38vft6tjj', '2025-09-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(238, '01K2F2DKG0QYKCNF34KEDY20NQ', 'LF-INV-2026000238', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-01 09:00:00', '2026-07-15 09:00:00', '2026-07-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000238.pdf', '2026-07-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(238, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-01', '2026-07-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(231, '01K2F2DKG0N6MM12X5D5DTKSTY', 'PAY-60231', 56, 238, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rpmfdevcvak4pvn3', 'idem-01K2F2DKG0C174ZM60VFBT9P9G', 'https://cdn.livfinder.com/receipts/PAY-60231.pdf', '2026-07-12 09:00:00', '2026-07-12 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG05A3R56M7B5M012ZN', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 231, 'Subscription payment 238', '2026-07-13 09:00:00'),
('01K2F2DKG05A3R56M7B5M012ZN', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 231, 'Subscription payment 238', '2026-07-05 09:00:00'),
('01K2F2DKG05A3R56M7B5M012ZN', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 231, 'Subscription payment 238', '2026-07-12 09:00:00'),
('01K2F2DKG05A3R56M7B5M012ZN', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 231, 'Subscription payment 238', '2026-07-01 09:00:00'),
('01K2F2DKG05A3R56M7B5M012ZN', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 231, 'Subscription payment 238', '2026-07-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(239, '01K2F2DKG0TKS3EVXJJX73RWSD', 'LF-INV-2026000239', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-01 09:00:00', '2026-06-15 09:00:00', '2026-06-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000239.pdf', '2026-06-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(239, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-01', '2026-07-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(232, '01K2F2DKG02FASWEA4BFK9VR4E', 'PAY-60232', 56, 239, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0e26dybk3z101f3v7', 'idem-01K2F2DKG0RSBCR8ASSZ320DYT', 'https://cdn.livfinder.com/receipts/PAY-60232.pdf', '2026-06-12 09:00:00', '2026-06-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG05PGNQXFVBST3P6Q1', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 232, 'Subscription payment 239', '2026-06-11 09:00:00'),
('01K2F2DKG05PGNQXFVBST3P6Q1', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 232, 'Subscription payment 239', '2026-06-12 09:00:00'),
('01K2F2DKG05PGNQXFVBST3P6Q1', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 232, 'Subscription payment 239', '2026-06-04 09:00:00'),
('01K2F2DKG05PGNQXFVBST3P6Q1', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 232, 'Subscription payment 239', '2026-06-01 09:00:00'),
('01K2F2DKG05PGNQXFVBST3P6Q1', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 232, 'Subscription payment 239', '2026-06-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(240, '01K2F2DKG0W5T70A6NQ4R8GH8J', 'LF-INV-2026000240', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-02 09:00:00', '2026-05-16 09:00:00', '2026-05-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000240.pdf', '2026-05-02 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(240, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-02', '2026-06-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(233, '01K2F2DKG0K7AW6GDVRZQMN4WX', 'PAY-60233', 56, 240, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0bymtt9hfbnrrjrec', 'idem-01K2F2DKG0VZTD4C9WD6A2N94P', 'https://cdn.livfinder.com/receipts/PAY-60233.pdf', '2026-05-05 09:00:00', '2026-05-03 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0J0PVQYCAP5A3Y1JC', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 233, 'Subscription payment 240', '2026-05-02 09:00:00'),
('01K2F2DKG0J0PVQYCAP5A3Y1JC', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 233, 'Subscription payment 240', '2026-05-10 09:00:00'),
('01K2F2DKG0J0PVQYCAP5A3Y1JC', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 233, 'Subscription payment 240', '2026-05-10 09:00:00'),
('01K2F2DKG0J0PVQYCAP5A3Y1JC', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 233, 'Subscription payment 240', '2026-05-05 09:00:00'),
('01K2F2DKG0J0PVQYCAP5A3Y1JC', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 233, 'Subscription payment 240', '2026-05-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(241, '01K2F2DKG0TTT67XZ2HHDSF53A', 'LF-INV-2026000241', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-02 09:00:00', '2026-04-16 09:00:00', '2026-04-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000241.pdf', '2026-04-02 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(241, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-02', '2026-05-02', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(234, '01K2F2DKG0NCQ328SM7YH38NQ7', 'PAY-60234', 56, 241, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0td7wb3x5185ee7fw', 'idem-01K2F2DKG0D505NGR33T5YMYWB', 'https://cdn.livfinder.com/receipts/PAY-60234.pdf', '2026-04-02 09:00:00', '2026-04-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0A49K1RH0DPMWCWY6', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 234, 'Subscription payment 241', '2026-04-02 09:00:00'),
('01K2F2DKG0A49K1RH0DPMWCWY6', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 234, 'Subscription payment 241', '2026-04-10 09:00:00'),
('01K2F2DKG0A49K1RH0DPMWCWY6', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 234, 'Subscription payment 241', '2026-04-08 09:00:00'),
('01K2F2DKG0A49K1RH0DPMWCWY6', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 234, 'Subscription payment 241', '2026-04-10 09:00:00'),
('01K2F2DKG0A49K1RH0DPMWCWY6', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 234, 'Subscription payment 241', '2026-04-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(242, '01K2F2DKG0V40GZG1FE2VRJVVK', 'LF-INV-2026000242', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-03 09:00:00', '2026-03-17 09:00:00', '2026-03-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000242.pdf', '2026-03-03 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(242, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-03', '2026-04-02', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(235, '01K2F2DKG0F2NEESC23QP6P2V0', 'PAY-60235', 56, 242, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pernfawaa5x6kegt', 'idem-01K2F2DKG0J60DN8TSRTZB1MA9', 'https://cdn.livfinder.com/receipts/PAY-60235.pdf', '2026-03-06 09:00:00', '2026-03-11 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0PH09D9FQJKSSBX86', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 235, 'Subscription payment 242', '2026-03-08 09:00:00'),
('01K2F2DKG0PH09D9FQJKSSBX86', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 235, 'Subscription payment 242', '2026-03-04 09:00:00'),
('01K2F2DKG0PH09D9FQJKSSBX86', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 235, 'Subscription payment 242', '2026-03-14 09:00:00'),
('01K2F2DKG0PH09D9FQJKSSBX86', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 235, 'Subscription payment 242', '2026-03-09 09:00:00'),
('01K2F2DKG0PH09D9FQJKSSBX86', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 235, 'Subscription payment 242', '2026-03-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(243, '01K2F2DKG0YHTXMTB254P13CM0', 'LF-INV-2026000243', 56, 44, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-01 09:00:00', '2026-02-15 09:00:00', '2026-02-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000243.pdf', '2026-02-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(243, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-01', '2026-03-03', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(236, '01K2F2DKG0KSATC63CXFCVGCTR', 'PAY-60236', 56, 243, 44, 44, 192, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ejxe3m71ttbsx4ty', 'idem-01K2F2DKG0ZVJYZDFX6CW99P06', 'https://cdn.livfinder.com/receipts/PAY-60236.pdf', '2026-02-02 09:00:00', '2026-02-10 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GCJBGZCF41Z0FQQH', 56, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 236, 'Subscription payment 243', '2026-02-13 09:00:00'),
('01K2F2DKG0GCJBGZCF41Z0FQQH', 56, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 236, 'Subscription payment 243', '2026-02-10 09:00:00'),
('01K2F2DKG0GCJBGZCF41Z0FQQH', 56, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 236, 'Subscription payment 243', '2026-02-10 09:00:00'),
('01K2F2DKG0GCJBGZCF41Z0FQQH', 56, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 236, 'Subscription payment 243', '2026-02-07 09:00:00'),
('01K2F2DKG0GCJBGZCF41Z0FQQH', 56, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 236, 'Subscription payment 243', '2026-02-08 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(56, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-11-25 09:00:00'),
(56, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-25 09:00:00'),
(56, 'listing', 20, 18, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-18 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(45, '01K2F2DKG02WQPJR5E5JYTMG5T', 57, 193, 'card', 'stripe', 'pm_01k2f2dkg0y1rs3tskcxx470te', 'amex', '9625', 7, 2029, 'Card Holder', 1, 'active', '2024-08-19 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(45, '01K2F2DKG0E9JGXFC9D72W6C9K', 57, 2, 'trialing', 299.0, 'AED', 299.0, 'monthly', '2026-07-25 09:00:00', '2026-08-24 09:00:00', '2026-08-08 09:00:00', NULL, 1, 45, 'sub_01k2f2dkg0h3m5fe336mbq7212', '2024-07-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(244, '01K2F2DKG0FNSMK84Y04MZ62MA', 'LF-INV-2026000244', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-25 09:00:00', '2026-07-09 09:00:00', '2026-07-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000244.pdf', '2026-06-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(244, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-25', '2026-07-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(237, '01K2F2DKG0WP3G97360QD56RFJ', 'PAY-60237', 57, 244, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0g6sa38btkfg4jvtf', 'idem-01K2F2DKG0XYDJF7Q5ER5ZP48S', 'https://cdn.livfinder.com/receipts/PAY-60237.pdf', '2026-07-06 09:00:00', '2026-06-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0H234VS3455GEHMT8', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 237, 'Subscription payment 244', '2026-06-25 09:00:00'),
('01K2F2DKG0H234VS3455GEHMT8', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 237, 'Subscription payment 244', '2026-06-28 09:00:00'),
('01K2F2DKG0H234VS3455GEHMT8', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 237, 'Subscription payment 244', '2026-07-07 09:00:00'),
('01K2F2DKG0H234VS3455GEHMT8', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 237, 'Subscription payment 244', '2026-07-06 09:00:00'),
('01K2F2DKG0H234VS3455GEHMT8', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 237, 'Subscription payment 244', '2026-07-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(245, '01K2F2DKG04J0XY74MACAMM9C5', 'LF-INV-2026000245', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-26 09:00:00', '2026-06-09 09:00:00', '2026-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000245.pdf', '2026-05-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(245, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-26', '2026-06-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(238, '01K2F2DKG0QXGA6R9MCW93AEZQ', 'PAY-60238', 57, 245, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg05qq0wzez7t2wsv35', 'idem-01K2F2DKG0MNAME2KHR6ZMEYCA', 'https://cdn.livfinder.com/receipts/PAY-60238.pdf', '2026-06-02 09:00:00', '2026-05-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0KMAAGW1TM83F3NPK', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 238, 'Subscription payment 245', '2026-06-07 09:00:00'),
('01K2F2DKG0KMAAGW1TM83F3NPK', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 238, 'Subscription payment 245', '2026-05-27 09:00:00'),
('01K2F2DKG0KMAAGW1TM83F3NPK', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 238, 'Subscription payment 245', '2026-06-04 09:00:00'),
('01K2F2DKG0KMAAGW1TM83F3NPK', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 238, 'Subscription payment 245', '2026-05-31 09:00:00'),
('01K2F2DKG0KMAAGW1TM83F3NPK', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 238, 'Subscription payment 245', '2026-06-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(246, '01K2F2DKG07GSWYBFDEQV64PMA', 'LF-INV-2026000246', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-26 09:00:00', '2026-05-10 09:00:00', '2026-05-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000246.pdf', '2026-04-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(246, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-26', '2026-05-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(239, '01K2F2DKG08QF7WMB74A85602D', 'PAY-60239', 57, 246, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xsczc8f8fb7xn8tj', 'idem-01K2F2DKG0EJ0HV2CFFZZBPKD7', 'https://cdn.livfinder.com/receipts/PAY-60239.pdf', '2026-05-07 09:00:00', '2026-05-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG02MYA6MJHN1K5VBE2', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 239, 'Subscription payment 246', '2026-05-02 09:00:00'),
('01K2F2DKG02MYA6MJHN1K5VBE2', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 239, 'Subscription payment 246', '2026-05-08 09:00:00'),
('01K2F2DKG02MYA6MJHN1K5VBE2', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 239, 'Subscription payment 246', '2026-04-30 09:00:00'),
('01K2F2DKG02MYA6MJHN1K5VBE2', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 239, 'Subscription payment 246', '2026-04-29 09:00:00'),
('01K2F2DKG02MYA6MJHN1K5VBE2', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 239, 'Subscription payment 246', '2026-05-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(247, '01K2F2DKG0YSJGTSB04T2868B8', 'LF-INV-2026000247', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-27 09:00:00', '2026-04-10 09:00:00', '2026-03-29 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000247.pdf', '2026-03-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(247, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-27', '2026-04-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(240, '01K2F2DKG0FKGDXTNBKEZYJ0NW', 'PAY-60240', 57, 247, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg01y3vvsynjdm36x9h', 'idem-01K2F2DKG0Y5ZZPX48Y17HZ7V9', 'https://cdn.livfinder.com/receipts/PAY-60240.pdf', '2026-04-04 09:00:00', '2026-03-31 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YAEBARA55PCNZ5KK', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 240, 'Subscription payment 247', '2026-03-30 09:00:00'),
('01K2F2DKG0YAEBARA55PCNZ5KK', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 240, 'Subscription payment 247', '2026-04-03 09:00:00'),
('01K2F2DKG0YAEBARA55PCNZ5KK', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 240, 'Subscription payment 247', '2026-03-28 09:00:00'),
('01K2F2DKG0YAEBARA55PCNZ5KK', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 240, 'Subscription payment 247', '2026-03-31 09:00:00'),
('01K2F2DKG0YAEBARA55PCNZ5KK', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 240, 'Subscription payment 247', '2026-04-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(248, '01K2F2DKG0S4NJF7WMXHC6CBKM', 'LF-INV-2026000248', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-25 09:00:00', '2026-03-11 09:00:00', '2026-03-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000248.pdf', '2026-02-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(248, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-25', '2026-03-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(241, '01K2F2DKG03E54EEKF1G2BWXXP', 'PAY-60241', 57, 248, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ppcpkctf7mek3w5a', 'idem-01K2F2DKG02PJN2YR6WEYP5ND0', 'https://cdn.livfinder.com/receipts/PAY-60241.pdf', '2026-03-05 09:00:00', '2026-02-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JF3BKGZN963ABR3K', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 241, 'Subscription payment 248', '2026-02-27 09:00:00'),
('01K2F2DKG0JF3BKGZN963ABR3K', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 241, 'Subscription payment 248', '2026-03-09 09:00:00'),
('01K2F2DKG0JF3BKGZN963ABR3K', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 241, 'Subscription payment 248', '2026-02-26 09:00:00'),
('01K2F2DKG0JF3BKGZN963ABR3K', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 241, 'Subscription payment 248', '2026-02-25 09:00:00'),
('01K2F2DKG0JF3BKGZN963ABR3K', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 241, 'Subscription payment 248', '2026-03-09 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(249, '01K2F2DKG0RVG6QH9G8CB2WAQM', 'LF-INV-2026000249', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-01-26 09:00:00', '2026-02-09 09:00:00', '2026-02-06 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000249.pdf', '2026-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(249, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-01-26', '2026-02-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(242, '01K2F2DKG0Y130EEA6XS72VP6B', 'PAY-60242', 57, 249, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0arw2v581rnjsvn9t', 'idem-01K2F2DKG05M0F0D94KH154ZG7', 'https://cdn.livfinder.com/receipts/PAY-60242.pdf', '2026-02-03 09:00:00', '2026-02-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0N1G6XSXQX1KMEFGZ', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 242, 'Subscription payment 249', '2026-02-05 09:00:00'),
('01K2F2DKG0N1G6XSXQX1KMEFGZ', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 242, 'Subscription payment 249', '2026-02-03 09:00:00'),
('01K2F2DKG0N1G6XSXQX1KMEFGZ', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 242, 'Subscription payment 249', '2026-02-04 09:00:00'),
('01K2F2DKG0N1G6XSXQX1KMEFGZ', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 242, 'Subscription payment 249', '2026-02-03 09:00:00'),
('01K2F2DKG0N1G6XSXQX1KMEFGZ', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 242, 'Subscription payment 249', '2026-02-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(250, '01K2F2DKG0GM67530XVKZTHV53', 'LF-INV-2026000250', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2025-12-27 09:00:00', '2026-01-10 09:00:00', '2025-12-31 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000250.pdf', '2025-12-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(250, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2025-12-27', '2026-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(243, '01K2F2DKG0GKQ63J5H85JFDF9X', 'PAY-60243', 57, 250, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mzheeyafw6qzdc9k', 'idem-01K2F2DKG0PCDFPHT26CRTTBRA', 'https://cdn.livfinder.com/receipts/PAY-60243.pdf', '2026-01-08 09:00:00', '2025-12-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VN2Y0XBSV2303M1A', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 243, 'Subscription payment 250', '2026-01-08 09:00:00'),
('01K2F2DKG0VN2Y0XBSV2303M1A', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 243, 'Subscription payment 250', '2026-01-05 09:00:00'),
('01K2F2DKG0VN2Y0XBSV2303M1A', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 243, 'Subscription payment 250', '2026-01-05 09:00:00'),
('01K2F2DKG0VN2Y0XBSV2303M1A', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 243, 'Subscription payment 250', '2026-01-08 09:00:00'),
('01K2F2DKG0VN2Y0XBSV2303M1A', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 243, 'Subscription payment 250', '2025-12-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(251, '01K2F2DKG0N573X0THSSQ3ZTMQ', 'LF-INV-2026000251', 57, 45, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2025-11-27 09:00:00', '2025-12-11 09:00:00', '2025-12-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000251.pdf', '2025-11-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(251, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2025-11-27', '2025-12-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(244, '01K2F2DKG03DN4Z0Z7W5F89GBG', 'PAY-60244', 57, 251, 45, 45, 193, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02ak3br89616ymkq6', 'idem-01K2F2DKG07FAQH95STQS59XAY', 'https://cdn.livfinder.com/receipts/PAY-60244.pdf', '2025-12-09 09:00:00', '2025-12-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0MZ9JGH526G5A3SQZ', 57, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 244, 'Subscription payment 251', '2025-12-08 09:00:00'),
('01K2F2DKG0MZ9JGH526G5A3SQZ', 57, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 244, 'Subscription payment 251', '2025-12-05 09:00:00'),
('01K2F2DKG0MZ9JGH526G5A3SQZ', 57, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 244, 'Subscription payment 251', '2025-11-27 09:00:00'),
('01K2F2DKG0MZ9JGH526G5A3SQZ', 57, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 244, 'Subscription payment 251', '2025-12-03 09:00:00'),
('01K2F2DKG0MZ9JGH526G5A3SQZ', 57, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 244, 'Subscription payment 251', '2025-12-01 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(57, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-01 09:00:00'),
(57, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-18 09:00:00'),
(57, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-29 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(46, '01K2F2DKG0F455JV7J5QKHQJEK', 58, 194, 'card', 'stripe', 'pm_01k2f2dkg0zmk0b9whjr10vk9x', 'amex', '1895', 7, 2028, 'Card Holder', 1, 'active', '2026-04-14 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(46, '01K2F2DKG0PZTCHTHRX6MRB4PS', 58, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-07-27 09:00:00', '2026-08-26 09:00:00', NULL, NULL, 1, 46, 'sub_01k2f2dkg0f4m0f9pp0pwjqtz2', '2024-12-30 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(252, '01K2F2DKG001X61RQZ8WA5E8XX', 'LF-INV-2026000252', 58, 46, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-27 09:00:00', '2026-07-11 09:00:00', '2026-07-05 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000252.pdf', '2026-06-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(252, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-27', '2026-07-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(245, '01K2F2DKG0CXZRNKFY11VZXG4P', 'PAY-60245', 58, 252, 46, 46, 194, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0y01ht20wg5vwb0c2', 'idem-01K2F2DKG06ZW6R388X335F7VA', 'https://cdn.livfinder.com/receipts/PAY-60245.pdf', '2026-07-01 09:00:00', '2026-06-27 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0F8J9VV2NX7YYPGTM', 58, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 245, 'Subscription payment 252', '2026-07-04 09:00:00'),
('01K2F2DKG0F8J9VV2NX7YYPGTM', 58, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 245, 'Subscription payment 252', '2026-07-07 09:00:00'),
('01K2F2DKG0F8J9VV2NX7YYPGTM', 58, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 245, 'Subscription payment 252', '2026-07-02 09:00:00'),
('01K2F2DKG0F8J9VV2NX7YYPGTM', 58, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 245, 'Subscription payment 252', '2026-07-05 09:00:00'),
('01K2F2DKG0F8J9VV2NX7YYPGTM', 58, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 245, 'Subscription payment 252', '2026-06-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(253, '01K2F2DKG0T5TYG1XQ5YNQ92WQ', 'LF-INV-2026000253', 58, 46, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-28 09:00:00', '2026-06-11 09:00:00', '2026-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000253.pdf', '2026-05-28 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(253, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-28', '2026-06-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(246, '01K2F2DKG0GSHZYC7FW40ZSS4H', 'PAY-60246', 58, 253, 46, 46, 194, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0za63naftxeygxpx0', 'idem-01K2F2DKG0E9R72ZWF9C8TBPNS', 'https://cdn.livfinder.com/receipts/PAY-60246.pdf', '2026-06-07 09:00:00', '2026-06-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG07EFGVJK43VWKTBQG', 58, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 246, 'Subscription payment 253', '2026-06-02 09:00:00'),
('01K2F2DKG07EFGVJK43VWKTBQG', 58, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 246, 'Subscription payment 253', '2026-06-06 09:00:00'),
('01K2F2DKG07EFGVJK43VWKTBQG', 58, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 246, 'Subscription payment 253', '2026-05-31 09:00:00'),
('01K2F2DKG07EFGVJK43VWKTBQG', 58, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 246, 'Subscription payment 253', '2026-06-09 09:00:00'),
('01K2F2DKG07EFGVJK43VWKTBQG', 58, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 246, 'Subscription payment 253', '2026-05-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(254, '01K2F2DKG0B394EQ7XNJ98MH2B', 'LF-INV-2026000254', 58, 46, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-28 09:00:00', '2026-05-12 09:00:00', '2026-05-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000254.pdf', '2026-04-28 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(254, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-28', '2026-05-28', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(247, '01K2F2DKG0C831TW7V24T806J7', 'PAY-60247', 58, 254, 46, 46, 194, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0pfw984fbkdjj1ejq', 'idem-01K2F2DKG0G4H3SPRT8GABJFBQ', 'https://cdn.livfinder.com/receipts/PAY-60247.pdf', '2026-05-04 09:00:00', '2026-05-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0AFGZ1K15KV8EGSA8', 58, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 247, 'Subscription payment 254', '2026-05-03 09:00:00'),
('01K2F2DKG0AFGZ1K15KV8EGSA8', 58, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 247, 'Subscription payment 254', '2026-05-05 09:00:00'),
('01K2F2DKG0AFGZ1K15KV8EGSA8', 58, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 247, 'Subscription payment 254', '2026-05-05 09:00:00'),
('01K2F2DKG0AFGZ1K15KV8EGSA8', 58, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 247, 'Subscription payment 254', '2026-04-28 09:00:00'),
('01K2F2DKG0AFGZ1K15KV8EGSA8', 58, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 247, 'Subscription payment 254', '2026-05-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(255, '01K2F2DKG0VX5K9VHSGAEV9TMJ', 'LF-INV-2026000255', 58, 46, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-29 09:00:00', '2026-04-12 09:00:00', '2026-04-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000255.pdf', '2026-03-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(255, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-29', '2026-04-28', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(248, '01K2F2DKG0MC0815T4Q2KJJH6K', 'PAY-60248', 58, 255, 46, 46, 194, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg050y7m147xnbdvbwx', 'idem-01K2F2DKG0ZCWMT9D8Q712ME2T', 'https://cdn.livfinder.com/receipts/PAY-60248.pdf', '2026-04-01 09:00:00', '2026-04-08 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TCH9Q37YTTXZFP5C', 58, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 248, 'Subscription payment 255', '2026-04-03 09:00:00'),
('01K2F2DKG0TCH9Q37YTTXZFP5C', 58, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 248, 'Subscription payment 255', '2026-04-05 09:00:00'),
('01K2F2DKG0TCH9Q37YTTXZFP5C', 58, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 248, 'Subscription payment 255', '2026-04-05 09:00:00'),
('01K2F2DKG0TCH9Q37YTTXZFP5C', 58, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 248, 'Subscription payment 255', '2026-04-09 09:00:00'),
('01K2F2DKG0TCH9Q37YTTXZFP5C', 58, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 248, 'Subscription payment 255', '2026-03-31 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(256, '01K2F2DKG0ZYE12PHCDCKNT5B9', 'LF-INV-2026000256', 58, 46, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-27 09:00:00', '2026-03-13 09:00:00', '2026-02-27 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000256.pdf', '2026-02-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(256, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-27', '2026-03-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(249, '01K2F2DKG0PS6HG8V7DH4T91XW', 'PAY-60249', 58, 256, 46, 46, 194, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rcga166974fsp6gt', 'idem-01K2F2DKG0HY9KG5J642HDG3Y8', 'https://cdn.livfinder.com/receipts/PAY-60249.pdf', '2026-02-28 09:00:00', '2026-03-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0FZ23313JH289XWKB', 58, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 249, 'Subscription payment 256', '2026-03-06 09:00:00'),
('01K2F2DKG0FZ23313JH289XWKB', 58, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 249, 'Subscription payment 256', '2026-03-03 09:00:00'),
('01K2F2DKG0FZ23313JH289XWKB', 58, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 249, 'Subscription payment 256', '2026-03-10 09:00:00'),
('01K2F2DKG0FZ23313JH289XWKB', 58, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 249, 'Subscription payment 256', '2026-03-03 09:00:00'),
('01K2F2DKG0FZ23313JH289XWKB', 58, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 249, 'Subscription payment 256', '2026-03-06 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(58, 'listing', 20, 20, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-03 09:00:00'),
(58, 'listing', -1, 19, 'consumption', 'listing', NULL, 'Listing published', '2026-04-27 09:00:00'),
(58, 'listing', -2, 17, 'consumption', 'listing', NULL, 'Listing published', '2025-11-14 09:00:00'),
(58, 'listing', -1, 16, 'consumption', 'listing', NULL, 'Listing published', '2026-02-17 09:00:00'),
(58, 'listing', -1, 15, 'consumption', 'listing', NULL, 'Listing published', '2026-06-24 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(47, '01K2F2DKG0XQ4ZKM3QPJ2H4PX5', 80, 216, 'card', 'stripe', 'pm_01k2f2dkg00r8ym0xwp7n5vq24', 'mastercard', '5015', 12, 2030, 'Card Holder', 1, 'active', '2025-07-31 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(47, '01K2F2DKG0E0XPZZC2Q0CQDVQJ', 80, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-08-15 09:00:00', '2026-09-14 09:00:00', NULL, NULL, 1, 47, 'sub_01k2f2dkg013r3whcf7zp7fyyp', '2024-03-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(257, '01K2F2DKG004HMDV9G0XC8TZCV', 'LF-INV-2026000257', 80, 47, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-16 09:00:00', '2026-07-30 09:00:00', '2026-07-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000257.pdf', '2026-07-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(257, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-16', '2026-08-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(250, '01K2F2DKG0EYJ1GM04B1WP50C1', 'PAY-60250', 80, 257, 47, 47, 216, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mbrqghcax9x07fm8', 'idem-01K2F2DKG00HF57Y64QYFNBK0K', 'https://cdn.livfinder.com/receipts/PAY-60250.pdf', '2026-07-27 09:00:00', '2026-07-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG061TNN9QYPN9REB9S', 80, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 250, 'Subscription payment 257', '2026-07-16 09:00:00'),
('01K2F2DKG061TNN9QYPN9REB9S', 80, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 250, 'Subscription payment 257', '2026-07-27 09:00:00'),
('01K2F2DKG061TNN9QYPN9REB9S', 80, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 250, 'Subscription payment 257', '2026-07-19 09:00:00'),
('01K2F2DKG061TNN9QYPN9REB9S', 80, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 250, 'Subscription payment 257', '2026-07-25 09:00:00'),
('01K2F2DKG061TNN9QYPN9REB9S', 80, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 250, 'Subscription payment 257', '2026-07-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(258, '01K2F2DKG0HZTM9BGJJCSVPFZQ', 'LF-INV-2026000258', 80, 47, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-16 09:00:00', '2026-06-30 09:00:00', '2026-06-23 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000258.pdf', '2026-06-16 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(258, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-16', '2026-07-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(251, '01K2F2DKG0TKABCBYMVW325586', 'PAY-60251', 80, 258, 47, 47, 216, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg02ra81c18mraey08e', 'idem-01K2F2DKG03N9JM19E6NE5HK0X', 'https://cdn.livfinder.com/receipts/PAY-60251.pdf', '2026-06-26 09:00:00', '2026-06-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0MXM2X19KBA864VPE', 80, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 251, 'Subscription payment 258', '2026-06-27 09:00:00'),
('01K2F2DKG0MXM2X19KBA864VPE', 80, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 251, 'Subscription payment 258', '2026-06-21 09:00:00'),
('01K2F2DKG0MXM2X19KBA864VPE', 80, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 251, 'Subscription payment 258', '2026-06-27 09:00:00'),
('01K2F2DKG0MXM2X19KBA864VPE', 80, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 251, 'Subscription payment 258', '2026-06-27 09:00:00'),
('01K2F2DKG0MXM2X19KBA864VPE', 80, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 251, 'Subscription payment 258', '2026-06-25 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(259, '01K2F2DKG0PREVPT3Z7AE15JC5', 'LF-INV-2026000259', 80, 47, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-17 09:00:00', '2026-05-31 09:00:00', '2026-05-25 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000259.pdf', '2026-05-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(259, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-17', '2026-06-16', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(252, '01K2F2DKG08ZTZC5A7M0ZYTC85', 'PAY-60252', 80, 259, 47, 47, 216, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03yd5jh9kvgnqkz8g', 'idem-01K2F2DKG05ETKBHDRX9S3YNMP', 'https://cdn.livfinder.com/receipts/PAY-60252.pdf', '2026-05-21 09:00:00', '2026-05-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0F11EW1PCNVZW9Y09', 80, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 252, 'Subscription payment 259', '2026-05-23 09:00:00'),
('01K2F2DKG0F11EW1PCNVZW9Y09', 80, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 252, 'Subscription payment 259', '2026-05-18 09:00:00'),
('01K2F2DKG0F11EW1PCNVZW9Y09', 80, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 252, 'Subscription payment 259', '2026-05-17 09:00:00'),
('01K2F2DKG0F11EW1PCNVZW9Y09', 80, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 252, 'Subscription payment 259', '2026-05-25 09:00:00'),
('01K2F2DKG0F11EW1PCNVZW9Y09', 80, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 252, 'Subscription payment 259', '2026-05-22 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(260, '01K2F2DKG0HVBCPMRWT227TJSV', 'LF-INV-2026000260', 80, 47, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-17 09:00:00', '2026-05-01 09:00:00', '2026-04-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000260.pdf', '2026-04-17 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(260, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-17', '2026-05-17', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(253, '01K2F2DKG0586625QNW4WQ1FQZ', 'PAY-60253', 80, 260, 47, 47, 216, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rpkjk57vaj1gxmys', 'idem-01K2F2DKG0QHTB06SGAMGC6Y0C', 'https://cdn.livfinder.com/receipts/PAY-60253.pdf', '2026-04-18 09:00:00', '2026-04-24 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Z0E6JAE4JHJPAC48', 80, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 253, 'Subscription payment 260', '2026-04-19 09:00:00'),
('01K2F2DKG0Z0E6JAE4JHJPAC48', 80, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 253, 'Subscription payment 260', '2026-04-29 09:00:00'),
('01K2F2DKG0Z0E6JAE4JHJPAC48', 80, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 253, 'Subscription payment 260', '2026-04-18 09:00:00'),
('01K2F2DKG0Z0E6JAE4JHJPAC48', 80, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 253, 'Subscription payment 260', '2026-04-24 09:00:00'),
('01K2F2DKG0Z0E6JAE4JHJPAC48', 80, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 253, 'Subscription payment 260', '2026-04-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(80, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-04-24 09:00:00'),
(80, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-10-25 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(48, '01K2F2DKG0354Q63FAZ2W9NGV4', 84, 220, 'card', 'stripe', 'pm_01k2f2dkg0gmj1gsnxm2nt095g', 'amex', '6271', 4, 2031, 'Card Holder', 1, 'active', '2025-08-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(48, '01K2F2DKG08DNQSCY8JDJTPFCN', 84, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-07-25 09:00:00', '2026-08-24 09:00:00', NULL, NULL, 1, 48, 'sub_01k2f2dkg0w1w08ys94hy0kagh', '2025-06-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(261, '01K2F2DKG0RHVWW3PGE8BN660S', 'LF-INV-2026000261', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-25 09:00:00', '2026-07-09 09:00:00', '2026-06-30 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000261.pdf', '2026-06-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(261, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-25', '2026-07-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(254, '01K2F2DKG0FCGBFVBN3R8W1SJW', 'PAY-60254', 84, 261, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg04mfhhf7w85yxkw59', 'idem-01K2F2DKG0JXS8RD3MRATG2NWP', 'https://cdn.livfinder.com/receipts/PAY-60254.pdf', '2026-07-06 09:00:00', '2026-07-02 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0575B74JAEWB7PWBS', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 254, 'Subscription payment 261', '2026-07-01 09:00:00'),
('01K2F2DKG0575B74JAEWB7PWBS', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 254, 'Subscription payment 261', '2026-06-26 09:00:00'),
('01K2F2DKG0575B74JAEWB7PWBS', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 254, 'Subscription payment 261', '2026-06-27 09:00:00'),
('01K2F2DKG0575B74JAEWB7PWBS', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 254, 'Subscription payment 261', '2026-06-29 09:00:00'),
('01K2F2DKG0575B74JAEWB7PWBS', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 254, 'Subscription payment 261', '2026-07-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(262, '01K2F2DKG0QA3KJTNF2Q2065N3', 'LF-INV-2026000262', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-26 09:00:00', '2026-06-09 09:00:00', '2026-05-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000262.pdf', '2026-05-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(262, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-26', '2026-06-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(255, '01K2F2DKG07MD0K5FSZ6436V6R', 'PAY-60255', 84, 262, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0swnnrarskrmc0e2d', 'idem-01K2F2DKG06D4DBN2AZ00Q1YFF', 'https://cdn.livfinder.com/receipts/PAY-60255.pdf', '2026-06-02 09:00:00', '2026-06-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04YK0NJ9W6CYBVSG9', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 255, 'Subscription payment 262', '2026-05-31 09:00:00'),
('01K2F2DKG04YK0NJ9W6CYBVSG9', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 255, 'Subscription payment 262', '2026-06-02 09:00:00'),
('01K2F2DKG04YK0NJ9W6CYBVSG9', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 255, 'Subscription payment 262', '2026-05-27 09:00:00'),
('01K2F2DKG04YK0NJ9W6CYBVSG9', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 255, 'Subscription payment 262', '2026-06-02 09:00:00'),
('01K2F2DKG04YK0NJ9W6CYBVSG9', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 255, 'Subscription payment 262', '2026-05-28 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(263, '01K2F2DKG0F99H1QWME998EAQX', 'LF-INV-2026000263', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-26 09:00:00', '2026-05-10 09:00:00', '2026-04-27 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000263.pdf', '2026-04-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(263, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-26', '2026-05-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(256, '01K2F2DKG0H2ZQCYCR637YFYKT', 'PAY-60256', 84, 263, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0h03r7v7vq635wy9t', 'idem-01K2F2DKG0H4BXY15CRDCJV9A8', 'https://cdn.livfinder.com/receipts/PAY-60256.pdf', '2026-04-29 09:00:00', '2026-04-29 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0Z34WN508EPEX7B85', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 256, 'Subscription payment 263', '2026-04-27 09:00:00'),
('01K2F2DKG0Z34WN508EPEX7B85', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 256, 'Subscription payment 263', '2026-05-07 09:00:00'),
('01K2F2DKG0Z34WN508EPEX7B85', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 256, 'Subscription payment 263', '2026-05-04 09:00:00'),
('01K2F2DKG0Z34WN508EPEX7B85', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 256, 'Subscription payment 263', '2026-04-27 09:00:00'),
('01K2F2DKG0Z34WN508EPEX7B85', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 256, 'Subscription payment 263', '2026-04-27 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(264, '01K2F2DKG08XW7WS322DV0DV47', 'LF-INV-2026000264', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-27 09:00:00', '2026-04-10 09:00:00', '2026-04-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000264.pdf', '2026-03-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(264, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-27', '2026-04-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(257, '01K2F2DKG0H5FW1JDFT0T5J8S1', 'PAY-60257', 84, 264, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06vg97jnddhzqeq9a', 'idem-01K2F2DKG02MNNQGGG40N88FJT', 'https://cdn.livfinder.com/receipts/PAY-60257.pdf', '2026-04-08 09:00:00', '2026-04-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG07MWMR0C60BDPH6VX', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 257, 'Subscription payment 264', '2026-04-07 09:00:00'),
('01K2F2DKG07MWMR0C60BDPH6VX', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 257, 'Subscription payment 264', '2026-03-29 09:00:00'),
('01K2F2DKG07MWMR0C60BDPH6VX', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 257, 'Subscription payment 264', '2026-04-08 09:00:00'),
('01K2F2DKG07MWMR0C60BDPH6VX', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 257, 'Subscription payment 264', '2026-03-30 09:00:00'),
('01K2F2DKG07MWMR0C60BDPH6VX', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 257, 'Subscription payment 264', '2026-04-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(265, '01K2F2DKG0NEB1VF0GG4F1D2FB', 'LF-INV-2026000265', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-25 09:00:00', '2026-03-11 09:00:00', '2026-03-09 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000265.pdf', '2026-02-25 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(265, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-25', '2026-03-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(258, '01K2F2DKG0DRCWQ7ZM9EWRKE3P', 'PAY-60258', 84, 265, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0f9399ycstqqr94sm', 'idem-01K2F2DKG0VM8NN412B25F9YSZ', 'https://cdn.livfinder.com/receipts/PAY-60258.pdf', '2026-03-04 09:00:00', '2026-03-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V6EW9955SSM1CB6Z', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 258, 'Subscription payment 265', '2026-03-02 09:00:00'),
('01K2F2DKG0V6EW9955SSM1CB6Z', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 258, 'Subscription payment 265', '2026-03-02 09:00:00'),
('01K2F2DKG0V6EW9955SSM1CB6Z', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 258, 'Subscription payment 265', '2026-02-28 09:00:00'),
('01K2F2DKG0V6EW9955SSM1CB6Z', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 258, 'Subscription payment 265', '2026-03-01 09:00:00'),
('01K2F2DKG0V6EW9955SSM1CB6Z', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 258, 'Subscription payment 265', '2026-03-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(266, '01K2F2DKG0PE4T5WSNSDR29281', 'LF-INV-2026000266', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-01-26 09:00:00', '2026-02-09 09:00:00', '2026-02-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000266.pdf', '2026-01-26 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(266, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-01-26', '2026-02-25', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(259, '01K2F2DKG0SBHXHCQNA439JXNK', 'PAY-60259', 84, 266, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gnvkyez4f8yz71f2', 'idem-01K2F2DKG0VG2K4X1FGSJ8JHAH', 'https://cdn.livfinder.com/receipts/PAY-60259.pdf', '2026-02-02 09:00:00', '2026-02-07 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG09QCVHT2FNV3QW8PE', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 259, 'Subscription payment 266', '2026-02-06 09:00:00'),
('01K2F2DKG09QCVHT2FNV3QW8PE', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 259, 'Subscription payment 266', '2026-02-03 09:00:00'),
('01K2F2DKG09QCVHT2FNV3QW8PE', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 259, 'Subscription payment 266', '2026-01-31 09:00:00'),
('01K2F2DKG09QCVHT2FNV3QW8PE', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 259, 'Subscription payment 266', '2026-01-30 09:00:00'),
('01K2F2DKG09QCVHT2FNV3QW8PE', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 259, 'Subscription payment 266', '2026-02-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(267, '01K2F2DKG0MT37K1XAE25CNT7W', 'LF-INV-2026000267', 84, 48, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2025-12-27 09:00:00', '2026-01-10 09:00:00', '2026-01-06 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000267.pdf', '2025-12-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(267, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2025-12-27', '2026-01-26', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(260, '01K2F2DKG025AE58NDTD94W3YW', 'PAY-60260', 84, 267, 48, 48, 220, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0mczad09z3r6yt1h8', 'idem-01K2F2DKG0Z0N66GSX2N3R0GSJ', 'https://cdn.livfinder.com/receipts/PAY-60260.pdf', '2026-01-08 09:00:00', '2026-01-06 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG07NQYHTTV53DB6N25', 84, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 260, 'Subscription payment 267', '2026-01-01 09:00:00'),
('01K2F2DKG07NQYHTTV53DB6N25', 84, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 260, 'Subscription payment 267', '2026-01-03 09:00:00'),
('01K2F2DKG07NQYHTTV53DB6N25', 84, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 260, 'Subscription payment 267', '2026-01-05 09:00:00'),
('01K2F2DKG07NQYHTTV53DB6N25', 84, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 260, 'Subscription payment 267', '2026-01-07 09:00:00'),
('01K2F2DKG07NQYHTTV53DB6N25', 84, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 260, 'Subscription payment 267', '2025-12-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(84, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-11-23 09:00:00'),
(84, 'listing', 50, 60, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-08 09:00:00'),
(84, 'listing', -1, 59, 'consumption', 'listing', NULL, 'Listing published', '2026-01-17 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(49, '01K2F2DKG0H2V487SCT5D9BV5N', 97, 233, 'card', 'stripe', 'pm_01k2f2dkg07zj2cy0fnge1z3b2', 'mastercard', '1925', 2, 2029, 'Card Holder', 1, 'active', '2025-06-05 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(49, '01K2F2DKG0MARAJ9C5Y65HYQFD', 97, 2, 'cancelled', 299.0, 'AED', 299.0, 'monthly', '2026-07-31 09:00:00', '2026-08-30 09:00:00', NULL, '2026-07-21 09:00:00', 0, 49, 'sub_01k2f2dkg0g4k97nsk44p36a2p', '2024-12-04 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(268, '01K2F2DKG08QN8SX1GE02NNZRK', 'LF-INV-2026000268', 97, 49, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-01 09:00:00', '2026-07-15 09:00:00', '2026-07-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000268.pdf', '2026-07-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(268, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-01', '2026-07-31', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(261, '01K2F2DKG0ZH7M04TXP7FF86ZG', 'PAY-60261', 97, 268, 49, 49, 233, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06xshj7acrd1m3zgz', 'idem-01K2F2DKG0ZJF9X2GCEQXZZ5YV', 'https://cdn.livfinder.com/receipts/PAY-60261.pdf', '2026-07-04 09:00:00', '2026-07-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0887DERG8HX9X0JYK', 97, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 261, 'Subscription payment 268', '2026-07-08 09:00:00'),
('01K2F2DKG0887DERG8HX9X0JYK', 97, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 261, 'Subscription payment 268', '2026-07-13 09:00:00'),
('01K2F2DKG0887DERG8HX9X0JYK', 97, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 261, 'Subscription payment 268', '2026-07-12 09:00:00'),
('01K2F2DKG0887DERG8HX9X0JYK', 97, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 261, 'Subscription payment 268', '2026-07-05 09:00:00'),
('01K2F2DKG0887DERG8HX9X0JYK', 97, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 261, 'Subscription payment 268', '2026-07-02 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(269, '01K2F2DKG0XGCBP2E1TS9Y1P46', 'LF-INV-2026000269', 97, 49, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-01 09:00:00', '2026-06-15 09:00:00', '2026-06-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000269.pdf', '2026-06-01 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(269, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-01', '2026-07-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(262, '01K2F2DKG05AQSQ18CCYSHZ2K5', 'PAY-60262', 97, 269, 49, 49, 233, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0eph133t8av079c9x', 'idem-01K2F2DKG0X1PXHP8H13FMJ2Z0', 'https://cdn.livfinder.com/receipts/PAY-60262.pdf', '2026-06-01 09:00:00', '2026-06-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG07AXVKJKP2EF3Q4NF', 97, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 262, 'Subscription payment 269', '2026-06-09 09:00:00'),
('01K2F2DKG07AXVKJKP2EF3Q4NF', 97, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 262, 'Subscription payment 269', '2026-06-05 09:00:00'),
('01K2F2DKG07AXVKJKP2EF3Q4NF', 97, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 262, 'Subscription payment 269', '2026-06-13 09:00:00'),
('01K2F2DKG07AXVKJKP2EF3Q4NF', 97, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 262, 'Subscription payment 269', '2026-06-01 09:00:00'),
('01K2F2DKG07AXVKJKP2EF3Q4NF', 97, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 262, 'Subscription payment 269', '2026-06-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(270, '01K2F2DKG0PFXRWJHB1YB3VX74', 'LF-INV-2026000270', 97, 49, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-02 09:00:00', '2026-05-16 09:00:00', '2026-05-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000270.pdf', '2026-05-02 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(270, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-02', '2026-06-01', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(263, '01K2F2DKG0FX8WKB4XK19NR12Q', 'PAY-60263', 97, 270, 49, 49, 233, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0af253rm3jjweace2', 'idem-01K2F2DKG0FHH3BAZSKA4VNGJT', 'https://cdn.livfinder.com/receipts/PAY-60263.pdf', '2026-05-02 09:00:00', '2026-05-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04MMMSB3T6CQ2F9QF', 97, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 263, 'Subscription payment 270', '2026-05-08 09:00:00'),
('01K2F2DKG04MMMSB3T6CQ2F9QF', 97, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 263, 'Subscription payment 270', '2026-05-11 09:00:00'),
('01K2F2DKG04MMMSB3T6CQ2F9QF', 97, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 263, 'Subscription payment 270', '2026-05-03 09:00:00'),
('01K2F2DKG04MMMSB3T6CQ2F9QF', 97, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 263, 'Subscription payment 270', '2026-05-11 09:00:00'),
('01K2F2DKG04MMMSB3T6CQ2F9QF', 97, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 263, 'Subscription payment 270', '2026-05-14 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(97, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-03 09:00:00'),
(97, 'listing', 50, 49, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2025-12-07 09:00:00'),
(97, 'listing', 50, 99, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-20 09:00:00'),
(97, 'listing', -2, 97, 'consumption', 'listing', NULL, 'Listing published', '2025-10-29 09:00:00'),
(97, 'listing', -1, 96, 'consumption', 'listing', NULL, 'Listing published', '2026-08-12 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(50, '01K2F2DKG0AMP61GKCDSA8DRYC', 98, 234, 'card', 'stripe', 'pm_01k2f2dkg0e5rfpn8vvrm4kmr7', 'mastercard', '4437', 11, 2029, 'Card Holder', 1, 'active', '2025-03-25 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(50, '01K2F2DKG04M512JEVHNGRYE10', 98, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-07-27 09:00:00', '2026-08-26 09:00:00', NULL, NULL, 1, 50, 'sub_01k2f2dkg0dc46abvbhy6e2qpt', '2026-04-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(271, '01K2F2DKG0SCQ2567GCR4C9GS6', 'LF-INV-2026000271', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-27 09:00:00', '2026-07-11 09:00:00', '2026-06-28 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000271.pdf', '2026-06-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(271, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-27', '2026-07-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(264, '01K2F2DKG0K7FYM51WDPV92KAZ', 'PAY-60264', 98, 271, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0r27d2swmwq044w5d', 'idem-01K2F2DKG0Z8D8ECTQEWKR1Z2D', 'https://cdn.livfinder.com/receipts/PAY-60264.pdf', '2026-07-06 09:00:00', '2026-06-28 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VPYJ6B4VYA6N4NRZ', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 264, 'Subscription payment 271', '2026-07-06 09:00:00'),
('01K2F2DKG0VPYJ6B4VYA6N4NRZ', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 264, 'Subscription payment 271', '2026-07-09 09:00:00'),
('01K2F2DKG0VPYJ6B4VYA6N4NRZ', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 264, 'Subscription payment 271', '2026-07-03 09:00:00'),
('01K2F2DKG0VPYJ6B4VYA6N4NRZ', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 264, 'Subscription payment 271', '2026-07-08 09:00:00'),
('01K2F2DKG0VPYJ6B4VYA6N4NRZ', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 264, 'Subscription payment 271', '2026-07-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(272, '01K2F2DKG094RTE0VVV647VWCF', 'LF-INV-2026000272', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-28 09:00:00', '2026-06-11 09:00:00', '2026-06-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000272.pdf', '2026-05-28 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(272, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-28', '2026-06-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(265, '01K2F2DKG0YEBVVN8KP6MPDCWQ', 'PAY-60265', 98, 272, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dxkeqtx48d36r0fh', 'idem-01K2F2DKG0VR406FZMR39VV7YN', 'https://cdn.livfinder.com/receipts/PAY-60265.pdf', '2026-06-04 09:00:00', '2026-06-09 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0T41QD10A666M3RY9', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 265, 'Subscription payment 272', '2026-06-07 09:00:00'),
('01K2F2DKG0T41QD10A666M3RY9', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 265, 'Subscription payment 272', '2026-06-05 09:00:00'),
('01K2F2DKG0T41QD10A666M3RY9', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 265, 'Subscription payment 272', '2026-05-30 09:00:00'),
('01K2F2DKG0T41QD10A666M3RY9', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 265, 'Subscription payment 272', '2026-06-04 09:00:00'),
('01K2F2DKG0T41QD10A666M3RY9', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 265, 'Subscription payment 272', '2026-06-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(273, '01K2F2DKG04H2SQ3YK758JN3T6', 'LF-INV-2026000273', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-28 09:00:00', '2026-05-12 09:00:00', '2026-05-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000273.pdf', '2026-04-28 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(273, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-28', '2026-05-28', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(266, '01K2F2DKG01CK5Q0EP378SA46M', 'PAY-60266', 98, 273, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09x8wjpt6sq1z2njb', 'idem-01K2F2DKG0KZCJFE6RH9YXHD0P', 'https://cdn.livfinder.com/receipts/PAY-60266.pdf', '2026-05-10 09:00:00', '2026-05-05 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0N9ZF9QKM0K1RY64D', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 266, 'Subscription payment 273', '2026-05-07 09:00:00'),
('01K2F2DKG0N9ZF9QKM0K1RY64D', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 266, 'Subscription payment 273', '2026-05-04 09:00:00'),
('01K2F2DKG0N9ZF9QKM0K1RY64D', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 266, 'Subscription payment 273', '2026-05-06 09:00:00'),
('01K2F2DKG0N9ZF9QKM0K1RY64D', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 266, 'Subscription payment 273', '2026-04-29 09:00:00'),
('01K2F2DKG0N9ZF9QKM0K1RY64D', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 266, 'Subscription payment 273', '2026-05-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(274, '01K2F2DKG0RTW4KK9AF2KCTQHW', 'LF-INV-2026000274', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-29 09:00:00', '2026-04-12 09:00:00', '2026-04-01 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000274.pdf', '2026-03-29 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(274, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-29', '2026-04-28', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(267, '01K2F2DKG0P9VGN880E5RPG4X2', 'PAY-60267', 98, 274, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0c51q2cdwengg60vj', 'idem-01K2F2DKG0XK686Y2593Z0MDQF', 'https://cdn.livfinder.com/receipts/PAY-60267.pdf', '2026-04-02 09:00:00', '2026-04-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG04XCSPAB44JF2NSAT', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 267, 'Subscription payment 274', '2026-04-08 09:00:00'),
('01K2F2DKG04XCSPAB44JF2NSAT', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 267, 'Subscription payment 274', '2026-04-06 09:00:00'),
('01K2F2DKG04XCSPAB44JF2NSAT', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 267, 'Subscription payment 274', '2026-04-02 09:00:00'),
('01K2F2DKG04XCSPAB44JF2NSAT', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 267, 'Subscription payment 274', '2026-03-31 09:00:00'),
('01K2F2DKG04XCSPAB44JF2NSAT', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 267, 'Subscription payment 274', '2026-04-08 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(275, '01K2F2DKG0Z3PAYCT5R7Y3RQ5H', 'LF-INV-2026000275', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-27 09:00:00', '2026-03-13 09:00:00', '2026-03-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000275.pdf', '2026-02-27 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(275, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-27', '2026-03-29', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(268, '01K2F2DKG09ZY8BJ7BN7NTMMPP', 'PAY-60268', 98, 275, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg06gmd1spt6ty9p9nk', 'idem-01K2F2DKG005AE1GFWQGE37DAE', 'https://cdn.livfinder.com/receipts/PAY-60268.pdf', '2026-03-05 09:00:00', '2026-03-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0KHNA6JKNXP2MC0KD', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 268, 'Subscription payment 275', '2026-03-07 09:00:00'),
('01K2F2DKG0KHNA6JKNXP2MC0KD', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 268, 'Subscription payment 275', '2026-03-03 09:00:00'),
('01K2F2DKG0KHNA6JKNXP2MC0KD', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 268, 'Subscription payment 275', '2026-03-04 09:00:00'),
('01K2F2DKG0KHNA6JKNXP2MC0KD', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 268, 'Subscription payment 275', '2026-03-01 09:00:00'),
('01K2F2DKG0KHNA6JKNXP2MC0KD', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 268, 'Subscription payment 275', '2026-03-07 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(276, '01K2F2DKG067JKCQKCQHCDH9BB', 'LF-INV-2026000276', 98, 50, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-01-28 09:00:00', '2026-02-11 09:00:00', '2026-02-07 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000276.pdf', '2026-01-28 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(276, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-01-28', '2026-02-27', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(269, '01K2F2DKG0WYNYKMA3WH41J6Y0', 'PAY-60269', 98, 276, 50, 50, 234, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kpwpcfdvrmy9b3qe', 'idem-01K2F2DKG0CZ02P2PTSXJ9RQ8B', 'https://cdn.livfinder.com/receipts/PAY-60269.pdf', '2026-02-08 09:00:00', '2026-02-04 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG017Y5WVRJS1FTFD5G', 98, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 269, 'Subscription payment 276', '2026-02-05 09:00:00'),
('01K2F2DKG017Y5WVRJS1FTFD5G', 98, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 269, 'Subscription payment 276', '2026-02-05 09:00:00'),
('01K2F2DKG017Y5WVRJS1FTFD5G', 98, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 269, 'Subscription payment 276', '2026-01-29 09:00:00'),
('01K2F2DKG017Y5WVRJS1FTFD5G', 98, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 269, 'Subscription payment 276', '2026-01-28 09:00:00'),
('01K2F2DKG017Y5WVRJS1FTFD5G', 98, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 269, 'Subscription payment 276', '2026-01-28 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(98, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-12-10 09:00:00'),
(98, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-03-18 09:00:00'),
(98, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-01-26 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(51, '01K2F2DKG0MFQ6ZHDQGS5Z6FVY', 124, 260, 'card', 'stripe', 'pm_01k2f2dkg0f46qcv42ndc4w28r', 'visa', '9477', 9, 2028, 'Card Holder', 1, 'active', '2026-05-31 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(51, '01K2F2DKG0VRCT6TFRFEB9ZM4B', 124, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-08-12 09:00:00', '2026-09-11 09:00:00', NULL, NULL, 1, 51, 'sub_01k2f2dkg0qf23hcvn7z5683a7', '2025-02-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(277, '01K2F2DKG0EY42HCRQZTYY3KKB', 'LF-INV-2026000277', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-13 09:00:00', '2026-07-27 09:00:00', '2026-07-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000277.pdf', '2026-07-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(277, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-13', '2026-08-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(270, '01K2F2DKG0N5S6JTZA33F4Y4C7', 'PAY-60270', 124, 277, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg012dr1qhv8g92a615', 'idem-01K2F2DKG09C1T65DCCW4J3HRB', 'https://cdn.livfinder.com/receipts/PAY-60270.pdf', '2026-07-16 09:00:00', '2026-07-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0ZF8MGAVFWPWYD9XN', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 270, 'Subscription payment 277', '2026-07-19 09:00:00'),
('01K2F2DKG0ZF8MGAVFWPWYD9XN', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 270, 'Subscription payment 277', '2026-07-24 09:00:00'),
('01K2F2DKG0ZF8MGAVFWPWYD9XN', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 270, 'Subscription payment 277', '2026-07-15 09:00:00'),
('01K2F2DKG0ZF8MGAVFWPWYD9XN', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 270, 'Subscription payment 277', '2026-07-20 09:00:00'),
('01K2F2DKG0ZF8MGAVFWPWYD9XN', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 270, 'Subscription payment 277', '2026-07-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(278, '01K2F2DKG0229WJSKYGRV83YE0', 'LF-INV-2026000278', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-13 09:00:00', '2026-06-27 09:00:00', '2026-06-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000278.pdf', '2026-06-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(278, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-13', '2026-07-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(271, '01K2F2DKG0RY9TQB561RRAZZAD', 'PAY-60271', 124, 278, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0fw4g7ccq0ab69hvp', 'idem-01K2F2DKG0HB23MCS744YEA90Y', 'https://cdn.livfinder.com/receipts/PAY-60271.pdf', '2026-06-18 09:00:00', '2026-06-13 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GTWY66VQTHBEWENX', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 271, 'Subscription payment 278', '2026-06-25 09:00:00'),
('01K2F2DKG0GTWY66VQTHBEWENX', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 271, 'Subscription payment 278', '2026-06-23 09:00:00'),
('01K2F2DKG0GTWY66VQTHBEWENX', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 271, 'Subscription payment 278', '2026-06-23 09:00:00'),
('01K2F2DKG0GTWY66VQTHBEWENX', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 271, 'Subscription payment 278', '2026-06-18 09:00:00'),
('01K2F2DKG0GTWY66VQTHBEWENX', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 271, 'Subscription payment 278', '2026-06-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(279, '01K2F2DKG0Z7XZNR0FFBZP5SKM', 'LF-INV-2026000279', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-14 09:00:00', '2026-05-28 09:00:00', '2026-05-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000279.pdf', '2026-05-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(279, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-14', '2026-06-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(272, '01K2F2DKG0Y2FCE7TCHFY1DR2A', 'PAY-60272', 124, 279, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0zfmcb8awekfnt7be', 'idem-01K2F2DKG08XA0N1R1J2GQ6PP7', 'https://cdn.livfinder.com/receipts/PAY-60272.pdf', '2026-05-25 09:00:00', '2026-05-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GZG29VM47BKA9YN9', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 272, 'Subscription payment 279', '2026-05-23 09:00:00'),
('01K2F2DKG0GZG29VM47BKA9YN9', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 272, 'Subscription payment 279', '2026-05-22 09:00:00'),
('01K2F2DKG0GZG29VM47BKA9YN9', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 272, 'Subscription payment 279', '2026-05-14 09:00:00'),
('01K2F2DKG0GZG29VM47BKA9YN9', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 272, 'Subscription payment 279', '2026-05-17 09:00:00'),
('01K2F2DKG0GZG29VM47BKA9YN9', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 272, 'Subscription payment 279', '2026-05-15 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(280, '01K2F2DKG0Y6Q6ZA6R69NPVKJ0', 'LF-INV-2026000280', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-14 09:00:00', '2026-04-28 09:00:00', '2026-04-16 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000280.pdf', '2026-04-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(280, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-14', '2026-05-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(273, '01K2F2DKG0XA2X6EWXWJZGCWVR', 'PAY-60273', 124, 280, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg09gjgn0fhew7zhapc', 'idem-01K2F2DKG0FY8FKCB272GPVWQB', 'https://cdn.livfinder.com/receipts/PAY-60273.pdf', '2026-04-14 09:00:00', '2026-04-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XEJPSKW4DV5FQV7M', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 273, 'Subscription payment 280', '2026-04-25 09:00:00'),
('01K2F2DKG0XEJPSKW4DV5FQV7M', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 273, 'Subscription payment 280', '2026-04-21 09:00:00'),
('01K2F2DKG0XEJPSKW4DV5FQV7M', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 273, 'Subscription payment 280', '2026-04-24 09:00:00'),
('01K2F2DKG0XEJPSKW4DV5FQV7M', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 273, 'Subscription payment 280', '2026-04-22 09:00:00'),
('01K2F2DKG0XEJPSKW4DV5FQV7M', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 273, 'Subscription payment 280', '2026-04-20 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(281, '01K2F2DKG0VQ95TZ632SJFWKPR', 'LF-INV-2026000281', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-15 09:00:00', '2026-03-29 09:00:00', '2026-03-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000281.pdf', '2026-03-15 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(281, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-15', '2026-04-14', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(274, '01K2F2DKG058K8AHGQGHZ32S19', 'PAY-60274', 124, 281, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0npey8wkzg4y93ktn', 'idem-01K2F2DKG06THMP6NMMR8RKWVH', 'https://cdn.livfinder.com/receipts/PAY-60274.pdf', '2026-03-17 09:00:00', '2026-03-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XD4XGRYREXAV9S0Y', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 274, 'Subscription payment 281', '2026-03-27 09:00:00'),
('01K2F2DKG0XD4XGRYREXAV9S0Y', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 274, 'Subscription payment 281', '2026-03-17 09:00:00'),
('01K2F2DKG0XD4XGRYREXAV9S0Y', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 274, 'Subscription payment 281', '2026-03-21 09:00:00'),
('01K2F2DKG0XD4XGRYREXAV9S0Y', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 274, 'Subscription payment 281', '2026-03-21 09:00:00'),
('01K2F2DKG0XD4XGRYREXAV9S0Y', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 274, 'Subscription payment 281', '2026-03-23 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(282, '01K2F2DKG0ATDHG0F18V3PHYJF', 'LF-INV-2026000282', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-13 09:00:00', '2026-02-27 09:00:00', '2026-02-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000282.pdf', '2026-02-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(282, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-13', '2026-03-15', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(275, '01K2F2DKG05S77RD87A0RRQ62X', 'PAY-60275', 124, 282, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0tneqb2g6q8j47q85', 'idem-01K2F2DKG0FYPNMD8FCECZFNPK', 'https://cdn.livfinder.com/receipts/PAY-60275.pdf', '2026-02-17 09:00:00', '2026-02-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0B9DK86Q3GFN9NSEX', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 275, 'Subscription payment 282', '2026-02-16 09:00:00'),
('01K2F2DKG0B9DK86Q3GFN9NSEX', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 275, 'Subscription payment 282', '2026-02-21 09:00:00'),
('01K2F2DKG0B9DK86Q3GFN9NSEX', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 275, 'Subscription payment 282', '2026-02-24 09:00:00'),
('01K2F2DKG0B9DK86Q3GFN9NSEX', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 275, 'Subscription payment 282', '2026-02-22 09:00:00'),
('01K2F2DKG0B9DK86Q3GFN9NSEX', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 275, 'Subscription payment 282', '2026-02-13 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(283, '01K2F2DKG079BDGH6K7YTA68KM', 'LF-INV-2026000283', 124, 51, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-01-14 09:00:00', '2026-01-28 09:00:00', '2026-01-22 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000283.pdf', '2026-01-14 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(283, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-01-14', '2026-02-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(276, '01K2F2DKG0DYWP78H15KQ8A8FF', 'PAY-60276', 124, 283, 51, 51, 260, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03yhqy9h2jwcsrqmj', 'idem-01K2F2DKG0YC12PD6NZJGKM36V', 'https://cdn.livfinder.com/receipts/PAY-60276.pdf', '2026-01-17 09:00:00', '2026-01-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0NDQ47RXM3ZYWGP6T', 124, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 276, 'Subscription payment 283', '2026-01-22 09:00:00'),
('01K2F2DKG0NDQ47RXM3ZYWGP6T', 124, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 276, 'Subscription payment 283', '2026-01-19 09:00:00'),
('01K2F2DKG0NDQ47RXM3ZYWGP6T', 124, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 276, 'Subscription payment 283', '2026-01-26 09:00:00'),
('01K2F2DKG0NDQ47RXM3ZYWGP6T', 124, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 276, 'Subscription payment 283', '2026-01-26 09:00:00'),
('01K2F2DKG0NDQ47RXM3ZYWGP6T', 124, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 276, 'Subscription payment 283', '2026-01-18 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(124, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-02 09:00:00'),
(124, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2026-01-01 09:00:00'),
(124, 'listing', 50, 59, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-02-26 09:00:00'),
(124, 'listing', -1, 58, 'consumption', 'listing', NULL, 'Listing published', '2026-03-29 09:00:00'),
(124, 'listing', 50, 108, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-29 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(52, '01K2F2DKG052HJB45MZWZXMSCJ', 126, 262, 'card', 'stripe', 'pm_01k2f2dkg0jbc61k7q838e7anz', 'amex', '8009', 9, 2029, 'Card Holder', 1, 'active', '2025-09-19 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(52, '01K2F2DKG09B31SCB5PM8NTWQZ', 126, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-08-04 09:00:00', '2026-09-03 09:00:00', NULL, NULL, 1, 52, 'sub_01k2f2dkg0v23n2p93m9fcpvv5', '2024-02-19 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(284, '01K2F2DKG01F4PKPD5WHAYZRTY', 'LF-INV-2026000284', 126, 52, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-05 09:00:00', '2026-07-19 09:00:00', '2026-07-08 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000284.pdf', '2026-07-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(284, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-05', '2026-08-04', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(277, '01K2F2DKG0SSS35E4J8N4FRMRZ', 'PAY-60277', 126, 284, 52, 52, 262, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0e3ew15ecw5nmz7ey', 'idem-01K2F2DKG06N12VH72TS1BYGFP', 'https://cdn.livfinder.com/receipts/PAY-60277.pdf', '2026-07-16 09:00:00', '2026-07-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0D17QQQ06GJDQEE6R', 126, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 277, 'Subscription payment 284', '2026-07-16 09:00:00'),
('01K2F2DKG0D17QQQ06GJDQEE6R', 126, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 277, 'Subscription payment 284', '2026-07-11 09:00:00'),
('01K2F2DKG0D17QQQ06GJDQEE6R', 126, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 277, 'Subscription payment 284', '2026-07-14 09:00:00'),
('01K2F2DKG0D17QQQ06GJDQEE6R', 126, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 277, 'Subscription payment 284', '2026-07-11 09:00:00'),
('01K2F2DKG0D17QQQ06GJDQEE6R', 126, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 277, 'Subscription payment 284', '2026-07-06 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(285, '01K2F2DKG018CK3PJTHX36YK5C', 'LF-INV-2026000285', 126, 52, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-05 09:00:00', '2026-06-19 09:00:00', '2026-06-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000285.pdf', '2026-06-05 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(285, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-05', '2026-07-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(278, '01K2F2DKG0P29WHHPS7F6QFDS9', 'PAY-60278', 126, 285, 52, 52, 262, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0kcrpxtm73z1wqj2q', 'idem-01K2F2DKG019Y8JKZQPRRE5VNF', 'https://cdn.livfinder.com/receipts/PAY-60278.pdf', '2026-06-07 09:00:00', '2026-06-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TGWQHJ1FJAXCJK33', 126, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 278, 'Subscription payment 285', '2026-06-11 09:00:00'),
('01K2F2DKG0TGWQHJ1FJAXCJK33', 126, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 278, 'Subscription payment 285', '2026-06-05 09:00:00'),
('01K2F2DKG0TGWQHJ1FJAXCJK33', 126, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 278, 'Subscription payment 285', '2026-06-15 09:00:00'),
('01K2F2DKG0TGWQHJ1FJAXCJK33', 126, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 278, 'Subscription payment 285', '2026-06-06 09:00:00'),
('01K2F2DKG0TGWQHJ1FJAXCJK33', 126, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 278, 'Subscription payment 285', '2026-06-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(286, '01K2F2DKG0FPCP62KGVGRC4AYP', 'LF-INV-2026000286', 126, 52, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-06 09:00:00', '2026-05-20 09:00:00', '2026-05-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000286.pdf', '2026-05-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(286, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-06', '2026-06-05', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(279, '01K2F2DKG0XGA32D1T465FAZYE', 'PAY-60279', 126, 286, 52, 52, 262, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg05vv630b09jjpf190', 'idem-01K2F2DKG0JQ3796W19CV03RC6', 'https://cdn.livfinder.com/receipts/PAY-60279.pdf', '2026-05-12 09:00:00', '2026-05-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TMFZ5FTAN5G8G3DJ', 126, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 279, 'Subscription payment 286', '2026-05-08 09:00:00'),
('01K2F2DKG0TMFZ5FTAN5G8G3DJ', 126, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 279, 'Subscription payment 286', '2026-05-13 09:00:00'),
('01K2F2DKG0TMFZ5FTAN5G8G3DJ', 126, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 279, 'Subscription payment 286', '2026-05-10 09:00:00'),
('01K2F2DKG0TMFZ5FTAN5G8G3DJ', 126, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 279, 'Subscription payment 286', '2026-05-11 09:00:00'),
('01K2F2DKG0TMFZ5FTAN5G8G3DJ', 126, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 279, 'Subscription payment 286', '2026-05-10 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(287, '01K2F2DKG0W1NJPRABRTBSZMJ4', 'LF-INV-2026000287', 126, 52, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-06 09:00:00', '2026-04-20 09:00:00', '2026-04-18 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000287.pdf', '2026-04-06 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(287, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-06', '2026-05-06', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(280, '01K2F2DKG0YJN2A8YSZ1T4CVMQ', 'PAY-60280', 126, 287, 52, 52, 262, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0wr49wqh5c59b1pp5', 'idem-01K2F2DKG0930D3PSVE5CRN1PD', 'https://cdn.livfinder.com/receipts/PAY-60280.pdf', '2026-04-18 09:00:00', '2026-04-18 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0DSAXCTT3BSMMHFNH', 126, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 280, 'Subscription payment 287', '2026-04-17 09:00:00'),
('01K2F2DKG0DSAXCTT3BSMMHFNH', 126, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 280, 'Subscription payment 287', '2026-04-08 09:00:00'),
('01K2F2DKG0DSAXCTT3BSMMHFNH', 126, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 280, 'Subscription payment 287', '2026-04-16 09:00:00'),
('01K2F2DKG0DSAXCTT3BSMMHFNH', 126, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 280, 'Subscription payment 287', '2026-04-14 09:00:00'),
('01K2F2DKG0DSAXCTT3BSMMHFNH', 126, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 280, 'Subscription payment 287', '2026-04-16 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(126, 'listing', 10, 10, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-04 09:00:00'),
(126, 'listing', -1, 9, 'consumption', 'listing', NULL, 'Listing published', '2026-03-21 09:00:00'),
(126, 'listing', 50, 59, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-08-01 09:00:00'),
(126, 'listing', -1, 58, 'consumption', 'listing', NULL, 'Listing published', '2026-02-18 09:00:00'),
(126, 'listing', -2, 56, 'consumption', 'listing', NULL, 'Listing published', '2026-03-27 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(53, '01K2F2DKG0JXDSH4X5XVNFGEYZ', 138, 274, 'card', 'stripe', 'pm_01k2f2dkg0ssycxdsqr72fhc9a', 'amex', '6241', 5, 2028, 'Card Holder', 1, 'active', '2025-05-04 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(53, '01K2F2DKG0012PP04KDKQ1RRJD', 138, 2, 'active', 299.0, 'AED', 299.0, 'monthly', '2026-08-10 09:00:00', '2026-09-09 09:00:00', NULL, NULL, 1, 53, 'sub_01k2f2dkg0tkzqeb85v6mtcqzv', '2026-01-05 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(288, '01K2F2DKG01D82P0TSS6ZN3SA8', 'LF-INV-2026000288', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-11 09:00:00', '2026-07-25 09:00:00', '2026-07-20 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000288.pdf', '2026-07-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(288, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-11', '2026-08-10', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(281, '01K2F2DKG0C2TFDTPWW8E5SS2M', 'PAY-60281', 138, 288, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0cfg1ez3gty5zrpqk', 'idem-01K2F2DKG0F5VKWHS877S8S412', 'https://cdn.livfinder.com/receipts/PAY-60281.pdf', '2026-07-19 09:00:00', '2026-07-22 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GPZ60ZTJ0RY64EAB', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 281, 'Subscription payment 288', '2026-07-20 09:00:00'),
('01K2F2DKG0GPZ60ZTJ0RY64EAB', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 281, 'Subscription payment 288', '2026-07-16 09:00:00'),
('01K2F2DKG0GPZ60ZTJ0RY64EAB', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 281, 'Subscription payment 288', '2026-07-22 09:00:00'),
('01K2F2DKG0GPZ60ZTJ0RY64EAB', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 281, 'Subscription payment 288', '2026-07-12 09:00:00'),
('01K2F2DKG0GPZ60ZTJ0RY64EAB', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 281, 'Subscription payment 288', '2026-07-14 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(289, '01K2F2DKG0RK0GR435ZG2NS2ZK', 'LF-INV-2026000289', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-11 09:00:00', '2026-06-25 09:00:00', '2026-06-11 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000289.pdf', '2026-06-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(289, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-11', '2026-07-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(282, '01K2F2DKG0EYJGA9PS42PDZ3XD', 'PAY-60282', 138, 289, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ab8m3rz8myrmr3qd', 'idem-01K2F2DKG0PBH8MEQRYH897C7X', 'https://cdn.livfinder.com/receipts/PAY-60282.pdf', '2026-06-21 09:00:00', '2026-06-19 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0BZACQ0ANF88TEBBR', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 282, 'Subscription payment 289', '2026-06-18 09:00:00'),
('01K2F2DKG0BZACQ0ANF88TEBBR', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 282, 'Subscription payment 289', '2026-06-21 09:00:00'),
('01K2F2DKG0BZACQ0ANF88TEBBR', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 282, 'Subscription payment 289', '2026-06-11 09:00:00'),
('01K2F2DKG0BZACQ0ANF88TEBBR', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 282, 'Subscription payment 289', '2026-06-19 09:00:00'),
('01K2F2DKG0BZACQ0ANF88TEBBR', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 282, 'Subscription payment 289', '2026-06-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(290, '01K2F2DKG0HW4Y2GBT4HW99PVQ', 'LF-INV-2026000290', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-12 09:00:00', '2026-05-26 09:00:00', '2026-05-12 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000290.pdf', '2026-05-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(290, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-12', '2026-06-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(283, '01K2F2DKG0SGXDMR769TN4650K', 'PAY-60283', 138, 290, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0rvvz7xgk777jan7w', 'idem-01K2F2DKG0KWEQBA58WEJX9P5Y', 'https://cdn.livfinder.com/receipts/PAY-60283.pdf', '2026-05-12 09:00:00', '2026-05-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0GFNHQWPECXR5EMZ3', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 283, 'Subscription payment 290', '2026-05-20 09:00:00'),
('01K2F2DKG0GFNHQWPECXR5EMZ3', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 283, 'Subscription payment 290', '2026-05-20 09:00:00'),
('01K2F2DKG0GFNHQWPECXR5EMZ3', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 283, 'Subscription payment 290', '2026-05-16 09:00:00'),
('01K2F2DKG0GFNHQWPECXR5EMZ3', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 283, 'Subscription payment 290', '2026-05-18 09:00:00'),
('01K2F2DKG0GFNHQWPECXR5EMZ3', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 283, 'Subscription payment 290', '2026-05-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(291, '01K2F2DKG0WEW4WK2G54Y006TR', 'LF-INV-2026000291', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-12 09:00:00', '2026-04-26 09:00:00', '2026-04-19 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000291.pdf', '2026-04-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(291, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-12', '2026-05-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(284, '01K2F2DKG0ZJ35GBV3F3DA5WMQ', 'PAY-60284', 138, 291, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0zpk8gmse0xfwk621', 'idem-01K2F2DKG0QKTTS1WAYQ8N0Q0G', 'https://cdn.livfinder.com/receipts/PAY-60284.pdf', '2026-04-13 09:00:00', '2026-04-21 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0H92H620NJ1H7FHT9', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 284, 'Subscription payment 291', '2026-04-24 09:00:00'),
('01K2F2DKG0H92H620NJ1H7FHT9', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 284, 'Subscription payment 291', '2026-04-21 09:00:00'),
('01K2F2DKG0H92H620NJ1H7FHT9', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 284, 'Subscription payment 291', '2026-04-14 09:00:00'),
('01K2F2DKG0H92H620NJ1H7FHT9', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 284, 'Subscription payment 291', '2026-04-18 09:00:00'),
('01K2F2DKG0H92H620NJ1H7FHT9', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 284, 'Subscription payment 291', '2026-04-16 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(292, '01K2F2DKG0W3PXF4F06ZR6GZHB', 'LF-INV-2026000292', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-03-13 09:00:00', '2026-03-27 09:00:00', '2026-03-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000292.pdf', '2026-03-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(292, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-03-13', '2026-04-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(285, '01K2F2DKG0J6ZGNRBHC8E2X3B9', 'PAY-60285', 138, 292, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0gpnc7bpg9ftg58np', 'idem-01K2F2DKG03A2JVARP46A0Q0QA', 'https://cdn.livfinder.com/receipts/PAY-60285.pdf', '2026-03-20 09:00:00', '2026-03-20 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RNVCWVQNGGX3Q3G9', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 285, 'Subscription payment 292', '2026-03-13 09:00:00'),
('01K2F2DKG0RNVCWVQNGGX3Q3G9', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 285, 'Subscription payment 292', '2026-03-13 09:00:00'),
('01K2F2DKG0RNVCWVQNGGX3Q3G9', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 285, 'Subscription payment 292', '2026-03-18 09:00:00'),
('01K2F2DKG0RNVCWVQNGGX3Q3G9', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 285, 'Subscription payment 292', '2026-03-21 09:00:00'),
('01K2F2DKG0RNVCWVQNGGX3Q3G9', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 285, 'Subscription payment 292', '2026-03-24 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(293, '01K2F2DKG0MZWADHD9PYGT00AG', 'LF-INV-2026000293', 138, 53, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-02-11 09:00:00', '2026-02-25 09:00:00', '2026-02-14 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000293.pdf', '2026-02-11 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(293, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-02-11', '2026-03-13', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(286, '01K2F2DKG0AEFJCETJQQZ6A4YA', 'PAY-60286', 138, 293, 53, 53, 274, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg03b4x8rk2shfdg2ay', 'idem-01K2F2DKG07CSNNWNJZRTZZ7W8', 'https://cdn.livfinder.com/receipts/PAY-60286.pdf', '2026-02-22 09:00:00', '2026-02-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0JXYW2657RQHZVJWA', 138, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 286, 'Subscription payment 293', '2026-02-17 09:00:00'),
('01K2F2DKG0JXYW2657RQHZVJWA', 138, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 286, 'Subscription payment 293', '2026-02-12 09:00:00'),
('01K2F2DKG0JXYW2657RQHZVJWA', 138, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 286, 'Subscription payment 293', '2026-02-20 09:00:00'),
('01K2F2DKG0JXYW2657RQHZVJWA', 138, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 286, 'Subscription payment 293', '2026-02-20 09:00:00'),
('01K2F2DKG0JXYW2657RQHZVJWA', 138, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 286, 'Subscription payment 293', '2026-02-12 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(138, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2025-10-29 09:00:00'),
(138, 'listing', 20, 19, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-03-13 09:00:00'),
(138, 'listing', 50, 69, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-04-26 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(54, '01K2F2DKG0CXMR2BY4RXHE9WVG', 146, 282, 'card', 'stripe', 'pm_01k2f2dkg0477ssvmkv3pdaa9z', 'amex', '6772', 7, 2030, 'Card Holder', 1, 'active', '2025-01-06 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(54, '01K2F2DKG0DAZE0MWKWNNSGZNQ', 146, 2, 'trialing', 299.0, 'AED', 299.0, 'monthly', '2026-07-22 09:00:00', '2026-08-21 09:00:00', '2026-08-05 09:00:00', NULL, 1, 54, 'sub_01k2f2dkg08p9d53qdw90w2em2', '2024-04-01 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(294, '01K2F2DKG012VTXJM2DMBKZH9Q', 'LF-INV-2026000294', 146, 54, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-22 09:00:00', '2026-07-06 09:00:00', '2026-07-04 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000294.pdf', '2026-06-22 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(294, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-22', '2026-07-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(287, '01K2F2DKG0TX2XFZ52T0WSF9NJ', 'PAY-60287', 146, 294, 54, 54, 282, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0dde70p1sxbcw94sy', 'idem-01K2F2DKG02TG606C65A6X0QWP', 'https://cdn.livfinder.com/receipts/PAY-60287.pdf', '2026-06-27 09:00:00', '2026-06-26 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0E7MTVNN96NT3JHDW', 146, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 287, 'Subscription payment 294', '2026-07-03 09:00:00'),
('01K2F2DKG0E7MTVNN96NT3JHDW', 146, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 287, 'Subscription payment 294', '2026-06-24 09:00:00'),
('01K2F2DKG0E7MTVNN96NT3JHDW', 146, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 287, 'Subscription payment 294', '2026-07-04 09:00:00'),
('01K2F2DKG0E7MTVNN96NT3JHDW', 146, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 287, 'Subscription payment 294', '2026-07-04 09:00:00'),
('01K2F2DKG0E7MTVNN96NT3JHDW', 146, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 287, 'Subscription payment 294', '2026-06-29 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(295, '01K2F2DKG044PWBA564E6GF06J', 'LF-INV-2026000295', 146, 54, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-23 09:00:00', '2026-06-06 09:00:00', '2026-06-02 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000295.pdf', '2026-05-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(295, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-23', '2026-06-22', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(288, '01K2F2DKG0DE66Z38TJA70AQ8C', 'PAY-60288', 146, 295, 54, 54, 282, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0918sw2hsdtyfxk2x', 'idem-01K2F2DKG07BDJCRQB74V18MDJ', 'https://cdn.livfinder.com/receipts/PAY-60288.pdf', '2026-05-24 09:00:00', '2026-05-30 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0VTFM6REJ8Y6CWBN8', 146, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 288, 'Subscription payment 295', '2026-06-01 09:00:00'),
('01K2F2DKG0VTFM6REJ8Y6CWBN8', 146, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 288, 'Subscription payment 295', '2026-05-24 09:00:00'),
('01K2F2DKG0VTFM6REJ8Y6CWBN8', 146, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 288, 'Subscription payment 295', '2026-05-23 09:00:00'),
('01K2F2DKG0VTFM6REJ8Y6CWBN8', 146, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 288, 'Subscription payment 295', '2026-05-25 09:00:00'),
('01K2F2DKG0VTFM6REJ8Y6CWBN8', 146, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 288, 'Subscription payment 295', '2026-05-26 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(296, '01K2F2DKG0C170BD8MGFMB3J45', 'LF-INV-2026000296', 146, 54, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-04-23 09:00:00', '2026-05-07 09:00:00', '2026-05-03 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000296.pdf', '2026-04-23 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(296, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-04-23', '2026-05-23', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(289, '01K2F2DKG0GX5VX3H8M5CBRF3W', 'PAY-60289', 146, 296, 54, 54, 282, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ept8vzh7mt5mfae6', 'idem-01K2F2DKG0QRT21QJSFMTJBVBY', 'https://cdn.livfinder.com/receipts/PAY-60289.pdf', '2026-04-28 09:00:00', '2026-05-01 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0EKCB0HNT1X1TQ84X', 146, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 289, 'Subscription payment 296', '2026-04-26 09:00:00'),
('01K2F2DKG0EKCB0HNT1X1TQ84X', 146, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 289, 'Subscription payment 296', '2026-04-30 09:00:00'),
('01K2F2DKG0EKCB0HNT1X1TQ84X', 146, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 289, 'Subscription payment 296', '2026-04-25 09:00:00'),
('01K2F2DKG0EKCB0HNT1X1TQ84X', 146, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 289, 'Subscription payment 296', '2026-04-28 09:00:00'),
('01K2F2DKG0EKCB0HNT1X1TQ84X', 146, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 289, 'Subscription payment 296', '2026-04-24 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(146, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-02-11 09:00:00'),
(146, 'listing', -1, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-05-26 09:00:00');

INSERT INTO payment_methods (id, public_id, account_id, user_id, method_type, provider, provider_token, brand, last_four, expiry_month, expiry_year, holder_name, is_default, status, created_at) VALUES
(55, '01K2F2DKG021BATCB5W4W8ZY8V', 182, 318, 'card', 'stripe', 'pm_01k2f2dkg0v6ggrfc9p89yb512', 'amex', '7915', 2, 2029, 'Card Holder', 1, 'active', '2025-05-24 09:00:00');

INSERT INTO subscriptions (id, public_id, account_id, plan_id, status, amount, currency_code, amount_base, billing_interval, current_period_start, current_period_end, trial_ends_at, cancelled_at, auto_renew, payment_method_id, external_reference, created_at) VALUES
(55, '01K2F2DKG0J1YP573JXRJASAE2', 182, 2, 'trialing', 299.0, 'AED', 299.0, 'monthly', '2026-08-11 09:00:00', '2026-09-10 09:00:00', '2026-08-25 09:00:00', NULL, 1, 55, 'sub_01k2f2dkg0t97zxrk1fedxxgjy', '2026-01-11 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(297, '01K2F2DKG07508TVF3T8221RQ0', 'LF-INV-2026000297', 182, 55, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-07-12 09:00:00', '2026-07-26 09:00:00', '2026-07-15 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000297.pdf', '2026-07-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(297, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-07-12', '2026-08-11', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(290, '01K2F2DKG0YVZ7TKWDE6HNCGPQ', 'PAY-60290', 182, 297, 55, 55, 318, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0xtm1f7t1araf16ja', 'idem-01K2F2DKG066PDCF1GXKAGTYBR', 'https://cdn.livfinder.com/receipts/PAY-60290.pdf', '2026-07-18 09:00:00', '2026-07-17 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WZRN8NMRSK1EESQD', 182, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 290, 'Subscription payment 297', '2026-07-12 09:00:00'),
('01K2F2DKG0WZRN8NMRSK1EESQD', 182, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 290, 'Subscription payment 297', '2026-07-12 09:00:00'),
('01K2F2DKG0WZRN8NMRSK1EESQD', 182, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 290, 'Subscription payment 297', '2026-07-13 09:00:00'),
('01K2F2DKG0WZRN8NMRSK1EESQD', 182, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 290, 'Subscription payment 297', '2026-07-20 09:00:00'),
('01K2F2DKG0WZRN8NMRSK1EESQD', 182, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 290, 'Subscription payment 297', '2026-07-21 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(298, '01K2F2DKG0NHGT157KY9EAN2M7', 'LF-INV-2026000298', 182, 55, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-06-12 09:00:00', '2026-06-26 09:00:00', '2026-06-17 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000298.pdf', '2026-06-12 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(298, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-06-12', '2026-07-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(291, '01K2F2DKG02PG8ASJ0X0H1C355', 'PAY-60291', 182, 298, 55, 55, 318, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0ktemsapt196m4vnw', 'idem-01K2F2DKG0DDA73R4VHWFKRV47', 'https://cdn.livfinder.com/receipts/PAY-60291.pdf', '2026-06-21 09:00:00', '2026-06-16 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0XBVWY9D5DZZ2Z02T', 182, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 291, 'Subscription payment 298', '2026-06-20 09:00:00'),
('01K2F2DKG0XBVWY9D5DZZ2Z02T', 182, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 291, 'Subscription payment 298', '2026-06-21 09:00:00'),
('01K2F2DKG0XBVWY9D5DZZ2Z02T', 182, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 291, 'Subscription payment 298', '2026-06-23 09:00:00'),
('01K2F2DKG0XBVWY9D5DZZ2Z02T', 182, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 291, 'Subscription payment 298', '2026-06-19 09:00:00'),
('01K2F2DKG0XBVWY9D5DZZ2Z02T', 182, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 291, 'Subscription payment 298', '2026-06-17 09:00:00');

INSERT INTO invoices (id, public_id, invoice_number, account_id, subscription_id, status, subtotal, discount_total, tax_total, total, amount_paid, amount_due, currency_code, exchange_rate, total_base, tax_rate, tax_label, billing_name, billing_email, issued_at, due_at, paid_at, pdf_url, created_at) VALUES
(299, '01K2F2DKG0B0Z1E9M0QWEDAN7Y', 'LF-INV-2026000299', 182, 55, 'paid', 299.0, 0, 14.95, 313.95, 313.95, 0.0, 'AED', 1.0, 313.95, 5.0, 'VAT', 'Account Holder', 'billing@example.com', '2026-05-13 09:00:00', '2026-05-27 09:00:00', '2026-05-13 09:00:00', 'https://cdn.livfinder.com/invoices/LF-INV-2026000299.pdf', '2026-05-13 09:00:00');

INSERT INTO invoice_lines (invoice_id, description, item_type, item_reference, quantity, unit_amount, tax_rate, tax_amount, line_total, period_start, period_end, sort_order) VALUES
(299, 'Subscription — monthly plan', 'subscription', 'plan:2', 1, 299.0, 5.0, 14.95, 313.95, '2026-05-13', '2026-06-12', 0);

INSERT INTO payments (id, public_id, reference, account_id, invoice_id, subscription_id, payment_method_id, user_id, amount, currency_code, exchange_rate, amount_base, fee_amount, net_amount, status, payment_type, provider, provider_payment_id, idempotency_key, receipt_url, paid_at, created_at) VALUES
(292, '01K2F2DKG09B2ABCNS5BSH1JBV', 'PAY-60292', 182, 299, 55, 55, 318, 313.95, 'AED', 1.0, 313.95, 10.1, 303.85, 'succeeded', 'subscription', 'stripe', 'pi_01k2f2dkg0cr622ezk0b35yhq7', 'idem-01K2F2DKG09NRS6EEXFYXFRCE1', 'https://cdn.livfinder.com/receipts/PAY-60292.pdf', '2026-05-22 09:00:00', '2026-05-14 09:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0THTGW47ZZ513V46H', 182, 'cash', 'debit', 313.95, 'AED', 313.95, 'payment', 292, 'Subscription payment 299', '2026-05-21 09:00:00'),
('01K2F2DKG0THTGW47ZZ513V46H', 182, 'revenue.subscription', 'credit', 299.0, 'AED', 299.0, 'payment', 292, 'Subscription payment 299', '2026-05-16 09:00:00'),
('01K2F2DKG0THTGW47ZZ513V46H', 182, 'tax_payable', 'credit', 14.95, 'AED', 14.95, 'payment', 292, 'Subscription payment 299', '2026-05-22 09:00:00'),
('01K2F2DKG0THTGW47ZZ513V46H', 182, 'expense.processor_fees', 'debit', 10.1, 'AED', 10.1, 'payment', 292, 'Subscription payment 299', '2026-05-24 09:00:00'),
('01K2F2DKG0THTGW47ZZ513V46H', 182, 'cash', 'credit', 10.1, 'AED', 10.1, 'payment', 292, 'Subscription payment 299', '2026-05-19 09:00:00');

INSERT INTO account_credits (account_id, credit_type, quantity, balance_after, source, reference_type, reference_id, note, created_at) VALUES
(182, 'listing', -2, 0, 'consumption', 'listing', NULL, 'Listing published', '2026-07-06 09:00:00'),
(182, 'listing', 20, 18, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-06-06 09:00:00'),
(182, 'listing', 10, 28, 'purchase', 'invoice', NULL, 'Credit pack purchase', '2026-01-04 09:00:00');

INSERT INTO payout_methods (public_id, account_id, method_type, account_holder_name, bank_name, account_last_four, swift_bic, currency_code, is_default, status, verified_at, created_at) VALUES
('01K2F2DKG0SED9BWZJF878CQ10', 11, 'bank_transfer', 'Crown Partners', 'ADCB', '7633', 'BBMEAEAD', 'AED', 1, 'active', '2025-06-28 09:00:00', '2025-10-20 09:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(1, '01K2F2DKG09PA892KJTEFP0A2D', 'PO-31001', 11, NULL, 29000, 435.0, 1450.0, 27115.0, 'AED', 1.0, 27115.0, 'processing', '2026-07-01', '2026-07-31', '2026-08-07', NULL, 'https://cdn.livfinder.com/statements/PO-31001.pdf', '2026-07-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(1, 'Commission — July 2026', 'commission', 'listing', 152, 20300.0, 'AED', '2026-07-31 00:00:00'),
(1, 'Referral — July 2026', 'referral', 'listing', 6, 5800.0, 'AED', '2026-07-31 00:00:00'),
(1, 'Bonus — July 2026', 'bonus', 'listing', 224, 2900.0, 'AED', '2026-07-31 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(2, '01K2F2DKG0N973V90AMPNKYKNG', 'PO-31002', 11, NULL, 105000, 1575.0, 5250.0, 98175.0, 'AED', 1.0, 98175.0, 'paid', '2026-06-01', '2026-06-30', '2026-07-07', '2026-07-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31002.pdf', '2026-06-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(2, 'Commission — June 2026', 'commission', 'listing', 130, 73500.0, 'AED', '2026-06-30 00:00:00'),
(2, 'Referral — June 2026', 'referral', 'listing', 388, 21000.0, 'AED', '2026-06-30 00:00:00'),
(2, 'Bonus — June 2026', 'bonus', 'listing', 405, 10500.0, 'AED', '2026-06-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0P5R5ZEW4NHWXD864', 11, 'partner_payable', 'debit', 105000, 'AED', 105000.0, 'payout', 2, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0P5R5ZEW4NHWXD864', 11, 'cash', 'credit', 98175.0, 'AED', 98175.0, 'payout', 2, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0P5R5ZEW4NHWXD864', 11, 'revenue.platform_fee', 'credit', 1575.0, 'AED', 1575.0, 'payout', 2, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0P5R5ZEW4NHWXD864', 11, 'tax_payable', 'credit', 5250.0, 'AED', 5250.0, 'payout', 2, 'Payout June 2026', '2026-07-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(3, '01K2F2DKG0NJNRJC3TE2FQHHSS', 'PO-31003', 11, NULL, 235000, 3525.0, 11750.0, 219725.0, 'AED', 1.0, 219725.0, 'paid', '2026-05-01', '2026-05-31', '2026-06-07', '2026-06-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31003.pdf', '2026-05-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(3, 'Commission — May 2026', 'commission', 'listing', 436, 164500.0, 'AED', '2026-05-31 00:00:00'),
(3, 'Referral — May 2026', 'referral', 'listing', 241, 47000.0, 'AED', '2026-05-31 00:00:00'),
(3, 'Bonus — May 2026', 'bonus', 'listing', 173, 23500.0, 'AED', '2026-05-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0P5QYZER6JGX8DA8F', 11, 'partner_payable', 'debit', 235000, 'AED', 235000.0, 'payout', 3, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0P5QYZER6JGX8DA8F', 11, 'cash', 'credit', 219725.0, 'AED', 219725.0, 'payout', 3, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0P5QYZER6JGX8DA8F', 11, 'revenue.platform_fee', 'credit', 3525.0, 'AED', 3525.0, 'payout', 3, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0P5QYZER6JGX8DA8F', 11, 'tax_payable', 'credit', 11750.0, 'AED', 11750.0, 'payout', 3, 'Payout May 2026', '2026-06-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(4, '01K2F2DKG0B8V051TS590ZQDWQ', 'PO-31004', 11, NULL, 190000, 2850.0, 9500.0, 177650.0, 'AED', 1.0, 177650.0, 'paid', '2026-04-01', '2026-04-30', '2026-05-07', '2026-05-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31004.pdf', '2026-04-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(4, 'Commission — April 2026', 'commission', 'listing', 316, 133000.0, 'AED', '2026-04-30 00:00:00'),
(4, 'Referral — April 2026', 'referral', 'listing', 75, 38000.0, 'AED', '2026-04-30 00:00:00'),
(4, 'Bonus — April 2026', 'bonus', 'listing', 174, 19000.0, 'AED', '2026-04-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0AWKZR64EM5605ZRC', 11, 'partner_payable', 'debit', 190000, 'AED', 190000.0, 'payout', 4, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0AWKZR64EM5605ZRC', 11, 'cash', 'credit', 177650.0, 'AED', 177650.0, 'payout', 4, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0AWKZR64EM5605ZRC', 11, 'revenue.platform_fee', 'credit', 2850.0, 'AED', 2850.0, 'payout', 4, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0AWKZR64EM5605ZRC', 11, 'tax_payable', 'credit', 9500.0, 'AED', 9500.0, 'payout', 4, 'Payout April 2026', '2026-05-07 00:00:00');

INSERT INTO payout_methods (public_id, account_id, method_type, account_holder_name, bank_name, account_last_four, swift_bic, currency_code, is_default, status, verified_at, created_at) VALUES
('01K2F2DKG0DS3HSY6R8C4GQF20', 21, 'bank_transfer', 'Kingsley Development', 'Emirates NBD', '1821', 'MSHQAEAD', 'EUR', 1, 'active', '2026-01-30 09:00:00', '2026-05-27 09:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(5, '01K2F2DKG0DQD45JCZ267Q2HVR', 'PO-31005', 21, NULL, 39000, 585.0, 1950.0, 36465.0, 'EUR', 3.9841, 145280.21, 'paid', '2026-07-01', '2026-07-31', '2026-08-07', '2026-08-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31005.pdf', '2026-07-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(5, 'Commission — July 2026', 'commission', 'listing', 475, 27300.0, 'EUR', '2026-07-31 00:00:00'),
(5, 'Referral — July 2026', 'referral', 'listing', 121, 7800.0, 'EUR', '2026-07-31 00:00:00'),
(5, 'Bonus — July 2026', 'bonus', 'listing', 424, 3900.0, 'EUR', '2026-07-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0RBMHXE3VBQBVB101', 21, 'partner_payable', 'debit', 39000, 'EUR', 155379.9, 'payout', 5, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0RBMHXE3VBQBVB101', 21, 'cash', 'credit', 36465.0, 'EUR', 145280.21, 'payout', 5, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0RBMHXE3VBQBVB101', 21, 'revenue.platform_fee', 'credit', 585.0, 'EUR', 2330.7, 'payout', 5, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0RBMHXE3VBQBVB101', 21, 'tax_payable', 'credit', 1950.0, 'EUR', 7769.0, 'payout', 5, 'Payout July 2026', '2026-08-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(6, '01K2F2DKG0W28WVX15MCZ87300', 'PO-31006', 21, NULL, 160000, 2400.0, 8000.0, 149600.0, 'EUR', 3.9841, 596021.36, 'paid', '2026-06-01', '2026-06-30', '2026-07-07', '2026-07-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31006.pdf', '2026-06-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(6, 'Commission — June 2026', 'commission', 'listing', 455, 112000.0, 'EUR', '2026-06-30 00:00:00'),
(6, 'Referral — June 2026', 'referral', 'listing', 501, 32000.0, 'EUR', '2026-06-30 00:00:00'),
(6, 'Bonus — June 2026', 'bonus', 'listing', 299, 16000.0, 'EUR', '2026-06-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0MS4NB194J0DMTN11', 21, 'partner_payable', 'debit', 160000, 'EUR', 637456.0, 'payout', 6, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0MS4NB194J0DMTN11', 21, 'cash', 'credit', 149600.0, 'EUR', 596021.36, 'payout', 6, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0MS4NB194J0DMTN11', 21, 'revenue.platform_fee', 'credit', 2400.0, 'EUR', 9561.84, 'payout', 6, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0MS4NB194J0DMTN11', 21, 'tax_payable', 'credit', 8000.0, 'EUR', 31872.8, 'payout', 6, 'Payout June 2026', '2026-07-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(7, '01K2F2DKG0MCA5HVK00VTQ9VE7', 'PO-31007', 21, NULL, 180000, 2700.0, 9000.0, 168300.0, 'EUR', 3.9841, 670524.03, 'paid', '2026-05-01', '2026-05-31', '2026-06-07', '2026-06-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31007.pdf', '2026-05-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(7, 'Commission — May 2026', 'commission', 'listing', 167, 126000.0, 'EUR', '2026-05-31 00:00:00'),
(7, 'Referral — May 2026', 'referral', 'listing', 179, 36000.0, 'EUR', '2026-05-31 00:00:00'),
(7, 'Bonus — May 2026', 'bonus', 'listing', 88, 18000.0, 'EUR', '2026-05-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0N1Y6WQF2B0M20RQJ', 21, 'partner_payable', 'debit', 180000, 'EUR', 717138.0, 'payout', 7, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0N1Y6WQF2B0M20RQJ', 21, 'cash', 'credit', 168300.0, 'EUR', 670524.03, 'payout', 7, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0N1Y6WQF2B0M20RQJ', 21, 'revenue.platform_fee', 'credit', 2700.0, 'EUR', 10757.07, 'payout', 7, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0N1Y6WQF2B0M20RQJ', 21, 'tax_payable', 'credit', 9000.0, 'EUR', 35856.9, 'payout', 7, 'Payout May 2026', '2026-06-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(8, '01K2F2DKG0S1GM964CY99CZMXR', 'PO-31008', 21, NULL, 155000, 2325.0, 7750.0, 144925.0, 'EUR', 3.9841, 577395.69, 'paid', '2026-04-01', '2026-04-30', '2026-05-07', '2026-05-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31008.pdf', '2026-04-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(8, 'Commission — April 2026', 'commission', 'listing', 33, 108500.0, 'EUR', '2026-04-30 00:00:00'),
(8, 'Referral — April 2026', 'referral', 'listing', 352, 31000.0, 'EUR', '2026-04-30 00:00:00'),
(8, 'Bonus — April 2026', 'bonus', 'listing', 234, 15500.0, 'EUR', '2026-04-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0YC466D4FXBRBTJ57', 21, 'partner_payable', 'debit', 155000, 'EUR', 617535.5, 'payout', 8, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0YC466D4FXBRBTJ57', 21, 'cash', 'credit', 144925.0, 'EUR', 577395.69, 'payout', 8, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0YC466D4FXBRBTJ57', 21, 'revenue.platform_fee', 'credit', 2325.0, 'EUR', 9263.03, 'payout', 8, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0YC466D4FXBRBTJ57', 21, 'tax_payable', 'credit', 7750.0, 'EUR', 30876.78, 'payout', 8, 'Payout April 2026', '2026-05-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(9, '01K2F2DKG03M0D037JVH9P3NVC', 'PO-31009', 21, NULL, 13500, 202.5, 675.0, 12622.5, 'EUR', 3.9841, 50289.3, 'paid', '2026-03-01', '2026-03-31', '2026-04-07', '2026-04-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31009.pdf', '2026-03-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(9, 'Commission — March 2026', 'commission', 'listing', 367, 9450.0, 'EUR', '2026-03-31 00:00:00'),
(9, 'Referral — March 2026', 'referral', 'listing', 390, 2700.0, 'EUR', '2026-03-31 00:00:00'),
(9, 'Bonus — March 2026', 'bonus', 'listing', 179, 1350.0, 'EUR', '2026-03-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V5D70RXYKP4PVJY9', 21, 'partner_payable', 'debit', 13500, 'EUR', 53785.35, 'payout', 9, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0V5D70RXYKP4PVJY9', 21, 'cash', 'credit', 12622.5, 'EUR', 50289.3, 'payout', 9, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0V5D70RXYKP4PVJY9', 21, 'revenue.platform_fee', 'credit', 202.5, 'EUR', 806.78, 'payout', 9, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0V5D70RXYKP4PVJY9', 21, 'tax_payable', 'credit', 675.0, 'EUR', 2689.27, 'payout', 9, 'Payout March 2026', '2026-04-07 00:00:00');

INSERT INTO payout_methods (public_id, account_id, method_type, account_holder_name, bank_name, account_last_four, swift_bic, currency_code, is_default, status, verified_at, created_at) VALUES
('01K2F2DKG0DJH0PGSYTEFKQZB5', 32, 'bank_transfer', 'Luxhabitat Development', 'HSBC', '8788', 'EBILAEAD', 'EUR', 1, 'active', '2025-04-21 09:00:00', '2025-06-16 09:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(10, '01K2F2DKG0SS9F1W0Y6RBRFGV5', 'PO-31010', 32, NULL, 31000, 465.0, 1550.0, 28985.0, 'EUR', 3.9841, 115479.14, 'paid', '2026-07-01', '2026-07-31', '2026-08-07', '2026-08-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31010.pdf', '2026-07-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(10, 'Commission — July 2026', 'commission', 'listing', 284, 21700.0, 'EUR', '2026-07-31 00:00:00'),
(10, 'Referral — July 2026', 'referral', 'listing', 404, 6200.0, 'EUR', '2026-07-31 00:00:00'),
(10, 'Bonus — July 2026', 'bonus', 'listing', 431, 3100.0, 'EUR', '2026-07-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0WTRAKVGXJQPH1BDY', 32, 'partner_payable', 'debit', 31000, 'EUR', 123507.1, 'payout', 10, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0WTRAKVGXJQPH1BDY', 32, 'cash', 'credit', 28985.0, 'EUR', 115479.14, 'payout', 10, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0WTRAKVGXJQPH1BDY', 32, 'revenue.platform_fee', 'credit', 465.0, 'EUR', 1852.61, 'payout', 10, 'Payout July 2026', '2026-08-07 00:00:00'),
('01K2F2DKG0WTRAKVGXJQPH1BDY', 32, 'tax_payable', 'credit', 1550.0, 'EUR', 6175.36, 'payout', 10, 'Payout July 2026', '2026-08-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(11, '01K2F2DKG0DJMGQ7DMFHYJS0XQ', 'PO-31011', 32, NULL, 14000, 210.0, 700.0, 13090.0, 'EUR', 3.9841, 52151.87, 'paid', '2026-06-01', '2026-06-30', '2026-07-07', '2026-07-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31011.pdf', '2026-06-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(11, 'Commission — June 2026', 'commission', 'listing', 95, 9800.0, 'EUR', '2026-06-30 00:00:00'),
(11, 'Referral — June 2026', 'referral', 'listing', 173, 2800.0, 'EUR', '2026-06-30 00:00:00'),
(11, 'Bonus — June 2026', 'bonus', 'listing', 18, 1400.0, 'EUR', '2026-06-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0AWMGP2KP9X6N681D', 32, 'partner_payable', 'debit', 14000, 'EUR', 55777.4, 'payout', 11, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0AWMGP2KP9X6N681D', 32, 'cash', 'credit', 13090.0, 'EUR', 52151.87, 'payout', 11, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0AWMGP2KP9X6N681D', 32, 'revenue.platform_fee', 'credit', 210.0, 'EUR', 836.66, 'payout', 11, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG0AWMGP2KP9X6N681D', 32, 'tax_payable', 'credit', 700.0, 'EUR', 2788.87, 'payout', 11, 'Payout June 2026', '2026-07-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(12, '01K2F2DKG000VJSC5BSWA3KVEX', 'PO-31012', 32, NULL, 220000, 3300.0, 11000.0, 205700.0, 'EUR', 3.9841, 819529.37, 'paid', '2026-05-01', '2026-05-31', '2026-06-07', '2026-06-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31012.pdf', '2026-05-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(12, 'Commission — May 2026', 'commission', 'listing', 239, 154000.0, 'EUR', '2026-05-31 00:00:00'),
(12, 'Referral — May 2026', 'referral', 'listing', 407, 44000.0, 'EUR', '2026-05-31 00:00:00'),
(12, 'Bonus — May 2026', 'bonus', 'listing', 214, 22000.0, 'EUR', '2026-05-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG093XT8Z766XZT8NBJ', 32, 'partner_payable', 'debit', 220000, 'EUR', 876502.0, 'payout', 12, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG093XT8Z766XZT8NBJ', 32, 'cash', 'credit', 205700.0, 'EUR', 819529.37, 'payout', 12, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG093XT8Z766XZT8NBJ', 32, 'revenue.platform_fee', 'credit', 3300.0, 'EUR', 13147.53, 'payout', 12, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG093XT8Z766XZT8NBJ', 32, 'tax_payable', 'credit', 11000.0, 'EUR', 43825.1, 'payout', 12, 'Payout May 2026', '2026-06-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(13, '01K2F2DKG00K86Z2Y00CD4ZKYV', 'PO-31013', 32, NULL, 59000, 885.0, 2950.0, 55165.0, 'EUR', 3.9841, 219782.88, 'paid', '2026-04-01', '2026-04-30', '2026-05-07', '2026-05-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31013.pdf', '2026-04-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(13, 'Commission — April 2026', 'commission', 'listing', 141, 41300.0, 'EUR', '2026-04-30 00:00:00'),
(13, 'Referral — April 2026', 'referral', 'listing', 64, 11800.0, 'EUR', '2026-04-30 00:00:00'),
(13, 'Bonus — April 2026', 'bonus', 'listing', 83, 5900.0, 'EUR', '2026-04-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0HR0TCNS75Q4QY2N8', 32, 'partner_payable', 'debit', 59000, 'EUR', 235061.9, 'payout', 13, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0HR0TCNS75Q4QY2N8', 32, 'cash', 'credit', 55165.0, 'EUR', 219782.88, 'payout', 13, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0HR0TCNS75Q4QY2N8', 32, 'revenue.platform_fee', 'credit', 885.0, 'EUR', 3525.93, 'payout', 13, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG0HR0TCNS75Q4QY2N8', 32, 'tax_payable', 'credit', 2950.0, 'EUR', 11753.1, 'payout', 13, 'Payout April 2026', '2026-05-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(14, '01K2F2DKG067KRGD6W8M4Q0D5C', 'PO-31014', 32, NULL, 90000, 1350.0, 4500.0, 84150.0, 'EUR', 3.9841, 335262.02, 'paid', '2026-03-01', '2026-03-31', '2026-04-07', '2026-04-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31014.pdf', '2026-03-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(14, 'Commission — March 2026', 'commission', 'listing', 511, 63000.0, 'EUR', '2026-03-31 00:00:00'),
(14, 'Referral — March 2026', 'referral', 'listing', 292, 18000.0, 'EUR', '2026-03-31 00:00:00'),
(14, 'Bonus — March 2026', 'bonus', 'listing', 215, 9000.0, 'EUR', '2026-03-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0TM2RTSGYHESHFHAE', 32, 'partner_payable', 'debit', 90000, 'EUR', 358569.0, 'payout', 14, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0TM2RTSGYHESHFHAE', 32, 'cash', 'credit', 84150.0, 'EUR', 335262.02, 'payout', 14, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0TM2RTSGYHESHFHAE', 32, 'revenue.platform_fee', 'credit', 1350.0, 'EUR', 5378.53, 'payout', 14, 'Payout March 2026', '2026-04-07 00:00:00'),
('01K2F2DKG0TM2RTSGYHESHFHAE', 32, 'tax_payable', 'credit', 4500.0, 'EUR', 17928.45, 'payout', 14, 'Payout March 2026', '2026-04-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(15, '01K2F2DKG0XAR4ADJ7ERDVCNR1', 'PO-31015', 32, NULL, 200000, 3000.0, 10000.0, 187000.0, 'EUR', 3.9841, 745026.7, 'paid', '2026-02-01', '2026-02-28', '2026-03-07', '2026-03-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31015.pdf', '2026-02-28 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(15, 'Commission — February 2026', 'commission', 'listing', 41, 140000.0, 'EUR', '2026-02-28 00:00:00'),
(15, 'Referral — February 2026', 'referral', 'listing', 191, 40000.0, 'EUR', '2026-02-28 00:00:00'),
(15, 'Bonus — February 2026', 'bonus', 'listing', 10, 20000.0, 'EUR', '2026-02-28 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0V6N742QQPXGBFW02', 32, 'partner_payable', 'debit', 200000, 'EUR', 796820.0, 'payout', 15, 'Payout February 2026', '2026-03-07 00:00:00'),
('01K2F2DKG0V6N742QQPXGBFW02', 32, 'cash', 'credit', 187000.0, 'EUR', 745026.7, 'payout', 15, 'Payout February 2026', '2026-03-07 00:00:00'),
('01K2F2DKG0V6N742QQPXGBFW02', 32, 'revenue.platform_fee', 'credit', 3000.0, 'EUR', 11952.3, 'payout', 15, 'Payout February 2026', '2026-03-07 00:00:00'),
('01K2F2DKG0V6N742QQPXGBFW02', 32, 'tax_payable', 'credit', 10000.0, 'EUR', 39841.0, 'payout', 15, 'Payout February 2026', '2026-03-07 00:00:00');

INSERT INTO payout_methods (public_id, account_id, method_type, account_holder_name, bank_name, account_last_four, swift_bic, currency_code, is_default, status, verified_at, created_at) VALUES
('01K2F2DKG0PES9PG288RTZ7H23', 33, 'bank_transfer', 'Driven Partners', 'Emirates NBD', '8592', 'BBMEAEAD', 'AED', 1, 'active', '2025-06-28 09:00:00', '2025-03-04 09:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(16, '01K2F2DKG02VQD7MSGKJNTB9K1', 'PO-31016', 33, NULL, 195000, 2925.0, 9750.0, 182325.0, 'AED', 1.0, 182325.0, 'processing', '2026-07-01', '2026-07-31', '2026-08-07', NULL, 'https://cdn.livfinder.com/statements/PO-31016.pdf', '2026-07-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(16, 'Commission — July 2026', 'commission', 'listing', 376, 136500.0, 'AED', '2026-07-31 00:00:00'),
(16, 'Referral — July 2026', 'referral', 'listing', 311, 39000.0, 'AED', '2026-07-31 00:00:00'),
(16, 'Bonus — July 2026', 'bonus', 'listing', 125, 19500.0, 'AED', '2026-07-31 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(17, '01K2F2DKG0MWHTKZ4WDW95A1B8', 'PO-31017', 33, NULL, 37000, 555.0, 1850.0, 34595.0, 'AED', 1.0, 34595.0, 'paid', '2026-06-01', '2026-06-30', '2026-07-07', '2026-07-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31017.pdf', '2026-06-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(17, 'Commission — June 2026', 'commission', 'listing', 359, 25900.0, 'AED', '2026-06-30 00:00:00'),
(17, 'Referral — June 2026', 'referral', 'listing', 478, 7400.0, 'AED', '2026-06-30 00:00:00'),
(17, 'Bonus — June 2026', 'bonus', 'listing', 298, 3700.0, 'AED', '2026-06-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG01GM7NGSRHHN5WN1X', 33, 'partner_payable', 'debit', 37000, 'AED', 37000.0, 'payout', 17, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG01GM7NGSRHHN5WN1X', 33, 'cash', 'credit', 34595.0, 'AED', 34595.0, 'payout', 17, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG01GM7NGSRHHN5WN1X', 33, 'revenue.platform_fee', 'credit', 555.0, 'AED', 555.0, 'payout', 17, 'Payout June 2026', '2026-07-07 00:00:00'),
('01K2F2DKG01GM7NGSRHHN5WN1X', 33, 'tax_payable', 'credit', 1850.0, 'AED', 1850.0, 'payout', 17, 'Payout June 2026', '2026-07-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(18, '01K2F2DKG0HGF7BCEGT7M9A4HC', 'PO-31018', 33, NULL, 205000, 3075.0, 10250.0, 191675.0, 'AED', 1.0, 191675.0, 'paid', '2026-05-01', '2026-05-31', '2026-06-07', '2026-06-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31018.pdf', '2026-05-31 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(18, 'Commission — May 2026', 'commission', 'listing', 478, 143500.0, 'AED', '2026-05-31 00:00:00'),
(18, 'Referral — May 2026', 'referral', 'listing', 81, 41000.0, 'AED', '2026-05-31 00:00:00'),
(18, 'Bonus — May 2026', 'bonus', 'listing', 64, 20500.0, 'AED', '2026-05-31 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG0AK1QRK4WHK4BC5QK', 33, 'partner_payable', 'debit', 205000, 'AED', 205000.0, 'payout', 18, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0AK1QRK4WHK4BC5QK', 33, 'cash', 'credit', 191675.0, 'AED', 191675.0, 'payout', 18, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0AK1QRK4WHK4BC5QK', 33, 'revenue.platform_fee', 'credit', 3075.0, 'AED', 3075.0, 'payout', 18, 'Payout May 2026', '2026-06-07 00:00:00'),
('01K2F2DKG0AK1QRK4WHK4BC5QK', 33, 'tax_payable', 'credit', 10250.0, 'AED', 10250.0, 'payout', 18, 'Payout May 2026', '2026-06-07 00:00:00');

INSERT INTO payouts (id, public_id, reference, account_id, payout_method_id, gross_amount, fee_amount, tax_amount, net_amount, currency_code, exchange_rate, net_amount_base, status, period_start, period_end, scheduled_for, paid_at, statement_url, created_at) VALUES
(19, '01K2F2DKG01SD4YBS88Q4GYTKM', 'PO-31019', 33, NULL, 75000, 1125.0, 3750.0, 70125.0, 'AED', 1.0, 70125.0, 'paid', '2026-04-01', '2026-04-30', '2026-05-07', '2026-05-07 00:00:00', 'https://cdn.livfinder.com/statements/PO-31019.pdf', '2026-04-30 00:00:00');

INSERT INTO payout_items (payout_id, description, item_type, reference_type, reference_id, amount, currency_code, earned_at) VALUES
(19, 'Commission — April 2026', 'commission', 'listing', 351, 52500.0, 'AED', '2026-04-30 00:00:00'),
(19, 'Referral — April 2026', 'referral', 'listing', 120, 15000.0, 'AED', '2026-04-30 00:00:00'),
(19, 'Bonus — April 2026', 'bonus', 'listing', 424, 7500.0, 'AED', '2026-04-30 00:00:00');

INSERT INTO ledger_entries (transaction_group, account_id, ledger_account, entry_type, amount, currency_code, amount_base, source_type, source_id, description, occurred_at) VALUES
('01K2F2DKG08QX6CXV8SWZJCQF5', 33, 'partner_payable', 'debit', 75000, 'AED', 75000.0, 'payout', 19, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG08QX6CXV8SWZJCQF5', 33, 'cash', 'credit', 70125.0, 'AED', 70125.0, 'payout', 19, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG08QX6CXV8SWZJCQF5', 33, 'revenue.platform_fee', 'credit', 1125.0, 'AED', 1125.0, 'payout', 19, 'Payout April 2026', '2026-05-07 00:00:00'),
('01K2F2DKG08QX6CXV8SWZJCQF5', 33, 'tax_payable', 'credit', 3750.0, 'AED', 3750.0, 'payout', 19, 'Payout April 2026', '2026-05-07 00:00:00');

INSERT INTO refunds (public_id, payment_id, account_id, amount, currency_code, exchange_rate, amount_base, reason, reason_note, status, provider_refund_id, processed_by_user_id, refunded_at, created_at) VALUES
('01K2F2DKG0HT36H1H03Q4SAWBC', 251, 16, 5500, 'AED', 1.0, 5500, 'requested_by_customer', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg087g8xjmgtkd5j35r', 7, '2026-07-26 09:00:00', '2026-05-02 09:00:00'),
('01K2F2DKG0NA2YP7W7MHG01ZH8', 208, 3, 5000, 'AED', 1.0, 5000, 'downgrade', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0mpsxeyhahe1r7eyn', 7, '2026-07-05 09:00:00', '2026-04-29 09:00:00'),
('01K2F2DKG03RDNXY9TRWPY6X8P', 259, 1, 5500, 'AED', 1.0, 5500, 'downgrade', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg01enwe4bz0fk9qwkk', 7, '2026-08-11 09:00:00', '2026-06-02 09:00:00'),
('01K2F2DKG05BVBG0KH76TCVY0N', 199, 4, 4000, 'AED', 1.0, 4000, 'duplicate', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0x933bkrdsas6vym4', 7, '2026-05-02 09:00:00', '2026-08-12 09:00:00'),
('01K2F2DKG0Q8A1MTR4WCG9X2E0', 24, 38, 5500, 'AED', 1.0, 5500, 'service_issue', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0jxjf8m5nndacasrn', 7, '2026-05-20 09:00:00', '2026-08-02 09:00:00'),
('01K2F2DKG05DC0B58NS2Q27B0G', 142, 36, 1000, 'AED', 1.0, 1000, 'downgrade', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0x509bkvdyqmcvfmn', 7, '2026-05-15 09:00:00', '2026-06-01 09:00:00'),
('01K2F2DKG0NEYJYR9XTJBMH2Z0', 64, 24, 1500, 'AED', 1.0, 1500, 'duplicate', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg04v17zdgnbf3vvq2k', 7, '2026-04-20 09:00:00', '2026-05-01 09:00:00'),
('01K2F2DKG0FNX66PRKS4TMHYE6', 258, 2, 3000, 'AED', 1.0, 3000, 'downgrade', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0qp2c8eetp72wbehc', 7, '2026-06-06 09:00:00', '2026-05-03 09:00:00'),
('01K2F2DKG0EN05BXTQFSH8694M', 78, 7, 2000, 'AED', 1.0, 2000, 'downgrade', 'Customer downgraded mid-cycle; pro-rata refund issued.', 'succeeded', 're_01k2f2dkg0cccb6tkpnk2yhxkd', 7, '2026-06-14 09:00:00', '2026-06-17 09:00:00');

INSERT INTO coupons (code, name, discount_type, discount_value, currency_code, max_redemptions, max_per_account, minimum_amount, applies_to_plan_id, starts_at, ends_at, is_active) VALUES
('LAUNCH25', 'Launch offer — 25% off', 'percentage', 25.0, NULL, 500, 1, NULL, NULL, '2026-05-19 09:00:00', '2026-11-15 09:00:00', 1),
('AGENCY1000', 'AED 1,000 off Agency Growth', 'fixed', 1000.0, 'AED', 100, 1, 5000.0, 5, '2026-07-18 09:00:00', '2026-10-16 09:00:00', 1),
('TRIAL60', '60-day extended trial', 'free_trial', 60.0, NULL, 0, 1, NULL, 4, '2026-01-29 09:00:00', '2026-08-07 09:00:00', 0);

INSERT INTO featured_placements (id, public_id, listing_id, account_id, placement_type, category_id, location_id, starts_at, ends_at, status, amount, currency_code, created_at) VALUES
(1, '01K2F2DKG0JSF0E3ZBKNW81YJ5', 7, 21, 'similar_listings', 1, 1900001, '2026-08-16 09:00:00', '2026-09-15 09:00:00', 'active', 11500, 'EUR', '2026-08-16 09:00:00'),
(2, '01K2F2DKG0Y0G2CGW7DWEJKQ1Y', 29, 22, 'homepage', 1, 1120784, '2026-08-13 09:00:00', '2026-08-20 09:00:00', 'active', 7500, 'USD', '2026-08-13 09:00:00'),
(3, '01K2F2DKG0R2S7G73R3DS76SYP', 31, 22, 'category', 1, 1050388, '2026-08-06 09:00:00', '2026-08-13 09:00:00', 'active', 12500, 'GBP', '2026-08-06 09:00:00'),
(4, '01K2F2DKG034RTKHMHK1ZXBFCJ', 32, 25, 'homepage', 1, 1046589, '2026-08-10 09:00:00', '2026-08-17 09:00:00', 'active', 1500, 'EUR', '2026-08-10 09:00:00'),
(5, '01K2F2DKG08C0DE6Q0CKSRVJQH', 34, 34, 'category', 1, 1089101, '2026-08-08 09:00:00', '2026-08-15 09:00:00', 'active', 21000, 'EUR', '2026-08-08 09:00:00'),
(6, '01K2F2DKG0X2E9Q8Y433WE51X4', 43, 12, 'homepage', 1, 1102858, '2026-08-05 09:00:00', '2026-08-19 09:00:00', 'active', 18500, 'SAR', '2026-08-05 09:00:00'),
(7, '01K2F2DKG0N8FJYS6538AR2RH7', 68, 1, 'search_top', 1, 1120784, '2026-07-29 09:00:00', '2026-08-28 09:00:00', 'active', 22000, 'USD', '2026-07-29 09:00:00'),
(8, '01K2F2DKG0SD13979NR7KRHDYW', 81, 14, 'location', 1, 1000032, '2026-08-11 09:00:00', '2026-08-18 09:00:00', 'active', 8000, 'AED', '2026-08-11 09:00:00'),
(9, '01K2F2DKG0ZE35BT6QZF7W6GDM', 89, 22, 'search_top', 1, 1050388, '2026-08-05 09:00:00', '2026-08-12 09:00:00', 'active', 6000, 'GBP', '2026-08-05 09:00:00'),
(10, '01K2F2DKG0MJB9VPNC2MA6ZGDN', 99, 35, 'search_top', 1, 1034729, '2026-07-28 09:00:00', '2026-08-04 09:00:00', 'active', 9000, 'EUR', '2026-07-28 09:00:00'),
(11, '01K2F2DKG0G9S7ZJ4STR2HHNW5', 113, 14, 'search_top', 1, 1046589, '2026-08-05 09:00:00', '2026-08-19 09:00:00', 'active', 9000, 'EUR', '2026-08-05 09:00:00'),
(12, '01K2F2DKG05YHT5TQ7RCF8Q0NP', 118, 11, 'category', 1, 1000032, '2026-08-01 09:00:00', '2026-08-15 09:00:00', 'active', 16000, 'AED', '2026-08-01 09:00:00'),
(13, '01K2F2DKG0M77T63K9H4CTHRR9', 119, 13, 'similar_listings', 1, 1000012, '2026-07-28 09:00:00', '2026-08-04 09:00:00', 'active', 1500, 'AED', '2026-07-28 09:00:00'),
(14, '01K2F2DKG0ZZ3H8HNSSTD7GHWV', 136, 10, 'search_top', 1, 1089245, '2026-07-30 09:00:00', '2026-08-13 09:00:00', 'active', 22500, 'EUR', '2026-07-30 09:00:00'),
(15, '01K2F2DKG01EVB4QGBP85B910Z', 140, 11, 'category', 1, 1000032, '2026-08-11 09:00:00', '2026-08-25 09:00:00', 'active', 11000, 'AED', '2026-08-11 09:00:00'),
(16, '01K2F2DKG0N1YJZFGC81TTXJDG', 143, 35, 'similar_listings', 1, 1034729, '2026-08-14 09:00:00', '2026-08-21 09:00:00', 'active', 7500, 'EUR', '2026-08-14 09:00:00'),
(17, '01K2F2DKG0NDWE8SJDH6Z8Q9P6', 157, 3, 'search_top', 1, 1900001, '2026-08-10 09:00:00', '2026-08-17 09:00:00', 'active', 6000, 'EUR', '2026-08-10 09:00:00'),
(18, '01K2F2DKG0Z2ZGCDRA91BJB0YS', 184, 3, 'search_top', 1, 1121746, '2026-08-13 09:00:00', '2026-08-20 09:00:00', 'active', 21500, 'USD', '2026-08-13 09:00:00'),
(19, '01K2F2DKG0A6XV54FCBG6SPZ73', 197, 14, 'category', 1, 1046589, '2026-08-09 09:00:00', '2026-08-16 09:00:00', 'active', 2500, 'EUR', '2026-08-09 09:00:00'),
(20, '01K2F2DKG0QMN2208BQB2VTQAT', 198, 12, 'search_top', 1, 1102858, '2026-07-28 09:00:00', '2026-08-11 09:00:00', 'active', 23000, 'SAR', '2026-07-28 09:00:00'),
(21, '01K2F2DKG0S2WDKVMC1AE1GW7P', 201, 22, 'category', 1, 1140142, '2026-08-09 09:00:00', '2026-08-16 09:00:00', 'active', 22500, 'EUR', '2026-08-09 09:00:00'),
(22, '01K2F2DKG08PGZJZ6H1XNB15JF', 227, 14, 'homepage', 1, 1046589, '2026-08-01 09:00:00', '2026-08-31 09:00:00', 'active', 9500, 'EUR', '2026-08-01 09:00:00'),
(23, '01K2F2DKG0J97FQA5Z8P6D2WY2', 258, 36, 'similar_listings', 1, 1121746, '2026-08-10 09:00:00', '2026-08-17 09:00:00', 'active', 12000, 'USD', '2026-08-10 09:00:00'),
(24, '01K2F2DKG04HEY9RVXWZMHHC79', 273, 37, 'location', 2, 1017827, '2026-08-11 09:00:00', '2026-09-10 09:00:00', 'active', 3500, 'CHF', '2026-08-11 09:00:00'),
(25, '01K2F2DKG0HJVGMMMYPKCM1ZDG', 320, 26, 'homepage', 2, 1007408, '2026-08-13 09:00:00', '2026-08-20 09:00:00', 'active', 15000, 'AUD', '2026-08-13 09:00:00'),
(26, '01K2F2DKG0FZJ11JAD8ZDD6S67', 321, 4, 'category', 2, 1102858, '2026-08-11 09:00:00', '2026-08-18 09:00:00', 'active', 2500, 'SAR', '2026-08-11 09:00:00'),
(27, '01K2F2DKG0Z111C1S4KR8E694E', 327, 37, 'similar_listings', 2, 1017827, '2026-08-12 09:00:00', '2026-08-26 09:00:00', 'active', 15500, 'CHF', '2026-08-12 09:00:00'),
(28, '01K2F2DKG0WW3P1XRSR7M2FP1X', 336, 4, 'location', 2, 1000012, '2026-08-14 09:00:00', '2026-08-28 09:00:00', 'active', 17500, 'AED', '2026-08-14 09:00:00'),
(29, '01K2F2DKG0E2TADQGE0XY6W547', 341, 126, 'similar_listings', 2, 1000012, '2026-08-10 09:00:00', '2026-08-17 09:00:00', 'active', 6000, 'AED', '2026-08-10 09:00:00'),
(30, '01K2F2DKG0DHF1GTR0SPC9FHSK', 353, 40, 'location', 3, 1000032, '2026-07-29 09:00:00', '2026-08-05 09:00:00', 'active', 16000, 'AED', '2026-07-29 09:00:00'),
(31, '01K2F2DKG0PZNEY0143EDSQ332', 359, 7, 'search_top', 3, 1000032, '2026-07-30 09:00:00', '2026-08-29 09:00:00', 'active', 15500, 'AED', '2026-07-30 09:00:00'),
(32, '01K2F2DKG07MMJJWJ2F2AFVDHS', 361, 6, 'search_top', 3, 1140142, '2026-07-31 09:00:00', '2026-08-30 09:00:00', 'active', 18000, 'EUR', '2026-07-31 09:00:00'),
(33, '01K2F2DKG0P5SFFY6JSWDYK324', 381, 18, 'search_top', 3, 1000032, '2026-07-29 09:00:00', '2026-08-12 09:00:00', 'active', 13000, 'AED', '2026-07-29 09:00:00'),
(34, '01K2F2DKG0G80YMTJE64VV4E1Q', 398, 7, 'location', 3, 1000032, '2026-08-01 09:00:00', '2026-08-31 09:00:00', 'active', 11500, 'AED', '2026-08-01 09:00:00'),
(35, '01K2F2DKG01AB8Q53ZENA9DMGV', 403, 40, 'homepage', 3, 1056263, '2026-08-07 09:00:00', '2026-08-21 09:00:00', 'active', 11000, 'USD', '2026-08-07 09:00:00'),
(36, '01K2F2DKG0GY6CGRHR6X0V2JQ8', 407, 7, 'location', 3, 1000032, '2026-08-05 09:00:00', '2026-08-19 09:00:00', 'active', 8000, 'AED', '2026-08-05 09:00:00'),
(37, '01K2F2DKG0B7HMGFHVA8DHPT86', 409, 7, 'similar_listings', 3, 1000032, '2026-08-12 09:00:00', '2026-09-11 09:00:00', 'active', 13000, 'AED', '2026-08-12 09:00:00'),
(38, '01K2F2DKG0DWYRCH9NYDSNRFBB', 418, 19, 'homepage', 4, 1102874, '2026-08-07 09:00:00', '2026-09-06 09:00:00', 'active', 7000, 'SAR', '2026-08-07 09:00:00'),
(39, '01K2F2DKG04BQFWEPCSA21290G', 420, 19, 'search_top', 4, 1044856, '2026-07-31 09:00:00', '2026-08-14 09:00:00', 'active', 21000, 'EUR', '2026-07-31 09:00:00'),
(40, '01K2F2DKG0PJ0TQS2277FAF74C', 424, 19, 'similar_listings', 4, 1000032, '2026-08-11 09:00:00', '2026-08-18 09:00:00', 'active', 13500, 'AED', '2026-08-11 09:00:00'),
(41, '01K2F2DKG01AJHTH1BRE3Q8FPB', 427, 19, 'category', 4, 1044856, '2026-08-06 09:00:00', '2026-08-20 09:00:00', 'active', 19000, 'EUR', '2026-08-06 09:00:00'),
(42, '01K2F2DKG0YRNKGPMB5PSWVYTX', 431, 8, 'location', 4, 1007408, '2026-08-14 09:00:00', '2026-08-28 09:00:00', 'active', 15000, 'AUD', '2026-08-14 09:00:00'),
(43, '01K2F2DKG0NXACZDMSHXBFQS8J', 451, 24, 'search_top', 5, 1000012, '2026-08-13 09:00:00', '2026-09-12 09:00:00', 'active', 18500, 'AED', '2026-08-13 09:00:00'),
(44, '01K2F2DKG080DZC5BSJA0G95HT', 467, 9, 'category', 5, 1900005, '2026-08-04 09:00:00', '2026-08-18 09:00:00', 'active', 14500, 'HKD', '2026-08-04 09:00:00'),
(45, '01K2F2DKG0HEECKRZT6DHVQY0A', 477, 9, 'location', 6, 1900005, '2026-08-15 09:00:00', '2026-09-14 09:00:00', 'active', 3000, 'HKD', '2026-08-15 09:00:00'),
(46, '01K2F2DKG0FVFEHKB77XH6RWYV', 483, 20, 'category', 6, 1140142, '2026-07-29 09:00:00', '2026-08-05 09:00:00', 'active', 17000, 'EUR', '2026-07-29 09:00:00'),
(47, '01K2F2DKG04QFRVPKA0M27KW1G', 496, 42, 'search_top', 6, 1017121, '2026-08-05 09:00:00', '2026-09-04 09:00:00', 'active', 20500, 'CAD', '2026-08-05 09:00:00'),
(48, '01K2F2DKG0BZMDB540WR415RJT', 499, 31, 'search_top', 6, 1017827, '2026-07-29 09:00:00', '2026-08-12 09:00:00', 'active', 16500, 'CHF', '2026-07-29 09:00:00'),
(49, '01K2F2DKG0BFQ31G2D5RYNJR6E', 513, 42, 'homepage', 6, 1017121, '2026-08-13 09:00:00', '2026-09-12 09:00:00', 'active', 21500, 'CAD', '2026-08-13 09:00:00'),
(50, '01K2F2DKG0QVW3KT6QR39WD8Z8', 516, 182, 'homepage', 6, 1106650, '2026-08-04 09:00:00', '2026-08-11 09:00:00', 'active', 3500, 'THB', '2026-08-04 09:00:00');


COMMIT;
SET autocommit = 1;
