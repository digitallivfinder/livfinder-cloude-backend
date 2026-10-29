-- =============================================================================
-- 0059 — Live and storage listing limits; the Integrations add-on
-- =============================================================================
-- Two limits per plan replace the single "slot" allowance of 0052/0053:
--
--   live limit     plans/accounts.listing_quota (unchanged column). Counts listings that
--                  are live or waiting for approval, so a company cannot queue more than
--                  its plan can show. `accounts.listing_used` now means this.
--   storage limit  plans/accounts.storage_quota (new). Counts every listing the account
--                  still holds: everything but archived (and deleted). NULL = unlimited,
--                  the same sentinel 0057 gave listing_quota.
--
-- Listings over the live limit simply stay unpublished; the company chooses in the portal
-- which ones go live. `account_category_access.listing_quota` stays as an optional live
-- cap per category and `listing_used` there follows the live rule.
--
-- Existing plans and accounts get a storage limit of twice their live limit, the owner's
-- worked example (50 live / 100 stored); admins set the real figures per plan.
--
-- The Integrations add-on (XML/CSV feeds, the listing API, lead export and webhooks) is
-- priced per plan by an admin (`plan_addons`, 0 allowed) and switched on per account
-- (`account_addons`). While it lapses, feeds stop and leads stop going out; listings stay.
--
-- Idempotent: load.sh re-applies every file. Post-seed: it recomputes usage from the
-- seeded listings and backfills the seeded plans.
-- =============================================================================

DROP PROCEDURE IF EXISTS lf_add_column;
DELIMITER //
CREATE PROCEDURE lf_add_column(IN p_table VARCHAR(64), IN p_column VARCHAR(64), IN p_definition TEXT)
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = DATABASE() AND table_name = p_table AND column_name = p_column
  ) THEN
    SET @lf_sql = CONCAT('ALTER TABLE `', p_table, '` ADD COLUMN `', p_column, '` ', p_definition);
    PREPARE lf_stmt FROM @lf_sql;
    EXECUTE lf_stmt;
    DEALLOCATE PREPARE lf_stmt;
  END IF;
END //
DELIMITER ;

-- Backfill the storage limit only on the run that adds it; later runs keep the admin's values.
SET @lf_plans_had_storage = (
  SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'plans' AND column_name = 'storage_quota'
);
SET @lf_accounts_had_storage = (
  SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'accounts' AND column_name = 'storage_quota'
);

CALL lf_add_column('plans', 'storage_quota', 'INT UNSIGNED NULL DEFAULT NULL AFTER listing_quota');
CALL lf_add_column('accounts', 'storage_quota', 'INT UNSIGNED NULL DEFAULT NULL AFTER listing_used');
CALL lf_add_column('accounts', 'storage_used', 'INT UNSIGNED NOT NULL DEFAULT 0 AFTER storage_quota');

DROP PROCEDURE IF EXISTS lf_add_column;

