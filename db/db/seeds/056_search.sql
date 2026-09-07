-- =============================================================================
-- Liv Finder — seed 056 · Search configuration and feedback
-- =============================================================================
-- The ranking profile is the most consequential configuration in the platform,
-- and it is written here to be argued with rather than discovered by reading
-- code. Three things about it are deliberate:
--
--   · Text relevance is not the dominant signal. On a property portal almost
--     nobody types a free-text query — they pick a location and a category from
--     the filters. Weighting text relevance the way a document search would is
--     the commonest mistake in this domain.
--
--   · Promotion boost is a declared signal with a visible weight, sitting
--     alongside the organic ones. The commercial thumb on the scale is on the
--     record, which is the only honest way to have one.
--
--   · The diversity caps are load-bearing. Three listings per agency per page
--     is what stops a single large agency owning the first screen, and a
--     marketplace that lets that happen loses its small sellers and then its
--     inventory.
--
-- The synonyms are real Gulf search behaviour: the same place is typed as
-- "JBR", "Jumeirah Beach Residence" and "jumeira beach residence", and a portal
-- that treats those as three different queries fails two of them.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Ranking profiles
-- -----------------------------------------------------------------------------
INSERT INTO search_ranking_profiles
  (code, name, description, version, context, combination, max_per_organization,
   max_per_agent, max_per_project, freshness_half_life_days, apply_promotions,
   promotion_slots_per_page, status, is_default, activated_at)
VALUES
  ('results-v3', 'Search results — v3',
   'The default results ordering. Relevance and quality first, freshness as a decay rather than a hard sort, and paid promotion as a declared signal with a bounded number of slots per page.',
   3, 'search_results', 'linear', 3, 2, 4, 21, 1, 3, 'active', 1, NOW(3)),

  ('results-v2', 'Search results — v2 (retired)',
   'The previous version, kept so historical experiment results remain interpretable against the weights that produced them.',
   2, 'search_results', 'linear', 5, 3, NULL, 14, 1, 4, 'retired', 0,
   DATE_SUB(NOW(3), INTERVAL 240 DAY)),

  ('map-v1', 'Map search',
   'Distance dominates. Somebody drawing a box on a map has told you exactly what they want, and reordering by quality inside that box is unhelpful.',
   1, 'map_search', 'linear', 4, NULL, NULL, 30, 1, 2, 'active', 0, NOW(3)),

  ('similar-v2', 'Similar listings rail',
   'No paid promotion at all. A sponsored slot in "similar properties" is user-hostile and measurably reduces engagement with the rail.',
   2, 'similar_listings', 'multiplicative', 2, 1, 2, 60, 0, NULL, 'active', 0, NOW(3)),

  ('alerts-v1', 'Saved search alerts',
   'Freshness dominates because the whole promise of an alert is that it is new. Quality still filters, so a poor listing does not arrive in an inbox.',
   1, 'saved_search_alert', 'linear', 2, NULL, NULL, 3, 0, NULL, 'active', 0, NOW(3)),

  ('landing-v1', 'Location landing pages',
   'The shop window. Weighted hard towards presentation quality and verification, because these pages are the market''s first impression.',
   1, 'location_landing', 'linear', 2, 1, 3, 30, 1, 2, 'active', 0, NOW(3)),

  ('results-v4-experimental', 'Search results — v4 (experimental)',
   'Under test. Raises engagement weighting and lowers freshness, on the hypothesis that a good listing three weeks old beats a mediocre one from yesterday.',
   4, 'search_results', 'linear', 3, 2, 4, 45, 1, 3, 'experimental', 0, NOW(3));

INSERT INTO search_ranking_signals
  (profile_id, signal_code, weight, normalization, min_value, max_value,
   applies_when, is_active, sort_order, notes)
SELECT p.id, v.sig, v.weight, v.norm, v.min_v, v.max_v, v.applies_when, 1,
       v.sort_order, v.notes
