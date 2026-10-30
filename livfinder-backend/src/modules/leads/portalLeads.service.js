import { execute, query, queryOne, queryValue } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { ownAgentClause } from "../../utils/tenantScope.js";
import { frontendCategoryIdFor, scopeClause } from "../portal/engagement.repository.js";
import { rootIdForFrontendCategory } from "../portal/portal.repository.js";
import { readLeadDocument, removeLeadDocument, storeLeadDocument } from "../media/media.service.js";
import { emitLeadEvent } from "./webhooks.service.js";
import {
  DEVELOPMENTS_ROOT_ID,
  findOrCreateContact,
  linkInquiryToLead,
  listingLeadSubject,
  projectLeadSubject,
} from "./leadCapture.service.js";
import {
  LOST_REASON_CODES,
  FUNNEL_STEPS,
  funnelStepLabel,
  funnelStepOf,
  inquiryStatusForStep,
  isClosedStep,
  statusForStep,
  stepForInquiryStatus,
  viewingKindFor,
} from "./leadFunnel.js";

/**
 * The lead workspace behind the client portal: for a company or an individual with no CRM of
 * their own. Every read and write starts from `loadLead`, so a lead outside the caller's account
 * is a 404 that confirms nothing.
 */

async function loadLead(scope, publicId, connection) {
  const clause = scopeClause("l", scope);
  const lead = await queryOne(
    `SELECT l.id, l.public_id, l.organization_id, l.account_id, l.contact_id, l.status, l.stage_id, l.stage_type,
            l.stage_entered_at, l.root_category_id, l.primary_listing_id, l.project_id, l.owner_agent_id,
            l.name, l.email, l.phone_e164, l.next_action_at, l.next_action_note, l.priority,
            li.root_category_id AS listing_root_category_id, li.agent_id AS listing_agent_id
       FROM leads l
       LEFT JOIN listings li ON li.id = l.primary_listing_id
      WHERE l.public_id = ? AND ${clause.sql} AND l.deleted_at IS NULL`,
    [publicId, ...clause.params],
    connection
  );
  if (!lead) throw AppError.notFound("That lead was not found.");
  return {
    ...lead,
    rootCategoryId: lead.listing_root_category_id ?? lead.root_category_id ?? (lead.project_id ? DEVELOPMENTS_ROOT_ID : null),
    step: funnelStepOf(lead.status, lead.stage_type),
  };
}

/** One timeline row, and the lead's own "last touched" with it. */
async function logActivity(lead, { type, title, body = null, userId, direction = "internal" }, connection) {
  await execute(
    `INSERT INTO activities
       (public_id, organization_id, subject_type, subject_id, lead_id, contact_id, activity_type, direction,
        subject_line, body, preview, occurred_at, user_id, created_at, updated_at)
     VALUES (?, ?, 'lead', ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), ?, NOW(3), NOW(3))`,
    [ulid(), lead.organization_id, lead.id, lead.id, lead.contact_id, type, direction, title, body, body ? body.slice(0, 300) : null, userId],
    connection
  );
  await execute("UPDATE leads SET last_activity_at = NOW(3), activity_count = activity_count + 1 WHERE id = ?", [lead.id], connection);
}

async function linkedInquiryIds(leadId, connection) {
  const rows = await query(
    `SELECT i.id FROM inquiries i
      WHERE i.deleted_at IS NULL
        AND (i.lead_id = ? OR i.id IN (SELECT li.inquiry_id FROM lead_inquiries li WHERE li.lead_id = ?))`,
    [leadId, leadId],
    connection
  );
  return rows.map((row) => row.id);
}

/**
 * Moves a lead to a funnel step, with its stage history, timeline row and linked inquiries.
 * The funnel's own stage is used whichever pipeline the lead started on: `stage_type` carries
 * the meaning, so admin and reporting read it the same way.
 */
