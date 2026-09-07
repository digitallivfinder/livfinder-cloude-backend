import {
  query, queryOne, queryValue, adminPagination, adminList, int, num, bool, isoDate,
  frontendCategoryId, categoryIdsFor, rootIdFor,
} from "./admin.shared.js";
import * as options from "./admin.options.js";
import { adminListingStatus } from "./admin.dashboard.js";

/**
 * Admin CRM reads: leads and contacts.
 *
 * These map onto the existing `leads`/`crm_contacts` pipeline tables — there is
 * no separate admin lead store.
 */
export async function listAdminLeads({
  category = "real-estate",
  status = "all",
  search = "",
  inquiryType = "",
  source = "",
  agent = "",
  property = "",
  community = "",
  sort = "newest",
  page = 1,
  pageSize = 10,
} = {}) {
  const rootId = rootIdFor(category);
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];

  if (rootId) {
    conditions.push("l.root_category_id = ?");
    params.push(rootId);
  }
  if (status !== "all") {
    conditions.push("l.status = ?");
    params.push(status);
  }
  if (inquiryType) {
    conditions.push("l.intent = ?");
    params.push(inquiryType);
  }
  if (source) {
    conditions.push("src.code = ?");
    params.push(source);
  }
  if (agent) {
    conditions.push("ag.public_id = ?");
    params.push(agent);
  }
  if (property) {
    conditions.push("li.public_id = ?");
    params.push(property);
  }
  if (community) {
    conditions.push("cm.slug = ?");
    params.push(community);
  }
  if (search) {
    conditions.push("(l.reference LIKE ? OR l.name LIKE ? OR l.email LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ? OR li.title LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });
  const orderBy = sort === "oldest" ? "l.created_at ASC" : "l.created_at DESC";

  const joins = `
     LEFT JOIN crm_contacts c ON c.id = l.contact_id
     LEFT JOIN lead_sources src ON src.id = l.source_id
     LEFT JOIN lead_pipeline_stages st ON st.id = l.stage_id
     LEFT JOIN agents ag ON ag.id = l.owner_agent_id
     LEFT JOIN listings li ON li.id = l.primary_listing_id
     LEFT JOIN locations cm ON cm.id = li.community_id
     LEFT JOIN locations ct ON ct.id = li.city_id`;

  const [rows, total, summary, options] = await Promise.all([
    query(
      `SELECT l.id, l.public_id, l.reference, l.status, l.priority, l.score, l.intent,
              l.timeframe, l.budget_min, l.budget_max, l.currency_code, l.created_at,
              l.last_activity_at, l.next_action_at, l.root_category_id,
              c.public_id AS contact_public_id, c.first_name, c.last_name,
              c.primary_email, c.primary_phone_e164,
              COALESCE(c.display_name, l.name) AS contact_name,
              src.name AS source_name, src.code AS source_code,
              st.name AS stage_name,
              ag.public_id AS agent_public_id, ag.display_name AS agent_name, ag.photo_url AS agent_photo,
              li.public_id AS listing_public_id, li.reference AS listing_reference,
              li.title AS listing_title, li.price AS listing_price, li.currency_code AS listing_currency,
              li.cover_image_url AS listing_image, li.status AS listing_status,
              cm.name AS community_name, cm.slug AS community_slug, ct.name AS city_name
         FROM leads l ${joins} ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM leads l ${joins} ${where}`, params),
    leadSummary(rootId),
    leadOptions(rootId),
  ]);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      leadId: String(row.id),
      reference: row.reference,
      status: row.status,
      priority: row.priority,
      score: int(row.score),
      inquiryType: row.intent,
      timeframe: row.timeframe,
      category: frontendCategoryId(row.root_category_id),
      source: row.source_name,
      sourceCode: row.source_code,
      stage: row.stage_name,
      price: row.listing_price ? `${row.listing_currency} ${Math.round(num(row.listing_price)).toLocaleString("en")}` : null,
      budget: { min: num(row.budget_min), max: num(row.budget_max), currency: row.currency_code },
      inquiryAt: isoDate(row.created_at),
      lastActivityAt: isoDate(row.last_activity_at),
      nextActionAt: isoDate(row.next_action_at),
      contactId: row.contact_public_id,
      contact: {
        id: row.contact_public_id,
        firstName: row.first_name,
        lastName: row.last_name,
        name: row.contact_name,
        primaryEmail: row.primary_email,
        primaryPhone: row.primary_phone_e164,
      },
      propertyId: row.listing_public_id,
      property: row.listing_public_id
        ? {
            id: row.listing_public_id,
            reference: row.listing_reference,
            title: row.listing_title,
            image: row.listing_image,
            status: adminListingStatus(row.listing_status),
            community: row.community_slug,
            location: [row.community_name, row.city_name].filter(Boolean).join(", "),
          }
        : null,
      agentId: row.agent_public_id,
      agent: row.agent_public_id
        ? { id: row.agent_public_id, name: row.agent_name, role: "Agent", image: row.agent_photo }
        : null,
      community: row.community_slug,
      location: [row.community_name, row.city_name].filter(Boolean).join(", "),
      title: row.listing_title,
      name: row.contact_name,
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary,
    options,
    options: await leadFilterOptions(),
  });
}

