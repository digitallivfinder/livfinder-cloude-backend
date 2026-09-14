import { Router } from "express";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { listResponse, detailResponse, cursorResponse, paginationFrom, toBool, asArray } from "../../utils/http.js";
import { AppError } from "../../utils/errors.js";
import * as searchRepo from "../search/search.repository.js";
import * as listingsRepo from "../listings/listings.repository.js";
import * as orgRepo from "../organizations/organizations.repository.js";
import * as locationsRepo from "../locations/locations.repository.js";
import * as editorialRepo from "../editorial/editorial.repository.js";
import * as optionsRepo from "./options.repository.js";
import * as sitemapRepo from "./sitemap.repository.js";
import { listingSearchQuery, slugParam, locationsQuery, paginationQuery } from "./public.schemas.js";
import { resolveCategory } from "../../utils/categories.js";
import { query } from "../../db/query.js";

const router = Router();

/* --------------------------------------------------------------------------
 * Listings
 * ------------------------------------------------------------------------ */

router.get(
  "/listings",
  validate({ query: listingSearchQuery }),
  asyncHandler(async (req, res) => {
    const filters = q(req);
    const pageSize = Math.min(100, Number(filters.pageSize) || 9);
    // Two paginations coexist on purpose: the marketplace grid pages by cursor,
    // the index pages by page number.
    const useCursor = filters.cursor !== undefined;
    const offset = useCursor ? Number(filters.cursor) : (Math.max(1, Number(filters.page) || 1) - 1) * pageSize;

    const { rows, total } = await searchRepo.searchListings(filters, { limit: pageSize, offset });

    if (useCursor) {
      return res.json(cursorResponse(rows, { cursor: offset, pageSize, total, sort: filters.sort || "featured" }));
    }
    return res.json({
      ...listResponse(rows, { page: Math.floor(offset / pageSize) + 1, pageSize, total }),
      pageInfo: {
        ...listResponse(rows, { page: Math.floor(offset / pageSize) + 1, pageSize, total }).pageInfo,
        estimatedTotal: total,
        nextCursor: offset + rows.length < total ? String(offset + rows.length) : null,
        sort: filters.sort || "featured",
      },
    });
  })
);

/**
 * Facet counts for the category strips.
 *
 * `searchRepo.facetCounts` has always been able to answer this, but nothing called it,
 * so the public pages printed hardcoded totals instead ("84,737 Apartments", "1,842
 * Supercars") that were unrelated to the catalogue. The counts respect the same filters
 * as the list itself, so a strip shown next to a filtered result set agrees with it.
 */
router.get(
  "/listings/facets",
  validate({ query: listingSearchQuery }),
  asyncHandler(async (req, res) => {
    const filters = q(req);
    const facet = String(req.query.facet || "category_slug");
    let rows;
    try {
      rows = await searchRepo.facetCounts(filters, facet);
    } catch (error) {
      if (error instanceof TypeError) throw AppError.badRequest(`Unsupported facet: ${facet}.`);
      throw error;
    }
    const data = rows.map((row) => ({ value: row.value, count: Number(row.count) }));
    return res.json({ data, facet, total: data.reduce((sum, row) => sum + row.count, 0) });
  })
);

/**
 * Countries holding listings, for the homepage explore strip.
 *
 * Takes the same filter set as the list itself, so `?category=yachts` counts yachts and nothing
 * else. The strip used to render `locations.listing_count`, a total across every category, beside
 * a link to a generic country page — so Spain advertised 14 listings under Yachts when the yacht
 * catalogue held none there, and the tile led away from the category being browsed.
 */
