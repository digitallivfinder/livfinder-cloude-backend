import { describe, expect, it } from "vitest";
import { tablesWritten, tagsForStatement, tagsForTable, tagsForProcedure, ALL_TAGS } from "../../src/cache/cacheTags.js";
import { requestCacheKey, tagsForPath } from "../../src/middleware/publicCache.js";

describe("cache tags read off SQL", () => {
  it("finds the table of each write form", () => {
    expect(tablesWritten("INSERT INTO listings (a) VALUES (?)")).toEqual(["listings"]);
    expect(tablesWritten("insert ignore into `listing_media` (a) values (?)")).toEqual(["listing_media"]);
    expect(tablesWritten("REPLACE INTO livfinder.settings (k) VALUES (?)")).toEqual(["settings"]);
    expect(tablesWritten("UPDATE listings l JOIN accounts a ON a.id = l.account_id SET a.status = ?")).toEqual(["listings", "accounts"]);
    expect(tablesWritten("DELETE rp FROM role_permissions rp JOIN roles r ON r.id = rp.role_id WHERE r.code = ?")).toEqual(["role_permissions", "roles"]);
    expect(tablesWritten("/* note */ DELETE FROM posts WHERE id = ?")).toEqual(["posts"]);
  });

  it("treats reads as reads", () => {
    expect(tablesWritten("SELECT * FROM listings")).toEqual([]);
    expect(tablesWritten("  select 1")).toEqual([]);
  });

  it("maps public tables to tags and ignores per-visit tables", () => {
    expect(tagsForStatement("UPDATE listings SET title = ? WHERE id = ?")).toEqual(["listings"]);
    expect(tagsForStatement("INSERT INTO reviews (a) VALUES (?)")).toEqual(["organizations"]);
    expect(tagsForTable("listing_daily_stats")).toEqual([]);
    expect(tagsForTable("user_sessions")).toEqual([]);
    expect(tagsForTable("messages")).toEqual([]);
    expect(tagsForTable("posts")).toEqual(["editorial"]);
  });

  it("maps procedures, and treats an unknown one as touching everything", () => {
    expect(tagsForProcedure("sp_refresh_listing_search")).toEqual(["listings"]);
    expect(tagsForProcedure("sp_something_new")).toEqual(ALL_TAGS.filter((tag) => tag !== "deploy"));
  });
});

describe("public cache keys", () => {
  it("ignores query parameter order", () => {
    expect(requestCacheKey({ originalUrl: "/v1/public/listings?b=2&a=1" })).toBe(requestCacheKey({ originalUrl: "/v1/public/listings?a=1&b=2" }));
    expect(requestCacheKey({ originalUrl: "/v1/public/listings?a=1" })).not.toBe(requestCacheKey({ originalUrl: "/v1/public/listings?a=2" }));
  });

  it("narrows tags by route and always includes the deploy tag", () => {
    expect(tagsForPath("/blogs/hello")).toEqual(["editorial", "organizations", "deploy"]);
    expect(tagsForPath("/home")).toEqual(ALL_TAGS);
  });
});
