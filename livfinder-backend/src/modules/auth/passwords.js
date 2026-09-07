import argon2 from "argon2";
import bcrypt from "bcryptjs";

// Argon2id with parameters that cost roughly 60-90ms on a modern server. Raise
// memoryCost before timeCost if hardware allows.
const ARGON2_OPTIONS = {
  type: argon2.argon2id,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
};

export async function hashPassword(plain) {
  return argon2.hash(plain, ARGON2_OPTIONS);
}

/**
 * Verifies against whichever scheme the stored hash uses.
 *
 * The seeded demo rows carry bcrypt placeholders. Accepting bcrypt lets those
 * rows be migrated in place on the owner's next successful sign-in rather than
 * forcing a reset; `needsRehash` tells the caller to upgrade the stored value.
 */
export async function verifyPassword(storedHash, plain) {
  if (!storedHash || !plain) return { valid: false, needsRehash: false };
  try {
    if (storedHash.startsWith("$argon2")) {
      const valid = await argon2.verify(storedHash, plain);
      return { valid, needsRehash: valid && argon2.needsRehash(storedHash, ARGON2_OPTIONS) };
    }
    if (storedHash.startsWith("$2")) {
      // bcryptjs only understands $2a/$2b; $2y is the same algorithm.
      const normalized = storedHash.replace(/^\$2y\$/, "$2b$");
      const valid = await bcrypt.compare(plain, normalized);
      return { valid, needsRehash: valid };
    }
  } catch {
    return { valid: false, needsRehash: false };
  }
  return { valid: false, needsRehash: false };
}

const COMMON = new Set([
  "password", "password1", "12345678", "qwertyui", "letmein1", "welcome1",
  "livfinder", "changeme", "iloveyou", "adminadmin",
]);

/** Returns null when acceptable, or a user-facing reason when not. */
export function passwordPolicyError(password, { email } = {}) {
  if (typeof password !== "string" || password.length < 10) {
    return "Password must be at least 10 characters.";
  }
  if (password.length > 200) return "Password must be 200 characters or fewer.";
  if (COMMON.has(password.toLowerCase())) return "That password is too common.";
  if (email && password.toLowerCase().includes(String(email).split("@")[0].toLowerCase())) {
    return "Password must not contain your email address.";
  }
  if (!/[a-z]/i.test(password) || !/[0-9]/.test(password)) {
    return "Password must contain at least one letter and one number.";
  }
  return null;
}
