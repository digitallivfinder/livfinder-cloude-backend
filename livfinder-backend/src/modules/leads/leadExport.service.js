import env from "../../config/env.js";
import { query } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";

/**
 * Leads, as a company's own systems receive them (Phase 6, 0064).
 *
 * A lead is anything a visitor filled in and LivFinder stored for the company: an enquiry, a
 * viewing request (or charter booking), or an offer. All three come out in one shape, the same in
 * the webhook payload, the lead feed (JSON, XML, CSV) and the portal's CSV download, and carry the
 * company's own listing id (`externalId`) when the listing came from its feed or API.
 *
 * The feed is the full history in the order things last changed, read with a cursor: a CRM that
 * keeps the last `nextCursor` gets only what is new or changed since. Leads for a category the
 * account no longer has stay in the history; leads that arrive after the category was taken away
 * are not sent (owner's rule, 2026-10-29). Spam is sent, flagged.
 */

export const LEAD_FEED_VERSION = 1;
const MAX_PAGE = 200;
const DEVELOPMENTS_ROOT_ID = 7;
const TYPES = { inquiry: "enquiry", booking: "viewing_request", offer: "offer" };

/* -------------------------------------------------------------------------- */
/* The cursor                                                                  */
/* -------------------------------------------------------------------------- */

export function encodeCursor(row) {
  const at = new Date(row.updated_at).toISOString();
  return Buffer.from(`${at}|${row.kind}|${row.id}`).toString("base64url");
}

function decodeCursor(cursor) {
  if (!cursor) return null;
  try {
    const [at, kind, id] = Buffer.from(String(cursor), "base64url").toString("utf8").split("|");
    const date = new Date(at);
    if (Number.isNaN(date.getTime()) || !TYPES[kind] || !/^\d+$/.test(id)) throw new Error("bad cursor");
    return { at: date, kind, id: Number(id) };
  } catch {
    throw AppError.validation("Some information is invalid.", { cursor: "That cursor is not one LivFinder gave out. Start again without it." });
  }
}

/* -------------------------------------------------------------------------- */
/* Which leads                                                                 */
/* -------------------------------------------------------------------------- */

// A lead's root category, from its listing (or 7 for a development), and the account's.
const SOURCES = `
  SELECT 'inquiry' AS kind, i.id, i.account_id, i.created_at, i.updated_at,
         COALESCE(l.root_category_id, IF(i.project_id IS NULL, NULL, ${DEVELOPMENTS_ROOT_ID})) AS root_category_id
    FROM inquiries i LEFT JOIN listings l ON l.id = i.listing_id
   WHERE i.account_id = ? AND i.deleted_at IS NULL
  UNION ALL
  SELECT 'booking', b.id, b.account_id, b.created_at, b.updated_at, l.root_category_id
    FROM bookings b LEFT JOIN listings l ON l.id = b.listing_id
   WHERE b.account_id = ? AND b.deleted_at IS NULL
  UNION ALL
  SELECT 'offer', o.id, o.account_id, o.created_at, o.updated_at, l.root_category_id
    FROM offers o LEFT JOIN listings l ON l.id = o.listing_id
   WHERE o.account_id = ? AND o.deleted_at IS NULL`;

// Not a lead that arrived after the account lost the category it is in.
const CATEGORY_RULE = `
  NOT EXISTS (
    SELECT 1 FROM account_category_access aca JOIN categories c ON c.id = aca.category_id
     WHERE aca.account_id = x.account_id AND COALESCE(c.root_category_id, c.id) = x.root_category_id
       AND aca.status IN ('revoked', 'rejected') AND aca.reviewed_at IS NOT NULL AND aca.reviewed_at <= x.created_at)`;

