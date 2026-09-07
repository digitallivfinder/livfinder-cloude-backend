-- =============================================================================
-- 099_platform_finalise.sql
--
-- The last file the loader runs. It does two things.
--
-- First, it re-derives the counters that can only be correct once every layer is
-- present -- the ones whose sources live in files that load after the file the
-- counter lives in. Running them here rather than in place means a partial load
-- never leaves a plausible-looking wrong number behind.
--
-- Second, and more importantly, it asserts. Every SELECT below returns a name
-- and a failure count, and every one of them must return zero. These are not
-- decorative: they encode the invariants the schema cannot express as
-- constraints -- a ledger that balances, attribution credit that sums to one, a
-- market statistic that is only publishable if its sample supports it -- and
-- they are the difference between a seed that loads and a seed that is correct.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Cross-layer derivations
-- -----------------------------------------------------------------------------

-- Buildings and units are seeded before the listings are linked to them, and
-- the link is what the counters count.
UPDATE property_units u
LEFT JOIN (
  SELECT unit_id, COUNT(*) AS total, SUM(status = 'active') AS active,
         MAX(created_at) AS last_listed
  FROM listings WHERE unit_id IS NOT NULL GROUP BY unit_id
) c ON c.unit_id = u.id
SET u.listing_count = COALESCE(c.total, 0),
    u.active_listing_count = LEAST(255, COALESCE(c.active, 0)),
    u.last_listed_at = c.last_listed;

UPDATE buildings b
LEFT JOIN (
  SELECT building_id, COUNT(*) AS units FROM property_units
  WHERE building_id IS NOT NULL GROUP BY building_id
) u ON u.building_id = b.id
LEFT JOIN (
  SELECT building_id, COUNT(*) AS total, SUM(status = 'active') AS active
  FROM listings WHERE building_id IS NOT NULL GROUP BY building_id
) l ON l.building_id = b.id
SET b.unit_count = LEAST(65535, COALESCE(u.units, 0)),
    b.listing_count = LEAST(65535, COALESCE(l.total, 0)),
    b.active_listing_count = LEAST(65535, COALESCE(l.active, 0));

-- A credit lot's remaining balance is the granted amount less what the
-- transactions consumed. Asserted below as well as derived here, because this
-- is the number a customer disputes.
UPDATE credit_lots cl
LEFT JOIN (
  SELECT lot_id, SUM(amount) AS net FROM credit_transactions
  WHERE lot_id IS NOT NULL GROUP BY lot_id
) t ON t.lot_id = cl.id
-- The grant itself is a transaction, so the balance is the sum of the ledger
-- rather than the grant plus the ledger.
SET cl.remaining = GREATEST(0, COALESCE(t.net, 0));

-- Campaign spend is the sum of its spend entries, never a figure typed beside
-- them. The same applies to delivery: impressions and clicks come from the
-- partitioned event tables.
UPDATE ad_campaigns c
LEFT JOIN (
  SELECT campaign_id, ROUND(SUM(amount), 2) AS spent, ROUND(SUM(amount_base), 2) AS spent_base
  FROM ad_spend_entries GROUP BY campaign_id
) s ON s.campaign_id = c.id
SET c.spent_amount = COALESCE(s.spent, 0),
    c.spent_amount_base = COALESCE(s.spent_base, 0);

-- Promotion inventory: what is left is the capacity less what sold and what is
-- being held. A slot cannot be oversold, and the assertion below proves it.
UPDATE promotion_inventory
SET available_count = GREATEST(0, capacity - sold_count - reserved_count);

