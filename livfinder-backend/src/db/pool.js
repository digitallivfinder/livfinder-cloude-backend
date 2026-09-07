import mysql from "mysql2/promise";
import env from "../config/env.js";
import logger from "../config/logger.js";

let pool = null;

function connectionOptions() {
  const base = {
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    waitForConnections: true,
    connectionLimit: env.DB_CONNECTION_LIMIT,
    maxIdle: env.DB_CONNECTION_LIMIT,
    idleTimeout: 60_000,
    queueLimit: 0,
    connectTimeout: env.DB_CONNECT_TIMEOUT_MS,
    charset: "utf8mb4_unicode_ci",
    timezone: "Z",
    // DECIMAL and BIGINT come back as strings by default, which silently breaks
    // arithmetic downstream. Numbers are converted explicitly in the serializers
    // instead, so keep the driver honest and return strings we control.
    decimalNumbers: false,
    supportBigNumbers: true,
    bigNumberStrings: false,
    dateStrings: false,
    multipleStatements: false,
    namedPlaceholders: false,
  };
  if (env.DB_SOCKET) return { ...base, socketPath: env.DB_SOCKET };
  return { ...base, host: env.DB_HOST, port: env.DB_PORT };
}

export function getPool() {
  if (pool) return pool;
  pool = mysql.createPool(connectionOptions());
  pool.on("connection", (connection) => {
    // Strict mode on every pooled connection: a truncated price or a silently
    // coerced enum is a data bug, not a warning.
    connection.query(
      "SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION', SESSION time_zone = '+00:00'"
    );
  });
  return pool;
}

export async function closePool() {
  if (!pool) return;
  const current = pool;
  pool = null;
  await current.end();
  logger.info("database pool closed");
}

export async function pingDatabase() {
  const connection = await getPool().getConnection();
  try {
    await connection.ping();
    const [rows] = await connection.query("SELECT VERSION() AS version, DATABASE() AS db");
    return { ok: true, version: rows[0].version, database: rows[0].db };
  } finally {
    connection.release();
  }
}

export default getPool;
