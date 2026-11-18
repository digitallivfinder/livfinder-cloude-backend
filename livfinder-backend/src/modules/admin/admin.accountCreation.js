import { z } from "zod";
import { queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { randomToken } from "../../utils/ids.js";
import { optionalPhone } from "../../utils/phone.js";
import { resolveCategory } from "../../utils/categories.js";
import { signupOrganization, signupPersonal } from "../accounts/accounts.service.js";
import { ORGANIZATION_KINDS } from "../accounts/organizationKinds.js";
import { sendAccountSetupEmail } from "../auth/auth.service.js";
import { decideCategoryAccess, decideVerification } from "./admin.mutations.js";

/**
 * Admin "Add Company" and "Add Individual".
 *
 * Both drawers used to add a row to the table in the browser only; nothing was stored and the
 * record was gone on reload. They now create the account the way signup does — the same user,
 * account, organisation, agent, category request and verification request, through the same
 * service functions — and then approve it at once, because staff created it. The owner gets one
 * email: a link to choose a password (sendAccountSetupEmail). Signup's own "confirm your email"
 * and "application received" emails, and the approval emails, are not sent.
 *
 * Not one transaction: signup commits first, then approval and the extra categories run. If a
 * later step fails, the account is left as an ordinary pending application that staff can
 * approve from its page, and the error is returned.
 */

const requiredPhone = optionalPhone.refine((value) => Boolean(value), "Enter a phone number.");
const blank = z.literal("");
const categoryList = z.array(z.string().trim().min(1).max(60)).max(10).optional();

export const adminCompanyCreateSchema = z.object({
  name: z.string().trim().min(2, "Enter the business name.").max(200),
  legalName: z.string().trim().max(255).optional().or(blank),
  organizationType: z.enum(ORGANIZATION_KINDS, { message: "Choose the business type." }),
  registrationNumber: z.string().trim().max(120).optional().or(blank),
  website: z.string().trim().max(500).optional().or(blank),
  description: z.string().trim().max(12000).optional().or(blank),
  contactName: z.string().trim().min(2, "Enter the primary contact's name.").max(240),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  phone: requiredPhone,
  countryId: z.coerce.string().trim().min(1, "Choose a country."),
  cityId: z.coerce.string().trim().optional().or(blank),
  address: z.string().trim().max(500).optional().or(blank),
  categoryId: z.string().trim().min(1, "Choose the primary category.").max(60),
  categoryIds: categoryList,
  sendSetupEmail: z.boolean().optional(),
});

export const adminIndividualCreateSchema = z.object({
  firstName: z.string().trim().min(1, "Enter the first name.").max(120),
  lastName: z.string().trim().min(1, "Enter the last name.").max(120),
  displayName: z.string().trim().max(200).optional().or(blank),
  profession: z.string().trim().max(120).optional().or(blank),
  bio: z.string().trim().max(12000).optional().or(blank),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  phone: requiredPhone,
  countryId: z.coerce.string().trim().min(1, "Choose a country."),
  cityId: z.coerce.string().trim().optional().or(blank),
  categoryId: z.string().trim().min(1, "Choose the primary category.").max(60),
  categoryIds: categoryList,
  sendSetupEmail: z.boolean().optional(),
});

/** A password nobody knows; the owner chooses their own from the set-up email. */
const unusablePassword = () => `${randomToken(24)}a1`;

const orEmpty = (value) => (value ? value : undefined);

async function adminName(userId) {
  return (await queryOne("SELECT display_name FROM users WHERE id = ?", [userId]))?.display_name ?? null;
}

/** The categories beyond the primary one, each approved like the Categories & Access tab does. */
async function grantExtraCategories({ accountId, primary, categoryIds = [], userId }) {
  const primaryRoot = resolveCategory(primary)?.rootId;
  const seen = new Set([primaryRoot]);
  for (const categoryId of categoryIds) {
    const definition = resolveCategory(categoryId);
    if (!definition) throw AppError.validation("Some information is invalid.", { categoryIds: `Unknown category: ${categoryId}.` });
    if (seen.has(definition.rootId)) continue;
    seen.add(definition.rootId);
    await decideCategoryAccess({ accountId, categoryId: definition.rootId, decision: "approve", userId, silent: true });
  }
}

export async function createCompanyByAdmin({ payload, userId, ip }) {
  if (!resolveCategory(payload.categoryId)) {
    throw AppError.validation("Some information is invalid.", { categoryId: "Choose a marketplace category." });
  }
  const [firstName, ...rest] = payload.contactName.split(/\s+/);
  const created = await signupOrganization(
    {
      email: payload.email,
      password: unusablePassword(),
      firstName,
      lastName: rest.join(" "),
      phone: payload.phone,
      legalName: payload.legalName || payload.name,
      publicName: payload.name,
      organizationType: payload.organizationType,
      categoryId: payload.categoryId,
      registrationNumber: orEmpty(payload.registrationNumber),
      website: orEmpty(payload.website),
      organizationEmail: payload.email,
      organizationPhone: payload.phone,
      address: orEmpty(payload.address),
      description: orEmpty(payload.description),
      countryId: payload.countryId,
      cityId: orEmpty(payload.cityId),
    },
    { ip, createdByAdmin: true }
  );
  const organization = await queryOne("SELECT public_id FROM organizations WHERE id = ?", [created.organizationId]);

  await decideVerification({ subjectType: "organization", identifier: organization.public_id, decision: "approve", userId, silent: true });
  await grantExtraCategories({ accountId: created.accountId, primary: payload.categoryId, categoryIds: payload.categoryIds, userId });
  if (payload.sendSetupEmail !== false) {
    await sendAccountSetupEmail({ userId: created.userId, companyName: payload.name, invitedBy: await adminName(userId), ip });
  }
  return { id: organization.public_id, setupEmailSent: payload.sendSetupEmail !== false };
}

export async function createIndividualByAdmin({ payload, userId, ip }) {
  const definition = resolveCategory(payload.categoryId);
  if (!definition) throw AppError.validation("Some information is invalid.", { categoryId: "Choose a marketplace category." });
  const created = await signupPersonal(
    {
      email: payload.email,
      password: unusablePassword(),
      firstName: payload.firstName,
      lastName: payload.lastName,
      displayName: payload.displayName || `${payload.firstName} ${payload.lastName}`.trim(),
      title: orEmpty(payload.profession),
      bio: orEmpty(payload.bio),
      phone: payload.phone,
      countryId: payload.countryId,
      cityId: orEmpty(payload.cityId),
      categoryId: payload.categoryId,
      intendsToList: true,
    },
    { ip, createdByAdmin: true }
  );
  const account = await queryOne(
    "SELECT a.public_id AS account_id, u.public_id AS user_id FROM accounts a JOIN users u ON u.id = a.owner_user_id WHERE a.id = ?",
    [created.accountId]
  );

  await decideVerification({ subjectType: "account", identifier: account.account_id, decision: "approve", userId, silent: true });
  await grantExtraCategories({ accountId: created.accountId, primary: payload.categoryId, categoryIds: payload.categoryIds, userId });
  if (payload.sendSetupEmail !== false) {
    await sendAccountSetupEmail({ userId: created.userId, invitedBy: await adminName(userId), ip });
  }
  // The admin Individuals screens address a person by their user id.
  return { id: account.user_id, setupEmailSent: payload.sendSetupEmail !== false };
}
