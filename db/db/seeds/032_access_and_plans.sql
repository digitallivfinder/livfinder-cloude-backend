-- =============================================================================
-- Liv Finder — seed 032 · Account types, RBAC, plans and templates
-- =============================================================================
-- The five account types the audit named (personal, lister, company,
-- organization, partner), the transitions permitted between them, the platform
-- staff role model, subscription plans, and notification templates.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Account types
--
-- `supports_members` is the flag that makes the owner/manager/agent/viewer role
-- model meaningful: only types with it can have more than one person acting for
-- them, so only they need roles.
-- -----------------------------------------------------------------------------
INSERT INTO account_types
  (id, code, name, description, supports_members, requires_organization, requires_verification, can_list, default_listing_quota, sort_order) VALUES
  (1, 'personal',     'Personal',
      'A private individual browsing, saving and enquiring. Cannot publish listings.',
      0, 0, 0, 0, 0, 1),
  (2, 'lister',       'Private Lister',
      'An individual selling their own property, car, yacht or watch. One person, a small quota, no team.',
      0, 0, 1, 1, 3, 2),
  (3, 'company',      'Company',
      'A small brokerage or dealership. Has a public profile and a handful of agents.',
      1, 1, 1, 1, 50, 3),
  (4, 'organization', 'Organization',
      'A multi-branch agency or group. Full team management, branches, category access and API.',
      1, 1, 1, 1, 500, 4),
  (5, 'partner',      'Partner',
      'A developer, marketing or service partner. Publishes projects and campaigns rather than resale inventory.',
      1, 1, 1, 1, 200, 5);

-- Which conversions are allowed, and what each requires.
--
-- Upward moves need documents and review; downward moves are permitted but carry
-- a warning, because they orphan team members and reduce quota. Personal -> any
-- listing type always requires verification: that is the point of the gate.
INSERT INTO account_type_transitions (from_type_id, to_type_id, is_allowed, requires_approval, requires_documents, notice) VALUES
  (1, 2, 1, 1, 1, 'You will need to verify your identity before you can publish.'),
  (1, 3, 1, 1, 1, 'Requires a valid trade licence and, in regulated markets, a brokerage registration.'),
  (1, 4, 1, 1, 1, 'Requires a trade licence, brokerage registration and proof of authority to act for the organisation.'),
  (1, 5, 1, 1, 1, 'Partner accounts are reviewed individually. Expect to supply company documents and a commercial contact.'),
  (2, 3, 1, 1, 1, 'Your existing listings transfer to the company. You become its owner.'),
  (2, 4, 1, 1, 1, 'Your existing listings transfer to the organisation. You become its owner.'),
  (2, 1, 1, 0, 0, 'Your live listings will be unpublished and your quota removed. Saved searches and favourites are kept.'),
  (3, 4, 1, 1, 1, 'Upgrades your team limits, adds branches and API access. Existing listings and leads are unaffected.'),
  (3, 5, 1, 1, 1, 'Partner accounts publish projects rather than resale inventory. Existing listings stay but new ones follow partner rules.'),
  (3, 2, 1, 1, 0, 'All team members except the owner lose access. Listings above the private-lister quota will be unpublished.'),
  (4, 3, 1, 1, 0, 'Branches beyond the first are archived and team members above the company limit lose access.'),
  (4, 5, 1, 1, 1, 'Existing listings stay but new ones follow partner rules.'),
  (5, 4, 1, 1, 1, 'Converts a partner into a full listing organisation.'),
  -- Explicitly disallowed: an organisation cannot collapse straight to a
  -- personal account without first shedding its team and inventory.
  (4, 1, 0, 1, 0, 'Downgrade to a company or private lister first.'),
  (5, 1, 0, 1, 0, 'Downgrade to an organisation first.'),
  (3, 1, 0, 1, 0, 'Downgrade to a private lister first.');

