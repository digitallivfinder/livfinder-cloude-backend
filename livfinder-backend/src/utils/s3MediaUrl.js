/**
 * Rewrites a public local-storage URL to the same key on the S3 public base.
 *
 * Used once, by scripts/migrate-media-to-s3.js, when an environment moves from
 * STORAGE_DRIVER=local to s3. Recognised as local media:
 *   - `/media/<key>` (the seed's relative form)
 *   - `<loopback origin, any port>/media/<key>`
 *   - `<legacy base>/<key>` for each base in `legacyBaseUrls` (an old STORAGE_PUBLIC_BASE_URL)
 * The key is kept verbatim: it is already URL-encoded the way publicUrl() encodes it.
 * Everything else comes back untouched — private:// values, signed links (any query or
 * fragment), the seeded CDN host, other hosts, and URLs already on the new base — so running
 * it twice is a no-op.
 */
const LOOPBACK = new Set(["localhost", "127.0.0.1", "[::1]"]);

const trimBase = (value) => String(value || "").replace(/\/+$/, "");

export function s3MediaUrl(value, { publicBaseUrl, legacyBaseUrls = [], protectedHosts = ["cdn.livfinder.com"] }) {
  if (typeof value !== "string" || !value) return value;
  const base = trimBase(publicBaseUrl);
  if (!base) throw new TypeError("publicBaseUrl is required");
  if (/[?#]/.test(value)) return value;

  if (value.startsWith("/media/")) {
    const key = value.slice("/media/".length);
    return key ? `${base}/${key}` : value;
  }

  let url;
  try {
    url = new URL(value);
  } catch {
    return value;
  }
  if (!["http:", "https:"].includes(url.protocol) || url.username || url.password) return value;
  if (protectedHosts.includes(url.hostname)) return value;
  if (value.startsWith(`${base}/`)) return value;

  for (const legacy of legacyBaseUrls) {
    const prefix = `${trimBase(legacy)}/`;
    if (prefix.length > 1 && value.startsWith(prefix) && value.length > prefix.length) {
      return `${base}/${value.slice(prefix.length)}`;
    }
  }

  if (LOOPBACK.has(url.hostname) && url.pathname.startsWith("/media/") && url.pathname.length > "/media/".length) {
    return `${base}/${url.pathname.slice("/media/".length)}`;
  }
  return value;
}

/** Applies s3MediaUrl to every string inside a decoded JSON value. Returns the same reference when nothing changed. */
export function s3MediaUrlDeep(value, options) {
  if (typeof value === "string") return s3MediaUrl(value, options);
  if (Array.isArray(value)) {
    let changed = false;
    const next = value.map((entry) => {
      const rewritten = s3MediaUrlDeep(entry, options);
      if (rewritten !== entry) changed = true;
      return rewritten;
    });
    return changed ? next : value;
  }
  if (value && typeof value === "object") {
    let changed = false;
    const next = {};
    for (const [key, entry] of Object.entries(value)) {
      const rewritten = s3MediaUrlDeep(entry, options);
      if (rewritten !== entry) changed = true;
      next[key] = rewritten;
    }
    return changed ? next : value;
  }
  return value;
}

export default s3MediaUrl;
