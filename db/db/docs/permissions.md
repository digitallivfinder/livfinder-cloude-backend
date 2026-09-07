# Permissions

## The problem this replaced

Two vocabularies were in use and only one of them was enforced.

- **26 coarse codes** in `permissions` (`listings.view`, `users.edit`, …). Every admin endpoint
  checked one of these. This was the security boundary.
- **~141 granular ids** in the admin frontend (`listings.cars.edit`,
  `locations.subCommunity.create`, …), drawn as checkboxes in the Role Access matrix.

The second was mapped back onto the first for display. The consequence is worse than a missing
feature: ticking **Cars → Edit** and leaving **Yachts → Edit** clear produced a role that could
edit *every* category, because the server only ever saw `listings.edit`. The matrix showed
control that did not exist.

A proposed fix (migration 0031) made all 141 ids real rows. That closes the drift, but encodes
categories and page names into the permission key — which LIV-IAM-001 §6.2 forbids in as many
words:

> Do not encode organization IDs, countries or categories into the permission key; use scopes
> and attributes.
>
> Do not name permissions after pages or UI components.

It also does not scale: a seventh marketplace category would mint six more permissions, a sixth
location tier four more.

## The model

Two dimensions instead of one.

| | Question | Where it lives |
|---|---|---|
| **Permission** | May this role do this action at all? | `permissions.code` = `<domain>.<action>` |
| **Scope** | Over which subset of records? | `role_scopes` |

```
role_permissions (role_id, permission_id)             -- what
role_scopes      (role_id, scope_type, scope_value)   -- over which subset
```

`scope_type` is `category`, `location` or `organization`. Only `category` is read by the
application today; the other two are declared so adding them is application work rather than a
migration.

**No rows for a scope type means unrestricted.** Restriction is something an administrator opts
into, so every existing role keeps working and a role created without touching the category
selector behaves exactly as before. A user holding several roles gets the union — one
unrestricted role makes the user unrestricted, which is the correct reading of "both of these
roles apply to me".

## Enforcement

Two checks, both server-side. Neither is optional and neither is sufficient alone.

```js
requirePermission("listings.edit")        // holds the action?
assertCategoryScope(req, "yachts")        // for this category?
```

Three call sites cover every route:

| Situation | Guard |
|---|---|
| Category is in the URL (`/categories/:category/dashboard`) | `requireCategoryScope("params", "category")` |
| Resource addressed by id (`/listings/:id/moderation`) | `scopeListingParam()` — one indexed read before the handler |
| Listing a collection | `scopedRootCategoryIds(req)` filters the query rather than rejecting |

A scoped-out record returns **404, not 403**. Confirming that a record exists is itself a
disclosure — a competitor should not learn that a reference is real.

A list is *filtered*, not refused: the page still works and contains what the user may act on.

## The catalogue

105 codes across 28 domains. `GET /v1/admin/roles/options` returns them as a matrix so the UI
derives its grid from data:

```json
{
  "permissionMatrix": {
    "actions": ["view", "create", "edit", "delete", "moderate", "..."],
    "domains": [
      { "id": "listings", "label": "Listings", "scopable": true,
        "actions": { "view": { "code": "listings.view", "label": "View listings" }, "...": {} } }
    ]
  },
  "categoryScopeOptions": [{ "value": "cars", "label": "Cars" }]
}
```

`scopable` marks the domains where a category restriction is meaningful — listings, developments,
leads, inquiries, bookings, offers, reviews, media. "Settings, but only for yachts" is not a
coherent grant, so the selector is not offered for the rest.

**Adding a permission is a migration, not a frontend change.** Insert the row; it appears in the
Role Access matrix on the next request. A domain the frontend has never heard of renders under
"Other" rather than disappearing.

## What the developer asked for, and where it landed

> permissions should be specific based on each page and task, for example each category should
> have its own permissions e.g. `listings.add, edit, delete, create, moderate`, `leads.add, edit`
> and all other tabs

Every one of those exists and is enforced per category — through the scope, not the key:

| Asked for | Delivered |
|---|---|
| `listings.add / edit / delete / moderate` | `listings.create`, `listings.edit`, `listings.delete`, `listings.moderate`, plus `view`, `feature`, `export` |
| `leads.add / edit` | `leads.create`, `leads.edit`, plus `view`, `delete`, `assign`, `export` |
| "each category its own" | `role_scopes` with `scope_type='category'` — enforced on the server, unlike the old checkboxes |
| "all other tabs" | 28 domains covering every admin page and portal tab |

A "Cars Moderator" is `listings.moderate` + a `category=cars` scope row. A seventh category needs
one scope row, not six new permissions.

## Roles as seeded

| Role | Grants | Shape |
|---|---|---|
| `super_admin` | 105 | Everything, materialised so the matrix shows the truth |
| `admin` | 100 | Everything except finance and the secure settings |
| `support` | 40 | Read widely; write where a support conversation needs it |
| `moderator` | 36 | The queue and what a decision touches |
| `analyst` | 33 | View and export only |
| `editor` | 28 | Content, media, collections, SEO, email |
| `finance` | 16 | Money, plus the accounts it applies to |

## Migration and compatibility

`0032_permission_model.sql` is idempotent and preserves every existing grant. Six codes that did
not fit the grammar were retired **after** their grants were translated:

| Retired | Became |
|---|---|
| `accounts.verify` | `companies.verify`, `individuals.verify` |
| `accounts.type_change` | `categoryAccess.view`, `categoryAccess.decide` |
| `locations.manage` | `locations.view/create/edit/delete` |
| `taxonomy.manage` | `taxonomy.view/create/edit/delete` |
| `moderation.queue` | `moderation.view/decide`, `reviews.moderate` |
| `system.logs` | `system.view`, `system.export` |

Widening is deliberate and one-directional: `locations.manage` really did permit create, edit and
delete, so translating it to all four loses nothing and grants nothing new.

## Extending it

- **A new action on an existing domain** — one `INSERT` into `permissions`. It appears in the
  matrix immediately.
- **A new domain** — insert its rows and add the domain id to `DOMAIN_GROUPS` in
  `frontend/src/app/admin/_lib/auth/permissionCatalog.js` so it groups sensibly. Skipping that
  step puts it under "Other"; it still works.
- **A new scope type** — `role_scopes.scope_type` already accepts `location` and `organization`.
  Add the resolver in `modules/auth/rbac.js` and a guard beside `assertCategoryScope`.
- **Never** put a category, a country or a page name in a permission code. That is what the scope
  is for, and it is the mistake this model exists to correct.