-- -----------------------------------------------------------------------------
-- Permissions and platform roles
-- -----------------------------------------------------------------------------
INSERT INTO permissions (id, code, name, domain, description) VALUES
  (1,  'listings.view',        'View all listings',        'listings',   'See every listing regardless of owner or status.'),
  (2,  'listings.moderate',    'Moderate listings',        'listings',   'Approve, reject, flag and unpublish listings.'),
  (3,  'listings.edit',        'Edit any listing',         'listings',   'Change listing content on behalf of an owner.'),
  (4,  'listings.delete',      'Delete listings',          'listings',   'Soft-delete any listing.'),
  (5,  'listings.feature',     'Feature listings',         'listings',   'Grant or revoke featured placement.'),
  (10, 'users.view',           'View users',               'users',      'See user records and account membership.'),
  (11, 'users.edit',           'Edit users',               'users',      'Change user details and status.'),
  (12, 'users.suspend',        'Suspend users',            'users',      'Suspend or ban a user account.'),
  (13, 'users.impersonate',    'Impersonate users',        'users',      'Assume a user identity for support. Always audit-logged.'),
  (14, 'accounts.verify',      'Verify accounts',          'users',      'Approve or reject account and organisation verification.'),
  (15, 'accounts.type_change', 'Approve type changes',     'users',      'Approve account type change requests.'),
  (20, 'moderation.queue',     'Work moderation queue',    'moderation', 'Triage and action the moderation queue.'),
  (21, 'reports.view',         'View reports',             'moderation', 'See user-submitted content reports.'),
  (22, 'reports.resolve',      'Resolve reports',          'moderation', 'Resolve, dismiss and escalate reports.'),
  (30, 'finance.view',         'View finance',             'finance',    'See invoices, payments, payouts and the ledger.'),
  (31, 'finance.refund',       'Issue refunds',            'finance',    'Refund a payment.'),
  (32, 'finance.payout',       'Approve payouts',          'finance',    'Approve and release partner payouts.'),
  (33, 'finance.plans',        'Manage plans',             'finance',    'Create and change subscription plans and pricing.'),
  (40, 'content.publish',      'Publish content',          'content',    'Publish articles, pages and landing pages.'),
  (41, 'content.edit',         'Edit content',             'content',    'Create and edit editorial content.'),
  (42, 'taxonomy.manage',      'Manage taxonomy',          'content',    'Manage categories, attributes and features.'),
  (43, 'locations.manage',     'Manage locations',         'content',    'Manage the country/state/city/community hierarchy.'),
  (50, 'settings.manage',      'Manage settings',          'system',     'Change platform settings and feature flags.'),
  (51, 'system.logs',          'View system logs',         'system',     'Read application and audit logs.'),
  (52, 'api.manage',           'Manage API access',        'system',     'Issue and revoke API clients and webhooks.'),
  (53, 'analytics.view',       'View analytics',           'system',     'See platform-wide analytics and reports.');

INSERT INTO roles (id, code, name, description, scope, is_system, sort_order) VALUES
  (1, 'super_admin',  'Super Administrator', 'Unrestricted access. Reserved for platform owners.',              'platform', 1, 1),
  (2, 'admin',        'Administrator',       'Day-to-day platform administration except finance and settings.', 'platform', 1, 2),
  (3, 'moderator',    'Moderator',           'Listing moderation, reports and verification.',                   'platform', 1, 3),
  (4, 'support',      'Support Agent',       'Read-only across the platform plus user support actions.',         'platform', 1, 4),
  (5, 'finance',      'Finance',             'Invoices, payments, refunds and payouts.',                        'platform', 1, 5),
  (6, 'editor',       'Content Editor',      'Editorial content, landing pages and taxonomy.',                  'platform', 1, 6),
  (7, 'analyst',      'Analyst',             'Read-only analytics and reporting.',                              'platform', 1, 7);

-- Super admin gets everything.
INSERT INTO role_permissions (role_id, permission_id) SELECT 1, id FROM permissions;
-- Admin: everything except refunds, payouts, plan pricing and settings.
INSERT INTO role_permissions (role_id, permission_id)
SELECT 2, id FROM permissions WHERE code NOT IN ('finance.refund','finance.payout','finance.plans','settings.manage');
INSERT INTO role_permissions (role_id, permission_id) VALUES
  (3, 1), (3, 2), (3, 4), (3, 10), (3, 12), (3, 14), (3, 20), (3, 21), (3, 22),
  (4, 1), (4, 10), (4, 11), (4, 13), (4, 21), (4, 30), (4, 51),
  (5, 30), (5, 31), (5, 32), (5, 33), (5, 10), (5, 53),
  (6, 40), (6, 41), (6, 42), (6, 43), (6, 1),
  (7, 53), (7, 1), (7, 10), (7, 30);