FROM search_ranking_profiles p
JOIN (
  SELECT 'results-v3' AS prof, 'text_relevance' AS sig, 1.8000 AS weight,
         'min_max' AS norm, NULL AS min_v, NULL AS max_v,
         'query.has_text' AS applies_when, 10 AS sort_order,
         'Only applies when there is a text query at all, which on this platform is a minority of searches.' AS notes
  UNION ALL SELECT 'results-v3', 'geo_distance', 2.2000, 'sigmoid', 0, 25000,
         'query.has_geo', 20,
         'Sigmoid rather than linear: the difference between 500m and 1km matters; between 20km and 21km it does not.'
  UNION ALL SELECT 'results-v3', 'listing_quality', 2.5000, 'min_max', 0, 100, NULL, 30,
         'The composite of completeness, photography and description quality. The largest organic weight in the profile.'
  UNION ALL SELECT 'results-v3', 'completeness', 1.4000, 'min_max', 0, 100, NULL, 40,
         'Missing fields are the commonest reason a listing underperforms, and the easiest for the agency to fix.'
  UNION ALL SELECT 'results-v3', 'photo_count', 0.9000, 'log', 0, 40, NULL, 50,
         'Logarithmic. Going from 3 photographs to 10 transforms a listing; from 30 to 40 changes nothing.'
  UNION ALL SELECT 'results-v3', 'has_video', 0.5000, 'none', 0, 1, NULL, 60, NULL
  UNION ALL SELECT 'results-v3', 'has_virtual_tour', 0.6000, 'none', 0, 1, NULL, 70, NULL
  UNION ALL SELECT 'results-v3', 'verified_listing', 1.6000, 'none', 0, 1, NULL, 80,
         'Verification is expensive for the agency and valuable to the buyer, so it is rewarded meaningfully.'
  UNION ALL SELECT 'results-v3', 'freshness', 1.2000, 'sigmoid', 0, 90, NULL, 90,
         'Decays with the profile half-life rather than sorting hard by date, which is what makes bump-spamming unprofitable.'
  UNION ALL SELECT 'results-v3', 'engagement_ctr', 1.5000, 'percentile', NULL, NULL, NULL, 100,
         'Percentile-normalised so a listing in a low-traffic community is compared against its peers, not against Dubai Marina.'
  UNION ALL SELECT 'results-v3', 'engagement_inquiries', 1.3000, 'percentile', NULL, NULL, NULL, 110, NULL
  UNION ALL SELECT 'results-v3', 'agent_response_rate', 1.0000, 'min_max', 0, 100, NULL, 120,
         'An agent who does not answer wastes the buyer''s time, and the marketplace pays for it in trust.'
  UNION ALL SELECT 'results-v3', 'price_competitiveness', 1.1000, 'z_score', NULL, NULL, NULL, 130,
         'Against comparable inventory in the same community. Overpriced listings sink, which is a service to everyone including the seller.'
  UNION ALL SELECT 'results-v3', 'promotion_boost', 2.0000, 'none', 1, 8, NULL, 140,
         'The declared commercial weight. Bounded by the profile''s promotion_slots_per_page so paid inventory cannot take the whole page.'
  UNION ALL SELECT 'results-v3', 'price_reduced', 0.7000, 'none', 0, 1, NULL, 150,
         'A reduction is a genuine signal of motivation and buyers respond to it.'
  UNION ALL SELECT 'results-v3', 'stale_penalty', -1.8000, 'none', 0, 1, NULL, 200,
         'Not refreshed in 90 days. Usually means sold and not withdrawn, which is the single most damaging thing on a portal.'
  UNION ALL SELECT 'results-v3', 'duplicate_penalty', -3.0000, 'none', 0, 1, NULL, 210,
         'The same unit listed twice. Heavily penalised because it degrades the results page for everyone.'
  UNION ALL SELECT 'results-v3', 'low_quality_penalty', -2.2000, 'none', 0, 1, NULL, 220,
         'Fewer than three photographs, or a description under forty words.'
  UNION ALL SELECT 'results-v3', 'random_tiebreak', 0.0100, 'none', 0, 1, NULL, 999,
         'A tiny random component so listings with identical scores do not always appear in id order, which would permanently advantage whoever listed first.'

  UNION ALL SELECT 'map-v1', 'geo_distance', 5.0000, 'sigmoid', 0, 10000, NULL, 10,
         'Dominant by design. The user has drawn the boundary; respect it.'
  UNION ALL SELECT 'map-v1', 'listing_quality', 1.2000, 'min_max', 0, 100, NULL, 20, NULL
  UNION ALL SELECT 'map-v1', 'photo_count', 0.6000, 'log', 0, 40, NULL, 30, NULL
  UNION ALL SELECT 'map-v1', 'promotion_boost', 1.0000, 'none', 1, 8, NULL, 40, NULL

  UNION ALL SELECT 'similar-v2', 'text_relevance', 1.0000, 'min_max', NULL, NULL, NULL, 10, NULL
  UNION ALL SELECT 'similar-v2', 'geo_distance', 2.8000, 'sigmoid', 0, 5000, NULL, 20,
         'Similar usually means nearby. A comparable villa forty kilometres away is not a comparable.'
  UNION ALL SELECT 'similar-v2', 'price_competitiveness', 2.0000, 'z_score', NULL, NULL, NULL, 30,
         'Price proximity to the source listing is most of what makes a property feel similar.'
  UNION ALL SELECT 'similar-v2', 'listing_quality', 1.5000, 'min_max', 0, 100, NULL, 40, NULL

  UNION ALL SELECT 'alerts-v1', 'freshness', 4.0000, 'sigmoid', 0, 7, NULL, 10,
         'The alert exists to say "this is new". Anything else is a digest.'
  UNION ALL SELECT 'alerts-v1', 'listing_quality', 2.0000, 'min_max', 0, 100, NULL, 20, NULL
  UNION ALL SELECT 'alerts-v1', 'low_quality_penalty', -4.0000, 'none', 0, 1, NULL, 30,
         'Heavier than in results: a poor listing in a results page is skipped, a poor listing in an inbox is an unsubscribe.'

  UNION ALL SELECT 'landing-v1', 'listing_quality', 3.0000, 'min_max', 0, 100, NULL, 10, NULL
  UNION ALL SELECT 'landing-v1', 'photo_count', 1.5000, 'log', 0, 40, NULL, 20, NULL
  UNION ALL SELECT 'landing-v1', 'verified_listing', 2.5000, 'none', 0, 1, NULL, 30, NULL
  UNION ALL SELECT 'landing-v1', 'has_virtual_tour', 1.2000, 'none', 0, 1, NULL, 40, NULL
  UNION ALL SELECT 'landing-v1', 'promotion_boost', 1.5000, 'none', 1, 8, NULL, 50, NULL

  UNION ALL SELECT 'results-v4-experimental', 'listing_quality', 2.5000, 'min_max', 0, 100, NULL, 10, NULL
  UNION ALL SELECT 'results-v4-experimental', 'engagement_ctr', 2.6000, 'percentile', NULL, NULL, NULL, 20,
         'Raised from 1.5. The hypothesis under test.'
  UNION ALL SELECT 'results-v4-experimental', 'engagement_inquiries', 2.2000, 'percentile', NULL, NULL, NULL, 30, NULL
  UNION ALL SELECT 'results-v4-experimental', 'freshness', 0.7000, 'sigmoid', 0, 90, NULL, 40,
         'Lowered from 1.2, with a longer half-life.'
  UNION ALL SELECT 'results-v4-experimental', 'promotion_boost', 2.0000, 'none', 1, 8, NULL, 50,
         'Held constant so the experiment measures the ranking change and not a change in commercial density.'
) v ON v.prof = p.code;

-- -----------------------------------------------------------------------------
-- Synonyms
--
-- Grouped into sets rather than pairs, because synonymy is transitive and
-- pairwise rows drift the moment a third form is added.
-- -----------------------------------------------------------------------------
INSERT INTO search_synonym_sets
  (canonical_term, language_id, set_type, expansion, location_id, notes, is_active)
SELECT v.canonical, (SELECT id FROM languages WHERE code = 'en'), v.set_type,
       v.expansion,
       (SELECT id FROM locations WHERE level IN ('community','sub_community')
         AND slug = v.loc_slug LIMIT 1),
       v.notes, 1
FROM (
  SELECT 'Jumeirah Beach Residence' AS canonical, 'location' AS set_type,
         'two_way' AS expansion, 'jumeirah-beach-residence' AS loc_slug,
         'JBR is used far more often than the full name, including by agents.' AS notes
  UNION ALL SELECT 'Dubai Marina', 'location', 'two_way', 'dubai-marina', NULL
  UNION ALL SELECT 'Downtown Dubai', 'location', 'two_way', 'downtown-dubai',
         'Frequently searched as "Burj Khalifa area" or "Downtown".'
  UNION ALL SELECT 'Palm Jumeirah', 'location', 'two_way', 'palm-jumeirah',
         '"The Palm" is the everyday name and is what most people type.'
  UNION ALL SELECT 'Jumeirah Lakes Towers', 'location', 'two_way', 'jumeirah-lakes-towers',
         'JLT. Also confused with JBR by newcomers, which is why the abbreviations are kept distinct.'
  UNION ALL SELECT 'Jumeirah Village Circle', 'location', 'two_way', 'jumeirah-village-circle', NULL
  UNION ALL SELECT 'Business Bay', 'location', 'two_way', 'business-bay', NULL
  UNION ALL SELECT 'Emirates Hills', 'location', 'two_way', 'emirates-hills', NULL
  UNION ALL SELECT 'Arabian Ranches', 'location', 'two_way', 'arabian-ranches', NULL
  UNION ALL SELECT 'Dubai Hills Estate', 'location', 'two_way', 'dubai-hills-estate', NULL
) v;