async function moveToStep(lead, step, { lostReason = null, lostNote = null, userId }, connection) {
  if (step === lead.step) return false;
  const stage = await queryOne(
    `SELECT s.id, s.pipeline_id, s.stage_type
       FROM lead_pipeline_stages s
       JOIN lead_pipelines p ON p.id = s.pipeline_id
      WHERE p.code = 'client-funnel' AND p.organization_id IS NULL AND s.code = ?`,
    [step],
    connection
  );
  const lostReasonId = step === "lost" && lostReason
    ? await queryValue(
        "SELECT id FROM lead_lost_reasons WHERE code = ? AND organization_id IS NULL LIMIT 1",
        [LOST_REASON_CODES[lostReason]],
        connection
      )
    : null;

  await execute(
    `UPDATE leads
        SET pipeline_id = ?, stage_id = ?, stage_type = ?, status = ?, stage_entered_at = NOW(3),
            closed_at = ?, lost_reason_id = ?, lost_note = ?
      WHERE id = ?`,
    [
      stage.pipeline_id, stage.id, stage.stage_type, statusForStep(step),
      isClosedStep(step) ? new Date() : null, lostReasonId, step === "lost" ? lostNote : null, lead.id,
    ],
    connection
  );
  await execute(
    `INSERT INTO lead_stage_history
       (lead_id, from_stage_id, to_stage_id, from_stage_type, to_stage_type, duration_seconds,
        changed_by_user_id, changed_by, reason, lost_reason_id, created_at)
     VALUES (?, ?, ?, ?, ?, TIMESTAMPDIFF(SECOND, ?, NOW(3)), ?, 'user', ?, ?, NOW(3))`,
    [lead.id, lead.stage_id, stage.id, lead.stage_type, stage.stage_type, lead.stage_entered_at, userId, lostNote, lostReasonId],
    connection
  );
  await logActivity(
    lead,
    { type: "stage_change", title: `Moved to ${funnelStepLabel(step, lead.rootCategoryId)}`, body: step === "lost" ? lostNote : null, userId },
    connection
  );

  const inquiryStatus = inquiryStatusForStep(step);
  for (const inquiryId of await linkedInquiryIds(lead.id, connection)) {
    const inquiry = await queryOne("SELECT status FROM inquiries WHERE id = ?", [inquiryId], connection);
    if (["closed", "spam", inquiryStatus].includes(inquiry.status)) continue;
    await execute("UPDATE inquiries SET status = ?, last_activity_at = NOW(3) WHERE id = ?", [inquiryStatus, inquiryId], connection);
    await execute(
      `INSERT INTO inquiry_status_history (inquiry_id, from_status, to_status, changed_by_user_id, changed_at)
       VALUES (?, ?, ?, ?, NOW(3))`,
      [inquiryId, inquiry.status, inquiryStatus, userId],
      connection
    );
  }
  return true;
}

/** The company's own systems hear about it through the linked enquiry, as they do for an inquiry edit. */
async function emitLeadUpdated(leadId) {
  for (const inquiryId of await linkedInquiryIds(leadId)) await emitLeadEvent("inquiry", inquiryId, "lead.updated");
}

/* -------------------------------------------------------------------------- */
/* Read                                                                        */
/* -------------------------------------------------------------------------- */

const LOST_REASON_BY_CODE = Object.fromEntries(Object.entries(LOST_REASON_CODES).map(([key, code]) => [code, key]));

