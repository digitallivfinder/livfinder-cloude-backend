import net from "node:net";
import env from "../../config/env.js";
import logger from "../../config/logger.js";

/**
 * Malware scanning for uploads — SEC-APP-011.
 *
 * `media_assets.scan_status` is an enum with `pending / clean / infected / failed / skipped`,
 * and every row was written as `skipped`: nothing ever looked at an uploaded file. Uploads were
 * type-verified by reading the actual bytes with sharp, which stops a `.exe` renamed to `.jpg`,
 * but says nothing about a genuine image carrying a payload.
 *
 * Three drivers, chosen by `MALWARE_SCAN_DRIVER`:
 *
 *   none    — the default. Records `skipped` and says so. Honest about doing nothing, which is
 *             the point: `skipped` is a different claim from `clean`, and the previous code
 *             wrote the former while the UI read it as the latter.
 *   clamav  — talks INSTREAM to a clamd socket. This is the real one.
 *   reject  — treats an unavailable scanner as infected. For deployments where an unscanned
 *             file must never be stored, at the cost of refusing uploads when clamd is down.
 *
 * A scanner being unreachable is deliberately *not* fatal under `clamav`: the asset is stored
 * as `failed`, which is queryable, rather than losing a seller's photographs to an outage. Use
 * `reject` when that trade goes the other way.
 */

const MAX_CHUNK = 64 * 1024;

/** clamd INSTREAM: length-prefixed chunks, then a zero-length terminator. */
async function scanWithClamAv(buffer, { host, port, timeoutMs }) {
  return new Promise((resolve) => {
    const socket = net.createConnection({ host, port });
    let response = "";
    let settled = false;

    const finish = (value) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(value);
    };

    socket.setTimeout(timeoutMs, () => finish({ status: "failed", detail: "scanner timed out" }));
    socket.on("error", (error) => finish({ status: "failed", detail: error.message }));
    socket.on("data", (chunk) => {
      response += chunk.toString("utf8");
    });
    socket.on("close", () => {
      const text = response.trim();
      if (!text) return finish({ status: "failed", detail: "no response from scanner" });
      if (text.endsWith("OK")) return finish({ status: "clean", detail: null });
      if (text.includes("FOUND")) {
        return finish({ status: "infected", detail: text.replace(/^stream:\s*/, "").replace(/\s*FOUND$/, "") });
      }
      return finish({ status: "failed", detail: text.slice(0, 200) });
    });

    socket.on("connect", () => {
      socket.write("zINSTREAM\0");
      for (let offset = 0; offset < buffer.length; offset += MAX_CHUNK) {
        const chunk = buffer.subarray(offset, offset + MAX_CHUNK);
        const header = Buffer.alloc(4);
        header.writeUInt32BE(chunk.length, 0);
        socket.write(header);
        socket.write(chunk);
      }
      socket.write(Buffer.from([0, 0, 0, 0]));
    });
  });
}

/**
 * Scans a buffer and returns the `scan_status` to record.
 *
 * Never throws: a scanner problem is recorded on the asset, not raised at the person uploading.
 * The caller decides whether an `infected` result blocks the upload — it does, in media.service.
 */
export async function scanBuffer(buffer) {
  const driver = env.MALWARE_SCAN_DRIVER ?? "none";
  if (driver === "none") return { status: "skipped", detail: "no scanner configured" };

  try {
    const result = await scanWithClamAv(buffer, {
      host: env.CLAMAV_HOST ?? "127.0.0.1",
      port: Number(env.CLAMAV_PORT ?? 3310),
      timeoutMs: Number(env.CLAMAV_TIMEOUT_MS ?? 15_000),
    });

    if (result.status === "failed") {
      logger.warn({ detail: result.detail }, "upload scan failed");
      // `reject` means an unscanned file is treated as unsafe.
      if (driver === "reject") return { status: "infected", detail: `scanner unavailable: ${result.detail}` };
    }
    return result;
  } catch (error) {
    logger.warn({ err: error }, "upload scan errored");
    return driver === "reject"
      ? { status: "infected", detail: "scanner unavailable" }
      : { status: "failed", detail: error.message };
  }
}

export default scanBuffer;
