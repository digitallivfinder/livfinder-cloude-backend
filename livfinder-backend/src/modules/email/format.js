import env from "../../config/env.js";

/**
 * Formatting for email copy. Every value that reaches an email passes through here so a price,
 * an area or a time reads the same way in every template, in the reader's own preferences.
 */

export const escapeHtml = (value) =>
  String(value ?? "").replace(/[&<>"']/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]);

export const siteUrl = (pathname = "/") => {
  const base = String(env.FRONTEND_URL || "").replace(/\/+$/, "");
  if (/^https?:\/\//i.test(pathname)) return pathname;
  return `${base}${pathname.startsWith("/") ? "" : "/"}${pathname}`;
};

export const assetUrl = (pathname) => `${String(env.EMAIL_ASSET_BASE_URL || env.FRONTEND_URL || "").replace(/\/+$/, "")}${pathname}`;

/** A public media URL as an absolute one (seeded rows store paths). */
export function imageUrl(url) {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  if (url.startsWith("/media")) return `${String(env.STORAGE_PUBLIC_BASE_URL).replace(/\/media\/?$/, "")}${url}`;
  return siteUrl(url);
}

export function firstName(person) {
  const name = person?.firstName || person?.first_name || String(person?.name || person?.display_name || "").split(" ")[0];
  return name && name.length < 40 ? name : "there";
}

/** 1234567 → "1,234,567"; AED 42,000,000 → "AED 42,000,000". */
export function money(amount, currency = "AED", { compact = false } = {}) {
  if (amount === null || amount === undefined || amount === "" || Number.isNaN(Number(amount))) return null;
  const value = Number(amount);
  const formatted = compact && value >= 1_000_000
    ? `${(value / 1_000_000).toLocaleString("en-US", { maximumFractionDigits: 2 })}M`
    : value.toLocaleString("en-US", { maximumFractionDigits: value % 1 ? 2 : 0 });
  return `${currency || ""} ${formatted}`.trim();
}

/**
 * The price in the listing's own currency, and in the reader's when it differs ("about USD 11.4M").
 * `rates` maps a currency code to how many of it one base unit (AED) buys — fx_rates_latest.
 */
export function priceLine({ price, currency, priceBase }, reader = {}, rates = {}) {
  const own = money(price, currency);
  if (!own) return "Price on request";
  const wanted = reader.currency;
  if (!wanted || wanted === currency || !priceBase || !rates[wanted]) return own;
  const converted = Number(priceBase) * Number(rates[wanted]);
  return `${own} · about ${money(Math.round(converted), wanted, { compact: true })}`;
}

const SQM_PER_SQFT = 0.09290304;

/** Areas are stored in sqft; shown in the reader's unit. */
export function area(sqft, unit = "sqft") {
  if (!sqft) return null;
  const value = unit === "sqm" ? Number(sqft) * SQM_PER_SQFT : Number(sqft);
  return `${Math.round(value).toLocaleString("en-US")} ${unit === "sqm" ? "sqm" : "sqft"}`;
}

function safeZone(timezone) {
  const zone = timezone || env.EMAIL_DEFAULT_TIMEZONE;
  try {
    new Intl.DateTimeFormat("en-GB", { timeZone: zone });
    return zone;
  } catch {
    return env.EMAIL_DEFAULT_TIMEZONE;
  }
}

/** "Tuesday 18 November 2026, 14:30 (Dubai)" in the reader's timezone. */
export function dateTime(value, timezone) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const zone = safeZone(timezone);
  const text = new Intl.DateTimeFormat("en-GB", {
    weekday: "long", day: "numeric", month: "long", year: "numeric", hour: "2-digit", minute: "2-digit", timeZone: zone,
  }).format(date);
  const city = zone.split("/").pop().replace(/_/g, " ");
  return `${text} (${city})`;
}

export function dateOnly(value, timezone) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "long", year: "numeric", timeZone: safeZone(timezone) }).format(date);
}

/** The local hour (0–23) and date key ("2026-11-17") of a moment in a timezone. */
export function localClock(timezone, now = new Date()) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat("en-CA", { timeZone: safeZone(timezone), year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23", weekday: "short" })
      .formatToParts(now)
      .map((part) => [part.type, part.value])
  );
  return { hour: Number(parts.hour), day: `${parts.year}-${parts.month}-${parts.day}`, weekday: parts.weekday };
}

export const plural = (count, one, many = `${one}s`) => `${Number(count).toLocaleString("en-US")} ${Number(count) === 1 ? one : many}`;

export const truncate = (value, length = 240) => {
  const text = String(value ?? "").replace(/\s+/g, " ").trim();
  return text.length > length ? `${text.slice(0, length - 1)}…` : text;
};
