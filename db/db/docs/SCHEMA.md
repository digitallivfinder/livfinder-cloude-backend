# Schema reference

506 tables across 27 domains, plus 7 views, 4 stored routines and 4 triggers.
Grouped by the migration that creates them.

Conventions (primary keys, public ids, timestamps, soft deletes, money, enums)
are documented in the header of `migrations/0001_conventions_and_reference.sql`.

---

## 1 · Reference — `0001`

Platform-wide lookups that almost everything else depends on.

| Table | Purpose |
|---|---|
| `schema_migrations` | Applied-migration bookkeeping |
| `languages` | 15 BCP-47 locales with LTR/RTL direction, drives every `*_translations` table |
| `currencies` | 24 currencies with the ISO 4217 minor unit (KWD/BHD/OMR are 3-decimal, JPY 0) |
| `fx_rates` | Append-only rate history, one row per (base, quote, date) |
| `fx_rates_latest` | Current rate per pair; a table not a view, so the hot path is a PK lookup |
| `measurement_units` | Unit conversions with a canonical unit per dimension |
| `settings` | Typed key/value, grouped, with `is_public` / `is_secret` flags |
| `feature_flags` | Boolean plus percentage rollout, evaluated against a stable hash of the actor |

**Exactly one currency has `is_base = 1`.** Every `*_base` column in the schema is
denominated in it. Changing it is a backfill, not a config edit.

---

## 2 · Geography — `0002`

The five-tier location tree. Fully documented in **[LOCATIONS.md](LOCATIONS.md)**.

| Table | Purpose |
|---|---|
| `locations` | The tree. `level` + `depth` + `parent_id` + `path` + denormalised ancestors |
| `location_closure` | Transitive ancestor/descendant edges, including the depth-0 self-pair |
| `location_country_profiles` | Country-only attributes (ISO codes, dialling code, currency, postal format, `state_label`, `curated_depth`) |
| `location_state_profiles` | ISO 3166-2 detail for the state tier |
| `location_translations` | Localised names, seeded for countries and states |
| `location_aliases` | Alternate names users actually type — `JBR`, `Akoya`, `Tecom`, `The Palm` |
| `location_boundaries` | Optional polygon + denormalised bounding box |
| `location_category_stats` | Inventory and price bands per (location, category, purpose) |

The country/state profiles are separate tables rather than nullable columns on
`locations` because they apply to 250 and 5,308 of 161,142 rows; carrying them
inline would bloat every page of the tree's clustered index.

---

## 3 · Taxonomy — `0003`

| Table | Purpose |
|---|---|
| `categories` | Six asset classes and their 52 listing types in one tree; `detail_table` names the backing table in `0007` |
| `category_translations` | Localised category names and SEO copy |
| `purposes` | sale / rent / charter / lease / auction, with `is_recurring` |
| `category_purposes` | Which purposes are real for which class (watches are sale-only; yachts charter rather than rent) |
| `attributes` | The field registry: type, unit, validation, UI control, and `backing_column` |
| `attribute_options` | Enum values for `enum` / `multi_enum` attributes |
| `attribute_translations` | Localised field labels |
| `category_attributes` | Which attributes apply where, whether required, and their form grouping |
| `feature_groups` / `features` | Boolean amenity tags — pool, helipad, wine cellar, sea view |
| `feature_translations` | Localised amenity names |
| `category_features` | Which amenities are offered per class |
| `brands` | Every kind of maker in one table: car marques, yacht yards, aircraft manufacturers, watch houses, property developers |
| `brand_models` | Models, with `reference_code` for markets that identify by code (`5711/1A`, `G650ER`) |

**The attribute registry is what stops six asset classes becoming six codebases.**
The listing form, filter panel, spec table and validators are all generated from
`attributes` + `category_attributes`, so adding "carbon ceramic brakes" to cars is
an `INSERT`, not a release.

---

## 4 · Identity and access — `0004`

