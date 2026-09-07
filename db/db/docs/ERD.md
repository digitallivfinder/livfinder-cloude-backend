# Entity relationships

Diagrams per domain rather than one unreadable 506-table poster. Cardinality is
shown from the perspective of the parent.

---

## The location tree

```mermaid
erDiagram
    locations ||--o{ locations : "parent_id (self)"
    locations ||--o{ location_closure : "ancestor_id"
    locations ||--o{ location_closure : "descendant_id"
    locations ||--o| location_country_profiles : "iso codes, dialling, currency"
    locations ||--o| location_state_profiles : "ISO 3166-2"
    locations ||--o{ location_translations : "localised names"
    locations ||--o{ location_aliases : "JBR, Akoya, Tecom"
    locations ||--o| location_boundaries : "polygon + bbox"
    locations ||--o{ location_category_stats : "inventory per category"

    locations {
        bigint id PK
        bigint parent_id FK
        enum level "country|state|city|community|sub_community"
        tinyint depth "physical tree position"
        bigint country_id FK "denormalised ancestor"
        bigint state_id FK
        bigint city_id FK
        bigint community_id FK
        varchar path UK "slug chain, routes in one hit"
        varchar path_ids "id chain"
        varchar name_ascii "diacritic-folded, for search"
        int active_listing_count "rolled up the subtree"
    }
    location_closure {
        bigint ancestor_id PK
        bigint descendant_id PK
        tinyint depth "0 = self"
    }
```

Five semantic tiers in one physical table. `level` answers "what is this", `depth`
answers "where is it in the tree" — they diverge where a country has no state
tier. See [LOCATIONS.md](LOCATIONS.md).

---

## Identity: users, accounts and roles

```mermaid
erDiagram
    users ||--o{ account_members : "memberships"
    accounts ||--o{ account_members : "members"
    account_types ||--o{ accounts : "type"
    account_types ||--o{ account_type_transitions : "from"
    account_types ||--o{ account_type_transitions : "to"
    accounts ||--o{ account_type_change_requests : "switch workflow"
    account_type_change_requests ||--o{ account_type_change_documents : "evidence"
    users ||--o{ user_sessions : "server-side sessions"
    users ||--o{ user_roles : "platform staff roles"
    roles ||--o{ user_roles : ""
    roles ||--o{ role_permissions : ""
    permissions ||--o{ role_permissions : ""
    accounts ||--o| organizations : "public profile"
    users ||--o{ user_identities : "oauth"
    users ||--o{ user_tokens : "reset, verify, invite"
    users ||--o{ user_consents : "versioned consent"
    users ||--o{ data_subject_requests : "GDPR"

    users {
        bigint id PK
        varchar email_normalized UK
        int session_epoch "bump to sign out everywhere"
        bigint default_account_id FK
    }
    accounts {
        bigint id PK
        smallint account_type_id FK
        bigint owner_user_id FK
        int listing_quota
        int listing_used
    }
    account_members {
        bigint account_id PK
        bigint user_id PK
        enum role "owner|manager|agent|viewer|accountant"
        bool can_manage_listings "cached from role"
        bool can_manage_leads
    }
```

A person is a `user`; what they can do belongs to the `account` they act as.
Many-to-many through `account_members`, which is where the organisation role model
finally has somewhere to live — and what makes account switching and type
conversion ordinary rather than special.

---

## Businesses and agents

```mermaid
erDiagram
    accounts ||--o| organizations : ""
    organizations ||--o{ organization_licenses : "RERA, ORN, trade licence"
    organizations ||--o{ organization_branches : "offices"
    organizations ||--o{ organization_category_access : "cleared asset classes"
    organizations ||--o{ organization_service_areas : "coverage"
    organizations ||--o{ agents : "team"
    organizations ||--o{ access_requests : "join requests"
    organizations ||--o{ api_clients : "feed credentials"
    organization_branches ||--o{ agents : "based at"
    users ||--o| agents : "optional login"
    agents ||--o{ agent_languages : ""
    agents ||--o{ agent_service_areas : ""
    agents ||--o{ agent_specialties : ""
    verification_requests ||--o{ verification_documents : ""

    organizations {
        bigint id PK
        bigint account_id UK
        enum kind "agency|dealership|yacht_broker|developer|partner"
        varchar phone
        varchar whatsapp "a different number in practice"
        bool is_publicly_visible
        int response_time_minutes
    }
    agents {
        bigint id PK
        bigint user_id FK "nullable"
        varchar slug UK "NOT NULL - no agent without a profile URL"
        varchar phone
        varchar whatsapp
        decimal rating_avg
    }
```

