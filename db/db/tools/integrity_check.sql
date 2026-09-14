-- =============================================================================
-- Liv Finder — integrity checks
-- =============================================================================
-- Checks the database cannot enforce for itself. Run nightly and after any bulk
-- import; every query must return 0.
--
-- Two categories:
--
--   1. POLYMORPHIC REFERENCES. `reports`, `reviews`, `verification_requests`,
--      `moderation_queue` and `notifications` all use (subject_type, subject_id)
--      so that one moderation queue can cover every kind of content. That is
--      worth the trade, but it means no foreign key protects them — these
--      queries are the replacement.
--
--   2. DERIVED STATE. Denormalised columns and maintained counters are correct
--      by construction only while the code that writes them is correct. These
--      queries detect drift rather than assuming its absence.
-- =============================================================================

SELECT '--- polymorphic references ---' AS check_group;

SELECT 'reports -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reports r
 WHERE r.subject_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = r.subject_id);

SELECT 'reports -> agent (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reports r
 WHERE r.subject_type = 'agent'
   AND NOT EXISTS (SELECT 1 FROM agents a WHERE a.id = r.subject_id);

SELECT 'reports -> organization (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reports r
 WHERE r.subject_type = 'organization'
   AND NOT EXISTS (SELECT 1 FROM organizations o WHERE o.id = r.subject_id);

SELECT 'reviews -> agent (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reviews v
 WHERE v.subject_type = 'agent'
   AND NOT EXISTS (SELECT 1 FROM agents a WHERE a.id = v.subject_id);

SELECT 'reviews -> organization (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reviews v
 WHERE v.subject_type = 'organization'
   AND NOT EXISTS (SELECT 1 FROM organizations o WHERE o.id = v.subject_id);

SELECT 'reviews -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM reviews v
 WHERE v.subject_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = v.subject_id);

SELECT 'verification_requests -> organization (orphaned)' AS check_name, COUNT(*) AS failures
  FROM verification_requests r
 WHERE r.subject_type = 'organization'
   AND NOT EXISTS (SELECT 1 FROM organizations o WHERE o.id = r.subject_id);

SELECT 'moderation_queue -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM moderation_queue m
 WHERE m.subject_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = m.subject_id);

SELECT '--- location tree ---' AS check_group;

SELECT 'non-country location without a parent' AS check_name, COUNT(*) AS failures
  FROM locations WHERE parent_id IS NULL AND level <> 'country';

SELECT 'location without a country ancestor' AS check_name, COUNT(*) AS failures
  FROM locations WHERE country_id IS NULL;

SELECT 'location depth disagrees with its path' AS check_name, COUNT(*) AS failures
  FROM locations
 WHERE depth <> (LENGTH(path) - LENGTH(REPLACE(path, '/', '')));

SELECT 'location missing its closure self-row' AS check_name, COUNT(*) AS failures
  FROM locations l
  LEFT JOIN location_closure c
    ON c.ancestor_id = l.id AND c.descendant_id = l.id AND c.depth = 0
 WHERE c.ancestor_id IS NULL;

SELECT 'closure edge count disagrees with tree depth' AS check_name, COUNT(*) AS failures
  FROM (SELECT l.id
          FROM locations l
          JOIN location_closure c ON c.descendant_id = l.id
         GROUP BY l.id, l.depth
        HAVING COUNT(*) <> l.depth + 1) x;

SELECT 'location is its own parent' AS check_name, COUNT(*) AS failures
  FROM locations WHERE parent_id = id;

SELECT '--- denormalised listing location chain ---' AS check_group;

SELECT 'listing.country_id disagrees with its location' AS check_name, COUNT(*) AS failures
  FROM listings l JOIN locations loc ON loc.id = l.location_id
 WHERE l.deleted_at IS NULL AND NOT (l.country_id <=> loc.country_id);

SELECT 'listing.city_id disagrees with its location' AS check_name, COUNT(*) AS failures
  FROM listings l JOIN locations loc ON loc.id = l.location_id
 WHERE l.deleted_at IS NULL AND NOT (l.city_id <=> loc.city_id);

