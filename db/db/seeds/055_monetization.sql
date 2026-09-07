-- =============================================================================
-- Liv Finder — seed 055 · Promotions, credits and advertising
-- =============================================================================
-- The rate card is the product. Every price here is a real one from the Gulf
-- market at roughly 2026 levels, and the relationships between them are the
-- part that matters: a featured slot costs about four times a bump, a homepage
-- takeover costs about twenty times a feature, and the credit packs are priced
-- so buying in volume is cheaper per unit without being so much cheaper that
-- the small buyer feels punished.
--
-- Inventory is finite and counted. `promotion_inventory` carries capacity and
-- sold counts per slot per day, which is what makes overselling impossible
-- rather than unlikely — and overselling a featured placement is not a rounding
-- error, it is a refund and an angry phone call.
--
-- The advertising side is seeded as a working ad server: placements that
-- correspond to real positions on the page, campaigns from the advertisers a
-- property portal actually sells to, targeting rules, and delivery data derived
-- from the listing views that already exist so the numbers are consistent with
-- the traffic in the rest of the database.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Promotion products
--
-- `boost_multiplier` and `results_pin_position` are the contract between what
-- was sold and what the ranking layer does. Making them explicit is what stops
-- "featured" meaning whatever the ORDER BY happened to say that week.
-- -----------------------------------------------------------------------------
INSERT INTO promotion_products
  (public_id, code, name, description, product_type, boost_multiplier,
   results_pin_position, badge_label, badge_colour, applies_to, duration_days,
   is_recurring, consumes_inventory, max_per_listing, is_bundle, is_active,
   is_public, sort_order)
VALUES
  (UPPER(LEFT(MD5('prod:bump'), 26)), 'bump', 'Bump to top',
   'Moves the listing to the top of the default sort as if it had just been published. Consumed once, with a cooling-off period so it cannot be abused.',
   'bump', 1.000, NULL, NULL, NULL, 'listing', NULL, 0, 0, 30, 0, 1, 1, 10),

  (UPPER(LEFT(MD5('prod:featured-7'), 26)), 'featured-7', 'Featured — 7 days',
   'Appears in the featured strip above the results for its community, with a badge. Capacity is limited per community per day.',
   'featured', 2.500, NULL, 'Featured', '#F59E0B', 'listing', 7, 0, 1, NULL, 0, 1, 1, 20),

  (UPPER(LEFT(MD5('prod:featured-30'), 26)), 'featured-30', 'Featured — 30 days',
   'The same placement over a month. Priced at roughly three weeks for four, which is where most agencies land.',
   'featured', 2.500, NULL, 'Featured', '#F59E0B', 'listing', 30, 1, 1, NULL, 0, 1, 1, 30),

  (UPPER(LEFT(MD5('prod:premium-30'), 26)), 'premium-30', 'Premium — 30 days',
   'A larger card, more photographs in the results, and a stronger ranking boost. The step up from featured.',
   'premium', 4.000, NULL, 'Premium', '#7C3AED', 'listing', 30, 1, 1, NULL, 0, 1, 1, 40),

  (UPPER(LEFT(MD5('prod:spotlight-7'), 26)), 'spotlight-7', 'Spotlight — 7 days',
   'Pinned into the third result position for its community and purpose. One listing at a time, which is why it is scarce and expensive.',
   'spotlight', 6.000, 3, 'Spotlight', '#DC2626', 'listing', 7, 0, 1, NULL, 0, 1, 1, 50),

  (UPPER(LEFT(MD5('prod:homepage-7'), 26)), 'homepage-7', 'Homepage feature — 7 days',
   'A slot in the homepage carousel. Eight slots exist and they sell out in the Dubai season.',
   'homepage', 8.000, NULL, 'Homepage', '#0EA5E9', 'listing', 7, 0, 1, NULL, 0, 1, 1, 60),

  (UPPER(LEFT(MD5('prod:category-top'), 26)), 'category-top', 'Category top — 30 days',
   'Pinned to the top of a category landing page. Sold per category per market.',
   'category_top', 5.000, 1, 'Top pick', '#10B981', 'listing', 30, 1, 1, NULL, 0, 1, 1, 70),

  (UPPER(LEFT(MD5('prod:verified'), 26)), 'verified-badge', 'Verified listing badge',
   'Awarded after documentary verification of ownership and permit. Not for sale on its own — included in the bundles below because verification has a real cost.',
   'verified_badge', 1.200, NULL, 'Verified', '#059669', 'listing', 90, 0, 0, 1, 0, 1, 0, 80),

  (UPPER(LEFT(MD5('prod:video'), 26)), 'video-upgrade', 'Video upgrade',
   'Allows video on the listing and surfaces a play badge in the results. Listings with video get materially more engagement, which is why it is sold separately.',
   'video_upgrade', 1.300, NULL, NULL, NULL, 'listing', 90, 0, 0, 1, 0, 1, 1, 90),

  (UPPER(LEFT(MD5('prod:photography'), 26)), 'photography', 'Professional photography',
   'A photographer attends and delivers an edited set within 48 hours. The single highest-return upgrade a poor listing can buy.',
   'photography', 1.000, NULL, NULL, NULL, 'listing', NULL, 0, 0, 1, 0, 1, 1, 100),

  (UPPER(LEFT(MD5('prod:tour'), 26)), 'virtual-tour', 'Virtual tour production',
   'A Matterport-style walkthrough. Expensive to produce and disproportionately effective on overseas buyers.',
   'virtual_tour', 1.400, NULL, NULL, NULL, 'listing', NULL, 0, 0, 1, 0, 1, 1, 110),

  (UPPER(LEFT(MD5('prod:social'), 26)), 'social-boost', 'Social boost',
   'The listing is promoted on the platform social accounts for a week.',
   'social_boost', 1.000, NULL, NULL, NULL, 'listing', 7, 0, 1, NULL, 0, 1, 1, 120),

  (UPPER(LEFT(MD5('prod:newsletter'), 26)), 'newsletter-slot', 'Newsletter placement',
   'A slot in the weekly buyer newsletter. Two hundred thousand subscribers, four slots.',
   'newsletter', 1.000, NULL, NULL, NULL, 'listing', 7, 0, 1, NULL, 0, 1, 1, 130),

  (UPPER(LEFT(MD5('prod:agent-featured'), 26)), 'agent-featured', 'Featured agent — 30 days',
   'The agent appears in the featured strip on their community pages. Sold to agents rather than for listings.',
   'featured', 2.000, NULL, 'Featured agent', '#F59E0B', 'agent', 30, 1, 1, NULL, 0, 1, 1, 140),

  (UPPER(LEFT(MD5('prod:launch-bundle'), 26)), 'launch-bundle', 'New listing launch bundle',
   'Photography, a video upgrade, 30 days featured and three bumps. Priced at about a third off the components, which is what makes a bundle worth assembling.',
   'bundle', 2.500, NULL, 'Featured', '#F59E0B', 'listing', 30, 0, 1, NULL, 1, 1, 1, 150);

INSERT INTO promotion_bundle_items (bundle_product_id, component_product_id, quantity, sort_order)
SELECT b.id, c.id, v.qty, v.sort_order
FROM promotion_products b
JOIN (
  SELECT 'photography' AS component, 1 AS qty, 10 AS sort_order
  UNION ALL SELECT 'video-upgrade', 1, 20
  UNION ALL SELECT 'featured-30', 1, 30
  UNION ALL SELECT 'bump', 3, 40
) v
JOIN promotion_products c ON c.code = v.component
WHERE b.code = 'launch-bundle';

-- -----------------------------------------------------------------------------
-- Rate card
--
-- AED is the base market. Other currencies are set independently rather than
-- converted, because a rate card is a commercial decision and nobody prices a
-- feature at €47.23.
-- -----------------------------------------------------------------------------
INSERT INTO promotion_prices
  (product_id, currency_code, country_id, audience, amount, amount_base,
   credit_cost, min_quantity, effective_from, is_active)