async function leadSummary(rootId) {
  // `leads.status` is the coarse open/won/lost outcome; the working state a
  // pipeline screen shows lives in `stage_type`. The summary reports both, and
  // the tab counts read the same rows the tabs then list.
  const row = await queryOne(
    `SELECT COUNT(*) AS total,
            SUM(l.status = 'open') AS open_count,
            SUM(l.status = 'won') AS won,
            SUM(l.status = 'lost') AS lost,
            SUM(l.status = 'disqualified') AS disqualified,
            SUM(l.status = 'archived') AS archived,
            SUM(l.status = 'open' AND s.stage_type = 'new') AS new_count,
            SUM(l.status = 'open' AND s.stage_type IN ('contacted','nurturing')) AS working,
            SUM(l.status = 'open' AND s.stage_type = 'qualified') AS qualified,
            SUM(l.status = 'open' AND s.stage_type IN ('proposal','negotiation')) AS viewing
       FROM leads l
       LEFT JOIN lead_pipeline_stages s ON s.id = l.stage_id
      WHERE l.deleted_at IS NULL${rootId ? " AND l.root_category_id = ?" : ""}`,
    rootId ? [rootId] : []
  );
  return {
    total: int(row?.total) ?? 0,
    all: int(row?.total) ?? 0,
    open: int(row?.open_count) ?? 0,
    new: int(row?.new_count) ?? 0,
    working: int(row?.working) ?? 0,
    qualified: int(row?.qualified) ?? 0,
    viewing: int(row?.viewing) ?? 0,
    won: int(row?.won) ?? 0,
    converted: int(row?.won) ?? 0,
    lost: int(row?.lost) ?? 0,
    disqualified: int(row?.disqualified) ?? 0,
    unqualified: int(row?.disqualified) ?? 0,
    archived: int(row?.archived) ?? 0,
    dormant: int(row?.archived) ?? 0,
    // The Leads screen's five metric tiles read total / new / qualified / follow-up / closed.
    // "follow-up" is the hyphenated key it asks for; without it the tile rendered NaN.
    "follow-up": int(row?.working) ?? 0,
    followUp: int(row?.working) ?? 0,
    closed: (int(row?.won) ?? 0) + (int(row?.lost) ?? 0) + (int(row?.disqualified) ?? 0),
  };
}

async function leadOptions(rootId) {
  const [sources, stages, agents, communities] = await Promise.all([
    query("SELECT code, name FROM lead_sources WHERE is_active = 1 ORDER BY name LIMIT 100").catch(() => []),
    query("SELECT id, name FROM lead_pipeline_stages ORDER BY sort_order LIMIT 100").catch(() => []),
    query(
      `SELECT DISTINCT ag.public_id, ag.display_name FROM agents ag
         JOIN leads l ON l.owner_agent_id = ag.id
        WHERE ag.deleted_at IS NULL${rootId ? " AND l.root_category_id = ?" : ""}
        ORDER BY ag.display_name LIMIT 200`,
      rootId ? [rootId] : []
    ),
    query(
      `SELECT DISTINCT cm.slug, cm.name FROM locations cm
         JOIN listings li ON li.community_id = cm.id
         JOIN leads l ON l.primary_listing_id = li.id
        WHERE cm.deleted_at IS NULL${rootId ? " AND l.root_category_id = ?" : ""}
        ORDER BY cm.name LIMIT 200`,
      rootId ? [rootId] : []
    ),
  ]);
  return {
    sources: sources.map((row) => ({ value: row.code, label: row.name })),
    stages: stages.map((row) => ({ value: String(row.id), label: row.name })),
    agents: agents.map((row) => ({ id: row.public_id, value: row.public_id, label: row.display_name, name: row.display_name })),
    communities: communities.map((row) => row.slug),
  };
}

