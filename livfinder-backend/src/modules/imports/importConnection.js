import { execute, queryOne, queryValue } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";

export const IMPORT_PROVIDER_CODE = "livfinder_import";

let providerIdPromise = null;

/** The `integration_providers` row every API import runs under (migration 0058). */
export function importProviderId() {
  if (!providerIdPromise) {
    providerIdPromise = queryValue("SELECT id FROM integration_providers WHERE code = ? LIMIT 1", [IMPORT_PROVIDER_CODE])
      .then((id) => {
        if (!id) throw AppError.serviceUnavailable("The listing API is not set up on this server (migration 0058).");
        return Number(id);
      })
      .catch((error) => {
        providerIdPromise = null;
        throw error;
      });
  }
  return providerIdPromise;
}

/**
 * One inbound connection per organization, shared by every way listings come in, so a partner's
 * id names the same listing whichever channel sends it. The unique key
 * (provider, organization, direction) decides a race between two first pushes.
 */
export async function ensureImportConnection({ organizationId, accountId, name }) {
  const providerId = await importProviderId();
  const existing = await queryOne(
    `SELECT id FROM integration_connections
      WHERE provider_id = ? AND organization_id = ? AND direction = 'inbound' LIMIT 1`,
    [providerId, organizationId]
  );
  if (existing) return { providerId, connectionId: Number(existing.id) };

  await execute(
    `INSERT INTO integration_connections
       (public_id, provider_id, organization_id, account_id, name, direction, status, is_enabled,
        last_connected_at, created_at)
     VALUES (?, ?, ?, ?, ?, 'inbound', 'connected', 1, NOW(3), NOW(3))
     ON DUPLICATE KEY UPDATE id = id`,
    [ulid(), providerId, organizationId, accountId ?? null, (name || "Listing API").slice(0, 160)]
  );
  const row = await queryOne(
    `SELECT id FROM integration_connections
      WHERE provider_id = ? AND organization_id = ? AND direction = 'inbound' LIMIT 1`,
    [providerId, organizationId]
  );
  return { providerId, connectionId: Number(row.id) };
}
