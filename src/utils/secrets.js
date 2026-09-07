import crypto from "node:crypto";
import env from "../config/env.js";

/**
 * AES-256-GCM for values that must survive a restart but must never leave the
 * server: payment provider secret keys, webhook signing secrets, and the like.
 *
 * The key is derived from SESSION_SECRET with a fixed, non-secret salt — the
 * secret itself is the secret. Rotating SESSION_SECRET therefore invalidates
 * stored ciphertexts, which is the intended behaviour: they are re-entered.
 */
const PREFIX = "enc:v1:";

function key() {
  return crypto.scryptSync(env.SESSION_SECRET, "livfinder.settings.v1", 32);
}

export function encryptSecret(plain) {
  if (plain === null || plain === undefined || plain === "") return null;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key(), iv);
  const encrypted = Buffer.concat([cipher.update(String(plain), "utf8"), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${PREFIX}${iv.toString("base64url")}.${tag.toString("base64url")}.${encrypted.toString("base64url")}`;
}

export function decryptSecret(stored) {
  if (typeof stored !== "string" || !stored.startsWith(PREFIX)) return null;
  try {
    const [ivPart, tagPart, dataPart] = stored.slice(PREFIX.length).split(".");
    const decipher = crypto.createDecipheriv("aes-256-gcm", key(), Buffer.from(ivPart, "base64url"));
    decipher.setAuthTag(Buffer.from(tagPart, "base64url"));
    return Buffer.concat([decipher.update(Buffer.from(dataPart, "base64url")), decipher.final()]).toString("utf8");
  } catch {
    return null;
  }
}

export function isEncrypted(value) {
  return typeof value === "string" && value.startsWith(PREFIX);
}

/** What a browser is allowed to know about a stored secret: whether it exists. */
export function secretStatus(stored) {
  const plain = decryptSecret(stored);
  return {
    configured: Boolean(stored),
    // Last four characters only, so an operator can tell two keys apart.
    hint: plain ? `••••${plain.slice(-4)}` : stored ? "••••" : null,
  };
}