router.get(
  "/listings/countries",
  validate({ query: listingSearchQuery }),
  asyncHandler(async (req, res) => {
    const rows = await searchRepo.countryFacets(q(req), { limit: req.query.limit ?? 12 });
    const data = rows.map((row) => ({
      // The entity id the filter engine addresses a location by. The header row is a location
      // filter like any other, so selecting a country has to be expressible as `country:1231`
      // and not only as a slug — a slug alone cannot say which tier it names.
      id: `country:${row.id}`,
      slug: row.slug,
      name: row.name,
      listingCount: Number(row.count) || 0,
      // Null when the winning listing has no cover photograph; the tile falls back to its
      // lettered mark rather than rendering an empty frame.
      image: row.image || null,
    }));

    /**
     * `countryCode` is the visitor's ISO alpha-2 from the edge, resolved here because this is
     * where the country data lives. Answered alongside the list so the header can render its
     * countries and know which one to preselect in a single call.
     *
     * Only ever a suggestion: an unrecognised code, or a country holding nothing in this
     * category, resolves to null and the caller falls back to the busiest country rather than
     * preselecting somewhere with no inventory.
     */
    let resolvedCountry = null;
    if (req.query.countryCode) {
      const row = await locationsRepo.resolveCountryByCode(req.query.countryCode);
      if (row) {
        /**
         * Checked against the catalogue, not against `data` — `data` is capped at the caller's
         * limit, so testing membership there would reject a visitor's own country purely for
         * ranking eleventh. It is counted on its own and, when it holds stock but fell below the
         * cut, appended so the header can show the country it has preselected.
         */
        const [own] = await searchRepo.countryFacets({ ...q(req), country: row.slug }, { limit: 1 });
        if (own) {
          resolvedCountry = row.slug;
          if (!data.some((entry) => entry.slug === row.slug)) {
            data.push({
              id: `country:${own.id}`,
              slug: own.slug,
              name: own.name,
              listingCount: Number(own.count) || 0,
              image: own.image || null,
            });
          }
        }
      }
    }

    return res.json({
      data,
      resolvedCountry,
      total: data.reduce((sum, row) => sum + row.listingCount, 0),
    });
  })
);

router.get(
  "/listings/by-path",
  asyncHandler(async (req, res) => {
    const pathname = String(req.query.path || "").trim();
    if (!pathname.startsWith("/")) throw AppError.badRequest("A listing path is required.");
    const result = await listingsRepo.getListingByPath(pathname.slice(0, 500));
    return res.json(detailResponse(result?.detail || null));
  })
);

router.get(
  "/listings/:reference",
  asyncHandler(async (req, res) => {
    const reference = String(req.params.reference).slice(0, 64);
    const result = await listingsRepo.getListingDetail({ reference, publicId: reference });
    if (!result) throw AppError.notFound("That listing is not available.");
    return res.json(detailResponse(result.detail));
  })
);

/* --------------------------------------------------------------------------
 * Home
 * ------------------------------------------------------------------------ */

router.get(
  "/home",
  asyncHandler(async (req, res) => {
    const [featured, companies, countries, blogs, categoryCounts] = await Promise.all([
      searchRepo.searchListings({ featured: true, sort: "featured" }, { limit: 12 }),
      orgRepo.listPublicOrganizations({ limit: 8, sort: "featured" }),
      locationsRepo.listCountries({ onlyWithListings: true, limit: 12 }),
      editorialRepo.listArticles({ limit: 3 }),
      optionsRepo.categoryCounts(),
    ]);

    return res.json(
      detailResponse({
        featuredListings: featured.rows,
        featuredCompanies: companies.rows,
        countries: countries.map(locationsRepo.toEntity).map((entity) => ({
          country: entity.slug,
          slug: entity.slug,
          name: entity.label,
          listingCount: entity.listingCount,
          intro: null,
          states: [],
        })),
        blogs: blogs.rows,
        categories: categoryCounts,
        totals: {
          listings: categoryCounts.reduce((sum, entry) => sum + entry.count, 0),
          companies: companies.total,
        },
      })
    );
  })
);

/* --------------------------------------------------------------------------
 * Companies and agents
 * ------------------------------------------------------------------------ */

router.get(
  "/companies",
  validate({ query: paginationQuery.extend(locationsQuery.shape).partial() }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { page, pageSize, offset } = paginationFrom(params, 24);
    const countryRow = params.country ? await locationsRepo.resolveLocation(params.country, { type: "country" }) : null;
    const definition = params.category ? resolveCategory(params.category) : null;
    const { rows, total } = await orgRepo.listPublicOrganizations({
      limit: pageSize,
      offset,
      q: params.q || null,
      countryId: countryRow?.id || null,
      rootCategoryId: definition?.rootId || null,
      sort: params.sort || "featured",
    });
    return res.json(listResponse(rows, { page, pageSize, total }));
  })
);

router.get(
  "/companies/:slug",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const result = await orgRepo.getPublicOrganization(req.params.slug);
    if (!result) throw AppError.notFound("That company page is not available.");
    return res.json(detailResponse(result.company));
  })
);

router.get(
  "/companies/:slug/profile",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const result = await orgRepo.getPublicOrganization(req.params.slug);
    if (!result) throw AppError.notFound("That company page is not available.");
    const [listings, agents] = await Promise.all([
      searchRepo.searchListings({ organizationId: result.raw.id }, { limit: 24 }),
      orgRepo.listPublicAgents({ organizationId: result.raw.id, limit: 50 }),
    ]);
    return res.json(
      detailResponse({
        agency: { ...result.company, activeListingCount: listings.total, publicAgentCount: agents.total },
        listings: listings.rows,
        agents: agents.rows,
      })
    );
  })
);