INSERT INTO search_synonym_sets
  (canonical_term, language_id, set_type, expansion, category_id, notes, is_active)
SELECT v.canonical, (SELECT id FROM languages WHERE code = 'en'), v.set_type,
       v.expansion,
       (SELECT id FROM categories WHERE slug = v.cat_slug LIMIT 1), v.notes, 1
FROM (
  SELECT 'Apartment' AS canonical, 'property_type' AS set_type, 'two_way' AS expansion,
         'apartments' AS cat_slug,
         'British English says flat, American says apartment, and Indian English says both. All three are typed daily.' AS notes
  UNION ALL SELECT 'Villa', 'property_type', 'two_way', 'villas', NULL
  UNION ALL SELECT 'Townhouse', 'property_type', 'two_way', 'townhouses', NULL
  UNION ALL SELECT 'Penthouse', 'property_type', 'two_way', 'penthouses', NULL
  UNION ALL SELECT 'Studio', 'property_type', 'two_way', 'studios', NULL
  UNION ALL SELECT 'Office', 'property_type', 'two_way', 'offices', NULL
) v;

INSERT INTO search_synonym_sets
  (canonical_term, language_id, set_type, expansion, notes, is_active)
VALUES
  ('bedrooms', (SELECT id FROM languages WHERE code = 'en'), 'abbreviation', 'one_way',
   'The South Asian convention "BHK" means bedroom-hall-kitchen and is typed constantly in Gulf markets. Mapping it to bedrooms is the difference between a result and a dead end.', 1),
  ('swimming pool', (SELECT id FROM languages WHERE code = 'en'), 'amenity', 'two_way', NULL, 1),
  ('sea view', (SELECT id FROM languages WHERE code = 'en'), 'feature', 'two_way',
   'Sea, ocean, water and marina views are distinct to a valuer and identical to a searcher.', 1),
  ('furnished', (SELECT id FROM languages WHERE code = 'en'), 'feature', 'two_way', NULL, 1),
  ('off-plan', (SELECT id FROM languages WHERE code = 'en'), 'generic', 'two_way',
   'Off-plan, under construction and pre-launch are the same thing to a buyer.', 1),
  ('freehold', (SELECT id FROM languages WHERE code = 'en'), 'generic', 'two_way', NULL, 1);

INSERT INTO search_synonyms
  (set_id, term, term_normalized, language_id, is_canonical, weight, created_at)
SELECT ss.id, v.term, LOWER(REPLACE(REPLACE(v.term, '-', ' '), '  ', ' ')),
       (SELECT id FROM languages WHERE code = 'en'), v.is_canonical, v.weight, NOW(3)
FROM search_synonym_sets ss
JOIN (
  SELECT 'Jumeirah Beach Residence' AS canon, 'Jumeirah Beach Residence' AS term, 1 AS is_canonical, 1.000 AS weight
  UNION ALL SELECT 'Jumeirah Beach Residence', 'JBR', 0, 1.000
  UNION ALL SELECT 'Jumeirah Beach Residence', 'Jumeira Beach Residence', 0, 0.900
  UNION ALL SELECT 'Jumeirah Beach Residence', 'The Beach JBR', 0, 0.800
  UNION ALL SELECT 'Dubai Marina', 'Dubai Marina', 1, 1.000
  UNION ALL SELECT 'Dubai Marina', 'Marina', 0, 0.850
  UNION ALL SELECT 'Dubai Marina', 'Dubai Marine', 0, 0.700
  UNION ALL SELECT 'Downtown Dubai', 'Downtown Dubai', 1, 1.000
  UNION ALL SELECT 'Downtown Dubai', 'Downtown', 0, 0.900
  UNION ALL SELECT 'Downtown Dubai', 'Burj Khalifa area', 0, 0.850
  UNION ALL SELECT 'Downtown Dubai', 'Dubai Downtown', 0, 0.950
  UNION ALL SELECT 'Palm Jumeirah', 'Palm Jumeirah', 1, 1.000
  UNION ALL SELECT 'Palm Jumeirah', 'The Palm', 0, 0.950
  UNION ALL SELECT 'Palm Jumeirah', 'Palm Island', 0, 0.900
  UNION ALL SELECT 'Palm Jumeirah', 'Palm Jumeira', 0, 0.900
  UNION ALL SELECT 'Jumeirah Lakes Towers', 'Jumeirah Lakes Towers', 1, 1.000
  UNION ALL SELECT 'Jumeirah Lakes Towers', 'JLT', 0, 1.000
  UNION ALL SELECT 'Jumeirah Village Circle', 'Jumeirah Village Circle', 1, 1.000
  UNION ALL SELECT 'Jumeirah Village Circle', 'JVC', 0, 1.000
  UNION ALL SELECT 'Business Bay', 'Business Bay', 1, 1.000
  UNION ALL SELECT 'Business Bay', 'Bussiness Bay', 0, 0.700
  UNION ALL SELECT 'Emirates Hills', 'Emirates Hills', 1, 1.000
  UNION ALL SELECT 'Emirates Hills', 'Emirate Hills', 0, 0.800
  UNION ALL SELECT 'Arabian Ranches', 'Arabian Ranches', 1, 1.000
  UNION ALL SELECT 'Arabian Ranches', 'Arabian Ranch', 0, 0.850
  UNION ALL SELECT 'Dubai Hills Estate', 'Dubai Hills Estate', 1, 1.000
  UNION ALL SELECT 'Dubai Hills Estate', 'Dubai Hills', 0, 0.950
  UNION ALL SELECT 'Apartment', 'Apartment', 1, 1.000
  UNION ALL SELECT 'Apartment', 'Flat', 0, 1.000
  UNION ALL SELECT 'Apartment', 'Appartment', 0, 0.700
  UNION ALL SELECT 'Apartment', 'Apt', 0, 0.800
  UNION ALL SELECT 'Villa', 'Villa', 1, 1.000
  UNION ALL SELECT 'Villa', 'House', 0, 0.850
  UNION ALL SELECT 'Villa', 'Detached house', 0, 0.800
  UNION ALL SELECT 'Townhouse', 'Townhouse', 1, 1.000
  UNION ALL SELECT 'Townhouse', 'Town house', 0, 1.000
  UNION ALL SELECT 'Townhouse', 'Terraced house', 0, 0.800
  UNION ALL SELECT 'Penthouse', 'Penthouse', 1, 1.000
  UNION ALL SELECT 'Penthouse', 'Pent house', 0, 0.950
  UNION ALL SELECT 'Studio', 'Studio', 1, 1.000
  UNION ALL SELECT 'Studio', 'Bachelor', 0, 0.700
  UNION ALL SELECT 'Office', 'Office', 1, 1.000
  UNION ALL SELECT 'Office', 'Commercial space', 0, 0.800
  UNION ALL SELECT 'bedrooms', 'bedrooms', 1, 1.000
  UNION ALL SELECT 'bedrooms', 'BHK', 0, 0.900
  UNION ALL SELECT 'bedrooms', 'bed', 0, 0.950
  UNION ALL SELECT 'bedrooms', 'br', 0, 0.900
  UNION ALL SELECT 'swimming pool', 'swimming pool', 1, 1.000
  UNION ALL SELECT 'swimming pool', 'pool', 0, 0.950
  UNION ALL SELECT 'swimming pool', 'private pool', 0, 0.900
  UNION ALL SELECT 'sea view', 'sea view', 1, 1.000
  UNION ALL SELECT 'sea view', 'ocean view', 0, 1.000
  UNION ALL SELECT 'sea view', 'water view', 0, 0.900
  UNION ALL SELECT 'sea view', 'marina view', 0, 0.850
  UNION ALL SELECT 'furnished', 'furnished', 1, 1.000
  UNION ALL SELECT 'furnished', 'fully furnished', 0, 1.000
  UNION ALL SELECT 'furnished', 'with furniture', 0, 0.850
  UNION ALL SELECT 'off-plan', 'off-plan', 1, 1.000
  UNION ALL SELECT 'off-plan', 'under construction', 0, 0.900
  UNION ALL SELECT 'off-plan', 'pre-launch', 0, 0.850
  UNION ALL SELECT 'freehold', 'freehold', 1, 1.000
  UNION ALL SELECT 'freehold', 'free hold', 0, 1.000
) v ON v.canon = ss.canonical_term;

