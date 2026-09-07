import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("../../src/db/query.js", () => ({ query: vi.fn(), queryOne: vi.fn(), queryValue: vi.fn(), execute: vi.fn() }));
vi.mock("../../src/modules/media/media.service.js", () => ({
  listRenditions: vi.fn(async () => []), thumbnailFrom: vi.fn((_, url) => url), softDeleteAsset: vi.fn(),
}));
vi.mock("../../src/modules/listings/listings.repository.js", () => ({ refreshListingSearch: vi.fn() }));
vi.mock("../../src/config/env.js", () => ({ default: { MEDIA_LEGACY_CDN_HOST: "cdn.livfinder.com", LOG_LEVEL: "silent" } }));

import { queryOne, queryValue, execute } from "../../src/db/query.js";
import { attachAssetToListing } from "../../src/modules/media/listingMedia.service.js";

beforeEach(() => vi.resetAllMocks());

async function attach({ cover = "https://cdn.livfinder.com/listings/seed/01.jpg", isCover = null, count = 3, promoteOverLegacy = true } = {}) {
  queryOne.mockResolvedValueOnce({ id: 99, public_id: "asset99", url: "https://api.livfinder.com/media/listings/actual.jpg" });
  queryOne.mockResolvedValueOnce(cover ? { url: cover } : null);
  queryValue.mockResolvedValueOnce(3).mockResolvedValueOnce(count);
  execute.mockResolvedValue({ insertId: 123 });
  await attachAssetToListing({ listingId: 143, assetId: 99, isCover, promoteOverLegacy });
  const insert = execute.mock.calls.find(([sql]) => sql.includes("INSERT INTO listing_media"));
  return insert[1][9]; // The actual is_cover value written for the newly attached image.
}

describe("uploading actual photos to a seeded listing", () => {
  it("replaces a seeded cover with the owner's uploaded photo", async () => {
    expect(await attach()).toBe(1);
    expect(execute.mock.calls.some(([sql]) => sql.includes("SET is_cover = 0"))).toBe(true);
  });
  it("preserves an existing actual cover", async () => {
    expect(await attach({ cover: "https://api.livfinder.com/media/listings/original.jpg" })).toBe(0);
  });
  it("honours an explicit request not to change the cover", async () => {
    expect(await attach({ isCover: false })).toBe(0);
  });
  it("does not promote a previously stored or library asset automatically", async () => {
    expect(await attach({ promoteOverLegacy: false })).toBe(0);
  });
  it("uses the actual upload when there are only non-image gallery rows", async () => {
    expect(await attach({ cover: null })).toBe(1);
  });
  it("does not mistake a lookalike CDN host for seed data", async () => {
    expect(await attach({ cover: "https://cdn.livfinder.com.example.org/listings/a.jpg" })).toBe(0);
  });
});
