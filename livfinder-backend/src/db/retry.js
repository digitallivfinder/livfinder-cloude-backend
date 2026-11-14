import logger from "../config/logger.js";

/**
 * MySQL errors that mean "this transaction lost a race, run it again", not "this write is wrong".
 * A deadlock rolls the losing transaction back whole, so running it again is safe.
 */
const TRANSIENT_CODES = new Set(["ER_LOCK_DEADLOCK", "ER_LOCK_WAIT_TIMEOUT"]);

/** True when `error`, or an error it wraps (query.js wraps driver errors as `cause`), is a deadlock or lock wait timeout. */
export function isTransientDbError(error) {
  for (let current = error, depth = 0; current && depth < 5; current = current.cause, depth++) {
    if (TRANSIENT_CODES.has(current.code)) return true;
  }
  return false;
}

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Runs `work` and runs it again, after a short and growing pause, when it fails on a deadlock or
 * lock wait timeout. Any other error, or the last attempt's, is thrown as it is. `work` must be a
 * whole transaction (or several), so a retry starts from a clean rollback.
 *
 * A bulk import writes listings while the photo downloader writes the same listings' media; the
 * two occasionally deadlock. 16 of 16,529 listings in one push failed that way before this.
 */
export async function retryTransient(work, { attempts = 4, delayMs = 150, sleep = wait, label = "transaction" } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      return await work();
    } catch (error) {
      if (attempt >= attempts || !isTransientDbError(error)) throw error;
      logger.warn({ attempt, label }, "database deadlock; running the transaction again");
      await sleep(delayMs * attempt + Math.floor(Math.random() * delayMs));
    }
  }
}