-- -----------------------------------------------------------------------------
-- Query rewrites
--
-- Whole-query transformations applied before parsing. The "2 bhk dubai marina"
-- case is the important one: it is not a text query at all, it is two filters
-- and a location, and treating it as text produces nothing.
-- -----------------------------------------------------------------------------
INSERT INTO search_query_rewrites
  (pattern, pattern_type, language_id, rewrite_type, replacement, applied_filters,
   redirect_url, priority, is_active, created_at, updated_at)
VALUES
  ('^([0-9]+)\\s*bhk\\b', 'regex', (SELECT id FROM languages WHERE code='en'),
   'apply_filters', NULL, JSON_OBJECT('bedrooms', '$1'), NULL, 10, 1, NOW(3), NOW(3)),
  ('^([0-9]+)\\s*(bed|beds|bedroom|bedrooms|br)\\b', 'regex',
   (SELECT id FROM languages WHERE code='en'), 'apply_filters', NULL,
   JSON_OBJECT('bedrooms', '$1'), NULL, 20, 1, NOW(3), NOW(3)),
  ('for sale', 'contains', (SELECT id FROM languages WHERE code='en'),
   'apply_filters', NULL, JSON_OBJECT('purpose', 'for-sale'), NULL, 30, 1, NOW(3), NOW(3)),
  ('for rent', 'contains', (SELECT id FROM languages WHERE code='en'),
   'apply_filters', NULL, JSON_OBJECT('purpose', 'for-rent'), NULL, 31, 1, NOW(3), NOW(3)),
  ('to let', 'contains', (SELECT id FROM languages WHERE code='en'),
   'apply_filters', NULL, JSON_OBJECT('purpose', 'for-rent'), NULL, 32, 1, NOW(3), NOW(3)),
  ('cheap', 'contains', (SELECT id FROM languages WHERE code='en'),
   'replace', 'affordable', NULL, NULL, 40, 1, NOW(3), NOW(3)),
  ('dubai marina', 'exact', (SELECT id FROM languages WHERE code='en'),
   'redirect', NULL, NULL, '/ae/dubai/dubai-marina', 50, 1, NOW(3), NOW(3)),
  ('palm jumeirah', 'exact', (SELECT id FROM languages WHERE code='en'),
   'redirect', NULL, NULL, '/ae/dubai/palm-jumeirah', 51, 1, NOW(3), NOW(3)),
  ('properties in ', 'prefix', (SELECT id FROM languages WHERE code='en'),
   'strip', NULL, NULL, NULL, 60, 1, NOW(3), NOW(3)),
  ('property for sale in ', 'prefix', (SELECT id FROM languages WHERE code='en'),
   'strip', NULL, NULL, NULL, 61, 1, NOW(3), NOW(3));

INSERT INTO search_stopwords (term, language_id, soft, is_active, created_at)
SELECT v.term, (SELECT id FROM languages WHERE code = 'en'), v.soft, 1, NOW(3)
FROM (
  SELECT 'the' AS term, 0 AS soft UNION ALL SELECT 'a', 0 UNION ALL SELECT 'an', 0
  UNION ALL SELECT 'in', 0 UNION ALL SELECT 'at', 0 UNION ALL SELECT 'of', 0
  UNION ALL SELECT 'for', 1 UNION ALL SELECT 'with', 1 UNION ALL SELECT 'and', 0
  UNION ALL SELECT 'or', 1 UNION ALL SELECT 'property', 1 UNION ALL SELECT 'properties', 1
  UNION ALL SELECT 'real', 1 UNION ALL SELECT 'estate', 1 UNION ALL SELECT 'near', 1
) v;

-- -----------------------------------------------------------------------------
-- Facet definitions
--
-- Which filters appear for which category. Showing a bedrooms filter on a watch
-- search is how a multi-vertical marketplace feels broken.
-- -----------------------------------------------------------------------------
INSERT INTO search_facet_definitions
  (code, label, category_id, purpose_id, source_column, facet_type, data_type,
   display_order, is_collapsed_by_default, show_counts, max_visible_options,
   range_buckets, min_value, max_value, step_value, is_url_facet, url_segment,
   is_active, created_at, updated_at)
SELECT v.code, v.label,
       (SELECT id FROM categories WHERE slug = v.cat_slug LIMIT 1),
       NULL, v.source_column, v.facet_type, v.data_type, v.display_order,
       v.collapsed, 1, v.max_options, v.buckets, v.min_v, v.max_v, v.step,
       v.is_url, v.url_segment, 1, NOW(3), NOW(3)
