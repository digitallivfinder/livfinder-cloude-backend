import { AppError } from "../../utils/errors.js";
import { isPropertySegment, normalizeSegment, typeFitsSegment } from "../search/propertySegments.js";

const LABEL = { residential: "Residential", commercial: "Commercial" };

function invalid(message, field = "propertySegment") {
  return AppError.validation("Some information is invalid.", { [field]: message });
}

/**
 * The Residential / Commercial a real-estate listing is saved with.
 *
 * Every way a listing arrives — the portal and admin forms, an edit, the API, a CSV or XML feed —
 * goes through this, so they all follow one rule:
 *
 * - a segment given is used, and the property type must belong to it ("A Villa is residential");
 * - no segment, and the type belongs to only one → that one (a Villa is Residential);
 * - no segment, and the type can be either (Plot, Whole Building) or there is no type → refused,
 *   asking for the segment.
 *
 * On an edit, `stored` is the listing's current segment: an edit that changes neither keeps it, and
 * one that only changes the type to a single-segment type follows that type.
 *
 * @param {object} input
 * @param {string|null|undefined} input.requested  the segment sent, if any
 * @param {string|null} input.typeSegment           the property type's `categories.property_segment`
 * @param {string|null} input.typeName              the property type's name, for messages
 * @param {string|null} [input.stored]              the listing's current segment (edits)
 * @returns {"residential"|"commercial"}
 */
export function decideSegment({ requested, typeSegment = null, typeName = null, stored = null }) {
  const asked = requested === undefined || requested === null || requested === "" ? null : normalizeSegment(requested);
  if (asked !== null && !isPropertySegment(asked)) throw invalid("Choose Residential or Commercial.");

  if (asked) {
    if (!typeFitsSegment(typeSegment, asked)) {
      throw invalid(
        `${typeName || "This property type"} is ${LABEL[typeSegment] || typeSegment}. Choose a ${LABEL[asked].toLowerCase()} property type, or ${LABEL[typeSegment] || typeSegment}.`,
        "categorySlug"
      );
    }
    return asked;
  }

  // Nothing sent: a type that belongs to one segment decides it.
  if (typeSegment === "residential" || typeSegment === "commercial") return typeSegment;
  // An edit keeps what it had when the type allows it.
  if (stored && typeFitsSegment(typeSegment, stored)) return stored;
  throw invalid(
    typeName
      ? `A ${typeName} can be residential or commercial. Choose Residential or Commercial.`
      : "Choose Residential or Commercial."
  );
}
