-- =============================================================================
-- 0062 — Sold, rented and withdrawn listings stay reachable by their URL
-- =============================================================================
-- The owner's rule from 2026-10-29: a listing marked sold or rented, withdrawn by
-- its owner, or dropped from a company's feed leaves search, category pages,
-- featured placements and ads, but its own page keeps working at the same URL,
-- with no banner, and stays in the sitemap so the page keeps its search ranking.
-- Enquiries from that page are still accepted and sent to the company as leads.
--
-- `v_public_listings` (live and searchable) is unchanged. `v_reachable_listings`
-- adds the closed ones whose page may still be served: approved and published
-- at some point, never deleted, and not taken down by LivFinder itself. A
-- moderator's "unpublish" stamps `unpublished_by_platform_at`, which keeps that
-- page a 404; approving the listing again clears it.
--
-- Expired listings are not reachable: they lapsed rather than closed.
--
-- Idempotent: load.sh re-applies every file.
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

CALL lf_add_column('listings', 'unpublished_by_platform_at', 'DATETIME(3) NULL DEFAULT NULL AFTER sold_at');
DROP PROCEDURE IF EXISTS lf_add_column;

CREATE OR REPLACE VIEW v_reachable_listings AS
SELECT l.*
FROM listings l
WHERE l.deleted_at IS NULL
  AND l.moderation_status = 'approved'
  AND l.published_at IS NOT NULL
  AND l.published_at <= NOW(3)
  AND (
        (l.status = 'active' AND (l.expires_at IS NULL OR l.expires_at > NOW(3)))
     OR (l.status IN ('sold', 'rented', 'withdrawn') AND l.unpublished_by_platform_at IS NULL)
  );

INSERT INTO schema_migrations (version, name) VALUES ('0062', 'reachable_closed_listings')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