`agents.user_id` is nullable: agencies publish profiles before those people have a
login, and a profile must survive an agent leaving. `agents.slug` is not nullable,
because an agent whose profile cannot be linked to should not exist.

---

## Listings and their specifications

```mermaid
erDiagram
    accounts ||--o{ listings : "owns"
    organizations ||--o{ listings : "lists"
    agents ||--o{ listings : "represents"
    categories ||--o{ listings : "leaf type"
    categories ||--o{ listings : "root asset class"
    purposes ||--o{ listings : "sale|rent|charter"
    locations ||--o{ listings : "deepest location"
    projects ||--o{ listings : "units in a development"
    brands ||--o{ listings : "marque"
    brand_models ||--o{ listings : "model"

    listings ||--o| listing_real_estate : "if real estate"
    listings ||--o| listing_vehicle : "if car"
    listings ||--o| listing_marine : "if yacht"
    listings ||--o| listing_aviation : "if jet or helicopter"
    listings ||--o| listing_timepiece : "if watch"

    listings ||--o{ listing_media : "gallery"
    listings ||--o{ listing_features : "amenity tags"
    listings ||--o{ listing_translations : ""
    listings ||--o{ listing_attribute_values : "long-tail EAV"
    listings ||--o{ listing_price_history : "by trigger"
    listings ||--o{ listing_status_history : "moderation trail"
    listings ||--o| listing_search : "read projection"
    media_assets ||--o{ listing_media : ""
    features ||--o{ listing_features : ""

    listings {
        bigint id PK
        varchar reference UK "LF-2847"
        varchar canonical_path UK "stored, never recomputed"
        decimal price
        char currency_code
        decimal price_base "for cross-currency sort"
        bigint country_id FK "denormalised chain"
        bigint city_id FK
        bigint community_id FK
        bigint sub_community_id FK
        varchar contact_phone "resolved at write time"
        varchar contact_whatsapp
        smallint quality_score "default search order"
    }
```

Class-table inheritance: exactly one detail row per listing, chosen by
`root_category_id`. `categories.detail_table` records the mapping so the
application dispatches from data.

---

## Engagement: from lead to deal

```mermaid
erDiagram
    listings ||--o{ inquiries : "leads"
    inquiries ||--o{ inquiry_notes : ""
    inquiries ||--o{ inquiry_status_history : ""
    inquiries ||--o| conversations : "thread"
    conversations ||--o{ conversation_participants : ""
    conversations ||--o{ messages : ""
    messages ||--o{ message_attachments : ""
    inquiries ||--o{ bookings : "viewings"
    bookings ||--o{ booking_status_history : ""
    inquiries ||--o{ offers : ""
    offers ||--o{ offers : "parent_offer_id (counter chain)"
    offers ||--o{ offer_events : ""
    bookings ||--o| reviews : "verified transaction"
    reviews ||--o| review_responses : "one official reply"
    users ||--o{ favourites : ""
    listings ||--o{ favourites : ""
    users ||--o{ collections : "shortlists"
    collections ||--o{ collection_items : ""
    users ||--o{ saved_searches : ""
    agents ||--o{ inquiries : "assigned to"

    inquiries {
        bigint id PK
        bigint user_id FK "nullable - most leads are anonymous"
        enum channel "form|whatsapp|phone|email|chat"
        enum status "new|contacted|qualified|...|won|lost"
        int first_response_minutes "the SLA metric"
        varchar utm_campaign
        tinyint spam_score
    }
    offers {
        bigint id PK
        bigint parent_offer_id FK "negotiation as a linked list"
        decimal amount
        decimal amount_base
        enum status
    }
```

---

## Money

