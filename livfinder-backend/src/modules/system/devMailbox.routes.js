import { Router } from "express";
import fs from "node:fs/promises";
import path from "node:path";
import { AppError } from "../../utils/errors.js";
import { mailboxDirectory } from "./mail.service.js";

/**
 * A local inbox for the "log" mail driver, at /dev/mailbox.
 *
 * Mail here holds live confirmation and reset links, so it is mounted only outside production
 * and answers only this machine.
 */
export const devMailboxRouter = Router();

const FILE_NAME = /^[\w.@-]+\.txt$/;
const LOOPBACK = new Set(["127.0.0.1", "::1", "::ffff:127.0.0.1"]);
const STYLE = `body{margin:0 auto;max-width:860px;padding:24px;background:#f6f7f9;color:#111318;font:15px/1.5 system-ui,sans-serif}
h1{font-size:22px;margin:0 0 4px}p{color:#667085}a{color:#0c447c}.row{display:block;padding:12px 16px;margin-bottom:8px;border:1px solid #e2e5ea;border-radius:8px;background:#fff;text-decoration:none;color:inherit}
.row small{display:block;color:#667085}pre{padding:16px;border:1px solid #e2e5ea;border-radius:8px;background:#fff;white-space:pre-wrap;overflow-wrap:anywhere}`;

export const escapeHtml = (value) =>
  String(value).replace(/[&<>"']/g, (character) => `&#${character.charCodeAt(0)};`);

export const linkify = (escaped) => escaped.replace(/https?:\/\/[^\s<&]+(?:&#38;[^\s<&]+)*/g, (url) => `<a href="${url}" target="_blank" rel="noreferrer">${url}</a>`);

/** The name as it stands, or null: nothing outside the mailbox folder is reachable. */
export function mailFilePath(name) {
  return FILE_NAME.test(name) && !name.includes("..") ? path.join(mailboxDirectory(), name) : null;
}

function page(title, body) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeHtml(title)}</title><style>${STYLE}</style></head><body>${body}</body></html>`;
}

function send(res, html) {
  res.setHeader("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'");
  res.setHeader("Cache-Control", "no-store");
  return res.type("html").send(html);
}

async function readMail(name) {
  const file = mailFilePath(name);
  if (!file) throw AppError.notFound();
  return fs.readFile(file, "utf8").catch(() => {
    throw AppError.notFound("That email is no longer in the mailbox.");
  });
}

devMailboxRouter.use((req, res, next) =>
  LOOPBACK.has(req.socket.remoteAddress) ? next() : next(AppError.notFound())
);

devMailboxRouter.get("/", async (req, res, next) => {
  try {
    const names = (await fs.readdir(mailboxDirectory()).catch(() => []))
      .filter((name) => FILE_NAME.test(name))
      .sort()
      .reverse()
      .slice(0, 100);
    const rows = await Promise.all(
      names.map(async (name) => {
        const text = await fs.readFile(path.join(mailboxDirectory(), name), "utf8");
        const header = (label) => text.match(new RegExp(`^${label}: (.*)$`, "m"))?.[1] ?? "";
        return `<a class="row" href="/dev/mailbox/${encodeURIComponent(name)}"><strong>${escapeHtml(header("Subject"))}</strong><small>${escapeHtml(header("To"))} · ${escapeHtml(header("Date"))}</small></a>`;
      })
    );
    return send(res, page("Local mailbox", `<h1>Local mailbox</h1><p>Emails the app would have sent. Nothing here left this computer. Refresh after an action.</p>${rows.join("") || "<p>No emails yet.</p>"}`));
  } catch (error) {
    return next(error);
  }
});

devMailboxRouter.get("/:name/invite.ics", async (req, res, next) => {
  try {
    const text = await readMail(req.params.name);
    const start = text.indexOf("BEGIN:VCALENDAR");
    if (start < 0) throw AppError.notFound();
    res.setHeader("Content-Disposition", 'attachment; filename="invite.ics"');
    return res.type("text/calendar").send(text.slice(start));
  } catch (error) {
    return next(error);
  }
});

/** The designed (HTML) version the worker saved beside the text, shown as the recipient sees it. */
devMailboxRouter.get("/:name/html", async (req, res, next) => {
  try {
    const file = mailFilePath(req.params.name);
    if (!file) throw AppError.notFound();
    const html = await fs.readFile(file.replace(/\.txt$/, ".html"), "utf8").catch(() => {
      throw AppError.notFound("This email has no designed version.");
    });
    res.setHeader("Content-Security-Policy", "default-src 'none'; img-src * data:; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com; frame-ancestors 'self'");
    res.setHeader("Cache-Control", "no-store");
    return res.type("html").send(html);
  } catch (error) {
    return next(error);
  }
});

devMailboxRouter.get("/:name", async (req, res, next) => {
  try {
    const text = await readMail(req.params.name);
    const [visible] = text.split("\n--- invite.ics ---\n");
    const invite = text.includes("BEGIN:VCALENDAR")
      ? `<p><a href="/dev/mailbox/${encodeURIComponent(req.params.name)}/invite.ics">Download calendar invite</a></p>`
      : "";
    const htmlFile = mailFilePath(req.params.name)?.replace(/\.txt$/, ".html");
    const hasHtml = htmlFile ? await fs.access(htmlFile).then(() => true, () => false) : false;
    const designed = hasHtml
      ? `<p><a href="/dev/mailbox/${encodeURIComponent(req.params.name)}/html" target="_blank">Open the designed email</a></p><iframe title="Designed email" src="/dev/mailbox/${encodeURIComponent(req.params.name)}/html" style="width:100%;height:760px;border:1px solid #e2e5ea;border-radius:8px;background:#fff"></iframe><h2 style="font-size:16px;margin:24px 0 8px">Plain-text part</h2>`
      : "";
    res.setHeader("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; frame-src 'self'");
    res.setHeader("Cache-Control", "no-store");
    return res.type("html").send(page("Email", `<p><a href="/dev/mailbox">Back to mailbox</a> · <a href="/dev/emails">All email designs</a></p>${designed}<pre>${linkify(escapeHtml(visible))}</pre>${invite}`));
  } catch (error) {
    return next(error);
  }
});
