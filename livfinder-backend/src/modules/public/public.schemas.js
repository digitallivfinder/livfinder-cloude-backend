import { z } from "zod";

const optionalString = (max = 200) => z.string().trim().max(max).optional().or(z.literal("").transform(() => undefined));

export const listingSearchQuery = z
  .object({
    category: optionalString(40),
    listingType: optionalString(40),
    propertyType: optionalString(80),
    type: optionalString(80),
    transactionType: optionalString(20),
    purpose: optionalString(20),
    country: optionalString(120),
    state: optionalString(120),
    city: optionalString(120),
    area: optionalString(120),
    community: optionalString(120),
    subcommunity: optionalString(120),
    location: z.union([z.string(), z.array(z.string())]).optional(),
    minPrice: z.coerce.number().min(0).max(1e15).optional(),
    maxPrice: z.coerce.number().min(0).max(1e15).optional(),
    priceMin: z.coerce.number().min(0).max(1e15).optional(),
    priceMax: z.coerce.number().min(0).max(1e15).optional(),
    currency: optionalString(3),
    keyword: optionalString(120),
    q: optionalString(120),
    // An unknown sort used to fall through to "featured" in `normalizeSearchInput`,
    // so `?sort=price-high` looked like it worked and quietly returned the featured
    // order. Rejecting it here means a wrong value is a 422, not a silent lie.
    sort: z
      .enum(["featured", "newest", "oldest", "priceAsc", "priceDesc", "price-asc", "price-desc", "relevance", "popular"])
      .optional()
      .or(z.literal("").transform(() => undefined)),
    featured: optionalString(6),
    verified: optionalString(6),
    exclusive: optionalString(6),
    make: optionalString(120),
    brand: optionalString(120),
    manufacturer: optionalString(120),
    model: optionalString(120),
    collection: optionalString(120),
    organizationId: z.coerce.number().int().positive().optional(),
    agentId: z.coerce.number().int().positive().optional(),
    // A project is addressed publicly by its ULID or its slug. The numeric
    // `projectId` is an internal key and is deliberately not accepted here:
    // "show me the properties in this development" must not require a caller
    // to know, or be able to probe, a database id.
    project: optionalString(220),
    bedrooms: z.union([z.string(), z.array(z.string())]).optional(),
    beds: z.union([z.string(), z.array(z.string())]).optional(),
    bathrooms: z.union([z.string(), z.array(z.string())]).optional(),
    baths: z.union([z.string(), z.array(z.string())]).optional(),
    page: z.coerce.number().int().min(1).max(2000).optional(),
    pageSize: z.coerce.number().int().min(1).max(100).optional(),
    cursor: z.coerce.number().int().min(0).max(100000).optional(),
  })
  /**
   * The category-specific range and facet keys are many and change with the filter registry,
   * so they are validated by type here rather than enumerated twice.
   *
   * String-only, deliberately. This accepted arrays, and `normalizeSearchInput` reads these
   * keys with `cleanString`, which returns null for anything that is not a string — so a
   * repeated facet silently *dropped its own filter* instead of being rejected:
   * `?furnishing=furnished&furnishing=unfurnished` answered with the entire catalogue, and so
   * did `completionStatus` and `ownershipType`. Every key the schema names above already
   * rejects a repeat with a 422; these now do the same.
   *
   * The four keys that are genuinely repeatable — `location`, `bedrooms`/`beds`,
   * `bathrooms`/`baths` — are declared explicitly above and are unaffected by this.
   */
  .catchall(optionalString(120));

export const slugParam = z.object({ slug: z.string().trim().min(1).max(280) });
export const referenceParam = z.object({ reference: z.string().trim().min(1).max(64) });

export const locationsQuery = z.object({
  q: optionalString(120),
  type: z.union([z.string(), z.array(z.string())]).optional(),
  entityType: z.union([z.string(), z.array(z.string())]).optional(),
  parentId: z.coerce.number().int().positive().optional(),
  country: optionalString(120),
  countryId: z.coerce.number().int().positive().optional(),
  // Clamped rather than rejected: an over-large limit is a client mistake, not
  // a reason to fail the request, and the cap is what protects the server.
  limit: z.coerce.number().int().min(1).optional().transform((value) => (value === undefined ? undefined : Math.min(50, value))),
  id: optionalString(80),
  slug: optionalString(180),
  pathname: optionalString(500),
  withListings: optionalString(6),
});

export const paginationQuery = z.object({
  page: z.coerce.number().int().min(1).max(2000).default(1),
  pageSize: z.coerce.number().int().min(1).max(100).default(20),
  q: optionalString(120),
  sort: optionalString(30),
});
