import { z } from "zod";
import { query, queryOne, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { isoDate, int, num, bool } from "../../serializers/primitives.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { AppError } from "../../utils/errors.js";
import { getAssetByPublicId } from "../media/media.service.js";
import { splitPhone } from "../../utils/phone.js";

export const profileUpdateSchema = z.object({
  firstName: z.string().trim().min(1).max(120).optional(),
  lastName: z.string().trim().min(1).max(120).optional(),
  displayName: z.string().trim().min(1).max(200).optional(),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  jobTitle: z.string().trim().max(120).optional().or(z.literal("")),
  bio: z.string().trim().max(8000).optional().or(z.literal("")),
  country: z.string().trim().max(120).optional().or(z.literal("")),
  city: z.string().trim().max(120).optional().or(z.literal("")),
  licenseNumber: z.string().trim().max(120).optional().or(z.literal("")),
  yearsExperience: z.coerce.number().int().min(0).max(80).optional(),
  languages: z.array(z.string().max(60)).max(20).optional(),
  serviceAreas: z.array(z.union([z.string().max(120), z.number()])).max(30).optional(),
  specialties: z.array(z.string().max(60)).max(20).optional(),
  avatarAssetId: z.string().max(40).optional().nullable(),
  timezone: z.string().trim().max(64).optional(),
  // Email is deliberately absent: changing it goes through a verified flow.
});

/**
 * The portal profile joins the user record with their agent profile when they
 * have one. Both are updated together so the public page and the account never
 * disagree about a name or a phone number.
 */
export async function getProfile(req) {
  const userId = req.auth.user.id;
  const user = await queryOne(
    `SELECT u.id, u.public_id, u.first_name, u.last_name, u.display_name, u.email, u.phone_e164,
            u.avatar_url, u.timezone, u.created_at, u.updated_at, u.email_verified_at,
            co.name AS country_name, ct.name AS city_name
       FROM users u
       LEFT JOIN locations co ON co.id = u.country_id
       LEFT JOIN locations ct ON ct.id = u.city_id
      WHERE u.id = ?`,
    [userId]
  );
  if (!user) throw AppError.notFound();

  const agent = await queryOne(
    `SELECT a.*, o.name AS organization_name, o.slug AS organization_slug
       FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id
      WHERE a.user_id = ? AND a.deleted_at IS NULL LIMIT 1`,
    [userId]
  );

  const [languages, specialties, serviceAreas, reviewSummary] = agent
    ? await Promise.all([
        query(
          `SELECT lang.name FROM agent_languages al JOIN languages lang ON lang.id = al.language_id WHERE al.agent_id = ?`,
          [agent.id]
        ),
        query(
          `SELECT c.name FROM agent_specialties asp JOIN categories c ON c.id = asp.category_id WHERE asp.agent_id = ?`,
          [agent.id]
        ),
        query(
          `SELECT l.name FROM agent_service_areas asa JOIN locations l ON l.id = asa.location_id WHERE asa.agent_id = ? ORDER BY asa.is_primary DESC`,
          [agent.id]
        ),
        queryOne(
          `SELECT COUNT(*) AS review_count, AVG(rating) AS rating_avg
             FROM reviews WHERE subject_type = 'agent' AND subject_id = ? AND status = 'published'`,
          [agent.id]
        ),
      ])
    : [[], [], [], null];

  const profile = {
    id: user.public_id,
    firstName: user.first_name,
    lastName: user.last_name,
    displayName: user.display_name,
    email: user.email,
    emailVerified: Boolean(user.email_verified_at),
    phone: user.phone_e164 || agent?.phone || "",
    jobTitle: agent?.title || "",
    company: agent?.organization_name || "",
    country: user.country_name || "",
    city: user.city_name || "",
    timezone: user.timezone || null,
    languages: languages.map((row) => row.name).join(", "),
    languageList: languages.map((row) => row.name),
    avatar: user.avatar_url || agent?.photo_url || null,
    bio: agent?.bio || "",
    licenseNumber: agent?.license_number || "",
    yearsExperience: agent?.experience_years ? `${agent.experience_years}+ Years` : "",
    yearsExperienceValue: int(agent?.experience_years),
    serviceAreas: serviceAreas.map((row) => row.name),
    specialties: specialties.map((row) => row.name),
    agentId: agent?.public_id || null,
    hasPublicProfile: Boolean(agent),
    publicProfile: {
      bannerImage: null,
      location: [user.city_name, user.country_name].filter(Boolean).join(", "),
      rating: reviewSummary?.rating_avg ? Number(Number(reviewSummary.rating_avg).toFixed(1)) : null,
      reviewCount: int(reviewSummary?.review_count) ?? 0,
      url: agent?.slug ? `/agents/${agent.slug}` : null,
      enabled: bool(agent?.is_publicly_visible),
    },
    createdAt: isoDate(user.created_at),
    updatedAt: isoDate(user.updated_at),
  };

  profile.profileCompletion = completionFor(profile, agent);
  return profile;
}

function completionFor(profile, agent) {
  const items = [
    { id: "photo", label: "Profile photo", complete: Boolean(profile.avatar) },
    { id: "contact", label: "Contact information", complete: Boolean(profile.phone && profile.email) },
    { id: "bio", label: "Bio", complete: Boolean(profile.bio && profile.bio.length > 40) },
    { id: "areas", label: "Service areas", complete: profile.serviceAreas.length > 0 },
    { id: "verification", label: "Identity verification", complete: agent?.verification_status === "verified" },
  ];
  const complete = items.filter((item) => item.complete).length;
  return { percentage: Math.round((complete / items.length) * 100), items };
}

export async function updateProfile(req, payload) {
  const userId = req.auth.user.id;

  await withTransaction(async (connection) => {
    const userAssignments = [];
    const userParams = [];
    const setUser = (column, value) => {
      userAssignments.push(`${column} = ?`);
      userParams.push(value);
    };

    if (payload.firstName !== undefined) setUser("first_name", payload.firstName);
    if (payload.lastName !== undefined) setUser("last_name", payload.lastName);
    if (payload.displayName !== undefined) setUser("display_name", payload.displayName);
    if (payload.phone !== undefined) {
      // phone_e164 is generated; write the parts.
      const phone = splitPhone(payload.phone);
      setUser("phone_country_code", phone.countryCode);
      setUser("phone_number", phone.number);
    }
    if (payload.timezone !== undefined) setUser("timezone", payload.timezone);

    if (payload.country !== undefined) {
      const country = payload.country ? await resolveLocation(payload.country, { type: "country" }) : null;
      setUser("country_id", country?.id ?? null);
    }
    if (payload.city !== undefined) {
      const city = payload.city ? await resolveLocation(payload.city, { type: "city" }) : null;
      setUser("city_id", city?.id ?? null);
    }
    if (payload.avatarAssetId !== undefined) {
      if (payload.avatarAssetId === null) setUser("avatar_url", null);
      else {
        const asset = await getAssetByPublicId(payload.avatarAssetId);
        if (!asset) throw AppError.validation("Some information is invalid.", { avatarAssetId: "That image was not found." });
        // The asset must belong to this account; a public id from elsewhere is
        // not a licence to use the file.
        if (asset.account_id && String(asset.account_id) !== String(req.auth.activeAccountId)) {
          throw AppError.forbidden("That image belongs to another account.");
        }
        setUser("avatar_url", asset.url);
      }
    }

    if (userAssignments.length) {
      await execute(`UPDATE users SET ${userAssignments.join(", ")} WHERE id = ?`, [...userParams, userId], connection);
    }

    const agent = await queryOne("SELECT id FROM agents WHERE user_id = ? AND deleted_at IS NULL LIMIT 1", [userId], connection);
    if (!agent) return;

    const agentAssignments = [];
    const agentParams = [];
    const setAgent = (column, value) => {
      agentAssignments.push(`${column} = ?`);
      agentParams.push(value);
    };
    if (payload.firstName !== undefined) setAgent("first_name", payload.firstName);
    if (payload.lastName !== undefined) setAgent("last_name", payload.lastName);
    if (payload.displayName !== undefined) setAgent("display_name", payload.displayName);
    if (payload.phone !== undefined) setAgent("phone", payload.phone || null);
    if (payload.jobTitle !== undefined) setAgent("title", payload.jobTitle || null);
    if (payload.bio !== undefined) setAgent("bio", payload.bio || null);
    if (payload.licenseNumber !== undefined) setAgent("license_number", payload.licenseNumber || null);
    if (payload.yearsExperience !== undefined) setAgent("experience_years", payload.yearsExperience);
    if (payload.avatarAssetId !== undefined && payload.avatarAssetId) {
      const asset = await getAssetByPublicId(payload.avatarAssetId);
      if (asset) setAgent("photo_url", asset.url);
    }
    if (agentAssignments.length) {
      await execute(`UPDATE agents SET ${agentAssignments.join(", ")} WHERE id = ?`, [...agentParams, agent.id], connection);
    }

    if (payload.languages) {
      await execute("DELETE FROM agent_languages WHERE agent_id = ?", [agent.id], connection);
      for (const name of payload.languages) {
        const language = await queryOne("SELECT id FROM languages WHERE name = ? OR code = ? LIMIT 1", [name, name], connection);
        if (language) {
          await execute(
            "INSERT IGNORE INTO agent_languages (agent_id, language_id, proficiency) VALUES (?, ?, 'fluent')",
            [agent.id, language.id],
            connection
          );
        }
      }
    }
    if (payload.serviceAreas) {
      await execute("DELETE FROM agent_service_areas WHERE agent_id = ?", [agent.id], connection);
      for (const [index, area] of payload.serviceAreas.entries()) {
        const location = await resolveLocation(area);
        if (location) {
          await execute(
            "INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES (?, ?, ?)",
            [agent.id, location.id, index === 0 ? 1 : 0],
            connection
          );
        }
      }
    }
    if (payload.specialties) {
      await execute("DELETE FROM agent_specialties WHERE agent_id = ?", [agent.id], connection);
      for (const [index, name] of payload.specialties.entries()) {
        const category = await queryOne(
          "SELECT id FROM categories WHERE name = ? OR slug = ? OR code = ? LIMIT 1",
          [name, name, name],
          connection
        );
        if (category) {
          await execute(
            "INSERT IGNORE INTO agent_specialties (agent_id, category_id, is_primary) VALUES (?, ?, ?)",
            [agent.id, category.id, index === 0 ? 1 : 0],
            connection
          );
        }
      }
    }
  });

  return getProfile(req);
}
