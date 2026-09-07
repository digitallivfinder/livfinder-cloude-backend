-- =============================================================================
-- 075_crm_search_ops_extensions.sql
--
-- The last of the platform: lead capture forms and routing rules, lead sharing
-- and buyer requirements, nurture sequences, CRM merges and tagging, search
-- curation and the index queue, the advertising event stream, affiliate clicks,
-- fraud rules and assessments, the anti-money-laundering escalation path,
-- contract versions, delivery event streams and the operational counters.
--
-- Several of these are the append-only partitioned tables -- ad impressions,
-- search result events, API logs, message delivery events. They are seeded
-- thinly on purpose: a demo database does not need a hundred million rows to
-- demonstrate that the partitioning works, and the queries that read them are
-- written against the shape, not the volume.
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
-- Business holidays
--
-- The service-level clocks pause on these. Without them an enquiry that arrives
-- on Eid is a breach by the following morning, and the agency is being measured
-- against a promise nobody made.
-- -----------------------------------------------------------------------------
INSERT INTO business_holidays
  (organization_id, country_id, name, holiday_date, is_half_day, created_at)
SELECT NULL, c.id, h.name,
       DATE_ADD(MAKEDATE(YEAR(@today), 1), INTERVAL h.day_of_year - 1 DAY),
       h.is_half_day, @now
FROM (
  SELECT 'United Arab Emirates' AS country_name, 'New Year''s Day' AS name, 1 AS day_of_year, 0 AS is_half_day
  UNION ALL SELECT 'United Arab Emirates', 'Eid al-Fitr',              80,  0
  UNION ALL SELECT 'United Arab Emirates', 'Eid al-Fitr holiday',      81,  0
  UNION ALL SELECT 'United Arab Emirates', 'Eid al-Fitr holiday',      82,  0
  UNION ALL SELECT 'United Arab Emirates', 'Arafat Day',              167,  1
  UNION ALL SELECT 'United Arab Emirates', 'Eid al-Adha',             168,  0
  UNION ALL SELECT 'United Arab Emirates', 'Islamic New Year',        188,  0
  UNION ALL SELECT 'United Arab Emirates', 'Prophet''s Birthday',     257,  0
  UNION ALL SELECT 'United Arab Emirates', 'Commemoration Day',       334,  0
  UNION ALL SELECT 'United Arab Emirates', 'National Day',            336,  0
  UNION ALL SELECT 'United Arab Emirates', 'National Day holiday',    337,  0
  UNION ALL SELECT 'United Kingdom',       'New Year''s Day',           1,  0
  UNION ALL SELECT 'United Kingdom',       'Good Friday',              88,  0
  UNION ALL SELECT 'United Kingdom',       'Easter Monday',            91,  0
  UNION ALL SELECT 'United Kingdom',       'Early May bank holiday',  125,  0
  UNION ALL SELECT 'United Kingdom',       'Spring bank holiday',     146,  0
  UNION ALL SELECT 'United Kingdom',       'Summer bank holiday',     237,  0
  UNION ALL SELECT 'United Kingdom',       'Christmas Day',           359,  0
  UNION ALL SELECT 'United Kingdom',       'Boxing Day',              360,  0
  UNION ALL SELECT 'United States',        'New Year''s Day',           1,  0
  UNION ALL SELECT 'United States',        'Independence Day',        185,  0
  UNION ALL SELECT 'United States',        'Thanksgiving',            331,  0
  UNION ALL SELECT 'United States',        'Christmas Day',           359,  0
  UNION ALL SELECT 'France',               'Jour de l''An',             1,  0
  UNION ALL SELECT 'France',               'Fête du Travail',         121,  0
  UNION ALL SELECT 'France',               'Fête Nationale',          195,  0
  UNION ALL SELECT 'France',               'Assomption',              227,  0
  UNION ALL SELECT 'France',               'Noël',                    359,  0
  UNION ALL SELECT 'Singapore',            'New Year''s Day',           1,  0
  UNION ALL SELECT 'Singapore',            'Chinese New Year',         41,  0
  UNION ALL SELECT 'Singapore',            'National Day',            221,  0
  UNION ALL SELECT 'Singapore',            'Deepavali',               304,  0
  UNION ALL SELECT 'Saudi Arabia',         'Eid al-Fitr',              80,  0
  UNION ALL SELECT 'Saudi Arabia',         'Eid al-Adha',             168,  0
  UNION ALL SELECT 'Saudi Arabia',         'Founding Day',             53,  0
  UNION ALL SELECT 'Saudi Arabia',         'National Day',            266,  0
) AS h
JOIN locations c ON c.level = 'country' AND c.name = h.country_name;

-- One agency closes for its own founding anniversary, which the platform has to
-- honour even though no country does.
INSERT INTO business_holidays
  (organization_id, country_id, name, holiday_date, is_half_day, created_at)
SELECT o.id, o.country_id, CONCAT(o.name, ' — founder''s day'),
       DATE_ADD(MAKEDATE(YEAR(@today), 1), INTERVAL MOD(o.id * 13, 360) DAY), 1, @now
FROM organizations o
WHERE MOD(o.id, 7) = 0;

-- -----------------------------------------------------------------------------
-- Lead capture forms
--
-- Each form owns its own anti-spam posture: a honeypot field, a minimum fill
-- time and a rate limit. The fill-time check catches more automated submissions
-- than the captcha does and costs the honest visitor nothing.
-- -----------------------------------------------------------------------------
INSERT INTO lead_forms
  (public_id, organization_id, code, name, form_type, pipeline_id, source_id,
   routing_pool_id, sla_policy_id, auto_create_lead, requires_captcha,
   honeypot_field, min_fill_seconds, rate_limit_per_hour, consent_text,
   consent_required, success_message, submission_count, spam_count,
   conversion_count, is_active, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('leadform:', f.code)), 26)),
  NULL, f.code, f.name, f.form_type, p.id, src.id, pool.id, sla.id,
  f.auto_create_lead, f.requires_captcha, 'company_website_url',
  f.min_fill_seconds, f.rate_limit_per_hour,
  'I agree to be contacted about this enquiry by the listing agent and by Liv Finder. I can withdraw this at any time from my account settings or the link in any message.',
  1, f.success_message, 0, 0, 0, 1, @now, @now
FROM (
  SELECT 'listing_inquiry' AS code, 'Listing enquiry' AS name, 'inquiry' AS form_type, 1 AS auto_create_lead, 0 AS requires_captcha, 4 AS min_fill_seconds, 6 AS rate_limit_per_hour, 'Thank you. The agent will be in touch shortly — usually within the hour during business hours.' AS success_message
  UNION ALL SELECT 'request_viewing',  'Viewing request',      'viewing_request', 1, 0, 5, 4, 'Your viewing request has been sent. The agent will confirm a time with you directly.'
  UNION ALL SELECT 'request_callback', 'Callback request',     'callback',        1, 0, 3, 8, 'We have your number. Expect a call back shortly.'
  UNION ALL SELECT 'valuation',        'Free property valuation','valuation',     1, 1, 8, 3, 'Thank you. A valuer will contact you to arrange a visit and prepare your report.'
  UNION ALL SELECT 'list_property',    'List your property',   'list_property',   1, 1, 10, 2, 'Thank you. Our onboarding team will contact you about listing your property.'
  UNION ALL SELECT 'mortgage_enquiry', 'Mortgage pre-approval','mortgage',        1, 1, 12, 3, 'Thank you. A mortgage adviser will call you to discuss your options.'
  UNION ALL SELECT 'newsletter',       'Newsletter signup',    'newsletter',      0, 0, 2, 10, 'You are subscribed. Check your inbox to confirm.'
  UNION ALL SELECT 'contact_us',       'General contact',      'contact',         0, 1, 6, 4, 'Thank you for getting in touch. We aim to reply within one working day.'
  UNION ALL SELECT 'agency_signup',    'Agency partnership enquiry','custom',     1, 1, 15, 2, 'Thank you. Our partnerships team will be in touch to discuss listing on Liv Finder.'
) AS f
LEFT JOIN lead_pipelines p ON p.id = (SELECT MIN(id) FROM lead_pipelines)
LEFT JOIN lead_sources src ON src.id = 1 + MOD(CRC32(f.code), (SELECT COUNT(*) FROM lead_sources))
LEFT JOIN lead_routing_pools pool ON pool.id = 1 + MOD(CRC32(f.code), (SELECT COUNT(*) FROM lead_routing_pools))
LEFT JOIN sla_policies sla ON sla.id = 1 + MOD(CRC32(f.code), (SELECT COUNT(*) FROM sla_policies));

INSERT INTO lead_form_fields
  (form_id, field_key, label, field_type, maps_to, placeholder, help_text,
   options, is_required, min_length, max_length, sort_order, is_active, created_at)
SELECT
  f.id, x.field_key, x.label, x.field_type, x.maps_to, x.placeholder,
  x.help_text, x.options, x.is_required, x.min_length, x.max_length,
  x.sort_order, 1, @now
FROM lead_forms f
JOIN (
  SELECT 'name' AS field_key, 'Your name' AS label, 'text' AS field_type, 'name' AS maps_to, 'Full name' AS placeholder, NULL AS help_text, NULL AS options, 1 AS is_required, 2 AS min_length, 120 AS max_length, 1 AS sort_order, 'all' AS applies_to
  UNION ALL SELECT 'email','Email address','email','email','you@example.com',NULL,NULL,1,5,255,2,'all'
  UNION ALL SELECT 'phone','Phone number','phone','phone','+971 50 000 0000','Include the country code so the agent can reach you.',NULL,1,6,20,3,'all'
  UNION ALL SELECT 'message','Message','textarea','message','Tell the agent what you would like to know',NULL,NULL,0,0,2000,4,'inquiry'
  UNION ALL SELECT 'preferred_time','Preferred viewing time','select','custom',NULL,NULL,'["Morning","Afternoon","Evening","Weekend"]',0,0,40,5,'viewing_request'
  UNION ALL SELECT 'budget_min','Budget from','budget','budget_min',NULL,NULL,NULL,0,0,20,6,'inquiry'
  UNION ALL SELECT 'budget_max','Budget up to','budget','budget_max',NULL,NULL,NULL,0,0,20,7,'inquiry'
  UNION ALL SELECT 'timeframe','When are you looking to move?','select','timeframe',NULL,NULL,'["Immediately","Within 3 months","3 to 6 months","6 to 12 months","Just researching"]',0,0,40,8,'inquiry'
  UNION ALL SELECT 'financing','How will you fund the purchase?','radio','financing',NULL,NULL,'["Cash","Mortgage","Not decided"]',0,0,40,9,'mortgage'
  UNION ALL SELECT 'property_address','Property address','text','custom','Building, community, city',NULL,NULL,1,4,255,5,'valuation'
  UNION ALL SELECT 'consent','I agree to be contacted','consent','consent',NULL,NULL,NULL,1,0,1,20,'all'
) AS x
  ON x.applies_to = 'all'
  OR x.applies_to = f.form_type;

INSERT INTO lead_form_submissions
  (form_id, lead_id, inquiry_id, organization_id, listing_id, payload, status,
   rejection_reason, spam_score, fill_seconds, honeypot_triggered,
   captcha_score, ip_address, user_agent, consent_given, consent_text_snapshot,
   landing_url, referrer_url, utm_source, utm_medium, utm_campaign,
   processed_at, created_at)
SELECT
  f.id, l.id, NULL, l.organization_id, l.primary_listing_id,
  JSON_OBJECT('name', l.name, 'email', l.email, 'phone', l.phone_e164,
              'message', 'Interested in this property. Please call me back.',
              'timeframe', COALESCE(l.timeframe, 'Within 3 months')),
  s.status, s.rejection_reason, s.spam_score, s.fill_seconds,
  s.honeypot_triggered,
  ROUND(0.30 + MOD(CONV(SUBSTRING(MD5(CONCAT('captcha:', l.id)), 1, 4), 16, 10), 70) / 100, 3),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('subip:', l.id)), 1, 8), 16, 10)), 8, '0')),
  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Version/17.4 Mobile Safari/604.1',
  1,
  'I agree to be contacted about this enquiry by the listing agent and by Liv Finder.',
  l.landing_url, l.referrer_url, l.utm_source, l.utm_medium, l.utm_campaign,
  CASE WHEN s.status = 'processed' THEN DATE_ADD(l.created_at, INTERVAL 2 SECOND) END,
  l.created_at
FROM leads l
JOIN lead_forms f
  ON f.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('subform:', l.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM lead_forms))
JOIN (
  SELECT l2.id AS lead_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('substat:', l2.id)), 1, 4), 16, 10), 14),
             'processed','processed','processed','processed','processed','processed',
             'processed','processed','processed','processed','processed',
             'rejected_spam','duplicate','rejected_validation') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('substat:', l2.id)), 1, 4), 16, 10), 14),
             NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             'Honeypot field completed and the form was filled in under a second.',
             'Identical enquiry on the same listing from the same address within the deduplication window.',
             'Phone number failed E.164 validation for the stated country.') AS rejection_reason,
         MOD(CONV(SUBSTRING(MD5(CONCAT('spam:', l2.id)), 1, 4), 16, 10), 100) AS spam_score,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('fill:', l2.id)), 1, 4), 16, 10), 180) AS fill_seconds,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('substat:', l2.id)), 1, 4), 16, 10), 14) = 11
              THEN 1 ELSE 0 END AS honeypot_triggered
  FROM leads l2
) AS s ON s.lead_id = l.id;

UPDATE lead_forms f
JOIN (
  SELECT form_id,
         COUNT(*) AS submissions,
         SUM(status = 'rejected_spam') AS spam,
         SUM(status = 'processed') AS processed
  FROM lead_form_submissions GROUP BY form_id
) x ON x.form_id = f.id
SET f.submission_count = x.submissions,
    f.spam_count = x.spam,
    f.conversion_count = x.processed;