FROM (
  SELECT 'purpose' AS code, 'Purpose' AS label, NULL AS cat_slug,
         'purpose_id' AS source_column, 'radio' AS facet_type, 'enum' AS data_type,
         10 AS display_order, 0 AS collapsed, NULL AS max_options,
         NULL AS buckets, NULL AS min_v, NULL AS max_v, NULL AS step,
         1 AS is_url, 'purpose' AS url_segment
  UNION ALL SELECT 'category', 'Property type', NULL, 'category_id', 'multiselect',
         'enum', 20, 0, 12, NULL, NULL, NULL, NULL, 1, 'type'
  UNION ALL SELECT 'price', 'Price', NULL, 'price_base', 'range', 'decimal', 30, 0, NULL,
         JSON_ARRAY(0, 500000, 1000000, 2000000, 3000000, 5000000, 10000000,
                    20000000, 50000000),
         0, 100000000, 50000, 0, NULL
  UNION ALL SELECT 'bedrooms', 'Bedrooms', 'real-estate', 'spec_a', 'checkbox', 'int',
         40, 0, 8, JSON_ARRAY(0, 1, 2, 3, 4, 5, 6, 7), 0, 12, 1, 1, 'bedrooms'
  UNION ALL SELECT 'bathrooms', 'Bathrooms', 'real-estate', 'spec_b', 'checkbox', 'int',
         50, 1, 6, JSON_ARRAY(1, 2, 3, 4, 5, 6), 1, 10, 1, 0, NULL
  UNION ALL SELECT 'area', 'Area', 'real-estate', 'spec_c', 'range', 'decimal', 60, 0, NULL,
         JSON_ARRAY(0, 500, 1000, 1500, 2000, 3000, 5000, 10000), 0, 100000, 50, 0, NULL
  UNION ALL SELECT 'furnishing', 'Furnishing', 'real-estate', 'facet_a', 'radio', 'enum',
         70, 1, NULL, NULL, NULL, NULL, NULL, 1, 'furnishing'
  UNION ALL SELECT 'completion', 'Completion status', 'real-estate', 'facet_b', 'radio',
         'enum', 80, 1, NULL, NULL, NULL, NULL, NULL, 1, 'completion'
  UNION ALL SELECT 'amenities', 'Amenities', 'real-estate', NULL, 'multiselect', 'set',
         90, 1, 20, NULL, NULL, NULL, NULL, 0, NULL
  UNION ALL SELECT 'make', 'Make', 'cars', 'brand_id', 'multiselect', 'enum', 40, 0, 20,
         NULL, NULL, NULL, NULL, 1, 'make'
  UNION ALL SELECT 'model-year', 'Year', 'cars', 'spec_a', 'range', 'int', 50, 0, NULL,
         NULL, 1950, 2027, 1, 0, NULL
  UNION ALL SELECT 'mileage', 'Mileage', 'cars', 'spec_b', 'range', 'int', 60, 0, NULL,
         JSON_ARRAY(0, 10000, 30000, 50000, 100000, 200000), 0, 500000, 1000, 0, NULL
  UNION ALL SELECT 'fuel', 'Fuel type', 'cars', 'facet_a', 'checkbox', 'enum', 70, 1, 8,
         NULL, NULL, NULL, NULL, 0, NULL
  UNION ALL SELECT 'length', 'Length', 'yachts', 'spec_a', 'range', 'decimal', 40, 0, NULL,
         JSON_ARRAY(0, 10, 20, 30, 50, 80, 120), 0, 200, 1, 0, NULL
  UNION ALL SELECT 'cabins', 'Cabins', 'yachts', 'spec_b', 'checkbox', 'int', 50, 0, 10,
         JSON_ARRAY(1, 2, 3, 4, 5, 6, 8, 10), 1, 20, 1, 0, NULL
  UNION ALL SELECT 'builder', 'Builder', 'yachts', 'brand_id', 'multiselect', 'enum',
         60, 0, 20, NULL, NULL, NULL, NULL, 1, 'builder'
  UNION ALL SELECT 'range-nm', 'Range', 'jets', 'spec_a', 'range', 'int', 40, 0, NULL,
         JSON_ARRAY(0, 1500, 3000, 5000, 7000), 0, 12000, 100, 0, NULL
  UNION ALL SELECT 'passengers', 'Passengers', 'jets', 'spec_b', 'range', 'int', 50, 0,
         NULL, NULL, 1, 50, 1, 0, NULL
  UNION ALL SELECT 'case-size', 'Case size', 'watches', 'spec_a', 'range', 'decimal',
         40, 0, NULL, JSON_ARRAY(28, 34, 38, 40, 42, 44, 48), 20, 60, 1, 0, NULL
  UNION ALL SELECT 'movement', 'Movement', 'watches', 'facet_a', 'checkbox', 'enum',
         50, 0, 6, NULL, NULL, NULL, NULL, 1, 'movement'
  UNION ALL SELECT 'watch-brand', 'Brand', 'watches', 'brand_id', 'multiselect', 'enum',
         30, 0, 30, NULL, NULL, NULL, NULL, 1, 'brand'
) v;

-- -----------------------------------------------------------------------------
-- Facet counts
--
-- The "(1,204)" numbers beside each filter option, precomputed per community.
-- Computing these live means a GROUP BY per facet per request, which is the
-- single most expensive thing a results page can do.
-- -----------------------------------------------------------------------------
INSERT INTO search_facet_counts
  (facet_id, location_id, category_id, purpose_id, option_value, option_label,
   option_id, listing_count, min_price_base, max_price_base, computed_at)
SELECT f.id, l.community_id, NULL, l.purpose_id,
       CAST(c.id AS CHAR), c.name, c.id, COUNT(*),
       MIN(l.price_base), MAX(l.price_base), NOW(3)
FROM listings l
JOIN categories c ON c.id = l.category_id
JOIN search_facet_definitions f ON f.code = 'category' AND f.category_id IS NULL
WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
GROUP BY f.id, l.community_id, l.purpose_id, c.id, c.name;

INSERT INTO search_facet_counts
  (facet_id, location_id, category_id, purpose_id, option_value, option_label,
   option_id, listing_count, min_price_base, max_price_base, computed_at)
SELECT f.id, l.community_id, l.category_id, l.purpose_id,
       CAST(re.bedrooms AS CHAR),
       CONCAT(re.bedrooms, IF(re.bedrooms = 1, ' bedroom', ' bedrooms')),
       NULL, COUNT(*), MIN(l.price_base), MAX(l.price_base), NOW(3)
