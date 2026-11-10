import { enumSet, enumValues, fixedSet, registerOptionSets, sentenceLabel, tableSet } from "./optionSets.js";
import { ADMIN_STATUS_TO_DB } from "../admin/admin.catalog.js";
import { LEAD_SCREEN_STATUSES } from "../admin/admin.crm.js";
import { LISTING_TAB_LABELS } from "../portal/portal.repository.js";
import { IMPORT_ITEM_RESULTS, IMPORT_TYPES } from "../imports/imports.repository.js";
import { FUNNEL_STEPS, funnelStepLabel } from "../leads/leadFunnel.js";
import { API_SCOPES } from "../../middleware/apiClient.js";
import { MAPPING_TYPES } from "../feeds/valueMappings.js";
import { rootIdFor } from "../admin/admin.shared.js";
import { query } from "../../db/query.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";

/**
 * The option sets behind every table header filter (see optionSets.js for where each kind of
 * set comes from). Names are `area.field`; the frontend asks for them by name.
 */

/**
 * The marketplace's top-level categories, by slug — the value every category filter sends —
 * read from the categories table. Named as the rest of the app names them (CATEGORY_DEFINITIONS:
 * "Real Estate", not the table's plural "Properties"); a new root shows its own name.
 */
const rootCategories = async () => {
  const rows = await query(
    `SELECT slug, name, name_plural FROM categories
      WHERE parent_id IS NULL AND deleted_at IS NULL AND status = 'active'
      ORDER BY sort_order ASC, id ASC`
  );
  const known = new Map(CATEGORY_DEFINITIONS.map((definition) => [definition.listingType, definition.label]));
  return rows.map((row) => ({ value: row.slug, label: known.get(row.slug) ?? (row.name_plural || row.name) }));
};

/** A status column plus the extra values the API works out (e.g. "rejected" = pending and rejected on verification). */
const enumPlus = (table, column, extra, options) => async () => [...(await enumSet(table, column, options)()), ...extra.map(([value, label]) => ({ value, label }))];

// Shared by both portals.
registerOptionSets(
  {
    "category.root": rootCategories,
    "inquiry.status": enumSet("inquiries", "status"),
    "inquiry.type": enumSet("inquiries", "inquiry_type"),
    // A draft offer or invoice is never shown to a client.
    "offer.status": enumSet("offers", "status", { exclude: ["draft"] }),
    "booking.status": enumSet("bookings", "status", { labels: { no_show: "No-show" } }),
    "booking.type": enumSet("bookings", "booking_type"),
    "payment.status": enumSet("payments", "status"),
    "payment.method": enumSet("payment_methods", "method_type", { labels: { sepa_debit: "SEPA debit", paypal: "PayPal" } }),
    "payout.status": enumSet("payouts", "status"),
    "payout.method": enumSet("payout_methods", "method_type", { labels: { paypal: "PayPal", stripe_connect: "Stripe Connect" } }),
    "invoice.status": enumSet("invoices", "status", { exclude: ["draft"] }),
    "agent.status": enumSet("agents", "status"),
    "agent.verification": enumSet("agents", "verification_status"),
    "lead.intent": enumSet("leads", "intent", { labels: { buy: "Buying", rent: "Renting", sell: "Selling", let: "Letting", invest: "Investment", other: "General enquiry" } }),
    "lead.timeframe": enumSet("leads", "timeframe", { labels: { within_1_month: "Within 1 month", within_3_months: "Within 3 months", within_6_months: "Within 6 months", within_12_months: "Within 12 months" } }),
    "lead.priority": enumSet("leads", "priority"),
    "categoryAccess.status": enumSet("account_category_access", "status"),
    // The client lead funnel; "viewing" is called what the category calls it ("lead.funnelStep:cars" → Test drive).
    "lead.funnelStep": async (category) => {
      const rootId = category ? rootIdFor(category) : null;
      return FUNNEL_STEPS.map((step) => ({ value: step, label: funnelStepLabel(step, rootId) }));
    },
    "listing.portalStatus": fixedSet(LISTING_TAB_LABELS),
    "import.type": fixedSet(IMPORT_TYPES),
    "import.status": enumSet("feed_imports", "status", { labels: { partial: "Some failed", held_for_review: "Held for review" } }),
    "importItem.result": fixedSet(IMPORT_ITEM_RESULTS),
    "importItem.operation": enumSet("feed_import_items", "operation"),
    "importItem.status": enumSet("feed_import_items", "status"),
    "member.role": enumSet("account_members", "role"),
    "invitation.role": enumSet("team_invitations", "role"),
    "invitation.status": enumSet("team_invitations", "status"),
    "apiClient.status": enumSet("api_clients", "status"),
    "apiClient.scope": fixedSet(API_SCOPES.map((scope) => [scope, scope])),
    "webhook.status": enumSet("webhooks", "status"),
    "webhookDelivery.status": enumSet("webhook_deliveries", "status"),
    "leadFeed.status": enumSet("lead_feed_tokens", "status"),
    "feedSource.status": enumSet("feed_sources", "status"),
    "feedSource.format": enumSet("feed_sources", "format", { labels: { auto: "Auto-detect", xml: "XML", csv: "CSV" } }),
    "feedSource.schedule": enumSet("feed_sources", "schedule", { labels: { every_6_hours: "Every 6 hours" } }),
    "lead.source": tableSet("SELECT code AS value, name AS label FROM lead_sources WHERE is_active = 1 AND code IS NOT NULL ORDER BY sort_order ASC, name ASC"),
    // The portal's lead rows carry the source's name, so its toolbar filters by name.
    "lead.sourceName": tableSet("SELECT DISTINCT name AS value, name AS label FROM lead_sources WHERE is_active = 1 ORDER BY name ASC"),
  },
  { portal: true }
);

