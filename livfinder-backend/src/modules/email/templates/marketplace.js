import { area, dateOnly, dateTime, firstName, money, plural, priceLine, siteUrl, truncate } from "../format.js";

/** Listings and developments, leads, offers, viewings, chat, reviews, alerts and reports. */

const SAMPLE_LISTING = {
  title: "Signature Villa, Palm Jumeirah",
  url: siteUrl("/real-estate/sample"),
  portalUrl: siteUrl("/portal/listings/sample"),
  image: null,
  price: 42000000,
  currency: "AED",
  priceBase: 42000000,
  facts: ["Villa", "7 beds", "9 baths"],
  areaSqft: 14800,
  reference: "LF-RE-10482",
};

export function listingCard(listing, ctx, extra = {}) {
  if (!listing) return null;
  return {
    type: "listing",
    title: listing.title || listing.reference || "Your listing",
    url: extra.url ?? listing.url,
    image: listing.image,
    price: listing.price !== undefined && listing.price !== null ? priceLine(listing, ctx.recipient, ctx.rates) : null,
    facts: [...(listing.facts ?? []), listing.areaSqft ? area(listing.areaSqft, ctx.recipient.areaUnit) : null].filter(Boolean),
    reference: listing.reference,
    status: extra.status,
    statusTone: extra.statusTone,
  };
}

const DECISIONS = {
  approve: { subject: "Your listing is live", tone: "success", status: "Live", text: "LivFinder approved your listing. It is now live on the marketplace." },
  reject: { subject: "Your listing was not approved", tone: "critical", status: "Not approved", text: "LivFinder could not approve your listing. Fix the points below and submit it again." },
  unpublish: { subject: "Your listing was unpublished", tone: "warning", status: "Unpublished", text: "LivFinder took your listing off the marketplace." },
  archive: { subject: "Your listing was archived", tone: "warning", status: "Archived", text: "LivFinder archived your listing. It is no longer on the marketplace." },
  flag: { subject: "Your listing was flagged for review", tone: "warning", status: "Under review", text: "Your listing was flagged and is being reviewed. It may be hidden until the review is finished." },
};

