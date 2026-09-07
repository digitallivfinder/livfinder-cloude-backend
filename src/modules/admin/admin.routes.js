import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth, requireAdmin, requirePermission, requireCategoryScope, requireStepUp } from "../../middleware/auth.js";
import { assertRootCategoryScope, scopedRootCategoryIds, scopeListingParam, scopeDevelopmentParam } from "./admin.shared.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { AppError } from "../../utils/errors.js";
import { auditFromRequest } from "../system/audit.service.js";
import * as dashboard from "./admin.dashboard.js";
import * as catalog from "./admin.catalog.js";
import * as crm from "./admin.crm.js";
import * as content from "./admin.content.js";
import * as settings from "./admin.settings.js";
import * as mutations from "./admin.mutations.js";
import { adminPermissionUniverse } from "../auth/adminPermissions.js";
import { toAdminPermissions } from "../auth/adminPermissions.js";
import { allPermissionCodes } from "../auth/rbac.js";

const router = Router();

// Admin is gated twice: a platform role to enter at all, and a specific
// permission on every route. Hidden nav is a convenience, never the control.
router.use(requireAuth, requireAdmin);

const listQuery = z
  .object({
    page: z.coerce.number().int().min(1).max(5000).optional(),
    pageSize: z.coerce.number().int().min(1).max(200).optional(),
    status: z.string().trim().max(40).optional(),
    category: z.string().trim().max(40).optional(),
    search: z.string().trim().max(200).optional(),
    sort: z.string().trim().max(40).optional(),
    owner: z.string().trim().max(200).optional(),
    location: z.string().trim().max(200).optional(),
    country: z.string().trim().max(120).optional(),
    developer: z.string().trim().max(120).optional(),
    // Developments. These were sent by the screen and stripped here, so six of
    // its eight selects reached the repository as nothing at all.
    developmentStatus: z.string().trim().max(40).optional(),
    projectType: z.string().trim().max(40).optional(),
    propertyType: z.string().trim().max(40).optional(),
    handoverYear: z.string().trim().max(4).optional(),
    priceMin: z.string().trim().max(20).optional(),
    priceMax: z.string().trim().max(20).optional(),
    q: z.string().trim().max(200).optional(),
    author: z.string().trim().max(120).optional(),
    type: z.string().trim().max(40).optional(),
    folder: z.string().trim().max(500).optional(),
    usage: z.string().trim().max(40).optional(),
    targetType: z.string().trim().max(40).optional(),
    rating: z.string().trim().max(4).optional(),
    priority: z.string().trim().max(20).optional(),
    entityType: z.string().trim().max(40).optional(),
    reason: z.string().trim().max(60).optional(),
    severity: z.string().trim().max(20).optional(),
    source: z.string().trim().max(80).optional(),
    inquiryType: z.string().trim().max(40).optional(),
    agent: z.string().trim().max(64).optional(),
    property: z.string().trim().max(64).optional(),
    community: z.string().trim().max(120).optional(),
    organizationId: z.string().trim().max(64).optional(),
    roleId: z.string().trim().max(20).optional(),
    parentId: z.string().trim().max(64).optional(),
    parent: z.string().trim().max(64).optional(),
    from: z.string().trim().max(30).optional(),
    to: z.string().trim().max(30).optional(),
  })
  .partial();

const params = (req) => q(req) || {};

/* -------------------------------------------------------------------------- */
/* Dashboard                                                                   */
/* -------------------------------------------------------------------------- */

