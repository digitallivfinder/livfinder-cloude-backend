import "dotenv/config";
import fs from "node:fs";
import path from "node:path";

/**
 * Prints each email in one clean terminal while MAIL_DRIVER=log: `npm run mail:watch`.
 *
 * The API saves every email to storage/mailbox instead of sending it; this shows them as they
 * arrive, without the request logs around them. With MAIL_DRIVER=smtp mail goes to the real
 * recipient and nothing arrives here.
 */
const directory = path.resolve(process.cwd(), process.env.LOCAL_STORAGE_PATH || "./storage", "mailbox");
const line = "=".repeat(72);
const seen = new Set();

fs.mkdirSync(directory, { recursive: true });
for (const name of fs.readdirSync(directory)) seen.add(name);

function show(name) {
  if (seen.has(name) || !name.endsWith(".txt")) return;
  seen.add(name);
  const file = path.join(directory, name);
  // The driver writes the file in one call, so a short wait is enough to read it whole.
  setTimeout(() => {
    const text = fs.readFileSync(file, "utf8");
    const [mail, attachment] = text.split(/\n--- .+ ---\n/);
    const body = mail.replace(/^From: .*\n/, "").replace(/^Date: .*\n/m, "");
    console.log(`\n${line}\n${body.trim()}${attachment ? "\n\nAttached: calendar invite" : ""}\n${line}`);
  }, 100);
}

console.log(`Waiting for emails...\nInbox: http://localhost:${process.env.PORT || 4000}/dev/mailbox`);
fs.watch(directory, (event, name) => name && show(name));