FROM listings l
JOIN listing_real_estate re ON re.listing_id = l.id
JOIN search_facet_definitions f ON f.code = 'bedrooms'
WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.community_id IS NOT NULL
  AND re.bedrooms IS NOT NULL
GROUP BY f.id, l.community_id, l.category_id, l.purpose_id, re.bedrooms;

-- -----------------------------------------------------------------------------
-- Autocomplete
--
-- Built from locations and categories that actually have inventory. A
-- suggestion that completes to a dead end is worse than no suggestion, which is
-- why `result_count` gates `is_active`.
-- -----------------------------------------------------------------------------
INSERT INTO search_suggestions
  (suggestion, suggestion_normalized, suggestion_type, language_id, country_id,
   target_type, target_id, target_url, context_label, icon, result_count,
   search_count, impression_count, selection_count, score, is_active,
   is_curated, refreshed_at, created_at)
SELECT
  loc.name, LOWER(loc.name_ascii), 'location',
  (SELECT id FROM languages WHERE code = 'en'), loc.country_id,
  'location', loc.id, CONCAT('/', CONVERT(loc.path USING utf8mb4) COLLATE utf8mb4_unicode_ci),
  CONCAT(COALESCE(parent.name, ''), ' · ', FORMAT(cnt.n, 0), ' properties'),
  'map-pin', cnt.n, 0, 0, 0,
  -- Score is inventory-weighted so the busiest communities surface first, which
  -- is what an autocomplete is for.
  ROUND(LOG(1 + cnt.n) * 100, 4),
  cnt.n > 0, 0, NOW(3), NOW(3)
FROM locations loc
LEFT JOIN locations parent ON parent.id = loc.parent_id
JOIN (
  SELECT community_id AS loc_id, COUNT(*) AS n FROM listings
   WHERE status = 'active' AND deleted_at IS NULL AND community_id IS NOT NULL
   GROUP BY community_id
) cnt ON cnt.loc_id = loc.id;

INSERT INTO search_suggestions
  (suggestion, suggestion_normalized, suggestion_type, language_id,
   target_type, target_id, target_url, context_label, icon, result_count,
   search_count, impression_count, selection_count, score, is_active,
   is_curated, refreshed_at, created_at)
SELECT c.name_plural, LOWER(c.name_plural), 'category',
       (SELECT id FROM languages WHERE code = 'en'),
       'category', c.id, CONCAT('/', c.slug),
       CONCAT(FORMAT(c.active_listing_count, 0), ' listings'),
       COALESCE(c.icon, 'tag'), c.active_listing_count, 0, 0, 0,
       ROUND(LOG(1 + c.active_listing_count) * 120, 4),
       c.active_listing_count > 0, 1, NOW(3), NOW(3)
FROM categories c
WHERE c.deleted_at IS NULL AND c.is_visible = 1;

INSERT INTO search_suggestions
  (suggestion, suggestion_normalized, suggestion_type, language_id,
   target_type, target_id, target_url, context_label, icon, result_count,
   search_count, impression_count, selection_count, score, is_active,
   is_curated, refreshed_at, created_at)
SELECT pj.name, LOWER(pj.name), 'project',
       (SELECT id FROM languages WHERE code = 'en'),
       'project', pj.id, CONCAT('/projects/', pj.slug),
       CONCAT('Off-plan · ', FORMAT(COALESCE(pj.available_units, 0), 0), ' units available'),
       'building', COALESCE(pj.listing_count, 0), 0, 0, 0,
       ROUND(LOG(1 + COALESCE(pj.listing_count, 0)) * 90, 4),
       pj.is_publicly_visible = 1, 1, NOW(3), NOW(3)
FROM projects pj WHERE pj.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Zero-result queries
--
-- The highest-value table in the migration and the one most portals throw away.
-- Seeded from the searches that already recorded no results.
-- -----------------------------------------------------------------------------
INSERT INTO search_zero_result_queries
  (query_normalized, query_sample, language_id, country_id, category_id,
   occurrence_count, unique_visitors, first_seen_at, last_seen_at,
   abandonment_rate, status)
SELECT
  LOWER(TRIM(sq.query_normalized)), MIN(sq.query_text),
  (SELECT id FROM languages WHERE code = 'en'),
  NULL, sq.category_id,
  COUNT(*), COUNT(DISTINCT sq.visitor_id),
  MIN(sq.searched_at), MAX(sq.searched_at),
  -- Abandonment: no click and no refinement afterwards. High on a
  -- zero-result query by definition, which is what makes it worth reading.
  ROUND(0.70 + MOD(CONV(SUBSTRING(MD5(sq.query_normalized),1,3),16,10), 28) / 100, 4),
  'new'
FROM search_queries sq
WHERE sq.result_count = 0 AND sq.query_normalized IS NOT NULL
GROUP BY LOWER(TRIM(sq.query_normalized)), sq.category_id;

-- -----------------------------------------------------------------------------
-- Experiments
-- -----------------------------------------------------------------------------
INSERT INTO search_experiments
  (public_id, code, name, hypothesis, experiment_type, primary_metric,
   guardrail_metrics, minimum_sample_size, traffic_percentage, status,
   starts_at, ends_at, concluded_at, outcome, confidence_level, results_summary,
   created_at, updated_at)
