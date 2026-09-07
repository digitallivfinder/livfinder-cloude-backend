-- =============================================================================
-- Liv Finder — 0014 · Views, routines and triggers
-- =============================================================================
-- Three kinds of thing live here:
--
--   VIEWS      encode the public-visibility rules once, so no query has to
--              remember them. The audit confirmed the frontend implements these
--              rules correctly today — including the subtle one that an agent is
--              only publicly visible if their agency is too. Encoding them in a
--              view means a future query cannot get it wrong.
--
--   ROUTINES   maintain the derived structures: the closure table, materialised
--              paths, and the search projection.
--
--   TRIGGERS   enforce the invariants that must hold no matter which code path
--              writes: the denormalised location chain on listings, and price
--              history.
--
-- A note on triggers: they are used sparingly and only for invariants that would
-- otherwise be silently violated. Business logic stays in the application, where
-- it can be tested and reasoned about.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- VIEWS
-- =============================================================================

-- Publicly visible organisations. Every condition here is a rule the frontend
-- already applies; centralising them prevents divergence.
CREATE OR REPLACE VIEW v_public_organizations AS
SELECT o.*
FROM organizations o
WHERE o.deleted_at IS NULL
  AND o.status = 'active'
  AND o.is_publicly_visible = 1;

-- Publicly visible agents.
--
-- The second condition is the one that is easy to lose: an agent is only public
-- if their organisation is also publicly eligible. An agent with no organisation
-- (an independent) passes on their own merits.
CREATE OR REPLACE VIEW v_public_agents AS
SELECT a.*
FROM agents a
LEFT JOIN organizations o ON o.id = a.organization_id
WHERE a.deleted_at IS NULL
  AND a.status = 'active'
  AND a.is_publicly_visible = 1
  AND (
        a.organization_id IS NULL
     OR (o.deleted_at IS NULL AND o.status = 'active' AND o.is_publicly_visible = 1)
      );

-- Publicly visible listings.
--
-- `expires_at` is checked here rather than relied upon from `status`: the expiry
-- sweeper runs on a schedule, so between a listing lapsing and the sweeper
-- noticing there is a window in which status still says 'active'. The view
-- closes it.
CREATE OR REPLACE VIEW v_public_listings AS
SELECT l.*
FROM listings l
WHERE l.deleted_at IS NULL
  AND l.status = 'active'
  AND l.moderation_status = 'approved'
  AND l.published_at IS NOT NULL
  AND l.published_at <= NOW(3)
  AND (l.expires_at IS NULL OR l.expires_at > NOW(3));

-- The five-level location cascade, flattened with the ancestor names resolved.
-- This is what the admin Locations screens and the public breadcrumb read.
CREATE OR REPLACE VIEW v_location_hierarchy AS
SELECT
  l.id,
  l.public_id,
  l.level,
  l.depth,
  l.name,
  l.slug,
  l.path,
  l.status,
  l.latitude,
  l.longitude,
  l.active_listing_count,
  l.is_core_market,
  c.id   AS country_id,       c.name AS country_name,       c.slug AS country_slug,
  s.id   AS state_id,         s.name AS state_name,         s.slug AS state_slug,
  ct.id  AS city_id,          ct.name AS city_name,         ct.slug AS city_slug,
  cm.id  AS community_id,     cm.name AS community_name,    cm.slug AS community_slug,
  CASE WHEN l.level = 'sub_community' THEN l.id   ELSE NULL END AS sub_community_id,
  CASE WHEN l.level = 'sub_community' THEN l.name ELSE NULL END AS sub_community_name
FROM locations l
LEFT JOIN locations c  ON c.id  = l.country_id
LEFT JOIN locations s  ON s.id  = l.state_id
LEFT JOIN locations ct ON ct.id = l.city_id
LEFT JOIN locations cm ON cm.id = l.community_id
WHERE l.deleted_at IS NULL;

