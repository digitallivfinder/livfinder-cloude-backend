/**
 * Email categories: what a person can switch on or off, and what they cannot.
 *
 * Every template belongs to one category. A category that is not `optional` always sends
 * (security, account, billing, receipts); an optional one follows the person's choice in
 * Notification settings and carries a one-click unsubscribe. `digest` categories can be
 * collected into one email a day. `marketing` categories also need marketing consent.
 * `audience` decides which settings screen shows the category.
 */
export const CATEGORIES = Object.freeze({
  security: { label: "Security and sign-in", description: "Password resets, confirmations and security notices.", optional: false, audience: "all" },
  account: { label: "Account and applications", description: "Your seller application, verification and account changes.", optional: false, audience: "all" },
  billing: { label: "Billing", description: "Plan changes, invoices and payment problems.", optional: false, audience: "seller" },
  receipts: { label: "Receipts", description: "Confirmation that your enquiry, offer or viewing request was sent.", optional: false, audience: "member" },
  leads: { label: "Enquiries and offers", description: "Someone asks about, or makes an offer on, one of your listings.", optional: true, digest: true, audience: "seller" },
  viewings: { label: "Viewings", description: "Viewing requests, confirmations and reminders.", optional: true, audience: "all" },
  messages: { label: "Chat messages", description: "A message arrives while you are offline.", optional: true, audience: "all" },
  listings: { label: "Listing decisions and expiry", description: "A listing is approved, rejected, changed by LivFinder or about to expire.", optional: true, digest: true, audience: "seller" },
  team: { label: "Team", description: "Invitations and changes to your team.", optional: true, audience: "seller" },
  integrations: { label: "Integrations and imports", description: "Import results, rejected listings and webhooks that stop working.", optional: true, audience: "seller" },
  reviews: { label: "Reviews", description: "Someone reviews you or your company.", optional: true, audience: "seller" },
  reports: { label: "Performance reports", description: "A weekly summary of views and enquiries.", optional: true, audience: "seller" },
  alerts: { label: "Saved searches and price drops", description: "New matches for your saved searches and price drops on favourites.", optional: true, audience: "member" },
  product: { label: "Product news", description: "Occasional news about LivFinder.", optional: true, marketing: true, audience: "all" },
  newsletter: { label: "Newsletter", description: "The LivFinder newsletter.", optional: true, marketing: true, audience: "all" },
  staff: { label: "Staff alerts", description: "New applications, reports, support requests and the daily review queue.", optional: true, digest: true, audience: "staff" },
});

export const CATEGORY_KEYS = Object.freeze(Object.keys(CATEGORIES));

export const isOptional = (category) => Boolean(CATEGORIES[category]?.optional);

/** Sender stream per category (separate addresses help deliverability once configured). */
export function streamFor(category) {
  if (category === "newsletter" || category === "product") return "news";
  if (category === "alerts" || category === "reports") return "alerts";
  return "transactional";
}
