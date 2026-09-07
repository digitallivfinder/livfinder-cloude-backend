import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";
import { StorageAdapter } from "./storageAdapter.js";

const VISIBILITY_DIRS = { public: "public", private: "private" };

export class LocalStorageAdapter extends StorageAdapter {
  constructor({ root = env.LOCAL_STORAGE_PATH, publicBaseUrl = env.STORAGE_PUBLIC_BASE_URL } = {}) {
    super();
    this.root = path.resolve(process.cwd(), root);
    this.publicBaseUrl = publicBaseUrl.replace(/\/+$/, "");
  }

  get driver() {
    return "local";
  }

  // Resolves a key inside its visibility root and refuses to escape it. Keys are
  // generated server-side, but a traversal here would expose the private tree.
  resolve(key, visibility) {
    const dir = VISIBILITY_DIRS[visibility];
    if (!dir) throw new TypeError(`unknown visibility: ${visibility}`);
    const base = path.join(this.root, dir);
    const target = path.resolve(base, key);
    if (target !== base && !target.startsWith(base + path.sep)) {
      throw AppError.badRequest("Invalid storage key.");
    }
    return target;
  }

  async put(key, body, { contentType, visibility = "public" } = {}) {
    const target = this.resolve(key, visibility);
    await fs.mkdir(path.dirname(target), { recursive: true });
    const buffer = Buffer.isBuffer(body) ? body : Buffer.from(body);
    await fs.writeFile(target, buffer);
    return {
      key,
      visibility,
      size: buffer.length,
      contentType: contentType || null,
      checksum: crypto.createHash("sha256").update(buffer).digest("hex"),
      url: visibility === "public" ? this.publicUrl(key) : null,
    };
  }

  async get(key, { visibility = "public" } = {}) {
    try {
      return await fs.readFile(this.resolve(key, visibility));
    } catch (error) {
      if (error.code === "ENOENT") throw AppError.notFound("That file is no longer stored.");
      throw error;
    }
  }

  createStream(key, { visibility = "public" } = {}) {
    return createReadStream(this.resolve(key, visibility));
  }

  async stat(key, { visibility = "public" } = {}) {
    try {
      const stats = await fs.stat(this.resolve(key, visibility));
      return { size: stats.size, modifiedAt: stats.mtime };
    } catch (error) {
      if (error.code === "ENOENT") return null;
      throw error;
    }
  }

  async delete(key, { visibility = "public" } = {}) {
    try {
      await fs.unlink(this.resolve(key, visibility));
      return true;
    } catch (error) {
      if (error.code === "ENOENT") return false;
      throw error;
    }
  }

  async exists(key, { visibility = "public" } = {}) {
    return (await this.stat(key, { visibility })) !== null;
  }

  publicUrl(key) {
    return `${this.publicBaseUrl}/${key.split("/").map(encodeURIComponent).join("/")}`;
  }

  // The local equivalent of a presigned PUT: an HMAC-signed URL on this API that
  // the upload route verifies before writing.
  signKey(key, visibility, expiresAt) {
    return crypto
      .createHmac("sha256", env.SESSION_SECRET)
      .update(`${key}|${visibility}|${expiresAt}`)
      .digest("base64url");
  }

  verifySignature(key, visibility, expiresAt, signature) {
    if (!expiresAt || Number(expiresAt) < Date.now()) return false;
    const expected = this.signKey(key, visibility, expiresAt);
    const a = Buffer.from(String(signature || ""));
    const b = Buffer.from(expected);
    return a.length === b.length && crypto.timingSafeEqual(a, b);
  }

  async createUploadTarget({ key, contentType, visibility = "private", expiresInSeconds = 900 }) {
    const expiresAt = Date.now() + expiresInSeconds * 1000;
    const signature = this.signKey(key, visibility, expiresAt);
    const params = new URLSearchParams({ key, visibility, expires: String(expiresAt), signature });
    return {
      method: "PUT",
      url: `/v1/media/direct-upload?${params}`,
      headers: contentType ? { "Content-Type": contentType } : {},
      key,
      expiresAt: new Date(expiresAt).toISOString(),
      driver: "local",
    };
  }

  async createSignedReadUrl(key, { visibility = "private", expiresInSeconds = 300 } = {}) {
    const expiresAt = Date.now() + expiresInSeconds * 1000;
    const signature = this.signKey(key, visibility, expiresAt);
    const params = new URLSearchParams({ key, visibility, expires: String(expiresAt), signature });
    return `/v1/media/signed?${params}`;
  }
}

export default LocalStorageAdapter;
