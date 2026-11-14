/**
 * One rent duration per rental, however it was sent.
 *
 * A real-estate rental carries its duration twice: `detail.rentPeriod` (yearly, monthly …), which
 * the listing form asks for as "Rent period", and the listing's `pricePeriod` (year, month …),
 * which the price is quoted per and which the search's Rent duration filter reads from the
 * projection. Saved independently, the two could disagree — a "Monthly" rental quoted per "total"
 * matched no duration at all — so they are aligned before anything is written:
 *
 * - `detail.rentPeriod` given → `pricePeriod` follows it (the form's own field wins);
 * - only a rent `pricePeriod` given (API, imports, feeds) → `detail.rentPeriod` follows it.
 *
 * Sales and every other marketplace are returned unchanged.
 */
// Half-yearly and Quarterly since 0080 (owner decision, 2026-11-14).
export const RENT_TO_PRICE_PERIOD = {
  yearly: "year", half_yearly: "half_year", quarterly: "quarter", monthly: "month", weekly: "week", daily: "day",
};
export const RENT_PERIODS = Object.keys(RENT_TO_PRICE_PERIOD);
export const PRICE_TO_RENT_PERIOD = Object.fromEntries(
  Object.entries(RENT_TO_PRICE_PERIOD).map(([rent, price]) => [price, rent])
);

/**
 * @param {string} listingType      "real-estate", "cars" …
 * @param {object} payload          the create / update body
 * @param {string|null} currentPurpose  the stored purpose code, for an update that does not resend it
 * @returns {object} the payload, aligned (a new object when anything changed)
 */
export function alignRentPeriod(listingType, payload = {}, currentPurpose = null) {
  if (listingType !== "real-estate") return payload;
  const purpose = payload.purpose ?? currentPurpose;
  if (purpose !== "rent") return payload;

  const rentPeriod = payload.detail?.rentPeriod;
  if (rentPeriod && RENT_TO_PRICE_PERIOD[rentPeriod]) {
    const pricePeriod = RENT_TO_PRICE_PERIOD[rentPeriod];
    return payload.pricePeriod === pricePeriod ? payload : { ...payload, pricePeriod };
  }

  const fromPrice = PRICE_TO_RENT_PERIOD[payload.pricePeriod];
  if (fromPrice && !rentPeriod) {
    return { ...payload, detail: { ...(payload.detail || {}), rentPeriod: fromPrice } };
  }
  return payload;
}