export async function getAdminLead(identifier) {
  const row = await queryOne(
    `SELECT l.* FROM leads l WHERE (l.public_id = ? OR l.reference = ?) AND l.deleted_at IS NULL LIMIT 1`,
    [identifier, identifier]
  );
  if (!row) return null;

  const list = await listAdminLeads({ category: null, pageSize: 1, page: 1, search: row.reference });
  const base = list.items[0];
  if (!base) return null;

  const [activities, stageHistory, otherContactLeads, otherListingInquiries, requirements] = await Promise.all([
    query(
      `SELECT public_id, activity_type, subject, body, occurred_at, created_by_user_id,
              (SELECT display_name FROM users u WHERE u.id = activities.created_by_user_id) AS actor_name
         FROM activities WHERE lead_id = ? ORDER BY occurred_at DESC LIMIT 50`,
      [row.id]
    ).catch(() => []),
    query(
      `SELECT h.changed_at, h.note, f.name AS from_stage, t.name AS to_stage,
              u.display_name AS actor_name
         FROM lead_stage_history h
         LEFT JOIN lead_pipeline_stages f ON f.id = h.from_stage_id
         LEFT JOIN lead_pipeline_stages t ON t.id = h.to_stage_id
         LEFT JOIN users u ON u.id = h.changed_by_user_id
        WHERE h.lead_id = ? ORDER BY h.changed_at DESC LIMIT 50`,
      [row.id]
    ).catch(() => []),
    row.contact_id
      ? query(
          `SELECT l.public_id, l.reference, l.status, l.created_at,
                  li.public_id AS listing_public_id, li.title AS listing_title
             FROM leads l LEFT JOIN listings li ON li.id = l.primary_listing_id
            WHERE l.contact_id = ? AND l.id <> ? AND l.deleted_at IS NULL
            ORDER BY l.created_at DESC LIMIT 20`,
          [row.contact_id, row.id]
        )
      : Promise.resolve([]),
    row.primary_listing_id
      ? query(
          `SELECT i.public_id, i.name, i.email, i.message, i.status, i.created_at
             FROM inquiries i WHERE i.listing_id = ? AND i.deleted_at IS NULL
            ORDER BY i.created_at DESC LIMIT 20`,
          [row.primary_listing_id]
        )
      : Promise.resolve([]),
    query("SELECT * FROM lead_requirements WHERE lead_id = ? LIMIT 5", [row.id]).catch(() => []),
  ]);

  return {
    ...base,
    notes: row.notes,
    lostNote: row.lost_note,
    activities: activities.map((activity) => ({
      id: activity.public_id,
      type: activity.activity_type,
      title: activity.subject,
      body: activity.body,
      actorName: activity.actor_name,
      at: isoDate(activity.occurred_at),
    })),
    stageHistory: stageHistory.map((entry) => ({
      from: entry.from_stage,
      to: entry.to_stage,
      note: entry.note,
      actorName: entry.actor_name,
      at: isoDate(entry.changed_at),
    })),
    otherContactLeads: otherContactLeads.map((entry) => ({
      id: entry.public_id,
      reference: entry.reference,
      status: entry.status,
      propertyId: entry.listing_public_id,
      property: { id: entry.listing_public_id, title: entry.listing_title },
      inquiryAt: isoDate(entry.created_at),
    })),
    otherListingInquiries: otherListingInquiries.map((entry) => ({
      id: entry.public_id,
      contact: { name: entry.name, primaryEmail: entry.email },
      message: entry.message,
      status: entry.status,
      inquiryAt: isoDate(entry.created_at),
    })),
    requirements: requirements.map((requirement) => ({ ...requirement })),
  };
}

/* -------------------------------------------------------------------------- */
/* Contacts                                                                    */
/* -------------------------------------------------------------------------- */

