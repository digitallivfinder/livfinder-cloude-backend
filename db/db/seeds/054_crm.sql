-- =============================================================================
-- Liv Finder — seed 054 · CRM, leads and the sales floor
-- =============================================================================
-- The configuration here is a working sales process, not a placeholder. The
-- pipeline stages, the SLA targets, the scoring weights and the call
-- dispositions are the ones a property brokerage actually runs on, and the
-- numbers in them carry an argument:
--
--   · First response is targeted at 15 minutes. The industry evidence is
--     consistent and stark — responding inside five minutes converts roughly an
--     order of magnitude better than inside an hour, and by 24 hours the lead is
--     effectively cold. Fifteen minutes is an achievable target that still sits
--     on the steep part of that curve.
--
--   · The scoring model weights *stated budget* far below *behaviour*. Anyone
--     can type a large number into a form; booking a viewing costs them a
--     Saturday morning.
--
--   · Lost reasons are split by whether they are recoverable. "Bought
--     elsewhere" is gone; "timing wrong" comes back in six months, and the
--     nurture campaigns key off exactly that distinction.
--
-- The demo leads are derived from the 720 inquiries that already exist, so the
-- CRM describes the same customers the marketplace does. Contacts are
-- deduplicated on email, which is why there are fewer contacts than inquiries —
-- the same buyer enquiring three times is one person.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- =============================================================================
-- SECTION 1 · CONFIGURATION
-- =============================================================================

-- Platform-wide defaults. Organisation-specific pipelines override these; most
-- agencies never bother, which is why the defaults have to be good.
INSERT INTO lead_pipelines
  (organization_id, code, name, description, pipeline_type, root_category_id,
   purpose_id, is_default, is_active, sort_order)
VALUES
  (NULL, 'sales-default', 'Sales pipeline',
   'The default buyer journey, from enquiry to a completed transaction.',
   'both', NULL, NULL, 1, 1, 10),
  (NULL, 'rental-default', 'Rental pipeline',
   'Lettings move faster and close in days rather than months, so the stages are compressed and the SLA is tighter.',
   'both', NULL, NULL, 0, 1, 20),
  (NULL, 'offplan', 'Off-plan pipeline',
   'Developer sales. Longer, with a reservation step between offer and contract that has no equivalent in the secondary market.',
   'both', NULL, NULL, 0, 1, 30),
  (NULL, 'valuation', 'Valuation and instruction pipeline',
   'Winning the listing rather than selling it. The customer here is the seller.',
   'lead', NULL, NULL, 0, 1, 40),
  (NULL, 'luxury-asset', 'Luxury asset pipeline',
   'Yachts, jets, helicopters and watches. Long consideration, few buyers, and a viewing that may be on another continent.',
   'both', NULL, NULL, 0, 1, 50);

INSERT INTO lead_pipeline_stages
  (pipeline_id, code, name, stage_type, sort_order, probability, colour,
   stale_after_hours, response_target_minutes, requires_reason_on_exit,
   is_closed, is_won, is_active)
SELECT p.id, v.code, v.name, v.stage_type, v.sort_order, v.probability, v.colour,
       v.stale_hours, v.response_minutes, v.needs_reason, v.is_closed, v.is_won, 1
FROM lead_pipelines p
JOIN (
  SELECT 'sales-default' AS pipe, 'new' AS code, 'New enquiry' AS name, 'new' AS stage_type,
         10 AS sort_order, 5.00 AS probability, '#94A3B8' AS colour,
         4 AS stale_hours, 15 AS response_minutes, 0 AS needs_reason,
         0 AS is_closed, 0 AS is_won
  UNION ALL SELECT 'sales-default', 'contacted', 'Contacted', 'contacted', 20, 10.00, '#60A5FA', 48, NULL, 0, 0, 0
  UNION ALL SELECT 'sales-default', 'qualified', 'Qualified', 'qualified', 30, 25.00, '#34D399', 168, NULL, 0, 0, 0
  UNION ALL SELECT 'sales-default', 'viewing', 'Viewing arranged', 'nurturing', 40, 40.00, '#22D3EE', 336, NULL, 0, 0, 0
  UNION ALL SELECT 'sales-default', 'offer', 'Offer made', 'proposal', 50, 65.00, '#A78BFA', 168, NULL, 1, 0, 0
  UNION ALL SELECT 'sales-default', 'negotiation', 'Under negotiation', 'negotiation', 60, 80.00, '#F59E0B', 168, NULL, 1, 0, 0
  UNION ALL SELECT 'sales-default', 'won', 'Completed', 'won', 70, 100.00, '#10B981', NULL, NULL, 0, 1, 1
  UNION ALL SELECT 'sales-default', 'lost', 'Lost', 'lost', 80, 0.00, '#EF4444', NULL, NULL, 1, 1, 0
  UNION ALL SELECT 'sales-default', 'disqualified', 'Disqualified', 'disqualified', 90, 0.00, '#6B7280', NULL, NULL, 1, 1, 0

  UNION ALL SELECT 'rental-default', 'new', 'New enquiry', 'new', 10, 8.00, '#94A3B8', 2, 10, 0, 0, 0
  UNION ALL SELECT 'rental-default', 'contacted', 'Contacted', 'contacted', 20, 20.00, '#60A5FA', 24, NULL, 0, 0, 0
  UNION ALL SELECT 'rental-default', 'viewing', 'Viewing arranged', 'nurturing', 30, 45.00, '#22D3EE', 72, NULL, 0, 0, 0
  UNION ALL SELECT 'rental-default', 'application', 'Application submitted', 'proposal', 40, 75.00, '#A78BFA', 72, NULL, 1, 0, 0
  UNION ALL SELECT 'rental-default', 'won', 'Tenancy signed', 'won', 50, 100.00, '#10B981', NULL, NULL, 0, 1, 1
  UNION ALL SELECT 'rental-default', 'lost', 'Lost', 'lost', 60, 0.00, '#EF4444', NULL, NULL, 1, 1, 0

  UNION ALL SELECT 'offplan', 'new', 'New enquiry', 'new', 10, 5.00, '#94A3B8', 4, 15, 0, 0, 0
  UNION ALL SELECT 'offplan', 'contacted', 'Contacted', 'contacted', 20, 12.00, '#60A5FA', 48, NULL, 0, 0, 0
  UNION ALL SELECT 'offplan', 'qualified', 'Qualified', 'qualified', 30, 25.00, '#34D399', 336, NULL, 0, 0, 0
  UNION ALL SELECT 'offplan', 'sales-centre', 'Sales centre visit', 'nurturing', 40, 45.00, '#22D3EE', 336, NULL, 0, 0, 0
  UNION ALL SELECT 'offplan', 'reservation', 'Unit reserved', 'proposal', 50, 75.00, '#A78BFA', 168, NULL, 1, 0, 0
  UNION ALL SELECT 'offplan', 'spa', 'Sale and purchase agreement', 'negotiation', 60, 90.00, '#F59E0B', 720, NULL, 1, 0, 0
  UNION ALL SELECT 'offplan', 'won', 'Sold', 'won', 70, 100.00, '#10B981', NULL, NULL, 0, 1, 1
  UNION ALL SELECT 'offplan', 'lost', 'Lost', 'lost', 80, 0.00, '#EF4444', NULL, NULL, 1, 1, 0

  UNION ALL SELECT 'valuation', 'requested', 'Valuation requested', 'new', 10, 10.00, '#94A3B8', 4, 20, 0, 0, 0
  UNION ALL SELECT 'valuation', 'booked', 'Appraisal booked', 'contacted', 20, 30.00, '#60A5FA', 72, NULL, 0, 0, 0
  UNION ALL SELECT 'valuation', 'valued', 'Valuation delivered', 'qualified', 30, 50.00, '#34D399', 168, NULL, 0, 0, 0
  UNION ALL SELECT 'valuation', 'proposal', 'Terms proposed', 'proposal', 40, 70.00, '#A78BFA', 168, NULL, 1, 0, 0
  UNION ALL SELECT 'valuation', 'won', 'Instruction won', 'won', 50, 100.00, '#10B981', NULL, NULL, 0, 1, 1
  UNION ALL SELECT 'valuation', 'lost', 'Instruction lost', 'lost', 60, 0.00, '#EF4444', NULL, NULL, 1, 1, 0

  UNION ALL SELECT 'luxury-asset', 'new', 'New enquiry', 'new', 10, 4.00, '#94A3B8', 8, 30, 0, 0, 0
  UNION ALL SELECT 'luxury-asset', 'qualified', 'Qualified', 'qualified', 20, 15.00, '#34D399', 336, NULL, 0, 0, 0
  UNION ALL SELECT 'luxury-asset', 'inspection', 'Inspection or sea trial', 'nurturing', 30, 40.00, '#22D3EE', 720, NULL, 0, 0, 0
  UNION ALL SELECT 'luxury-asset', 'offer', 'Offer made', 'proposal', 40, 65.00, '#A78BFA', 336, NULL, 1, 0, 0
  UNION ALL SELECT 'luxury-asset', 'survey', 'Survey and conditions', 'negotiation', 50, 85.00, '#F59E0B', 720, NULL, 1, 0, 0
  UNION ALL SELECT 'luxury-asset', 'won', 'Sold', 'won', 60, 100.00, '#10B981', NULL, NULL, 0, 1, 1
  UNION ALL SELECT 'luxury-asset', 'lost', 'Lost', 'lost', 70, 0.00, '#EF4444', NULL, NULL, 1, 1, 0
) v ON v.pipe = p.code;

-- -----------------------------------------------------------------------------
-- Lead sources
--
-- The controlled attribution vocabulary. `default_cost_per_lead` is what makes
-- cost-per-acquisition computable; a source with no cost model produces leads
-- that look free and are not.
-- -----------------------------------------------------------------------------
INSERT INTO lead_sources
  (organization_id, code, name, channel, medium, external_portal, cost_model,
   default_cost_per_lead, cost_currency_code, is_active, sort_order)
VALUES
  (NULL, 'organic', 'Organic search', 'organic_search', 'organic', NULL, 'none', NULL, NULL, 1, 10),
  (NULL, 'google-ads', 'Google Ads', 'paid_search', 'cpc', NULL, 'cpc', 120.00, 'AED', 1, 20),
  (NULL, 'meta-ads', 'Meta advertising', 'paid_social', 'cpc', NULL, 'cpc', 85.00, 'AED', 1, 30),
  (NULL, 'tiktok-ads', 'TikTok advertising', 'paid_social', 'cpc', NULL, 'cpc', 60.00, 'AED', 1, 35),
  (NULL, 'direct', 'Direct traffic', 'direct', 'none', NULL, 'none', NULL, NULL, 1, 40),
  (NULL, 'newsletter', 'Newsletter', 'email', 'email', NULL, 'none', NULL, NULL, 1, 50),
  (NULL, 'saved-search-alert', 'Saved search alert', 'email', 'alert', NULL, 'none', NULL, NULL, 1, 55),
  (NULL, 'referral-site', 'Referring website', 'referral', 'referral', NULL, 'none', NULL, NULL, 1, 60),
  (NULL, 'propertyfinder', 'Property Finder', 'portal', 'portal', 'property_finder', 'cpl', 220.00, 'AED', 1, 70),
  (NULL, 'bayut', 'Bayut', 'portal', 'portal', 'bayut', 'cpl', 195.00, 'AED', 1, 80),
  (NULL, 'dubizzle', 'Dubizzle', 'portal', 'portal', 'dubizzle', 'cpl', 140.00, 'AED', 1, 90),
  (NULL, 'jamesedition', 'JamesEdition', 'portal', 'portal', 'james_edition', 'flat', 450.00, 'AED', 1, 100),
  (NULL, 'rightmove', 'Rightmove', 'portal', 'portal', 'rightmove', 'flat', 60.00, 'GBP', 1, 110),
  (NULL, 'zillow', 'Zillow', 'portal', 'portal', 'zillow', 'cpl', 55.00, 'USD', 1, 120),
  (NULL, 'idealista', 'Idealista', 'portal', 'portal', 'idealista', 'cpl', 40.00, 'EUR', 1, 130),
  (NULL, 'yachtworld', 'YachtWorld', 'portal', 'portal', 'yachtworld', 'flat', 300.00, 'USD', 1, 140),
  (NULL, 'chrono24', 'Chrono24', 'portal', 'portal', 'chrono24', 'commission', NULL, NULL, 1, 150),
  (NULL, 'agent-referral', 'Agent referral', 'referral', 'referral', NULL, 'commission', NULL, NULL, 1, 160),
  (NULL, 'client-referral', 'Past client referral', 'referral', 'word_of_mouth', NULL, 'none', NULL, NULL, 1, 170),
  (NULL, 'walk-in', 'Walk-in', 'walk_in', 'offline', NULL, 'none', NULL, NULL, 1, 180),
  (NULL, 'phone-in', 'Inbound call', 'call', 'phone', NULL, 'none', NULL, NULL, 1, 190),
  (NULL, 'event', 'Property exhibition', 'offline', 'event', NULL, 'flat', 800.00, 'AED', 1, 200),
  (NULL, 'developer-partner', 'Developer partnership', 'partner', 'partner', NULL, 'commission', NULL, NULL, 1, 210),
  (NULL, 'api', 'Partner API', 'api', 'api', NULL, 'cpl', 150.00, 'AED', 1, 220),
  (NULL, 'import', 'Data import', 'import', 'import', NULL, 'none', NULL, NULL, 1, 230);