router.get(
  "/agents",
  validate({ query: paginationQuery.partial() }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { page, pageSize, offset } = paginationFrom(params, 24);
    const { rows, total } = await orgRepo.listPublicAgents({
      limit: pageSize,
      offset,
      q: params.q || null,
      sort: params.sort || "featured",
    });
    return res.json(listResponse(rows, { page, pageSize, total }));
  })
);

router.get(
  "/agents/:slug",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const result = await orgRepo.getPublicAgent(req.params.slug);
    if (!result) throw AppError.notFound("That profile is not available.");
    const [listings, organization] = await Promise.all([
      searchRepo.searchListings({ agentId: result.raw.id }, { limit: 24 }),
      result.raw.organization_id ? orgRepo.getPublicOrganization(String(result.raw.organization_id)) : null,
    ]);
    return res.json(
      detailResponse({
        agent: { ...result.agent, activeListingCount: listings.total },
        agency: organization?.company || null,
        listings: listings.rows,
      })
    );
  })
);

/** The combined agency + agent directory the professionals page renders. */
router.get(
  "/directory",
  asyncHandler(async (req, res) => {
    const [companies, agents] = await Promise.all([
      orgRepo.listPublicOrganizations({ limit: 60, sort: "listings" }),
      orgRepo.listPublicAgents({ limit: 60, sort: "listings" }),
    ]);
    const byOrganization = new Map(companies.rows.map((company) => [company.organizationId, company]));
    return res.json(
      detailResponse({
        agencies: companies.rows.map((agency) => ({
          ...agency,
          activeListingCount: agency.activeListingCount,
          publicAgentCount: agency.agentCount,
        })),
        agents: agents.rows.map((agent) => ({
          ...agent,
          agency: byOrganization.get(agent.organizationId) || null,
        })),
      })
    );
  })
);

/** The agency card shown on a listing detail page, resolved from the URL. */
router.get(
  "/listing-agency",
  asyncHandler(async (req, res) => {
    const pathname = String(req.query.path || "").trim();
    if (!pathname.startsWith("/")) throw AppError.badRequest("A listing path is required.");
    const result = await listingsRepo.getListingByPath(pathname.slice(0, 500));
    if (!result?.raw?.organization_id) return res.json(detailResponse(null));
    const organization = await orgRepo.getPublicOrganization(String(result.raw.organization_id));
    if (!organization) return res.json(detailResponse(null));
    const [listingCount, agent] = await Promise.all([
      searchRepo.countListings({ organizationId: result.raw.organization_id }),
      result.raw.agent_id ? orgRepo.getPublicAgent(String(result.raw.agent_id)) : null,
    ]);
    const agentListingCount = result.raw.agent_id
      ? await searchRepo.countListings({ agentId: result.raw.agent_id })
      : 0;
    return res.json(
      detailResponse({
        ...organization.company,
        activeListingCount: listingCount,
        agent: agent ? { ...agent.agent, activeListingCount: agentListingCount } : null,
      })
    );
  })
);


/* --------------------------------------------------------------------------
 * Features
 * ------------------------------------------------------------------------ */

/**
 * The features a category's listings may carry — the list the portal form offers, so a
 * lister picks from the catalogue rather than typing tags nothing can filter by.
 */
router.get(
  "/features",
  asyncHandler(async (req, res) => {
    const definition = resolveCategory(String(req.query.category || ""));
    if (!definition) throw AppError.validation("Some information is invalid.", { category: "Unknown category." });
    const rows = await query(
      `SELECT f.id, f.slug, f.name, fg.name AS group_name
         FROM category_features cf
         JOIN features f ON f.id = cf.feature_id
         LEFT JOIN feature_groups fg ON fg.id = f.feature_group_id
        WHERE cf.category_id = ?
        ORDER BY fg.sort_order ASC, cf.sort_order ASC, f.name ASC`,
      [definition.rootId]
    );
    return res.json(
      detailResponse(rows.map((row) => ({ id: Number(row.id), slug: row.slug, name: row.name, group: row.group_name || null })))
    );
  })
);

/* --------------------------------------------------------------------------
 * Locations and countries
 * ------------------------------------------------------------------------ */

router.get(
  "/countries",
  asyncHandler(async (req, res) => {
    const rows = await locationsRepo.listCountries({ onlyWithListings: toBool(req.query.all) ? false : true });
    const countries = await Promise.all(
      rows.map(async (row) => {
        const entity = locationsRepo.toEntity(row);
        return {
          country: entity.slug,
          slug: entity.slug,
          name: entity.label,
          id: entity.id,
          listingCount: entity.listingCount,
          intro: null,
          states: [],
        };
      })
    );
    return res.json(detailResponse(countries));
  })
);