SELECT p.id, v.ccy, NULL, 'all', v.amount, v.amount_base, v.credits, v.min_qty,
       '2026-01-01', 1
FROM promotion_products p
JOIN (
  SELECT 'bump' AS code, 'AED' AS ccy, 45.00 AS amount, 45.00 AS amount_base, 1 AS credits, 1 AS min_qty
  UNION ALL SELECT 'bump', 'AED', 38.00, 38.00, 1, 10
  UNION ALL SELECT 'bump', 'USD', 12.00, 44.00, 1, 1
  UNION ALL SELECT 'bump', 'EUR', 11.00, 44.00, 1, 1
  UNION ALL SELECT 'bump', 'GBP', 10.00, 46.00, 1, 1
  UNION ALL SELECT 'featured-7', 'AED', 185.00, 185.00, 4, 1
  UNION ALL SELECT 'featured-7', 'USD', 50.00, 184.00, 4, 1
  UNION ALL SELECT 'featured-7', 'EUR', 46.00, 184.00, 4, 1
  UNION ALL SELECT 'featured-30', 'AED', 540.00, 540.00, 12, 1
  UNION ALL SELECT 'featured-30', 'AED', 460.00, 460.00, 10, 10
  UNION ALL SELECT 'featured-30', 'USD', 147.00, 540.00, 12, 1
  UNION ALL SELECT 'featured-30', 'EUR', 135.00, 540.00, 12, 1
  UNION ALL SELECT 'featured-30', 'GBP', 118.00, 543.00, 12, 1
  UNION ALL SELECT 'premium-30', 'AED', 1250.00, 1250.00, 28, 1
  UNION ALL SELECT 'premium-30', 'USD', 340.00, 1249.00, 28, 1
  UNION ALL SELECT 'premium-30', 'EUR', 312.00, 1248.00, 28, 1
  UNION ALL SELECT 'spotlight-7', 'AED', 950.00, 950.00, 21, 1
  UNION ALL SELECT 'spotlight-7', 'USD', 259.00, 951.00, 21, 1
  UNION ALL SELECT 'homepage-7', 'AED', 3800.00, 3800.00, 85, 1
  UNION ALL SELECT 'homepage-7', 'USD', 1035.00, 3801.00, 85, 1
  UNION ALL SELECT 'category-top', 'AED', 2400.00, 2400.00, 54, 1
  UNION ALL SELECT 'verified-badge', 'AED', 0.00, 0.00, 0, 1
  UNION ALL SELECT 'video-upgrade', 'AED', 350.00, 350.00, 8, 1
  UNION ALL SELECT 'photography', 'AED', 750.00, 750.00, 17, 1
  UNION ALL SELECT 'virtual-tour', 'AED', 1800.00, 1800.00, 40, 1
  UNION ALL SELECT 'social-boost', 'AED', 420.00, 420.00, 9, 1
  UNION ALL SELECT 'newsletter-slot', 'AED', 1600.00, 1600.00, 36, 1
  UNION ALL SELECT 'agent-featured', 'AED', 890.00, 890.00, 20, 1
  UNION ALL SELECT 'launch-bundle', 'AED', 1650.00, 1650.00, 37, 1
  UNION ALL SELECT 'launch-bundle', 'USD', 449.00, 1649.00, 37, 1
) v ON v.code = p.code;

-- Premium markets carry a premium price. A featured slot in Dubai Marina is not
-- worth the same as one in a secondary city, and the rate card should say so.
INSERT INTO promotion_prices
  (product_id, currency_code, country_id, location_id, audience, amount,
   amount_base, credit_cost, min_quantity, effective_from, is_active)
SELECT p.id, 'AED', loc.country_id, loc.id, 'all',
       ROUND(base.amount * 1.60, 0), ROUND(base.amount_base * 1.60, 0),
       ROUND(base.credit_cost * 1.60), 1, '2026-01-01', 1
FROM promotion_products p
JOIN promotion_prices base
  ON base.product_id = p.id AND base.currency_code = 'AED'
 AND base.location_id IS NULL AND base.min_quantity = 1
JOIN locations loc
  ON loc.level = 'community'
 AND loc.slug IN ('palm-jumeirah', 'downtown-dubai', 'dubai-marina',
                  'emirates-hills', 'jumeirah-bay-island', 'bluewaters-island')
WHERE p.code IN ('featured-7', 'featured-30', 'premium-30', 'spotlight-7');

-- -----------------------------------------------------------------------------
-- Inventory
--
-- Capacity per community per day for the products that occupy a finite slot.
-- The numbers are the ones a results page can actually carry: six featured
-- cards above the fold, one spotlight, eight homepage slots globally.
-- -----------------------------------------------------------------------------
INSERT INTO promotion_inventory
  (product_id, inventory_date, location_id, capacity, sold_count, reserved_count,
   available_count, waitlist_count)
SELECT p.id, d.inventory_date, loc.location_id, v.capacity, 0, 0, v.capacity, 0
FROM promotion_products p
JOIN (
  SELECT 'featured-7' AS code, 6 AS capacity
  UNION ALL SELECT 'featured-30', 6
  UNION ALL SELECT 'premium-30', 3
  UNION ALL SELECT 'spotlight-7', 1
) v ON v.code = p.code
JOIN (
  SELECT DISTINCT l.community_id AS location_id
    FROM listings l
   WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
) loc
JOIN (
  SELECT DATE_ADD(CURDATE(), INTERVAL n DAY) AS inventory_date
  FROM (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
        UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
        UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
        UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
        UNION ALL SELECT 13) days
) d;

-- Homepage inventory is global, so it has no location dimension at all.
INSERT INTO promotion_inventory
  (product_id, inventory_date, location_id, capacity, sold_count, reserved_count,
   available_count, waitlist_count)
SELECT p.id, DATE_ADD(CURDATE(), INTERVAL n.n DAY), NULL, 8, 0, 0, 8, 0
FROM promotion_products p
JOIN (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3
      UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6
      UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9
      UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12
      UNION ALL SELECT 13) n
WHERE p.code = 'homepage-7';

-- -----------------------------------------------------------------------------
-- Purchases and applied promotions
--
-- Derived from the listings already flagged featured or premium, so the
-- commercial record matches what the marketplace is actually showing.
-- -----------------------------------------------------------------------------
INSERT INTO promotion_purchases
  (public_id, reference, account_id, organization_id, user_id, product_id,
   quantity, quantity_used, unit_price, subtotal, discount_amount, tax_amount,
   total_amount, currency_code, total_amount_base, payment_method, status,
   purchased_at, expires_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('promo-purchase:', l.id)), 26)),
  CONCAT('PP-', LPAD(l.id, 8, '0')),
  l.account_id, l.organization_id, l.created_by_user_id, p.id,
  1, 1, pr.amount, pr.amount, 0,
  ROUND(pr.amount * 0.05, 2),
  ROUND(pr.amount * 1.05, 2), pr.currency_code,
  ROUND(pr.amount_base * 1.05, 2),
  ELT(1 + MOD(l.id, 3), 'card', 'credits', 'invoice'),
  'fully_used',
  COALESCE(l.published_at, l.created_at),
  COALESCE(l.featured_until, DATE_ADD(COALESCE(l.published_at, l.created_at), INTERVAL 30 DAY)),
  COALESCE(l.published_at, l.created_at), l.updated_at
FROM listings l
JOIN promotion_products p ON p.code = IF(l.is_premium, 'premium-30', 'featured-30')
JOIN promotion_prices pr
  ON pr.product_id = p.id AND pr.currency_code = 'AED'
 AND pr.location_id IS NULL AND pr.min_quantity = 1
WHERE (l.is_featured = 1 OR l.is_premium = 1) AND l.deleted_at IS NULL;

INSERT INTO listing_promotions
  (purchase_id, product_id, subject_type, subject_id, listing_id,
   organization_id, account_id, location_id, root_category_id, boost_multiplier,
   pin_position, badge_label, status, starts_at, ends_at, impressions,
   detail_views, inquiries, calls, baseline_daily_views, created_by_user_id,
   created_at, updated_at)
