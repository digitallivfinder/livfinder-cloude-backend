import { query, queryOne } from "../../db/query.js";
import { descriptionToText } from "../../utils/richText.js";
import { qualityBand } from "./listingQuality.js";

/**
 * Agent and company quality scores (owner's rule, 2026-11-13):
 *
 *   score = 70% × the average quality score of their live listings
 *         + 30% × how complete their profile is
 *
 * With no live listings the listing part is 0, and the first suggestion says to publish one.
 * Computed on read: both parts come from columns that are already maintained.
 */

export const LISTING_WEIGHT = 0.7;
export const PROFILE_WEIGHT = 0.3;

const has = (value) => value !== null && value !== undefined && String(value).trim() !== "";

/** Profile checks for an agent; points add up to 100. */
export function agentProfileChecks(agent, { languageCount = 0 } = {}) {
  return [
    { key: "photo", label: "Profile photo", points: 20, done: has(agent.photo_url), suggestion: "Add a clear, professional head-and-shoulders photo." },
    { key: "bio", label: "Bio", points: 20, done: descriptionToText(agent.bio || "").trim().length >= 150, suggestion: "Write a bio of at least 150 characters: experience, areas and specialities." },
    { key: "languages", label: "Languages", points: 15, done: languageCount > 0, suggestion: "Add the languages this agent speaks." },
    { key: "licence", label: "Licence number", points: 15, done: has(agent.license_number), suggestion: "Add the agent's licence or broker number (BRN)." },
    { key: "contact", label: "Phone or WhatsApp", points: 15, done: has(agent.phone) || has(agent.whatsapp), suggestion: "Add a phone or WhatsApp number buyers can reach." },
    { key: "verified", label: "Verified agent", points: 15, done: agent.verification_status === "verified", suggestion: "Get the agent verified by LivFinder (identity and licence check)." },
  ];
}

/** Profile checks for a company; points add up to 100. */
export function organizationProfileChecks(org, { licenceCount = 0 } = {}) {
  return [
    { key: "logo", label: "Logo", points: 20, done: has(org.logo_url), suggestion: "Upload the company logo." },
    { key: "about", label: "About the company", points: 20, done: descriptionToText(org.description || "").trim().length >= 200, suggestion: "Write at least 200 characters about the company, its history and services." },
    { key: "contact", label: "Email and phone", points: 15, done: has(org.email) && has(org.phone), suggestion: "Add both a contact email and a phone number." },
    { key: "website", label: "Website", points: 10, done: has(org.website_url), suggestion: "Add the company website." },
    { key: "licence", label: "Trade licence", points: 15, done: licenceCount > 0, suggestion: "Add the company's trade or RERA licence." },
    { key: "verified", label: "Verified company", points: 20, done: org.verification_status === "verified", suggestion: "Get the company verified by LivFinder." },
  ];
}

function combine({ checks, listingAverage, liveListings }) {
  const profile = checks.reduce((sum, check) => sum + (check.done ? check.points : 0), 0);
  const listings = liveListings > 0 ? Math.round(listingAverage) : 0;
  const score = Math.round(LISTING_WEIGHT * listings + PROFILE_WEIGHT * profile);
  const suggestions = [];
  if (liveListings === 0) {
    suggestions.push({ key: "listings.none", message: "No live listings yet.", suggestion: "Publish listings: 70% of this score is their average quality.", gain: Math.round(LISTING_WEIGHT * 100) });
  } else if (listings < 100) {
    suggestions.push({
      key: "listings.average",
      message: `Live listings average ${listings} out of 100.`,
      suggestion: "Raise the score of the weakest listings; each listing's Quality Score tab lists what to fix.",
      gain: Math.round(LISTING_WEIGHT * (100 - listings)),
    });
  }
  for (const check of checks) {
    if (!check.done) suggestions.push({ key: `profile.${check.key}`, message: `${check.label} missing.`, suggestion: check.suggestion, gain: Math.round(PROFILE_WEIGHT * check.points) });
  }
  suggestions.sort((a, b) => b.gain - a.gain);
  return {
    score,
    band: qualityBand(score),
    listingScore: listings,
    liveListings,
    profileScore: profile,
    profileChecks: checks.map(({ key, label, done, points }) => ({ key, label, done, points })),
    suggestions,
  };
}