SELECT 'listing.root_category_id is not the root of its category' AS check_name,
       COUNT(*) AS failures
  FROM listings l JOIN categories c ON c.id = l.category_id
 WHERE l.deleted_at IS NULL
   AND l.root_category_id <> COALESCE(c.root_category_id, c.id);

SELECT '--- maintained counters ---' AS check_group;

SELECT 'listing.inquiry_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT l.id FROM listings l
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM inquiries
                      WHERE deleted_at IS NULL AND listing_id IS NOT NULL
                      GROUP BY listing_id) i ON i.listing_id = l.id
         WHERE l.inquiry_count <> COALESCE(i.n, 0)) x;

SELECT 'listing.favourite_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT l.id FROM listings l
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM favourites GROUP BY listing_id) f
            ON f.listing_id = l.id
         WHERE l.favourite_count <> COALESCE(f.n, 0)) x;

SELECT 'listing.image_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT l.id FROM listings l
          LEFT JOIN (SELECT listing_id, COUNT(*) n FROM listing_media
                      WHERE media_type = 'image' GROUP BY listing_id) m
            ON m.listing_id = l.id
         -- image_count may legitimately exceed the rows present: the seed
         -- records the true photo count while materialising only the first
         -- twelve gallery rows. Only an undercount is a defect.
         WHERE l.image_count < COALESCE(m.n, 0)) x;

SELECT 'agent.active_listing_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT a.id FROM agents a
          LEFT JOIN (SELECT agent_id, COUNT(*) n FROM listings
                      WHERE status = 'active' AND deleted_at IS NULL GROUP BY agent_id) l
            ON l.agent_id = a.id
         WHERE a.active_listing_count <> COALESCE(l.n, 0)) x;

SELECT 'organization.active_listing_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT o.id FROM organizations o
          LEFT JOIN (SELECT organization_id, COUNT(*) n FROM listings
                      WHERE status = 'active' AND deleted_at IS NULL
                      GROUP BY organization_id) l ON l.organization_id = o.id
         WHERE o.active_listing_count <> COALESCE(l.n, 0)) x;

SELECT 'organization.agent_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT o.id FROM organizations o
          LEFT JOIN (SELECT organization_id, COUNT(*) n FROM agents
                      WHERE status = 'active' AND deleted_at IS NULL
                      GROUP BY organization_id) a ON a.organization_id = o.id
         WHERE o.agent_count <> COALESCE(a.n, 0)) x;

SELECT 'collection.item_count' AS check_name, COUNT(*) AS failures
  FROM (SELECT c.id FROM collections c
          LEFT JOIN (SELECT collection_id, COUNT(*) n FROM collection_items
                      GROUP BY collection_id) i ON i.collection_id = c.id
         WHERE c.item_count <> COALESCE(i.n, 0)) x;

SELECT '--- search projection ---' AS check_group;

SELECT 'projection contains a non-public listing' AS check_name, COUNT(*) AS failures
  FROM listing_search s
 WHERE s.listing_id NOT IN (SELECT id FROM v_public_listings);

SELECT 'public listing missing from the projection' AS check_name, COUNT(*) AS failures
  FROM v_public_listings v
 WHERE v.id NOT IN (SELECT listing_id FROM listing_search);

SELECT 'projection is stale relative to its source' AS check_name, COUNT(*) AS failures
  FROM listing_search s JOIN listings l ON l.id = s.listing_id
 WHERE s.source_updated_at < l.updated_at;

SELECT '--- projects ---' AS check_group;

-- The public visibility contract, asserted from the outside. `project_search` is
-- the only thing the public API reads, so a row in it that should not be public
-- is a project on the open web that nobody chose to publish.
SELECT 'projection contains a non-public project' AS check_name, COUNT(*) AS failures
  FROM project_search s
  JOIN projects p ON p.id = s.project_id
 WHERE p.deleted_at IS NOT NULL
    OR p.is_publicly_visible = 0
    OR p.moderation_status <> 'published'
    OR p.status = 'cancelled'
    OR p.canonical_path IS NULL;

