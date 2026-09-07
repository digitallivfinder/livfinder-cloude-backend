import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth } from "../../middleware/auth.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import crypto from "node:crypto";
import { ulid } from "../../utils/ids.js";
import { auditFromRequest } from "../system/audit.service.js";
import { listFavourites, listSavedSearches } from "../portal/engagement.repository.js";
import { resolveCategory } from "../../utils/categories.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { sendMail } from "../system/mail.service.js";
import net from "node:net";
import { notifyNewBooking, notifyNewInquiry, notifyNewOffer } from "../system/notifications.service.js";
import { idempotency } from "../../middleware/idempotency.js";

/**
 * Buyer-side actions available to any signed-in user: favourites, saved
 * searches, inquiries, viewing requests and offers. These are not portal
 * features — a visitor with an account uses them without belonging to any
 * seller account.
 */
const router = Router();

function ipToBinary(ip) {
  if (!ip) return null;
  const clean = String(ip).replace(/^::ffff:/, "");
  return net.isIPv4(clean) ? Buffer.from(clean.split(".").map(Number)) : null;
}

async function resolvePublicListing(identifier) {
  const listing = await queryOne(
    `SELECT l.id, l.public_id, l.reference, l.title, l.account_id, l.organization_id, l.agent_id,
            l.category_id, l.location_id, l.country_id, l.currency_code, l.contact_email
       FROM v_public_listings l
      WHERE l.public_id = ? OR l.reference = ? OR l.canonical_path = ?
      LIMIT 1`,
    [String(identifier), String(identifier), String(identifier)]
  );
  if (!listing) throw AppError.notFound("That listing is not available.");
  return listing;
}

/**
 * A project an enquiry may be sent about.
 *
 * Read from `project_search`, so an unpublished, archived or cancelled project
 * cannot receive one — and `accepts_inquiries` is honoured here rather than by
 * hiding the form, because hiding a form is a presentation choice and this is a
 * rule.
 */
async function resolvePublicProject(identifier) {
  const reference = String(identifier).slice(0, 220);
  const row = await queryOne(
    `SELECT ps.project_id AS id, ps.public_id, ps.name, ps.canonical_path, ps.accepts_inquiries,
            ps.country_id, ps.city_id, ps.community_id, ps.currency_code,
            p.organization_id, p.category_id, p.location_id
       FROM project_search ps
       JOIN projects p ON p.id = ps.project_id
      WHERE ps.public_id = ? OR ps.slug = ? OR ps.canonical_path = ?
      LIMIT 1`,
    [reference, reference, reference]
  );
  if (!row) throw AppError.notFound("That project is not available.");
  if (!row.accepts_inquiries) throw AppError.badRequest("This project is not accepting enquiries.");
  return row;
}

/**
 * Unlock a project's gated documents for the person who just enquired.
 *
 * "Gated" means exactly this: the file exists, the public DTO names it without
 * a URL, and a successful enquiry earns a grant. Restricted and internal
 * documents are never touched — those need an explicit grant from an operator,
 * which an enquiry form cannot confer.
 */
async function grantProjectDocuments({ projectId, inquiryId, email, userId }, connection) {
  const documents = await query(
    `SELECT id FROM documents
      WHERE owner_type = 'project' AND owner_id = ? AND deleted_at IS NULL
        AND status = 'active' AND visibility = 'gated'
        AND (expires_at IS NULL OR expires_at > NOW(3))`,
    [projectId],
    connection
  );
  const granted = [];
  for (const document of documents) {
    const token = crypto.randomBytes(32).toString("hex");
    await execute(
      `INSERT INTO document_access_grants
         (document_id, user_id, email, inquiry_id, access_token, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(3), INTERVAL 30 DAY), NOW(3))`,
      [document.id, userId ?? null, email, inquiryId ?? null, token],
      connection
    );
    granted.push(document.id);
  }
  return granted;
}

/* -------------------------------------------------------------------------- */
/* Favourites                                                                  */
/* -------------------------------------------------------------------------- */

router.get(
  "/favourites",
  requireAuth,
  asyncHandler(async (req, res) => {
    const result = await listFavourites({ userId: req.auth.user.id, ...(q(req) || {}) });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      countsByCategory: result.countsByCategory,
      locations: result.locations,
    });
  })
);

/** The set of listing ids this user has favourited, for hydrating heart icons. */
router.get(
  "/favourites/ids",
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await query(
      `SELECT l.public_id FROM favourites f JOIN listings l ON l.id = f.listing_id
        WHERE f.user_id = ? AND l.deleted_at IS NULL LIMIT 2000`,
      [req.auth.user.id]
    );
    return res.json({ data: rows.map((row) => row.public_id) });
  })
);

