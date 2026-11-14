import { createMemberAccount } from "./memberAccount.js";
import logger from "../../config/logger.js";
import { sanitizeDescription } from "../../utils/richText.js";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
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
import { notifyPlanChanged } from "../system/notifications.service.js";
import { syncAccountAddons } from "./addons.service.js";
import env from "../../config/env.js";
import { issueToken, normalizeEmail } from "../auth/auth.service.js";
import { splitPhone } from "../../utils/phone.js";
import { isoDay } from "../../serializers/primitives.js";
import { assertApplicationCategory } from "./sellerType.js";

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

async function resolveSignupLocation({ country, countryId, city, cityId }) {
  // An id is what the form's pickers send. A name is only for callers without one: city
  // names repeat across the world, so a slug lookup can land in the wrong country.
  const countryRow = countryId
    ? await resolveLocation(countryId)
    : country
      ? await resolveLocation(slugify(country), { type: "country" })
      : null;
  if (countryId && countryRow?.level !== "country") {
    throw AppError.validation("Some information is invalid.", { country: "Choose a country from the list." });
  }
  const cityRow = cityId
    ? await resolveLocation(cityId)
    : city
      ? await resolveLocation(slugify(city), { type: "city" })
      : null;
  // A city that does not sit under the stated country is not accepted; the
  // relationship is verified server-side rather than trusted from the form.
  const mismatched = cityRow && (cityRow.level !== "city" || (countryRow && String(cityRow.country_id) !== String(countryRow.id)));
  if (cityId && (!cityRow || mismatched)) {
    throw AppError.validation("Some information is invalid.", { city: "Choose a city in the selected country." });
  }
  return { countryId: countryRow?.id ?? null, cityId: mismatched ? null : cityRow?.id ?? null };
}

// `users.phone_e164` is unique; without this a repeated number surfaces as a server error.
async function assertPhoneAvailable(phone, executor) {
  const { countryCode, number } = splitPhone(phone);
  if (!countryCode || !number) return;
  const existing = await queryValue(
    "SELECT id FROM users WHERE phone_country_code = ? AND phone_number = ? LIMIT 1",
    [countryCode, number],
    executor
  );
  if (existing) {
    throw AppError.conflict("An account with that phone number already exists.", {
      phone: "An account with that phone number already exists.",
    });
  }
}

/** A company registers once, however many email addresses apply for it. */
export async function assertRegistrationAvailable(registrationNumber, ownAccountId = null) {
  const existing = await queryValue(
    `SELECT l.id FROM organization_licenses l
       JOIN organizations o ON o.id = l.organization_id
      WHERE l.license_number = ? AND (? IS NULL OR o.account_id <> ?) LIMIT 1`,
    [registrationNumber, ownAccountId, ownAccountId]
  );
  if (existing) {
    throw AppError.conflict("This organization is already registered.", {
      registrationNumber: "This organization is already registered.",
    });
  }
}

/**
 * The short signup: a Member, with no review and no confirmation step before first use.
 * The address is confirmed later, when it starts to matter (see claimRecordsByEmail).
 */
