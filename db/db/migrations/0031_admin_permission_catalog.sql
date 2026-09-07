-- =============================================================================
-- Liv Finder — migration 0031 · Admin permission catalog
-- =============================================================================
-- Registers every permission id the admin Role Access matrix can grant, and
-- links them to the seven platform roles.
--
-- WHY THIS EXISTS
--
-- Two permission vocabularies were in use and only one of them existed in the
-- database:
--
--   * `permissions` held 26 coarse codes (`listings.view`, `users.edit`, …).
--     These are what every admin endpoint checks — the security boundary.
--
--   * The admin frontend's Role Access matrix
--     (`_lib/auth/permissionCatalog.js`) offers 120 granular ids across nine
--     main menus — `listings.cars.view`, `locations.country.create`,
--     `blog.publish`, `media.upload`, and so on. None of them had a row here.
--
-- `admin.mutations.js → upsertRole()` resolves each submitted code with
-- `SELECT id FROM permissions WHERE code = ?` and skips it when the lookup
-- returns nothing:
--
--     const permission = await queryValue("SELECT id FROM permissions WHERE code = ?", [code]);
--     if (permission) { INSERT INTO role_permissions … }
--
-- So a role saved from the matrix silently kept only the handful of ids that
-- happened to collide with a coarse code, and dropped the other ~115 without
-- error. Users holding that role then resolved almost no permissions, and the
-- admin nav — which is built from them — rendered nearly empty.
--
-- This migration closes the gap: the granular ids become real rows, so the
-- lookup succeeds and role_permissions records what the administrator actually
-- ticked.
--
-- IDEMPOTENT. Safe to re-run. `INSERT IGNORE` leaves the original 26 rows and
-- any existing grant untouched.
--
-- NOTE — five ids exist in both vocabularies and are therefore already present:
--   listings.view · listings.edit · listings.moderate · reports.view ·
--   reports.resolve
-- They are deliberately omitted from the INSERT below so their original name,
-- domain and description survive.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1 · The catalog
--
-- `domain` follows the Role Access main-menu grouping rather than the coarse
-- vocabulary's (listings/users/moderation/finance/content/system), because these
-- rows exist to drive that matrix.
-- -----------------------------------------------------------------------------

-- Dashboard -------------------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('dashboard.view', 'View dashboard', 'dashboard', 'See the admin dashboard and its KPIs.');

-- Control Center --------------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('companies.view',      'View companies',      'control_center', 'Open the Companies list and company files.'),
  ('companies.create',    'Create companies',    'control_center', 'Register a new company record.'),
  ('companies.edit',      'Edit companies',      'control_center', 'Change company profile details.'),
  ('companies.archive',   'Archive companies',   'control_center', 'Suspend or archive a company.'),
  ('companies.verify',    'Verify companies',    'control_center', 'Approve or reject company verification.'),
  ('individuals.view',    'View individuals',    'control_center', 'Open the Individuals list and account files.'),
  ('individuals.create',  'Create individuals',  'control_center', 'Register a new personal account.'),
  ('individuals.edit',    'Edit individuals',    'control_center', 'Change personal account details.'),
  ('individuals.archive', 'Archive individuals', 'control_center', 'Suspend or archive a personal account.'),
  ('individuals.verify',  'Verify individuals',  'control_center', 'Approve or reject individual verification.');

-- Listings — coarse actions ---------------------------------------------------
-- `listings.view`, `listings.edit` and `listings.moderate` already exist.
-- These two are the matrix's Create and Delete columns, which had no code.
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('listings.create',  'Create listings',  'listings', 'Publish a listing on behalf of an owner.'),
  ('listings.archive', 'Archive listings', 'listings', 'Archive a listing without deleting it.');

-- Leads — coarse actions ------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('leads.view',   'View leads',   'listings', 'See the lead pipeline and contact records.'),
  ('leads.manage', 'Manage leads', 'listings', 'Change lead stage, status and notes.'),
  ('leads.assign', 'Assign leads', 'listings', 'Assign a lead to an agent or owner.'),
  ('leads.export', 'Export leads', 'listings', 'Export the lead pipeline to a file.');

