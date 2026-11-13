# Design

## Context

The stream server admin portal (`/stream-server-admin`, own Repo, own
migrations under `priv/stream_server_admin_portal_repo`) manages two API
key-adjacent things today: `api_keys` belonging to applications
(`Applications.ApiKey`, bcrypt `hashed_api_key`, virtual `plaintext_key`,
no `lock_version`, no events) and `stream_server_public_keys` also
belonging to applications (lock-versioned, per-field portal editing,
event-sourced). Stream servers themselves live in the `StreamServers`
context with `lock_version` and events on create/assign/remove. The new
stream server API keys sit between these two: storage like application
API keys, management UX like the public keys page.

See proposal.md — Why for motivation.

## Goals / Non-Goals

**Goals:**

- A `stream_server_api_keys` record per stream server with hashed-only
  secrets, one-time plaintext display, and `lock_version` concurrency.
- A single-owner, server-filtered admin page with per-field editing,
  consistent with the public keys page's modal pattern.
- One shared secret-generation implementation for both API key scopes.

**Non-Goals:**

- No key deletion from the UI (revocation = disable; deletion can be a
  later change if needed).
- No event-store emission for API key mutations (matches application API
  keys; stream-server events cover the server aggregate, not its keys).
- No verification/authentication endpoint consuming these secrets — the
  REST API these keys will authenticate is a separate change.
- No polymorphic owner on the existing `api_keys` table.

## Decisions

### Separate `stream_server_api_keys` table, not a shared `api_keys`

`api_keys.application_id` is `NOT NULL` and every constraint assumes an
application owner. Making it nullable and adding `stream_server_id`
creates a two-FK polymorphic row needing a CHECK constraint and weakens
the "key belongs to an application" invariant. A dedicated table inside
the `StreamServers` context keeps each aggregate self-contained, matching
how the codebase separates `Applications` and `StreamServers`.

New schema `StreamServers.ApiKey` (table `stream_server_api_keys`):
`id` binary_id PK, `stream_server_id` FK `on_delete: :delete_all`,
`name`, `hashed_api_key`, `description`, `enabled` (default true),
`lock_version` (default 1), timestamps. Unique index on
`(stream_server_id, hashed_api_key)` only — names are deliberately not
unique (unlike application API keys), per the request.

### Shared `StreamServerAdminPortal.ApiKeySecret` module

`Applications.generate_api_key_secret/0` moves into a new
`ApiKeySecret` module exposing `generate/0` (`"ssak_" <>`
`Base.url_encode64(32 random bytes)`) and `hash/1`
(`Bcrypt.hash_pwd_salt`). Both `Applications.create_api_key/1` and the new
`StreamServers.create_stream_server_api_key/1` call it.
`Applications.generate_api_key_secret/0` is kept as a one-line delegate —
the `ssak_` ("stream server api key") prefix already fits both scopes and
existing tests may call it. Alternatives considered: duplicating the
function in `StreamServers` (rejected — the request explicitly asks to
encapsulate it); a per-scope prefix (rejected — one prefix is already
descriptive of both).

### Context API on `StreamServers`

Mirrors the `StreamServer` per-field style rather than the single
`update_api_key/2` used for application keys:

- `list_stream_server_api_keys(stream_server_id)` — keys ordered by name
- `get_stream_server_api_key!(id)`
- `create_stream_server_api_key(attrs)` — generates the secret via
  `ApiKeySecret`, stores only the hash, returns `{:ok, key}` with
  `plaintext_key` set once
- `rename_stream_server_api_key(id, name)`
- `edit_stream_server_api_key_description(id, description)`
- `enable_/disable_stream_server_api_key(id)`
- `change_stream_server_api_key/2` for the create form

The schema gets `changeset/2` (create) plus `name_changeset/2`,
`description_changeset/2`, and `enabled_changeset/2`, each with
`optimistic_lock(:lock_version)`, and updates pass
`stale_error_field: :lock_version` — the same treatment `StreamServer`
and `StreamServerPublicKey` have. No delete function (no Remove action).

### Page: index-only LiveView, required filter, modal add

`StreamServerApiKeysLive` at `/stream-server-admin/stream-servers/api-keys`
(plus the `/stream-server-admin`-prefixed mirror route required for LV
`route_info` resolution — see the note in the portal router).

- **Filter**: `DropdownComponent` with `searchable` and options
  `{"#{s.name} (#{s.host})", s.id}`; no `empty_label`, so "all servers"
  cannot be selected. Picking pushes `?stream_server_id=` into the URL
  via `push_patch`, like the public keys page's application filter.
- **Nothing picked**: the table area renders a select-a-server prompt and
  the "Add API key" button is hidden/disabled. The component still
  accepts an empty field value, so no dropdown change is needed.
- **Add modal**: event-driven (no `:new` route), reusing the private
  `modal/1` component pattern from `StreamServersLive` and
  `StreamServerPublicKeysLive`. The form shows the filtered server as
  read-only "name (host)" text; `stream_server_id` is injected into the
  params at save time from the filter assign, not submitted through a
  form field.
- **One-time secret**: same banner + copy + dismiss flow as
  `ApiKeysLive` (`new_key_secret` assign).
- **Table**: name + pencil → rename modal; description (truncated at 50
  chars with expand) + pencil → description modal; enabled checkbox →
  `toggle-enabled` event calling enable/disable. Stale `lock_version`
  failures surface as modal changeset errors or an error flash, matching
  the existing pages.
- **Sidebar**: the "Stream servers" `<li>` gains a nested `<ul>` with an
  "API keys" link — same markup shape as the Applications group.

## Risks / Trade-offs

- **[Two different "API keys" pages/schemas]** — `Applications.ApiKey` and
  `StreamServers.ApiKey` share a name. Aliases stay unambiguous because
  each is referenced through its context namespace; the sidebar labels
  distinguish the pages by their parent group.
- **[Non-unique names make keys harder to tell apart]** — deliberate per
  the request; description exists for disambiguation.
- **[Required filter breaks the "no param" deep link]** — mitigated by
  the select-a-server prompt; picking a server restores the URL param.
- **[Secret-hash unique-index collision]** — a duplicate generated secret
  would fail the insert; probability is negligible (256-bit random), and
  a retry generates a new secret.
- **[Disabled-but-present keys accumulate]** — no delete means revoked
  keys linger as disabled rows; acceptable until a deletion change is
  requested.

## Migration Plan

One new migration in `priv/stream_server_admin_portal_repo/migrations`
creating `stream_server_api_keys`; run via the standard portal repo
migration task (`.env`-driven). No data migration — the table is new.
Rollback is `mix ecto.rollback` on the portal repo; nothing else depends
on the table yet.