-- Account membership resolved to a permission set. This is what an authorisation
-- check reads: one indexed lookup by (user_id, account_id), no role-to-permission
-- join at request time.
CREATE OR REPLACE VIEW v_account_permissions AS
SELECT
  am.user_id,
  am.account_id,
  am.role,
  am.status              AS membership_status,
  a.account_type_id,
  at.code                AS account_type_code,
  a.status               AS account_status,
  a.verification_status,
  o.id                   AS organization_id,
  am.can_manage_organization,
  am.can_manage_members,
  am.can_manage_listings,
  am.can_publish_listings,
  am.can_manage_leads,
  am.can_view_integrations,
  am.can_manage_billing
FROM account_members am
JOIN accounts a       ON a.id  = am.account_id
JOIN account_types at ON at.id = a.account_type_id
LEFT JOIN organizations o ON o.account_id = a.id
WHERE am.status = 'active'
  AND a.deleted_at IS NULL;

-- Live listing counts by status per account. The portal "My Listings" tab
-- counters read this, so a tab labelled "Active (6)" is counting the same rows
-- the tab then shows.
CREATE OR REPLACE VIEW v_account_listing_counts AS
SELECT
  account_id,
  COUNT(*)                                                          AS total,
  SUM(status = 'active')                                            AS active,
  SUM(status = 'pending_review')                                    AS pending,
  SUM(status = 'draft')                                             AS drafts,
  SUM(status IN ('sold','rented'))                                  AS sold_rented,
  SUM(status = 'expired')                                           AS expired,
  SUM(status = 'rejected')                                          AS rejected
FROM listings
WHERE deleted_at IS NULL
GROUP BY account_id;

-- Same idea for the inquiry inbox tabs.
CREATE OR REPLACE VIEW v_organization_inquiry_counts AS
SELECT
  organization_id,
  COUNT(*)                            AS total,
  SUM(status = 'new')                 AS new_count,
  SUM(status = 'contacted')           AS contacted,
  SUM(status = 'qualified')           AS qualified,
  SUM(status IN ('won','lost','closed')) AS closed_count
FROM inquiries
WHERE deleted_at IS NULL
  AND is_spam = 0
GROUP BY organization_id;

-- =============================================================================
-- ROUTINES
-- =============================================================================

DELIMITER $$

-- -----------------------------------------------------------------------------
-- sp_location_rebuild_tree()
--
-- Rebuilds `location_closure`, and the denormalised `depth`, `path`, `path_ids`
-- and ancestor id columns on `locations`, from `parent_id` alone.
--
-- Written level-by-level rather than recursively so it runs on any supported
-- version and stays predictable on a 160k-row tree. Run after any bulk import;
-- individual edits are handled by the application.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_location_rebuild_tree$$
CREATE PROCEDURE sp_location_rebuild_tree()
MODIFIES SQL DATA
BEGIN
  DECLARE v_level TINYINT DEFAULT 0;

  -- MAX_TREE_DEPTH bounds both loops. It must exceed the deepest tree the
  -- `level` enum allows (country → … → building = 7 tiers, depth 0-6).
  DECLARE v_max_depth TINYINT DEFAULT 8;

  -- Roots first.
  UPDATE locations
     SET depth = 0,
         path = slug,
         path_ids = CAST(id AS CHAR),
         country_id = CASE WHEN level = 'country' THEN id ELSE country_id END
   WHERE parent_id IS NULL;

  -- Then each successive generation, deriving everything from the parent that
  -- was completed in the previous pass.
  --
  -- The loop runs a fixed number of passes rather than stopping when a pass
  -- changes nothing. That earlier form was wrong: a generation that happens to
  -- be already correct returns ROW_COUNT() = 0 and would end the loop before
  -- the deeper generations were visited. That is not hypothetical — Monaco and
  -- Hong Kong have no state tier, so their cities sit at depth 1 alongside
  -- every other country's states, making pass 1 a no-op and silently leaving
  -- their communities with a stale depth.
  SET v_level = 0;
  WHILE v_level < v_max_depth DO
    SET v_level = v_level + 1;

    UPDATE locations c
      JOIN locations p ON p.id = c.parent_id
       SET c.depth      = p.depth + 1,
           c.path       = CONCAT(p.path, '/', c.slug),
           c.path_ids   = CONCAT(p.path_ids, '/', c.id),
           c.country_id = CASE WHEN c.level = 'country'   THEN c.id ELSE p.country_id   END,
           c.state_id   = CASE WHEN c.level = 'state'     THEN c.id ELSE p.state_id     END,
           c.city_id    = CASE WHEN c.level = 'city'      THEN c.id ELSE p.city_id      END,
           c.community_id = CASE WHEN c.level = 'community' THEN c.id ELSE p.community_id END
     WHERE p.depth = v_level - 1
       AND (c.depth <> v_level
            OR c.path <> CONCAT(p.path, '/', c.slug)
            OR c.path_ids <> CONCAT(p.path_ids, '/', c.id));
  END WHILE;

  -- Closure: self-pairs, then one pass per generation, joining each node to
  -- everything its parent already reaches.
  DELETE FROM location_closure;

  INSERT INTO location_closure (ancestor_id, descendant_id, depth)
  SELECT id, id, 0 FROM locations;

  -- Same fixed-pass reasoning as above: each pass extends every edge by one
  -- generation, and a pass that inserts nothing must not end the loop.
  SET v_level = 0;
  WHILE v_level < v_max_depth DO
    SET v_level = v_level + 1;

    INSERT IGNORE INTO location_closure (ancestor_id, descendant_id, depth)
    SELECT cl.ancestor_id, c.id, cl.depth + 1
      FROM locations c
      JOIN location_closure cl ON cl.descendant_id = c.parent_id
     WHERE c.parent_id IS NOT NULL
       AND cl.depth = v_level - 1;
  END WHILE;
