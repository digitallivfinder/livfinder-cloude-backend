import { execute, queryOne, queryValue } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { resolveCategory } from "../../utils/categories.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { splitPhone } from "../../utils/phone.js";
import { sanitizeDescription } from "../../utils/richText.js";
import { slugify } from "../../utils/slug.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { assertRegistrationAvailable, createVerificationRequest, organizationKindFor } from "./accounts.service.js";
import { attachUploadedDocuments } from "./verification.service.js";

/**
 * A Member asking to become a seller.
 *
 * Nothing about the account changes until an admin approves: the person keeps everything a
 * Member has while they wait, and the application itself is what the review reads.
 * `payload.application` marks it, and is what approval uses to upgrade the account.
 */
const OPEN = ["pending", "in_review"];

async function latestApplication(accountId, { organizationOnly = false } = {}) {
  return queryOne(
    `SELECT vr.id, vr.public_id, vr.status, vr.subject_type, vr.decision_notes, vr.rejection_reason, vr.submitted_at, vr.payload
       FROM verification_requests vr
      WHERE JSON_EXTRACT(vr.payload, '$.application') IS NOT NULL
        AND ((vr.subject_type = 'account' AND vr.subject_id = ? AND ? = 0)
          OR (vr.subject_type = 'organization' AND vr.subject_id IN (SELECT id FROM organizations WHERE account_id = ?)))
      ORDER BY vr.id DESC LIMIT 1`,
    [accountId, organizationOnly ? 1 : 0, accountId]
  );
}

/** Whether a person who chose to sell still owes an application: none yet, or the last one refused. */
export async function sellerProfileRequired(accountId) {
  const application = await latestApplication(accountId);
  return !application || !OPEN.includes(application.status);
}

export async function applicationStatus(req) {
  const membership = req.auth.activeMembership;
  const isMember = membership?.account_type_code === "personal";
  // An individual seller's own approved application is history; only a move to a company counts.
  const canUpgrade = membership?.account_type_code === "lister";
  const application =
    isMember || canUpgrade
      ? await latestApplication(req.auth.activeAccountId, { organizationOnly: canUpgrade })
      : null;
  const payload = typeof application?.payload === "string" ? JSON.parse(application.payload) : application?.payload;
  const account = await queryOne("SELECT seller_intent FROM accounts WHERE id = ?", [req.auth.activeAccountId]);
  const user = await queryOne(
    `SELECT u.first_name, u.last_name, u.phone_e164, u.email, u.email_verified_at, u.country_id, u.city_id,
            co.name AS country_name, ct.name AS city_name
       FROM users u
       LEFT JOIN locations co ON co.id = u.country_id
       LEFT JOIN locations ct ON ct.id = u.city_id
      WHERE u.id = ?`,
    [req.auth.user.id]
  );
  return {
    isMember,
    canUpgrade,
    emailConfirmed: Boolean(user.email_verified_at),
    sellerIntent: isMember ? account?.seller_intent ?? null : null,
    application: application
      ? {
          id: application.public_id,
          status: application.status,
          type: payload?.application ?? null,
          subjectType: application.subject_type,
          decisionNotes: application.status === "in_review" ? application.decision_notes : null,
          rejectionReason: application.rejection_reason,
        }
      : null,
    prefill: {
      name: [user.first_name, user.last_name].filter(Boolean).join(" "),
      email: user.email,
      phone: user.phone_e164,
      countryId: user.country_id ? `country:${user.country_id}` : null,
      country: user.country_name,
      cityId: user.city_id ? `city:${user.city_id}` : null,
      city: user.city_name,
    },
  };
}

async function location(countryId, cityId) {
  const country = await resolveLocation(countryId);
  if (country?.level !== "country") {
    throw AppError.validation("Some information is invalid.", { country: "Choose a country from the list." });
  }
  if (!cityId) return { countryId: country.id, cityId: null };
  const city = await resolveLocation(cityId);
  if (city?.level !== "city" || String(city.country_id) !== String(country.id)) {
    throw AppError.validation("Some information is invalid.", { city: "Choose a city in the selected country." });
  }
  return { countryId: country.id, cityId: city.id };
}

function requireDocuments(input) {
  const types = new Set(input.documents.map((document) => document.documentType));
  const errors = {};
  if (!types.has("identity")) errors.identity = "Upload an identity document.";
  if (input.accountType === "organization" && !types.has("organization_registration")) {
    errors.organization_registration = "Upload proof of the organization.";
  }
  if (Object.keys(errors).length) throw AppError.validation("Some information is invalid.", errors);
}

