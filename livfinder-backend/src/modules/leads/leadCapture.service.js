import { execute, queryOne, queryValue } from "../../db/query.js";
import { ulid } from "../../utils/ids.js";

/** Best-effort `leads.intent` from the public form's (looser) `inquiryType`. */
const INTENT_BY_INQUIRY_TYPE = {
  viewing: "buy", callback: "buy", price: "buy", offer: "buy", availability: "buy",
  general: "buy", brochure: "buy", floor_plan: "buy",
  valuation: "valuation", charter: "charter",
};

/** The platform-wide "Website enquiry" lead source (migration 0049). */
export async function websiteLeadSourceId(connection) {
  return queryValue(
    "SELECT id FROM lead_sources WHERE code = 'website' AND organization_id IS NULL LIMIT 1",
    [],
    connection
  );
}

/**
 * Turns a public listing enquiry into a CRM lead.
 *
 * Before this, `POST /inquiries` only ever wrote to `inquiries` — the table
 * the client portal's Leads page reads. The admin Leads module reads the
 * separate `leads` table, which nothing in the running application wrote to
 * (every row was seed data). A real visitor's enquiry reached the listing's
 * owner and never reached admin/ops at all. This closes that gap: dedupe the
 * contact by (organization, email), reuse an already-open lead for the same
 * contact + listing rather than spawning a new one on every re-submission,
 * and log one activity that is visible from the lead, the contact and the
 * listing's own engagement tab (`getAdminListingEngagement` reads
 * `subject_type = 'listing'`; the lead and contact detail screens read the
 * direct `lead_id` / `contact_id` columns — this row satisfies all three).
 *
 * Returns the lead's numeric id, to link back from `inquiries.lead_id`.
 */
/**
 * What an enquiry is about, in the one shape a lead needs — a listing or a development.
 * A development is filed under the Real Estate Developments root (7), which is where the
 * admin Developments → Leads screen and its summary look; the project row itself hangs off
 * the Real Estate root for historical reasons.
 */
export const DEVELOPMENTS_ROOT_ID = 7;

export function listingLeadSubject(listing) {
  return {
    kind: "listing", id: listing.id, title: listing.title,
    organization_id: listing.organization_id, account_id: listing.account_id,
    category_id: listing.category_id, root_category_id: listing.root_category_id ?? null,
    purpose_id: listing.purpose_id ?? null, location_id: listing.location_id, country_id: listing.country_id,
  };
}

export function projectLeadSubject(project) {
  return {
    kind: "project", id: project.id, title: project.name,
    organization_id: project.organization_id, account_id: project.account_id ?? null,
    category_id: DEVELOPMENTS_ROOT_ID, root_category_id: DEVELOPMENTS_ROOT_ID,
    purpose_id: null, location_id: project.location_id ?? null, country_id: project.country_id ?? null,
  };
}

/**
 * The CRM contact for a person, deduplicated within the organization. Contacts belong to an
 * organization, so an individual seller's leads carry the person on the lead itself instead.
 */
export async function findOrCreateContact({ organizationId, name, email, phone, sourceId }, connection) {
  if (!organizationId) return null;
  const normalizedEmail = email ? String(email).trim().toLowerCase() : null;
  const match = normalizedEmail
    ? { sql: "primary_email_normalized = ?", value: normalizedEmail }
    : phone
      ? { sql: "primary_phone_e164 = ?", value: phone }
      : null;
  const existing = match
    ? await queryOne(
        `SELECT id FROM crm_contacts WHERE organization_id = ? AND ${match.sql} AND deleted_at IS NULL LIMIT 1`,
        [organizationId, match.value],
        connection
      )
    : null;
  if (existing) return existing;

  const [firstName, ...rest] = name.split(/\s+/);
  const lastName = rest.join(" ") || null;
  const result = await execute(
    `INSERT INTO crm_contacts
       (public_id, organization_id, contact_type, first_name, last_name, display_name, name_normalized,
        primary_email, primary_email_normalized, primary_phone_e164, source_id, created_at, updated_at)
     VALUES (?, ?, 'buyer', ?, ?, ?, LOWER(?), ?, ?, ?, ?, NOW(3), NOW(3))`,
    [ulid(), organizationId, firstName || name, lastName, name, name, email || null, normalizedEmail, phone || null, sourceId],
    connection
  );
  return { id: result.insertId };
}

