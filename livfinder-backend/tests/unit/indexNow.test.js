import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.fn();
const env = { INDEXNOW_KEY: "abcdef0123456789", INDEXNOW_SITE_URL: "https://livfinder.com", FRONTEND_URL: "http://localhost:3000" };
let stored = null;

vi.mock("../../src/db/query.js", () => ({ query }));
vi.mock("../../src/config/env.js", () => ({ default: env, env }));
vi.mock("../../src/config/logger.js", () => ({ default: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() } }));
vi.mock("../../src/cache/redis.js", () => ({
  cacheKey: (...parts) => parts.join(":"),
  withRedis: async (run) => run({ get: async () => stored, set: async (_key, value) => { stored = value; } }),
}));

const { indexNowSite, runIndexNow } = await import("../../src/modules/seo/indexnow.jobs.js");

beforeEach(() => {
  query.mockReset();
  stored = null;
  env.INDEXNOW_KEY = "abcdef0123456789";
  env.INDEXNOW_SITE_URL = "https://livfinder.com";
});

describe("IndexNow", () => {
  it("stays off without a key or on a non-public site", () => {
    expect(indexNowSite()).toEqual({ key: "abcdef0123456789", origin: "https://livfinder.com", host: "livfinder.com" });
    env.INDEXNOW_SITE_URL = "http://localhost:3000";
    expect(indexNowSite()).toBeNull();
    env.INDEXNOW_SITE_URL = "https://livfinder.com";
    env.INDEXNOW_KEY = "";
    expect(indexNowSite()).toBeNull();
    env.INDEXNOW_KEY = "bad key!";
    expect(indexNowSite()).toBeNull();
  });

  it("starts the clock on its first run without sending the whole catalogue", async () => {
    const fetchImpl = vi.fn();
    expect(await runIndexNow({ now: new Date("2026-11-25T10:00:00Z"), fetchImpl })).toBe(0);
    expect(fetchImpl).not.toHaveBeenCalled();
    expect(stored).toBe("2026-11-25 10:00:00.000");
  });

  it("sends changed listings, developments and posts once, as absolute URLs", async () => {
    stored = "2026-11-25 10:00:00.000";
    query
      .mockResolvedValueOnce([{ path: "/cars/ferrari/sf90/2024/x" }, { path: "/cars/ferrari/sf90/2024/x" }])
      .mockResolvedValueOnce([{ path: "/projects/uae/dubai/tower" }])
      .mockResolvedValueOnce([{ path: "/blogs/story" }]);
    const fetchImpl = vi.fn().mockResolvedValue({ status: 202 });
    expect(await runIndexNow({ now: new Date("2026-11-25T10:10:00Z"), fetchImpl })).toBe(3);
    const body = JSON.parse(fetchImpl.mock.calls[0][1].body);
    expect(body).toEqual({
      host: "livfinder.com",
      key: "abcdef0123456789",
      keyLocation: "https://livfinder.com/indexnow-key.txt",
      urlList: ["https://livfinder.com/cars/ferrari/sf90/2024/x", "https://livfinder.com/projects/uae/dubai/tower", "https://livfinder.com/blogs/story"],
    });
    expect(query.mock.calls.every(([, params]) => params[0] === "2026-11-25 10:00:00.000")).toBe(true);
    expect(stored).toBe("2026-11-25 10:10:00.000");
  });

  it("keeps the watermark when the submission is refused, so the URLs go next time", async () => {
    stored = "2026-11-25 10:00:00.000";
    query.mockResolvedValueOnce([{ path: "/cars/x" }]).mockResolvedValueOnce([]).mockResolvedValueOnce([]);
    expect(await runIndexNow({ now: new Date("2026-11-25T10:10:00Z"), fetchImpl: vi.fn().mockResolvedValue({ status: 429 }) })).toBe(0);
    expect(stored).toBe("2026-11-25 10:00:00.000");
  });
});