SELECT 'public project missing from the projection' AS check_name, COUNT(*) AS failures
  FROM projects p
  LEFT JOIN brands b ON b.id = p.developer_brand_id AND b.deleted_at IS NULL
 WHERE p.deleted_at IS NULL
   AND p.is_publicly_visible = 1
   AND p.moderation_status = 'published'
   AND p.status <> 'cancelled'
   AND p.canonical_path IS NOT NULL
   AND (p.developer_brand_id IS NULL OR b.id IS NOT NULL)
   AND p.id NOT IN (SELECT project_id FROM project_search);

SELECT 'project projection is stale relative to its source' AS check_name, COUNT(*) AS failures
  FROM project_search s JOIN projects p ON p.id = s.project_id
 WHERE s.source_updated_at < p.updated_at;

-- Two projects claiming one URL means one of them is unreachable.
SELECT 'duplicate project canonical path' AS check_name, COUNT(*) AS failures
  FROM (SELECT canonical_path FROM projects
         WHERE canonical_path IS NOT NULL AND deleted_at IS NULL
         GROUP BY canonical_path HAVING COUNT(*) > 1) d;

-- A canonical path is built from the project's own location chain, so one that
-- does not start with its country's slug was written by something other than
-- sp_rebuild_project_canonical_path.
SELECT 'project canonical path disagrees with its location' AS check_name, COUNT(*) AS failures
  FROM projects p
  JOIN locations co ON co.id = p.country_id
 WHERE p.canonical_path IS NOT NULL
   AND p.deleted_at IS NULL
   AND p.canonical_path <> CONCAT('/projects/', co.slug, '/', p.slug)
   AND p.canonical_path NOT LIKE CONCAT('/projects/', co.slug, '/%/', p.slug);

-- A percentage schedule that does not reach 100 under-bills every buyer on it.
SELECT 'payment plan milestones do not total 100%' AS check_name, COUNT(*) AS failures
  FROM (SELECT m.plan_id
          FROM payment_plan_milestones m
          JOIN project_payment_plans pp ON pp.id = m.plan_id
         WHERE pp.is_active = 1
         GROUP BY m.plan_id
        HAVING SUM(m.fixed_amount IS NOT NULL) = 0
           AND COUNT(m.amount_percent) > 0
           AND ABS(SUM(COALESCE(m.amount_percent, 0)) - 100) > 0.01) x;

-- A project unit type belongs to exactly one project; an orphan is a row the
-- public DTO would happily render under whatever project inherits its id.
SELECT 'project unit type with no project' AS check_name, COUNT(*) AS failures
  FROM project_unit_types u
 WHERE u.project_id NOT IN (SELECT id FROM projects);

SELECT 'project amenity with no project' AS check_name, COUNT(*) AS failures
  FROM project_amenities a
 WHERE a.project_id NOT IN (SELECT id FROM projects);

-- Availability that contradicts the counters it is derived from.
SELECT 'project reports more available units than it has' AS check_name, COUNT(*) AS failures
  FROM projects
 WHERE available_units IS NOT NULL AND total_units IS NOT NULL
   AND available_units > total_units;

SELECT '--- money ---' AS check_group;

SELECT 'ledger group is unbalanced' AS check_name, COUNT(*) AS failures
  FROM (SELECT transaction_group FROM ledger_entries
         GROUP BY transaction_group
        HAVING ABS(SUM(CASE WHEN entry_type = 'debit'  THEN amount_base ELSE 0 END)
                 - SUM(CASE WHEN entry_type = 'credit' THEN amount_base ELSE 0 END)) > 0.01) x;

SELECT 'invoice total does not equal its lines' AS check_name, COUNT(*) AS failures
  FROM (SELECT i.id FROM invoices i
          JOIN invoice_lines il ON il.invoice_id = i.id
         GROUP BY i.id, i.total
        HAVING ABS(SUM(il.line_total) - i.total) > 0.01) x;

