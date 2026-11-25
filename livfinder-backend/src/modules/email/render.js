import env from "../../config/env.js";
import { assetUrl, escapeHtml, siteUrl } from "./format.js";

/**
 * The LivFinder email layout and its components.
 *
 * A template returns `{ subject, preheader, heading, blocks, reason }`. Each block is a plain
 * object (`{ type: "button", label, url }`); this file turns the same blocks into the HTML part
 * and the plain-text part, so the two can never say different things.
 *
 * The HTML is table-based with inline styles (Outlook, Gmail and Apple Mail all render it), 600px
 * wide, and carries dark-mode overrides for the clients that honour prefers-color-scheme.
 * Brand: navy #0c447c, red #e10114, Prata headings → Georgia, Open Sans body → Arial.
 */

export const THEME = Object.freeze({
  navy: "#0c447c",
  red: "#e10114",
  ink: "#14202e",
  slate: "#5b6878",
  line: "#dbe2ea",
  canvas: "#f2f4f7",
  paper: "#ffffff",
  soft: "#eef3f9",
  okBg: "#e7f5ed", ok: "#1d7a46",
  warnBg: "#fdf3e1", warn: "#8a5200",
  badBg: "#fdecee", bad: "#b0000f",
  display: "Prata, Georgia, 'Times New Roman', serif",
  body: "'Open Sans', Arial, Helvetica, sans-serif",
});

const T = THEME;
const e = escapeHtml;

const TONES = {
  info: [T.soft, T.navy],
  success: [T.okBg, T.ok],
  warning: [T.warnBg, T.warn],
  critical: [T.badBg, T.bad],
};

const p = (text, style = "") =>
  `<p class="lf-text" style="margin:0 0 16px;font-family:${T.body};font-size:15px;line-height:1.6;color:${T.ink};${style}">${text}</p>`;

/** Paragraph text: escaped, with **bold** and line breaks kept. */
const inline = (text) => e(text).replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>").replace(/\n/g, "<br>");
const plainInline = (text) => String(text ?? "").replace(/\*\*(.+?)\*\*/g, "$1");

function button({ label, url, tone = "primary", note }) {
  const bg = tone === "secondary" ? T.paper : T.red;
  const fg = tone === "secondary" ? T.navy : "#ffffff";
  const border = tone === "secondary" ? T.navy : T.red;
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 ${note ? "8px" : "20px"}"><tr><td align="center" bgcolor="${bg}" style="border-radius:6px;border:2px solid ${border}">
<!--[if mso]><v:roundrect xmlns:v="urn:schemas-microsoft-com:vml" href="${e(url)}" style="height:44px;v-text-anchor:middle;width:240px" arcsize="12%" stroke="f" fillcolor="${bg}"><center style="color:${fg};font-family:Arial;font-size:15px;font-weight:bold">${e(label)}</center></v:roundrect><![endif]-->
<!--[if !mso]><!--><a href="${e(url)}" target="_blank" class="${tone === "secondary" ? "lf-btn2" : "lf-btn"}" style="display:inline-block;padding:12px 26px;font-family:${T.body};font-size:15px;font-weight:700;line-height:20px;color:${fg};text-decoration:none;border-radius:6px">${e(label)}</a><!--<![endif]-->
</td></tr></table>${note ? p(e(note), `font-size:12px;color:${T.slate}`) : ""}`;
}

function card(inner, extra = "") {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="lf-card" style="margin:0 0 18px;border:1px solid ${T.line};border-radius:8px;${extra}"><tr><td style="padding:14px 16px">${inner}</td></tr></table>`;
}

const small = (text, style = "") => `<div class="lf-muted" style="font-family:${T.body};font-size:13px;line-height:1.5;color:${T.slate};${style}">${text}</div>`;
const strong = (text, url) =>
  `<div style="font-family:${T.body};font-size:15px;font-weight:700;line-height:1.4;margin:0 0 4px">${
    url ? `<a href="${e(url)}" class="lf-link" style="color:${T.navy};text-decoration:none">${e(text)}</a>` : `<span class="lf-text" style="color:${T.ink}">${e(text)}</span>`
  }</div>`;