router.get(
  "/dashboard",
  requirePermission("analytics.view", "listings.view", "users.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await dashboard.adminDashboard())))
);

router.get(
  "/categories/:category/dashboard",
  requirePermission("listings.view"),
  requireCategoryScope("params", "category"),
  validate({ query: z.object({ period: z.enum(["7d", "30d", "90d"]).optional() }) }),
  asyncHandler(async (req, res) => {
    // Developments live in `projects`, not `listings`, so they have their own reader.
    const result =
      req.params.category === "real-estate-developments"
        ? await dashboard.developmentsDashboard({ period: req.query.period })
        : await dashboard.categoryDashboard(req.params.category, { period: req.query.period });
    if (!result) throw AppError.notFound("Unknown category.");
    return res.json(detailResponse(result));
  })
);

/* -------------------------------------------------------------------------- */
/* Listings                                                                    */
/* -------------------------------------------------------------------------- */

router.get(
  "/listings",
  requirePermission("listings.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) =>
    res.json(await catalog.listAdminListings({ ...params(req), scopedRootIds: scopedRootCategoryIds(req) }))
  )
);

router.get(
  "/listings/:id",
  requirePermission("listings.view"),
  asyncHandler(async (req, res) => {
    const { getListingDetail } = await import("../listings/listings.repository.js");
    const result = await getListingDetail({ publicId: req.params.id, reference: req.params.id }, { source: "any", includePrivate: true });
    if (!result) throw AppError.notFound("That listing was not found.");
    assertRootCategoryScope(req, result.raw.root_category_id);
    const [summary] = (await catalog.listAdminListings({ search: result.raw.reference, pageSize: 1 })).items;
    return res.json(detailResponse({ ...result.detail, admin: summary ?? null, status: result.raw.status, moderationStatus: result.raw.moderation_status }));
  })
);

router.patch(
  "/listings/:id/moderation",
  writeLimiter,
  requirePermission("listings.moderate"),
  scopeListingParam(),
  validate({ body: mutations.moderateListingSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.moderateListing({ identifier: req.params.id, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, {
      action: `listing.${req.body.decision}`,
      subjectType: "listing",
      subjectLabel: req.params.id,
      changes: req.body,
    });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/listings/:id",
  writeLimiter,
  requirePermission("listings.edit"),
  asyncHandler(async (req, res) => {
    const { updateListingSchema } = await import("../listings/listings.schemas.js");
    const payload = updateListingSchema.parse(req.body);
    const { getListingOwnership } = await import("../listings/listings.repository.js");
    const { updateListing } = await import("../listings/listings.service.js");
    const listing = await getListingOwnership({ publicId: req.params.id, reference: req.params.id });
    if (!listing) throw AppError.notFound("That listing was not found.");
    assertRootCategoryScope(req, listing.root_category_id);
    await updateListing({
      listing,
      payload,
      userId: req.auth.user.id,
      accountId: listing.account_id,
      organizationId: listing.organization_id,
    });
    await auditFromRequest(req, { action: "listing.updated", subjectType: "listing", subjectId: listing.id, changes: payload });
    return res.json(detailResponse({ id: listing.public_id, updated: true }));
  })
);

router.delete(
  "/listings/:id",
  writeLimiter,
  requirePermission("listings.delete"),
  scopeListingParam(),
  asyncHandler(async (req, res) => {
    const result = await mutations.deleteAdminListing({ identifier: req.params.id, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "listing.deleted", subjectType: "listing", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

/* -------------------------------------------------------------------------- */
/* Developments                                                                */
/* -------------------------------------------------------------------------- */

router.get(
  "/developments",
  requirePermission("developments.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await catalog.listAdminDevelopments(params(req))))
);

router.post(
  "/developments",
  writeLimiter,
  requirePermission("developments.create"),
  validate({ body: mutations.developmentSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertDevelopment({ identifier: null, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "development.created", subjectType: "project", subjectLabel: result.id, changes: req.body });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/developments/:id",
  writeLimiter,
  requirePermission("developments.edit"),
  scopeDevelopmentParam(),
  validate({ body: mutations.developmentSchema.partial().extend({ name: z.string().trim().min(1).max(200) }) }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertDevelopment({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "development.updated", subjectType: "project", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/developments/:id",
  writeLimiter,
  requirePermission("developments.delete"),
  scopeDevelopmentParam(),
  asyncHandler(async (req, res) => {
    const result = await mutations.archiveDevelopment({ identifier: req.params.id });
    await auditFromRequest(req, { action: "development.archived", subjectType: "project", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/developments/:id",
  requirePermission("developments.view"),
  asyncHandler(async (req, res) => {
    const result = await catalog.getAdminDevelopment(req.params.id);
    if (!result) throw AppError.notFound("That development was not found.");
    return res.json(detailResponse(result));
  })
);

router.get(
  "/developers",
  requirePermission("listings.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json({ data: await catalog.listDevelopers(params(req)) }))
);

router.get(
  "/developers/:id",
  requirePermission("listings.view"),
  asyncHandler(async (req, res) => {
    const developer = await catalog.getDeveloper(req.params.id);
    if (!developer) throw AppError.notFound("That developer was not found.");
    return res.json(detailResponse(developer));
  })
);

/* -------------------------------------------------------------------------- */
/* Companies, individuals, agents                                              */
/* -------------------------------------------------------------------------- */

router.get(
  "/companies",
  requirePermission("companies.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await catalog.listAdminCompanies(params(req))))
);

router.get(
  "/companies/:id",
  requirePermission("companies.view"),
  asyncHandler(async (req, res) => {
    const company = await catalog.getAdminCompany(req.params.id);
    if (!company) throw AppError.notFound("That company was not found.");
    return res.json(detailResponse(company));
  })
);

router.patch(
  "/companies/:id/verification",
  writeLimiter,
  requirePermission("companies.verify"),
  validate({ body: mutations.verificationDecisionSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.decideVerification({
      subjectType: "organization",
      identifier: req.params.id,
      ...req.body,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, {
      action: `organization.verification_${req.body.decision}`,
      subjectType: "organization",
      subjectLabel: req.params.id,
      changes: req.body,
    });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/companies/:id/status",
  writeLimiter,
  requirePermission("companies.suspend"),
  validate({ body: mutations.accountStateSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.setOrganizationState({ identifier: req.params.id, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "organization.status_changed", subjectType: "organization", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/companies/:id/category-access",
  writeLimiter,
  requirePermission("categoryAccess.decide"),
  validate({ body: mutations.categoryAccessSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.decideCategoryAccess({
      organizationPublicId: req.params.id,
      ...req.body,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, { action: "category_access.decided", subjectType: "organization", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/individuals",
  requirePermission("individuals.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await catalog.listAdminIndividuals(params(req))))
);

router.get(
  "/individuals/:id",
  requirePermission("individuals.view"),
  asyncHandler(async (req, res) => {
    const individual = await catalog.getAdminIndividual(req.params.id);
    if (!individual) throw AppError.notFound("That account was not found.");
    return res.json(detailResponse(individual));
  })
);

/**
 * Company, agent and package writes.
 *
 * The admin screens for all three were already built; none of them had an endpoint to submit
 * to, so every "Save" updated React state and was gone on reload.
 */
router.patch(
  "/companies/:id",
  writeLimiter,
  requirePermission("companies.edit"),
  validate({ body: mutations.organizationProfileSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.updateOrganizationProfile({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "company.updated", subjectType: "organization", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/companies/:id/package",
  writeLimiter,
  requirePermission("companies.edit", "finance.plans"),
  validate({ body: mutations.packageChangeSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.changeAccountPackage({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "account.package_changed", subjectType: "account", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/individuals/:id",
  writeLimiter,
  requirePermission("individuals.edit"),
  validate({ body: mutations.organizationProfileSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.updateOrganizationProfile({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "individual.updated", subjectType: "organization", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/agents",
  writeLimiter,
  requirePermission("agents.create"),
  validate({ body: mutations.agentSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertAgent({ identifier: null, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "agent.created", subjectType: "agent", subjectLabel: result.id, changes: req.body });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/agents/:id",
  writeLimiter,
  requirePermission("agents.edit"),
  validate({ body: mutations.agentSchema.partial().extend({ firstName: z.string().trim().min(1).max(120), lastName: z.string().trim().min(1).max(120) }) }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertAgent({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "agent.updated", subjectType: "agent", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/individuals/:id/verification",
  writeLimiter,
  requirePermission("individuals.verify"),
  validate({ body: mutations.verificationDecisionSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.decideVerification({
      subjectType: "account",
      identifier: req.params.id,
      ...req.body,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, { action: `account.verification_${req.body.decision}`, subjectType: "account", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/agents",
  requirePermission("agents.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await catalog.listAdminAgents(params(req))))
);

router.get(
  "/agents/:id",
  requirePermission("agents.view"),
  asyncHandler(async (req, res) => {
    const agent = await catalog.getAdminAgent(req.params.id);
    if (!agent) throw AppError.notFound("That agent was not found.");
    return res.json(detailResponse(agent));
  })
);

router.patch(
  "/agents/:id/status",
  writeLimiter,
  requirePermission("agents.edit"),
  validate({ body: mutations.accountStateSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.setAgentState({ identifier: req.params.id, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "agent.status_changed", subjectType: "agent", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/owner-listings",
  requirePermission("listings.view"),
  validate({ query: listQuery.extend({ ownerType: z.string().max(20).optional(), ownerId: z.string().max(64).optional() }).partial() }),
  asyncHandler(async (req, res) => {
    const { ownerType, ownerId } = params(req);
    if (!ownerId) throw AppError.badRequest("An owner is required.");
    return res.json(await catalog.listOwnerListings({ ownerType: ownerType || "company", ownerId, ...params(req) }));
  })
);

router.get(
  "/business-activity",
  requirePermission("companies.view", "individuals.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) =>
    res.json({ data: await catalog.listBusinessActivity({ organizationId: params(req).organizationId, limit: params(req).pageSize }) })
  )
);

router.get(
  "/packages",
  requirePermission("finance.view"),
  asyncHandler(async (req, res) => res.json({ data: await catalog.listAdminPackages() }))
);

/* -------------------------------------------------------------------------- */
/* Locations and categories                                                    */
/* -------------------------------------------------------------------------- */

// The URL segment for each tier. Naive pluralisation gets "countrys" and
// "communitys" wrong, so the mapping is written out.
const TIERS = [
  { tier: "country", path: "countries" },
  { tier: "state", path: "states" },
  { tier: "city", path: "cities" },
  { tier: "community", path: "communities" },
  { tier: "subCommunity", path: "sub-communities" },
];

for (const { tier, path } of TIERS) {
  router.get(
    `/locations/${path}`,
    requirePermission("locations.view"),
    validate({ query: listQuery }),
    asyncHandler(async (req, res) => res.json(await catalog.listAdminLocations({ tier, ...params(req) })))
  );
}

router.get(
  "/locations/hierarchy-options",
  requirePermission("locations.view"),
  validate({ query: listQuery.extend({ countryId: z.string().max(64).optional(), stateId: z.string().max(64).optional(), cityId: z.string().max(64).optional(), communityId: z.string().max(64).optional() }).partial() }),
  asyncHandler(async (req, res) => res.json(detailResponse(await catalog.locationHierarchyOptions(params(req)))))
);

router.get(
  "/locations/:id",
  requirePermission("locations.view"),
  asyncHandler(async (req, res) => {
    const location = await catalog.getAdminLocation(req.params.id);
    if (!location) throw AppError.notFound("That location was not found.");
    return res.json(detailResponse(location));
  })
);

router.post(
  "/locations",
  writeLimiter,
  requirePermission("locations.create"),
  validate({ body: mutations.locationSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.createLocation({ payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "location.created", subjectType: "location", subjectLabel: req.body.name, changes: req.body });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/locations/:id",
  writeLimiter,
  requirePermission("locations.edit"),
  validate({ body: mutations.locationSchema.partial() }),
  asyncHandler(async (req, res) => {
    const result = await mutations.updateLocation({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "location.updated", subjectType: "location", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/locations/:id",
  writeLimiter,
  requirePermission("locations.delete"),
  asyncHandler(async (req, res) => {
    const result = await mutations.archiveLocation({ identifier: req.params.id });
    await auditFromRequest(req, { action: "location.archived", subjectType: "location", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/categories",
  requirePermission("taxonomy.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await catalog.listAdminCategories(params(req))))
);

router.get(
  "/categories/:id",
  requirePermission("taxonomy.view"),
  asyncHandler(async (req, res) => {
    const category = await catalog.getAdminCategory(req.params.id);
    if (!category) throw AppError.notFound("That category was not found.");
    return res.json(detailResponse(category));
  })
);

router.post(
  "/categories",
  writeLimiter,
  requirePermission("taxonomy.create"),
  validate({ body: mutations.categorySchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertCategory({ identifier: null, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "category.created", subjectType: "category", subjectLabel: req.body.name });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/categories/:id",
  writeLimiter,
  requirePermission("taxonomy.edit"),
  validate({ body: mutations.categorySchema.partial() }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertCategory({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "category.updated", subjectType: "category", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

/* -------------------------------------------------------------------------- */
/* CRM                                                                         */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/* Brands and models                                                           */
/* -------------------------------------------------------------------------- */

router.post(
  "/brands",
  writeLimiter,
  requirePermission("taxonomy.create"),
  validate({ body: mutations.brandSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertBrand({ identifier: null, payload: req.body });
    await auditFromRequest(req, { action: "brand.created", subjectType: "brand", subjectLabel: req.body.name, changes: req.body });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/brands/:id",
  writeLimiter,
  requirePermission("taxonomy.edit"),
  validate({ body: mutations.brandSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertBrand({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "brand.updated", subjectType: "brand", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/brands/:id",
  writeLimiter,
  requirePermission("taxonomy.delete"),
  asyncHandler(async (req, res) => {
    const result = await mutations.archiveBrand({ identifier: req.params.id });
    await auditFromRequest(req, { action: "brand.archived", subjectType: "brand", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/brand-models",
  writeLimiter,
  requirePermission("taxonomy.create"),
  validate({ body: mutations.brandModelSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertBrandModel({ identifier: null, payload: req.body });
    await auditFromRequest(req, { action: "brand_model.created", subjectType: "brand_model", subjectLabel: req.body.name, changes: req.body });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/brand-models/:id",
  writeLimiter,
  requirePermission("taxonomy.edit"),
  validate({ body: mutations.brandModelSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertBrandModel({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "brand_model.updated", subjectType: "brand_model", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/brand-models/:id",
  writeLimiter,
  requirePermission("taxonomy.delete"),
  asyncHandler(async (req, res) => {
    const result = await mutations.archiveBrandModel({ identifier: req.params.id });
    await auditFromRequest(req, { action: "brand_model.archived", subjectType: "brand_model", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/leads",
  requirePermission("leads.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await crm.listAdminLeads(params(req))))
);

router.get(
  "/leads/:id",
  requirePermission("leads.view"),
  asyncHandler(async (req, res) => {
    const lead = await crm.getAdminLead(req.params.id);
    if (!lead) throw AppError.notFound("That lead was not found.");
    return res.json(detailResponse(lead));
  })
);

router.patch(
  "/leads/:id",
  writeLimiter,
  requirePermission("leads.edit"),
  validate({ body: mutations.leadUpdateSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.updateAdminLead({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "lead.updated", subjectType: "lead", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/contacts",
  requirePermission("inquiries.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await crm.listAdminContacts(params(req))))
);

router.get(
  "/contacts/:id",
  requirePermission("inquiries.view"),
  asyncHandler(async (req, res) => {
    const contact = await crm.getAdminContact(req.params.id);
    if (!contact) throw AppError.notFound("That contact was not found.");
    return res.json(detailResponse(contact));
  })
);

/* -------------------------------------------------------------------------- */
/* Content                                                                     */
/* -------------------------------------------------------------------------- */

router.get(
  "/articles",
  requirePermission("content.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await content.listAdminArticles(params(req))))
);

router.get(
  "/articles/options",
  requirePermission("content.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await content.adminArticleOptions())))
);

router.get(
  "/articles/:id",
  requirePermission("content.view"),
  asyncHandler(async (req, res) => {
    const article = await content.getAdminArticle(req.params.id);
    if (!article) throw AppError.notFound("That article was not found.");
    return res.json(detailResponse(article));
  })
);

router.post(
  "/articles",
  writeLimiter,
  requirePermission("content.create"),
  validate({ body: mutations.articleSchema }),
  asyncHandler(async (req, res) => {
    // Publishing is a separate permission from authoring.
    if (req.body.status === "published" && !req.auth.platform.isSuperAdmin && !req.auth.platform.permissions.has("content.publish")) {
      throw AppError.forbidden("You can create drafts but not publish them.");
    }
    const result = await mutations.createArticle({ payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "article.created", subjectType: "post", subjectLabel: req.body.title });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/articles/:id",
  writeLimiter,
  requirePermission("content.edit"),
  validate({ body: mutations.articleSchema.partial() }),
  asyncHandler(async (req, res) => {
    if (req.body.status === "published" && !req.auth.platform.isSuperAdmin && !req.auth.platform.permissions.has("content.publish")) {
      throw AppError.forbidden("You can edit drafts but not publish them.");
    }
    const result = await mutations.updateArticle({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "article.updated", subjectType: "post", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/articles/:id/status",
  writeLimiter,
  requirePermission("content.publish"),
  validate({ body: z.object({ status: z.enum(["draft", "in_review", "scheduled", "published", "archived"]) }) }),
  asyncHandler(async (req, res) => {
    const result = await mutations.setArticleStatus({ identifier: req.params.id, status: req.body.status, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "article.status_changed", subjectType: "post", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/articles/:id",
  writeLimiter,
  requirePermission("content.delete"),
  asyncHandler(async (req, res) => {
    const result = await mutations.deleteArticle({ identifier: req.params.id });
    await auditFromRequest(req, { action: "article.archived", subjectType: "post", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/media",
  requirePermission("media.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await content.listAdminMedia(params(req))))
);

router.get(
  "/media/options",
  requirePermission("media.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await content.adminMediaOptions())))
);

router.get(
  "/media/:id",
  requirePermission("media.view"),
  asyncHandler(async (req, res) => {
    const media = await content.getAdminMedia(req.params.id);
    if (!media) throw AppError.notFound("That media item was not found.");
    return res.json(detailResponse(media));
  })
);

router.patch(
  "/media/:id",
  writeLimiter,
  requirePermission("media.edit"),
  validate({ body: mutations.mediaUpdateSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.updateMediaAsset({ identifier: req.params.id, payload: req.body });
    await auditFromRequest(req, { action: "media.updated", subjectType: "media_asset", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/media/:id",
  writeLimiter,
  requirePermission("media.delete"),
  asyncHandler(async (req, res) => {
    const result = await mutations.archiveMediaAsset({ identifier: req.params.id });
    await auditFromRequest(req, { action: "media.archived", subjectType: "media_asset", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

/* -------------------------------------------------------------------------- */
/* Reviews and reports                                                         */
/* -------------------------------------------------------------------------- */

router.get(
  "/reviews",
  requirePermission("reviews.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await content.listAdminReviews(params(req))))
);

router.get(
  "/reviews/:id",
  requirePermission("reviews.view"),
  asyncHandler(async (req, res) => {
    const review = await content.getAdminReview(req.params.id);
    if (!review) throw AppError.notFound("That review was not found.");
    return res.json(detailResponse(review));
  })
);

router.get(
  "/reviews/:id/reviewer-history",
  requirePermission("moderation.view"),
  asyncHandler(async (req, res) => {
    const review = await content.getAdminReview(req.params.id);
    if (!review?.reviewerId) return res.json({ data: [] });
    return res.json({ data: await content.adminReviewerHistory(review.reviewerId) });
  })
);

router.patch(
  "/reviews/:id/moderation",
  writeLimiter,
  requirePermission("reviews.moderate"),
  validate({ body: mutations.reviewModerationSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.moderateReview({ identifier: req.params.id, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: `review.${req.body.decision}`, subjectType: "review", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/reports",
  requirePermission("reports.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await content.listAdminReports(params(req))))
);

router.get(
  "/reports/:id",
  requirePermission("reports.view"),
  asyncHandler(async (req, res) => {
    const report = await content.getAdminReport(req.params.id);
    if (!report) throw AppError.notFound("That report was not found.");
    return res.json(detailResponse(report));
  })
);

router.patch(
  "/reports/:id",
  writeLimiter,
  requirePermission("reports.resolve"),
  validate({ body: mutations.reportActionSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.actOnReport({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: `report.${req.body.action}`, subjectType: "report", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

/* -------------------------------------------------------------------------- */
/* Settings                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * The admin General Settings screen owns a nested document; the flat
 * `general.*` rows the public site reads are mirrored from it on save.
 */
router.get(
  "/settings/general",
  requirePermission("settings.view"),
  asyncHandler(async (req, res) => {
    const [document, flat] = await Promise.all([
      settings.getSettingsDocument("admin_general"),
      settings.getSettings("general"),
    ]);
    return res.json(detailResponse({ ...document.document, _flat: flat.values, _meta: document.meta }));
  })
);

router.get(
  "/settings/general/options",
  requirePermission("settings.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await settings.generalSettingsOptions())))
);

router.patch(
  "/settings/general",
  writeLimiter,
  requirePermission("settings.edit"),
  validate({ body: z.record(z.string().max(120), z.unknown()) }),
  asyncHandler(async (req, res) => {
    const result = await settings.updateSettingsDocument({
      groupKey: "admin_general",
      patch: req.body,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, {
      action: "settings.updated",
      subjectType: "settings",
      subjectLabel: "general",
      changes: Object.keys(result.applied),
    });
    const document = await settings.getSettingsDocument("admin_general");
    return res.json(detailResponse(document.document));
  })
);

router.get(
  "/settings/payment",
  requirePermission("settings.view", "finance.view"),
  asyncHandler(async (req, res) => {
    const [document, flat] = await Promise.all([
      settings.getSettingsDocument("admin_payment"),
      settings.getSettings("payment"),
    ]);
    // `_flat` carries the provider credential status only — `{ configured, hint }`,
    // never a secret value.
    return res.json(detailResponse({ ...document.document, _flat: flat.values, _meta: document.meta }));
  })
);

router.get(
  "/settings/payment/options",
  requirePermission("settings.view", "finance.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await settings.paymentSettingsOptions())))
);

router.patch(
  "/settings/payment",
  writeLimiter,
  requirePermission("settings.manage"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: z.record(z.string().max(120), z.unknown()) }),
  asyncHandler(async (req, res) => {
    // Credential fields go to the flat `payment` group, which encrypts them;
    // everything else is a section of the admin document.
    const { credentials = {}, ...sections } = req.body;
    if (Object.keys(credentials).length) {
      await settings.updateSettings({ groupKey: "payment", patch: credentials, userId: req.auth.user.id });
    }
    const result = await settings.updateSettingsDocument({
      groupKey: "admin_payment",
      patch: sections,
      userId: req.auth.user.id,
    });
    // The audit records which keys changed, never a secret value.
    await auditFromRequest(req, {
      action: "settings.updated",
      subjectType: "settings",
      subjectLabel: "payment",
      changes: [...Object.keys(result.applied), ...Object.keys(credentials).map((key) => `${key}:[updated]`)],
    });
    const [document, flat] = await Promise.all([
      settings.getSettingsDocument("admin_payment"),
      settings.getSettings("payment"),
    ]);
    return res.json(detailResponse({ ...document.document, _flat: flat.values }));
  })
);

for (const group of ["listings", "security", "seo"]) {
  router.get(
    `/settings/${group}`,
    requirePermission("settings.view"),
    asyncHandler(async (req, res) => res.json(detailResponse(await settings.getSettings(group))))
  );
  router.patch(
    `/settings/${group}`,
    writeLimiter,
    requirePermission("settings.manage"),
    validate({ body: z.record(z.string().max(120), z.unknown()) }),
    asyncHandler(async (req, res) => {
      const result = await settings.updateSettings({ groupKey: group, patch: req.body, userId: req.auth.user.id });
      await auditFromRequest(req, { action: "settings.updated", subjectType: "settings", subjectLabel: group, changes: result.applied });
      return res.json(detailResponse(result.settings));
    })
  );
}

/* -------------------------------------------------------------------------- */
/* Access management                                                           */
/* -------------------------------------------------------------------------- */

router.get(
  "/roles",
  requirePermission("roles.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await settings.listAdminRoles(params(req))))
);

router.get(
  "/roles/options",
  requirePermission("roles.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await settings.adminRoleOptions())))
);

router.get(
  "/permission-catalog",
  requirePermission("roles.view"),
  asyncHandler(async (req, res) => {
    // The catalogue is the database's, not the frontend's: the matrix is drawn from
    // `permissionMatrix` (domain x action) and the category selector from
    // `categoryScopeOptions`. Adding a permission is a migration, not a UI change.
    const options = await settings.adminRoleOptions();
    return res.json(
      detailResponse({
        databasePermissions: await allPermissionCodes(),
        adminPermissions: await allPermissionCodes(),
        permissionMatrix: options.permissionMatrix,
        categoryScopeOptions: options.categoryScopeOptions,
      })
    );
  })
);

router.get(
  "/roles/:id",
  requirePermission("roles.view"),
  asyncHandler(async (req, res) => {
    const role = await settings.getAdminRole(req.params.id);
    if (!role) throw AppError.notFound("That role was not found.");
    return res.json(detailResponse(role));
  })
);

router.post(
  "/roles",
  writeLimiter,
  requirePermission("roles.create"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: mutations.roleSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertRole({ identifier: null, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "role.created", subjectType: "role", subjectId: Number(result.id), subjectLabel: req.body.name });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/roles/:id",
  writeLimiter,
  requirePermission("roles.edit"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: mutations.roleSchema.partial().extend({ name: z.string().trim().min(1).max(120) }) }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertRole({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "role.updated", subjectType: "role", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/roles/:id",
  writeLimiter,
  requirePermission("roles.delete"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  asyncHandler(async (req, res) => {
    const result = await mutations.deleteRole({ identifier: req.params.id });
    await auditFromRequest(req, { action: "role.deleted", subjectType: "role", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/access-users",
  requirePermission("users.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await settings.listAdminAccessUsers(params(req))))
);

router.get(
  "/access-users/:id",
  requirePermission("users.view"),
  asyncHandler(async (req, res) => {
    const user = await settings.getAdminAccessUser(req.params.id);
    if (!user) throw AppError.notFound("That user was not found.");
    return res.json(detailResponse(user));
  })
);

router.post(
  "/access-users",
  writeLimiter,
  requirePermission("users.create"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: mutations.internalUserSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertInternalUser({ identifier: null, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "internal_user.created", subjectType: "user", subjectLabel: req.body.email });
    return res.status(201).json(detailResponse(result));
  })
);

router.patch(
  "/access-users/:id",
  writeLimiter,
  requirePermission("users.edit"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: mutations.internalUserSchema.partial().extend({ firstName: z.string().trim().min(1).max(120), lastName: z.string().trim().min(1).max(120), email: z.string().trim().toLowerCase().email().max(255) }) }),
  asyncHandler(async (req, res) => {
    const result = await mutations.upsertInternalUser({ identifier: req.params.id, payload: req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "internal_user.updated", subjectType: "user", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/users/:id/reset-access",
  writeLimiter,
  requirePermission("users.suspend"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  asyncHandler(async (req, res) => {
    const result = await mutations.resetUserAccess({ identifier: req.params.id, actorUserId: req.auth.user.id });
    await auditFromRequest(req, {
      action: "user.access_reset",
      subjectType: "user",
      subjectLabel: req.params.id,
      metadata: { sessionsRevoked: result.sessionsRevoked },
    });
    return res.json(detailResponse(result));
  })
);

router.patch(
  "/users/:id/status",
  writeLimiter,
  requirePermission("users.suspend"),
  // SEC-IAM-011: high-risk, so the session must have re-proved itself recently.
  requireStepUp(),
  validate({ body: mutations.accountStateSchema }),
  asyncHandler(async (req, res) => {
    const result = await mutations.setUserState({ identifier: req.params.id, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "user.status_changed", subjectType: "user", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

/** The caller's own resolved permissions, for the admin shell. */
router.get(
  "/me/permissions",
  asyncHandler(async (req, res) =>
    res.json(
      detailResponse({
        roles: req.auth.platform.roles,
        databasePermissions: [...req.auth.platform.permissions].sort(),
        permissions: toAdminPermissions([...req.auth.platform.permissions], { isSuperAdmin: req.auth.platform.isSuperAdmin }),
        isSuperAdmin: req.auth.platform.isSuperAdmin,
      })
    )
  )
);

/* -------------------------------------------------------------------------- */
/* System logs                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * The audit trail, queryable at last. Gated on `system.view` — the same permission that opens
 * system logs, because they answer the same kind of question.
 */
router.get(
  "/audit-events",
  requirePermission("system.view"),
  validate({
    query: z
      .object({
        actor: z.string().trim().max(120).optional(),
        action: z.string().trim().max(80).optional(),
        subjectType: z.string().trim().max(60).optional(),
        subjectId: z.string().trim().max(60).optional(),
        from: z.string().trim().max(40).optional(),
        to: z.string().trim().max(40).optional(),
        search: z.string().trim().max(200).optional(),
        page: z.coerce.number().int().min(1).max(5000).optional(),
        pageSize: z.coerce.number().int().min(1).max(200).optional(),
      })
      .partial(),
  }),
  asyncHandler(async (req, res) => res.json(await settings.searchAuditEvents(params(req))))
);

router.get(
  "/system-logs",
  requirePermission("system.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => res.json(await settings.listAdminSystemLogs(params(req))))
);

router.get(
  "/system-logs/options",
  requirePermission("system.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(await settings.adminSystemLogOptions())))
);

router.get(
  "/system-logs/:id",
  requirePermission("system.view"),
  asyncHandler(async (req, res) => {
    const log = await settings.getAdminSystemLog(req.params.id);
    if (!log) throw AppError.notFound("That log entry was not found.");
    return res.json(detailResponse(log));
  })
);

router.get(
  "/system-logs/:id/related",
  requirePermission("system.view"),
  asyncHandler(async (req, res) => res.json({ data: await settings.getRelatedSystemLogs(req.params.id) }))
);

export default router;