VALUES
  (UPPER(LEFT(MD5('exp:engagement-weight'), 26)), 'engagement-weight-v4',
   'Raise engagement weighting, lower freshness',
   'A listing that consistently earns clicks and enquiries is a better result than a newer one that does not. Raising engagement weight from 1.5 to 2.6 and lengthening the freshness half-life from 21 to 45 days should raise the inquiry rate without materially raising the zero-result rate.',
   'ranking', 'inquiry_rate',
   'zero_result_rate,organization_diversity,revenue_per_session',
   50000, 50, 'running',
   DATE_SUB(NOW(3), INTERVAL 21 DAY), DATE_ADD(NOW(3), INTERVAL 21 DAY),
   NULL, NULL, NULL, NULL, DATE_SUB(NOW(3), INTERVAL 28 DAY), NOW(3)),

  (UPPER(LEFT(MD5('exp:promo-density'), 26)), 'promotion-density',
   'Four promoted slots per page instead of three',
   'Adding a fourth promoted slot raises revenue per session. The guardrail is inquiry rate: if organic engagement falls by more than 2% the additional revenue is being taken out of the marketplace rather than added to it.',
   'promotion_density', 'revenue_per_session',
   'inquiry_rate,bounce_rate', 80000, 30, 'concluded',
   DATE_SUB(NOW(3), INTERVAL 90 DAY), DATE_SUB(NOW(3), INTERVAL 60 DAY),
   DATE_SUB(NOW(3), INTERVAL 58 DAY), 'stopped_by_guardrail', 96.20,
   'Revenue per session rose 4.1%, but inquiry rate fell 3.8% and bounce rate rose 2.9% — both past the guardrail. Stopped early and rolled back. The revenue was coming out of engagement, not out of nowhere.',
   DATE_SUB(NOW(3), INTERVAL 95 DAY), DATE_SUB(NOW(3), INTERVAL 58 DAY)),

  (UPPER(LEFT(MD5('exp:autocomplete'), 26)), 'autocomplete-inventory-order',
   'Order autocomplete by inventory rather than alphabetically',
   'Suggesting the communities with the most listings first should reduce zero-result searches and shorten time to first click.',
   'autocomplete', 'zero_result_rate', 'bounce_rate', 30000, 50,
   'rolled_out', DATE_SUB(NOW(3), INTERVAL 150 DAY), DATE_SUB(NOW(3), INTERVAL 120 DAY),
   DATE_SUB(NOW(3), INTERVAL 118 DAY), 'variant_won', 99.10,
   'Zero-result rate fell from 6.2% to 4.4%. Rolled out to everyone and folded into the default.',
   DATE_SUB(NOW(3), INTERVAL 155 DAY), DATE_SUB(NOW(3), INTERVAL 118 DAY)),

  (UPPER(LEFT(MD5('exp:map-default'), 26)), 'map-default-sort',
   'Default the map view to distance rather than relevance',
   'Users who open the map have expressed a spatial intent. Sorting by distance should raise click-through.',
   'default_sort', 'click_through_rate', 'inquiry_rate', 20000, 50, 'concluded',
   DATE_SUB(NOW(3), INTERVAL 200 DAY), DATE_SUB(NOW(3), INTERVAL 170 DAY),
   DATE_SUB(NOW(3), INTERVAL 168 DAY), 'no_difference', 71.40,
   'No significant difference at 71% confidence, which is not significance. Recorded as such rather than reported as a small win — the commonest and least reported experiment outcome.',
   DATE_SUB(NOW(3), INTERVAL 205 DAY), DATE_SUB(NOW(3), INTERVAL 168 DAY));

INSERT INTO search_experiment_variants
  (experiment_id, code, name, is_control, traffic_share, ranking_profile_id,
   exposures, searches, clicks, inquiries, conversions, primary_metric_value,
   lift_percent, p_value, created_at, updated_at)
SELECT e.id, v.code, v.name, v.is_control, v.share,
       (SELECT id FROM search_ranking_profiles WHERE code = v.profile_code LIMIT 1),
       v.exposures, v.searches, v.clicks, v.inquiries, v.conversions,
       v.metric, v.lift, v.p_value, e.created_at, NOW(3)
FROM search_experiments e
JOIN (
  SELECT 'engagement-weight-v4' AS exp, 'control' AS code, 'Control — v3' AS name,
         1 AS is_control, 50 AS share, 'results-v3' AS profile_code,
         26400 AS exposures, 61200 AS searches, 4890 AS clicks,
         742 AS inquiries, 742 AS conversions, 0.012124 AS metric,
         NULL AS lift, NULL AS p_value
  UNION ALL SELECT 'engagement-weight-v4', 'variant', 'Variant — v4', 0, 50,
         'results-v4-experimental', 26180, 60840, 5216, 806, 806, 0.013247,
         9.263, 0.083000
  UNION ALL SELECT 'promotion-density', 'control', 'Control — three slots', 1, 50,
         'results-v3', 41200, 96400, 7900, 1210, 1210, 0.012552, NULL, NULL
  UNION ALL SELECT 'promotion-density', 'variant', 'Variant — four slots', 0, 50,
         'results-v3', 41050, 96100, 7690, 1164, 1164, 0.012112, -3.505, 0.038000
  UNION ALL SELECT 'autocomplete-inventory-order', 'control', 'Control — alphabetical',
         1, 50, NULL, 18400, 44100, 3120, 498, 498, 0.011293, NULL, NULL
  UNION ALL SELECT 'autocomplete-inventory-order', 'variant', 'Variant — by inventory',
         0, 50, NULL, 18310, 43980, 3402, 561, 561, 0.012756, 12.955, 0.009000
  UNION ALL SELECT 'map-default-sort', 'control', 'Control — relevance', 1, 50,
         'map-v1', 9800, 21400, 1602, 214, 214, 0.010000, NULL, NULL
  UNION ALL SELECT 'map-default-sort', 'variant', 'Variant — distance', 0, 50,
         'map-v1', 9760, 21350, 1631, 218, 218, 0.010211, 2.110, 0.286000
) v ON v.exp = e.code;

UPDATE search_experiments e
  JOIN search_experiment_variants v
    ON v.experiment_id = e.id AND v.is_control = 0
   SET e.winning_variant_id = v.id
 WHERE e.outcome = 'variant_won';

-- -----------------------------------------------------------------------------
-- Similar listings
--
-- Precomputed neighbours: same community, same category, closest price. The
-- rail under a listing page reads this directly rather than computing
-- similarity across millions of rows in 40ms, which is not something a database
-- does.
-- -----------------------------------------------------------------------------
INSERT INTO listing_similarities
  (listing_id, similar_listing_id, similarity_type, score, rank_position,
   reason_code, computed_at)
SELECT
  a.id, b.id, 'blended',
  -- Score falls with price distance. Two listings 5% apart in the same
  -- community are near-identical propositions; 60% apart are not comparable.
  ROUND(GREATEST(0.100000,
        1 - ABS(a.price_base - b.price_base) / GREATEST(a.price_base, 1)), 6),
  -- Same community first, then closest price. Neighbourhood proximity beats
  -- price proximity: a buyer looking in Dubai Marina wants Dubai Marina.
  ROW_NUMBER() OVER (PARTITION BY a.id
                     ORDER BY a.community_id <> b.community_id,
                              ABS(a.price_base - b.price_base)),
  IF(a.community_id = b.community_id, 'same_community_and_type', 'same_city_and_type'),
  NOW(3)
FROM listings a
JOIN listings b
  ON b.city_id = a.city_id
 AND b.category_id = a.category_id
 AND b.purpose_id = a.purpose_id
 AND b.id <> a.id
 AND b.status = 'active' AND b.deleted_at IS NULL
WHERE a.status = 'active' AND a.deleted_at IS NULL
  AND a.price_base IS NOT NULL AND b.price_base IS NOT NULL;

-- Keep the top eight per listing. Anything past that is not a similar property,
-- it is the rest of the market.
DELETE FROM listing_similarities WHERE rank_position > 8;

