import { query, queryOne, queryValue } from "../../db/query.js";
import { bool, int, isoDate, isoDay, num } from "../../serializers/primitives.js";
import { PORTAL_LISTING_COLUMNS, PORTAL_LISTING_JOINS, serializePortalListing, formatMoney, relativeTime, rootIdForFrontendCategory, titleize } from "./portal.repository.js";

/**
 * Everything the portal shows that is not a listing: inquiries, leads,
 * conversations, bookings, offers, reviews, favourites, saved searches and the
 * finance screens.
 *
 * Scoping rule, applied without exception: a row is visible when it belongs to
 * the caller's account, their organization, or (for buyer-side features like
 * favourites) their user.
 */
function scopeClause(alias, { accountId, organizationId }) {
  const conditions = [`${alias}.account_id = ?`];
  const params = [accountId];
  if (organizationId) {
    conditions.push(`${alias}.organization_id = ?`);
    params.push(organizationId);
  }
  return { sql: `(${conditions.join(" OR ")})`, params };
}

function paginate({ page, pageSize }, defaultSize = 10) {
  const safePage = Math.max(1, Number(page) || 1);
  const safeSize = Math.min(100, Math.max(1, Number(pageSize) || defaultSize));
  return { page: safePage, pageSize: safeSize, offset: (safePage - 1) * safeSize };
}

/* -------------------------------------------------------------------------- */
/* Inquiries                                                                   */
/* -------------------------------------------------------------------------- */