async function requestCategory(accountId, rootId, userId, connection) {
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, requested_by_user_id, created_at)
     VALUES (?, ?, 'requested', 0, NOW(3), ?, NOW(3))
     ON DUPLICATE KEY UPDATE status = IF(status = 'approved', status, 'requested'), requested_at = NOW(3)`,
    [accountId, rootId, userId],
    connection
  );
}

async function savePersonal(input, { userId, accountId, rootId }, place, connection) {
  const existing = await queryValue("SELECT id FROM agents WHERE user_id = ? AND deleted_at IS NULL LIMIT 1", [userId], connection);
  const fields = [input.displayName, sanitizeDescription(input.bio), input.phone, input.license || null, place.countryId, place.cityId];
  if (existing) {
    await execute(
      "UPDATE agents SET display_name = ?, bio = ?, phone = ?, license_number = ?, country_id = ?, city_id = ? WHERE id = ?",
      [...fields, existing],
      connection
    );
  } else {
    const user = await queryOne("SELECT first_name, last_name, email FROM users WHERE id = ?", [userId], connection);
    await execute(
      `INSERT INTO agents
         (public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, email, phone,
          license_number, country_id, city_id, status, verification_status, is_publicly_visible, created_at)
       VALUES (?, ?, NULL, ?, ?, ?, ?, 'Independent Advisor', ?, ?, ?, ?, ?, ?, 'pending', 'pending', 0, NOW(3))`,
      [ulid(), userId, user.first_name, user.last_name, input.displayName, `${slugify(input.displayName) || "advisor"}-${userId}`,
        fields[1], user.email, input.phone, fields[3], place.countryId, place.cityId],
      connection
    );
  }
  await requestCategory(accountId, rootId, userId, connection);
  return createVerificationRequest(
    { subjectType: "account", subjectId: accountId, userId, payload: { application: "personal", accountType: "personal", categoryId: input.categoryId } },
    connection
  );
}

async function saveOrganization(input, { userId, accountId, rootId, listingType, fromType }, place, connection) {
  const name = input.publicName;
  const kind = organizationKindFor(input.organizationType, listingType);
  const values = [kind, name, input.legalName, sanitizeDescription(input.description), input.organizationEmail,
    input.organizationPhone, input.website || null, input.address, place.countryId, place.cityId];
  const previous = await queryValue("SELECT id FROM organizations WHERE account_id = ? LIMIT 1", [accountId], connection);
  let organizationId = previous;
  if (previous) {
    await execute(
      `UPDATE organizations
          SET kind = ?, name = ?, legal_name = ?, description = ?, email = ?, phone = ?, website_url = ?, address_line1 = ?,
              country_id = ?, city_id = ?, status = 'pending', verification_status = 'pending'
        WHERE id = ?`,
      [...values, previous],
      connection
    );
    await execute("DELETE FROM organization_licenses WHERE organization_id = ?", [previous], connection);
  } else {
    const result = await execute(
      `INSERT INTO organizations
         (public_id, account_id, kind, name, legal_name, slug, description, email, phone, website_url, address_line1,
          country_id, city_id, status, verification_status, is_publicly_visible, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending', 0, NOW(3))`,
      [ulid(), accountId, values[0], values[1], values[2], `${slugify(name) || "company"}-${accountId}`, ...values.slice(3)],
      connection
    );
    organizationId = result.insertId;
  }
  await execute(
    `INSERT INTO organization_licenses (organization_id, license_type, license_number, country_id, status, created_at)
     VALUES (?, 'trade_license', ?, ?, 'pending', NOW(3))`,
    [organizationId, input.registrationNumber, place.countryId],
    connection
  );
  await requestCategory(accountId, rootId, userId, connection);
  return createVerificationRequest(
    { subjectType: "organization", subjectId: organizationId, userId, payload: { application: "organization", accountType: "organization", categoryId: input.categoryId, fromType } },
    connection
  );
}

export async function submitApplication(req, input) {
  const accountId = req.auth.activeAccountId;
  const userId = req.auth.user.id;
  const fromType = req.auth.activeMembership?.account_type_code;
  const canApply = fromType === "personal" || (fromType === "lister" && input.accountType === "organization");
  if (!canApply) throw AppError.conflict("This account is already a seller account.");
  if (!req.auth.user.emailVerifiedAt) {
    throw new AppError("Confirm your email address before applying.", { status: 403, code: "EMAIL_NOT_VERIFIED" });
  }
  const open = await latestApplication(accountId, { organizationOnly: fromType === "lister" });
  if (open && OPEN.includes(open.status)) throw AppError.conflict("Your application is already being reviewed.");
  requireDocuments(input);
  const definition = resolveCategory(input.categoryId);
  if (!definition) throw AppError.validation("Some information is invalid.", { categoryId: "Choose a marketplace category." });
  const place = await location(input.countryId, input.cityId);
  const phone = splitPhone(input.phone);
  const phoneOwner = await queryValue(
    "SELECT id FROM users WHERE phone_country_code = ? AND phone_number = ? AND id <> ? LIMIT 1",
    [phone.countryCode, phone.number, userId]
  );
  if (phoneOwner) {
    throw AppError.conflict("An account with that phone number already exists.", { phone: "An account with that phone number already exists." });
  }
  if (input.accountType === "organization") await assertRegistrationAvailable(input.registrationNumber, accountId);

  const context = { userId, accountId, rootId: definition.rootId, listingType: definition.listingType, fromType };
  const verificationRequestId = await withTransaction(async (connection) => {
    await execute(
      "UPDATE users SET phone_country_code = ?, phone_number = ?, country_id = ?, city_id = ? WHERE id = ?",
      [phone.countryCode, phone.number, place.countryId, place.cityId, userId],
      connection
    );
    return input.accountType === "organization"
      ? saveOrganization(input, context, place, connection)
      : savePersonal(input, context, place, connection);
  });
  await attachUploadedDocuments({ verificationRequestId, userId, accountId, documents: input.documents });
  return { status: "pending" };
}

