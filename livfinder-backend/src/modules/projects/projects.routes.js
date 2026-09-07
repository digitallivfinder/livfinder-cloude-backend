import { Router } from "express";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { listResponse, detailResponse, paginationFrom, toBool } from "../../utils/http.js";
import * as projectsRepo from "./projects.repository.js";
import * as searchRepo from "../search/search.repository.js";
import * as locationsRepo from "../locations/locations.repository.js";
import { projectSearchQuery, projectFacetQuery, developerQuery } from "./projects.schemas.js";
import { serializeProjectCard, serializeProjectDetail, serializeDeveloper } from "../../serializers/project.js";
import { FACET_COLUMNS } from "./projects.filters.js";

/**
 * The public Projects marketplace API.
 *
 * Mounted under `/v1/public` ahead of the general public router so `/projects`
 * and `/developers` are owned here rather than being swallowed by that router's
 * `/:category/search-options` catch-all.
 *
 * Publication is enforced by `project_search` — the repository reads nothing
 * else — so no handler in this file has to remember a visibility clause, and
 * none of them can forget one.
 */
const router = Router();

/* --------------------------------------------------------------------------
 * Search
 * ------------------------------------------------------------------------ */

router.get(
  "/projects",
  validate({ query: projectSearchQuery }),
  asyncHandler(async (req, res) => {
    const filters = q(req);
    const { page, pageSize, offset } = paginationFrom(filters, 24);
    const { rows, total, sort } = await projectsRepo.searchProjects(filters, { limit: pageSize, offset });
    return res.json({
      ...listResponse(rows.map(serializeProjectCard), { page, pageSize, total }),
      pageInfo: {
        ...listResponse(rows, { page, pageSize, total }).pageInfo,
        sort,
      },
    });
  })
);

/**
 * Facet counts under the caller's own filters.
 *
 * Every Projects option list is served from here so a control cannot offer a
 * developer, unit type, handover year or availability the catalogue does not
 * hold — and cannot print a count the result page then contradicts.
 */
router.get(
  "/projects/facets",
  validate({ query: projectFacetQuery }),
  asyncHandler(async (req, res) => {
    const filters = q(req);
    const facet = String(filters.facet || "projectType");
    if (!FACET_COLUMNS[facet]) throw AppError.badRequest(`Unsupported facet: ${facet}.`);
    const data = await projectsRepo.projectFacets(filters, facet);
    return res.json({ data, facet, total: data.reduce((sum, row) => sum + row.count, 0) });
  })
);

/**
 * Countries holding publicly visible projects.
 *
 * The count is projects, not listings: the countries directory browsed under
 * Projects must not advertise a property total beside a link to a project page.
 */
router.get(
  "/projects/countries",
  validate({ query: projectSearchQuery }),
  asyncHandler(async (req, res) => {
    const rows = await projectsRepo.projectCountryFacets(q(req), { limit: req.query.limit ?? 60 });
    const data = rows.map((row) => ({
      slug: row.slug,
      name: row.name,
      id: `country:${row.location_id}`,
      projectCount: Number(row.count) || 0,
      // Kept for the shared country-card contract, which reads `listingCount`.
      listingCount: Number(row.count) || 0,
      image: row.image || null,
    }));
    return res.json({ data, total: data.reduce((sum, row) => sum + row.projectCount, 0) });
  })
);

/**
 * Resolve a URL to a project.
 *
 * Answers three questions in one round trip, because the route dispatcher needs
 * all three before it can render anything: is this path a project, is it that
 * project's canonical path, and if not, where should it permanently redirect?
 */
router.get(
  "/projects/by-path",
  asyncHandler(async (req, res) => {
    const pathname = String(req.query.path || "").trim();
    if (!pathname.startsWith("/")) throw AppError.badRequest("A project path is required.");
    const row = await projectsRepo.getProjectRowByPath(pathname.slice(0, 500));
    if (row) return res.json(detailResponse(serializeProjectCard(row)));

    /**
     * Not canonical, but possibly still resolvable.
     *
     * A project keeps its slug when its community is re-parented or renamed, so
     * an indexed URL with the old location still identifies the project. The
     * last segment is the slug; if it names a published project, the caller is
     * told where that project now lives and issues a 301.
     */
    const slug = pathname.split("/").filter(Boolean).at(-1) || "";
    const canonical = slug ? await projectsRepo.resolveProjectCanonicalPath({ slug, publicId: slug }) : null;
    if (canonical && canonical !== pathname) {
      return res.json(detailResponse(null, { redirectTo: canonical }));
    }
    return res.json(detailResponse(null));
  })
);

