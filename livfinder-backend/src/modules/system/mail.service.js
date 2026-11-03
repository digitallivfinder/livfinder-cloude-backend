import fs from "node:fs/promises";
import path from "node:path";
import env from "../../config/env.js";
import logger from "../../config/logger.js";

/**
 * Mail adapter.
 *
 * The "log" driver is a real development mailbox: every message is written to
 * storage/mailbox as a readable .txt file and logged, so a password-reset flow
 * can be tested end to end without SMTP credentials. Point MAIL_DRIVER at
 * "smtp" and set SMTP_* to send for real.
 */
const mailboxDir = () => path.resolve(process.cwd(), env.LOCAL_STORAGE_PATH, "mailbox");

let sentInMemory = [];

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
  const file = path.join(dir, `${stamp}-${safeTo}.txt`);
  await fs.writeFile(
    file,
    `From: ${message.from}\nTo: ${message.to}\nSubject: ${message.subject}\nDate: ${new Date().toISOString()}\n\n${message.text}\n${(message.attachments ?? [])
      .map((attachment) => `\n--- ${attachment.filename} ---\n${attachment.content}`)
      .join("")}`
  );
  logger.info({ to: message.to, subject: message.subject, file }, "mail written to development mailbox");
  if (!env.isProduction && !env.isTest) printToTerminal(message);
  return { delivered: true, driver: "log", file };
}

async function smtpDriver(message) {
  if (!env.SMTP_HOST) {
    logger.warn("MAIL_DRIVER=smtp but SMTP_HOST is unset — falling back to the development mailbox");
    return logDriver(message);
  }
  // nodemailer is intentionally not a dependency: with no SMTP credentials in
  // this workspace it could not be exercised, and an untested transport is
  // worse than a documented gap. Install nodemailer and replace this branch
  // when real credentials exist; the interface above does not change.
  const { createTransport } = await import("nodemailer").catch(() => ({ createTransport: null }));
  if (!createTransport) {
    logger.warn("nodemailer is not installed — falling back to the development mailbox");
    return logDriver(message);
  }
  const transport = createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_PORT === 465,
    auth: env.SMTP_USER ? { user: env.SMTP_USER, pass: env.SMTP_PASSWORD } : undefined,
  });
  await transport.sendMail(message);
  return { delivered: true, driver: "smtp" };
}

export async function sendMail({ to, subject, text, html, attachments, from = env.MAIL_FROM }) {
  const message = { from, to, subject, text, html, attachments };
  sentInMemory.push({ ...message, sentAt: new Date().toISOString() });
  if (sentInMemory.length > 100) sentInMemory = sentInMemory.slice(-100);
  if (env.isTest) return { delivered: true, driver: "memory" };
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