router.post(
  "/favourites",
  writeLimiter,
  requireAuth,
  validate({ body: z.object({ listingId: z.string().min(1).max(64), notes: z.string().trim().max(500).optional() }) }),
  asyncHandler(async (req, res) => {
    const listing = await resolvePublicListing(req.body.listingId);
    await withTransaction(async (connection) => {
      const price = await queryValue("SELECT price FROM listings WHERE id = ?", [listing.id], connection);
      // price_at_save is what makes "this dropped 5% since you saved it" possible.
      await execute(
        `INSERT INTO favourites (user_id, listing_id, price_at_save, currency_code, notes, created_at)
         VALUES (?, ?, ?, ?, ?, NOW(3))
         ON DUPLICATE KEY UPDATE notes = VALUES(notes)`,
        [req.auth.user.id, listing.id, price, listing.currency_code, req.body.notes || null],
        connection
      );
      await execute(
        `UPDATE listings SET favourite_count = (SELECT COUNT(*) FROM favourites WHERE listing_id = ?) WHERE id = ?`,
        [listing.id, listing.id],
        connection
      );
    });
    return res.status(201).json(detailResponse({ listingId: listing.public_id, favourited: true }));
  })
);

router.delete(
  "/favourites/:listingId",
  writeLimiter,
  requireAuth,
  asyncHandler(async (req, res) => {
    const listing = await queryOne(
      "SELECT id, public_id FROM listings WHERE public_id = ? OR reference = ? LIMIT 1",
      [req.params.listingId, req.params.listingId]
    );
    if (!listing) throw AppError.notFound("That listing was not found.");
    await withTransaction(async (connection) => {
      await execute("DELETE FROM favourites WHERE user_id = ? AND listing_id = ?", [req.auth.user.id, listing.id], connection);
      await execute(
        `UPDATE listings SET favourite_count = (SELECT COUNT(*) FROM favourites WHERE listing_id = ?) WHERE id = ?`,
        [listing.id, listing.id],
        connection
      );
    });
    return res.json(detailResponse({ listingId: listing.public_id, favourited: false }));
  })
);

/* -------------------------------------------------------------------------- */
/* Saved searches                                                              */
/* -------------------------------------------------------------------------- */

router.get(
  "/saved-searches",
  requireAuth,
  asyncHandler(async (req, res) => res.json({ data: await listSavedSearches({ userId: req.auth.user.id }) }))
);

const savedSearchSchema = z.object({
  name: z.string().trim().min(1, "Name this search.").max(160),
  category: z.string().trim().max(40).optional(),
  purpose: z.string().trim().max(20).optional(),
  locationId: z.union([z.string(), z.number()]).optional().nullable(),
  criteria: z.record(z.string(), z.unknown()).default({}),
  canonicalUrl: z.string().trim().max(500).optional(),
  alertsEnabled: z.boolean().optional(),
  alertFrequency: z.enum(["instant", "daily", "weekly", "never"]).optional(),
});

router.post(
  "/saved-searches",
  writeLimiter,
  requireAuth,
  validate({ body: savedSearchSchema }),
  asyncHandler(async (req, res) => {
    const definition = req.body.category ? resolveCategory(req.body.category) : null;
    const location = req.body.locationId ? await resolveLocation(req.body.locationId) : null;
    const purposeId = req.body.purpose
      ? await queryValue("SELECT id FROM purposes WHERE code = ? LIMIT 1", [req.body.purpose])
      : await queryValue("SELECT id FROM purposes WHERE code = 'sale' LIMIT 1");

    const publicId = ulid();
    await execute(
      `INSERT INTO saved_searches
         (public_id, user_id, name, category_id, purpose_id, location_id, criteria, canonical_url,
          alerts_enabled, alert_frequency, alert_channels, last_result_count, new_result_count, created_at)
       VALUES (?, ?, ?, ?, ?, ?, CAST(? AS JSON), ?, ?, ?, CAST(? AS JSON), 0, 0, NOW(3))`,
      [
        publicId,
        req.auth.user.id,
        req.body.name,
        definition?.rootId ?? null,
        purposeId,
        location?.id ?? null,
        JSON.stringify(req.body.criteria || {}),
        req.body.canonicalUrl || null,
        req.body.alertsEnabled === false ? 0 : 1,
        req.body.alertFrequency || "daily",
        JSON.stringify(["email"]),
      ]
    );
    await auditFromRequest(req, { action: "saved_search.created", subjectType: "saved_search", subjectLabel: req.body.name });
    return res.status(201).json(detailResponse({ id: publicId, name: req.body.name }));
  })
);