export async function listInquiries({ accountId, organizationId, search = "", listing = "all", category = "all", status = "all", from, to, sort = "newest", page = 1, pageSize = 10 }) {
  const scope = scopeClause("i", { accountId, organizationId });
  const conditions = [scope.sql, "i.deleted_at IS NULL", "i.is_spam = 0"];
  const params = [...scope.params];

  if (status !== "all") {
    conditions.push("i.status = ?");
    params.push(status);
  }
  if (listing !== "all") {
    conditions.push("(l.public_id = ? OR l.reference = ?)");
    params.push(String(listing), String(listing));
  }
  if (category !== "all") {
    const rootId = rootIdForFrontendCategory(category);
    if (rootId) {
      conditions.push("l.root_category_id = ?");
      params.push(rootId);
    }
  }
  if (from) {
    conditions.push("i.created_at >= ?");
    params.push(new Date(from));
  }
  if (to) {
    conditions.push("i.created_at <= ?");
    params.push(new Date(`${to}T23:59:59`));
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(i.name LIKE ? OR i.email LIKE ? OR i.message LIKE ? OR l.title LIKE ? OR l.reference LIKE ?)");
    params.push(`%${term}%`, `%${term}%`, `%${term}%`, `%${term}%`, `%${term}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });
  const orderBy = sort === "oldest" ? "i.created_at ASC" : "i.created_at DESC";

  const [rows, total, counts, listings] = await Promise.all([
    query(
      `SELECT i.id AS entity_id, i.public_id AS entity_public_id, i.reference AS entity_reference,
              i.name, i.email, i.phone, i.message, i.subject,
              i.status AS entity_status, i.priority, i.channel, i.inquiry_type,
              i.created_at AS entity_created_at, i.first_response_at,
              i.assigned_to_agent_id, i.budget_min, i.budget_max, i.currency_code AS entity_currency_code,
              ${PORTAL_LISTING_COLUMNS.replaceAll("l.", "l.")}
         FROM inquiries i
         LEFT JOIN listings l ON l.id = i.listing_id
         LEFT JOIN categories cat ON cat.id = l.category_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN locations sc ON sc.id = l.sub_community_id
         LEFT JOIN agents ag ON ag.id = l.agent_id
         LEFT JOIN listing_real_estate re ON re.listing_id = l.id
         LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
         LEFT JOIN listing_marine mar ON mar.listing_id = l.id
         LEFT JOIN listing_aviation av ON av.listing_id = l.id
         LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
         ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM inquiries i LEFT JOIN listings l ON l.id = i.listing_id ${where}`, params),
    inquiryCounts({ accountId, organizationId }),
    query(
      `SELECT ${PORTAL_LISTING_COLUMNS} FROM listings l ${PORTAL_LISTING_JOINS}
        WHERE l.account_id = ? AND l.deleted_at IS NULL AND l.inquiry_count > 0
        ORDER BY l.inquiry_count DESC LIMIT 20`,
      [accountId]
    ),
  ]);

  return {
    data: rows.map((row) => ({
      id: row.entity_public_id,
      reference: row.entity_reference,
      buyer: { name: row.name, email: row.email, phone: row.phone },
      message: row.message,
      subject: row.subject,
      status: row.entity_status,
      priority: row.priority,
      channel: row.channel,
      inquiryType: row.inquiry_type,
      budget: row.budget_min ? { min: num(row.budget_min), max: num(row.budget_max), currency: row.entity_currency_code } : null,
      receivedAt: isoDate(row.entity_created_at),
      relativeTime: relativeTime(row.entity_created_at),
      firstResponseAt: isoDate(row.first_response_at),
      listing: row.id ? serializePortalListing(row) : null,
      availableActions: inquiryActions(row.entity_status),
    })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    counts,
    listings: listings.map(serializePortalListing),
  };
}

function inquiryActions(status) {
  if (status === "new") return ["reply", "markContacted", "assign", "markSpam"];
  if (status === "contacted") return ["reply", "qualify", "close"];
  if (status === "qualified") return ["reply", "convert", "close"];
  return ["reply", "reopen"];
}

export async function inquiryCounts({ accountId, organizationId }) {
  const scope = scopeClause("i", { accountId, organizationId });
  const row = await queryOne(
    `SELECT COUNT(*) AS all_count,
            SUM(i.status = 'new') AS new_count,
            SUM(i.status = 'contacted') AS contacted,
            SUM(i.status = 'qualified') AS qualified,
            SUM(i.status IN ('won','lost','closed')) AS closed
       FROM inquiries i
      WHERE ${scope.sql} AND i.deleted_at IS NULL AND i.is_spam = 0`,
    scope.params
  );
  return {
    all: int(row?.all_count) ?? 0,
    new: int(row?.new_count) ?? 0,
    contacted: int(row?.contacted) ?? 0,
    qualified: int(row?.qualified) ?? 0,
    closed: int(row?.closed) ?? 0,
  };
}

/* -------------------------------------------------------------------------- */
/* Leads (CRM)                                                                 */
/* -------------------------------------------------------------------------- */

export async function listLeads({ accountId, organizationId, status = "all", search = "", page = 1, pageSize = 20 }) {
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];
  if (organizationId) {
    conditions.push("l.organization_id = ?");
    params.push(organizationId);
  } else {
    conditions.push("l.account_id = ?");
    params.push(accountId);
  }
  if (status !== "all") {
    conditions.push("l.status = ?");
    params.push(status);
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(c.first_name LIKE ? OR c.last_name LIKE ? OR c.primary_email LIKE ? OR l.reference LIKE ?)");
    params.push(`%${term}%`, `%${term}%`, `%${term}%`, `%${term}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize }, 20);

  const [rows, total] = await Promise.all([
    query(
      `SELECT l.id, l.public_id, l.reference, l.status, l.stage_id, l.score, l.score_band,
              l.priority, l.created_at, l.owner_agent_id, l.budget_min, l.budget_max,
              l.currency_code, l.intent, l.timeframe, l.last_activity_at, l.next_action_at,
              l.root_category_id AS lead_root_category_id,
              COALESCE(c.first_name, SUBSTRING_INDEX(l.name, ' ', 1)) AS first_name,
              COALESCE(c.last_name, TRIM(SUBSTRING(l.name, LOCATE(' ', l.name)))) AS last_name,
              COALESCE(c.primary_email, l.email) AS primary_email,
              COALESCE(c.primary_phone_e164, l.phone_e164) AS primary_phone,
              s.name AS stage_name, src.name AS source_name,
              ag.display_name AS agent_name, ag.public_id AS agent_public_id,
              li.title AS listing_title, li.public_id AS listing_public_id,
              li.root_category_id AS listing_root_category_id
         FROM leads l
         LEFT JOIN crm_contacts c ON c.id = l.contact_id
         LEFT JOIN lead_pipeline_stages s ON s.id = l.stage_id
         LEFT JOIN lead_sources src ON src.id = l.source_id
         LEFT JOIN agents ag ON ag.id = l.owner_agent_id
         LEFT JOIN listings li ON li.id = l.primary_listing_id
         ${where}
        ORDER BY l.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM leads l LEFT JOIN crm_contacts c ON c.id = l.contact_id ${where}`,
      params
    ),
  ]);

  return {
    data: rows.map((row) => ({
      id: row.public_id,
      reference: row.reference,
      contactName: [row.first_name, row.last_name].filter(Boolean).join(" "),
      contactEmail: row.primary_email,
      contactPhone: row.primary_phone,
      listingTitle: row.listing_title,
      listingId: row.listing_public_id,
      categoryId: require_frontendCategoryId(row.listing_root_category_id ?? row.lead_root_category_id),
      assignedAgentName: row.agent_name,
      assignedAgentId: row.agent_public_id,
      source: row.source_name,
      stage: row.stage_name,
      status: row.status,
      priority: row.priority,
      intent: row.intent,
      timeframe: row.timeframe,
      score: int(row.score),
      scoreBand: row.score_band,
      lastActivityAt: isoDate(row.last_activity_at),
      nextActionAt: isoDate(row.next_action_at),
      budget: row.budget_min ? { min: num(row.budget_min), max: num(row.budget_max), currency: row.currency_code } : null,
      receivedAt: isoDate(row.created_at),
    })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
  };
}

function require_frontendCategoryId(rootId) {
  const map = { 1: "realEstate", 2: "car", 3: "yacht", 4: "jet", 5: "helicopter", 6: "watch" };
  return map[Number(rootId)] || null;
}

/* -------------------------------------------------------------------------- */
/* Messages                                                                    */
/* -------------------------------------------------------------------------- */

export async function listConversations({ userId, organizationId, filter = "all", conversationId = null }) {
  const conditions = ["cp.user_id = ?"];
  const params = [userId];
  if (organizationId) {
    conditions[0] = "(cp.user_id = ? OR c.organization_id = ?)";
    params.push(organizationId);
  }
  if (filter === "unread") conditions.push("cp.unread_count > 0");
  if (filter === "archived") conditions.push("cp.left_at IS NOT NULL");
  else conditions.push("cp.left_at IS NULL");

  const rows = await query(
    `SELECT DISTINCT c.id, c.public_id, c.subject, c.listing_id, c.status,
            c.last_message_at, c.last_message_preview, c.message_count,
            cp.unread_count, cp.last_read_at, cp.left_at,
            l.title AS listing_title, l.public_id AS listing_public_id,
            l.cover_image_url, l.reference AS listing_reference,
            l.root_category_id
       FROM conversations c
       JOIN conversation_participants cp ON cp.conversation_id = c.id
       LEFT JOIN listings l ON l.id = c.listing_id
      WHERE ${conditions.join(" AND ")}
      ORDER BY c.last_message_at DESC
      LIMIT 100`,
    params
  );

  const conversations = [];
  for (const row of rows) {
    const [participants, messages] = await Promise.all([
      query(
        `SELECT cp.user_id, cp.role, u.display_name, u.avatar_url, u.last_seen_at
           FROM conversation_participants cp
           LEFT JOIN users u ON u.id = cp.user_id
          WHERE cp.conversation_id = ?`,
        [row.id]
      ),
      // Only the active thread needs its messages; the list needs a preview.
      String(row.public_id) === String(conversationId) || conversations.length === 0
        ? query(
            `SELECT m.public_id, m.sender_user_id, m.body, m.created_at, m.status
               FROM messages m
              WHERE m.conversation_id = ? AND m.deleted_at IS NULL
              ORDER BY m.created_at ASC LIMIT 200`,
            [row.id]
          )
        : Promise.resolve([]),
    ]);

    const counterpart = participants.find((participant) => String(participant.user_id) !== String(userId)) || participants[0];
    conversations.push({
      id: row.public_id,
      conversationId: String(row.id),
      subject: row.subject,
      participant: {
        id: counterpart ? String(counterpart.user_id) : null,
        name: counterpart?.display_name || "LivFinder member",
        avatar: counterpart?.avatar_url || null,
        online: counterpart?.last_seen_at ? Date.now() - new Date(counterpart.last_seen_at).getTime() < 5 * 60 * 1000 : false,
      },
      listingId: row.listing_public_id,
      listing: row.listing_id
        ? {
            id: row.listing_public_id,
            title: row.listing_title,
            reference: row.listing_reference,
            image: { src: row.cover_image_url, alt: row.listing_title },
            category: require_frontendCategoryId(row.root_category_id),
          }
        : null,
      lastMessage: row.last_message_preview,
      relativeTime: relativeTime(row.last_message_at),
      lastMessageAt: isoDate(row.last_message_at),
      unread: int(row.unread_count) > 0,
      unreadCount: int(row.unread_count) ?? 0,
      archived: Boolean(row.left_at),
      messageCount: int(row.message_count) ?? 0,
      messages: messages.map((message) => ({
        id: message.public_id,
        sender: String(message.sender_user_id) === String(userId) ? "outgoing" : "incoming",
        text: message.body,
        sentAt: new Intl.DateTimeFormat("en", { hour: "numeric", minute: "2-digit", timeZone: "UTC" }).format(new Date(message.created_at)),
        sentAtIso: isoDate(message.created_at),
        read: message.status === "read",
      })),
    });
  }

  const active = conversations.find((conversation) => conversation.id === conversationId) || conversations[0] || null;
  return {
    conversations,
    unreadCount: conversations.filter((conversation) => conversation.unread).length,
    activeConversation: active,
  };
}

/* -------------------------------------------------------------------------- */
/* Bookings                                                                    */
/* -------------------------------------------------------------------------- */

export async function listBookings({ accountId, organizationId, search = "", category = "all", status = "upcoming", from, to, view = "list", page = 1, pageSize = 10 }) {
  const scope = scopeClause("b", { accountId, organizationId });
  const conditions = [scope.sql, "b.deleted_at IS NULL"];
  const params = [...scope.params];

  if (status === "upcoming") conditions.push("b.status IN ('requested','confirmed','rescheduled') AND b.scheduled_start >= NOW(3)");
  else if (status !== "all") {
    conditions.push("b.status = ?");
    params.push(status);
  }
  if (category !== "all") {
    const rootId = rootIdForFrontendCategory(category);
    if (rootId) {
      conditions.push("l.root_category_id = ?");
      params.push(rootId);
    }
  }
  if (from) {
    conditions.push("b.scheduled_start >= ?");
    params.push(new Date(from));
  }
  if (to) {
    conditions.push("b.scheduled_start <= ?");
    params.push(new Date(`${to}T23:59:59`));
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(b.contact_name LIKE ? OR l.title LIKE ? OR b.reference LIKE ?)");
    params.push(`%${term}%`, `%${term}%`, `%${term}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });

  const [rows, total, counts] = await Promise.all([
    query(
      `SELECT b.id AS entity_id, b.public_id AS entity_public_id, b.reference AS entity_reference,
              b.booking_type, b.status AS entity_status, b.scheduled_start,
              b.scheduled_end, b.timezone, b.guest_count, b.contact_name, b.contact_email,
              b.contact_phone, b.notes, b.meeting_location, b.meeting_url, b.total_amount,
              b.currency_code AS entity_currency_code, b.created_at AS entity_created_at,
              ag.display_name AS agent_name, ag.public_id AS agent_public_id,
              ${PORTAL_LISTING_COLUMNS}
         FROM bookings b
         LEFT JOIN listings l ON l.id = b.listing_id
         LEFT JOIN categories cat ON cat.id = l.category_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN locations sc ON sc.id = l.sub_community_id
         LEFT JOIN agents ag ON ag.id = b.agent_id
         LEFT JOIN listing_real_estate re ON re.listing_id = l.id
         LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
         LEFT JOIN listing_marine mar ON mar.listing_id = l.id
         LEFT JOIN listing_aviation av ON av.listing_id = l.id
         LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
         ${where}
        ORDER BY b.scheduled_start ASC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM bookings b LEFT JOIN listings l ON l.id = b.listing_id ${where}`, params),
    bookingCounts({ accountId, organizationId }),
  ]);

  return {
    data: rows.map((row) => ({
      id: row.entity_public_id,
      reference: row.entity_reference,
      bookingType: row.booking_type,
      status: row.entity_status,
      startsAt: isoDate(row.scheduled_start),
      endsAt: isoDate(row.scheduled_end),
      timezone: row.timezone,
      guestCount: int(row.guest_count),
      client: { name: row.contact_name, email: row.contact_email, phone: row.contact_phone },
      assignedTo: { name: row.agent_name, id: row.agent_public_id },
      notes: row.notes,
      location: row.meeting_location,
      meetingUrl: row.meeting_url,
      amount: num(row.total_amount),
      currency: row.entity_currency_code,
      listing: row.id ? serializePortalListing(row) : null,
      availableActions: bookingActions(row.entity_status),
    })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    counts,
    summary: {
      total: counts.upcoming,
      confirmed: counts.confirmed,
      pending: counts.pending,
      reschedule: counts.rescheduled,
    },
    view: view === "calendar" ? "calendar" : "list",
  };
}

function bookingActions(status) {
  if (status === "requested") return ["confirm", "reschedule", "cancel"];
  if (status === "confirmed") return ["complete", "reschedule", "cancel"];
  if (status === "rescheduled") return ["confirm", "cancel"];
  return ["view"];
}

export async function bookingCounts({ accountId, organizationId }) {
  const scope = scopeClause("b", { accountId, organizationId });
  const row = await queryOne(
    `SELECT SUM(b.status IN ('requested','confirmed','rescheduled') AND b.scheduled_start >= NOW(3)) AS upcoming,
            SUM(b.status = 'requested') AS pending,
            SUM(b.status = 'confirmed') AS confirmed,
            SUM(b.status = 'rescheduled') AS rescheduled,
            SUM(b.status = 'completed') AS completed,
            SUM(b.status = 'cancelled') AS cancelled
       FROM bookings b WHERE ${scope.sql} AND b.deleted_at IS NULL`,
    scope.params
  );
  return {
    upcoming: int(row?.upcoming) ?? 0,
    pending: int(row?.pending) ?? 0,
    confirmed: int(row?.confirmed) ?? 0,
    rescheduled: int(row?.rescheduled) ?? 0,
    completed: int(row?.completed) ?? 0,
    cancelled: int(row?.cancelled) ?? 0,
  };
}

/* -------------------------------------------------------------------------- */
/* Offers                                                                      */
/* -------------------------------------------------------------------------- */

export async function listOffers({ accountId, organizationId, search = "", category = "all", listing = "all", status = "all", sort = "newest", view = "list", page = 1, pageSize = 10 }) {
  const scope = scopeClause("o", { accountId, organizationId });
  const conditions = [scope.sql, "o.deleted_at IS NULL"];
  const params = [...scope.params];

  if (status !== "all") {
    conditions.push("o.status = ?");
    params.push(status);
  }
  if (listing !== "all") {
    conditions.push("(l.public_id = ? OR l.reference = ?)");
    params.push(String(listing), String(listing));
  }
  if (category !== "all") {
    const rootId = rootIdForFrontendCategory(category);
    if (rootId) {
      conditions.push("l.root_category_id = ?");
      params.push(rootId);
    }
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(o.buyer_name LIKE ? OR l.title LIKE ? OR o.reference LIKE ?)");
    params.push(`%${term}%`, `%${term}%`, `%${term}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });
  const orderBy =
    { newest: "o.created_at DESC", oldest: "o.created_at ASC", valueHigh: "o.amount DESC", valueLow: "o.amount ASC" }[sort] ||
    "o.created_at DESC";

  const [rows, total, counts, summary] = await Promise.all([
    query(
      `SELECT o.id AS entity_id, o.public_id AS entity_public_id, o.reference AS entity_reference,
              o.buyer_name, o.buyer_email, o.buyer_phone,
              o.amount, o.currency_code AS entity_currency_code, o.status AS entity_status,
              o.message, o.conditions,
              o.is_subject_to_finance, o.is_subject_to_survey, o.expires_at AS entity_expires_at,
              o.responded_at, o.response_note, o.created_at AS entity_created_at,
              ${PORTAL_LISTING_COLUMNS}
         FROM offers o
         LEFT JOIN listings l ON l.id = o.listing_id
         LEFT JOIN categories cat ON cat.id = l.category_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN locations sc ON sc.id = l.sub_community_id
         LEFT JOIN agents ag ON ag.id = l.agent_id
         LEFT JOIN listing_real_estate re ON re.listing_id = l.id
         LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
         LEFT JOIN listing_marine mar ON mar.listing_id = l.id
         LEFT JOIN listing_aviation av ON av.listing_id = l.id
         LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
         ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM offers o LEFT JOIN listings l ON l.id = o.listing_id ${where}`, params),
    offerCounts({ accountId, organizationId }),
    queryOne(
      `SELECT COALESCE(SUM(o.amount_base), 0) AS value_base
         FROM offers o WHERE ${scope.sql} AND o.deleted_at IS NULL AND o.status IN ('submitted','under_review','countered','accepted')`,
      scope.params
    ),
  ]);

  return {
    data: rows.map((row) => {
      const askingAmount = num(row.price) ?? 0;
      const offerAmount = num(row.amount) ?? 0;
      return {
        id: row.entity_public_id,
        reference: row.entity_reference,
        buyer: { name: row.buyer_name, email: row.buyer_email, phone: row.buyer_phone },
        offerAmount,
        currency: row.entity_currency_code,
        offerFormatted: formatMoney({ amount: offerAmount, currency: row.entity_currency_code }),
        askingAmount,
        // The asking price is the listing's, so it is quoted in the listing's currency.
        askingFormatted: formatMoney({ amount: askingAmount, currency: row.currency_code }),
        differencePercent: askingAmount ? ((offerAmount - askingAmount) / askingAmount) * 100 : 0,
        status: row.entity_status,
        message: row.message,
        conditions: row.conditions,
        subjectToFinance: bool(row.is_subject_to_finance),
        subjectToSurvey: bool(row.is_subject_to_survey),
        expiresAt: isoDate(row.entity_expires_at),
        respondedAt: isoDate(row.responded_at),
        responseNote: row.response_note,
        receivedAt: isoDate(row.entity_created_at),
        listing: row.id ? serializePortalListing(row) : null,
        availableActions: offerActions(row.entity_status),
      };
    }),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    counts,
    summary: {
      newOffers: counts.new,
      offerValue: formatMoney({ amount: num(summary?.value_base) ?? 0, currency: "AED" }),
      negotiations: counts.negotiating,
      accepted: counts.accepted,
    },
    view: view === "grid" ? "grid" : "list",
  };
}

function offerActions(status) {
  // The enum is submitted / under_review / countered / accepted / declined / withdrawn /
  // expired / completed. "new" and "negotiating" were never members of it, so no offer ever
  // matched and every row was treated as closed.
  if (status === "submitted" || status === "under_review" || status === "countered") {
    return ["accept", "counter", "decline"];
  }
  return ["view"];
}

export async function offerCounts({ accountId, organizationId }) {
  const scope = scopeClause("o", { accountId, organizationId });
  const row = await queryOne(
    `SELECT COUNT(*) AS all_count,
            SUM(o.status = 'submitted') AS new_count,
            SUM(o.status IN ('countered','under_review')) AS negotiating,
            SUM(o.status = 'accepted') AS accepted,
            SUM(o.status IN ('declined','rejected')) AS declined
       FROM offers o WHERE ${scope.sql} AND o.deleted_at IS NULL`,
    scope.params
  );
  return {
    all: int(row?.all_count) ?? 0,
    new: int(row?.new_count) ?? 0,
    negotiating: int(row?.negotiating) ?? 0,
    accepted: int(row?.accepted) ?? 0,
    declined: int(row?.declined) ?? 0,
  };
}

/* -------------------------------------------------------------------------- */
/* Reviews                                                                     */
/* -------------------------------------------------------------------------- */

export async function listReviews({ organizationId, agentId, status = "all", page = 1, pageSize = 10 }) {
  const conditions = ["r.deleted_at IS NULL", "r.status = 'published'"];
  const params = [];
  if (organizationId) {
    conditions.push("r.organization_id = ?");
    params.push(organizationId);
  } else if (agentId) {
    conditions.push("(r.subject_type = 'agent' AND r.subject_id = ?)");
    params.push(agentId);
  } else {
    return { data: [], total: 0, page: 1, pageSize, counts: { all: 0, "needs-response": 0, responded: 0 }, summary: emptyReviewSummary() };
  }
  if (status === "needs-response") conditions.push("NOT EXISTS (SELECT 1 FROM review_responses rr WHERE rr.review_id = r.id)");
  if (status === "responded") conditions.push("EXISTS (SELECT 1 FROM review_responses rr WHERE rr.review_id = r.id)");

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });

  const [rows, total, summary, needsResponse] = await Promise.all([
    query(
      `SELECT r.id, r.public_id, r.author_name, r.rating, r.rating_communication, r.rating_knowledge,
              r.rating_professionalism, r.rating_responsiveness, r.title, r.body,
              r.is_verified_transaction, r.helpful_count, r.published_at, r.created_at,
              rr.body AS response_body, rr.created_at AS response_created_at,
              l.title AS listing_title, l.public_id AS listing_public_id, l.cover_image_url,
              l.root_category_id
         FROM reviews r
         LEFT JOIN review_responses rr ON rr.review_id = r.id
         LEFT JOIN bookings b ON b.id = r.booking_id
         LEFT JOIN listings l ON l.id = b.listing_id
         ${where}
        ORDER BY r.published_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM reviews r ${where}`, params),
    queryOne(
      `SELECT COUNT(*) AS review_count, AVG(r.rating) AS rating_avg,
              SUM(r.rating = 5) AS five, SUM(r.rating = 4) AS four, SUM(r.rating = 3) AS three,
              SUM(r.rating = 2) AS two, SUM(r.rating = 1) AS one,
              AVG(r.rating_communication) AS communication, AVG(r.rating_knowledge) AS knowledge,
              AVG(r.rating_professionalism) AS professionalism, AVG(r.rating_responsiveness) AS responsiveness
         FROM reviews r ${where.replace(/ AND NOT EXISTS[\s\S]*$/, "").replace(/ AND EXISTS[\s\S]*$/, "")}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM reviews r ${where.replace(/ AND NOT EXISTS[\s\S]*$/, "").replace(/ AND EXISTS[\s\S]*$/, "")}
        AND NOT EXISTS (SELECT 1 FROM review_responses rr WHERE rr.review_id = r.id)`,
      params
    ),
  ]);

  return {
    data: rows.map((row) => ({
      id: row.public_id,
      reviewer: { name: row.author_name },
      rating: num(row.rating),
      title: row.title,
      body: row.body,
      verified: bool(row.is_verified_transaction),
      helpfulCount: int(row.helpful_count) ?? 0,
      reviewedAt: isoDate(row.published_at || row.created_at),
      reviewedLabel: new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(
        new Date(row.published_at || row.created_at)
      ),
      response: { exists: Boolean(row.response_body), body: row.response_body, respondedAt: isoDate(row.response_created_at) },
      listing: row.listing_public_id
        ? {
            id: row.listing_public_id,
            title: row.listing_title,
            image: { src: row.cover_image_url, alt: row.listing_title },
            category: require_frontendCategoryId(row.root_category_id),
          }
        : null,
    })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    counts: {
      all: int(summary?.review_count) ?? 0,
      "needs-response": Number(needsResponse || 0),
      responded: (int(summary?.review_count) ?? 0) - Number(needsResponse || 0),
    },
    summary: {
      reviewCount: int(summary?.review_count) ?? 0,
      averageRating: summary?.rating_avg ? Number(Number(summary.rating_avg).toFixed(2)) : 0,
      needsResponseCount: Number(needsResponse || 0),
      ratingDistribution: {
        5: int(summary?.five) ?? 0,
        4: int(summary?.four) ?? 0,
        3: int(summary?.three) ?? 0,
        2: int(summary?.two) ?? 0,
        1: int(summary?.one) ?? 0,
      },
      insightScores: {
        communication: summary?.communication ? Number(Number(summary.communication).toFixed(1)) : 0,
        knowledge: summary?.knowledge ? Number(Number(summary.knowledge).toFixed(1)) : 0,
        professionalism: summary?.professionalism ? Number(Number(summary.professionalism).toFixed(1)) : 0,
        responsiveness: summary?.responsiveness ? Number(Number(summary.responsiveness).toFixed(1)) : 0,
      },
    },
  };
}

