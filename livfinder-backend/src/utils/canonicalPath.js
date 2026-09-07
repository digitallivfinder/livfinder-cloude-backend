import { slugify } from "./slug.js";
import { categoryByRootId } from "./categories.js";

/**
 * The user-facing marketplace URL contract, mirrored from the frontend's
 * `marketplaceRouteSchema`. The backend is the writer of
 * `listings.canonical_path`, so this function and that schema must agree.
 *
 *   real-estate  /real-estate/{country}/{state}/{city}/{community}/{subcommunity}/{slug}
 *   cars         /cars/{make}/{model}/{year}/{slug}
 *   yachts       /yachts/{manufacturer}/{model}/{year}/{slug}
 *   jets         /jets/{manufacturer}/{model}/{year}/{slug}
 *   helicopters  /helicopters/{manufacturer}/{model}/{year}/{slug}
 *   watches      /watches/{brand}/{collection}/{slug}
 *
 * Hierarchy segments stop at the first level the listing does not have, so a
 * property with no sub-community simply has a shorter path. The slug is always
 * the last segment.
 */
export function buildCanonicalPath({
  rootCategoryId,
  listingType,
  slug,
  location = {},
  brandSlug,
  modelSlug,
  year,
}) {
  const definition = listingType
    ? { routeBase: listingType }
    : categoryByRootId(rootCategoryId);
  if (!definition) return null;
  const base = definition.routeBase || definition;
  const segments = [base];

  if (base === "real-estate") {
    for (const level of ["country", "state", "city", "community", "subCommunity"]) {
      const value = location[level];
      if (!value) break;
      segments.push(slugify(value));
    }
  } else if (base === "watches") {
    if (brandSlug) segments.push(slugify(brandSlug));
    if (brandSlug && modelSlug) segments.push(slugify(modelSlug));
  } else {
    if (brandSlug) segments.push(slugify(brandSlug));
    if (brandSlug && modelSlug) segments.push(slugify(modelSlug));
    if (brandSlug && modelSlug && year) segments.push(String(year));
  }

  segments.push(slugify(slug));
  return `/${segments.filter(Boolean).join("/")}`;
}

/** Splits a marketplace pathname back into its category and segments. */
export function splitCanonicalPath(pathname = "/") {
  const segments = String(pathname).split("/").filter(Boolean);
  if (!segments.length) return null;
  const base = segments[0] === "helpcopters" ? "helicopters" : segments[0];
  const definition = categoryByRootId(
    { "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 }[base]
  );
  if (!definition) return null;
  return { base, definition, segments: segments.slice(1) };
}
