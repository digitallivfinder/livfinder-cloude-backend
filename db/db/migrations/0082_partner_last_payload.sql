-- =============================================================================
-- 0082_partner_last_payload.sql
--
-- Partial updates for the partner listing API (PATCH /v1/partner/listings/{externalId}).
--
-- A partner can now send only the fields that changed (a new price, a new status). LivFinder
-- merges them onto the last complete listing the partner pushed and checks the result by the
-- same rules as a full push. `feed_import_items.raw_payload` cannot serve as that base: it is
-- nulled on a clean success. So the reference keeps the last accepted record itself.
--
--   external_references.last_payload   the partner's last accepted record for this listing,
--                                      as it was parsed (JSON). NULL for references made
--                                      before this migration, and for listings never pushed
--                                      in full; those need one full PUT before a PATCH.
--
-- Safe to run more than once.
-- =============================================================================

SET @has_last_payload := (SELECT COUNT(*) FROM information_schema.columns
                           WHERE table_schema = DATABASE() AND table_name = 'external_references' AND column_name = 'last_payload');
SET @ddl := IF(@has_last_payload = 0,
  'ALTER TABLE external_references ADD COLUMN last_payload JSON NULL AFTER payload_hash',
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT INTO schema_migrations (version, name) VALUES ('0082', 'partner_last_payload')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
