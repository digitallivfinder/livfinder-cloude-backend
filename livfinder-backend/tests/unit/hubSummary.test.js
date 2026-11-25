import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.fn();
const queryValue = vi.fn();
vi.mock("../../src/db/query.js", () => ({ query, queryValue }));

const { hubSummary } = await import("../../src/modules/public/hubSummary.repository.js");

beforeEach(() => {
  query.mockReset();
  queryValue.mockReset().mockResolvedValue("AED");
});

describe("browse page summary", () => {
  it("counts sale and rent, ranges visible sale prices, and ranks the child pages", async () => {
    query
      .mockResolvedValueOnce([
        { purpose_slug: "for-sale", total: 4, min_base: "1300000.00", max_base: "3200000.00" },
        { purpose_slug: "for-rent", total: 1, min_base: "650000.00", max_base: "650000.00" },
      ])
      .mockResolvedValueOnce([{ name: "Apartment", total: 3 }])
      .mockResolvedValueOnce([
        { canonical_path: "/real-estate/uae/dubai/dubai/marina/a" },
        { canonical_path: "/real-estate/uae/dubai/dubai/marina/b" },
        { canonical_path: "/real-estate/uae/dubai/dubai/palm/c" },
        // A listing directly under the page is not a child page.
        { canonical_path: "/real-estate/uae/dubai/dubai/d" },
      ])
      .mockResolvedValueOnce([{ total: 2 }]);
    const summary = await hubSummary("real-estate", "/real-estate/uae/dubai/dubai/");
    expect(summary).toEqual({
      path: "/real-estate/uae/dubai/dubai",
      total: 5,
      sale: { count: 4, minPrice: 1300000, maxPrice: 3200000 },
      rentCount: 1,
      currency: "AED",
      companies: 2,
      types: [{ name: "Apartment", count: 3 }],
      children: [{ url: "/real-estate/uae/dubai/dubai/marina", count: 2 }, { url: "/real-estate/uae/dubai/dubai/palm", count: 1 }],
    });
    // Hidden prices stay out of the range; the path is matched as a prefix, wildcards escaped.
    expect(query.mock.calls[0][0]).toContain("CASE WHEN l.is_price_hidden = 0");
    expect(query.mock.calls[0][1]).toEqual([1, "/real-estate/uae/dubai/dubai/%"]);
  });

  it("refuses anything that is not a marketplace browse page", async () => {
    expect(await hubSummary("boats", "/boats")).toBeNull();
    expect(await hubSummary("cars", "/yachts/x")).toBeNull();
    expect(query).not.toHaveBeenCalled();
  });

  it("escapes LIKE wildcards in the path", async () => {
    query.mockResolvedValue([]);
    await hubSummary("cars", "/cars/a_b%c");
    expect(query.mock.calls[0][1]).toEqual([2, "/cars/a\\_b\\%c/%"]);
  });
});