router.get(
  "/countries/:slug",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const row = await locationsRepo.resolveLocation(req.params.slug, { type: "country" });
    if (!row) throw AppError.notFound("That country page is not available.");
    const entity = locationsRepo.toEntity(row);
    const states = await locationsRepo.listChildren(row.id, { limit: 60 });
    const stateEntities = await Promise.all(
      states
        .filter((state) => state.active_listing_count > 0)
        .map(async (state) => {
          const cities = await locationsRepo.listChildren(state.id, { limit: 30 });
          return {
            slug: state.slug,
            name: state.name,
            id: `state:${state.id}`,
            listingCount: Number(state.active_listing_count || 0),
            cities: cities.filter((city) => city.active_listing_count > 0).map((city) => city.slug),
          };
        })
    );
    return res.json(
      detailResponse({
        country: entity.slug,
        slug: entity.slug,
        name: entity.label,
        id: entity.id,
        listingCount: entity.listingCount,
        latitude: entity.latitude,
        longitude: entity.longitude,
        intro: null,
        states: stateEntities,
      })
    );
  })
);

/**
 * Location typeahead. 161k rows are never shipped to a browser: the caller
 * always supplies a query, a parent, or accepts the ranked default page.
 */
router.get(
  "/locations",
  validate({ query: locationsQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const types = [...asArray(params.type), ...asArray(params.entityType)];

    if (params.id) {
      const row = await locationsRepo.resolveLocation(params.id);
      return res.json(row ? { status: "resolved", entity: locationsRepo.toEntity(row) } : { status: "not-found", matches: [] });
    }
    if (params.slug) {
      const row = await locationsRepo.resolveLocation(params.slug, { type: types[0] });
      return res.json(row ? { status: "resolved", entity: locationsRepo.toEntity(row) } : { status: "not-found", matches: [] });
    }
    if (params.pathname) {
      const segments = String(params.pathname).split("/").filter(Boolean).slice(1);
      const resolution = await locationsRepo.resolveLocationPath(segments);
      if (!resolution.valid) return res.json({ status: "not-found", matches: [] });
      return res.json({
        status: "resolved",
        entities: resolution.entities,
        pathname: `/real-estate/${resolution.entities.map((entity) => entity.slug).join("/")}`,
      });
    }

    const countryRow = params.country ? await locationsRepo.resolveLocation(params.country, { type: "country" }) : null;
    let options = await locationsRepo.searchLocations({
      q: params.q || null,
      types,
      parentId: params.parentId || null,
      countryId: countryRow?.id || params.countryId || null,
      limit: params.limit || 20,
      onlyWithListings: params.withListings === undefined ? Boolean(params.q) === false : toBool(params.withListings),
    });
    // A prefix match is the right first answer; fall back to contains so
    // "Jumeirah" still finds "Palm Jumeirah".
    if (params.q && options.length < 5) {
      const extra = await locationsRepo.searchLocationsContains({ q: params.q, types, limit: params.limit || 20 });
      const seen = new Set(options.map((option) => option.id));
      options = [...options, ...extra.filter((option) => !seen.has(option.id))].slice(0, params.limit || 20);
    }
    return res.json({ options, data: options, hasMore: false });
  })
);

router.get(
  "/locations/:id/children",
  asyncHandler(async (req, res) => {
    const parent = await locationsRepo.resolveLocation(req.params.id);
    if (!parent) throw AppError.notFound("That location could not be found.");
    const limit = Math.min(500, Math.max(1, Number(req.query.limit) || 100));
    const q = String(req.query.q ?? "").trim().slice(0, 120) || null;
    const rows = await locationsRepo.listChildren(parent.id, { limit, q });
    // `hasMore` tells a picker the page is not the whole list, so it searches the
    // server instead of filtering what it already holds.
    return res.json({ options: rows.map(locationsRepo.toEntity), hasMore: rows.length === limit });
  })
);

/* --------------------------------------------------------------------------
 * Filter options
 * ------------------------------------------------------------------------ */

router.get(
  "/filter-options/:category/:filterKey",
  asyncHandler(async (req, res) => {
    const options = await optionsRepo.filterOptions(req.params.category, req.params.filterKey, {
      q: req.query.q || null,
      parent: req.query.parent || null,
      limit: Number(req.query.limit) || 30,
      // The header's selected country. Orders the location list; never restricts it.
      preferCountry: req.query.preferCountry || null,
      // Search menus offer only makes/models/types the marketplace has inventory for;
      // the add-listing form needs the whole catalogue, so it asks for `all`.
      all: req.query.all === "true" || req.query.all === "1",
    });
    return res.json({ options, data: options });
  })
);

