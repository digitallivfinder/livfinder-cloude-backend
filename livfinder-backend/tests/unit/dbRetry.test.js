import { describe, expect, it, vi } from "vitest";
import { isTransientDbError, retryTransient } from "../../src/db/retry.js";
import { AppError } from "../../src/utils/errors.js";

const deadlock = () => AppError.internal("A database error occurred.", { cause: Object.assign(new Error("Deadlock found"), { code: "ER_LOCK_DEADLOCK", errno: 1213 }) });
const noSleep = () => Promise.resolve();

describe("retrying a transaction that lost a deadlock", () => {
  it("recognises a deadlock or lock wait timeout, wrapped or not", () => {
    expect(isTransientDbError(deadlock())).toBe(true);
    expect(isTransientDbError(Object.assign(new Error("x"), { code: "ER_LOCK_WAIT_TIMEOUT" }))).toBe(true);
    expect(isTransientDbError(AppError.internal("A database error occurred.", { cause: Object.assign(new Error("dup"), { code: "ER_DUP_ENTRY" }) }))).toBe(false);
    expect(isTransientDbError(new AppError("bad", { status: 422, code: "VALIDATION_ERROR" }))).toBe(false);
    expect(isTransientDbError(null)).toBe(false);
  });

  it("runs the work again after a deadlock and returns its result", async () => {
    const work = vi.fn().mockRejectedValueOnce(deadlock()).mockRejectedValueOnce(deadlock()).mockResolvedValue("done");
    await expect(retryTransient(work, { sleep: noSleep })).resolves.toBe("done");
    expect(work).toHaveBeenCalledTimes(3);
  });

  it("gives up after the last attempt with the deadlock itself", async () => {
    const work = vi.fn().mockRejectedValue(deadlock());
    await expect(retryTransient(work, { attempts: 3, sleep: noSleep })).rejects.toMatchObject({ code: "INTERNAL_ERROR" });
    expect(work).toHaveBeenCalledTimes(3);
  });

  it("never retries a real error", async () => {
    const work = vi.fn().mockRejectedValue(new AppError("Unknown property type", { status: 422, code: "UNMAPPED_VALUE" }));
    await expect(retryTransient(work, { sleep: noSleep })).rejects.toMatchObject({ code: "UNMAPPED_VALUE" });
    expect(work).toHaveBeenCalledTimes(1);
  });
});
