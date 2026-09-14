-- 0049_inquiry_lead_link.sql
--
-- Found during a full go-live QA walkthrough: the public contact form
-- (`POST /v1/inquiries`) has never created a CRM lead. It only ever wrote to
-- `inquiries` — the table the client portal's "Leads" page (`GET
-- /v1/portal/inquiries`) reads. The admin "Leads" module (`GET
-- /v1/admin/leads`, and everything under it — detail, activity, stage
-- history) reads the separate `leads` table, which nothing in the live
-- application ever wrote to; every row in it is seed data (`054_crm.sql`).
--
-- Practically: a real visitor's enquiry showed up for the listing's owner in
-- their portal, and NEVER showed up for the admin/ops team at all. The two
-- "Leads" screens were showing two disconnected universes.
--
-- This adds what the write path (0050 / engagement.routes.js) needs to close
-- the loop: a link from the inquiry to the lead it produced, and a lead
-- source row for the marketplace's own contact form (the existing taxonomy
-- had rows for syndication partners and ad channels but none for "asked us
-- directly").
--
-- Pure ADD COLUMN + one lookup row — data-safe and idempotent (the
-- lf_add_column helper checks information_schema first; the lead_sources
-- insert is ON DUPLICATE KEY). Not post-seed: `inquiries` and `lead_sources`
-- both exist from earlier migrations/seeds, independent of demo data.

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

CALL lf_add_column('inquiries', 'lead_id', 'BIGINT UNSIGNED NULL AFTER project_id');

DROP PROCEDURE IF EXISTS lf_add_column;

-- Index + FK only if not already present (a second run must not error).
SET @lf_has_index = (
  SELECT COUNT(*) FROM information_schema.statistics
   WHERE table_schema = DATABASE() AND table_name = 'inquiries' AND index_name = 'ix_inquiries_lead'
);
SET @lf_sql = IF(@lf_has_index = 0, 'ALTER TABLE inquiries ADD INDEX ix_inquiries_lead (lead_id)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_has_fk = (
  SELECT COUNT(*) FROM information_schema.table_constraints
   WHERE table_schema = DATABASE() AND table_name = 'inquiries' AND constraint_name = 'fk_inquiries_lead'
);
SET @lf_sql = IF(@lf_has_fk = 0,
  'ALTER TABLE inquiries ADD CONSTRAINT fk_inquiries_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- `ON DUPLICATE KEY` does not help here: `uq_lead_sources_code` is
-- (organization_id, code), and InnoDB treats every NULL organization_id as
-- distinct for uniqueness, so a plain upsert against a NULL-scoped row
-- inserts a fresh duplicate on every run instead of updating one. Guard with
-- NOT EXISTS instead.
INSERT INTO lead_sources (code, name)
SELECT 'website', 'Website enquiry' FROM DUAL
 WHERE NOT EXISTS (
   SELECT 1 FROM lead_sources WHERE code = 'website' AND organization_id IS NULL
 );

INSERT INTO schema_migrations (version, name) VALUES ('0049', 'inquiry_lead_link')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