export async function getLead(scope, publicId) {
  const lead = await loadLead(scope, publicId);
  const row = await queryOne(
    `SELECT l.reference, l.intent, l.timeframe, l.budget_min, l.budget_max, l.currency_code, l.lost_note,
            l.created_at, l.last_activity_at,
            COALESCE(c.display_name, l.name) AS contact_name,
            COALESCE(c.primary_email, l.email) AS contact_email,
            COALESCE(c.primary_phone_e164, l.phone_e164) AS contact_phone,
            src.name AS source_name, ag.display_name AS agent_name, lr.code AS lost_reason_code,
            li.title AS listing_title, li.public_id AS listing_public_id,
            pj.name AS project_name, pj.public_id AS project_public_id
       FROM leads l
       LEFT JOIN crm_contacts c ON c.id = l.contact_id
       LEFT JOIN lead_sources src ON src.id = l.source_id
       LEFT JOIN agents ag ON ag.id = l.owner_agent_id
       LEFT JOIN lead_lost_reasons lr ON lr.id = l.lost_reason_id
       LEFT JOIN listings li ON li.id = l.primary_listing_id
       LEFT JOIN projects pj ON pj.id = l.project_id
      WHERE l.id = ?`,
    [lead.id]
  );

  const inquiryIds = await linkedInquiryIds(lead.id);
  const placeholders = inquiryIds.map(() => "?").join(", ") || "NULL";
  const bookingClause = scopeClause("b", scope);
  const [enquiries, conversationId, activity, documents, viewings] = await Promise.all([
    inquiryIds.length
      ? query(
          `SELECT public_id, reference, message, inquiry_type, created_at
             FROM inquiries WHERE id IN (${placeholders}) ORDER BY created_at DESC LIMIT 20`,
          inquiryIds
        )
      : [],
    inquiryIds.length
      ? queryValue(`SELECT public_id FROM conversations WHERE inquiry_id IN (${placeholders}) ORDER BY id DESC LIMIT 1`, inquiryIds)
      : null,
    query(
      `SELECT a.public_id, a.activity_type, a.subject_line, a.body, a.occurred_at,
              COALESCE(u.display_name, ag.display_name) AS actor_name
         FROM activities a
         LEFT JOIN users u ON u.id = a.user_id
         LEFT JOIN agents ag ON ag.id = a.agent_id
        WHERE a.lead_id = ? AND a.deleted_at IS NULL AND a.is_private = 0
        ORDER BY a.occurred_at DESC, a.id DESC LIMIT 200`,
      [lead.id]
    ),
    query(
      `SELECT d.public_id, d.title, d.file_size_bytes, d.created_at, m.mime_type, m.original_file_name, u.display_name AS uploader
         FROM documents d
         JOIN media_assets m ON m.id = d.media_asset_id
         LEFT JOIN users u ON u.id = d.uploaded_by_user_id
        WHERE d.owner_type = 'lead' AND d.owner_id = ? AND d.deleted_at IS NULL
        ORDER BY d.created_at DESC`,
      [lead.id]
    ),
    // A viewing the buyer requested from the listing page belongs here too, though it has no `lead_id`.
    query(
      `SELECT b.public_id, b.reference, b.booking_type, b.status, b.scheduled_start, b.meeting_location, b.notes
         FROM bookings b
        WHERE b.deleted_at IS NULL AND ${bookingClause.sql}
          AND (b.lead_id = ? OR (b.lead_id IS NULL AND b.listing_id = ? AND b.contact_email = ?))
        ORDER BY b.scheduled_start DESC LIMIT 50`,
      [...bookingClause.params, lead.id, lead.primary_listing_id, row.contact_email]
    ),
  ]);

  return {
    id: lead.public_id,
    reference: row.reference,
    status: lead.step,
    categoryId: frontendCategoryIdFor(lead.rootCategoryId),
    contactName: row.contact_name,
    contactEmail: row.contact_email,
    contactPhone: row.contact_phone,
    listingId: row.listing_public_id ?? row.project_public_id ?? null,
    listingTitle: row.listing_title ?? row.project_name ?? null,
    source: row.source_name,
    intent: row.intent,
    timeframe: row.timeframe,
    priority: lead.priority,
    assignedAgentName: row.agent_name,
    budget: row.budget_min ? { min: Number(row.budget_min), max: row.budget_max ? Number(row.budget_max) : null, currency: row.currency_code } : null,
    receivedAt: row.created_at,
    lastActivityAt: row.last_activity_at,
    nextActionAt: lead.next_action_at,
    nextActionNote: lead.next_action_note,
    lostReason: LOST_REASON_BY_CODE[row.lost_reason_code] ?? null,
    lostNote: row.lost_note,
    conversationId,
    enquiries: enquiries.map((entry) => ({
      id: entry.public_id,
      reference: entry.reference,
      message: entry.message,
      type: entry.inquiry_type,
      receivedAt: entry.created_at,
    })),
    notes: activity
      .filter((entry) => entry.activity_type === "note")
      .map((entry) => ({ id: entry.public_id, body: entry.body, authorName: entry.actor_name, at: entry.occurred_at })),
    activity: activity.map((entry) => ({
      id: entry.public_id,
      type: entry.activity_type,
      title: entry.subject_line,
      body: entry.body,
      actorName: entry.actor_name,
      at: entry.occurred_at,
    })),
    documents: documents.map((entry) => ({
      id: entry.public_id,
      title: entry.title,
      fileName: entry.original_file_name,
      mimeType: entry.mime_type,
      sizeBytes: Number(entry.file_size_bytes),
      uploaderName: entry.uploader,
      at: entry.created_at,
    })),
    viewings: viewings.map((entry) => ({
      id: entry.public_id,
      reference: entry.reference,
      type: entry.booking_type,
      status: entry.status,
      startsAt: entry.scheduled_start,
      location: entry.meeting_location,
      notes: entry.notes,
    })),
  };
}

