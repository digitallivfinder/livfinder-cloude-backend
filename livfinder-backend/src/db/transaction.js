import { getPool } from "./pool.js";
import logger from "../config/logger.js";
import { beginTransactionScope, endTransactionScope } from "../cache/invalidation.js";

/**
 * Runs `handler` inside a single transaction and hands it the connection.
 *
 * Every multi-table write in this codebase goes through here: a signup that
 * creates a user, an account and a membership must not be able to leave two of
 * the three behind.
 *
 * The handler receives a connection object; pass it as the `executor` argument
 * to query()/execute() so the statements join the transaction.
 */
export async function withTransaction(handler, { isolationLevel } = {}) {
  const connection = await getPool().getConnection();
  try {
    if (isolationLevel) {
      await connection.query(`SET TRANSACTION ISOLATION LEVEL ${isolationLevel}`);
    }
    await connection.beginTransaction();
    // Cache invalidations wait for the commit: published earlier, a reader could re-cache the
    // rows as they were before this transaction landed.
    beginTransactionScope(connection);
    let result;
    let committed = false;
    try {
      try {
        result = await handler(connection);
      } catch (error) {
        await connection.rollback();
        throw error;
      }
      await connection.commit();
      committed = true;
    } finally {
      endTransactionScope(connection, { committed });
    }
    return result;
  } catch (error) {
    if (error?.code?.startsWith?.("ER_")) {
      logger.error({ err: { code: error.code, errno: error.errno } }, "transaction failed");
    }
    throw error;
  } finally {
    connection.release();
  }
}

export default withTransaction;