-- Listings and Leads — per marketplace category -------------------------------
-- Seven categories, mirroring `marketplaceCategories.js`. `real-estate-
-- developments` is included: it is a Role Access module even though it has no
-- root row in `categories` (developments live in `projects`).
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('listings.real-estate.view',                 'View real estate listings',              'listings', 'Real Estate — view.'),
  ('listings.real-estate.create',               'Create real estate listings',            'listings', 'Real Estate — create.'),
  ('listings.real-estate.edit',                 'Edit real estate listings',              'listings', 'Real Estate — update.'),
  ('listings.real-estate.archive',              'Archive real estate listings',           'listings', 'Real Estate — delete.'),
  ('leads.real-estate.view',                    'View real estate leads',                 'listings', 'Real Estate — leads and contacts, view.'),
  ('leads.real-estate.manage',                  'Manage real estate leads',               'listings', 'Real Estate — leads and contacts, update.'),

  ('listings.real-estate-developments.view',    'View developments',                      'listings', 'Real Estate Developments — view.'),
  ('listings.real-estate-developments.create',  'Create developments',                    'listings', 'Real Estate Developments — create.'),
  ('listings.real-estate-developments.edit',    'Edit developments',                      'listings', 'Real Estate Developments — update.'),
  ('listings.real-estate-developments.archive', 'Archive developments',                   'listings', 'Real Estate Developments — delete.'),
  ('leads.real-estate-developments.view',       'View development leads',                 'listings', 'Real Estate Developments — leads and contacts, view.'),
  ('leads.real-estate-developments.manage',     'Manage development leads',               'listings', 'Real Estate Developments — leads and contacts, update.'),

  ('listings.cars.view',                        'View car listings',                      'listings', 'Cars — view.'),
  ('listings.cars.create',                      'Create car listings',                    'listings', 'Cars — create.'),
  ('listings.cars.edit',                        'Edit car listings',                      'listings', 'Cars — update.'),
  ('listings.cars.archive',                     'Archive car listings',                   'listings', 'Cars — delete.'),
  ('leads.cars.view',                           'View car leads',                         'listings', 'Cars — leads and contacts, view.'),
  ('leads.cars.manage',                         'Manage car leads',                       'listings', 'Cars — leads and contacts, update.'),

  ('listings.jets.view',                        'View jet listings',                      'listings', 'Jets — view.'),
  ('listings.jets.create',                      'Create jet listings',                    'listings', 'Jets — create.'),
  ('listings.jets.edit',                        'Edit jet listings',                      'listings', 'Jets — update.'),
  ('listings.jets.archive',                     'Archive jet listings',                   'listings', 'Jets — delete.'),
  ('leads.jets.view',                           'View jet leads',                         'listings', 'Jets — leads and contacts, view.'),
  ('leads.jets.manage',                         'Manage jet leads',                       'listings', 'Jets — leads and contacts, update.'),

  ('listings.yachts.view',                      'View yacht listings',                    'listings', 'Yachts — view.'),
  ('listings.yachts.create',                    'Create yacht listings',                  'listings', 'Yachts — create.'),
  ('listings.yachts.edit',                      'Edit yacht listings',                    'listings', 'Yachts — update.'),
  ('listings.yachts.archive',                   'Archive yacht listings',                 'listings', 'Yachts — delete.'),
  ('leads.yachts.view',                         'View yacht leads',                       'listings', 'Yachts — leads and contacts, view.'),
  ('leads.yachts.manage',                       'Manage yacht leads',                     'listings', 'Yachts — leads and contacts, update.'),

  ('listings.helicopters.view',                 'View helicopter listings',               'listings', 'Helicopters — view.'),
  ('listings.helicopters.create',               'Create helicopter listings',             'listings', 'Helicopters — create.'),
  ('listings.helicopters.edit',                 'Edit helicopter listings',               'listings', 'Helicopters — update.'),
  ('listings.helicopters.archive',              'Archive helicopter listings',            'listings', 'Helicopters — delete.'),
  ('leads.helicopters.view',                    'View helicopter leads',                  'listings', 'Helicopters — leads and contacts, view.'),
  ('leads.helicopters.manage',                  'Manage helicopter leads',                'listings', 'Helicopters — leads and contacts, update.'),

  ('listings.watches.view',                     'View watch listings',                    'listings', 'Watches — view.'),
  ('listings.watches.create',                   'Create watch listings',                  'listings', 'Watches — create.'),
  ('listings.watches.edit',                     'Edit watch listings',                    'listings', 'Watches — update.'),
  ('listings.watches.archive',                  'Archive watch listings',                 'listings', 'Watches — delete.'),
  ('leads.watches.view',                        'View watch leads',                       'listings', 'Watches — leads and contacts, view.'),
  ('leads.watches.manage',                      'Manage watch leads',                     'listings', 'Watches — leads and contacts, update.');

-- Manage — categories ---------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('categories.manageAccess', 'Manage category access', 'manage', 'Grant, refuse and quota a marketplace category for an organisation.');