-- -----------------------------------------------------------------------------
-- Saved search matches and recommendations
-- -----------------------------------------------------------------------------
INSERT INTO saved_search_matches
  (saved_search_id, listing_id, user_id, match_reason, matched_at,
   price_at_match, notified_at, notification_channel, opened_at)
SELECT ss.id, l.id, ss.user_id, 'new_listing',
       GREATEST(l.published_at, ss.created_at), l.price,
       DATE_ADD(GREATEST(l.published_at, ss.created_at), INTERVAL 1 HOUR),
       'email',
       -- Roughly a third of alert emails are opened, which is a good rate for
       -- a triggered send and a poor one for a broadcast.
       IF(MOD(l.id + ss.id, 3) = 0,
          DATE_ADD(GREATEST(l.published_at, ss.created_at), INTERVAL 4 HOUR), NULL)
FROM saved_searches ss
JOIN listings l
  -- A saved search commonly names a root category ("real estate") while a
  -- listing carries a leaf ("apartments"), so both have to match.
  ON (ss.category_id IS NULL OR l.category_id = ss.category_id
      OR l.root_category_id = ss.category_id)
 AND (ss.purpose_id IS NULL OR l.purpose_id = ss.purpose_id)
 AND (ss.location_id IS NULL OR l.community_id = ss.location_id
      OR l.city_id = ss.location_id OR l.country_id = ss.location_id)
 AND l.status = 'active' AND l.deleted_at IS NULL
 AND l.published_at IS NOT NULL
WHERE ss.deleted_at IS NULL AND ss.alerts_enabled = 1
  -- A saved search that matched four hundred listings would send an alert
  -- nobody reads. The alert job caps what it sends per run; so does this.
  AND MOD(l.id + ss.id, 3) = 0
GROUP BY ss.id, l.id;

INSERT INTO user_recommendations
  (user_id, listing_id, slot, score, rank_position, reason_code, reason_text,
   source_listing_id, saved_search_id, generated_at, expires_at, shown_count)
SELECT m.user_id, m.listing_id, 'saved_search_alert',
       ROUND(0.500000 + MOD(m.listing_id, 400) / 1000, 6),
       ROW_NUMBER() OVER (PARTITION BY m.user_id ORDER BY m.matched_at DESC),
       'matches_saved_search',
       'Matches your saved search',
       NULL, m.saved_search_id, m.matched_at,
       DATE_ADD(m.matched_at, INTERVAL 30 DAY), 1
FROM saved_search_matches m
WHERE m.user_id IS NOT NULL
GROUP BY m.user_id, m.listing_id, m.saved_search_id, m.matched_at;

DELETE FROM user_recommendations WHERE rank_position > 12;

-- -----------------------------------------------------------------------------
-- Trending
-- -----------------------------------------------------------------------------
INSERT INTO search_trending
  (window_type, window_start, scope_type, scope_id, subject_type, subject_id,
   subject_label, search_count, unique_visitors, previous_count, change_percent,
   rank_position, is_breakout, computed_at)
SELECT 'day', DATE_SUB(CURDATE(), INTERVAL 1 DAY), 'country', loc.country_id,
       'location', loc.id, loc.name, t.n, ROUND(t.n * 0.72),
       ROUND(t.n * 0.85), ROUND((t.n - t.n * 0.85) / GREATEST(1, t.n * 0.85) * 100, 2),
       ROW_NUMBER() OVER (PARTITION BY loc.country_id ORDER BY t.n DESC),
       0, NOW(3)
FROM (
  SELECT community_id AS loc_id, COUNT(*) * 7 AS n FROM listings
   WHERE status = 'active' AND deleted_at IS NULL AND community_id IS NOT NULL
   GROUP BY community_id
) t
JOIN locations loc ON loc.id = t.loc_id;

DELETE FROM search_trending WHERE rank_position > 20;

-- -----------------------------------------------------------------------------
-- Index freshness
--
-- Per-document state, so "is the index stale?" is answerable rather than a
-- matter of faith.
-- -----------------------------------------------------------------------------
INSERT INTO search_index_state
  (subject_type, subject_id, index_name, source_updated_at, indexed_at,
   document_hash, document_version, is_stale, is_indexed, exclusion_reason,
   error_count, updated_at)
SELECT 'listing', l.id, 'listing_search', l.updated_at,
       IF(l.status = 'active', l.updated_at, NULL),
       LOWER(LEFT(MD5(CONCAT('doc:', l.id, ':', l.updated_at)), 32)), 1,
       0, l.status = 'active',
       CASE WHEN l.status = 'draft' THEN 'unpublished'
            WHEN l.status = 'pending_review' THEN 'moderation_hold'
            WHEN l.status IN ('expired','withdrawn','archived') THEN 'expired'
            WHEN l.status IN ('sold','rented') THEN 'expired'
            WHEN l.status = 'rejected' THEN 'moderation_hold'
            WHEN l.deleted_at IS NOT NULL THEN 'deleted'
            ELSE NULL END,
       0, NOW(3)
FROM listings l;

-- -----------------------------------------------------------------------------
-- Search health
--
-- Zero-result rate and click-through by market are the two numbers that say
-- whether search is working. They belong on a wall, not in an ad-hoc query.
-- -----------------------------------------------------------------------------
INSERT INTO search_daily_stats
  (stat_date, country_id, root_category_id, device_type, ranking_profile_id,
   searches, unique_searchers, zero_result_searches, refined_searches,
   result_impressions, result_clicks, inquiries, favourites,
   avg_results_per_search, avg_click_position, zero_result_rate,
   click_through_rate, computed_at)
SELECT
  s.stat_date, NULL, NULL, 'all',
  (SELECT id FROM search_ranking_profiles WHERE code = 'results-v3'),
  s.searches, ROUND(s.searches * 0.68), s.zero_results,
  ROUND(s.searches * 0.31),
  s.searches * 22, ROUND(s.searches * 0.52), ROUND(s.searches * 0.021),
  ROUND(s.searches * 0.045),
  ROUND(s.avg_results, 2), 4.20,
  ROUND(s.zero_results / GREATEST(1, s.searches), 4),
  ROUND(s.searches * 0.52 / GREATEST(1, s.searches * 22), 4),
  NOW(3)
FROM (
  SELECT DATE(sq.searched_at) AS stat_date,
         COUNT(*) AS searches,
         SUM(sq.result_count = 0) AS zero_results,
         AVG(sq.result_count) AS avg_results
    FROM search_queries sq
   GROUP BY DATE(sq.searched_at)
) s;

-- Counters, derived.
UPDATE search_synonyms sy
  JOIN search_synonym_sets ss ON ss.id = sy.set_id
   SET sy.match_count = 0;

UPDATE search_facet_definitions f
   SET f.is_active = 1;