| Table | Purpose |
|---|---|
| `users` | One row per human. Credentials, presentation preferences, `session_epoch` for global sign-out |
| `account_types` | personal / lister / company / organization / partner, with behaviour flags |
| `account_type_transitions` | Which conversions are permitted and what each requires |
| `accounts` | The entity that owns listings, leads, money and members |
| `account_members` | **The organisation role model.** owner / manager / agent / viewer / accountant, per membership |
| `account_type_change_requests` | The post-signup type-switching workflow, with review lifecycle |
| `account_type_change_documents` | Evidence uploaded for a change request |
| `permissions` / `roles` / `role_permissions` / `user_roles` | Platform staff RBAC, separate from account membership |
| `user_sessions` | Server-side sessions. Stores only the SHA-256 of the cookie token; `active_account_id` is what makes account switching work |
| `user_identities` | OAuth / social identities |
| `user_tokens` | Password reset, verification, invitations — one table, single-use via `consumed_at` |
| `user_mfa_factors` | TOTP / SMS / WebAuthn factors |
| `user_consents` | Versioned consent records |
| `data_subject_requests` | GDPR export / deletion / rectification with a statutory clock |

### The user/account split

A person is a `users` row. What they can do is a property of the `account` they
are acting as, and the two are many-to-many:

```
users ──< account_members >── accounts ──> account_types
```

That one change makes two otherwise-awkward features ordinary:

- **Organisation roles have somewhere real to live.** `account_members.role`
  differs per membership, so the same person can own one brokerage and be a
  viewer at another. Permission flags are denormalised alongside it because
  authorisation is checked on essentially every request and should not pay a
  three-table join; `role` remains the source of truth.
- **Account-type switching is a reviewable workflow**, not a destructive edit —
  because personal → organisation genuinely needs licence checks.

`v_account_permissions` resolves a membership to a permission set in one indexed
lookup.

---

## 5 · Organisations and agents — `0005`

| Table | Purpose |
|---|---|
| `organizations` | Public business profile attached 1:1 to an account. `kind` covers agency, brokerage, dealership, developer, yacht/aviation broker, watch dealer, partners |
| `organization_translations` | Localised profile copy |
| `organization_licenses` | RERA, ORN, DED trade licence, broker licence, maritime, aviation, VAT — with expiry, indexed for the compliance job |
| `organization_branches` | Branch offices with their own address, phone and catchment |
| `organization_category_access` | Which asset classes an organisation is cleared to list in, with the application workflow |
| `organization_service_areas` | Where it actually operates |
| `agents` | Public professional profile. `slug` is NOT NULL and unique, so an agent without a working profile URL cannot exist |
| `agent_languages` | Spoken languages — a real filter in Dubai, Marbella and Miami |
| `agent_service_areas` / `agent_specialties` | Coverage and asset-class focus |
| `verification_requests` / `verification_documents` | One moderation queue covering organisations, agents, accounts and listings |
| `access_requests` | "Let me join this organisation" — the agent asks the agency |
| `api_clients` | Partner API credentials; only a hash and a display hint are stored |

`agents.user_id` is nullable on purpose: agencies routinely publish agent profiles
before those people have a login, and a profile must survive an agent leaving.

---

## 6 · Listings — `0006`

| Table | Purpose |
|---|---|
| `projects` | Off-plan developments with handover date, payment plan and unit counts |
| `listings` | The core table. Ownership, classification, price, location, lifecycle, placement, contact, media summary, ranking, SEO |
| `listing_translations` | Per-locale title and description, flagged when machine-translated |
| `media_folders` / `media_assets` | The media library. Uploads are rows, not URL strings, so an asset can be reused, derivatives tracked, and orphans reclaimed |
| `listing_media` | Ordered gallery join; carries `url` so a gallery renders from one read |
| `listing_features` | Many-to-many amenity tags. The reverse index is what makes "has pool AND sea view" answerable |
| `listing_attribute_values` | Typed EAV for filterable fields not promoted to a column |
| `listing_price_history` | Every price change, written by a trigger |
| `listing_status_history` | The moderation audit trail, with `actor_type` distinguishing admin from the expiry sweeper |

### Two deliberate denormalisations

**The full location chain** (`country_id` … `sub_community_id`) is stored on every
listing, maintained by triggers. "Villas in Dubai" is then one indexed predicate.

**Contact details** (`contact_phone`, `contact_whatsapp`, `contact_email`) are
resolved at write time from agent → branch → organisation. This is what makes the
Call and WhatsApp buttons a column read rather than a join plus a policy decision,
and it lets a single listing override the agency default. `allow_call` /
`allow_whatsapp` / `allow_email` let the UI render only live buttons.

`canonical_path` is stored, not derived, and is unique. Computing a URL in two
places is how two datasets drift apart and start publishing 404s into
`sitemap.xml`.

