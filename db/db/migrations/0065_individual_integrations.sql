-- =============================================================================
-- 0065 — Individuals can use the Integrations add-on too
-- =============================================================================
-- The owner's rule (2026-10-29): an individual seller may switch on the
-- Integrations add-on (feeds, the lead feed, webhooks) like a company. New
-- personal and lister accounts already give their owner `can_view_integrations`
-- (accounts.service.js); the seeded ones did not, which hid the portal's API &
-- Integrations page from them. Owners only: an individual account has no other
-- members.
--
-- Idempotent. Post-seed: it updates the seeded memberships.
-- =============================================================================

UPDATE account_members am
  JOIN accounts a ON a.id = am.account_id
  JOIN account_types at ON at.id = a.account_type_id
   SET am.can_view_integrations = 1
 WHERE am.role = 'owner' AND at.code IN ('personal', 'lister') AND am.can_view_integrations = 0;

INSERT INTO schema_migrations (version, name) VALUES ('0065', 'individual_integrations')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
