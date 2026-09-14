-- =============================================================================
-- 0053 — sp_refresh_entity_counters by the allowance slot rule; units and sitemap
-- =============================================================================
-- The rollup set accounts.listing_used from active + pending listings only, while
-- the service (listings.service.js syncAccountListingUsage, 0052) counts every
-- listing holding a slot: draft, pending review, live or rejected. Running the
-- rollup would have re-introduced the drift 0052 removed, so it is redefined here
-- from the live definition with only that clause changed. The listing
-- maintenance sweep (listings.jobs.js) now runs it every ten minutes; nothing ran
-- it before, so agent/organisation/category/brand counters drifted.
--
-- Also: property_units counters recomputed with the definition the service keeps
-- (soft-deleted listings excluded — the integrity check now agrees), and seeded
-- sitemap_entries for listings that are no longer public removed.
-- =============================================================================

-- The rollup's listing counter updates preserve updated_at: a counter is not a content
-- change, and bumping it made the search projection look stale after every run and moved the
-- owner's "Updated" date whenever the view rollup ran.
DELIMITER $
DROP PROCEDURE IF EXISTS sp_refresh_entity_counters$$
CREATE PROCEDURE sp_refresh_entity_counters()
MODIFIES SQL DATA
BEGIN
  -- Traffic counters come from the analytics rollups, never from the raw event
  -- stream. There is no fact table for a page view, so the rollup *is* the
  -- source of truth for these — and it is subject to the rollup's retention.
  UPDATE listings l
    JOIN (
      SELECT listing_id,
             SUM(views)           AS views,
             SUM(unique_views)    AS unique_views,
             SUM(call_clicks)     AS call_clicks,
             SUM(whatsapp_clicks) AS whatsapp_clicks,
             SUM(shares)          AS shares
        FROM listing_daily_stats
       GROUP BY listing_id
    ) s ON s.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.view_count           = s.views,
         l.unique_view_count    = s.unique_views,
         l.call_click_count     = s.call_clicks,
         l.whatsapp_click_count = s.whatsapp_clicks,
         l.share_count          = s.shares;

  -- Counters that DO have a fact table are derived from it, not from the
  -- rollup. `inquiries` and `favourites` are permanent rows; the daily rollups
  -- are pruned on a retention schedule. Reading the counter from the rollup
  -- would silently undercount every listing older than that retention — which
  -- is precisely the "count disagrees with the rows behind it" defect this
  -- schema is trying to make impossible.
  UPDATE listings l
    LEFT JOIN (
      SELECT listing_id, COUNT(*) c
        FROM inquiries
       WHERE deleted_at IS NULL AND listing_id IS NOT NULL
       GROUP BY listing_id
    ) i ON i.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.inquiry_count = COALESCE(i.c, 0);

  UPDATE listings l
    LEFT JOIN (SELECT listing_id, COUNT(*) c FROM favourites GROUP BY listing_id) f
      ON f.listing_id = l.id
     SET l.updated_at = l.updated_at,
         l.favourite_count = COALESCE(f.c, 0);

  -- Agent rollups.
  UPDATE agents a
    LEFT JOIN (
      SELECT agent_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY agent_id
    ) l ON l.agent_id = a.id
     SET a.listing_count        = COALESCE(l.total, 0),
         a.active_listing_count = COALESCE(l.active, 0);

  UPDATE agents a
    LEFT JOIN (
      SELECT subject_id, COUNT(*) c, AVG(rating) avg_rating
        FROM reviews
       WHERE subject_type = 'agent' AND status = 'published' AND deleted_at IS NULL
       GROUP BY subject_id
    ) r ON r.subject_id = a.id
     SET a.review_count = COALESCE(r.c, 0),
         a.rating_avg   = r.avg_rating;

  -- Organisation rollups.
  UPDATE organizations o
    LEFT JOIN (
      SELECT organization_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY organization_id
    ) l ON l.organization_id = o.id
     SET o.listing_count        = COALESCE(l.total, 0),
         o.active_listing_count = COALESCE(l.active, 0);

  UPDATE organizations o
    LEFT JOIN (
      SELECT organization_id, COUNT(*) c
        FROM agents WHERE deleted_at IS NULL AND status = 'active'
       GROUP BY organization_id
    ) a ON a.organization_id = o.id
     SET o.agent_count = COALESCE(a.c, 0);

  UPDATE organizations o
    LEFT JOIN (
      SELECT subject_id, COUNT(*) c, AVG(rating) avg_rating
        FROM reviews
       WHERE subject_type = 'organization' AND status = 'published' AND deleted_at IS NULL
       GROUP BY subject_id
    ) r ON r.subject_id = o.id
     SET o.review_count = COALESCE(r.c, 0),
         o.rating_avg   = r.avg_rating;

  -- Category and brand rollups.
  UPDATE categories c
    LEFT JOIN (
      SELECT category_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL GROUP BY category_id
    ) l ON l.category_id = c.id
     SET c.listing_count        = COALESCE(l.total, 0),
         c.active_listing_count = COALESCE(l.active, 0);

  UPDATE brands b
    LEFT JOIN (
      SELECT brand_id, COUNT(*) total, SUM(status = 'active') active
        FROM listings WHERE deleted_at IS NULL AND brand_id IS NOT NULL
       GROUP BY brand_id
    ) l ON l.brand_id = b.id
     SET b.listing_count        = COALESCE(l.total, 0),
         b.active_listing_count = COALESCE(l.active, 0);

  -- Account quota consumption.
  UPDATE accounts a
    LEFT JOIN (
      SELECT account_id, COUNT(*) c
        FROM listings
       WHERE deleted_at IS NULL AND status IN ('draft', 'pending_review', 'active', 'rejected')
       GROUP BY account_id
    ) l ON l.account_id = a.id
     SET a.listing_used = COALESCE(l.c, 0);

  -- Collection item counts.
  UPDATE collections c
    LEFT JOIN (SELECT collection_id, COUNT(*) n FROM collection_items GROUP BY collection_id) i
      ON i.collection_id = c.id
     SET c.item_count = COALESCE(i.n, 0);

  -- Editorial term post counts.
  UPDATE editorial_terms t
    LEFT JOIN (
      SELECT pt.term_id, COUNT(*) n
        FROM post_terms pt
        JOIN posts p ON p.id = pt.post_id AND p.status = 'published' AND p.deleted_at IS NULL
       GROUP BY pt.term_id
    ) x ON x.term_id = t.id
     SET t.post_count = COALESCE(x.n, 0);

  UPDATE authors a
    LEFT JOIN (
      SELECT author_id, COUNT(*) n FROM posts
       WHERE status = 'published' AND deleted_at IS NULL GROUP BY author_id
    ) p ON p.author_id = a.id
     SET a.post_count = COALESCE(p.n, 0);
END$$
DELIMITER ;

UPDATE property_units u
   SET u.listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL),
       u.active_listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL AND l.status = 'active');

DELETE FROM sitemap_entries
 WHERE entity_type = 'listing' AND entity_id NOT IN (SELECT id FROM v_public_listings);

CALL sp_refresh_entity_counters();

INSERT INTO schema_migrations (version, name) VALUES ('0053', 'entity_counters_slot_rule')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