SELECT 'invoice amount_due does not equal total minus paid' AS check_name, COUNT(*) AS failures
  FROM invoices WHERE ABS(amount_due - (total - amount_paid)) > 0.01;

SELECT 'payment refunded more than it collected' AS check_name, COUNT(*) AS failures
  FROM payments WHERE refunded_amount > amount;

SELECT 'priced listing missing its base-currency amount' AS check_name, COUNT(*) AS failures
  FROM listings
 WHERE deleted_at IS NULL AND price IS NOT NULL AND price_base IS NULL;

SELECT 'active currency without an FX rate to base' AS check_name, COUNT(*) AS failures
  FROM currencies c
 WHERE c.is_active = 1 AND c.is_base = 0
   AND NOT EXISTS (SELECT 1 FROM fx_rates_latest f
                    WHERE f.base_code = 'AED' AND f.quote_code = c.code);

SELECT '--- public integrity ---' AS check_group;

SELECT 'active listing without a canonical path' AS check_name, COUNT(*) AS failures
  FROM listings
 WHERE deleted_at IS NULL AND status = 'active'
   AND (canonical_path IS NULL OR canonical_path = '');

SELECT 'active listing without any contact channel' AS check_name, COUNT(*) AS failures
  FROM listings
 WHERE deleted_at IS NULL AND status = 'active'
   AND contact_phone IS NULL AND contact_whatsapp IS NULL AND contact_email IS NULL;

SELECT 'agent without a profile slug' AS check_name, COUNT(*) AS failures
  FROM agents WHERE slug IS NULL OR slug = '';

SELECT 'publicly visible agent whose organisation is not' AS check_name, COUNT(*) AS failures
  FROM agents a JOIN organizations o ON o.id = a.organization_id
 WHERE a.deleted_at IS NULL AND a.status = 'active' AND a.is_publicly_visible = 1
   AND (o.deleted_at IS NOT NULL OR o.status <> 'active' OR o.is_publicly_visible = 0)
   AND a.id IN (SELECT id FROM v_public_agents);

SELECT 'sitemap entry for a non-public listing' AS check_name, COUNT(*) AS failures
  FROM sitemap_entries s
 WHERE s.entity_type = 'listing'
   AND s.entity_id NOT IN (SELECT id FROM v_public_listings);

SELECT 'exactly one base currency' AS check_name,
       ABS((SELECT COUNT(*) FROM currencies WHERE is_base = 1) - 1) AS failures;

SELECT 'exactly one default language' AS check_name,
       ABS((SELECT COUNT(*) FROM languages WHERE is_default = 1) - 1) AS failures;

-- =============================================================================
-- The corporate layers — 0016 to 0029
--
-- Same two categories, extended: polymorphic references that no foreign key
-- protects, and derived state that is only correct while the code writing it
-- is. Everything below must return 0.
-- =============================================================================

SELECT '--- polymorphic references, corporate layers ---' AS check_group;

SELECT 'media_attachments -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM media_attachments m
 WHERE m.attachable_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = m.attachable_id);

SELECT 'media_attachments -> organization (orphaned)' AS check_name, COUNT(*) AS failures
  FROM media_attachments m
 WHERE m.attachable_type = 'organization'
   AND NOT EXISTS (SELECT 1 FROM organizations o WHERE o.id = m.attachable_id);

SELECT 'documents -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM documents d
 WHERE d.owner_type = 'listing' AND d.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = d.owner_id);

SELECT 'documents -> project (orphaned)' AS check_name, COUNT(*) AS failures
  FROM documents d
 WHERE d.owner_type = 'project' AND d.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM projects p WHERE p.id = d.owner_id);

SELECT 'documents -> building (orphaned)' AS check_name, COUNT(*) AS failures
  FROM documents d
 WHERE d.owner_type = 'building' AND d.deleted_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM buildings b WHERE b.id = d.owner_id);