-- -----------------------------------------------------------------------------
-- Subscription plans
-- -----------------------------------------------------------------------------
INSERT INTO plans
  (id, public_id, code, name, slug, description, audience, tier, billing_interval, trial_days,
   listing_quota, featured_quota, agent_seat_quota, lead_quota, is_active, is_public, is_default, sort_order) VALUES
  (1, '01K2F5A0000000000000000001', 'free',            'Free',            'free',
      'Browse, save and enquire. No listing capability.', 'personal', 0, 'monthly', 0,
      0, 0, 0, 0, 1, 1, 1, 1),
  (2, '01K2F5A0000000000000000002', 'lister_starter',  'Lister Starter',  'lister-starter',
      'For private sellers. Three concurrent listings and standard placement.', 'lister', 1, 'monthly', 14,
      3, 0, 1, 0, 1, 1, 0, 2),
  (3, '01K2F5A0000000000000000003', 'lister_plus',     'Lister Plus',     'lister-plus',
      'Ten listings, one featured slot and verified-seller badging.', 'lister', 2, 'monthly', 14,
      10, 1, 1, 0, 1, 1, 0, 3),
  (4, '01K2F5A0000000000000000004', 'agency_essential','Agency Essential','agency-essential',
      'For small brokerages: 50 listings, 5 agent seats, lead inbox and basic analytics.', 'company', 3, 'monthly', 30,
      50, 3, 5, 0, 1, 1, 0, 4),
  (5, '01K2F5A0000000000000000005', 'agency_growth',   'Agency Growth',   'agency-growth',
      '200 listings, 20 seats, featured placement, saved-search alerts and full analytics.', 'company', 4, 'monthly', 30,
      200, 15, 20, 0, 1, 1, 0, 5),
  (6, '01K2F5A0000000000000000006', 'enterprise',      'Enterprise',      'enterprise',
      'Unlimited listings, unlimited seats, multi-branch, API access and a dedicated manager.', 'organization', 5, 'yearly', 0,
      0, 100, 0, 0, 1, 1, 0, 6),
  (7, '01K2F5A0000000000000000007', 'partner',         'Partner',         'partner',
      'For developers and service partners: project listings, campaign placement and co-branded content.', 'partner', 5, 'yearly', 0,
      200, 50, 25, 0, 1, 0, 0, 7);

INSERT INTO plan_prices (plan_id, currency_code, amount, setup_fee) VALUES
  (2, 'AED',   299.00, 0), (2, 'USD',    82.00, 0), (2, 'EUR',    75.00, 0), (2, 'GBP',    64.00, 0),
  (3, 'AED',   799.00, 0), (3, 'USD',   218.00, 0), (3, 'EUR',   200.00, 0), (3, 'GBP',   171.00, 0),
  (4, 'AED',  2499.00, 0), (4, 'USD',   680.00, 0), (4, 'EUR',   627.00, 0), (4, 'GBP',   535.00, 0),
  (5, 'AED',  7499.00, 0), (5, 'USD',  2041.00, 0), (5, 'EUR',  1882.00, 0), (5, 'GBP',  1605.00, 0),
  (6, 'AED', 149000.00, 5000.00), (6, 'USD', 40565.00, 1361.00), (6, 'EUR', 37399.00, 1255.00),
  (7, 'AED',  89000.00, 2500.00), (7, 'USD', 24230.00,  681.00), (7, 'EUR', 22339.00,  628.00);