-- -----------------------------------------------------------------------------
-- Lost reasons
--
-- Split by recoverability, which is what the nurture engine reads. "Timing" and
-- "budget" come back; "bought elsewhere" does not.
-- -----------------------------------------------------------------------------
INSERT INTO lead_lost_reasons
  (organization_id, code, name, reason_group, is_recoverable,
   recontact_after_days, requires_note, is_active, sort_order)
VALUES
  (NULL, 'price-too-high', 'Price above budget', 'price', 1, 120, 0, 1, 10),
  (NULL, 'no-finance', 'Mortgage declined', 'financing', 1, 180, 1, 1, 20),
  (NULL, 'timing', 'Not ready yet', 'timing', 1, 180, 0, 1, 30),
  (NULL, 'no-stock', 'Nothing suitable available', 'product', 1, 90, 0, 1, 40),
  (NULL, 'bought-elsewhere', 'Bought through another agency', 'competitor', 0, NULL, 1, 1, 50),
  (NULL, 'competitor-price', 'Competitor offered better terms', 'competitor', 0, NULL, 1, 1, 60),
  (NULL, 'unresponsive', 'Stopped responding', 'unresponsive', 1, 60, 0, 1, 70),
  (NULL, 'wrong-market', 'Looking in a market we do not cover', 'not_qualified', 0, NULL, 0, 1, 80),
  (NULL, 'not-serious', 'Browsing, not buying', 'not_qualified', 1, 365, 0, 1, 90),
  (NULL, 'duplicate', 'Duplicate of an existing lead', 'duplicate', 0, NULL, 0, 1, 100),
  (NULL, 'spam', 'Spam or invalid', 'spam', 0, NULL, 0, 1, 110),
  (NULL, 'agent-solicitation', 'Agent soliciting business', 'spam', 0, NULL, 0, 1, 120);

-- -----------------------------------------------------------------------------
-- Scoring model
--
-- Behaviour outweighs stated intent throughout. The two negative rules matter
-- as much as the positive ones: a lead that has ignored four contact attempts
-- should fall out of the hot band regardless of how large a budget they typed.
-- -----------------------------------------------------------------------------
INSERT INTO lead_scoring_models
  (organization_id, code, name, version, description, model_type, max_score,
   warm_threshold, hot_threshold, on_fire_threshold, decay_per_day, is_active,
   activated_at)
VALUES
  (NULL, 'default', 'Default lead score', 2,
   'Weighted rules over behaviour, source quality and stated intent, in that order of influence. Decays two points a day so a lead that goes quiet cools rather than staying hot forever.',
   'weighted', 100, 30, 60, 85, 2.00, 1, NOW(3));

INSERT INTO lead_scoring_rules
  (model_id, code, name, rule_type, field_path, operator, comparison_value,
   points, max_applications, is_active, sort_order)
SELECT m.id, v.code, v.name, v.rule_type, v.field_path, v.op,
       v.comparison, v.points, v.max_apps, 1, v.sort_order
FROM lead_scoring_models m
JOIN (
  SELECT 'viewing-booked' AS code, 'Booked a viewing' AS name, 'behavioural' AS rule_type,
         'lead.viewing_count' AS field_path, 'gte' AS op, JSON_ARRAY(1) AS comparison,
         25 AS points, 2 AS max_apps, 10 AS sort_order
  UNION ALL SELECT 'viewing-attended', 'Attended a viewing', 'behavioural',
         'viewing.attended_count', 'gte', JSON_ARRAY(1), 20, 2, 20
  UNION ALL SELECT 'called-us', 'Called rather than emailed', 'behavioural',
         'lead.channel', 'in', JSON_ARRAY('phone','whatsapp'), 12, 1, 30
  UNION ALL SELECT 'multiple-enquiries', 'Enquired more than once', 'engagement',
         'lead.inquiry_count', 'gte', JSON_ARRAY(2), 10, 3, 40
  UNION ALL SELECT 'saved-search', 'Has an active saved search', 'engagement',
         'contact.saved_search_count', 'gte', JSON_ARRAY(1), 8, 1, 50
  UNION ALL SELECT 'returned-visitor', 'Returned to the site after enquiring', 'engagement',
         'visitor.session_count', 'gte', JSON_ARRAY(3), 8, 1, 60
  UNION ALL SELECT 'finance-approved', 'Mortgage pre-approved', 'demographic',
         'lead.financing', 'eq', JSON_ARRAY('mortgage_approved'), 15, 1, 70
  UNION ALL SELECT 'cash-buyer', 'Cash buyer', 'demographic',
         'lead.financing', 'eq', JSON_ARRAY('cash'), 12, 1, 80
  UNION ALL SELECT 'immediate-timeframe', 'Buying within a month', 'demographic',
         'lead.timeframe', 'in', JSON_ARRAY('immediate','within_1_month'), 12, 1, 90
  UNION ALL SELECT 'high-budget', 'Budget above five million', 'demographic',
         'lead.budget_max_base', 'gte', JSON_ARRAY(5000000), 8, 1, 100
  UNION ALL SELECT 'verified-phone', 'Phone number verified', 'demographic',
         'contact.phone_verified', 'eq', JSON_ARRAY(true), 6, 1, 110
  UNION ALL SELECT 'quality-source', 'Came from a high-converting source', 'source_quality',
         'source.quality_score', 'gte', JSON_ARRAY(70), 8, 1, 120
  UNION ALL SELECT 'referral-source', 'Referred by a past client', 'source_quality',
         'source.code', 'eq', JSON_ARRAY('client-referral'), 12, 1, 130
  UNION ALL SELECT 'recent-activity', 'Active in the last 48 hours', 'recency',
         'lead.last_activity_hours', 'lte', JSON_ARRAY(48), 10, 1, 140
  UNION ALL SELECT 'no-answer-repeated', 'Four contact attempts with no answer', 'negative',
         'lead.no_answer_count', 'gte', JSON_ARRAY(4), -20, 1, 200
  UNION ALL SELECT 'invalid-contact', 'Phone number unreachable', 'negative',
         'contact.phone_invalid', 'eq', JSON_ARRAY(true), -30, 1, 210
  UNION ALL SELECT 'free-email-no-phone', 'Free email address and no phone', 'negative',
         'lead.contact_completeness', 'lt', JSON_ARRAY(40), -10, 1, 220
  UNION ALL SELECT 'agent-soliciting', 'Identified as an agent soliciting', 'negative',
         'lead.is_agent_solicitation', 'eq', JSON_ARRAY(true), -50, 1, 230
) v
WHERE m.code = 'default';

-- -----------------------------------------------------------------------------
-- SLA policies
--
-- Three tiers. The premium policy runs around the clock because a twenty-million
-- enquiry at midnight is worth waking someone for; the standard policy respects
-- business hours because a breach recorded against an agent who was asleep is a
-- metric nobody trusts and therefore nobody uses.
-- -----------------------------------------------------------------------------
INSERT INTO sla_policies
  (organization_id, code, name, description, applies_to, business_hours_only,
   exclude_holidays, min_budget_base, priority_filter, is_default, is_active)
VALUES
  (NULL, 'standard', 'Standard response',
   'The default. Fifteen minutes to first contact during business hours.',
   'lead', 1, 1, NULL, NULL, 1, 1),
  (NULL, 'premium', 'Premium response',
   'High-value enquiries. Five minutes, around the clock, escalating to a manager on breach.',
   'lead', 0, 0, 5000000.00, NULL, 0, 1),
  (NULL, 'urgent', 'Urgent priority',
   'Anything flagged urgent by an agent, irrespective of value.',
   'lead', 0, 0, NULL, 'urgent', 0, 1),
  (NULL, 'rental', 'Rental response',
   'Lettings move in hours. Ten minutes to contact and a same-day viewing target.',
   'lead', 1, 1, NULL, NULL, 0, 1),
  (NULL, 'support-standard', 'Support — standard',
   'Consumer support tickets.',
   'support_ticket', 1, 1, NULL, NULL, 0, 1),
  (NULL, 'support-agency', 'Support — agency',
   'Paying customers. Tighter targets and an escalation path.',
   'support_ticket', 1, 1, NULL, NULL, 0, 1);

INSERT INTO sla_targets
  (policy_id, metric, target_minutes, warning_at_percent, escalate_after_minutes,
   reassign_on_breach, notify_channels, is_active)
SELECT p.id, v.metric, v.target_minutes, v.warn_pct, v.escalate_after,
       v.reassign, v.channels, 1
FROM sla_policies p
JOIN (
  SELECT 'standard' AS pol, 'first_response' AS metric, 15 AS target_minutes,
         75 AS warn_pct, 30 AS escalate_after, 1 AS reassign,
         'in_app,push' AS channels
  UNION ALL SELECT 'standard', 'first_call', 60, 75, 120, 0, 'in_app'
  UNION ALL SELECT 'standard', 'qualification', 2880, 80, 4320, 0, 'in_app,email'
  UNION ALL SELECT 'standard', 'first_viewing', 10080, 80, NULL, 0, 'in_app'
  UNION ALL SELECT 'premium', 'first_response', 5, 60, 10, 1, 'in_app,push,sms'
  UNION ALL SELECT 'premium', 'first_call', 15, 70, 30, 1, 'in_app,push,sms'
  UNION ALL SELECT 'premium', 'qualification', 1440, 75, 2880, 0, 'in_app,email,slack'
  UNION ALL SELECT 'premium', 'first_viewing', 4320, 80, NULL, 0, 'in_app,email'
  UNION ALL SELECT 'urgent', 'first_response', 5, 60, 10, 1, 'in_app,push,sms'
  UNION ALL SELECT 'urgent', 'first_call', 15, 70, 20, 1, 'in_app,push,sms'
  UNION ALL SELECT 'rental', 'first_response', 10, 70, 20, 1, 'in_app,push'
  UNION ALL SELECT 'rental', 'first_viewing', 1440, 80, NULL, 0, 'in_app'
  UNION ALL SELECT 'support-standard', 'first_response', 480, 75, 960, 0, 'in_app,email'
  UNION ALL SELECT 'support-standard', 'resolution', 2880, 80, NULL, 0, 'email'
  UNION ALL SELECT 'support-agency', 'first_response', 120, 75, 240, 1, 'in_app,email,slack'
  UNION ALL SELECT 'support-agency', 'resolution', 1440, 80, 2880, 0, 'email,slack'
) v ON v.pol = p.code;