export default {
  "listings.decision": {
    category: "listings",
    digestible: true,
    label: "Listing or development decision",
    render: (d, ctx) => {
      const wording = DECISIONS[d.decision] ?? DECISIONS.flag;
      const noun = d.kind === "development" ? "development" : "listing";
      return {
        subject: `${wording.subject.replace("listing", noun)}: ${d.listing.title}`,
        preheader: d.reason ? truncate(d.reason, 90) : wording.text,
        heading: wording.subject.replace("listing", noun),
        blocks: [
          { type: "p", text: wording.text.replace(/listing/g, noun) },
          listingCard(d.listing, ctx, { status: wording.status, statusTone: wording.tone }),
          d.reason ? { type: "quote", text: d.reason, by: "LivFinder review team" } : null,
          { type: "button", label: d.decision === "approve" ? `View your ${noun}` : `Open the ${noun}`, url: d.decision === "approve" ? d.listing.url : d.listing.portalUrl },
        ],
      };
    },
    sample: { decision: "reject", listing: SAMPLE_LISTING, reason: "The photos show a different property. Upload photos of this villa." },
  },

  "listings.revision_decision": {
    category: "listings",
    digestible: true,
    label: "Changes to a live listing or development",
    render: (d, ctx) => {
      const noun = d.kind === "development" ? "development" : "listing";
      return {
        subject: d.approved ? `Your changes to ${d.listing.title} are live` : `Your changes to ${d.listing.title} need attention`,
        preheader: d.approved ? `The ${noun} now shows your changes.` : `The ${noun} still shows the last approved version.`,
        heading: d.approved ? "Your changes are live" : "Your changes need attention",
        blocks: d.approved
          ? [
              { type: "p", text: `LivFinder approved your changes. The ${noun} now shows them.` },
              listingCard(d.listing, ctx, { status: "Live", statusTone: "success" }),
              { type: "button", label: `View the ${noun}`, url: d.listing.portalUrl },
            ]
          : [
              { type: "p", text: `LivFinder did not approve your latest changes. The ${noun} still shows the last approved version.` },
              listingCard(d.listing, ctx),
              d.reason ? { type: "quote", text: `Reason: ${d.reason}`, by: "LivFinder review team" } : null,
              d.issues?.length ? { type: "issues", items: d.issues } : null,
              { type: "button", label: `Fix the ${noun}`, url: d.listing.portalUrl, note: `Save the ${noun} again to resubmit it.` },
            ],
      };
    },
    sample: { approved: false, kind: "listing", listing: SAMPLE_LISTING, reason: "The price does not match the brochure.", issues: [{ label: "Price", reasons: ["Enter the asking price, not the service charge."] }] },
  },

  "listings.expiring": {
    category: "listings",
    digestible: true,
    label: "Listing expiring soon",
    render: (d, ctx) => ({
      subject: d.days <= 1 ? `${d.listing.title} expires tomorrow` : `${d.listing.title} expires in ${d.days} days`,
      preheader: `Renew it to keep it on LivFinder after ${dateOnly(d.expiresAt, ctx.recipient.timezone)}.`,
      heading: d.days <= 1 ? "Your listing expires tomorrow" : `Your listing expires in ${d.days} days`,
      blocks: [
        { type: "p", text: `Your listing comes off LivFinder on **${dateTime(d.expiresAt, ctx.recipient.timezone)}**. Renew it now to keep it live without a gap.` },
        listingCard(d.listing, ctx, { status: `Expires ${dateOnly(d.expiresAt, ctx.recipient.timezone)}`, statusTone: "warning" }),
        { type: "button", label: "Renew listing", url: d.listing.portalUrl },
      ],
    }),
    sample: { listing: SAMPLE_LISTING, days: 7, expiresAt: new Date(Date.now() + 7 * 864e5).toISOString() },
  },

  "listings.expired": {
    category: "listings",
    digestible: true,
    label: "Listing expired",
    render: (d, ctx) => ({
      subject: `${d.listing.title} has expired`,
      preheader: "It is no longer on LivFinder. Renew it to bring it back.",
      heading: "Your listing has expired",
      blocks: [
        { type: "p", text: "Your listing reached the end of its period and is no longer shown on LivFinder. Its slot is free again." },
        listingCard(d.listing, ctx, { status: "Expired", statusTone: "critical" }),
        { type: "button", label: "Renew listing", url: d.listing.portalUrl },
      ],
    }),
    sample: { listing: SAMPLE_LISTING },
  },

  "leads.new_enquiry": {
    category: "leads",
    digestible: true,
    priority: 2,
    label: "New enquiry (to seller)",
    render: (d, ctx) => ({
      subject: `New enquiry ${d.reference} — ${d.listing?.title ?? "your listing"}`,
      preheader: `${d.lead.name} asked about ${d.listing?.title ?? "your listing"}.`,
      heading: "You have a new enquiry",
      blocks: [
        { type: "p", text: `**${d.lead.name}** asked about ${d.kind === "development" ? "your development" : "your listing"}. Buyers who get a reply within an hour are far more likely to book a viewing.` },
        { type: "lead", name: d.lead.name, email: d.lead.email, phone: d.lead.phone, message: d.lead.message, receivedAt: dateTime(d.receivedAt, ctx.recipient.timezone) },
        listingCard(d.listing, ctx),
        { type: "button", label: `Reply to ${firstName({ name: d.lead.name })}`, url: d.url, note: "You can also reply to this email to write to the buyer directly." },
      ],
    }),
    sample: { reference: "INQ-24518", lead: { name: "Ahmed Khan", email: "ahmed@example.com", phone: "+971 50 123 4567", message: "Is the villa still available? We would like to view it this weekend." }, receivedAt: new Date().toISOString(), listing: SAMPLE_LISTING, url: siteUrl("/portal/inquiries") },
  },

  "leads.enquiry_receipt": {
    category: "receipts",
    label: "Enquiry sent (to the enquirer)",
    render: (d, ctx) => ({
      subject: `Your enquiry about ${d.listing?.title ?? "a listing"} was sent`,
      preheader: `${d.sellerName} will reply to you directly.`,
      heading: "Your enquiry was sent",
      blocks: [
        { type: "p", text: `Hi ${firstName(ctx.recipient)}, we sent your enquiry to **${d.sellerName}**. They will reply to you by email or phone.` },
        listingCard(d.listing, ctx),
        { type: "table", rows: [["Reference", d.reference], ["Sent", dateTime(d.sentAt, ctx.recipient.timezone)]] },
        d.message ? { type: "quote", text: truncate(d.message, 400), by: "Your message" } : null,
        { type: "button", label: "View the listing", url: d.listing?.url ?? siteUrl("/"), tone: "secondary" },
      ],
      reason: "You get this because you sent an enquiry on LivFinder.",
    }),
    sample: { listing: SAMPLE_LISTING, sellerName: "Example Realty", reference: "INQ-24518", sentAt: new Date().toISOString(), message: "Is the villa still available?" },
  },

  "leads.offer_received": {
    category: "leads",
    priority: 2,
    label: "Offer received (to seller)",
    render: (d, ctx) => ({
      subject: `Offer received on ${d.listing.title}: ${money(d.amount, d.currency)}`,
      preheader: `${d.buyerName} made an offer.`,
      heading: "You received an offer",
      blocks: [
        { type: "p", text: `**${d.buyerName}** made an offer on your listing.` },
        { type: "table", rows: [["Offer", money(d.amount, d.currency)], ["Asking price", money(d.listing.price, d.listing.currency) ?? "—"], ["Reference", d.reference], d.expiresAt ? ["Valid until", dateTime(d.expiresAt, ctx.recipient.timezone)] : null].filter(Boolean) },
        d.message ? { type: "quote", text: d.message, by: d.buyerName } : null,
        listingCard(d.listing, ctx),
        { type: "button", label: "Review the offer", url: siteUrl("/portal/offers") },
      ],
    }),
    sample: { buyerName: "Ahmed Khan", amount: 39500000, currency: "AED", reference: "OFR-1182", listing: SAMPLE_LISTING, message: "Cash buyer, ready to close within 30 days." },
  },

  "leads.offer_receipt": {
    category: "receipts",
    label: "Offer sent (to the buyer)",
    render: (d, ctx) => ({
      subject: `Your offer on ${d.listing.title} was sent`,
      preheader: `${d.sellerName} will reply to you.`,
      heading: "Your offer was sent",
      blocks: [
        { type: "p", text: `We sent your offer of **${money(d.amount, d.currency)}** to **${d.sellerName}**.` },
        listingCard(d.listing, ctx),
        { type: "table", rows: [["Reference", d.reference], ["Offer", money(d.amount, d.currency)]] },
      ],
      reason: "You get this because you made an offer on LivFinder.",
    }),
    sample: { amount: 39500000, currency: "AED", sellerName: "Example Realty", reference: "OFR-1182", listing: SAMPLE_LISTING },
  },

  "leads.unanswered": {
    category: "leads",
    label: "Unanswered enquiries reminder",
    render: (d) => ({
      subject: `${plural(d.count, "enquiry", "enquiries")} waiting for a reply`,
      preheader: "Buyers are waiting to hear from you.",
      heading: `${plural(d.count, "enquiry", "enquiries")} waiting for a reply`,
      blocks: [
        { type: "p", text: "These buyers have not had a reply for more than a day. A quick answer keeps the lead warm and your response score high." },
        ...d.leads.slice(0, 10).map((lead) => ({ type: "lead", name: lead.name, about: lead.about, receivedAt: lead.age })),
        d.count > 10 ? { type: "p", text: `…and ${d.count - 10} more.` } : null,
        { type: "button", label: "Open enquiries", url: siteUrl("/portal/inquiries") },
      ],
    }),
    sample: { count: 2, leads: [{ name: "Ahmed Khan", about: "Signature Villa, Palm Jumeirah", age: "2 days ago" }, { name: "Lena Fischer", about: "Riva Aquariva 33", age: "1 day ago" }] },
  },

  "viewings.requested": {
    category: "viewings",
    priority: 2,
    label: "Viewing requested (to seller)",
    render: (d, ctx) => ({
      subject: `Viewing requested for ${d.listing.title}`,
      preheader: `${d.customerName} asked for ${d.when ? dateTime(d.when, ctx.recipient.timezone) : "a viewing"}.`,
      heading: "Someone wants to view your listing",
      blocks: [
        { type: "p", text: `**${d.customerName}** asked for a ${d.typeLabel?.toLowerCase() ?? "viewing"}. Confirm the time or suggest another from your portal.` },
        { type: "event", title: d.listing.title, when: d.when ? dateTime(d.when, ctx.recipient.timezone) : "Time to be agreed", lines: [d.customerEmail, d.customerPhone, `Reference ${d.reference}`].filter(Boolean) },
        d.notes ? { type: "quote", text: d.notes, by: d.customerName } : null,
        { type: "button", label: "Confirm or reschedule", url: siteUrl("/portal/bookings") },
      ],
    }),
    sample: { customerName: "Ahmed Khan", customerEmail: "ahmed@example.com", customerPhone: "+971 50 123 4567", when: new Date(Date.now() + 2 * 864e5).toISOString(), reference: "BKG-3381", typeLabel: "Viewing", listing: SAMPLE_LISTING },
  },

  "viewings.request_receipt": {
    category: "receipts",
    label: "Viewing request sent (to the customer)",
    render: (d, ctx) => ({
      subject: `Your viewing request for ${d.listing.title} was sent`,
      preheader: `${d.sellerName} will confirm the time.`,
      heading: "Your viewing request was sent",
      blocks: [
        { type: "p", text: `We sent your request to **${d.sellerName}**. You will get a calendar invite as soon as they confirm.` },
        { type: "event", title: d.listing.title, when: d.when ? dateTime(d.when, ctx.recipient.timezone) : "Time to be agreed", lines: [`Reference ${d.reference}`] },
      ],
      reason: "You get this because you asked for a viewing on LivFinder.",
    }),
    sample: { sellerName: "Example Realty", when: new Date(Date.now() + 2 * 864e5).toISOString(), reference: "BKG-3381", listing: SAMPLE_LISTING },
  },

  "viewings.confirmed": {
    // A confirmed time is a booking record, not a notification preference: it always sends.
    category: "receipts",
    priority: 2,
    label: "Viewing confirmed or cancelled (calendar invite)",
    render: (d, ctx) => ({
      subject: `${d.cancelled ? "Cancelled" : "Confirmed"}: ${d.summary}`,
      preheader: d.cancelled ? "This viewing has been cancelled." : `${dateTime(d.start, ctx.recipient.timezone)}. The invite is attached.`,
      heading: d.cancelled ? "Viewing cancelled" : d.moved ? "Viewing moved" : "Viewing confirmed",
      blocks: [
        d.cancelled ? { type: "alert", tone: "warning", text: "This has been cancelled. The attached update removes it from your calendar." } : { type: "p", text: "The attached invite adds this to your calendar." },
        { type: "event", title: d.summary, when: dateTime(d.start, ctx.recipient.timezone), location: d.location, lines: d.lines },
        d.url ? { type: "button", label: d.cancelled ? "View details" : "Open booking", url: d.url, tone: "secondary" } : null,
      ],
    }),
    sample: { summary: "Viewing: Signature Villa, Palm Jumeirah", start: new Date(Date.now() + 2 * 864e5).toISOString(), location: "Frond K, Palm Jumeirah", lines: ["Booking BKG-3381", "With: Example Realty", "Phone: +971 4 000 0000"] },
  },

  "viewings.reminder": {
    category: "viewings",
    label: "Viewing reminder",
    render: (d, ctx) => ({
      subject: `Reminder: ${d.summary} ${d.hours <= 2 ? "in 2 hours" : "tomorrow"}`,
      preheader: dateTime(d.start, ctx.recipient.timezone),
      heading: d.hours <= 2 ? "Your viewing starts soon" : "Your viewing is tomorrow",
      blocks: [
        { type: "event", title: d.summary, when: dateTime(d.start, ctx.recipient.timezone), location: d.location, lines: d.lines },
        d.url ? { type: "button", label: "Open booking", url: d.url, tone: "secondary" } : null,
      ],
    }),
    sample: { summary: "Viewing: Signature Villa, Palm Jumeirah", hours: 24, start: new Date(Date.now() + 864e5).toISOString(), location: "Frond K, Palm Jumeirah", lines: ["With: Example Realty"] },
  },

  "chat.message": {
    category: "messages",
    label: "New chat message while offline",
    render: (d) => ({
      subject: `New message from ${d.senderName} — ${d.about}`,
      preheader: truncate(d.preview, 100),
      heading: `${d.senderName} sent you a message`,
      blocks: [
        { type: "quote", text: d.preview, by: d.senderName },
        { type: "button", label: "Reply", url: d.url },
        { type: "p", text: d.guest ? "This link signs you in to the chat on this device. Do not forward it." : "You are receiving this because you were not online when the message arrived. We send at most one email every 15 minutes per conversation." },
      ],
    }),
    sample: { senderName: "Ahmed Khan", about: "Signature Villa, Palm Jumeirah", preview: "Hi, could we move the viewing to 5pm?", url: siteUrl("/portal/messages") },
  },

  "reviews.received": {
    category: "reviews",
    label: "New review",
    render: (d) => ({
      subject: `New ${d.rating}-star review`,
      preheader: truncate(d.body, 90),
      heading: "You have a new review",
      blocks: [
        { type: "p", text: `${"★".repeat(Math.max(0, Math.min(5, d.rating)))}${"☆".repeat(Math.max(0, 5 - d.rating))}` },
        d.body ? { type: "quote", text: d.body, by: d.author } : null,
        { type: "button", label: "Read and reply", url: siteUrl("/portal/reviews") },
      ],
    }),
    sample: { rating: 5, body: "Very professional and quick to arrange viewings.", author: "Ahmed K." },
  },

  "alerts.saved_search": {
    category: "alerts",
    label: "Saved search matches",
    render: (d, ctx) => ({
      subject: `${plural(d.count, "new match", "new matches")} for “${d.searchName}”`,
      preheader: d.listings[0]?.title ?? "New listings match your search.",
      heading: `New matches for “${d.searchName}”`,
      blocks: [
        ...d.listings.slice(0, 6).map((listing) => listingCard(listing, ctx)),
        { type: "button", label: d.count > 6 ? `See all ${d.count}` : "See the search", url: d.url },
      ],
    }),
    sample: { searchName: "Villas in Palm Jumeirah", count: 3, listings: [SAMPLE_LISTING], url: siteUrl("/real-estate") },
  },

  "alerts.price_drop": {
    category: "alerts",
    label: "Price drop on a favourite",
    render: (d, ctx) => ({
      subject: `Price drop: ${d.listing.title}`,
      preheader: `Now ${money(d.newPrice, d.listing.currency)}, down from ${money(d.oldPrice, d.listing.currency)}.`,
      heading: "A favourite just dropped in price",
      blocks: [
        { type: "table", rows: [["Was", money(d.oldPrice, d.listing.currency)], ["Now", money(d.newPrice, d.listing.currency)], ["Change", `${Number(d.changePercent).toFixed(1)}%`]] },
        listingCard(d.listing, ctx),
        { type: "button", label: "View the listing", url: d.listing.url },
      ],
    }),
    sample: { oldPrice: 45000000, newPrice: 42000000, changePercent: -6.7, listing: SAMPLE_LISTING },
  },

  "reports.weekly": {
    category: "reports",
    label: "Weekly performance",
    render: (d, ctx) => ({
      subject: `Your week on LivFinder: ${plural(d.views, "view")}, ${plural(d.enquiries, "enquiry", "enquiries")}`,
      preheader: `${dateOnly(d.from, ctx.recipient.timezone)} to ${dateOnly(d.to, ctx.recipient.timezone)}`,
      heading: "Your week on LivFinder",
      blocks: [
        { type: "stats", items: [
          { label: "Views", value: Number(d.views).toLocaleString("en-US"), change: d.viewsChange },
          { label: "Enquiries", value: Number(d.enquiries).toLocaleString("en-US"), change: d.enquiriesChange },
          { label: "Live listings", value: Number(d.live).toLocaleString("en-US") },
        ] },
        d.top?.length ? { type: "h", text: "Most viewed" } : null,
        ...(d.top ?? []).slice(0, 3).map((listing) => listingCard(listing, ctx, { status: `${plural(listing.views, "view")}`, statusTone: "info" })),
        { type: "button", label: "Open analytics", url: siteUrl("/portal/analytics"), tone: "secondary" },
      ],
    }),
    sample: { views: 1240, enquiries: 18, live: 12, viewsChange: "+12%", enquiriesChange: "-5%", from: new Date(Date.now() - 7 * 864e5).toISOString(), to: new Date().toISOString(), top: [{ ...SAMPLE_LISTING, views: 410 }] },
  },
};