const RENDER = {
  p: (b) => p(inline(b.text)),
  h: (b) => `<h2 class="lf-text" style="margin:8px 0 10px;font-family:${T.display};font-weight:400;font-size:19px;line-height:1.3;color:${T.ink}">${e(b.text)}</h2>`,
  button,
  link: (b) => p(`<a href="${e(b.url)}" class="lf-link" style="color:${T.navy};font-weight:600">${e(b.label)}</a>`),
  divider: () => `<div style="height:1px;background:${T.line};margin:8px 0 20px;line-height:1px;font-size:1px">&nbsp;</div>`,
  alert: (b) => {
    const [bg, fg] = TONES[b.tone] ?? TONES.info;
    return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 18px"><tr><td style="background:${bg};border-left:4px solid ${fg};border-radius:4px;padding:12px 14px;font-family:${T.body};font-size:14px;line-height:1.5;color:${fg}">${inline(b.text)}</td></tr></table>`;
  },
  quote: (b) =>
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 18px"><tr><td class="lf-soft" style="background:${T.soft};border-radius:6px;padding:12px 16px;font-family:${T.body};font-size:14px;line-height:1.6;color:${T.ink}">${inline(b.text)}${
      b.by ? `<div class="lf-muted" style="margin-top:6px;font-size:12px;color:${T.slate}">${e(b.by)}</div>` : ""
    }</td></tr></table>`,
  list: (b) =>
    `<ul style="margin:0 0 16px;padding-left:20px;font-family:${T.body};font-size:15px;line-height:1.6;color:${T.ink}" class="lf-text">${b.items
      .map((item) => `<li style="margin:0 0 4px">${inline(item)}</li>`)
      .join("")}</ul>`,
  code: (b) =>
    `<div class="lf-soft" style="margin:0 0 18px;padding:14px;background:${T.soft};border-radius:6px;text-align:center;font-family:'Courier New',monospace;font-size:26px;letter-spacing:6px;font-weight:700;color:${T.navy}">${e(b.text)}</div>`,
  table: (b) =>
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="lf-card" style="margin:0 0 18px;border:1px solid ${T.line};border-radius:8px;border-collapse:separate">${b.rows
      .map(
        ([label, value], index) =>
          `<tr><td class="lf-muted" style="padding:9px 14px;font-family:${T.body};font-size:13px;color:${T.slate};${index ? `border-top:1px solid ${T.line};` : ""}">${e(label)}</td><td class="lf-text" align="right" style="padding:9px 14px;font-family:${T.body};font-size:14px;color:${T.ink};font-variant-numeric:tabular-nums;${index ? `border-top:1px solid ${T.line};` : ""}${b.total && index === b.rows.length - 1 ? "font-weight:700;" : ""}">${e(value ?? "—")}</td></tr>`
      )
      .join("")}</table>`,
  issues: (b) =>
    card(
      b.items
        .map(
          (item, index) =>
            `<div style="${index ? `border-top:1px solid ${T.line};padding-top:10px;margin-top:10px` : ""}">${strong(item.label)}${item.reasons
              .map((reason) => small(`• ${e(reason)}`, `color:${T.bad}`))
              .join("")}</div>`
        )
        .join("") + (b.more ? small(e(b.more), "margin-top:10px") : "")
    ),
  stats: (b) =>
    `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 18px"><tr>${b.items
      .map(
        (item) =>
          `<td class="lf-card" width="${Math.floor(100 / b.items.length)}%" style="padding:12px 10px;border:1px solid ${T.line};border-radius:8px;text-align:center"><div style="font-family:${T.display};font-size:24px;color:${T.navy};line-height:1.2">${e(item.value)}</div><div class="lf-muted" style="font-family:${T.body};font-size:12px;color:${T.slate}">${e(item.label)}</div>${
            item.change ? `<div style="font-family:${T.body};font-size:12px;color:${String(item.change).startsWith("-") ? T.bad : T.ok}">${e(item.change)}</div>` : ""
          }</td>`
      )
      .join('<td width="8" style="font-size:1px">&nbsp;</td>')}</tr></table>`,
  listing: (b) => {
    const image = b.image
      ? `<td width="112" valign="top" style="padding-right:14px"><a href="${e(b.url)}"><img src="${e(b.image)}" width="112" height="80" alt="" style="display:block;width:112px;height:80px;object-fit:cover;border-radius:6px;border:0"></a></td>`
      : "";
    const status = b.status
      ? `<span style="display:inline-block;margin-top:6px;padding:2px 8px;border-radius:999px;background:${(TONES[b.statusTone] ?? TONES.info)[0]};color:${(TONES[b.statusTone] ?? TONES.info)[1]};font-family:${T.body};font-size:11px;font-weight:700">${e(b.status)}</span>`
      : "";
    return card(
      `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>${image}<td valign="top">${strong(b.title, b.url)}${
        b.price ? `<div style="font-family:${T.body};font-size:14px;font-weight:600;color:${T.red};margin:0 0 4px">${e(b.price)}</div>` : ""
      }${b.facts?.length ? small(e(b.facts.filter(Boolean).join(" · "))) : ""}${b.reference ? small(`Ref ${e(b.reference)}`) : ""}${status}</td></tr></table>`
    );
  },
  lead: (b) =>
    card(
      `${strong(b.name)}${small([b.email, b.phone].filter(Boolean).map(e).join(" · "))}${
        b.about ? small(`About: ${e(b.about)}`, "margin-top:4px") : ""
      }${b.message ? `<div class="lf-text" style="margin-top:10px;font-family:${T.body};font-size:14px;line-height:1.6;color:${T.ink}">“${inline(b.message)}”</div>` : ""}${
        b.receivedAt ? small(`Received ${e(b.receivedAt)}`, "margin-top:8px") : ""
      }`
    ),
  event: (b) =>
    card(
      `${strong(b.title, b.url)}<div style="font-family:${T.body};font-size:15px;font-weight:600;color:${T.navy};margin:4px 0">${e(b.when)}</div>${
        b.location ? small(e(b.location)) : ""
      }${b.with ? small(`With ${e(b.with)}`) : ""}${(b.lines ?? []).map((line) => small(e(line))).join("")}`
    ),
};

