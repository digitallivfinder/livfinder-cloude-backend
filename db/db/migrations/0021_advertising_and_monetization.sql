-- =============================================================================
-- Liv Finder — 0021 · Advertising, promotions and credits
-- =============================================================================
-- A marketplace makes money in four ways, and this migration models all four
-- because a schema that only knows about subscriptions caps the business at the
-- first one:
--
--   1. SUBSCRIPTIONS — recurring plan fees. Already in 0009.
--   2. PROMOTIONS    — paying to make one listing more visible than another:
--                      featured, premium, spotlight, homepage, bump-to-top.
--                      This is the largest revenue line on every property
--                      portal in the world, and it is inventory: a "featured in
--                      Dubai Marina" slot is finite, and selling the eleventh
--                      of ten is the fastest way to lose a client.
--   3. ADVERTISING   — display and native inventory sold to developers, banks
--                      and brands. Served, targeted, capped, measured and
--                      invoiced.
--   4. CREDITS       — pay-per-lead and pay-per-listing consumption, which is
--                      how smaller agencies buy without committing to a plan.
--
-- Three things here are load-bearing and are usually got wrong:
--
-- INVENTORY IS COUNTED, NOT ASSUMED. `promotion_inventory` holds capacity and
-- sold counts per slot per day. Overselling featured placement is not a
-- rounding error, it is a refund and an angry phone call.
--
-- SPEND IS A LEDGER. `ad_spend_entries` is append-only and every impression
-- charge, click charge and adjustment is a row. A campaign's `spent_amount` is
-- derived from it, never incremented in isolation, because a budget that drifts
-- overspends real money.
--
-- DELIVERY DATA IS PARTITIONED AND UNJOINED. `ad_impressions` and `ad_events`
-- take the same shape as `analytics_events` in 0012: month partitions, no
-- foreign keys, every dimension denormalised at write time. At portal volume
-- this table is the largest in the database by an order of magnitude, and
-- retention has to be a DROP PARTITION.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · PROMOTION PRODUCTS AND INVENTORY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- promotion_products
--
-- The sellable catalogue. `boost_multiplier` and `results_pin_position` are the
-- link between what was sold and what the ranking layer in 0022 actually does —
-- so "featured" has a defined, auditable effect rather than being whatever the
-- ORDER BY happened to say that week.
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_products (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(500)    NULL,
  product_type   ENUM('featured','premium','spotlight','homepage','category_top','search_pin','bump','refresh','verified_badge','video_upgrade','photography','virtual_tour','social_boost','newsletter','bundle') NOT NULL DEFAULT 'featured',
  -- What the listing gets. Read by the ranking profile in 0022.
  boost_multiplier DECIMAL(6,3)  NOT NULL DEFAULT 1.000,
  results_pin_position TINYINT UNSIGNED NULL,
  badge_label    VARCHAR(40)     NULL,
  badge_colour   CHAR(7)         NULL,
  -- Scope. A product may be sold only for certain categories or markets.
  root_category_id INT UNSIGNED  NULL,
  applies_to     ENUM('listing','project','agent','organization','post') NOT NULL DEFAULT 'listing',
  -- Duration and consumption model.
  duration_days  SMALLINT UNSIGNED NULL,
  is_recurring   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Quantity model: a "bump" is consumed once, a "featured 30 days" occupies a
  -- slot for its duration. The inventory checker branches on this.
  consumes_inventory TINYINT(1)  NOT NULL DEFAULT 1,
  max_per_listing SMALLINT UNSIGNED NULL,
  -- Bundles reference their components in promotion_bundle_items.
  is_bundle      TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_promotion_products_code (code),
  UNIQUE KEY uq_promotion_products_public (public_id),
  KEY ix_promotion_products_active (is_active, product_type, sort_order),
  CONSTRAINT fk_promotion_products_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE promotion_bundle_items (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  bundle_product_id INT UNSIGNED NOT NULL,
  component_product_id INT UNSIGNED NOT NULL,
  quantity       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_bundle_item (bundle_product_id, component_product_id),
  CONSTRAINT fk_bundle_items_bundle FOREIGN KEY (bundle_product_id) REFERENCES promotion_products (id) ON DELETE CASCADE,
  CONSTRAINT fk_bundle_items_component FOREIGN KEY (component_product_id) REFERENCES promotion_products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- promotion_prices
--
-- Price varies by currency, by market and over time, and the price a customer
-- paid must remain knowable after the rate card changes. Hence effective dating
-- rather than a mutable column on the product.
--
-- A featured slot in Dubai Marina and one in a secondary city are not worth the
-- same money; `location_id` is what lets the rate card say so.
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_prices (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  product_id     INT UNSIGNED    NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  -- Audience tiering: an enterprise account's rate card differs from self-serve.
  audience       ENUM('all','individual','agency','developer','enterprise') NOT NULL DEFAULT 'all',
  amount         DECIMAL(12,2)   NOT NULL,
  amount_base    DECIMAL(12,2)   NULL,
  credit_cost    INT UNSIGNED    NULL,
  -- Volume breaks: buy 10 features, pay less each.
  min_quantity   SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- The resolution query is "this product, this currency, this market, today",
  -- most specific first.
  KEY ix_promotion_prices_resolve (product_id, currency_code, is_active, effective_from),
  KEY ix_promotion_prices_location (location_id, product_id),
  CONSTRAINT fk_promotion_prices_product FOREIGN KEY (product_id) REFERENCES promotion_products (id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_prices_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_prices_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_prices_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- promotion_inventory
--
-- Finite capacity, per product per slot per day. The purchase path takes a row
-- lock here and increments `sold_count` inside the same transaction that
-- creates the purchase, which is what makes overselling impossible rather than
-- unlikely.
--
-- `reserved_count` covers the checkout window: a slot held while payment
-- authorises but not yet sold, released by a sweeper if the payment never
-- completes.
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_inventory (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  product_id     INT UNSIGNED    NOT NULL,
  inventory_date DATE            NOT NULL,
  -- The slot dimensions. NULL means "not scoped by this dimension", so a
  -- product sold globally has one row per day and one sold per community has
  -- one row per community per day.
  location_id    BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  capacity       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  sold_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  reserved_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Kept as a stored column rather than a generated one so it is portable to
  -- MariaDB and indexable without expression-index support.
  available_count SMALLINT       NOT NULL DEFAULT 0,
  waitlist_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_promotion_inventory (product_id, inventory_date, location_id, root_category_id, purpose_id),
  -- "What is still available in this area for these dates" — the availability
  -- calendar the sales team lives in.
  KEY ix_promotion_inventory_avail (location_id, inventory_date, available_count),
  KEY ix_promotion_inventory_date (inventory_date, product_id),
  CONSTRAINT fk_promotion_inventory_product FOREIGN KEY (product_id) REFERENCES promotion_products (id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_inventory_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- promotion_purchases
--
-- The commercial transaction: what was bought, by whom, for how much, paid how.
-- Distinct from `listing_promotions`, which is the *application* of it — one
-- purchase of ten features becomes ten applications over three months, and
-- collapsing the two makes refunds and unused balances impossible to represent.
-- -----------------------------------------------------------------------------
CREATE TABLE promotion_purchases (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(32)     NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  product_id     INT UNSIGNED    NOT NULL,
  quantity       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  quantity_used  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  unit_price     DECIMAL(12,2)   NOT NULL DEFAULT 0,
  subtotal       DECIMAL(12,2)   NOT NULL DEFAULT 0,
  discount_amount DECIMAL(12,2)  NOT NULL DEFAULT 0,
  tax_amount     DECIMAL(12,2)   NOT NULL DEFAULT 0,
  total_amount   DECIMAL(12,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  total_amount_base DECIMAL(12,2) NULL,
  -- Paid with money, with credits, or granted as part of a plan. All three are
  -- real and each needs a different revenue treatment.
  payment_method ENUM('card','wallet','credits','invoice','bank_transfer','plan_allowance','free','manual') NOT NULL DEFAULT 'card',
  credits_used   INT UNSIGNED    NULL,
  payment_id     BIGINT UNSIGNED NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  coupon_id      INT UNSIGNED    NULL,
  status         ENUM('pending','paid','active','partially_used','fully_used','expired','refunded','cancelled','failed') NOT NULL DEFAULT 'pending',
  purchased_at   DATETIME(3)     NULL,
  expires_at     DATETIME(3)     NULL,
  refunded_at    DATETIME(3)     NULL,
  refund_amount  DECIMAL(12,2)   NULL,
  refund_reason  VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_promotion_purchases_public (public_id),
  UNIQUE KEY uq_promotion_purchases_reference (reference),
  KEY ix_promotion_purchases_account (account_id, status, created_at),
  KEY ix_promotion_purchases_org (organization_id, created_at),
  KEY ix_promotion_purchases_product (product_id, purchased_at),
  -- "What have I bought and not yet used" — the balance screen.
  KEY ix_promotion_purchases_unused (account_id, status, expires_at),
  CONSTRAINT fk_promotion_purchases_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_promotion_purchases_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_promotion_purchases_product FOREIGN KEY (product_id) REFERENCES promotion_products (id),
  CONSTRAINT fk_promotion_purchases_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_promotion_purchases_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL,
  CONSTRAINT fk_promotion_purchases_coupon FOREIGN KEY (coupon_id) REFERENCES coupons (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_promotions
--
-- One row per active or historical promotion on one listing. This is what the
-- search projection reads, so it is deliberately narrow and its index is built
-- for exactly one question: "which listings are promoted right now".
-- -----------------------------------------------------------------------------
CREATE TABLE listing_promotions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  purchase_id    BIGINT UNSIGNED NULL,
  product_id     INT UNSIGNED    NOT NULL,
  subject_type   ENUM('listing','project','agent','organization','post') NOT NULL DEFAULT 'listing',
  subject_id     BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  -- Slot the promotion occupies, mirrored from the inventory row so the
  -- release path does not have to re-derive it.
  inventory_id   BIGINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  boost_multiplier DECIMAL(6,3)  NOT NULL DEFAULT 1.000,
  pin_position   TINYINT UNSIGNED NULL,
  badge_label    VARCHAR(40)     NULL,
  status         ENUM('scheduled','active','paused','expired','cancelled','refunded') NOT NULL DEFAULT 'active',
  starts_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  ends_at        DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  -- Performance, so the renewal conversation is evidence-based. Derived from
  -- ad_daily_stats-style rollups rather than incremented per event.
  impressions    INT UNSIGNED    NOT NULL DEFAULT 0,
  detail_views   INT UNSIGNED    NOT NULL DEFAULT 0,
  inquiries      INT UNSIGNED    NOT NULL DEFAULT 0,
  calls          INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Measured against the listing's own pre-promotion baseline, which is the
  -- only honest way to claim an uplift.
  baseline_daily_views INT UNSIGNED NULL,
  uplift_percent DECIMAL(8,2)    NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- The search path's only question.
  KEY ix_listing_promotions_active (status, subject_type, subject_id, ends_at),
  KEY ix_listing_promotions_listing (listing_id, status, ends_at),
  -- The expiry sweeper.
  KEY ix_listing_promotions_expiry (status, ends_at),
  KEY ix_listing_promotions_purchase (purchase_id),
  KEY ix_listing_promotions_org (organization_id, status, starts_at),
  CONSTRAINT fk_listing_promotions_purchase FOREIGN KEY (purchase_id) REFERENCES promotion_purchases (id) ON DELETE SET NULL,
  CONSTRAINT fk_listing_promotions_product FOREIGN KEY (product_id) REFERENCES promotion_products (id),
  CONSTRAINT fk_listing_promotions_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_promotions_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_promotions_inventory FOREIGN KEY (inventory_id) REFERENCES promotion_inventory (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_bumps
--
-- "Refresh to top of the list" is sold separately from featuring, is consumed
-- once, and is heavily abused — an agency bumping the same tired listing three
-- times a day degrades the results page for everyone. `cooldown_until` and the
-- per-day counters are the throttle, and they are in the data rather than in
-- application memory so they survive a deploy.
-- -----------------------------------------------------------------------------
CREATE TABLE listing_bumps (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  purchase_id    BIGINT UNSIGNED NULL,
  bump_type      ENUM('paid','plan_allowance','free_weekly','auto','admin') NOT NULL DEFAULT 'paid',
  previous_refreshed_at DATETIME(3) NULL,
  bumped_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  cooldown_until DATETIME(3)     NULL,
  bumps_today    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  credits_used   INT UNSIGNED    NULL,
  triggered_by_user_id BIGINT UNSIGNED NULL,
  PRIMARY KEY (id),
  KEY ix_listing_bumps_listing (listing_id, bumped_at),
  KEY ix_listing_bumps_cooldown (listing_id, cooldown_until),
  KEY ix_listing_bumps_account (account_id, bumped_at),
  CONSTRAINT fk_listing_bumps_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_listing_bumps_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_listing_bumps_purchase FOREIGN KEY (purchase_id) REFERENCES promotion_purchases (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 2 · CREDITS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- credit_types
--
-- Credits are not interchangeable. A lead credit, a listing credit and a
-- feature credit are separate currencies with separate balances, and a plan
-- that grants 50 listing credits must not silently pay for leads.
-- -----------------------------------------------------------------------------
CREATE TABLE credit_types (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  description    VARCHAR(400)    NULL,
  -- Whether unused credits survive the billing period. Expiring credits are
  -- the norm on plan allowances and the exception on purchased packs.
  expires        TINYINT(1)      NOT NULL DEFAULT 1,
  default_validity_days SMALLINT UNSIGNED NULL,
  -- Whether a negative balance is allowed, i.e. the account may go into debt
  -- and be invoiced later. Enterprise accounts often can; self-serve cannot.
  allow_negative TINYINT(1)      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_credit_types_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- credit_packs / credit_pack_prices
--
-- What can be bought. Separated from the price so the same pack is sold in
-- twelve currencies without twelve products.
-- -----------------------------------------------------------------------------
CREATE TABLE credit_packs (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  credit_type_id SMALLINT UNSIGNED NOT NULL,
  credits        INT UNSIGNED    NOT NULL,
  -- Extra credits thrown in on larger packs. Kept separate from `credits` so
  -- the discount is visible in reporting rather than baked into the total.
  bonus_credits  INT UNSIGNED    NOT NULL DEFAULT 0,
  validity_days  SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_credit_packs_code (code),
  CONSTRAINT fk_credit_packs_type FOREIGN KEY (credit_type_id) REFERENCES credit_types (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE credit_pack_prices (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  pack_id        INT UNSIGNED    NOT NULL,
  currency_code  CHAR(3)         NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  amount         DECIMAL(12,2)   NOT NULL,
  amount_base    DECIMAL(12,2)   NULL,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY ix_credit_pack_prices_resolve (pack_id, currency_code, is_active, effective_from),
  CONSTRAINT fk_credit_pack_prices_pack FOREIGN KEY (pack_id) REFERENCES credit_packs (id) ON DELETE CASCADE,
  CONSTRAINT fk_credit_pack_prices_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- credit_balances
--
-- One row per (account, credit type). `balance` is a cache of the ledger below
-- and is asserted against it by the integrity suite — the ledger is the truth,
-- the balance is the index.
--
-- `reserved` holds credits committed to an in-flight operation (a lead being
-- purchased, a feature being applied) so two concurrent spends cannot both see
-- the same credits as available.
-- -----------------------------------------------------------------------------
CREATE TABLE credit_balances (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  credit_type_id SMALLINT UNSIGNED NOT NULL,
  balance        INT             NOT NULL DEFAULT 0,
  reserved       INT UNSIGNED    NOT NULL DEFAULT 0,
  lifetime_granted BIGINT UNSIGNED NOT NULL DEFAULT 0,
  lifetime_spent BIGINT UNSIGNED NOT NULL DEFAULT 0,
  lifetime_expired BIGINT UNSIGNED NOT NULL DEFAULT 0,
  -- The soonest expiry in the account's credit lots, so "12 credits expire on
  -- Friday" is a column read rather than an aggregate over the ledger.
  next_expiry_at DATETIME(3)     NULL,
  next_expiry_amount INT UNSIGNED NULL,
  low_balance_threshold INT UNSIGNED NULL,
  low_balance_notified_at DATETIME(3) NULL,
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_credit_balance (account_id, credit_type_id),
  KEY ix_credit_balances_expiry (next_expiry_at),
  KEY ix_credit_balances_low (credit_type_id, balance),
  CONSTRAINT fk_credit_balances_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_credit_balances_type FOREIGN KEY (credit_type_id) REFERENCES credit_types (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- credit_lots
--
-- Credits arrive in batches with their own expiry, and spending must consume
-- the oldest-expiring lot first. Without lots, "500 credits expiring in March"
-- and "500 with no expiry" are one indistinguishable number and every expiry
-- run takes credits the customer thought were permanent.
-- -----------------------------------------------------------------------------
CREATE TABLE credit_lots (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id     BIGINT UNSIGNED NOT NULL,
  credit_type_id SMALLINT UNSIGNED NOT NULL,
  source         ENUM('purchase','plan_allowance','promotion','refund','adjustment','referral','trial','compensation') NOT NULL DEFAULT 'purchase',
  purchase_id    BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  granted        INT UNSIGNED    NOT NULL,
  remaining      INT UNSIGNED    NOT NULL,
  -- Unit cost carried so consumption can be valued for revenue recognition —
  -- a credit granted free and a credit bought for 40 AED are not the same
  -- deferred revenue.
  unit_cost      DECIMAL(10,4)   NULL,
  currency_code  CHAR(3)         NULL,
  granted_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  expires_at     DATETIME(3)     NULL,
  exhausted_at   DATETIME(3)     NULL,
  expired_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  -- The consumption order: oldest expiry first, then oldest grant.
  KEY ix_credit_lots_consume (account_id, credit_type_id, remaining, expires_at),
  KEY ix_credit_lots_expiry (expires_at, remaining),
  KEY ix_credit_lots_purchase (purchase_id),
  CONSTRAINT fk_credit_lots_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_credit_lots_type FOREIGN KEY (credit_type_id) REFERENCES credit_types (id),
  CONSTRAINT fk_credit_lots_subscription FOREIGN KEY (subscription_id) REFERENCES subscriptions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- credit_transactions
--
-- Append-only. Every grant, spend, expiry, refund and adjustment, with the
-- resulting balance stamped on the row so a statement renders without a running
-- window function, and so a drift between ledger and balance is detectable at
-- the exact transaction where it started.
-- -----------------------------------------------------------------------------
CREATE TABLE credit_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  credit_type_id SMALLINT UNSIGNED NOT NULL,
  lot_id         BIGINT UNSIGNED NULL,
  transaction_type ENUM('grant','spend','refund','expiry','adjustment','transfer_in','transfer_out','reservation','release') NOT NULL,
  amount         INT             NOT NULL,
  balance_after  INT             NOT NULL,
  -- What it was spent on. Polymorphic because credits buy leads, features,
  -- listings and boosts, and a nullable FK per kind would be five columns.
  subject_type   ENUM('lead','lead_share','listing','listing_promotion','listing_bump','ad_campaign','purchase','subscription','none') NOT NULL DEFAULT 'none',
  subject_id     BIGINT UNSIGNED NULL,
  -- Idempotency key for the spend path. A retried lead purchase must not
  -- charge twice, and this unique index is what guarantees it.
  idempotency_key VARCHAR(120)   NULL,
  description    VARCHAR(300)    NULL,
  performed_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_credit_transactions_public (public_id),
  UNIQUE KEY uq_credit_transactions_idem (account_id, idempotency_key),
  KEY ix_credit_transactions_account (account_id, credit_type_id, created_at),
  KEY ix_credit_transactions_subject (subject_type, subject_id),
  KEY ix_credit_transactions_lot (lot_id),
  CONSTRAINT fk_credit_transactions_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_credit_transactions_type FOREIGN KEY (credit_type_id) REFERENCES credit_types (id),
  CONSTRAINT fk_credit_transactions_lot FOREIGN KEY (lot_id) REFERENCES credit_lots (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- lead_pricing_rules
--
-- What a lead costs in credits, which is not one number. A Palm Jumeirah buyer
-- lead with a stated 20M budget is worth many times a rental enquiry in a
-- secondary city, and pricing them the same is how a pay-per-lead marketplace
-- either loses money or prices itself out.
-- -----------------------------------------------------------------------------
CREATE TABLE lead_pricing_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name           VARCHAR(160)    NOT NULL,
  priority       SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  root_category_id INT UNSIGNED  NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  min_budget_base DECIMAL(18,2)  NULL,
  max_budget_base DECIMAL(18,2)  NULL,
  min_score      SMALLINT        NULL,
  exclusivity    ENUM('exclusive','shared','open','any') NOT NULL DEFAULT 'any',
  credit_cost    INT UNSIGNED    NOT NULL DEFAULT 1,
  -- Cash price for accounts buying without credits.
  cash_price     DECIMAL(10,2)   NULL,
  currency_code  CHAR(3)         NULL,
  -- Multiplier applied on top for verified-phone or high-score leads. Kept
  -- separate from credit_cost so the base price and the quality premium are
  -- separately explainable to a customer disputing a charge.
  quality_multiplier DECIMAL(5,2) NOT NULL DEFAULT 1.00,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  effective_from DATE            NULL,
  effective_to   DATE            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_lead_pricing_eval (is_active, priority),
  KEY ix_lead_pricing_location (location_id, is_active),
  CONSTRAINT fk_lead_pricing_category FOREIGN KEY (root_category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_pricing_purpose FOREIGN KEY (purpose_id) REFERENCES purposes (id) ON DELETE CASCADE,
  CONSTRAINT fk_lead_pricing_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 3 · AD SERVER
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ad_advertisers
--
-- Who is buying. Distinct from `accounts` because most display advertisers —
-- a bank, a furniture retailer, a developer's media agency — never list a
-- property and have no marketplace account at all.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_advertisers (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  advertiser_type ENUM('developer','agency','bank','mortgage','furniture','automotive','luxury_brand','media_agency','internal','other') NOT NULL DEFAULT 'other',
  -- Billing counterparty, which is frequently the media agency rather than the
  -- brand. Getting this wrong means invoicing the wrong company.
  billing_entity_name VARCHAR(200) NULL,
  billing_email  VARCHAR(255)    NULL,
  billing_country_id BIGINT UNSIGNED NULL,
  tax_id         VARCHAR(60)     NULL,
  -- Credit control. An advertiser over its limit cannot book more inventory.
  credit_limit   DECIMAL(14,2)   NULL,
  outstanding_balance DECIMAL(14,2) NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  payment_terms_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  account_manager_user_id BIGINT UNSIGNED NULL,
  status         ENUM('prospect','active','on_hold','suspended','closed') NOT NULL DEFAULT 'active',
  logo_url       VARCHAR(500)    NULL,
  website_url    VARCHAR(500)    NULL,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_advertisers_public (public_id),
  UNIQUE KEY uq_ad_advertisers_slug (slug),
  KEY ix_ad_advertisers_status (status, name),
  KEY ix_ad_advertisers_account (account_id),
  CONSTRAINT fk_ad_advertisers_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_ad_advertisers_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_placements
--
-- The inventory map: every slot on the site that can hold an ad, with its
-- dimensions and rules. Defining placements in data rather than in template
-- code means sales can quote from a list that is guaranteed to exist.
--
-- `floor_cpm` is the price below which the slot is not sold at all; it is what
-- stops remnant inventory destroying the rate card.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_placements (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  description    VARCHAR(400)    NULL,
  -- Where it lives.
  page_type      ENUM('home','search_results','listing_detail','category','location','agent_profile','organization_profile','project','blog','blog_post','saved_searches','dashboard','email','global') NOT NULL DEFAULT 'global',
  position       ENUM('leaderboard','sidebar','in_feed','interstitial','sticky_footer','hero','below_gallery','above_results','between_results','native_card','popup','email_banner') NOT NULL DEFAULT 'sidebar',
  format         ENUM('display','native','video','sponsored_listing','sponsored_agent','takeover','text_link','email') NOT NULL DEFAULT 'display',
  -- Accepted creative sizes as [{w,h}], validated on upload so a 970x250 is
  -- never booked into a 300x250 slot.
  accepted_sizes JSON            NULL,
  max_file_size_kb SMALLINT UNSIGNED NULL,
  -- How many ads may render in this slot on one page view. In-feed slots take
  -- several; a leaderboard takes one.
  slot_count     TINYINT UNSIGNED NOT NULL DEFAULT 1,
  -- Position within the results list for in-feed placements, so "third card"
  -- is a booked property of the slot rather than a CSS accident.
  feed_positions JSON            NULL,
  floor_cpm      DECIMAL(10,2)   NULL,
  floor_cpc      DECIMAL(10,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  -- Whether unsold impressions fall through to house ads or render nothing.
  allow_house_ads TINYINT(1)     NOT NULL DEFAULT 1,
  is_above_fold  TINYINT(1)      NOT NULL DEFAULT 0,
  device_targets SET('desktop','mobile','tablet','app') NOT NULL DEFAULT 'desktop,mobile,tablet',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_placements_code (code),
  KEY ix_ad_placements_page (page_type, position, is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_campaigns
--
-- The advertiser's brief: a budget, a period, an objective. Pacing and delivery
-- happen at the line-item level below, because one campaign routinely runs a
-- leaderboard, an in-feed native and a video at three different rates.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_campaigns (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  advertiser_id  INT UNSIGNED    NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  reference      VARCHAR(60)     NULL,
  objective      ENUM('awareness','traffic','leads','listings','app_installs','retargeting','sponsorship') NOT NULL DEFAULT 'awareness',
  status         ENUM('draft','pending_approval','approved','scheduled','active','paused','completed','cancelled','rejected') NOT NULL DEFAULT 'draft',
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  -- Budget in the advertiser's currency plus a base copy, same rule as
  -- everywhere else in this schema.
  total_budget   DECIMAL(14,2)   NULL,
  daily_budget   DECIMAL(14,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  total_budget_base DECIMAL(14,2) NULL,
  -- Derived from ad_spend_entries by sp_ads_refresh_spend, never incremented
  -- in place.
  spent_amount   DECIMAL(14,2)   NOT NULL DEFAULT 0,
  spent_amount_base DECIMAL(14,2) NOT NULL DEFAULT 0,
  -- Even pacing spends the budget across the flight; accelerated spends it as
  -- fast as inventory allows. Getting this wrong burns a month's budget in a
  -- weekend.
  pacing         ENUM('even','accelerated','front_loaded','manual') NOT NULL DEFAULT 'even',
  -- Rollups, refreshed from ad_daily_stats.
  impressions    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         BIGINT UNSIGNED NOT NULL DEFAULT 0,
  conversions    INT UNSIGNED    NOT NULL DEFAULT 0,
  io_number      VARCHAR(60)     NULL,
  io_signed_at   DATETIME(3)     NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  approved_by_user_id BIGINT UNSIGNED NULL,
  approved_at    DATETIME(3)     NULL,
  rejection_reason VARCHAR(300)  NULL,
  notes          TEXT            NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_campaigns_public (public_id),
  KEY ix_ad_campaigns_advertiser (advertiser_id, status, starts_at),
  -- The ad server's candidate query starts here: campaigns live right now.
  KEY ix_ad_campaigns_live (status, starts_at, ends_at),
  CONSTRAINT fk_ad_campaigns_advertiser FOREIGN KEY (advertiser_id) REFERENCES ad_advertisers (id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_campaigns_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_line_items
--
-- The bookable unit: one placement, one price model, one flight, one set of
-- targeting. This is what the ad server actually selects from.
--
-- `priority` and `weight` together implement the standard direct-sold model:
-- guaranteed line items win over preemptible ones, and within a priority band
-- delivery is proportional to weight.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_line_items (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  campaign_id    INT UNSIGNED    NOT NULL,
  placement_id   INT UNSIGNED    NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  status         ENUM('draft','ready','delivering','paused','completed','cancelled','out_of_budget','no_creatives') NOT NULL DEFAULT 'draft',
  -- Commercial model.
  pricing_model  ENUM('cpm','cpc','cpl','cpd','flat','house','sponsorship') NOT NULL DEFAULT 'cpm',
  rate           DECIMAL(10,4)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  -- Guaranteed line items must deliver their goal; preemptible ones fill what
  -- is left. `goal_quantity` is impressions for CPM, clicks for CPC, days for
  -- CPD.
  delivery_type  ENUM('guaranteed','preemptible','house','sponsorship') NOT NULL DEFAULT 'guaranteed',
  goal_quantity  BIGINT UNSIGNED NULL,
  delivered_quantity BIGINT UNSIGNED NOT NULL DEFAULT 0,
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 5,
  weight         SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  starts_at      DATETIME(3)     NULL,
  ends_at        DATETIME(3)     NULL,
  budget         DECIMAL(14,2)   NULL,
  daily_budget   DECIMAL(14,2)   NULL,
  spent_amount   DECIMAL(14,2)   NOT NULL DEFAULT 0,
  -- Frequency capping. Stored on the line item and enforced against
  -- ad_frequency_state per visitor.
  frequency_cap_impressions SMALLINT UNSIGNED NULL,
  frequency_cap_period ENUM('hour','day','week','month','lifetime') NULL,
  -- Delivery counters, refreshed from the daily rollup.
  impressions    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         BIGINT UNSIGNED NOT NULL DEFAULT 0,
  conversions    INT UNSIGNED    NOT NULL DEFAULT 0,
  viewable_impressions BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_line_items_public (public_id),
  -- The ad server's hot query: deliverable line items for this placement,
  -- highest priority first.
  KEY ix_ad_line_items_serve (placement_id, status, priority, ends_at),
  KEY ix_ad_line_items_campaign (campaign_id, status),
  KEY ix_ad_line_items_flight (status, starts_at, ends_at),
  CONSTRAINT fk_ad_line_items_campaign FOREIGN KEY (campaign_id) REFERENCES ad_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_line_items_placement FOREIGN KEY (placement_id) REFERENCES ad_placements (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_creatives
--
-- The asset that renders. Multiple creatives per line item is the norm — sizes,
-- languages, and A/B variants — and `rotation_weight` decides between them.
--
-- Creatives are moderated: an unreviewed creative must never serve, which is
-- why `review_status` gates delivery rather than being advisory.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_creatives (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  line_item_id   INT UNSIGNED    NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  creative_type  ENUM('image','html5','video','native','text','sponsored_listing','carousel') NOT NULL DEFAULT 'image',
  -- Asset. Display creatives reference the DAM from 0016 so they get the same
  -- CDN, renditions and virus scanning as everything else.
  media_asset_id BIGINT UNSIGNED NULL,
  asset_url      VARCHAR(500)    NULL,
  width          SMALLINT UNSIGNED NULL,
  height         SMALLINT UNSIGNED NULL,
  file_size_kb   MEDIUMINT UNSIGNED NULL,
  -- Native and text creatives.
  headline       VARCHAR(200)    NULL,
  body_text      VARCHAR(500)    NULL,
  call_to_action VARCHAR(60)     NULL,
  -- Sponsored-listing creatives point at a real listing rather than an external
  -- site, which is the highest-converting inventory a property portal owns.
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  click_url      VARCHAR(1000)   NULL,
  -- Third-party impression pixel, required by most media agencies.
  tracking_pixel_url VARCHAR(1000) NULL,
  language_id    SMALLINT UNSIGNED NULL,
  rotation_weight SMALLINT UNSIGNED NOT NULL DEFAULT 100,
  review_status  ENUM('pending','approved','rejected','changes_requested') NOT NULL DEFAULT 'pending',
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  rejection_reason VARCHAR(300)  NULL,
  impressions    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ctr            DECIMAL(7,4)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_creatives_public (public_id),
  KEY ix_ad_creatives_serve (line_item_id, is_active, review_status),
  KEY ix_ad_creatives_review (review_status, created_at),
  KEY ix_ad_creatives_listing (listing_id),
  CONSTRAINT fk_ad_creatives_line_item FOREIGN KEY (line_item_id) REFERENCES ad_line_items (id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_creatives_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL,
  CONSTRAINT fk_ad_creatives_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_ad_creatives_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- ad_targeting_rules
--
-- Who sees the line item. Rows rather than a JSON blob for the same reason as
-- lead routing: an ops team must be able to ask "which campaigns target Dubai
-- Marina?" and get an indexed answer.
--
-- `is_negative` is the exclusion form, which is used far more than people
-- expect — a bank's mortgage ad excluded from rental pages, a developer's ad
-- excluded from its competitors' listings.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_targeting_rules (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  line_item_id   INT UNSIGNED    NOT NULL,
  dimension      ENUM('country','city','location','category','purpose','price_band','device','language','browser','os','day_part','day_of_week','audience_segment','utm_source','referrer','logged_in','account_type','listing_attribute','keyword','new_visitor') NOT NULL,
  operator       ENUM('in','not_in','between','eq','contains','descendant_of') NOT NULL DEFAULT 'in',
  is_negative    TINYINT(1)      NOT NULL DEFAULT 0,
  value_ids      JSON            NULL,
  value_text     VARCHAR(500)    NULL,
  value_min      DECIMAL(18,2)   NULL,
  value_max      DECIMAL(18,2)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_ad_targeting_line_item (line_item_id, dimension),
  KEY ix_ad_targeting_dimension (dimension, is_negative),
  CONSTRAINT fk_ad_targeting_line_item FOREIGN KEY (line_item_id) REFERENCES ad_line_items (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_frequency_state
--
-- Per-visitor, per-line-item impression counts, so a cap of "3 per day" is
-- enforced rather than asserted. Deliberately narrow: this table is written on
-- every single ad render and read before every one.
--
-- `period_start` in the key makes expiry a range delete rather than a scan, and
-- keeps the row count bounded by (visitors × capped line items × live periods).
-- -----------------------------------------------------------------------------
CREATE TABLE ad_frequency_state (
  visitor_id     CHAR(32)        CHARACTER SET ascii NOT NULL,
  line_item_id   INT UNSIGNED    NOT NULL,
  period_start   DATETIME        NOT NULL,
  impressions    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  last_served_at DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (visitor_id, line_item_id, period_start),
  KEY ix_ad_frequency_cleanup (period_start)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_impressions
--
-- The raw delivery log. Month-partitioned, no foreign keys, every dimension
-- denormalised at write time — identical reasoning to `analytics_events` in
-- 0012, and for the same reason: at portal volume this is the largest table in
-- the database and it must never join, never be updated, and be droppable by
-- partition.
--
-- One row per rendered ad. A busy portal writes tens of millions a month, so
-- the column list is as short as the reporting genuinely requires and nothing
-- more.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_impressions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  line_item_id   INT UNSIGNED    NOT NULL,
  creative_id    INT UNSIGNED    NULL,
  placement_id   INT UNSIGNED    NOT NULL,
  campaign_id    INT UNSIGNED    NOT NULL,
  advertiser_id  INT UNSIGNED    NOT NULL,
  -- Context, denormalised.
  page_type      VARCHAR(40)     NULL,
  category_id    INT UNSIGNED    NULL,
  location_id    BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  user_id        BIGINT UNSIGNED NULL,
  device_type    ENUM('desktop','mobile','tablet','app','bot','other') NOT NULL DEFAULT 'other',
  -- Viewability, per the IAB definition (50% of pixels for one second). An
  -- impression that was never in the viewport is not billable to most agencies,
  -- so this is a commercial field, not a nicety.
  is_viewable    TINYINT(1)      NOT NULL DEFAULT 0,
  view_time_ms   MEDIUMINT UNSIGNED NULL,
  slot_position  TINYINT UNSIGNED NULL,
  -- What this impression cost, stamped at serve time so a later rate change
  -- cannot rewrite history.
  revenue        DECIMAL(12,6)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  -- Invalid traffic. Filtered from billing but kept, because "you charged us
  -- for bot traffic" is a conversation you win with data or not at all.
  is_invalid     TINYINT(1)      NOT NULL DEFAULT 0,
  invalid_reason VARCHAR(60)     NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_ad_impressions_line_item (line_item_id, occurred_at),
  KEY ix_ad_impressions_campaign (campaign_id, occurred_at),
  KEY ix_ad_impressions_creative (creative_id, occurred_at),
  KEY ix_ad_impressions_placement (placement_id, occurred_at),
  KEY ix_ad_impressions_visitor (visitor_id, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p2027_01 VALUES LESS THAN (TO_DAYS('2027-02-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- ad_events
--
-- Clicks, video quartiles, conversions and interactions. Kept apart from
-- impressions because it is two to three orders of magnitude smaller and is
-- queried on completely different axes — mixing them would put a 0.3%-selective
-- event_type predicate on the largest table in the system.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_events (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  occurred_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  event_type     ENUM('click','conversion','video_start','video_25','video_50','video_75','video_complete','expand','close','engagement','lead_submit') NOT NULL DEFAULT 'click',
  line_item_id   INT UNSIGNED    NOT NULL,
  creative_id    INT UNSIGNED    NULL,
  placement_id   INT UNSIGNED    NULL,
  campaign_id    INT UNSIGNED    NOT NULL,
  advertiser_id  INT UNSIGNED    NOT NULL,
  impression_id  BIGINT UNSIGNED NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  user_id        BIGINT UNSIGNED NULL,
  device_type    ENUM('desktop','mobile','tablet','app','bot','other') NOT NULL DEFAULT 'other',
  country_id     BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  destination_url VARCHAR(1000)  NULL,
  -- Seconds between the impression and this event. The single best signal for
  -- separating a human click from a bot's instant one.
  seconds_since_impression MEDIUMINT UNSIGNED NULL,
  revenue        DECIMAL(12,6)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  conversion_value DECIMAL(14,2) NULL,
  is_invalid     TINYINT(1)      NOT NULL DEFAULT 0,
  invalid_reason VARCHAR(60)     NULL,
  PRIMARY KEY (id, occurred_at),
  KEY ix_ad_events_line_item (line_item_id, event_type, occurred_at),
  KEY ix_ad_events_campaign (campaign_id, event_type, occurred_at),
  KEY ix_ad_events_creative (creative_id, occurred_at),
  KEY ix_ad_events_visitor (visitor_id, occurred_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
PARTITION BY RANGE (TO_DAYS(occurred_at)) (
  PARTITION p2026_06 VALUES LESS THAN (TO_DAYS('2026-07-01')),
  PARTITION p2026_07 VALUES LESS THAN (TO_DAYS('2026-08-01')),
  PARTITION p2026_08 VALUES LESS THAN (TO_DAYS('2026-09-01')),
  PARTITION p2026_09 VALUES LESS THAN (TO_DAYS('2026-10-01')),
  PARTITION p2026_10 VALUES LESS THAN (TO_DAYS('2026-11-01')),
  PARTITION p2026_11 VALUES LESS THAN (TO_DAYS('2026-12-01')),
  PARTITION p2026_12 VALUES LESS THAN (TO_DAYS('2027-01-01')),
  PARTITION p2027_01 VALUES LESS THAN (TO_DAYS('2027-02-01')),
  PARTITION p_max    VALUES LESS THAN MAXVALUE
);

-- -----------------------------------------------------------------------------
-- ad_daily_stats
--
-- The rollup every report reads. Grain is (date, line item, creative,
-- placement, device, country) — wide enough for the standard agency report,
-- narrow enough that a month of a busy campaign is thousands of rows rather
-- than tens of millions.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  line_item_id   INT UNSIGNED    NOT NULL,
  creative_id    INT UNSIGNED    NULL,
  placement_id   INT UNSIGNED    NULL,
  campaign_id    INT UNSIGNED    NOT NULL,
  advertiser_id  INT UNSIGNED    NOT NULL,
  device_type    ENUM('desktop','mobile','tablet','app','all') NOT NULL DEFAULT 'all',
  country_id     BIGINT UNSIGNED NULL,
  impressions    BIGINT UNSIGNED NOT NULL DEFAULT 0,
  viewable_impressions BIGINT UNSIGNED NOT NULL DEFAULT 0,
  clicks         INT UNSIGNED    NOT NULL DEFAULT 0,
  conversions    INT UNSIGNED    NOT NULL DEFAULT 0,
  video_completes INT UNSIGNED   NOT NULL DEFAULT 0,
  invalid_impressions INT UNSIGNED NOT NULL DEFAULT 0,
  invalid_clicks INT UNSIGNED    NOT NULL DEFAULT 0,
  unique_visitors INT UNSIGNED   NOT NULL DEFAULT 0,
  revenue        DECIMAL(16,4)   NOT NULL DEFAULT 0,
  revenue_base   DECIMAL(16,4)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NULL,
  -- Derived ratios stored because every report shows them and recomputing them
  -- per row per request is pure waste.
  ctr            DECIMAL(7,4)    NULL,
  viewability_rate DECIMAL(7,4)  NULL,
  effective_cpm  DECIMAL(10,4)   NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_daily (stat_date, line_item_id, creative_id, placement_id, device_type, country_id),
  KEY ix_ad_daily_campaign (campaign_id, stat_date),
  KEY ix_ad_daily_advertiser (advertiser_id, stat_date),
  KEY ix_ad_daily_placement (placement_id, stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_spend_entries
--
-- The money ledger for advertising, append-only. Impressions and clicks are
-- events; this is what they cost, batched by the billing job, plus manual
-- credits and adjustments.
--
-- `ad_campaigns.spent_amount` is a SUM over this table, refreshed by a
-- procedure and asserted by the integrity suite. A budget cap enforced against
-- an incremented counter eventually overspends; enforced against a ledger it
-- does not.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_spend_entries (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  campaign_id    INT UNSIGNED    NOT NULL,
  line_item_id   INT UNSIGNED    NULL,
  advertiser_id  INT UNSIGNED    NOT NULL,
  entry_type     ENUM('impression_batch','click_batch','conversion_batch','daily_flat','manual_charge','credit','adjustment','invalid_traffic_refund') NOT NULL,
  spend_date     DATE            NOT NULL,
  quantity       BIGINT UNSIGNED NOT NULL DEFAULT 0,
  unit_rate      DECIMAL(10,6)   NULL,
  amount         DECIMAL(14,4)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  amount_base    DECIMAL(14,4)   NOT NULL DEFAULT 0,
  fx_rate_to_base DECIMAL(20,10) NULL,
  -- Idempotency for the batch job: re-running a day must not double-charge.
  batch_key      VARCHAR(120)    NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  description    VARCHAR(300)    NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_ad_spend_batch (batch_key),
  KEY ix_ad_spend_campaign (campaign_id, spend_date),
  KEY ix_ad_spend_line_item (line_item_id, spend_date),
  KEY ix_ad_spend_advertiser (advertiser_id, spend_date),
  KEY ix_ad_spend_invoice (invoice_id),
  CONSTRAINT fk_ad_spend_campaign FOREIGN KEY (campaign_id) REFERENCES ad_campaigns (id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_spend_line_item FOREIGN KEY (line_item_id) REFERENCES ad_line_items (id) ON DELETE SET NULL,
  CONSTRAINT fk_ad_spend_advertiser FOREIGN KEY (advertiser_id) REFERENCES ad_advertisers (id) ON DELETE CASCADE,
  CONSTRAINT fk_ad_spend_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- ad_brand_safety_rules
--
-- Where an ad must never appear. A mortgage lender does not want its banner
-- beside a distressed-sale article, and a developer will not pay to appear on a
-- competitor's project page. These are contractual commitments, and enforcing
-- them in configuration rather than in code is what lets ops honour one at
-- 5pm on a Friday.
-- -----------------------------------------------------------------------------
CREATE TABLE ad_brand_safety_rules (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  advertiser_id  INT UNSIGNED    NULL,
  campaign_id    INT UNSIGNED    NULL,
  scope          ENUM('global','advertiser','campaign') NOT NULL DEFAULT 'campaign',
  rule_type      ENUM('block_keyword','block_category','block_organization','block_project','block_url_pattern','block_page_type','require_language') NOT NULL,
  value_text     VARCHAR(300)    NULL,
  value_ids      JSON            NULL,
  reason         VARCHAR(300)    NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_brand_safety_advertiser (advertiser_id, is_active),
  KEY ix_brand_safety_campaign (campaign_id, is_active),
  CONSTRAINT fk_brand_safety_advertiser FOREIGN KEY (advertiser_id) REFERENCES ad_advertisers (id) ON DELETE CASCADE,
  CONSTRAINT fk_brand_safety_campaign FOREIGN KEY (campaign_id) REFERENCES ad_campaigns (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 4 · AFFILIATES AND PARTNERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- affiliates / affiliate_links / affiliate_clicks / affiliate_conversions
--
-- Partner-driven acquisition: relocation consultants, mortgage comparison
-- sites, expat forums and influencers who send traffic for a share of what it
-- produces.
--
-- The attribution window is stored on the affiliate, not assumed globally,
-- because it is negotiated per partner and disputes about it are the single
-- most common affiliate argument.
-- -----------------------------------------------------------------------------
CREATE TABLE affiliates (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  account_id     BIGINT UNSIGNED NULL,
  affiliate_type ENUM('individual','company','influencer','comparison_site','relocation','mortgage_broker','media','employee_referral') NOT NULL DEFAULT 'individual',
  contact_email  VARCHAR(255)    NULL,
  contact_phone  VARCHAR(32)     NULL,
  country_id     BIGINT UNSIGNED NULL,
  status         ENUM('pending','active','paused','suspended','terminated') NOT NULL DEFAULT 'pending',
  -- Commercials.
  commission_model ENUM('cpa','cpl','revenue_share','tiered','flat') NOT NULL DEFAULT 'cpa',
  commission_rate DECIMAL(7,4)   NULL,
  commission_amount DECIMAL(10,2) NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  -- Days after the click within which a conversion still counts.
  attribution_window_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  attribution_model ENUM('last_click','first_click','linear') NOT NULL DEFAULT 'last_click',
  minimum_payout DECIMAL(10,2)   NULL,
  payout_method_id BIGINT UNSIGNED NULL,
  -- Lifetime counters, derived from the conversion table.
  click_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  signup_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  conversion_count INT UNSIGNED  NOT NULL DEFAULT 0,
  earned_total   DECIMAL(14,2)   NOT NULL DEFAULT 0,
  paid_total     DECIMAL(14,2)   NOT NULL DEFAULT 0,
  approved_at    DATETIME(3)     NULL,
  terms_accepted_at DATETIME(3)  NULL,
  tax_form_on_file TINYINT(1)    NOT NULL DEFAULT 0,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_affiliates_code (code),
  UNIQUE KEY uq_affiliates_public (public_id),
  KEY ix_affiliates_status (status, created_at),
  CONSTRAINT fk_affiliates_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_affiliates_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE SET NULL,
  CONSTRAINT fk_affiliates_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE affiliate_links (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  affiliate_id   INT UNSIGNED    NOT NULL,
  slug           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NULL,
  destination_url VARCHAR(1000)  NOT NULL,
  campaign_name  VARCHAR(120)    NULL,
  -- Per-link override of the affiliate's default commission, for a partner who
  -- is paid differently for a specific promotion.
  commission_rate DECIMAL(7,4)   NULL,
  commission_amount DECIMAL(10,2) NULL,
  click_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  conversion_count INT UNSIGNED  NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  expires_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_affiliate_links_slug (slug),
  KEY ix_affiliate_links_affiliate (affiliate_id, is_active),
  CONSTRAINT fk_affiliate_links_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliates (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE affiliate_clicks (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  affiliate_id   INT UNSIGNED    NOT NULL,
  link_id        INT UNSIGNED    NULL,
  visitor_id     CHAR(32)        CHARACTER SET ascii NULL,
  session_id     CHAR(32)        CHARACTER SET ascii NULL,
  -- The attribution cookie value. Indexed because the conversion path looks up
  -- by it, and it is the only join key between a click and a signup weeks later.
  click_token    CHAR(32)        CHARACTER SET ascii NOT NULL,
  landing_url    VARCHAR(500)    NULL,
  referrer_url   VARCHAR(500)    NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,
  country_id     BIGINT UNSIGNED NULL,
  device_type    ENUM('desktop','mobile','tablet','app','bot','other') NOT NULL DEFAULT 'other',
  is_suspicious  TINYINT(1)      NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NULL,
  clicked_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_affiliate_clicks_token (click_token),
  KEY ix_affiliate_clicks_affiliate (affiliate_id, clicked_at),
  KEY ix_affiliate_clicks_link (link_id, clicked_at),
  KEY ix_affiliate_clicks_expiry (expires_at),
  CONSTRAINT fk_affiliate_clicks_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliates (id) ON DELETE CASCADE,
  CONSTRAINT fk_affiliate_clicks_link FOREIGN KEY (link_id) REFERENCES affiliate_links (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE affiliate_conversions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  affiliate_id   INT UNSIGNED    NOT NULL,
  link_id        INT UNSIGNED    NULL,
  click_id       BIGINT UNSIGNED NULL,
  conversion_type ENUM('signup','listing_created','subscription','promotion_purchase','credit_purchase','lead','deal') NOT NULL DEFAULT 'signup',
  subject_type   ENUM('user','account','listing','subscription','purchase','lead','deal') NOT NULL,
  subject_id     BIGINT UNSIGNED NOT NULL,
  -- Value of the conversion and the commission it earns, both stamped at the
  -- time so a later rate change does not silently repay old conversions.
  order_value    DECIMAL(14,2)   NULL,
  currency_code  CHAR(3)         NULL,
  commission_amount DECIMAL(12,2) NOT NULL DEFAULT 0,
  commission_base DECIMAL(12,2)  NULL,
  status         ENUM('pending','approved','rejected','reversed','paid') NOT NULL DEFAULT 'pending',
  -- Hold period before approval, so a refunded subscription does not pay a
  -- commission that must then be clawed back.
  approvable_at  DATETIME(3)     NULL,
  approved_at    DATETIME(3)     NULL,
  rejected_reason VARCHAR(300)   NULL,
  reversed_at    DATETIME(3)     NULL,
  reversal_reason VARCHAR(300)   NULL,
  payout_id      BIGINT UNSIGNED NULL,
  paid_at        DATETIME(3)     NULL,
  attributed_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  days_since_click SMALLINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_affiliate_conversions_public (public_id),
  -- One commission per conversion subject per affiliate.
  UNIQUE KEY uq_affiliate_conversion_subject (affiliate_id, subject_type, subject_id),
  KEY ix_affiliate_conversions_affiliate (affiliate_id, status, attributed_at),
  KEY ix_affiliate_conversions_payout (payout_id),
  KEY ix_affiliate_conversions_approvable (status, approvable_at),
  CONSTRAINT fk_affiliate_conversions_affiliate FOREIGN KEY (affiliate_id) REFERENCES affiliates (id) ON DELETE CASCADE,
  CONSTRAINT fk_affiliate_conversions_link FOREIGN KEY (link_id) REFERENCES affiliate_links (id) ON DELETE SET NULL,
  CONSTRAINT fk_affiliate_conversions_click FOREIGN KEY (click_id) REFERENCES affiliate_clicks (id) ON DELETE SET NULL,
  CONSTRAINT fk_affiliate_conversions_payout FOREIGN KEY (payout_id) REFERENCES payouts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- revenue_daily_stats
--
-- One line across every revenue stream, per day, per market. Finance asks "what
-- did we make yesterday and from what" constantly, and answering it by
-- unioning six tables at read time is the reason those dashboards are slow
-- everywhere.
-- -----------------------------------------------------------------------------
CREATE TABLE revenue_daily_stats (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_date      DATE            NOT NULL,
  country_id     BIGINT UNSIGNED NULL,
  root_category_id INT UNSIGNED  NULL,
  currency_code  CHAR(3)         NULL,
  subscription_revenue DECIMAL(16,2) NOT NULL DEFAULT 0,
  promotion_revenue DECIMAL(16,2) NOT NULL DEFAULT 0,
  credit_revenue DECIMAL(16,2)   NOT NULL DEFAULT 0,
  advertising_revenue DECIMAL(16,2) NOT NULL DEFAULT 0,
  lead_revenue   DECIMAL(16,2)   NOT NULL DEFAULT 0,
  commission_revenue DECIMAL(16,2) NOT NULL DEFAULT 0,
  other_revenue  DECIMAL(16,2)   NOT NULL DEFAULT 0,
  gross_revenue  DECIMAL(16,2)   NOT NULL DEFAULT 0,
  refunds        DECIMAL(16,2)   NOT NULL DEFAULT 0,
  chargebacks    DECIMAL(16,2)   NOT NULL DEFAULT 0,
  net_revenue    DECIMAL(16,2)   NOT NULL DEFAULT 0,
  net_revenue_base DECIMAL(16,2) NOT NULL DEFAULT 0,
  affiliate_cost DECIMAL(16,2)   NOT NULL DEFAULT 0,
  payment_fees   DECIMAL(16,2)   NOT NULL DEFAULT 0,
  -- Account counts, so ARPA and churn come from the same row as the revenue.
  paying_accounts INT UNSIGNED   NOT NULL DEFAULT 0,
  new_paying_accounts INT UNSIGNED NOT NULL DEFAULT 0,
  churned_accounts INT UNSIGNED  NOT NULL DEFAULT 0,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_revenue_daily (stat_date, country_id, root_category_id, currency_code),
  KEY ix_revenue_daily_date (stat_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0021', 'advertising_and_monetization');
