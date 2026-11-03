/**
 * A post-sign-in destination taken from a query string or cookie.
 *
 * Only a path on this site passes. `//evil.example` and `/\evil.example` are protocol-relative
 * in a browser, and the URL parser strips tabs and newlines, so parsing it is the check.
 */
export function safeReturnPath(value) {
  if (typeof value !== "string" || !value.startsWith("/")) return null;
  try {
    const base = "https://livfinder.invalid";
    const parsed = new URL(value, base);
    return parsed.origin === base ? `${parsed.pathname}${parsed.search}${parsed.hash}` : null;
  } catch {
    return null;
  }
}