/** One page of an account's leads after `cursor`, oldest change first. */
export async function listLeadsSince({ accountId, cursor = null, limit = 100 }) {
  const after = decodeCursor(cursor);
  const size = Math.min(MAX_PAGE, Math.max(1, Number(limit) || 100));
  const params = [accountId, accountId, accountId];
  let where = CATEGORY_RULE;
  if (after) {
    where += " AND (x.updated_at > ? OR (x.updated_at = ? AND (x.kind > ? OR (x.kind = ? AND x.id > ?))))";
    params.push(after.at, after.at, after.kind, after.kind, after.id);
  }
  const rows = await query(
    `SELECT x.kind, x.id, x.updated_at FROM (${SOURCES}) x WHERE ${where}
      ORDER BY x.updated_at ASC, x.kind ASC, x.id ASC LIMIT ${size + 1}`,
    params
  );
  const page = rows.slice(0, size);
  const leads = await loadLeads(page);
  return {
    leads,
    nextCursor: page.length ? encodeCursor(page.at(-1)) : cursor || null,
    hasMore: rows.length > size,
  };
}

const ONE_LEAD = {
  inquiry: `SELECT i.account_id, i.created_at,
                   COALESCE(l.root_category_id, IF(i.project_id IS NULL, NULL, ${DEVELOPMENTS_ROOT_ID})) AS root_category_id
              FROM inquiries i LEFT JOIN listings l ON l.id = i.listing_id WHERE i.id = ?`,
  booking: `SELECT b.account_id, b.created_at, l.root_category_id
              FROM bookings b LEFT JOIN listings l ON l.id = b.listing_id WHERE b.id = ?`,
  offer: `SELECT o.account_id, o.created_at, l.root_category_id
            FROM offers o LEFT JOIN listings l ON l.id = o.listing_id WHERE o.id = ?`,
};

/** The account a lead belongs to, or null when it may not go out (its category was taken away first). */
export async function deliverableAccount(kind, id) {
  if (!ONE_LEAD[kind]) return null;
  const [row] = await query(`SELECT x.account_id FROM (${ONE_LEAD[kind]}) x WHERE x.account_id IS NOT NULL AND ${CATEGORY_RULE}`, [id]);
  return row ? Number(row.account_id) : null;
}

/* -------------------------------------------------------------------------- */
/* Loading and shaping                                                         */
/* -------------------------------------------------------------------------- */

const LISTING_COLUMNS = `
  l.public_id AS listing_public_id, l.reference AS listing_reference, l.title AS listing_title,
  l.canonical_path AS listing_path, l.root_category_id AS listing_root,
  (SELECT er.external_id FROM external_references er JOIN integration_connections ic ON ic.id = er.connection_id
    WHERE er.entity_type = 'listing' AND er.entity_id = l.id AND ic.account_id = l.account_id LIMIT 1) AS listing_external_id`;
const AGENT_COLUMNS = `ag.public_id AS agent_public_id, ag.display_name AS agent_name, ag.email AS agent_email, ag.phone AS agent_phone`;