INSERT INTO plan_features (plan_id, feature_key, label, value, is_included, is_highlighted, sort_order) VALUES
  (1, 'saved_searches',  'Saved searches',            '5',         1, 0, 1),
  (1, 'favourites',      'Favourites',                'Unlimited', 1, 0, 2),
  (1, 'alerts',          'Email alerts',              'Daily',     1, 0, 3),
  (1, 'listings',        'Publish listings',          NULL,        0, 0, 4),
  (2, 'listings',        'Concurrent listings',       '3',         1, 1, 1),
  (2, 'photos',          'Photos per listing',        '20',        1, 0, 2),
  (2, 'verified_badge',  'Verified seller badge',     NULL,        1, 0, 3),
  (2, 'featured',        'Featured placement',        NULL,        0, 0, 4),
  (3, 'listings',        'Concurrent listings',       '10',        1, 1, 1),
  (3, 'featured',        'Featured slots',            '1',         1, 1, 2),
  (3, 'photos',          'Photos per listing',        '40',        1, 0, 3),
  (3, 'analytics',       'Listing analytics',         'Basic',     1, 0, 4),
  (4, 'listings',        'Concurrent listings',       '50',        1, 1, 1),
  (4, 'seats',           'Agent seats',               '5',         1, 1, 2),
  (4, 'featured',        'Featured slots',            '3',         1, 0, 3),
  (4, 'leads',           'Lead inbox & assignment',   NULL,        1, 0, 4),
  (4, 'analytics',       'Analytics',                 'Standard',  1, 0, 5),
  (5, 'listings',        'Concurrent listings',       '200',       1, 1, 1),
  (5, 'seats',           'Agent seats',               '20',        1, 1, 2),
  (5, 'featured',        'Featured slots',            '15',        1, 1, 3),
  (5, 'analytics',       'Analytics',                 'Full',      1, 0, 4),
  (5, 'alerts',          'Saved-search alert placement', NULL,     1, 0, 5),
  (6, 'listings',        'Concurrent listings',       'Unlimited', 1, 1, 1),
  (6, 'seats',           'Agent seats',               'Unlimited', 1, 1, 2),
  (6, 'branches',        'Multiple branches',         NULL,        1, 1, 3),
  (6, 'api',             'API access & webhooks',     NULL,        1, 1, 4),
  (6, 'manager',         'Dedicated account manager', NULL,        1, 0, 5),
  (7, 'projects',        'Project listings',          'Unlimited', 1, 1, 1),
  (7, 'campaigns',       'Campaign placement',        NULL,        1, 1, 2),
  (7, 'content',         'Co-branded editorial',      NULL,        1, 0, 3);

-- -----------------------------------------------------------------------------
-- Notification templates
-- -----------------------------------------------------------------------------
INSERT INTO notification_templates (code, name, channel, subject, body_text, variables, is_transactional) VALUES
  ('inquiry_received',    'New enquiry received',       'email', 'New enquiry for {{listing.title}}',
   'You have a new enquiry from {{inquiry.name}} about {{listing.title}} ({{listing.reference}}).',
   JSON_ARRAY('listing.title','listing.reference','inquiry.name','inquiry.message'), 1),
  ('inquiry_received',    'New enquiry received',       'push',  NULL,
   'New enquiry from {{inquiry.name}}',
   JSON_ARRAY('inquiry.name'), 1),
  ('listing_approved',    'Listing approved',           'email', 'Your listing is live',
   '{{listing.title}} has been approved and is now live at {{listing.url}}.',
   JSON_ARRAY('listing.title','listing.url'), 1),
  ('listing_rejected',    'Listing rejected',           'email', 'Your listing needs attention',
   '{{listing.title}} was not approved. Reason: {{listing.rejection_reason}}.',
   JSON_ARRAY('listing.title','listing.rejection_reason'), 1),
  ('listing_expiring',    'Listing expiring soon',      'email', 'Your listing expires in {{days}} days',
   '{{listing.title}} expires on {{listing.expires_at}}. Refresh it to keep it live.',
   JSON_ARRAY('listing.title','listing.expires_at','days'), 1),
  ('saved_search_alert',  'New matches for your search','email', '{{count}} new matches for "{{search.name}}"',
   'We found {{count}} new listings matching {{search.name}}.',
   JSON_ARRAY('search.name','count','search.url'), 0),
  ('price_drop',          'Price reduced',              'email', 'Price reduced on a saved listing',
   '{{listing.title}} has been reduced by {{change.percentage}}% to {{listing.price}}.',
   JSON_ARRAY('listing.title','listing.price','change.percentage'), 0),
  ('booking_confirmed',   'Viewing confirmed',          'email', 'Your viewing is confirmed',
   'Your {{booking.type}} for {{listing.title}} is confirmed for {{booking.scheduled_start}}.',
   JSON_ARRAY('booking.type','booking.scheduled_start','listing.title'), 1),
  ('booking_reminder',    'Viewing reminder',           'whatsapp', NULL,
   'Reminder: your viewing of {{listing.title}} is tomorrow at {{booking.time}}.',
   JSON_ARRAY('listing.title','booking.time'), 1),
  ('offer_received',      'Offer received',             'email', 'New offer on {{listing.title}}',
   '{{offer.buyer_name}} has offered {{offer.amount}} for {{listing.title}}.',
   JSON_ARRAY('listing.title','offer.amount','offer.buyer_name'), 1),
  ('offer_response',      'Offer response',             'email', 'Your offer has been {{offer.status}}',
   'Your offer of {{offer.amount}} for {{listing.title}} has been {{offer.status}}.',
   JSON_ARRAY('listing.title','offer.amount','offer.status'), 1),
  ('verification_approved','Verification approved',     'email', 'You are verified',
   'Your {{subject.type}} verification has been approved.',
   JSON_ARRAY('subject.type'), 1),
  ('account_type_changed','Account type changed',       'email', 'Your account type has changed',
   'Your account has been converted from {{from.name}} to {{to.name}}.',
   JSON_ARRAY('from.name','to.name'), 1),
  ('invoice_issued',      'Invoice issued',             'email', 'Invoice {{invoice.number}}',
   'Invoice {{invoice.number}} for {{invoice.total}} is due on {{invoice.due_at}}.',
   JSON_ARRAY('invoice.number','invoice.total','invoice.due_at'), 1),
  ('payment_failed',      'Payment failed',             'email', 'We could not process your payment',
   'Payment of {{payment.amount}} failed. Please update your payment method.',
   JSON_ARRAY('payment.amount'), 1),
  ('payout_sent',         'Payout sent',                'email', 'Payout {{payout.reference}} sent',
   '{{payout.net_amount}} has been sent to your account ending {{payout.last_four}}.',
   JSON_ARRAY('payout.reference','payout.net_amount','payout.last_four'), 1),
  ('welcome',             'Welcome to Liv Finder',      'email', 'Welcome to Liv Finder',
   'Welcome {{user.first_name}}. Confirm your email to get started.',
   JSON_ARRAY('user.first_name','verification.url'), 1),
  ('password_reset',      'Reset your password',        'email', 'Reset your Liv Finder password',
   'Use this link to reset your password. It expires in 60 minutes: {{reset.url}}',
   JSON_ARRAY('reset.url'), 1),
  ('report_resolved',     'Report resolved',            'email', 'Update on your report',
   'Your report {{report.reference}} has been reviewed. Outcome: {{report.resolution}}.',
   JSON_ARRAY('report.reference','report.resolution'), 1);

