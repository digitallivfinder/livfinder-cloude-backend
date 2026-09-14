import sanitizeHtml from "sanitize-html";

/**
 * Listing descriptions.
 *
 * The portal writes them in a rich-text editor and the public listing page renders them as
 * HTML, so what is stored and served is only ever this allowlist: paragraphs, headings,
 * lists, quotes, emphasis and plain links. No classes, no scripts, no images, no inline
 * styles beyond text alignment. A description written as plain text — every one seeded
 * before the editor existed — is kept as typed and turned into paragraphs on the way out.
 */
const ALIGNMENT = { "text-align": [/^(left|right|center|justify)$/] };

const RICH_TEXT = {
  allowedTags: ["p", "br", "h2", "h3", "h4", "strong", "b", "em", "i", "u", "s", "ul", "ol", "li", "blockquote", "a", "span"],
  allowedAttributes: {
    a: ["href", "target", "rel"],
    p: ["style"],
    h2: ["style"],
    h3: ["style"],
    h4: ["style"],
    li: ["style"],
  },
  allowedStyles: { "*": ALIGNMENT },
  allowedSchemes: ["http", "https", "mailto", "tel"],
  transformTags: {
    // The listing page owns its one h1.
    h1: "h2",
    a: sanitizeHtml.simpleTransform("a", { target: "_blank", rel: "noopener noreferrer nofollow" }),
  },
};

const HTML_TAG = /<\/?[a-z][^>]*>/i;

export function isRichText(value) {
  return HTML_TAG.test(String(value ?? ""));
}

/** What is stored: rich text through the allowlist, plain text untouched. */
export function sanitizeDescription(value) {
  if (value === null || value === undefined) return value;
  const text = String(value);
  return isRichText(text) ? sanitizeHtml(text, RICH_TEXT) : text;
}

const escapeText = (text) => text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/** What a page renders: sanitised rich text, or plain text as escaped paragraphs. */
export function descriptionToHtml(value) {
  const text = String(value ?? "").trim();
  if (!text) return "";
  if (isRichText(text)) return sanitizeHtml(text, RICH_TEXT);
  return text
    .split(/\n{2,}/)
    .map((paragraph) => `<p>${escapeText(paragraph).replace(/\n/g, "<br />")}</p>`)
    .join("");
}

const ENTITIES = { "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&nbsp;": " " };

/** The words alone — for meta descriptions, structured data and previews. */
export function descriptionToText(value) {
  const text = String(value ?? "");
  if (!isRichText(text)) return text.trim();
  return sanitizeHtml(text.replace(/<\/(p|h[1-6]|li|blockquote)>|<br\s*\/?>/gi, "$& "), { allowedTags: [], allowedAttributes: {} })
    .replace(/&(amp|lt|gt|quot|#39|nbsp);/g, (entity) => ENTITIES[entity])
    .replace(/\s+/g, " ")
    .trim();
}