SELECT 'url_inventory -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM url_inventory u
 WHERE u.entity_type = 'listing' AND u.retired_at IS NULL
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = u.entity_id);

SELECT 'crm_tag_assignments -> contact (orphaned)' AS check_name, COUNT(*) AS failures
  FROM crm_tag_assignments t
 WHERE t.subject_type = 'contact'
   AND NOT EXISTS (SELECT 1 FROM crm_contacts c WHERE c.id = t.subject_id);

SELECT 'crm_tag_assignments -> deal (orphaned)' AS check_name, COUNT(*) AS failures
  FROM crm_tag_assignments t
 WHERE t.subject_type = 'deal'
   AND NOT EXISTS (SELECT 1 FROM deals d WHERE d.id = t.subject_id);

SELECT 'conversions -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM conversions c
 WHERE c.subject_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = c.subject_id);

SELECT 'conversions -> deal (orphaned)' AS check_name, COUNT(*) AS failures
  FROM conversions c
 WHERE c.subject_type = 'deal'
   AND NOT EXISTS (SELECT 1 FROM deals d WHERE d.id = c.subject_id);

SELECT 'entity_snapshots -> contract (orphaned)' AS check_name, COUNT(*) AS failures
  FROM entity_snapshots s
 WHERE s.entity_type = 'contract'
   AND NOT EXISTS (SELECT 1 FROM contracts c WHERE c.id = s.entity_id);

SELECT 'external_references -> listing (orphaned)' AS check_name, COUNT(*) AS failures
  FROM external_references e
 WHERE e.entity_type = 'listing'
   AND NOT EXISTS (SELECT 1 FROM listings l WHERE l.id = e.entity_id);

SELECT '--- money invariants, corporate layers ---' AS check_group;

SELECT 'journal does not balance' AS check_name, COUNT(*) AS failures
  FROM journals WHERE ABS(total_debit - total_credit) > 0.01;

SELECT 'journal total disagrees with its lines' AS check_name, COUNT(*) AS failures
  FROM (SELECT j.id FROM journals j
          LEFT JOIN (SELECT journal_id,
                            ROUND(SUM(CASE WHEN entry_type = 'debit' THEN amount ELSE 0 END), 2) dr
                       FROM ledger_entries WHERE journal_id IS NOT NULL GROUP BY journal_id) l
            ON l.journal_id = j.id
         WHERE ABS(j.total_debit - COALESCE(l.dr, 0)) > 0.01) x;

SELECT 'payment split total exceeds the payment' AS check_name, COUNT(*) AS failures
  FROM (SELECT p.id FROM payments p
          JOIN payment_splits s ON s.payment_id = p.id
         GROUP BY p.id
        HAVING SUM(s.amount) > MAX(p.amount) + 0.01) x;

SELECT 'credit lot balance disagrees with its transactions' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT cl.id FROM credit_lots cl
          LEFT JOIN (SELECT lot_id, SUM(amount) n FROM credit_transactions
                      WHERE lot_id IS NOT NULL GROUP BY lot_id) t ON t.lot_id = cl.id
         WHERE cl.remaining <> GREATEST(0, COALESCE(t.n, 0))) x;

SELECT 'campaign spend disagrees with its spend entries' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT c.id FROM ad_campaigns c
          LEFT JOIN (SELECT campaign_id, ROUND(SUM(amount), 2) s
                       FROM ad_spend_entries GROUP BY campaign_id) e ON e.campaign_id = c.id
         WHERE ABS(c.spent_amount - COALESCE(e.s, 0)) > 0.01) x;

SELECT 'promotion inventory oversold' AS check_name, COUNT(*) AS failures
  FROM promotion_inventory WHERE sold_count + reserved_count > capacity;

SELECT 'invoice credited beyond its own total' AS check_name, COUNT(*) AS failures
  FROM (SELECT i.id FROM invoices i
          JOIN credit_notes cn ON cn.invoice_id = i.id AND cn.status <> 'void'
         GROUP BY i.id
        HAVING SUM(cn.amount) > MAX(i.total) + 0.01) x;

