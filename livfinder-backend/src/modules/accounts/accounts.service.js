import { queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";
import { hashPassword, passwordPolicyError } from "../auth/passwords.js";
import { createSession } from "../auth/sessions.js";
import { recordAudit } from "../system/audit.service.js";
import { resolveCategory } from "../../utils/categories.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { sendMail } from "../system/mail.service.js";
import env from "../../config/env.js";
import { issueToken, normalizeEmail } from "../auth/auth.service.js";
import { splitPhone } from "../../utils/phone.js";

async function assertEmailAvailable(email, executor) {
  const existing = await queryValue(
    "SELECT id FROM users WHERE email_normalized = ? LIMIT 1",
    [normalizeEmail(email)],
    executor
  );
  if (existing) {
    throw AppError.conflict("An account with that email already exists.", {
      email: "An account with that email already exists.",
    });
  }
}

async function uniqueSlug(table, base, executor) {
  const root = slugify(base) || `account-${Date.now()}`;
  for (let attempt = 0; attempt < 25; attempt += 1) {
    const candidate = attempt === 0 ? root : `${root}-${attempt + 1}`;
    const taken = await queryValue(
      `SELECT id FROM ${table} WHERE slug = ? LIMIT 1`,
      [candidate],
      executor
    );
    if (!taken) return candidate;
  }
  return `${root}-${Date.now()}`;
}

async function accountTypeId(code, executor) {
  const id = await queryValue(
    "SELECT id FROM account_types WHERE code = ? LIMIT 1",
    [code],
    executor
  );
  if (!id) throw AppError.internal(`account type ${code} is missing`);
  return id;
}

async function resolveSignupLocation(countryName, cityName, executor) {
  const country = countryName
    ? await resolveLocation(slugify(countryName), { type: "country" })
    : null;
  let city = null;
  if (cityName) {
    city = await resolveLocation(slugify(cityName), { type: "city" });
    // A city that does not sit under the stated country is not accepted; the
    // relationship is verified server-side rather than trusted from the form.
    if (city && country && String(city.country_id) !== String(country.id))
      city = null;
  }
  return { countryId: country?.id ?? null, cityId: city?.id ?? null };
}

/**
 * Personal signup.
 *
 * Creates the user, a personal account and the owner membership in one
 * transaction: a half-completed signup that leaves a user with no account is
 * exactly the orphan this guards against.
 */
export async function signupPersonal(input, { ip, userAgent } = {}) {
  const policyError = passwordPolicyError(input.password, {
    email: input.email,
  });
  if (policyError)
    throw AppError.validation("Some information is invalid.", {
      password: policyError,
    });

  await assertEmailAvailable(input.email);

  const result = await withTransaction(async (connection) => {
    await assertEmailAvailable(input.email, connection);
    const { countryId, cityId } = await resolveSignupLocation(
      input.country,
      input.city,
      connection
    );
    const passwordHash = await hashPassword(input.password);
    const phone = splitPhone(input.phone);
    const displayName =
      input.displayName?.trim() ||
      `${input.firstName} ${input.lastName}`.trim();

    const userResult = await execute(
      `INSERT INTO users
         (public_id, email, email_normalized, phone_country_code, phone_number, password_hash,
          password_updated_at, status, first_name, last_name, display_name, country_id, city_id,
          marketing_opt_in, terms_accepted_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW(3), 'pending_verification', ?, ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
      [
        ulid(),
        input.email,
        normalizeEmail(input.email),
        phone.countryCode,
        phone.number,
        passwordHash,
        input.firstName,
        input.lastName,
        displayName,
        countryId,
        cityId,
        input.marketingOptIn ? 1 : 0,
      ],
      connection
    );
    const userId = userResult.insertId;

    // A personal profile that intends to list is a "lister"; a plain personal
    // account cannot list at all (account_types.can_list = 0).
    const typeCode = input.intendsToList === false ? "personal" : "lister";
    const accountResult = await execute(
      `INSERT INTO accounts
         (public_id, account_type_id, owner_user_id, name, slug, status, verification_status,
          listing_quota, listing_used, billing_email, country_id, created_at)
       VALUES (?, ?, ?, ?, ?, 'active', 'unverified',
               (SELECT default_listing_quota FROM account_types WHERE code = ?), 0, ?, ?, NOW(3))`,
      [
        ulid(),
        await accountTypeId(typeCode, connection),
        userId,
        displayName,
        await uniqueSlug("accounts", displayName, connection),
        typeCode,
        input.email,
        countryId,
      ],
      connection
    );
    const accountId = accountResult.insertId;

    await execute(
      `INSERT INTO account_members
         (account_id, user_id, role, status, title, can_manage_organization, can_manage_members,
          can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations,
          can_manage_billing, joined_at, created_at)
       VALUES (?, ?, 'owner', 'active', ?, 1, 1, 1, 1, 1, 1, 1, NOW(3), NOW(3))`,
      [accountId, userId, input.title || null],
      connection
    );

    // A lister can list real estate from day one — the grant every personal
    // lister used to get implicitly, now a real row an admin can also revoke or
    // add to. A plain personal account gets nothing until an admin grants it.
    if (typeCode === "lister") {
      await execute(
        `INSERT INTO account_category_access
           (account_id, category_id, status, listing_used, requested_at, reviewed_at, created_at)
         VALUES (?, 1, 'approved', 0, NOW(3), NOW(3), NOW(3))`,
        [accountId],
        connection
      );
    }

    await execute(
      "UPDATE users SET default_account_id = ? WHERE id = ?",
      [accountId, userId],
      connection
    );

    // A personal professional profile becomes a public agent record only once
    // they ask for one; created here as a draft so the portal has something to
    // edit, and invisible until verified.
    let agentId = null;
    if (input.displayName || input.bio || input.license) {
      const agentResult = await execute(
        `INSERT INTO agents
           (public_id, user_id, organization_id, first_name, last_name, display_name, slug,
            title, bio, email, phone, license_number, country_id, city_id,
            status, verification_status, is_publicly_visible, created_at)
         VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending', 0, NOW(3))`,
        [
          ulid(),
          userId,
          input.firstName,
          input.lastName,
          displayName,
          await uniqueSlug("agents", displayName, connection),
          input.title || "Independent Advisor",
          input.bio || null,
          input.email,
          input.phone || null,
          input.license || null,
          countryId,
          cityId,
        ],
        connection
      );
      agentId = agentResult.insertId;
    }

    const verificationId = await createVerificationRequest(
      {
        subjectType: "account",
        subjectId: accountId,
        userId,
        payload: { accountType: "personal", categoryId: input.categoryId },
      },
      connection
    );

    await recordAudit(
      {
        action: "account.signup_personal",
        subjectType: "account",
        subjectId: accountId,
        subjectLabel: displayName,
        userId,
        metadata: { accountType: typeCode },
        ip,
      },
      connection
    );

    const user = await queryOne(
      "SELECT session_epoch FROM users WHERE id = ?",
      [userId],
      connection
    );
    const session = await createSession(
      {
        userId,
        sessionEpoch: user.session_epoch,
        activeAccountId: accountId,
        ip,
        userAgent,
      },
      connection
    );

    return { userId, accountId, agentId, verificationId, session };
  });

  await sendVerificationEmail(result.userId, input.email, ip);
  return result;
}