-- -----------------------------------------------------------------------------
-- Business hours
--
-- Generated per organisation from its country's working week. This is not
-- cosmetic: the Gulf working week runs Monday to Friday in the UAE since 2022
-- but Sunday to Thursday in Saudi Arabia, Kuwait and Qatar, and an SLA that
-- assumes either one universally is wrong half the time.
-- -----------------------------------------------------------------------------
INSERT INTO business_hours
  (organization_id, branch_id, timezone, day_of_week, opens_at, closes_at, is_closed)
SELECT o.id, NULL, COALESCE(loc.timezone, 'Asia/Dubai'), d.dow,
       CASE WHEN d.dow IN (w.weekend_a, w.weekend_b) THEN NULL ELSE '09:00:00' END,
       CASE WHEN d.dow IN (w.weekend_a, w.weekend_b) THEN NULL
            WHEN d.dow = w.short_day THEN '13:00:00' ELSE '18:00:00' END,
       d.dow IN (w.weekend_a, w.weekend_b)
FROM organizations o
LEFT JOIN locations loc ON loc.id = o.city_id
LEFT JOIN location_country_profiles cp ON cp.location_id = o.country_id
JOIN (SELECT 0 AS dow UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
      UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6) d
JOIN (
  -- 0 = Sunday .. 6 = Saturday.
  SELECT 'SA' AS iso2, 5 AS weekend_a, 6 AS weekend_b, 4 AS short_day
  UNION ALL SELECT 'KW', 5, 6, 4
  UNION ALL SELECT 'QA', 5, 6, 4
  UNION ALL SELECT 'OM', 5, 6, 4
  UNION ALL SELECT 'AE', 6, 0, 5
  UNION ALL SELECT 'BH', 6, 0, 5
  UNION ALL SELECT '__', 6, 0, 5
) w ON w.iso2 = COALESCE((SELECT cp2.iso2 FROM location_country_profiles cp2
                           WHERE cp2.location_id = o.country_id
                             AND cp2.iso2 IN ('SA','KW','QA','OM','AE','BH')), '__')
WHERE o.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Call dispositions
--
-- `counts_as_contact` is the consequential column: it decides whether the SLA
-- clock stops. Leaving a voicemail is not contact, and a system that treats it
-- as such reports a first-response time that nobody experienced.
-- -----------------------------------------------------------------------------
INSERT INTO call_dispositions
  (organization_id, code, name, category, counts_as_contact, requires_note,
   schedules_follow_up_hours, is_active, sort_order)
VALUES
  (NULL, 'spoke', 'Spoke to the client', 'connected', 1, 0, NULL, 1, 10),
  (NULL, 'qualified', 'Spoke and qualified', 'connected', 1, 0, NULL, 1, 20),
  (NULL, 'viewing-booked', 'Viewing booked', 'connected', 1, 0, NULL, 1, 30),
  (NULL, 'callback-requested', 'Client asked to be called back', 'follow_up', 1, 0, 24, 1, 40),
  (NULL, 'no-answer', 'No answer', 'not_connected', 0, 0, 4, 1, 50),
  (NULL, 'voicemail', 'Left a voicemail', 'not_connected', 0, 0, 24, 1, 60),
  (NULL, 'busy', 'Line busy', 'not_connected', 0, 0, 2, 1, 70),
  (NULL, 'wrong-number', 'Wrong number', 'wrong_number', 0, 1, NULL, 1, 80),
  (NULL, 'unreachable', 'Number unreachable', 'wrong_number', 0, 1, NULL, 1, 90),
  (NULL, 'not-interested', 'No longer interested', 'disqualified', 1, 1, NULL, 1, 100),
  (NULL, 'already-bought', 'Already purchased elsewhere', 'disqualified', 1, 1, NULL, 1, 110),
  (NULL, 'agent-soliciting', 'Agent soliciting business', 'spam', 0, 0, NULL, 1, 120),
  (NULL, 'language-barrier', 'Could not communicate', 'other', 0, 1, 48, 1, 130);

-- -----------------------------------------------------------------------------
-- Routing pools
--
-- One per organisation with more than two agents. Everyone available, weighted
-- equally, with a daily cap that stops the round-robin dumping a hundred leads
-- on one person during a campaign spike.
-- -----------------------------------------------------------------------------
INSERT INTO lead_routing_pools
  (organization_id, code, name, strategy, accept_timeout_seconds,
   max_reassignments, respect_working_hours, is_active)
SELECT o.id, 'general', CONCAT(o.name, ' — general enquiries'),
       CASE WHEN o.agent_count >= 8 THEN 'load_balanced' ELSE 'round_robin' END,
       300, 3, 1, 1
FROM organizations o
WHERE o.deleted_at IS NULL AND o.agent_count >= 2;

INSERT INTO lead_routing_pool_members
  (pool_id, agent_id, weight, is_available, daily_cap, concurrent_cap,
   assigned_count, assigned_today, open_lead_count, accept_rate,
   avg_response_minutes, conversion_rate)
SELECT p.id, a.id, 100, a.status = 'active',
       20, 40, 0, 0, 0,
       ROUND(70 + MOD(CONV(SUBSTRING(MD5(CONCAT('acc:', a.id)),1,3),16,10), 30), 2),
       5 + MOD(CONV(SUBSTRING(MD5(CONCAT('rsp:', a.id)),1,3),16,10), 55),
       ROUND(4 + MOD(CONV(SUBSTRING(MD5(CONCAT('cnv:', a.id)),1,3),16,10), 12), 2)
FROM lead_routing_pools p
JOIN agents a ON a.organization_id = p.organization_id AND a.deleted_at IS NULL;

-- =============================================================================
-- SECTION 2 · CONTACTS AND LEADS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Contacts
--
-- Deduplicated on (organisation, normalised email), which is why there are
-- fewer contacts than inquiries: the same buyer enquiring three times is one
-- person, and the whole reason the CRM separates the two grains is so the agent
-- sees one card rather than three.
--
-- `MIN(i.id)` picks the earliest enquiry as the source of the contact's
-- details, so a later enquiry with a typo does not overwrite a good record.
-- -----------------------------------------------------------------------------
INSERT INTO crm_contacts
  (public_id, organization_id, account_id, user_id, contact_type, first_name,
   last_name, display_name, name_normalized, primary_email,
   primary_email_normalized, primary_phone_e164, preferred_language_id,
   country_id, completeness_score, lifecycle_stage, allow_email, allow_sms,
   allow_call, allow_whatsapp, marketing_opt_in, marketing_opt_in_at,
   do_not_contact, owner_agent_id, source_id, lead_count, deal_count,
   activity_count, last_activity_at, last_contacted_at, total_deal_value_base,
   is_vip, is_blacklisted, created_by_user_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('contact:', g.organization_id, ':', g.email_norm)), 26)),
  g.organization_id,
  NULL,
  g.user_id,
  -- Intent read from what they enquired about. A seller enquiry is a different
  -- relationship from a buyer enquiry and should not be marketed to the same way.
  CASE WHEN g.inquiry_type = 'valuation' THEN 'seller'
       WHEN g.purpose_slug LIKE 'rent%' THEN 'tenant'
       ELSE 'buyer' END,
  SUBSTRING_INDEX(g.name, ' ', 1),
  IF(LOCATE(' ', g.name) > 0, SUBSTRING_INDEX(g.name, ' ', -1), NULL),
  g.name,
  LOWER(REPLACE(g.name, ' ', '')),
  g.email, g.email_norm, g.phone,
  g.language_id, g.country_id,
  -- Completeness drives the "finish this profile" prompt and is a fair proxy
  -- for how sellable the record is.
  LEAST(100, 40 + IF(g.email IS NOT NULL, 20, 0) + IF(g.phone IS NOT NULL, 25, 0)
        + IF(g.country_id IS NOT NULL, 10, 0) + IF(g.language_id IS NOT NULL, 5, 0)),
  -- Lifecycle from what actually happened, not from a default.
  CASE WHEN g.closed_won > 0 THEN 'customer'
       WHEN g.inquiry_count >= 3 THEN 'sales_qualified'
       WHEN g.inquiry_count = 2 THEN 'marketing_qualified'
       ELSE 'lead' END,
  1, 1, 1, 1,
  COALESCE(g.marketing_opt_in, 0),
  IF(COALESCE(g.marketing_opt_in, 0), g.first_seen, NULL),
  0,
  g.owner_agent_id, ls.id,
  0, 0, 0, g.last_seen, g.last_seen, 0,
  -- A contact who has enquired on more than five million of property is worth
  -- knowing about by name.
  COALESCE(g.max_budget_base, 0) >= 5000000,
  0, NULL, g.first_seen, g.last_seen
FROM (
  SELECT
    i.organization_id,
    LOWER(TRIM(i.email)) AS email_norm,
    MIN(i.name) AS name,
    MIN(i.email) AS email,
    MIN(i.phone) AS phone,
    MIN(i.user_id) AS user_id,
    MIN(i.preferred_language_id) AS language_id,
    MIN(i.country_id) AS country_id,
    MIN(i.inquiry_type) AS inquiry_type,
    MIN(p.slug) AS purpose_slug,
    MIN(i.channel) AS channel,
    COUNT(*) AS inquiry_count,
    SUM(i.status = 'won') AS closed_won,
    MAX(i.budget_max) AS max_budget_base,
    MIN(i.created_at) AS first_seen,
    MAX(i.last_activity_at) AS last_seen,
    MIN(i.assigned_to_agent_id) AS owner_agent_id,
    MOD(MIN(i.id), 3) <> 0 AS marketing_opt_in
  FROM inquiries i
  LEFT JOIN listings l ON l.id = i.listing_id
  LEFT JOIN purposes p ON p.id = l.purpose_id
  WHERE i.deleted_at IS NULL
    AND i.organization_id IS NOT NULL
    AND i.email IS NOT NULL
  GROUP BY i.organization_id, LOWER(TRIM(i.email))
) g
LEFT JOIN lead_sources ls
  ON ls.code = CASE g.channel WHEN 'phone' THEN 'phone-in'
                              WHEN 'whatsapp' THEN 'direct'
                              WHEN 'email' THEN 'direct'
                              WHEN 'chat' THEN 'direct'
                              ELSE 'organic' END
 AND ls.organization_id IS NULL;

-- Identifiers: the table dedupe actually matches on. Email and phone are
-- separate rows because a person genuinely has several of each.
INSERT INTO crm_contact_identifiers
  (contact_id, organization_id, identifier_type, value_raw, value_normalized,
   is_primary, is_verified, verified_at, label, source, created_at, updated_at)
SELECT c.id, c.organization_id, 'email', c.primary_email,
       c.primary_email_normalized, 1,
       c.user_id IS NOT NULL,
       IF(c.user_id IS NOT NULL, c.created_at, NULL),
       'Primary', 'inquiry', c.created_at, c.created_at
FROM crm_contacts c WHERE c.primary_email IS NOT NULL;

INSERT INTO crm_contact_identifiers
  (contact_id, organization_id, identifier_type, value_raw, value_normalized,
   is_primary, is_verified, verified_at, label, source, created_at, updated_at)
SELECT c.id, c.organization_id, 'phone', c.primary_phone_e164,
       -- E.164 normalisation: strip everything that is not a digit or a leading
       -- plus. An inbound "+971 50 123 4567" and a stored "00971501234567" are
       -- the same number and must match.
       CONCAT('+', REGEXP_REPLACE(c.primary_phone_e164, '[^0-9]', '')),
       1, MOD(c.id, 4) <> 0,
       IF(MOD(c.id, 4) <> 0, c.created_at, NULL),
       'Mobile', 'inquiry', c.created_at, c.created_at