-- -----------------------------------------------------------------------------
-- Routing rules
--
-- Evaluated in priority order until one says stop. Conditions are rows rather
-- than a serialised expression so the rule that fired can be shown to the agent
-- who is asking why they got a lead in a city they do not cover.
-- -----------------------------------------------------------------------------
INSERT INTO lead_routing_rules
  (organization_id, name, description, priority, target_type, target_pool_id,
   set_priority, sla_policy_id, stop_processing, match_count, last_matched_at,
   is_active, effective_from, created_by_user_id, created_at, updated_at)
SELECT
  NULL, r.name, r.description, r.priority, r.target_type, pool.id,
  r.set_priority, sla.id, r.stop_processing,
  MOD(CONV(SUBSTRING(MD5(CONCAT('rulehits:', r.name)), 1, 5), 16, 10), 9000),
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('ruleseen:', r.name)), 1, 4), 16, 10), 200) HOUR),
  1, DATE_SUB(@now, INTERVAL 400 DAY), 1, @now, @now
FROM (
  SELECT 'Prime enquiries above five million' AS name,
         'Anything over five million in base currency goes to the private client desk regardless of location, and carries an urgent service level.' AS description,
         10 AS priority, 'pool' AS target_type, 'urgent' AS set_priority, 1 AS stop_processing
  UNION ALL SELECT 'Listing owner first refusal',
         'The agent who holds the listing gets the enquiry first. Only if they do not respond inside the service level does it fall back to the pool.',
         20, 'listing_owner', 'high', 1
  UNION ALL SELECT 'Arabic-language enquiries',
         'Routed to the Arabic-speaking pool. Language is a routing dimension, not a preference to be discovered on the call.',
         30, 'pool', 'normal', 0
  UNION ALL SELECT 'Off-plan enquiries to the new homes desk',
         'Off-plan requires a different conversation and a different set of consents.',
         40, 'pool', 'normal', 1
  UNION ALL SELECT 'Yachts and aviation to the specialist desk',
         'The generalist property agents are not equipped for a charter enquiry.',
         50, 'pool', 'normal', 1
  UNION ALL SELECT 'Out-of-hours to the follow-the-sun pool',
         'Enquiries arriving outside Gulf business hours route to whichever region is awake.',
         60, 'pool', 'normal', 0
  UNION ALL SELECT 'Repeat contacts back to their original agent',
         'A contact who has enquired before goes back to the agent who handled them, so the relationship is not restarted.',
         15, 'agent', 'high', 1
  UNION ALL SELECT 'Everything else, round robin',
         'The catch-all. Even distribution across the pool with a per-member cursor rather than a random draw.',
         999, 'round_robin_org', 'normal', 1
) AS r
LEFT JOIN lead_routing_pools pool ON pool.id = 1 + MOD(CRC32(r.name), (SELECT COUNT(*) FROM lead_routing_pools))
LEFT JOIN sla_policies sla ON sla.id = 1 + MOD(CRC32(r.name), (SELECT COUNT(*) FROM sla_policies));

INSERT INTO lead_routing_rule_conditions
  (rule_id, condition_group, field, operator, value_text, value_number_min,
   value_number_max, value_ids, created_at)
SELECT r.id, c.condition_group, c.field, c.operator, c.value_text,
       c.value_number_min, c.value_number_max, c.value_ids, @now
FROM lead_routing_rules r
JOIN (
  SELECT 'Prime enquiries above five million' AS rule_name, 1 AS condition_group, 'budget_base' AS field, 'gte' AS operator, NULL AS value_text, 5000000 AS value_number_min, NULL AS value_number_max, NULL AS value_ids
  UNION ALL SELECT 'Listing owner first refusal', 1, 'listing_agent', 'is_not_null', NULL, NULL, NULL, NULL
  UNION ALL SELECT 'Arabic-language enquiries', 1, 'language', 'eq', 'ar', NULL, NULL, NULL
  UNION ALL SELECT 'Off-plan enquiries to the new homes desk', 1, 'project', 'is_not_null', NULL, NULL, NULL, NULL
  UNION ALL SELECT 'Yachts and aviation to the specialist desk', 1, 'root_category', 'in', NULL, NULL, NULL, '[3,4,5]'
  UNION ALL SELECT 'Out-of-hours to the follow-the-sun pool', 1, 'hour_of_day', 'not_in', NULL, NULL, NULL, '[8,9,10,11,12,13,14,15,16,17]'
  UNION ALL SELECT 'Out-of-hours to the follow-the-sun pool', 2, 'day_of_week', 'in', NULL, NULL, NULL, '[1,2,3,4,5]'
  UNION ALL SELECT 'Repeat contacts back to their original agent', 1, 'is_repeat_contact', 'eq', 'true', NULL, NULL, NULL
  UNION ALL SELECT 'Prime enquiries above five million', 2, 'purpose', 'eq', 'sale', NULL, NULL, NULL
) AS c ON c.rule_name = r.name;

-- -----------------------------------------------------------------------------
-- Buyer requirements
--
-- What the buyer actually wants, held structurally so a new listing can be
-- matched against it the moment it goes live. The locations are rows because a
-- buyer says "Marina or JBR, but not Dubai Marina towers on Sheikh Zayed Road",
-- and that is an include list plus an exclude.
-- -----------------------------------------------------------------------------
INSERT INTO lead_requirements
  (lead_id, label, category_id, purpose_id, price_min, price_max, currency_code,
   price_max_base, bedrooms_min, bedrooms_max, bathrooms_min, area_min, area_max,
   area_unit_id, furnishing, completion, move_in_by, notes, is_active,
   match_count, last_matched_at, created_at, updated_at)
SELECT
  l.id,
  CASE WHEN r.seq = 0 THEN 'Primary brief' ELSE 'Alternative brief' END,
  l.category_id, l.purpose_id,
  ROUND(COALESCE(l.budget_min, 500000) * r.min_factor, 2),
  ROUND(COALESCE(l.budget_max, 2000000) * r.max_factor, 2),
  COALESCE(l.currency_code, 'USD'),
  ROUND(COALESCE(l.budget_max_base, l.budget_max, 2000000) * r.max_factor, 2),
  r.bedrooms_min, r.bedrooms_max, r.bathrooms_min,
  r.area_min, r.area_max,
  (SELECT id FROM measurement_units WHERE code = 'sqft' LIMIT 1),
  r.furnishing, r.completion,
  DATE_ADD(@today, INTERVAL r.move_in_days DAY),
  r.notes, 1, 0, NULL, l.created_at, @now
FROM leads l
JOIN (
  SELECT l2.id AS lead_id, n.n AS seq,
         ELT(1 + n.n, 0.90, 0.70) AS min_factor,
         ELT(1 + n.n, 1.00, 1.25) AS max_factor,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bmin:', l2.id, n.n)), 1, 4), 16, 10), 3) AS bedrooms_min,
         3 + MOD(CONV(SUBSTRING(MD5(CONCAT('bmax:', l2.id, n.n)), 1, 4), 16, 10), 4) AS bedrooms_max,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bath:', l2.id, n.n)), 1, 4), 16, 10), 3) AS bathrooms_min,
         600 + MOD(CONV(SUBSTRING(MD5(CONCAT('amin:', l2.id, n.n)), 1, 4), 16, 10), 1400) AS area_min,
         2600 + MOD(CONV(SUBSTRING(MD5(CONCAT('amax:', l2.id, n.n)), 1, 4), 16, 10), 6000) AS area_max,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('furn:', l2.id, n.n)), 1, 4), 16, 10), 4),
             'any','furnished','unfurnished','part_furnished') AS furnishing,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('comp:', l2.id, n.n)), 1, 4), 16, 10), 3),
             'any','ready','off_plan') AS completion,
         30 + MOD(CONV(SUBSTRING(MD5(CONCAT('movein:', l2.id, n.n)), 1, 4), 16, 10), 300) AS move_in_days,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('rnote:', l2.id, n.n)), 1, 4), 16, 10), 5),
             'Needs a study and covered parking for two cars. Will not consider ground floor.',
             'School run matters more than the view. Walking distance to the British curriculum school is the deciding factor.',
             'Buying to let. Yield above six per cent gross or it does not work.',
             'Wants a high floor with an unobstructed view. Has walked away from two units where a tower is planned opposite.',
             'Relocating from London in the autumn. Furnished preferred but will furnish if the layout is right.') AS notes
  FROM leads l2
  CROSS JOIN (SELECT n FROM tmp_n WHERE n < 2) n
) AS r ON r.lead_id = l.id
WHERE l.status NOT IN ('lost', 'closed')
  AND (r.seq = 0 OR MOD(CONV(SUBSTRING(MD5(CONCAT('hasalt:', l.id)), 1, 4), 16, 10), 4) = 0);

INSERT INTO lead_requirement_locations
  (requirement_id, location_id, is_excluded, weight)
SELECT
  r.id, loc.id,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('excl:', r.id, loc.id)), 1, 4), 16, 10), 9) = 0 THEN 1 ELSE 0 END,
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('wt:', r.id, loc.id)), 1, 4), 16, 10), 5)
FROM lead_requirements r
JOIN leads l ON l.id = r.lead_id
JOIN locations loc
  ON loc.level = 'community'
 AND loc.city_id = l.city_id
 AND MOD(CONV(SUBSTRING(MD5(CONCAT('locpick:', r.id, ':', loc.id)), 1, 4), 16, 10), 7) = 0;

UPDATE lead_requirements r
JOIN (
  SELECT r2.id AS requirement_id, COUNT(l.id) AS n
  FROM lead_requirements r2
  JOIN listings l
    ON l.status = 'active'
   AND l.purpose_id = r2.purpose_id
   AND l.price_base BETWEEN r2.price_min AND r2.price_max
  GROUP BY r2.id
) m ON m.requirement_id = r.id
SET r.match_count = m.n, r.last_matched_at = @now;

-- -----------------------------------------------------------------------------
-- Lead sharing
--
-- A lead sold, referred or broadcast to another agency. exclusivity and
-- recipient_index together are what make a broadcast honest: the buyer knows
-- how many agencies received it, and the platform can prove it did not oversell.
-- -----------------------------------------------------------------------------
INSERT INTO lead_shares
  (public_id, lead_id, from_organization_id, to_organization_id, to_agent_id,
   share_type, exclusivity, max_recipients, recipient_index, status, offered_at,
   expires_at, accepted_at, rejected_at, rejection_reason, price, currency_code,
   credits_charged, referral_fee_percent, contact_revealed, contact_revealed_at,
   notes, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('leadshare:', l.id, ':', n.n)), 26)),
  l.id, l.organization_id, o.id, NULL,
  sh.share_type, sh.exclusivity, sh.max_recipients, n.n + 1, sh.status,
  DATE_ADD(l.created_at, INTERVAL 1 HOUR),
  DATE_ADD(l.created_at, INTERVAL 25 HOUR),
  CASE WHEN sh.status = 'accepted' THEN DATE_ADD(l.created_at, INTERVAL 3 HOUR) END,
  CASE WHEN sh.status = 'rejected' THEN DATE_ADD(l.created_at, INTERVAL 2 HOUR) END,
  CASE WHEN sh.status = 'rejected' THEN sh.rejection_reason END,
  sh.price, 'USD', sh.credits_charged, sh.referral_fee_percent,
  CASE WHEN sh.status = 'accepted' THEN 1 ELSE 0 END,
  CASE WHEN sh.status = 'accepted' THEN DATE_ADD(l.created_at, INTERVAL 3 HOUR) END,
  CASE WHEN sh.share_type = 'referral'
       THEN 'Referred out of area. Fee payable on completion under the partner agreement.' END,
  DATE_ADD(l.created_at, INTERVAL 1 HOUR), @now
FROM leads l
JOIN (
  SELECT l2.id AS lead_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shtype:', l2.id)), 1, 4), 16, 10), 4),
             'sale','broadcast','referral','partner') AS share_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shtype:', l2.id)), 1, 4), 16, 10), 4),
             'exclusive','shared','exclusive','shared') AS exclusivity,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shtype:', l2.id)), 1, 4), 16, 10), 4),
             1, 3, 1, 2) AS max_recipients,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shstat:', l2.id)), 1, 4), 16, 10), 8),
             'accepted','accepted','accepted','accepted','accepted',
             'rejected','expired','offered') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shrej:', l2.id)), 1, 4), 16, 10), 5),
             'out_of_area','out_of_budget','duplicate','not_qualified','capacity') AS rejection_reason,
         ROUND(25 + MOD(CONV(SUBSTRING(MD5(CONCAT('shprice:', l2.id)), 1, 4), 16, 10), 220), 2) AS price,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shcred:', l2.id)), 1, 4), 16, 10), 8) AS credits_charged,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shfee:', l2.id)), 1, 4), 16, 10), 3),
             15.000, 20.000, 25.000) AS referral_fee_percent
  FROM leads l2
) AS sh ON sh.lead_id = l.id
JOIN tmp_n n ON n.n < sh.max_recipients
-- Each recipient index takes the next organization along, so a broadcast to
-- three agencies reaches three different agencies rather than the same one
-- three times.
JOIN organizations o
  ON o.id <> COALESCE(l.organization_id, 0)
 AND o.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('shorg:', l.id)), 1, 5), 16, 10) + n.n,
                    (SELECT COUNT(*) FROM organizations))
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasshare:', l.id)), 1, 4), 16, 10), 6) = 0;

-- -----------------------------------------------------------------------------
-- Commission schemes
--
-- What the platform charges, tiered so a high-volume agency's marginal rate
-- falls. The tiers are rows so a rate change is a data change and the historic
-- calculation stays reproducible.
-- -----------------------------------------------------------------------------
INSERT INTO commission_schemes
  (code, name, applies_to, calculation, base_percentage, base_fee, currency_code,
   minimum_fee, maximum_fee, effective_from, is_active, created_at)