END$$

-- -----------------------------------------------------------------------------
-- sp_location_refresh_counts()
--
-- Recomputes `listing_count` / `active_listing_count` on every location, rolled
-- up through the subtree so a country's count includes everything beneath it.
-- The closure table is what makes this one statement rather than a recursion.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_location_refresh_counts$$
CREATE PROCEDURE sp_location_refresh_counts()
MODIFIES SQL DATA
BEGIN
  UPDATE locations SET listing_count = 0, active_listing_count = 0;

  UPDATE locations loc
    JOIN (
      SELECT cl.ancestor_id AS location_id,
             COUNT(*)                       AS total,
             SUM(l.status = 'active')       AS active
        FROM listings l
        JOIN location_closure cl ON cl.descendant_id = l.location_id
       WHERE l.deleted_at IS NULL
       GROUP BY cl.ancestor_id
    ) agg ON agg.location_id = loc.id
     SET loc.listing_count        = agg.total,
         loc.active_listing_count = COALESCE(agg.active, 0);
END$$

-- -----------------------------------------------------------------------------
-- sp_refresh_listing_search(listing_id)
--
-- Rebuilds one row of the search projection from the source tables. Pass NULL to
-- rebuild everything (use for the initial build and after a bulk import).
--
-- The spec_a..spec_f mapping documented in 0013 is applied here — this routine
-- is the single place that mapping exists, so it cannot drift between the
-- writer and the reader.
-- -----------------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_refresh_listing_search$$
CREATE PROCEDURE sp_refresh_listing_search(IN p_listing_id BIGINT UNSIGNED)
MODIFIES SQL DATA
BEGIN
  -- Remove rows that no longer qualify (unpublished, expired, soft-deleted).
  DELETE ls FROM listing_search ls
   WHERE (p_listing_id IS NULL OR ls.listing_id = p_listing_id)
     AND NOT EXISTS (SELECT 1 FROM v_public_listings v WHERE v.id = ls.listing_id);

  REPLACE INTO listing_search (
    listing_id, public_id, reference,
    root_category_id, category_id, purpose_id, category_slug, purpose_slug,
    title, slug, canonical_path, cover_image_url, image_count,
    price, currency_code, price_base, price_period, price_per_area,
    country_id, state_id, city_id, community_id, sub_community_id,
    location_label, latitude, longitude,
    organization_id, organization_name, organization_logo_url,
    agent_id, agent_name, agent_slug, agent_photo_url,
    contact_phone, contact_whatsapp,
    is_featured, is_premium, is_verified, is_exclusive, has_virtual_tour,
    spec_a, spec_b, spec_c, spec_d, spec_e, spec_f, spec_labels,
    facet_a, facet_b, facet_c,
    brand_id, brand_model_id, project_id, feature_ids,
    quality_score, published_at, last_refreshed_at, boost_score,
    source_updated_at
  )
  SELECT
    l.id, l.public_id, l.reference,
    l.root_category_id, l.category_id, l.purpose_id, cat.slug, pur.slug,
    l.title, l.slug, l.canonical_path, l.cover_image_url, l.image_count,
    l.price, l.currency_code, l.price_base, l.price_period, l.price_per_area,
    l.country_id, l.state_id, l.city_id, l.community_id, l.sub_community_id,
    -- Breadcrumb built deepest-first, skipping levels the listing does not have.
    CONCAT_WS(', ',
      NULLIF(COALESCE(sc.name, ''), ''),
      NULLIF(COALESCE(cm.name, ''), ''),
      NULLIF(COALESCE(ct.name, ''), ''),
      NULLIF(COALESCE(co.name, ''), '')
    ),
    l.latitude, l.longitude,
    l.organization_id, org.name, org.logo_url,
    l.agent_id, ag.display_name, ag.slug, ag.photo_url,
    l.contact_phone, l.contact_whatsapp,
    l.is_featured, l.is_premium, l.is_verified, l.is_exclusive, l.has_virtual_tour,

    -- spec_a..spec_f, per the mapping in 0013.
    CASE root.code
      WHEN 'real-estate' THEN re.bedrooms
      WHEN 'cars'        THEN veh.model_year
      WHEN 'yachts'      THEN FLOOR(mar.length_overall_ft)
      WHEN 'jets'        THEN av.year_built
      WHEN 'helicopters' THEN av.year_built
      WHEN 'watches'     THEN tp.year_of_production
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.bathrooms
      WHEN 'cars'        THEN veh.mileage_km
      WHEN 'yachts'      THEN mar.build_year
      WHEN 'jets'        THEN av.total_time_hours
      WHEN 'helicopters' THEN av.total_time_hours
      WHEN 'watches'     THEN FLOOR(tp.case_diameter_mm)
    END,
    CASE root.code
      WHEN 'real-estate' THEN FLOOR(re.built_area_sqft)
      WHEN 'cars'        THEN veh.horsepower
      WHEN 'yachts'      THEN mar.cabins
      WHEN 'jets'        THEN av.passenger_capacity
      WHEN 'helicopters' THEN av.passenger_capacity
      WHEN 'watches'     THEN tp.power_reserve_hours
    END,
    CASE root.code
      WHEN 'real-estate' THEN FLOOR(re.plot_area_sqft)
      WHEN 'cars'        THEN veh.engine_size_cc
      WHEN 'yachts'      THEN mar.guests_sleeping
      WHEN 'jets'        THEN av.range_nm
      WHEN 'helicopters' THEN av.range_nm
      WHEN 'watches'     THEN tp.water_resistance_m
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.year_built
      WHEN 'cars'        THEN veh.seats
      WHEN 'yachts'      THEN mar.engine_hours
      WHEN 'jets'        THEN av.cycles
      WHEN 'helicopters' THEN av.cycles
      WHEN 'watches'     THEN tp.jewels
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.floor_number
      WHEN 'cars'        THEN veh.doors
      WHEN 'yachts'      THEN FLOOR(mar.max_speed_knots)
      WHEN 'jets'        THEN av.max_cruise_speed_kts
      WHEN 'helicopters' THEN av.max_cruise_speed_kts
      ELSE NULL
    END,
    -- Human-readable spec strip for the card.
    CASE root.code
      WHEN 'real-estate' THEN JSON_OBJECT('beds', re.bedrooms, 'baths', re.bathrooms,
                                          'area_sqft', re.built_area_sqft, 'type', cat.name)
      WHEN 'cars'        THEN JSON_OBJECT('year', veh.model_year, 'mileage_km', veh.mileage_km,
                                          'transmission', veh.transmission, 'fuel', veh.fuel_type)
      WHEN 'yachts'      THEN JSON_OBJECT('length_ft', mar.length_overall_ft, 'year', mar.build_year,
                                          'cabins', mar.cabins, 'guests', mar.guests_sleeping)
      WHEN 'jets'        THEN JSON_OBJECT('year', av.year_built, 'seats', av.passenger_capacity,
                                          'range_nm', av.range_nm, 'hours', av.total_time_hours)
      WHEN 'helicopters' THEN JSON_OBJECT('year', av.year_built, 'seats', av.passenger_capacity,
                                          'range_nm', av.range_nm, 'hours', av.total_time_hours)
      WHEN 'watches'     THEN JSON_OBJECT('year', tp.year_of_production, 'case_mm', tp.case_diameter_mm,
                                          'movement', tp.movement_type, 'full_set', tp.is_full_set)
    END,

    CASE root.code
      WHEN 'real-estate' THEN re.furnishing
      WHEN 'cars'        THEN veh.transmission
      WHEN 'yachts'      THEN mar.vessel_type
      WHEN 'jets'        THEN av.aircraft_type
      WHEN 'helicopters' THEN av.aircraft_type
      WHEN 'watches'     THEN tp.movement_type
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.completion_status
      WHEN 'cars'        THEN veh.fuel_type
      WHEN 'yachts'      THEN mar.hull_material
      WHEN 'jets'        THEN av.engine_program
      WHEN 'helicopters' THEN av.engine_program
      WHEN 'watches'     THEN tp.condition_grade
    END,
    CASE root.code
      WHEN 'real-estate' THEN re.ownership_type
      WHEN 'cars'        THEN veh.condition_type
      WHEN 'yachts'      THEN IF(mar.is_charter_available, 'charter', 'sale')
      WHEN 'watches'     THEN tp.case_material
      ELSE NULL
    END,

    l.brand_id, l.brand_model_id, l.project_id,
    (SELECT JSON_ARRAYAGG(lf.feature_id) FROM listing_features lf WHERE lf.listing_id = l.id),

    l.quality_score, l.published_at, l.last_refreshed_at,
    (l.is_featured * 100) + (l.is_premium * 50),
    l.updated_at
  FROM v_public_listings l
  JOIN categories cat  ON cat.id  = l.category_id
  JOIN categories root ON root.id = l.root_category_id
  JOIN purposes   pur  ON pur.id  = l.purpose_id
  LEFT JOIN organizations org ON org.id = l.organization_id
  LEFT JOIN agents ag         ON ag.id  = l.agent_id
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations cm ON cm.id = l.community_id
  LEFT JOIN locations sc ON sc.id = l.sub_community_id
  LEFT JOIN listing_real_estate re ON re.listing_id  = l.id
  LEFT JOIN listing_vehicle veh    ON veh.listing_id = l.id
  LEFT JOIN listing_marine mar     ON mar.listing_id = l.id
  LEFT JOIN listing_aviation av    ON av.listing_id  = l.id
  LEFT JOIN listing_timepiece tp   ON tp.listing_id  = l.id
  WHERE p_listing_id IS NULL OR l.id = p_listing_id;