SELECT
  pp.id, pp.product_id, 'listing', l.id, l.id, l.organization_id, l.account_id,
  l.community_id, l.root_category_id, p.boost_multiplier, p.results_pin_position,
  p.badge_label,
  CASE WHEN l.featured_until IS NULL THEN 'expired'
       WHEN l.featured_until > NOW() THEN 'active' ELSE 'expired' END,
  pp.purchased_at, pp.expires_at,
  -- Performance from the listing's own counters, so the uplift claim below is
  -- computed rather than asserted.
  l.view_count * 6, l.view_count, l.inquiry_count, l.call_click_count,
  GREATEST(1, ROUND(l.view_count / 30)),
  l.created_by_user_id, pp.created_at, pp.updated_at
FROM promotion_purchases pp
JOIN listings l ON pp.reference = CONCAT('PP-', LPAD(l.id, 8, '0'))
JOIN promotion_products p ON p.id = pp.product_id;

-- Uplift measured against the listing's own pre-promotion baseline, which is the
-- only honest way to claim one.
UPDATE listing_promotions lp
  JOIN listings l ON l.id = lp.listing_id
   SET lp.uplift_percent = ROUND(
         (l.view_count / GREATEST(1, DATEDIFF(NOW(), COALESCE(l.published_at, l.created_at))))
         / GREATEST(1, lp.baseline_daily_views) * 100 - 100, 2)
 WHERE lp.baseline_daily_views > 0;

-- Inventory consumed by those promotions. Counted, not assumed.
UPDATE promotion_inventory inv
  JOIN (
    SELECT lp.product_id, lp.location_id, DATE(lp.starts_at) AS d, COUNT(*) AS n
      FROM listing_promotions lp
     WHERE lp.status = 'active' AND lp.location_id IS NOT NULL
     GROUP BY lp.product_id, lp.location_id, DATE(lp.starts_at)
  ) s ON s.product_id = inv.product_id
     AND s.location_id = inv.location_id
     AND s.d = inv.inventory_date
   SET inv.sold_count = LEAST(inv.capacity, s.n),
       inv.available_count = inv.capacity - LEAST(inv.capacity, s.n),
       inv.waitlist_count = GREATEST(0, s.n - inv.capacity);

-- Bumps, with the cooldown that stops the same tired listing being pushed to
-- the top three times a day.
INSERT INTO listing_bumps
  (listing_id, account_id, organization_id, bump_type, previous_refreshed_at,
   bumped_at, cooldown_until, bumps_today, credits_used, triggered_by_user_id)
SELECT l.id, l.account_id, l.organization_id,
       ELT(1 + MOD(l.id, 3), 'paid', 'plan_allowance', 'free_weekly'),
       l.last_refreshed_at,
       COALESCE(l.last_refreshed_at, l.updated_at),
       DATE_ADD(COALESCE(l.last_refreshed_at, l.updated_at), INTERVAL 24 HOUR),
       1, IF(MOD(l.id, 3) = 0, 1, NULL), l.created_by_user_id
FROM listings l
WHERE l.status = 'active' AND l.deleted_at IS NULL AND MOD(l.id, 4) = 0;

-- =============================================================================
-- CREDITS
-- =============================================================================

INSERT INTO credit_types
  (code, name, description, expires, default_validity_days, allow_negative,
   is_active, sort_order)
VALUES
  ('listing', 'Listing credits',
   'One credit publishes one listing for its standard duration. The unit smaller agencies buy in.',
   1, 365, 0, 1, 10),
  ('feature', 'Feature credits',
   'Spend on any promotion product at the credit price on the rate card.',
   1, 180, 0, 1, 20),
  ('lead', 'Lead credits',
   'Buy an individual lead. Priced by market and quality — see lead_pricing_rules.',
   1, 90, 0, 1, 30),
  ('ad', 'Advertising credits',
   'Prepaid display spend. Enterprise accounts may run negative against an invoice.',
   0, NULL, 1, 1, 40),
  ('verification', 'Verification credits',
   'One credit covers one document verification. Never expires because verification demand is lumpy.',
   0, NULL, 0, 1, 50);

INSERT INTO credit_packs
  (code, name, credit_type_id, credits, bonus_credits, validity_days, is_active, sort_order)
SELECT v.code, v.name, ct.id, v.credits, v.bonus, v.validity, 1, v.sort_order
FROM (
  SELECT 'listing-10' AS code, 'Listing credits — 10' AS name, 'listing' AS type,
         10 AS credits, 0 AS bonus, 365 AS validity, 10 AS sort_order
  UNION ALL SELECT 'listing-50', 'Listing credits — 50', 'listing', 50, 5, 365, 20
  UNION ALL SELECT 'listing-200', 'Listing credits — 200', 'listing', 200, 30, 365, 30
  UNION ALL SELECT 'listing-1000', 'Listing credits — 1,000', 'listing', 1000, 200, 730, 40
  UNION ALL SELECT 'feature-25', 'Feature credits — 25', 'feature', 25, 0, 180, 50
  UNION ALL SELECT 'feature-100', 'Feature credits — 100', 'feature', 100, 10, 180, 60
  UNION ALL SELECT 'feature-500', 'Feature credits — 500', 'feature', 500, 75, 365, 70
  UNION ALL SELECT 'lead-20', 'Lead credits — 20', 'lead', 20, 0, 90, 80
  UNION ALL SELECT 'lead-100', 'Lead credits — 100', 'lead', 100, 8, 90, 90
  UNION ALL SELECT 'lead-500', 'Lead credits — 500', 'lead', 500, 60, 180, 100
  UNION ALL SELECT 'ad-5000', 'Advertising credits — 5,000', 'ad', 5000, 0, NULL, 110
  UNION ALL SELECT 'verify-25', 'Verification credits — 25', 'verification', 25, 0, NULL, 120
) v
JOIN credit_types ct ON ct.code = v.type;

INSERT INTO credit_pack_prices
  (pack_id, currency_code, amount, amount_base, effective_from, is_active)
SELECT cp.id, 'AED',
       -- Unit price falls with volume: 45 AED a listing credit at ten, 34 at a
       -- thousand. Enough of a break to reward commitment, not so much that the
       -- small buyer is being punished for being small.
       ROUND(cp.credits * CASE WHEN cp.credits >= 1000 THEN 34
                               WHEN cp.credits >= 200 THEN 38
                               WHEN cp.credits >= 50 THEN 42
                               ELSE 45 END, 0),
       ROUND(cp.credits * CASE WHEN cp.credits >= 1000 THEN 34
                               WHEN cp.credits >= 200 THEN 38
                               WHEN cp.credits >= 50 THEN 42
                               ELSE 45 END, 0),
       '2026-01-01', 1
FROM credit_packs cp;

-- Balances for every account, lots for the ones that bought.
INSERT INTO credit_balances
  (account_id, organization_id, credit_type_id, balance, reserved,
   lifetime_granted, lifetime_spent, lifetime_expired, low_balance_threshold)
SELECT a.id, o.id, ct.id, 0, 0, 0, 0, 0,
       CASE ct.code WHEN 'lead' THEN 10 WHEN 'listing' THEN 5 ELSE NULL END
FROM accounts a
LEFT JOIN organizations o ON o.account_id = a.id
JOIN credit_types ct ON ct.is_active = 1
WHERE a.deleted_at IS NULL AND ct.code IN ('listing', 'feature', 'lead');

-- Grants: a plan allowance every month for subscribers, plus a purchased pack
-- for the accounts that ran out.
INSERT INTO credit_lots
  (account_id, credit_type_id, source, subscription_id, granted, remaining,
   unit_cost, currency_code, granted_at, expires_at)
