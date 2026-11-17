import { CATEGORIES } from "../catalog.js";
import { dateOnly, dateTime, money, plural, siteUrl, truncate } from "../format.js";

/** Billing, integrations and imports, staff alerts, digests, contact receipts and the newsletter. */

const invoiceRows = (invoice, ctx) =>
  [
    ["Invoice", invoice.number],
    invoice.planName ? ["Plan", invoice.planName] : null,
    invoice.issuedAt ? ["Issued", dateOnly(invoice.issuedAt, ctx.recipient.timezone)] : null,
    invoice.dueAt ? ["Due", dateOnly(invoice.dueAt, ctx.recipient.timezone)] : null,
    ["Total", money(invoice.total, invoice.currency)],
  ].filter(Boolean);

const SAMPLE_INVOICE = { number: "INV-2026-0142", total: 4999, currency: "AED", planName: "Professional", issuedAt: new Date(Date.now() - 20 * 864e5).toISOString(), dueAt: new Date(Date.now() + 3 * 864e5).toISOString() };

export default {
  "billing.plan_changed": {
    category: "billing",
    label: "Plan changed",
    render: (d) => ({
      subject: `Your LivFinder plan is now ${d.planName}`,
      preheader: "Your limits updated straight away.",
      heading: `You are on ${d.planName}`,
      blocks: [
        { type: "p", text: `Your account moved to the **${d.planName}** plan${d.scheduled ? " on its billing date, as you scheduled" : ""}. Your listing, featured and team limits updated straight away.` },
        d.limits ? { type: "table", rows: d.limits } : null,
        { type: "button", label: "View billing", url: siteUrl("/portal/billing"), tone: "secondary" },
      ],
    }),
    sample: { planName: "Professional", limits: [["Live listings", "100"], ["Featured", "10"], ["Team seats", "10"]] },
  },

  "billing.plan_change_scheduled": {
    category: "billing",
    label: "Plan change scheduled or cancelled",
    render: (d, ctx) => ({
      subject: d.cancelled ? "Your scheduled plan change was cancelled" : `Your plan changes to ${d.planName} on ${dateOnly(d.effectiveAt, ctx.recipient.timezone)}`,
      preheader: d.cancelled ? "You stay on your current plan." : "Nothing changes until then.",
      heading: d.cancelled ? "Plan change cancelled" : d.reminder ? "Your plan changes soon" : "Plan change scheduled",
      blocks: [
        { type: "p", text: d.cancelled ? "The plan change you scheduled will not happen. You stay on your current plan." : `Your account moves to **${d.planName}** on **${dateOnly(d.effectiveAt, ctx.recipient.timezone)}**, at the start of your next billing cycle.` },
        { type: "button", label: "View billing", url: siteUrl("/portal/billing"), tone: "secondary" },
      ],
    }),
    sample: { planName: "Enterprise", effectiveAt: new Date(Date.now() + 10 * 864e5).toISOString() },
  },

  "billing.invoice_paid": {
    category: "billing",
    label: "Payment received",
    render: (d, ctx) => ({
      subject: `Payment received for invoice ${d.invoice.number}`,
      preheader: `${money(d.invoice.total, d.invoice.currency)} received. Thank you.`,
      heading: "Payment received",
      blocks: [
        { type: "alert", tone: "success", text: `We received ${money(d.invoice.total, d.invoice.currency)}. Thank you.` },
        { type: "table", rows: invoiceRows(d.invoice, ctx), total: true },
        { type: "button", label: "View invoice", url: siteUrl("/portal/billing"), tone: "secondary" },
      ],
    }),
    sample: { invoice: SAMPLE_INVOICE },
  },

  "billing.invoice_due_soon": {
    category: "billing",
    label: "Invoice due soon",
    render: (d, ctx) => ({
      subject: `Invoice ${d.invoice.number} is due on ${dateOnly(d.invoice.dueAt, ctx.recipient.timezone)}`,
      preheader: `${money(d.invoice.total, d.invoice.currency)} due soon.`,
      heading: "Your invoice is due soon",
      blocks: [
        { type: "table", rows: invoiceRows(d.invoice, ctx), total: true },
        { type: "button", label: "Pay invoice", url: siteUrl("/portal/billing") },
      ],
    }),
    sample: { invoice: SAMPLE_INVOICE },
  },

  "billing.invoice_overdue": {
    category: "billing",
    priority: 2,
    label: "Invoice overdue",
    render: (d, ctx) => ({
      subject: `Invoice ${d.invoice.number} is overdue`,
      preheader: `${money(d.invoice.total, d.invoice.currency)} was due and has not been received.`,
      heading: "Your invoice is overdue",
      blocks: [
        { type: "alert", tone: "critical", text: `Payment of ${money(d.invoice.total, d.invoice.currency)} was due and has not been received.` },
        { type: "table", rows: invoiceRows(d.invoice, ctx), total: true },
        { type: "button", label: "Pay now", url: siteUrl("/portal/billing") },
        { type: "p", text: "Already paid? Reply to this email with the payment reference." },
      ],
    }),
    sample: { invoice: { ...SAMPLE_INVOICE, dueAt: new Date(Date.now() - 2 * 864e5).toISOString() } },
  },

  "billing.subscription_past_due": {
    category: "billing",
    priority: 2,
    label: "Subscription past due",
    render: () => ({
      subject: "Your LivFinder subscription is past due",
      preheader: "Choose a plan to keep your paid features.",
      heading: "Your subscription is past due",
      blocks: [
        { type: "alert", tone: "critical", text: "Your subscription passed its renewal date without payment. Paid features may stop working." },
        { type: "p", text: "Choose a plan again from **Billing & Plans**, or contact support, to keep your listings and team active." },
        { type: "button", label: "Go to Billing & Plans", url: siteUrl("/portal/billing") },
      ],
    }),
    sample: {},
  },

  "billing.addon": {
    category: "billing",
    label: "Add-on switched on or off",
    render: (d) => ({
      subject: `${d.name} switched ${d.enabled ? "on" : "off"}`,
      preheader: d.enabled ? "It is ready to use." : "It is no longer active on your account.",
      heading: `${d.name} is ${d.enabled ? "on" : "off"}`,
      blocks: [
        { type: "p", text: d.enabled ? `**${d.name}** is now active on your account.` : `**${d.name}** is no longer active on your account.${d.reason ? ` ${d.reason}` : ""}` },
        { type: "button", label: "View add-ons", url: siteUrl("/portal/billing"), tone: "secondary" },
      ],
    }),
    sample: { name: "Integrations", enabled: true },
  },

  "integrations.import_rejected": {
    category: "integrations",
    label: "Listings rejected from an import or push",
    render: (d) => ({
      subject: `LivFinder: ${d.failed} of ${d.total} ${d.total === 1 ? "listing was" : "listings were"} rejected`,
      preheader: "Fix them and send them again. The others were not affected.",
      heading: `${plural(d.failed, "listing")} could not be imported`,
      blocks: [
        { type: "p", text: `${d.failed} of ${d.total} ${d.total === 1 ? "listing was" : "listings were"} rejected and did not come in. Fix them and send them again; the others were not affected.` },
        { type: "issues", items: d.items.map((item) => ({ label: `Row ${item.row} · ${item.id}${item.title ? ` · ${item.title}` : ""}`, reasons: item.reasons })), more: d.more ? `…and ${d.more} more. See them all under API & Integrations in the portal.` : null },
        { type: "button", label: "Open API & Integrations", url: siteUrl("/portal/integrations") },
      ],
    }),
    sample: { failed: 2, total: 120, items: [{ row: 14, id: "EXT-551", title: "Marina Penthouse", reasons: ["price: Enter a price above zero."] }, { row: 37, id: "EXT-588", title: null, reasons: ["community: Unknown community 'Dubai Hils'."] }], more: 0 },
  },

  "integrations.webhook_disabled": {
    category: "integrations",
    priority: 2,
    label: "Webhook switched off",
    render: (d) => ({
      subject: `Webhook "${d.name}" was switched off`,
      preheader: `It failed ${d.failures} times in a row.`,
      heading: "A webhook was switched off",
      blocks: [
        { type: "alert", tone: "critical", text: `Your webhook **${d.name}** failed ${d.failures} times in a row, so we stopped sending to it.` },
        { type: "table", rows: [["Endpoint", d.url ?? "—"], ["Last error", truncate(d.error, 160)]] },
        { type: "p", text: "Leads are still in your portal. Fix the endpoint, then turn the webhook back on; new events will flow again." },
        { type: "button", label: "Open API & Integrations", url: siteUrl("/portal/integrations") },
      ],
    }),
    sample: { name: "CRM sync", failures: 20, error: "HTTP 500 Internal Server Error", url: "https://crm.example.com/hooks/livfinder" },
  },

  "receipts.contact": {
    category: "receipts",
    label: "Contact form received",
    render: (d) => ({
      subject: `We received your message (${d.reference})`,
      preheader: "Our team will reply soon.",
      heading: "We received your message",
      blocks: [
        { type: "p", text: "Thank you for contacting LivFinder. Our team replies within one working day." },
        { type: "table", rows: [["Reference", d.reference], ["Topic", d.topic]] },
        d.message ? { type: "quote", text: truncate(d.message, 600), by: "Your message" } : null,
      ],
      reason: "You get this because you used the contact form on LivFinder.",
    }),
    sample: { reference: "SUP-8124", topic: "Advertising enquiry", message: "We would like to list our yacht fleet." },
  },

  "staff.alert": {
    category: "staff",
    label: "Staff alert",
    render: (d) => ({
      subject: `[LivFinder staff] ${d.title}`,
      preheader: d.summary ? truncate(d.summary, 100) : d.title,
      heading: d.title,
      blocks: [
        d.summary ? { type: "p", text: d.summary } : null,
        d.rows?.length ? { type: "table", rows: d.rows } : null,
        d.quote ? { type: "quote", text: truncate(d.quote, 800) } : null,
        { type: "button", label: d.actionLabel || "Open in admin", url: siteUrl(d.url || "/admin") },
      ],
      reason: "You get this because your LivFinder staff role covers this work.",
    }),
    sample: { title: "New seller application: Example Realty", summary: "A Company applied to sell on LivFinder.", rows: [["Applicant", "Sara Haddad"], ["Type", "Company"]], url: "/admin/companies", actionLabel: "Review application" },
  },

  "staff.daily_queue": {
    category: "staff",
    label: "Daily review queue (staff)",
    render: (d) => ({
      subject: `[LivFinder staff] Today's queue: ${plural(d.total, "item")} waiting`,
      preheader: d.rows.map(([label, value]) => `${value} ${label.toLowerCase()}`).join(", "),
      heading: "Today's review queue",
      blocks: [
        { type: "table", rows: d.rows },
        d.oldest ? { type: "p", text: `The oldest item has waited ${d.oldest}.` } : null,
        { type: "button", label: "Open admin", url: siteUrl("/admin/dashboard") },
      ],
      reason: "You get this because your LivFinder staff role covers reviews.",
    }),
    sample: { total: 14, rows: [["Seller applications", "3"], ["Listings to review", "8"], ["Changes to review", "2"], ["Open reports", "1"]], oldest: "3 days" },
  },

  "digest.daily": {
    category: "account",
    label: "Daily digest",
    render: (d, ctx) => ({
      subject: `Your LivFinder summary: ${plural(d.total, "update")}`,
      preheader: d.sections.map((section) => `${section.items.length} ${section.title.toLowerCase()}`).join(", "),
      heading: "Your daily summary",
      blocks: [
        { type: "p", text: `Here is what happened since your last summary. You chose to get these once a day; change that in Email settings.` },
        ...d.sections.flatMap((section) => [
          { type: "h", text: `${section.title} (${section.items.length})` },
          { type: "list", items: section.items.slice(0, 15).map((item) => `${item.subject}${item.at ? ` — ${dateTime(item.at, ctx.recipient.timezone)}` : ""}`) },
          section.items.length > 15 ? { type: "p", text: `…and ${section.items.length - 15} more.` } : null,
        ]),
        { type: "button", label: "Open your portal", url: siteUrl("/portal") },
      ],
    }),
    sample: { total: 3, sections: [{ title: CATEGORIES.leads.label, items: [{ subject: "New enquiry INQ-24518 — Signature Villa", at: new Date().toISOString() }] }, { title: CATEGORIES.listings.label, items: [{ subject: "Your listing is live: Marina Penthouse" }, { subject: "Signature Villa expires in 7 days" }] }] },
  },

  "newsletter.confirm": {
    category: "security",
    priority: 2,
    label: "Confirm newsletter subscription",
    render: (d) => ({
      subject: "Confirm your LivFinder newsletter subscription",
      preheader: "One click and you are on the list.",
      heading: "Confirm your subscription",
      blocks: [
        { type: "p", text: "Please confirm that you would like to receive the LivFinder newsletter." },
        { type: "button", label: "Confirm subscription", url: d.url, note: "If you did not ask for this, ignore this email and you will not be subscribed." },
      ],
      reason: "You get this because this address was entered in the LivFinder newsletter form.",
    }),
    sample: { url: siteUrl("/newsletter/confirm?token=sample") },
  },

  "newsletter.welcome": {
    category: "newsletter",
    label: "Newsletter welcome",
    render: () => ({
      subject: "You are subscribed to the LivFinder newsletter",
      preheader: "The best of luxury property, cars, yachts and more.",
      heading: "You are on the list",
      blocks: [
        { type: "p", text: "Thank you for subscribing. Expect a short selection of remarkable listings, new developments and market notes, never more than a few times a month." },
        { type: "button", label: "Explore LivFinder", url: siteUrl("/") },
      ],
      reason: "You get this because you subscribed to the LivFinder newsletter.",
    }),
    sample: {},
  },

  "newsletter.campaign": {
    category: "newsletter",
    label: "Newsletter issue",
    render: (d) => ({
      subject: d.subject,
      preheader: d.preheader || "",
      heading: d.heading,
      blocks: [
        ...String(d.body || "").split(/\n{2,}/).filter(Boolean).map((text) => ({ type: "p", text })),
        d.ctaLabel && d.ctaUrl ? { type: "button", label: d.ctaLabel, url: d.ctaUrl } : null,
      ],
      reason: "You get this because you subscribed to the LivFinder newsletter.",
    }),
    sample: { subject: "New on LivFinder this month", heading: "This month on LivFinder", body: "Three waterfront villas, a new tower on the Creek and the yachts of the season.\n\nRead on for the highlights.", ctaLabel: "See the highlights", ctaUrl: siteUrl("/") },
  },
};