const TEXT = {
  p: (b) => plainInline(b.text),
  h: (b) => `${b.text}\n${"-".repeat(Math.min(60, b.text.length))}`,
  button: (b) => `${b.label}: ${b.url}${b.note ? `\n${b.note}` : ""}`,
  link: (b) => `${b.label}: ${b.url}`,
  divider: () => "----",
  alert: (b) => plainInline(b.text),
  quote: (b) => `> ${plainInline(b.text).replace(/\n/g, "\n> ")}${b.by ? `\n  ${b.by}` : ""}`,
  list: (b) => b.items.map((item) => `- ${plainInline(item)}`).join("\n"),
  code: (b) => b.text,
  table: (b) => b.rows.map(([label, value]) => `${label}: ${value ?? "—"}`).join("\n"),
  issues: (b) => [...b.items.flatMap((item) => [item.label, ...item.reasons.map((reason) => `  - ${reason}`)]), b.more].filter(Boolean).join("\n"),
  stats: (b) => b.items.map((item) => `${item.label}: ${item.value}${item.change ? ` (${item.change})` : ""}`).join("\n"),
  listing: (b) => [b.title, b.price, b.facts?.filter(Boolean).join(" · "), b.reference && `Ref ${b.reference}`, b.status, b.url].filter(Boolean).join("\n"),
  lead: (b) => [b.name, [b.email, b.phone].filter(Boolean).join(" · "), b.about && `About: ${b.about}`, b.message && `"${b.message}"`, b.receivedAt && `Received ${b.receivedAt}`].filter(Boolean).join("\n"),
  event: (b) => [b.title, b.when, b.location, b.with && `With ${b.with}`, ...(b.lines ?? []), b.url].filter(Boolean).join("\n"),
};

const DARK_CSS = `
:root{color-scheme:light dark;supported-color-schemes:light dark}
@media (prefers-color-scheme:dark){
  .lf-canvas{background:#0d141c!important}
  .lf-paper,.lf-head{background:#141e2a!important}
  .lf-card{border-color:#263446!important}
  .lf-soft{background:#1b2838!important}
  .lf-text,.lf-text p,.lf-text li{color:#e5ebf2!important}
  .lf-muted{color:#98a6b6!important}
  .lf-link{color:#7fb0e6!important}
  .lf-btn2{color:#7fb0e6!important}
}
[data-ogsc] .lf-canvas{background:#0d141c!important}
[data-ogsc] .lf-paper,[data-ogsc] .lf-head{background:#141e2a!important}
[data-ogsc] .lf-text{color:#e5ebf2!important}
[data-ogsc] .lf-muted{color:#98a6b6!important}
[data-ogsc] .lf-link{color:#7fb0e6!important}
@media only screen and (max-width:620px){.lf-pad{padding:22px 18px!important}.lf-wrap{width:100%!important}}
`;

/** The preview gallery forces dark mode with this class, since an iframe follows the OS setting. */
const FORCED_DARK = DARK_CSS.match(/@media \(prefers-color-scheme:dark\)\{([\s\S]*?)\n\}/)[1].replace(/(^|\n)\s*\./g, "$1.lf-force-dark .");

