import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import os from "node:os";
import path from "node:path";
import fs from "node:fs/promises";

/** Builds the env object as config/env.js would, for one combination of settings. */
function envFor({ driver, live }) {
  return {
    NODE_ENV: "development",
    isProduction: false,
    isTest: false,
    PORT: 4100,
    LOCAL_STORAGE_PATH: path.join(os.tmpdir(), `lf-mail-${process.pid}`),
    MAIL_DRIVER: driver,
    MAIL_LIVE: live,
    mailDriver: driver === "smtp" && live === true ? "smtp" : "log",
    MAIL_FROM: "no-reply@livfinder.com",
    MAIL_FROM_NAME: "LivFinder",
    EMAIL_SUPPORT_ADDRESS: "support@livfinder.com",
    SMTP_HOST: "smtp.gmail.com",
    SMTP_PORT: 465,
    SMTP_USER: "noreply@livfinder.com",
    SMTP_PASSWORD: "secret",
  };
}

const sendMailSpy = vi.fn(async () => ({ messageId: "smtp-1" }));

async function load(settings) {
  vi.resetModules();
  vi.doMock("../../src/config/env.js", () => {
    const env = envFor(settings);
    return { default: env, env };
  });
  vi.doMock("../../src/config/logger.js", () => ({ default: { info: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() } }));
  vi.doMock("nodemailer", () => ({ createTransport: () => ({ sendMail: sendMailSpy, verify: vi.fn() }) }));
  return import("../../src/modules/system/mail.service.js");
}

const message = { to: "buyer@example.com", subject: "Hello", text: "Body" };

beforeEach(() => {
  sendMailSpy.mockClear();
  vi.spyOn(process.stdout, "write").mockImplementation(() => true);
});

afterEach(async () => {
  vi.restoreAllMocks();
  await fs.rm(path.join(os.tmpdir(), `lf-mail-${process.pid}`), { recursive: true, force: true });
});

describe("MAIL_LIVE", () => {
  it("never sends from a system that is not live, even with SMTP configured", async () => {
    const mail = await load({ driver: "smtp", live: false });
    const result = await mail.sendMail(message);
    expect(result.driver).toBe("log");
    expect(sendMailSpy).not.toHaveBeenCalled();
    expect(mail.mailModeSummary()).toEqual({ mode: "log", detail: expect.stringContaining("NOT sent (system not live (MAIL_LIVE is not true))") });
    expect((await mail.verifyTransport()).driver).toBe("log");
  });

  it("logs with MAIL_DRIVER=log whatever MAIL_LIVE says", async () => {
    const mail = await load({ driver: "log", live: true });
    expect((await mail.sendMail(message)).driver).toBe("log");
    expect(sendMailSpy).not.toHaveBeenCalled();
  });

  it("sends only when MAIL_DRIVER=smtp and MAIL_LIVE=true", async () => {
    const mail = await load({ driver: "smtp", live: true });
    expect((await mail.sendMail(message)).driver).toBe("smtp");
    expect(sendMailSpy).toHaveBeenCalledTimes(1);
    expect(mail.mailModeSummary().mode).toBe("live");
  });

  it("writes a logged email to the mailbox with its recipient and subject", async () => {
    const mail = await load({ driver: "smtp", live: false });
    const result = await mail.sendMail(message);
    const text = await fs.readFile(result.file, "utf8");
    expect(text).toContain("To: buyer@example.com");
    expect(text).toContain("Subject: Hello");
  });
});