-- -----------------------------------------------------------------------------
-- Navigation
-- -----------------------------------------------------------------------------
INSERT INTO navigation_menus (id, code, name, location) VALUES
  (1, 'main_header', 'Main header', 'header'),
  (2, 'footer_explore', 'Footer — Explore', 'footer'),
  (3, 'footer_company', 'Footer — Company', 'footer'),
  (4, 'footer_legal', 'Footer — Legal', 'legal');

INSERT INTO menu_items (menu_id, parent_id, label, url, target_type, sort_order) VALUES
  (1, NULL, 'Real Estate',  '/real-estate',  'url', 1),
  (1, NULL, 'Cars',         '/cars',         'url', 2),
  (1, NULL, 'Yachts',       '/yachts',       'url', 3),
  (1, NULL, 'Jets',         '/jets',         'url', 4),
  (1, NULL, 'Helicopters',  '/helicopters',  'url', 5),
  (1, NULL, 'Watches',      '/watches',      'url', 6),
  (1, NULL, 'Agencies',     '/companies',    'url', 7),
  (1, NULL, 'Agents',       '/agents',       'url', 8),
  (1, NULL, 'Magazine',     '/magazine',     'url', 9),
  (2, NULL, 'Property for sale in Dubai', '/real-estate/for-sale/uae/dubai', 'url', 1),
  (2, NULL, 'Villas in Palm Jumeirah',    '/real-estate/villas/uae/dubai/palm-jumeirah', 'url', 2),
  (2, NULL, 'Supercars for sale',         '/cars/supercars', 'url', 3),
  (2, NULL, 'Yachts for charter',         '/yachts/for-charter', 'url', 4),
  (2, NULL, 'Private jets for sale',      '/jets/for-sale', 'url', 5),
  (3, NULL, 'About',    '/about',    'page', 1),
  (3, NULL, 'Careers',  '/careers',  'page', 2),
  (3, NULL, 'Press',    '/press',    'page', 3),
  (3, NULL, 'Contact',  '/contact',  'page', 4),
  (3, NULL, 'Advertise','/advertise','page', 5),
  (4, NULL, 'Terms of Service',  '/legal/terms',    'page', 1),
  (4, NULL, 'Privacy Policy',    '/legal/privacy',  'page', 2),
  (4, NULL, 'Cookie Policy',     '/legal/cookies',  'page', 3),
  (4, NULL, 'Listing Guidelines','/legal/listing-guidelines', 'page', 4);
