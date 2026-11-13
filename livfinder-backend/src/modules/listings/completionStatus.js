/**
 * Shell and core is a commercial completion state — a building finished outside and bare inside,
 * let or sold for the tenant to fit out. The listing forms offer it only when the listing is
 * Commercial; a residential listing sent with it (an import, a feed, the API) is stored as Ready,
 * which is what the website counts it as anyway.
 *
 * @param {string} listingType   "real-estate", "cars" …
 * @param {object|undefined} detail  the detail being written
 * @param {string|null} segment  the listing's Residential / Commercial (as it will be saved)
 * @returns {object|undefined} the detail, aligned (a new object when anything changed)
 */
export function alignCompletionStatus(listingType, detail, segment) {
  if (listingType !== "real-estate" || detail?.completionStatus !== "shell_and_core") return detail;
  if (segment === "commercial") return detail;
  return { ...detail, completionStatus: "ready" };
}