VALUES
  ('lead_purchase_standard', 'Lead purchase — standard',       'lead_purchase',     'flat_fee',          NULL,    45.00, 'USD',  NULL,    NULL, DATE_SUB(CURDATE(), INTERVAL 500 DAY), 1, NOW(3)),
  ('lead_purchase_tiered',   'Lead purchase — volume tiers',   'lead_purchase',     'tiered_fee',        NULL,    NULL,  'USD', 18.00,  120.00, DATE_SUB(CURDATE(), INTERVAL 400 DAY), 1, NOW(3)),
  ('featured_standard',      'Featured placement',             'featured_placement','flat_fee',          NULL,    89.00, 'USD',  NULL,    NULL, DATE_SUB(CURDATE(), INTERVAL 600 DAY), 1, NOW(3)),
  ('transaction_tiered',     'Transaction commission — tiered','transaction',       'tiered_percentage', NULL,    NULL,  'USD', 500.00, 45000.00, DATE_SUB(CURDATE(), INTERVAL 400 DAY), 1, NOW(3)),
  ('referral_partner',       'Partner referral share',         'referral',          'flat_percentage', 20.0000,   NULL,  'USD', 100.00,    NULL, DATE_SUB(CURDATE(), INTERVAL 300 DAY), 1, NOW(3)),
  ('booking_charter',        'Charter booking commission',     'booking',           'flat_percentage', 12.5000,   NULL,  'USD', 250.00,    NULL, DATE_SUB(CURDATE(), INTERVAL 250 DAY), 1, NOW(3)),
  ('subscription_reseller',  'Reseller subscription share',    'subscription',      'flat_percentage', 30.0000,   NULL,  'USD',  NULL,    NULL, DATE_SUB(CURDATE(), INTERVAL 200 DAY), 1, NOW(3)),
  ('transaction_legacy',     'Transaction commission — legacy','transaction',       'flat_percentage',  2.5000,   NULL,  'USD',  NULL,    NULL, DATE_SUB(CURDATE(), INTERVAL 1200 DAY), 0, NOW(3));

INSERT INTO commission_tiers
  (scheme_id, tier_order, threshold_from, threshold_to, percentage, fixed_fee)
SELECT s.id, t.tier_order, t.threshold_from, t.threshold_to, t.percentage, t.fixed_fee
FROM commission_schemes s
JOIN (
  SELECT 'lead_purchase_tiered' AS code, 1 AS tier_order, 0 AS threshold_from, 50 AS threshold_to, NULL AS percentage, 45.00 AS fixed_fee
  UNION ALL SELECT 'lead_purchase_tiered', 2, 50,   250,  NULL, 34.00
  UNION ALL SELECT 'lead_purchase_tiered', 3, 250,  1000, NULL, 25.00
  UNION ALL SELECT 'lead_purchase_tiered', 4, 1000, NULL, NULL, 18.00
  UNION ALL SELECT 'transaction_tiered',   1, 0,        1000000,  2.5000, NULL
  UNION ALL SELECT 'transaction_tiered',   2, 1000000,  5000000,  2.0000, NULL
  UNION ALL SELECT 'transaction_tiered',   3, 5000000,  20000000, 1.5000, NULL
  UNION ALL SELECT 'transaction_tiered',   4, 20000000, NULL,     1.0000, NULL
) AS t ON t.code = s.code;

-- -----------------------------------------------------------------------------
-- Nurture
--
-- Sequences that run themselves, with exit conditions that matter more than the
-- steps: a sequence that keeps sending after the person replied is the fastest
-- way to lose them.
-- -----------------------------------------------------------------------------
INSERT INTO nurture_campaigns
  (public_id, organization_id, code, name, description, campaign_type,
   entry_criteria, exit_criteria, exit_on_reply, exit_on_stage_change,
   send_window_start, send_window_end, respect_business_hours,
   max_sends_per_week, status, created_by_user_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('nurture:', c.code)), 26)),
  NULL, c.code, c.name, c.description, c.campaign_type,
  c.entry_criteria, c.exit_criteria, 1, 1,
  '09:00:00', '19:00:00', 1, c.max_sends_per_week, c.status, 1, @now, @now
FROM (
  SELECT 'new_lead_welcome' AS code, 'New enquiry welcome sequence' AS name,
         'Five touches over ten days for an enquiry that has not converted to a viewing. Stops the moment they reply.' AS description,
         'nurture' AS campaign_type,
         '{"stage":"new","no_reply_hours":24}' AS entry_criteria,
         '{"viewing_booked":true,"replied":true}' AS exit_criteria,
         3 AS max_sends_per_week, 'active' AS status
  UNION ALL SELECT 'post_viewing','After the viewing',
         'Two touches after a viewing: feedback request, then a comparable if the feedback was lukewarm.',
         'post_viewing','{"viewing_completed":true}','{"offer_made":true,"lost":true}',2,'active'
  UNION ALL SELECT 'price_drop_alert','Price reduction alert',
         'Triggered when a listing the contact viewed drops in price. The highest converting sequence on the platform by a distance.',
         'price_drop','{"viewed_listing":true,"price_reduced":true}','{"inquiry_made":true}',2,'active'
  UNION ALL SELECT 'new_match','New listing matches your brief',
         'A listing matching the saved requirement went live. Batched daily rather than sent per listing.',
         'new_listing_match','{"has_active_requirement":true}','{"unsubscribed":true}',3,'active'
  UNION ALL SELECT 'agency_onboarding','Agency onboarding',
         'Six steps over four weeks: first listing, first photograph upload, first response, first lead, first renewal conversation.',
         'onboarding','{"account_created":true,"account_type":"company"}','{"listings_published":5}',2,'active'
  UNION ALL SELECT 're_engagement','Dormant contact re-engagement',
         'Ninety days quiet. Two touches, then suppression rather than continuing to send to somebody who has moved on.',
         're_engagement','{"days_inactive":90}','{"any_activity":true}',1,'active'
  UNION ALL SELECT 'win_back','Cancelled subscription win-back',
         'Three touches over sixty days after a cancellation, spaced deliberately wide.',
         'win_back','{"subscription_cancelled":true}','{"resubscribed":true}',1,'paused'
  UNION ALL SELECT 'seasonal_summer','Summer market briefing',
         'Seasonal editorial rather than a sales sequence. Kept separate so its unsubscribes do not poison the transactional reputation.',
         'seasonal','{"marketing_opt_in":true}','{"unsubscribed":true}',1,'draft'
) AS c;

INSERT INTO nurture_campaign_steps
  (campaign_id, step_number, name, channel, delay_hours, notification_template_id,
   subject_line, body_template, creates_task, task_title, task_type,
   sent_count, opened_count, clicked_count, replied_count, is_active,
   created_at, updated_at)
SELECT
  c.id, s.step_number, s.name, s.channel, s.delay_hours, nt.id,
  s.subject_line, s.body_template, s.creates_task, s.task_title, s.task_type,
  0, 0, 0, 0, 1, @now, @now
FROM nurture_campaigns c
JOIN (
  SELECT 'new_lead_welcome' AS code, 1 AS step_number, 'Immediate acknowledgement' AS name, 'email' AS channel, 0 AS delay_hours, 'We have your enquiry — here is what happens next' AS subject_line, 'Thank you for enquiring about {{listing_title}}. {{agent_name}} will call you shortly. In the meantime, here are three similar properties in {{community}}.' AS body_template, 0 AS creates_task, NULL AS task_title, NULL AS task_type
  UNION ALL SELECT 'new_lead_welcome', 2, 'Agent call task',        'task',     2,   NULL, NULL, 1, 'Call the enquirer — no response to the acknowledgement', 'call'
  UNION ALL SELECT 'new_lead_welcome', 3, 'Similar properties',     'email',    48,  'Three more in {{community}} you may not have seen', 'Since you enquired about {{listing_title}}, three comparable properties have come to the market in {{community}}.', 0, NULL, NULL
  UNION ALL SELECT 'new_lead_welcome', 4, 'WhatsApp nudge',         'whatsapp', 120, NULL, 'Hi {{first_name}}, {{agent_name}} here from {{agency}}. Still looking in {{community}}? Happy to arrange a viewing this week.', 0, NULL, NULL
  UNION ALL SELECT 'new_lead_welcome', 5, 'Market note and close',  'email',    240, 'A quick note on the {{community}} market', 'Prices in {{community}} moved {{yoy_change}} over the last year. If the timing is not right, I will leave you to it — reply any time.', 0, NULL, NULL
  UNION ALL SELECT 'post_viewing',     1, 'Feedback request',       'email',    18,  'How was the viewing?', 'Thank you for viewing {{listing_title}}. What did you think? Your feedback goes straight to the owner.', 0, NULL, NULL
  UNION ALL SELECT 'post_viewing',     2, 'Comparable follow-up',   'email',    96,  'Another option in {{community}}', 'Based on your feedback, this one may suit better.', 0, NULL, NULL
  UNION ALL SELECT 'price_drop_alert', 1, 'Price drop notice',      'email',    0,   'Price reduced on a property you viewed', '{{listing_title}} has been reduced from {{old_price}} to {{new_price}}.', 0, NULL, NULL
  UNION ALL SELECT 'price_drop_alert', 2, 'Agent follow-up task',   'task',     24,  NULL, NULL, 1, 'Follow up on the price reduction', 'call'
  UNION ALL SELECT 'new_match',        1, 'Daily match digest',     'email',    0,   'New listings matching your brief', '{{match_count}} new listings match what you are looking for in {{locations}}.', 0, NULL, NULL
  UNION ALL SELECT 'agency_onboarding',1, 'Welcome and first steps','email',    0,   'Welcome to Liv Finder', 'Your account is live. Here is how to publish your first listing.', 0, NULL, NULL
  UNION ALL SELECT 'agency_onboarding',2, 'Photography standards',  'email',    48,  'Photographs that sell', 'Listings with twelve or more photographs receive 3.4 times the enquiries.', 0, NULL, NULL
  UNION ALL SELECT 'agency_onboarding',3, 'Response time matters',  'email',    168, 'The first hour', 'Enquiries answered within an hour convert at four times the rate.', 0, NULL, NULL
  UNION ALL SELECT 'agency_onboarding',4, 'Account manager call',   'task',     240, NULL, NULL, 1, 'Onboarding check-in call', 'call'
  UNION ALL SELECT 'agency_onboarding',5, 'Featured placement offer','email',   336, 'Try a featured placement', 'Your first featured placement is on us.', 0, NULL, NULL
  UNION ALL SELECT 'agency_onboarding',6, 'Thirty-day review',      'email',    672, 'Your first month', 'Here is how your listings performed against comparable agencies.', 0, NULL, NULL
  UNION ALL SELECT 're_engagement',    1, 'Still looking?',         'email',    0,   'Still looking in {{community}}?', 'It has been a while. The market has moved — here is where it stands.', 0, NULL, NULL
  UNION ALL SELECT 're_engagement',    2, 'Final note',             'email',    336, 'Last note from us', 'We will stop emailing about your search unless you tell us otherwise.', 0, NULL, NULL
  UNION ALL SELECT 'win_back',         1, 'We would like you back', 'email',    336, 'Your listings are still here', 'Reactivate and your listings go live again immediately.', 0, NULL, NULL
  UNION ALL SELECT 'win_back',         2, 'What changed',           'email',    1008,'What we have built since you left', 'A short note on what has changed.', 0, NULL, NULL
  UNION ALL SELECT 'win_back',         3, 'Offer',                  'email',    1440,'Three months at half price', 'A one-off offer to come back.', 0, NULL, NULL
  UNION ALL SELECT 'seasonal_summer',  1, 'Summer briefing',        'email',    0,   'The summer market, in five minutes', 'What moved, what did not, and where the value is.', 0, NULL, NULL
) AS s ON s.code = c.code
LEFT JOIN notification_templates nt
  ON nt.id = 1 + MOD(s.step_number, (SELECT COUNT(*) FROM notification_templates));

INSERT INTO nurture_enrolments
  (campaign_id, lead_id, contact_id, organization_id, status, current_step,
   next_step_at, enrolled_at, completed_at, exited_at, exit_reason, sends_count,
   opens_count, clicks_count, replies_count, converted, converted_at,
   enrolled_by_user_id, created_at, updated_at)
SELECT
  c.id, l.id, l.contact_id, l.organization_id, e.status, e.current_step,
  CASE WHEN e.status = 'active' THEN DATE_ADD(@now, INTERVAL 1 DAY) END,
  DATE_ADD(l.created_at, INTERVAL 1 DAY),
  CASE WHEN e.status = 'completed' THEN DATE_ADD(l.created_at, INTERVAL 12 DAY) END,
  CASE WHEN e.status = 'exited' THEN DATE_ADD(l.created_at, INTERVAL 4 DAY) END,
  CASE WHEN e.status = 'exited' THEN e.exit_reason END,
  e.sends_count, e.opens_count, e.clicks_count, e.replies_count,
  e.converted,
  CASE WHEN e.converted = 1 THEN DATE_ADD(l.created_at, INTERVAL 6 DAY) END,
  NULL, DATE_ADD(l.created_at, INTERVAL 1 DAY), @now
FROM leads l
JOIN nurture_campaigns c
  ON c.status = 'active'
 AND c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nucamp:', l.id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM nurture_campaigns WHERE status = 'active'))