---

## 7 · Per-category detail — `0007`

Class-table inheritance: one table per asset class, keyed 1:1 on `listings.id`.

| Table | Backs | Key filterable columns |
|---|---|---|
| `listing_real_estate` | real estate | bedrooms, bathrooms, built/plot area (m² **and** ft²), floor, year built, completion status, furnishing, ownership, view, permit numbers, yield |
| `listing_vehicle` | cars | model year, mileage (km **and** miles), transmission, fuel, drivetrain, engine, power, condition, steering side, regional spec, service history, VIN |
| `listing_marine` | yachts | LOA (m **and** ft), beam, draft, tonnage, vessel type, hull material, cabins, guests, crew, engines, speeds, range, flag state, berth, charter rates, VAT status |
| `listing_aviation` | jets **and** helicopters | aircraft type, year, total time, cycles, pax, range, cruise speed, engine programme, avionics, base airport, certificate, inspection due, charter rate |
| `listing_timepiece` | watches | reference number, year, case material and diameter, dial, movement, caliber, power reserve, water resistance, complications, condition, box/papers/card (+ generated `is_full_set`) |

Five tables, not six: helicopters and jets share `listing_aviation` because their
specification set is genuinely identical. `root_category_id` separates them.

The rationale for typed columns over JSON is in
**[PERFORMANCE.md](PERFORMANCE.md)** — the short version is that a range filter
can only be served from an index by a real column.

---

## 8 · Engagement — `0008`

| Table | Purpose |
|---|---|
| `inquiries` | The lead. `user_id` nullable, because most high-value enquiries come from people who have not registered. Channel, type, status, priority, assignment, SLA timing, UTM attribution, spam score, budget |
| `inquiry_notes` / `inquiry_status_history` | Internal notes and the status trail |
| `conversations` / `conversation_participants` / `messages` / `message_attachments` | Threaded messaging. Per-participant `unread_count` maintained on write; denormalised thread summary so an inbox renders without a correlated subquery per row |
| `favourites` | The heart toggle, with `price_at_save` so "reduced since you saved it" needs no history read |
| `collections` / `collection_items` | Named shortlists, and editorial collections curated by staff |
| `saved_searches` | Stored filter set (JSON) replayed through the live query builder, with alert frequency and a `last_result_max_listing_id` watermark so alerts never re-send |
| `bookings` / `booking_status_history` | Viewings, test drives, sea trials, inspections, charters. UTC plus originating timezone |
| `offers` / `offer_events` | Formal offers with `parent_offer_id` making the negotiation a linked list |
| `reviews` / `review_responses` | Polymorphic subject with one moderation pipeline; `is_verified_transaction` separates a review from noise |
| `contacts` | General-enquiry and partnership submissions, kept out of the agency inbox |
| `notification_templates` / `notifications` / `notification_preferences` / `notification_deliveries` | Templates with declared variables, in-app notifications, per-type channel preferences, and a delivery log with provider message ids for bounce handling |

**Every count in this domain is a `COUNT` over an index designed for it.** The
status column leads each composite (`ix_inquiries_org_status`,
`ix_bookings_user`, `ix_notifications_user_unread`) so an inbox tab label and the
rows it then shows come from the same source.

---

## 9 · Finance — `0009`

| Table | Purpose |
|---|---|
| `plans` / `plan_prices` / `plan_features` | Subscription plans, priced separately per currency so each market gets a sensible price point rather than whatever FX produces |
| `subscriptions` | Status, period, trial, quota consumption |
| `payment_methods` | Presentation detail only — brand, last four, expiry. The instrument lives at the processor, keeping this database out of PCI scope |
| `invoices` / `invoice_lines` | Gapless document numbering; a cancelled invoice becomes `void`, never deleted |
| `credit_notes` | Corrections. An invoice is never edited |
| `payments` / `refunds` | With `idempotency_key` to prevent double-charging on a retry |
| `payout_methods` / `payouts` / `payout_items` | Money out. IBAN encrypted, last four in the clear |
| `ledger_entries` | Double-entry general ledger |
| `coupons` / `coupon_redemptions` | Promotions with per-account limits |
| `featured_placements` | Paid promotion — who paid for what, when, and whether it delivered. Distinct from `listings.is_featured`, which only says "featured now" |
| `account_credits` | Prepaid listing/feature credits with a running `balance_after` |

