/** A URL with any `secret` query parameter removed, for everything that writes a URL to a log. */
export const withoutSecret = (url) =>
  String(url)
    .replace(/([?&])secret=[^&]*(&|$)/, (match, before, after) => (after ? before : ""))
    .replace(/\?$/, "");