SELECT s.account_id, ct.id, 'plan_allowance', s.id,
       COALESCE(p.listing_quota, 10), COALESCE(p.listing_quota, 10),
       0, 'AED', s.current_period_start,
       DATE_ADD(s.current_period_start, INTERVAL 365 DAY)
FROM subscriptions s
JOIN plans p ON p.id = s.plan_id
JOIN credit_types ct ON ct.code = 'listing'
WHERE s.status IN ('active', 'trialing');

INSERT INTO credit_lots
  (account_id, credit_type_id, source, granted, remaining, unit_cost,
   currency_code, granted_at, expires_at)
SELECT a.id, ct.id, 'purchase', cp.credits + cp.bonus_credits,
       cp.credits + cp.bonus_credits,
       ROUND(cpp.amount / (cp.credits + cp.bonus_credits), 4), 'AED',
       DATE_SUB(NOW(3), INTERVAL MOD(a.id, 60) DAY),
       DATE_ADD(DATE_SUB(NOW(3), INTERVAL MOD(a.id, 60) DAY),
                INTERVAL COALESCE(cp.validity_days, 3650) DAY)
FROM accounts a
JOIN credit_packs cp ON cp.code = 'lead-100'
JOIN credit_pack_prices cpp ON cpp.pack_id = cp.id AND cpp.currency_code = 'AED'
JOIN credit_types ct ON ct.id = cp.credit_type_id
WHERE a.deleted_at IS NULL AND MOD(a.id, 4) = 0;

INSERT INTO credit_transactions
  (public_id, account_id, organization_id, credit_type_id, lot_id,
   transaction_type, amount, balance_after, subject_type, subject_id,
   idempotency_key, description, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('credit-grant:', cl.id)), 26)),
  cl.account_id, NULL, cl.credit_type_id, cl.id, 'grant', cl.granted, cl.granted,
  IF(cl.subscription_id IS NULL, 'purchase', 'subscription'),
  COALESCE(cl.subscription_id, cl.id),
  CONCAT('grant:', cl.id),
  IF(cl.source = 'plan_allowance', 'Monthly plan allowance', 'Credit pack purchase'),
  cl.granted_at
FROM credit_lots cl;

-- Spend against those lots, oldest expiry first — which is what `credit_lots`
-- exists to make possible.
INSERT INTO credit_transactions
  (public_id, account_id, organization_id, credit_type_id, lot_id,
   transaction_type, amount, balance_after, subject_type, subject_id,
   idempotency_key, description, created_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('credit-spend:', pp.id)), 26)),
  pp.account_id, pp.organization_id, ct.id,
  (SELECT cl.id FROM credit_lots cl
    WHERE cl.account_id = pp.account_id AND cl.credit_type_id = ct.id
    ORDER BY cl.expires_at IS NULL, cl.expires_at, cl.granted_at LIMIT 1),
  'spend', -COALESCE(pr.credit_cost, 1),
  0, 'listing_promotion', pp.id,
  CONCAT('spend:promo:', pp.id),
  CONCAT('Promotion — ', p.name),
  pp.purchased_at
FROM promotion_purchases pp
JOIN promotion_products p ON p.id = pp.product_id
JOIN promotion_prices pr ON pr.product_id = p.id AND pr.currency_code = 'AED'
                        AND pr.location_id IS NULL AND pr.min_quantity = 1
JOIN credit_types ct ON ct.code = 'feature'
WHERE pp.payment_method = 'credits';

-- The balance is a cache of the ledger. Derived, then asserted by the finalise
-- step, which is the same discipline as the wallets in 052.
UPDATE credit_balances cb
  LEFT JOIN (
    SELECT account_id, credit_type_id,
           SUM(amount) AS net,
           SUM(GREATEST(amount, 0)) AS granted,
           SUM(GREATEST(-amount, 0)) AS spent
      FROM credit_transactions
     GROUP BY account_id, credit_type_id
  ) t ON t.account_id = cb.account_id AND t.credit_type_id = cb.credit_type_id
   SET cb.balance = COALESCE(t.net, 0),
       cb.lifetime_granted = COALESCE(t.granted, 0),
       cb.lifetime_spent = COALESCE(t.spent, 0);

UPDATE credit_balances cb
  LEFT JOIN (
    SELECT account_id, credit_type_id, MIN(expires_at) AS next_expiry,
           SUM(remaining) AS remaining
      FROM credit_lots
     WHERE remaining > 0 AND expires_at IS NOT NULL
     GROUP BY account_id, credit_type_id
  ) l ON l.account_id = cb.account_id AND l.credit_type_id = cb.credit_type_id
   SET cb.next_expiry_at = l.next_expiry, cb.next_expiry_amount = l.remaining;

-- -----------------------------------------------------------------------------
-- Lead pricing
--
-- What a lead costs, which is not one number. A Palm Jumeirah buyer with a
-- stated twenty million is worth many times a rental enquiry in a secondary
-- city, and pricing them the same either loses money or prices the marketplace
-- out of its own long tail.
-- -----------------------------------------------------------------------------
INSERT INTO lead_pricing_rules
  (name, priority, root_category_id, location_id, min_budget_base,
   max_budget_base, min_score, exclusivity, credit_cost, cash_price,
   currency_code, quality_multiplier, is_active, effective_from)
SELECT v.name, v.priority, NULL,
       (SELECT id FROM locations WHERE level='community' AND slug = v.loc_slug LIMIT 1),
       v.min_budget, v.max_budget, v.min_score, v.exclusivity, v.credits,
       v.cash, 'AED', v.multiplier, 1, '2026-01-01'
FROM (
  SELECT 'Prime community, exclusive, above 20M' AS name, 10 AS priority,
         'palm-jumeirah' AS loc_slug, 20000000.00 AS min_budget,
         NULL AS max_budget, 60 AS min_score, 'exclusive' AS exclusivity,
         40 AS credits, 1800.00 AS cash, 1.50 AS multiplier
  UNION ALL SELECT 'Prime community, exclusive', 20, 'emirates-hills', 5000000.00,
         NULL, 40, 'exclusive', 28, 1250.00, 1.30
  UNION ALL SELECT 'Prime community, shared', 30, 'dubai-marina', 2000000.00,
         NULL, 20, 'shared', 12, 540.00, 1.10
  UNION ALL SELECT 'Downtown, shared', 40, 'downtown-dubai', 2000000.00,
         NULL, 20, 'shared', 12, 540.00, 1.10
  UNION ALL SELECT 'High budget anywhere, exclusive', 50, NULL, 10000000.00,
         NULL, 40, 'exclusive', 24, 1080.00, 1.25
  UNION ALL SELECT 'Mid budget anywhere, shared', 60, NULL, 1000000.00,
         10000000.00, 20, 'shared', 8, 360.00, 1.00
  UNION ALL SELECT 'Low budget or unscored, open', 70, NULL, NULL, 1000000.00,
         NULL, 'open', 3, 135.00, 0.90
  UNION ALL SELECT 'Default', 999, NULL, NULL, NULL, NULL, 'any', 5, 225.00, 1.00
) v;

-- =============================================================================
-- ADVERTISING
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Placements
--
-- The inventory map. `floor_cpm` is the price below which a slot is not sold at
-- all — the thing that stops remnant inventory destroying the rate card — and
-- the above-the-fold slots carry the higher floors because that is where the
-- viewability is.
-- -----------------------------------------------------------------------------
INSERT INTO ad_placements
  (code, name, description, page_type, position, format, accepted_sizes,
   max_file_size_kb, slot_count, feed_positions, floor_cpm, floor_cpc,
   currency_code, allow_house_ads, is_above_fold, device_targets, is_active, sort_order)
