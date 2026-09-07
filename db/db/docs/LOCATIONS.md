# The location hierarchy

```
Country  →  State / Emirate / Province  →  City  →  Community  →  Sub-Community
  250              5,308                  152,976      809           1,799
```

161,142 rows in one table, 481,956 closure edges. This document covers the
model, what "real data" means at each tier, and the per-market coverage.

---

## One table, not five

The admin portal presents five management screens and public URLs are five
segments deep, so five physical tables looks like the obvious mapping. It is the
wrong one:

**Ancestor and descendant queries are the common case.** Breadcrumbs, "everything
under Dubai", and the location facet all need them. Across five tables that is a
five-way join with a different shape at every level. Against one tree it is one
indexed read of the closure table.

**Depth is not uniform in the real world.** Monaco and Hong Kong have no
meaningful state tier — the source dataset has no state row for either, and
inventing one would be a lie the whole schema then has to carry. Dubai, in the
other direction, has genuine building-level granularity below sub-community
(Princess Tower, Shoreline Apartment 8). A fixed five-table design can express
neither.

**Autocomplete searches every level at once.** A user typing `mar` should see
Marbella (city), Dubai Marina (community), Marassi (sub-community) and Al Marjan
Island (community) in one ranked list. One table, one index, one query.

The five admin screens are served by `WHERE level = '…'`, which is an indexed
scan of exactly the rows that screen shows. Nothing is given up.

### `level` versus `depth`

Two different questions, so two columns:

- **`level`** is the semantic tier — what the thing *is*. Drives routing, the
  admin screens, and the label shown to users.
- **`depth`** is the physical tree position, 0 for a country. Drives tree maths
  and the closure table.

They usually agree. Where a country has no state tier they diverge: Monaco's
communities are `level = 'community'` at `depth = 2`, not 3. The cascade UI reads
`level` and simply finds no rows for the missing tier; nothing needs to
special-case it.

The `level` enum also defines `district` and `building`, which are **not seeded**.
They exist so a market that needs a sixth tier is a data change, never a
migration.

---

## Three access paths, maintained side by side

Deliberately redundant, because they answer different questions at different
costs.

### 1. `path` — URL routing and breadcrumbs, zero joins

```sql
SELECT id, level, name FROM locations
 WHERE path = 'united-arab-emirates/dubai/dubai/palm-jumeirah/shoreline-apartments';
```

One unique-index hit. `path_ids` carries the same chain as ids
(`1231/103391/1000032/50000001/60000001`) for cheap breadcrumb rendering and a
stable tree sort key.

### 2. `location_closure` — arbitrary-depth set operations

One row per (ancestor, descendant) pair including the self-pair at depth 0.

```sql
-- Breadcrumb: ancestors of a sub-community
SELECT a.level, a.name
  FROM location_closure c JOIN locations a ON a.id = c.ancestor_id
 WHERE c.descendant_id = 60000001
 ORDER BY c.depth DESC;

-- Everything anywhere under Dubai, at any depth
SELECT COUNT(*) FROM listings l
  JOIN location_closure c ON c.descendant_id = l.location_id
 WHERE c.ancestor_id = 1000032;
```

~4 rows per node at five levels — 481,956 rows for the full global tree, a
rounding error next to the query cost it removes.

### 3. `parent_id` — cascading dropdowns

```sql
SELECT id, name FROM locations
 WHERE parent_id = ? AND status = 'active'
 ORDER BY sort_order, name;
```

### Plus denormalised ancestors on every row

`country_id`, `state_id`, `city_id` and `community_id` are stored on every
location *and* on every listing. This is what makes "villas in Dubai" a single
indexed predicate instead of a closure join — and it is the single
most-executed query in the product. The columns are derived from `parent_id` by
`sp_location_rebuild_tree()` and, on listings, maintained by triggers, so they
cannot drift.

---

## Data provenance

### Countries, states, cities — real, sourced