async function loadKind(kind, ids) {
  if (!ids.length) return [];
  const marks = ids.map(() => "?").join(", ");
  if (kind === "inquiry") {
    return query(
      `SELECT 'inquiry' AS kind, i.id, i.public_id, i.reference, i.status, i.is_spam, i.channel, i.inquiry_type, i.name, i.email, i.phone,
              i.message, i.budget_min, i.budget_max, i.currency_code, i.source_url, i.created_at, i.updated_at,
              ${LISTING_COLUMNS}, ${AGENT_COLUMNS},
              p.public_id AS project_public_id, p.name AS project_name, p.canonical_path AS project_path,
              (SELECT er.external_id FROM external_references er JOIN integration_connections ic ON ic.id = er.connection_id
                WHERE er.entity_type = 'project' AND er.entity_id = p.id AND ic.account_id = i.account_id LIMIT 1) AS project_external_id
         FROM inquiries i
         LEFT JOIN listings l ON l.id = i.listing_id
         LEFT JOIN projects p ON p.id = i.project_id
         LEFT JOIN agents ag ON ag.id = COALESCE(i.assigned_to_agent_id, i.agent_id)
        WHERE i.id IN (${marks})`,
      ids
    );
  }
  if (kind === "booking") {
    return query(
      `SELECT 'booking' AS kind, b.id, b.public_id, b.reference, b.status, 0 AS is_spam, 'form' AS channel, b.booking_type,
              b.contact_name AS name, b.contact_email AS email, b.contact_phone AS phone, b.notes AS message,
              b.scheduled_start, b.scheduled_end, b.guest_count, b.currency_code, b.created_at, b.updated_at,
              ${LISTING_COLUMNS}, ${AGENT_COLUMNS}
         FROM bookings b
         LEFT JOIN listings l ON l.id = b.listing_id
         LEFT JOIN agents ag ON ag.id = b.agent_id
        WHERE b.id IN (${marks})`,
      ids
    );
  }
  return query(
    `SELECT 'offer' AS kind, o.id, o.public_id, o.reference, o.status, 0 AS is_spam, 'form' AS channel,
            o.buyer_name AS name, o.buyer_email AS email, o.buyer_phone AS phone, o.message, o.amount, o.currency_code,
            o.is_subject_to_finance, o.is_subject_to_survey, o.conditions, o.expires_at, o.created_at, o.updated_at,
            ${LISTING_COLUMNS}, ${AGENT_COLUMNS}
       FROM offers o
       LEFT JOIN listings l ON l.id = o.listing_id
       LEFT JOIN agents ag ON ag.id = o.agent_id
      WHERE o.id IN (${marks})`,
    ids
  );
}

const iso = (value) => (value ? new Date(value).toISOString() : null);
const num = (value) => (value === null || value === undefined ? null : Number(value));
const url = (path) => (path ? `${String(env.FRONTEND_URL || "").replace(/\/$/, "")}${path}` : null);
const ROOT_CATEGORY = { 1: "real-estate", 2: "cars", 3: "yachts", 4: "jets", 5: "helicopters", 6: "watches", 7: "developments" };

/** The one shape a lead has everywhere it goes out. */
export function serializeLead(row) {
  return {
    id: row.public_id,
    type: TYPES[row.kind],
    reference: row.reference,
    status: row.status,
    spam: Boolean(Number(row.is_spam)),
    channel: row.channel,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    contact: { name: row.name ?? null, email: row.email ?? null, phone: row.phone ?? null },
    message: row.message ?? null,
    enquiry:
      row.kind === "inquiry"
        ? { type: row.inquiry_type, budgetMin: num(row.budget_min), budgetMax: num(row.budget_max), currency: row.currency_code ?? null }
        : null,
    viewing:
      row.kind === "booking"
        ? { type: row.booking_type, start: iso(row.scheduled_start), end: iso(row.scheduled_end), guests: num(row.guest_count) }
        : null,
    offer:
      row.kind === "offer"
        ? {
            amount: num(row.amount),
            currency: row.currency_code ?? null,
            subjectToFinance: Boolean(Number(row.is_subject_to_finance)),
            subjectToSurvey: Boolean(Number(row.is_subject_to_survey)),
            conditions: row.conditions ?? null,
            expiresAt: iso(row.expires_at),
          }
        : null,
    listing: row.listing_public_id
      ? {
          id: row.listing_public_id,
          reference: row.listing_reference,
          externalId: row.listing_external_id ?? null,
          title: row.listing_title,
          category: ROOT_CATEGORY[row.listing_root] ?? null,
          url: url(row.listing_path),
        }
      : null,
    project: row.project_public_id
      ? { id: row.project_public_id, externalId: row.project_external_id ?? null, name: row.project_name, url: url(row.project_path) }
      : null,
    agent: row.agent_public_id ? { id: row.agent_public_id, name: row.agent_name, email: row.agent_email ?? null, phone: row.agent_phone ?? null } : null,
    sourceUrl: row.source_url ?? null,
  };
}

