/** Relocate public local-storage URLs saved in a development database.
 * Keep the storage key verbatim. Never rewrite private/signed links or external CDNs.
 */
export function publicMediaUrl(value, publicBaseUrl) {
  if (typeof value !== "string") return value;
  const base = publicBaseUrl.replace(/\/+$/, "");
  if (value.startsWith("/media/") && !/[?#]/.test(value)) return `${base}/${value.slice("/media/".length)}`;
  try {
    const url = new URL(value);
    if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) return value;
    if (!["localhost", "127.0.0.1", "[::1]"].includes(url.hostname)) return value;
    if (!url.pathname.startsWith("/media/") || url.search || url.hash) return value;
    return `${base}/${url.pathname.slice("/media/".length)}`;
  } catch {
    return value;
  }
}

/** The API's own /media base, where generated placeholders are served. Null on s3 without API_MEDIA_BASE_URL. */
export function apiMediaBaseUrl(env) {
  const base = env.API_MEDIA_BASE_URL || (env.STORAGE_DRIVER === "local" ? env.STORAGE_PUBLIC_BASE_URL : null);
  return base ? base.replace(/\/+$/, "") : null;
}
