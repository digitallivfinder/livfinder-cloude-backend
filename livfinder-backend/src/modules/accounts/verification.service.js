import crypto from "node:crypto";
import { queryOne, query, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { getStorage } from "../../config/storage.js";
import logger from "../../config/logger.js";
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
const SIGNUP_FOLDER = "verification/signup";
const ABANDONED_AFTER_MS = 24 * 60 * 60 * 1000;

const mimeTypeFor = (key) => {
  const extension = String(key).split(".").pop().toLowerCase();
  for (const [mimeType, known] of ALLOWED_DOCUMENT_TYPES) if (known === extension) return mimeType;
  return "application/octet-stream";
};

/** A key the client cannot influence: it carries no user-supplied path text. */
function verificationKey({ accountId, userId, extension }) {
  const random = crypto.randomBytes(16).toString("hex");
  const scope = accountId ? `accounts/${accountId}` : userId ? `users/${userId}` : "signup";
  return `verification/${scope}/${Date.now()}-${random}.${extension}`;
}

// An applicant has no account yet, so nothing scopes these keys: the random part is what
// proves the upload is theirs. Exact shape, so a crafted id cannot climb out of the folder.
const SIGNUP_KEY = /^verification\/signup\/\d+-[a-f0-9]{32}\.[a-z0-9]+$/;

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

function assertOwnKey(key, { userId, accountId, atSignup = false }) {
  if (atSignup && SIGNUP_KEY.test(key)) return;
  const ownScope = accountId ? `verification/accounts/${accountId}/` : `verification/users/${userId}/`;
  const alternate = `verification/users/${userId}/`;
  if (!key.startsWith(ownScope) && !key.startsWith(alternate)) {
    // A caller replaying someone else's upload id gets nothing.
    throw AppError.forbidden("That upload does not belong to this account.");
  }
}

/** Checked before an account is created, so a bad document cannot strand a half-finished signup. */
export async function assertSignupDocuments(documents = []) {
  const storage = getStorage();
  for (const document of documents) {
    assertOwnKey(document.uploadId, { atSignup: true });
    if (!(await storage.exists(document.uploadId, { visibility: "private" }))) {
      throw AppError.badRequest("One of the uploaded documents could not be found. Upload it again.");
    }
  }
}

export async function attachUploadedDocuments({ verificationRequestId, userId, accountId = null, atSignup = false, documents }) {
  const storage = getStorage();
  await withTransaction(async (connection) => {
    for (const document of documents) {
      assertOwnKey(document.uploadId, { userId, accountId, atSignup });
      const exists = await storage.exists(document.uploadId, { visibility: "private" });
      if (!exists) {
        throw AppError.badRequest("One of the uploaded documents could not be found. Upload it again.");
      }
      // Out of the applicants' folder: whatever stays there was abandoned and gets swept.
      const key = atSignup ? await claimSignupUpload(document.uploadId, userId) : document.uploadId;
      // Only the local driver can stat; object stores report the size on the read instead.
      const size = storage.stat
        ? (await storage.stat(key, { visibility: "private" }))?.size
        : (await storage.get(key, { visibility: "private" })).length;
      await attachVerificationDocument(
        {
          verificationRequestId,
          documentType: String(document.documentType).slice(0, 80),
          // The stored value is the private key, not a URL. Nothing serves it
          // without an authorization check.
          fileUrl: `private://${key}`,
          fileName: String(document.fileName || key.split("/").pop()).slice(0, 255),
          mimeType: mimeTypeFor(key),
          fileSizeBytes: size ?? null,
        },
        connection
      );
    }
  });
}

async function claimSignupUpload(uploadId, userId) {
  const storage = getStorage();
  const key = `verification/users/${userId}/${uploadId.split("/").pop()}`;
  const body = await storage.get(uploadId, { visibility: "private" });
  await storage.put(key, body, { contentType: mimeTypeFor(key), visibility: "private" });
  await storage.delete(uploadId, { visibility: "private" });
  return key;
}

/**
 * Identity documents from applications that were never completed must not sit in storage.
 * An attached file has already left this folder, so age alone identifies the abandoned ones.
 */
export async function sweepAbandonedSignupUploads({ now = Date.now(), maxAgeMs = ABANDONED_AFTER_MS } = {}) {
  const storage = getStorage();
  const uploads = await storage.list(SIGNUP_FOLDER, { visibility: "private" });
  const expired = uploads.filter((upload) => now - new Date(upload.modifiedAt).getTime() > maxAgeMs);
  for (const upload of expired) await storage.delete(upload.key, { visibility: "private" });
  return expired.length;
}

/** The latest request for a subject, with what a reviewer needs to decide it. */
export async function verificationReview(subjectType, subjectId) {
  const request = await queryOne(
    `SELECT vr.id, vr.public_id, vr.status, vr.submitted_at, vr.reviewed_at, vr.payload,
            vr.rejection_reason, vr.decision_notes,
            reviewer.display_name AS reviewer_name
       FROM verification_requests vr
       LEFT JOIN users reviewer ON reviewer.id = vr.reviewed_by_user_id
      WHERE vr.subject_type = ? AND vr.subject_id = ?
      ORDER BY vr.id DESC LIMIT 1`,
    [subjectType, subjectId]
  );
  if (!request) return null;
  const documents = await query(
    `SELECT id, document_type, file_name, mime_type, file_size_bytes, uploaded_at
       FROM verification_documents WHERE verification_request_id = ? ORDER BY id`,
    [request.id]
  );
  const payload = typeof request.payload === "string" ? JSON.parse(request.payload) : request.payload;
  return {
    id: request.public_id,
    status: request.status,
    submittedAt: isoDate(request.submitted_at),
    reviewedAt: isoDate(request.reviewed_at),
    reviewerName: request.reviewer_name,
    rejectionReason: request.rejection_reason,
    decisionNotes: request.decision_notes,
    requestedCategoryId: payload?.categoryId ?? null,
    documents: documents.map((document) => ({
      id: String(document.id),
      documentType: document.document_type,
      fileName: document.file_name,
      mimeType: document.mime_type || mimeTypeFor(document.file_name),
      sizeBytes: document.file_size_bytes === null ? null : Number(document.file_size_bytes),
      uploadedAt: isoDate(document.uploaded_at),
    })),
  };
}

const PUBLISHABLE_IMAGES = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

/**
 * The photo and logo sent with an application become public only here, on approval. Identity
 * files stay private, so these are copied to public storage rather than exposed. A failed copy
 * must not undo the decision: the owner can still upload one from their profile.
 */
export async function publishApplicationImages({ requestId, accountId, organizationId }) {
  const documents = await query(
    `SELECT document_type, file_url, mime_type FROM verification_documents
      WHERE verification_request_id = ? AND document_type IN ('profile_photo', 'organization_logo')`,
    [requestId]
  );
  const storage = getStorage();
  for (const document of documents) {
    const extension = PUBLISHABLE_IMAGES[document.mime_type];
    if (!extension) continue;
    try {
      const body = await storage.get(document.file_url.replace("private://", ""), { visibility: "private" });
      const { url } = await storage.put(`profiles/${ulid()}.${extension}`, body, { contentType: document.mime_type, visibility: "public" });
      if (document.document_type === "organization_logo" && organizationId) {
        await execute("UPDATE organizations SET logo_url = COALESCE(logo_url, ?) WHERE id = ?", [url, organizationId]);
      } else if (document.document_type === "profile_photo") {
        await execute(
          `UPDATE agents ag JOIN accounts a ON a.owner_user_id = ag.user_id
              SET ag.photo_url = COALESCE(ag.photo_url, ?) WHERE a.id = ? AND ag.deleted_at IS NULL`,
          [url, accountId]
        );
      }
    } catch (error) {
      logger.error({ err: error, requestId, documentType: document.document_type }, "application image could not be published");
    }
  }
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
  return { body, fileName: document.file_name, mimeType: document.mime_type || mimeTypeFor(key) };
}

export { ALLOWED_DOCUMENT_TYPES, MAX_DOCUMENT_BYTES };
