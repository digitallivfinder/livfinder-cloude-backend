import { z } from "zod";

const optionalString = (max = 200) =>
  z.string().trim().max(max).optional().or(z.literal("").transform(() => undefined));

/** Any multi-select field: `?developer=emaar&developer=nakheel` or `?developer=emaar,nakheel`. */
const repeatable = (max = 120) =>
  z.union([z.string().max(max), z.array(z.string().max(max)).max(50)]).optional();

/**
 * The public Projects query contract.
 *
 * Named for what the URL says, not for what the column is called: these keys
 * are the shareable part of a Projects URL and changing one breaks every link
 * anyone has saved.
 *
 * `sort` is an enum rather than a free string so a typo is a 422 instead of a
 * silent fall-back to the default order — the failure mode where a control
 * appears to work and does nothing.
 */
export const projectSearchQuery = z.object({
  developer: repeatable(160),
  projectType: repeatable(40),
  status: repeatable(40),
  launchStatus: repeatable(40),
  ownership: repeatable(40),
  propertyType: repeatable(40),
  availability: repeatable(40),
  paymentPlan: repeatable(40),
  beds: repeatable(8),
  bedrooms: repeatable(8),

  handoverFrom: optionalString(10),
  handoverTo: optionalString(10),
  priceMin: z.coerce.number().min(0).max(1e15).optional(),
  priceMax: z.coerce.number().min(0).max(1e15).optional(),
  currency: optionalString(3),
  areaMin: z.coerce.number().min(0).max(1e9).optional(),
  areaMax: z.coerce.number().min(0).max(1e9).optional(),
  maxDownPayment: z.coerce.number().min(0).max(100).optional(),
  completionMin: z.coerce.number().min(0).max(100).optional(),

  country: optionalString(160),
  state: optionalString(160),
  city: optionalString(160),
  community: optionalString(160),
  subcommunity: optionalString(160),
  location: repeatable(80),

  q: optionalString(120),
  featured: optionalString(6),
  sort: z
    .enum(["featured", "newest", "handoverSoonest", "handoverLatest", "priceAsc", "priceDesc", "completion"])
    .optional()
    .or(z.literal("").transform(() => undefined)),
  page: z.coerce.number().int().min(1).max(2000).optional(),
  pageSize: z.coerce.number().int().min(1).max(60).optional(),
});

export const projectFacetQuery = projectSearchQuery.extend({
  facet: z.string().trim().min(1).max(40),
});

export const developerQuery = z.object({
  q: optionalString(120),
  country: optionalString(160),
  page: z.coerce.number().int().min(1).max(500).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).optional(),
});
