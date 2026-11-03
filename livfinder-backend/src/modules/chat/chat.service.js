import { execute, inClause, query, queryOne, queryValue } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import logger from "../../config/logger.js";
import { canReplySupport, canViewSupport, refFor, teamAccountIds } from "./identity.js";
import { emitTo } from "../../realtime/realtime.js";
import * as presence from "../../realtime/presence.js";
import { attachmentDto, claimPendingAttachments } from "./attachments.js";
import { notifyOfflineRecipients } from "./chatNotifications.js";

/**
 * Live chat on conversations / conversation_participants / messages (0008, extended by 0073).
 *
 *   enquiry  a visitor and the seller of a listing, development, agent or company. Everyone on
 *            the seller's account who works leads joins the thread, so a team shares one inbox.
 *   support  a visitor or a client and LivFinder staff. Staff who may view the support inbox see
 *            every support thread; replying joins them to it.
 *
 * Access is always decided here from the participant rows, never from what the client asks for:
 * the socket layer only relays events this service emits.
 *
 * Message bodies are plain text. The frontends render them as text nodes, never as HTML.
 */

const PAGE_SIZE = 50;
const MAX_BODY = 5000;
const SIDE_BY_ROLE = { buyer: "visitor", seller: "seller", agent: "seller", admin: "staff", observer: "staff" };

/* ---------------------------------------------------------------------------------------------
 * Loading
 * ------------------------------------------------------------------------------------------- */

const CONVERSATION_COLUMNS = `c.id, c.public_id, c.kind, c.subject, c.status, c.listing_id, c.project_id, c.agent_id,
  c.inquiry_id, c.organization_id, c.account_id, c.created_by_user_id, c.created_by_guest_id, c.assigned_user_id,
  c.closed_at, c.blocked_by_user_id, c.blocked_at, c.last_message_at, c.last_message_preview,
  c.last_message_by_user_id, c.message_count, c.created_at`;

async function loadConversation(publicId, executor) {
  const row = await queryOne(`SELECT ${CONVERSATION_COLUMNS} FROM conversations c WHERE c.public_id = ? LIMIT 1`, [String(publicId)], executor);
  if (!row) throw AppError.notFound("That conversation was not found.");
  return row;
}

async function participantsOf(conversationIds, executor) {
  const ids = inClause(conversationIds);
  if (!ids) return [];
  return query(
    `SELECT cp.id, cp.conversation_id, cp.user_id, cp.guest_id, cp.role, cp.unread_count, cp.last_read_at,
            cp.last_delivered_at, cp.is_muted, cp.left_at,
            u.public_id AS user_public_id, u.display_name, u.first_name, u.last_name, u.avatar_url, u.email AS user_email,
            u.phone_e164 AS user_phone, u.last_seen_at,
            g.public_id AS guest_public_id, g.name AS guest_name, g.email AS guest_email, g.phone AS guest_phone,
            g.last_seen_at AS guest_last_seen_at
       FROM conversation_participants cp
       LEFT JOIN users u ON u.id = cp.user_id
       LEFT JOIN chat_guests g ON g.id = cp.guest_id
      WHERE cp.conversation_id IN ${ids.sql}`,
    ids.params,
    executor
  );
}

const participantRef = (row) =>
  row.user_public_id ? `u:${row.user_public_id}` : row.guest_public_id ? `g:${row.guest_public_id}` : null;

function isMine(row, identity) {
  if (identity.type === "user") return row.user_id !== null && String(row.user_id) === String(identity.userId);
  return row.guest_id !== null && String(row.guest_id) === String(identity.guestId);
}

function teamScope(identity) {
  if (identity.type !== "user") return { accountIds: [], organizationIds: [] };
  const accountIds = teamAccountIds(identity);
  const organizationIds = identity.memberships
    .filter((membership) => accountIds.some((id) => String(id) === String(membership.account_id)) && membership.organization_id)
    .map((membership) => membership.organization_id);
  return { accountIds, organizationIds };
}

/**
 * How `identity` may reach this conversation: as a participant, as a member of the seller's team,
 * or as support staff. Anything else is a 404, so a guessed id reveals nothing.
 */
function accessFor(identity, conversation, participants, { write = false } = {}) {
  const mine = participants.find((row) => row.conversation_id === conversation.id && isMine(row, identity) && !row.left_at)
    || participants.find((row) => row.conversation_id === conversation.id && isMine(row, identity));
  if (mine) return { participant: mine, joinAs: null };
  if (identity.type === "user") {
    if (conversation.kind === "enquiry") {
      const { accountIds, organizationIds } = teamScope(identity);
      const onTeam =
        (conversation.account_id && accountIds.some((id) => String(id) === String(conversation.account_id))) ||
        (conversation.organization_id && organizationIds.some((id) => String(id) === String(conversation.organization_id)));
      if (onTeam) return { participant: null, joinAs: "seller" };
    }
    if (conversation.kind === "support" && (write ? canReplySupport(identity) : canViewSupport(identity))) {
      return { participant: null, joinAs: "admin" };
    }
  }
  throw AppError.notFound("That conversation was not found.");
}

async function join(identity, conversation, role, executor) {
  if (identity.type === "user") {
    await execute(
      `INSERT INTO conversation_participants (conversation_id, user_id, role, unread_count, last_read_at, last_delivered_at, joined_at)
       VALUES (?, ?, ?, 0, NOW(3), NOW(3), NOW(3))
       ON DUPLICATE KEY UPDATE left_at = NULL`,
      [conversation.id, identity.userId, role],
      executor
    );
  } else {
    await execute(
      `INSERT INTO conversation_participants (conversation_id, guest_id, role, unread_count, last_read_at, last_delivered_at, joined_at)
       VALUES (?, ?, ?, 0, NOW(3), NOW(3), NOW(3))
       ON DUPLICATE KEY UPDATE left_at = NULL`,
      [conversation.id, identity.guestId, role],
      executor
    );
  }
}

/* ---------------------------------------------------------------------------------------------
 * What a conversation is about
 * ------------------------------------------------------------------------------------------- */

async function contextsFor(conversations) {
  const byKey = new Map();
  const listingIds = inClause(conversations.map((row) => row.listing_id));
  const projectIds = inClause(conversations.map((row) => row.project_id));
  const agentIds = inClause(conversations.map((row) => row.agent_id));
  const organizationIds = inClause(conversations.map((row) => row.organization_id));
  const [listings, projects, agents, organizations] = await Promise.all([
    listingIds
      ? query(
          `SELECT id, public_id, reference, title, canonical_path, cover_image_url, price, currency_code, is_price_hidden, status
             FROM listings WHERE id IN ${listingIds.sql}`,
          listingIds.params
        )
      : [],
    projectIds
      ? query(
          `SELECT p.id, p.public_id, p.name, ps.canonical_path, ps.cover_image_url
             FROM projects p LEFT JOIN project_search ps ON ps.project_id = p.id
            WHERE p.id IN ${projectIds.sql}`,
          projectIds.params
        )
      : [],
    agentIds
      ? query(`SELECT id, public_id, display_name, slug, photo_url, title FROM agents WHERE id IN ${agentIds.sql}`, agentIds.params)
      : [],
    organizationIds
      ? query(`SELECT id, public_id, name, slug, logo_url FROM organizations WHERE id IN ${organizationIds.sql}`, organizationIds.params)
      : [],
  ]);
  for (const row of listings) byKey.set(`l:${row.id}`, row);
  for (const row of projects) byKey.set(`p:${row.id}`, row);
  for (const row of agents) byKey.set(`a:${row.id}`, row);
  for (const row of organizations) byKey.set(`o:${row.id}`, row);
  return byKey;
}

