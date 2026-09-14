/**
 * Which media and document kinds belong to which marketplace category.
 *
 * Floor plans and virtual tours are property features — they make no sense on a
 * car or a watch — and the useful document types differ per category (a car has
 * a registration and a service history; real estate has a title deed and an
 * NOC). This is the one place that decides it, for uploads, links and the
 * add/edit forms.
 *
 * Keyed by `listingType` (`utils/categories.js`). `resolveCategoryMediaPolicy`
 * accepts any category alias.
 */
import { resolveCategory } from "./categories.js";

// All document types the schema accepts (`documents.document_type`, held in
// `listing_media.tag`). Category lists below are subsets of this.
export const ALL_DOCUMENT_TYPES = Object.freeze([
  "brochure",
  "title_deed",
  "price_list",
  "payment_plan",
  "noc",
  "contract",
  "spec_sheet",
  "survey",
  "inspection_report",
  "valuation",
  "service_charge",
  "maintenance_log",
  "registration",
  "insurance",
  "other",
]);

const REAL_ESTATE_DOCS = ["brochure", "title_deed", "noc", "contract", "spec_sheet", "survey", "valuation", "service_charge", "other"];
const DEVELOPMENT_DOCS = ["brochure", "price_list", "payment_plan", "noc", "spec_sheet", "contract", "other"];
const CAR_DOCS = ["registration", "inspection_report", "maintenance_log", "insurance", "valuation", "spec_sheet", "contract", "other"];
const MARINE_DOCS = ["registration", "survey", "inspection_report", "maintenance_log", "insurance", "valuation", "spec_sheet", "contract", "other"];
const AVIATION_DOCS = ["registration", "inspection_report", "maintenance_log", "spec_sheet", "insurance", "valuation", "contract", "other"];
const WATCH_DOCS = ["brochure", "spec_sheet", "valuation", "insurance", "maintenance_log", "contract", "other"];

export const CATEGORY_MEDIA_POLICY = Object.freeze({
  "real-estate": { floorPlan: true, virtualTour: true, video: true, documentTypes: REAL_ESTATE_DOCS },
  "real-estate-developments": { floorPlan: true, virtualTour: true, video: true, documentTypes: DEVELOPMENT_DOCS },
  cars: { floorPlan: false, virtualTour: false, video: true, documentTypes: CAR_DOCS },
  yachts: { floorPlan: false, virtualTour: false, video: true, documentTypes: MARINE_DOCS },
  jets: { floorPlan: false, virtualTour: false, video: true, documentTypes: AVIATION_DOCS },
  helicopters: { floorPlan: false, virtualTour: false, video: true, documentTypes: AVIATION_DOCS },
  watches: { floorPlan: false, virtualTour: false, video: true, documentTypes: WATCH_DOCS },
});

const FALLBACK = CATEGORY_MEDIA_POLICY["real-estate"];

/** The media policy for a category, given any alias (slug, listingType, root id). */
export function resolveCategoryMediaPolicy(categoryValue) {
  const definition = resolveCategory(categoryValue);
  return (definition && CATEGORY_MEDIA_POLICY[definition.listingType]) || FALLBACK;
}

/** Does this category allow a `floor_plan` / `virtual_tour` / `video` media row? */
export function categoryAllowsMedia(categoryValue, mediaType) {
  const policy = resolveCategoryMediaPolicy(categoryValue);
  if (mediaType === "floor_plan") return policy.floorPlan;
  if (mediaType === "virtual_tour") return policy.virtualTour;
  if (mediaType === "video") return policy.video;
  return true; // image / document handled elsewhere
}

/** The document types (the `tag` on a `document` row) this category offers. */
export function categoryDocumentTypes(categoryValue) {
  return resolveCategoryMediaPolicy(categoryValue).documentTypes;
}
