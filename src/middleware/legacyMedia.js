/**
 * Rewrites seeded CDN image URLs on the way out.
 *
 * `db/seeds/*` ship absolute `https://cdn.livfinder.com/...` URLs for avatars, logos, covers and
 * hero images — roughly 2,500 of them, spread across a dozen tables and three views. That host
 * exists in a deployed environment and nowhere else, so without this every one of those images
 * renders broken.
 *
 * The rewrite happens here, in one place on the response, rather than in each of the many
 * serializers that emit an image URL, and rather than by editing the seed data — the URLs are not
 * wrong, the CDN is simply absent. Point `MEDIA_CDN_BASE_URL` at a real origin and this middleware
 * rewrites to that instead; the stand-in only appears when nothing is configured.
 */
import env from "../config/env.js";

const legacyPrefix = `https://${env.MEDIA_LEGACY_CDN_HOST}/`;
const legacyPrefixInsecure = `http://${env.MEDIA_LEGACY_CDN_HOST}/`;

function replacementFor(url) {
  const pathname = url.startsWith(legacyPrefix)
    ? url.slice(legacyPrefix.length)
    : url.slice(legacyPrefixInsecure.length);
  if (env.MEDIA_CDN_BASE_URL) return `${env.MEDIA_CDN_BASE_URL.replace(/\/$/, "")}/${pathname}`;
  // The extension is dropped: the stand-in is always an SVG whatever the original named.
  return `${env.STORAGE_PUBLIC_BASE_URL.replace(/\/$/, "")}/placeholder/${pathname.replace(/\.[a-z0-9]+$/i, "")}.svg`;
}

const isLegacy = (value) =>
  typeof value === "string" && (value.startsWith(legacyPrefix) || value.startsWith(legacyPrefixInsecure));

/**
 * Walks a decoded JSON body and returns a rewritten copy.
 *
 * Copying rather than mutating in place: a payload may legitimately contain a frozen object —
 * a module-level constant such as a label map serialised straight into the response — and
 * assigning to one of those throws in strict mode, turning a successful handler into a 500.
 * An untouched subtree is returned by reference, so this only allocates along paths that
 * actually changed.
 */
function rewrite(value) {
  if (isLegacy(value)) return replacementFor(value);

  if (Array.isArray(value)) {
    let changed = false;
    const next = value.map((entry) => {
      const rewritten = rewrite(entry);
      if (rewritten !== entry) changed = true;
      return rewritten;
    });
    return changed ? next : value;
  }

  // Dates, buffers and the like serialise on their own; walking them would flatten them.
  if (value && typeof value === "object" && (value.constructor === Object || value.constructor === undefined)) {
    let changed = false;
    const next = {};
    for (const key of Object.keys(value)) {
      const rewritten = rewrite(value[key]);
      if (rewritten !== value[key]) changed = true;
      next[key] = rewritten;
    }
    return changed ? next : value;
  }

  return value;
}

export function legacyMediaRewrite(req, res, next) {
  const json = res.json.bind(res);
  res.json = (body) => json(rewrite(body));
  return next();
}

export { rewrite as rewriteLegacyMediaUrls };
export default legacyMediaRewrite;