/* -------------------------------------------------------------------------- */
/* Funnel and follow-up                                                        */
/* -------------------------------------------------------------------------- */

export async function updateLead({ scope, publicId, payload, userId }) {
  const { step, lostReason, lostNote, priority, nextActionAt, nextActionNote, ownerAgentId } = payload;
  if (step === "lost" && !lostReason) {
    throw AppError.validation("Some information is invalid.", { lostReason: "Choose a reason." });
  }

  const outcome = await withTransaction(async (connection) => {
    const lead = await loadLead(scope, publicId, connection);
    const moved = step ? await moveToStep(lead, step, { lostReason, lostNote, userId }, connection) : false;

    const assignments = [];
    const params = [];
    if (priority) {
      assignments.push("priority = ?");
      params.push(priority);
    }
    if (ownerAgentId !== undefined) {
      const ownAgent = ownAgentClause({ organizationId: scope.organizationId, userId });
      const agent = ownerAgentId
        ? await queryOne(`SELECT id FROM agents WHERE public_id = ? AND ${ownAgent.sql} AND deleted_at IS NULL`, [ownerAgentId, ...ownAgent.params], connection)
        : null;
      if (ownerAgentId && !agent) {
        throw AppError.validation("Some information is invalid.", { ownerAgentId: "That agent is not on this account." });
      }
      assignments.push("owner_agent_id = ?", "assigned_at = NOW(3)", "assignment_method = 'manual'");
      params.push(agent?.id ?? null);
    }
    if (nextActionAt !== undefined) {
      assignments.push("next_action_at = ?", "next_action_note = ?");
      params.push(nextActionAt ? new Date(nextActionAt) : null, nextActionAt ? nextActionNote || null : null);
      await logActivity(
        lead,
        { type: "task", title: nextActionAt ? "Follow-up set" : "Follow-up cleared", body: nextActionAt ? nextActionNote || null : null, userId },
        connection
      );
    }
    if (assignments.length) await execute(`UPDATE leads SET ${assignments.join(", ")} WHERE id = ?`, [...params, lead.id], connection);
    return { leadId: lead.id, moved };
  });

  if (outcome.moved) await emitLeadUpdated(outcome.leadId);
  return { id: publicId, updated: true, leadId: outcome.leadId };
}

/** An inquiry's status and its lead's funnel step are one fact, shown in two lists. */
export async function syncLeadWithInquiry({ scope, inquiryId, inquiryStatus, userId }, connection) {
  const step = stepForInquiryStatus(inquiryStatus);
  if (!step) return;
  const leadPublicId = await queryValue(
    `SELECT l.public_id FROM leads l
      WHERE l.id = COALESCE((SELECT i.lead_id FROM inquiries i WHERE i.id = ?),
                            (SELECT li.lead_id FROM lead_inquiries li WHERE li.inquiry_id = ? LIMIT 1))`,
    [inquiryId, inquiryId],
    connection
  );
  if (!leadPublicId) return;
  const lead = await loadLead(scope, leadPublicId, connection);
  await moveToStep(lead, step, { userId }, connection);
}

/* -------------------------------------------------------------------------- */
/* Notes                                                                       */
/* -------------------------------------------------------------------------- */

export async function addNote({ scope, publicId, body, userId }) {
  return withTransaction(async (connection) => {
    const lead = await loadLead(scope, publicId, connection);
    await logActivity(lead, { type: "note", title: "Note added", body, userId }, connection);
    return { id: lead.id };
  });
}