router.get(
  "/:category/search-options",
  asyncHandler(async (req, res) => {
    const options = await optionsRepo.searchOptions(req.params.category, {
      q: req.query.q || null,
      limit: Number(req.query.limit) || 30,
    });
    return res.json({ options, data: options });
  })
);

router.get(
  "/:category/popular-searches",
  asyncHandler(async (req, res) => {
    const options = await optionsRepo.popularSearches(req.params.category, { limit: Number(req.query.limit) || 12 });
    return res.json({ options, data: options });
  })
);

router.get(
  "/hierarchy/:category",
  asyncHandler(async (req, res) => {
    const resolution = await optionsRepo.resolveAssetHierarchy(req.params.category, asArray(req.query.segments));
    return res.json(detailResponse(resolution));
  })
);

/* --------------------------------------------------------------------------
 * Editorial
 * ------------------------------------------------------------------------ */

router.get(
  "/editorial",
  asyncHandler(async (req, res) => res.json(detailResponse(await editorialRepo.editorialHome())))
);

router.get(
  "/blogs",
  asyncHandler(async (req, res) => {
    const page = Math.max(1, Number(req.query.page) || 1);
    const pageSize = Math.min(50, Number(req.query.pageSize) || 8);
    const { rows, total } = await editorialRepo.listArticles({
      limit: pageSize,
      offset: (page - 1) * pageSize,
      taxonomy: req.query.type && req.query.type !== "author" ? String(req.query.type) : null,
      termSlug: req.query.slug ? String(req.query.slug) : null,
      authorSlug: req.query.type === "author" ? String(req.query.slug || "") : null,
      q: req.query.query ? String(req.query.query) : null,
    });
    return res.json(listResponse(rows, { page, pageSize, total }));
  })
);

router.get(
  "/blogs/:slug",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const article = await editorialRepo.getArticle(req.params.slug);
    if (!article) throw AppError.notFound("That article is not available.");
    return res.json(detailResponse(article));
  })
);

router.get(
  "/blogs/:slug/related",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const article = await editorialRepo.getArticle(req.params.slug);
    if (!article) throw AppError.notFound("That article is not available.");
    const related = await editorialRepo.relatedArticles(article.postId, Number(req.query.limit) || 3);
    return res.json({ data: related });
  })
);

router.get(
  "/articles/recent",
  asyncHandler(async (req, res) => {
    const rows = await editorialRepo.recentArticles({
      excludeId: req.query.excludeId ? String(req.query.excludeId) : null,
      limit: Number(req.query.limit) || 4,
    });
    return res.json({ data: rows });
  })
);

router.get(
  "/editorial/terms/:taxonomy",
  asyncHandler(async (req, res) => {
    const taxonomy = String(req.params.taxonomy);
    if (!["category", "tag", "topic", "destination", "series"].includes(taxonomy)) {
      throw AppError.badRequest("Unknown taxonomy.");
    }
    return res.json({ data: await editorialRepo.listTerms(taxonomy) });
  })
);

router.get(
  "/editorial/terms/:taxonomy/:slug",
  asyncHandler(async (req, res) => {
    const term = await editorialRepo.getTerm(String(req.params.taxonomy), String(req.params.slug));
    if (!term) throw AppError.notFound("That page is not available.");
    return res.json(detailResponse(term));
  })
);

router.get(
  "/authors/:slug",
  validate({ params: slugParam }),
  asyncHandler(async (req, res) => {
    const author = await editorialRepo.getAuthor(req.params.slug);
    if (!author) throw AppError.notFound("That profile is not available.");
    return res.json(detailResponse(author));
  })
);

/* --------------------------------------------------------------------------
 * SEO
 * ------------------------------------------------------------------------ */

router.get(
  "/sitemap",
  asyncHandler(async (req, res) => {
    const entries = await sitemapRepo.sitemapEntries(String(req.query.kind || "all"));
    return res.json({ data: entries });
  })
);

router.get(
  "/redirects",
  asyncHandler(async (req, res) => {
    const path = String(req.query.path || "");
    if (!path.startsWith("/")) throw AppError.badRequest("A path is required.");
    const rows = await query(
      `SELECT to_path, status_code FROM redirects
        WHERE from_path = ? AND is_active = 1 AND is_loop = 0 LIMIT 1`,
      [path.slice(0, 500)]
    );
    return res.json(detailResponse(rows[0] ? { to: rows[0].to_path, status: Number(rows[0].status_code) } : null));
  })
);

export default router;
