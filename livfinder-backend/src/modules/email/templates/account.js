import { dateTime, firstName, siteUrl } from "../format.js";

/** Sign-in, security, team invitations, seller applications and privacy requests. */

const SELLER_LABEL = { individual: "Individual seller", company: "Company", developer: "Developer" };

const NEXT_STEPS = {
  individual: ["Add your first listing from **My Listings → Add listing**.", "Complete your profile so buyers see who they are talking to."],
  company: [
    "Add your first listing, or connect a feed under **API & Integrations**.",
    "Invite your agents from **Team** so leads reach the right person.",
    "Add your logo and company details so your profile page is complete.",
  ],
  developer: [
    "Add your first project under **Developments**.",
    "Upload brochures and floor plans so buyers can request them.",
    "Invite your sales team from **Team**.",
  ],
  member: ["Save searches to hear about new matches.", "Favourite listings to follow their price.", "Upgrade to a seller account at any time from **Become a seller**."],
};

export default {
  "auth.confirm_email": {
    category: "security",
    priority: 1,
    label: "Confirm email address",
    render: (d, ctx) => ({
      subject: "Confirm your LivFinder email address",
      preheader: "One click to finish setting up your account.",
      heading: d.resend ? "Confirm your email address" : `Welcome to LivFinder, ${firstName(ctx.recipient)}`,
      blocks: [
        { type: "p", text: d.resend ? "Confirm your address to finish setting up your account." : "Confirm your email address to activate your account." },
        { type: "button", label: "Confirm email address", url: d.url, note: "This link works for 24 hours. If you did not create a LivFinder account, ignore this email." },
      ],
    }),
    sample: { url: siteUrl("/verify-email?token=sample-token") },
  },

  "auth.password_reset": {
    category: "security",
    priority: 1,
    label: "Password reset link",
    render: (d) => ({
      subject: "Reset your LivFinder password",
      preheader: "Use this link within the hour.",
      heading: "Reset your password",
      blocks: [
        { type: "p", text: "We received a request to reset the password for your LivFinder account." },
        { type: "button", label: "Choose a new password", url: d.url, note: "The link works for one hour. If you did not ask for this, nothing has changed and you can ignore this email." },
      ],
    }),
    sample: { url: siteUrl("/reset-password?token=sample-token") },
  },

  "auth.account_setup": {
    category: "security",
    priority: 1,
    label: "Account set-up link (account created by LivFinder)",
    render: (d) => ({
      subject: d.companyName ? `Your LivFinder account for ${d.companyName} is ready` : "Your LivFinder account is ready",
      preheader: `Choose a password to start. The link works for ${d.days} days.`,
      heading: "Set up your LivFinder account",
      blocks: [
        {
          type: "p",
          text: d.companyName
            ? `LivFinder${d.invitedBy ? ` (${d.invitedBy})` : ""} created an account for **${d.companyName}** with this email address.`
            : `LivFinder${d.invitedBy ? ` (${d.invitedBy})` : ""} created an account for you with this email address.`,
        },
        { type: "button", label: "Choose your password", url: d.url, note: `The link works for ${d.days} days. If you were not expecting this, you can ignore it and nothing will happen.` },
      ],
    }),
    sample: { url: siteUrl("/reset-password?token=sample-token&setup=1"), companyName: "Example Realty", invitedBy: "Sara Haddad", days: 7 },
  },

  "auth.password_reset_support": {
    category: "security",
    priority: 1,
    label: "Password reset link from support",
    render: (d) => ({
      subject: `LivFinder support sent you a password reset link`,
      preheader: `For ${d.companyName}. Use it within the hour.`,
      heading: "Reset your password",
      blocks: [
        { type: "p", text: `LivFinder support sent this link for **${d.companyName}**.` },
        { type: "button", label: "Choose a new password", url: d.url, note: "The link works for one hour. If you did not ask support for this, contact us and nothing will change." },
      ],
    }),
    sample: { url: siteUrl("/reset-password?token=sample-token"), companyName: "Example Realty" },
  },

  "auth.password_reset_temporary": {
    category: "security",
    priority: 1,
    label: "Password reset by support",
    render: () => ({
      subject: "Your LivFinder password was reset",
      preheader: "Support set a temporary password for you.",
      heading: "Your password was reset",
      blocks: [
        { type: "alert", tone: "warning", text: "LivFinder support reset your password and signed you out everywhere." },
        { type: "p", text: "Sign in with the temporary password support gives you, then choose your own under **Account Settings**." },
        { type: "button", label: "Sign in", url: siteUrl("/login") },
        { type: "p", text: "If you did not ask for this, contact support straight away." },
      ],
    }),
    sample: {},
  },

  "auth.password_changed": {
    category: "security",
    priority: 1,
    label: "Password changed",
    render: (d, ctx) => ({
      subject: "Your LivFinder password was changed",
      preheader: "If this was you, there is nothing to do.",
      heading: "Your password was changed",
      blocks: [
        { type: "p", text: `The password for your account was ${d.how === "reset" ? "reset with an emailed link" : "changed"} on ${dateTime(d.at, ctx.recipient.timezone)}. You were signed out on your other devices.` },
        { type: "alert", tone: "warning", text: "If this was not you, reset your password now and contact support." },
        { type: "button", label: "Reset my password", url: siteUrl("/forgot-password"), tone: "secondary" },
      ],
    }),
    sample: { how: "changed", at: new Date().toISOString() },
  },

  "auth.mfa_changed": {
    category: "security",
    priority: 1,
    label: "Two-step sign-in turned on or off",
    render: (d, ctx) => ({
      subject: d.enabled ? "Two-step sign-in is on" : "Two-step sign-in was turned off",
      preheader: d.enabled ? "Your account now asks for a code when you sign in." : "Your account no longer asks for a code.",
      heading: d.enabled ? "Two-step sign-in is on" : "Two-step sign-in was turned off",
      blocks: [
        { type: "p", text: `${d.enabled ? "Two-step sign-in was turned on" : "Two-step sign-in was turned off"} for your account on ${dateTime(d.at, ctx.recipient.timezone)}.` },
        d.enabled ? { type: "p", text: "Keep your recovery codes somewhere safe. You need one if you lose your phone." } : { type: "alert", tone: "warning", text: "If you did not do this, reset your password and turn two-step sign-in back on." },
        { type: "button", label: "Review security settings", url: siteUrl("/portal/settings/account"), tone: "secondary" },
      ],
    }),
    sample: { enabled: true, at: new Date().toISOString() },
  },

  "auth.welcome": {
    category: "account",
    label: "Welcome (after confirming email)",
    render: (d, ctx) => {
      const type = d.sellerType || "member";
      const steps = NEXT_STEPS[type] ?? NEXT_STEPS.member;
      return {
        subject: "Welcome to LivFinder",
        preheader: type === "member" ? "Your account is ready." : "Your account is ready. Here is what to do first.",
        heading: `Welcome, ${firstName(ctx.recipient)}`,
        blocks: [
          { type: "p", text: type === "member" ? "Your email is confirmed and your LivFinder account is ready." : d.pendingReview ? `Your email is confirmed. We are reviewing your ${SELLER_LABEL[type]?.toLowerCase() ?? "seller"} application and will email you when it is decided.` : "Your email is confirmed and your account is ready." },
          { type: "h", text: "What to do next" },
          { type: "list", items: steps },
          { type: "button", label: type === "member" ? "Start exploring" : "Open your portal", url: siteUrl(type === "member" ? "/" : "/portal") },
        ],
      };
    },
    sample: { sellerType: "company", pendingReview: true },
  },

  "team.invitation": {
    category: "account",
    priority: 1,
    label: "Team invitation",
    render: (d) => ({
      subject: `${d.companyName} invited you to LivFinder`,
      preheader: `${d.inviterName} invited you to join as ${d.roleLabel}.`,
      heading: `Join ${d.companyName} on LivFinder`,
      blocks: [
        { type: "p", text: `**${d.inviterName}** invited you to join **${d.companyName}** on LivFinder as **${d.roleLabel}**.` },
        { type: "button", label: "Accept the invitation", url: d.url, note: `The link works for ${d.days} days. If you were not expecting this, you can ignore it.` },
      ],
      reason: `You get this because ${d.inviterName} entered your address on LivFinder.`,
    }),
    sample: { inviterName: "Sara Haddad", companyName: "Example Realty", roleLabel: "Agent", url: siteUrl("/accept-invite?token=sample"), days: 7 },
  },

  "team.invitation_reminder": {
    category: "account",
    label: "Team invitation reminder",
    render: (d, ctx) => ({
      subject: `Your invitation to ${d.companyName} expires soon`,
      preheader: `Accept it before ${dateTime(d.expiresAt, ctx.recipient.timezone)}.`,
      heading: "Your invitation expires soon",
      blocks: [
        { type: "p", text: `${d.inviterName} invited you to join **${d.companyName}** as **${d.roleLabel}**. The invitation expires on ${dateTime(d.expiresAt, ctx.recipient.timezone)}.` },
        { type: "button", label: "Accept the invitation", url: d.url },
      ],
      reason: `You get this because ${d.inviterName} entered your address on LivFinder.`,
    }),
    sample: { inviterName: "Sara Haddad", companyName: "Example Realty", roleLabel: "Agent", url: siteUrl("/accept-invite?token=sample"), expiresAt: new Date(Date.now() + 2 * 864e5).toISOString() },
  },

  "team.invitation_accepted": {
    category: "team",
    label: "Invitation accepted",
    render: (d) => ({
      subject: `${d.memberName} joined ${d.companyName}`,
      preheader: `They joined as ${d.roleLabel}.`,
      heading: `${d.memberName} joined your team`,
      blocks: [
        { type: "p", text: `**${d.memberName}** (${d.memberEmail}) accepted your invitation and joined **${d.companyName}** as **${d.roleLabel}**.` },
        { type: "button", label: "View your team", url: siteUrl("/portal/team"), tone: "secondary" },
      ],
    }),
    sample: { memberName: "Omar Aziz", memberEmail: "omar@example.com", companyName: "Example Realty", roleLabel: "Agent" },
  },

  "applications.received": {
    category: "account",
    label: "Seller application received",
    render: (d) => ({
      subject: "We received your LivFinder application",
      preheader: "We will email you when it is reviewed.",
      heading: "Your application is with us",
      blocks: [
        { type: "p", text: `Thank you for applying as ${d.sellerType === "member" ? "a seller" : `a${d.sellerType === "individual" ? "n" : ""} **${SELLER_LABEL[d.sellerType] ?? "seller"}**`}. Our team reviews applications within two working days.` },
        { type: "p", text: "We will email you as soon as it is decided. You can check its status at any time in your portal." },
        { type: "button", label: "Check application status", url: siteUrl("/portal"), tone: "secondary" },
      ],
    }),
    sample: { sellerType: "company" },
  },

  "applications.decision": {
    category: "account",
    priority: 2,
    label: "Seller application decision",
    render: (d) => {
      const approved = d.decision === "approve";
      const changes = d.decision === "request_changes";
      const type = d.sellerType || "individual";
      return {
        subject: approved ? "Your LivFinder account is verified" : changes ? "Your LivFinder application needs changes" : "Your LivFinder application was not approved",
        preheader: approved ? "You can start listing now." : changes ? "A reviewer needs something changed." : "See the reason and what you can do.",
        heading: approved ? "You are verified" : changes ? "Your application needs changes" : "Your application was not approved",
        blocks: approved
          ? [
              { type: "alert", tone: "success", text: `Your ${SELLER_LABEL[type]?.toLowerCase() ?? "seller"} application was approved.${d.agentProfile ? " Your public profile is now live." : ""}` },
              { type: "h", text: "What to do next" },
              { type: "list", items: NEXT_STEPS[type] ?? NEXT_STEPS.individual },
              { type: "button", label: "Open your portal", url: siteUrl("/portal") },
            ]
          : [
              { type: "p", text: changes ? "A reviewer needs something changed before your application can be approved." : "Your application could not be approved." },
              d.detail ? { type: "quote", text: d.detail, by: "LivFinder review team" } : null,
              { type: "button", label: changes ? "Update your application" : "See the details", url: siteUrl("/portal") },
              { type: "p", text: "Questions? Reply to this email or contact support." },
            ],
      };
    },
    sample: { decision: "request_changes", detail: "The trade licence you uploaded has expired. Upload the current one.", sellerType: "company" },
  },

  "applications.category_access": {
    category: "account",
    label: "Category access decision",
    render: (d) => ({
      subject: d.approved ? `You can now list in ${d.categoryName}` : `Your request to list in ${d.categoryName} was not approved`,
      preheader: d.approved ? "The category is open on your account." : "See the reason.",
      heading: d.approved ? `${d.categoryName} is open to you` : `${d.categoryName} access was not approved`,
      blocks: [
        { type: "p", text: d.approved ? `Your account can now publish listings in **${d.categoryName}**${d.listingQuota ? ` (up to ${d.listingQuota})` : ""}.` : `Your request to list in **${d.categoryName}** was not approved.` },
        d.note ? { type: "quote", text: d.note, by: "LivFinder review team" } : null,
        { type: "button", label: d.approved ? "Add a listing" : "Open your portal", url: siteUrl(d.approved ? "/portal/listings" : "/portal") },
      ],
    }),
    sample: { approved: true, categoryName: "Yachts", listingQuota: 10 },
  },

  "privacy.request": {
    category: "account",
    label: "Privacy request received",
    render: (d) => ({
      subject: d.type === "erasure" ? "We received your request to delete your data" : "We received your data request",
      preheader: `Reference ${d.reference}.`,
      heading: "We received your privacy request",
      blocks: [
        { type: "p", text: `We received your request${d.type ? ` (${String(d.type).replace(/_/g, " ")})` : ""} and will complete it within 30 days, as the law requires.` },
        { type: "table", rows: [["Reference", d.reference], ["Status", "Received"]] },
        { type: "button", label: "View privacy settings", url: siteUrl("/portal/settings/privacy"), tone: "secondary" },
      ],
    }),
    sample: { type: "export", reference: "01JABCDEF" },
  },
};