/**
 * Organization signup: user + account + owner membership + organization +
 * category access request + verification request, all or nothing.
 */
export async function signupOrganization(input, { ip, userAgent } = {}) {
  const policyError = passwordPolicyError(input.password, {
    email: input.email,
  });
  if (policyError)
    throw AppError.validation("Some information is invalid.", {
      password: policyError,
    });

  await assertEmailAvailable(input.email);

  const definition = resolveCategory(input.categoryId);
  if (!definition) {
    throw AppError.validation("Some information is invalid.", {
      categoryId: "Choose a marketplace category.",
    });
  }

  const result = await withTransaction(async (connection) => {
    await assertEmailAvailable(input.email, connection);
    const { countryId, cityId } = await resolveSignupLocation(
      input.country,
      input.city,
      connection
    );
    const passwordHash = await hashPassword(input.password);
    const phone = splitPhone(input.phone);
    const ownerName = `${input.firstName} ${input.lastName}`.trim();

    const userResult = await execute(
      `INSERT INTO users
         (public_id, email, email_normalized, phone_country_code, phone_number, password_hash,
          password_updated_at, status, first_name, last_name, display_name, country_id, city_id,
          marketing_opt_in, terms_accepted_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, NOW(3), 'pending_verification', ?, ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
      [
        ulid(),
        input.email,
        normalizeEmail(input.email),
        phone.countryCode,
        phone.number,
        passwordHash,
        input.firstName,
        input.lastName,
        ownerName,
        countryId,
        cityId,
        input.marketingOptIn ? 1 : 0,
      ],
      connection
    );
    const userId = userResult.insertId;

    const accountResult = await execute(
      `INSERT INTO accounts
         (public_id, account_type_id, owner_user_id, name, slug, status, verification_status,
          listing_quota, listing_used, billing_email, country_id, created_at)
       VALUES (?, ?, ?, ?, ?, 'pending', 'pending',
               (SELECT default_listing_quota FROM account_types WHERE code = 'company'), 0, ?, ?, NOW(3))`,
      [
        ulid(),
        await accountTypeId("company", connection),
        userId,
        input.publicName || input.legalName,
        await uniqueSlug(
          "accounts",
          input.publicName || input.legalName,
          connection
        ),
        input.organizationEmail || input.email,
        countryId,
      ],
      connection
    );
    const accountId = accountResult.insertId;

    await execute(
      `INSERT INTO account_members
         (account_id, user_id, role, status, title, can_manage_organization, can_manage_members,
          can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations,
          can_manage_billing, joined_at, created_at)
       VALUES (?, ?, 'owner', 'active', 'Owner', 1, 1, 1, 1, 1, 1, 1, NOW(3), NOW(3))`,
      [accountId, userId],
      connection
    );
    await execute(
      "UPDATE users SET default_account_id = ? WHERE id = ?",
      [accountId, userId],
      connection
    );

    const organizationResult = await execute(
      `INSERT INTO organizations
         (public_id, account_id, kind, name, legal_name, slug, tagline, description,
          email, phone, website_url, address_line1, country_id, city_id,
          status, verification_status, is_publicly_visible, created_at)
       VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, 'pending', 'pending', 0, NOW(3))`,
      [
        ulid(),
        accountId,
        organizationKindFor(input.organizationType, definition.listingType),
        input.publicName || input.legalName,
        input.legalName,
        await uniqueSlug(
          "organizations",
          input.publicName || input.legalName,
          connection
        ),
        input.description || null,
        input.organizationEmail || input.email,
        input.organizationPhone || input.phone || null,
        input.website || null,
        input.address || null,
        countryId,
        cityId,
      ],
      connection
    );
    const organizationId = organizationResult.insertId;

    if (input.registrationNumber) {
      await execute(
        `INSERT INTO organization_licenses
           (organization_id, license_type, license_number, issuing_authority, country_id, status, created_at)
         VALUES (?, 'trade_license', ?, ?, ?, 'pending', NOW(3))`,
        [
          organizationId,
          input.registrationNumber,
          input.issuingAuthority || null,
          countryId,
        ],
        connection
      );
    }

    // Category access starts as a request; approval is an admin action.
    await execute(
      `INSERT INTO account_category_access
         (account_id, category_id, status, listing_quota, listing_used, requested_at,
          requested_by_user_id, created_at)
       VALUES (?, ?, 'requested', NULL, 0, NOW(3), ?, NOW(3))`,
      [accountId, definition.rootId, userId],
      connection
    );

    const verificationId = await createVerificationRequest(
      {
        subjectType: "organization",
        subjectId: organizationId,
        userId,
        payload: {
          accountType: "organization",
          categoryId: definition.frontendId,
          legalName: input.legalName,
        },
      },
      connection
    );

    await recordAudit(
      {
        action: "account.signup_organization",
        subjectType: "organization",
        subjectId: organizationId,
        subjectLabel: input.legalName,
        userId,
        ip,
      },
      connection
    );

    const user = await queryOne(
      "SELECT session_epoch FROM users WHERE id = ?",
      [userId],
      connection
    );
    const session = await createSession(
      {
        userId,
        sessionEpoch: user.session_epoch,
        activeAccountId: accountId,
        ip,
        userAgent,
      },
      connection
    );

    return { userId, accountId, organizationId, verificationId, session };
  });

  await sendVerificationEmail(result.userId, input.email, ip);
  return result;
}

function organizationKindFor(organizationType, listingType) {
  const declared = String(organizationType || "")
    .toLowerCase()
    .replace(/[^a-z]/g, "_");
  const allowed = new Set([
    "agency",
    "brokerage",
    "dealership",
    "developer",
    "yacht_broker",
    "aviation_broker",
    "watch_dealer",
    "marketing_partner",
    "service_partner",
    "media_partner",
  ]);
  if (allowed.has(declared)) return declared;
  return (
    {
      "real-estate": "agency",
      cars: "dealership",
      yachts: "yacht_broker",
      jets: "aviation_broker",
      helicopters: "aviation_broker",
      watches: "watch_dealer",
    }[listingType] || "agency"
  );
}

async function sendVerificationEmail(userId, email, ip) {
  const token = await issueToken({
    userId,
    purpose: "email_verification",
    target: email,
    ip,
  });
  await sendMail({
    to: email,
    subject: "Confirm your LivFinder email address",
    text: `Welcome to LivFinder. Confirm your address to activate your account:\n\n${
      env.FRONTEND_URL
    }/verify-email?token=${encodeURIComponent(token)}`,
  });
}

export async function createVerificationRequest(
  { subjectType, subjectId, userId, payload, priority = "normal" },
  executor
) {
  const result = await execute(
    `INSERT INTO verification_requests
       (public_id, subject_type, subject_id, requested_by_user_id, status, priority,
        submitted_at, payload, created_at)
     VALUES (?, ?, ?, ?, 'pending', ?, NOW(3), CAST(? AS JSON), NOW(3))`,
    [
      ulid(),
      subjectType,
      subjectId,
      userId,
      priority,
      JSON.stringify(payload || {}),
    ],
    executor
  );
  return result.insertId;
}

export async function attachVerificationDocument(
  {
    verificationRequestId,
    documentType,
    fileUrl,
    fileName,
    mimeType,
    fileSizeBytes,
  },
  executor
) {
  await execute(
    `INSERT INTO verification_documents
       (verification_request_id, document_type, file_url, file_name, mime_type,
        file_size_bytes, status, uploaded_at)
     VALUES (?, ?, ?, ?, ?, ?, 'pending', NOW(3))`,
    [
      verificationRequestId,
      documentType,
      fileUrl,
      fileName,
      mimeType,
      fileSizeBytes,
    ],
    executor
  );
}

export async function latestVerificationRequest({ subjectType, subjectId }) {
  return queryOne(
    `SELECT * FROM verification_requests
      WHERE subject_type = ? AND subject_id = ?
      ORDER BY id DESC LIMIT 1`,
    [subjectType, subjectId]
  );
}