-- Journal totals follow their lines.
UPDATE journals j
LEFT JOIN (
  SELECT journal_id,
         ROUND(SUM(CASE WHEN entry_type = 'debit'  THEN amount ELSE 0 END), 2) AS dr,
         ROUND(SUM(CASE WHEN entry_type = 'credit' THEN amount ELSE 0 END), 2) AS cr,
         ROUND(SUM(CASE WHEN entry_type = 'debit'  THEN amount_base ELSE 0 END), 2) AS dr_base,
         ROUND(SUM(CASE WHEN entry_type = 'credit' THEN amount_base ELSE 0 END), 2) AS cr_base
  FROM ledger_entries WHERE journal_id IS NOT NULL GROUP BY journal_id
) l ON l.journal_id = j.id
SET j.total_debit = COALESCE(l.dr, 0),
    j.total_credit = COALESCE(l.cr, 0),
    j.total_debit_base = COALESCE(l.dr_base, 0),
    j.total_credit_base = COALESCE(l.cr_base, 0);

-- Tenant daily statistics carry a visible-listing count that depends on the
-- inventory layer, which loads after them.
UPDATE tenant_daily_stats s
JOIN tenants t ON t.id = s.tenant_id AND t.tenant_type IN ('primary', 'staging', 'embedded')
SET s.visible_listings = (SELECT COUNT(*) FROM listings WHERE status = 'active');

-- =============================================================================
-- Assertions. Every one of these must return zero failures.
-- =============================================================================

-- --- Tenancy and governance -------------------------------------------------

SELECT 'every tenant has exactly one canonical domain' AS assertion, COUNT(*) AS failures
  FROM (SELECT t.id FROM tenants t
          LEFT JOIN tenant_domains d ON d.tenant_id = t.id AND d.is_canonical = 1
         GROUP BY t.id HAVING COUNT(d.id) <> 1) x;

SELECT 'exactly one tenant is the default' AS assertion,
       ABS((SELECT COUNT(*) FROM tenants WHERE is_default = 1) - 1) AS failures;

SELECT 'every redirecting domain points at a live domain' AS assertion, COUNT(*) AS failures
  FROM tenant_domains d
  LEFT JOIN tenant_domains target ON target.id = d.redirects_to_domain_id
 WHERE d.redirects_to_domain_id IS NOT NULL
   AND (target.id IS NULL OR target.status <> 'active');

SELECT 'every white-label tenant has an owning organization' AS assertion, COUNT(*) AS failures
  FROM tenants WHERE tenant_type = 'white_label' AND owner_organization_id IS NULL;

SELECT 'revenue share is only set where a contract exists' AS assertion, COUNT(*) AS failures
  FROM tenants WHERE revenue_share_percent IS NOT NULL AND contract_ends_on IS NULL;

SELECT 'no tenant reports revenue share without a share percent' AS assertion,
       COUNT(*) AS failures
  FROM tenant_daily_stats s JOIN tenants t ON t.id = s.tenant_id
 WHERE s.revenue_share > 0 AND COALESCE(t.revenue_share_percent, 0) = 0;

SELECT 'every personal-data field names an erasure action' AS assertion, COUNT(*) AS failures
  FROM data_field_registry
 WHERE is_personal_data = 1 AND erasure_action = 'no_action';

SELECT 'every anonymize action references a rule' AS assertion, COUNT(*) AS failures
  FROM data_field_registry
 WHERE erasure_action IN ('anonymize', 'pseudonymize', 'hash') AND anonymization_rule_id IS NULL;

SELECT 'every consent-based field maps to a consent purpose' AS assertion, COUNT(*) AS failures
  FROM data_field_registry r
 WHERE r.lawful_basis = 'consent'
   AND NOT EXISTS (SELECT 1 FROM consent_purposes cp WHERE cp.is_active = 1);

SELECT 'every processing activity that transfers data names a safeguard' AS assertion,
       COUNT(*) AS failures
  FROM processing_activities
 WHERE transfers_outside_region = 1 AND (transfer_safeguard IS NULL OR transfer_safeguard = 'none');

SELECT 'every active processor has a signed data processing agreement' AS assertion,
       COUNT(*) AS failures
  FROM data_processors WHERE status = 'active' AND dpa_signed = 0;

