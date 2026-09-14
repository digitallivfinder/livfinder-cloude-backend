/**
 * The one place the three category vocabularies meet.
 *
 *   dbCode      — `categories.code` for the seven root rows in the database
 *   frontendId  — the `id` in the frontend marketplaceCategories registry
 *   listingType — the frontend route/filter key, and the URL base segment
 *   label       — the human name the admin screens print
 */
const DEFINITIONS = [
  { dbCode: "real-estate", rootId: 1, frontendId: "realEstate", listingType: "real-estate", routeBase: "real-estate", label: "Real Estate", detailTable: "listing_real_estate", detailAlias: "re" },
  // Off-plan projects. Their records live in `projects`, not `listings`, so there
  // is no detail table — this entry exists for category access and category
  // vocabulary (root id 7, pinned in migration 0040).
  { dbCode: "real-estate-developments", rootId: 7, frontendId: "realEstateDevelopment", listingType: "real-estate-developments", routeBase: "real-estate-developments", label: "Real Estate Developments", detailTable: null, detailAlias: null },
  { dbCode: "cars", rootId: 2, frontendId: "car", listingType: "cars", routeBase: "cars", label: "Cars", detailTable: "listing_vehicle", detailAlias: "veh" },
  { dbCode: "yachts", rootId: 3, frontendId: "yacht", listingType: "yachts", routeBase: "yachts", label: "Yachts", detailTable: "listing_marine", detailAlias: "mar" },
  { dbCode: "jets", rootId: 4, frontendId: "jet", listingType: "jets", routeBase: "jets", label: "Jets", detailTable: "listing_aviation", detailAlias: "av" },
  { dbCode: "helicopters", rootId: 5, frontendId: "helicopter", listingType: "helicopters", routeBase: "helicopters", label: "Helicopters", detailTable: "listing_aviation", detailAlias: "av" },
  { dbCode: "watches", rootId: 6, frontendId: "watch", listingType: "watches", routeBase: "watches", label: "Watches", detailTable: "listing_timepiece", detailAlias: "tp" },
];

const ALIASES = new Map();
for (const definition of DEFINITIONS) {
  for (const alias of [
    definition.dbCode,
    definition.frontendId,
    definition.listingType,
    definition.routeBase,
    definition.frontendId.toLowerCase(),
  ]) {
    ALIASES.set(alias, definition);
  }
}
// Frontend aliases that do not fall out of the canonical names. Keyed by dbCode
// so the list is insensitive to the order of DEFINITIONS.
const defByCode = (code) => DEFINITIONS.find((definition) => definition.dbCode === code);
ALIASES.set("property", defByCode("real-estate"));
ALIASES.set("properties", defByCode("real-estate"));
ALIASES.set("realestate", defByCode("real-estate"));
ALIASES.set("realEstateDevelopments", defByCode("real-estate-developments"));
ALIASES.set("developments", defByCode("real-estate-developments"));
ALIASES.set("development", defByCode("real-estate-developments"));
ALIASES.set("projects", defByCode("real-estate-developments"));
ALIASES.set("off-plan", defByCode("real-estate-developments"));
ALIASES.set("private-jets", defByCode("jets"));
ALIASES.set("rotorcraft", defByCode("helicopters"));
ALIASES.set("helpcopters", defByCode("helicopters"));

/**
 * `rootId` above is the id the seed loader happens to assign. Reseeding in a different order
 * would silently misfile every listing, every dashboard and every scope check — the single
 * most load-bearing hardcoded value in the service.
 *
 * This reconciles the table against `categories.code` at boot and corrects any drift, so the
 * literals become a starting guess rather than an assumption. Called from server.js; the tests
 * call it too, because they run against the same database.
 */
export async function reconcileCategoryIds(query) {
  const rows = await query("SELECT id, code FROM categories WHERE depth = 0 AND deleted_at IS NULL");
  const byCode = new Map(rows.map((row) => [row.code, Number(row.id)]));
  const corrections = [];
  for (const definition of DEFINITIONS) {
    const actual = byCode.get(definition.dbCode);
    if (actual == null) {
      corrections.push({ code: definition.dbCode, expected: definition.rootId, actual: null, problem: "missing" });
      continue;
    }
    if (actual !== definition.rootId) {
      corrections.push({ code: definition.dbCode, expected: definition.rootId, actual });
      definition.rootId = actual;
    }
  }
  return corrections;
}

export const CATEGORY_DEFINITIONS = Object.freeze(DEFINITIONS);
export const ROOT_CATEGORY_IDS = Object.freeze(DEFINITIONS.map((definition) => definition.rootId));

export function resolveCategory(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === "number") {
    return DEFINITIONS.find((definition) => definition.rootId === value) || null;
  }
  return ALIASES.get(String(value).trim()) || null;
}

export function categoryByRootId(rootId) {
  return DEFINITIONS.find((definition) => definition.rootId === Number(rootId)) || null;
}

export function frontendCategoryId(rootId) {
  return categoryByRootId(rootId)?.frontendId ?? null;
}

export function listingTypeFor(rootId) {
  return categoryByRootId(rootId)?.listingType ?? null;
}

/** The purposes a category can legitimately carry. */
export const CATEGORY_PURPOSES = Object.freeze({
  "real-estate": ["sale", "rent"],
  "real-estate-developments": ["sale"],
  cars: ["sale", "rent"],
  yachts: ["sale", "charter"],
  jets: ["sale", "charter"],
  helicopters: ["sale", "charter"],
  watches: ["sale"],
});