Two rules govern this domain:

1. **Financial rows are immutable once issued.** Corrections leave a trail.
2. **Every amount carries its currency and its FX snapshot.** `exchange_rate` is
   stored on the row, not looked up later, because a refund six months on must use
   the original rate.

`ledger_entries` is balanced per `transaction_group` — asserted in the integrity
suite.

---

## 10 · Moderation and audit — `0010`

| Table | Purpose |
|---|---|
| `report_reasons` | The report taxonomy, with `applies_to` scoping and `is_severe` for straight-to-urgent routing |
| `reports` | User-submitted reports with a `subject_snapshot`, because reported content is frequently edited or deleted before review |
| `report_actions` | Every moderator action — assign, reassign, status change, note, escalate, resolve, dismiss |
| `moderation_queue` | Proactive review fed by automated checks (duplicate detection, price anomaly, banned terms, image similarity) with a risk score |
| `audit_logs` | Append-only, month-partitioned, **no foreign keys** — an audit row must outlive its subject. Field-level before/after in `changes` |
| `system_logs` | Application and infrastructure events, month-partitioned, shorter retention |
| `user_blocks` | User-to-user blocking |
| `blocklist_entries` | Platform bans on identifiers (email, domain, IP, range, device, keyword) with `flag` / `block` / `throttle` |
| `rate_limit_counters` | Durable rate-limit record; hot counters belong in Redis |

---

## 11 · Editorial and CMS — `0011`

| Table | Purpose |
|---|---|
| `authors` | Bylines, distinct from `users` — a guest contributor has no login |
| `editorial_terms` | One table for category / tag / topic / destination / series. `destination` terms link to `locations` |
| `editorial_term_translations` | Localised term names |
| `posts` / `post_translations` / `post_terms` / `post_listings` | Articles, guides, market reports, with explicit listing references |
| `pages` / `page_translations` | Static and legal pages, versioned so `user_consents.policy_version` means something |
| `location_landing_pages` | Per-(location, category, purpose, language) editorial copy plus FAQ — the organic-search surface for "villas for sale in Palm Jumeirah" |
| `navigation_menus` / `menu_items` | Menus; items can target a managed entity so a slug change cannot leave a dead link |
| `redirects` | Every URL the platform has ever emitted must resolve. Prefix matching, hit counts, 301/302/307/308/410 |
| `faqs` | Scoped to global / category / location / page / plan |
| `newsletter_subscribers` | Double opt-in with interests and an unsubscribe token |

---

## 12 · Analytics — `0012`

| Table | Purpose |
|---|---|
| `analytics_events` | The raw stream, month-partitioned, no foreign keys. Dimensions denormalised at write time so rollups never join |
| `listing_daily_stats` | Per-listing daily rollup: impressions, views, contact views, call/WhatsApp/email clicks, inquiries, favourites, shares |
| `organization_daily_stats` / `agent_daily_stats` | Rollups for the agency and agent dashboards, with median response time |
| `platform_daily_stats` | One row per day — the admin dashboard's KPI row and every "vs last 30 days" delta |
| `search_queries` | What people search for. `result_count = 0` at volume is a market-expansion signal |
| `search_query_daily_stats` | Pre-aggregated popular searches |
| `price_index_daily` | Median price and price-per-area per (location, category, purpose) |
| `jobs` / `job_runs` | Every scheduled maintenance task, with `max_staleness_minutes` for health alerting |
| `webhooks` / `webhook_deliveries` | Outbound integrations with HMAC signing, exponential backoff and auto-disable after sustained failure |

**No dashboard queries `analytics_events`.** Everything user-facing reads a
`*_daily` rollup.

---

## 13 · Search projection — `0013`

| Table | Purpose |
|---|---|
| `listing_search` | Flat, read-only projection of every publicly visible listing. One row, no joins, everything a result card renders |
| `sitemap_entries` | The sitemap as a table, with `last_verified_at`. A path that has never been verified is never emitted |

Generic `spec_a`..`spec_f` and `facet_a`..`facet_c` columns serve all six asset
classes from one set of indexes; the mapping is documented in `0013` and
implemented in exactly one place, `sp_refresh_listing_search()`.

---

## Views — `0014`