function contextDto(conversation, contexts) {
  const organization = contexts.get(`o:${conversation.organization_id}`);
  const agent = contexts.get(`a:${conversation.agent_id}`);
  const seller = agent
    ? { name: agent.display_name, avatar: agent.photo_url, url: agent.slug ? `/agents/${agent.slug}` : null }
    : organization
      ? { name: organization.name, avatar: organization.logo_url, url: organization.slug ? `/companies/${organization.slug}` : null }
      : null;
  const listing = contexts.get(`l:${conversation.listing_id}`);
  if (listing) {
    return {
      type: "listing",
      id: listing.public_id,
      title: listing.title,
      reference: listing.reference,
      url: listing.canonical_path,
      image: listing.cover_image_url,
      price: listing.is_price_hidden || listing.price === null ? null : { amount: Number(listing.price), currency: listing.currency_code },
      seller,
    };
  }
  const project = contexts.get(`p:${conversation.project_id}`);
  if (project) {
    return { type: "project", id: project.public_id, title: project.name, url: project.canonical_path, image: project.cover_image_url, seller };
  }
  if (agent) return { type: "agent", id: agent.public_id, title: agent.display_name, url: seller.url, image: agent.photo_url, seller };
  if (organization) {
    return { type: "organization", id: organization.public_id, title: organization.name, url: seller.url, image: organization.logo_url, seller };
  }
  return null;
}

/* ---------------------------------------------------------------------------------------------
 * DTOs
 * ------------------------------------------------------------------------------------------- */

const iso = (value) => (value ? new Date(value).toISOString() : null);

function participantName(row) {
  if (row.user_public_id) {
    return row.display_name || [row.first_name, row.last_name].filter(Boolean).join(" ") || "LivFinder member";
  }
  return row.guest_name || "Visitor";
}

function participantDto(row, identity, presenceMap, { showContact }) {
  const ref = participantRef(row);
  const live = presenceMap[ref] || {};
  const side = SIDE_BY_ROLE[row.role] || "visitor";
  return {
    ref,
    name: participantName(row),
    avatar: row.avatar_url || null,
    role: row.role,
    side,
    isMe: isMine(row, identity),
    isGuest: !row.user_public_id,
    active: !row.left_at,
    lastReadAt: iso(row.last_read_at),
    lastDeliveredAt: iso(row.last_delivered_at),
    online: Boolean(live.online),
    lastSeenAt: live.online ? null : live.lastSeenAt || iso(row.last_seen_at || row.guest_last_seen_at),
    // The seller sees how to reach the visitor, as they already do for a form enquiry; nobody
    // else's contact details are handed out.
    contact:
      showContact && side === "visitor"
        ? { email: row.user_email || row.guest_email || null, phone: row.user_phone || row.guest_phone || null }
        : undefined,
  };
}

function conversationDto(conversation, participants, identity, contexts, presenceMap) {
  const rows = participants.filter((row) => row.conversation_id === conversation.id);
  const mineRow = rows.find((row) => isMine(row, identity));
  const mySide = mineRow ? SIDE_BY_ROLE[mineRow.role] : conversation.kind === "support" ? "staff" : "seller";
  const people = rows.map((row) =>
    participantDto(row, identity, presenceMap, { showContact: mySide === "seller" || mySide === "staff" })
  );
  const others = people.filter((person) => !person.isMe);
  // A support chat is filed under the client's company for staff; the client just sees Support.
  const context = conversation.kind === "support" && mySide !== "staff" ? null : contextDto(conversation, contexts);

  // What the inbox row is called depends on who is looking.
  let title;
  let avatar = null;
  if (conversation.kind === "support" && mySide !== "staff") {
    title = "LivFinder Support";
  } else if (mySide === "visitor" && context?.seller) {
    title = context.seller.name;
    avatar = context.seller.avatar;
  } else {
    const counterpart = others.filter((person) => person.side === "visitor");
    const named = (counterpart.length ? counterpart : others.filter((person) => person.active)).map((person) => person.name);
    title = named.join(", ") || conversation.subject || "Conversation";
    avatar = (counterpart[0] || others[0])?.avatar || null;
  }

  return {
    id: conversation.public_id,
    kind: conversation.kind,
    status: conversation.status,
    subject: conversation.subject,
    title,
    avatar,
    mySide,
    context,
    participants: people,
    lastMessageAt: iso(conversation.last_message_at || conversation.created_at),
    lastMessagePreview: conversation.last_message_preview,
    messageCount: Number(conversation.message_count || 0),
    unreadCount: Number(mineRow?.unread_count || 0),
    muted: Boolean(mineRow?.is_muted),
    archived: Boolean(mineRow?.left_at),
    joined: Boolean(mineRow),
    assignedTo: conversation.assigned_user_id
      ? people.find((person) => person.side === "staff" && rows.some((row) => participantRef(row) === person.ref && String(row.user_id) === String(conversation.assigned_user_id)))?.name ?? "Staff"
      : null,
    assignedToMe: identity.type === "user" && String(conversation.assigned_user_id) === String(identity.userId),
    blocked: conversation.status === "blocked",
    blockedByMe: conversation.status === "blocked" && identity.type === "user" && String(conversation.blocked_by_user_id) === String(identity.userId),
    closedAt: iso(conversation.closed_at),
    createdAt: iso(conversation.created_at),
  };
}

async function messagesFor(messageRows) {
  const ids = inClause(messageRows.map((row) => row.id));
  const attachments = ids
    ? await query(
        `SELECT id, public_id, message_id, file_name, file_url, mime_type, file_size_bytes, width, height, storage_key, preview_key, scan_status
           FROM message_attachments WHERE message_id IN ${ids.sql} ORDER BY id`,
        ids.params
      )
    : [];
  return messageRows.map((row) => messageDto(row, attachments.filter((attachment) => attachment.message_id === row.id)));
}

function messageDto(row, attachments = []) {
  const sender =
    row.sender_type === "system" || row.sender_type === "bot"
      ? { ref: "system", name: "LivFinder", side: "system" }
      : row.sender_user_public_id
        ? { ref: `u:${row.sender_user_public_id}`, name: row.sender_name || "LivFinder member", avatar: row.sender_avatar || null }
        : row.sender_guest_public_id
          ? { ref: `g:${row.sender_guest_public_id}`, name: row.sender_guest_name || "Visitor", avatar: null }
          : { ref: "unknown", name: "Former member" };
  return {
    id: row.public_id,
    conversationId: row.conversation_public_id,
    body: row.deleted_at ? "" : row.body,
    deleted: Boolean(row.deleted_at),
    sender,
    channel: row.channel,
    clientRef: row.client_ref || null,
    createdAt: iso(row.created_at),
    attachments: row.deleted_at ? [] : attachments.map(attachmentDto),
  };
}

const MESSAGE_SELECT = `SELECT m.id, m.public_id, m.conversation_id, m.body, m.sender_type, m.channel, m.client_ref,
       m.created_at, m.deleted_at, c.public_id AS conversation_public_id,
       su.public_id AS sender_user_public_id, su.display_name AS sender_name, su.avatar_url AS sender_avatar,
       sg.public_id AS sender_guest_public_id, sg.name AS sender_guest_name
  FROM messages m
  JOIN conversations c ON c.id = m.conversation_id
  LEFT JOIN users su ON su.id = m.sender_user_id
  LEFT JOIN chat_guests sg ON sg.id = m.sender_guest_id`;