function emptyReviewSummary() {
  return {
    reviewCount: 0,
    averageRating: 0,
    needsResponseCount: 0,
    ratingDistribution: { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 },
    insightScores: { communication: 0, knowledge: 0, professionalism: 0, responsiveness: 0 },
  };
}

/* -------------------------------------------------------------------------- */
/* Favourites and saved searches                                               */
/* -------------------------------------------------------------------------- */

export async function listFavourites({ userId, search = "", category = "all", location = "all", sort = "recent", page = 1, pageSize = 12 }) {
  const conditions = ["f.user_id = ?", "l.deleted_at IS NULL"];
  const params = [userId];
  if (category !== "all") {
    const rootId = rootIdForFrontendCategory(category);
    if (rootId) {
      conditions.push("l.root_category_id = ?");
      params.push(rootId);
    }
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(l.title LIKE ? OR l.reference LIKE ?)");
    params.push(`%${term}%`, `%${term}%`);
  }
  if (location !== "all") {
    conditions.push("(ct.name = ? OR co.name = ? OR cm.name = ?)");
    params.push(location, location, location);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize }, 12);
  const orderBy = { recent: "f.created_at DESC", priceHigh: "l.price DESC", priceLow: "l.price ASC" }[sort] || "f.created_at DESC";

  const [rows, total, counts, locations] = await Promise.all([
    query(
      `SELECT f.created_at AS saved_at, f.notes, ${PORTAL_LISTING_COLUMNS}
         FROM favourites f JOIN listings l ON l.id = f.listing_id
         ${PORTAL_LISTING_JOINS.replace("JOIN categories", "JOIN categories")}
         ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM favourites f JOIN listings l ON l.id = f.listing_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id ${where}`,
      params
    ),
    query(
      `SELECT l.root_category_id, COUNT(*) AS count
         FROM favourites f JOIN listings l ON l.id = f.listing_id
        WHERE f.user_id = ? AND l.deleted_at IS NULL
        GROUP BY l.root_category_id`,
      [userId]
    ),
    query(
      `SELECT DISTINCT COALESCE(cm.name, ct.name, co.name) AS label
         FROM favourites f JOIN listings l ON l.id = f.listing_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
        WHERE f.user_id = ? AND l.deleted_at IS NULL
        LIMIT 40`,
      [userId]
    ),
  ]);

  const countsByCategory = { all: 0 };
  for (const row of counts) {
    const key = require_frontendCategoryId(row.root_category_id);
    if (!key) continue;
    countsByCategory[key] = Number(row.count);
    countsByCategory.all += Number(row.count);
  }

  return {
    data: rows.map((row) => ({ ...serializePortalListing(row), isFavourite: true, savedAt: isoDate(row.saved_at), notes: row.notes })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    countsByCategory,
    locations: locations.map((row) => row.label).filter(Boolean),
  };
}