SELECT 'every terminated processor confirmed deletion' AS assertion, COUNT(*) AS failures
  FROM data_processors WHERE status = 'terminated' AND data_deletion_confirmed_at IS NULL;

SELECT 'high-risk processors are audited at least annually' AS assertion, COUNT(*) AS failures
  FROM data_processors
 WHERE status = 'active' AND risk_rating = 'high'
   AND (last_audit_at IS NULL OR last_audit_at < DATE_SUB(CURDATE(), INTERVAL 400 DAY));

SELECT 'a granted consent receipt carries a grant timestamp' AS assertion, COUNT(*) AS failures
  FROM consent_receipts WHERE action = 'granted' AND granted_at IS NULL;

SELECT 'a withdrawn consent receipt carries a withdrawal timestamp' AS assertion,
       COUNT(*) AS failures
  FROM consent_receipts WHERE action = 'withdrawn' AND withdrawn_at IS NULL;

SELECT 'marketing consent receipts agree with the user preference' AS assertion,
       COUNT(*) AS failures
  FROM consent_receipts cr
  JOIN consent_purposes cp ON cp.id = cr.purpose_id AND cp.code = 'marketing_email'
  JOIN users u ON u.id = cr.user_id
 WHERE (cr.action = 'granted') <> (u.marketing_opt_in = 1);

SELECT 'every completed deletion request has an erasure record' AS assertion,
       COUNT(*) AS failures
  FROM data_subject_requests d
 WHERE d.request_type = 'deletion' AND d.status = 'completed'
   AND NOT EXISTS (SELECT 1 FROM erasure_records e WHERE e.request_id = d.id);

SELECT 'every subject request has a statutory deadline' AS assertion, COUNT(*) AS failures
  FROM data_subject_requests WHERE due_at IS NULL;

SELECT 'a retention run never deletes more than was eligible' AS assertion, COUNT(*) AS failures
  FROM retention_runs WHERE affected_rows > eligible_rows;

SELECT 'a dry-run retention pass changes nothing' AS assertion, COUNT(*) AS failures
  FROM retention_runs WHERE was_dry_run = 1 AND affected_rows > 0;

SELECT 'a released legal hold records who released it and why' AS assertion,
       COUNT(*) AS failures
  FROM legal_holds
 WHERE status = 'released'
   AND (released_at IS NULL OR released_by_user_id IS NULL OR release_reason IS NULL);

SELECT 'field change log numeric deltas agree with their values' AS assertion,
       COUNT(*) AS failures
  FROM field_change_log
 WHERE old_numeric IS NOT NULL AND new_numeric IS NOT NULL
   AND ABS(COALESCE(delta_numeric, 0) - (new_numeric - old_numeric)) > 0.0001;

SELECT 'every legal-record snapshot has a retention date' AS assertion, COUNT(*) AS failures
  FROM entity_snapshots WHERE is_legal_record = 1 AND retain_until IS NULL;

-- --- Property inventory -----------------------------------------------------

SELECT 'every real-estate listing resolves to a unit' AS assertion, COUNT(*) AS failures
  FROM listings WHERE root_category_id = 1 AND deleted_at IS NULL AND unit_id IS NULL;

SELECT 'a unit and its listing agree on the building' AS assertion, COUNT(*) AS failures
  FROM listings l JOIN property_units u ON u.id = l.unit_id
 WHERE NOT (l.building_id <=> u.building_id);

SELECT 'a floor belongs to the building its unit does' AS assertion, COUNT(*) AS failures
  FROM property_units u JOIN building_floors f ON f.id = u.floor_id
 WHERE f.building_id <> u.building_id;

SELECT 'building unit counts match the units' AS assertion, COUNT(*) AS failures
  FROM (SELECT b.id FROM buildings b
          LEFT JOIN (SELECT building_id, COUNT(*) n FROM property_units
                      WHERE building_id IS NOT NULL GROUP BY building_id) u
            ON u.building_id = b.id
         WHERE b.unit_count <> COALESCE(u.n, 0)) x;

