#!/usr/bin/env node
// Read-only public catalogue audit. No database credentials or application imports required.
// node scripts/audit-live-images.mjs https://api.livfinder.com https://livfinder-web.vercel.app
import { pathToFileURL } from "node:url";

export function imageIssue(url, status, contentType) {
  if (new URL(url).pathname.includes("/placeholder/")) return "generated-placeholder";
  if (status < 200 || status >= 300) return `http-${status}`;
  if (!/^image\//i.test(contentType || "")) return "not-an-image";
  if (new URL(url).pathname.includes("/listings/imported/")) return "demo-import-not-verified-listing-photo";
  return null;
}

async function json(url) {
  const response = await fetch(url, { signal: AbortSignal.timeout(20000), redirect: "error" });
  if (!response.ok || !response.headers.get("content-type")?.includes("application/json")) {
    await response.body?.cancel();
    throw new Error(`Expected API JSON from ${url}: HTTP ${response.status}`);
  }
  return response.json();
}

async function probe(url) {
  try {
    const response = await fetch(url, {
      method: "GET", headers: { Range: "bytes=0-511" },
      signal: AbortSignal.timeout(20000), redirect: "error",
    });
    const contentType = response.headers.get("content-type") || "";
    await response.body?.cancel();
    return { url, status: response.status, contentType, issue: imageIssue(url, response.status, contentType) };
  } catch (error) {
    return { url, issue: "request-failed", message: error.message };
  }
}

export async function audit(apiOrigin, siteOrigin) {
  const api = new URL(apiOrigin);
  const site = new URL(siteOrigin);
  for (const origin of [api, site]) {
    if (!/^https?:$/.test(origin.protocol) || origin.username || origin.password ||
        origin.pathname !== "/" || origin.search || origin.hash) throw new Error("Pass API and frontend origins only.");
  }
  const listings = [];
  let complete = false;
  for (let page = 1; page <= 100; page++) {
    const payload = await json(`${api.origin}/v1/public/listings?pageSize=100&page=${page}`);
    if (!Array.isArray(payload.data)) throw new Error("Unexpected listing response.");
    listings.push(...payload.data);
    if (!payload.pageInfo?.hasMore) { complete = true; break; }
  }
  const probes = new Map();
  const check = async (value) => {
    const url = new URL(value, api.origin);
    // Do not follow arbitrary catalogue URLs to third parties or log signed query strings.
    if (url.search || url.hash || url.username || url.password || url.origin !== api.origin) {
      return { url: `${url.origin}${url.pathname}`, issue: "external-or-signed-url-requires-separate-verification" };
    }
    if (!probes.has(url.href)) probes.set(url.href, await probe(url.href));
    return probes.get(url.href);
  };
  const covers = [];
  for (const listing of listings) {
    const value = listing.coverImage?.url;
    let result = { issue: "missing-cover" };
    if (value) {
      const url = new URL(value, api.origin);
      // The path alone proves a generated placeholder. Avoid hundreds of redundant GETs.
      result = url.pathname.includes("/placeholder/")
        ? { url: `${url.origin}${url.pathname}`, issue: "generated-placeholder" }
        : await check(value);
    }
    covers.push({ id: listing.id, reference: listing.reference, ...result });
  }
  const galleries = [];
  for (const listing of listings.slice(0, 3)) {
    const detail = (await json(`${api.origin}/v1/public/listings/${encodeURIComponent(listing.id)}`)).data;
    const cover = detail?.gallery?.find((item) => item.isCover) || detail?.gallery?.[0];
    galleries.push({
      id: listing.id, coverMatchesGallery: detail?.coverImage?.url === cover?.url,
      galleryCover: cover?.url ? await check(cover.url) : { issue: "no-gallery" },
    });
  }
  const proxy = await json(`${site.origin}/v1/public/listings?pageSize=1`);
  const sample = galleries.map((row) => row.galleryCover.url).find((value) => value && new URL(value).pathname.startsWith("/media/"));
  const mediaProxy = sample ? await probe(`${site.origin}${new URL(sample).pathname}`) : null;
  const issueCounts = {};
  for (const cover of covers) if (cover.issue) issueCounts[cover.issue] = (issueCounts[cover.issue] || 0) + 1;
  const result = {
    checkedAt: new Date().toISOString(), api: api.origin, site: site.origin,
    complete, listingCount: listings.length, issueCounts,
    apiProxyMatches: proxy.data?.[0]?.id === listings[0]?.id,
    mediaProxy, galleries, covers,
  };
  result.ok = complete && listings.length > 0 && !Object.keys(issueCounts).length &&
    result.apiProxyMatches && galleries.every((row) => row.coverMatchesGallery && !row.galleryCover.issue) &&
    Boolean(mediaProxy && !mediaProxy.issue);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  if (!process.argv[2] || !process.argv[3]) {
    console.error("Usage: node scripts/audit-live-images.mjs <api-origin> <frontend-origin>");
    process.exitCode = 2;
  } else {
    try {
      const result = await audit(process.argv[2], process.argv[3]);
      console.log(JSON.stringify(result, null, 2));
      process.exitCode = result.ok ? 0 : 1;
    } catch (error) {
      console.error(error.message);
      process.exitCode = 2;
    }
  }
}