```mermaid
erDiagram
    accounts ||--o{ subscriptions : ""
    plans ||--o{ subscriptions : ""
    plans ||--o{ plan_prices : "per currency"
    plans ||--o{ plan_features : ""
    accounts ||--o{ payment_methods : ""
    accounts ||--o{ invoices : ""
    subscriptions ||--o{ invoices : ""
    invoices ||--o{ invoice_lines : ""
    invoices ||--o{ credit_notes : "corrections, never edits"
    invoices ||--o{ payments : ""
    payments ||--o{ refunds : ""
    accounts ||--o{ payouts : ""
    payout_methods ||--o{ payouts : ""
    payouts ||--o{ payout_items : ""
    accounts ||--o{ ledger_entries : "double entry"
    coupons ||--o{ coupon_redemptions : ""
    listings ||--o{ featured_placements : "paid promotion"
    accounts ||--o{ account_credits : "prepaid"

    invoices {
        bigint id PK
        varchar invoice_number UK "gapless"
        enum status "draft|open|paid|void|..."
        decimal total
        decimal exchange_rate "snapshot at issue"
        decimal total_base
    }
    ledger_entries {
        bigint id PK
        char transaction_group "debits = credits per group"
        varchar ledger_account "cash|revenue|tax_payable|..."
        enum entry_type "debit|credit"
        decimal amount_base
    }
```

---

## Moderation and audit

```mermaid
erDiagram
    report_reasons ||--o{ reports : ""
    reports ||--o{ report_actions : "every moderator action"
    reports ||--o{ reports : "duplicate_of_id"
    users ||--o{ reports : "reporter"
    users ||--o{ report_actions : "actor"
    verification_requests ||--o{ verification_documents : ""

    reports {
        bigint id PK
        enum subject_type "listing|agent|organization|review|..."
        bigint subject_id "polymorphic - no FK"
        json subject_snapshot "content as reported"
        enum status "new|triaged|in_review|escalated|resolved|dismissed"
        enum resolution
        datetime due_at "statutory clock"
    }
    audit_logs {
        bigint id PK
        datetime occurred_at PK "partition key"
        bigint actor_user_id "no FK - must outlive its subject"
        bigint impersonator_user_id "support actions stay attributable"
        varchar action
        json changes "field-level before/after"
    }
    moderation_queue {
        bigint id PK
        enum queue_reason "duplicate_suspected|price_anomaly|banned_terms|..."
        tinyint risk_score
        json signals
    }
```

`reports`, `reviews`, `verification_requests` and `moderation_queue` are
polymorphic: one moderation queue covering every content type is worth more than
the foreign key it gives up. `tools/integrity_check.sql` is the replacement for
that missing constraint.

---

## Analytics: raw stream to dashboard

```mermaid
erDiagram
    analytics_events }o--|| listings : "subject (no FK, partitioned)"
    listings ||--o{ listing_daily_stats : "rollup"
    organizations ||--o{ organization_daily_stats : ""
    agents ||--o{ agent_daily_stats : ""
    locations ||--o{ price_index_daily : ""
    jobs ||--o{ job_runs : ""
    webhooks ||--o{ webhook_deliveries : ""

    analytics_events {
        bigint id PK
        datetime occurred_at PK "monthly partition"
        enum event_type "listing_view|call_click|whatsapp_click|..."
        int category_id "dimensions denormalised at write"
        bigint city_id
        bigint organization_id
        char visitor_id "anonymous, for unique counts"
    }
    listing_daily_stats {
        bigint listing_id PK
        date stat_date PK
        int impressions "appearances in a result list"
        int views "detail-page opens"
        int inquiries "derived from the inquiries table"
        int call_clicks
        int whatsapp_clicks
    }
```

The arrow from `analytics_events` is dashed in intent: there is no foreign key.
InnoDB forbids them on partitioned tables, and a page view must never block on a
lock held against `listings`.

Dashboards read the rollups. Nothing user-facing touches the raw stream.

---

## Editorial

```mermaid
erDiagram
    authors ||--o{ posts : "byline"
    editorial_terms ||--o{ posts : "primary category"
    editorial_terms ||--o{ post_terms : ""
    posts ||--o{ post_terms : "tags, topics, destinations"
    posts ||--o{ post_translations : ""
    posts ||--o{ post_listings : "explicit listing references"
    listings ||--o{ post_listings : ""
    locations ||--o{ editorial_terms : "destination terms map to the tree"
    locations ||--o{ location_landing_pages : "per-location SEO copy"
    pages ||--o{ pages : "parent_id"
    pages ||--o{ page_translations : ""
    navigation_menus ||--o{ menu_items : ""
    menu_items ||--o{ menu_items : "parent_id"

    editorial_terms {
        int id PK
        enum taxonomy "category|tag|topic|destination|series"
        varchar slug "unique per taxonomy"
        bigint location_id FK "destinations link to geography"
    }
    location_landing_pages {
        bigint location_id PK
        int category_id PK
        smallint purpose_id PK
        smallint language_id PK
        json faq "rendered as FAQPage structured data"
    }
```

---