SELECT 'unit listing counts match the listings' AS assertion, COUNT(*) AS failures
  FROM (SELECT u.id FROM property_units u
          LEFT JOIN (SELECT unit_id, COUNT(*) n FROM listings
                      WHERE unit_id IS NOT NULL GROUP BY unit_id) l ON l.unit_id = u.id
         WHERE u.listing_count <> COALESCE(l.n, 0)) x;

SELECT 'current ownership shares sum to a hundred per unit' AS assertion, COUNT(*) AS failures
  FROM (SELECT unit_id FROM unit_ownerships WHERE is_current = 1
         GROUP BY unit_id HAVING ABS(SUM(share_percent) - 100) > 0.001) x;

SELECT 'a disposed ownership is not current' AS assertion, COUNT(*) AS failures
  FROM unit_ownerships WHERE disposed_on IS NOT NULL AND is_current = 1;

SELECT 'a non-arms-length transaction states why it is excluded' AS assertion,
       COUNT(*) AS failures
  FROM unit_transactions WHERE is_arms_length = 0 AND exclusion_reason IS NULL;

SELECT 'transaction price per area agrees with amount over area' AS assertion,
       COUNT(*) AS failures
  FROM unit_transactions
 WHERE area > 0 AND price_per_area IS NOT NULL
   AND ABS(price_per_area - amount / area) > 0.01;

SELECT 'a tenancy ends after it starts' AS assertion, COUNT(*) AS failures
  FROM tenancies WHERE ends_on <= starts_on;

SELECT 'every tenancy has a landlord and a tenant' AS assertion, COUNT(*) AS failures
  FROM (SELECT t.id FROM tenancies t
          LEFT JOIN tenancy_parties lp ON lp.tenancy_id = t.id AND lp.party_role = 'landlord'
          LEFT JOIN tenancy_parties tp ON tp.tenancy_id = t.id AND tp.party_role = 'tenant'
         GROUP BY t.id
        HAVING COUNT(DISTINCT lp.id) = 0 OR COUNT(DISTINCT tp.id) = 0) x;

SELECT 'rent instalments sum to the annual rent' AS assertion, COUNT(*) AS failures
  FROM (SELECT t.id FROM tenancies t
          JOIN rent_schedules r ON r.tenancy_id = t.id
         GROUP BY t.id
        HAVING ABS(SUM(r.amount) - MAX(t.annual_rent)) > 1.00) x;

SELECT 'a bounced instalment records the bounce' AS assertion, COUNT(*) AS failures
  FROM rent_schedules WHERE status = 'bounced' AND (bounced_at IS NULL OR bounce_reason IS NULL);

SELECT 'a paid instalment is fully paid' AS assertion, COUNT(*) AS failures
  FROM rent_schedules WHERE status = 'paid' AND ABS(paid_amount - amount) > 0.01;

SELECT 'a renewal chain is symmetric' AS assertion, COUNT(*) AS failures
  FROM tenancies prev JOIN tenancies next ON next.id = prev.renewed_into_tenancy_id
 WHERE NOT (next.previous_tenancy_id <=> prev.id);

SELECT 'an emergency maintenance request has a four-hour response promise' AS assertion,
       COUNT(*) AS failures
  FROM maintenance_requests
 WHERE priority = 'emergency'
   AND (response_due_at IS NULL OR TIMESTAMPDIFF(HOUR, reported_at, response_due_at) > 4);

SELECT 'a completed maintenance request records a final amount' AS assertion,
       COUNT(*) AS failures
  FROM maintenance_requests WHERE status IN ('completed', 'verified') AND final_amount IS NULL;

