import crypto from "node:crypto";

const CROCKFORD = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

/**
 * ULID-shaped 26-character Crockford base32 public id, matching the CHAR(26)
 * `public_id` columns the schema uses everywhere. Monotonic within a
 * millisecond is not required here; uniqueness and sortability are.
 */
export function ulid(now = Date.now()) {
  let timePart = "";
  let time = now;
  for (let index = 0; index < 10; index += 1) {
    timePart = CROCKFORD[time % 32] + timePart;
    time = Math.floor(time / 32);
  }
  const random = crypto.randomBytes(16);
  let randomPart = "";
  for (let index = 0; index < 16; index += 1) {
    randomPart += CROCKFORD[random[index] % 32];
  }
  return timePart + randomPart;
}

export function randomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString("base64url");
}

export function sha256(value) {
  return crypto.createHash("sha256").update(value).digest();
}

export function sha256Hex(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

export function requestId() {
  return crypto.randomUUID();
}
