import crypto from "node:crypto";
import { queryOne, query, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { getStorage } from "../../config/storage.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { auditFromRequest } from "../system/audit.service.js";
import { createVerificationRequest, attachVerificationDocument } from "./accounts.service.js";
import { isoDate } from "../../serializers/primitives.js";

/**
 * Sensitive documents are held to a much tighter allow-list than listing media:
 * images and PDFs only, 25 MB, and only in the private tree.
 */
const ALLOWED_DOCUMENT_TYPES = new Map([
  ["application/pdf", "pdf"],
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/heic", "heic"],
  ["image/webp", "webp"],
]);

const MAX_DOCUMENT_BYTES = 25 * 1024 * 1024;

/** A key the client cannot influence: it carries no user-supplied path text. */
function verificationKey({ accountId, userId, extension }) {
  const random = crypto.randomBytes(16).toString("hex");
  const scope = accountId ? `accounts/${accountId}` : `users/${userId}`;
  return `verification/${scope}/${Date.now()}-${random}.${extension}`;
}

export async function presignVerificationUpload({ userId, accountId, fileName, mimeType, fileSizeBytes, documentType }) {
  const extension = ALLOWED_DOCUMENT_TYPES.get(String(mimeType).toLowerCase());
  if (!extension) {
    throw AppError.unsupportedMedia("Upload a PDF or an image of the document.");
  }
  if (Number(fileSizeBytes) > MAX_DOCUMENT_BYTES) {
    throw AppError.payloadTooLarge("Documents must be 25 MB or smaller.");
  }

  const key = verificationKey({ accountId, userId, extension });
  const target = await getStorage().createUploadTarget({
    key,
    contentType: mimeType,
    visibility: "private",
    expiresInSeconds: 900,
  });

  // The uploadId is the key. It is opaque to the browser in the sense that
  // matters: it resolves only inside the private tree, and every later use is
  // re-checked against the caller's ownership.
  return {
    uploadId: key,
    documentType,
    originalFileName: String(fileName).slice(0, 255),
    ...target,
  };
}

function assertOwnKey(key, { userId, accountId }) {
  const ownScope = accountId ? `verification/accounts/${accountId}/` : `verification/users/${userId}/`;
  const alternate = `verification/users/${userId}/`;
  if (!key.startsWith(ownScope) && !key.startsWith(alternate)) {
    // A caller replaying someone else's upload id gets nothing.
    throw AppError.forbidden("That upload does not belong to this account.");
  }
}

export async function attachUploadedDocuments({ verificationRequestId, userId, accountId = null, documents }) {
  const storage = getStorage();
  await withTransaction(async (connection) => {
    for (const document of documents) {
      assertOwnKey(document.uploadId, { userId, accountId });
      const exists = await storage.exists(document.uploadId, { visibility: "private" });
      if (!exists) {
        throw AppError.badRequest("One of the uploaded documents could not be found. Upload it again.");
      }
      const stat = storage.stat ? await storage.stat(document.uploadId, { visibility: "private" }) : null;
      await attachVerificationDocument(
        {
          verificationRequestId,
          documentType: String(document.documentType).slice(0, 80),
          // The stored value is the private key, not a URL. Nothing serves it
          // without an authorization check.
          fileUrl: `private://${document.uploadId}`,
          fileName: document.uploadId.split("/").pop(),
          mimeType: null,
          fileSizeBytes: stat?.size ?? null,
        },
        connection
      );
    }
  });
}

async function subjectFor(req, subjectType) {
  if (subjectType === "organization") {
    const membership = req.auth.activeMembership;
    if (!membership?.organization_id) throw AppError.forbidden("This account has no organization.");
    return { subjectType: "organization", subjectId: membership.organization_id };
  }
  if (subjectType === "agent") {
    if (!req.auth.agent) throw AppError.forbidden("This account has no professional profile.");
    return { subjectType: "agent", subjectId: req.auth.agent.id };
  }
  if (!req.auth.activeAccountId) throw AppError.forbidden("This account cannot submit verification.");
  return { subjectType: "account", subjectId: req.auth.activeAccountId };
}

export async function submitVerification({ req, subjectType, documents, notes }) {
  const subject = await subjectFor(req, subjectType);

  const result = await withTransaction(async (connection) => {
    const existing = await queryOne(
      `SELECT id, status FROM verification_requests
        WHERE subject_type = ? AND subject_id = ? AND status IN ('pending','in_review')
        ORDER BY id DESC LIMIT 1`,
      [subject.subjectType, subject.subjectId],
      connection
    );

    const verificationRequestId =
      existing?.id ??
      (await createVerificationRequest(
        {
          subjectType: subject.subjectType,
          subjectId: subject.subjectId,
          userId: req.auth.user.id,
          payload: { notes: notes || null },
        },
        connection
      ));

    if (existing) {
      await execute(
        "UPDATE verification_requests SET submitted_at = NOW(3), status = 'pending', updated_at = NOW(3) WHERE id = ?",
        [verificationRequestId],
        connection
      );
    }
    return verificationRequestId;
  });

  await attachUploadedDocuments({
    verificationRequestId: result,
    userId: req.auth.user.id,
    accountId: req.auth.activeAccountId,
    documents,
  });

  await auditFromRequest(req, {
    action: "verification.submitted",
    subjectType: subject.subjectType,
    subjectId: subject.subjectId,
    metadata: { documentCount: documents.length },
  });

  return { id: String(result), status: "pending", submittedAt: new Date().toISOString() };
}

export async function verificationStatus(req) {
  const subjects = [];
  if (req.auth.activeAccountId) subjects.push(["account", req.auth.activeAccountId]);
  if (req.auth.activeMembership?.organization_id) subjects.push(["organization", req.auth.activeMembership.organization_id]);
  if (req.auth.agent) subjects.push(["agent", req.auth.agent.id]);
  if (!subjects.length) return { status: "not_required", requests: [] };

  const conditions = subjects.map(() => "(subject_type = ? AND subject_id = ?)").join(" OR ");
  const rows = await query(
    `SELECT vr.id, vr.public_id, vr.subject_type, vr.subject_id, vr.status, vr.priority,
            vr.submitted_at, vr.reviewed_at, vr.rejection_reason, vr.decision_notes,
            (SELECT COUNT(*) FROM verification_documents vd WHERE vd.verification_request_id = vr.id) AS document_count
       FROM verification_requests vr
      WHERE ${conditions}
      ORDER BY vr.id DESC
      LIMIT 20`,
    subjects.flat()
  );

  return {
    status: rows[0]?.status || "not_submitted",
    requests: rows.map((row) => ({
      id: row.public_id,
      subjectType: row.subject_type,
      status: row.status,
      priority: row.priority,
      submittedAt: isoDate(row.submitted_at),
      reviewedAt: isoDate(row.reviewed_at),
      rejectionReason: row.rejection_reason,
      decisionNotes: row.decision_notes,
      documentCount: Number(row.document_count),
    })),
  };
}

/**
 * Streams a verification document to an authorised reader. There is no public
 * URL for these objects; this is the only way to read one.
 */
export async function readVerificationDocument({ documentId, req }) {
  const document = await queryOne(
    `SELECT vd.id, vd.file_url, vd.file_name, vd.mime_type, vd.verification_request_id,
            vr.subject_type, vr.subject_id, vr.requested_by_user_id
       FROM verification_documents vd
       JOIN verification_requests vr ON vr.id = vd.verification_request_id
      WHERE vd.id = ? LIMIT 1`,
    [Number(documentId)]
  );
  if (!document) throw AppError.notFound();

  const isReviewer = req.auth?.platform?.isSuperAdmin || req.auth?.platform?.permissions?.has("companies.verify") ||
    req.auth?.platform?.permissions?.has("individuals.verify");
  const isOwner =
    String(document.requested_by_user_id) === String(req.auth?.user?.id) ||
    (document.subject_type === "account" && String(document.subject_id) === String(req.auth?.activeAccountId)) ||
    (document.subject_type === "organization" &&
      String(document.subject_id) === String(req.auth?.activeMembership?.organization_id));

  if (!isReviewer && !isOwner) throw AppError.forbidden();

  const key = String(document.file_url).replace(/^private:\/\//, "");
  const body = await getStorage().get(key, { visibility: "private" });
  await auditFromRequest(req, {
    action: "verification.document_read",
    subjectType: "verification_document",
    subjectId: document.id,
  });
  return { body, fileName: document.file_name, mimeType: document.mime_type || "application/octet-stream" };
}

export { ALLOWED_DOCUMENT_TYPES, MAX_DOCUMENT_BYTES };