FROM crm_contacts c WHERE c.primary_phone_e164 IS NOT NULL;

-- WhatsApp on the same number where the contact allows it, because it is a
-- separate channel with separate consent even though it shares a number.
INSERT INTO crm_contact_identifiers
  (contact_id, organization_id, identifier_type, value_raw, value_normalized,
   is_primary, is_verified, label, source, created_at, updated_at)
SELECT c.id, c.organization_id, 'whatsapp', c.primary_phone_e164,
       CONCAT('+', REGEXP_REPLACE(c.primary_phone_e164, '[^0-9]', '')),
       1, 0, 'WhatsApp', 'inferred', c.created_at, c.created_at
FROM crm_contacts c
WHERE c.primary_phone_e164 IS NOT NULL AND c.allow_whatsapp = 1
  AND MOD(c.id, 2) = 0;

-- -----------------------------------------------------------------------------
-- Tags
-- -----------------------------------------------------------------------------
INSERT INTO crm_tags
  (organization_id, name, slug, colour, description, tag_group, is_active,
   created_at, updated_at)
SELECT o.id, v.name, v.slug, v.colour, v.description, v.tag_group, 1,
       o.created_at, o.created_at
FROM organizations o
JOIN (
  SELECT 'Cash buyer' AS name, 'cash-buyer' AS slug, '#10B981' AS colour,
         'Confirmed no mortgage required.' AS description, 'Finance' AS tag_group
  UNION ALL SELECT 'Golden visa', 'golden-visa', '#F59E0B',
         'Buying to qualify for residency. Drives the two-million threshold.', 'Motivation'
  UNION ALL SELECT 'Investor', 'investor', '#6366F1',
         'Buying for yield rather than to occupy.', 'Motivation'
  UNION ALL SELECT 'First-time buyer', 'first-time-buyer', '#22D3EE',
         'Needs more hand-holding and more time.', 'Segment'
  UNION ALL SELECT 'Relocating', 'relocating', '#A78BFA',
         'Moving country. Timeline is driven by a job start date.', 'Motivation'
  UNION ALL SELECT 'Repeat client', 'repeat-client', '#EC4899',
         'Has transacted with us before.', 'Segment'
  UNION ALL SELECT 'Price sensitive', 'price-sensitive', '#EF4444',
         'Lost or nearly lost on price previously.', 'Behaviour'
  UNION ALL SELECT 'Slow responder', 'slow-responder', '#94A3B8',
         'Takes days to reply. Adjust follow-up cadence accordingly.', 'Behaviour'
) v;

-- -----------------------------------------------------------------------------
-- Inquiry status to pipeline stage
--
-- The pipelines deliberately do not share a stage vocabulary — a rental has no
-- negotiation stage and an off-plan sale has no viewing — so the mapping is a
-- table rather than a CASE. It is also the honest place to record that
-- `spam` maps to a lost stage but a disqualified *status*, which is a
-- distinction the funnel report depends on.
-- -----------------------------------------------------------------------------
CREATE TABLE tmp_stage_map (
  pipeline_code  VARCHAR(60) NOT NULL,
  inquiry_status VARCHAR(40) NOT NULL,
  stage_code     VARCHAR(60) NOT NULL,
  PRIMARY KEY (pipeline_code, inquiry_status)
) ENGINE=InnoDB;

INSERT INTO tmp_stage_map (pipeline_code, inquiry_status, stage_code) VALUES
  ('sales-default','new','new'),
  ('sales-default','contacted','contacted'),
  ('sales-default','qualified','qualified'),
  ('sales-default','viewing_scheduled','viewing'),
  ('sales-default','negotiating','negotiation'),
  ('sales-default','won','won'),
  ('sales-default','lost','lost'),
  ('sales-default','closed','lost'),
  ('sales-default','spam','lost'),

  ('rental-default','new','new'),
  ('rental-default','contacted','contacted'),
  ('rental-default','qualified','contacted'),
  ('rental-default','viewing_scheduled','viewing'),
  ('rental-default','negotiating','application'),
  ('rental-default','won','won'),
  ('rental-default','lost','lost'),
  ('rental-default','closed','lost'),
  ('rental-default','spam','lost'),

  ('offplan','new','new'),
  ('offplan','contacted','contacted'),
  ('offplan','qualified','qualified'),
  ('offplan','viewing_scheduled','sales-centre'),
  ('offplan','negotiating','reservation'),
  ('offplan','won','won'),
  ('offplan','lost','lost'),
  ('offplan','closed','lost'),
  ('offplan','spam','lost'),

  ('valuation','new','requested'),
  ('valuation','contacted','booked'),
  ('valuation','qualified','valued'),
  ('valuation','viewing_scheduled','booked'),
  ('valuation','negotiating','proposal'),
  ('valuation','won','won'),
  ('valuation','lost','lost'),
  ('valuation','closed','lost'),
  ('valuation','spam','lost'),

  ('luxury-asset','new','new'),
  ('luxury-asset','contacted','new'),
  ('luxury-asset','qualified','qualified'),
  ('luxury-asset','viewing_scheduled','inspection'),
  ('luxury-asset','negotiating','survey'),
  ('luxury-asset','won','won'),
  ('luxury-asset','lost','lost'),
  ('luxury-asset','closed','lost'),
  ('luxury-asset','spam','lost');

-- -----------------------------------------------------------------------------
-- Leads
--
-- One per inquiry. In a mature CRM several inquiries roll into one lead; here
-- the grain is kept at one-to-one so `lead_inquiries` has an unambiguous
-- primary, and the many-to-one case is demonstrated through the contact instead.
--
-- Stage and status are derived from the inquiry's own outcome, so the funnel
-- reflects the marketplace data rather than a separate invented distribution.
-- -----------------------------------------------------------------------------
INSERT INTO leads
  (public_id, reference, organization_id, account_id, contact_id, user_id,
   pipeline_id, stage_id, stage_type, status, name, email, phone_e164,
   preferred_language_id, intent, category_id, root_category_id, purpose_id,
   primary_listing_id, project_id, location_id, country_id, city_id,
   budget_min, budget_max, currency_code, budget_max_base, timeframe, financing,
   owner_agent_id, assigned_at, assignment_method, score, score_band, priority,
   is_qualified, qualified_at, first_response_at, first_response_minutes,
   response_due_at, sla_status, last_contacted_at, last_activity_at,
   stage_entered_at, is_stale, source_id, channel, utm_source, utm_medium,
   utm_campaign, landing_url, referrer_url, acquisition_cost,
   acquisition_cost_currency, lost_reason_id, closed_at, is_duplicate,
   spam_score, is_spam, inquiry_count, activity_count, viewing_count,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('lead:', i.id)), 26)),
  CONCAT('LD-', LPAD(i.id, 8, '0')),
  i.organization_id, i.account_id, c.id, i.user_id,
  pl.id, st.id, st.stage_type,
  CASE i.status WHEN 'won' THEN 'won'
                WHEN 'lost' THEN 'lost'
                WHEN 'closed' THEN 'lost'
                WHEN 'spam' THEN 'disqualified'
                ELSE 'open' END,
  i.name, i.email, i.phone, i.preferred_language_id,
  CASE WHEN i.inquiry_type = 'valuation' THEN 'valuation'
       WHEN p.slug LIKE 'rent%' THEN 'rent'
       WHEN rc.code IN ('yachts','jets','helicopters') THEN 'buy'
       ELSE 'buy' END,
  i.category_id, l.root_category_id, l.purpose_id,
  i.listing_id, i.project_id, i.location_id, i.country_id, l.city_id,
  i.budget_min, i.budget_max, i.currency_code, i.budget_max,
  -- Timeframe and financing are not on the inquiry, so they are derived
  -- deterministically. Weighted towards the honest answer: most people do not
  -- say, and "unknown" is the commonest real value in any CRM.
  ELT(1 + MOD(i.id, 8), 'immediate', 'within_1_month', 'within_3_months',
      'within_6_months', 'exploring', 'unknown', 'unknown', 'within_3_months'),
  ELT(1 + MOD(i.id, 6), 'cash', 'mortgage_approved', 'mortgage_needed',
      'unknown', 'unknown', 'mortgage_needed'),
  i.assigned_to_agent_id, i.assigned_at,
  IF(i.assigned_to_agent_id IS NULL, NULL, 'round_robin'),
  0, 'cold',
  CASE WHEN i.priority = 'urgent' THEN 'urgent' WHEN i.priority = 'high' THEN 'high'
       WHEN i.priority = 'low' THEN 'low' ELSE 'normal' END,
  i.status IN ('qualified','viewing_scheduled','negotiating','won'),
  IF(i.status IN ('qualified','viewing_scheduled','negotiating','won'),
     i.first_response_at, NULL),
  i.first_response_at, i.first_response_minutes,
  DATE_ADD(i.created_at, INTERVAL 15 MINUTE),
  CASE WHEN i.first_response_at IS NULL THEN 'pending'
       WHEN i.first_response_minutes <= 15 THEN 'met'
       ELSE 'breached' END,
  i.first_response_at, i.last_activity_at,
  COALESCE(i.assigned_at, i.created_at),
  -- Stale: open, and untouched for longer than the stage allows.
  i.status NOT IN ('won','lost','closed','spam')
    AND i.last_activity_at < DATE_SUB(NOW(), INTERVAL 14 DAY),
  ls.id,
  CASE i.channel WHEN 'phone' THEN 'phone' WHEN 'whatsapp' THEN 'whatsapp'
                 WHEN 'email' THEN 'email' WHEN 'chat' THEN 'chat'
                 ELSE 'web_form' END,
  i.utm_source, i.utm_medium, i.utm_campaign, i.source_url, i.referrer_url,
  ls.default_cost_per_lead, ls.cost_currency_code,
  -- A lost lead needs a reason. Assigned deterministically across the real
  -- vocabulary rather than left null, because a null reason teaches nothing.
  CASE WHEN i.status IN ('lost','closed')
       THEN (SELECT lr.id FROM lead_lost_reasons lr
              WHERE lr.organization_id IS NULL AND lr.is_active = 1
              ORDER BY lr.sort_order LIMIT 1 OFFSET 0) + MOD(i.id, 8)
       ELSE NULL END,
  IF(i.status IN ('won','lost','closed','spam'), i.closed_at, NULL),
  i.is_duplicate, i.spam_score, i.is_spam,
  1, 0, 0,
  i.created_at, i.updated_at
FROM inquiries i
LEFT JOIN listings l ON l.id = i.listing_id
LEFT JOIN purposes p ON p.id = l.purpose_id
LEFT JOIN categories rc ON rc.id = l.root_category_id
LEFT JOIN crm_contacts c
  ON c.organization_id = i.organization_id
 AND c.primary_email_normalized = LOWER(TRIM(i.email))
LEFT JOIN lead_sources ls
  ON ls.organization_id IS NULL
 AND ls.code = CASE
       WHEN i.utm_source = 'google' AND i.utm_medium = 'cpc' THEN 'google-ads'
       WHEN i.utm_source IN ('facebook','instagram') THEN 'meta-ads'
       WHEN i.utm_source = 'newsletter' THEN 'newsletter'
       WHEN i.channel = 'phone' THEN 'phone-in'
       WHEN i.referrer_url IS NOT NULL THEN 'referral-site'
       WHEN i.utm_source IS NOT NULL THEN 'organic'
       ELSE 'direct' END
