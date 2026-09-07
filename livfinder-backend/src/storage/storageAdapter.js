/**
 * Storage contract.
 *
 * Two visibilities matter and are not interchangeable:
 *   "public"  — listing galleries, organisation logos, agent photos. Served
 *               directly under a public base URL.
 *   "private" — verification documents, identity papers, contracts. Never
 *               reachable by URL; read back through an authorised endpoint or a
 *               short-lived signed URL.
 *
 * Implementations must place the two in separate prefixes/buckets so a
 * misconfigured web server cannot expose the private set.
 */
export class StorageAdapter {
  get driver() {
    throw new Error("not implemented");
  }

  // eslint-disable-next-line no-unused-vars
  async put(key, body, { contentType, visibility = "public", cacheControl } = {}) {
    throw new Error("not implemented");
  }

  // eslint-disable-next-line no-unused-vars
  async get(key, { visibility = "public" } = {}) {
    throw new Error("not implemented");
  }

  // eslint-disable-next-line no-unused-vars
  async delete(key, { visibility = "public" } = {}) {
    throw new Error("not implemented");
  }

  // eslint-disable-next-line no-unused-vars
  async exists(key, { visibility = "public" } = {}) {
    throw new Error("not implemented");
  }

  /** Absolute URL for a public object. Throws for private ones. */
  // eslint-disable-next-line no-unused-vars
  publicUrl(key) {
    throw new Error("not implemented");
  }

  /**
   * A short-lived upload target. S3 returns a genuine presigned PUT; the local
   * driver returns an API endpoint that accepts the same PUT, so the client
   * flow is identical in development.
   */
  // eslint-disable-next-line no-unused-vars
  async createUploadTarget({ key, contentType, visibility = "private", expiresInSeconds = 900 }) {
    throw new Error("not implemented");
  }

  // eslint-disable-next-line no-unused-vars
  async createSignedReadUrl(key, { visibility = "private", expiresInSeconds = 300 } = {}) {
    throw new Error("not implemented");
  }
}

export default StorageAdapter;
