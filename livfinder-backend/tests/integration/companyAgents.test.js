import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, client, createDisposablePortalOwner, ensureTestPassword, execute, query, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";

/**
 * A company and its team: a profile added by hand has no login, an invited person joins with
 * one. Everything runs against a company created here, so nothing touches real accounts.
 */
const PASSWORD = "LivFinder!2026";
const newPassword = "Harbour-view-2049";
const suffix = Date.now();
const address = (name) => `invite-${name}-${suffix}@example.test`;
const owner = client();
const emails = [];
const listings = [];
let organizationId;
let accountId;
let ownerEmail;
let handMadeAgent;

const invite = async (name, body = {}) => {
  const email = address(name);
  emails.push(email);
  clearSentMessages();
  const response = await owner.send("post", "/v1/portal/organization/invitations", { email, role: "agent", ...body });
  expect(response.status, JSON.stringify(response.body)).toBe(201);
  const mail = sentMessages().at(-1);
  return { email, id: response.body.data.id, mail, token: decodeURIComponent(mail.text.match(/token=([^\s]+)/)[1]) };
};
const accept = (person, body) => person.send("post", "/v1/accounts/invitations/accept", body);
const newcomer = { firstName: "Nadia", lastName: "Rahman", password: newPassword, agreements: true };
const session = async (person) => {
  const { data } = (await person.send("get", "/v1/auth/session")).body;
  person.csrfToken = data.csrfToken;
  return data;
};

beforeAll(async () => {
  await ensureTestPassword();
  const disposable = await createDisposablePortalOwner({ prefix: "company-agents" });
  ownerEmail = disposable.email;
  ({ id: accountId } = await queryOne("SELECT id FROM accounts WHERE owner_user_id = ?", [disposable.id]));
  await execute("UPDATE accounts a JOIN account_types t ON t.code = 'company' SET a.account_type_id = t.id WHERE a.id = ?", [accountId]);
  const organization = await execute(
    `INSERT INTO organizations (public_id, account_id, kind, name, legal_name, slug, status, verification_status, is_publicly_visible, created_at)
     VALUES (?, ?, 'agency', 'Team Test', 'Team Test LLC', ?, 'active', 'verified', 1, NOW(3))`,
    [`team${suffix}`, accountId, `team-test-${suffix}`]
  );
  organizationId = organization.insertId;
  await execute("UPDATE agents SET organization_id = ? WHERE user_id = ?", [organizationId, disposable.id]);
  await execute("UPDATE account_members SET role = 'owner', can_manage_members = 1 WHERE account_id = ?", [accountId]);
  await owner.login(ownerEmail, PASSWORD);
});

afterAll(async () => {
  await cleanupListings(listings);
  await execute("DELETE FROM team_invitations WHERE organization_id = ?", [organizationId]);
  await execute("DELETE FROM agents WHERE organization_id = ?", [organizationId]);
  await execute("DELETE FROM organizations WHERE id = ?", [organizationId]);
  await cleanupUsers([ownerEmail, ...emails]);
  await closePool();
});