SET @lf_sql = IF(@lf_plans_had_storage = 0,
  'UPDATE plans SET storage_quota = IF(listing_quota IS NULL, NULL, listing_quota * 2)',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_sql = IF(@lf_accounts_had_storage = 0,
  'UPDATE accounts SET storage_quota = IF(listing_quota IS NULL, NULL, listing_quota * 2)',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- -----------------------------------------------------------------------------
-- Add-ons
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plan_addons (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  plan_id        INT UNSIGNED    NOT NULL,
  addon_code     VARCHAR(60)     CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- Whether accounts on this plan may switch the add-on on at all.
  is_available   TINYINT(1)      NOT NULL DEFAULT 0,
  -- Per billing period of the plan; 0 is a real "free" price.
  amount         DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_addons (plan_id, addon_code),
  CONSTRAINT fk_plan_addons_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS account_addons (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NOT NULL,
  addon_code     VARCHAR(60)     CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  -- The plan, price and currency it was switched on under, so a later price change by an
  -- admin never rewrites what an account agreed to.
  plan_id        INT UNSIGNED    NULL,
  amount         DECIMAL(18,2)   NOT NULL DEFAULT 0,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  status         ENUM('active','cancelled','expired') NOT NULL DEFAULT 'active',
  started_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  -- NULL: runs as long as the subscription does. Set: lapses at that moment.
  ends_at        DATETIME(3)     NULL,
  cancelled_at   DATETIME(3)     NULL,
  enabled_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_account_addons_public_id (public_id),
  -- One row per add-on per account; switching it back on reuses the row, so its history
  -- (leads, feeds, keys) carries on where it stopped.
  UNIQUE KEY uq_account_addons (account_id, addon_code),
  KEY ix_account_addons_status (addon_code, status, ends_at),
  CONSTRAINT fk_account_addons_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_account_addons_plan FOREIGN KEY (plan_id) REFERENCES plans (id) ON DELETE SET NULL,
  CONSTRAINT fk_account_addons_user FOREIGN KEY (enabled_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Every plan gets an Integrations row, unavailable until an admin prices it.
INSERT INTO plan_addons (plan_id, addon_code, is_available, amount, currency_code)
SELECT p.id, 'integrations', 0, 0, 'AED' FROM plans p
ON DUPLICATE KEY UPDATE plan_id = plan_addons.plan_id;

-- Companies already holding an active API key keep their integration running.
INSERT INTO account_addons (public_id, account_id, addon_code, plan_id, amount, currency_code, status, started_at)
SELECT CONCAT('01JADDON', LPAD(CONV(a.id, 10, 32), 18, '0')), a.id, 'integrations', s.plan_id, 0, 'AED', 'active', NOW(3)
  FROM accounts a
  LEFT JOIN subscriptions s ON s.id = (
         SELECT s2.id FROM subscriptions s2
          WHERE s2.account_id = a.id AND s2.status IN ('active','trialing','past_due')
          ORDER BY s2.created_at DESC LIMIT 1)
 WHERE EXISTS (
         SELECT 1 FROM api_clients ac
           LEFT JOIN organizations o ON o.id = ac.organization_id
          WHERE ac.status = 'active' AND COALESCE(ac.account_id, o.account_id) = a.id)
ON DUPLICATE KEY UPDATE account_id = account_addons.account_id;

-- -----------------------------------------------------------------------------
-- Usage under the new rules
-- -----------------------------------------------------------------------------
UPDATE accounts a
  LEFT JOIN (
    SELECT account_id,
           SUM(status IN ('pending_review', 'active')) AS live,
           SUM(status <> 'archived') AS held
      FROM listings
     WHERE deleted_at IS NULL
     GROUP BY account_id
  ) l ON l.account_id = a.id
   SET a.listing_used = COALESCE(l.live, 0),
       a.storage_used = COALESCE(l.held, 0);

UPDATE account_category_access aca
  JOIN categories c ON c.id = aca.category_id
   SET aca.listing_used = (
         SELECT COUNT(*) FROM listings l
          WHERE l.account_id = aca.account_id
            AND l.root_category_id = COALESCE(c.root_category_id, c.id)
            AND l.deleted_at IS NULL
            AND l.status IN ('pending_review', 'active')
       )
 WHERE COALESCE(c.root_category_id, c.id) <> 7;

-- The rollup, redefined from 0053 with only the account limits block changed.
DELIMITER $
DROP PROCEDURE IF EXISTS sp_refresh_entity_counters$$
CREATE PROCEDURE sp_refresh_entity_counters()
MODIFIES SQL DATA
BEGIN
  -- Traffic counters come from the analytics rollups, never from the raw event
  -- stream. There is no fact table for a page view, so the rollup *is* the
  -- source of truth for these — and it is subject to the rollup's retention.
  UPDATE listings l
    JOIN (
      SELECT listing_id,
             SUM(views)           AS views,
             SUM(unique_views)    AS unique_views,
             SUM(call_clicks)     AS call_clicks,
             SUM(whatsapp_clicks) AS whatsapp_clicks,
             SUM(shares)          AS shares
        FROM listing_daily_stats
       GROUP BY listing_id
    ) s ON s.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.view_count           = s.views,
         l.unique_view_count    = s.unique_views,
         l.call_click_count     = s.call_clicks,
         l.whatsapp_click_count = s.whatsapp_clicks,
         l.share_count          = s.shares;

  -- Counters that DO have a fact table are derived from it, not from the
  -- rollup. `inquiries` and `favourites` are permanent rows; the daily rollups
  -- are pruned on a retention schedule. Reading the counter from the rollup
  -- would silently undercount every listing older than that retention — which
  -- is precisely the "count disagrees with the rows behind it" defect this
  -- schema is trying to make impossible.
  UPDATE listings l
    LEFT JOIN (
      SELECT listing_id, COUNT(*) c
        FROM inquiries
       WHERE deleted_at IS NULL AND listing_id IS NOT NULL
       GROUP BY listing_id
    ) i ON i.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.inquiry_count = COALESCE(i.c, 0);

  UPDATE listings l
    LEFT JOIN (SELECT listing_id, COUNT(*) c FROM favourites GROUP BY listing_id) f
      ON f.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.favourite_count = COALESCE(f.c, 0);

  -- Agent rollups.
  UPDATE agents a
    LEFT JOIN (
      SELECT agent_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY agent_id
    ) l ON l.agent_id = a.id
     SET a.listing_count        = COALESCE(l.total, 0),
         a.active_listing_count = COALESCE(l.active, 0);

  UPDATE agents a
    LEFT JOIN (
      SELECT subject_id, COUNT(*) c, AVG(rating) avg_rating
        FROM reviews
       WHERE subject_type = 'agent' AND status = 'published' AND deleted_at IS NULL
       GROUP BY subject_id
    ) r ON r.subject_id = a.id
     SET a.review_count = COALESCE(r.c, 0),
         a.rating_avg   = r.avg_rating;

  -- Organisation rollups.
  UPDATE organizations o
    LEFT JOIN (
      SELECT organization_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY organization_id
    ) l ON l.organization_id = o.id
     SET o.listing_count        = COALESCE(l.total, 0),
         o.active_listing_count = COALESCE(l.active, 0);

  UPDATE organizations o
    LEFT JOIN (
      SELECT organization_id, COUNT(*) c
        FROM agents WHERE deleted_at IS NULL AND status = 'active'
       GROUP BY organization_id
    ) a ON a.organization_id = o.id
     SET o.agent_count = COALESCE(a.c, 0);

  UPDATE organizations o
    LEFT JOIN (
      SELECT subject_id, COUNT(*) c, AVG(rating) avg_rating
        FROM reviews
       WHERE subject_type = 'organization' AND status = 'published' AND deleted_at IS NULL
       GROUP BY subject_id
    ) r ON r.subject_id = o.id
     SET o.review_count = COALESCE(r.c, 0),
         o.rating_avg   = r.avg_rating;

  -- Category and brand rollups.
  UPDATE categories c
    LEFT JOIN (
      SELECT category_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY category_id
    ) l ON l.category_id = c.id
     SET c.listing_count        = COALESCE(l.total, 0),
         c.active_listing_count = COALESCE(l.active, 0);

  UPDATE brands b
    LEFT JOIN (
      SELECT brand_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL AND brand_id IS NOT NULL
       GROUP BY brand_id
    ) l ON l.brand_id = b.id
     SET b.listing_count        = COALESCE(l.total, 0),
         b.active_listing_count = COALESCE(l.active, 0);

  -- Account limits (0059): the live limit counts live + waiting for approval; the storage
  -- limit counts every listing the account still holds, so everything but archived.
  UPDATE accounts a
    LEFT JOIN (
      SELECT account_id,
             SUM(status IN ('pending_review', 'active')) AS live,
             SUM(status <> 'archived') AS held
        FROM listings
       WHERE deleted_at IS NULL
       GROUP BY account_id
    ) l ON l.account_id = a.id
     SET a.listing_used = COALESCE(l.live, 0),
         a.storage_used = COALESCE(l.held, 0);

  -- Collection item counts.
  UPDATE collections c
    LEFT JOIN (SELECT collection_id, COUNT(*) n FROM collection_items GROUP BY collection_id) i
      ON i.collection_id = c.id
     SET c.item_count = COALESCE(i.n, 0);

  -- Editorial term post counts.
  UPDATE editorial_terms t
    LEFT JOIN (
      SELECT pt.term_id, COUNT(*) n
        FROM post_terms pt
        JOIN posts p ON p.id = pt.post_id AND p.status = 'published' AND p.deleted_at IS NULL
       GROUP BY pt.term_id
    ) x ON x.term_id = t.id
     SET t.post_count = COALESCE(x.n, 0);

  UPDATE authors a
    LEFT JOIN (
      SELECT author_id, COUNT(*) n FROM posts
       WHERE status = 'published' AND deleted_at IS NULL GROUP BY author_id
    ) p ON p.author_id = a.id
     SET a.post_count = COALESCE(p.n, 0);
END$$
DELIMITER ;

INSERT INTO schema_migrations (version, name) VALUES ('0059', 'listing_limits_and_addons')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
