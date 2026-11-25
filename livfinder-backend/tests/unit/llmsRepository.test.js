import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.fn();
vi.mock("../../src/db/query.js", () => ({ query }));

const { llmsEntries } = await import("../../src/modules/public/llms.repository.js");

beforeEach(() => query.mockReset());

describe("llms facts", () => {
  it("withholds a hidden price and reads the facts a card shows", async () => {
    query.mockResolvedValue([
      { title: "Villa", canonical_path: "/real-estate/x", purpose_slug: "for-rent", price: 650000, currency_code: "AED", price_period: "year", is_price_hidden: 0, location_label: "Palm", organization_name: "Acme", spec_labels: '{"beds":4}', root_category_id: 1, source_updated_at: "2026-11-24T10:00:00Z" },
      { title: "Flat", canonical_path: "/real-estate/y", purpose_slug: "for-sale", price: 900000, currency_code: "AED", is_price_hidden: 1, spec_labels: null, root_category_id: 1 },
    ]);
    const [villa, flat] = await llmsEntries("listings", { category: "real-estate" });
    expect(villa).toMatchObject({ purpose: "rent", price: { amount: 650000, currency: "AED", period: "year" }, specs: { beds: 4 }, seller: "Acme", updated: "2026-11-24" });
    expect(flat.price).toBeNull();
    // Live listings only, from the search projection, one category at a time, a page at most.
    expect(query.mock.calls[0][0]).toContain("FROM listing_search ls");
    expect(query.mock.calls[0][0]).toContain("LIMIT 5000 OFFSET 0");
    expect(query.mock.calls[0][1]).toEqual([1]);
  });

  it("turns any post body into plain text", async () => {
    query.mockResolvedValue([
      { slug: "a", title: "A", body: "<p>Prices <strong>rose</strong>.</p>", body_format: "html", published_at: "2026-11-01" },
      { slug: "b", title: "B", body: JSON.stringify([{ type: "heading", text: "Outlook" }, { type: "paragraph", text: "Calm." }]), body_format: "blocks", published_at: "2026-11-02" },
    ]);
    const [html, blocks] = await llmsEntries("posts");
    expect(html.text).toBe("Prices rose.");
    expect(blocks.text).toContain("Outlook");
    expect(blocks.text).toContain("Calm.");
    expect(html.url).toBe("/blogs/a");
  });

  it("knows nothing about an unknown kind or category", async () => {
    expect(await llmsEntries("listings", { category: "boats" })).toEqual([]);
    expect(await llmsEntries("secrets")).toEqual([]);
    expect(query).not.toHaveBeenCalled();
  });
});