export async function listSavedSearches({ userId }) {
  const rows = await query(
    `SELECT ss.id, ss.public_id, ss.name, ss.criteria, ss.canonical_url, ss.alerts_enabled,
            ss.alert_frequency, ss.last_result_count, ss.new_result_count, ss.created_at,
            c.name AS category_name, COALESCE(c.root_category_id, c.id) AS root_category_id,
            l.name AS location_name
       FROM saved_searches ss
       LEFT JOIN categories c ON c.id = ss.category_id
       LEFT JOIN locations l ON l.id = ss.location_id
      WHERE ss.user_id = ? AND ss.deleted_at IS NULL
      ORDER BY ss.created_at DESC
      LIMIT 100`,
    [userId]
  );
  return rows.map((row) => {
    const criteria = typeof row.criteria === "string" ? safeJson(row.criteria) : row.criteria || {};
    return {
      id: row.public_id,
      name: row.name,
      category: require_frontendCategoryId(row.root_category_id),
      categoryLabel: row.category_name,
      image: null,
      filterLabels: buildFilterLabels(criteria, row.location_name),
      criteria,
      resultCount: int(row.last_result_count) ?? 0,
      newResultCount: int(row.new_result_count) ?? 0,
      emailAlertsEnabled: bool(row.alerts_enabled),
      alertFrequency: row.alert_frequency,
      savedAt: new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(new Date(row.created_at)),
      savedAtIso: isoDate(row.created_at),
      resultUrl: row.canonical_url || "/search",
    };
  });
}