async function presenceFor(participants) {
  try {
    return await presence.lookup(participants.map(participantRef));
  } catch {
    return {};
  }
}

/* ---------------------------------------------------------------------------------------------
 * Inbox
 * ------------------------------------------------------------------------------------------- */

/**
 * The conversations `identity` is in, newest first.
 *   scope "mine"    their own threads, plus their team's enquiries
 *   scope "support" the staff support inbox (needs supportChat.view)
 */
export async function listConversations(identity, { scope = "mine", kind = null, filter = "all", search = "", before = null, limit = 30 } = {}) {
  const conditions = [];
  const params = [];

  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;

  if (scope === "support") {
    if (!canViewSupport(identity)) throw AppError.forbidden();
    conditions.push("c.kind = 'support'", "c.message_count > 0");
    if (filter === "open") conditions.push("c.status = 'open'");
    if (filter === "closed") conditions.push("c.status IN ('closed','archived')");
    if (filter === "mine") conditions.push("c.assigned_user_id = ?"), params.push(identity.userId);
    if (filter === "unassigned") conditions.push("c.assigned_user_id IS NULL AND c.status = 'open'");
  } else {
    const access = [`EXISTS (SELECT 1 FROM conversation_participants me WHERE me.conversation_id = c.id AND me.${meColumn} = ?)`];
    params.push(meId);
    const { accountIds, organizationIds } = teamScope(identity);
    const accounts = inClause(accountIds);
    const organizations = inClause(organizationIds);
    if (accounts) {
      access.push(`(c.kind = 'enquiry' AND c.account_id IN ${accounts.sql})`);
      params.push(...accounts.params);
    }
    if (organizations) {
      access.push(`(c.kind = 'enquiry' AND c.account_id IS NULL AND c.organization_id IN ${organizations.sql})`);
      params.push(...organizations.params);
    }
    conditions.push(`(${access.join(" OR ")})`);
    // A chat opened but never written in is not listed for anyone, its opener included: leaving
    // without writing leaves nothing behind (owner decision, 2026-11-03).
    conditions.push("c.message_count > 0");
    if (kind) conditions.push("c.kind = ?"), params.push(kind);
    if (filter === "unread") conditions.push(`mine.unread_count > 0`);
    if (filter === "archived") conditions.push("mine.left_at IS NOT NULL");
    else conditions.push("(mine.id IS NULL OR mine.left_at IS NULL)");
  }
  if (search) {
    const like = `%${String(search).replace(/[%_\\]/g, "\\$&").slice(0, 80)}%`;
    conditions.push(
      `(c.subject LIKE ? OR c.last_message_preview LIKE ?
        OR EXISTS (SELECT 1 FROM conversation_participants sp
                     LEFT JOIN users su ON su.id = sp.user_id
                     LEFT JOIN chat_guests sg ON sg.id = sp.guest_id
                    WHERE sp.conversation_id = c.id
                      AND (su.display_name LIKE ? OR su.email LIKE ? OR sg.name LIKE ? OR sg.email LIKE ?)))`
    );
    params.push(like, like, like, like, like, like);
  }
  if (before) conditions.push("COALESCE(c.last_message_at, c.created_at) < ?"), params.push(new Date(before));

  const size = Math.min(Math.max(Number(limit) || 30, 1), 100);
  const rows = await query(
    `SELECT ${CONVERSATION_COLUMNS}
       FROM conversations c
       LEFT JOIN conversation_participants mine ON mine.conversation_id = c.id AND mine.${meColumn} = ?
      WHERE ${conditions.join(" AND ")}
      ORDER BY COALESCE(c.last_message_at, c.created_at) DESC, c.id DESC
      LIMIT ${size + 1}`,
    [meId, ...params]
  );
  const page = rows.slice(0, size);
  const participants = await participantsOf(page.map((row) => row.id));
  const [contexts, presenceMap] = await Promise.all([contextsFor(page), presenceFor(participants)]);
  const conversations = page.map((row) => conversationDto(row, participants, identity, contexts, presenceMap));
  const unreadTotal =
    scope === "support"
      ? null
      : Number(
          (await queryValue(
            `SELECT COALESCE(SUM(unread_count), 0) FROM conversation_participants WHERE ${meColumn} = ? AND left_at IS NULL`,
            [meId]
          )) || 0
        );
  return {
    conversations,
    unreadTotal,
    nextBefore: rows.length > size ? conversations[conversations.length - 1]?.lastMessageAt : null,
  };
}

export async function unreadTotal(identity) {
  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  return Number(
    (await queryValue(
      `SELECT COALESCE(SUM(unread_count), 0) FROM conversation_participants WHERE ${meColumn} = ? AND left_at IS NULL`,
      [meId]
    )) || 0
  );
}

/** One conversation and a page of its messages (newest PAGE_SIZE, or those before `before`). */
export async function getConversation(identity, publicId, { before = null } = {}) {
  const conversation = await loadConversation(publicId);
  const participants = await participantsOf([conversation.id]);
  accessFor(identity, conversation, participants);

  const params = [conversation.id];
  let beforeSql = "";
  if (before) {
    const anchor = await queryOne("SELECT id, created_at FROM messages WHERE public_id = ? AND conversation_id = ?", [String(before), conversation.id]);
    if (anchor) {
      beforeSql = "AND (m.created_at < ? OR (m.created_at = ? AND m.id < ?))";
      params.push(anchor.created_at, anchor.created_at, anchor.id);
    }
  }
  const rows = await query(
    `${MESSAGE_SELECT}
      WHERE m.conversation_id = ? ${beforeSql}
      ORDER BY m.created_at DESC, m.id DESC
      LIMIT ${PAGE_SIZE + 1}`,
    params
  );
  const hasMore = rows.length > PAGE_SIZE;
  const messages = await messagesFor(rows.slice(0, PAGE_SIZE).reverse());
  const [contexts, presenceMap] = await Promise.all([contextsFor([conversation]), presenceFor(participants)]);
  return {
    conversation: conversationDto(conversation, participants, identity, contexts, presenceMap),
    messages,
    hasMore,
  };
}

/* ---------------------------------------------------------------------------------------------
 * Starting a conversation
 * ------------------------------------------------------------------------------------------- */