SELECT 'instalment schedule disagrees with its plan' AS check_name, COUNT(*) AS failures
  FROM (SELECT p.id FROM installment_plans p
          JOIN installment_schedules s ON s.installment_plan_id = p.id
         GROUP BY p.id
        HAVING COUNT(*) <> MAX(p.installment_count)) x;

SELECT 'withholding does not reconcile gross to net' AS check_name, COUNT(*) AS failures
  FROM withholding_taxes
 WHERE ABS(gross_amount - withheld_amount - net_amount) > 0.01;

SELECT 'rent instalments do not sum to the annual rent' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT t.id FROM tenancies t
          JOIN rent_schedules r ON r.tenancy_id = t.id
         GROUP BY t.id
        HAVING ABS(SUM(r.amount) - MAX(t.annual_rent)) > 1.00) x;

SELECT '--- derived state, corporate layers ---' AS check_group;

SELECT 'building unit count disagrees with property_units' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT b.id FROM buildings b
          LEFT JOIN (SELECT building_id, COUNT(*) n FROM property_units
                      WHERE building_id IS NOT NULL GROUP BY building_id) u
            ON u.building_id = b.id
         WHERE b.unit_count <> COALESCE(u.n, 0)) x;

SELECT 'unit listing count disagrees with listings' AS check_name, COUNT(*) AS failures
  FROM (SELECT u.id FROM property_units u
          -- Soft-deleted listings do not count: the same definition the service maintains
          -- (listings.service.js syncUnitListingCountersForListing). The check used to count
          -- them, so a deleted listing made its unit "disagree" forever.
          LEFT JOIN (SELECT unit_id, COUNT(*) n FROM listings
                      WHERE unit_id IS NOT NULL AND deleted_at IS NULL GROUP BY unit_id) l ON l.unit_id = u.id
         WHERE u.listing_count <> COALESCE(l.n, 0)) x;

SELECT 'current ownership shares do not sum to 100' AS check_name, COUNT(*) AS failures
  FROM (SELECT unit_id FROM unit_ownerships WHERE is_current = 1
         GROUP BY unit_id HAVING ABS(SUM(share_percent) - 100) > 0.001) x;

SELECT 'attribution credit does not sum to 1 per conversion per model'
       AS check_name, COUNT(*) AS failures
  FROM (SELECT conversion_id, model_id FROM conversion_credits
         GROUP BY conversion_id, model_id
        HAVING ABS(SUM(credit_fraction) - 1) > 0.000001) x;

SELECT 'funnel completions and drops do not account for entries' AS check_name,
       COUNT(*) AS failures
  FROM funnel_daily_stats WHERE completed + dropped <> entered;

SELECT 'cohort retains more subjects than it started with' AS check_name,
       COUNT(*) AS failures
  FROM cohort_periods WHERE retained_count > cohort_size;

SELECT 'ratio KPI disagrees with its numerator over its denominator'
       AS check_name, COUNT(*) AS failures
  FROM kpi_values
 WHERE numerator IS NOT NULL AND denominator > 0
   AND ABS(value - numerator / denominator) > 0.000001;

SELECT 'nurture campaign counters disagree with enrolments' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT c.id FROM nurture_campaigns c
          LEFT JOIN (SELECT campaign_id, COUNT(*) n FROM nurture_enrolments
                      GROUP BY campaign_id) e ON e.campaign_id = c.id
         WHERE c.enrolled_count <> COALESCE(e.n, 0)) x;

SELECT 'lead form counters disagree with submissions' AS check_name,
       COUNT(*) AS failures
  FROM (SELECT f.id FROM lead_forms f
          LEFT JOIN (SELECT form_id, COUNT(*) n FROM lead_form_submissions
                      GROUP BY form_id) s ON s.form_id = f.id
         WHERE f.submission_count <> COALESCE(s.n, 0)) x;