function safeJson(value) {
  try {
    return JSON.parse(value);
  } catch {
    return {};
  }
}

function buildFilterLabels(criteria, locationName) {
  const labels = [];
  if (locationName) labels.push(locationName);
  if (criteria.propertyType) labels.push(titleize(criteria.propertyType));
  if (criteria.make) labels.push(titleize(criteria.make));
  if (criteria.model) labels.push(titleize(criteria.model));
  if (criteria.minPrice || criteria.maxPrice) {
    const currency = criteria.currency || "AED";
    const min = criteria.minPrice ? compactMoney(criteria.minPrice) : null;
    const max = criteria.maxPrice ? compactMoney(criteria.maxPrice) : null;
    labels.push(min && max ? `${currency} ${min} – ${max}` : min ? `${currency} ${min}+` : `Up to ${currency} ${max}`);
  }
  if (criteria.bedrooms) labels.push(`${criteria.bedrooms}+ Beds`);
  if (criteria.yearMin || criteria.yearMax) labels.push([criteria.yearMin, criteria.yearMax].filter(Boolean).join(" – "));
  return labels.filter(Boolean).slice(0, 6);
}

function compactMoney(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) return String(value);
  if (amount >= 1_000_000) return `${(amount / 1_000_000).toFixed(amount % 1_000_000 === 0 ? 0 : 1)}M`;
  if (amount >= 1000) return `${(amount / 1000).toFixed(0)}K`;
  return String(amount);
}

