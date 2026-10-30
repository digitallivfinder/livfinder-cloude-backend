-- =============================================================================
-- 0066 — Lead workspace in the client portal
-- =============================================================================
-- A company or an individual with no CRM of their own works their leads from the
-- portal: a short funnel, notes, documents, follow-ups and viewings.
--
-- Individuals: `leads` and `activities` required an organization, so an enquiry on
-- an individual seller's listing stopped at `inquiries` and never became a lead.
-- Both columns are now optional; such a lead is owned by `account_id` alone.
--
-- Viewings: `bookings.lead_id` ties a viewing added on a lead to that lead. It is an
-- ordinary booking, so it appears on the portal's Bookings page without further work.
--
-- Funnel: one short pipeline for every category. Existing leads stay on their
-- pipeline and read as a funnel step through `stage_type` (src/modules/leads/
-- leadFunnel.js); a lead joins this pipeline the first time a client moves it.
--
-- Lost reasons: the portal offers five. Four already exist; `other` is added here.
--
-- Idempotent. Post-seed: the pipeline and lost-reason rows are added after the seeded
-- ones, so their ids do not move.
-- =============================================================================

ALTER TABLE leads MODIFY organization_id BIGINT UNSIGNED NULL;
ALTER TABLE activities MODIFY organization_id BIGINT UNSIGNED NULL;

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

CALL lf_add_column('bookings', 'lead_id', 'BIGINT UNSIGNED NULL AFTER inquiry_id');

DROP PROCEDURE IF EXISTS lf_add_column;

SET @lf_has_index = (
  SELECT COUNT(*) FROM information_schema.statistics
   WHERE table_schema = DATABASE() AND table_name = 'bookings' AND index_name = 'ix_bookings_lead'
);
SET @lf_sql = IF(@lf_has_index = 0, 'ALTER TABLE bookings ADD INDEX ix_bookings_lead (lead_id, scheduled_start)', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

SET @lf_has_fk = (
  SELECT COUNT(*) FROM information_schema.table_constraints
   WHERE table_schema = DATABASE() AND table_name = 'bookings' AND constraint_name = 'fk_bookings_lead'
);
SET @lf_sql = IF(@lf_has_fk = 0,
  'ALTER TABLE bookings ADD CONSTRAINT fk_bookings_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL',
  'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

INSERT INTO lead_pipelines (organization_id, code, name, description, pipeline_type, is_default, is_active, sort_order)
SELECT NULL, 'client-funnel', 'Client funnel',
       'The short funnel clients use in the portal, the same for every category.',
       'lead', 0, 1, 60
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM lead_pipelines WHERE code = 'client-funnel' AND organization_id IS NULL);

SET @lf_funnel = (SELECT id FROM lead_pipelines WHERE code = 'client-funnel' AND organization_id IS NULL LIMIT 1);

INSERT IGNORE INTO lead_pipeline_stages (pipeline_id, code, name, stage_type, sort_order, probability, is_closed, is_won) VALUES
  (@lf_funnel, 'new',         'New',         'new',         10,   5.00, 0, 0),
  (@lf_funnel, 'contacted',   'Contacted',   'contacted',   20,  15.00, 0, 0),
  (@lf_funnel, 'qualified',   'Qualified',   'qualified',   30,  30.00, 0, 0),
  (@lf_funnel, 'viewing',     'Viewing',     'nurturing',   40,  50.00, 0, 0),
  (@lf_funnel, 'negotiating', 'Negotiating', 'negotiation', 50,  75.00, 0, 0),
  (@lf_funnel, 'won',         'Won',         'won',         60, 100.00, 1, 1),
  (@lf_funnel, 'lost',        'Lost',        'lost',        70,   0.00, 1, 0);

INSERT INTO lead_lost_reasons (organization_id, code, name, reason_group, sort_order)
SELECT NULL, 'other', 'Other', 'other', 200
  FROM DUAL
 WHERE NOT EXISTS (SELECT 1 FROM lead_lost_reasons WHERE code = 'other' AND organization_id IS NULL);

INSERT INTO schema_migrations (version, name) VALUES ('0066', 'client_lead_workspace')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