## Property inventory: listing versus unit

The distinction the whole property layer turns on. A listing is an
advertisement — it appears, it expires, the same flat is advertised again next
year by a different agency at a different price. The unit is what persists.

```mermaid
erDiagram
    buildings ||--o{ building_floors : ""
    buildings ||--o{ property_units : ""
    building_floors ||--o{ property_units : ""
    property_units ||--o{ listings : "advertised as, over time"
    property_units ||--o{ unit_ownerships : "shares, current and historic"
    property_units ||--o{ unit_transactions : "registered facts"
    property_units ||--o{ tenancies : ""
    property_units ||--o{ valuations : ""
    tenancies ||--o{ tenancy_parties : "landlord, tenant, guarantor"
    tenancies ||--o{ rent_schedules : "instalments and cheques"
    tenancies ||--o{ maintenance_requests : ""
    valuations ||--o{ valuation_comparables : "what it was built from"
    unit_transactions ||--o{ valuation_comparables : "used as a comparable"
    lenders ||--o{ mortgage_products : ""
    mortgage_products ||--o{ mortgage_applications : ""
    property_units ||--o{ mortgage_applications : ""

    property_units {
        bigint id PK
        bigint building_id FK
        bigint floor_id FK
        varchar unit_number "unique within the building"
        varchar registry_reference "where the jurisdiction publishes one"
        enum occupancy_status "vacant|owner_occupied|tenanted|off_plan"
        decimal last_sale_price "derived from unit_transactions"
        decimal estimated_value "derived from the latest model valuation"
    }
    unit_transactions {
        bigint id PK
        enum transaction_type "sale|resale|rent|inheritance|auction"
        decimal amount "a fact, not an asking price"
        tinyint is_arms_length "family transfers excluded from medians"
        bigint deal_id FK "set when the platform brokered it"
    }
```

---

## Attribution: touch to credit

Four models score the same conversions differently, and the disagreement is the
point. Credit fractions sum to exactly one per conversion per model — asserted
in `099_platform_finalise.sql`, not assumed.

```mermaid
erDiagram
    web_sessions ||--o{ attribution_touchpoints : "one per session"
    attribution_touchpoints ||--o{ conversion_credits : "credited"
    conversions ||--o{ conversion_credits : "divided among touches"
    attribution_models ||--o{ conversion_credits : "by this model"
    attribution_models ||--o{ channel_performance_daily : "part of the grain"
    conversions }o--|| web_sessions : "the converting session"

    attribution_models {
        int id PK
        enum model_type "last_click|first_click|linear|time_decay|position_based"
        smallint lookback_days
        tinyint is_default "the number quoted in the board pack"
    }
    conversion_credits {
        bigint conversion_id PK
        int model_id PK
        bigint touchpoint_id PK
        decimal credit_fraction "sums to exactly 1.000000 per conversion per model"
        decimal credited_value
    }
    conversions {
        bigint id PK
        enum conversion_type "inquiry|call|deal_won|subscription"
        smallint touch_count
        smallint days_to_convert
        enum first_touch_channel
        enum last_touch_channel
    }
```

---

## Governance: what is held, why, and for how long

```mermaid
erDiagram
    data_field_registry }o--|| anonymization_rules : "how to erase it"
    data_field_registry }o--o{ processing_activities : "under this lawful basis"
    processing_activities ||--o{ consent_purposes : "where the basis is consent"
    consent_purposes ||--o{ consent_receipts : "versioned; the receipt names the version"
    retention_policies ||--o{ retention_runs : ""
    legal_holds ||--o{ entity_snapshots : "frozen at the moment of the hold"
    data_subject_requests ||--o| erasure_records : "proof of what was done"
    data_processors }o--o{ processing_activities : "who else touches it"

    data_field_registry {
        int id PK
        varchar table_name
        varchar column_name
        tinyint is_personal_data
        enum lawful_basis "consent|contract|legal_obligation|legitimate_interests"
        enum erasure_action "delete_row|null_field|anonymize|retain_legal_obligation"
        int retention_days
        tinyint include_in_export "answers a subject access request by query"
    }
    legal_holds {
        int id PK
        enum hold_type "litigation|regulatory|investigation|tax"
        json affected_tables
        enum status "active|released|expired"
        varchar release_reason "required when released"
    }
    retention_runs {
        bigint id PK
        int eligible_rows
        int affected_rows
        int held_rows "reported separately, never silently deducted"
        tinyint was_dry_run
    }
```