export async function deleteNote({ scope, publicId, noteId }) {
  const lead = await loadLead(scope, publicId);
  const result = await execute(
    "UPDATE activities SET deleted_at = NOW(3) WHERE public_id = ? AND lead_id = ? AND activity_type = 'note' AND deleted_at IS NULL",
    [noteId, lead.id]
  );
  if (!result.affectedRows) throw AppError.notFound("That note was not found.");
  return { id: lead.id };
}

/* -------------------------------------------------------------------------- */
/* Documents                                                                   */
/* -------------------------------------------------------------------------- */

export async function addDocument({ scope, publicId, file, userId }) {
  const lead = await loadLead(scope, publicId);
  const asset = await storeLeadDocument({
    buffer: file.buffer,
    originalFileName: file.originalname,
    accountId: lead.account_id ?? scope.accountId,
    userId,
  });
  const title = String(file.originalname).slice(0, 255);
  const documentId = ulid();
  await withTransaction(async (connection) => {
    await execute(
      `INSERT INTO documents
         (public_id, media_asset_id, owner_type, owner_id, document_type, title, file_size_bytes,
          visibility, status, uploaded_by_user_id, created_at)
       VALUES (?, ?, 'lead', ?, 'other', ?, ?, 'internal', 'active', ?, NOW(3))`,
      [documentId, asset.id, lead.id, title, asset.sizeBytes, userId],
      connection
    );
    await logActivity(lead, { type: "document", title: "Document added", body: title, userId }, connection);
  });
  return { id: documentId, title, leadId: lead.id };
}

async function loadDocument(leadId, documentId) {
  const document = await queryOne(
    `SELECT d.id, d.title, d.media_asset_id, m.storage_path, m.mime_type, m.original_file_name
       FROM documents d
       JOIN media_assets m ON m.id = d.media_asset_id
      WHERE d.public_id = ? AND d.owner_type = 'lead' AND d.owner_id = ? AND d.deleted_at IS NULL`,
    [documentId, leadId]
  );
  if (!document) throw AppError.notFound("That document was not found.");
  return document;
}

/** Shared with the admin lead screen: the caller has already established it may see this lead. */
export async function documentFile(leadId, documentId) {
  const document = await loadDocument(leadId, documentId);
  return { body: await readLeadDocument(document.storage_path), mimeType: document.mime_type, fileName: document.original_file_name };
}

export async function downloadDocument({ scope, publicId, documentId }) {
  const lead = await loadLead(scope, publicId);
  return documentFile(lead.id, documentId);
}

export async function deleteDocument({ scope, publicId, documentId, userId }) {
  const lead = await loadLead(scope, publicId);
  const document = await loadDocument(lead.id, documentId);
  await withTransaction(async (connection) => {
    await execute("UPDATE documents SET deleted_at = NOW(3), status = 'archived' WHERE id = ?", [document.id], connection);
    await logActivity(lead, { type: "document", title: "Document removed", body: document.title, userId }, connection);
  });
  await removeLeadDocument(document.media_asset_id, document.storage_path);
  return { id: lead.id };
}

/* -------------------------------------------------------------------------- */
/* Viewings                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * A viewing added on a lead is an ordinary booking, so it is on the portal's Bookings page and
 * goes through the same confirm / complete / cancel actions. The client arranged it, so it
 * starts confirmed. The lead moves to the viewing step unless it is already past it.
 */
