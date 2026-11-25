import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { query } from "../../db/query.js";
import { cacheKey, withRedis } from "../../cache/redis.js";

/**
 * IndexNow (https://www.indexnow.org): tells Bing, Yandex, Seznam, Naver and the other engines
 * that share it which URLs changed, so a new listing, a price change or a sold / withdrawn
 * listing is recrawled within minutes rather than whenever the sitemap is next read. Google does
 * not take part; it reads the sitemap.
 *
 * Every ten minutes the URLs of listings, developments and magazine posts changed since the last
 * run are sent in one request. A page that has just closed or been taken down is sent too — that
 * is how an engine learns to drop it.
 *
 * Off unless INDEXNOW_KEY is set and the site URL is a public https host, so development, test
 * and staging servers never announce anything. The same key is served by the website at
 * `/indexnow-key.txt` (frontend env INDEXNOW_KEY), which proves the site owns it.
 */
const ENDPOINT = "https://api.indexnow.org/indexnow";
const MAX_URLS = 10000;
const WATERMARK_KEY = () => cacheKey("indexnow", "watermark");
let memoryWatermark = null;

export function indexNowSite() {
  const key = String(env.INDEXNOW_KEY || "").trim();
  if (!/^[A-Za-z0-9-]{8,128}$/.test(key)) return null;
  let url;
  try {
    url = new URL(env.INDEXNOW_SITE_URL || env.FRONTEND_URL);
  } catch {
    return null;
  }
  if (url.protocol !== "https:" || ["localhost", "127.0.0.1", "[::1]"].includes(url.hostname) || url.hostname.endsWith(".localhost")) return null;
  return { key, origin: url.origin, host: url.host };
}

async function readWatermark() {
  const stored = await withRedis((redis) => redis.get(WATERMARK_KEY()));
  return stored || memoryWatermark;
}

async function writeWatermark(value) {
  memoryWatermark = value;
  await withRedis((redis) => redis.set(WATERMARK_KEY(), value));
}

const sqlTime = (date) => date.toISOString().slice(0, 23).replace("T", " ");

/** Paths of everything public-facing that changed after `since` (newest first, capped). */
export async function changedPaths(since) {
  const [listings, projects, posts] = await Promise.all([
    // Ever published: a draft that never went live has no page to announce.
    query(
      `SELECT canonical_path AS path FROM listings
        WHERE updated_at > ? AND published_at IS NOT NULL AND canonical_path IS NOT NULL
        ORDER BY updated_at DESC LIMIT ${MAX_URLS}`,
      [since]
    ),
    query(
      `SELECT canonical_path AS path FROM projects
        WHERE updated_at > ? AND canonical_path IS NOT NULL
        ORDER BY updated_at DESC LIMIT ${MAX_URLS}`,
      [since]
    ),
    query(
      `SELECT CONCAT('/blogs/', slug) AS path FROM posts
        WHERE updated_at > ? AND published_at IS NOT NULL
        ORDER BY updated_at DESC LIMIT ${MAX_URLS}`,
      [since]
    ),
  ]);
  return [...new Set([...listings, ...projects, ...posts].map((row) => row.path).filter(Boolean))].slice(0, MAX_URLS);
}

/** One run: send what changed since the last one. Returns how many URLs were sent. */
export async function runIndexNow({ now = new Date(), fetchImpl = fetch } = {}) {
  const site = indexNowSite();
  if (!site) return 0;
  const since = await readWatermark();
  // The first run starts the clock; the existing catalogue is in the sitemap already.
  if (!since) {
    await writeWatermark(sqlTime(now));
    return 0;
  }
  const paths = await changedPaths(since);
  if (!paths.length) {
    await writeWatermark(sqlTime(now));
    return 0;
  }
  const response = await fetchImpl(ENDPOINT, {
    method: "POST",
    headers: { "content-type": "application/json; charset=utf-8" },
    body: JSON.stringify({
      host: site.host,
      key: site.key,
      keyLocation: `${site.origin}/indexnow-key.txt`,
      urlList: paths.map((path) => `${site.origin}${path}`),
    }),
    signal: AbortSignal.timeout(10000),
  });
  // 200 and 202 are both success; anything else keeps the watermark so the URLs go next time.
  if (response.status !== 200 && response.status !== 202) {
    logger.warn({ status: response.status, urls: paths.length }, "indexnow rejected the submission");
    return 0;
  }
  await writeWatermark(sqlTime(now));
  return paths.length;
}

export function startIndexNow({ intervalMs = 10 * 60 * 1000 } = {}) {
  if (!indexNowSite()) {
    logger.info("indexnow off (no INDEXNOW_KEY, or the site URL is not a public https host)");
    return null;
  }
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const sent = await runIndexNow();
      if (sent) logger.info({ urls: sent }, "indexnow submitted");
    } catch (error) {
      logger.error({ err: error }, "indexnow failed");
    } finally {
      running = false;
    }
  };
  tick();
  const timer = setInterval(tick, intervalMs);
  timer.unref();
  return timer;
}