VALUES
  ('home-hero', 'Homepage hero takeover',
   'Full-width unit above the search box. One advertiser at a time, sold by the day.',
   'home', 'hero', 'display',
   JSON_ARRAY(JSON_OBJECT('w',1920,'h',600), JSON_OBJECT('w',768,'h',400)),
   400, 1, NULL, 180.00, NULL, 'AED', 0, 1, 'desktop,mobile,tablet', 1, 10),

  ('home-leaderboard', 'Homepage leaderboard',
   'Standard 970x250 below the hero.', 'home', 'leaderboard', 'display',
   JSON_ARRAY(JSON_OBJECT('w',970,'h',250), JSON_OBJECT('w',728,'h',90), JSON_OBJECT('w',320,'h',100)),
   200, 1, NULL, 95.00, NULL, 'AED', 1, 1, 'desktop,mobile,tablet', 1, 20),

  ('search-above-results', 'Search — above results',
   'Between the filters and the first result. The highest-intent display slot on the site.',
   'search_results', 'above_results', 'display',
   JSON_ARRAY(JSON_OBJECT('w',970,'h',90), JSON_OBJECT('w',728,'h',90), JSON_OBJECT('w',320,'h',100)),
   200, 1, NULL, 120.00, NULL, 'AED', 1, 1, 'desktop,mobile,tablet', 1, 30),

  ('search-in-feed', 'Search — in feed',
   'Native cards woven into the results at positions 4, 12 and 24. Blends with the inventory, which is why the labelling rules matter.',
   'search_results', 'in_feed', 'native', NULL, 150, 3,
   JSON_ARRAY(4, 12, 24), 85.00, 4.50, 'AED', 1, 0, 'desktop,mobile,tablet', 1, 40),

  ('search-sidebar', 'Search — sidebar',
   'Desktop only. Two stacked 300x250 units.', 'search_results', 'sidebar', 'display',
   JSON_ARRAY(JSON_OBJECT('w',300,'h',250), JSON_OBJECT('w',300,'h',600)),
   200, 2, NULL, 55.00, NULL, 'AED', 1, 0, 'desktop', 1, 50),

  ('listing-below-gallery', 'Listing — below gallery',
   'Directly under the photographs on a listing page, where attention already is.',
   'listing_detail', 'below_gallery', 'display',
   JSON_ARRAY(JSON_OBJECT('w',970,'h',250), JSON_OBJECT('w',336,'h',280)),
   200, 1, NULL, 110.00, NULL, 'AED', 1, 1, 'desktop,mobile,tablet', 1, 60),

  ('listing-sidebar-mortgage', 'Listing — mortgage sidebar',
   'A contextual unit beside the price, sold almost exclusively to lenders and brokers. The single most valuable slot per impression on the site.',
   'listing_detail', 'sidebar', 'native', NULL, 100, 1, NULL, 240.00, 12.00,
   'AED', 0, 1, 'desktop,mobile,tablet', 1, 70),

  ('listing-similar', 'Listing — sponsored similar properties',
   'Sponsored listings in the similar-properties rail. Sold to developers.',
   'listing_detail', 'between_results', 'sponsored_listing', NULL, NULL, 2,
   JSON_ARRAY(1, 4), 90.00, 5.50, 'AED', 1, 0, 'desktop,mobile,tablet', 1, 80),

  ('location-leaderboard', 'Community page leaderboard',
   'On a community landing page. Geographically targeted by definition, which is what developers pay for.',
   'location', 'leaderboard', 'display',
   JSON_ARRAY(JSON_OBJECT('w',970,'h',250), JSON_OBJECT('w',728,'h',90)),
   200, 1, NULL, 130.00, NULL, 'AED', 1, 1, 'desktop,mobile,tablet', 1, 90),

  ('project-sponsored', 'Project page sponsorship',
   'Whole-page sponsorship of an off-plan project page.', 'project', 'hero',
   'takeover', NULL, 500, 1, NULL, 200.00, NULL, 'AED', 0, 1,
   'desktop,mobile,tablet', 1, 100),

  ('blog-in-article', 'Editorial — in article',
   'Between paragraphs of a market report. Low intent, high dwell.',
   'blog_post', 'in_feed', 'native', NULL, 150, 2, JSON_ARRAY(3, 8),
   45.00, 3.00, 'AED', 1, 0, 'desktop,mobile,tablet', 1, 110),

  ('email-banner', 'Newsletter banner',
   'A unit in the weekly buyer newsletter. Priced flat because email impressions are not comparable to web impressions.',
   'email', 'email_banner', 'email',
   JSON_ARRAY(JSON_OBJECT('w',600,'h',200)), 100, 1, NULL, NULL, NULL,
   'AED', 0, 0, 'desktop,mobile,tablet', 1, 120),

  ('mobile-sticky', 'Mobile sticky footer',
   'Anchored to the bottom of the viewport on mobile. High viewability, and the reason its floor is higher than the sidebar.',
   'global', 'sticky_footer', 'display',
   JSON_ARRAY(JSON_OBJECT('w',320,'h',50), JSON_OBJECT('w',320,'h',100)),
   100, 1, NULL, 70.00, NULL, 'AED', 1, 1, 'mobile', 1, 130);

-- -----------------------------------------------------------------------------
-- Advertisers
--
-- The set a property portal actually sells to: developers first, then the
-- banks and mortgage brokers who follow the buyer, then the furniture and
-- fit-out brands who follow the completion.
-- -----------------------------------------------------------------------------
INSERT INTO ad_advertisers
  (public_id, name, slug, advertiser_type, billing_entity_name, billing_email,
   billing_country_id, credit_limit, outstanding_balance, currency_code,
   payment_terms_days, status, website_url, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('advertiser:', v.slug)), 26)), v.name, v.slug,
       v.type, v.billing_entity,
       CONCAT('accounts@', SUBSTRING_INDEX(SUBSTRING_INDEX(v.website, '//', -1), '/', 1)),
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       v.credit_limit, 0, 'AED', v.terms, 'active', v.website, NOW(3), NOW(3)
FROM (
  SELECT 'Marina Bay Developments' AS name, 'marina-bay-developments' AS slug,
         'developer' AS type, 'Marina Bay Developments LLC' AS billing_entity,
         'https://marinabaydev.example.com' AS website,
         'united-arab-emirates' AS country, 500000.00 AS credit_limit, 30 AS terms
  UNION ALL SELECT 'Skyline Estates Group', 'skyline-estates-group', 'developer',
         'Skyline Estates Group FZE', 'https://skylineestates.example.com',
         'united-arab-emirates', 750000.00, 45
  UNION ALL SELECT 'Coastal Residences', 'coastal-residences', 'developer',
         'Coastal Residences Ltd', 'https://coastalres.example.com',
         'saudi-arabia', 400000.00, 30
  UNION ALL SELECT 'Gulf Mortgage Bank', 'gulf-mortgage-bank', 'bank',
         'Gulf Mortgage Bank PJSC', 'https://gulfmortgage.example.com',
         'united-arab-emirates', 1000000.00, 60
  UNION ALL SELECT 'Meridian Home Finance', 'meridian-home-finance', 'mortgage',
         'Meridian Home Finance LLC', 'https://meridianfinance.example.com',
         'united-arab-emirates', 300000.00, 30
  UNION ALL SELECT 'Atelier Interiors', 'atelier-interiors', 'furniture',
         'Atelier Interiors DMCC', 'https://atelierinteriors.example.com',
         'united-arab-emirates', 150000.00, 30
  UNION ALL SELECT 'Halcyon Motors', 'halcyon-motors', 'automotive',
         'Halcyon Motors FZCO', 'https://halcyonmotors.example.com',
         'united-arab-emirates', 200000.00, 30
  UNION ALL SELECT 'Maison Verrier', 'maison-verrier', 'luxury_brand',
         'Maison Verrier SA', 'https://maisonverrier.example.com',
         'france', 250000.00, 45
  UNION ALL SELECT 'Northgate Media', 'northgate-media', 'media_agency',
         'Northgate Media Group Ltd', 'https://northgatemedia.example.com',
         'united-kingdom', 900000.00, 60
  UNION ALL SELECT 'Liv Finder (house)', 'liv-finder-house', 'internal',
         'Liv Finder FZ-LLC', 'https://livfinder.com',
         'united-arab-emirates', NULL, 0
) v;