From [`dr5hn/countries-states-cities-database`](https://github.com/dr5hn/countries-states-cities-database)
(ODbL 1.0), transcribed into `seeds/020_geo_countries.sql`,
`021_geo_states.sql` and `022_geo_cities_*.sql`:

- **250 countries** — ISO 3166-1 alpha-2/alpha-3/numeric, dialling code, capital,
  currency, TLD, native name, nationality, region/subregion, postal-code format
  and validation regex, coordinates, population.
- **5,308 states** — ISO 3166-2 codes, FIPS codes, upstream subdivision type
  (province, emirate, canton, prefecture…), native names, coordinates.
- **152,976 cities** — names and WGS 84 coordinates.
- **3,484 localised country names** across 14 languages, from the dataset's own
  translation payload, so an Arabic or Chinese visitor sees native country names.

Six additional cities are created by the builder for markets the dataset does
not carry as a city row — Monaco, Hong Kong, Sotogrande, Verbier, Buenos Aires
and Providenciales — with real coordinates supplied in the market files. These
are marked `source = 'livfinder'` so a re-import can tell them apart.

### Communities and sub-communities — hand-authored

No open dataset carries these at the granularity a luxury portal needs. They live
directly in `seeds/023_geo_communities.sql` and
`seeds/024_geo_sub_communities.sql`, written from market knowledge.

**Nothing here is generated or inferred.** Where a market does not genuinely use
a fifth tier, `subs` is an empty list rather than invented names. Lake Como has
towns, not communities-within-cities, and forcing a fifth level there would be
fabrication. Where a market genuinely has only one sub-city tier, the hierarchy
is four levels deep for that market and the schema handles it.

**Coordinates are present where known and NULL where not.** An approximate pin is
worse than none: it puts every community in a city on the same map point and
makes radius search silently wrong. Curated coordinates exist for the Gulf, most
of Europe and the major US markets; other communities have NULL and should be
geocoded before map search is enabled for them.

**Aliases matter more than they look.** 288 alias rows cover what users actually
type: `JBR` for Jumeirah Beach Residence, `Akoya` for DAMAC Hills, `Tecom` for
Barsha Heights, `The Palm` for Palm Jumeirah, `Banus` for Puerto Banús, `KAFD`
for King Abdullah Financial District. Without them a large share of high-intent
searches return nothing.

---

## Coverage matrix

Every country has country and state tiers. This table shows where communities
and sub-communities have been curated.

| Country | Communities | Sub-communities | Depth | Notes |
|---------|------------:|----------------:|:-----:|-------|
| 🇦🇪 United Arab Emirates | 160 | 816 | 5 | Full Bayut/Property Finder parity. Dubai 91/663, Abu Dhabi 30, plus all five northern emirates |
| 🇺🇸 United States | 102 | 215 | 5 | Miami/Miami Beach, NYC, LA, Newport Beach, SF, Aspen, Palm Beach, Hamptons, Las Vegas, Austin, Hawaii |
| 🇪🇸 Spain | 53 | 133 | 5 | Marbella (full Golden Mile / Nueva Andalucía / Zagaleta), Madrid, Barcelona, Mallorca, Ibiza, Sotogrande |
| 🇬🇧 United Kingdom | 51 | 131 | 5 | London prime with named estates, plus Surrey, Ascot, Edinburgh, Cheshire |
| 🇮🇹 Italy | 40 | 31 | 5 | Milan, Rome, Como, Sardinia, Forte dei Marmi, Florence, Positano, Venice |
| 🇫🇷 France | 36 | 42 | 5 | Paris arrondissements + quartiers, Cannes, Saint-Tropez, Cap Ferrat, Nice, Courchevel, Megève |
| 🇸🇦 Saudi Arabia | 26 | 19 | 5 | Riyadh (incl. Diriyah, KAFD), Jeddah, NEOM |
| 🇵🇹 Portugal | 25 | 25 | 5 | Lisbon, Cascais, Algarve (Quinta do Lago, Vale do Lobo, Vilamoura), Porto, Comporta |
| 🇬🇷 Greece | 22 | 22 | 5 | Athens + Riviera, Mykonos, Santorini |
| 🇦🇺 Australia | 22 | 20 | 5 | Sydney eastern suburbs, Melbourne, Gold Coast |
| 🇨🇦 Canada | 19 | 18 | 5 | Toronto, Vancouver, Montreal |
| 🇨🇭 Switzerland | 18 | 0 | 4 | Geneva, Zurich Goldküste, Verbier, St. Moritz — communes, no sub-tier |
| 🇹🇷 Turkey | 16 | 16 | 5 | Istanbul Bosphorus, Bodrum |
| 🇿🇦 South Africa | 16 | 19 | 5 | Cape Town Atlantic Seaboard, Johannesburg |
| 🇹🇭 Thailand | 15 | 24 | 5 | Phuket west coast, Bangkok |
| 🇭🇰 Hong Kong | 14 | 24 | 5 | The Peak, Mid-Levels, Island South, Sai Kung |
| 🇲🇽 Mexico | 13 | 8 | 5 | Los Cabos, Mexico City |
| 🇩🇪 Germany | 12 | 12 | 5 | Munich, Berlin |
| 🇮🇳 India | 12 | 11 | 5 | Mumbai, Delhi |
| 🇶🇦 Qatar | 12 | 30 | 5 | The Pearl (all districts), Lusail, West Bay |
| 🇸🇬 Singapore | 10 | 28 | 5 | Districts 9/10/11, Sentosa Cove, Marina Bay |
| 🇧🇭 Bahrain | 10 | 23 | 5 | Amwaj, Durrat, Diyar, Bahrain Bay |
| 🇴🇲 Oman | 10 | 14 | 5 | Al Mouj, Muscat Bay, Jebel Sifah |
| 🇲🇨 Monaco | 9 | 20 | 5 | All nine wards, with named buildings — no state tier |
| 🇧🇷 Brazil | 9 | 7 | 5 | Rio, São Paulo |
| 🇰🇼 Kuwait | 9 | 2 | 5 | Kuwait City suburbs |
| 🇮🇩 Indonesia | 8 | 18 | 5 | Bali (Seminyak, Canggu, Uluwatu, Ubud) |
| 🇦🇹 Austria | 7 | 3 | 5 | Vienna, Kitzbühel |
| 🇪🇬 Egypt | 6 | 17 | 5 | New Cairo, Sheikh Zayed, New Capital |
| 🇯🇵 Japan | 6 | 22 | 5 | Tokyo wards |
| 🇲🇦 Morocco | 6 | 3 | 5 | Marrakesh |
| 🇦🇷 Argentina | 5 | 9 | 5 | Buenos Aires (city created; barrios modelled as communities) |
| 🇧🇸 Bahamas | 5 | 7 | 5 | Lyford Cay, Albany, Paradise Island |
| 🇨🇾 Cyprus | 5 | 4 | 5 | Limassol |
| 🇳🇿 New Zealand | 4 | 0 | 4 | Queenstown |
| 🇹🇨 Turks & Caicos | 4 | 3 | 5 | Grace Bay, Leeward |
| 🇧🇧 Barbados | 3 | 3 | 5 | Platinum Coast, Sandy Lane |
| 🇲🇹 Malta | 3 | 0 | 4 | Sliema, Tigné Point |
| 🇲🇺 Mauritius | 3 | 0 | 4 | Grand Baie |
| 🇲🇻 Maldives | 3 | 0 | 4 | Atolls |
| *All others (209)* | 0 | 0 | 3 | Country + state + city only |

**Depth 3** means the country has real country/state/city data and nothing below
it. That is the honest state for markets with no curated inventory, and adding a
market is an edit to one `VALUES` block in the community seed — no migration,
no generator, no build step.

---

## Working with the tree

### Autocomplete

```sql
-- Prefix match on the folded name, searchable rows only, best-stocked first
SELECT id, level, name, path, active_listing_count
  FROM locations
 WHERE is_searchable = 1 AND status = 'active'
   AND name_ascii LIKE CONCAT(?, '%')
 ORDER BY active_listing_count DESC, LENGTH(name)
 LIMIT 10;

-- Include aliases in the same result set
SELECT DISTINCT l.id, l.level, l.name, l.path
  FROM locations l
  LEFT JOIN location_aliases a ON a.location_id = l.id
 WHERE l.status = 'active' AND l.is_searchable = 1
   AND (l.name_ascii LIKE CONCAT(?, '%') OR a.alias_ascii LIKE CONCAT(?, '%'))
 LIMIT 10;
```

`name_ascii` is the diacritic-folded name, so a user on an English keyboard finds
Málaga, Nîmes, Ålesund and Şişli. Thirteen of the 152,976 city names are written
entirely in a script with no Latin decomposition (Cyrillic, Arabic, Thai); for
those `name_ascii` falls back to the name itself rather than being NULL, so they
stay searchable in their own script, and their slug becomes a stable `loc-<id>`.

### Popular areas in a city

```sql
SELECT name, slug, active_listing_count
  FROM locations
 WHERE city_id = ? AND level = 'community' AND status = 'active'
 ORDER BY active_listing_count DESC LIMIT 12;
```

Served from `ix_locations_popular`. Counts are maintained by
`sp_location_refresh_counts()`, which rolls them up the subtree — a country's
count includes everything beneath it.

### Renaming or merging a location

Set `status = 'merged'` and `merged_into_id` to the survivor. Old URLs then 301
rather than 404. Add a `location_aliases` row with
`alias_type = 'former_name', is_redirecting = 1` so the old slug keeps resolving.
Never delete a location that has ever been published.

### After a bulk import

```sql
CALL sp_location_rebuild_tree();      -- closure, depth, path, ancestor ids
CALL sp_location_refresh_counts();    -- inventory counts, rolled up
```

Then `make integrity`, which checks the tree is sound — including that each
node's closure edge count equals `depth + 1`.

---

## Optional geometry

`location_boundaries` holds a polygon per location, kept out of `locations`
because a SPATIAL index needs a NOT NULL geometry and only a minority of
locations will ever have a boundary traced. It carries a denormalised bounding
box for a cheap pre-filter before the polygon containment test.

On MySQL 8, migration `0015` adds `location_points` and `listing_points` — SRID
4326 POINT columns with real SPATIAL indexes — plus
`sp_listings_within_radius()`. Without `0015` the schema still does bounding-box
search from the indexed `latitude`/`longitude` DECIMAL columns; it just cannot
order by true distance.

**Axis order matters:** in SRID 4326 the first coordinate is *latitude*. Getting
it backwards produces distances that are wrong in a way that looks plausible.
`sp_rebuild_spatial_points()` is the only place points are constructed, so the
convention is applied once.
