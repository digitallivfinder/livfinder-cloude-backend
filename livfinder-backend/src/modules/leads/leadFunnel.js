/**
 * The short funnel a client works a lead through in the portal.
 *
 * `leads.status` is only the coarse outcome and `leads.stage_id` points at whichever
 * pipeline the lead was created on, so the step is derived from `status` + `stage_type`.
 * That way a lead on any pipeline reads correctly, and admin's own status logic (which
 * also reads `stage_type`) stays true after a client moves one.
 */

export const FUNNEL_STEPS = Object.freeze(["new", "contacted", "qualified", "viewing", "negotiating", "won", "lost"]);

const STEP_BY_STAGE_TYPE = Object.freeze({
  new: "new",
  contacted: "contacted",
  qualified: "qualified",
  nurturing: "viewing",
  proposal: "negotiating",
  negotiation: "negotiating",
  won: "won",
  lost: "lost",
  disqualified: "lost",
});

export function funnelStepOf(status, stageType) {
  if (status === "won") return "won";
  if (status === "lost" || status === "disqualified" || status === "archived") return "lost";
  return STEP_BY_STAGE_TYPE[stageType] ?? "new";
}

export function isClosedStep(step) {
  return step === "won" || step === "lost";
}

/** The status a step implies. Everything short of the two ends is still `open`. */
export function statusForStep(step) {
  return isClosedStep(step) ? step : "open";
}

/** A step's name in a category's own words: a car has a test drive, not a viewing. */
const VIEWING_BY_ROOT = Object.freeze({
  2: { label: "Test drive", bookingType: "test_drive" },
  3: { label: "Sea trial", bookingType: "sea_trial" },
  4: { label: "Inspection", bookingType: "inspection" },
  5: { label: "Inspection", bookingType: "inspection" },
});

export function viewingKindFor(rootCategoryId) {
  return VIEWING_BY_ROOT[Number(rootCategoryId)] ?? { label: "Viewing", bookingType: "viewing" };
}

const STEP_LABELS = Object.freeze({
  new: "New",
  contacted: "Contacted",
  qualified: "Qualified",
  negotiating: "Negotiating",
  won: "Won",
  lost: "Lost",
});

export function funnelStepLabel(step, rootCategoryId) {
  return step === "viewing" ? viewingKindFor(rootCategoryId).label : STEP_LABELS[step] ?? step;
}

/** The five reasons the portal offers, and the seeded `lead_lost_reasons` row each one files under. */
export const LOST_REASON_CODES = Object.freeze({
  budget: "price-too-high",
  bought_elsewhere: "bought-elsewhere",
  not_interested: "not-serious",
  no_response: "unresponsive",
  other: "other",
});

const INQUIRY_STATUS_BY_STEP = Object.freeze({
  new: "new",
  contacted: "contacted",
  qualified: "qualified",
  viewing: "viewing_scheduled",
  negotiating: "negotiating",
  won: "won",
  lost: "lost",
});

export function inquiryStatusForStep(step) {
  return INQUIRY_STATUS_BY_STEP[step] ?? null;
}

/** `closed` and `spam` are the client tidying the inquiry list, not a move in the funnel. */
export function stepForInquiryStatus(status) {
  return Object.keys(INQUIRY_STATUS_BY_STEP).find((step) => INQUIRY_STATUS_BY_STEP[step] === status) ?? null;
}