| View | Purpose |
|---|---|
| `v_public_listings` | The definition of a publicly visible listing. Checks `expires_at` directly, closing the window between a listing lapsing and the sweeper noticing |
| `v_public_organizations` | Publicly visible organisations |
| `v_public_agents` | Publicly visible agents — **including** the rule that an agent is only public if their organisation is too |
| `v_location_hierarchy` | The five-tier cascade flattened with ancestor names resolved |
| `v_account_permissions` | Membership resolved to a permission set |
| `v_account_listing_counts` | Live per-status listing counts per account, for the portal tabs |
| `v_organization_inquiry_counts` | Live per-status inquiry counts, for the inbox tabs |

The visibility views exist so no query has to remember the rules. Anything that
repeats them by hand — a sitemap generator, for instance — will eventually get one
wrong.

---

# Part two — the corporate layers, `0016`–`0029`

Migrations `0001`–`0015` are the marketplace. Everything from `0016` on is what
a marketplace needs in order to be run as a business: assets, discoverability,
money, customers, inventory and the evidence trail behind all of it.

The pattern repeats across all fourteen. Each layer separates the thing from the
record of what happened to it — an asset from its renditions, a payment from its
attempts, a lead from its touches, a unit from its transactions — because the
first is state and the second is history, and conflating them is what makes a
system unable to answer questions about its own past.

## 14 · Media asset management — `0016`

| Table | Notes |
|---|---|
| `media_assets` | The library. One row per original, with perceptual hash, blurhash, dominant colour, focal point, licence and storage tier |
| `media_renditions` | Every derived file. Separate rows so a failed WebP variant is visible rather than inferred from a 404 |
| `media_crops` | Aspect-ratio crops stored as coordinates, so a re-crop is a metadata change rather than a re-upload |
| `media_exif`, `media_tags`, `media_captions`, `media_translations` | Extracted metadata, AI and manual tags, subtitle tracks, per-language alt text |
| `media_moderation_results` | NSFW, text, watermark and face detection, each with its own decision |
| `video_assets`, `video_transcode_jobs` | Video as a one-to-one extension, with a per-rendition transcode ladder |
| `virtual_tours`, `tour_scenes`, `tour_hotspots` | Scenes stitched into a walkable path by navigation hotspots |
| `floor_plans`, `floor_plan_rooms` | Rooms as rows, so "has a study" is a query rather than an image somebody has to open |
| `upload_sessions`, `upload_parts` | Resumable uploads. The abandoned sessions are what the orphan-cleanup policy prunes |
| `documents`, `document_access_grants`, `document_downloads` | The gated brochure: a lead-generation instrument with an auditable gate |

## 15 · SEO platform — `0017`

| Table | Notes |
|---|---|
| `url_inventory` | Every URL the platform can emit, with an explicit indexation decision and the rule that made it. A portal with a million facet combinations either governs its own index or has its crawl budget spent for it |
| `indexation_rules` | The policy that produces those decisions, as data |
| `seo_meta`, `seo_meta_templates` | Patterns, with editorial overrides recorded explicitly so a regeneration cannot discard them |
| `structured_data_templates`, `structured_data_instances` | Schema.org payloads with a validation status: an invalid payload is a rich result that quietly disappeared |
| `internal_links`, `backlinks` | The link graph, inbound and outbound. `is_disavowed` turns a negative-SEO complaint into a documented action |
| `crawl_sessions`, `crawl_results`, `crawl_budget_daily` | Audit crawls, and where the real crawlers actually spend. `wasted_requests` is the column this table exists for |
| `sitemap_files`, `sitemap_entries`, `sitemap_submissions` | Split at the fifty-thousand limit, submitted per file, with submitted and indexed counts kept apart |
| `content_quality_scores`, `content_duplicate_clusters` | Thin as a compound judgement rather than a word count, and near-duplicate detection with a canonical resolution |
| `seo_experiments` | Split by URL rather than by visitor, because the thing under test is what the crawler sees |

## 16 · Payments infrastructure — `0018`