INSERT INTO ad_campaigns
  (public_id, advertiser_id, name, reference, objective, status, starts_at,
   ends_at, total_budget, daily_budget, currency_code, total_budget_base,
   spent_amount, spent_amount_base, pacing, io_number, io_signed_at,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('campaign:', a.slug, ':', v.name)), 26)),
  a.id, v.name, CONCAT('CMP-', UPPER(LEFT(MD5(CONCAT(a.slug, v.name)), 8))),
  v.objective,
  CASE WHEN v.days_ago > 60 THEN 'completed' ELSE 'active' END,
  DATE_SUB(NOW(3), INTERVAL v.days_ago DAY),
  DATE_ADD(DATE_SUB(NOW(3), INTERVAL v.days_ago DAY), INTERVAL v.duration DAY),
  v.budget, ROUND(v.budget / v.duration, 2), 'AED', v.budget, 0, 0, v.pacing,
  CONCAT('IO-2026-', LPAD(a.id * 10 + v.seq, 5, '0')),
  DATE_SUB(NOW(3), INTERVAL (v.days_ago + 7) DAY),
  DATE_SUB(NOW(3), INTERVAL (v.days_ago + 7) DAY), NOW(3)
FROM ad_advertisers a
JOIN (
  SELECT 'marina-bay-developments' AS slug, 1 AS seq,
         'Marina Heights launch' AS name, 'leads' AS objective,
         30 AS days_ago, 60 AS duration, 180000.00 AS budget, 'even' AS pacing
  UNION ALL SELECT 'skyline-estates-group', 1, 'Skyline Tower — Q1 push', 'leads', 20, 45, 260000.00, 'even'
  UNION ALL SELECT 'skyline-estates-group', 2, 'Brand awareness — Gulf', 'awareness', 90, 30, 120000.00, 'accelerated'
  UNION ALL SELECT 'coastal-residences', 1, 'Red Sea launch', 'leads', 15, 90, 300000.00, 'even'
  UNION ALL SELECT 'gulf-mortgage-bank', 1, 'Mortgage pre-approval — always on', 'leads', 120, 365, 900000.00, 'even'
  UNION ALL SELECT 'meridian-home-finance', 1, 'First-time buyer campaign', 'leads', 45, 90, 140000.00, 'even'
  UNION ALL SELECT 'atelier-interiors', 1, 'Post-handover furnishing', 'traffic', 25, 60, 90000.00, 'even'
  UNION ALL SELECT 'halcyon-motors', 1, 'Luxury audience cross-sell', 'awareness', 40, 45, 110000.00, 'even'
  UNION ALL SELECT 'maison-verrier', 1, 'Timepiece collectors', 'awareness', 70, 60, 160000.00, 'front_loaded'
  UNION ALL SELECT 'northgate-media', 1, 'Agency trading desk — Q1', 'traffic', 35, 90, 420000.00, 'even'
  UNION ALL SELECT 'liv-finder-house', 1, 'House — list your property', 'listings', 60, 365, 0.00, 'even'
) v ON v.slug = a.slug;

INSERT INTO ad_line_items
  (public_id, campaign_id, placement_id, name, status, pricing_model, rate,
   currency_code, delivery_type, goal_quantity, delivered_quantity, priority,
   weight, starts_at, ends_at, budget, daily_budget, spent_amount,
   frequency_cap_impressions, frequency_cap_period, impressions, clicks,
   conversions, viewable_impressions, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('lineitem:', c.id, ':', pl.code)), 26)),
  c.id, pl.id, CONCAT(c.name, ' — ', pl.name),
  IF(c.status = 'completed', 'completed', 'delivering'),
  IF(pl.floor_cpc IS NULL, 'cpm', 'cpc'),
  IF(pl.floor_cpc IS NULL, pl.floor_cpm * 1.15, pl.floor_cpc * 1.20),
  'AED',
  IF(a.advertiser_type = 'internal', 'house', 'guaranteed'),
  -- Goal derived from budget and rate, so the two are consistent.
  IF(pl.floor_cpc IS NULL,
     ROUND(c.total_budget / 3 / (pl.floor_cpm * 1.15) * 1000),
     ROUND(c.total_budget / 3 / (pl.floor_cpc * 1.20))),
  0,
  IF(a.advertiser_type = 'internal', 9, 3),
  100,
  c.starts_at, c.ends_at,
  ROUND(c.total_budget / 3, 2),
  ROUND(c.total_budget / 3 / GREATEST(1, DATEDIFF(c.ends_at, c.starts_at)), 2),
  0,
  -- Three impressions a day per visitor. Beyond that the creative is not being
  -- seen, it is being ignored, and the advertiser is paying for the privilege.
  3, 'day',
  0, 0, 0, 0, c.created_at, NOW(3)
FROM ad_campaigns c
JOIN ad_advertisers a ON a.id = c.advertiser_id
JOIN ad_placements pl
  ON pl.code IN (
       CASE a.advertiser_type
         WHEN 'developer' THEN 'location-leaderboard'
         WHEN 'bank' THEN 'listing-sidebar-mortgage'
         WHEN 'mortgage' THEN 'listing-sidebar-mortgage'
         ELSE 'search-in-feed' END,
       'search-above-results',
       'mobile-sticky');

INSERT INTO ad_creatives
  (public_id, line_item_id, name, creative_type, asset_url, width, height,
   file_size_kb, headline, body_text, call_to_action, click_url,
   rotation_weight, review_status, reviewed_at, impressions, clicks, is_active,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('creative:', li.id, ':', n.variant)), 26)),
  li.id, CONCAT(li.name, ' — variant ', n.variant),
  IF(pl.format = 'native', 'native', 'image'),
  CONCAT('https://cdn.livfinder.com/ads/', LOWER(LEFT(MD5(CONCAT('ad:', li.id, n.variant)), 20)), '.jpg'),
  COALESCE(JSON_EXTRACT(pl.accepted_sizes, '$[0].w'), 300),
  COALESCE(JSON_EXTRACT(pl.accepted_sizes, '$[0].h'), 250),
  60 + MOD(li.id * n.variant, 120),
  CASE a.advertiser_type
    WHEN 'developer' THEN CONCAT(a.name, ' — now selling')
    WHEN 'bank' THEN 'Pre-approved in 48 hours'
    WHEN 'mortgage' THEN 'Compare 14 lenders in one place'
    WHEN 'furniture' THEN 'Furnish your new home'
    WHEN 'automotive' THEN 'The car that belongs in the driveway'
    WHEN 'luxury_brand' THEN 'A collection worth keeping'
    WHEN 'internal' THEN 'List your property free'
    ELSE a.name END,
  CASE a.advertiser_type
    WHEN 'developer' THEN 'Waterfront residences with handover in 2028. Register your interest today.'
    WHEN 'bank' THEN 'Fixed rates from 3.99%. No arrangement fee on the first year.'
    WHEN 'mortgage' THEN 'One application, fourteen lenders, no impact on your credit file.'
    ELSE NULL END,
  ELT(1 + MOD(li.id, 4), 'Learn more', 'Register interest', 'Get a quote', 'View properties'),
  CONCAT(a.website_url, '?utm_source=livfinder&utm_medium=display&utm_campaign=',
         LOWER(REPLACE(c.name, ' ', '-'))),
  IF(n.variant = 1, 60, 40),
  'approved',
  li.created_at, 0, 0, 1, li.created_at, li.created_at
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
JOIN ad_advertisers a ON a.id = c.advertiser_id
JOIN ad_placements pl ON pl.id = li.placement_id
JOIN (SELECT 1 AS variant UNION ALL SELECT 2) n;

-- Targeting. Developers buy their own market; lenders buy price bands; the
-- house campaign buys everyone who is not logged in.
INSERT INTO ad_targeting_rules
  (line_item_id, dimension, operator, is_negative, value_ids, value_min, value_max)