/** The seller behind what a visitor is asking about, and the people who answer for it. */
export async function resolveSellerContext({ listingId, projectId, agentId, organizationId }) {
  let context = null;
  if (listingId) {
    const listing = await queryOne(
      `SELECT l.id, l.public_id, l.reference, l.title, l.account_id, l.organization_id, l.agent_id, l.category_id,
              l.location_id, l.country_id, l.currency_code, l.contact_email
         FROM v_reachable_listings l
        WHERE l.public_id = ? OR l.reference = ? LIMIT 1`,
      [String(listingId), String(listingId)]
    );
    if (!listing) throw AppError.notFound("That listing is not available.");
    context = { kind: "listing", listing, accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id, label: listing.title };
  } else if (projectId) {
    const project = await queryOne(
      `SELECT ps.project_id AS id, ps.public_id, ps.name, ps.accepts_inquiries, ps.country_id, ps.currency_code,
              p.organization_id, p.category_id, p.location_id, o.account_id
         FROM project_search ps
         JOIN projects p ON p.id = ps.project_id
         LEFT JOIN organizations o ON o.id = p.organization_id
        WHERE ps.public_id = ? OR ps.slug = ? LIMIT 1`,
      [String(projectId), String(projectId)]
    );
    if (!project) throw AppError.notFound("That development is not available.");
    if (!project.accepts_inquiries) throw AppError.badRequest("This development is not accepting enquiries.");
    context = { kind: "project", project, accountId: project.account_id, organizationId: project.organization_id, agentId: null, label: project.name };
  } else if (agentId) {
    const agent = await queryOne(
      `SELECT a.id, a.public_id, a.display_name, a.user_id, a.organization_id, o.account_id
         FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id
        WHERE (a.public_id = ? OR a.slug = ?) AND a.deleted_at IS NULL AND a.status = 'active' AND a.is_publicly_visible = 1
        LIMIT 1`,
      [String(agentId), String(agentId)]
    );
    if (!agent) throw AppError.notFound("That agent is not available.");
    const accountId = agent.account_id ?? (await queryValue("SELECT account_id FROM account_members WHERE user_id = ? AND status = 'active' LIMIT 1", [agent.user_id ?? 0]));
    context = { kind: "agent", agent, accountId, organizationId: agent.organization_id, agentId: agent.id, label: agent.display_name };
  } else if (organizationId) {
    const organization = await queryOne(
      `SELECT id, public_id, name, account_id FROM organizations
        WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL AND is_publicly_visible = 1 LIMIT 1`,
      [String(organizationId), String(organizationId)]
    );
    if (!organization) throw AppError.notFound("That company is not available.");
    context = { kind: "organization", organization, accountId: organization.account_id, organizationId: organization.id, agentId: null, label: organization.name };
  } else {
    throw AppError.validation("Choose what the chat is about.");
  }

  // The named agent answers first; everyone on the account who works leads shares the thread.
  const agentUser = context.agentId ? await queryValue("SELECT user_id FROM agents WHERE id = ? AND deleted_at IS NULL", [context.agentId]) : null;
  const team = context.accountId
    ? await query(
        `SELECT DISTINCT user_id FROM v_account_permissions
          WHERE account_id = ? AND membership_status = 'active'
            AND (role IN ('owner','admin','manager') OR can_manage_leads = 1)
          LIMIT 25`,
        [context.accountId]
      )
    : [];
  const sellerUserIds = [...new Set([agentUser, ...team.map((row) => row.user_id)].filter(Boolean).map(String))];
  return { ...context, sellerUserIds, agentUserId: agentUser ? String(agentUser) : null };
}

const cleanBody = (body) =>
  String(body ?? "")
    // Control characters other than tab and newline have no place in a chat message.
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "")
    .replace(/\n{4,}/g, "\n\n\n")
    .trim()
    .slice(0, MAX_BODY);

/**
 * A visitor asking a seller something. An open thread with the same seller about the same thing is
 * reused, so pressing "Chat" twice does not split the conversation. A new listing or development
 * thread is also an enquiry (channel `chat`), so it reaches the seller's leads like a form enquiry.
 */
export async function startEnquiry(identity, input, req) {
  const context = await resolveSellerContext(input);
  if (identity.type === "user" && context.sellerUserIds.includes(String(identity.userId))) {
    throw AppError.badRequest("This is your own listing, so there is no one to chat with.");
  }
  if (!context.sellerUserIds.length) {
    throw AppError.badRequest("This seller cannot receive chat messages yet. Send an enquiry instead.");
  }
  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  const subjectColumn = { listing: "listing_id", project: "project_id", agent: "agent_id", organization: "organization_id" }[context.kind];
  const subjectId = { listing: context.listing?.id, project: context.project?.id, agent: context.agentId, organization: context.organizationId }[context.kind];

  const existing = await queryOne(
    `SELECT c.public_id FROM conversations c
       JOIN conversation_participants me ON me.conversation_id = c.id AND me.${meColumn} = ?
      WHERE c.kind = 'enquiry' AND c.${subjectColumn} = ? AND c.status IN ('open','closed')
        ${context.kind === "organization" ? "AND c.listing_id IS NULL AND c.project_id IS NULL AND c.agent_id IS NULL" : ""}
        ${context.kind === "agent" ? "AND c.listing_id IS NULL AND c.project_id IS NULL" : ""}
      ORDER BY c.id DESC LIMIT 1`,
    [meId, subjectId]
  );
  if (existing) {
    const message = input.message ? await sendMessage(identity, existing.public_id, input, req) : null;
    return { conversationId: existing.public_id, message, created: false };
  }

  const publicId = ulid();
  await withTransaction(async (connection) => {
    const result = await execute(
      `INSERT INTO conversations
         (public_id, kind, subject, listing_id, project_id, agent_id, inquiry_id, organization_id, account_id,
          created_by_user_id, created_by_guest_id, status, message_count, created_at)
       VALUES (?, 'enquiry', ?, ?, ?, ?, ?, ?, ?, ?, ?, 'open', 0, NOW(3))`,
      [
        publicId,
        String(context.label || "").slice(0, 255) || null,
        context.listing?.id ?? null,
        context.project?.id ?? null,
        context.agentId ?? null,
        null,
        context.organizationId ?? null,
        context.accountId ?? null,
        identity.type === "user" ? identity.userId : null,
        identity.type === "guest" ? identity.guestId : null,
      ],
      connection
    );
    await join(identity, { id: result.insertId }, "buyer", connection);
    for (const userId of context.sellerUserIds) {
      await execute(
        `INSERT IGNORE INTO conversation_participants (conversation_id, user_id, role, unread_count, joined_at)
         VALUES (?, ?, ?, 0, NOW(3))`,
        [result.insertId, userId, userId === context.agentUserId ? "agent" : "seller"],
        connection
      );
    }
  });

  // The enquiry (and lead) is created by the visitor's first message, not by opening the chat.
  const message = input.message ? await sendMessage(identity, publicId, input, req) : null;
  return { conversationId: publicId, message, created: true };
}

/** What createChatInquiry needs, rebuilt from a conversation that is about a listing or development. */
async function sellerContextOf(conversation, connection) {
  if (conversation.listing_id) {
    const listing = await queryOne(
      `SELECT id, public_id, reference, title, account_id, organization_id, agent_id, category_id, location_id, country_id, currency_code
         FROM listings WHERE id = ?`,
      [conversation.listing_id],
      connection
    );
    return listing ? { kind: "listing", listing, accountId: listing.account_id, organizationId: listing.organization_id } : null;
  }
  const project = await queryOne(
    `SELECT p.id, p.public_id, p.name, p.organization_id, p.category_id, p.location_id, ps.country_id, ps.currency_code, o.account_id
       FROM projects p LEFT JOIN project_search ps ON ps.project_id = p.id LEFT JOIN organizations o ON o.id = p.organization_id
      WHERE p.id = ?`,
    [conversation.project_id],
    connection
  );
  return project ? { kind: "project", project, accountId: project.account_id, organizationId: project.organization_id } : null;
}

/**
 * The enquiry row behind a new chat about a listing or development: the seller's inquiries and
 * leads see a chat exactly as they see a form enquiry, with `channel = 'chat'`.
 */
