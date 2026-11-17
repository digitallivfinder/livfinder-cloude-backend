import { describe, expect, it } from "vitest";
import { CATEGORIES } from "../../src/modules/email/catalog.js";
import { normalizeProviderEvents } from "../../src/modules/email/email.routes.js";
import { area, dateTime, money, priceLine } from "../../src/modules/email/format.js";
import { readUnsubscribeToken, unsubscribeToken } from "../../src/modules/email/preferences.js";
import { renderEmail } from "../../src/modules/email/render.js";
import { TEMPLATES } from "../../src/modules/email/templates/index.js";

const ctx = { recipient: { firstName: "Sara", timezone: "Asia/Dubai", currency: "USD", areaUnit: "sqm" }, rates: { USD: 0.2723 } };

describe("email templates", () => {
  for (const [key, template] of Object.entries(TEMPLATES)) {
    it(`${key} renders its sample in HTML and text`, () => {
      expect(CATEGORIES[template.category], `${key} has a known category`).toBeTruthy();
      expect(template.label).toBeTruthy();
      const output = template.render(template.sample ?? {}, ctx);
      expect(output.subject).toBeTruthy();
      expect(output.subject.length).toBeLessThanOrEqual(200);
      const { html, text } = renderEmail({ ...output, footer: { reason: "Test", unsubscribeUrl: "https://example.test/u" } });
      expect(html).toContain("<!doctype html>");
      expect(html).toContain("LivFinder");
      expect(html).not.toContain("undefined");
      expect(text).not.toContain("undefined");
      expect(text).not.toContain("[object Object]");
    });
  }

  it("escapes what people typed, so a message cannot inject markup", () => {
    const output = TEMPLATES["leads.new_enquiry"].render(
      { ...TEMPLATES["leads.new_enquiry"].sample, lead: { name: "<img src=x onerror=alert(1)>", email: "a@b.c", message: "<script>x</script>" } },
      ctx
    );
    const { html } = renderEmail(output);
    expect(html).not.toContain("<script>x");
    expect(html).not.toContain("<img src=x");
  });

  it("keeps the token link in the text part, which tests and plain-text readers rely on", () => {
    const output = TEMPLATES["auth.password_reset"].render({ url: "http://localhost:3000/reset-password?token=abc123" }, ctx);
    expect(renderEmail(output).text).toContain("token=abc123");
  });
});

describe("email formatting", () => {
  it("shows prices in the listing currency and the reader's", () => {
    expect(money(42000000, "AED")).toBe("AED 42,000,000");
    expect(priceLine({ price: 42000000, currency: "AED", priceBase: 42000000 }, { currency: "USD" }, { USD: 0.2723 })).toBe("AED 42,000,000 · about USD 11.44M");
    expect(priceLine({ price: 100, currency: "AED", priceBase: 100 }, { currency: "AED" }, {})).toBe("AED 100");
  });

  it("converts areas to the reader's unit", () => {
    expect(area(1000, "sqft")).toBe("1,000 sqft");
    expect(area(1000, "sqm")).toBe("93 sqm");
  });

  it("writes times in the reader's timezone", () => {
    expect(dateTime("2026-11-18T10:00:00Z", "Asia/Dubai")).toContain("14:00");
    expect(dateTime("2026-11-18T10:00:00Z", "Not/AZone")).toContain("(Dubai)");
  });
});

describe("unsubscribe links", () => {
  it("round-trips and rejects a changed token", () => {
    const token = unsubscribeToken("Person@Example.com", "leads");
    expect(readUnsubscribeToken(token)).toEqual({ email: "person@example.com", category: "leads" });
    const [payload] = token.split(".");
    const forged = `${Buffer.from(JSON.stringify({ e: "other@example.com", c: "leads" })).toString("base64url")}.${token.split(".")[1]}`;
    expect(readUnsubscribeToken(forged)).toBeNull();
    expect(readUnsubscribeToken(`${payload}.x`)).toBeNull();
    expect(readUnsubscribeToken("nonsense")).toBeNull();
  });
});

describe("provider events", () => {
  it("reads Postmark bounces and complaints", () => {
    expect(normalizeProviderEvents("postmark", { RecordType: "Bounce", Type: "HardBounce", Email: "a@b.c", MessageID: "m1" })[0]).toMatchObject({ email: "a@b.c", event: "bounced" });
    expect(normalizeProviderEvents("postmark", { RecordType: "SpamComplaint", Email: "a@b.c" })[0].event).toBe("complained");
  });

  it("reads SES notifications through SNS", () => {
    const body = { Type: "Notification", Message: JSON.stringify({ notificationType: "Bounce", mail: { messageId: "x" }, bounce: { bounceType: "Permanent", bouncedRecipients: [{ emailAddress: "a@b.c" }] } }) };
    expect(normalizeProviderEvents("ses", body)).toEqual([expect.objectContaining({ email: "a@b.c", event: "bounced", providerMessageId: "x" })]);
  });

  it("reads SendGrid event batches", () => {
    const events = normalizeProviderEvents("sendgrid", [{ event: "bounce", email: "a@b.c" }, { event: "spamreport", email: "d@e.f" }, { event: "open", email: "g@h.i" }]);
    expect(events.map((item) => item.event)).toEqual(["bounced", "complained"]);
  });
});