export async function signupMember(input, { ip, userAgent } = {}) {
  const policyError = passwordPolicyError(input.password, { email: input.email });
  if (policyError) throw AppError.validation("Some information is invalid.", { password: policyError });
  await assertEmailAvailable(input.email);

  const result = await withTransaction(async (connection) => {
    await assertEmailAvailable(input.email, connection);
    const [firstName, ...rest] = input.name.split(/\s+/);
    const userResult = await execute(
      `INSERT INTO users
         (public_id, email, email_normalized, password_hash, password_updated_at, status, first_name, last_name,
          display_name, terms_accepted_at, created_at)
       VALUES (?, ?, ?, ?, NOW(3), 'active', ?, ?, ?, NOW(3), NOW(3))`,
      [ulid(), input.email, normalizeEmail(input.email), await hashPassword(input.password), firstName, rest.join(" "), input.name],
      connection
    );
    const userId = userResult.insertId;
    const accountId = await createMemberAccount({ userId, displayName: input.name, email: input.email }, connection);
    const user = await queryOne("SELECT session_epoch FROM users WHERE id = ?", [userId], connection);
    const session = await createSession(
      { userId, sessionEpoch: user.session_epoch, activeAccountId: accountId, ip, userAgent },
      connection
    );
    await recordAudit(
      { action: "account.signup_member", subjectType: "account", subjectId: accountId, subjectLabel: input.name, userId, ip },
      connection
    );
    return { userId, session };
  });
  await sendVerificationEmail(result.userId, input.email, ip);
  return result;
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
  await assertPhoneAvailable(input.phone);
  // An individual never lists developments: those come from developer companies (sellerType.js).
  if (input.intendsToList !== false && input.categoryId) assertApplicationCategory({ accountType: "personal", categoryId: input.categoryId });

  const result = await withTransaction(async (connection) => {
    await assertEmailAvailable(input.email, connection);
    await assertPhoneAvailable(input.phone, connection);
    const { countryId, cityId } = await resolveSignupLocation(input);
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
         (public_id, account_type_id, seller_type, owner_user_id, name, slug, status, verification_status,
          listing_quota, listing_used, billing_email, country_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', 'pending',
               (SELECT default_listing_quota FROM account_types WHERE code = ?), 0, ?, ?, NOW(3))`,
      [
        ulid(),
        await accountTypeId(typeCode, connection),
        typeCode === "lister" ? "individual" : null,
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

    // The category they chose is granted when the account is approved (decideVerification).
    const chosen = typeCode === "lister" ? resolveCategory(input.categoryId) ?? resolveCategory("realEstate") : null;
    if (chosen) {
      await execute(
        `INSERT INTO account_category_access
           (account_id, category_id, status, listing_used, requested_at, requested_by_user_id, created_at)
         VALUES (?, ?, 'requested', 0, NOW(3), ?, NOW(3))`,
        [accountId, chosen.rootId, userId],
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
          sanitizeDescription(input.bio) || null,
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
  await assertPhoneAvailable(input.phone);

  const definition = resolveCategory(input.categoryId);
  if (!definition) {
    throw AppError.validation("Some information is invalid.", {
      categoryId: "Choose a marketplace category.",
    });
  }
  const organizationKind = organizationKindFor(input.organizationType, definition.listingType);
  // A Developer lists Real Estate Developments, and only a Developer may (sellerType.js).
  assertApplicationCategory({ accountType: "organization", organizationType: organizationKind, categoryId: definition.frontendId });
  await assertRegistrationAvailable(input.registrationNumber);

  const result = await withTransaction(async (connection) => {
    await assertEmailAvailable(input.email, connection);
    await assertPhoneAvailable(input.phone, connection);
    const { countryId, cityId } = await resolveSignupLocation(input);
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
         (public_id, account_type_id, seller_type, owner_user_id, name, slug, status, verification_status,
          listing_quota, listing_used, billing_email, country_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', 'pending',
               (SELECT default_listing_quota FROM account_types WHERE code = 'company'), 0, ?, ?, NOW(3))`,
      [
        ulid(),
        await accountTypeId("company", connection),
        organizationKind === "developer" ? "developer" : "company",
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
        organizationKind,
        input.publicName || input.legalName,
        input.legalName,
        await uniqueSlug(
          "organizations",
          input.publicName || input.legalName,
          connection
        ),
        sanitizeDescription(input.description) || null,
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

export const ORGANIZATION_KINDS = [
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
];

export function organizationKindFor(organizationType, listingType) {
  const declared = String(organizationType || "")
    .toLowerCase()
    .replace(/[^a-z]/g, "_");
  if (ORGANIZATION_KINDS.includes(declared)) return declared;
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
  // The account is already committed. A mail outage must not report that as a failed signup,
  // or the retry meets "email already exists"; the login screen can send a new link.
  try {
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
  } catch (error) {
    logger.error({ err: error, userId }, "signup confirmation email could not be sent");
  }
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

async function assignablePlan(packageId, { publicOnly = false } = {}) {
  const plan = await queryOne(
    // AED is the platform's base currency (see `currencies.is_base`) — the
    // same price row the package pickers show, so the amount recorded on the
    // subscription matches what was on screen when it was chosen.
    // `publicOnly` (the portal's self-service path) excludes plans like
    // Partner (`is_public = 0`) — never offered as a "Choose Plan" card, so an
    // account should not be able to grant it to itself by calling the API
    // directly with a copied plan id. The admin path has no such restriction.
    `SELECT p.id, p.public_id, p.name, p.listing_quota, p.storage_quota, p.featured_quota, p.billing_interval,
            pp.amount, pp.currency_code
       FROM plans p
       LEFT JOIN plan_prices pp ON pp.plan_id = p.id AND pp.currency_code = 'AED' AND pp.is_active = 1
      WHERE p.public_id = ? AND p.is_active = 1 ${publicOnly ? "AND p.is_public = 1" : ""}`,
    [packageId]
  );
  if (!plan) throw AppError.validation("Some information is invalid.", { packageId: "That package is not available." });
  return plan;
}

/**
 * Moves an account onto a different plan — shared by the admin "Change
 * Package" action and the portal's own self-service "Choose Plan". Both
 * deliberately do not take money: there is no billing provider connected, and
 * a screen that implied a charge had been raised would be worse than one that
 * plainly does not. The plan and its entitlements change; the invoice is a
 * separate concern for when payments exist.
 */
export async function assignPlanToAccount({ accountId, packageId, publicOnly = false }) {
  const plan = await assignablePlan(packageId, { publicOnly });
  const amount = plan.amount ?? 0;
  const currency = plan.currency_code || "AED";

  // The plan lives on `subscriptions`, not on the account: an account can have had several over
  // time and the history is what billing and entitlement questions are answered from. So the
  // current one is switched, or one is opened if the account has never had a plan.
  await withTransaction(async (connection) => {
    const current = await queryOne(
      "SELECT id FROM subscriptions WHERE account_id = ? AND status IN ('active','trialing','past_due') ORDER BY created_at DESC LIMIT 1",
      [accountId],
      connection
    );
    if (current) {
      // A change made now replaces one that was waiting for the renewal date.
      await execute(
        "UPDATE subscription_changes SET status = 'cancelled' WHERE subscription_id = ? AND status = 'scheduled' AND reason = ?",
        [current.id, SCHEDULED_REASON],
        connection
      );
      await execute(
        `UPDATE subscriptions SET plan_id = ?, amount = ?, currency_code = ?, listing_quota = ?, featured_quota = ?, billing_interval = ?, updated_at = NOW(3)
          WHERE id = ?`,
        [plan.id, amount, currency, plan.listing_quota ?? 0, plan.featured_quota ?? 0, plan.billing_interval ?? "monthly", current.id],
        connection
      );
    } else {
      await execute(
        `INSERT INTO subscriptions (public_id, account_id, plan_id, status, amount, currency_code, billing_interval,
                                    current_period_start, current_period_end, listing_quota, listing_used,
                                    featured_quota, featured_used, auto_renew, created_at, updated_at)
         VALUES (?, ?, ?, 'active', ?, ?, ?, NOW(3), DATE_ADD(NOW(3), INTERVAL 1 MONTH), ?, 0, ?, 0, 1, NOW(3), NOW(3))`,
        [ulid(), accountId, plan.id, amount, currency, plan.billing_interval ?? "monthly", plan.listing_quota ?? 0, plan.featured_quota ?? 0],
        connection
      );
    }
    // The account's own quota mirrors the plan so quota checks stay one indexed read
    // (`POST /listings` only ever looks at `accounts.listing_quota`, and treats NULL
    // as its "unlimited" sentinel). `plan.listing_quota` is NULL for a genuinely
    // unlimited plan (Enterprise) and a real number everywhere else, including a
    // literal 0 for Free ("no listing capability") — passed straight through, not
    // coalesced to 0, or "unlimited" would become a hard cap of zero.
    await execute(
      "UPDATE accounts SET listing_quota = ?, storage_quota = ?, featured_quota = ?, updated_at = NOW(3) WHERE id = ?",
      [plan.listing_quota, plan.storage_quota, plan.featured_quota ?? 0, accountId],
      connection
    );
  });

  // Best-effort: `notify`/`notifyAccount` already swallow their own errors, so
  // a notification failure never undoes or masks the plan change above.
  await syncAccountAddons(accountId);
  await notifyPlanChanged({ accountId, planName: plan.name });

  return { packageId: plan.public_id, packageName: plan.name, chargeRaised: false };
}

const LIVE_SUBSCRIPTION = "s.status IN ('active','trialing','past_due')";
const PERIOD_MONTHS = { monthly: 1, quarterly: 3, yearly: 12 };
// Marks a row this flow wrote. Demo data seeds `subscription_changes` with old 'scheduled' rows
// (074_finance_extensions.sql), which must never be read as work to do.
const SCHEDULED_REASON = "Next billing cycle, chosen in Change Package";

/**
 * A plan change that waits for the renewal date. The account keeps its plan and quotas until
 * then. With no renewal date ahead there is nothing to wait for, so the change applies now and
 * the result says so.
 */
export async function schedulePlanChange({ accountId, packageId, userId = null }) {
  const plan = await assignablePlan(packageId);
  const current = await queryOne(
    `SELECT s.id, s.plan_id, s.amount, s.currency_code, s.current_period_end, s.current_period_end > NOW(3) AS period_open
       FROM subscriptions s WHERE s.account_id = ? AND ${LIVE_SUBSCRIPTION} ORDER BY s.created_at DESC LIMIT 1`,
    [accountId]
  );
  if (!current?.period_open) {
    return { ...(await assignPlanToAccount({ accountId, packageId })), scheduled: false };
  }
  if (String(current.plan_id) === String(plan.id)) {
    throw AppError.validation("Some information is invalid.", { packageId: "This account is already on that package." });
  }
  await withTransaction(async (connection) => {
    await execute(
      "UPDATE subscription_changes SET status = 'cancelled' WHERE subscription_id = ? AND status = 'scheduled' AND reason = ?",
      [current.id, SCHEDULED_REASON],
      connection
    );
    await execute(
      `INSERT INTO subscription_changes
         (subscription_id, change_type, from_plan_id, to_plan_id, from_amount, to_amount, currency_code,
          effective_timing, effective_at, proration_behavior, reason, requested_by_user_id, status)
       VALUES (?, 'plan_change', ?, ?, ?, ?, ?, 'period_end', ?, 'none', ?, ?, 'scheduled')`,
      [current.id, current.plan_id, plan.id, current.amount, plan.amount ?? 0, current.currency_code,
        current.current_period_end, SCHEDULED_REASON, userId],
      connection
    );
  });
  return {
    packageId: plan.public_id,
    packageName: plan.name,
    scheduled: true,
    effectiveAt: isoDay(current.current_period_end),
    chargeRaised: false,
  };
}

export async function scheduledPlanChange(accountId) {
  const row = await queryOne(
    `SELECT p.public_id, p.name, c.effective_at
       FROM subscription_changes c
       JOIN subscriptions s ON s.id = c.subscription_id
       JOIN plans p ON p.id = c.to_plan_id
      WHERE s.account_id = ? AND ${LIVE_SUBSCRIPTION} AND c.status = 'scheduled' AND c.reason = ?
      ORDER BY c.id DESC LIMIT 1`,
    [accountId, SCHEDULED_REASON]
  );
  return row ? { packageId: row.public_id, packageName: row.name, effectiveAt: isoDay(row.effective_at) } : null;
}

export async function cancelScheduledPlanChange(accountId) {
  const result = await execute(
    `UPDATE subscription_changes c JOIN subscriptions s ON s.id = c.subscription_id
        SET c.status = 'cancelled' WHERE s.account_id = ? AND c.status = 'scheduled' AND c.reason = ?`,
    [accountId, SCHEDULED_REASON]
  );
  return result.affectedRows > 0;
}

/** Run hourly. The row is claimed first, so two API processes cannot apply the same change. */
export async function applyDuePlanChanges() {
  const due = await query(
    `SELECT c.id, c.subscription_id, s.account_id, p.public_id AS package_id
       FROM subscription_changes c
       JOIN subscriptions s ON s.id = c.subscription_id
       LEFT JOIN plans p ON p.id = c.to_plan_id
      WHERE c.status = 'scheduled' AND c.reason = ? AND c.effective_at <= NOW(3) AND ${LIVE_SUBSCRIPTION}
      ORDER BY c.effective_at LIMIT 100`,
    [SCHEDULED_REASON]
  );
  let applied = 0;
  for (const change of due) {
    const claimed = await execute(
      "UPDATE subscription_changes SET status = 'applied', applied_at = NOW(3) WHERE id = ? AND status = 'scheduled'",
      [change.id]
    );
    if (!claimed.affectedRows) continue;
    try {
      await assignPlanToAccount({ accountId: change.account_id, packageId: change.package_id });
      const { billing_interval: interval } = await queryOne("SELECT billing_interval FROM subscriptions WHERE id = ?", [change.subscription_id]);
      if (PERIOD_MONTHS[interval]) {
        await execute(
          `UPDATE subscriptions
              SET current_period_start = current_period_end,
                  current_period_end = DATE_ADD(current_period_end, INTERVAL ? MONTH)
            WHERE id = ? AND current_period_end <= NOW(3)`,
          [PERIOD_MONTHS[interval], change.subscription_id]
        );
      }
      applied += 1;
    } catch (error) {
      logger.error({ err: error, changeId: change.id }, "a scheduled plan change could not be applied");
      await execute("UPDATE subscription_changes SET status = 'failed', applied_at = NULL WHERE id = ?", [change.id]);
    }
  }
  return applied;
}