-- Pipeline follows the asset class and the purpose, which is what the pipeline
-- definitions above exist to distinguish.
JOIN lead_pipelines pl
  ON pl.organization_id IS NULL
 AND pl.code = CASE
       WHEN rc.code IN ('yachts','jets','helicopters','watches') THEN 'luxury-asset'
       WHEN i.inquiry_type = 'valuation' THEN 'valuation'
       WHEN i.project_id IS NOT NULL THEN 'offplan'
       WHEN p.slug LIKE 'rent%' THEN 'rental-default'
       ELSE 'sales-default' END
JOIN tmp_stage_map sm ON sm.pipeline_code = pl.code AND sm.inquiry_status = i.status
JOIN lead_pipeline_stages st ON st.pipeline_id = pl.id AND st.code = sm.stage_code
WHERE i.deleted_at IS NULL AND i.organization_id IS NOT NULL;

DROP TABLE tmp_stage_map;

-- The join that lets the two grains coexist.
INSERT INTO lead_inquiries (lead_id, inquiry_id, is_primary, attached_at, attached_by)
SELECT ld.id, i.id, 1, i.created_at, 'system'
FROM inquiries i
JOIN leads ld ON ld.reference = CONCAT('LD-', LPAD(i.id, 8, '0'));

-- The listings a lead has engaged with. Derived from the enquiry itself plus the
-- contact's favourites, which is exactly how an agent's shortlist gets built.
INSERT INTO lead_listings
  (lead_id, listing_id, relation, interest_level, created_at, updated_at)
SELECT ld.id, ld.primary_listing_id, 'enquired',
       CASE ld.stage_type WHEN 'proposal' THEN 'high' WHEN 'negotiation' THEN 'high'
                          WHEN 'qualified' THEN 'medium' ELSE 'unknown' END,
       ld.created_at, ld.updated_at
FROM leads ld WHERE ld.primary_listing_id IS NOT NULL;

INSERT IGNORE INTO lead_listings
  (lead_id, listing_id, relation, interest_level, sent_at, created_at, updated_at)
SELECT ld.id, f.listing_id, 'shortlisted', 'medium',
       f.created_at, f.created_at, f.created_at
FROM leads ld
JOIN crm_contacts c ON c.id = ld.contact_id
JOIN favourites f ON f.user_id = c.user_id
WHERE c.user_id IS NOT NULL;

-- =============================================================================
-- SECTION 3 · ACTIVITY, VIEWINGS, CALLS AND DEALS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Assignments
--
-- One offer per assigned lead, accepted. Declines and timeouts would be here
-- too in production; the demo data has no rejected assignments because the
-- source inquiries carry no such signal, and inventing declines would put
-- fiction into a table whose whole purpose is evidence.
-- -----------------------------------------------------------------------------
INSERT INTO lead_assignments
  (lead_id, agent_id, pool_id, assignment_method, sequence_number, status,
   offered_at, expires_at, responded_at, response_seconds, created_at, updated_at)
SELECT ld.id, ld.owner_agent_id, p.id, 'round_robin', 1, 'accepted',
       ld.assigned_at,
       DATE_ADD(ld.assigned_at, INTERVAL 5 MINUTE),
       DATE_ADD(ld.assigned_at, INTERVAL (20 + MOD(ld.id, 200)) SECOND),
       20 + MOD(ld.id, 200),
       ld.assigned_at, ld.assigned_at
FROM leads ld
LEFT JOIN lead_routing_pools p ON p.organization_id = ld.organization_id
WHERE ld.owner_agent_id IS NOT NULL AND ld.assigned_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Stage history
--
-- Every stage the lead has passed through, with the time spent in each. The
-- funnel report reads `duration_seconds` directly rather than self-joining the
-- table, which is why it is written on exit.
-- -----------------------------------------------------------------------------
INSERT INTO lead_stage_history
  (lead_id, from_stage_id, to_stage_id, from_stage_type, to_stage_type,
   duration_seconds, changed_by, reason, created_at)
SELECT ld.id, NULL, first_stage.id, NULL, 'new', NULL, 'system',
       'Lead created from enquiry.', ld.created_at
FROM leads ld
JOIN lead_pipeline_stages first_stage
  ON first_stage.pipeline_id = ld.pipeline_id AND first_stage.sort_order = 10;

INSERT INTO lead_stage_history
  (lead_id, from_stage_id, to_stage_id, from_stage_type, to_stage_type,
   duration_seconds, changed_by_user_id, changed_by, reason, lost_reason_id,
   created_at)
SELECT ld.id, first_stage.id, ld.stage_id, first_stage.stage_type, ld.stage_type,
       GREATEST(0, TIMESTAMPDIFF(SECOND, ld.created_at,
                COALESCE(ld.first_response_at, ld.updated_at))),
       ld.owner_user_id, 'user',
       CONCAT('Advanced to ', (SELECT s2.name FROM lead_pipeline_stages s2 WHERE s2.id = ld.stage_id), '.'),
       ld.lost_reason_id,
       COALESCE(ld.first_response_at, ld.updated_at)
FROM leads ld
JOIN lead_pipeline_stages first_stage
  ON first_stage.pipeline_id = ld.pipeline_id AND first_stage.sort_order = 10
WHERE ld.stage_id <> first_stage.id;

-- -----------------------------------------------------------------------------
-- SLA clocks and breaches
--
-- One clock per lead against the first-response target. A lead that was
-- answered inside the target shows `met`; one answered late shows `breached`
-- with the overdue minutes, and that breach survives into the reporting table
-- even after the clock itself is cleaned up.
-- -----------------------------------------------------------------------------
INSERT INTO sla_clocks
  (policy_id, target_id, subject_type, subject_id, organization_id, metric,
   state, started_at, due_at, warning_at, elapsed_seconds, completed_at,
   breached_at, breach_seconds, owner_agent_id, escalation_level,
   created_at, updated_at)
SELECT
  pol.id, tgt.id, 'lead', ld.id, ld.organization_id, 'first_response',
  CASE ld.sla_status WHEN 'met' THEN 'met' WHEN 'breached' THEN 'breached'
                     ELSE 'running' END,
  ld.created_at,
  DATE_ADD(ld.created_at, INTERVAL tgt.target_minutes MINUTE),
  DATE_ADD(ld.created_at, INTERVAL ROUND(tgt.target_minutes * tgt.warning_at_percent / 100) MINUTE),
  COALESCE(ld.first_response_minutes, 0) * 60,
  ld.first_response_at,
  IF(ld.sla_status = 'breached',
     DATE_ADD(ld.created_at, INTERVAL tgt.target_minutes MINUTE), NULL),
  IF(ld.sla_status = 'breached',
     (ld.first_response_minutes - tgt.target_minutes) * 60, NULL),
  ld.owner_agent_id, 0, ld.created_at, ld.updated_at
FROM leads ld
JOIN sla_policies pol
  ON pol.organization_id IS NULL
 AND pol.code = CASE WHEN ld.priority = 'urgent' THEN 'urgent'
                     WHEN ld.budget_max_base >= 5000000 THEN 'premium'
                     WHEN ld.intent = 'rent' THEN 'rental'
                     ELSE 'standard' END
JOIN sla_targets tgt ON tgt.policy_id = pol.id AND tgt.metric = 'first_response';

INSERT INTO sla_breaches
  (clock_id, policy_id, organization_id, subject_type, subject_id, metric,
   target_minutes, actual_minutes, overdue_minutes, owner_agent_id,
   breached_at, breach_date, is_excused, created_at)
SELECT c.id, c.policy_id, c.organization_id, 'lead', c.subject_id, c.metric,
       t.target_minutes, ld.first_response_minutes,
       ld.first_response_minutes - t.target_minutes,
       c.owner_agent_id, c.breached_at, DATE(c.breached_at),
       -- A breach can be excused. Around one in twelve is, which is roughly the
       -- rate at which "the client asked us to call on Monday" is genuine.
       MOD(c.id, 12) = 0,
       c.created_at
FROM sla_clocks c
JOIN sla_targets t ON t.id = c.target_id
JOIN leads ld ON ld.id = c.subject_id
WHERE c.state = 'breached' AND c.subject_type = 'lead';

-- -----------------------------------------------------------------------------
-- Score events
--
-- The audit trail behind each lead's score. A score with no explanation is not
-- actionable, and agents ignore what they cannot interrogate — so every point
-- here traces to the rule that awarded it.
-- -----------------------------------------------------------------------------
INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 0, r.points, 'cold',
       CASE WHEN r.points >= m.hot_threshold THEN 'hot'
            WHEN r.points >= m.warm_threshold THEN 'warm' ELSE 'cold' END,
       'rule', r.name, ld.created_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'quality-source'
WHERE ld.source_id IS NOT NULL;

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 8, 8 + r.points, 'cold', 'warm',
       'rule', r.name, COALESCE(ld.first_response_at, ld.created_at)
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'called-us'
WHERE ld.channel IN ('phone', 'whatsapp');

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 20, 20 + r.points, 'warm', 'hot',
       'rule', r.name, ld.updated_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'high-budget'
WHERE ld.budget_max_base >= 5000000;

-- -----------------------------------------------------------------------------
-- Viewings
--
-- Booked for the leads that got past qualification. The outcome distribution is
-- deliberately unflattering: most viewings do not produce an offer, and a
-- dataset where they do would make every conversion metric built on it useless.
-- -----------------------------------------------------------------------------
INSERT INTO viewings
  (public_id, reference, organization_id, listing_id, project_id, lead_id,
   contact_id, agent_id, viewing_type, status, scheduled_at, scheduled_end_at,
   timezone, duration_minutes, location_id, meeting_address, attendee_count,
   checked_in_at, completed_at, outcome, interest_level, feedback_sent_to_owner_at,
   reminder_sent_at, confirmation_sent_at, created_by_user_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('viewing:', ld.id)), 26)),
  CONCAT('VW-', LPAD(ld.id, 8, '0')),
  ld.organization_id, ld.primary_listing_id, ld.project_id, ld.id, ld.contact_id,
  ld.owner_agent_id,
  CASE WHEN rc.code = 'yachts' THEN 'sea_trial'
       WHEN rc.code = 'cars' THEN 'test_drive'
       WHEN rc.code IN ('jets','helicopters') THEN 'private_showing'
       WHEN MOD(ld.id, 7) = 0 THEN 'virtual'
       ELSE 'in_person' END,
  CASE WHEN ld.stage_type IN ('won','proposal','negotiation') THEN 'completed'
       WHEN ld.stage_type = 'lost' THEN ELT(1 + MOD(ld.id, 3), 'completed', 'cancelled', 'no_show')
       WHEN ld.stage_type = 'nurturing' THEN 'confirmed'
       ELSE 'completed' END,
  DATE_ADD(ld.created_at, INTERVAL (2 + MOD(ld.id, 12)) DAY),
  DATE_ADD(ld.created_at, INTERVAL (2 + MOD(ld.id, 12)) DAY) + INTERVAL 45 MINUTE,
  COALESCE(loc.timezone, 'Asia/Dubai'), 45, l.location_id, l.address,
  1 + MOD(ld.id, 3),
  IF(ld.stage_type IN ('won','proposal','negotiation'),
     DATE_ADD(ld.created_at, INTERVAL (2 + MOD(ld.id, 12)) DAY), NULL),
  IF(ld.stage_type IN ('won','proposal','negotiation','lost'),
     DATE_ADD(ld.created_at, INTERVAL (2 + MOD(ld.id, 12)) DAY) + INTERVAL 50 MINUTE, NULL),
  CASE WHEN ld.stage_type = 'won' THEN 'offer_made'
       WHEN ld.stage_type IN ('proposal','negotiation') THEN 'very_interested'
       WHEN ld.stage_type = 'lost' THEN ELT(1 + MOD(ld.id, 3), 'not_interested', 'undecided', 'no_show')
       ELSE ELT(1 + MOD(ld.id, 4), 'interested', 'undecided', 'needs_second_viewing', 'not_interested') END,
  CASE WHEN ld.stage_type = 'won' THEN 5
       WHEN ld.stage_type IN ('proposal','negotiation') THEN 4
       WHEN ld.stage_type = 'lost' THEN 1 + MOD(ld.id, 2)
       ELSE 2 + MOD(ld.id, 3) END,
  IF(ld.stage_type IN ('won','proposal','negotiation','lost'),
     DATE_ADD(ld.created_at, INTERVAL (3 + MOD(ld.id, 12)) DAY), NULL),
  DATE_ADD(ld.created_at, INTERVAL (1 + MOD(ld.id, 12)) DAY),
  DATE_ADD(ld.created_at, INTERVAL 1 DAY),
  ld.owner_user_id, ld.created_at, ld.updated_at