async function createChatInquiry(identity, context, input, req, connection) {
  const { linkInquiryToLead, listingLeadSubject, projectLeadSubject } = await import("../leads/leadCapture.service.js");
  const listing = context.listing;
  const project = context.project;
  const maxRef = await queryValue(
    "SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) FROM inquiries WHERE reference LIKE 'IQ-%'",
    [],
    connection
  );
  const reference = `IQ-${Number(maxRef || 10000) + 1}`;
  const name = identity.name;
  const email = identity.email;
  const phone = identity.type === "guest" ? identity.phone : null;
  const message = cleanBody(input.message);
  const result = await execute(
    `INSERT INTO inquiries
       (public_id, reference, listing_id, project_id, account_id, organization_id, agent_id, category_id,
        location_id, country_id, user_id, name, email, phone, channel, inquiry_type, message, status, priority,
        currency_code, source_url, user_agent, spam_score, is_spam, last_activity_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'chat', 'general', ?, 'new', 'normal', ?, ?, ?, 0, 0, NOW(3), NOW(3))`,
    [
      ulid(),
      reference,
      listing?.id ?? null,
      project?.id ?? null,
      context.accountId ?? null,
      context.organizationId ?? null,
      listing?.agent_id ?? null,
      listing?.category_id ?? project?.category_id ?? null,
      listing?.location_id ?? project?.location_id ?? null,
      listing?.country_id ?? project?.country_id ?? null,
      identity.type === "user" ? identity.userId : null,
      String(name || "Visitor").slice(0, 160),
      email,
      phone,
      message,
      listing?.currency_code ?? project?.currency_code ?? null,
      input.sourceUrl ? String(input.sourceUrl).slice(0, 700) : null,
      (req?.get?.("user-agent") || "").slice(0, 500) || null,
    ],
    connection
  );
  if (listing) {
    await execute("UPDATE listings SET inquiry_count = inquiry_count + 1, updated_at = updated_at WHERE id = ?", [listing.id], connection);
  }
  const subject = listing ? listingLeadSubject(listing) : project ? projectLeadSubject(project) : null;
  if (subject) {
    const leadId = await linkInquiryToLead(
      { subject, inquiry: { name, email, phone, message, inquiryType: "general" } },
      connection
    );
    if (leadId) await execute("UPDATE inquiries SET lead_id = ? WHERE id = ?", [leadId, result.insertId], connection);
  }
  return result.insertId;
}

/** The side effects a form enquiry has, for one started in chat. Never fails the chat. */
async function afterChatInquiry(conversationId) {
  const row = await queryOne(
    `SELECT i.id, i.reference, i.name, i.message, i.listing_id, l.category_id, l.title, l.account_id, l.organization_id, l.agent_id, l.reference AS listing_reference
       FROM conversations c JOIN inquiries i ON i.id = c.inquiry_id LEFT JOIN listings l ON l.id = i.listing_id
      WHERE c.id = ?`,
    [conversationId]
  );
  if (!row) return;
  try {
    const { emitLeadEvent } = await import("../leads/webhooks.service.js");
    await emitLeadEvent("inquiry", row.id, "lead.created");
  } catch (error) {
    logger.warn({ err: error }, "chat enquiry webhook failed");
  }
  if (row.listing_id) {
    await execute(
      `INSERT INTO listing_daily_stats
         (listing_id, stat_date, impressions, views, unique_views, inquiries, favourites, organization_id, agent_id, category_id, computed_at)
       VALUES (?, CURDATE(), 0, 0, 0, 1, 0, ?, ?, ?, NOW(3))
       ON DUPLICATE KEY UPDATE inquiries = inquiries + 1, computed_at = NOW(3)`,
      [row.listing_id, row.organization_id, row.agent_id, row.category_id]
    ).catch(() => {});
  }
}

/** A visitor or a client asking LivFinder. One open support thread per person. */
export async function startSupport(identity, input, req) {
  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  const existing = await queryOne(
    `SELECT c.public_id FROM conversations c
       JOIN conversation_participants me ON me.conversation_id = c.id AND me.${meColumn} = ? AND me.role IN ('buyer','seller')
      WHERE c.kind = 'support' AND c.status IN ('open','closed')
      ORDER BY c.id DESC LIMIT 1`,
    [meId]
  );
  if (existing) {
    const message = input.message ? await sendMessage(identity, existing.public_id, input, req) : null;
    return { conversationId: existing.public_id, message, created: false };
  }
  const publicId = ulid();
  // A client asking about their account files the thread under it, so staff see whose it is.
  const membership = identity.type === "user" ? identity.memberships.find((row) => row.role === "owner") || identity.memberships[0] : null;
  const isClient = membership && !["personal"].includes(membership.account_type_code);
  await withTransaction(async (connection) => {
    const result = await execute(
      `INSERT INTO conversations
         (public_id, kind, subject, organization_id, account_id, created_by_user_id, created_by_guest_id, status, message_count, created_at)
       VALUES (?, 'support', ?, ?, ?, ?, ?, 'open', 0, NOW(3))`,
      [
        publicId,
        input.topic ? String(input.topic).slice(0, 255) : null,
        isClient ? membership.organization_id ?? null : null,
        isClient ? membership.account_id : null,
        identity.type === "user" ? identity.userId : null,
        identity.type === "guest" ? identity.guestId : null,
      ],
      connection
    );
    await join(identity, { id: result.insertId }, isClient ? "seller" : "buyer", connection);
  });
  const message = input.message ? await sendMessage(identity, publicId, input, req) : null;
  return { conversationId: publicId, message, created: true };
}

async function notifyStaffOfSupport(conversationId, identity, topic) {
  const { notifyStaff } = await import("../system/notifications.service.js");
  await notifyStaff("supportChat.view", {
    type: "support.chat_started",
    title: `New support chat from ${identity.name}`,
    body: topic ? String(topic).slice(0, 240) : null,
    actionUrl: "/admin/support-chats",
    icon: "message",
    subjectType: "conversation",
    subjectId: conversationId,
  });
}

/** Staff opening a support thread with a company (every lead-working member joins it). */
export async function startSupportWithAccount(staff, { accountId, message, topic }, req) {
  if (!canReplySupport(staff)) throw AppError.forbidden();
  const account = await queryOne(
    `SELECT a.id, o.id AS organization_id FROM accounts a LEFT JOIN organizations o ON o.account_id = a.id
      WHERE a.public_id = ? OR a.id = ? LIMIT 1`,
    [String(accountId), Number(accountId) || 0]
  );
  if (!account) throw AppError.notFound("That account was not found.");
  const members = await query(
    `SELECT DISTINCT user_id FROM v_account_permissions
      WHERE account_id = ? AND membership_status = 'active' AND (role IN ('owner','admin','manager') OR can_manage_leads = 1)
      LIMIT 25`,
    [account.id]
  );
  if (!members.length) throw AppError.badRequest("That account has no one who can receive messages.");
  const publicId = ulid();
  await withTransaction(async (connection) => {
    const result = await execute(
      `INSERT INTO conversations
         (public_id, kind, subject, organization_id, account_id, created_by_user_id, assigned_user_id, status, message_count, created_at)
       VALUES (?, 'support', ?, ?, ?, ?, ?, 'open', 0, NOW(3))`,
      [publicId, topic ? String(topic).slice(0, 255) : null, account.organization_id, account.id, staff.userId, staff.userId],
      connection
    );
    await join(staff, { id: result.insertId }, "admin", connection);
    for (const member of members) {
      await execute(
        "INSERT IGNORE INTO conversation_participants (conversation_id, user_id, role, unread_count, joined_at) VALUES (?, ?, 'seller', 0, NOW(3))",
        [result.insertId, member.user_id],
        connection
      );
    }
  });
  const sent = await sendMessage(staff, publicId, { message }, req);
  return { conversationId: publicId, message: sent, created: true };
}

/* ---------------------------------------------------------------------------------------------
 * Messages
 * ------------------------------------------------------------------------------------------- */

