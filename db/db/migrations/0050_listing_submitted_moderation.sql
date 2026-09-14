-- 0050_listing_submitted_moderation.sql
--
-- A listing created through the portal with "Submit for review" was inserted with
-- status = 'pending_review' but moderation_status = 'not_submitted' (listings.service.js
-- hardcoded the latter on create; only the later status-change path set 'pending').
-- The admin queue reads `status`, so these listings were reviewable, but every surface
-- that reads `moderation_status` — the portal's "Moderation:" badge first — reported a
-- submitted listing as never submitted.
--
-- The create path now derives moderation_status from the status it inserts. This
-- corrects the rows written before that fix. Idempotent: a second run matches nothing.

UPDATE listings
   SET moderation_status = 'pending'
 WHERE status = 'pending_review'
   AND moderation_status = 'not_submitted'
   AND deleted_at IS NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0050', 'listing_submitted_moderation')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