SELECT 'market statistic below the sample floor marked publishable'
       AS check_name, COUNT(*) AS failures
  FROM market_statistics_monthly WHERE sample_size < 5 AND is_publishable = 1;

SELECT '--- compliance and governance ---' AS check_group;

SELECT 'personal-data field with no erasure action' AS check_name, COUNT(*) AS failures
  FROM data_field_registry WHERE is_personal_data = 1 AND erasure_action = 'no_action';

SELECT 'anonymise action with no rule' AS check_name, COUNT(*) AS failures
  FROM data_field_registry
 WHERE erasure_action IN ('anonymize', 'pseudonymize', 'hash')
   AND anonymization_rule_id IS NULL;

SELECT 'active processor with no signed agreement' AS check_name, COUNT(*) AS failures
  FROM data_processors WHERE status = 'active' AND dpa_signed = 0;

SELECT 'cross-border transfer with no safeguard' AS check_name, COUNT(*) AS failures
  FROM processing_activities
 WHERE transfers_outside_region = 1
   AND (transfer_safeguard IS NULL OR transfer_safeguard = 'none');

SELECT 'completed deletion request with no erasure record' AS check_name,
       COUNT(*) AS failures
  FROM data_subject_requests d
 WHERE d.request_type = 'deletion' AND d.status = 'completed'
   AND NOT EXISTS (SELECT 1 FROM erasure_records e WHERE e.request_id = d.id);

SELECT 'subject request past its statutory deadline and still open' AS check_name,
       COUNT(*) AS failures
  FROM data_subject_requests
 WHERE status IN ('pending', 'in_progress') AND due_at < NOW(3);

SELECT 'dry-run retention pass that changed rows' AS check_name, COUNT(*) AS failures
  FROM retention_runs WHERE was_dry_run = 1 AND affected_rows > 0;

SELECT 'retention run that deleted more than was eligible' AS check_name,
       COUNT(*) AS failures
  FROM retention_runs WHERE affected_rows > eligible_rows;

SELECT 'released legal hold with no reason' AS check_name, COUNT(*) AS failures
  FROM legal_holds
 WHERE status = 'released'
   AND (released_at IS NULL OR released_by_user_id IS NULL OR release_reason IS NULL);

SELECT 'suspicious activity report disclosed to the customer' AS check_name,
       COUNT(*) AS failures
  FROM suspicious_activity_reports WHERE customer_disclosed = 1;

SELECT 'expired permit on an active listing' AS check_name, COUNT(*) AS failures
  FROM listings l
  JOIN listing_permits p ON p.listing_id = l.id
 WHERE l.status = 'active' AND p.expires_at < CURDATE() AND p.status = 'active';

SELECT 'identity document past its purge date' AS check_name, COUNT(*) AS failures
  FROM identity_documents
 WHERE purge_after < CURDATE() AND purged_at IS NULL;

SELECT '--- operational ---' AS check_group;

SELECT 'outbox event stuck undispatched for over an hour' AS check_name,
       COUNT(*) AS failures
  FROM outbox_events
 WHERE status = 'pending' AND occurred_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR);

SELECT 'queue message claimed and never released' AS check_name, COUNT(*) AS failures
  FROM queue_messages
 WHERE status = 'processing' AND visible_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR);

SELECT 'unreviewed dead letter older than a week' AS check_name, COUNT(*) AS failures
  FROM dead_letter_messages
 WHERE status = 'pending' AND first_failed_at < DATE_SUB(NOW(3), INTERVAL 7 DAY);

-- distributed_locks has no released_at: releasing deletes the row, so a row
-- still present past its expiry is the reaper's backlog. An hour of grace, the
-- same window the other operational checks in this file allow, separates a
-- crashed holder waiting on the next reaper pass from a reaper that is down.
SELECT 'distributed lock held past its expiry' AS check_name, COUNT(*) AS failures
  FROM distributed_locks
 WHERE expires_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR);