export async function sendMessage(identity, conversationPublicId, { message, attachmentIds = [], clientRef = null }, req) {
  const body = cleanBody(message);
  if (!body && !attachmentIds.length) throw AppError.validation("Write a message.", { message: "Write a message." });

  const conversation = await loadConversation(conversationPublicId);
  let participants = await participantsOf([conversation.id]);
  const { participant, joinAs } = accessFor(identity, conversation, participants, { write: true });

  if (conversation.status === "blocked") throw AppError.forbidden("This chat has been blocked, so new messages cannot be sent.");
  if (participant?.role === "observer") throw AppError.forbidden("You can read this chat but not reply.");

  if (clientRef) {
    const repeat = await queryOne(`${MESSAGE_SELECT} WHERE m.conversation_id = ? AND m.client_ref = ? LIMIT 1`, [conversation.id, String(clientRef)]);
    if (repeat) return (await messagesFor([repeat]))[0];
  }

  const firstEnquiryMessage =
    conversation.kind === "enquiry" &&
    !conversation.inquiry_id &&
    (conversation.listing_id || conversation.project_id) &&
    participant?.role === "buyer";
  const firstSupportMessage = conversation.kind === "support" && Number(conversation.message_count) === 0;

  const publicId = ulid();
  const preview = body ? body.replace(/\s+/g, " ").slice(0, 200) : `📎 ${attachmentIds.length === 1 ? "Attachment" : `${attachmentIds.length} attachments`}`;
  await withTransaction(async (connection) => {
    if (joinAs) await join(identity, conversation, joinAs, connection);
    if (firstEnquiryMessage) {
      const context = await sellerContextOf(conversation, connection);
      if (context) {
        const inquiryId = await createChatInquiry(identity, context, { message: body || preview, sourceUrl: req?.body?.sourceUrl }, req, connection);
        await execute("UPDATE conversations SET inquiry_id = ? WHERE id = ?", [inquiryId, conversation.id], connection);
      }
    }
    const result = await execute(
      `INSERT INTO messages (public_id, conversation_id, sender_user_id, sender_guest_id, sender_type, body, body_format,
                             status, channel, client_ref, created_at)
       VALUES (?, ?, ?, ?, 'user', ?, 'plain', 'sent', 'in_app', ?, NOW(3))`,
      [
        publicId,
        conversation.id,
        identity.type === "user" ? identity.userId : null,
        identity.type === "guest" ? identity.guestId : null,
        body,
        clientRef ? String(clientRef).slice(0, 64) : null,
      ],
      connection
    );
    if (attachmentIds.length) await claimPendingAttachments(identity, conversation.id, result.insertId, attachmentIds, connection);
    // A reply to a closed support thread reopens it; staff assigned to it keep it.
    const reopen = conversation.kind === "support" && conversation.status === "closed";
    await execute(
      `UPDATE conversations
          SET last_message_at = NOW(3), last_message_preview = ?, last_message_by_user_id = ?,
              message_count = message_count + 1 ${reopen ? ", status = 'open', closed_at = NULL" : ""}
              ${conversation.kind === "support" && joinAs === "admin" && !conversation.assigned_user_id ? ", assigned_user_id = ?" : ""}
        WHERE id = ?`,
      [
        preview,
        identity.type === "user" ? identity.userId : null,
        ...(conversation.kind === "support" && joinAs === "admin" && !conversation.assigned_user_id ? [identity.userId] : []),
        conversation.id,
      ],
      connection
    );
    const meColumn = identity.type === "user" ? "user_id" : "guest_id";
    const meId = identity.type === "user" ? identity.userId : identity.guestId;
    // Everyone else gains an unread; a thread someone archived comes back, as on a phone.
    await execute(
      `UPDATE conversation_participants
          SET unread_count = unread_count + 1, left_at = NULL
        WHERE conversation_id = ? AND NOT (${meColumn} <=> ?)`,
      [conversation.id, meId],
      connection
    );
    await execute(
      `UPDATE conversation_participants SET unread_count = 0, last_read_at = NOW(3), last_delivered_at = NOW(3), left_at = NULL
        WHERE conversation_id = ? AND ${meColumn} = ?`,
      [conversation.id, meId],
      connection
    );
    if (conversation.inquiry_id) {
      // A seller's reply is the enquiry's first response.
      const fromSeller = joinAs === "seller" || ["seller", "agent"].includes(participant?.role);
      await execute(
        `UPDATE inquiries SET last_activity_at = NOW(3)
           ${fromSeller ? ", first_response_at = COALESCE(first_response_at, NOW(3)), status = IF(status = 'new', 'contacted', status)" : ""}
          WHERE id = ?`,
        [conversation.inquiry_id],
        connection
      );
    }
  });

  const row = await queryOne(`${MESSAGE_SELECT} WHERE m.public_id = ?`, [publicId]);
  const dto = (await messagesFor([row]))[0];
  participants = await participantsOf([conversation.id]);
  publishMessage(conversation, participants, dto);
  // Replying means the sender has read everything before it: their ticks turn blue for the others.
  const now = new Date().toISOString();
  publishReceipt(conversation, participants, { ref: refFor(identity), readAt: now, deliveredAt: now });
  if (firstEnquiryMessage) afterChatInquiry(conversation.id).catch(() => {});
  if (firstSupportMessage && joinAs !== "admin" && participant?.role !== "admin") {
    notifyStaffOfSupport(conversation.id, identity, body || conversation.subject).catch(() => {});
  }
  notifyOfflineRecipients({ conversation, participants, sender: identity, message: dto }).catch((error) =>
    logger.warn({ err: error }, "chat offline notification failed")
  );
  return dto;
}

/** Every participant gets the message and their own unread count; support staff see support threads. */
function publishMessage(conversation, participants, message) {
  for (const row of participants) {
    const ref = participantRef(row);
    if (!ref) continue;
    emitTo([ref], "message", { conversationId: conversation.public_id, message, unreadCount: Number(row.unread_count || 0) });
  }
  if (conversation.kind === "support") {
    emitTo([], "support:activity", { conversationId: conversation.public_id, message }, { staff: true });
  }
}

function publishReceipt(conversation, participants, payload) {
  const refs = participants.map(participantRef).filter((ref) => ref && ref !== payload.ref);
  emitTo(refs, "receipt", { conversationId: conversation.public_id, ...payload }, { staff: conversation.kind === "support" });
}

/** Two blue ticks: the reader has seen everything up to now. */
export async function markRead(identity, conversationPublicId) {
  const conversation = await loadConversation(conversationPublicId);
  const participants = await participantsOf([conversation.id]);
  const { participant } = accessFor(identity, conversation, participants);
  if (!participant) return { read: false };
  await execute(
    "UPDATE conversation_participants SET unread_count = 0, last_read_at = NOW(3), last_delivered_at = NOW(3) WHERE id = ?",
    [participant.id]
  );
  // The portal's older inbox reads message status.
  const senderColumn = identity.type === "user" ? "sender_user_id" : "sender_guest_id";
  await execute(
    `UPDATE messages SET status = 'read'
      WHERE conversation_id = ? AND status IN ('sent','delivered') AND NOT (${senderColumn} <=> ?)`,
    [conversation.id, identity.type === "user" ? identity.userId : identity.guestId]
  );
  const now = new Date().toISOString();
  publishReceipt(conversation, participants, { ref: refFor(identity), readAt: now, deliveredAt: now });
  emitTo([refFor(identity)], "unread", { conversationId: conversation.public_id, unreadCount: 0, total: await unreadTotal(identity) });
  return { read: true, readAt: now };
}

