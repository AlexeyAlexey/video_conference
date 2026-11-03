# Design

## Context

See proposal.md for motivation. This ports the archived
`add-public-stream-server-keys` feature from the `/admin` portal to the
stream server admin portal (`/stream-server-admin`), simplified to
public-key-only storage and **re-owned by applications**: each key
belongs to a portal application, so the portal can later send a stream
server all of an application's public keys when the server is assigned
(sending is out of scope). Portal conventions apply: dedicated SQLite
repo (`VideoConference.StreamServerAdminPortal.Repo`), `binary_id` UUID
primary keys, migrations under
`priv/stream_server_admin_portal_repo/migrations/`, a forwarded router
needing `/stream-server-admin`-prefixed mirror `live` routes,
`Layouts.stream_server_admin`, inline section-swapping LiveView CRUD via
`push_patch`, and `DropdownComponent` for select fields (native
`<select>` is forbidden).

The portal already has `Applications` (context + `ApplicationsLive` +
`ApiKeysLive`, including `api_keys` as an application-owned entity) and
`StreamServers` with a working `?application_id=` searchable dropdown
filter — both patterns are reused directly. The `/admin` source feature
lives in `AdminPortal.StreamServers` (`PublicStreamServerKey`,
`PublicStreamServerKeysLive`, grouped list); its `KeyEncryption` and
`SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` are **not** needed because the
portal stores no private key material.

## Goals / Non-Goals

**Goals:**

- Portal-owned `public_stream_server_keys` table holding only public
  key material, keyed by UUID and belonging to an application — no
  `public_key_id`, no `private_key`, optional non-unique `name`.
- Portal CRUD on a single "Public keys" page grouped by application,
  with the same application filter UX as the stream servers page.
- Single "Add" creation flow: application dropdown + existing public
  key material.
- Zero new dependencies, zero new env vars, no encryption.

**Non-Goals:**

- Sending an application's keys to a stream server on assignment — the
  user marked this as a separate task; this change only stores the data
  that future flow will read.
- Any change to the `/admin` public keys page, the main repo's
  `public_stream_server_keys` table, or `KeyEncryption`.
- Key pair generation, private key storage or encryption, `kid`/claim
  placement in JWTs.

## Decisions

### D1: Record UUID is the public key id — no `public_key_id` field

Unlike the `/admin` version (where an external stream server assigns
`public_key_id` after the public key is shared), the portal issues the
id itself: the record's `binary_id` primary key is the public key id,
available from insert. The migration omits `public_key_id`; the list's
"Public key Id" column renders `key.id`. Alternative — a separate
`public_key_id` column defaulting to the id — rejected: two columns for
one value invites drift.

### D2: No private key, no encryption, no generation

The portal persists only `public_key` material the admin pastes in.
There is no `private_key` column, no `private_key_pem` virtual field, no
`KeyEncryption` dependency, no `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY`
requirement, and no `JOSE`/`generate_key_pair` code or `:generate` live
action. Per the user's exception, the portal never holds private
material, so nothing needs encrypting.

### D3: Keys belong to applications, in the `Applications` context

`public_stream_server_keys` has `application_id` →
`references(:applications, type: :binary_id, on_delete: :delete_all)`
(deleting an application removes its keys, mirroring how
`application_stream_servers` cascades). The schema lives at
`StreamServerAdminPortal.Applications.PublicStreamServerKey` with CRUD
on `StreamServerAdminPortal.Applications` — matching `ApiKey`, the other
application-owned entity — and `Application` gains `has_many
:public_stream_server_keys` for the grouped preload. Alternative —
`StreamServers` namespace, echoing the "stream server key" name —
rejected: the association owner, the grouping, the dropdown, and the
sidebar placement are all application-side. `name` is a plain nullable
string: no `null: false`, no unique index, no uniqueness validation,
since the UUID carries identification.

### D4: Page grouped by application with the stream-servers-style filter

`VideoConferenceWeb.StreamServerAdminPortal.PublicStreamServerKeysLive`
(live actions `:index`/`:new`/`:edit`) renders sections per application
(keys or a "No public keys yet" line each), an "Add key" action, and a
searchable `DropdownComponent` filter — same construction as
`StreamServersLive`: wrapped in `<.form onsubmit="event.preventDefault()">`,
picking a value `push_patch`es `?application_id=<id>` (or no param for
all), `handle_params` applies it via
`Applications.list_applications_with_public_keys(application_id: filter)`
(filtered queries preload keys only for the chosen application; there is
no "unassigned" option because keys always belong to an application).
The `application_picked` form handler drops `String.to_integer/1` —
portal ids are UUID strings. Routes: `/applications/public-stream-server-keys`,
`/applications/public-stream-server-keys/new`, `/applications/public-stream-server-keys/:id/edit` plus
`/stream-server-admin`-prefixed mirrors. They cannot collide with
`/applications/:id/edit` (different arity / literal tails) but are still
placed before the `:id` routes for readability. The "Public key Id"
column renders `key.id` next to a copy-to-clipboard button (same
`navigator.clipboard.writeText` pattern as the stream servers page's
cert hash); the page description explains the id identifies
which public key verifies the application's signed JWT. Long
descriptions truncate at 50 characters with a `...` preview that expands
on click, and both preview and full text wrap (`break-all`, plus
`whitespace-pre-wrap` for the full text) inside the column so unbroken
text never overflows or overlaps other columns.

### D5: Sidebar sub-item under "Applications"

`admin_components.ex` adds a "Public keys" link inside the existing
nested `<ul>` under "Applications", alongside "API keys".

## Risks / Trade-offs

- [The `/admin` registry (stream-server-owned keys) and the portal
  registry (application-owned keys) now differ in shape and meaning] →
  Accepted: they serve the two sides of the same relationship; a future
  change may sync them when the send-keys-on-assignment flow lands.
- [Optional non-unique `name` leaves rows hard to tell apart] →
  Mitigated by the UUID public key id being the primary identifier shown
  in the list; name is auxiliary metadata.
- [Mirror-route drift breaks LiveView mounts (infinite reload)] → Every
  real route gets a `/stream-server-admin` mirror; browser validation
  covers each action.
- [UUID shown as public key id is long for the table column] → Render
  the full UUID; truncation is possible later if it proves unwieldy.

## Migration Plan

1. Add the portal-repo migration (new table only — no data migration;
   the portal key registry starts empty).
2. Deploy runs `mix ecto.migrate` for both repos as today.

## Follow-up (not this change)

- When a stream server is assigned to an application, send that
  application's public stream server keys to the server — consumes this
  registry.
