import { describe, expect, it } from "vitest";
import { refFor, resumeToken, teamAccountIds, verifyResumeToken } from "../../src/modules/chat/identity.js";

describe("chat resume links", () => {
  it("round-trips a guest id", () => {
    const token = resumeToken("01JGUEST000000000000000000");
    expect(verifyResumeToken(token)).toBe("01JGUEST000000000000000000");
  });

  it("refuses a tampered or expired link", () => {
    const token = resumeToken("01JGUEST000000000000000000");
    const [id, expires, signature] = token.split(".");
    expect(verifyResumeToken(`01JOTHER000000000000000000.${expires}.${signature}`)).toBeNull();
    expect(verifyResumeToken(`${id}.${Number(expires) + 1}.${signature}`)).toBeNull();
    expect(verifyResumeToken(`${token}x`)).toBeNull();
    expect(verifyResumeToken("not-a-token")).toBeNull();
    const old = resumeToken("01JGUEST000000000000000000", Date.now() - 31 * 24 * 60 * 60 * 1000);
    expect(verifyResumeToken(old)).toBeNull();
  });
});

describe("chat identities", () => {
  it("names users and guests apart", () => {
    expect(refFor({ type: "user", publicId: "U1" })).toBe("u:U1");
    expect(refFor({ type: "guest", publicId: "G1" })).toBe("g:G1");
  });

  it("shares an enquiry inbox only with owners, admins and lead managers", () => {
    const identity = {
      type: "user",
      memberships: [
        { account_id: 1, role: "owner", membership_status: "active" },
        { account_id: 2, role: "viewer", membership_status: "active", can_manage_leads: 0 },
        { account_id: 3, role: "agent", membership_status: "active", can_manage_leads: 1 },
        { account_id: 4, role: "owner", membership_status: "suspended" },
      ],
    };
    expect(teamAccountIds(identity)).toEqual([1, 3]);
    expect(teamAccountIds({ type: "guest" })).toEqual([]);
  });
});