/**
 * Validate a `/projects/{country}/{state}/{city}/{community}` prefix.
 *
 * The dispatcher needs this to tell an empty result set from a wrong URL: a
 * hierarchy that does not exist, or whose child does not sit under its stated
 * parent, is a 404, not a page saying "no projects match". Segments are checked
 * against the location tree by parent, so a city filed under another state
 * cannot resolve.
 */
router.get(
  "/projects/resolve-location",
  asyncHandler(async (req, res) => {
    const pathname = String(req.query.path || "").trim();
    const segments = pathname.split("/").filter(Boolean);
    // The caller may send the whole URL or just the location part.
    const locationSegments = segments[0] === "projects" ? segments.slice(1) : segments;
    if (!locationSegments.length) {
      return res.json({ status: "resolved", entities: [], labels: [], pathname: "/projects" });
    }
    if (locationSegments.length > 4) return res.json({ status: "not-found", entities: [], labels: [] });
    const resolution = await locationsRepo.resolveLocationPath(locationSegments);
    if (!resolution.valid) return res.json({ status: "not-found", entities: [], labels: [] });
    return res.json({
      status: "resolved",
      entities: resolution.entities,
      labels: resolution.labels,
      pathname: `/projects/${resolution.entities.map((entity) => entity.slug).join("/")}`,
    });
  })
);

/** One filter control's options, from the catalogue rather than a hardcoded list. */
router.get(
  "/projects/filter-options/:filterKey",
  validate({ query: projectSearchQuery }),
  asyncHandler(async (req, res) => {
    const options = await projectsRepo.projectFilterOptions(req.params.filterKey, {
      q: req.query.q ? String(req.query.q).slice(0, 120) : null,
      limit: Number(req.query.limit) || 60,
      filters: q(req),
    });
    return res.json({ options, data: options });
  })
);

/* --------------------------------------------------------------------------
 * Detail
 * ------------------------------------------------------------------------ */

async function detailFor(row, { includeGatedDocuments = false } = {}) {
  const children = await projectsRepo.getProjectChildren(row.project_id, { includeGatedDocuments });
  const [listings, related] = await Promise.all([
    // The project's own inventory, through the listing search so publication,
    // moderation and expiry are applied by the one place that owns those rules.
    searchRepo.searchListings({ category: "real-estate", projectId: row.project_id }, { limit: 12 }),
    projectsRepo.getRelatedProjects(row, { limit: 6 }),
  ]);
  return serializeProjectDetail({ row, ...children, listings: listings.rows, related });
}

/**
 * The detail behind a canonical path.
 *
 * Separate from `/projects/:identifier` so the route dispatcher can ask for a
 * page by the URL the visitor typed, without first turning it into an id and
 * losing the ability to tell "wrong path" from "no such project".
 */
router.get(
  "/projects/by-path/detail",
  asyncHandler(async (req, res) => {
    const pathname = String(req.query.path || "").trim();
    if (!pathname.startsWith("/")) throw AppError.badRequest("A project path is required.");
    const row = await projectsRepo.getProjectRowByPath(pathname.slice(0, 500));
    if (!row) return res.json(detailResponse(null));
    return res.json(detailResponse(await detailFor(row, { includeGatedDocuments: toBool(req.query.unlocked) })));
  })
);

router.get(
  "/projects/:identifier",
  asyncHandler(async (req, res) => {
    const row = await projectsRepo.getProjectRowByIdentifier(req.params.identifier);
    if (!row) throw AppError.notFound("That project is not available.");
    return res.json(detailResponse(await detailFor(row)));
  })
);

/* --------------------------------------------------------------------------
 * Developers
 * ------------------------------------------------------------------------ */

router.get(
  "/developers",
  validate({ query: developerQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { page, pageSize, offset } = paginationFrom(params, 60);
    const countryRow = params.country ? await locationsRepo.resolveLocation(params.country, { type: "country" }) : null;
    const { rows, total } = await projectsRepo.listPublicDevelopers({
      q: params.q || null,
      limit: pageSize,
      offset,
      countryId: countryRow?.id || null,
    });
    return res.json(listResponse(rows.map(serializeDeveloper), { page, pageSize, total }));
  })
);

router.get(
  "/developers/:slug",
  asyncHandler(async (req, res) => {
    const developer = await projectsRepo.getPublicDeveloper(req.params.slug);
    if (!developer) throw AppError.notFound("That developer page is not available.");
    const { rows, total } = await projectsRepo.searchProjects(
      { developerId: developer.id, sort: "featured" },
      { limit: 24 }
    );
    return res.json(
      detailResponse({
        developer: serializeDeveloper(developer),
        projects: rows.map(serializeProjectCard),
        projectCount: total,
      })
    );
  })
);

export default router;
