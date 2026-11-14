-- =============================================================================
-- 0079_seller_type.sql
--
-- Every seller account says what it is: an Individual, a Company or a Developer.
--
--   * `accounts.seller_type` — individual | company | developer. NULL for a Member (a personal
--     account), who cannot sell. The seller picks it when applying; an admin can change it.
--   * Only a Developer may hold Real Estate Developments (category 7). A Developer is always a
--     company (organizations.kind = 'developer'); an individual can never be one.
--   * `accounts.seller_intent` gains 'developer', so a social signup that chose Developer keeps
--     that choice until it applies.
--
-- Backfill: a private lister is an individual; an account whose organization's kind is
-- 'developer' is a developer; any other account with an organization is a company.
--
-- Accounts that did not match are put right (owner decision, 2026-11-14):
--   * a non-developer loses Developments access, and any project it owns goes back to draft and
--     off the website (nothing is deleted);
--   * a developer without Developments access is given it.
--
-- Post-seed: it reads the seeded organizations and grants. Safe to run more than once.
-- =============================================================================

SET NAMES utf8mb4;

SET @add_column = (
  SELECT IF(COUNT(*) = 0,
    "ALTER TABLE accounts ADD COLUMN seller_type ENUM('individual','company','developer') NULL AFTER account_type_id",
    'SELECT 1')
    FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'accounts' AND column_name = 'seller_type'
);
PREPARE add_column FROM @add_column;
EXECUTE add_column;
DEALLOCATE PREPARE add_column;

SET @add_index = (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE accounts ADD KEY ix_accounts_seller_type (seller_type)',
    'SELECT 1')
    FROM information_schema.statistics
   WHERE table_schema = DATABASE() AND table_name = 'accounts' AND index_name = 'ix_accounts_seller_type'
);
PREPARE add_index FROM @add_index;
EXECUTE add_index;
DEALLOCATE PREPARE add_index;

ALTER TABLE accounts
  MODIFY COLUMN seller_intent ENUM('personal','organization','developer') NULL;

-- Backfill. Only rows not yet typed, so an admin's later choice survives a re-run.
UPDATE accounts a
  JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
   SET a.seller_type = IF(o.kind = 'developer', 'developer', 'company')
 WHERE a.seller_type IS NULL;

UPDATE accounts a
  JOIN account_types t ON t.id = a.account_type_id
   SET a.seller_type = 'individual'
 WHERE a.seller_type IS NULL AND t.code = 'lister';

-- A non-developer's projects go back to draft and off the website; open change requests close.
UPDATE project_revisions r
  JOIN projects p ON p.pending_revision_id = r.id
  JOIN organizations o ON o.id = p.organization_id
  JOIN accounts a ON a.id = o.account_id
   SET r.status = 'superseded'
 WHERE r.status = 'pending' AND COALESCE(a.seller_type, '') <> 'developer';

UPDATE projects p
  JOIN organizations o ON o.id = p.organization_id
  JOIN accounts a ON a.id = o.account_id
   SET p.moderation_status = IF(p.moderation_status = 'archived', 'archived', 'draft'),
       p.is_publicly_visible = 0,
       p.pending_revision_id = NULL
 WHERE p.deleted_at IS NULL AND COALESCE(a.seller_type, '') <> 'developer';

DELETE ps FROM project_search ps
  JOIN projects p ON p.id = ps.project_id
  JOIN organizations o ON o.id = p.organization_id
  JOIN accounts a ON a.id = o.account_id
 WHERE COALESCE(a.seller_type, '') <> 'developer';

-- A non-developer loses Developments access.
UPDATE account_category_access aca
  JOIN accounts a ON a.id = aca.account_id
   SET aca.status = 'revoked', aca.reviewed_at = NOW(3),
       aca.notes = 'Developments are for developer accounts only (0079).'
 WHERE aca.category_id = 7
   AND aca.status IN ('requested','approved','suspended')
   AND COALESCE(a.seller_type, '') <> 'developer';

-- A developer is given it.
INSERT INTO account_category_access (account_id, category_id, status, listing_used, reviewed_at, notes, created_at)
SELECT a.id, 7, 'approved', 0, NOW(3), 'Developer account (0079).', NOW(3)
  FROM accounts a
 WHERE a.seller_type = 'developer' AND a.deleted_at IS NULL
ON DUPLICATE KEY UPDATE status = 'approved', reviewed_at = NOW(3), notes = VALUES(notes);

INSERT INTO schema_migrations (version, name) VALUES ('0079', 'seller_type')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