/* -------------------------------------------------------------------------- */
/* Finance                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * Month-over-month change, or null when the comparison is meaningless — no previous
 * month, or a previous month of zero, which would make every change "infinite".
 */
function monthOverMonthPercent(thisMonth, lastMonth) {
  const current = Number(thisMonth) || 0;
  const previous = Number(lastMonth) || 0;
  if (!previous) return null;
  return Math.round(((current - previous) / previous) * 1000) / 10;
}

export async function listPayments({ accountId, search = "", from, to, status = "all", category = "all", page = 1, pageSize = 10 }) {
  const conditions = ["p.account_id = ?"];
  const params = [accountId];
  if (status !== "all") {
    conditions.push("p.status = ?");
    params.push(status);
  }
  if (category !== "all") {
    conditions.push("p.payment_type = ?");
    params.push(category);
  }
  if (from) {
    conditions.push("p.created_at >= ?");
    params.push(new Date(from));
  }
  if (to) {
    conditions.push("p.created_at <= ?");
    params.push(new Date(`${to}T23:59:59`));
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(p.reference LIKE ? OR p.provider_payment_id LIKE ? OR i.invoice_number LIKE ?)");
    params.push(`%${term}%`, `%${term}%`, `%${term}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT p.public_id, p.reference, p.amount, p.currency_code, p.status, p.payment_type,
              p.provider, p.paid_at, p.created_at, p.receipt_url, p.fee_amount, p.net_amount,
              i.invoice_number, pm.brand AS method_brand, pm.last_four AS method_last4, pm.method_type
         FROM payments p
         LEFT JOIN invoices i ON i.id = p.invoice_id
         LEFT JOIN payment_methods pm ON pm.id = p.payment_method_id
         ${where}
        ORDER BY p.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM payments p LEFT JOIN invoices i ON i.id = p.invoice_id ${where}`, params),
    queryOne(
      // `pending_count` and `last_month` exist because the payments screen printed
      // "5 payments pending" and "+12.6% vs last month" as literals — neither came
      // from anywhere. A comparison needs the previous month to compare against.
      `SELECT COALESCE(SUM(CASE WHEN status = 'succeeded' THEN amount_base END), 0) AS received,
              COALESCE(SUM(CASE WHEN status IN ('pending','processing') THEN amount_base END), 0) AS pending,
              COUNT(CASE WHEN status IN ('pending','processing') THEN 1 END) AS pending_count,
              COALESCE(SUM(CASE WHEN status = 'succeeded' AND paid_at >= DATE_FORMAT(NOW(), '%Y-%m-01') THEN amount_base END), 0) AS this_month,
              COALESCE(SUM(CASE WHEN status = 'succeeded'
                                 AND paid_at >= DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m-01')
                                 AND paid_at <  DATE_FORMAT(NOW(), '%Y-%m-01') THEN amount_base END), 0) AS last_month,
              COUNT(*) AS transactions
         FROM payments WHERE account_id = ?`,
      [accountId]
    ),
  ]);

  const data = rows.map((row) => ({
    id: row.public_id,
    transactionId: row.reference,
    title: row.invoice_number ? `Invoice ${row.invoice_number}` : titleize(row.payment_type || "payment"),
    description: row.provider ? `Processed by ${titleize(row.provider)}` : null,
    category: row.payment_type,
    amount: num(row.amount),
    currency: row.currency_code,
    amountFormatted: formatMoney({ amount: num(row.amount), currency: row.currency_code }),
    feeAmount: num(row.fee_amount),
    netAmount: num(row.net_amount),
    status: row.status,
    paymentMethod: { brand: row.method_brand, last4: row.method_last4, type: row.method_type },
    receiptUrl: row.receipt_url,
    occurredAt: isoDate(row.paid_at || row.created_at),
    occurredLabel: new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(
      new Date(row.paid_at || row.created_at)
    ),
    client: { name: null },
    listing: null,
  }));

  return {
    data,
    exportRows: data,
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    summary: {
      totalReceived: formatMoney({ amount: num(summary?.received) ?? 0, currency: "AED" }),
      pending: formatMoney({ amount: num(summary?.pending) ?? 0, currency: "AED" }),
      pendingCount: int(summary?.pending_count) ?? 0,
      thisMonth: formatMoney({ amount: num(summary?.this_month) ?? 0, currency: "AED" }),
      lastMonth: formatMoney({ amount: num(summary?.last_month) ?? 0, currency: "AED" }),
      // Null rather than 0% when there is no previous month to compare against:
      // a percentage against nothing is not a comparison.
      thisMonthChangePercent: monthOverMonthPercent(num(summary?.this_month), num(summary?.last_month)),
      transactions: int(summary?.transactions) ?? 0,
    },
  };
}

