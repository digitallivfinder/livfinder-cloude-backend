import { AppError } from "../../utils/errors.js";

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

/** Not built yet. Under Construction was folded into Off plan (0076) but an old payload may carry it. */
export const OFF_PLAN_STATUSES = ["off_plan", "under_construction"];
export const OFF_PLAN_RENT_MESSAGE = "Off plan is for sale only. A rental is Ready.";

/**
 * Off plan is for sale only (owner decision, 2026-11-14): a property not yet built cannot be let.
 * A rental sent as off plan — from the form, the API or a pushed file — is refused, not quietly
 * changed, so the sender sees what was wrong. Pass the purpose and completion status the listing
 * will have once written (the stored value where the request does not change it).
 */
export function assertOffPlanForSale(listingType, { purpose, completionStatus }) {
  if (listingType !== "real-estate") return;
  if (purpose === "rent" && OFF_PLAN_STATUSES.includes(completionStatus)) {
    throw AppError.validation("Some information is invalid.", { "detail.completionStatus": OFF_PLAN_RENT_MESSAGE });
  }
}
