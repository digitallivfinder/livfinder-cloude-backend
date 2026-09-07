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