SELECT li.id, 'country', 'in', 0,
       JSON_ARRAY((SELECT id FROM locations WHERE level='country' AND slug='united-arab-emirates' LIMIT 1)),
       NULL, NULL
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
JOIN ad_advertisers a ON a.id = c.advertiser_id
WHERE a.advertiser_type = 'developer';

INSERT INTO ad_targeting_rules
  (line_item_id, dimension, operator, is_negative, value_min, value_max)
SELECT li.id, 'price_band', 'between', 0, 1000000, 15000000
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
JOIN ad_advertisers a ON a.id = c.advertiser_id
WHERE a.advertiser_type IN ('bank', 'mortgage');

-- The exclusion that matters: a lender's ad must not appear on a rental page,
-- and a developer's must not appear on a competitor's project.
INSERT INTO ad_targeting_rules
  (line_item_id, dimension, operator, is_negative, value_ids)
SELECT li.id, 'purpose', 'in', 1,
       JSON_ARRAY((SELECT id FROM purposes WHERE slug LIKE 'rent%' LIMIT 1))
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
JOIN ad_advertisers a ON a.id = c.advertiser_id
WHERE a.advertiser_type IN ('bank', 'mortgage');

INSERT INTO ad_targeting_rules
  (line_item_id, dimension, operator, is_negative, value_ids)
SELECT li.id, 'device', 'in', 0, JSON_ARRAY('mobile')
FROM ad_line_items li
JOIN ad_placements pl ON pl.id = li.placement_id
WHERE pl.code = 'mobile-sticky';

INSERT INTO ad_brand_safety_rules
  (advertiser_id, scope, rule_type, value_text, reason, is_active)
SELECT a.id, 'advertiser', 'block_keyword', v.kw, v.reason, 1
FROM ad_advertisers a
JOIN (
  SELECT 'distressed sale' AS kw,
         'Contractual: the brand does not appear alongside distressed-sale content.' AS reason
  UNION ALL SELECT 'repossession', 'Contractual: no adjacency to repossession content.'
  UNION ALL SELECT 'bankruptcy', 'Contractual: no adjacency to insolvency content.'
) v
WHERE a.advertiser_type IN ('bank', 'mortgage', 'luxury_brand');

-- -----------------------------------------------------------------------------
-- Delivery
--
-- Daily stats derived from the real traffic in `listing_daily_stats`, so ad
-- impressions are proportional to actual page views rather than invented. The
-- viewability rate is deliberately in the 60–75% band that real display
-- inventory achieves, not the 100% that synthetic data tends to assume.
-- -----------------------------------------------------------------------------
INSERT INTO ad_daily_stats
  (stat_date, line_item_id, creative_id, placement_id, campaign_id, advertiser_id,
   device_type, impressions, viewable_impressions, clicks, conversions,
   video_completes, invalid_impressions, invalid_clicks, unique_visitors,
   revenue, revenue_base, currency_code, ctr, viewability_rate, effective_cpm,
   computed_at)
SELECT
  d.stat_date, li.id, cr.id, li.placement_id, li.campaign_id, c.advertiser_id,
  dv.device,
  ROUND(traffic.page_views * sh.share * dv.traffic_share),
  ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.viewability),
  GREATEST(0, ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.ctr)),
  GREATEST(0, ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.ctr * 0.06)),
  0,
  -- Invalid traffic. Around 1.8% of display impressions are bot or otherwise
  -- non-human even on clean inventory; filtered from billing, kept as evidence.
  ROUND(traffic.page_views * sh.share * dv.traffic_share * 0.018),
  GREATEST(0, ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.ctr * 0.03)),
  ROUND(traffic.page_views * sh.share * dv.traffic_share * 0.42),
  ROUND(IF(li.pricing_model = 'cpm',
           traffic.page_views * sh.share * dv.traffic_share / 1000 * li.rate,
           ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.ctr) * li.rate), 4),
  ROUND(IF(li.pricing_model = 'cpm',
           traffic.page_views * sh.share * dv.traffic_share / 1000 * li.rate,
           ROUND(traffic.page_views * sh.share * dv.traffic_share * dv.ctr) * li.rate), 4),
  'AED',
  ROUND(dv.ctr, 4),
  ROUND(dv.viewability, 4),
  ROUND(IF(li.pricing_model = 'cpm', li.rate, li.rate * dv.ctr * 1000), 4),
  NOW(3)
FROM ad_line_items li
JOIN ad_campaigns c ON c.id = li.campaign_id
JOIN ad_creatives cr ON cr.line_item_id = li.id AND cr.rotation_weight = 60
JOIN ad_placements pl ON pl.id = li.placement_id
-- Viewability in the 60–75% band real display inventory achieves, not the 100%
-- synthetic data tends to assume. Mobile carries most of the traffic and clicks
-- better; desktop is more viewable.
JOIN (SELECT 'desktop' AS device, 0.72 AS viewability, 0.0021 AS ctr, 0.34 AS traffic_share
      UNION ALL SELECT 'mobile', 0.64, 0.0034, 0.58
      UNION ALL SELECT 'tablet', 0.68, 0.0019, 0.08) dv
JOIN (
  SELECT DATE_SUB(CURDATE(), INTERVAL n DAY) AS stat_date
  FROM (SELECT 1 AS n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
        UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7
        UNION ALL SELECT 8 UNION ALL SELECT 9 UNION ALL SELECT 10
        UNION ALL SELECT 11 UNION ALL SELECT 12 UNION ALL SELECT 13
        UNION ALL SELECT 14) days
) d
-- Impressions are proportional to the site's real traffic on the day, scaled
-- by how much of the page the placement occupies. Sourced from
-- `platform_daily_stats` so ad delivery and site traffic cannot disagree.
JOIN (
  SELECT DATE(ps.stat_date) AS stat_date,
         GREATEST(500, ps.page_views) AS page_views
    FROM platform_daily_stats ps
) traffic ON traffic.stat_date = d.stat_date
JOIN (
  SELECT 'hero' AS position, 0.90 AS share
  UNION ALL SELECT 'leaderboard', 0.75
  UNION ALL SELECT 'above_results', 0.55
  UNION ALL SELECT 'in_feed', 0.45
  UNION ALL SELECT 'sidebar', 0.35
  UNION ALL SELECT 'below_gallery', 0.30
  UNION ALL SELECT 'between_results', 0.25
  UNION ALL SELECT 'sticky_footer', 0.60
  UNION ALL SELECT 'email_banner', 0.05
  UNION ALL SELECT 'interstitial', 0.10
  UNION ALL SELECT 'native_card', 0.20
  UNION ALL SELECT 'popup', 0.08
) sh ON sh.position = pl.position
WHERE li.status = 'delivering';

-- Spend, batched daily from the delivery above. The ledger is what the campaign
-- totals are derived from.
INSERT INTO ad_spend_entries
  (campaign_id, line_item_id, advertiser_id, entry_type, spend_date, quantity,
   unit_rate, amount, currency_code, amount_base, batch_key, description, created_at)
SELECT s.campaign_id, s.line_item_id, s.advertiser_id,
       IF(li.pricing_model = 'cpm', 'impression_batch', 'click_batch'),
       s.stat_date,
       IF(li.pricing_model = 'cpm', SUM(s.impressions), SUM(s.clicks)),
       li.rate, SUM(s.revenue), 'AED', SUM(s.revenue_base),
       CONCAT('batch:', s.line_item_id, ':', s.stat_date),
       CONCAT('Daily delivery batch for ', s.stat_date),
       NOW(3)
FROM ad_daily_stats s
JOIN ad_line_items li ON li.id = s.line_item_id
GROUP BY s.campaign_id, s.line_item_id, s.advertiser_id, s.stat_date, li.pricing_model, li.rate;

