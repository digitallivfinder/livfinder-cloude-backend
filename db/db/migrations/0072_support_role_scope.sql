-- =============================================================================
-- 0072_support_role_scope.sql
--
-- The Support Agent role is described as "read-only across the platform plus user support
-- actions", but 0031 gave every role holding `users.edit` the admin-management permissions too,
-- so Support could manage staff accounts and change their roles (QA finding F20). The owner
-- decided (2026-11-03) that Support keeps its user-support actions and loses admin management.
-- Editing a staff account now needs `accessManagement.manageUsers` rather than `users.edit`
-- (admin.routes.js), so this is what closes it. Safe to run more than once.
-- =============================================================================

DELETE rp
  FROM role_permissions rp
  JOIN roles r ON r.id = rp.role_id AND r.code = 'support' AND r.scope = 'platform'
  JOIN permissions p ON p.id = rp.permission_id
 WHERE p.code IN ('adminUsers.manage', 'accessManagement.manageUsers');

INSERT INTO schema_migrations (version, name) VALUES ('0072', 'support_role_scope')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