JOIN (
  SELECT l2.id AS lead_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nustat:', l2.id)), 1, 4), 16, 10), 8),
             'completed','completed','completed','exited','exited','active','active','suppressed') AS status,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nustep:', l2.id)), 1, 4), 16, 10), 5) AS current_step,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nuexit:', l2.id)), 1, 4), 16, 10), 4),
             'replied','converted','unsubscribed','stage_changed') AS exit_reason,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nusends:', l2.id)), 1, 4), 16, 10), 5) AS sends_count,
         MOD(CONV(SUBSTRING(MD5(CONCAT('nuopens:', l2.id)), 1, 4), 16, 10), 4) AS opens_count,
         MOD(CONV(SUBSTRING(MD5(CONCAT('nuclicks:', l2.id)), 1, 4), 16, 10), 3) AS clicks_count,
         MOD(CONV(SUBSTRING(MD5(CONCAT('nureplies:', l2.id)), 1, 4), 16, 10), 2) AS replies_count,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('nuconv:', l2.id)), 1, 4), 16, 10), 6) = 0 THEN 1 ELSE 0 END AS converted
  FROM leads l2
) AS e ON e.lead_id = l.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasnurture:', l.id)), 1, 4), 16, 10), 3) = 0;

INSERT INTO nurture_step_deliveries
  (enrolment_id, step_id, channel, status, scheduled_at, sent_at, delivered_at,
   opened_at, clicked_at, replied_at, skip_reason, created_at, updated_at)
SELECT
  e.id, st.id, st.channel,
  CASE
    WHEN st.step_number > e.current_step THEN 'scheduled'
    WHEN st.channel = 'task' THEN 'sent'
    WHEN st.step_number = e.current_step AND e.replies_count > 0 THEN 'replied'
    WHEN st.step_number <= e.opens_count THEN 'opened'
    ELSE 'delivered'
  END,
  DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours HOUR),
  CASE WHEN st.step_number <= e.current_step
       THEN DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours HOUR) END,
  CASE WHEN st.step_number <= e.current_step
       THEN DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours + 1 HOUR) END,
  CASE WHEN st.step_number <= e.opens_count
       THEN DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours + 3 HOUR) END,
  CASE WHEN st.step_number <= e.clicks_count
       THEN DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours + 4 HOUR) END,
  CASE WHEN st.step_number = e.current_step AND e.replies_count > 0
       THEN DATE_ADD(e.enrolled_at, INTERVAL st.delay_hours + 6 HOUR) END,
  NULL,
  e.enrolled_at, @now
FROM nurture_enrolments e
JOIN nurture_campaign_steps st ON st.campaign_id = e.campaign_id
WHERE st.step_number <= e.current_step + 1;

UPDATE nurture_campaigns c
JOIN (
  SELECT campaign_id,
         COUNT(*) AS enrolled,
         SUM(status = 'active') AS active,
         SUM(status = 'completed') AS completed,
         SUM(converted) AS converted
  FROM nurture_enrolments GROUP BY campaign_id
) x ON x.campaign_id = c.id
SET c.enrolled_count = x.enrolled,
    c.active_count = x.active,
    c.completed_count = x.completed,
    c.converted_count = x.converted;

UPDATE nurture_campaign_steps st
JOIN (
  SELECT step_id,
         SUM(status <> 'scheduled') AS sent,
         SUM(status IN ('opened','clicked','replied')) AS opened,
         SUM(status IN ('clicked','replied')) AS clicked,
         SUM(status = 'replied') AS replied
  FROM nurture_step_deliveries GROUP BY step_id
) d ON d.step_id = st.id
SET st.sent_count = d.sent,
    st.opened_count = d.opened,
    st.clicked_count = d.clicked,
    st.replied_count = d.replied;

DROP TABLE IF EXISTS tmp_n;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- CRM merges, tags and daily statistics
--
-- The merge keeps a snapshot of what it destroyed, and a reverted_at column,
-- because merging two contacts who turn out to be different people is the one
-- CRM mistake that cannot otherwise be undone.
-- -----------------------------------------------------------------------------
INSERT INTO crm_contact_merges
  (organization_id, surviving_contact_id, merged_contact_id, merged_snapshot,
   field_resolutions, match_method, match_confidence, moved_leads,
   moved_activities, moved_deals, performed_by_user_id, reverted_at,
   reverted_by_user_id, created_at)
SELECT
  s.organization_id, s.id, m.id,
  JSON_OBJECT('id', m.id, 'first_name', m.first_name, 'last_name', m.last_name,
              'primary_email', m.primary_email, 'primary_phone_e164', m.primary_phone_e164,
              'created_at', m.created_at),
  JSON_OBJECT('primary_email', 'kept_surviving', 'primary_phone_e164', 'kept_merged',
              'notes', 'concatenated'),
  mg.match_method, mg.match_confidence,
  mg.moved_leads, mg.moved_activities, mg.moved_deals,
  1,
  CASE WHEN mg.reverted = 1 THEN DATE_SUB(@now, INTERVAL 10 DAY) END,
  CASE WHEN mg.reverted = 1 THEN 2 END,
  DATE_SUB(@now, INTERVAL mg.age_days DAY)
FROM crm_contacts s
JOIN crm_contacts m
  ON m.id <> s.id
 AND m.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mergesrc:', s.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM crm_contacts))
JOIN (
  SELECT c.id AS contact_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mmethod:', c.id)), 1, 4), 16, 10), 5),
             'email','phone','name_and_phone','fuzzy','manual') AS match_method,
         ROUND(70 + MOD(CONV(SUBSTRING(MD5(CONCAT('mconf:', c.id)), 1, 4), 16, 10), 30), 2) AS match_confidence,
         MOD(CONV(SUBSTRING(MD5(CONCAT('mleads:', c.id)), 1, 4), 16, 10), 5) AS moved_leads,
         MOD(CONV(SUBSTRING(MD5(CONCAT('macts:', c.id)), 1, 4), 16, 10), 20) AS moved_activities,
         MOD(CONV(SUBSTRING(MD5(CONCAT('mdeals:', c.id)), 1, 4), 16, 10), 3) AS moved_deals,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('mrev:', c.id)), 1, 4), 16, 10), 14) = 0 THEN 1 ELSE 0 END AS reverted,
         MOD(CONV(SUBSTRING(MD5(CONCAT('mage:', c.id)), 1, 4), 16, 10), 400) AS age_days
  FROM crm_contacts c
) AS mg ON mg.contact_id = s.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasmerge:', s.id)), 1, 4), 16, 10), 14) = 0;

INSERT INTO crm_tag_assignments
  (tag_id, subject_type, subject_id, assigned_by_user_id, created_at)
SELECT
  t.id, 'contact', c.id, 1, c.created_at
FROM crm_contacts c
JOIN crm_tags t
  ON t.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('tagc:', c.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM crm_tags))
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hastag:', c.id)), 1, 4), 16, 10), 2) = 0;

INSERT INTO crm_tag_assignments
  (tag_id, subject_type, subject_id, assigned_by_user_id, created_at)
SELECT
  t.id, 'lead', l.id, 1, l.created_at
FROM leads l
JOIN crm_tags t
  ON t.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('tagl:', l.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM crm_tags))
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hastagl:', l.id)), 1, 4), 16, 10), 3) = 0;

INSERT INTO crm_tag_assignments
  (tag_id, subject_type, subject_id, assigned_by_user_id, created_at)
SELECT
  t.id, 'deal', d.id, 1, d.created_at
FROM deals d
JOIN crm_tags t
  ON t.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('tagd:', d.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM crm_tags))
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hastagd:', d.id)), 1, 4), 16, 10), 2) = 0;

INSERT INTO crm_daily_stats
  (stat_date, organization_id, agent_id, leads_created, leads_assigned,
   leads_contacted, leads_qualified, leads_won, leads_lost, calls_made,
   calls_answered, call_seconds, viewings_booked, viewings_completed,
   activities_logged, tasks_completed, deals_created, deals_won,
   deal_value_base, commission_base, avg_first_response_minutes,
   median_first_response_minutes, sla_met_count, sla_breached_count, computed_at)
SELECT
  DATE_SUB(@today, INTERVAL d.n DAY), a.organization_id, a.id,
  v.leads_created, v.leads_created,
  ROUND(v.leads_created * 0.86), ROUND(v.leads_created * 0.42),
  ROUND(v.leads_created * 0.07), ROUND(v.leads_created * 0.31),
  v.calls_made, ROUND(v.calls_made * 0.61), ROUND(v.calls_made * 0.61 * 155),
  ROUND(v.leads_created * 0.22), ROUND(v.leads_created * 0.16),
  ROUND(v.leads_created * 2.4), ROUND(v.leads_created * 1.1),
  ROUND(v.leads_created * 0.11), ROUND(v.leads_created * 0.05),
  ROUND(v.leads_created * 0.05 * 1450000, 2),
  ROUND(v.leads_created * 0.05 * 1450000 * 0.02, 2),
  v.avg_response, ROUND(v.avg_response * 0.72),
  ROUND(v.leads_created * 0.79), ROUND(v.leads_created * 0.21),
  @now
FROM agents a
JOIN (SELECT n FROM tmp_n WHERE n BETWEEN 1 AND 60) AS d
JOIN (
  SELECT a2.id AS agent_id, n2.n AS days_ago,
         MOD(CONV(SUBSTRING(MD5(CONCAT('crmleads:', a2.id, n2.n)), 1, 4), 16, 10), 9) AS leads_created,
         MOD(CONV(SUBSTRING(MD5(CONCAT('crmcalls:', a2.id, n2.n)), 1, 4), 16, 10), 22) AS calls_made,
         12 + MOD(CONV(SUBSTRING(MD5(CONCAT('crmresp:', a2.id, n2.n)), 1, 4), 16, 10), 220) AS avg_response
  FROM agents a2 CROSS JOIN (SELECT n FROM tmp_n WHERE n BETWEEN 1 AND 60) n2
) AS v ON v.agent_id = a.id AND v.days_ago = d.n
WHERE a.status = 'active'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hascrmstat:', a.id)), 1, 4), 16, 10), 3) = 0;

-- -----------------------------------------------------------------------------
-- Call events
--
-- The leg-by-leg trace behind a call record. The consent announcement is an
-- event of its own because in several jurisdictions the recording is only
-- lawful if it played, and "it should have" is not evidence.
-- -----------------------------------------------------------------------------
INSERT INTO call_events
  (call_id, sequence_number, event_type, leg, target_e164, target_agent_id,
   dtmf_digits, error_code, error_message, occurred_at)
SELECT
  c.id, e.sequence_number, e.event_type, e.leg,
  CASE WHEN e.event_type IN ('ringing', 'answered', 'transferred') THEN '+971500000000' END,
  NULL,
  CASE WHEN e.event_type = 'dtmf' THEN '1' END,
  CASE WHEN e.event_type = 'failed' THEN 'SIP-486' END,
  CASE WHEN e.event_type = 'failed' THEN 'Busy here. The destination rejected the call.' END,
  DATE_ADD(c.started_at, INTERVAL e.offset_seconds SECOND)
FROM calls c
JOIN (
  SELECT 1 AS sequence_number, 'initiated' AS event_type, 'inbound' AS leg, 0 AS offset_seconds, 'all' AS applies_to
  UNION ALL SELECT 2, 'consent_played',  'inbound',    1,  'all'
  UNION ALL SELECT 3, 'ringing',         'outbound',   3,  'all'
  UNION ALL SELECT 4, 'whisper_played',  'outbound',   9,  'answered'
  UNION ALL SELECT 5, 'answered',        'outbound',  11,  'answered'
  UNION ALL SELECT 6, 'dtmf',            'inbound',   14,  'answered'
  UNION ALL SELECT 7, 'held',            'conference',60,  'answered'
  UNION ALL SELECT 8, 'resumed',         'conference',95,  'answered'
  UNION ALL SELECT 9, 'completed',       'inbound',  180,  'answered'
  UNION ALL SELECT 10,'voicemail_start', 'outbound',  28,  'missed'
  UNION ALL SELECT 11,'voicemail_end',   'outbound',  62,  'missed'
  UNION ALL SELECT 12,'failed',          'outbound',  25,  'failed'
) AS e
  ON e.applies_to = 'all'
  OR (e.applies_to = 'answered' AND c.status IN ('completed', 'in_progress'))
  OR (e.applies_to = 'missed' AND c.status IN ('missed', 'voicemail', 'no_answer'))
  OR (e.applies_to = 'failed' AND c.status IN ('failed', 'busy', 'cancelled'));

-- -----------------------------------------------------------------------------
-- Search curation, boosting and the index queue
--
-- Curation is editorial override, boosting is systematic. Keeping them apart
-- matters: a pinned result for one query is a decision somebody made on a
-- Tuesday, and a category-wide boost is a change to how ranking works.
-- -----------------------------------------------------------------------------
INSERT INTO search_curations
  (query_normalized, match_type, country_id, language_id, curation_type,
   listing_id, project_id, pin_position, message_text, redirect_url, reason,
   starts_at, ends_at, is_active, created_by_user_id, created_at, updated_at)
SELECT
  c.query_normalized, c.match_type, loc.id, 1, c.curation_type,
  CASE WHEN c.curation_type IN ('pin', 'bury', 'exclude') THEN l.id END,
  NULL,
  CASE WHEN c.curation_type = 'pin' THEN c.pin_position END,
  CASE WHEN c.curation_type = 'message' THEN c.message_text END,
  CASE WHEN c.curation_type = 'redirect' THEN c.redirect_url END,
  c.reason,
  DATE_SUB(@now, INTERVAL 60 DAY),
  CASE WHEN c.curation_type = 'banner' THEN DATE_ADD(@now, INTERVAL 30 DAY) END,
  1, 1, @now, @now