export async function listAdminContacts({
  category = "real-estate",
  status = "all",
  search = "",
  source = "",
  country = "",
  page = 1,
  pageSize = 10,
} = {}) {
  const rootId = rootIdFor(category);
  const conditions = ["c.deleted_at IS NULL"];
  const params = [];
  const joins = [
    "LEFT JOIN lead_sources src ON src.id = c.source_id",
    "LEFT JOIN locations co ON co.id = c.country_id",
  ];

  if (rootId) {
    joins.push("JOIN leads cl ON cl.contact_id = c.id AND cl.root_category_id = ? AND cl.deleted_at IS NULL");
    params.push(rootId);
  }
  if (status !== "all") {
    conditions.push("c.lifecycle_stage = ?");
    params.push(status);
  }
  if (source) {
    conditions.push("src.code = ?");
    params.push(source);
  }
  if (country) {
    conditions.push("co.slug = ?");
    params.push(country);
  }
  if (search) {
    conditions.push("(c.first_name LIKE ? OR c.last_name LIKE ? OR c.primary_email LIKE ? OR c.primary_phone_e164 LIKE ? OR c.public_id = ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`, search);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary, options] = await Promise.all([
    query(
      `SELECT DISTINCT c.id, c.public_id, c.first_name, c.last_name, c.display_name,
              c.primary_email, c.primary_phone_e164, c.company_name, c.job_title,
              c.lifecycle_stage, c.contact_type, c.lead_count, c.deal_count, c.activity_count,
              c.last_activity_at, c.last_contacted_at, c.created_at, c.notes,
              c.allow_email, c.allow_sms, c.allow_call, c.allow_whatsapp, c.is_vip,
              src.name AS source_name, src.code AS source_code,
              co.name AS country_name, co.slug AS country_slug,
              lang.name AS language_name
         FROM crm_contacts c
         ${joins.join("\n")}
         LEFT JOIN languages lang ON lang.id = c.preferred_language_id
         ${where}
        ORDER BY c.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(DISTINCT c.id) FROM crm_contacts c ${joins.join("\n")} ${where}`, params),
    contactSummary(rootId),
    contactOptions(),
  ]);

  const ids = rows.map((row) => row.id);
  const interests = ids.length
    ? await query(
        `SELECT contact_id, root_category_id FROM leads
          WHERE contact_id IN (${ids.map(() => "?").join(", ")}) AND deleted_at IS NULL
          GROUP BY contact_id, root_category_id`,
        ids
      )
    : [];
  const byContact = interests.reduce((map, row) => {
    const list = map.get(String(row.contact_id)) || [];
    list.push(row.root_category_id);
    map.set(String(row.contact_id), list);
    return map;
  }, new Map());

  const leadRows = ids.length
    ? await query(
        `SELECT l.contact_id, l.public_id, l.reference, l.status AS status_label, l.created_at,
                st.name AS stage_label,
                li.public_id AS listing_public_id, li.reference AS listing_reference, li.title AS listing_title
           FROM leads l
           LEFT JOIN lead_pipeline_stages st ON st.id = l.stage_id
           LEFT JOIN listings li ON li.id = l.primary_listing_id
          WHERE l.contact_id IN (${ids.map(() => "?").join(", ")}) AND l.deleted_at IS NULL
          ORDER BY l.created_at DESC`,
        ids
      )
    : [];
  const leadsByContact = leadRows.reduce((map, row) => {
    const list = map.get(String(row.contact_id)) || [];
    list.push(row);
    map.set(String(row.contact_id), list);
    return map;
  }, new Map());

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      contactId: String(row.id),
      reference: `CT-${String(row.id).padStart(6, "0")}`,
      firstName: row.first_name,
      lastName: row.last_name,
      displayName: row.display_name,
      // The contacts table renders `name` and iterates `leads`. Both are supplied here rather
      // than the view reaching for `displayName` and rebuilding a lead list, so one serializer
      // owns the shape the screen was written against.
      name: row.display_name || `${row.first_name ?? ""} ${row.last_name ?? ""}`.trim() || row.primary_email || "Unknown",
      primaryEmail: row.primary_email,
      secondaryEmail: null,
      primaryPhone: row.primary_phone_e164,
      secondaryPhone: null,
      company: row.company_name,
      jobTitle: row.job_title,
      status: row.lifecycle_stage,
      accountType: row.contact_type,
      source: row.source_name,
      sourceCode: row.source_code,
      country: row.country_name,
      countrySlug: row.country_slug,
      language: row.language_name,
      notes: row.notes,
      isVip: bool(row.is_vip),
      communicationPreference: {
        email: bool(row.allow_email),
        sms: bool(row.allow_sms),
        call: bool(row.allow_call),
        whatsapp: bool(row.allow_whatsapp),
      },
      preferredContactMethod: bool(row.allow_whatsapp) ? "whatsapp" : bool(row.allow_call) ? "phone" : "email",
      interestedCategories: (byContact.get(String(row.id)) || [])
        .map((rootCategoryId) => frontendCategoryId(rootCategoryId))
        .filter(Boolean),
      leadStats: { total: int(row.lead_count) ?? 0, deals: int(row.deal_count) ?? 0 },
      // The table counts open leads and distinct listings from this array, so it has to be
      // present even when the contact has none — `[]`, never undefined.
      leads: (leadsByContact.get(String(row.id)) || []).map((lead) => ({
        id: lead.public_id,
        reference: lead.reference,
        stage: lead.stage_label,
        status: lead.status_label,
        listing: { id: lead.listing_public_id ?? null, reference: lead.listing_reference ?? null, title: lead.listing_title ?? null },
        createdAt: isoDate(lead.created_at),
      })),
      listingStats: { inquiries: int(row.activity_count) ?? 0 },
      multipleListingInquiries: (int(row.lead_count) ?? 0) > 1,
      createdAt: isoDate(row.created_at),
      lastActivityAt: isoDate(row.last_activity_at),
      lastInquiryAt: isoDate(row.last_contacted_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary,
    options,
    options: await contactFilterOptions(),
  });
}