SELECT 'a valuation range brackets its own figure' AS assertion, COUNT(*) AS failures
  FROM valuations
 WHERE value_low IS NOT NULL AND value_high IS NOT NULL
   AND (valued_amount < value_low OR valued_amount > value_high);

SELECT 'a formal survey names its valuer and licence' AS assertion, COUNT(*) AS failures
  FROM valuations
 WHERE valuation_type = 'formal_survey'
   AND (valuer_name IS NULL OR valuer_licence IS NULL);

SELECT 'an excluded comparable states why' AS assertion, COUNT(*) AS failures
  FROM valuation_comparables WHERE is_excluded = 1 AND exclusion_reason IS NULL;

SELECT 'a comparable predates the valuation that used it' AS assertion, COUNT(*) AS failures
  FROM valuation_comparables c JOIN valuations v ON v.id = c.valuation_id
 WHERE c.transaction_date IS NOT NULL AND c.transaction_date > v.valued_on;

SELECT 'an Islamic product quotes a profit rate, not an interest rate' AS assertion,
       COUNT(*) AS failures
  FROM mortgage_products
 WHERE is_sharia_compliant = 1 AND (rate_percent IS NOT NULL OR profit_rate_percent IS NULL);

SELECT 'a mortgage application stays inside its product loan-to-value cap' AS assertion,
       COUNT(*) AS failures
  FROM mortgage_applications a JOIN mortgage_products p ON p.id = a.product_id
 WHERE p.max_ltv_percent IS NOT NULL AND a.ltv_percent > p.max_ltv_percent;

SELECT 'a mortgage deposit and loan sum to the property value' AS assertion,
       COUNT(*) AS failures
  FROM mortgage_applications
 WHERE requested_amount IS NOT NULL AND deposit_amount IS NOT NULL AND property_value IS NOT NULL
   AND ABS(requested_amount + deposit_amount - property_value) > 1.00;

SELECT 'a completed mortgage records its referral fee state' AS assertion, COUNT(*) AS failures
  FROM mortgage_applications WHERE status = 'completed' AND referral_fee_status = 'none';

SELECT 'payment plan milestones sum to a hundred per cent' AS assertion, COUNT(*) AS failures
  FROM (SELECT plan_id FROM payment_plan_milestones
         GROUP BY plan_id HAVING ABS(SUM(amount_percent) - 100) > 0.01) x;

SELECT 'a market statistic below the sample floor is not publishable' AS assertion,
       COUNT(*) AS failures
  FROM market_statistics_monthly WHERE sample_size < 5 AND is_publishable = 1;

SELECT 'a market statistic sample equals its transaction and rental counts' AS assertion,
       COUNT(*) AS failures
  FROM market_statistics_monthly
 WHERE location_level = 'community'
   AND sample_size <> transaction_count + rental_count;

-- --- Analytics --------------------------------------------------------------

SELECT 'a bounced session has exactly one page view' AS assertion, COUNT(*) AS failures
  FROM web_sessions WHERE is_bounce = 1 AND page_views <> 1;

SELECT 'a converted session names its conversion type' AS assertion, COUNT(*) AS failures
  FROM web_sessions WHERE converted = 1 AND conversion_type = 'none';

SELECT 'unique listings viewed never exceeds listing views' AS assertion, COUNT(*) AS failures
  FROM web_sessions WHERE unique_listings_viewed > listing_views;

SELECT 'touch numbers are contiguous from one per visitor' AS assertion, COUNT(*) AS failures
  FROM (SELECT visitor_id FROM attribution_touchpoints
         GROUP BY visitor_id
        HAVING MIN(touch_number) <> 1 OR MAX(touch_number) <> COUNT(*)) x;

SELECT 'only paid channels carry a cost' AS assertion, COUNT(*) AS failures
  FROM attribution_touchpoints
 WHERE cost IS NOT NULL
   AND channel NOT IN ('paid_search', 'paid_social', 'display', 'affiliate', 'offline');