export async function accountBilling({ accountId, page = 1, pageSize = 5 }) {
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize }, 5);
  const [subscription, plans, invoices, invoiceTotal, seatsUsed] = await Promise.all([
    queryOne(
      `SELECT s.public_id, s.status, s.amount, s.currency_code, s.billing_interval,
              s.current_period_start, s.current_period_end, s.auto_renew,
              s.listing_quota, s.listing_used, s.featured_quota, s.featured_used,
              p.name AS plan_name, p.code AS plan_code, p.tier, p.agent_seat_quota, p.lead_quota
         FROM subscriptions s JOIN plans p ON p.id = s.plan_id
        WHERE s.account_id = ? AND s.status IN ('trialing','active','past_due')
        ORDER BY s.id DESC LIMIT 1`,
      [accountId]
    ),
    query(
      `SELECT public_id, code, name, description, tier, billing_interval, listing_quota,
              featured_quota, agent_seat_quota, lead_quota
         FROM plans WHERE is_active = 1 AND is_public = 1 ORDER BY sort_order ASC`,
      []
    ),
    query(
      // The Billing History table has a Plan column. Invoices carry a subscription, so
      // the plan is knowable; without this join the column rendered blank on every row.
      `SELECT i.public_id, i.invoice_number, i.status, i.total, i.currency_code, i.issued_at,
              i.due_at, i.paid_at, i.pdf_url, p.name AS plan_name
         FROM invoices i
         LEFT JOIN subscriptions s ON s.id = i.subscription_id
         LEFT JOIN plans p ON p.id = s.plan_id
        WHERE i.account_id = ? ORDER BY i.issued_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      [accountId]
    ),
    queryValue("SELECT COUNT(*) FROM invoices WHERE account_id = ?", [accountId]),
    // Seats in use. The Billing screen shows a "Team Members" meter against the plan's
    // `agent_seat_quota`; nothing was ever published for it, so the row read
    // `undefined.used` and the whole screen threw.
    queryValue(
      "SELECT COUNT(*) FROM account_members WHERE account_id = ? AND status = 'active'",
      [accountId]
    ),
  ]);

  const planPrices = await planPricing(plans.map((plan) => plan.public_id));

  return {
    currentPlan: subscription
      ? {
          id: subscription.public_id,
          name: subscription.plan_name,
          code: subscription.plan_code,
          tier: subscription.tier,
          status: subscription.status,
          price: num(subscription.amount),
          currency: subscription.currency_code,
          priceFormatted: formatMoney({ amount: num(subscription.amount), currency: subscription.currency_code }),
          interval: subscription.billing_interval,
          nextBillingDate: isoDay(subscription.current_period_end),
          nextBillingLabel: subscription.current_period_end
            ? new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(
                new Date(subscription.current_period_end)
              )
            : null,
          autoRenew: bool(subscription.auto_renew),
          benefits: [
            subscription.listing_quota ? `${subscription.listing_quota} listings` : "Unlimited listings",
            subscription.featured_quota ? `${subscription.featured_quota} featured slots` : null,
            subscription.agent_seat_quota ? `${subscription.agent_seat_quota} agent seats` : null,
            subscription.lead_quota ? `${subscription.lead_quota} leads / month` : null,
          ].filter(Boolean),
        }
      : null,
    usage: subscription
      ? {
          listings: {
            used: int(subscription.listing_used) ?? 0,
            limit: int(subscription.listing_quota) ?? 0,
            percent: subscription.listing_quota
              ? Math.round(((int(subscription.listing_used) ?? 0) / int(subscription.listing_quota)) * 100)
              : 0,
          },
          featured: {
            used: int(subscription.featured_used) ?? 0,
            limit: int(subscription.featured_quota) ?? 0,
            percent: subscription.featured_quota
              ? Math.round(((int(subscription.featured_used) ?? 0) / int(subscription.featured_quota)) * 100)
              : 0,
          },
          teamMembers: {
            used: int(seatsUsed) ?? 0,
            limit: int(subscription.agent_seat_quota) ?? 0,
            percent: subscription.agent_seat_quota
              ? Math.round(((int(seatsUsed) ?? 0) / int(subscription.agent_seat_quota)) * 100)
              : 0,
          },
        }
      : {},
    plans: plans.map((plan) => ({
      id: plan.public_id,
      code: plan.code,
      name: plan.name,
      description: plan.description,
      tier: plan.tier,
      interval: plan.billing_interval,
      price: planPrices.get(plan.public_id)?.amount ?? null,
      currency: planPrices.get(plan.public_id)?.currency ?? "AED",
      priceFormatted: planPrices.get(plan.public_id)
        ? formatMoney(planPrices.get(plan.public_id))
        : null,
      benefits: [
        plan.listing_quota ? `${plan.listing_quota} listings` : "Unlimited listings",
        plan.featured_quota ? `${plan.featured_quota} featured slots` : null,
        plan.agent_seat_quota ? `${plan.agent_seat_quota} agent seats` : null,
        plan.lead_quota ? `${plan.lead_quota} leads / month` : null,
      ].filter(Boolean),
      current: subscription?.plan_code === plan.code,
    })),
    billingHistory: {
      data: invoices.map((invoice) => ({
        id: invoice.public_id,
        number: invoice.invoice_number,
        planName: invoice.plan_name,
        status: invoice.status,
        amount: num(invoice.total),
        currency: invoice.currency_code,
        amountFormatted: formatMoney({ amount: num(invoice.total), currency: invoice.currency_code }),
        date: isoDay(invoice.issued_at),
        dateLabel: invoice.issued_at
          ? new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(new Date(invoice.issued_at))
          : null,
        dueAt: isoDay(invoice.due_at),
        paidAt: isoDay(invoice.paid_at),
        pdfUrl: invoice.pdf_url,
      })),
      pageInfo: {
        page: safePage,
        pageSize: safeSize,
        total: Number(invoiceTotal || 0),
        totalPages: Math.max(1, Math.ceil(Number(invoiceTotal || 0) / safeSize)),
      },
    },
  };
}

async function planPricing(publicIds) {
  if (!publicIds.length) return new Map();
  const rows = await query(
    `SELECT p.public_id, pp.amount, pp.currency_code
       FROM plans p
       LEFT JOIN plan_prices pp ON pp.plan_id = p.id AND pp.is_active = 1
      WHERE p.public_id IN (${publicIds.map(() => "?").join(", ")})`,
    publicIds
  ).catch(() => []);
  return new Map(rows.filter((row) => row.amount !== null).map((row) => [row.public_id, { amount: num(row.amount), currency: row.currency_code }]));
}

export async function accountPayouts({ accountId, page = 1, pageSize = 10 }) {
  const { page: safePage, pageSize: safeSize, offset } = paginate({ page, pageSize });
  const [rows, total, summary, method] = await Promise.all([
    query(
      `SELECT po.public_id, po.reference, po.gross_amount, po.fee_amount, po.net_amount,
              po.currency_code, po.status, po.period_start, po.period_end, po.scheduled_for,
              po.paid_at, po.statement_url, pm.method_type,
              COALESCE(pm.bank_name, pm.account_holder_name) AS display_name,
              pm.account_last_four AS last4
         FROM payouts po
         LEFT JOIN payout_methods pm ON pm.id = po.payout_method_id
        WHERE po.account_id = ?
        ORDER BY po.scheduled_for DESC LIMIT ${safeSize} OFFSET ${offset}`,
      [accountId]
    ),
    queryValue("SELECT COUNT(*) FROM payouts WHERE account_id = ?", [accountId]),
    queryOne(
      `SELECT COALESCE(SUM(CASE WHEN status = 'paid' THEN net_amount_base END), 0) AS total_paid,
              COALESCE(SUM(CASE WHEN status IN ('pending','scheduled','processing') THEN net_amount_base END), 0) AS pending,
              MIN(CASE WHEN status IN ('pending','scheduled') THEN scheduled_for END) AS next_date
         FROM payouts WHERE account_id = ?`,
      [accountId]
    ),
    queryOne(
      `SELECT method_type, COALESCE(bank_name, account_holder_name) AS display_name,
              account_last_four AS last4, is_default, status
         FROM payout_methods
        WHERE account_id = ? AND status <> 'removed'
        ORDER BY is_default DESC, id DESC LIMIT 1`,
      [accountId]
    ),
  ]);

  return {
    summary: {
      availableBalance: { amount: 0, currency: "AED", formatted: formatMoney({ amount: 0, currency: "AED" }) },
      pendingPayout: {
        amount: num(summary?.pending) ?? 0,
        currency: "AED",
        formatted: formatMoney({ amount: num(summary?.pending) ?? 0, currency: "AED" }),
      },
      totalPaid: {
        amount: num(summary?.total_paid) ?? 0,
        currency: "AED",
        formatted: formatMoney({ amount: num(summary?.total_paid) ?? 0, currency: "AED" }),
      },
      nextPayout: {
        date: isoDay(summary?.next_date),
        dateLabel: summary?.next_date
          ? new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(new Date(summary.next_date))
          : "Not scheduled",
        // The card prints "{daysRemaining} days remaining" beneath the date. Without the field
        // it rendered "undefined days remaining"; with no scheduled payout it is null and the
        // card says so instead.
        daysRemaining: summary?.next_date
          ? Math.max(0, Math.ceil((new Date(summary.next_date).getTime() - Date.now()) / 86_400_000))
          : null,
      },
    },
    payoutMethod: method
      ? { type: method.method_type, displayName: method.display_name, last4: method.last4, isDefault: bool(method.is_default) }
      : null,
    schedule: { nextDate: isoDay(summary?.next_date), nextDateLabel: null, frequency: "monthly" },
    history: {
      data: rows.map((row) => ({
        id: row.public_id,
        reference: row.reference,
        grossAmount: num(row.gross_amount),
        feeAmount: num(row.fee_amount),
        amount: num(row.net_amount),
        currency: row.currency_code,
        amountFormatted: formatMoney({ amount: num(row.net_amount), currency: row.currency_code }),
        status: row.status,
        periodStart: isoDay(row.period_start),
        periodEnd: isoDay(row.period_end),
        date: isoDay(row.paid_at || row.scheduled_for),
        dateLabel: (row.paid_at || row.scheduled_for)
          ? new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(
              new Date(row.paid_at || row.scheduled_for)
            )
          : null,
        method: { type: row.method_type, displayName: row.display_name, last4: row.last4 },
        statementUrl: row.statement_url,
      })),
      pageInfo: {
        page: safePage,
        pageSize: safeSize,
        total: Number(total || 0),
        totalPages: Math.max(1, Math.ceil(Number(total || 0) / safeSize)),
      },
    },
  };
}

export { require_frontendCategoryId as frontendCategoryIdFor, paginate, scopeClause };