async function contactSummary(rootId) {
  const row = await queryOne(
    `SELECT COUNT(DISTINCT c.id) AS total,
            SUM(c.created_at >= DATE_FORMAT(NOW(), '%Y-%m-01')) AS newThisMonth,
            SUM(c.lifecycle_stage IN ('lead','opportunity','customer')) AS active,
            SUM(c.lead_count > 1) AS multipleListingInquiries
       FROM crm_contacts c
       ${rootId ? "JOIN leads cl ON cl.contact_id = c.id AND cl.root_category_id = ?" : ""}
      WHERE c.deleted_at IS NULL`,
    rootId ? [rootId] : []
  );
  const statuses = await query(
    `SELECT c.lifecycle_stage AS value, COUNT(DISTINCT c.id) AS count
       FROM crm_contacts c
       ${rootId ? "JOIN leads cl ON cl.contact_id = c.id AND cl.root_category_id = ?" : ""}
      WHERE c.deleted_at IS NULL GROUP BY c.lifecycle_stage`,
    rootId ? [rootId] : []
  );
  return {
    total: int(row?.total) ?? 0,
    newThisMonth: int(row?.newThisMonth) ?? 0,
    active: int(row?.active) ?? 0,
    multipleListingInquiries: int(row?.multipleListingInquiries) ?? 0,
    // The Contacts view reads these two names; they are the same figures under
    // the labels that screen uses.
    activeLeads: int(row?.active) ?? 0,
    multiple: int(row?.multipleListingInquiries) ?? 0,
    statuses: Object.fromEntries(statuses.map((entry) => [entry.value, Number(entry.count)])),
  };
}

async function contactOptions() {
  const [sources, countries] = await Promise.all([
    query("SELECT DISTINCT s.code, s.name FROM lead_sources s ORDER BY s.name LIMIT 100").catch(() => []),
    query(
      `SELECT DISTINCT co.slug, co.name FROM locations co
         JOIN crm_contacts c ON c.country_id = co.id
        ORDER BY co.name LIMIT 250`
    ),
  ]);
  return {
    sources: sources.map((row) => row.name),
    countries: countries.map((row) => row.name),
  };
}

