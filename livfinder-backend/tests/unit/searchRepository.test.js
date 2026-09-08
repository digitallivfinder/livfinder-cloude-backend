import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.fn();
const queryValue = vi.fn();

vi.mock("../../src/db/query.js", () => ({ query, queryValue }));

const { buildSearchQuery } = await import("../../src/modules/search/search.repository.js");

beforeEach(() => {
  query.mockReset();
  queryValue.mockReset();
});

describe("standalone model filters", () => {
  it("resolves a unique model inside the requested marketplace", async () => {
    query.mockResolvedValue([{ id: 72, brand_id: 19 }]);
    const built = await buildSearchQuery({ category: "cars", model: "xm" });

    expect(built.impossible).toBe(false);
    expect(built.where).toContain("ls.brand_id = ?");
    expect(built.where).toContain("ls.brand_model_id = ?");
    expect(built.params).toEqual([2, 19, 72]);
  });

  it("returns an impossible search for an unknown or ambiguous standalone model", async () => {
    query.mockResolvedValue([]);
    await expect(buildSearchQuery({ category: "cars", model: "not-a-model" }))
      .resolves.toMatchObject({ impossible: true });

    query.mockResolvedValue([{ id: 1, brand_id: 10 }, { id: 2, brand_id: 11 }]);
    await expect(buildSearchQuery({ category: "cars", model: "shared-name" }))
      .resolves.toMatchObject({ impossible: true });
  });
});
