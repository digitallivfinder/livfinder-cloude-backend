-- =============================================================================
-- 0074_destination_photos.sql
--
-- Real photographs for the magazine's destination pages ("Explore markets").
--
-- The demo seed pointed every destination at https://cdn.livfinder.com/destinations/<city>.jpg,
-- a host that does not exist, so the API served a generated placeholder (a flat colour with a
-- sun and two hills) for all 24 cities. These are free Unsplash photographs
-- (https://unsplash.com/license), one per city, chosen 2026-11-09.
--
-- Only rows still holding the seed URL change: an image set in the admin since is kept.
-- Safe to run more than once.
-- =============================================================================

UPDATE editorial_terms
   SET cover_image_url = CASE cover_image_url
    WHEN 'https://cdn.livfinder.com/destinations/abu-dhabi.jpg' THEN 'https://images.unsplash.com/photo-1651467606797-e1c660cf3fda?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/dubai.jpg' THEN 'https://images.unsplash.com/photo-1512453979798-5ea266f8880c?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/sydney.jpg' THEN 'https://images.unsplash.com/photo-1624138784614-87fd1b6528f8?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/toronto.jpg' THEN 'https://images.unsplash.com/photo-1543962226-818f4301073f?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/geneva.jpg' THEN 'https://images.unsplash.com/photo-1574904935745-7e40279f589d?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/barcelona.jpg' THEN 'https://images.unsplash.com/photo-1583422409516-2895a77efded?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/ibiza.jpg' THEN 'https://images.unsplash.com/photo-1631444195070-225ba8898160?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/madrid.jpg' THEN 'https://images.unsplash.com/photo-1543783207-ec64e4d95325?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/marbella.jpg' THEN 'https://images.unsplash.com/photo-1589642073293-d0d511afb66e?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/palma.jpg' THEN 'https://images.unsplash.com/photo-1617093888347-f73de2649f94?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/cannes.jpg' THEN 'https://images.unsplash.com/photo-1659642081573-ac1a040d2e50?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/paris.jpg' THEN 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/saint-tropez.jpg' THEN 'https://images.unsplash.com/photo-1662895450073-0cc13cfc562f?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/london.jpg' THEN 'https://images.unsplash.com/photo-1513635269975-59663e0ac1ad?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/athens.jpg' THEN 'https://images.unsplash.com/photo-1603565816030-6b389eeb23cb?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/mykonos.jpg' THEN 'https://images.unsplash.com/photo-1601581875309-fafbf2d3ed3a?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/denpasar.jpg' THEN 'https://images.unsplash.com/photo-1577717903315-1691ae25ab3f?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/rome.jpg' THEN 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/cabo-san-lucas.jpg' THEN 'https://images.unsplash.com/photo-1580846629083-02669741360a?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/cascais.jpg' THEN 'https://images.unsplash.com/photo-1615672337780-6e19a28a5b39?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/lisbon.jpg' THEN 'https://images.unsplash.com/photo-1585208798174-6cedd86e019a?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/loule.jpg' THEN 'https://images.unsplash.com/photo-1566988148642-343730e135bf?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/doha.jpg' THEN 'https://images.unsplash.com/photo-1700901742651-6b353164caf3?auto=format&fit=crop&w=1200&q=80'
    WHEN 'https://cdn.livfinder.com/destinations/jeddah.jpg' THEN 'https://images.unsplash.com/photo-1586715065342-98d1f6016fd1?auto=format&fit=crop&w=1200&q=80'
    ELSE cover_image_url
  END
 WHERE taxonomy = 'destination'
   AND cover_image_url LIKE 'https://cdn.livfinder.com/destinations/%';

INSERT INTO schema_migrations (version, name) VALUES ('0074', 'destination_photos')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