FROM (
  SELECT 'palm jumeirah villa' AS query_normalized, 'exact' AS match_type, 'United Arab Emirates' AS country_name, 'pin' AS curation_type, 1 AS pin_position, NULL AS message_text, NULL AS redirect_url, 'Signature villa placed first for the highest-volume branded query in the market.' AS reason
  UNION ALL SELECT 'burj khalifa apartment','exact','United Arab Emirates','pin',1,NULL,NULL,'The tower itself, not the surrounding towers that rank on the name.'
  UNION ALL SELECT 'off plan dubai','contains','United Arab Emirates','banner',NULL,NULL,NULL,'Off-plan explainer banner: the query is dominated by first-time buyers who do not know what escrow means.'
  UNION ALL SELECT 'cheap property dubai','contains','United Arab Emirates','message',NULL,'Prices in Dubai start from around AED 400,000 for a studio. Use the price filter to set your budget.',NULL,'A query with a mismatch between expectation and market. The message sets it straight rather than returning nothing useful.'
  UNION ALL SELECT 'james edition','exact',NULL,'redirect',NULL,NULL,'/collections/luxury','Competitor brand query. Redirected to the curated collection rather than an empty result.'
  UNION ALL SELECT 'scam listing','contains',NULL,'message',NULL,'Report a suspicious listing using the flag on any listing page. Our moderation team reviews every report within four hours.',NULL,'Trust query. The right answer is a route to the report flow, not a set of listings.'
  UNION ALL SELECT 'monaco penthouse','exact','Monaco','pin',1,NULL,NULL,'Flagship Monaco listing pinned for the market''s defining query.'
  UNION ALL SELECT 'sunset villa','exact',NULL,'bury',NULL,NULL,NULL,'A withdrawn listing kept ranking on its name after relisting elsewhere. Buried rather than deleted so the URL still resolves.'
  UNION ALL SELECT 'test listing','prefix',NULL,'exclude',NULL,NULL,NULL,'Staging content that reached production through a feed. Excluded pending removal.'
) AS c
LEFT JOIN locations loc ON loc.level = 'country' AND loc.name = c.country_name
-- Numbering the active listings first means the pick always lands on one,
-- rather than hashing onto an id that happens to be withdrawn.
JOIN (
  SELECT id, ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM listings WHERE status = 'active'
) AS l
  ON l.rn = 1 + MOD(CRC32(c.query_normalized),
                    (SELECT COUNT(*) FROM listings WHERE status = 'active'));

INSERT INTO search_boost_rules
  (name, profile_id, subject_type, subject_id, attribute_code, attribute_value,
   scope_category_id, boost_type, boost_value, pin_position, reason, starts_at,
   ends_at, is_active, created_by_user_id, created_at, updated_at)
SELECT
  b.name, p.id, b.subject_type,
  CASE WHEN b.subject_type IN ('organization') THEN o.id END,
  b.attribute_code, b.attribute_value, cat.id, b.boost_type, b.boost_value,
  NULL, b.reason,
  DATE_SUB(@now, INTERVAL 120 DAY),
  CASE WHEN b.is_temporary = 1 THEN DATE_ADD(@now, INTERVAL 45 DAY) END,
  1, 1, @now, @now
FROM (
  SELECT 'Verified listings first' AS name, 'attribute' AS subject_type, 'is_verified' AS attribute_code, 'true' AS attribute_value, NULL AS category_code, 'multiply' AS boost_type, 1.2500 AS boost_value, 'Verified listings convert better and complain less. The boost is modest deliberately -- large enough to matter, small enough that relevance still wins.' AS reason, 0 AS is_temporary
  UNION ALL SELECT 'Penalise listings with fewer than five photographs', 'attribute', 'image_count_low', 'true', NULL, 'multiply', 0.7000, 'Thin listings waste a click. Demoted rather than hidden, because sometimes the property is genuinely worth it.', 0
  UNION ALL SELECT 'Freshness decay', 'attribute', 'days_since_refresh', '30', NULL, 'multiply', 0.9000, 'A listing untouched for a month is more likely to be gone. Decay is gentle and applies per thirty days.', 0
  UNION ALL SELECT 'Exclusive mandates', 'attribute', 'is_exclusive', 'true', NULL, 'multiply', 1.1500, 'Exclusive mandates are less likely to be duplicated across agencies, so the result set is cleaner.', 0
  UNION ALL SELECT 'Suppress duplicate inventory', 'attribute', 'is_duplicate_cluster_member', 'true', NULL, 'multiply', 0.4000, 'The same unit listed by four agencies. One survives at full weight; the rest are heavily demoted rather than removed.', 0
  UNION ALL SELECT 'Partner agency visibility', 'organization', NULL, NULL, NULL, 'multiply', 1.1000, 'Contractual visibility uplift for a strategic partner. Disclosed in the ranking documentation.', 1
  UNION ALL SELECT 'New homes campaign', 'attribute', 'is_off_plan', 'true', 'real-estate', 'multiply', 1.2000, 'Seasonal campaign uplift for off-plan inventory during the launch window.', 1
  -- An exclude carries no multiplier; the column holds zero so the arithmetic
  -- downstream never has to special-case a null.
  UNION ALL SELECT 'Exclude withdrawn from suggestions', 'attribute', 'status_withdrawn', 'true', NULL, 'exclude', 0.0000, 'Withdrawn listings must not appear in autocomplete even though their pages still resolve.', 0
) AS b
LEFT JOIN search_ranking_profiles p ON p.id = (SELECT MIN(id) FROM search_ranking_profiles)
LEFT JOIN categories cat ON cat.code = b.category_code AND cat.parent_id IS NULL
LEFT JOIN organizations o ON o.id = 1
;

INSERT INTO search_index_queue
  (subject_type, subject_id, operation, changed_fields, priority, status,
   attempts, last_error, claimed_by, claimed_at, available_at, processed_at,
   created_at)
SELECT
  'listing', l.id, q.operation, q.changed_fields, q.priority, q.status,
  q.attempts,
  CASE WHEN q.status = 'failed'
       THEN 'Index cluster returned 429 on bulk write. The document is retried with backoff.' END,
  CASE WHEN q.status = 'processing' THEN 'indexer-worker-03' END,
  CASE WHEN q.status = 'processing' THEN DATE_SUB(@now, INTERVAL 40 SECOND) END,
  DATE_SUB(@now, INTERVAL q.age_minutes MINUTE),
  CASE WHEN q.status = 'completed' THEN DATE_SUB(@now, INTERVAL q.age_minutes - 1 MINUTE) END,
  DATE_SUB(@now, INTERVAL q.age_minutes MINUTE)
FROM listings l
JOIN (
  SELECT l2.id AS listing_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('idxop:', l2.id)), 1, 4), 16, 10), 6),
             'upsert','upsert','upsert','partial','reindex','delete') AS operation,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('idxop:', l2.id)), 1, 4), 16, 10), 6) = 3
              THEN '["price","price_base","updated_at"]' END AS changed_fields,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('idxpri:', l2.id)), 1, 4), 16, 10), 3), 1, 5, 9) AS priority,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('idxstat:', l2.id)), 1, 4), 16, 10), 10),
             'completed','completed','completed','completed','completed','completed',
             'completed','pending','processing','failed') AS status,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('idxstat:', l2.id)), 1, 4), 16, 10), 10) = 9
              THEN 3 ELSE 1 END AS attempts,
         MOD(CONV(SUBSTRING(MD5(CONCAT('idxage:', l2.id)), 1, 4), 16, 10), 600) AS age_minutes
  FROM listings l2
) AS q ON q.listing_id = l.id;

INSERT INTO search_experiment_exposures
  (experiment_id, variant_id, visitor_id, user_id, first_exposed_at,
   last_exposed_at, exposure_count, converted, converted_at)
SELECT
  v.experiment_id, v.id, s.visitor_id, s.user_id,
  MIN(s.started_at), MAX(s.started_at), COUNT(*),
  MAX(s.converted),
  CASE WHEN MAX(s.converted) = 1 THEN MAX(s.started_at) END
FROM web_sessions s
JOIN search_experiment_variants v
  ON v.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sexp:', s.visitor_id)), 1, 4), 16, 10),
                    (SELECT COUNT(*) FROM search_experiment_variants))
WHERE s.is_bot = 0
GROUP BY v.experiment_id, v.id, s.visitor_id, s.user_id;

INSERT INTO search_result_events
  (occurred_at, event_type, search_id, query_hash, query_text, listing_id,
   position, page_number, ranking_profile_id, is_promoted, relevance_score,
   category_id, location_id, visitor_id, session_id, user_id, device_type,
   dwell_seconds)
SELECT
  DATE_ADD(q.searched_at, INTERVAL n.n SECOND),
  CASE WHEN n.n = 0 THEN 'impression'
       WHEN n.n = 1 AND MOD(CONV(SUBSTRING(MD5(CONCAT('sre:', q.id, n.n)), 1, 4), 16, 10), 5) = 0 THEN 'click'
       WHEN n.n = 2 AND MOD(CONV(SUBSTRING(MD5(CONCAT('sre:', q.id, n.n)), 1, 4), 16, 10), 23) = 0 THEN 'inquiry'
       WHEN n.n = 3 AND MOD(CONV(SUBSTRING(MD5(CONCAT('sre:', q.id, n.n)), 1, 4), 16, 10), 11) = 0 THEN 'favourite'
       ELSE 'skip' END,
  q.id,
  LEFT(MD5(COALESCE(q.query_text, '')), 32),
  LEFT(COALESCE(q.query_text, ''), 300),
  l.id,
  n.n + 1, 1,
  rp.id,
  CASE WHEN l.is_featured = 1 THEN 1 ELSE 0 END,
  ROUND(100 - n.n * 6 + MOD(CONV(SUBSTRING(MD5(CONCAT('rel:', q.id, n.n)), 1, 4), 16, 10), 12), 4),
  l.category_id, l.location_id,
  LOWER(MD5(CONCAT('visitor:', MOD(q.id, 900)))),
  LOWER(MD5(CONCAT('session:', q.id))),
  NULL,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sredev:', q.id)), 1, 4), 16, 10), 3), 'mobile', 'desktop', 'tablet'),
  CASE WHEN n.n = 1 THEN 5 + MOD(CONV(SUBSTRING(MD5(CONCAT('dwell:', q.id)), 1, 4), 16, 10), 200) END
FROM (
  SELECT sq.id, sq.searched_at, sq.query_text
  FROM search_queries sq
  WHERE MOD(sq.id, 6) = 0
) AS q
JOIN tmp_n n ON n.n < 5
JOIN (
  SELECT id, category_id, location_id, is_featured,
         ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM listings WHERE status = 'active'
) AS l
  ON l.rn = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('srelist:', q.id, ':', n.n)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM listings WHERE status = 'active'))
LEFT JOIN search_ranking_profiles rp ON rp.id = (SELECT MIN(id) FROM search_ranking_profiles);

-- -----------------------------------------------------------------------------
-- Affinity profiles
--
-- What the platform believes about a visitor, with a confidence attached. The
-- confidence is the honest part: three sessions is a guess, forty is a profile,
-- and the recommendation layer should treat them differently.
-- -----------------------------------------------------------------------------
INSERT INTO user_affinity_profiles
  (user_id, visitor_id, primary_intent, root_category_id, purpose_id,
   budget_p25_base, budget_median_base, budget_p75_base, location_affinity,
   category_affinity, bedroom_affinity, view_count, inquiry_count,
   favourite_count, search_count, session_count, confidence, lifecycle_stage,
   first_seen_at, last_active_at, computed_at, expires_at)
SELECT
  s.user_id, s.visitor_id,
  a.primary_intent, a.root_category_id, a.purpose_id,
  ROUND(a.budget * 0.75, 2), ROUND(a.budget, 2), ROUND(a.budget * 1.35, 2),
  JSON_OBJECT('top', JSON_ARRAY('dubai-marina', 'palm-jumeirah', 'downtown-dubai'),
              'weights', JSON_ARRAY(0.52, 0.31, 0.17)),
  JSON_OBJECT('real-estate', 0.86, 'yachts', 0.09, 'cars', 0.05),
  JSON_OBJECT('2', 0.41, '3', 0.38, '4', 0.21),
  s.listing_views, s.inquiries, s.favourites, s.searches, s.sessions,
  -- Confidence rises with observed sessions and saturates: forty sessions tells
  -- you little more than twenty did.
  ROUND(LEAST(0.9500, 0.1200 + s.sessions * 0.0700), 4),
  CASE
    WHEN s.inquiries > 0 THEN 'deciding'
    WHEN s.favourites > 0 THEN 'shortlisting'
    WHEN s.sessions > 2 THEN 'browsing'
    ELSE 'new'
  END,
  s.first_seen, s.last_active, @now,
  DATE_ADD(@now, INTERVAL 90 DAY)
FROM (
  SELECT visitor_id, MAX(user_id) AS user_id,
         SUM(listing_views) AS listing_views, SUM(inquiries) AS inquiries,
         SUM(favourites) AS favourites, SUM(searches) AS searches,
         COUNT(*) AS sessions,
         MIN(started_at) AS first_seen, MAX(started_at) AS last_active
  FROM web_sessions WHERE is_bot = 0
  GROUP BY visitor_id
) AS s
JOIN (
  SELECT w.visitor_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('intent:', w.visitor_id)), 1, 4), 16, 10), 5),
             'buy','rent','browse','invest','sell') AS primary_intent,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('affcat:', w.visitor_id)), 1, 4), 16, 10), 6) AS root_category_id,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('affpur:', w.visitor_id)), 1, 4), 16, 10), 2) AS purpose_id,
         400000 + MOD(CONV(SUBSTRING(MD5(CONCAT('affbud:', w.visitor_id)), 1, 6), 16, 10), 9000000) AS budget
  FROM (SELECT DISTINCT visitor_id FROM web_sessions WHERE is_bot = 0) w
) AS a ON a.visitor_id = s.visitor_id;

DROP TABLE IF EXISTS tmp_n;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- Advertising delivery
--
-- Month-partitioned, append-only and seeded thinly: the shape is what matters,
-- not the volume. is_viewable is separate from served, because an impression
-- that never entered the viewport is not one the advertiser agreed to pay for,
-- and the invalid-traffic flag is what keeps the billed figure defensible.
-- -----------------------------------------------------------------------------
INSERT INTO ad_impressions
  (occurred_at, line_item_id, creative_id, placement_id, campaign_id,
   advertiser_id, page_type, category_id, country_id, listing_id, visitor_id,
   session_id, user_id, device_type, is_viewable, view_time_ms, slot_position,
   revenue, currency_code, is_invalid, invalid_reason)