describe("Adding an agent by hand", () => {
  it("creates the profile with its formatted biography, public under the company", async () => {
    const response = await owner.send("post", "/v1/portal/organization/agents", {
      firstName: "Nadia", lastName: "Rahman", title: "Sales Advisor", email: address("profile"),
      bio: "<p>Ten years in <strong>Dubai</strong>.</p><script>alert(1)</script>",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    handMadeAgent = response.body.data;
    const stored = await queryOne("SELECT bio, user_id FROM agents WHERE slug = ?", [handMadeAgent.slug]);
    expect(stored.bio).not.toContain("script");
    expect(stored.user_id).toBeNull();
    const profile = await client().send("get", `/v1/public/agents/${handMadeAgent.slug}`);
    expect(profile.status).toBe(200);
    expect((profile.body.data.agent ?? profile.body.data).biographyHtml).toContain("<strong>Dubai</strong>");
  });
});

describe("Inviting someone new", () => {
  const person = client();
  let invitation;

  it("emails a link and shows the invitation as waiting", async () => {
    invitation = await invite("new", { firstName: "Nadia", title: "Sales Advisor" });
    expect(invitation.mail.to).toBe(invitation.email);
    expect(invitation.mail.subject).toContain("Team Test");
    expect(invitation.mail.text).toContain("/accept-invite?token=");
    const list = (await owner.send("get", "/v1/portal/organization/invitations")).body.data;
    expect(list.find((row) => row.id === invitation.id)).toMatchObject({ status: "pending", role: "agent" });
    const stored = await queryOne("SELECT token_hash FROM team_invitations WHERE public_id = ?", [invitation.id]);
    expect(stored.token_hash).not.toBe(invitation.token);
  });

  it("will not invite the same address twice", async () => {
    const again = await owner.send("post", "/v1/portal/organization/invitations", { email: invitation.email, role: "agent" });
    expect(again.status).toBe(409);
  });

  it("tells the invited person what they are joining", async () => {
    const preview = await client().send("post", "/v1/accounts/invitations/preview", { token: invitation.token });
    expect(preview.status).toBe(200);
    expect(preview.body.data).toMatchObject({ company: "Team Test", email: invitation.email, hasAccount: false, roleLabel: "Agent" });
  });

  it("refuses a made-up link", async () => {
    const preview = await client().send("post", "/v1/accounts/invitations/preview", { token: "x".repeat(43) });
    expect(preview.status).toBe(410);
  });

  it("needs a name, a good password and the terms", async () => {
    const refused = await accept(client(), { token: invitation.token, password: "short" });
    expect(refused.status).toBe(422);
    expect(Object.keys(refused.body.error.fields ?? refused.body.error.details?.fields ?? {})).toEqual(
      expect.arrayContaining(["lastName", "password", "agreements"])
    );
    expect(await queryOne("SELECT id FROM users WHERE email_normalized = ?", [invitation.email])).toBeFalsy();
  });

  it("creates a confirmed login on the company, with a public agent profile", async () => {
    const accepted = await accept(person, { ...newcomer, token: invitation.token, phone: `+9715${String(suffix).slice(-8)}` });
    expect(accepted.status, JSON.stringify(accepted.body)).toBe(201);
    person.csrfToken = accepted.body.data.csrfToken;
    const current = await session(person);
    expect(current.account).toMatchObject({ memberType: "organization", accountType: "organization" });
    expect(current.user.email).toBe(invitation.email);
    const user = await queryOne("SELECT id, email_verified_at, default_account_id FROM users WHERE email_normalized = ?", [invitation.email]);
    expect(user.email_verified_at).toBeTruthy();
    expect(Number(user.default_account_id)).toBe(Number(accountId));
    const agent = await queryOne("SELECT slug, title, organization_id, phone FROM agents WHERE user_id = ?", [user.id]);
    expect(Number(agent.organization_id)).toBe(Number(organizationId));
    expect(agent).toMatchObject({ title: "Sales Advisor" });
    expect(agent.phone).toMatch(/^\+971/);
    expect((await client().send("get", `/v1/public/agents/${agent.slug}`)).status).toBe(200);
    const list = (await owner.send("get", "/v1/portal/organization/invitations")).body.data;
    expect(list.find((row) => row.id === invitation.id).status).toBe("accepted");
  });

  it("does not work twice", async () => {
    expect((await accept(client(), { ...newcomer, token: invitation.token })).status).toBe(410);
  });

  it("signs in later and lands on the company", async () => {
    const again = client();
    expect((await again.login(invitation.email, newPassword)).status).toBe(200);
    expect((await session(again)).account.memberType).toBe("organization");
  });

  it("works listings and leads, but not the team or the organization", async () => {
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
    expect((await person.send("get", "/v1/portal/leads")).status).toBe(200);
    expect((await person.send("post", "/v1/portal/organization/invitations", { email: address("nope"), role: "agent" })).status).toBe(403);
    expect((await person.send("post", "/v1/portal/organization/agents", { firstName: "No", lastName: "Way" })).status).toBe(403);
    expect((await person.send("patch", "/v1/portal/organization", { tagline: "Not mine" })).status).toBe(403);
  });

  it("files a listing under the company and the agent", async () => {
    const community = await queryOne("SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1");
    const created = await person.send("post", "/v1/portal/listings", {
      category: "real-estate", categorySlug: "villas", purpose: "sale", title: `Invited Villa ${suffix}`, description: "Created by the invited agent in the team test suite, long enough to pass.",
      price: 9500000, currency: "AED", locationId: `community:${community.id}`, detail: { bedrooms: 4, bathrooms: 5, builtAreaSqft: 5400 },
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    listings.push(created.body.data.id);
    const row = await queryOne(
      `SELECT l.organization_id, l.account_id, a.user_id FROM listings l LEFT JOIN agents a ON a.id = l.agent_id WHERE l.public_id = ?`,
      [created.body.data.id]
    );
    expect(Number(row.organization_id)).toBe(Number(organizationId));
    expect(Number(row.account_id)).toBe(Number(accountId));
    expect(row.user_id).toBeTruthy();
  });

  it("stops acting for the company when taken off the team, and comes back", async () => {
    const list = (await owner.send("get", "/v1/portal/organization/agents")).body.data;
    const agent = list.find((row) => row.email === invitation.email);
    expect((await owner.send("patch", `/v1/portal/organization/agents/${agent.id}`, { status: "suspended" })).status).toBe(200);
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(403);
    expect((await owner.send("patch", `/v1/portal/organization/agents/${agent.id}`, { status: "active" })).status).toBe(200);
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
  });
});

describe("Managing an invitation", () => {
  it("replaces the link on resend", async () => {
    const { id, token } = await invite("resend");
    clearSentMessages();
    const resent = await owner.send("post", `/v1/portal/organization/invitations/${id}/resend`);
    expect(resent.status).toBe(200);
    const fresh = decodeURIComponent(sentMessages().at(-1).text.match(/token=([^\s]+)/)[1]);
    expect(fresh).not.toBe(token);
    expect((await client().send("post", "/v1/accounts/invitations/preview", { token })).status).toBe(410);
    expect((await client().send("post", "/v1/accounts/invitations/preview", { token: fresh })).status).toBe(200);
  });

  it("stops a cancelled link", async () => {
    const { id, token } = await invite("revoke");
    expect((await owner.send("delete", `/v1/portal/organization/invitations/${id}`)).status).toBe(200);
    expect((await accept(client(), { ...newcomer, token })).status).toBe(410);
  });

  it("stops an expired link, and shows it as expired", async () => {
    const { id, token } = await invite("expired");
    await execute("UPDATE team_invitations SET expires_at = '2020-01-01' WHERE public_id = ?", [id]);
    expect((await client().send("post", "/v1/accounts/invitations/preview", { token })).status).toBe(410);
    const list = (await owner.send("get", "/v1/portal/organization/invitations")).body.data;
    expect(list.find((row) => row.id === id).status).toBe("expired");
  });

  it("gives another company's manager nothing", async () => {
    const { id } = await invite("foreign");
    const other = await createDisposablePortalOwner({ prefix: "company-agents-other" });
    emails.push(other.email);
    const stranger = client();
    await stranger.login(other.email, PASSWORD);
    expect((await stranger.send("delete", `/v1/portal/organization/invitations/${id}`)).status).not.toBe(200);
    await owner.send("delete", `/v1/portal/organization/invitations/${id}`);
  });

  it("gives a named profile its login", async () => {
    const { token } = await invite("profile-link", { agentId: handMadeAgent.id, firstName: "Nadia", lastName: "Rahman" });
    const person = client();
    expect((await accept(person, { password: newPassword, agreements: true, token })).status).toBe(201);
    const row = await queryOne("SELECT user_id FROM agents WHERE public_id = ?", [handMadeAgent.id]);
    expect(row.user_id).toBeTruthy();
    const count = await query("SELECT id FROM agents WHERE user_id = ?", [row.user_id]);
    expect(count).toHaveLength(1);
  });

  it("makes a viewer read-only, with no public profile", async () => {
    const { email, token } = await invite("viewer", { role: "viewer", firstName: "Vera", lastName: "Viewer" });
    const person = client();
    expect((await accept(person, { password: newPassword, agreements: true, token })).status).toBe(201);
    const user = await queryOne("SELECT id FROM users WHERE email_normalized = ?", [email]);
    expect(await queryOne("SELECT id FROM agents WHERE user_id = ?", [user.id])).toBeFalsy();
  });
});

describe("Inviting someone who already has a login", () => {
  const member = async (name) => {
    const email = address(name);
    emails.push(email);
    const person = client();
    const response = await person.send("post", "/v1/accounts/member/signup", { name: "Mia Member", email, password: newPassword, agreements: true });
    expect(response.status).toBe(201);
    person.csrfToken = response.body.data.csrfToken;
    return { person, email };
  };

  it("asks them to sign in, and only that login may accept", async () => {
    const { person, email } = await member("existing");
    clearSentMessages();
    const response = await owner.send("post", "/v1/portal/organization/invitations", { email, role: "manager" });
    expect(response.status).toBe(201);
    const token = decodeURIComponent(sentMessages().at(-1).text.match(/token=([^\s]+)/)[1]);
    expect((await client().send("post", "/v1/accounts/invitations/preview", { token })).body.data.hasAccount).toBe(true);
    expect((await accept(client(), { token })).status).toBe(401);
    const { person: wrong } = await member("wrong-login");
    expect((await accept(wrong, { token })).status).toBe(403);

    expect((await accept(person, { token })).status, "accepted").toBe(200);
    const current = await session(person);
    expect(current.account.memberType).toBe("organization");
    expect((await person.send("get", "/v1/portal/organization/invitations")).status).toBe(200);
    expect((await person.send("get", "/v1/portal/my-enquiries")).status).toBe(200);
  });

  it("keeps a seller's own business separate", async () => {
    const seller = await createDisposablePortalOwner({ prefix: "company-agents-seller" });
    emails.push(seller.email);
    clearSentMessages();
    await owner.send("post", "/v1/portal/organization/invitations", { email: seller.email, role: "agent" });
    const token = decodeURIComponent(sentMessages().at(-1).text.match(/token=([^\s]+)/)[1]);
    expect((await client().send("post", "/v1/accounts/invitations/preview", { token })).body.data.isSeller).toBe(true);
    const person = client();
    await person.login(seller.email, PASSWORD);
    expect((await accept(person, { token })).status).toBe(409);
  });
});

describe("Team seats", () => {
  it("refuses an invitation past the plan's seats", async () => {
    const plan = await queryOne("SELECT id FROM plans ORDER BY id LIMIT 1");
    const before = await queryOne("SELECT agent_seat_quota FROM plans WHERE id = ?", [plan.id]);
    const subscription = await execute(
      `INSERT INTO subscriptions (public_id, account_id, plan_id, status, billing_interval, amount, currency_code, created_at)
       VALUES (?, ?, ?, 'active', 'monthly', 0, 'AED', NOW(3))`,
      [`seat${suffix}`, accountId, plan.id]
    );
    await execute("UPDATE plans SET agent_seat_quota = 1 WHERE id = ?", [plan.id]);
    try {
      const refused = await owner.send("post", "/v1/portal/organization/invitations", { email: address("seat"), role: "agent" });
      expect(refused.status).toBe(409);
    } finally {
      await execute("UPDATE plans SET agent_seat_quota = ? WHERE id = ?", [before.agent_seat_quota, plan.id]);
      await execute("DELETE FROM subscriptions WHERE id = ?", [subscription.insertId]);
    }
  });
});
