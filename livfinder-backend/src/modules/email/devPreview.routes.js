import { Router } from "express";
import { AppError } from "../../utils/errors.js";
import { CATEGORIES } from "./catalog.js";
import { escapeHtml } from "./format.js";
import { TEMPLATES } from "./templates/index.js";
import { composeMessage } from "./worker.js";

/**
 * /dev/emails: every email design, rendered from its sample data, light and dark side by side,
 * at desktop and phone width, with the plain-text part. Loopback only, never in production.
 */
export const devEmailsRouter = Router();

const LOOPBACK = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);
devEmailsRouter.use((req, res, next) => (LOOPBACK.has(req.socket.remoteAddress) ? next() : next(AppError.notFound())));

const STYLE = `body{margin:0;font:14px/1.5 system-ui,sans-serif;background:#f6f7f9;color:#111318;display:grid;grid-template-columns:280px 1fr;min-height:100vh}
nav{background:#fff;border-right:1px solid #e2e5ea;padding:16px;overflow:auto;max-height:100vh;position:sticky;top:0}
nav h1{font-size:18px;margin:0 0 4px}nav h2{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:#667085;margin:16px 0 4px}
nav a{display:block;padding:4px 8px;border-radius:6px;color:#0c447c;text-decoration:none}nav a.on{background:#e8eff7;font-weight:600}
main{padding:20px;min-width:0}.row{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-start}
figure{margin:0}figcaption{font-size:12px;color:#667085;margin-bottom:6px}iframe{border:1px solid #e2e5ea;border-radius:8px;background:#fff}
pre{background:#fff;border:1px solid #e2e5ea;border-radius:8px;padding:16px;white-space:pre-wrap;max-width:900px}`;

const sampleRow = (key) => ({ template_key: key, data: TEMPLATES[key].sample ?? {}, to_email: "preview@livfinder.com", to_name: "Sara Haddad", public_id: "PREVIEW", user_id: null, reply_to: null });

function frameHeaders(res) {
  res.setHeader("Content-Security-Policy", "default-src 'none'; img-src * data:; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; frame-ancestors 'self'");
  res.setHeader("Cache-Control", "no-store");
}

devEmailsRouter.get("/:key/render", async (req, res, next) => {
  try {
    if (!TEMPLATES[req.params.key]) throw AppError.notFound();
    const message = await composeMessage(sampleRow(req.params.key), { forceDark: req.query.theme === "dark" });
    frameHeaders(res);
    return res.type("html").send(message.html);
  } catch (error) {
    return next(error);
  }
});

devEmailsRouter.get(["/", "/:key"], async (req, res, next) => {
  try {
    const keys = Object.keys(TEMPLATES);
    const key = req.params.key && TEMPLATES[req.params.key] ? req.params.key : keys[0];
    const message = await composeMessage(sampleRow(key));
    const groups = {};
    for (const item of keys) (groups[TEMPLATES[item].category] ??= []).push(item);
    const nav = Object.entries(groups)
      .map(([category, items]) => `<h2>${escapeHtml(CATEGORIES[category].label)}</h2>${items.map((item) => `<a class="${item === key ? "on" : ""}" href="/dev/emails/${item}">${escapeHtml(TEMPLATES[item].label)}</a>`).join("")}`)
      .join("");
    const src = (theme) => `/dev/emails/${encodeURIComponent(key)}/render${theme ? `?theme=${theme}` : ""}`;
    res.setHeader("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-src 'self'");
    res.setHeader("Cache-Control", "no-store");
    return res.type("html").send(`<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Email designs</title><style>${STYLE}</style></head><body>
<nav><h1>Email designs</h1><p style="color:#667085;margin:0">${keys.length} templates · sample data · <a href="/dev/mailbox" style="display:inline;padding:0">mailbox</a></p>${nav}</nav>
<main><h2 style="margin:0 0 2px">${escapeHtml(TEMPLATES[key].label)}</h2><p style="margin:0 0 16px;color:#667085"><code>${escapeHtml(key)}</code> · ${escapeHtml(CATEGORIES[TEMPLATES[key].category].label)} · Subject: <strong>${escapeHtml(message.subject)}</strong></p>
<div class="row">
<figure><figcaption>Light · 640px</figcaption><iframe title="Light" src="${src()}" width="640" height="900"></iframe></figure>
<figure><figcaption>Dark · 640px</figcaption><iframe title="Dark" src="${src("dark")}" width="640" height="900"></iframe></figure>
<figure><figcaption>Phone · 375px</figcaption><iframe title="Phone" src="${src()}" width="375" height="900"></iframe></figure>
</div><h3>Plain-text part</h3><pre>${escapeHtml(message.text)}</pre></main></body></html>`);
  } catch (error) {
    return next(error);
  }
});
