import env from "./env.js";
import logger from "./logger.js";
import { LocalStorageAdapter } from "../storage/localStorage.js";
import { S3StorageAdapter } from "../storage/s3Storage.js";

let adapter = null;

export function getStorage() {
  if (adapter) return adapter;
  if (env.STORAGE_DRIVER === "s3") {
    if (!env.STORAGE_BUCKET) {
      // Refusing to start is worse than a documented, working fallback: the rest
      // of the application is testable end to end on the local driver.
      logger.warn("STORAGE_DRIVER=s3 but STORAGE_BUCKET is unset — falling back to the local driver");
      adapter = new LocalStorageAdapter();
      return adapter;
    }
    adapter = new S3StorageAdapter();
    logger.info({ bucket: env.STORAGE_BUCKET, region: env.STORAGE_REGION }, "storage: s3 driver");
    return adapter;
  }
  adapter = new LocalStorageAdapter();
  logger.info({ root: env.LOCAL_STORAGE_PATH }, "storage: local driver");
  return adapter;
}

export function resetStorage() {
  adapter = null;
}

export default getStorage;