END$$

-- -----------------------------------------------------------------------------
-- sp_refresh_entity_counters()
--
-- Recomputes the denormalised counters on listings, agents, organisations,
-- categories and brands from their source tables.
--
-- This is the reconciliation pass. Counters are maintained incrementally in
-- normal operation; this exists so drift is bounded and detectable rather than
-- permanent. Run nightly.
-- -----------------------------------------------------------------------------
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
     SET l.view_count           = s.views,
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
     SET l.inquiry_count = COALESCE(i.c, 0);

  UPDATE listings l
    LEFT JOIN (SELECT listing_id, COUNT(*) c FROM favourites GROUP BY listing_id) f
      ON f.listing_id = l.id
     SET l.favourite_count = COALESCE(f.c, 0);

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
       WHERE deleted_at IS NULL AND status IN ('active','pending_review')
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

-- =============================================================================
-- TRIGGERS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Maintain the denormalised location chain on listings.
--
-- Without this, `listings.city_id` could disagree with `listings.location_id`,
-- and every location filter in the product would quietly return the wrong rows.
-- The invariant is enforced here so it holds regardless of which code path
-- writes the listing — application, import, admin or API.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_listings_location_bi$$
CREATE TRIGGER trg_listings_location_bi
BEFORE INSERT ON listings
FOR EACH ROW
BEGIN
  IF NEW.location_id IS NOT NULL THEN
    SELECT
      l.country_id,
      l.state_id,
      l.city_id,
      CASE WHEN l.level = 'sub_community' THEN l.community_id
           WHEN l.level = 'community'     THEN l.id
           ELSE l.community_id END,
      CASE WHEN l.level = 'sub_community' THEN l.id ELSE NULL END
      INTO @c, @s, @ct, @cm, @sc
      FROM locations l WHERE l.id = NEW.location_id;

    SET NEW.country_id       = @c,
        NEW.state_id         = @s,
        NEW.city_id          = @ct,
        NEW.community_id     = @cm,
        NEW.sub_community_id = @sc;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_listings_location_bu$$