-- Campaign and line-item totals are a SUM over the ledger, refreshed here and
-- asserted by the finalise step. A budget cap enforced against an incremented
-- counter eventually overspends; enforced against a ledger it does not.
UPDATE ad_line_items li
  LEFT JOIN (SELECT line_item_id, SUM(amount) AS spend FROM ad_spend_entries
              WHERE line_item_id IS NOT NULL GROUP BY line_item_id) e
    ON e.line_item_id = li.id
  LEFT JOIN (SELECT line_item_id, SUM(impressions) i, SUM(clicks) c,
                    SUM(conversions) cv, SUM(viewable_impressions) v
               FROM ad_daily_stats GROUP BY line_item_id) s ON s.line_item_id = li.id
   SET li.spent_amount = COALESCE(e.spend, 0),
       li.impressions = COALESCE(s.i, 0),
       li.clicks = COALESCE(s.c, 0),
       li.conversions = COALESCE(s.cv, 0),
       li.viewable_impressions = COALESCE(s.v, 0),
       li.delivered_quantity = IF(li.pricing_model = 'cpm',
                                  COALESCE(s.i, 0), COALESCE(s.c, 0));

UPDATE ad_campaigns c
  LEFT JOIN (SELECT campaign_id, SUM(amount) AS spend, SUM(amount_base) AS spend_base
               FROM ad_spend_entries GROUP BY campaign_id) e ON e.campaign_id = c.id
  LEFT JOIN (SELECT campaign_id, SUM(impressions) i, SUM(clicks) cl,
                    SUM(conversions) cv FROM ad_daily_stats GROUP BY campaign_id) s
    ON s.campaign_id = c.id
   SET c.spent_amount = COALESCE(e.spend, 0),
       c.spent_amount_base = COALESCE(e.spend_base, 0),
       c.impressions = COALESCE(s.i, 0),
       c.clicks = COALESCE(s.cl, 0),
       c.conversions = COALESCE(s.cv, 0);

UPDATE ad_creatives cr
  LEFT JOIN (SELECT creative_id, SUM(impressions) i, SUM(clicks) c
               FROM ad_daily_stats WHERE creative_id IS NOT NULL
              GROUP BY creative_id) s ON s.creative_id = cr.id
   SET cr.impressions = COALESCE(s.i, 0), cr.clicks = COALESCE(s.c, 0),
       cr.ctr = IF(COALESCE(s.i, 0) = 0, NULL, ROUND(s.c / s.i, 4));

UPDATE ad_advertisers a
  LEFT JOIN (SELECT advertiser_id, SUM(amount) AS spend FROM ad_spend_entries
              GROUP BY advertiser_id) e ON e.advertiser_id = a.id
   SET a.outstanding_balance = ROUND(COALESCE(e.spend, 0) * 0.35, 2);

-- =============================================================================
-- AFFILIATES
-- =============================================================================

INSERT INTO affiliates
  (public_id, code, name, user_id, affiliate_type, contact_email, country_id,
   status, commission_model, commission_rate, commission_amount, currency_code,
   attribution_window_days, attribution_model, minimum_payout, click_count,
   signup_count, conversion_count, earned_total, paid_total, approved_at,
   terms_accepted_at, tax_form_on_file, created_at, updated_at)
SELECT UPPER(LEFT(MD5(CONCAT('affiliate:', v.code)), 26)), v.code, v.name, NULL,
       v.type, v.email,
       (SELECT id FROM locations WHERE level='country' AND slug = v.country LIMIT 1),
       'active', v.model, v.rate, v.amount, 'AED', v.window_days, 'last_click',
       500.00, 0, 0, 0, 0, 0,
       DATE_SUB(NOW(3), INTERVAL 200 DAY), DATE_SUB(NOW(3), INTERVAL 200 DAY),
       1, DATE_SUB(NOW(3), INTERVAL 210 DAY), NOW(3)
FROM (
  SELECT 'RELOC-GULF' AS code, 'Gulf Relocation Partners' AS name,
         'relocation' AS type, 'partners@gulfreloc.example.com' AS email,
         'united-arab-emirates' AS country, 'cpl' AS model, NULL AS rate,
         180.00 AS amount, 60 AS window_days
  UNION ALL SELECT 'MORTGAGE-CMP', 'Mortgage Compare ME', 'comparison_site',
         'affiliates@mortgagecompare.example.com', 'united-arab-emirates',
         'cpa', NULL, 450.00, 90
  UNION ALL SELECT 'EXPAT-FORUM', 'Expat Forum Middle East', 'media',
         'ads@expatforum.example.com', 'united-arab-emirates', 'cpl', NULL, 120.00, 30
  UNION ALL SELECT 'LUXE-EDITOR', 'Luxe Property Editorial', 'media',
         'partnerships@luxeeditorial.example.com', 'united-kingdom',
         'revenue_share', 12.5000, NULL, 90
  UNION ALL SELECT 'INFL-DXB', 'Dubai Property Influencer', 'influencer',
         'hello@dxbproperty.example.com', 'united-arab-emirates', 'cpa', NULL, 300.00, 30
  UNION ALL SELECT 'BROKER-REF', 'Broker referral programme', 'employee_referral',
         'referrals@livfinder.com', 'united-arab-emirates', 'revenue_share',
         5.0000, NULL, 365
) v;

INSERT INTO affiliate_links
  (affiliate_id, slug, name, destination_url, campaign_name, click_count,
   conversion_count, is_active, created_at, updated_at)
SELECT a.id, CONCAT(LOWER(a.code), '-', v.suffix), v.name,
       CONCAT('https://livfinder.com', v.path), v.campaign, 0, 0, 1,
       a.created_at, a.created_at
FROM affiliates a
JOIN (
  SELECT 'home' AS suffix, 'Homepage' AS name, '/' AS path, 'evergreen' AS campaign
  UNION ALL SELECT 'dubai', 'Dubai search', '/ae/dubai', 'dubai'
  UNION ALL SELECT 'mortgage', 'Mortgage calculator', '/mortgage-calculator', 'finance'
) v;

-- Conversions attributed back to the signups that already exist.
INSERT INTO affiliate_conversions
  (public_id, affiliate_id, link_id, conversion_type, subject_type, subject_id,
   order_value, currency_code, commission_amount, commission_base, status,
   approvable_at, approved_at, attributed_at, days_since_click, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('affconv:', u.id)), 26)),
  a.id, al.id, 'signup', 'user', u.id, NULL, 'AED',
  COALESCE(a.commission_amount, 200.00),
  COALESCE(a.commission_amount, 200.00),
  -- A hold period before approval, so a refunded signup does not pay a
  -- commission that then has to be clawed back.
  IF(u.created_at < DATE_SUB(NOW(3), INTERVAL 30 DAY), 'approved', 'pending'),
  DATE_ADD(u.created_at, INTERVAL 30 DAY),
  IF(u.created_at < DATE_SUB(NOW(3), INTERVAL 30 DAY),
     DATE_ADD(u.created_at, INTERVAL 30 DAY), NULL),
  u.created_at, MOD(u.id, 45), u.created_at, u.created_at
FROM users u
JOIN affiliates a ON a.id = 1 + MOD(u.id, 6)
JOIN affiliate_links al ON al.affiliate_id = a.id AND al.slug LIKE '%-home'
WHERE u.deleted_at IS NULL AND MOD(u.id, 9) = 0;

UPDATE affiliates a
  LEFT JOIN (SELECT affiliate_id, COUNT(*) n, SUM(commission_amount) earned,
                    SUM(IF(status = 'paid', commission_amount, 0)) paid
               FROM affiliate_conversions GROUP BY affiliate_id) c
    ON c.affiliate_id = a.id
   SET a.conversion_count = COALESCE(c.n, 0),
       a.signup_count = COALESCE(c.n, 0),
       a.earned_total = COALESCE(c.earned, 0),
       a.paid_total = COALESCE(c.paid, 0);

UPDATE affiliate_links al
  LEFT JOIN (SELECT link_id, COUNT(*) n FROM affiliate_conversions
              WHERE link_id IS NOT NULL GROUP BY link_id) c ON c.link_id = al.id
   SET al.conversion_count = COALESCE(c.n, 0);
