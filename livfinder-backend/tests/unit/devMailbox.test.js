import { describe, expect, it } from "vitest";
import { escapeHtml, linkify, mailFilePath } from "../../src/modules/system/devMailbox.routes.js";

describe("local mailbox", () => {
  it("only reaches files inside the mailbox", () => {
    expect(mailFilePath("2026-11-02-a@example.test.txt")).toContain("mailbox");
    for (const name of ["../.env", "..%2f.env", "a/b.txt", "a..b.txt", ".env"]) expect(mailFilePath(name)).toBeNull();
  });

  it("shows mail as text, so a message cannot run in the page", () => {
    expect(escapeHtml(`<script>alert("x")</script>`)).not.toContain("<");
  });

  it("makes links clickable, including their query string", () => {
    expect(linkify(escapeHtml("Open http://localhost:3000/verify-email?token=abc now"))).toContain(
      '<a href="http://localhost:3000/verify-email?token=abc"'
    );
  });
});