CREATE TRIGGER trg_listings_location_bu
BEFORE UPDATE ON listings
FOR EACH ROW
BEGIN
  IF NOT (NEW.location_id <=> OLD.location_id) AND NEW.location_id IS NOT NULL THEN
    SELECT
      l.country_id,
      l.state_id,
      l.city_id,
      CASE WHEN l.level = 'sub_community' THEN l.community_id
           WHEN l.level = 'community'     THEN l.id
           ELSE l.community_id END,
      CASE WHEN l.level = 'sub_community' THEN l.id ELSE NULL END
      INTO @c, @s, @ct, @cm, @sc
      FROM locations l WHERE l.id = NEW.location_id;

    SET NEW.country_id       = @c,
        NEW.state_id         = @s,
        NEW.city_id          = @ct,
        NEW.community_id     = @cm,
        NEW.sub_community_id = @sc;
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Record every price change.
--
-- In the trigger rather than the application because the "reduced by 8%" badge
-- and the price-trend chart are claims made to buyers. If any write path can
-- change a price without leaving a record, those claims are unverifiable.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_listings_price_history$$
CREATE TRIGGER trg_listings_price_history
AFTER UPDATE ON listings
FOR EACH ROW
BEGIN
  IF NOT (NEW.price <=> OLD.price) THEN
    INSERT INTO listing_price_history
      (listing_id, old_price, new_price, currency_code,
       old_price_base, new_price_base, change_percentage)
    VALUES
      (NEW.id, OLD.price, NEW.price, NEW.currency_code,
       OLD.price_base, NEW.price_base,
       CASE WHEN OLD.price IS NULL OR OLD.price = 0 THEN NULL
            ELSE ROUND(((NEW.price - OLD.price) / OLD.price) * 100, 2) END);
  END IF;
END$$

-- -----------------------------------------------------------------------------
-- Prevent a location from becoming its own parent.
--
-- The CHECK constraint that would normally express this is rejected by both
-- MySQL and MariaDB because `id` is AUTO_INCREMENT (see the note in 0002).
-- Deeper cycles are structurally impossible while parents are always created
-- before children, and are caught by the integrity checks in tools/.
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_locations_no_self_parent_bu$$
CREATE TRIGGER trg_locations_no_self_parent_bu
BEFORE UPDATE ON locations
FOR EACH ROW
BEGIN
  IF NEW.parent_id IS NOT NULL AND NEW.parent_id = NEW.id THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A location cannot be its own parent';
  END IF;
END$$

DELIMITER ;

INSERT INTO schema_migrations (version, name) VALUES ('0014', 'views_and_routines');