SELECT 'circuit breaker open for over an hour' AS check_name, COUNT(*) AS failures
  FROM circuit_breakers
 WHERE state = 'open' AND opened_at < DATE_SUB(NOW(3), INTERVAL 1 HOUR);

SELECT 'search index queue item stuck processing' AS check_name, COUNT(*) AS failures
  FROM search_index_queue
 WHERE status = 'processing' AND claimed_at < DATE_SUB(NOW(3), INTERVAL 15 MINUTE);

SELECT 'webhook delivery abandoned without exhausting retries' AS check_name,
       COUNT(*) AS failures
  FROM webhook_deliveries WHERE status = 'abandoned' AND attempts < 5;

SELECT 'tenant with no canonical domain' AS check_name, COUNT(*) AS failures
  FROM (SELECT t.id FROM tenants t
          LEFT JOIN tenant_domains d ON d.tenant_id = t.id AND d.is_canonical = 1
         WHERE t.status = 'active'
         GROUP BY t.id HAVING COUNT(d.id) <> 1) x;

SELECT 'certificate expiring within fourteen days' AS check_name, COUNT(*) AS failures
  FROM tenant_domains
 WHERE status = 'active' AND ssl_expires_at < DATE_ADD(NOW(3), INTERVAL 14 DAY);

SELECT '--- category access ---' AS check_group;

-- Every listing's owning account must hold approved access to that listing's
-- category — otherwise the category is unreachable in the account's own
-- dashboard even though it has live inventory there. Caught this exact gap for
-- helicopters (0048_category_access_backfill.sql): 24 listings, 18 accounts,
-- zero approved grants.
SELECT 'listing owned by an account without approved category access' AS check_name, COUNT(*) AS failures
  FROM listings l
  JOIN organizations o ON o.id = l.organization_id AND o.deleted_at IS NULL
  LEFT JOIN account_category_access aca
         ON aca.account_id = o.account_id AND aca.category_id = l.root_category_id AND aca.status = 'approved'
 WHERE l.deleted_at IS NULL AND aca.id IS NULL;

-- A website enquiry only ever creates a lead *for a listing*
-- (engagement.routes.js linkInquiryToLead), and live code only soft-deletes
-- listings. `leads.primary_listing_id` is ON DELETE SET NULL, so a web-form lead
-- with no listing means something hard-deleted a listing out from under it —
-- that is exactly how a test cleanup left 54 of these behind on 2026-09-11, and
-- the admin Leads page crashed on every one.
SELECT 'website-enquiry lead whose listing was hard-deleted' AS check_name, COUNT(*) AS failures
  FROM leads
 WHERE deleted_at IS NULL AND channel = 'web_form' AND primary_listing_id IS NULL AND project_id IS NULL;

-- A development's owning developer must hold Real Estate Developments access, or they
-- cannot open it, submit it or work its enquiries in the portal (0051).
SELECT 'development owned by an account without approved developments access' AS check_name, COUNT(*) AS failures
  FROM projects p
  JOIN organizations o ON o.id = p.organization_id AND o.deleted_at IS NULL
  LEFT JOIN account_category_access aca
         ON aca.account_id = o.account_id AND aca.category_id = 7 AND aca.status = 'approved'
 WHERE p.deleted_at IS NULL AND aca.id IS NULL;

-- Allowance usage is what the portal checks before a new listing ("allowance used").
-- It is recomputed from the rows on every change (listings.service.js
-- `syncAccountListingUsage`, 0052); a mismatch means a write bypassed the service.
-- The old counter was only ever incremented and 47 accounts had drifted, one to
-- 500/500 while owning 26 listings.
SELECT 'account listing usage disagrees with its listings' AS check_name, COUNT(*) AS failures
  FROM accounts a
 WHERE a.listing_used <> (
         SELECT COUNT(*) FROM listings l
          WHERE l.account_id = a.id AND l.deleted_at IS NULL
            AND l.status IN ('draft', 'pending_review', 'active', 'rejected')
       );