export async function addViewing({ scope, publicId, payload, userId }) {
  const start = new Date(payload.scheduledStart);
  if (Number.isNaN(start.getTime())) {
    throw AppError.validation("Some information is invalid.", { scheduledStart: "Choose a valid date and time." });
  }
  if (start.getTime() < Date.now()) {
    throw AppError.validation("Some information is invalid.", { scheduledStart: "Choose a time in the future." });
  }

  const publicBookingId = ulid();
  const outcome = await withTransaction(async (connection) => {
    const lead = await loadLead(scope, publicId, connection);
    if (isClosedStep(lead.step)) throw AppError.badRequest("Reopen this lead before adding a viewing.");

    const kind = viewingKindFor(lead.rootCategoryId);
    const maxRef = await queryValue(
      "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM bookings WHERE reference LIKE 'BK-%'",
      [],
      connection
    );
    const reference = `BK-${Number(maxRef || 5000) + 1}`;
    const contact = lead.contact_id
      ? await queryOne("SELECT display_name, primary_email, primary_phone_e164 FROM crm_contacts WHERE id = ?", [lead.contact_id], connection)
      : null;
    const result = await execute(
      `INSERT INTO bookings
         (public_id, reference, listing_id, lead_id, account_id, organization_id, agent_id, booking_type, status,
          scheduled_start, scheduled_end, guest_count, contact_name, contact_email, contact_phone, notes,
          meeting_location, confirmed_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?, ?, 1, ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
      [
        publicBookingId, reference, lead.primary_listing_id, lead.id, lead.account_id ?? scope.accountId, lead.organization_id,
        lead.owner_agent_id ?? lead.listing_agent_id, kind.bookingType, start, new Date(start.getTime() + 60 * 60 * 1000),
        contact?.display_name ?? lead.name, contact?.primary_email ?? lead.email, contact?.primary_phone_e164 ?? lead.phone_e164,
        payload.notes || null, payload.location || null,
      ],
      connection
    );
    await execute(
      `INSERT INTO booking_status_history (booking_id, from_status, to_status, changed_by_user_id, changed_at)
       VALUES (?, NULL, 'confirmed', ?, NOW(3))`,
      [result.insertId, userId],
      connection
    );
    await execute("UPDATE leads SET viewing_count = viewing_count + 1 WHERE id = ?", [lead.id], connection);
    await logActivity(lead, { type: "viewing", title: `${kind.label} added`, body: payload.notes || null, userId }, connection);

    if (FUNNEL_STEPS.indexOf(lead.step) < FUNNEL_STEPS.indexOf("viewing")) {
      await moveToStep(lead, "viewing", { userId }, connection);
    }
    return { bookingId: result.insertId, reference, leadId: lead.id };
  });

  await emitLeadEvent("booking", outcome.bookingId, "lead.updated");
  return { id: publicBookingId, reference: outcome.reference, leadId: outcome.leadId };
}

/* -------------------------------------------------------------------------- */
/* New leads                                                                   */
/* -------------------------------------------------------------------------- */

const MANUAL_SOURCES = Object.freeze({
  phone: { channel: "phone", sourceCode: "phone-in" },
  walk_in: { channel: "walk_in", sourceCode: "walk-in" },
  referral: { channel: "referral", sourceCode: "client-referral" },
  other: { channel: "other", sourceCode: null },
});

/** A lead the client met off the platform: a phone call, a walk-in, a referral. */
export async function createManualLead({ scope, payload, userId }) {
  const rootId = payload.category === "realEstateDevelopment" ? DEVELOPMENTS_ROOT_ID : rootIdForFrontendCategory(payload.category);
  if (!rootId) throw AppError.validation("Some information is invalid.", { category: "Choose a category." });

  // A development's picker lists projects, which have no `account_id` of their own.
  const developments = rootId === DEVELOPMENTS_ROOT_ID;
  const subjectId = payload.listingId
    ? developments
      ? await queryValue(
          "SELECT p.id FROM projects p WHERE p.public_id = ? AND p.organization_id = ? AND p.deleted_at IS NULL",
          [payload.listingId, scope.organizationId]
        )
      : await queryValue(
          `SELECT l.id FROM listings l
            WHERE l.public_id = ? AND l.root_category_id = ? AND ${scopeClause("l", scope).sql} AND l.deleted_at IS NULL`,
          [payload.listingId, rootId, ...scopeClause("l", scope).params]
        )
    : null;
  if (payload.listingId && !subjectId) {
    throw AppError.validation("Some information is invalid.", { listingId: "That listing is not on this account." });
  }

  const source = MANUAL_SOURCES[payload.source || "other"];
  const name = payload.name.trim();
  return withTransaction(async (connection) => {
    const stage = await queryOne(
      `SELECT s.id, s.pipeline_id
         FROM lead_pipeline_stages s
         JOIN lead_pipelines p ON p.id = s.pipeline_id
        WHERE p.code = 'client-funnel' AND p.organization_id IS NULL AND s.code = 'new'`,
      [],
      connection
    );
    const sourceId = source.sourceCode
      ? await queryValue("SELECT id FROM lead_sources WHERE code = ? AND organization_id IS NULL LIMIT 1", [source.sourceCode], connection)
      : null;
    const contact = await findOrCreateContact(
      { organizationId: scope.organizationId, name, email: payload.email, phone: payload.phone, sourceId },
      connection
    );
    const maxRef = await queryValue(
      "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM leads WHERE reference LIKE 'LD-%'",
      [],
      connection
    );
    const reference = `LD-${Number(maxRef || 10000) + 1}`;
    const publicId = ulid();
    const result = await execute(
      `INSERT INTO leads
         (public_id, reference, organization_id, account_id, contact_id, pipeline_id, stage_id, stage_type,
          status, name, email, phone_e164, intent, category_id, root_category_id, primary_listing_id, project_id,
          source_id, channel, stage_entered_at, last_activity_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'new', 'open', ?, ?, ?, 'other', ?, ?, ?, ?, ?, ?, NOW(3), NOW(3), NOW(3), NOW(3))`,
      [
        publicId, reference, scope.organizationId, scope.accountId, contact?.id ?? null, stage.pipeline_id, stage.id,
        name, payload.email || null, payload.phone || null, rootId, rootId,
        developments ? null : subjectId, developments ? subjectId : null, sourceId, source.channel,
      ],
      connection
    );
    const lead = { id: result.insertId, organization_id: scope.organizationId, contact_id: contact?.id ?? null };
    await logActivity(lead, { type: "other", title: "Lead added manually", userId }, connection);
    if (payload.note) await logActivity(lead, { type: "note", title: "Note added", body: payload.note, userId }, connection);
    return { id: publicId, reference, categoryId: frontendCategoryIdFor(rootId), leadId: result.insertId };
  });
}

/**
 * The lead behind an inquiry, for the Inquiries list's "open" action. An enquiry that predates
 * individuals having leads (or whose listing is gone) has none yet, so it gets one here.
 */
export async function ensureInquiryLead({ scope, inquiryPublicId }) {
  const clause = scopeClause("i", scope);
  const inquiry = await queryOne(
    `SELECT i.id, i.name, i.email, i.phone, i.message, i.inquiry_type, i.listing_id, i.project_id,
            i.account_id, i.organization_id,
            COALESCE(i.lead_id, (SELECT li.lead_id FROM lead_inquiries li WHERE li.inquiry_id = i.id LIMIT 1)) AS linked_lead_id
       FROM inquiries i
      WHERE i.public_id = ? AND ${clause.sql} AND i.deleted_at IS NULL`,
    [inquiryPublicId, ...clause.params]
  );
  if (!inquiry) throw AppError.notFound("That inquiry was not found.");
  if (inquiry.linked_lead_id) {
    return { id: await queryValue("SELECT public_id FROM leads WHERE id = ?", [inquiry.linked_lead_id]) };
  }

  return withTransaction(async (connection) => {
    const listing = inquiry.listing_id
      ? await queryOne(
          `SELECT id, title, organization_id, account_id, category_id, root_category_id, purpose_id, location_id, country_id
             FROM listings WHERE id = ?`,
          [inquiry.listing_id],
          connection
        )
      : null;
    const project = inquiry.project_id
      ? await queryOne(
          `SELECT p.id, p.name, p.organization_id, p.location_id, o.account_id
             FROM projects p LEFT JOIN organizations o ON o.id = p.organization_id WHERE p.id = ?`,
          [inquiry.project_id],
          connection
        )
      : null;
    const subject = listing
      ? listingLeadSubject(listing)
      : project
        ? projectLeadSubject(project)
        : {
            kind: "inquiry", id: inquiry.id, title: "Removed listing",
            organization_id: inquiry.organization_id, account_id: inquiry.account_id,
            category_id: null, root_category_id: null, purpose_id: null, location_id: null, country_id: null,
          };
    const leadId = await linkInquiryToLead(
      { subject, inquiry: { name: inquiry.name, email: inquiry.email, phone: inquiry.phone, message: inquiry.message, inquiryType: inquiry.inquiry_type } },
      connection
    );
    if (!leadId) throw AppError.badRequest("This inquiry cannot be opened as a lead.");
    await execute("UPDATE inquiries SET lead_id = ? WHERE id = ?", [leadId, inquiry.id], connection);
    return { id: await queryValue("SELECT public_id FROM leads WHERE id = ?", [leadId], connection) };
  });
}
