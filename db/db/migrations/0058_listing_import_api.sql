-- =============================================================================
-- 0058 — listing import API: provider, queued items, provenance
-- =============================================================================
-- Companies push listings into their own account with an API key
-- (`/v1/partner/*`). Every push is recorded as a `feed_imports` run under one
-- inbound connection per organization, provider `livfinder_import`.
--
-- Provenance: a run records the key, the caller's IP and user agent; a listing
-- records the key that created or last changed it, alongside the existing
-- `source` / `source_reference` (the partner's own id). Together they answer
-- "where did this listing come from" for the company and for admins.
--
-- Post-seed on a fresh `load.sh all`: the provider row is inserted after the
-- seeded providers so their ids do not move.
-- =============================================================================

INSERT INTO integration_providers
  (code, name, provider_kind, direction, transport, format, auth_type,
   max_batch_size, status, notes)
VALUES
  ('livfinder_import', 'LivFinder Listing API', 'crm', 'inbound', 'http_api', 'json', 'api_key',
   100, 'available',
   'Companies push their own listings with an API key created in Portal > API & Integrations.')
ON DUPLICATE KEY UPDATE name = VALUES(name), auth_type = VALUES(auth_type), max_batch_size = VALUES(max_batch_size);

-- A bulk push is accepted first and processed afterwards; its items wait as `queued`.
ALTER TABLE feed_import_items
  MODIFY COLUMN status ENUM('queued','success','warning','failed','skipped') NOT NULL DEFAULT 'success',
  MODIFY COLUMN processed_at DATETIME(3) NULL DEFAULT NULL;

ALTER TABLE feed_imports
  ADD COLUMN api_client_id BIGINT UNSIGNED NULL AFTER account_id,
  ADD COLUMN source_ip VARBINARY(16) NULL AFTER api_client_id,
  ADD COLUMN source_user_agent VARCHAR(300) NULL AFTER source_ip,
  ADD KEY ix_feed_imports_api_client (api_client_id, created_at),
  ADD CONSTRAINT fk_feed_imports_api_client FOREIGN KEY (api_client_id) REFERENCES api_clients (id) ON DELETE SET NULL;

ALTER TABLE listings
  ADD COLUMN source_api_client_id BIGINT UNSIGNED NULL AFTER source_reference,
  ADD KEY ix_listings_source_api_client (source_api_client_id),
  ADD CONSTRAINT fk_listings_source_api_client FOREIGN KEY (source_api_client_id) REFERENCES api_clients (id) ON DELETE SET NULL;

INSERT INTO schema_migrations (version, name) VALUES ('0058', 'listing_import_api')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
