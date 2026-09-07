#!/usr/bin/env node
/**
 * Gives the seeded demo users a usable Argon2id password.
 *
 * The database seed ships a synthetic bcrypt placeholder that no plaintext
 * verifies against, so without this no demo account can sign in. This is the one
 * development fixture that could not be avoided: real passwords cannot be
 * derived from the seed, and inventing them inside the seed SQL would put a
 * usable credential in a committed file.
 *
 * Refuses to run against NODE_ENV=production. Idempotent.
 *
 *   npm run seed:dev-passwords            # every demo user gets DEV_PASSWORD
 *   DEV_PASSWORD=... npm run seed:dev-passwords
 */
import env from "../src/config/env.js";
import logger from "../src/config/logger.js";
import { query, execute } from "../src/db/query.js";
import { closePool } from "../src/db/pool.js";
import { hashPassword } from "../src/modules/auth/passwords.js";

const DEFAULT_PASSWORD = process.env.DEV_PASSWORD || "LivFinder!2026";

export async function seedDevPasswords({ password = DEFAULT_PASSWORD } = {}) {
  if (env.isProduction) {
    throw new Error("seed:dev-passwords refuses to run with NODE_ENV=production");
  }

  const hash = await hashPassword(password);
  // One hash for every demo row: the point is a working sign-in, not a
  // per-user secret. Any account whose hash is already Argon2id is left alone,
  // so a password changed through the API survives a re-run.
  const result = await execute(
    `UPDATE users
        SET password_hash = ?, password_updated_at = NOW(3),
            failed_login_count = 0, locked_until = NULL
      WHERE deleted_at IS NULL
        AND password_hash NOT LIKE '$argon2%'`,
    [hash]
  );

  const samples = await query(
    `SELECT u.email, u.status,
            GROUP_CONCAT(DISTINCT r.code) AS platform_roles,
            GROUP_CONCAT(DISTINCT CONCAT(at.code, ':', am.role)) AS memberships
       FROM users u
       LEFT JOIN user_roles ur ON ur.user_id = u.id
       LEFT JOIN roles r ON r.id = ur.role_id
       LEFT JOIN account_members am ON am.user_id = u.id AND am.status = 'active'
       LEFT JOIN accounts a ON a.id = am.account_id
       LEFT JOIN account_types at ON at.id = a.account_type_id
      WHERE u.deleted_at IS NULL AND u.status = 'active'
      GROUP BY u.id
      HAVING platform_roles IS NOT NULL OR memberships IS NOT NULL
      ORDER BY (platform_roles IS NULL), u.id
      LIMIT 12`,
    []
  );

  return { updated: result.affectedRows, password, samples };
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  seedDevPasswords()
    .then(async (result) => {
      logger.info({ updated: result.updated }, "development passwords seeded");
      // eslint-disable-next-line no-console
      console.log(`\n  Password for every seeded demo user: ${result.password}\n`);
      // eslint-disable-next-line no-console
      console.table(
        result.samples.map((row) => ({
          email: row.email,
          platformRoles: row.platform_roles || "—",
          memberships: row.memberships || "—",
        }))
      );
      await closePool();
      process.exit(0);
    })
    .catch(async (error) => {
      logger.error({ err: error }, "seeding development passwords failed");
      await closePool();
      process.exit(1);
    });
}
