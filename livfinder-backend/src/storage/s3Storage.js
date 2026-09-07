import crypto from "node:crypto";
import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";
import { StorageAdapter } from "./storageAdapter.js";

const PREFIX = { public: "public", private: "private" };

export class S3StorageAdapter extends StorageAdapter {
  constructor(options = {}) {
    super();
    this.bucket = options.bucket ?? env.STORAGE_BUCKET;
    this.publicBaseUrl = (options.publicBaseUrl ?? env.STORAGE_PUBLIC_BASE_URL ?? "").replace(/\/+$/, "");
    if (!this.bucket) {
      throw new Error("STORAGE_BUCKET is required when STORAGE_DRIVER=s3");
    }
    this.client = new S3Client({
      region: options.region ?? env.STORAGE_REGION ?? "us-east-1",
      // Optional for AWS proper; required for R2/MinIO/Spaces.
      endpoint: options.endpoint ?? env.STORAGE_ENDPOINT ?? undefined,
      forcePathStyle: options.forcePathStyle ?? env.STORAGE_FORCE_PATH_STYLE,
      credentials:
        (options.accessKeyId ?? env.STORAGE_ACCESS_KEY)
          ? {
              accessKeyId: options.accessKeyId ?? env.STORAGE_ACCESS_KEY,
              secretAccessKey: options.secretAccessKey ?? env.STORAGE_SECRET_KEY,
            }
          : undefined, // fall back to the ambient AWS credential chain
    });
  }

  get driver() {
    return "s3";
  }

  objectKey(key, visibility) {
    const prefix = PREFIX[visibility];
    if (!prefix) throw new TypeError(`unknown visibility: ${visibility}`);
    if (key.includes("..")) throw AppError.badRequest("Invalid storage key.");
    return `${prefix}/${key}`;
  }

  async put(key, body, { contentType, visibility = "public", cacheControl } = {}) {
    const buffer = Buffer.isBuffer(body) ? body : Buffer.from(body);
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: this.objectKey(key, visibility),
        Body: buffer,
        ContentType: contentType || "application/octet-stream",
        CacheControl: cacheControl || (visibility === "public" ? "public, max-age=31536000, immutable" : "private, no-store"),
      })
    );
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
      const result = await this.client.send(
        new GetObjectCommand({ Bucket: this.bucket, Key: this.objectKey(key, visibility) })
      );
      return Buffer.from(await result.Body.transformToByteArray());
    } catch (error) {
      if (error?.name === "NoSuchKey" || error?.$metadata?.httpStatusCode === 404) {
        throw AppError.notFound("That file is no longer stored.");
      }
      throw error;
    }
  }

  async delete(key, { visibility = "public" } = {}) {
    await this.client.send(
      new DeleteObjectCommand({ Bucket: this.bucket, Key: this.objectKey(key, visibility) })
    );
    return true;
  }

  async exists(key, { visibility = "public" } = {}) {
    try {
      await this.client.send(
        new HeadObjectCommand({ Bucket: this.bucket, Key: this.objectKey(key, visibility) })
      );
      return true;
    } catch {
      return false;
    }
  }

  publicUrl(key) {
    if (this.publicBaseUrl) {
      return `${this.publicBaseUrl}/${key.split("/").map(encodeURIComponent).join("/")}`;
    }
    return `https://${this.bucket}.s3.amazonaws.com/${this.objectKey(key, "public")}`;
  }

  async createUploadTarget({ key, contentType, visibility = "private", expiresInSeconds = 900 }) {
    const url = await getSignedUrl(
      this.client,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: this.objectKey(key, visibility),
        ContentType: contentType || "application/octet-stream",
      }),
      { expiresIn: expiresInSeconds }
    );
    return {
      method: "PUT",
      url,
      headers: contentType ? { "Content-Type": contentType } : {},
      key,
      expiresAt: new Date(Date.now() + expiresInSeconds * 1000).toISOString(),
      driver: "s3",
    };
  }

  async createSignedReadUrl(key, { visibility = "private", expiresInSeconds = 300 } = {}) {
    return getSignedUrl(
      this.client,
      new GetObjectCommand({ Bucket: this.bucket, Key: this.objectKey(key, visibility) }),
      { expiresIn: expiresInSeconds }
    );
  }
}

export default S3StorageAdapter;
