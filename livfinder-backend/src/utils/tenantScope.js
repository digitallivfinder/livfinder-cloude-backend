/**
 * Tenant scoping for rows that may belong to an organization or to an individual.
 *
 * These checks used `organization_id <=> ?`, MySQL's NULL-safe equality. For a caller with no
 * organization — every individual account — that compares NULL with NULL and is true, so the
 * caller matched every other individual's rows across the platform: they could read and change
 * other people's inquiries, leads, bookings and offers, assign their agents, and answer their
 * reviews. Plain `=` is never true for NULL, which is the rule these checks meant.
 */

/**
 * An agent the caller may assign: one of their organization's agents or, for an individual, only
 * the agent profile tied to their own user.
 */
export function ownAgentClause({ organizationId = null, userId = null } = {}, alias = "") {
  const column = (name) => (alias ? `${alias}.${name}` : name);
  if (organizationId) return { sql: `${column("organization_id")} = ?`, params: [organizationId] };
  return { sql: `${column("organization_id")} IS NULL AND ${column("user_id")} = ?`, params: [userId ?? 0] };
}