router.patch(
  "/saved-searches/:id",
  writeLimiter,
  requireAuth,
  validate({ body: savedSearchSchema.partial() }),
  asyncHandler(async (req, res) => {
    const saved = await queryOne(
      "SELECT id FROM saved_searches WHERE public_id = ? AND user_id = ? AND deleted_at IS NULL",
      [req.params.id, req.auth.user.id]
    );
    if (!saved) throw AppError.notFound("That saved search was not found.");

    const assignments = [];
    const params = [];
    if (req.body.name !== undefined) {
      assignments.push("name = ?");
      params.push(req.body.name);
    }
    if (req.body.alertsEnabled !== undefined) {
      assignments.push("alerts_enabled = ?");
      params.push(req.body.alertsEnabled ? 1 : 0);
    }
    if (req.body.alertFrequency !== undefined) {
      assignments.push("alert_frequency = ?");
      params.push(req.body.alertFrequency);
    }
    if (req.body.criteria !== undefined) {
      assignments.push("criteria = CAST(? AS JSON)");
      params.push(JSON.stringify(req.body.criteria));
    }
    if (req.body.canonicalUrl !== undefined) {
      assignments.push("canonical_url = ?");
      params.push(req.body.canonicalUrl);
    }
    if (!assignments.length) return res.json(detailResponse({ id: req.params.id, updated: false }));

    await execute(`UPDATE saved_searches SET ${assignments.join(", ")} WHERE id = ?`, [...params, saved.id]);
    return res.json(detailResponse({ id: req.params.id, updated: true }));
  })
);

