#!/usr/bin/env node
/**
 * Deployment readiness check.
 *
 * Verifies the things that must be true before the API is useful: the database
 * answers, the schema and seed are loaded, the search projection is populated,
 * the storage driver can write and read back, and the configuration is coherent.
 *
 *   npm run health-check
 */
import crypto from "node:crypto";
import env from "../src/config/env.js";
import { pingDatabase, closePool } from "../src/db/pool.js";
import { query, queryOne, queryValue } from "../src/db/query.js";
import { getStorage } from "../src/config/storage.js";

const results = [];
const record = (name, ok, detail) => results.push({ name, ok, detail });

async function checkDatabase() {
  try {
    const info = await pingDatabase();
    record("database reachable", true, `MySQL ${info.version} / ${info.database}`);
  } catch (error) {
    record("database reachable", false, error.message);
    return false;
  }

  const tables = await queryValue(
    "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_TYPE = 'BASE TABLE'"
  );
  record("schema loaded", Number(tables) > 400, `${tables} tables`);

  const views = await queryValue(
    "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = DATABASE()"
  );
  record("visibility views present", Number(views) >= 7, `${views} views`);

  const routines = await queryValue(
    "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = DATABASE()"
  );
  record("stored routines present", Number(routines) >= 4, `${routines} routines`);

  const listings = await queryValue("SELECT COUNT(*) FROM listings WHERE deleted_at IS NULL");
  record("seed data loaded", Number(listings) > 0, `${listings} listings`);

  const projection = await queryValue("SELECT COUNT(*) FROM listing_search");
  const publicListings = await queryValue("SELECT COUNT(*) FROM v_public_listings");
  record(
    "search projection matches the visibility view",
    Number(projection) === Number(publicListings),
    `${projection} projected / ${publicListings} public`
  );

  const locations = await queryValue("SELECT COUNT(*) FROM locations WHERE deleted_at IS NULL");
  record("location tree loaded", Number(locations) > 100_000, `${locations} locations`);

  const argon = await queryValue("SELECT COUNT(*) FROM users WHERE password_hash LIKE '$argon2%'");
  const users = await queryValue("SELECT COUNT(*) FROM users WHERE deleted_at IS NULL");
  record(
    "user passwords are Argon2id",
    Number(argon) === Number(users),
    `${argon} of ${users}`
  );

  const canonical = await queryValue(
    `SELECT COUNT(*) FROM listings
      WHERE deleted_at IS NULL AND canonical_path NOT REGEXP '^/(real-estate|cars|yachts|jets|helicopters|watches)/'`
  );
  record("canonical paths follow the route contract", Number(canonical) === 0, `${canonical} off-contract`);

  const orphanDetail = await queryValue(
    `SELECT COUNT(*) FROM listings l
      WHERE l.deleted_at IS NULL AND l.root_category_id = 1
        AND NOT EXISTS (SELECT 1 FROM listing_real_estate d WHERE d.listing_id = l.id)`
  );
  record("every real-estate listing has its detail row", Number(orphanDetail) === 0, `${orphanDetail} orphans`);

  return true;
}

async function checkStorage() {
  const storage = getStorage();
  const key = `health/${Date.now()}-${crypto.randomBytes(6).toString("hex")}.txt`;
  const payload = Buffer.from("livfinder health check");
  try {
    await storage.put(key, payload, { contentType: "text/plain", visibility: "public" });
    const read = await storage.get(key, { visibility: "public" });
    const matches = read.equals(payload);
    await storage.delete(key, { visibility: "public" });
    record("storage read/write", matches, `${storage.driver} driver`);
  } catch (error) {
    record("storage read/write", false, `${storage.driver}: ${error.message}`);
  }

  const media = await queryValue("SELECT COUNT(*) FROM media_assets WHERE deleted_at IS NULL");
  record("media assets present", Number(media) > 0, `${media} assets`);
}

function checkConfiguration() {
  record(
    "session secret is not the placeholder",
    !env.SESSION_SECRET.startsWith("change-me"),
    env.isProduction ? "required in production" : "development value"
  );
  record("cors allow-list configured", env.allowedOrigins.length > 0, env.allowedOrigins.join(", "));
  record(
    "cookies secure in production",
    !env.isProduction || env.COOKIE_SAMESITE !== "none" || Boolean(env.COOKIE_DOMAIN),
    `SameSite=${env.COOKIE_SAMESITE}`
  );

  const external = [];
  if (env.STORAGE_DRIVER === "local") external.push("object storage (STORAGE_DRIVER=local)");
  if (env.MAIL_DRIVER === "log") external.push("email delivery (MAIL_DRIVER=log)");
  if (env.PAYMENTS_DRIVER === "mock") external.push("payments (PAYMENTS_DRIVER=mock)");
  record("external services", true, external.length ? `local drivers: ${external.join(", ")}` : "all configured");
}

async function main() {
  const reachable = await checkDatabase();
  if (reachable) await checkStorage();
  checkConfiguration();

  const width = Math.max(...results.map((result) => result.name.length));
  console.log("\nLivFinder API health check\n");
  for (const result of results) {
    console.log(`  ${result.ok ? "ok  " : "FAIL"}  ${result.name.padEnd(width)}  ${result.detail}`);
  }
  const failures = results.filter((result) => !result.ok);
  console.log(`\n${results.length - failures.length} of ${results.length} checks passed\n`);
  await closePool();
  process.exit(failures.length ? 1 : 0);
}

main().catch(async (error) => {
  console.error("health check crashed:", error.message);
  await closePool();
  process.exit(1);
});
