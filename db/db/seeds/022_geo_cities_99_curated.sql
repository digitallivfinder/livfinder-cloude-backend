-- =============================================================================
-- Liv Finder — geography seed  (curated cities)
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
-- Regenerate with:  python3 db/tools/build_geo_seed.py
--
-- Markets the upstream dataset does not carry as a city row —
-- Monaco and Hong Kong (which are countries/territories with no
-- state tier), plus a handful of resort towns. Added so the
-- five-level cascade has somewhere to hang their communities.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO locations (id, public_id, parent_id, level, depth, country_id, state_id, city_id, community_id, name, name_ascii, slug, path, path_ids, latitude, longitude, timezone, status, is_searchable, is_core_market, population, sort_order, source, source_id) VALUES
(1900000, '01K2F2DKG0X0XS354VV446NN5K', 1145, 'city', 1, 1145, NULL, 1900000, NULL, 'Monaco', 'Monaco', 'monaco', 'monaco/monaco', '1145/1900000', 43.7384, 7.4246, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:monaco'),
(1900001, '01K2F2DKG020R9D3A2HGFYDVCX', 105325, 'city', 2, 1207, 105325, 1900001, NULL, 'Sotogrande', 'Sotogrande', 'sotogrande', 'spain/andalusia/sotogrande', '1207/105325/1900001', 36.287, -5.281, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:sotogrande'),
(1900002, '01K2F2DKG0ZEMN007RF7F53S2A', 102118, 'city', 2, 1085, 102118, 1900002, NULL, 'Santorini', 'Santorini', 'santorini', 'greece/south-aegean/santorini', '1085/102118/1900002', 36.3932, 25.4615, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:santorini'),
(1900003, '01K2F2DKG0NY15QCN2V81N5JQX', 105363, 'city', 2, 1227, 105363, 1900003, NULL, 'Providenciales', 'Providenciales', 'providenciales', 'turks-and-caicos-islands/providenciales/providenciales', '1227/105363/1900003', 21.794, -72.267, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:providenciales'),
(1900004, '01K2F2DKG0M2DTRZAY1D5ASM14', 104880, 'city', 2, 1011, 104880, 1900004, NULL, 'Buenos Aires', 'Buenos Aires', 'buenos-aires', 'argentina/autonomous-city-of-buenos-aires/buenos-aires', '1011/104880/1900004', -34.6037, -58.3816, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:buenos-aires'),
(1900005, '01K2F2DKG05CWPRTR188QVJEFT', 1098, 'city', 1, 1098, NULL, 1900005, NULL, 'Hong Kong', 'Hong Kong', 'hong-kong', 'hong-kong-s-a-r/hong-kong', '1098/1900005', 22.3193, 114.1694, NULL, 'active', 1, 1, NULL, 0, 'livfinder', 'city:hong-kong');

COMMIT;
SET autocommit = 1;
