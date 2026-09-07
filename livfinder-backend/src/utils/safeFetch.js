import dns from "node:dns/promises";
import net from "node:net";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";
import logger from "../config/logger.js";

/**
 * Outbound HTTP with a destination allow-list — SEC-APP-012.
 *
 * The OAuth callback fetches a token URL and a userinfo URL taken from provider configuration.
 * Those are administrator-supplied, which is exactly the shape of a server-side request forgery:
 * point one at `http://169.254.169.254/` and the API will happily fetch cloud instance
 * credentials and hand the response to the caller's session.
 *
 * Four checks, in order of how cheap they are:
 *
 *   1. https only outside development. A plaintext token exchange is its own problem.
 *   2. The host must be on the allow-list, if one is configured.
 *   3. Every resolved address must be public. This is the one that matters — a hostname on the
 *      allow-list can still resolve to 127.0.0.1 or a link-local address, and DNS is attacker
 *      controlled far more often than configuration is.
 *   4. Redirects are not followed. A permitted host that 302s to the metadata endpoint would
 *      walk straight past checks 2 and 3.
 *
 * The TOCTOU gap between resolving and connecting is real and not closed here: doing that
 * properly needs a custom agent that pins the checked address. The checks above remove the
 * straightforward attacks; the residual risk is noted rather than papered over.
 */

const PRIVATE_V4 = [
  { base: "0.0.0.0", bits: 8 },
  { base: "10.0.0.0", bits: 8 },
  { base: "100.64.0.0", bits: 10 },
  { base: "127.0.0.0", bits: 8 },
  { base: "169.254.0.0", bits: 16 }, // link-local, and the cloud metadata endpoint
  { base: "172.16.0.0", bits: 12 },
  { base: "192.0.0.0", bits: 24 },
  { base: "192.168.0.0", bits: 16 },
  { base: "198.18.0.0", bits: 15 },
  { base: "224.0.0.0", bits: 4 },
  { base: "240.0.0.0", bits: 4 },
];

const toInt = (address) => address.split(".").reduce((total, part) => (total << 8) + Number(part), 0) >>> 0;

function isPrivateV4(address) {
  const value = toInt(address);
  return PRIVATE_V4.some(({ base, bits }) => (value ^ toInt(base)) >>> (32 - bits) === 0);
}

function isPrivateV6(address) {
  const lower = address.toLowerCase();
  if (lower === "::1" || lower === "::") return true;
  if (lower.startsWith("fc") || lower.startsWith("fd")) return true; // unique local
  if (lower.startsWith("fe80")) return true; // link-local
  // IPv4-mapped: ::ffff:169.254.169.254 must not slip past the v4 rules.
  const mapped = lower.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
  if (mapped) return isPrivateV4(mapped[1]);
  return false;
}

export function isPrivateAddress(address) {
  if (net.isIPv4(address)) return isPrivateV4(address);
  if (net.isIPv6(address)) return isPrivateV6(address);
  return true; // Unparseable is not provably public.
}

/** Hosts an operator has explicitly permitted. Empty means "any public address". */
function allowedHosts() {
  return String(env.OUTBOUND_ALLOWED_HOSTS ?? "")
    .split(",")
    .map((entry) => entry.trim().toLowerCase())
    .filter(Boolean);
}

export async function assertSafeUrl(rawUrl) {
  let url;
  try {
    url = new URL(String(rawUrl));
  } catch {
    throw AppError.badRequest("That URL is not valid.");
  }

  if (url.protocol !== "https:" && !(env.isProduction === false && url.protocol === "http:")) {
    throw AppError.badRequest("Only https destinations are allowed.");
  }

  const hosts = allowedHosts();
  const host = url.hostname.toLowerCase();
  if (hosts.length && !hosts.some((entry) => host === entry || host.endsWith(`.${entry}`))) {
    throw AppError.forbidden("That destination is not permitted.");
  }

  // A literal address skips DNS but not the range check.
  const addresses = net.isIP(host)
    ? [host]
    : (await dns.lookup(host, { all: true }).catch(() => [])).map((entry) => entry.address);

  if (!addresses.length) throw AppError.badRequest("That host could not be resolved.");
  for (const address of addresses) {
    if (isPrivateAddress(address)) {
      logger.warn({ host, address }, "outbound request blocked: destination resolves to a private address");
      throw AppError.forbidden("That destination is not permitted.");
    }
  }
  return url;
}

/**
 * `fetch`, with the checks above and no redirect following.
 *
 * Use this for every request to a URL that is not a compile-time constant.
 */
export async function safeFetch(rawUrl, options = {}) {
  const url = await assertSafeUrl(rawUrl);
  return fetch(url, {
    ...options,
    redirect: "error",
    signal: options.signal ?? AbortSignal.timeout(options.timeoutMs ?? 10_000),
  });
}

export default safeFetch;
