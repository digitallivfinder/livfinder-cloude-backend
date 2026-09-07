/** DECIMAL and BIGINT arrive as strings; nothing downstream should do that maths. */
export function num(value) {
  if (value === null || value === undefined) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function int(value) {
  const parsed = num(value);
  return parsed === null ? null : Math.trunc(parsed);
}

export function bool(value) {
  if (value === null || value === undefined) return false;
  return value === 1 || value === true || value === "1";
}

export function isoDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

/** `2026-05-02` — the shape the existing fixtures use for display-only dates. */
export function isoDay(value) {
  const iso = isoDate(value);
  return iso ? iso.slice(0, 10) : null;
}

export function jsonField(value, fallback = null) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

export function money(amount, currency) {
  const parsed = num(amount);
  if (parsed === null) return null;
  return { amount: parsed, currency: currency || "AED" };
}

export function compact(object) {
  return Object.fromEntries(
    Object.entries(object).filter(([, value]) => value !== undefined)
  );
}