/** Average live-listing score and count per agent id. */
async function listingAveragesByAgent(agentIds) {
  if (!agentIds.length) return new Map();
  const rows = await query(
    `SELECT agent_id, AVG(quality_score) AS average, COUNT(*) AS live
       FROM listings
      WHERE agent_id IN (${agentIds.map(() => "?").join(", ")}) AND status = 'active' AND deleted_at IS NULL
      GROUP BY agent_id`,
    agentIds
  );
  return new Map(rows.map((row) => [Number(row.agent_id), { average: Number(row.average) || 0, live: Number(row.live) || 0 }]));
}

/**
 * Quality for many agents at once — `Map(agentId → quality)`. Rows must carry the agent columns
 * the profile checks read (`photo_url`, `bio`, `license_number`, `phone`, `whatsapp`,
 * `verification_status`); missing ones are loaded.
 */
export async function agentQualities(agentIds) {
  const ids = [...new Set(agentIds.map(Number).filter(Boolean))];
  if (!ids.length) return new Map();
  const placeholders = ids.map(() => "?").join(", ");
  const [agents, languages, averages] = await Promise.all([
    query(
      `SELECT id, photo_url, bio, license_number, phone, whatsapp, verification_status
         FROM agents WHERE id IN (${placeholders})`,
      ids
    ),
    query(`SELECT agent_id, COUNT(*) AS n FROM agent_languages WHERE agent_id IN (${placeholders}) GROUP BY agent_id`, ids),
    listingAveragesByAgent(ids),
  ]);
  const languageCount = new Map(languages.map((row) => [Number(row.agent_id), Number(row.n)]));
  const result = new Map();
  for (const agent of agents) {
    const listings = averages.get(Number(agent.id)) ?? { average: 0, live: 0 };
    result.set(
      Number(agent.id),
      {
        ...combine({
          checks: agentProfileChecks(agent, { languageCount: languageCount.get(Number(agent.id)) ?? 0 }),
          listingAverage: listings.average,
          liveListings: listings.live,
        }),
        verified: agent.verification_status === "verified",
      }
    );
  }
  return result;
}

export async function agentQuality(agentId) {
  return (await agentQualities([agentId])).get(Number(agentId)) ?? null;
}

/** A company's quality: its live listings across every agent, and its own profile. */
export async function organizationQuality(organizationId) {
  if (!organizationId) return null;
  const [org, licences, listings] = await Promise.all([
    queryOne(
      `SELECT id, logo_url, description, email, phone, website_url, verification_status
         FROM organizations WHERE id = ? AND deleted_at IS NULL`,
      [Number(organizationId)]
    ),
    queryOne("SELECT COUNT(*) AS n FROM organization_licenses WHERE organization_id = ?", [Number(organizationId)]),
    queryOne(
      `SELECT AVG(quality_score) AS average, COUNT(*) AS live
         FROM listings WHERE organization_id = ? AND status = 'active' AND deleted_at IS NULL`,
      [Number(organizationId)]
    ),
  ]);
  if (!org) return null;
  return {
    ...combine({
      checks: organizationProfileChecks(org, { licenceCount: Number(licences?.n) || 0 }),
      listingAverage: Number(listings?.average) || 0,
      liveListings: Number(listings?.live) || 0,
    }),
    verified: org.verification_status === "verified",
  };
}

/** An account's own listings score, for a seller with no company (an individual agent or owner). */
export async function accountListingQuality(accountId) {
  const row = await queryOne(
    `SELECT AVG(quality_score) AS average, COUNT(*) AS live
       FROM listings WHERE account_id = ? AND status = 'active' AND deleted_at IS NULL`,
    [Number(accountId)]
  );
  const live = Number(row?.live) || 0;
  const score = live ? Math.round(Number(row.average)) : 0;
  return { score, band: qualityBand(score), listingScore: score, liveListings: live };
}
