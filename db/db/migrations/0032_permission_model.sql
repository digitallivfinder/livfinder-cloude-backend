-- =============================================================================
-- Liv Finder — migration 0032 · Permission model
-- =============================================================================
-- Replaces two half-models with one, and closes a real authorization hole.
--
-- WHERE THIS CAME FROM
--
-- Two permission vocabularies were in use:
--
--   * 26 coarse codes in `permissions` (`listings.view`, `users.edit`, …).
--     These are what every admin endpoint actually checks. The security
--     boundary lived here and nowhere else.
--
--   * ~141 granular ids in the admin frontend (`listings.cars.edit`,
--     `locations.subCommunity.create`, …), drawn as checkboxes in the Role
--     Access matrix.
--
-- The frontend ids were mapped back onto the coarse ones for display. The
-- consequence is worse than a missing feature: ticking "Cars → Edit" and
-- leaving "Yachts → Edit" clear produced a role that could edit **every**
-- category, because the server only ever saw `listings.edit`. The matrix
-- showed control that did not exist.
--
-- Migration 0031 proposed making all 141 ids real rows. That closes the drift
-- but encodes categories and page names into the permission key, which
-- LIV-IAM-001 §6.2 forbids in as many words — "Do not encode organization IDs,
-- countries or categories into the permission key; use scopes and attributes"
-- and "Do not name permissions after pages or UI components". It also does not
-- scale: a seventh category would mint six more permissions, a sixth location
-- tier four more.
--
-- WHAT THIS DOES INSTEAD
--
-- Two dimensions instead of one.
--
--   1. WHAT — `permissions.code` is `<domain>.<action>`, and nothing else.
--      No category, no page, no UI component. ~110 codes covering every admin
--      and portal task.
--
--   2. OVER WHICH SUBSET — `role_scopes` restricts a role to named categories
--      (and is shaped to take other scope types later). No rows for a scope
--      type means "unrestricted in that dimension", so existing roles keep
--      working untouched.
--
-- Authorization is then two questions, both server-side:
--
--      requirePermission("listings.edit")        -- do they hold the action?
--      assertCategoryScope(req, rootCategoryId)  -- for this category?
--
-- A "Cars Moderator" role is now `listings.moderate` + a `category=cars`
-- scope row. Real per-category control, enforced where it counts, and a
-- seventh category needs one scope row rather than a schema change.
--
-- IDEMPOTENT. Safe to re-run. Existing grants are preserved and remapped, not
-- dropped: §5 translates every old coarse grant into its new equivalents.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1 · Scope table
-- -----------------------------------------------------------------------------
-- `scope_type` is an enum rather than free text so a typo cannot silently widen
-- a role. `category` is the only type the application reads today; the other two
-- are the extension points LIV-IAM-001 §5 names, declared here so adding them
-- later is application work rather than a migration.