export async function linkInquiryToLead({ subject, inquiry }, connection) {
  // Nobody owns it, so nobody can work it: it stays an enquiry.
  if (!subject.organization_id && !subject.account_id) return null;
  const email = inquiry.email ? String(inquiry.email).trim().toLowerCase() : null;
  const name = String(inquiry.name).trim();

  const contact = await findOrCreateContact(
    {
      organizationId: subject.organization_id,
      name,
      email: inquiry.email,
      phone: inquiry.phone,
      sourceId: await websiteLeadSourceId(connection),
    },
    connection
  );

  // An enquiry whose listing is gone has no subject to dedupe against.
  const subjectColumn = { project: "project_id", listing: "primary_listing_id" }[subject.kind];
  const person = contact ? { sql: "contact_id = ?", value: contact.id } : { sql: "account_id = ? AND email = ?", values: [subject.account_id, email] };
  const existingLead = subjectColumn
    ? await queryOne(
        `SELECT id FROM leads
          WHERE ${person.sql} AND ${subjectColumn} = ? AND status = 'open' AND deleted_at IS NULL
          LIMIT 1`,
        [...(person.values ?? [person.value]), subject.id],
        connection
      )
    : null;
  if (existingLead) {
    await execute(
      "UPDATE leads SET inquiry_count = inquiry_count + 1, last_activity_at = NOW(3) WHERE id = ?",
      [existingLead.id],
      connection
    );
    await logInquiryActivity({ subject, contact, leadId: existingLead.id, inquiry }, connection);
    return existingLead.id;
  }

  const sourceId = await websiteLeadSourceId(connection);
  const stage = await queryOne(
    `SELECT lps.id AS stage_id, lps.pipeline_id
       FROM lead_pipeline_stages lps
       JOIN lead_pipelines lp ON lp.id = lps.pipeline_id
      WHERE lp.is_default = 1 AND lps.code = 'new'
      LIMIT 1`,
    [],
    connection
  );
  const maxRef = await queryValue(
    "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM leads WHERE reference LIKE 'LD-%'",
    [],
    connection
  );
  const reference = `LD-${Number(maxRef || 10000) + 1}`;

  const leadResult = await execute(
    `INSERT INTO leads
       (public_id, reference, organization_id, account_id, contact_id, pipeline_id, stage_id, stage_type,
        status, name, email, phone_e164, intent, category_id, root_category_id, purpose_id,
        primary_listing_id, project_id, location_id, country_id, source_id, channel, inquiry_count,
        stage_entered_at, last_activity_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 'new', 'open', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'web_form', 1,
             NOW(3), NOW(3), NOW(3), NOW(3))`,
    [
      ulid(), reference, subject.organization_id ?? null, subject.account_id, contact?.id ?? null,
      stage?.pipeline_id ?? 1, stage?.stage_id ?? null,
      name, inquiry.email, inquiry.phone || null,
      INTENT_BY_INQUIRY_TYPE[inquiry.inquiryType] || "other",
      subject.category_id, subject.root_category_id, subject.purpose_id,
      subject.kind === "listing" ? subject.id : null,
      subject.kind === "project" ? subject.id : null,
      subject.location_id, subject.country_id, sourceId,
    ],
    connection
  );

  await logInquiryActivity({ subject, contact, leadId: leadResult.insertId, inquiry }, connection);
  return leadResult.insertId;
}

async function logInquiryActivity({ subject, contact, leadId, inquiry }, connection) {
  await execute(
    `INSERT INTO activities
       (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
        activity_type, direction, subject_line, body, occurred_at, is_automated, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 'other', 'inbound', ?, ?, NOW(3), 1, NOW(3), NOW(3))`,
    [
      ulid(), subject.organization_id ?? null, subject.kind, subject.id, leadId, contact?.id ?? null,
      `Website enquiry — ${subject.title}`, inquiry.message,
    ],
    connection
  );
}