-- Manage — locations, one row per cascading level ------------------------------
-- `subCommunity` is camelCase to match the frontend id exactly; a snake_case
-- spelling here would not resolve.
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('locations.country.view',         'View countries',           'manage', 'Locations — Country, view.'),
  ('locations.country.create',       'Create countries',         'manage', 'Locations — Country, create.'),
  ('locations.country.edit',         'Edit countries',           'manage', 'Locations — Country, update.'),
  ('locations.country.archive',      'Archive countries',        'manage', 'Locations — Country, delete.'),
  ('locations.state.view',           'View states',              'manage', 'Locations — State, view.'),
  ('locations.state.create',         'Create states',            'manage', 'Locations — State, create.'),
  ('locations.state.edit',           'Edit states',              'manage', 'Locations — State, update.'),
  ('locations.state.archive',        'Archive states',           'manage', 'Locations — State, delete.'),
  ('locations.city.view',            'View cities',              'manage', 'Locations — City, view.'),
  ('locations.city.create',          'Create cities',            'manage', 'Locations — City, create.'),
  ('locations.city.edit',            'Edit cities',              'manage', 'Locations — City, update.'),
  ('locations.city.archive',         'Archive cities',           'manage', 'Locations — City, delete.'),
  ('locations.community.view',       'View communities',         'manage', 'Locations — Community, view.'),
  ('locations.community.create',     'Create communities',       'manage', 'Locations — Community, create.'),
  ('locations.community.edit',       'Edit communities',         'manage', 'Locations — Community, update.'),
  ('locations.community.archive',    'Archive communities',      'manage', 'Locations — Community, delete.'),
  ('locations.subCommunity.view',    'View sub communities',     'manage', 'Locations — Sub Community, view.'),
  ('locations.subCommunity.create',  'Create sub communities',   'manage', 'Locations — Sub Community, create.'),
  ('locations.subCommunity.edit',    'Edit sub communities',     'manage', 'Locations — Sub Community, update.'),
  ('locations.subCommunity.archive', 'Archive sub communities',  'manage', 'Locations — Sub Community, delete.');

-- Manage — reviews and customer compliance ------------------------------------
-- `reports.view` and `reports.resolve` already exist as coarse codes.
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('reviews.view',     'View reviews',      'manage', 'Open the review moderation queue.'),
  ('reviews.moderate', 'Moderate reviews',  'manage', 'Action a review in the queue.'),
  ('reviews.publish',  'Publish reviews',   'manage', 'Publish a held review.'),
  ('reviews.reject',   'Reject reviews',    'manage', 'Reject a review with a reason.'),
  ('reviews.archive',  'Archive reviews',   'manage', 'Archive a moderated review.'),
  ('reports.create',   'Create reports',    'manage', 'Raise a compliance report.'),
  ('reports.edit',     'Edit reports',      'manage', 'Change report details and priority.'),
  ('reports.assign',   'Assign reports',    'manage', 'Assign a report to a reviewer.');

-- Billing ---------------------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('billing.view',         'View billing',        'billing', 'See transactions and payment settings.'),
  ('billing.manage',       'Manage billing',      'billing', 'Change payment settings and plan pricing.'),
  ('transactions.export',  'Export transactions', 'billing', 'Export the transaction ledger.'),
  ('transactions.refund',  'Refund transactions', 'billing', 'Issue a refund against a payment.');

-- Marketing -------------------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('blog.create',   'Create articles',   'marketing', 'Write a new article as a draft.'),
  ('blog.edit',     'Edit articles',     'marketing', 'Change article content.'),
  ('blog.publish',  'Publish articles',  'marketing', 'Move an article to published.'),
  ('blog.archive',  'Archive articles',  'marketing', 'Archive an article.'),
  ('pages.create',  'Create pages',      'marketing', 'Create a static or landing page.'),
  ('pages.edit',    'Edit pages',        'marketing', 'Change page content.'),
  ('pages.publish', 'Publish pages',     'marketing', 'Publish a page.'),
  ('media.upload',  'Upload media',      'marketing', 'Add assets to the media library.'),
  ('media.edit',    'Edit media',        'marketing', 'Change alt text, caption, credit and folder.'),
  ('media.archive', 'Archive media',     'marketing', 'Archive a media asset.'),
  ('emails.view',   'View marketing',    'marketing', 'Open Blog, Pages, Media Library and Email Templates.'),
  ('emails.manage', 'Manage marketing',  'marketing', 'Change email templates and marketing content.');

