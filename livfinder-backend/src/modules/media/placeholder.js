/**
 * Deterministic placeholder imagery.
 *
 * The seed data ships absolute `https://cdn.livfinder.com/...` URLs. That host is real in a
 * deployed environment and does not exist anywhere else, so every avatar, logo and cover image
 * in the seeded catalogue renders as a broken image locally.
 *
 * Rather than rewrite the seed data — the URLs are correct, the CDN is simply absent — the API
 * serves a stand-in for those paths when no CDN is configured. The image is derived from the
 * path itself, so the same subject always gets the same colour and the same initials, and a
 * gallery of them looks deliberate instead of broken.
 */
import crypto from "node:crypto";

/** Muted, brand-adjacent hues. Picked by hash, so a given subject is stable across restarts. */
const PALETTE = [
  ["#1e3a5f", "#2c5282"], ["#3c2a4d", "#553c6e"], ["#1f4037", "#2d5a4a"],
  ["#4a3728", "#6b5340"], ["#2b3a55", "#3f5175"], ["#4a2c35", "#6b4049"],
  ["#26404a", "#385d6b"], ["#3d3a29", "#5a5540"],
];

/** How a path is drawn: people get initials, everything else gets a monogram or a plain field. */
function classify(pathname) {
  const first = pathname.split("/")[0] || "";
  if (first === "agents" || first === "users" || first === "authors") return "initials";
  if (first === "organizations" || first === "brands" || first === "logos") return "monogram";
  return "scene";
}

/** "farah-khoury-119.jpg" → "Farah Khoury" → "FK" */
function labelFrom(pathname) {
  const base = pathname.split("/").pop() || "";
  const words = base
    .replace(/\.[a-z0-9]+$/i, "")
    .replace(/[-_]?\d+$/, "")
    .split(/[-_]+/)
    .filter(Boolean);
  return words.map((word) => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
}

function initialsFrom(label) {
  const words = label.split(/\s+/).filter(Boolean);
  if (!words.length) return "LF";
  if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
  return (words[0][0] + words[words.length - 1][0]).toUpperCase();
}

const escapeXml = (value) =>
  String(value).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;" }[c]));

/**
 * Renders an SVG for one path. SVG rather than a raster: it costs no image pipeline, scales to
 * whatever box the frontend puts it in, and stays crisp on a retina display.
 */
export function renderPlaceholder(pathname, { width = 800, height = 600 } = {}) {
  const digest = crypto.createHash("sha256").update(pathname).digest();
  const [from, to] = PALETTE[digest[0] % PALETTE.length];
  const kind = classify(pathname);
  const label = labelFrom(pathname);
  const angle = digest[1] % 90;

  const square = kind !== "scene";
  const w = square ? 512 : width;
  const h = square ? 512 : height;

  let foreground = "";
  if (kind === "initials" || kind === "monogram") {
    const text = kind === "initials" ? initialsFrom(label) : (label[0] || "L").toUpperCase();
    foreground = `<text x="50%" y="50%" dy="0.35em" text-anchor="middle"
        font-family="Georgia, 'Times New Roman', serif" font-size="${square ? 200 : 160}"
        fill="#ffffff" fill-opacity="0.9" letter-spacing="6">${escapeXml(text)}</text>`;
  } else {
    // A horizon line and a soft disc: enough shape to read as a photograph slot, not a texture.
    foreground = `
      <circle cx="${w * 0.74}" cy="${h * 0.28}" r="${h * 0.13}" fill="#ffffff" fill-opacity="0.10"/>
      <path d="M0 ${h * 0.72} L${w * 0.28} ${h * 0.55} L${w * 0.52} ${h * 0.74} L${w * 0.72} ${h * 0.6} L${w} ${h * 0.78} L${w} ${h} L0 ${h} Z"
            fill="#ffffff" fill-opacity="0.08"/>
      <text x="50%" y="${h - 28}" text-anchor="middle" font-family="Helvetica, Arial, sans-serif"
            font-size="20" fill="#ffffff" fill-opacity="0.55" letter-spacing="3">${escapeXml(label.toUpperCase().slice(0, 32))}</text>`;
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" width="${w}" height="${h}" role="img" aria-label="${escapeXml(label)}">
  <defs><linearGradient id="g" gradientTransform="rotate(${angle})">
    <stop offset="0%" stop-color="${from}"/><stop offset="100%" stop-color="${to}"/>
  </linearGradient></defs>
  <rect width="${w}" height="${h}" fill="url(#g)"/>
  ${foreground}
</svg>`;
}

export default renderPlaceholder;