FROM leads ld
LEFT JOIN listings l ON l.id = ld.primary_listing_id
LEFT JOIN locations loc ON loc.id = l.city_id
LEFT JOIN categories rc ON rc.id = ld.root_category_id
WHERE ld.stage_type IN ('nurturing','proposal','negotiation','won','lost')
  AND ld.primary_listing_id IS NOT NULL;

INSERT INTO viewing_attendees
  (viewing_id, contact_id, agent_id, attendee_role, name, email, phone_e164,
   rsvp_status, attended, created_at)
SELECT v.id, v.contact_id, NULL, 'buyer', ld.name, ld.email, ld.phone_e164,
       'accepted', v.status = 'completed', v.created_at
FROM viewings v JOIN leads ld ON ld.id = v.lead_id;

INSERT INTO viewing_attendees
  (viewing_id, contact_id, agent_id, attendee_role, name, rsvp_status, attended,
   created_at)
SELECT v.id, NULL, v.agent_id, 'agent', a.display_name, 'accepted',
       v.status = 'completed', v.created_at
FROM viewings v JOIN agents a ON a.id = v.agent_id;

-- -----------------------------------------------------------------------------
-- Viewing feedback
--
-- Structured, because aggregated across viewings this is the evidence that
-- persuades a seller to reduce a price. "Nine of eleven viewers said the price
-- was too high" is an argument; "buyers seem hesitant" is not.
-- -----------------------------------------------------------------------------
INSERT INTO viewing_feedback
  (viewing_id, listing_id, contact_id, submitted_by, overall_rating,
   price_opinion, condition_rating, location_rating, layout_rating,
   likes, dislikes, would_offer, indicative_offer, currency_code, next_step,
   is_shareable_with_owner, internal_note, created_at, updated_at)
SELECT
  v.id, v.listing_id, v.contact_id, 'agent',
  v.interest_level,
  CASE WHEN v.outcome IN ('offer_made','very_interested') THEN 'fair'
       WHEN v.outcome = 'not_interested' THEN 'too_high'
       ELSE ELT(1 + MOD(v.id, 3), 'slightly_high', 'fair', 'too_high') END,
  2 + MOD(v.id, 4), 3 + MOD(v.id, 3), 2 + MOD(v.id, 4),
  ELT(1 + MOD(v.id, 6),
      'Loved the view and the natural light.',
      'Impressed by the finish and the building amenities.',
      'Layout works well for a family.',
      'Location is exactly what they were looking for.',
      'Liked the size of the terrace.',
      'Parking and storage were a strong point.'),
  ELT(1 + MOD(v.id, 6),
      'Felt the price was above the market for the building.',
      'Kitchen needs updating and they do not want a project.',
      'Second bedroom is smaller than it looked in the photographs.',
      'Concerned about the service charge.',
      'Road noise from the balcony.',
      'Handover date is later than they need.'),
  v.outcome IN ('offer_made','very_interested'),
  IF(v.outcome IN ('offer_made','very_interested'),
     ROUND(l.price * (0.88 + MOD(v.id, 9) / 100), 0), NULL),
  l.currency_code,
  CASE v.outcome WHEN 'offer_made' THEN 'offer'
                 WHEN 'very_interested' THEN 'offer'
                 WHEN 'needs_second_viewing' THEN 'second_viewing'
                 WHEN 'not_interested' THEN 'other_properties'
                 ELSE 'undecided' END,
  1,
  ELT(1 + MOD(v.id, 3),
      'Owner is aware of the price feedback and is considering a reduction.',
      'Client is comparing against two other properties in the same tower.',
      'Decision maker was not present. Second viewing likely.'),
  COALESCE(v.completed_at, v.scheduled_at), COALESCE(v.completed_at, v.scheduled_at)
FROM viewings v
JOIN listings l ON l.id = v.listing_id
WHERE v.status = 'completed';

-- -----------------------------------------------------------------------------
-- Calls
--
-- Tracking numbers first: one per organisation for attribution, plus a pool for
-- the visitor-level allocation that makes a call attributable to the exact
-- session and keyword that produced it.
-- -----------------------------------------------------------------------------
INSERT INTO call_tracking_pools
  (organization_id, code, name, lease_minutes, is_active, created_at, updated_at)
SELECT o.id, 'web-pool', CONCAT(o.name, ' — web session pool'), 30, 1,
       o.created_at, o.created_at
FROM organizations o
WHERE o.deleted_at IS NULL AND o.active_listing_count >= 5;

INSERT INTO call_tracking_numbers
  (organization_id, provider, provider_number_sid, phone_e164, display_number,
   country_id, number_type, allocation, attribution_type, agent_id,
   forward_to_e164, record_calls, recording_announcement_required,
   transcribe_calls, status, monthly_cost, per_minute_cost, cost_currency_code,
   provisioned_at, created_at, updated_at)
SELECT
  a.organization_id, 'twilio',
  CONCAT('PN', LOWER(LEFT(MD5(CONCAT('num:', a.id)), 30))),
  CONCAT('+9714', LPAD(MOD(a.id * 7717, 10000000), 7, '0')),
  CONCAT('04 ', LPAD(MOD(a.id * 7717, 10000000), 7, '0')),
  a.country_id, 'local', 'static', 'agent', a.id,
  a.phone, 1, 1, 1, 'assigned',
  3.50, 0.0180, 'USD', a.created_at, a.created_at, a.created_at
FROM agents a
WHERE a.deleted_at IS NULL AND a.status = 'active' AND a.phone IS NOT NULL;

-- The pooled numbers, leased per visit. Ten per pool, which is what a portal
-- with moderate concurrent traffic needs.
INSERT INTO call_tracking_numbers
  (organization_id, provider, provider_number_sid, phone_e164, display_number,
   number_type, allocation, attribution_type, pool_id, forward_to_e164,
   record_calls, recording_announcement_required, transcribe_calls, status,
   monthly_cost, per_minute_cost, cost_currency_code, provisioned_at,
   created_at, updated_at)
SELECT
  p.organization_id, 'twilio',
  CONCAT('PN', LOWER(LEFT(MD5(CONCAT('pool:', p.id, ':', n.i)), 30))),
  CONCAT('+9718', LPAD(MOD(p.id * 100 + n.i, 10000000), 7, '0')),
  CONCAT('800 ', LPAD(MOD(p.id * 100 + n.i, 10000000), 7, '0')),
  'toll_free', 'pooled', 'session', p.id, o.phone,
  1, 1, 0, 'available', 8.00, 0.0220, 'USD',
  p.created_at, p.created_at, p.created_at
FROM call_tracking_pools p
JOIN organizations o ON o.id = p.organization_id
JOIN (SELECT 1 AS i UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
      UNION ALL SELECT 9 UNION ALL SELECT 10) n;

UPDATE call_tracking_pools p
  JOIN (SELECT pool_id, COUNT(*) n, SUM(status = 'available') a
          FROM call_tracking_numbers WHERE pool_id IS NOT NULL GROUP BY pool_id) c
    ON c.pool_id = p.id
   SET p.number_count = c.n, p.available_count = c.a;

-- The calls themselves. Inbound, on the agent's tracking number, tied back to
-- the lead — which is the only way "we sent you 300 leads" survives an audit.
INSERT INTO calls
  (public_id, organization_id, provider, provider_call_sid, tracking_number_id,
   direction, from_e164, to_e164, dialled_e164, forwarded_to_e164, caller_name,
   caller_country_id, status, started_at, answered_at, ended_at, ring_seconds,
   duration_seconds, billable_seconds, listing_id, agent_id, lead_id, contact_id,
   inquiry_id, source_id, is_first_time_caller, is_qualified_call, is_billable,
   disposition_id, transcript_status, sentiment_score, talk_ratio_percent,
   cost, cost_currency_code, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('call:', ld.id)), 26)),
  ld.organization_id, 'twilio',
  CONCAT('CA', LOWER(LEFT(MD5(CONCAT('sid:', ld.id)), 30))),
  tn.id, 'inbound', ld.phone_e164, tn.phone_e164, tn.phone_e164, tn.forward_to_e164,
  ld.name, ld.country_id,
  -- Roughly a third of first calls are not answered, which is the real rate and
  -- the reason the follow-up cadence exists.
  ELT(1 + MOD(ld.id, 3), 'completed', 'completed', 'no_answer'),
  COALESCE(ld.first_response_at, ld.created_at),
  IF(MOD(ld.id, 3) = 2, NULL, DATE_ADD(COALESCE(ld.first_response_at, ld.created_at), INTERVAL 8 SECOND)),
  DATE_ADD(COALESCE(ld.first_response_at, ld.created_at),
           INTERVAL (8 + IF(MOD(ld.id, 3) = 2, 22, 60 + MOD(ld.id, 540))) SECOND),
  8,
  IF(MOD(ld.id, 3) = 2, 0, 60 + MOD(ld.id, 540)),
  -- Carriers bill in whole minutes. Reconciling a provider invoice against raw
  -- duration fails every month, which is why this column exists.
  IF(MOD(ld.id, 3) = 2, 0, CEIL((60 + MOD(ld.id, 540)) / 60) * 60),
  ld.primary_listing_id, ld.owner_agent_id, ld.id, ld.contact_id,
  (SELECT li.inquiry_id FROM lead_inquiries li WHERE li.lead_id = ld.id LIMIT 1),
  ld.source_id,
  1,
  -- The commercial definition: answered, and longer than 90 seconds. This is
  -- what gets invoiced when the client pays per call.
  MOD(ld.id, 3) <> 2 AND (60 + MOD(ld.id, 540)) >= 90,
  MOD(ld.id, 3) <> 2 AND (60 + MOD(ld.id, 540)) >= 90,
  disp.id, 'completed',
  IF(MOD(ld.id, 3) = 2, NULL, CAST(MOD(ld.id, 140) AS SIGNED) - 40),
  IF(MOD(ld.id, 3) = 2, NULL, 35 + MOD(ld.id, 40)),
  ROUND(IF(MOD(ld.id, 3) = 2, 0, CEIL((60 + MOD(ld.id, 540)) / 60)) * 0.0180, 4),
  'USD',
  COALESCE(ld.first_response_at, ld.created_at),
  COALESCE(ld.first_response_at, ld.created_at)
FROM leads ld
JOIN call_tracking_numbers tn ON tn.agent_id = ld.owner_agent_id
LEFT JOIN call_dispositions disp
  ON disp.organization_id IS NULL
 AND disp.code = CASE WHEN MOD(ld.id, 3) = 2 THEN 'no-answer'
                      WHEN ld.stage_type = 'won' THEN 'viewing-booked'
                      WHEN ld.stage_type IN ('qualified','nurturing','proposal','negotiation') THEN 'qualified'
                      WHEN ld.stage_type = 'lost' THEN 'not-interested'
                      ELSE 'spoke' END
WHERE ld.phone_e164 IS NOT NULL
  AND ld.channel IN ('phone', 'whatsapp', 'web_form');

INSERT INTO call_transcripts
  (call_id, language_code, engine, confidence, full_text, summary, created_at)