| Table | Notes |
|---|---|
| `payment_gateways`, `gateway_accounts`, `gateway_routing_rules` | Multi-acquirer routing by currency, method and country |
| `payment_intents`, `payment_attempts` | The intent survives its failed attempts, which is what makes a retry a retry rather than a second charge |
| `three_ds_authentications` | Exemption claimed, exemption granted and liability shift, held separately because they are three different facts |
| `payment_mandates` | Direct debit authority with its signature evidence |
| `payment_splits` | One inbound payment, several beneficiaries, held as rows |
| `disputes`, `dispute_evidence` | The chargeback lifecycle with its deadlines |
| `settlements`, `settlement_lines`, `reconciliation_exceptions` | Gateway settlement against the ledger, and every line that will not match becoming somebody's problem by name |
| `dunning_campaigns`, `dunning_steps`, `dunning_runs`, `dunning_attempts` | Failed-payment recovery that ends in an actual action |
| `fraud_rules`, `fraud_assessments` | Rules with true-positive and false-positive counters, so one that costs more than it saves can be retired |

## 17 · Tax and accounting — `0019`

| Table | Notes |
|---|---|
| `tax_jurisdictions`, `tax_rates`, `tax_rules`, `tax_registrations` | Rates versioned by effective date; place-of-supply rules as data |
| `tax_transactions` | Per-line tax with the rule that produced it, including reverse charge and the timestamped VAT-number validation behind it |
| `chart_of_accounts`, `journals`, `ledger_entries` | Double entry, balanced per journal |
| `revenue_recognition_rules`, `revenue_schedules`, `revenue_recognition_entries` | IFRS 15: billed and recognised are different numbers in different periods |
| `accounting_periods`, `period_close_tasks` | The close checklist, whose blocking tasks are what make the closed flag mean something |
| `bank_accounts`, `bank_transactions`, `bank_reconciliations` | The outside world's version of events, and the process of agreeing with it |
| `escrow_accounts`, `escrow_transactions` | Off-plan money that is neither the developer's nor the platform's |
| `tax_filings`, `tax_exemptions`, `withholding_taxes` | Returns, certificates and treaty relief |
| `budgets`, `budget_lines`, `cost_centers`, `fx_revaluations` | Plan against actual, with derived variances |

## 18 · CRM and leads — `0020`

Four grains, deliberately separate: `crm_contacts` is a person, `leads` is an
intent, `inquiries` is a touch, `deals` is a transaction. Collapsing any pair of
them is the mistake that makes a CRM unable to answer how many people it knows.

| Table | Notes |
|---|---|
| `crm_contacts`, `crm_contact_merges` | The person. The merge keeps a snapshot of what it destroyed |
| `leads`, `lead_requirements`, `lead_requirement_locations` | The intent, with a structured brief including excluded locations |
| `lead_pipelines`, `lead_pipeline_stages`, `lead_routing_pools`, `lead_routing_rules` | Routing with per-member round-robin state and conditions as rows |
| `sla_policies`, `sla_clocks` | Clocks that pause outside business hours and on `business_holidays` |
| `lead_forms`, `lead_form_fields`, `lead_form_submissions` | Capture with a honeypot, a minimum fill time and a rate limit |
| `lead_shares` | Referral, sale and broadcast, with exclusivity and recipient index |
| `viewings`, `viewing_feedback` | Structured feedback rather than a free-text note |
| `deals`, `deal_commissions` | Commission splits as rows, because co-brokerage is the normal case |
| `calls`, `call_events`, `call_recordings` | Pooled numbers and a leg-by-leg trace, including the consent announcement |
| `nurture_campaigns`, `nurture_enrolments`, `nurture_step_deliveries` | Sequences whose exit conditions matter more than their steps |

## 19 · Advertising and monetisation — `0021`

| Table | Notes |
|---|---|
| `ad_advertisers`, `ad_campaigns`, `ad_line_items`, `ad_creatives`, `ad_placements` | The sell side |
| `ad_impressions`, `ad_events` | Month-partitioned, append-only. Viewability separate from served, invalid traffic flagged |
| `ad_frequency_state` | Per-visitor caps |
| `ad_spend_entries` | An append-only ledger; the campaign's spend is its sum, never a typed figure |
| `promotion_products`, `promotion_inventory`, `promotions` | Featured slots counted per slot per day, so they cannot be oversold |
| `credit_lots`, `credit_transactions` | Consumed oldest-expiry-first; the balance is the ledger |
| `affiliates`, `affiliate_links`, `affiliate_clicks`, `affiliate_conversions` | Attribution tokens that expire |

## 20 · Search infrastructure — `0022`