router.delete(
  "/saved-searches/:id",
  writeLimiter,
  requireAuth,
  asyncHandler(async (req, res) => {
    const result = await execute(
      "UPDATE saved_searches SET deleted_at = NOW(3) WHERE public_id = ? AND user_id = ? AND deleted_at IS NULL",
      [req.params.id, req.auth.user.id]
    );
    if (!result.affectedRows) throw AppError.notFound("That saved search was not found.");
    return res.json(detailResponse({ id: req.params.id, deleted: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Inquiries                                                                   */
/* -------------------------------------------------------------------------- */

const inquirySchema = z.object({
  listingId: z.string().min(1).max(64).optional(),
  /**
   * A project enquiry, addressed by its public ULID, its slug or its canonical
   * path. Independent of `listingId`: a visitor enquiring about a development
   * is not enquiring about any one unit in it, and forcing a listing id would
   * have meant either inventing one or refusing the enquiry.
   */
  projectId: z.string().min(1).max(220).optional(),
  name: z.string().trim().min(1, "Enter your name.").max(200),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  message: z.string().trim().min(10, "Write a short message.").max(4000),
  inquiryType: z.enum(["general", "viewing", "callback", "brochure", "floor_plan", "price", "availability", "offer", "valuation", "charter"]).optional(),
  // Mirrors the `inquiries.channel` enum; the public contact form is "form".
  channel: z.enum(["form", "email", "phone", "whatsapp", "chat"]).optional(),
  budgetMin: z.coerce.number().min(0).max(1e15).optional(),
  budgetMax: z.coerce.number().min(0).max(1e15).optional(),
  sourceUrl: z.string().trim().max(700).optional(),
}).refine((value) => Boolean(value.listingId || value.projectId), {
  message: "Tell us which listing or project this is about.",
  path: ["listingId"],
});

/**
 * Public inquiry. Deliberately does not require a session — the marketplace
 * contact form is open — but it is rate-limited and every field is validated
 * and length-capped before it reaches the database.
 */
router.post(
  "/inquiries",
  writeLimiter,
  idempotency({ scope: "engagement" }),
  validate({ body: inquirySchema }),
  asyncHandler(async (req, res) => {
    /**
     * One enquiry table, two subjects.
     *
     * `inquiries` has carried `project_id` since 0008 and nothing ever wrote it,
     * so a development enquiry had to borrow one of its units — which attributed
     * the lead to a listing the buyer had not asked about. The two subjects are
     * resolved separately and the row records whichever the caller named; an
     * enquiry may legitimately carry both when a visitor asks about a specific
     * unit inside a project.
     */
    const listing = req.body.listingId ? await resolvePublicListing(req.body.listingId) : null;
    const project = req.body.projectId ? await resolvePublicProject(req.body.projectId) : null;
    const subject = listing || project;
    const subjectLabel = listing?.title || project?.name;
    const publicId = ulid();

    const { reference, inquiryId, grantedDocuments } = await withTransaction(async (connection) => {
      const maxRef = await queryValue(
        "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM inquiries WHERE reference LIKE 'IQ-%'",
        [],
        connection
      );
      const ref = `IQ-${Number(maxRef || 10000) + 1}`;

      const result = await execute(
        `INSERT INTO inquiries
           (public_id, reference, listing_id, project_id, account_id, organization_id, agent_id, category_id,
            location_id, country_id, user_id, name, email, phone, channel, inquiry_type,
            message, status, priority, budget_min, budget_max, currency_code,
            source_url, ip_address, user_agent, spam_score, is_spam, last_activity_at, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'new', 'normal', ?, ?, ?, ?, ?, ?, 0, 0, NOW(3), NOW(3))`,
        [
          publicId,
          ref,
          listing?.id ?? null,
          project?.id ?? null,
          listing?.account_id ?? null,
          listing?.organization_id ?? project?.organization_id ?? null,
          listing?.agent_id ?? null,
          listing?.category_id ?? project?.category_id ?? null,
          listing?.location_id ?? project?.location_id ?? null,
          listing?.country_id ?? project?.country_id ?? null,
          req.auth?.user?.id ?? null,
          req.body.name,
          req.body.email,
          req.body.phone || null,
          req.body.channel || "form",
          req.body.inquiryType || "general",
          req.body.message,
          req.body.budgetMin ?? null,
          req.body.budgetMax ?? null,
          listing?.currency_code ?? project?.currency_code ?? null,
          req.body.sourceUrl || null,
          ipToBinary(req.ip),
          (req.get("user-agent") || "").slice(0, 500) || null,
        ],
        connection
      );

      if (listing) {
        await execute("UPDATE listings SET inquiry_count = inquiry_count + 1 WHERE id = ?", [listing.id], connection);
      }
      const granted = project
        ? await grantProjectDocuments(
            { projectId: project.id, inquiryId: result.insertId, email: req.body.email, userId: req.auth?.user?.id },
            connection
          )
        : [];
      return { reference: ref, inquiryId: result.insertId, grantedDocuments: granted };
    });

    if (listing?.contact_email) {
      await sendMail({
        to: listing.contact_email,
        subject: `New enquiry ${reference} — ${listing.title}`,
        text: `${req.body.name} (${req.body.email}${req.body.phone ? `, ${req.body.phone}` : ""}) asked about ${listing.title} (${listing.reference}):\n\n${req.body.message}`,
      });
    }

    await auditFromRequest(req, {
      action: "inquiry.created",
      subjectType: listing ? "listing" : "project",
      subjectId: subject.id,
      metadata: { reference, projectId: project?.public_id ?? null },
    });
    /**
     * The daily counter, alongside the view counter in `POST /listings/:id/view`.
     *
     * `db/seeds/049_demo_finalise.sql` asserts that `listing_daily_stats.inquiries` reconciles
     * with the `inquiries` table, so an enquiry that does not increment this leaves the two
     * permanently out of step — and every "inquiries" trend line understates reality. A
     * project-only enquiry has no listing to attribute, so it is counted in `inquiries` alone.
     */
    if (listing) {
      await execute(
        `INSERT INTO listing_daily_stats
           (listing_id, stat_date, impressions, views, unique_views, inquiries, favourites,
            organization_id, agent_id, category_id, computed_at)
         VALUES (?, CURDATE(), 0, 0, 0, 1, 0, ?, ?, ?, NOW(3))
         ON DUPLICATE KEY UPDATE inquiries = inquiries + 1, computed_at = NOW(3)`,
        [listing.id, listing.organization_id, listing.agent_id, listing.category_id]
      ).catch(() => {});
    }

    // Outside the transaction and non-fatal: the enquiry is already stored and visible in the
    // inbox. A notification that cannot be written must not turn a successful enquiry into a
    // 500 for the buyer who sent it.
    if (listing) {
      await notifyNewInquiry({
        listing,
        inquiry: { id: inquiryId, reference, name: req.body.name, message: req.body.message },
      });
    }
    return res.status(201).json(
      detailResponse({
        id: publicId,
        reference,
        submitted: true,
        subject: subjectLabel,
        projectId: project?.public_id ?? null,
        // What the enquiry just unlocked, so the page can reveal the brochure it
        // was gating rather than telling the visitor to check their email.
        unlockedDocumentCount: grantedDocuments.length,
      })
    );
  })
);

/* -------------------------------------------------------------------------- */
/* Viewing requests and offers                                                 */
/* -------------------------------------------------------------------------- */

router.post(
  "/bookings",
  writeLimiter,
  idempotency({ scope: "engagement" }),
  requireAuth,
  validate({
    body: z.object({
      listingId: z.string().min(1).max(64),
      scheduledStart: z.string().min(1).max(40),
      scheduledEnd: z.string().max(40).optional(),
      bookingType: z.enum(["viewing", "inspection", "sea_trial", "test_drive", "charter", "consultation"]).optional(),
      guestCount: z.coerce.number().int().min(1).max(50).optional(),
      notes: z.string().trim().max(2000).optional(),
      contactName: z.string().trim().max(200).optional(),
      contactEmail: z.string().trim().toLowerCase().email().max(255).optional(),
      contactPhone: z.string().trim().max(40).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await resolvePublicListing(req.body.listingId);
    const start = new Date(req.body.scheduledStart);
    if (Number.isNaN(start.getTime())) {
      throw AppError.validation("Some information is invalid.", { scheduledStart: "Choose a valid date and time." });
    }
    if (start.getTime() < Date.now()) {
      throw AppError.validation("Some information is invalid.", { scheduledStart: "Choose a time in the future." });
    }

    const publicId = ulid();
    const reference = await withTransaction(async (connection) => {
      const maxRef = await queryValue(
        "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM bookings WHERE reference LIKE 'BK-%'",
        [],
        connection
      );
      const ref = `BK-${Number(maxRef || 5000) + 1}`;
      await execute(
        `INSERT INTO bookings
           (public_id, reference, listing_id, user_id, account_id, organization_id, agent_id,
            booking_type, status, scheduled_start, scheduled_end, guest_count,
            contact_name, contact_email, contact_phone, notes, currency_code, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'requested', ?, ?, ?, ?, ?, ?, ?, ?, NOW(3))`,
        [
          publicId,
          ref,
          listing.id,
          req.auth.user.id,
          listing.account_id,
          listing.organization_id,
          listing.agent_id,
          req.body.bookingType || "viewing",
          start,
          req.body.scheduledEnd ? new Date(req.body.scheduledEnd) : new Date(start.getTime() + 60 * 60 * 1000),
          req.body.guestCount ?? 1,
          req.body.contactName || req.auth.user.displayName,
          req.body.contactEmail || req.auth.user.email,
          req.body.contactPhone || null,
          req.body.notes || null,
          listing.currency_code,
        ],
        connection
      );
      await execute(
        `INSERT INTO booking_status_history (booking_id, from_status, to_status, changed_by_user_id, changed_at)
         SELECT id, NULL, 'requested', ?, NOW(3) FROM bookings WHERE public_id = ?`,
        [req.auth.user.id, publicId],
        connection
      );
      return ref;
    });

    await notifyNewBooking({
      listing,
      booking: { id: null, reference, scheduledStart: req.body.scheduledStart },
    });
    return res.status(201).json(detailResponse({ id: publicId, reference, status: "requested" }));
  })
);

router.post(
  "/offers",
  writeLimiter,
  idempotency({ scope: "engagement" }),
  requireAuth,
  validate({
    body: z.object({
      listingId: z.string().min(1).max(64),
      amount: z.coerce.number().min(1).max(1e15),
      currency: z.string().trim().length(3).toUpperCase().optional(),
      message: z.string().trim().max(2000).optional(),
      conditions: z.string().trim().max(2000).optional(),
      subjectToFinance: z.boolean().optional(),
      subjectToSurvey: z.boolean().optional(),
      expiresAt: z.string().max(40).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await resolvePublicListing(req.body.listingId);
    const currency = req.body.currency || listing.currency_code;
    const publicId = ulid();

    const reference = await withTransaction(async (connection) => {
      const maxRef = await queryValue(
        "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM offers WHERE reference LIKE 'OF-%'",
        [],
        connection
      );
      const ref = `OF-${Number(maxRef || 3000) + 1}`;
      const baseRate = await queryValue(
        "SELECT rate FROM fx_rates_latest WHERE base_code = (SELECT code FROM currencies WHERE is_base = 1) AND quote_code = ? LIMIT 1",
        [currency],
        connection
      );
      const amountBase = Number(baseRate) > 0 ? Number((req.body.amount / Number(baseRate)).toFixed(2)) : req.body.amount;

      await execute(
        `INSERT INTO offers
           (public_id, reference, listing_id, buyer_user_id, buyer_name, buyer_email, buyer_phone,
            account_id, organization_id, agent_id, amount, currency_code, amount_base,
            is_subject_to_finance, is_subject_to_survey, conditions, message, status,
            expires_at, created_at)
         -- 'submitted' is the enum's first live state; 'new' is not a member of it, so this
         -- insert used to fail with "Data truncated for column 'status'" and no offer could
         -- ever be placed from the marketplace.
         VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted', ?, NOW(3))`,
        [
          publicId,
          ref,
          listing.id,
          req.auth.user.id,
          req.auth.user.displayName,
          req.auth.user.email,
          listing.account_id,
          listing.organization_id,
          listing.agent_id,
          req.body.amount,
          currency,
          amountBase,
          req.body.subjectToFinance ? 1 : 0,
          req.body.subjectToSurvey ? 1 : 0,
          req.body.conditions || null,
          req.body.message || null,
          req.body.expiresAt ? new Date(req.body.expiresAt) : new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
        ],
        connection
      );
      await execute(
        // offer_events records `created_at`, not `occurred_at`.
        `INSERT INTO offer_events (offer_id, event_type, to_status, actor_user_id, amount, note, created_at)
         SELECT id, 'submitted', 'submitted', ?, ?, ?, NOW(3) FROM offers WHERE public_id = ?`,
        [req.auth.user.id, req.body.amount, req.body.message || null, publicId],
        connection
      );
      return ref;
    });

    await notifyNewOffer({
      listing,
      offer: { id: null, reference, amount: req.body.amount, currency },
    });
    return res.status(201).json(detailResponse({ id: publicId, reference, status: "submitted" }));
  })
);

/* -------------------------------------------------------------------------- */
/* Listing view tracking                                                       */
/* -------------------------------------------------------------------------- */

/**
 * A listing view.
 *
 * Two writes, because two different questions are asked of them. `listings.view_count` answers
 * "how popular is this listing" and drives ordering. `listing_daily_stats` answers "what
 * happened last week" and is what every trend chart on the portal and the admin dashboards
 * reads — that table had no writer at all, so every trend line was frozen at the seed dates
 * regardless of real traffic.
 *
 * Anonymous by design; no session required. Failure is never surfaced: a view counter must not
 * be able to break the page it is counting.
 */
router.post(
  "/listings/:id/view",
  validate({ body: z.object({ visitorId: z.string().max(64).optional() }).partial() }),
  asyncHandler(async (req, res) => {
    const listing = await queryOne(
      `SELECT id, category_id, organization_id, agent_id FROM v_public_listings
        WHERE public_id = ? OR canonical_path = ? LIMIT 1`,
      [req.params.id, req.params.id]
    );
    if (!listing) return res.json(detailResponse({ counted: false }));

    // `listings.updated_at` is ON UPDATE CURRENT_TIMESTAMP, and the search projection's
    // staleness check is `listing_search.source_updated_at < listings.updated_at`.
    // Incrementing the view counter therefore marked the projection stale on every
    // page view — the integrity suite's "projection is stale relative to its source",
    // and needless reindexing work behind it. Assigning `updated_at` to itself keeps
    // the timestamp meaning "the listing changed", which a view is not.
    await execute(
      "UPDATE listings SET view_count = view_count + 1, updated_at = updated_at WHERE id = ?",
      [listing.id]
    );

    // One row per listing per day; the primary key makes the upsert the whole concurrency story.
    await execute(
      `INSERT INTO listing_daily_stats
         (listing_id, stat_date, impressions, views, unique_views, inquiries, favourites,
          organization_id, agent_id, category_id, computed_at)
       VALUES (?, CURDATE(), 0, 1, 1, 0, 0, ?, ?, ?, NOW(3))
       ON DUPLICATE KEY UPDATE views = views + 1, computed_at = NOW(3)`,
      [listing.id, listing.organization_id, listing.agent_id, listing.category_id]
    ).catch(() => {});

    return res.json(detailResponse({ counted: true }));
  })
);

/**
 * Project engagement events.
 *
 * `analytics_events` is polymorphic, so a project event is a row with
 * `subject_type = 'project'` rather than a second table. The event vocabulary is
 * an allow-list: an unknown type is dropped rather than stored, because an
 * analytics table that accepts anything a client sends stops being evidence.
 *
 * A project that cannot be resolved is answered with `counted: false` and no
 * row — an event with an undefined subject is worse than no event, since it
 * inflates totals that no one can then attribute.
 *
 * Anonymous by design and never fatal: instrumentation must not be able to
 * break the page it is instrumenting.
 */
const PROJECT_EVENT_TYPES = [
  "project_view",
  "gallery_open",
  "brochure_request",
  "floor_plan_request",
  "developer_click",
  "virtual_tour_open",
  "map_open",
  "share",
  "inquiry_start",
  "inquiry_submit",
  "contact_view",
];

router.post(
  "/projects/:id/events",
  validate({
    body: z.object({
      event: z.enum(PROJECT_EVENT_TYPES),
      visitorId: z.string().max(32).optional(),
      sessionId: z.string().max(32).optional(),
      path: z.string().max(500).optional(),
      properties: z.record(z.string().max(60), z.union([z.string().max(200), z.number(), z.boolean()])).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const reference = String(req.params.id).slice(0, 220);
    const project = await queryOne(
      `SELECT ps.project_id AS id, ps.country_id, ps.city_id, p.category_id, p.location_id, p.organization_id
         FROM project_search ps
         JOIN projects p ON p.id = ps.project_id
        WHERE ps.public_id = ? OR ps.slug = ? OR ps.canonical_path = ?
        LIMIT 1`,
      [reference, reference, reference]
    );
    if (!project) return res.json(detailResponse({ counted: false }));

    await execute(
      `INSERT INTO analytics_events
         (occurred_at, event_type, subject_type, subject_id, category_id, location_id, city_id, country_id,
          organization_id, user_id, visitor_id, session_id, device_type, url_path, properties)
       VALUES (NOW(3), ?, 'project', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'other', ?, ?)`,
      [
        req.body.event,
        project.id,
        project.category_id,
        project.location_id,
        project.city_id,
        project.country_id,
        project.organization_id,
        req.auth?.user?.id ?? null,
        req.body.visitorId || null,
        req.body.sessionId || null,
        (req.body.path || "").slice(0, 500) || null,
        req.body.properties ? JSON.stringify(req.body.properties) : null,
      ]
    ).catch(() => {});

    return res.json(detailResponse({ counted: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Notifications                                                               */
/* -------------------------------------------------------------------------- */

router.get(
  "/notifications",
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await query(
      `SELECT public_id, type, title, body, action_url, icon, read_at, created_at
         FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50`,
      [req.auth.user.id]
    );
    const unread = await queryValue("SELECT COUNT(*) FROM notifications WHERE user_id = ? AND read_at IS NULL", [
      req.auth.user.id,
    ]);
    return res.json({
      data: rows.map((row) => ({
        id: row.public_id,
        type: row.type,
        title: row.title,
        body: row.body,
        actionUrl: row.action_url,
        icon: row.icon,
        read: Boolean(row.read_at),
        createdAt: row.created_at,
      })),
      meta: { unreadCount: Number(unread || 0) },
    });
  })
);

router.post(
  "/notifications/read",
  requireAuth,
  validate({ body: z.object({ ids: z.array(z.string().max(40)).max(100).optional() }) }),
  asyncHandler(async (req, res) => {
    if (req.body.ids?.length) {
      await execute(
        `UPDATE notifications SET read_at = NOW(3)
          WHERE user_id = ? AND read_at IS NULL AND public_id IN (${req.body.ids.map(() => "?").join(", ")})`,
        [req.auth.user.id, ...req.body.ids]
      );
    } else {
      await execute("UPDATE notifications SET read_at = NOW(3) WHERE user_id = ? AND read_at IS NULL", [req.auth.user.id]);
    }
    return res.json(detailResponse({ read: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Reports                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * Reporting a listing.
 *
 * The public "Report" modal used to be `onFinish={() => message.success("Report
 * submitted.")}` — no request, no row, and a confirmation either way. The schema for
 * this has always existed (`reports`, `report_reasons`), so the surface is real now.
 *
 * Open to signed-out visitors, like the inquiry form, and rate-limited for the same
 * reason. The reporter's IP is stored for abuse handling; the reason must be one the
 * database actually defines for that subject type, so the UI cannot invent reasons.
 */
router.get(
  "/reports/reasons",
  asyncHandler(async (req, res) => {
    const subjectType = String(req.query.subjectType || "listing");
    const rows = await query(
      `SELECT id, code, name, description, is_severe
         FROM report_reasons
        WHERE is_active = 1 AND FIND_IN_SET(?, applies_to)
        ORDER BY sort_order ASC, name ASC`,
      [subjectType]
    );
    return res.json({
      data: rows.map((row) => ({
        id: row.code,
        code: row.code,
        label: row.name,
        description: row.description,
        severe: Boolean(row.is_severe),
      })),
    });
  })
);

const reportSchema = z.object({
  listingId: z.string().min(1).max(64),
  reasons: z.array(z.string().trim().max(60)).min(1, "Choose at least one reason.").max(6),
  details: z.string().trim().min(10, "Add a short detail.").max(2000),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255).optional().or(z.literal("")),
});

router.post(
  "/reports",
  writeLimiter,
  idempotency({ scope: "engagement" }),
  validate({ body: reportSchema }),
  asyncHandler(async (req, res) => {
    const listing = await resolvePublicListing(req.body.listingId);

    // Only reasons the database defines for a listing are accepted; the first is
    // recorded as the report's reason and the rest are kept in the details, because
    // `reports.reason_id` is a single column.
    // Placeholders are built explicitly: the driver runs prepared statements, which
    // do not expand an array into an IN list.
    const codes = [...new Set(req.body.reasons)];
    const reasons = await query(
      `SELECT id, code, name, is_severe FROM report_reasons
        WHERE is_active = 1 AND FIND_IN_SET('listing', applies_to)
          AND code IN (${codes.map(() => "?").join(", ")})`,
      codes
    );
    if (!reasons.length) throw AppError.badRequest("Choose a reason from the list.");

    const publicId = ulid();
    const details = [
      req.body.details,
      reasons.length > 1 ? `Reported for: ${reasons.map((row) => row.name).join(", ")}` : null,
    ]
      .filter(Boolean)
      .join("\n\n")
      .slice(0, 2000);

    const reference = await withTransaction(async (connection) => {
      const maxRef = await queryValue(
        "SELECT MAX(CAST(SUBSTRING(reference, 5) AS UNSIGNED)) FROM reports WHERE reference LIKE 'RPT-%'",
        [],
        connection
      );
      const ref = `RPT-${Number(maxRef || 5000) + 1}`;
      await execute(
        `INSERT INTO reports
           (public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details,
            reporter_user_id, reporter_email, reporter_ip, status, priority, report_count, created_at)
         VALUES (?, ?, 'listing', ?, CAST(? AS JSON), ?, ?, ?, ?, INET6_ATON(?), 'new', ?, 1, NOW(3))`,
        [
          publicId,
          ref,
          listing.id,
          JSON.stringify({ reference: listing.reference, title: listing.title }),
          reasons[0].id,
          details,
          req.auth?.user?.id ?? null,
          req.body.email || null,
          // `reporter_ip` is varbinary(16); INET6_ATON does the encoding and returns
          // NULL for anything malformed, so a strange proxy header cannot break the write.
          req.ip ? String(req.ip).replace(/^::ffff:/, "") : null,
          reasons.some((row) => row.is_severe) ? "high" : "normal",
        ],
        connection
      );
      return ref;
    });

    return res.status(201).json(detailResponse({ id: publicId, reference }));
  })
);

/* -------------------------------------------------------------------------- */
/* Public contact                                                              */
/* -------------------------------------------------------------------------- */

/**
 * The public contact form.
 *
 * `/contact-us` rendered a complete form that submitted nowhere and said so:
 * "Online form delivery is not connected yet." The schema for this already existed —
 * `support_tickets` with `channel = 'web_form'` and a `support_queues` row per topic —
 * so the form now opens a real ticket.
 *
 * Open to signed-out visitors and rate-limited, like the inquiry and report forms.
 */
const CONTACT_TOPICS = {
  buying: { queue: "consumer", type: "question", subject: "Buying inquiry" },
  company: { queue: "agency", type: "question", subject: "Company profile" },
  listing: { queue: "consumer", type: "problem", subject: "Listing question" },
  partnership: { queue: "agency", type: "other", subject: "Partnership" },
  billing: { queue: "billing", type: "billing", subject: "Billing question" },
  abuse: { queue: "abuse", type: "abuse_report", subject: "Trust and safety" },
};

router.get(
  "/contact/topics",
  asyncHandler(async (_req, res) =>
    res.json({
      data: Object.entries(CONTACT_TOPICS).map(([value, topic]) => ({ value, label: topic.subject })),
    })
  )
);

const contactSchema = z.object({
  name: z.string().trim().min(1, "Enter your name.").max(200),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  topic: z.enum(Object.keys(CONTACT_TOPICS)),
  message: z.string().trim().min(10, "Write a short message.").max(5000),
  consent: z.literal(true, { errorMap: () => ({ message: "Please agree to be contacted." }) }),
});

router.post(
  "/contact",
  writeLimiter,
  idempotency({ scope: "engagement" }),
  validate({ body: contactSchema }),
  asyncHandler(async (req, res) => {
    const topic = CONTACT_TOPICS[req.body.topic];
    const queueId = await queryValue("SELECT id FROM support_queues WHERE code = ? LIMIT 1", [topic.queue]);
    if (!queueId) throw AppError.badRequest("That topic is not available right now.");

    const publicId = ulid();
    const reference = await withTransaction(async (connection) => {
      const maxRef = await queryValue(
        "SELECT MAX(CAST(SUBSTRING(reference, 5) AS UNSIGNED)) FROM support_tickets WHERE reference LIKE 'SUP-%'",
        [],
        connection
      );
      const ref = `SUP-${Number(maxRef || 8000) + 1}`;
      await execute(
        `INSERT INTO support_tickets
           (public_id, reference, queue_id, subject, description, requester_user_id,
            requester_name, requester_email, ticket_type, category, priority, status,
            channel, message_count, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'normal', 'new', 'web_form', 1, NOW(3))`,
        [
          publicId,
          ref,
          queueId,
          topic.subject,
          req.body.message,
          req.auth?.user?.id ?? null,
          req.body.name,
          req.body.email,
          topic.type,
          req.body.topic,
        ],
        connection
      );
      return ref;
    });

    return res.status(201).json(detailResponse({ id: publicId, reference }));
  })
);

/* -------------------------------------------------------------------------- */
/* Newsletter                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * The footer newsletter form.
 *
 * The footer rendered an email field and a submit arrow with no handler at all —
 * typing an address and pressing it did nothing, silently. `newsletter_subscribers`
 * has always existed, so the form now records a real subscription.
 *
 * Status is `pending`, not `subscribed`: a double opt-in is the correct default, and
 * claiming someone is subscribed before they confirm would be the same class of lie
 * this replaces. Re-subscribing an existing address is idempotent rather than an
 * error, so the form cannot be used to probe who is already on the list.
 */
const newsletterSchema = z.object({
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  source: z.string().trim().max(80).optional(),
});

router.post(
  "/newsletter/subscribe",
  writeLimiter,
  validate({ body: newsletterSchema }),
  asyncHandler(async (req, res) => {
    const existing = await queryOne(
      "SELECT id, status FROM newsletter_subscribers WHERE email = ? LIMIT 1",
      [req.body.email]
    );

    if (existing) {
      // Already unsubscribed? Put them back to pending so the confirmation can run
      // again. Otherwise leave the record exactly as it is.
      if (existing.status === "unsubscribed") {
        await execute(
          "UPDATE newsletter_subscribers SET status = 'pending', unsubscribed_at = NULL, updated_at = NOW(3) WHERE id = ?",
          [existing.id]
        );
      }
      return res.status(202).json(detailResponse({ status: "pending" }));
    }

    await execute(
      `INSERT INTO newsletter_subscribers
         (public_id, email, user_id, status, source, ip_address, unsubscribe_token, created_at)
       VALUES (?, ?, ?, 'pending', ?, INET6_ATON(?), ?, NOW(3))`,
      [
        ulid(),
        req.body.email,
        req.auth?.user?.id ?? null,
        req.body.source || "footer",
        req.ip ? String(req.ip).replace(/^::ffff:/, "") : null,
        // `unsubscribe_token` is char(32); 16 bytes of hex is exactly 32 characters.
        // `randomToken` returns base64url, which is 22 characters for 16 bytes.
        crypto.randomBytes(16).toString("hex"),
      ]
    );

    return res.status(201).json(detailResponse({ status: "pending" }));
  })
);

export default router;