/** Loads and shapes `[{ kind, id }]`, in the order given. */
export async function loadLeads(refs) {
  const byKind = { inquiry: [], booking: [], offer: [] };
  for (const ref of refs) byKind[ref.kind].push(Number(ref.id));
  const rows = (await Promise.all(Object.entries(byKind).map(([kind, ids]) => loadKind(kind, ids)))).flat();
  const index = new Map(rows.map((row) => [`${row.kind}:${row.id}`, row]));
  return refs.map((ref) => index.get(`${ref.kind}:${ref.id}`)).filter(Boolean).map(serializeLead);
}

export async function loadLead(kind, id) {
  const [lead] = await loadLeads([{ kind, id }]);
  return lead ?? null;
}

/* -------------------------------------------------------------------------- */
/* XML and CSV                                                                 */
/* -------------------------------------------------------------------------- */

const escapeXml = (value) => String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function xmlNode(name, value, pad) {
  if (value === null || value === undefined) return [];
  if (typeof value === "object") {
    const inner = Object.entries(value).flatMap(([key, child]) => xmlNode(key, child, `${pad}  `));
    return inner.length ? [`${pad}<${name}>`, ...inner, `${pad}</${name}>`] : [];
  }
  return [`${pad}<${name}>${escapeXml(value)}</${name}>`];
}

export function leadsToXml({ leads, nextCursor, hasMore }) {
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    `<livfinder-leads version="${LEAD_FEED_VERSION}" next-cursor="${escapeXml(nextCursor ?? "")}" has-more="${hasMore ? "true" : "false"}">`,
    ...leads.flatMap((lead) => xmlNode("lead", lead, "  ")),
    "</livfinder-leads>",
    "",
  ].join("\n");
}

export const LEAD_CSV_COLUMNS = [
  ["id", (l) => l.id],
  ["type", (l) => l.type],
  ["reference", (l) => l.reference],
  ["status", (l) => l.status],
  ["spam", (l) => (l.spam ? "yes" : "no")],
  ["createdAt", (l) => l.createdAt],
  ["updatedAt", (l) => l.updatedAt],
  ["name", (l) => l.contact.name],
  ["email", (l) => l.contact.email],
  ["phone", (l) => l.contact.phone],
  ["message", (l) => l.message],
  ["enquiryType", (l) => l.enquiry?.type],
  ["budgetMin", (l) => l.enquiry?.budgetMin],
  ["budgetMax", (l) => l.enquiry?.budgetMax],
  ["viewingStart", (l) => l.viewing?.start],
  ["offerAmount", (l) => l.offer?.amount],
  ["currency", (l) => l.enquiry?.currency ?? l.offer?.currency],
  ["listingId", (l) => l.listing?.id],
  ["listingReference", (l) => l.listing?.reference],
  ["listingExternalId", (l) => l.listing?.externalId],
  ["listingTitle", (l) => l.listing?.title],
  ["listingCategory", (l) => l.listing?.category],
  ["listingUrl", (l) => l.listing?.url],
  ["projectId", (l) => l.project?.id],
  ["projectExternalId", (l) => l.project?.externalId],
  ["projectName", (l) => l.project?.name],
  ["agentName", (l) => l.agent?.name],
  ["agentEmail", (l) => l.agent?.email],
  ["sourceUrl", (l) => l.sourceUrl],
];

const csvCell = (value) => {
  if (value === null || value === undefined) return "";
  const text = String(value);
  return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

export function leadsToCsv(leads) {
  const header = LEAD_CSV_COLUMNS.map(([name]) => name).join(",");
  const rows = leads.map((lead) => LEAD_CSV_COLUMNS.map(([, read]) => csvCell(read(lead))).join(","));
  return `${[header, ...rows].join("\r\n")}\r\n`;
}