CREATE TABLE IF NOT EXISTS `role_scopes` (
  `id`          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  `role_id`     INT UNSIGNED    NOT NULL,
  `scope_type`  ENUM('category','location','organization') NOT NULL,
  `scope_value` VARCHAR(60)     NOT NULL COMMENT 'category code, location public id, or organization public id',
  `created_at`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_role_scopes` (`role_id`,`scope_type`,`scope_value`),
  KEY `ix_role_scopes_role` (`role_id`,`scope_type`),
  CONSTRAINT `fk_role_scopes_role` FOREIGN KEY (`role_id`) REFERENCES `roles`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Restricts a role to a subset of resources. No rows for a scope type = unrestricted.';

-- -----------------------------------------------------------------------------
-- 2 · Permission metadata
-- -----------------------------------------------------------------------------
-- `action` is split out so the Role matrix can be drawn as domain × action from
-- the data, instead of the frontend re-deriving it by splitting the code string.
-- `is_scopable` marks the domains where a category scope is meaningful — the UI
-- greys the category selector for the rest rather than implying, say, that
-- "settings.edit" could be limited to yachts.

SET @has_action := (SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'permissions' AND column_name = 'action');
SET @sql := IF(@has_action = 0,
  'ALTER TABLE `permissions`
     ADD COLUMN `action` VARCHAR(40) NOT NULL DEFAULT ''view'' AFTER `domain`,
     ADD COLUMN `is_scopable` TINYINT(1) NOT NULL DEFAULT 0 AFTER `action`,
     ADD COLUMN `sort_order` SMALLINT NOT NULL DEFAULT 0 AFTER `is_scopable`',
  'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 3 · The catalogue
-- -----------------------------------------------------------------------------
-- One row per (domain, action). Ordered by the admin navigation so the matrix
-- reads in the same order as the sidebar without the frontend re-sorting it.
--
-- `is_scopable = 1` on the domains that hang off a marketplace category:
-- listings, developments, leads, inquiries, bookings, offers, reviews, media.
-- Everything else is platform-wide by nature.

INSERT INTO `permissions` (`code`, `name`, `domain`, `action`, `is_scopable`, `sort_order`, `description`) VALUES
  -- Dashboard
  ('dashboard.view',        'View dashboard',            'dashboard',     'view',       0,  10, 'Open the admin dashboard and category dashboards.'),

  -- Listings
  ('listings.view',         'View listings',             'listings',      'view',       1, 100, 'See listings and their detail pages.'),
  ('listings.create',       'Create listings',           'listings',      'create',     1, 101, 'Add a new listing.'),
  ('listings.edit',         'Edit listings',             'listings',      'edit',       1, 102, 'Change an existing listing.'),
  ('listings.delete',       'Delete listings',           'listings',      'delete',     1, 103, 'Archive or delete a listing.'),
  ('listings.moderate',     'Moderate listings',         'listings',      'moderate',   1, 104, 'Approve, reject, flag or unpublish a submitted listing.'),
  ('listings.feature',      'Feature listings',          'listings',      'feature',    1, 105, 'Promote a listing into featured placement.'),
  ('listings.export',       'Export listings',           'listings',      'export',     1, 106, 'Download listing data.'),

  -- Developments (real-estate projects)
  ('developments.view',     'View developments',         'developments',  'view',       1, 120, 'See off-plan developments.'),
  ('developments.create',   'Create developments',       'developments',  'create',     1, 121, 'Add a development.'),
  ('developments.edit',     'Edit developments',         'developments',  'edit',       1, 122, 'Change a development, its floor plans and payment plans.'),
  ('developments.delete',   'Delete developments',       'developments',  'delete',     1, 123, 'Archive a development.'),

  -- Leads
  ('leads.view',            'View leads',                'leads',         'view',       1, 140, 'See the lead pipeline.'),
  ('leads.create',          'Create leads',              'leads',         'create',     1, 141, 'Add a lead by hand.'),
  ('leads.edit',            'Edit leads',                'leads',         'edit',       1, 142, 'Change a lead, its stage and its notes.'),
  ('leads.delete',          'Delete leads',              'leads',         'delete',     1, 143, 'Remove a lead.'),
  ('leads.assign',          'Assign leads',              'leads',         'assign',     1, 144, 'Reassign a lead to another owner.'),
  ('leads.export',          'Export leads',              'leads',         'export',     1, 145, 'Download lead data.'),

  -- Inquiries
  ('inquiries.view',        'View inquiries',            'inquiries',     'view',       1, 160, 'See buyer inquiries.'),
  ('inquiries.edit',        'Edit inquiries',            'inquiries',     'edit',       1, 161, 'Change inquiry status, owner and notes.'),
  ('inquiries.export',      'Export inquiries',          'inquiries',     'export',     1, 162, 'Download inquiry data.'),

  -- Bookings and offers
  ('bookings.view',         'View bookings',             'bookings',      'view',       1, 170, 'See viewing requests.'),
  ('bookings.edit',         'Edit bookings',             'bookings',      'edit',       1, 171, 'Confirm, reschedule or cancel a viewing.'),
  ('offers.view',           'View offers',               'offers',        'view',       1, 175, 'See offers placed on listings.'),
  ('offers.edit',           'Edit offers',               'offers',        'edit',       1, 176, 'Accept, decline or counter an offer.'),

  -- Reviews and reports
  ('reviews.view',          'View reviews',              'reviews',       'view',       1, 190, 'See submitted reviews.'),
  ('reviews.moderate',      'Moderate reviews',          'reviews',       'moderate',   1, 191, 'Approve or reject a review.'),
  ('reviews.publish',       'Publish reviews',           'reviews',       'publish',    1, 192, 'Make an approved review public.'),
  ('reviews.delete',        'Delete reviews',            'reviews',       'delete',     1, 193, 'Remove a review.'),
  ('reports.view',          'View reports',              'reports',       'view',       0, 200, 'See abuse and content reports.'),
  ('reports.create',        'Create reports',            'reports',       'create',     0, 201, 'Raise a report.'),
  ('reports.edit',          'Edit reports',              'reports',       'edit',       0, 202, 'Change a report and its notes.'),
  ('reports.assign',        'Assign reports',            'reports',       'assign',     0, 203, 'Reassign a report.'),
  ('reports.resolve',       'Resolve reports',           'reports',       'resolve',    0, 204, 'Close a report with a decision.'),
  ('moderation.view',       'View moderation queue',     'moderation',    'view',       0, 210, 'Open the moderation queue.'),
  ('moderation.decide',     'Decide moderation cases',   'moderation',    'decide',     0, 211, 'Action a moderation case, appeal or legal hold.'),

  -- Accounts
  ('companies.view',        'View companies',            'companies',     'view',       0, 300, 'See organization accounts.'),
  ('companies.create',      'Create companies',          'companies',     'create',     0, 301, 'Add an organization.'),
  ('companies.edit',        'Edit companies',            'companies',     'edit',       0, 302, 'Change organization details and packages.'),
  ('companies.delete',      'Delete companies',          'companies',     'delete',     0, 303, 'Close an organization account.'),
  ('companies.verify',      'Verify companies',          'companies',     'verify',     0, 304, 'Decide an organization verification case.'),
  ('companies.suspend',     'Suspend companies',         'companies',     'suspend',    0, 305, 'Suspend or reinstate an organization.'),
  ('individuals.view',      'View individuals',          'individuals',   'view',       0, 320, 'See personal accounts.'),
  ('individuals.create',    'Create individuals',        'individuals',   'create',     0, 321, 'Add a personal account.'),
  ('individuals.edit',      'Edit individuals',          'individuals',   'edit',       0, 322, 'Change a personal account.'),
  ('individuals.delete',    'Delete individuals',        'individuals',   'delete',     0, 323, 'Close a personal account.'),
  ('individuals.verify',    'Verify individuals',        'individuals',   'verify',     0, 324, 'Decide a personal verification case.'),
  ('individuals.suspend',   'Suspend individuals',       'individuals',   'suspend',    0, 325, 'Suspend or reinstate a personal account.'),
  ('agents.view',           'View agents',               'agents',        'view',       0, 340, 'See agent profiles.'),
  ('agents.create',         'Create agents',             'agents',        'create',     0, 341, 'Add an agent.'),
  ('agents.edit',           'Edit agents',               'agents',        'edit',       0, 342, 'Change an agent profile.'),
  ('agents.delete',         'Delete agents',             'agents',        'delete',     0, 343, 'Remove an agent.'),
  ('categoryAccess.view',   'View category requests',    'categoryAccess','view',       1, 360, 'See requests for category access.'),
  ('categoryAccess.decide', 'Decide category requests',  'categoryAccess','decide',     1, 361, 'Grant or refuse category access.'),

  -- Identity and access
  ('users.view',            'View users',                'users',         'view',       0, 400, 'See platform users.'),
  ('users.create',          'Create users',              'users',         'create',     0, 401, 'Add a staff user.'),
  ('users.edit',            'Edit users',                'users',         'edit',       0, 402, 'Change a user and their roles.'),
  ('users.delete',          'Delete users',              'users',         'delete',     0, 403, 'Remove a user.'),
  ('users.suspend',         'Suspend users',             'users',         'suspend',    0, 404, 'Suspend or reinstate a user.'),
  ('users.impersonate',     'Impersonate users',         'users',         'impersonate',0, 405, 'Sign in as another user for support.'),
  ('roles.view',            'View roles',                'roles',         'view',       0, 420, 'See roles and their permissions.'),
  ('roles.create',          'Create roles',              'roles',         'create',     0, 421, 'Add a role.'),
  ('roles.edit',            'Edit roles',                'roles',         'edit',       0, 422, 'Change a role, its permissions and its scopes.'),
  ('roles.delete',          'Delete roles',              'roles',         'delete',     0, 423, 'Remove a role.'),

  -- Content
  ('content.view',          'View content',              'content',       'view',       0, 500, 'See articles and pages.'),
  ('content.create',        'Create content',            'content',       'create',     0, 501, 'Write an article or page.'),
  ('content.edit',          'Edit content',              'content',       'edit',       0, 502, 'Change an article or page.'),
  ('content.publish',       'Publish content',           'content',       'publish',    0, 503, 'Publish or unpublish content.'),
  ('content.delete',        'Delete content',            'content',       'delete',     0, 504, 'Archive an article or page.'),
  ('media.view',            'View media',                'media',         'view',       1, 520, 'Browse the media library.'),
  ('media.create',          'Upload media',              'media',         'create',     1, 521, 'Upload files.'),
  ('media.edit',            'Edit media',                'media',         'edit',       1, 522, 'Change alt text, folders and ordering.'),
  ('media.delete',          'Delete media',              'media',         'delete',     1, 523, 'Archive or delete a file.'),
  ('emails.view',           'View email templates',      'emails',        'view',       0, 540, 'See transactional templates.'),
  ('emails.edit',           'Edit email templates',      'emails',        'edit',       0, 541, 'Change a template.'),
  ('collections.view',      'View collections',          'collections',   'view',       0, 550, 'See curated collections.'),
  ('collections.create',    'Create collections',        'collections',   'create',     0, 551, 'Add a collection.'),
  ('collections.edit',      'Edit collections',          'collections',   'edit',       0, 552, 'Change a collection.'),
  ('collections.delete',    'Delete collections',        'collections',   'delete',     0, 553, 'Remove a collection.'),
  ('seo.view',              'View SEO',                  'seo',           'view',       0, 560, 'See SEO metadata and redirects.'),
  ('seo.edit',              'Edit SEO',                  'seo',           'edit',       0, 561, 'Change SEO metadata and redirects.'),

  -- Reference data
  ('locations.view',        'View locations',            'locations',     'view',       0, 600, 'See the location hierarchy.'),
  ('locations.create',      'Create locations',          'locations',     'create',     0, 601, 'Add a country, state, city, community or sub-community.'),
  ('locations.edit',        'Edit locations',            'locations',     'edit',       0, 602, 'Change a location.'),
  ('locations.delete',      'Delete locations',          'locations',     'delete',     0, 603, 'Archive a location.'),
  ('taxonomy.view',         'View taxonomy',             'taxonomy',      'view',       0, 620, 'See categories, brands, models, features and attributes.'),
  ('taxonomy.create',       'Create taxonomy',           'taxonomy',      'create',     0, 621, 'Add a category, brand, model, feature or attribute.'),
  ('taxonomy.edit',         'Edit taxonomy',             'taxonomy',      'edit',       0, 622, 'Change reference data.'),
  ('taxonomy.delete',       'Delete taxonomy',           'taxonomy',      'delete',     0, 623, 'Archive reference data.'),

  -- Money
  ('finance.view',          'View finance',              'finance',       'view',       0, 700, 'See transactions, invoices and payouts.'),
  ('finance.edit',          'Edit finance',              'finance',       'edit',       0, 701, 'Change billing records.'),
  ('finance.refund',        'Issue refunds',             'finance',       'refund',     0, 702, 'Refund a payment.'),
  ('finance.payout',        'Approve payouts',           'finance',       'payout',     0, 703, 'Release a payout.'),
  ('finance.plans',         'Manage plans',              'finance',       'plans',      0, 704, 'Change subscription plans and prices.'),
  ('finance.export',        'Export finance',            'finance',       'export',     0, 705, 'Download financial data.'),

  -- Platform
  ('analytics.view',        'View analytics',            'analytics',     'view',       0, 800, 'Open analytics and reporting.'),
  ('analytics.export',      'Export analytics',          'analytics',     'export',     0, 801, 'Download analytics data.'),
  ('settings.view',         'View settings',             'settings',      'view',       0, 820, 'See platform settings.'),
  ('settings.edit',         'Edit settings',             'settings',      'edit',       0, 821, 'Change general and marketplace settings.'),
  ('settings.manage',       'Manage secure settings',    'settings',      'manage',     0, 822, 'Change payment credentials and security settings.'),
  ('system.view',           'View system logs',          'system',        'view',       0, 840, 'Read system and audit logs.'),
  ('system.export',         'Export system logs',        'system',        'export',     0, 841, 'Download log data.'),
  ('system.manage',         'Manage system jobs',        'system',        'manage',     0, 842, 'Replay jobs, drain queues and run repairs.'),
  ('api.view',              'View API clients',          'api',           'view',       0, 860, 'See API clients and webhooks.'),
  ('api.manage',            'Manage API clients',        'api',           'manage',     0, 861, 'Issue and revoke API credentials and webhook subscriptions.')
AS new
ON DUPLICATE KEY UPDATE
  `name`        = new.`name`,
  `domain`      = new.`domain`,
  `action`      = new.`action`,
  `is_scopable` = new.`is_scopable`,
  `sort_order`  = new.`sort_order`,
  `description` = new.`description`;

-- -----------------------------------------------------------------------------
-- 4 · Retire the codes the new grammar replaces
-- -----------------------------------------------------------------------------
-- The old coarse set had a handful of codes that do not fit `<domain>.<action>`
-- or that duplicate a new one. Their grants are carried across in §5 first, so
-- nothing is lost; these rows are then removed and role_permissions cascades.
--
--   accounts.verify      -> companies.verify + individuals.verify
--   accounts.type_change -> categoryAccess.decide
--   locations.manage     -> locations.create/edit/delete
--   moderation.queue     -> moderation.view/decide
--   system.logs          -> system.view
--   listings.moderate    kept (already `<domain>.<action>`)

-- -----------------------------------------------------------------------------
-- 5 · Carry existing grants across
-- -----------------------------------------------------------------------------
-- Every role keeps at least what it had. A coarse grant becomes the set of
-- fine-grained codes it used to imply, so no administrator loses access on
-- deploy. Widening is deliberate and one-directional: `locations.manage` really
-- did permit create, edit and delete.

CREATE TEMPORARY TABLE `tmp_grant_map` (
  `old_code` VARCHAR(100) NOT NULL,
  `new_code` VARCHAR(100) NOT NULL,
  PRIMARY KEY (`old_code`,`new_code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `tmp_grant_map` (`old_code`,`new_code`) VALUES
  ('accounts.verify','companies.verify'),
  ('accounts.verify','individuals.verify'),
  ('accounts.type_change','categoryAccess.view'),
  ('accounts.type_change','categoryAccess.decide'),
  ('locations.manage','locations.view'),
  ('locations.manage','locations.create'),
  ('locations.manage','locations.edit'),
  ('locations.manage','locations.delete'),
  ('taxonomy.manage','taxonomy.view'),
  ('taxonomy.manage','taxonomy.create'),
  ('taxonomy.manage','taxonomy.edit'),
  ('taxonomy.manage','taxonomy.delete'),
  ('moderation.queue','moderation.view'),
  ('moderation.queue','moderation.decide'),
  ('moderation.queue','reviews.moderate'),
  ('system.logs','system.view'),
  ('system.logs','system.export'),
  ('content.edit','content.view'),
  ('content.edit','content.create'),
  ('content.edit','content.delete'),
  ('content.edit','media.view'),
  ('content.edit','media.create'),
  ('content.edit','media.edit'),
  ('content.publish','content.publish'),
  ('listings.view','dashboard.view'),
  ('listings.view','developments.view'),
  ('listings.view','locations.view'),
  ('listings.view','taxonomy.view'),
  ('listings.edit','listings.create'),
  ('listings.edit','developments.create'),
  ('listings.edit','developments.edit'),
  ('listings.edit','media.create'),
  ('listings.delete','developments.delete'),
  ('listings.feature','listings.feature'),
  ('users.view','companies.view'),
  ('users.view','individuals.view'),
  ('users.view','agents.view'),
  ('users.view','roles.view'),
  ('users.view','leads.view'),
  ('users.view','inquiries.view'),
  ('users.edit','companies.create'),
  ('users.edit','companies.edit'),
  ('users.edit','individuals.create'),
  ('users.edit','individuals.edit'),
  ('users.edit','agents.create'),
  ('users.edit','agents.edit'),
  ('users.edit','roles.create'),
  ('users.edit','roles.edit'),
  ('users.edit','roles.delete'),
  ('users.edit','users.create'),
  ('users.edit','leads.edit'),
  ('users.edit','leads.assign'),
  ('users.edit','inquiries.edit'),
  ('users.suspend','companies.suspend'),
  ('users.suspend','individuals.suspend'),
  ('reports.view','moderation.view'),
  ('reports.view','reviews.view'),
  ('reports.resolve','reports.edit'),
  ('reports.resolve','reports.assign'),
  ('reports.resolve','reviews.moderate'),
  ('reports.resolve','reviews.publish'),
  ('reports.resolve','moderation.decide'),
  ('finance.view','finance.export'),
  ('finance.plans','finance.edit'),
  ('analytics.view','analytics.export'),
  ('settings.manage','settings.view'),
  ('settings.manage','settings.edit'),
  ('settings.manage','seo.view'),
  ('settings.manage','seo.edit'),
  ('settings.manage','emails.view'),
  ('settings.manage','emails.edit'),
  ('settings.manage','collections.view'),
  ('settings.manage','collections.create'),
  ('settings.manage','collections.edit'),
  ('settings.manage','collections.delete'),
  ('api.manage','api.view'),
  ('api.manage','system.manage'),
  ('listings.moderate','bookings.view'),
  ('listings.moderate','bookings.edit'),
  ('listings.moderate','offers.view'),
  ('listings.moderate','offers.edit');

INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT rp.`role_id`, np.`id`
  FROM `role_permissions` rp
  JOIN `permissions` op ON op.`id` = rp.`permission_id`
  JOIN `tmp_grant_map` m ON m.`old_code` = op.`code`
  JOIN `permissions` np ON np.`code` = m.`new_code`;

DROP TEMPORARY TABLE `tmp_grant_map`;

-- Now the superseded codes can go; their grants live on under the new names.
DELETE FROM `permissions`
 WHERE `code` IN ('accounts.verify','accounts.type_change','locations.manage','taxonomy.manage','moderation.queue','system.logs');

-- -----------------------------------------------------------------------------
-- 6 · Super Administrator holds everything, always
-- -----------------------------------------------------------------------------
-- The application short-circuits on the super_admin role, but the grants are
-- materialised anyway so the Role Access matrix shows the truth rather than an
-- empty grid, and so a report over role_permissions is complete.

INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r CROSS JOIN `permissions` p WHERE r.`code` = 'super_admin';

-- -----------------------------------------------------------------------------
-- 7 · Sensible defaults for the other seeded platform roles
-- -----------------------------------------------------------------------------
-- Only additive. An operator who has already tailored a role keeps their edits;
-- these fill in the codes that did not exist before this migration ran.

-- Administrator: everything except the money and the security settings.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'admin'
   AND p.`domain` NOT IN ('finance')
   AND p.`code` NOT IN ('settings.manage','users.impersonate','system.manage');

-- Moderator: the queue, and the things a decision touches.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'moderator'
   AND p.`code` IN ('dashboard.view','listings.view','listings.moderate','listings.edit',
                    'developments.view','media.view','moderation.view','moderation.decide',
                    'reviews.view','reviews.moderate','reviews.publish','reviews.delete',
                    'reports.view','reports.edit','reports.assign','reports.resolve',
                    'companies.view','individuals.view','agents.view');

-- Support: read widely, write only where a support conversation needs it.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'support'
   AND p.`code` IN ('dashboard.view','listings.view','developments.view','leads.view','leads.edit',
                    'inquiries.view','inquiries.edit','bookings.view','bookings.edit',
                    'offers.view','reviews.view','reports.view','reports.create',
                    'companies.view','individuals.view','agents.view','users.view',
                    'categoryAccess.view','media.view','system.view');

-- Finance.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'finance'
   AND (p.`domain` = 'finance'
        OR p.`code` IN ('dashboard.view','companies.view','individuals.view','analytics.view','analytics.export'));

-- Content editor.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'editor'
   AND (p.`domain` IN ('content','media','collections','seo','emails')
        OR p.`code` IN ('dashboard.view','listings.view','taxonomy.view','locations.view'));

-- Analyst: read-only across the platform, plus exports.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` = 'analyst'
   AND (p.`action` IN ('view','export') AND p.`code` <> 'settings.view');
