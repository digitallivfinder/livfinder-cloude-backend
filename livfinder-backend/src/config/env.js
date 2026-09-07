import { config as loadDotenv } from "dotenv";
import { z } from "zod";

loadDotenv();

const bool = (fallback) =>
  z
    .union([z.boolean(), z.string()])
    .optional()
    .transform((value) => {
      if (value === undefined || value === "") return fallback;
      if (typeof value === "boolean") return value;
      return ["1", "true", "yes", "on"].includes(value.toLowerCase());
    });

const int = (fallback) =>
  z
    .string()
    .optional()
    .transform((value) => (value === undefined || value === "" ? fallback : Number(value)))
    .pipe(z.number().int());

const csv = z
  .string()
  .optional()
  .transform((value) =>
    (value || "")
      .split(",")
      .map((entry) => entry.trim())
      .filter(Boolean)
  );

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: int(4000),

  DB_HOST: z.string().default("127.0.0.1"),
  DB_PORT: int(3306),
  DB_USER: z.string().default("root"),
  DB_PASSWORD: z.string().default(""),
  DB_NAME: z.string().default("livfinder"),
  DB_SOCKET: z.string().optional().transform((value) => value || null),
  DB_CONNECTION_LIMIT: int(15),
  DB_CONNECT_TIMEOUT_MS: int(10000),

  FRONTEND_URL: z.string().default("http://localhost:3000"),
  LIVFINDER_ALLOWED_ORIGINS: csv,
  BODY_LIMIT: z.string().default("1mb"),
  TRUST_PROXY: bool(false),

  SESSION_SECRET: z.string().min(32, "SESSION_SECRET must be at least 32 characters"),
  SESSION_COOKIE_NAME: z.string().default("livfinder_session"),
  SESSION_TTL_DAYS: int(30),
  CSRF_COOKIE_NAME: z.string().default("livfinder_csrf"),
  COOKIE_DOMAIN: z.string().optional().transform((value) => value || undefined),
  COOKIE_SAMESITE: z.enum(["lax", "strict", "none"]).default("lax"),

  STORAGE_DRIVER: z.enum(["local", "s3"]).default("local"),
  LOCAL_STORAGE_PATH: z.string().default("./storage"),
  STORAGE_PUBLIC_BASE_URL: z.string().default("http://localhost:4000/media"),
  // The CDN host the seeded catalogue's image URLs point at. When MEDIA_CDN_BASE_URL is set,
  // those URLs are served as-is; when it is empty the host does not exist in this environment
  // and the API substitutes a generated stand-in so the UI is not full of broken images.
  // Hosts the API is allowed to make outbound requests to (OAuth token and userinfo endpoints,
  // and any future webhook target). Comma-separated; empty means any public address, which is
  // still checked against private ranges. See utils/safeFetch.js.
  OUTBOUND_ALLOWED_HOSTS: z.string().optional().transform((value) => value || ""),
  // Upload scanning. "none" records `skipped` (the default, and honest about it); "clamav"
  // scans via clamd; "reject" additionally refuses an upload the scanner could not check.
  MALWARE_SCAN_DRIVER: z.enum(["none", "clamav", "reject"]).default("none"),
  CLAMAV_HOST: z.string().default("127.0.0.1"),
  CLAMAV_PORT: z.coerce.number().int().default(3310),
  CLAMAV_TIMEOUT_MS: z.coerce.number().int().default(15000),
  MEDIA_LEGACY_CDN_HOST: z.string().default("cdn.livfinder.com"),
  MEDIA_CDN_BASE_URL: z.string().optional().transform((value) => value || null),
  STORAGE_ENDPOINT: z.string().optional().transform((value) => value || null),
  STORAGE_REGION: z.string().optional().transform((value) => value || null),
  STORAGE_BUCKET: z.string().optional().transform((value) => value || null),
  STORAGE_ACCESS_KEY: z.string().optional().transform((value) => value || null),
  STORAGE_SECRET_KEY: z.string().optional().transform((value) => value || null),
  STORAGE_FORCE_PATH_STYLE: bool(false),

  MAIL_DRIVER: z.enum(["log", "smtp"]).default("log"),
  MAIL_FROM: z.string().default("no-reply@livfinder.com"),
  SMTP_HOST: z.string().optional().transform((value) => value || null),
  SMTP_PORT: int(587),
  SMTP_USER: z.string().optional().transform((value) => value || null),
  SMTP_PASSWORD: z.string().optional().transform((value) => value || null),

  PAYMENTS_DRIVER: z.enum(["mock", "stripe"]).default("mock"),
  STRIPE_SECRET_KEY: z.string().optional().transform((value) => value || null),
  STRIPE_WEBHOOK_SECRET: z.string().optional().transform((value) => value || null),
  STRIPE_PUBLISHABLE_KEY: z.string().optional().transform((value) => value || null),

  LOG_LEVEL: z.string().default("info"),
  RATE_LIMIT_WINDOW_MS: int(60000),
  RATE_LIMIT_MAX: int(300),
  // Session resolution has its own budget. Server-side rendering calls
  // `GET /v1/auth/session` once per page, so a visitor moving through the portal
  // spends the general read budget on identity checks alone — which is how a route
  // sweep exhausted it and turned every protected page into a 500.
  SESSION_RATE_LIMIT_MAX: int(1200),
  AUTH_RATE_LIMIT_MAX: int(10),
  PUBLIC_SITE_ORIGIN: z.string().default("https://livfinder.com"),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  const issues = parsed.error.issues
    .map((issue) => `  ${issue.path.join(".")}: ${issue.message}`)
    .join("\n");
  // Fail loudly at boot rather than at the first request that needs the value.
  throw new Error(`Invalid environment configuration:\n${issues}`);
}

export const env = Object.freeze({
  ...parsed.data,
  isProduction: parsed.data.NODE_ENV === "production",
  isTest: parsed.data.NODE_ENV === "test",
  allowedOrigins: parsed.data.LIVFINDER_ALLOWED_ORIGINS.length
    ? parsed.data.LIVFINDER_ALLOWED_ORIGINS
    : [parsed.data.FRONTEND_URL],
});

export default env;