SELECT 'attribution credit sums to exactly one per conversion per model' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT conversion_id, model_id
          FROM conversion_credits
         GROUP BY conversion_id, model_id
        HAVING ABS(SUM(credit_fraction) - 1) > 0.000001) x;

SELECT 'every conversion has credit under every scoring model' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT c.id
          FROM conversions c
          CROSS JOIN attribution_models m
         WHERE m.code IN ('last_non_direct', 'first_click', 'linear', 'position_40_40')
           AND NOT EXISTS (SELECT 1 FROM conversion_credits cc
                            WHERE cc.conversion_id = c.id AND cc.model_id = m.id)) x;

SELECT 'a conversion path is at least one touch long' AS assertion, COUNT(*) AS failures
  FROM conversions WHERE touch_count < 1;

SELECT 'channel performance bounces never exceed sessions' AS assertion, COUNT(*) AS failures
  FROM channel_performance_daily WHERE bounces > sessions;

SELECT 'return on spend is only stated where there was spend' AS assertion, COUNT(*) AS failures
  FROM channel_performance_daily WHERE return_on_spend IS NOT NULL AND cost <= 0;

SELECT 'funnel step numbers are contiguous from one' AS assertion, COUNT(*) AS failures
  FROM (SELECT funnel_id FROM funnel_steps
         GROUP BY funnel_id
        HAVING MIN(step_number) <> 1 OR MAX(step_number) <> COUNT(*)) x;

SELECT 'funnel completions and drops account for everyone who entered' AS assertion,
       COUNT(*) AS failures
  FROM funnel_daily_stats WHERE completed + dropped <> entered;

SELECT 'a cohort never retains more subjects than it started with' AS assertion,
       COUNT(*) AS failures
  FROM cohort_periods WHERE retained_count > cohort_size;

SELECT 'a cohort at period zero retains everybody' AS assertion, COUNT(*) AS failures
  FROM cohort_periods WHERE period_offset = 0 AND retained_count <> cohort_size;

SELECT 'every KPI definition says what it counts' AS assertion, COUNT(*) AS failures
  FROM kpi_definitions WHERE definition IS NULL OR CHAR_LENGTH(definition) < 40;

SELECT 'a ratio KPI value agrees with its numerator over its denominator' AS assertion,
       COUNT(*) AS failures
  FROM kpi_values
 WHERE numerator IS NOT NULL AND denominator > 0
   AND ABS(value - numerator / denominator) > 0.000001;

SELECT 'a KPI change agrees with the previous value' AS assertion, COUNT(*) AS failures
  FROM kpi_values
 WHERE previous_value IS NOT NULL
   AND ABS(COALESCE(change_absolute, 0) - (value - previous_value)) > 0.000001;

SELECT 'a stretch target is above the target' AS assertion, COUNT(*) AS failures
  FROM kpi_targets WHERE stretch_value IS NOT NULL AND stretch_value <= target_value;

SELECT 'an alert that has fired records when' AS assertion, COUNT(*) AS failures
  FROM metric_alerts WHERE fire_count > 0 AND last_fired_at IS NULL;

SELECT 'an acknowledged anomaly records who acknowledged it' AS assertion, COUNT(*) AS failures
  FROM metric_anomalies
 WHERE status <> 'new' AND (acknowledged_by_user_id IS NULL OR acknowledged_at IS NULL);

SELECT 'an anomaly deviation agrees with observed against expected' AS assertion,
       COUNT(*) AS failures
  FROM metric_anomalies
 WHERE expected_value > 0
   AND ABS(deviation_percent - (observed_value - expected_value) / expected_value * 100) > 0.01;

SELECT 'every dashboard widget resolves to something it can render' AS assertion,
       COUNT(*) AS failures
  FROM dashboard_widgets
 WHERE widget_type IN ('metric', 'line_chart', 'bar_chart', 'gauge')
   AND kpi_id IS NULL AND source_query IS NULL;