SELECT
  DATE_SUB(@now, INTERVAL i.minutes_ago MINUTE),
  li.id, cr.id, li.placement_id, li.campaign_id, c.advertiser_id,
  i.page_type, NULL, l.country_id, l.id,
  LOWER(MD5(CONCAT('visitor:', MOD(i.seq, 900)))),
  LOWER(MD5(CONCAT('session:', i.seq))),
  NULL, i.device_type,
  i.is_viewable, i.view_time_ms, i.slot_position,
  ROUND(i.revenue, 6), 'USD',
  i.is_invalid,
  CASE WHEN i.is_invalid = 1 THEN 'datacentre_ip' END
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
LEFT JOIN ad_creatives cr ON cr.line_item_id = li.id
  AND cr.id = (SELECT MIN(cr2.id) FROM ad_creatives cr2 WHERE cr2.line_item_id = li.id)
JOIN (
  SELECT li2.id AS line_item_id, n.n AS seq,
         MOD(CONV(SUBSTRING(MD5(CONCAT('impmin:', li2.id, n.n)), 1, 5), 16, 10), 43200) AS minutes_ago,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('imppage:', li2.id, n.n)), 1, 4), 16, 10), 4),
             'search_results','listing_detail','location_landing','home') AS page_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('impdev:', li2.id, n.n)), 1, 4), 16, 10), 4),
             'mobile','desktop','mobile','tablet') AS device_type,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('impview:', li2.id, n.n)), 1, 4), 16, 10), 10) < 7
              THEN 1 ELSE 0 END AS is_viewable,
         200 + MOD(CONV(SUBSTRING(MD5(CONCAT('imptime:', li2.id, n.n)), 1, 4), 16, 10), 9000) AS view_time_ms,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('impslot:', li2.id, n.n)), 1, 4), 16, 10), 4) AS slot_position,
         MOD(CONV(SUBSTRING(MD5(CONCAT('imprev:', li2.id, n.n)), 1, 4), 16, 10), 900) / 100000 AS revenue,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('impinv:', li2.id, n.n)), 1, 4), 16, 10), 34) = 0
              THEN 1 ELSE 0 END AS is_invalid
  FROM ad_line_items li2 CROSS JOIN (SELECT n FROM tmp_n WHERE n < 40) n
) AS i ON i.line_item_id = li.id
JOIN (
  SELECT id, country_id, ROW_NUMBER() OVER (ORDER BY id) AS rn
  FROM listings WHERE status = 'active'
) AS l
  ON l.rn = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('implist:', li.id, i.seq)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM listings WHERE status = 'active'));

INSERT INTO ad_events
  (occurred_at, event_type, line_item_id, creative_id, placement_id, campaign_id,
   advertiser_id, impression_id, visitor_id, session_id, device_type, country_id,
   listing_id, destination_url, seconds_since_impression, revenue, currency_code,
   conversion_value, is_invalid, invalid_reason)
SELECT
  DATE_ADD(i.occurred_at, INTERVAL e.delay_seconds SECOND),
  e.event_type, i.line_item_id, i.creative_id, i.placement_id, i.campaign_id,
  i.advertiser_id, i.id, i.visitor_id, i.session_id, i.device_type, i.country_id,
  i.listing_id,
  CASE WHEN e.event_type = 'click'
       THEN CONCAT('https://www.livfinder.com/listing/', i.listing_id, '?utm_source=onsite&utm_medium=display') END,
  e.delay_seconds,
  CASE WHEN e.event_type = 'click' THEN ROUND(i.revenue * 30, 6) ELSE 0 END,
  'USD',
  CASE WHEN e.event_type = 'conversion' THEN 240.00 END,
  0, NULL
FROM ad_impressions i
JOIN (
  SELECT 'click' AS event_type, 4 AS delay_seconds, 22 AS every
  UNION ALL SELECT 'engagement', 2,  9
  UNION ALL SELECT 'expand',     6,  31
  UNION ALL SELECT 'close',      8,  17
  UNION ALL SELECT 'conversion', 180, 260
  UNION ALL SELECT 'lead_submit',240, 340
) AS e ON MOD(i.id, e.every) = 0
WHERE i.is_viewable = 1 AND i.is_invalid = 0;

INSERT INTO ad_frequency_state
  (visitor_id, line_item_id, period_start, impressions, clicks, last_served_at)
SELECT
  i.visitor_id, i.line_item_id,
  DATE_FORMAT(i.occurred_at, '%Y-%m-%d 00:00:00'),
  COUNT(*),
  SUM(CASE WHEN EXISTS (SELECT 1 FROM ad_events e
                         WHERE e.impression_id = i.id AND e.event_type = 'click')
           THEN 1 ELSE 0 END),
  MAX(i.occurred_at)
FROM ad_impressions i
GROUP BY i.visitor_id, i.line_item_id, DATE_FORMAT(i.occurred_at, '%Y-%m-%d 00:00:00');

-- -----------------------------------------------------------------------------
-- Affiliate clicks
--
-- The click token is the attribution key and it expires. Without an expiry an
-- affiliate is paid on a conversion two years after a click nobody remembers.
-- -----------------------------------------------------------------------------
INSERT INTO affiliate_clicks
  (affiliate_id, link_id, visitor_id, session_id, click_token, landing_url,
   referrer_url, ip_address, user_agent, country_id, device_type,
   is_suspicious, expires_at, clicked_at)
SELECT
  al.affiliate_id, al.id,
  LOWER(MD5(CONCAT('visitor:', MOD(n.n, 900)))),
  LOWER(MD5(CONCAT('session:', al.id, ':', n.n))),
  LOWER(MD5(CONCAT('clicktoken:', al.id, ':', n.n))),
  CONCAT('https://www.livfinder.com/?ref=', al.id),
  CONCAT('https://partner-', al.affiliate_id, '.example/reviews'),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('afip:', al.id, n.n)), 1, 8), 16, 10)), 8, '0')),
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  loc.id,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('afdev:', al.id, n.n)), 1, 4), 16, 10), 3), 'mobile', 'desktop', 'tablet'),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('afsus:', al.id, n.n)), 1, 4), 16, 10), 40) = 0 THEN 1 ELSE 0 END,
  DATE_ADD(DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('afwhen:', al.id, n.n)), 1, 4), 16, 10), 900) HOUR),
           INTERVAL 30 DAY),
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('afwhen:', al.id, n.n)), 1, 4), 16, 10), 900) HOUR)
FROM affiliate_links al
JOIN (SELECT n FROM tmp_n WHERE n < 25) AS n
LEFT JOIN locations loc
  ON loc.level = 'country'
 AND loc.name = ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('afcty:', al.id, n.n)), 1, 4), 16, 10), 4),
                    'United Arab Emirates', 'United Kingdom', 'United States', 'Singapore');

-- -----------------------------------------------------------------------------
-- Fraud
--
-- Rules with a score and an action, and assessments that record which rules
-- fired. The true-positive and false-positive counters on the rule are what
-- make it possible to retire a rule that is costing more in declined good
-- customers than it saves.
-- -----------------------------------------------------------------------------
INSERT INTO fraud_rules
  (code, name, description, rule_type, conditions, score_delta, action,
   is_active, priority, trigger_count, true_positive_count,
   false_positive_count, created_at, updated_at)
SELECT
  r.code, r.name, r.description, r.rule_type, r.conditions, r.score_delta,
  r.action, r.is_active, r.priority,
  r.trigger_count, r.true_positive_count, r.false_positive_count, @now, @now
FROM (
  SELECT 'card_testing_velocity' AS code, 'Card testing — rapid small attempts' AS name,
         'More than four payment attempts from one device within ten minutes, each under twenty units. The signature of a card-testing script rather than a customer.' AS description,
         'velocity' AS rule_type,
         '{"window_minutes":10,"attempt_count":4,"max_amount":20,"group_by":"device_fingerprint"}' AS conditions,
         60 AS score_delta, 'block' AS action, 1 AS is_active, 10 AS priority,
         842 AS trigger_count, 806 AS true_positive_count, 36 AS false_positive_count
  UNION ALL SELECT 'bin_country_mismatch','Card country differs from IP country',
         'On its own this is weak -- expatriates and travellers trip it constantly -- so it scores rather than blocks.',
         'bin_country_mismatch','{"compare":["bin_country","ip_country"]}',15,'score_only',1,50,
         14022, 611, 13411
  UNION ALL SELECT 'high_value_new_account','High value on a new account',
         'First transaction above ten thousand within seventy-two hours of signup. Challenged with 3-D Secure rather than blocked.',
         'amount_threshold','{"amount_min":10000,"account_age_hours_max":72}',35,'challenge_3ds',1,20,
         402, 88, 314
  UNION ALL SELECT 'proxy_vpn','Connection through a proxy or VPN',
         'Weak signal in isolation. Meaningful only in combination, which is why it scores low.',
         'proxy_vpn','{"providers":["datacentre","vpn","tor"]}',10,'score_only',1,60,
         28114, 902, 27212
  UNION ALL SELECT 'disposable_email','Disposable email domain',
         'Signup with a throwaway address. Reviewed rather than blocked; some legitimate buyers value the privacy.',
         'email_domain','{"list":"disposable_domains"}',25,'review',1,40,
         1904, 641, 1263
  UNION ALL SELECT 'blacklisted_device','Device on the blocklist',
         'A device fingerprint previously associated with a confirmed chargeback.',
         'blacklist','{"list":"device_blocklist"}',80,'block',1,5,
         211, 203, 8
  UNION ALL SELECT 'impossible_travel','Impossible travel between sessions',
         'Two sessions from the same account whose separation would require faster-than-commercial-flight travel.',
         'geo_mismatch','{"max_kmh":900}',40,'review',1,30,
         664, 291, 373
  UNION ALL SELECT 'ml_composite','Model composite score',
         'The provider''s own score, folded in as one input rather than treated as the decision. A model that cannot be explained cannot be appealed.',
         'ml_score','{"threshold":0.72}',30,'review',1,70,
         5120, 2810, 2310
  UNION ALL SELECT 'listing_flood','Bulk listing creation from a new account',
         'More than forty listings in an hour from an account under a week old. Almost always a scraped feed being republished.',
         'velocity','{"window_minutes":60,"listing_count":40,"account_age_days_max":7}',55,'review',1,25,
         96, 84, 12
  UNION ALL SELECT 'refund_abuse','Repeated refund requests',
         'Retired. It fired on genuinely dissatisfied customers far more often than on abusers.',
         'velocity','{"window_days":90,"refund_count":3}',30,'review',0,80,
         1440, 96, 1344
) AS r;

INSERT INTO fraud_assessments
  (payment_intent_id, account_id, user_id, assessment_type, total_score,
   decision, triggered_rules, provider, provider_score, device_fingerprint,
   ip_address, ip_country_id, is_proxy, bin_country, outcome,
   reviewed_by_user_id, reviewed_at, created_at)
SELECT
  NULL, p.account_id, NULL, 'payment',
  a.total_score, a.decision,
  a.triggered_rules,
  'fraud_scoring',
  ROUND(a.total_score / 100, 3),
  LEFT(MD5(CONCAT('device:', p.id)), 32),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('frip:', p.id)), 1, 8), 16, 10)), 8, '0')),
  loc.id,
  CASE WHEN a.total_score > 40 THEN 1 ELSE 0 END,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bin:', p.id)), 1, 4), 16, 10), 5), 'AE', 'GB', 'US', 'FR', 'RU'),
  a.outcome,
  CASE WHEN a.decision IN ('review', 'block') THEN 1 END,
  CASE WHEN a.decision IN ('review', 'block') THEN DATE_ADD(p.created_at, INTERVAL 40 MINUTE) END,
  p.created_at
FROM payments p
LEFT JOIN locations loc ON loc.level = 'country' AND loc.name = 'United Arab Emirates'
JOIN (
  SELECT p2.id AS payment_id,
         MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) AS total_score,
         CASE
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 80 THEN 'block'
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 55 THEN 'challenge'
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 35 THEN 'review'
           ELSE 'allow'
         END AS decision,
         CASE
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 80
             THEN '["blacklisted_device","card_testing_velocity"]'
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 55
             THEN '["high_value_new_account","bin_country_mismatch"]'
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 35
             THEN '["proxy_vpn","ml_composite"]'
           ELSE '[]'
         END AS triggered_rules,
         CASE
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frscore:', p2.id)), 1, 4), 16, 10), 100) >= 80 THEN 'fraudulent'
           WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('frout:', p2.id)), 1, 4), 16, 10), 12) = 0 THEN 'disputed'
           ELSE 'legitimate'
         END AS outcome
  FROM payments p2
) AS a ON a.payment_id = p.id;

INSERT INTO blocklist_entries
  (entry_type, value, reason, action, hit_count, expires_at,
   created_by_user_id, created_at)