SELECT c.id, 'en', 'whisper-large-v3', 0.9200,
       CONCAT('Agent: Good morning, this is ', a.display_name, ' from ', o.name,
              '. Thank you for your enquiry.\nCaller: Yes, I was looking at the property you have listed. '
              'Is it still available?\nAgent: It is. Would you like to arrange a viewing?\n'
              'Caller: Yes, I would. What is your availability this week?'),
       'Caller confirmed continued interest and asked to arrange a viewing.',
       c.started_at
FROM calls c
JOIN agents a ON a.id = c.agent_id
JOIN organizations o ON o.id = c.organization_id
WHERE c.status = 'completed' AND MOD(c.id, 6) = 0;

UPDATE call_tracking_numbers tn
  JOIN (SELECT tracking_number_id, COUNT(*) n, SUM(duration_seconds) s,
               MAX(started_at) last_at
          FROM calls WHERE tracking_number_id IS NOT NULL
         GROUP BY tracking_number_id) c ON c.tracking_number_id = tn.id
   SET tn.call_count = c.n, tn.total_seconds = c.s, tn.last_call_at = c.last_at;

-- -----------------------------------------------------------------------------
-- Deals
--
-- Created for the leads that reached an offer. Commission is computed from the
-- organisation's scheme rather than assumed, and the itemised splits below are
-- what finance actually pays from.
-- -----------------------------------------------------------------------------
INSERT INTO deals
  (public_id, reference, organization_id, lead_id, contact_id, listing_id,
   project_id, category_id, root_category_id, purpose_id, location_id,
   country_id, city_id, pipeline_id, stage_id, deal_type, status, asking_price,
   offer_amount, agreed_amount, final_amount, currency_code, agreed_amount_base,
   commission_rate, gross_commission, gross_commission_base, net_commission,
   probability, weighted_value_base, expected_close_date, offer_made_at,
   offer_accepted_at, contract_signed_at, completed_at, lost_at, lost_reason_id,
   owner_agent_id, is_co_brokered, compliance_status, created_by_user_id,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('deal:', ld.id)), 26)),
  CONCAT('DL-', LPAD(ld.id, 8, '0')),
  ld.organization_id, ld.id, ld.contact_id, ld.primary_listing_id, ld.project_id,
  ld.category_id, ld.root_category_id, ld.purpose_id, ld.location_id,
  ld.country_id, ld.city_id, ld.pipeline_id, ld.stage_id,
  CASE WHEN p.slug LIKE 'rent%' THEN 'rental' ELSE 'sale' END,
  CASE ld.stage_type WHEN 'won' THEN 'completed'
                     WHEN 'negotiation' THEN 'agreed'
                     WHEN 'proposal' THEN 'under_offer'
                     WHEN 'lost' THEN 'lost'
                     ELSE 'open' END,
  l.price,
  -- Offers come in below asking. Between 88% and 97%, which is the band a
  -- reasonable market actually trades in.
  ROUND(l.price * (0.88 + MOD(ld.id, 10) / 100), 0),
  IF(ld.stage_type IN ('won','negotiation'),
     ROUND(l.price * (0.90 + MOD(ld.id, 8) / 100), 0), NULL),
  IF(ld.stage_type = 'won', ROUND(l.price * (0.90 + MOD(ld.id, 8) / 100), 0), NULL),
  l.currency_code,
  IF(ld.stage_type IN ('won','negotiation'),
     ROUND(l.price_base * (0.90 + MOD(ld.id, 8) / 100), 0), NULL),
  -- 2% is the standard Gulf sale commission; lettings are charged at 5% of the
  -- annual rent.
  IF(p.slug LIKE 'rent%', 5.0000, 2.0000),
  IF(ld.stage_type IN ('won','negotiation'),
     ROUND(l.price * (0.90 + MOD(ld.id, 8) / 100)
           * IF(p.slug LIKE 'rent%', 0.05, 0.02), 2), NULL),
  IF(ld.stage_type IN ('won','negotiation'),
     ROUND(l.price_base * (0.90 + MOD(ld.id, 8) / 100)
           * IF(p.slug LIKE 'rent%', 0.05, 0.02), 2), NULL),
  NULL,
  st.probability,
  ROUND(COALESCE(l.price_base, 0) * st.probability / 100, 2),
  DATE_ADD(DATE(ld.created_at), INTERVAL (30 + MOD(ld.id, 90)) DAY),
  DATE_ADD(ld.created_at, INTERVAL (14 + MOD(ld.id, 20)) DAY),
  IF(ld.stage_type IN ('won','negotiation'),
     DATE_ADD(ld.created_at, INTERVAL (18 + MOD(ld.id, 20)) DAY), NULL),
  IF(ld.stage_type = 'won', DATE_ADD(ld.created_at, INTERVAL (25 + MOD(ld.id, 20)) DAY), NULL),
  IF(ld.stage_type = 'won', ld.closed_at, NULL),
  IF(ld.stage_type = 'lost', ld.closed_at, NULL),
  ld.lost_reason_id,
  ld.owner_agent_id,
  MOD(ld.id, 9) = 0,
  IF(ld.stage_type = 'won', 'cleared', 'pending'),
  ld.owner_user_id, ld.created_at, ld.updated_at
FROM leads ld
JOIN listings l ON l.id = ld.primary_listing_id
JOIN lead_pipeline_stages st ON st.id = ld.stage_id
LEFT JOIN purposes p ON p.id = ld.purpose_id
WHERE ld.stage_type IN ('proposal','negotiation','won')
   OR (ld.stage_type = 'lost' AND MOD(ld.id, 3) = 0);

UPDATE leads ld JOIN deals d ON d.lead_id = ld.id SET ld.deal_id = d.id;
UPDATE viewings v JOIN deals d ON d.lead_id = v.lead_id SET v.deal_id = d.id;

INSERT INTO deal_parties
  (deal_id, party_role, contact_id, external_name, is_primary, created_at)
SELECT d.id, IF(d.deal_type = 'rental', 'tenant', 'buyer'),
       d.contact_id, c.display_name, 1, d.created_at
FROM deals d JOIN crm_contacts c ON c.id = d.contact_id;

INSERT INTO deal_parties
  (deal_id, party_role, agent_id, organization_id, external_name,
   is_primary, created_at)
SELECT d.id, 'buyer_agent', d.owner_agent_id, d.organization_id,
       a.display_name, 1, d.created_at
FROM deals d JOIN agents a ON a.id = d.owner_agent_id;

INSERT INTO deal_stage_history
  (deal_id, to_status, amount_at_change, changed_by_user_id, reason, created_at)
SELECT d.id, 'under_offer', d.offer_amount, d.created_by_user_id,
       'Offer submitted to the seller.', d.offer_made_at
FROM deals d WHERE d.offer_made_at IS NOT NULL;

INSERT INTO deal_stage_history
  (deal_id, from_status, to_status, amount_at_change, duration_seconds,
   changed_by_user_id, reason, created_at)
SELECT d.id, 'under_offer', 'completed', d.final_amount,
       GREATEST(0, TIMESTAMPDIFF(SECOND, d.offer_made_at, d.completed_at)),
       d.created_by_user_id, 'Transaction completed and funds released.',
       d.completed_at
FROM deals d WHERE d.completed_at IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Commission splits
--
-- Four payables from one commission: the agency's share, the agent's cut under
-- their scheme, the platform's fee and, where the deal was co-brokered, the
-- other agency's half. Each has its own due date and its own state, which is
-- why they are rows and not columns.
-- -----------------------------------------------------------------------------
INSERT INTO deal_commissions
  (deal_id, organization_id, commission_type, payee_type, payee_organization_id,
   calculation, rate, base_amount, amount, currency_code, amount_base,
   tax_amount, net_amount, status, due_date, approved_at, paid_at, created_at, updated_at)
SELECT d.id, d.organization_id, 'agency', 'organization', d.organization_id,
       'percentage_of_commission', 60.0000, d.gross_commission,
       ROUND(d.gross_commission * 0.60, 2), d.currency_code,
       ROUND(d.gross_commission_base * 0.60, 2),
       ROUND(d.gross_commission * 0.60 * 0.05, 2),
       ROUND(d.gross_commission * 0.60 * 0.95, 2),
       IF(d.status = 'completed', 'paid', 'accrued'),
       DATE_ADD(DATE(COALESCE(d.completed_at, d.created_at)), INTERVAL 30 DAY),
       IF(d.status = 'completed', d.completed_at, NULL),
       IF(d.status = 'completed', DATE_ADD(d.completed_at, INTERVAL 30 DAY), NULL),
       d.created_at, d.updated_at
FROM deals d WHERE d.gross_commission IS NOT NULL;

INSERT INTO deal_commissions
  (deal_id, organization_id, commission_type, payee_type, payee_agent_id,
   calculation, rate, base_amount, amount, currency_code, amount_base,
   tax_amount, net_amount, status, due_date, approved_at, paid_at, created_at, updated_at)
SELECT d.id, d.organization_id, 'agent', 'agent', d.owner_agent_id,
       'percentage_of_commission', 35.0000, d.gross_commission,
       ROUND(d.gross_commission * 0.35, 2), d.currency_code,
       ROUND(d.gross_commission_base * 0.35, 2), 0,
       ROUND(d.gross_commission * 0.35, 2),
       IF(d.status = 'completed', 'paid', 'projected'),
       DATE_ADD(DATE(COALESCE(d.completed_at, d.created_at)), INTERVAL 45 DAY),
       IF(d.status = 'completed', d.completed_at, NULL),
       IF(d.status = 'completed', DATE_ADD(d.completed_at, INTERVAL 45 DAY), NULL),
       d.created_at, d.updated_at
FROM deals d WHERE d.gross_commission IS NOT NULL AND d.owner_agent_id IS NOT NULL;

INSERT INTO deal_commissions
  (deal_id, organization_id, commission_type, payee_type, payee_external_name,
   calculation, rate, base_amount, amount, currency_code, amount_base,
   tax_amount, net_amount, status, due_date, created_at, updated_at)
SELECT d.id, d.organization_id, 'platform', 'platform', 'Liv Finder',
       'percentage_of_commission', 5.0000, d.gross_commission,
       ROUND(d.gross_commission * 0.05, 2), d.currency_code,
       ROUND(d.gross_commission_base * 0.05, 2),
       ROUND(d.gross_commission * 0.05 * 0.05, 2),
       ROUND(d.gross_commission * 0.05 * 0.95, 2),
       IF(d.status = 'completed', 'invoiced', 'projected'),
       DATE_ADD(DATE(COALESCE(d.completed_at, d.created_at)), INTERVAL 15 DAY),
       d.created_at, d.updated_at
FROM deals d WHERE d.gross_commission IS NOT NULL;

UPDATE deals d
  LEFT JOIN (SELECT deal_id, SUM(amount) AS total FROM deal_commissions
              WHERE commission_type IN ('agent','platform','co_broke')
              GROUP BY deal_id) c ON c.deal_id = d.id
   SET d.net_commission = d.gross_commission - COALESCE(c.total, 0)
 WHERE d.gross_commission IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Activities
--
-- The single timeline. One row per real event that already exists elsewhere —
-- the enquiry, the call, the viewing, the stage change — so the timeline is a
-- view of the truth rather than a parallel invention.
-- -----------------------------------------------------------------------------
INSERT INTO activities
  (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
   activity_type, direction, subject_line, body, preview, occurred_at,
   agent_id, user_id, is_automated, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('act:inq:', i.id)), 26)),
  ld.organization_id, 'lead', ld.id, ld.id, ld.contact_id,
  'email', 'inbound',
  COALESCE(i.subject, 'Property enquiry'),
  i.message, LEFT(COALESCE(i.message, ''), 300),
  i.created_at, ld.owner_agent_id, NULL, 0, i.created_at, i.created_at
