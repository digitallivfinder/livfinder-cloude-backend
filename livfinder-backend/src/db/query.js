import { getPool } from "./pool.js";
import logger from "../config/logger.js";
import { AppError } from "../utils/errors.js";

// Every value reaching MySQL goes through a placeholder. Nothing in this module
// interpolates a caller-supplied value into SQL text.
function assertParameterised(sql, params) {
  if (params === undefined) return;
  if (!Array.isArray(params)) {
    throw new TypeError("query parameters must be an array");
  }
  const placeholders = (sql.match(/\?/g) || []).length;
  if (placeholders !== params.length) {
    throw new TypeError(
      `SQL placeholder count (${placeholders}) does not match parameter count (${params.length})`
    );
  }
}

function wrapDbError(error, sql) {
  // The message and the SQL text can carry table structure and, for a
  // constraint violation, row values. Log them; never return them.
  logger.error(
    { err: { code: error.code, errno: error.errno, message: error.message }, sql: sql.slice(0, 400) },
    "database query failed"
  );
  return AppError.internal("A database error occurred.", { cause: error });
}

export async function query(sql, params = [], executor) {
  assertParameterised(sql, params);
  const runner = executor || getPool();
  try {
    const [rows] = await runner.execute(sql, params);
    return rows;
  } catch (error) {
    if (error.code === "ER_UNSUPPORTED_PS") {
      // A few statements (SET, some DDL) cannot be prepared. Fall back to the
      // text protocol with the same escaping guarantees.
      try {
        const [rows] = await runner.query(sql, params);
        return rows;
      } catch (fallbackError) {
        throw wrapDbError(fallbackError, sql);
      }
    }
    throw wrapDbError(error, sql);
  }
}

export async function queryOne(sql, params = [], executor) {
  const rows = await query(sql, params, executor);
  return rows[0] || null;
}

export async function queryValue(sql, params = [], executor) {
  const row = await queryOne(sql, params, executor);
  if (!row) return null;
  return Object.values(row)[0];
}

export async function execute(sql, params = [], executor) {
  assertParameterised(sql, params);
  const runner = executor || getPool();
  try {
    const [result] = await runner.execute(sql, params);
    return result;
  } catch (error) {
    throw wrapDbError(error, sql);
  }
}

// Runs a stored procedure. CALL cannot always use the prepared protocol on
// older servers, so it goes through query() with the same placeholder rules.
export async function callProcedure(name, params = [], executor) {
  if (!/^[a-z_][a-z0-9_]*$/i.test(name)) {
    throw new TypeError(`unsafe procedure name: ${name}`);
  }
  const placeholders = params.map(() => "?").join(", ");
  const runner = executor || getPool();
  try {
    await runner.query(`CALL \`${name}\`(${placeholders})`, params);
  } catch (error) {
    throw wrapDbError(error, `CALL ${name}`);
  }
}

// Builds `IN (?, ?, ?)` with a matching parameter list. Returns null when the
// list is empty so the caller can short-circuit instead of emitting `IN ()`.
export function inClause(values) {
  const list = [...new Set((values || []).filter((value) => value !== null && value !== undefined))];
  if (!list.length) return null;
  return { sql: `(${list.map(() => "?").join(", ")})`, params: list };
}
