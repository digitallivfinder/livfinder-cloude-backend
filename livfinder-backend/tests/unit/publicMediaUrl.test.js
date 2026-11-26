import { describe, expect, it } from "vitest";
import { apiMediaBaseUrl, publicMediaUrl } from "../../src/utils/publicMediaUrl.js";

const base = "https://api.livfinder.com/media/";
describe("public media restored from development", () => {
  it.each(["http://localhost:4100", "http://127.0.0.1:4000", "http://[::1]:4100", ""])(
    "relocates %s media without changing its key", (origin) => {
      expect(publicMediaUrl(`${origin}/media/listings/my%20photo.card.webp`, base))
        .toBe("https://api.livfinder.com/media/listings/my%20photo.card.webp");
    }
  );
  it.each([
    "https://photos.example.com/public/a.jpg?X-Amz-Signature=abc",
    "/v1/media/signed?key=private/a.jpg&signature=abc",
    "/media/a.jpg?signature=abc",
    "http://localhost:4100/v1/media/signed?signature=abc",
    "http://localhost:4100/media/a.jpg?signature=abc",
    "https://localhost.evil.example/media/a.jpg",
    "private://documents/a.jpg", "/images/brand.jpg", "//example.com/media/a.jpg", null,
  ])("leaves unrelated/private/signed value unchanged: %s", (value) => {
    expect(publicMediaUrl(value, base)).toBe(value);
  });
});

describe("the API's own media base", () => {
  it("is the storage base on the local driver", () => {
    expect(apiMediaBaseUrl({ STORAGE_DRIVER: "local", STORAGE_PUBLIC_BASE_URL: "http://localhost:4100/media/" }))
      .toBe("http://localhost:4100/media");
  });
  it("never falls back to the bucket on s3", () => {
    expect(apiMediaBaseUrl({ STORAGE_DRIVER: "s3", STORAGE_PUBLIC_BASE_URL: "https://b.s3.amazonaws.com/public" }))
      .toBeNull();
    expect(apiMediaBaseUrl({
      STORAGE_DRIVER: "s3",
      STORAGE_PUBLIC_BASE_URL: "https://b.s3.amazonaws.com/public",
      API_MEDIA_BASE_URL: "https://api.livfinder.com/media",
    })).toBe("https://api.livfinder.com/media");
  });
});