-- Access Management -----------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('adminUsers.view',                 'View admin users',        'access_management', 'Open General Settings and the staff directory.'),
  ('adminUsers.manage',               'Manage admin users',      'access_management', 'Change staff accounts and General Settings.'),
  ('accessManagement.viewRoles',      'View roles',              'access_management', 'Open the Roles list and the permission matrix.'),
  ('accessManagement.manageRoles',    'Manage roles',            'access_management', 'Create, edit and delete platform roles.'),
  ('accessManagement.viewUsers',      'View user accesses',      'access_management', 'Open the User Accesses list.'),
  ('accessManagement.manageUsers',    'Manage user accesses',    'access_management', 'Grant and revoke role assignments.');

-- Settings --------------------------------------------------------------------
INSERT IGNORE INTO permissions (code, name, domain, description) VALUES
  ('emailTemplates.create',  'Create email templates',  'settings', 'Add a notification template.'),
  ('emailTemplates.archive', 'Archive email templates', 'settings', 'Archive a notification template.'),
  ('systemLogs.view',        'View system logs',        'settings', 'Read the application log.'),
  ('systemLogs.resolve',     'Resolve system logs',     'settings', 'Mark a log entry resolved.'),
  ('systemLogs.export',      'Export system logs',      'settings', 'Export log entries to a file.');


-- -----------------------------------------------------------------------------
-- 2 · Role grants
--
-- Derived from the coarse grants each role already holds, mirroring
-- `src/modules/auth/adminPermissions.js → DB_TO_ADMIN_PERMISSIONS` exactly. Two
-- consequences worth knowing:
--
--   * a custom role created before this migration gains the granular ids its
--     existing coarse grants imply, so nobody's effective access narrows;
--   * the mapping stays in one place conceptually — if you change the mapping in
--     source, change it here too, or re-run this migration after editing.
--
-- `grant_from` names the coarse code that implies the block beneath it.
-- -----------------------------------------------------------------------------

-- listings.view → dashboard, per-category view, location view
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'listings.view') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'dashboard.view',
  'listings.real-estate.view','listings.real-estate-developments.view','listings.cars.view',
  'listings.jets.view','listings.yachts.view','listings.helicopters.view','listings.watches.view',
  'locations.country.view','locations.state.view','locations.city.view',
  'locations.community.view','locations.subCommunity.view'
);

-- listings.edit → create/edit, per category
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'listings.edit') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'listings.create',
  'listings.real-estate.create','listings.real-estate-developments.create','listings.cars.create',
  'listings.jets.create','listings.yachts.create','listings.helicopters.create','listings.watches.create',
  'listings.real-estate.edit','listings.real-estate-developments.edit','listings.cars.edit',
  'listings.jets.edit','listings.yachts.edit','listings.helicopters.edit','listings.watches.edit'
);

-- listings.delete → archive, per category
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'listings.delete') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'listings.archive',
  'listings.real-estate.archive','listings.real-estate-developments.archive','listings.cars.archive',
  'listings.jets.archive','listings.yachts.archive','listings.helicopters.archive','listings.watches.archive'
);

-- moderation.queue → review moderation
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'moderation.queue') AS g
CROSS JOIN permissions p
WHERE p.code IN ('reviews.view','reviews.moderate','reviews.publish','reviews.reject');

-- reports.view → dashboard
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'reports.view') AS g
CROSS JOIN permissions p
WHERE p.code IN ('dashboard.view');

-- reports.resolve → edit and assign
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'reports.resolve') AS g
CROSS JOIN permissions p
WHERE p.code IN ('reports.edit','reports.assign');

-- users.view → control center, staff directory, lead visibility
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'users.view') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'dashboard.view','companies.view','individuals.view','adminUsers.view','accessManagement.viewUsers',
  'leads.view',
  'leads.real-estate.view','leads.real-estate-developments.view','leads.cars.view',
  'leads.jets.view','leads.yachts.view','leads.helicopters.view','leads.watches.view'
);

-- users.edit → create/edit across control center, lead management
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'users.edit') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'companies.create','companies.edit','individuals.create','individuals.edit',
  'adminUsers.manage','accessManagement.manageUsers','leads.manage','leads.assign',
  'leads.real-estate.manage','leads.real-estate-developments.manage','leads.cars.manage',
  'leads.jets.manage','leads.yachts.manage','leads.helicopters.manage','leads.watches.manage'
);

-- users.suspend → archive
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'users.suspend') AS g
CROSS JOIN permissions p
WHERE p.code IN ('companies.archive','individuals.archive');

-- accounts.verify → verification decisions
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'accounts.verify') AS g
CROSS JOIN permissions p
WHERE p.code IN ('companies.verify','individuals.verify');

-- accounts.type_change / taxonomy.manage → category access
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id
       WHERE s.code IN ('accounts.type_change','taxonomy.manage')) AS g