export async function getAdminContact(identifier) {
  const row = await queryOne(
    "SELECT id, public_id FROM crm_contacts WHERE public_id = ? AND deleted_at IS NULL LIMIT 1",
    [identifier]
  );
  if (!row) return null;
  const list = await listAdminContacts({ category: null, pageSize: 1, search: identifier });
  const base = list.items[0];
  if (!base) return null;

  const [leads, inquiries, activities, listings] = await Promise.all([
    query(
      `SELECT l.public_id, l.reference, l.status, l.created_at, li.title AS listing_title,
              li.public_id AS listing_public_id
         FROM leads l LEFT JOIN listings li ON li.id = l.primary_listing_id
        WHERE l.contact_id = ? AND l.deleted_at IS NULL ORDER BY l.created_at DESC LIMIT 50`,
      [row.id]
    ),
    query(
      `SELECT i.public_id, i.message, i.status, i.created_at, l.title AS listing_title, l.public_id AS listing_public_id
         FROM inquiries i LEFT JOIN listings l ON l.id = i.listing_id
        WHERE i.email = (SELECT primary_email FROM crm_contacts WHERE id = ?) AND i.deleted_at IS NULL
        ORDER BY i.created_at DESC LIMIT 50`,
      [row.id]
    ),
    query(
      `SELECT public_id, activity_type, subject, body, occurred_at FROM activities
        WHERE contact_id = ? ORDER BY occurred_at DESC LIMIT 50`,
      [row.id]
    ).catch(() => []),
    query(
      `SELECT DISTINCT li.public_id, li.reference, li.title, li.status, li.cover_image_url
         FROM leads l JOIN listings li ON li.id = l.primary_listing_id
        WHERE l.contact_id = ? LIMIT 50`,
      [row.id]
    ),
  ]);

  return {
    ...base,
    leads: leads.map((lead) => ({
      id: lead.public_id,
      reference: lead.reference,
      status: lead.status,
      listingTitle: lead.listing_title,
      listingId: lead.listing_public_id,
      createdAt: isoDate(lead.created_at),
    })),
    inquiries: inquiries.map((inquiry) => ({
      id: inquiry.public_id,
      message: inquiry.message,
      status: inquiry.status,
      listingTitle: inquiry.listing_title,
      listingId: inquiry.listing_public_id,
      createdAt: isoDate(inquiry.created_at),
    })),
    activities: activities.map((activity) => ({
      id: activity.public_id,
      type: activity.activity_type,
      title: activity.subject,
      body: activity.body,
      at: isoDate(activity.occurred_at),
    })),
    listings: listings.map((listing) => ({
      id: listing.public_id,
      reference: listing.reference,
      title: listing.title,
      status: adminListingStatus(listing.status),
      image: listing.cover_image_url,
    })),
    relatedListingIds: listings.map((listing) => listing.public_id),
  };
}

/* -------------------------------------------------------------------------- */
/* Filter options                                                              */
/* -------------------------------------------------------------------------- */

/**
 * Selects above the Leads table. `properties` and `contacts` are the two
 * "link this lead to something" pickers, so both are capped — a full contact
 * list would be tens of thousands of rows in a dropdown.
 */
async function leadFilterOptions() {
  const [agents, communities, properties, contacts, sources] = await Promise.all([
    options.agents(),
    options.communities(),
    query(
      `SELECT public_id, title FROM listings
        WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 300`
    ).catch(() => []),
    query(
      `SELECT public_id, COALESCE(NULLIF(TRIM(CONCAT_WS(' ', first_name, last_name)), ''), email) AS name
         FROM crm_contacts ORDER BY created_at DESC LIMIT 300`
    ).catch(() => []),
    query("SELECT id, name FROM lead_sources ORDER BY name ASC LIMIT 100").catch(() => []),
  ]);
  return {
    agents,
    communities,
    properties: properties.map((row) => ({ id: row.public_id, name: row.title, value: row.public_id, label: row.title })),
    contacts: contacts.map((row) => ({ id: row.public_id, name: row.name, value: row.public_id, label: row.name })),
    sources: sources.map((row) => ({ id: String(row.id), name: row.name, value: String(row.id), label: row.name })),
    statuses: options.staticOptions(["new", "working", "qualified", "unqualified", "converted", "lost", "dormant"]),
    categories: options.marketplaceCategories(),
  };
}

/** Selects above the Contacts table. */
async function contactFilterOptions() {
  const [agents, countries, sources] = await Promise.all([
    options.agents(),
    options.countries(),
    query("SELECT id, name FROM lead_sources ORDER BY name ASC LIMIT 100").catch(() => []),
  ]);
  return {
    agents,
    countries,
    sources: sources.map((row) => ({ id: String(row.id), name: row.name, value: String(row.id), label: row.name })),
    statuses: options.staticOptions(["active", "inactive", "unqualified", "converted"]),
  };
}
