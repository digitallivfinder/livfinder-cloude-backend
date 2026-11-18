import { z } from "zod";
import { execute, queryOne, queryValue } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { optionalPhone } from "../../utils/phone.js";
import { enumValues } from "../options/optionSets.js";

/**
 * Admin "Add Contact" / "Edit Contact".
 *
 * `/v1/admin/contacts` was read-only, so both drawers had their Save switched off (and before
 * that, built a record in the browser that vanished on reload). A contact is a row in a
 * company's CRM (`crm_contacts.organization_id` is required), so a new one names the company it
 * belongs to; that never changes on edit.
 *
 * Choice fields are validated against the database's own ENUMs and tables — the same sources the
 * form's option sets read (`contact.type`, `contact.stage`, `lead.source`).
 */

const blank = z.literal("");
const flag = z.boolean().optional();

export const contactWriteSchema = z.object({
  companyId: z.string().trim().max(40).optional(),
  firstName: z.string().trim().min(1, "Enter the first name.").max(120),
  lastName: z.string().trim().max(120).optional().or(blank),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255).optional().or(blank),
  phone: optionalPhone,
  companyName: z.string().trim().max(200).optional().or(blank),
  jobTitle: z.string().trim().max(160).optional().or(blank),
  contactType: z.string().trim().max(40).optional(),
  lifecycleStage: z.string().trim().max(40).optional(),
  source: z.string().trim().max(60).optional().or(blank),
  countryId: z.coerce.number().int().positive().optional().nullable(),
  cityId: z.coerce.number().int().positive().optional().nullable(),
  notes: z.string().trim().max(5000).optional().or(blank),
  allowEmail: flag,
  allowSms: flag,
  allowCall: flag,
  allowWhatsapp: flag,
  isVip: flag,
});

const invalid = (field, message) => AppError.validation("Some information is invalid.", { [field]: message });

async function assertEnum(column, value, field) {
  if (value === undefined) return;
  const allowed = await enumValues("crm_contacts", column);
  if (!allowed.includes(value)) throw invalid(field, "Choose one of the listed values.");
}

async function sourceId(code) {
  if (code === undefined) return undefined;
  if (!code) return null;
  const id = await queryValue("SELECT id FROM lead_sources WHERE code = ? OR name = ? LIMIT 1", [code, code]);
  if (!id) throw invalid("source", "Choose one of the listed sources.");
  return id;
}

async function place(id, level, field) {
  if (id === undefined || id === null) return id;
  const row = await queryOne("SELECT id, level, country_id FROM locations WHERE id = ? AND deleted_at IS NULL", [id]);
  if (!row || row.level !== level) throw invalid(field, `Choose a ${level} from the list.`);
  return row;
}

/** Column assignments for the fields present in the payload; a missing key leaves the column alone. */
async function columnsFor(payload, existing = {}) {
  await assertEnum("contact_type", payload.contactType, "contactType");
  await assertEnum("lifecycle_stage", payload.lifecycleStage, "lifecycleStage");
  const country = await place(payload.countryId, "country", "countryId");
  const city = await place(payload.cityId, "city", "cityId");
  const countryId = country === undefined ? existing.country_id : country?.id ?? null;
  if (city && countryId && String(city.country_id) !== String(countryId)) throw invalid("cityId", "Choose a city in the selected country.");

  const firstName = payload.firstName ?? existing.first_name ?? "";
  const lastName = payload.lastName === undefined ? existing.last_name ?? "" : payload.lastName;
  const displayName = `${firstName} ${lastName ?? ""}`.trim();
  const columns = {
    first_name: firstName,
    last_name: lastName || null,
    display_name: displayName,
    name_normalized: displayName.toLowerCase(),
  };
  const optional = {
    company_name: payload.companyName,
    job_title: payload.jobTitle,
    notes: payload.notes,
    contact_type: payload.contactType,
    lifecycle_stage: payload.lifecycleStage,
    primary_phone_e164: payload.phone,
  };
  for (const [column, value] of Object.entries(optional)) if (value !== undefined) columns[column] = value || null;
  if (payload.contactType === undefined && !existing.id) columns.contact_type = "buyer";
  if (payload.lifecycleStage === undefined && !existing.id) columns.lifecycle_stage = "lead";
  if (payload.email !== undefined) {
    columns.primary_email = payload.email || null;
    columns.primary_email_normalized = payload.email ? payload.email.toLowerCase() : null;
  }
  if (country !== undefined) columns.country_id = country?.id ?? null;
  if (city !== undefined) columns.city_id = city?.id ?? null;
  const source = await sourceId(payload.source);
  if (source !== undefined) columns.source_id = source;
  for (const [key, column] of [["allowEmail", "allow_email"], ["allowSms", "allow_sms"], ["allowCall", "allow_call"], ["allowWhatsapp", "allow_whatsapp"], ["isVip", "is_vip"]]) {
    if (payload[key] !== undefined) columns[column] = payload[key] ? 1 : 0;
  }
  return columns;
}

