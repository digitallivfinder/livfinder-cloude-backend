-- =============================================================================
-- Liv Finder — 0037 · project analytics event types
-- =============================================================================
-- `analytics_events` is already polymorphic — `subject_type` / `subject_id` —
-- so a project event needs no new table. What it did need was a vocabulary:
-- the enum described listings, agents, organisations and posts, and a project
-- detail view had to masquerade as a `page_view` or a `listing_view`. The first
-- is indistinguishable from any other page; the second is a lie that lands in
-- the listing funnel reports.
--
-- Five values are added, all of them things the Projects pages actually do:
--
--   project_view          the detail page was opened
--   gallery_open          the gallery or a media item was opened
--   floor_plan_request    a floor plan was requested (they are lead-gated)
--   developer_click       the developer's name, logo or profile was followed
--   inquiry_start         the enquiry form was opened, not yet submitted
--
-- A completed enquiry stays `inquiry_submit`, which already exists and is what
-- every conversion report counts — a project enquiry must land in the same
-- bucket as a listing enquiry or the funnel splits in two.
--
-- IDEMPOTENT: the ALTER restates the whole enum, so re-running it is a no-op.
-- =============================================================================

SET NAMES utf8mb4;

ALTER TABLE analytics_events
  MODIFY COLUMN event_type ENUM(
    'page_view','listing_view','listing_impression','search','filter_applied',
    'contact_view','call_click','whatsapp_click','email_click','inquiry_submit',
    'favourite_add','favourite_remove','share','brochure_request','video_play',
    'virtual_tour_open','map_open','signup','login','listing_publish',
    'agent_profile_view','organization_profile_view','post_view','outbound_click',
    'project_view','gallery_open','floor_plan_request','developer_click','inquiry_start'
  ) NOT NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0037', 'project_analytics_events')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