/** Two grey ticks: the message reached one of the person's devices. */
export async function markDelivered(identity, conversationPublicIds = null) {
  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  const ids = conversationPublicIds ? inClause(conversationPublicIds.map(String).slice(0, 100)) : null;
  const rows = await query(
    `SELECT cp.id, c.id AS conversation_id, c.public_id, c.kind
       FROM conversation_participants cp JOIN conversations c ON c.id = cp.conversation_id
      WHERE cp.${meColumn} = ?
        AND (cp.last_delivered_at IS NULL OR cp.last_delivered_at < c.last_message_at)
        ${ids ? `AND c.public_id IN ${ids.sql}` : ""}
      LIMIT 200`,
    [meId, ...(ids ? ids.params : [])]
  );
  if (!rows.length) return 0;
  const participantIds = inClause(rows.map((row) => row.id));
  await execute(`UPDATE conversation_participants SET last_delivered_at = NOW(3) WHERE id IN ${participantIds.sql}`, participantIds.params);
  const now = new Date().toISOString();
  const all = await participantsOf(rows.map((row) => row.conversation_id));
  for (const row of rows) {
    publishReceipt(
      { public_id: row.public_id, kind: row.kind },
      all.filter((participant) => participant.conversation_id === row.conversation_id),
      { ref: refFor(identity), deliveredAt: now }
    );
  }
  return rows.length;
}

/** Who should see "typing…": everyone else in the thread. Returns null when not allowed. */
export async function typingAudience(identity, conversationPublicId) {
  const conversation = await loadConversation(conversationPublicId);
  const participants = await participantsOf([conversation.id]);
  accessFor(identity, conversation, participants, { write: true });
  if (conversation.status === "blocked") return null;
  const me = refFor(identity);
  return {
    conversation,
    refs: participants.map(participantRef).filter((ref) => ref && ref !== me),
  };
}

/** People who share a thread with `identity`, to tell them when they come and go. */
export async function contactsOf(identity) {
  const meColumn = identity.type === "user" ? "user_id" : "guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  const rows = await query(
    `SELECT DISTINCT u.public_id AS user_public_id, g.public_id AS guest_public_id
       FROM conversation_participants me
       JOIN conversation_participants other ON other.conversation_id = me.conversation_id AND other.id <> me.id
       LEFT JOIN users u ON u.id = other.user_id
       LEFT JOIN chat_guests g ON g.id = other.guest_id
       JOIN conversations c ON c.id = me.conversation_id
      WHERE me.${meColumn} = ? AND c.last_message_at > DATE_SUB(NOW(3), INTERVAL 90 DAY)
      LIMIT 500`,
    [meId]
  );
  return rows.map(participantRef).filter(Boolean);
}

/* ---------------------------------------------------------------------------------------------
 * Thread actions
 * ------------------------------------------------------------------------------------------- */

async function ownParticipant(identity, conversationPublicId, { write = false } = {}) {
  const conversation = await loadConversation(conversationPublicId);
  const participants = await participantsOf([conversation.id]);
  const access = accessFor(identity, conversation, participants, { write });
  return { conversation, participants, ...access };
}

export async function setArchived(identity, conversationPublicId, archived) {
  const { participant } = await ownParticipant(identity, conversationPublicId);
  if (!participant) return { archived: false };
  await execute("UPDATE conversation_participants SET left_at = ? WHERE id = ?", [archived ? new Date() : null, participant.id]);
  return { archived: Boolean(archived) };
}

export async function setMuted(identity, conversationPublicId, muted) {
  const { participant } = await ownParticipant(identity, conversationPublicId);
  if (!participant) return { muted: false };
  await execute("UPDATE conversation_participants SET is_muted = ? WHERE id = ?", [muted ? 1 : 0, participant.id]);
  return { muted: Boolean(muted) };
}

/**
 * Either side of an enquiry may block the other; staff may block any support thread. Only whoever
 * blocked it (or staff) may unblock it. Guests cannot block: they can simply stop replying.
 */
export async function setBlocked(identity, conversationPublicId, blocked, req) {
  if (identity.type !== "user") throw AppError.forbidden("Sign in to block a chat.");
  const { conversation, participants, participant } = await ownParticipant(identity, conversationPublicId, { write: true });
  const isStaff = canReplySupport(identity);
  if (!participant && !isStaff) throw AppError.forbidden();
  if (!blocked && conversation.status === "blocked" && String(conversation.blocked_by_user_id) !== String(identity.userId) && !isStaff) {
    throw AppError.forbidden("Only the person who blocked this chat can unblock it.");
  }
  await execute(
    blocked
      ? "UPDATE conversations SET status = 'blocked', blocked_by_user_id = ?, blocked_at = NOW(3) WHERE id = ?"
      : "UPDATE conversations SET status = 'open', blocked_by_user_id = NULL, blocked_at = NULL WHERE id = ? AND ? IS NOT NULL",
    blocked ? [identity.userId, conversation.id] : [conversation.id, identity.userId]
  );
  const { auditFromRequest } = await import("../system/audit.service.js");
  await auditFromRequest(req, { action: blocked ? "chat.blocked" : "chat.unblocked", subjectType: "conversation", subjectId: conversation.id });
  emitTo(participants.map(participantRef), "conversation", { conversationId: conversation.public_id, status: blocked ? "blocked" : "open" }, { staff: conversation.kind === "support" });
  return { blocked: Boolean(blocked) };
}

/** A report goes to the moderation queue with the recent thread attached as evidence. */
export async function reportConversation(identity, conversationPublicId, { reason = "harassment", details = "" }, req) {
  const { conversation } = await ownParticipant(identity, conversationPublicId);
  const meColumn = identity.type === "user" ? "sender_user_id" : "sender_guest_id";
  const meId = identity.type === "user" ? identity.userId : identity.guestId;
  const recent = await query(
    `${MESSAGE_SELECT} WHERE m.conversation_id = ? ORDER BY m.created_at DESC, m.id DESC LIMIT 20`,
    [conversation.id]
  );
  // The newest message from someone else is what the report is filed against.
  const subjectMessage = await queryValue(
    `SELECT id FROM messages WHERE conversation_id = ? AND sender_type = 'user' AND NOT (${meColumn} <=> ?) ORDER BY id DESC LIMIT 1`,
    [conversation.id, meId]
  );
  if (!subjectMessage) throw AppError.badRequest("There is nothing from the other person to report yet.");
  const reasonRow = await queryOne(
    "SELECT id FROM report_reasons WHERE code = ? AND is_active = 1 LIMIT 1",
    [["spam", "harassment", "offensive_content", "impersonation", "privacy", "other"].includes(reason) ? reason : "other"]
  );
  const snapshot = recent.reverse().map((row) => ({
    id: row.public_id,
    at: iso(row.created_at),
    from: row.sender_name || row.sender_guest_name || "System",
    body: String(row.body || "").slice(0, 1000),
  }));
  const reference = await withTransaction(async (connection) => {
    const maxRef = await queryValue(
      "SELECT MAX(CAST(SUBSTRING(reference, 5) AS UNSIGNED)) FROM reports WHERE reference LIKE 'RPT-%'",
      [],
      connection
    );
    const ref = `RPT-${Number(maxRef || 5000) + 1}`;
    await execute(
      `INSERT INTO reports
         (public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details,
          reporter_user_id, reporter_email, reporter_ip, status, priority, report_count, created_at)
       VALUES (?, ?, 'message', ?, CAST(? AS JSON), ?, ?, ?, ?, INET6_ATON(?), 'new', 'normal', 1, NOW(3))`,
      [
        ulid(),
        ref,
        subjectMessage,
        JSON.stringify({ conversation: conversation.public_id, kind: conversation.kind, messages: snapshot }),
        reasonRow?.id ?? null,
        String(details || "").slice(0, 2000) || null,
        identity.type === "user" ? identity.userId : null,
        identity.type === "guest" ? identity.email : null,
        String(req?.ip || "").replace(/^::ffff:/, "") || null,
      ],
      connection
    );
    await execute("UPDATE messages SET is_flagged = 1 WHERE id = ?", [subjectMessage], connection);
    return ref;
  });
  return { reported: true, reference };
}