| Table | Notes |
|---|---|
| `search_ranking_profiles`, `search_ranking_signals` | Versioned weights, so a ranking change is reviewable and revertible |
| `search_synonym_sets`, `search_synonyms`, `search_query_rewrites`, `search_stopwords` | Query understanding as data |
| `search_facet_definitions`, `search_facet_counts` | Facets and their cached counts |
| `search_curations`, `search_boost_rules` | Editorial override kept apart from systematic boosting |
| `search_zero_result_queries` | The triage queue: demand the platform has and cannot serve |
| `search_experiments`, `search_experiment_variants`, `search_experiment_exposures` | User-split experiments with guardrail metrics |
| `search_index_queue` | The outbox into the search cluster, with its stuck and failed rows visible |
| `listing_similarities`, `user_affinity_profiles` | Recommendations, with a stated confidence |

## 21 · Feeds and integrations — `0023`

| Table | Notes |
|---|---|
| `integration_providers`, `integration_connections` | Who, and with what credentials |
| `external_references` | The two-way identity map. Without it, re-importing a feed creates duplicates forever |
| `field_mappings`, `value_mappings` | Mapping as data rather than as code per partner |
| `feed_imports`, `feed_import_items` | Per-row outcomes, and `max_deletion_percent` — the safety valve that stops a truncated feed unpublishing an agency's whole inventory |
| `api_clients`, `api_request_logs`, `webhooks`, `webhook_deliveries` | Both directions, with retries and dead-lettering |

## 22 · Compliance and contracts — `0024`

| Table | Notes |
|---|---|
| `regulatory_authorities`, `permits` | Listing permits with expiry enforcement |
| `kyc_profiles`, `kyc_cases`, `identity_documents` | Risk-driven review cycles; documents held as a hash with a purge date set on arrival |
| `beneficial_owners` | Ownership chains, walkable |
| `sanctions_screenings`, `screening_matches` | Screening with dispositions rather than a boolean |
| `source_of_funds_declarations` | Declared, evidenced, reviewed |
| `suspicious_activity_reports` | With `customer_disclosed` permanently zero: telling the customer is the tipping-off offence, and the column is the evidence it did not happen |
| `contracts`, `contract_versions`, `contract_parties`, `signature_events` | Every version kept with its hash, and an evidence trail per signature |

## 23 · Communications and support — `0025`

| Table | Notes |
|---|---|
| `sending_domains`, `sender_identities`, `sender_reputation_daily` | SPF, DKIM and DMARC per domain; reputation per recipient mailbox provider |
| `suppressions`, `unsubscribe_tokens` | Checked before every send, ahead of preferences and templates |
| `broadcast_campaigns`, `campaign_recipients`, `message_delivery_events` | Approval before send; a partitioned delivery event stream |
| `support_tickets`, `ticket_messages` | Reusing the CRM's SLA clocks rather than inventing a second set |
| `kb_articles`, `kb_feedback` | Knowledge base with staleness tracking |

## 24 · Platform operations — `0026`

| Table | Notes |
|---|---|
| `outbox_events` | The transactional outbox: publish and commit in one transaction or neither |
| `queues`, `queue_messages`, `dead_letter_messages` | Visibility timeouts, claim index, and a dead-letter table somebody actually looks at |
| `idempotency_keys` | Storing the response, not just the key — a retry must return what the first call returned |
| `distributed_locks` | With a fencing token, because a lock without one does not prevent the split-brain write |
| `circuit_breakers` | State held in the database so every process agrees a dependency is down |
| `workflow_definitions`, `workflow_steps`, `workflow_instances`, `workflow_actions` | Approvals with delegation |
| `health_checks`, `maintenance_windows` | Operational state |

## 25 · Tenancy and governance — `0027`

| Table | Notes |
|---|---|
| `tenants`, `tenant_domains`, `tenant_settings`, `tenant_visibility_rules` | Multi-brand: regional front doors, white-label brokerage sites and embedded widgets over one inventory pool |
| `data_field_registry` | The column-level inventory that makes a subject access request answerable by query |
| `anonymization_rules` | Deterministic hashing separated from random tokenisation, because a hash keeps joins working and a token deliberately breaks them |
| `processing_activities`, `data_processors` | The Article 30 record and every third party that touches personal data |
| `retention_policies`, `retention_runs` | Windows as data, with dry runs before deletion is enabled |
| `legal_holds` | Overrides every retention policy; the runs report `held_rows` separately rather than quietly deleting fewer |
| `consent_purposes`, `consent_receipts` | Versioned purposes; the receipt records which notice version the subject actually saw |
| `erasure_records` | Keyed by hash so it survives the erasure it documents |
| `field_change_log`, `entity_snapshots` | Partitioned change history, and full copies at the moments that matter |

