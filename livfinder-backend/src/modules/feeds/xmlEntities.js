/**
 * How feed XML expands entities (fast-xml-parser's `processEntities`).
 *
 * The library's default stops a file after 1,000 expansions in total, and it counts the ordinary
 * escapes (`&lt;`, `&amp;`…) too. A portal export with HTML descriptions has millions of those: the
 * 16,529-listing LuxuryProperty.com file stopped at its second listing. Ordinary escapes only ever
 * shorten the text, so they need no cap. The guards against an entity bomb stay, because they
 * apply to entities a file declares in its own DOCTYPE: how many it may declare, how large each
 * may be, how deep they may nest, and how much text they may add in total.
 */
export const FEED_XML_ENTITIES = Object.freeze({
  enabled: true,
  maxTotalExpansions: Number.MAX_SAFE_INTEGER,
  maxEntityCount: 100,
  maxEntitySize: 10_000,
  maxExpansionDepth: 10,
  maxExpandedLength: 100_000,
});