FROM leads ld
JOIN lead_inquiries li ON li.lead_id = ld.id
JOIN inquiries i ON i.id = li.inquiry_id;

INSERT INTO activities
  (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
   activity_type, direction, subject_line, preview, outcome, duration_seconds,
   occurred_at, agent_id, is_automated, call_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('act:call:', c.id)), 26)),
  c.organization_id, 'lead', c.lead_id, c.lead_id, c.contact_id,
  'call', c.direction,
  CONCAT('Call — ', COALESCE(disp.name, c.status)),
  CONCAT('Inbound call on the tracking number, ', c.duration_seconds, ' seconds.'),
  CASE c.status WHEN 'completed' THEN 'completed'
                WHEN 'no_answer' THEN 'no_answer'
                WHEN 'busy' THEN 'busy' ELSE 'failed' END,
  c.duration_seconds, c.started_at, c.agent_id, 0, c.id,
  c.started_at, c.started_at
FROM calls c
LEFT JOIN call_dispositions disp ON disp.id = c.disposition_id
WHERE c.lead_id IS NOT NULL;

INSERT INTO activities
  (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
   activity_type, direction, subject_line, preview, outcome, occurred_at,
   agent_id, is_automated, viewing_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('act:view:', v.id)), 26)),
  v.organization_id, 'lead', v.lead_id, v.lead_id, v.contact_id,
  'viewing', 'internal',
  CONCAT('Viewing — ', v.reference),
  CONCAT('Viewing ', v.status, IFNULL(CONCAT(', outcome: ', v.outcome), ''), '.'),
  CASE v.status WHEN 'completed' THEN 'completed'
                WHEN 'cancelled' THEN 'cancelled'
                WHEN 'no_show' THEN 'no_answer' ELSE 'scheduled' END,
  v.scheduled_at, v.agent_id, 0, v.id, v.created_at, v.updated_at
FROM viewings v WHERE v.lead_id IS NOT NULL;

INSERT INTO activities
  (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
   activity_type, direction, subject_line, preview, occurred_at, user_id,
   is_automated, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('act:stage:', h.id)), 26)),
  ld.organization_id, 'lead', ld.id, ld.id, ld.contact_id,
  'stage_change', 'internal',
  CONCAT('Stage → ', s.name), h.reason, h.created_at,
  h.changed_by_user_id, h.changed_by <> 'user', h.created_at, h.created_at
FROM lead_stage_history h
JOIN leads ld ON ld.id = h.lead_id
JOIN lead_pipeline_stages s ON s.id = h.to_stage_id;

-- -----------------------------------------------------------------------------
-- Tasks
--
-- The next action on every open lead. A lead with no next action is a lead
-- nobody is working, which is what the manager's dashboard is looking for.
-- -----------------------------------------------------------------------------
INSERT INTO crm_tasks
  (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
   title, description, task_type, priority, status, due_at, remind_at,
   completed_at, assigned_to_agent_id, assigned_to_user_id, created_by_user_id,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('task:', ld.id)), 26)),
  ld.organization_id, 'lead', ld.id, ld.id, ld.contact_id,
  CASE ld.stage_type
    WHEN 'new' THEN CONCAT('Call ', ld.name, ' — first contact')
    WHEN 'contacted' THEN CONCAT('Qualify ', ld.name, ' — budget and timeframe')
    WHEN 'qualified' THEN CONCAT('Send shortlist to ', ld.name)
    WHEN 'nurturing' THEN CONCAT('Follow up after viewing — ', ld.name)
    WHEN 'proposal' THEN CONCAT('Chase offer decision — ', ld.name)
    WHEN 'negotiation' THEN CONCAT('Progress paperwork — ', ld.name)
    ELSE CONCAT('Review ', ld.name) END,
  CASE ld.stage_type
    WHEN 'new' THEN 'First contact is the whole ballgame. Inside fifteen minutes converts an order of magnitude better than inside an hour.'
    WHEN 'contacted' THEN 'Establish budget, timeframe and financing before spending time on a shortlist.'
    WHEN 'qualified' THEN 'Send three to five properties that genuinely match the brief. More than five reads as a mailshot.'
    ELSE NULL END,
  CASE ld.stage_type WHEN 'new' THEN 'call' WHEN 'contacted' THEN 'call'
                     WHEN 'qualified' THEN 'email' WHEN 'nurturing' THEN 'follow_up'
                     ELSE 'follow_up' END,
  CASE WHEN ld.priority = 'urgent' THEN 'urgent'
       WHEN ld.score_band IN ('hot','on_fire') THEN 'high'
       WHEN ld.score_band = 'cold' THEN 'low' ELSE 'normal' END,
  CASE WHEN ld.status <> 'open' THEN 'completed'
       WHEN ld.is_stale THEN 'open'
       ELSE 'open' END,
  DATE_ADD(ld.last_activity_at, INTERVAL (1 + MOD(ld.id, 5)) DAY),
  DATE_ADD(ld.last_activity_at, INTERVAL (1 + MOD(ld.id, 5)) DAY) - INTERVAL 30 MINUTE,
  IF(ld.status <> 'open', ld.closed_at, NULL),
  ld.owner_agent_id, ld.owner_user_id, ld.owner_user_id,
  ld.created_at, ld.updated_at
FROM leads ld
WHERE ld.owner_agent_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Derived counters
--
-- Every count is a COUNT over the rows it describes.
-- -----------------------------------------------------------------------------
UPDATE leads ld
  LEFT JOIN (SELECT lead_id, COUNT(*) c FROM lead_inquiries GROUP BY lead_id) i
    ON i.lead_id = ld.id
  LEFT JOIN (SELECT lead_id, COUNT(*) c FROM activities
              WHERE lead_id IS NOT NULL AND deleted_at IS NULL GROUP BY lead_id) a
    ON a.lead_id = ld.id
  LEFT JOIN (SELECT lead_id, COUNT(*) c FROM viewings
              WHERE lead_id IS NOT NULL AND deleted_at IS NULL GROUP BY lead_id) v
    ON v.lead_id = ld.id
   SET ld.inquiry_count = COALESCE(i.c, 0),
       ld.activity_count = COALESCE(a.c, 0),
       ld.viewing_count = COALESCE(v.c, 0);

UPDATE crm_contacts c
  LEFT JOIN (SELECT contact_id, COUNT(*) n FROM leads
              WHERE contact_id IS NOT NULL AND deleted_at IS NULL GROUP BY contact_id) l
    ON l.contact_id = c.id
  LEFT JOIN (SELECT contact_id, COUNT(*) n, SUM(COALESCE(agreed_amount_base, 0)) v
               FROM deals WHERE contact_id IS NOT NULL AND deleted_at IS NULL
              GROUP BY contact_id) d ON d.contact_id = c.id
  LEFT JOIN (SELECT contact_id, COUNT(*) n, MAX(occurred_at) last_at
               FROM activities WHERE contact_id IS NOT NULL AND deleted_at IS NULL
              GROUP BY contact_id) a ON a.contact_id = c.id
   SET c.lead_count = COALESCE(l.n, 0),
       c.deal_count = COALESCE(d.n, 0),
       c.total_deal_value_base = COALESCE(d.v, 0),
       c.activity_count = COALESCE(a.n, 0),
       c.last_activity_at = a.last_at;

UPDATE lead_sources s
  LEFT JOIN (SELECT source_id, COUNT(*) n,
                    SUM(is_qualified) q,
                    SUM(status = 'won') d
               FROM leads WHERE source_id IS NOT NULL AND deleted_at IS NULL
              GROUP BY source_id) l ON l.source_id = s.id
   SET s.lead_count = COALESCE(l.n, 0),
       s.qualified_count = COALESCE(l.q, 0),
       s.deal_count = COALESCE(l.d, 0),
       -- Quality is the qualification rate, which is the only source metric
       -- that survives contact with a sales floor.
       s.quality_score = IF(COALESCE(l.n, 0) = 0, NULL,
                            ROUND(l.q / l.n * 100, 2));

UPDATE lead_routing_pool_members m
  LEFT JOIN (SELECT agent_id, COUNT(*) n, MAX(offered_at) last_at
               FROM lead_assignments WHERE agent_id IS NOT NULL GROUP BY agent_id) a
    ON a.agent_id = m.agent_id
  LEFT JOIN (SELECT owner_agent_id, COUNT(*) n FROM leads
              WHERE status = 'open' AND owner_agent_id IS NOT NULL
              GROUP BY owner_agent_id) o ON o.owner_agent_id = m.agent_id
   SET m.assigned_count = COALESCE(a.n, 0),
       m.last_assigned_at = a.last_at,
       m.open_lead_count = COALESCE(o.n, 0);

-- Scoring, run last because two of its rules depend on viewings existing.
-- Behavioural points, awarded from what actually happened rather than from what
-- was claimed. These are the rules that move a lead out of the cold band, which
-- is the intended shape: stated budget alone should not make a lead hot.
INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT v.lead_id, m.id, r.id, r.points, 28, 28 + r.points, 'cold', 'warm',
       'rule', r.name, v.created_at
FROM viewings v
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'viewing-booked'
WHERE v.lead_id IS NOT NULL;

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT v.lead_id, m.id, r.id, r.points, 53, 53 + r.points, 'warm', 'hot',
       'rule', r.name, v.completed_at
FROM viewings v
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'viewing-attended'
WHERE v.lead_id IS NOT NULL AND v.status = 'completed';

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 40, 40 + r.points, 'warm', 'warm',
       'rule', r.name, ld.updated_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'immediate-timeframe'
WHERE ld.timeframe IN ('immediate', 'within_1_month');

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 45, 45 + r.points, 'warm', 'warm',
       'rule', r.name, ld.updated_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'finance-approved'
WHERE ld.financing = 'mortgage_approved';

INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 50, 50 + r.points, 'warm', 'warm',
       'rule', r.name, ld.last_activity_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'recent-activity'
WHERE ld.last_activity_at >= DATE_SUB(NOW(), INTERVAL 48 HOUR);

-- And the penalties. A lead that has been called four times without an answer
-- should leave the hot band no matter how large a budget was typed into the form.
INSERT INTO lead_score_events
  (lead_id, model_id, rule_id, points_delta, score_before, score_after,
   band_before, band_after, trigger_type, explanation, created_at)
SELECT ld.id, m.id, r.id, r.points, 30, 30 + r.points, 'warm', 'cold',
       'rule', r.name, ld.updated_at
FROM leads ld
JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
JOIN lead_scoring_rules r ON r.model_id = m.id AND r.code = 'no-answer-repeated'
WHERE ld.is_stale = 1 AND ld.first_response_at IS NULL;

-- The lead's score is the sum of its events, and its band is read off the
-- model's own thresholds. Neither is set independently.
UPDATE leads ld
  LEFT JOIN (SELECT lead_id, SUM(points_delta) AS total
               FROM lead_score_events GROUP BY lead_id) e ON e.lead_id = ld.id
  JOIN lead_scoring_models m ON m.code = 'default' AND m.organization_id IS NULL
   SET ld.score = GREATEST(0, LEAST(m.max_score, COALESCE(e.total, 0))),
       ld.score_band =
         CASE WHEN COALESCE(e.total, 0) >= m.on_fire_threshold THEN 'on_fire'
              WHEN COALESCE(e.total, 0) >= m.hot_threshold THEN 'hot'
              WHEN COALESCE(e.total, 0) >= m.warm_threshold THEN 'warm'
              ELSE 'cold' END;


UPDATE crm_tags t
  LEFT JOIN (SELECT tag_id, COUNT(*) n FROM crm_tag_assignments GROUP BY tag_id) a
    ON a.tag_id = t.id
   SET t.usage_count = COALESCE(a.n, 0);