VALUES
  ('email_domain', 'mailinator.com',       'Disposable address provider. Signups flagged for review rather than blocked outright.', 'flag',     4102, NULL, 1, NOW(3)),
  ('email_domain', 'guerrillamail.com',    'Disposable address provider.',                                                          'flag',     2881, NULL, 1, NOW(3)),
  ('email_domain', 'yopmail.com',          'Disposable address provider.',                                                          'flag',     1944, NULL, 1, NOW(3)),
  ('email',        'known.fraudster@example.com', 'Confirmed chargeback fraud across three accounts.',                              'block',      41, NULL, 1, NOW(3)),
  ('ip_range',     '185.220.100.0/22',     'Tor exit node range. Blocked on the checkout path only.',                               'block',     882, NULL, 1, NOW(3)),
  ('ip_range',     '45.155.204.0/24',      'Datacentre range with sustained scraping.',                                             'throttle', 20114, NULL, 1, NOW(3)),
  ('ip',           '203.0.113.44',         'Single address responsible for four hundred enquiry submissions in an hour.',           'block',     412, DATE_ADD(NOW(3), INTERVAL 30 DAY), 1, NOW(3)),
  ('phone',        '+447700900000',        'Number used across nineteen fraudulent listings.',                                      'block',      88, NULL, 1, NOW(3)),
  ('device',       'a41f9c2b7e0d4a6f8b3c1e5d7a9f2b4c', 'Device fingerprint tied to a confirmed card-testing run.',                   'block',     203, NULL, 1, NOW(3)),
  ('keyword',      'guaranteed rental return', 'Regulated financial claim. Listings containing it are held for moderation.',         'flag',      612, NULL, 1, NOW(3)),
  ('keyword',      'wire transfer only',    'Common advance-fee fraud phrasing.',                                                    'flag',      284, NULL, 1, NOW(3)),
  ('keyword',      'no viewing required',   'Almost always a listing that does not exist.',                                          'flag',      147, NULL, 1, NOW(3));

-- -----------------------------------------------------------------------------
-- Anti-money-laundering escalation
--
-- The source-of-funds declaration and the suspicious activity report. The
-- tipping-off control is the customer_disclosed flag: telling the customer a
-- report has been filed is itself an offence in most of these jurisdictions, so
-- the column exists to prove it did not happen.
-- -----------------------------------------------------------------------------
INSERT INTO source_of_funds_declarations
  (profile_id, deal_id, source_type, description, amount, currency_code,
   amount_base, origin_country_id, institution_name, institution_country_id,
   evidence_document_ids, status, reviewed_by_user_id, reviewed_at, review_note,
   declared_at, created_at, updated_at)
SELECT
  p.id, NULL, s.source_type, s.description,
  ROUND(s.amount, 2), 'USD', ROUND(s.amount, 2),
  origin.id, s.institution_name, origin.id,
  '[]', s.status,
  CASE WHEN s.status IN ('accepted', 'rejected', 'escalated') THEN 1 END,
  CASE WHEN s.status IN ('accepted', 'rejected', 'escalated')
       THEN DATE_SUB(@now, INTERVAL MOD(p.id, 200) DAY) END,
  CASE s.status
    WHEN 'accepted'  THEN 'Evidence consistent with the declaration. Bank statements and the sale contract agree to the amount declared.'
    WHEN 'rejected'  THEN 'Documentation does not support the declared amount. A further explanation was requested and not provided.'
    WHEN 'escalated' THEN 'Referred to the money laundering reporting officer. The origin jurisdiction is on the enhanced due diligence list.'
    ELSE NULL
  END,
  DATE_SUB(@now, INTERVAL MOD(p.id, 300) DAY),
  DATE_SUB(@now, INTERVAL MOD(p.id, 300) DAY), @now
FROM kyc_profiles p
JOIN (
  SELECT p2.id AS profile_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sof:', p2.id)), 1, 4), 16, 10), 8),
             'employment','business_income','sale_of_property','sale_of_investments',
             'inheritance','gift','mortgage','savings') AS source_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sof:', p2.id)), 1, 4), 16, 10), 8),
             'Salary and annual bonus accumulated over eleven years with the same employer.',
             'Distributions from a trading company the declarant owns outright. Audited accounts provided for three years.',
             'Proceeds of a residential sale completed four months ago. Completion statement and bank credit provided.',
             'Liquidation of a listed equity portfolio held with a private bank. Contract notes provided.',
             'Inheritance following probate. Grant of probate and executor''s distribution statement provided.',
             'Gift from a parent. Gift letter, the donor''s own source of funds and the transfer record provided.',
             'Mortgage advance from a regulated lender. Offer letter provided; funds to be drawn at completion.',
             'Accumulated savings across two accounts held for more than five years.') AS description,
         200000 + MOD(CONV(SUBSTRING(MD5(CONCAT('sofamt:', p2.id)), 1, 6), 16, 10), 14000000) AS amount,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sofinst:', p2.id)), 1, 4), 16, 10), 6),
             'HSBC Private Bank','Emirates NBD Private','Julius Baer','Coutts',
             'Standard Chartered Priority','Barclays Wealth') AS institution_name,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sofstat:', p2.id)), 1, 4), 16, 10), 8),
             'accepted','accepted','accepted','accepted','accepted',
             'under_review','evidence_pending','escalated') AS status
  FROM kyc_profiles p2
) AS s ON s.profile_id = p.id
LEFT JOIN locations origin
  ON origin.level = 'country'
 AND origin.name = ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('soforig:', p.id)), 1, 4), 16, 10), 5),
                       'United Kingdom', 'United Arab Emirates', 'Switzerland', 'Singapore', 'United States');

INSERT INTO suspicious_activity_reports
  (public_id, reference, profile_id, subject_type, subject_id, report_type,
   trigger_reason, narrative, amount_involved, currency_code, amount_base,
   status, raised_by_user_id, raised_at, mlro_user_id, mlro_decision,
   mlro_decided_at, mlro_rationale, filed_at, filed_with, filing_reference,
   action_taken, customer_disclosed, retain_until, closed_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('sar:', s.reference)), 26)),
  s.reference, p.id, s.subject_type, p.id, s.report_type, s.trigger_reason,
  s.narrative, ROUND(s.amount, 2), 'USD', ROUND(s.amount, 2), s.status,
  1, DATE_SUB(@now, INTERVAL s.age_days DAY),
  2, s.mlro_decision,
  CASE WHEN s.mlro_decision <> 'pending'
       THEN DATE_SUB(@now, INTERVAL s.age_days - 4 DAY) END,
  CASE WHEN s.mlro_decision = 'file'
       THEN 'The pattern is not explained by the customer''s stated profile and the counterparty jurisdiction is high risk. Filing.'
       WHEN s.mlro_decision = 'do_not_file'
       THEN 'Explained on review: the funds are a documented inheritance and the timing coincides with probate. No grounds to file.'
       WHEN s.mlro_decision = 'more_information'
       THEN 'Insufficient to decide. Further source-of-funds evidence requested from the relationship manager.'
       ELSE NULL END,
  CASE WHEN s.status IN ('filed', 'closed_reported')
       THEN DATE_SUB(@now, INTERVAL s.age_days - 6 DAY) END,
  CASE WHEN s.status IN ('filed', 'closed_reported') THEN 'UAE Financial Intelligence Unit' END,
  CASE WHEN s.status IN ('filed', 'closed_reported')
       THEN CONCAT('FIU-', UPPER(LEFT(MD5(CONCAT('fiu:', s.reference)), 10))) END,
  s.action_taken,
  -- Never. Telling the customer is the tipping-off offence, and this column is
  -- the evidence that it did not happen.
  0,
  DATE_ADD(@today, INTERVAL 1825 DAY),
  CASE WHEN s.status LIKE 'closed%' THEN DATE_SUB(@now, INTERVAL s.age_days - 20 DAY) END,
  DATE_SUB(@now, INTERVAL s.age_days DAY), @now
FROM kyc_profiles p
JOIN (
  SELECT p2.id AS profile_id,
         CONCAT('SAR-', YEAR(CURDATE()), '-', LPAD(p2.id, 5, '0')) AS reference,
         'account' AS subject_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sartype:', p2.id)), 1, 4), 16, 10), 3),
             'internal_escalation','sar','str') AS report_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sartrig:', p2.id)), 1, 4), 16, 10), 6),
             'source_of_funds_unclear','structuring','high_risk_jurisdiction',
             'third_party_payment','pep_exposure','unusual_value') AS trigger_reason,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sartrig:', p2.id)), 1, 4), 16, 10), 6),
             'Purchaser declined to evidence the origin of a seven-figure deposit beyond a one-line statement, then withdrew and re-offered through a different corporate vehicle.',
             'A single purchase settled through eleven transfers over nine days, each below the reporting threshold, from four accounts in three jurisdictions.',
             'Funds routed through a jurisdiction on the enhanced due diligence list with no commercial connection to the transaction or to the purchaser.',
             'Payment received from a company with no disclosed relationship to the purchaser and no explanation offered when asked.',
             'The beneficial owner was identified during screening as a close associate of a politically exposed person not declared at onboarding.',
             'Transaction value is an order of magnitude above anything in the customer''s declared profile and the explanation offered was not credible.') AS narrative,
         400000 + MOD(CONV(SUBSTRING(MD5(CONCAT('saramt:', p2.id)), 1, 6), 16, 10), 12000000) AS amount,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sarstat:', p2.id)), 1, 4), 16, 10), 6),
             'filed','closed_reported','closed_no_action','under_investigation','escalated','draft') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('sarstat:', p2.id)), 1, 4), 16, 10), 6),
             'file','file','do_not_file','pending','more_information','pending') AS mlro_decision,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('saract:', p2.id)), 1, 4), 16, 10), 5),
             'monitoring','restricted','none','frozen','terminated') AS action_taken,
         30 + MOD(CONV(SUBSTRING(MD5(CONCAT('sarage:', p2.id)), 1, 4), 16, 10), 300) AS age_days
  FROM kyc_profiles p2
) AS s ON s.profile_id = p.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hassar:', p.id)), 1, 4), 16, 10), 9) = 0;

-- -----------------------------------------------------------------------------
-- Contract versions
--
-- Every rendered version kept with its hash. When a party says the clause was
-- different when they signed, the answer is a row rather than an argument.
-- -----------------------------------------------------------------------------
INSERT INTO contract_versions
  (contract_id, version_number, content_hash, rendered_body, change_summary,
   changed_clauses, created_by_user_id, is_current, created_at)
SELECT
  c.id, v.n + 1,
  LEFT(SHA2(CONCAT('contractver:', c.id, ':', v.n), 256), 64),
  CONCAT('AGREEMENT — ', c.title, CHAR(10), CHAR(10), 'Version ', v.n + 1,
         CHAR(10), CHAR(10),
         '1. Parties', CHAR(10), '2. Property', CHAR(10), '3. Consideration', CHAR(10),
         '4. Commission', CHAR(10), '5. Term and termination', CHAR(10),
         '6. Governing law and jurisdiction', CHAR(10)),
  CASE v.n
    WHEN 0 THEN 'Initial draft generated from the standard template.'
    WHEN 1 THEN 'Commission rate amended following negotiation. Clause 4.2 revised.'
    WHEN 2 THEN 'Governing law changed at the buyer''s request. Clause 6 revised and the jurisdiction clause aligned.'
    ELSE 'Execution copy. No substantive changes from the previous version.'
  END,
  CASE v.n
    WHEN 1 THEN '["4.2"]'
    WHEN 2 THEN '["6.1","6.2"]'
    ELSE NULL
  END,
  c.created_by_user_id,
  CASE WHEN v.n = vc.max_version THEN 1 ELSE 0 END,
  DATE_ADD(c.created_at, INTERVAL v.n * 2 DAY)
FROM contracts c
JOIN (
  SELECT c2.id AS contract_id,
         MOD(CONV(SUBSTRING(MD5(CONCAT('cver:', c2.id)), 1, 4), 16, 10), 4) AS max_version
  FROM contracts c2
) AS vc ON vc.contract_id = c.id
JOIN tmp_n v ON v.n <= vc.max_version;

-- -----------------------------------------------------------------------------
-- Delivery streams and operational counters
-- -----------------------------------------------------------------------------
INSERT INTO notification_deliveries
  (notification_id, user_id, template_id, channel, recipient, subject, status,
   provider, provider_message_id, error_message, attempts, sent_at,
   delivered_at, opened_at, created_at)
SELECT
  n.id, n.user_id, nt.id, d.channel,
  CASE d.channel WHEN 'email' THEN u.email
                 WHEN 'sms' THEN u.phone_e164
                 ELSE CONCAT('device:', LEFT(MD5(CONCAT('push:', u.id)), 16)) END,
  CASE WHEN d.channel = 'email' THEN LEFT(n.title, 255) END,
  d.status,
  CASE d.channel WHEN 'email' THEN 'sendgrid' WHEN 'sms' THEN 'twilio' ELSE 'firebase' END,
  LEFT(MD5(CONCAT('provmsg:', n.id, d.channel)), 32),
  CASE WHEN d.status IN ('bounced', 'failed')
       THEN '550 5.1.1 The email account that you tried to reach does not exist.' END,
  CASE WHEN d.status IN ('bounced', 'failed') THEN 2 ELSE 1 END,
  n.created_at,
  CASE WHEN d.status NOT IN ('queued', 'failed', 'bounced')
       THEN DATE_ADD(n.created_at, INTERVAL 4 SECOND) END,
  CASE WHEN d.status IN ('opened', 'clicked')
       THEN DATE_ADD(n.created_at, INTERVAL 40 MINUTE) END,
  n.created_at
FROM notifications n
JOIN users u ON u.id = n.user_id
LEFT JOIN notification_templates nt
  ON nt.id = 1 + MOD(n.id, (SELECT COUNT(*) FROM notification_templates))
JOIN (
  SELECT 'email' AS channel, 0 AS slot
  UNION ALL SELECT 'push', 1
  UNION ALL SELECT 'sms', 2
  UNION ALL SELECT 'in_app', 3
) AS ch ON ch.slot = MOD(n.id, 4)
JOIN (
  SELECT n2.id AS notification_id, ch2.channel,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('ndstat:', n2.id, ch2.channel)), 1, 4), 16, 10), 12),
             'delivered','delivered','delivered','delivered','opened','opened',
             'opened','clicked','sent','queued','bounced','failed') AS status
  FROM notifications n2
  CROSS JOIN (SELECT 'email' AS channel UNION ALL SELECT 'push'
              UNION ALL SELECT 'sms' UNION ALL SELECT 'in_app') ch2
) AS d ON d.notification_id = n.id AND d.channel = ch.channel;

INSERT INTO message_delivery_events
  (occurred_at, event_type, channel, delivery_id, notification_id, user_id,
   destination_hash, recipient_domain, bounce_class, smtp_code, reason,
   clicked_url, is_machine_open, device_type, client_name, ip_address)
