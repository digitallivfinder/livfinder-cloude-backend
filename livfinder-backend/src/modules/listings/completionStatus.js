/**
 * Shell and core is a commercial completion state — a building finished outside and bare inside,
 * let or sold for the tenant to fit out. The listing forms offer it only for these types; a
 * residential listing sent with it (an import, a feed, the API) is stored as Ready, which is what
 * the website counts it as anyway.
 */
export const SHELL_AND_CORE_TYPES = new Set(["offices", "retail", "buildings"]);

/**
 * @param {string} listingType           "real-estate", "cars" …
 * @param {object} payload               the create / update body
 * @param {string|null} storedCategory   the stored leaf category slug, for an edit that does not resend it
 * @returns {object} the payload, aligned (a new object when anything changed)
 */
export function alignCompletionStatus(listingType, payload = {}, storedCategory = null) {
  if (listingType !== "real-estate" || payload.detail?.completionStatus !== "shell_and_core") return payload;
  const category = payload.categorySlug ?? storedCategory;
  if (SHELL_AND_CORE_TYPES.has(category)) return payload;
  return { ...payload, detail: { ...payload.detail, completionStatus: "ready" } };
}
