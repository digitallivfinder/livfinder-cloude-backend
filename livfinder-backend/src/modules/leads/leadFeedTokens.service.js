import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { randomToken, sha256, ulid } from "../../utils/ids.js";

/**
 * Read-only lead feed addresses (Phase 6, 0064), for CRMs that can only fetch a URL and cannot
 * send an API key. The token in the address reads this account's leads and nothing else; it is
 * stored only as a hash, shown once, and can be revoked at any time.
 */

function serialize(row) {
  return {
    id: row.public_id,
    name: row.name,
    hint: row.token_hint ? `••••${row.token_hint}` : null,
    status: row.status,
    lastUsedAt: row.last_used_at,
    createdAt: row.created_at,
  };
}

export async function listFeedTokens(accountId) {
  return (await query("SELECT * FROM lead_feed_tokens WHERE account_id = ? ORDER BY created_at DESC", [accountId])).map(serialize);
}

export async function createFeedToken({ accountId, name, userId }) {
  const token = `lft_${randomToken(24)}`;
  const publicId = ulid();
  await execute(
    "INSERT INTO lead_feed_tokens (public_id, account_id, name, token_hash, token_hint, created_by_user_id) VALUES (?, ?, ?, ?, ?, ?)",
    [publicId, accountId, name, sha256(token), token.slice(-4), userId ?? null]
  );
  const row = await queryOne("SELECT * FROM lead_feed_tokens WHERE public_id = ?", [publicId]);
  return { ...serialize(row), token };
}

export async function revokeFeedToken({ accountId, publicId }) {
  const result = await execute(
    "UPDATE lead_feed_tokens SET status = 'revoked', revoked_at = NOW(3) WHERE public_id = ? AND account_id = ? AND status = 'active'",
    [publicId, accountId]
  );
  if (!result.affectedRows) throw AppError.notFound("That feed address was not found, or it is already revoked.");
  return true;
}

/** The account a token reads, or null for an unknown or revoked one. */
export async function accountForToken(token) {
  if (!token || !/^lft_[A-Za-z0-9_-]{20,64}$/.test(token)) return null;
  const row = await queryOne(
    `SELECT t.id, t.account_id FROM lead_feed_tokens t JOIN accounts a ON a.id = t.account_id AND a.status = 'active'
      WHERE t.token_hash = ? AND t.status = 'active'`,
    [sha256(token)]
  );
  if (!row) return null;
  await execute("UPDATE lead_feed_tokens SET last_used_at = NOW(3) WHERE id = ?", [row.id]);
  return Number(row.account_id);
}
