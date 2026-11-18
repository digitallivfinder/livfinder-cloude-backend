/**
 * The statuses an administrator may give a staff user (`users.status`), with the label the Admin
 * Users form shows. The write schema and the `internalUser.status` option set both read this, so
 * the form never offers a status the API refuses (it used to offer "Invited" and "Inactive").
 */
export const INTERNAL_USER_STATUS_OPTIONS = Object.freeze([
  ["active", "Active"],
  ["pending_verification", "Invited (has not set a password yet)"],
  ["suspended", "Suspended"],
]);

export const INTERNAL_USER_STATUSES = Object.freeze(INTERNAL_USER_STATUS_OPTIONS.map(([value]) => value));