// Admin only.
registerOptionSets({
  // The admin listing Status column: the API's tab grouping (ADMIN_STATUS_TO_DB) plus "changes"
  // — live listings with owner changes waiting (0060).
  "listing.adminStatus": fixedSet([
    ...Object.keys(ADMIN_STATUS_TO_DB).map((value) => [value, { approved: "Approved", sold: "Sold / Rented" }[value] ?? sentenceLabel(value)]),
    ["changes", "Changes waiting"],
  ]),
  "listing.status": enumSet("listings", "status"),
  "lead.status": enumSet("leads", "status"),
  "invoice.anyStatus": enumSet("invoices", "status"),
  "watch.condition": enumSet("listing_timepiece", "condition_grade"),
  "project.status": enumSet("projects", "status"),
  "project.moderation": enumSet("projects", "moderation_status"),
  "lead.adminStatus": fixedSet(LEAD_SCREEN_STATUSES),
  "contact.type": enumSet("crm_contacts", "contact_type"),
  "contact.stage": enumSet("crm_contacts", "lifecycle_stage"),
  "organization.status": enumPlus("organizations", "status", [["rejected", "Rejected"]]),
  "account.status": enumPlus("accounts", "status", [["rejected", "Rejected"]]),
  "user.status": enumSet("users", "status"),
  "plan": tableSet("SELECT id AS value, name AS label FROM plans WHERE is_active = 1 ORDER BY sort_order ASC, id ASC"),
  "plan.billing": enumSet("plans", "billing_interval"),
  "plan.tier": tableSet("SELECT DISTINCT tier AS value, CONCAT('Tier ', tier) AS label FROM plans WHERE tier IS NOT NULL ORDER BY tier ASC"),
  // How a plan offers Integrations, and its active / public flags (plans.is_active, plans.is_public).
  "plan.integrations": fixedSet([["not-offered", "Not offered"], ["free", "Free"], ["paid", "Paid"]]),
  "plan.state": fixedSet([["active", "Active"], ["inactive", "Inactive"], ["public", "Public"], ["internal", "Internal"]]),
  "role": tableSet("SELECT id AS value, name AS label FROM roles WHERE scope = 'platform' ORDER BY sort_order ASC, id ASC"),
  // roles.is_system, and whether a role is in use.
  "role.type": fixedSet([["system", "System Role"], ["custom", "Custom Role"]]),
  "role.state": fixedSet([["active", "Active"], ["inactive", "Inactive"]]),
  "post.status": enumSet("posts", "status"),
  "editorial.category": tableSet("SELECT slug AS value, name AS label FROM editorial_terms WHERE taxonomy = 'category' ORDER BY name ASC"),
  "author": tableSet("SELECT public_id AS value, name AS label, avatar_url AS image FROM authors WHERE is_active = 1 ORDER BY name ASC"),
  // media_assets.media_type, with PDFs split out of documents and everything else as "other" (admin.content.js).
  "media.type": async () => {
    const types = await enumValues("media_assets", "media_type");
    const main = ["image", "video", "document", "audio"].filter((type) => types.includes(type));
    return [...main.map((value) => ({ value, label: sentenceLabel(value) })), { value: "pdf", label: "PDFs" }, { value: "other", label: "Other" }];
  },
  "location.status": enumSet("locations", "status"),
  "category.status": enumSet("categories", "status"),
  "feedMapping.kind": fixedSet(MAPPING_TYPES.map((type) => [type, { location: "Place", category: "Property type" }[type] ?? sentenceLabel(type)])),
  "report.status": enumSet("reports", "status", { labels: { in_review: "Under review" } }),
  "report.priority": enumSet("reports", "priority"),
  "report.subjectType": enumSet("reports", "subject_type", { labels: { organization: "Company" } }),
  "report.reason": tableSet("SELECT code AS value, name AS label FROM report_reasons WHERE is_active = 1 ORDER BY sort_order ASC"),
  "review.status": enumSet("reviews", "status"),
  "review.subjectType": enumSet("reviews", "subject_type", { labels: { organization: "Company" } }),
  "review.rating": fixedSet([5, 4, 3, 2, 1].map((value) => [String(value), `${value} star${value === 1 ? "" : "s"}`])),
  "systemLog.level": enumSet("system_logs", "level"),
  // What a category grant can allow (session.serializer.js maps each to a permission flag).
  "categoryAccess.action": fixedSet([["manageListings", "Manage Listings"], ["leads", "Leads"], ["inquiries", "Inquiries"], ["edit", "Edit"], ["delete", "Delete"]]),
  "categoryAccess.level": fixedSet([["full", "Full Access"], ["limited", "Limited Access"], ["none", "No Access"]]),
  "revision.status": enumSet("listing_revisions", "status"),
});