## 26 · Property inventory — `0028`

A listing is an advertisement; a unit is the thing that persists. That
distinction is what makes price history, yield, ownership and market statistics
possible at all.

| Table | Notes |
|---|---|
| `buildings`, `building_floors`, `property_units` | The physical asset beneath the listing. `listings.unit_id` is the join that recognises the same flat across three agencies and four years of feeds |
| `unit_ownerships` | Shares as rows, with a prior-owner history |
| `unit_transactions` | Registered facts, kept apart from asking prices. `is_arms_length` keeps family transfers out of the medians |
| `tenancies`, `tenancy_parties`, `rent_schedules` | Post-dated cheques as first-class columns, because a bounced cheque is a legal event with a deadline |
| `maintenance_requests` | With liability actually assigned rather than defaulted to the landlord |
| `valuations`, `valuation_comparables` | Three kinds — model, broker opinion, formal survey — with the comparables each was built from |
| `lenders`, `mortgage_products`, `mortgage_applications` | A pipeline of its own, because finance falls through independently of the sale |
| `project_payment_plans`, `payment_plan_milestones` | Off-plan is sold on the plan, not the price |
| `market_statistics_monthly` | Computed from transactions, with a five-sample floor below which nothing is publishable |

## 27 · Analytics platform — `0029`

| Table | Notes |
|---|---|
| `web_sessions` | The grain everything counts, carrying its own engagement counters |
| `attribution_models` | Several, deliberately: a single model is a policy decision disguised as a measurement |
| `attribution_touchpoints`, `conversions`, `conversion_credits` | Credit fractions sum to exactly one per conversion per model — asserted, not assumed |
| `channel_performance_daily` | The model is part of the grain, so the disagreement between first-click and last-click is visible rather than hidden |
| `funnels`, `funnel_steps`, `funnel_daily_stats` | Steps as data; statistics per step so one can be inserted without rewriting history |
| `cohorts`, `cohort_periods` | Retention and revenue retention side by side |
| `kpi_definitions`, `kpi_values`, `kpi_targets` | The metric dictionary. Every number on every dashboard resolves to a row here that says in words what it counts — the cheapest cure there is for two departments reporting different figures for the same thing |
| `metric_alerts`, `metric_anomalies` | The rule, and what the rule found, kept apart |
| `dashboards`, `dashboard_widgets`, `scheduled_reports`, `report_runs` | Per-audience dashboards and delivery history |

---

## Routines — `0014` and `0015`

| Routine | Purpose |
|---|---|
| `sp_location_rebuild_tree()` | Rebuilds `location_closure` and re-derives `depth`, `path`, `path_ids` and ancestor ids from `parent_id` alone. Fixed-pass loops, deliberately: an earlier version stopped when a generation needed no changes, which silently skipped deeper tiers in countries with no state |
| `sp_location_refresh_counts()` | Per-location inventory counts, rolled up the subtree via the closure table |
| `sp_refresh_listing_search(id)` | Rebuilds one projection row from source; `NULL` rebuilds all |
| `sp_refresh_entity_counters()` | Reconciles every denormalised counter. Traffic from the rollups; anything with a fact table from the fact table |
| `sp_rebuild_spatial_points()` | *(0015)* Rebuilds the SRID-4326 point tables from lat/lng |
| `sp_listings_within_radius()` | *(0015)* The canonical radius query, ordered by true distance |

## Triggers — `0014`

| Trigger | Enforces |
|---|---|
| `trg_listings_location_bi` / `_bu` | The denormalised location chain matches `location_id`, whichever code path writes |
| `trg_listings_price_history` | Every price change is recorded — the "reduced by 8%" badge is a claim made to buyers, so it must be verifiable |
| `trg_locations_no_self_parent_bu` | A location cannot be its own parent (a `CHECK` cannot express this: neither MySQL nor MariaDB permits an `AUTO_INCREMENT` column inside one) |

Triggers are used sparingly and only for invariants that would otherwise be
silently violated. Business logic stays in the application, where it can be
tested.
