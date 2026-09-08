import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import sharp from "sharp";
import { describe, expect, it } from "vitest";

const directory = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../../assets/project-presentation"
);

describe("project presentation images", () => {
  it("ships five landscape WebP covers suitable for project cards", async () => {
    const files = (await fs.readdir(directory)).filter((file) => file.endsWith(".webp"));
    expect(files).toHaveLength(5);

    for (const file of files) {
      const metadata = await sharp(path.join(directory, file)).metadata();
      expect(metadata.format).toBe("webp");
      expect(metadata.width).toBeGreaterThanOrEqual(1500);
      expect(metadata.height).toBeGreaterThanOrEqual(1000);
      expect(metadata.width).toBeGreaterThan(metadata.height);
    }
  });
});