/**
 * Lays a template's output into the LivFinder shell.
 * `footer` = { reason, settingsUrl, unsubscribeUrl, reference }.
 */
export function renderEmail({ subject, preheader, heading, blocks = [], footer = {}, locale = "en", forceDark = false }) {
  const dir = locale === "ar" ? "rtl" : "ltr";
  const body = blocks.filter(Boolean).map((block) => (RENDER[block.type] ?? RENDER.p)(block)).join("\n");
  const logo = assetUrl("/brand/email-logo.png");
  const year = new Date().getFullYear();
  const footerLinks = [
    footer.settingsUrl && `<a href="${e(footer.settingsUrl)}" class="lf-link" style="color:${T.navy}">Email settings</a>`,
    footer.unsubscribeUrl && `<a href="${e(footer.unsubscribeUrl)}" class="lf-link" style="color:${T.navy}">Unsubscribe</a>`,
    `<a href="${e(siteUrl("/privacy-policy"))}" class="lf-link" style="color:${T.navy}">Privacy</a>`,
    `<a href="${e(siteUrl("/contact-us"))}" class="lf-link" style="color:${T.navy}">Help</a>`,
  ].filter(Boolean);

  const html = `<!doctype html>
<html lang="${e(locale)}" dir="${dir}" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="x-apple-disable-message-reformatting">
<meta name="color-scheme" content="light dark"><meta name="supported-color-schemes" content="light dark">
<title>${e(subject)}</title>
<!--[if !mso]><!--><link href="https://fonts.googleapis.com/css2?family=Open+Sans:wght@400;600;700&family=Prata&display=swap" rel="stylesheet"><!--<![endif]-->
<style>${DARK_CSS}${forceDark ? FORCED_DARK : ""}</style>
</head>
<body class="${forceDark ? "lf-force-dark" : ""}" style="margin:0;padding:0;background:${T.canvas}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;mso-hide:all">${e(preheader || "")}${"&#847;&zwnj;&nbsp;".repeat(30)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="lf-canvas" style="background:${T.canvas}"><tr><td align="center" style="padding:24px 12px">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" class="lf-wrap" style="width:600px;max-width:600px">
<tr><td class="lf-head" style="background:${T.paper};padding:20px 32px;border-radius:10px 10px 0 0" align="${dir === "rtl" ? "right" : "left"}">
<a href="${e(siteUrl("/"))}" target="_blank" style="text-decoration:none"><img src="${e(logo)}" width="150" height="51" alt="LivFinder" style="display:block;width:150px;height:auto;border:0;font-family:${T.display};font-size:22px;color:${T.red}"></a>
</td></tr>
<tr><td style="background:${T.navy};height:4px;line-height:4px;font-size:4px">&nbsp;</td></tr>
<tr><td class="lf-paper lf-pad lf-text" style="background:${T.paper};padding:30px 32px 14px;border-radius:0 0 10px 10px" dir="${dir}">
${heading ? `<h1 class="lf-text" style="margin:0 0 16px;font-family:${T.display};font-weight:400;font-size:25px;line-height:1.3;color:${T.ink}">${e(heading)}</h1>` : ""}
${body}
</td></tr>
<tr><td class="lf-muted" style="padding:20px 32px 8px;font-family:${T.body};font-size:12px;line-height:1.6;color:${T.slate}" dir="${dir}">
${footer.reason ? `${e(footer.reason)}<br>` : ""}${footerLinks.join(" &nbsp;·&nbsp; ")}<br>
© ${year} ${e(env.EMAIL_LEGAL_NAME)}${footer.reference ? `<br><span style="color:#98a6b6">Ref ${e(footer.reference)}</span>` : ""}
</td></tr>
</table></td></tr></table>
</body></html>`;

  const text = [
    heading,
    "",
    ...blocks.filter(Boolean).flatMap((block) => [(TEXT[block.type] ?? TEXT.p)(block), ""]),
    "—",
    footer.reason,
    footer.settingsUrl && `Email settings: ${footer.settingsUrl}`,
    footer.unsubscribeUrl && `Unsubscribe: ${footer.unsubscribeUrl}`,
    `© ${new Date().getFullYear()} ${env.EMAIL_LEGAL_NAME}`,
  ]
    .filter((line) => line !== undefined && line !== null && line !== false)
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();

  return { html, text };
}
