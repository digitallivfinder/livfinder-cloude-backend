import fs from "node:fs/promises";
import path from "node:path";
import env from "../../config/env.js";
import logger from "../../config/logger.js";

/**
 * Mail transport. Nothing in the app calls this directly any more: emails are queued with
 * `queueEmail` (modules/email/send.js) and the email worker hands each one here.
 *
 * The "log" driver is a real development mailbox: every message is written to storage/mailbox
 * (a readable .txt, plus the HTML part as .html) and shown at /dev/mailbox, so every flow can be
 * tested end to end without SMTP credentials. MAIL_DRIVER=smtp with SMTP_* set sends for real.
 */
const mailboxDir = () => path.resolve(process.cwd(), env.LOCAL_STORAGE_PATH, "mailbox");

let sentInMemory = [];
let transportPromise = null;

/** "LivFinder <no-reply@livfinder.com>" from a bare address and a name. */
export function formatAddress(address, name = env.MAIL_FROM_NAME) {
  if (!address || /</.test(address) || !name) return address;
  return `"${String(name).replace(/["\\]/g, "")}" <${address}>`;
}

/** The development inbox, as readable text between the JSON log lines. */
function printToTerminal(message) {
  const line = "=".repeat(72);
  const attachments = (message.attachments ?? []).map((attachment) => attachment.filename).join(", ");
  process.stdout.write(
    `\n${line}\nEMAIL (not sent: MAIL_DRIVER=log)\nTo:      ${message.to}\nSubject: ${message.subject}\n${
      attachments ? `Attached: ${attachments}\n` : ""
    }\n${message.text}\n\nInbox: http://localhost:${env.PORT}/dev/mailbox\n${line}\n\n`
  );
}

async function logDriver(message) {
  const dir = mailboxDir();
  await fs.mkdir(dir, { recursive: true });
  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  const safeTo = String(message.to).replace(/[^a-zA-Z0-9@._-]/g, "_");
  const base = path.join(dir, `${stamp}-${safeTo}`);
  const headerLines = Object.entries(message.headers ?? {}).map(([key, value]) => `${key}: ${value}`);
  await fs.writeFile(
    `${base}.txt`,
    [
      `From: ${message.from}`,
      `To: ${message.to}`,
      message.replyTo ? `Reply-To: ${message.replyTo}` : null,
      `Subject: ${message.subject}`,
      `Date: ${new Date().toISOString()}`,
      ...headerLines,
    ]
      .filter(Boolean)
      .join("\n") +
      `\n\n${message.text}\n${(message.attachments ?? [])
        .map((attachment) => `\n--- ${attachment.filename} ---\n${attachment.content}`)
        .join("")}`
  );
  if (message.html) await fs.writeFile(`${base}.html`, message.html);
  logger.info({ to: message.to, subject: message.subject, file: `${base}.txt` }, "mail written to development mailbox");
  if (!env.isProduction && !env.isTest) printToTerminal(message);
  return { delivered: true, driver: "log", file: `${base}.txt`, messageId: path.basename(base) };
}

async function smtpTransport() {
  if (!transportPromise) {
    transportPromise = import("nodemailer")
      .then(({ createTransport }) =>
        createTransport({
          host: env.SMTP_HOST,
          port: env.SMTP_PORT,
          secure: env.SMTP_SECURE ?? env.SMTP_PORT === 465,
          auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASSWORD } : undefined,
          // One open connection reused by the worker instead of a handshake per email.
          pool: true,
          maxConnections: 3,
        })
      )
      .catch((error) => {
        transportPromise = null;
        throw error;
      });
  }
  return transportPromise;
}

async function smtpDriver(message) {
  if (!env.SMTP_HOST) {
    logger.warn("MAIL_DRIVER=smtp but SMTP_HOST is unset — falling back to the development mailbox");
    return logDriver(message);
  }
  const transport = await smtpTransport();
  const info = await transport.sendMail(message);
  return { delivered: true, driver: "smtp", messageId: info?.messageId ?? null };
}

/** Checks the SMTP login without sending anything (admin Emails screen → "Test connection"). */
export async function verifyTransport() {
  if (env.MAIL_DRIVER !== "smtp") return { ok: true, driver: "log", detail: "MAIL_DRIVER=log: emails go to the development mailbox." };
  if (!env.SMTP_HOST) return { ok: false, driver: "smtp", detail: "SMTP_HOST is empty." };
  try {
    const transport = await smtpTransport();
    await transport.verify();
    return { ok: true, driver: "smtp", detail: `Connected to ${env.SMTP_HOST}:${env.SMTP_PORT}.` };
  } catch (error) {
    return { ok: false, driver: "smtp", detail: error.message };
  }
}

export async function sendMail({ to, subject, text, html, attachments, from = env.MAIL_FROM, fromName, replyTo, headers }) {
  const message = {
    from: formatAddress(from, fromName ?? env.MAIL_FROM_NAME),
    to,
    subject,
    text,
    html,
    attachments,
    replyTo: replyTo ?? env.MAIL_REPLY_TO ?? env.EMAIL_SUPPORT_ADDRESS ?? undefined,
    headers: headers && Object.keys(headers).length ? headers : undefined,
  };
  sentInMemory.push({ ...message, sentAt: new Date().toISOString() });
  if (sentInMemory.length > 100) sentInMemory = sentInMemory.slice(-100);
  if (env.isTest) return { delivered: true, driver: "memory", messageId: `memory-${sentInMemory.length}` };
  return env.MAIL_DRIVER === "smtp" ? smtpDriver(message) : logDriver(message);
}

export const mailboxDirectory = mailboxDir;

/** Used by the integration tests to assert a message was produced. */
export function sentMessages() {
  return [...sentInMemory];
}

export function clearSentMessages() {
  sentInMemory = [];
}
