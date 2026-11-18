/**
 * The kinds of organisation a company account can be (`organizations.kind`), with the label the
 * forms show. One list for the signup schema, the admin "Add Company" schema and the option set
 * the admin form reads (`organization.kind`), so a choice offered is always a choice accepted.
 */
export const ORGANIZATION_KIND_OPTIONS = Object.freeze([
  ["agency", "Real estate agency"],
  ["brokerage", "Brokerage"],
  ["developer", "Property developer"],
  ["dealership", "Car dealership"],
  ["yacht_broker", "Yacht broker"],
  ["aviation_broker", "Aviation broker"],
  ["watch_dealer", "Watch dealer"],
  ["marketing_partner", "Marketing partner"],
  ["service_partner", "Service partner"],
  ["media_partner", "Media partner"],
]);

export const ORGANIZATION_KINDS = Object.freeze(ORGANIZATION_KIND_OPTIONS.map(([value]) => value));
