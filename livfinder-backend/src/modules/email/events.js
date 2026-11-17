import logger from "../../config/logger.js";
import { queryOne } from "../../db/query.js";
import { siteUrl } from "./format.js";
import { accountUsers, developmentSummary, emailUsers, listingSummary, queueEmail } from "./send.js";

/**
 * Emails for marketplace events. Each one loads its record fresh after the request committed it,
 * emails the seller side and the buyer side, and never throws into the request that caused it.
 */

const safe = (label, work) =>
  work().catch((error) => {
    logger.warn({ err: error }, `${label} email not queued`);
    return 0;
  });

async function sellerName({ organizationId, agentId, accountId }) {
  const row = await queryOne(
    `SELECT COALESCE(
        (SELECT name FROM organizations WHERE id = ?),
        (SELECT display_name FROM agents WHERE id = ?),
        (SELECT u.display_name FROM accounts a JOIN users u ON u.id = a.owner_user_id WHERE a.id = ?),
        'the seller') AS name`,
    [organizationId ?? 0, agentId ?? 0, accountId ?? 0]
  );
  return row?.name ?? "the seller";
}

/** A new enquiry: the agent and the account's owners and managers, then a receipt for the buyer. */
export function emailNewInquiry(inquiryId) {
  return safe("enquiry", async () => {
    const inquiry = await queryOne(
      `SELECT i.*, l.contact_email AS listing_contact_email FROM inquiries i LEFT JOIN listings l ON l.id = i.listing_id WHERE i.id = ?`,
      [inquiryId]
    );
    if (!inquiry || inquiry.is_spam) return 0;
    const kind = inquiry.listing_id ? "listing" : "development";
    const subject = inquiry.listing_id ? await listingSummary(inquiry.listing_id) : inquiry.project_id ? await developmentSummary(inquiry.project_id) : null;
    const data = {
      kind,
      reference: inquiry.reference,
      receivedAt: inquiry.created_at,
      listing: subject,
      lead: { name: inquiry.name, email: inquiry.email, phone: inquiry.phone, message: inquiry.message },
      url: siteUrl("/portal/inquiries"),
    };
    const recipients = await accountUsers({ accountId: inquiry.account_id, organizationId: inquiry.organization_id, agentId: inquiry.agent_id ?? inquiry.assigned_to_agent_id });
    let queued = await emailUsers(recipients, "leads.new_enquiry", data, { accountId: inquiry.account_id, replyTo: inquiry.email, dedupeKey: `leads.new_enquiry:${inquiry.id}` });
    // The listing's own contact address, when it is not one of those people (e.g. a shared inbox).
    const contact = inquiry.listing_contact_email?.toLowerCase();
    if (contact && !recipients.some((user) => user.email.toLowerCase() === contact)) {
      if (await queueEmail({ template: "leads.new_enquiry", to: contact, accountId: inquiry.account_id, data, replyTo: inquiry.email, dedupeKey: `leads.new_enquiry:${inquiry.id}:contact` })) queued += 1;
    }
    if (inquiry.email) {
      const name = await sellerName({ organizationId: inquiry.organization_id, agentId: inquiry.agent_id, accountId: inquiry.account_id });
      if (
        await queueEmail({
          template: "leads.enquiry_receipt",
          to: inquiry.email,
          toName: inquiry.name,
          userId: inquiry.user_id,
          data: { listing: subject, sellerName: name, reference: inquiry.reference, sentAt: inquiry.created_at, message: inquiry.message },
          dedupeKey: `leads.enquiry_receipt:${inquiry.id}`,
        })
      ) queued += 1;
    }
    return queued;
  });
}

const BOOKING_TYPES = { viewing: "Viewing", inspection: "Inspection", test_drive: "Test drive", sea_trial: "Sea trial", demo_flight: "Demo flight", consultation: "Consultation", appointment: "Appointment" };

/** A viewing request: the seller is asked to confirm, the customer gets a receipt. */
export function emailNewBooking(bookingPublicId) {
  return safe("viewing request", async () => {
    const booking = await queryOne("SELECT * FROM bookings WHERE public_id = ?", [bookingPublicId]);
    if (!booking) return 0;
    const listing = booking.listing_id ? await listingSummary(booking.listing_id) : { title: booking.reference };
    const recipients = await accountUsers({ accountId: booking.account_id, organizationId: booking.organization_id, agentId: booking.agent_id });
    let queued = await emailUsers(
      recipients,
      "viewings.requested",
      {
        listing,
        customerName: booking.contact_name ?? "A customer",
        customerEmail: booking.contact_email,
        customerPhone: booking.contact_phone,
        when: booking.scheduled_start,
        reference: booking.reference,
        typeLabel: BOOKING_TYPES[booking.booking_type] ?? "Viewing",
        notes: booking.notes,
      },
      { accountId: booking.account_id, replyTo: booking.contact_email, dedupeKey: `viewings.requested:${booking.id}` }
    );
    if (booking.contact_email) {
      const name = await sellerName({ organizationId: booking.organization_id, agentId: booking.agent_id, accountId: booking.account_id });
      if (
        await queueEmail({
          template: "viewings.request_receipt",
          to: booking.contact_email,
          toName: booking.contact_name,
          userId: booking.user_id,
          data: { listing, sellerName: name, when: booking.scheduled_start, reference: booking.reference },
          dedupeKey: `viewings.request_receipt:${booking.id}`,
        })
      ) queued += 1;
    }
    return queued;
  });
}

