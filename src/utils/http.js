import { z } from "zod";

export const MAX_PAGE_SIZE = 100;

/** `{ data, pageInfo }` — the list contract the frontend already expects. */
export function listResponse(data, { page, pageSize, total, ...rest } = {}) {
  const safePage = Math.max(1, Number(page) || 1);
  const safeSize = Math.max(1, Number(pageSize) || 20);
  const safeTotal = Math.max(0, Number(total) || 0);
  return {
    data,
    pageInfo: {
      page: safePage,
      pageSize: safeSize,
      total: safeTotal,
      totalPages: Math.max(1, Math.ceil(safeTotal / safeSize)),
      hasMore: safePage * safeSize < safeTotal,
      ...rest,
    },
  };
}

export function detailResponse(data, meta) {
  return meta ? { data, meta } : { data };
}

/** Cursor form used by the public marketplace grid. */
export function cursorResponse(data, { cursor = 0, pageSize, total, sort }) {
  const start = Number(cursor) || 0;
  const nextCursor = start + data.length;
  return {
    data,
    pageInfo: {
      nextCursor: nextCursor < total ? String(nextCursor) : null,
      hasMore: nextCursor < total,
      pageSize,
      sort,
      estimatedTotal: total,
      total,
      page: Math.floor(start / pageSize) + 1,
      totalPages: Math.max(1, Math.ceil(total / pageSize)),
    },
  };
}

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).max(10_000).default(1),
  pageSize: z.coerce.number().int().min(1).max(MAX_PAGE_SIZE).default(20),
});

export function paginationFrom(input = {}, defaultPageSize = 20) {
  const page = Math.max(1, Math.min(10_000, Number(input.page) || 1));
  const pageSize = Math.max(1, Math.min(MAX_PAGE_SIZE, Number(input.pageSize) || defaultPageSize));
  return { page, pageSize, offset: (page - 1) * pageSize };
}

/**
 * An allow-list for ORDER BY. Sort keys never reach SQL as text; they select a
 * pre-written fragment.
 */
export function resolveSort(sortKey, map, fallbackKey) {
  return map[sortKey] || map[fallbackKey] || Object.values(map)[0];
}

/** Trims a string query param to null when blank. */
export function cleanString(value, maxLength = 200) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  if (!trimmed) return null;
  return trimmed.slice(0, maxLength);
}

export function toNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

export function toInt(value) {
  const parsed = toNumber(value);
  return parsed === null ? null : Math.trunc(parsed);
}

export function toBool(value) {
  if (value === true || value === 1) return true;
  if (typeof value === "string") return ["1", "true", "yes", "on"].includes(value.toLowerCase());
  return false;
}

export function asArray(value) {
  if (value === undefined || value === null || value === "") return [];
  const list = Array.isArray(value) ? value : [value];
  return list
    .flatMap((entry) => (typeof entry === "string" ? entry.split(",") : [entry]))
    .map((entry) => (typeof entry === "string" ? entry.trim() : entry))
    .filter((entry) => entry !== "" && entry !== null && entry !== undefined);
}