CROSS JOIN permissions p
WHERE p.code IN ('categories.manageAccess');

-- content.edit → authoring
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'content.edit') AS g
CROSS JOIN permissions p
WHERE p.code IN (
  'emails.view','emails.manage','blog.create','blog.edit','pages.create','pages.edit',
  'media.upload','media.edit','emailTemplates.create'
);

-- content.publish → publishing and archiving
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'content.publish') AS g
CROSS JOIN permissions p
WHERE p.code IN ('blog.publish','blog.archive','pages.publish','media.archive','emailTemplates.archive');

-- locations.manage → full location tree
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'locations.manage') AS g
CROSS JOIN permissions p
WHERE p.code LIKE 'locations.%';

-- finance.view → billing visibility
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'finance.view') AS g
CROSS JOIN permissions p
WHERE p.code IN ('billing.view','dashboard.view');

-- finance.plans / finance.payout → billing management
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id
       WHERE s.code IN ('finance.plans','finance.payout')) AS g
CROSS JOIN permissions p
WHERE p.code IN ('billing.manage');

-- finance.refund → refunds and export
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'finance.refund') AS g
CROSS JOIN permissions p
WHERE p.code IN ('transactions.refund','transactions.export');

-- analytics.view → dashboard and reporting
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'analytics.view') AS g
CROSS JOIN permissions p
WHERE p.code IN ('dashboard.view');

-- settings.manage → role administration and marketing management
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'settings.manage') AS g
CROSS JOIN permissions p
WHERE p.code IN ('emails.manage','accessManagement.viewRoles','accessManagement.manageRoles');

-- api.manage → role visibility
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'api.manage') AS g
CROSS JOIN permissions p
WHERE p.code IN ('accessManagement.viewRoles');

-- system.logs → log tooling
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT g.role_id, p.id
FROM (SELECT DISTINCT rp.role_id FROM role_permissions rp
        JOIN permissions s ON s.id = rp.permission_id AND s.code = 'system.logs') AS g
CROSS JOIN permissions p
WHERE p.code IN ('systemLogs.view','systemLogs.resolve','systemLogs.export');


-- -----------------------------------------------------------------------------
-- 3 · Top-ups the derivation cannot reach
--
-- Eight matrix ids have no coarse counterpart at all — they exist only in the
-- frontend catalog. Without an explicit grant nobody would ever hold them.
-- -----------------------------------------------------------------------------

-- Super Administrator holds the entire catalog, by definition.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'super_admin';

-- Administrator holds everything except the finance and role-administration
-- actions the original seed deliberately withheld.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r CROSS JOIN permissions p
WHERE r.code = 'admin'
  AND p.code NOT IN (
    'finance.refund','finance.payout','finance.plans','settings.manage',
    'transactions.refund','transactions.export','billing.manage','accessManagement.manageRoles'
  );

-- Moderator raises and archives what it already moderates.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'moderator' AND p.code IN ('reviews.archive','reports.create');

-- Content Editor owns the marketing surface end to end.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code = 'editor' AND p.code IN ('emails.view','emails.manage');

-- Support and Analyst work leads, so they get the export action.
INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p
WHERE r.code IN ('support','analyst') AND p.code IN ('leads.export');


-- -----------------------------------------------------------------------------
-- 4 · Verification
--
-- Uncomment to check the result after applying:
--
--   SELECT domain, COUNT(*) FROM permissions GROUP BY domain ORDER BY domain;
--   -- expect 141 rows total: the original 26 plus 115 new. The catalog holds 120
--   -- ids, five of which already existed as coarse codes, so 115 are added.
--
--   SELECT r.code, COUNT(*) AS granted
--     FROM roles r JOIN role_permissions rp ON rp.role_id = r.id
--    WHERE r.scope = 'platform' GROUP BY r.code ORDER BY granted DESC;
--
--   -- Any matrix id still missing a row would show here:
--   SELECT 'listings.cars.view' AS code
--    WHERE NOT EXISTS (SELECT 1 FROM permissions WHERE code = 'listings.cars.view');
-- =============================================================================

-- Record the migration.
--
-- Every other file in this directory ends with this line; these five did not, so the five
-- changes they make were applied to the database while `schema_migrations` went on reporting
-- the schema as five versions older than it is. Anything that reads the ledger to decide what
-- to run — a deployment, a restore, a new environment — would conclude these were outstanding.
-- Idempotent, so re-applying the file re-asserts the row rather than failing on it.
INSERT INTO schema_migrations (version, name) VALUES ('0031', 'admin_permission_catalog')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