/** An offer: the seller side, and a receipt to the buyer. */
export function emailNewOffer(offerPublicId) {
  return safe("offer", async () => {
    const offer = await queryOne("SELECT * FROM offers WHERE public_id = ?", [offerPublicId]);
    if (!offer) return 0;
    const listing = await listingSummary(offer.listing_id);
    const recipients = await accountUsers({ accountId: offer.account_id, organizationId: offer.organization_id, agentId: offer.agent_id });
    const data = { listing, buyerName: offer.buyer_name ?? "A buyer", amount: offer.amount, currency: offer.currency_code, reference: offer.reference, message: offer.message, expiresAt: offer.expires_at };
    let queued = await emailUsers(recipients, "leads.offer_received", data, { accountId: offer.account_id, replyTo: offer.buyer_email, dedupeKey: `leads.offer_received:${offer.id}` });
    if (offer.buyer_email) {
      const name = await sellerName({ organizationId: offer.organization_id, agentId: offer.agent_id, accountId: offer.account_id });
      if (
        await queueEmail({
          template: "leads.offer_receipt",
          to: offer.buyer_email,
          toName: offer.buyer_name,
          userId: offer.buyer_user_id,
          data: { listing, sellerName: name, amount: offer.amount, currency: offer.currency_code, reference: offer.reference },
          dedupeKey: `leads.offer_receipt:${offer.id}`,
        })
      ) queued += 1;
    }
    return queued;
  });
}

/** A moderation decision on a listing: owners, managers and the listing's agent. */
export function emailListingDecision({ listing, decision, reason }) {
  return safe("listing decision", async () => {
    const summary = await listingSummary(listing.id);
    const recipients = await accountUsers({ accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id });
    return emailUsers(recipients, "listings.decision", { decision, reason: reason || null, listing: summary, kind: "listing" }, { accountId: listing.account_id });
  });
}

/** A moderation decision on a development: the developer's owners and managers. */
export function emailDevelopmentDecision({ projectId, decision, reason }) {
  return safe("development decision", async () => {
    const project = await queryOne("SELECT id, organization_id FROM projects WHERE id = ?", [projectId]);
    if (!project) return 0;
    const account = await queryOne("SELECT account_id FROM organizations WHERE id = ?", [project.organization_id]);
    const summary = await developmentSummary(project.id);
    const recipients = await accountUsers({ accountId: account?.account_id, organizationId: project.organization_id });
    return emailUsers(recipients, "listings.decision", { decision, reason: reason || null, listing: summary, kind: "development" }, { accountId: account?.account_id });
  });
}

/**
 * A seller application arrived. Staff who review that kind are told; an existing member who
 * applied through Become a seller gets a receipt (a new signup's welcome email says it instead).
 */
export function emailApplicationSubmitted({ userId, sellerType, applicantName, companyName = null, receipt = false }) {
  return safe("application", async () => {
    let queued = 0;
    if (receipt) {
      const { emailUser } = await import("./send.js");
      queued += await emailUser(userId, "applications.received", { sellerType });
    }
    const { emailStaff } = await import("./send.js");
    const company = sellerType === "company" || sellerType === "developer";
    queued += await emailStaff(company ? "companies.verify" : "individuals.verify", {
      title: `New ${sellerType === "developer" ? "developer" : company ? "company" : "individual seller"} application${companyName ? `: ${companyName}` : ""}`,
      summary: `${applicantName || "Someone"} applied to sell on LivFinder.`,
      rows: [["Applicant", applicantName || "—"], companyName ? ["Company", companyName] : null, ["Type", sellerType === "developer" ? "Developer" : company ? "Company" : "Individual"]].filter(Boolean),
      url: company ? "/admin/companies?status=pending" : "/admin/individuals?status=pending",
      actionLabel: "Review application",
    });
    return queued;
  });
}

/** Category access decided by staff. */
export function emailCategoryAccessDecision({ accountId, categoryName, approved, note, listingQuota }) {
  return safe("category access", async () =>
    (await import("./send.js")).emailAccount({ accountId, roles: ["owner"] }, "applications.category_access", { approved, categoryName, note: note || null, listingQuota: listingQuota || null })
  );
}
