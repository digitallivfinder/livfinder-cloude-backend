import { describe, expect, it } from "vitest";
import { buildInvite } from "../../src/modules/calendar/ics.js";

const base = {
  uid: "abc@livfinder.com",
  start: "2026-12-01T09:00:00.000Z",
  end: "2026-12-01T10:00:00.000Z",
  summary: "Viewing: Villa, Palm; Jumeirah",
};

describe("buildInvite", () => {
  it("writes a calendar file with UTC times and CRLF lines", () => {
    const ics = buildInvite({ ...base, sequence: 3 });
    expect(ics).toContain("METHOD:REQUEST\r\n");
    expect(ics).toContain("SEQUENCE:3\r\n");
    expect(ics).toContain("DTSTART:20261201T090000Z\r\n");
    expect(ics).toContain("DTEND:20261201T100000Z\r\n");
    expect(ics.endsWith("END:VCALENDAR\r\n")).toBe(true);
  });

  it("escapes text so a value cannot break out into a new property", () => {
    const ics = buildInvite({ ...base, description: "Line one\nATTENDEE:mailto:evil@example.test" });
    expect(ics).toContain(String.raw`SUMMARY:Viewing: Villa\, Palm\; Jumeirah`);
    expect(ics).toContain("DESCRIPTION:Line one\\nATTENDEE:mailto:evil@example.test");
    expect(ics).not.toMatch(/\r\nATTENDEE:mailto:evil/);
  });

  it("folds long lines at 75 bytes without splitting a character", () => {
    const ics = buildInvite({ ...base, summary: "ع".repeat(80) });
    for (const line of ics.split("\r\n")) expect(Buffer.byteLength(line)).toBeLessThanOrEqual(75);
    expect(ics.replace(/\r\n /g, "")).toContain(`SUMMARY:${"ع".repeat(80)}`);
  });

  it("marks a cancellation", () => {
    const ics = buildInvite({ ...base, method: "CANCEL" });
    expect(ics).toContain("METHOD:CANCEL\r\n");
    expect(ics).toContain("STATUS:CANCELLED\r\n");
  });
});