SELECT
  DATE_ADD(nd.created_at, INTERVAL e.offset_seconds SECOND),
  e.event_type, nd.channel, nd.id, nd.notification_id, nd.user_id,
  SHA2(nd.recipient, 256),
  SUBSTRING_INDEX(nd.recipient, '@', -1),
  CASE WHEN e.event_type = 'bounced' THEN 'hard' END,
  CASE WHEN e.event_type = 'bounced' THEN '550' END,
  CASE WHEN e.event_type = 'bounced'
       THEN 'The email account that you tried to reach does not exist.' END,
  CASE WHEN e.event_type = 'clicked'
       THEN 'https://www.livfinder.com/account/notifications' END,
  CASE WHEN e.event_type = 'opened' AND MOD(nd.id, 3) = 0 THEN 1 ELSE 0 END,
  ELT(1 + MOD(nd.id, 3), 'mobile', 'desktop', 'tablet'),
  ELT(1 + MOD(nd.id, 4), 'Apple Mail', 'Gmail', 'Outlook', 'Superhuman'),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('mdeip:', nd.id)), 1, 8), 16, 10)), 8, '0'))
FROM notification_deliveries nd
JOIN (
  SELECT 'queued' AS event_type, 0 AS offset_seconds, 'all' AS applies_to
  UNION ALL SELECT 'sent',      1,   'all'
  UNION ALL SELECT 'delivered', 4,   'delivered'
  UNION ALL SELECT 'opened',    2400,'opened'
  UNION ALL SELECT 'clicked',   2700,'clicked'
  UNION ALL SELECT 'bounced',   6,   'bounced'
) AS e
  ON e.applies_to = 'all'
  OR e.applies_to = nd.status
  OR (e.applies_to = 'delivered' AND nd.status IN ('opened', 'clicked'))
  OR (e.applies_to = 'opened' AND nd.status = 'clicked')
WHERE nd.channel = 'email';

INSERT INTO message_attachments
  (message_id, media_asset_id, file_name, file_url, mime_type, file_size_bytes,
   created_at)
SELECT
  m.id, NULL,
  a.file_name,
  CONCAT('https://secure.livfinder.com/messages/', LEFT(MD5(CONCAT('att:', m.id)), 20), '/', a.file_name),
  a.mime_type,
  120000 + MOD(CONV(SUBSTRING(MD5(CONCAT('attsize:', m.id)), 1, 5), 16, 10), 6000000),
  m.created_at
FROM messages m
JOIN (
  SELECT 'floor-plan.pdf' AS file_name, 'application/pdf' AS mime_type, 0 AS slot
  UNION ALL SELECT 'passport-copy.pdf',    'application/pdf', 1
  UNION ALL SELECT 'tenancy-contract.pdf', 'application/pdf', 2
  UNION ALL SELECT 'photo.jpg',            'image/jpeg',      3
  UNION ALL SELECT 'brochure.pdf',         'application/pdf', 4
) AS a ON a.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('atttype:', m.id)), 1, 4), 16, 10), 5)
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasatt:', m.id)), 1, 4), 16, 10), 8) = 0;

INSERT INTO webhook_deliveries
  (webhook_id, event_type, payload, status, attempts, response_status,
   response_body, duration_ms, next_retry_at, delivered_at, created_at)
SELECT
  w.id, d.event_type,
  JSON_OBJECT('event', d.event_type, 'id', d.seq,
              'occurred_at', DATE_FORMAT(DATE_SUB(@now, INTERVAL d.minutes_ago MINUTE), '%Y-%m-%dT%H:%i:%sZ'),
              'data', JSON_OBJECT('object', 'listing', 'id', d.seq)),
  d.status, d.attempts,
  CASE d.status WHEN 'delivered' THEN 200 WHEN 'failed' THEN 503 WHEN 'abandoned' THEN 500 END,
  CASE WHEN d.status <> 'pending' THEN LEFT(CONCAT('{"received":', IF(d.status = 'delivered', 'true', 'false'), '}'), 2000) END,
  40 + MOD(CONV(SUBSTRING(MD5(CONCAT('whdur:', w.id, d.seq)), 1, 4), 16, 10), 3000),
  CASE WHEN d.status = 'failed' THEN DATE_ADD(@now, INTERVAL 8 MINUTE) END,
  CASE WHEN d.status = 'delivered'
       THEN DATE_SUB(@now, INTERVAL d.minutes_ago - 1 MINUTE) END,
  DATE_SUB(@now, INTERVAL d.minutes_ago MINUTE)
FROM webhooks w
JOIN (
  SELECT w2.id AS webhook_id, n.n AS seq,
         ELT(1 + MOD(n.n, 8),
             'listing.published','listing.updated','listing.withdrawn','inquiry.created',
             'lead.assigned','deal.won','payment.succeeded','subscription.updated') AS event_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('whstat:', w2.id, n.n)), 1, 4), 16, 10), 10),
             'delivered','delivered','delivered','delivered','delivered','delivered',
             'delivered','pending','failed','abandoned') AS status,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('whstat:', w2.id, n.n)), 1, 4), 16, 10), 10) >= 8
              THEN 5 ELSE 1 END AS attempts,
         MOD(CONV(SUBSTRING(MD5(CONCAT('whmin:', w2.id, n.n)), 1, 4), 16, 10), 4000) AS minutes_ago
  FROM webhooks w2 CROSS JOIN (SELECT n FROM tmp_n WHERE n < 30) n
) AS d ON d.webhook_id = w.id;

INSERT INTO api_request_logs
  (occurred_at, direction, api_client_id, organization_id, method, endpoint,
   full_path, api_version, status_code, duration_ms, request_bytes,
   response_bytes, error_code, error_message, rate_limit_remaining,
   was_rate_limited, retry_attempt, trace_id, ip_address, user_agent)
SELECT
  DATE_SUB(@now, INTERVAL r.minutes_ago MINUTE),
  'inbound', c.id, NULL, r.method, r.endpoint,
  CONCAT('/v2', r.endpoint), 'v2',
  r.status_code, r.duration_ms,
  400 + MOD(CONV(SUBSTRING(MD5(CONCAT('reqb:', c.id, r.seq)), 1, 4), 16, 10), 9000),
  900 + MOD(CONV(SUBSTRING(MD5(CONCAT('resb:', c.id, r.seq)), 1, 5), 16, 10), 90000),
  CASE WHEN r.status_code >= 400 THEN r.error_code END,
  CASE WHEN r.status_code >= 400 THEN r.error_message END,
  GREATEST(0, 1000 - MOD(r.seq * 37, 1000)),
  CASE WHEN r.status_code = 429 THEN 1 ELSE 0 END,
  CASE WHEN r.status_code >= 500 THEN 1 ELSE 0 END,
  LEFT(MD5(CONCAT('trace:', c.id, r.seq)), 32),
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('apiip:', c.id)), 1, 8), 16, 10)), 8, '0')),
  'LivFinder-Partner-SDK/2.4 (php/8.3)'
FROM api_clients c
JOIN (
  SELECT c2.id AS client_id, n.n AS seq,
         MOD(CONV(SUBSTRING(MD5(CONCAT('apimin:', c2.id, n.n)), 1, 4), 16, 10), 5000) AS minutes_ago,
         ELT(1 + MOD(n.n, 6), 'GET','GET','GET','POST','PATCH','DELETE') AS method,
         ELT(1 + MOD(n.n, 6),
             '/listings','/listings/{id}','/locations/search','/listings',
             '/listings/{id}','/listings/{id}') AS endpoint,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('apistat:', c2.id, n.n)), 1, 4), 16, 10), 14),
             200,200,200,200,200,200,200,200,201,204,400,401,429,500) AS status_code,
         20 + MOD(CONV(SUBSTRING(MD5(CONCAT('apidur:', c2.id, n.n)), 1, 4), 16, 10), 1800) AS duration_ms,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('apistat:', c2.id, n.n)), 1, 4), 16, 10), 14),
             NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             'validation_failed','unauthorized','rate_limited','internal_error') AS error_code,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('apistat:', c2.id, n.n)), 1, 4), 16, 10), 14),
             NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,
             'price must be a positive number',
             'The API key is not valid for this environment.',
             'Rate limit exceeded. Retry after 42 seconds.',
             'An unexpected error occurred. The trace id is in the response header.') AS error_message
  FROM api_clients c2 CROSS JOIN (SELECT n FROM tmp_n WHERE n < 60) n
) AS r ON r.client_id = c.id;

INSERT INTO rate_limit_counters
  (bucket_key, window_start, window_seconds, hit_count, blocked_count, expires_at)
SELECT
  b.bucket_key,
  DATE_SUB(@now, INTERVAL MOD(b.seq, 12) HOUR),
  b.window_seconds,
  b.hit_count, b.blocked_count,
  DATE_ADD(DATE_SUB(@now, INTERVAL MOD(b.seq, 12) HOUR), INTERVAL b.window_seconds SECOND)
FROM (
  SELECT CONCAT('api:client:', c.id, ':hour') AS bucket_key, 3600 AS window_seconds,
         MOD(CONV(SUBSTRING(MD5(CONCAT('rl:', c.id)), 1, 4), 16, 10), 9000) AS hit_count,
         MOD(CONV(SUBSTRING(MD5(CONCAT('rlb:', c.id)), 1, 4), 16, 10), 40) AS blocked_count,
         c.id AS seq
  FROM api_clients c
  UNION ALL
  SELECT CONCAT('form:', f.code, ':ip:hour'), 3600,
         MOD(CONV(SUBSTRING(MD5(CONCAT('rlf:', f.id)), 1, 4), 16, 10), 200),
         MOD(CONV(SUBSTRING(MD5(CONCAT('rlfb:', f.id)), 1, 4), 16, 10), 12),
         f.id
  FROM lead_forms f
  UNION ALL
  SELECT CONCAT('login:ip:', n.n, ':minute'), 60,
         MOD(CONV(SUBSTRING(MD5(CONCAT('rll:', n.n)), 1, 4), 16, 10), 30),
         MOD(CONV(SUBSTRING(MD5(CONCAT('rllb:', n.n)), 1, 4), 16, 10), 8),
         n.n
  FROM tmp_n n WHERE n.n < 20
  UNION ALL
  SELECT CONCAT('search:visitor:', n.n, ':minute'), 60,
         MOD(CONV(SUBSTRING(MD5(CONCAT('rls:', n.n)), 1, 4), 16, 10), 60),
         MOD(CONV(SUBSTRING(MD5(CONCAT('rlsb:', n.n)), 1, 4), 16, 10), 5),
         n.n
  FROM tmp_n n WHERE n.n < 20
) AS b;

-- -----------------------------------------------------------------------------
-- Listing attribute values and location boundaries
--
-- The attribute value table is the generic half of the hybrid model: the
-- per-category tables carry the columns every listing in that category has, and
-- this carries the ones only some of them do. The boundary is a polygon so a
-- "draw your own search area" query resolves against a real shape rather than a
-- bounding box.
-- -----------------------------------------------------------------------------
INSERT INTO listing_attribute_values
  (listing_id, attribute_id, value_numeric, value_text, value_boolean,
   value_date, attribute_option_id)
SELECT
  l.id, a.id,
  CASE WHEN a.data_type IN ('integer', 'decimal')
       THEN ROUND(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('av:', l.id, a.id)), 1, 5), 16, 10), 9000), 4) END,
  CASE WHEN a.data_type = 'string'
       THEN CONCAT('Value ', 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('avs:', l.id, a.id)), 1, 4), 16, 10), 40)) END,
  CASE WHEN a.data_type = 'boolean'
       THEN MOD(CONV(SUBSTRING(MD5(CONCAT('avb:', l.id, a.id)), 1, 4), 16, 10), 2) END,
  CASE WHEN a.data_type = 'date'
       THEN DATE_SUB(@today, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('avd:', l.id, a.id)), 1, 4), 16, 10), 3000) DAY) END,
  opt.id
FROM listings l
JOIN attributes a
  ON MOD(CONV(SUBSTRING(MD5(CONCAT('avpick:', l.id, ':', a.id)), 1, 4), 16, 10), 9) = 0
LEFT JOIN attribute_options opt
  ON a.data_type = 'enum' AND opt.attribute_id = a.id
 AND opt.id = (SELECT MIN(o2.id) FROM attribute_options o2 WHERE o2.attribute_id = a.id);

-- Boundaries for the core markets. A rectangle around the centroid stands in
-- for the surveyed polygon a production system imports from the land registry;
-- the shape of the table and the spatial index are what matter here.
INSERT INTO location_boundaries
  (location_id, boundary, bbox_min_lat, bbox_min_lng, bbox_max_lat, bbox_max_lng,
   source, updated_at)
SELECT
  l.id,
  ST_GeomFromText(CONCAT('POLYGON((',
    l.latitude - b.d, ' ', l.longitude - b.d, ',',
    l.latitude - b.d, ' ', l.longitude + b.d, ',',
    l.latitude + b.d, ' ', l.longitude + b.d, ',',
    l.latitude + b.d, ' ', l.longitude - b.d, ',',
    l.latitude - b.d, ' ', l.longitude - b.d, '))'), 4326),
  ROUND(l.latitude - b.d, 7), ROUND(l.longitude - b.d, 7),
  ROUND(l.latitude + b.d, 7), ROUND(l.longitude + b.d, 7),
  'derived_bbox', @now
FROM locations l
JOIN (
  SELECT 'city' AS level, 0.0900 AS d
  UNION ALL SELECT 'community', 0.0180
  UNION ALL SELECT 'sub_community', 0.0060
) AS b ON b.level = l.level
WHERE l.latitude IS NOT NULL AND l.longitude IS NOT NULL
  AND l.is_core_market = 1;

DROP TABLE IF EXISTS tmp_n;