async function assertNoDuplicate({ organizationId, email, exceptId = null }) {
  if (!email) return;
  const duplicate = await queryOne(
    `SELECT public_id, display_name FROM crm_contacts
      WHERE organization_id = ? AND primary_email_normalized = ? AND deleted_at IS NULL AND (? IS NULL OR id <> ?)
      LIMIT 1`,
    [organizationId, email.toLowerCase(), exceptId, exceptId]
  );
  if (duplicate) {
    const message = `${duplicate.display_name} already has this email in that company's contacts.`;
    throw AppError.conflict(message, { email: message });
  }
}

export async function createAdminContact({ payload, userId }) {
  if (!payload.companyId) throw invalid("companyId", "Choose the company this contact belongs to.");
  if (!payload.email && !payload.phone) throw invalid("email", "Give an email address or a phone number.");
  const organization = await queryOne(
    "SELECT id, account_id FROM organizations WHERE public_id = ? AND deleted_at IS NULL",
    [payload.companyId]
  );
  if (!organization) throw invalid("companyId", "That company was not found.");
  await assertNoDuplicate({ organizationId: organization.id, email: payload.email });

  const columns = {
    public_id: ulid(),
    organization_id: organization.id,
    account_id: organization.account_id,
    created_by_user_id: userId,
    ...(await columnsFor(payload)),
  };
  const names = Object.keys(columns);
  await execute(
    `INSERT INTO crm_contacts (${names.join(", ")}, created_at, updated_at)
     VALUES (${names.map(() => "?").join(", ")}, NOW(3), NOW(3))`,
    Object.values(columns)
  );
  return { id: columns.public_id };
}

export async function updateAdminContact({ identifier, payload }) {
  const existing = await queryOne(
    "SELECT id, organization_id, first_name, last_name, country_id FROM crm_contacts WHERE public_id = ? AND deleted_at IS NULL",
    [identifier]
  );
  if (!existing) throw AppError.notFound("That contact was not found.");
  if (payload.email) await assertNoDuplicate({ organizationId: existing.organization_id, email: payload.email, exceptId: existing.id });

  const columns = await columnsFor(payload, existing);
  const names = Object.keys(columns);
  await execute(
    `UPDATE crm_contacts SET ${names.map((name) => `${name} = ?`).join(", ")}, updated_at = NOW(3) WHERE id = ?`,
    [...Object.values(columns), existing.id]
  );
  return { id: identifier };
}

/**
 * Archive: the contact leaves every list and search, and its leads keep their history. A soft
 * delete (`deleted_at`), so it can be brought back in the database. The list's "Archive" used to
 * hide the row in the browser only.
 */
export async function archiveAdminContact({ identifier }) {
  const result = await execute(
    "UPDATE crm_contacts SET deleted_at = NOW(3), updated_at = NOW(3) WHERE public_id = ? AND deleted_at IS NULL",
    [identifier]
  );
  if (!result.affectedRows) throw AppError.notFound("That contact was not found.");
  return { id: identifier, archived: true };
}
