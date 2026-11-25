/* Agent-role visibility, shared by the portal repositories (kept apart to avoid an import cycle). */

/**
 * What an agent-role member may see: an inquiry sent to them, assigned to them, or about a
 * listing assigned to them. Owners and managers pass no agent and see the whole account.
 */
export function agentInquiryClause(alias, agentId) {
  return {
    sql: `(${alias}.agent_id = ? OR ${alias}.assigned_to_agent_id = ?
           OR EXISTS (SELECT 1 FROM listings agl WHERE agl.id = ${alias}.listing_id AND agl.agent_id = ?))`,
    params: [agentId, agentId, agentId],
  };
}

/** The same rule for leads: owned by the agent, on their listing, or behind one of their inquiries. */
export function agentLeadClause(alias, agentId) {
  return {
    sql: `(${alias}.owner_agent_id = ?
           OR EXISTS (SELECT 1 FROM listings agl WHERE agl.id = ${alias}.primary_listing_id AND agl.agent_id = ?)
           OR EXISTS (SELECT 1 FROM inquiries agi
                       WHERE agi.deleted_at IS NULL
                         AND (agi.lead_id = ${alias}.id OR agi.id IN (SELECT agli.inquiry_id FROM lead_inquiries agli WHERE agli.lead_id = ${alias}.id))
                         AND (agi.agent_id = ? OR agi.assigned_to_agent_id = ?
                              OR EXISTS (SELECT 1 FROM listings agl2 WHERE agl2.id = agi.listing_id AND agl2.agent_id = ?))))`,
    params: [agentId, agentId, agentId, agentId, agentId],
  };
}

/** Offers: made to the agent, or on a listing assigned to them. */
export function agentOfferClause(alias, agentId) {
  return {
    sql: `(${alias}.agent_id = ? OR EXISTS (SELECT 1 FROM listings agl WHERE agl.id = ${alias}.listing_id AND agl.agent_id = ?))`,
    params: [agentId, agentId],
  };
}
