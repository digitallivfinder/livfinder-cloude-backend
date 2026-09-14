-- =============================================================================
-- Liv Finder — 0040 · Real Estate Developments as a category, per-account access
-- =============================================================================
-- Two changes that belong together:
--
--   1. "Real Estate Developments" becomes a real seventh root category, granted
--      and revoked on its own — not a flag on the real-estate row (0039).
--
--   2. Category access moves from `organization_category_access` (organisation
--      only; personal accounts were hardcoded to real estate in code) to
--      `account_category_access`, keyed on `accounts.id`. An admin can now grant
--      any category to any account, company or individual alike.
--
-- The old `organization_category_access` table is left in place, unused, for one
-- release so a rollback keeps its data. All reads and writes move to the new
-- table.
--
-- IDEMPOTENT. Safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

-- 1. The seventh root category. id 7 is unused (roots are 1-6, children 101+),
--    so it is pinned to keep `utils/categories.js` rootId literals honest.
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural,
                        depth, path, icon, status, is_visible, sort_order)
VALUES (7, '01K2F3A0000000000000000007', NULL, 7, 'real-estate-developments', 'real-estate-developments',
        'Real Estate Developments', 'Real Estate Developments', 0, 'real-estate-developments',
        'building', 'active', 1, 7)
ON DUPLICATE KEY UPDATE name = VALUES(name), name_plural = VALUES(name_plural),
                        slug = VALUES(slug), icon = VALUES(icon), sort_order = VALUES(sort_order);

-- 2. Revert 0039's flag column — replaced by a real category grant.
SET @lf_has_flag = (
  SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE()
     AND table_name = 'organization_category_access'
     AND column_name = 'developments_enabled'
);
SET @lf_sql = IF(@lf_has_flag > 0,
  'ALTER TABLE organization_category_access DROP COLUMN developments_enabled', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- 3. Per-account category access.
CREATE TABLE IF NOT EXISTS account_category_access (
  id                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_id           BIGINT UNSIGNED NOT NULL,
  category_id          INT UNSIGNED    NOT NULL,
  status               ENUM('requested','approved','rejected','revoked','suspended') NOT NULL DEFAULT 'requested',
  listing_quota        INT UNSIGNED    NULL,
  listing_used         INT UNSIGNED    NOT NULL DEFAULT 0,
  requested_at         DATETIME(3)     NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at          DATETIME(3)     NULL,
  reviewed_by_user_id  BIGINT UNSIGNED NULL,
  notes                VARCHAR(500)    NULL,
  created_at           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_account_category_access (account_id, category_id),
  KEY ix_aca_cat (category_id, status),
  KEY ix_aca_queue (status, requested_at),
  CONSTRAINT fk_aca_account   FOREIGN KEY (account_id)          REFERENCES accounts (id)   ON DELETE CASCADE,
  CONSTRAINT fk_aca_category  FOREIGN KEY (category_id)         REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_aca_reviewer  FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id)      ON DELETE SET NULL,
  CONSTRAINT fk_aca_requester FOREIGN KEY (requested_by_user_id) REFERENCES users (id)     ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4a. Carry every organisation grant over to its account.
INSERT INTO account_category_access
  (account_id, category_id, status, listing_quota, listing_used, requested_at,
   requested_by_user_id, reviewed_at, reviewed_by_user_id, notes, created_at, updated_at)
SELECT o.account_id, oca.category_id, oca.status, oca.listing_quota, oca.listing_used,
       oca.requested_at, oca.requested_by_user_id, oca.reviewed_at, oca.reviewed_by_user_id,
       oca.notes, oca.created_at, oca.updated_at
  FROM organization_category_access oca
  JOIN organizations o ON o.id = oca.organization_id AND o.deleted_at IS NULL
ON DUPLICATE KEY UPDATE status = VALUES(status);

-- 4b. Personal lister accounts were real-estate approved implicitly; make it real.
INSERT INTO account_category_access
  (account_id, category_id, status, listing_used, requested_at, reviewed_at, created_at)
SELECT a.id, 1, 'approved', 0, a.created_at, a.created_at, a.created_at
  FROM accounts a
  JOIN account_types at ON at.id = a.account_type_id
 WHERE at.code = 'lister' AND a.deleted_at IS NULL
ON DUPLICATE KEY UPDATE status = account_category_access.status;

INSERT INTO schema_migrations (version, name) VALUES ('0040', 'account_category_access')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