/* ---------------------------------------------------------------------------------------------
 * Staff
 * ------------------------------------------------------------------------------------------- */

export async function assignSupport(staff, conversationPublicId, { toMe = true, userId = null } = {}, req) {
  if (!canReplySupport(staff)) throw AppError.forbidden();
  const conversation = await loadConversation(conversationPublicId);
  if (conversation.kind !== "support") throw AppError.notFound("That conversation was not found.");
  const target = toMe ? staff.userId : userId ? await queryValue("SELECT id FROM users WHERE public_id = ?", [String(userId)]) : null;
  await execute("UPDATE conversations SET assigned_user_id = ? WHERE id = ?", [target, conversation.id]);
  if (target && String(target) === String(staff.userId)) await join(staff, conversation, "admin");
  const { auditFromRequest } = await import("../system/audit.service.js");
  await auditFromRequest(req, { action: "support_chat.assigned", subjectType: "conversation", subjectId: conversation.id, changes: { assignedUserId: target } });
  emitTo([], "conversation", { conversationId: conversation.public_id, assigned: Boolean(target) }, { staff: true });
  return { assigned: Boolean(target) };
}

export async function setSupportStatus(staff, conversationPublicId, status, req) {
  if (!canReplySupport(staff)) throw AppError.forbidden();
  const conversation = await loadConversation(conversationPublicId);
  if (conversation.kind !== "support") throw AppError.notFound("That conversation was not found.");
  const closing = status === "closed";
  await execute(
    `UPDATE conversations SET status = ?, closed_at = ${closing ? "NOW(3)" : "NULL"} WHERE id = ? AND status <> 'blocked'`,
    [closing ? "closed" : "open", conversation.id]
  );
  if (closing) {
    await execute(
      `INSERT INTO messages (public_id, conversation_id, sender_type, body, body_format, status, channel, created_at)
       VALUES (?, ?, 'system', ?, 'plain', 'sent', 'in_app', NOW(3))`,
      [ulid(), conversation.id, "This chat was closed by LivFinder Support. Reply any time to reopen it."]
    );
  }
  const { auditFromRequest } = await import("../system/audit.service.js");
  await auditFromRequest(req, { action: closing ? "support_chat.closed" : "support_chat.reopened", subjectType: "conversation", subjectId: conversation.id });
  const participants = await participantsOf([conversation.id]);
  emitTo(participants.map(participantRef), "conversation", { conversationId: conversation.public_id, status: closing ? "closed" : "open" }, { staff: true });
  return { status: closing ? "closed" : "open" };
}

export async function supportCounts(staff) {
  if (!canViewSupport(staff)) throw AppError.forbidden();
  const row = await queryOne(
    `SELECT SUM(status = 'open') AS open,
            SUM(status = 'open' AND assigned_user_id IS NULL) AS unassigned,
            SUM(status = 'open' AND assigned_user_id = ?) AS mine
       FROM conversations WHERE kind = 'support'`,
    [staff.userId]
  );
  return { open: Number(row?.open || 0), unassigned: Number(row?.unassigned || 0), mine: Number(row?.mine || 0) };
}

/** A guest who signs up or signs in with the same email keeps their threads. */
export async function claimGuestThreads(guest, user) {
  if (!guest || !user) return 0;
  const result = await execute(
    `UPDATE conversation_participants cp
        LEFT JOIN conversation_participants existing ON existing.conversation_id = cp.conversation_id AND existing.user_id = ?
        SET cp.user_id = ?, cp.guest_id = NULL
      WHERE cp.guest_id = ? AND existing.id IS NULL`,
    [user.userId, user.userId, guest.guestId]
  );
  await execute("UPDATE messages SET sender_user_id = ?, sender_guest_id = NULL WHERE sender_guest_id = ?", [user.userId, guest.guestId]);
  await execute("UPDATE chat_guests SET claimed_by_user_id = ? WHERE id = ?", [user.userId, guest.guestId]);
  return result.affectedRows || 0;
}

/** For an upload: the conversation, once the caller is known to be allowed to write to it. */
export async function writableConversation(identity, conversationPublicId) {
  const conversation = await loadConversation(conversationPublicId);
  const participants = await participantsOf([conversation.id]);
  accessFor(identity, conversation, participants, { write: true });
  if (conversation.status === "blocked") throw AppError.forbidden("This chat has been blocked, so files cannot be sent.");
  return { conversation };
}

/** For a file download: throws unless the caller may read the conversation. */
export async function readableConversation(identity, conversationPublicId) {
  const conversation = await loadConversation(conversationPublicId);
  const participants = await participantsOf([conversation.id]);
  accessFor(identity, conversation, participants);
  return { conversation };
}

/**
 * Companies and agents someone can start a chat with, by name: public, active profiles only, and
 * only ones that have someone to answer (an agent with a login, or a company with an account).
 */
export async function searchDirectory(term) {
  const like = `%${String(term).replace(/[%_\\]/g, "\\$&").slice(0, 80)}%`;
  const prefix = `${String(term).replace(/[%_\\]/g, "\\$&").slice(0, 80)}%`;
  const [companies, agents] = await Promise.all([
    query(
      `SELECT o.public_id, o.name, o.slug, o.logo_url, o.kind
         FROM organizations o
        WHERE o.deleted_at IS NULL AND o.is_publicly_visible = 1 AND o.account_id IS NOT NULL AND o.name LIKE ?
        ORDER BY (o.name LIKE ?) DESC, o.name
        LIMIT 6`,
      [like, prefix]
    ),
    query(
      `SELECT a.public_id, a.display_name, a.slug, a.photo_url, a.title, o.name AS organization_name
         FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id
        WHERE a.deleted_at IS NULL AND a.status = 'active' AND a.is_publicly_visible = 1 AND a.user_id IS NOT NULL
          AND a.display_name LIKE ?
        ORDER BY (a.display_name LIKE ?) DESC, a.display_name
        LIMIT 6`,
      [like, prefix]
    ),
  ]);
  return [
    ...companies.map((row) => ({
      type: "organization",
      id: row.public_id,
      name: row.name,
      subtitle: row.kind ? `${row.kind.charAt(0).toUpperCase()}${row.kind.slice(1).replace(/_/g, " ")}` : "Company",
      avatar: row.logo_url || null,
    })),
    ...agents.map((row) => ({
      type: "agent",
      id: row.public_id,
      name: row.display_name,
      subtitle: [row.title || "Agent", row.organization_name].filter(Boolean).join(" · "),
      avatar: row.photo_url || null,
    })),
  ];
}

/** Chats opened but never written in, once nobody can still be looking at them. */
export async function sweepEmptyConversations() {
  const result = await execute(
    `DELETE FROM conversations
      WHERE message_count = 0 AND created_at < DATE_SUB(NOW(3), INTERVAL 1 DAY)
        AND NOT EXISTS (SELECT 1 FROM messages m WHERE m.conversation_id = conversations.id)
      LIMIT 1000`
  );
  return result.affectedRows || 0;
}