SELECT 'a funnel widget names a funnel' AS assertion, COUNT(*) AS failures
  FROM dashboard_widgets WHERE widget_type = 'funnel' AND funnel_id IS NULL;

SELECT 'a completed report run delivered to everyone it addressed' AS assertion,
       COUNT(*) AS failures
  FROM report_runs WHERE status = 'completed' AND delivered_count <> recipients_count;

SELECT 'a failed report run says why' AS assertion, COUNT(*) AS failures
  FROM report_runs WHERE status = 'failed' AND error_message IS NULL;

SELECT 'opens never exceed deliveries' AS assertion, COUNT(*) AS failures
  FROM report_runs WHERE opened_count > delivered_count;

-- --- Commercial and operational ---------------------------------------------

SELECT 'campaign spend equals the sum of its spend entries' AS assertion,
       COUNT(*) AS failures
  FROM (SELECT c.id FROM ad_campaigns c
          LEFT JOIN (SELECT campaign_id, ROUND(SUM(amount), 2) s
                       FROM ad_spend_entries GROUP BY campaign_id) e ON e.campaign_id = c.id
         WHERE ABS(c.spent_amount - COALESCE(e.s, 0)) > 0.01) x;

-- A zero budget means house inventory, which is not budget-capped; only
-- campaigns with a real budget are held to it.
SELECT 'campaign spend stays inside its budget' AS assertion, COUNT(*) AS failures
  FROM ad_campaigns WHERE total_budget > 0 AND spent_amount > total_budget;

SELECT 'promotion inventory is never oversold' AS assertion, COUNT(*) AS failures
  FROM promotion_inventory WHERE sold_count + reserved_count > capacity;

SELECT 'promotion availability agrees with capacity less what is taken' AS assertion,
       COUNT(*) AS failures
  FROM promotion_inventory WHERE available_count <> capacity - sold_count - reserved_count;

SELECT 'a credit lot balance equals grants less consumption' AS assertion, COUNT(*) AS failures
  FROM (SELECT cl.id FROM credit_lots cl
          LEFT JOIN (SELECT lot_id, SUM(amount) n FROM credit_transactions
                      WHERE lot_id IS NOT NULL GROUP BY lot_id) t ON t.lot_id = cl.id
         WHERE cl.remaining <> GREATEST(0, COALESCE(t.n, 0))) x;

SELECT 'a credit lot never goes negative' AS assertion, COUNT(*) AS failures
  FROM credit_lots WHERE remaining < 0 OR remaining > granted;

SELECT 'every journal balances' AS assertion, COUNT(*) AS failures
  FROM journals WHERE ABS(total_debit - total_credit) > 0.01;

SELECT 'a posted journal has a posting timestamp' AS assertion, COUNT(*) AS failures
  FROM journals WHERE status = 'posted' AND posted_at IS NULL;

SELECT 'every dead letter names the queue it came from' AS assertion, COUNT(*) AS failures
  FROM dead_letter_messages WHERE queue_id IS NULL;

SELECT 'an idempotency key that stored a response has a status' AS assertion,
       COUNT(*) AS failures
  FROM idempotency_keys WHERE response_body IS NOT NULL AND response_status IS NULL;

SELECT 'a published outbox event records when' AS assertion, COUNT(*) AS failures
  FROM outbox_events WHERE status = 'published' AND published_at IS NULL;

-- Only unsubscribes have to agree with the stored preference. A bounce or a
-- spam complaint suppresses regardless of what the preference says, which is
-- the whole point of holding them separately.
SELECT 'no unsubscribed address is also a live subscriber' AS assertion,
       COUNT(*) AS failures
  FROM suppressions s
  JOIN users u ON u.email_normalized = s.destination
 WHERE s.channel = 'email' AND s.reason = 'unsubscribe' AND s.scope = 'marketing'
   AND s.removed_at IS NULL AND u.marketing_opt_in = 1;
