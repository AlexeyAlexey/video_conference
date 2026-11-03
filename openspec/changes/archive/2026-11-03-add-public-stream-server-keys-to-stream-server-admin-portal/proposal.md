# Proposal

## Why

The stream server admin portal manages applications and the stream
servers assigned to them, but it has no registry of the public keys each
application uses — the keys a stream server needs to verify the signed
JWTs that application's participants present when connecting. The
`/admin` portal already has a related feature
(`public_stream_server_keys` in the main database); the portal needs its
own per-application key registry so that when a stream server is
assigned to an application, the portal has all of that application's
public stream server keys to send it (sending is a future change).

## What Changes

- Port the public stream server keys feature to the stream server admin
  portal, re-shaped around applications: a new
  `public_stream_server_keys` table in the **portal database** with a
  UUID (`binary_id`) primary key, an optional non-unique `name`,
  `public_key`, `application_id` (FK to the portal `applications`
  table, `delete_all`), a `disabled` flag, `description`, and
  timestamps.
- Keys belong to **applications**, not stream servers: an application
  can have multiple public stream server keys.
- **No `public_key_id` field** (difference from the `/admin` version):
  the record's UUID primary key *is* the public key id — the portal
  assigns it at creation instead of the id arriving later from an
  external stream server.
- **No `private_key`** (difference from the `/admin` version): the
  portal stores only already-existing public key material. Nothing is
  encrypted, so no key encryption helper or
  `SECRET_KEY_TO_ENCRYPT_PRIVATE_KEY` is involved.
- **No generation flow** (difference from the `/admin` version): the
  portal never creates key pairs. The single creation flow is "Add"
  (application dropdown, name, public key — the admin pastes existing
  public key material).
- New `PublicStreamServerKey` schema and context CRUD functions under
  the portal `Applications` context.
- New portal page "Public keys" as a sub-item under "Applications" in
  the portal sidebar, at `/stream-server-admin/applications/public-stream-server-keys`,
  listing keys **grouped by application**. The list's "Public key Id"
  column shows the key record's UUID.
- An application filter on the page — the same searchable
  `DropdownComponent` filter as the stream servers page — limiting the
  list to the chosen application's keys (`?application_id=` in the URL).
- Out of scope: sending an application's public stream server keys to a
  stream server when the server is assigned (explicitly a follow-up
  task), which key is chosen when several are enabled, and any JWT
  `kid`/verification wiring. The `/admin` portal's
  `public_stream_server_keys` table, page, and `KeyEncryption` are
  untouched.

## Capabilities

### New Capabilities

- `portal-public-stream-server-keys`: Management of per-application
  public stream server keys in the stream server admin portal —
  UUID-keyed persistence in the portal database with the record id
  serving as the public key id, admin CRUD, the grouped-by-application
  listing, and the application filter.

### Modified Capabilities

- `stream-server-admin-portal`: The *Portal navigation* requirement
  changes — the sidebar gains a "Public keys" sub-item under
  "Applications".

## Impact

- New portal-repo migration under
  `priv/stream_server_admin_portal_repo/migrations/` creating
  `public_stream_server_keys` (binary_id PK, `application_id` binary_id
  FK, no private key or public_key_id columns, `name` nullable).
- New schema under
  `lib/video_conference/stream_server_admin_portal/applications/` (e.g.
  `public_stream_server_key.ex`); `has_many
  :public_stream_server_keys` added to the `Application` schema; new
  functions on `StreamServerAdminPortal.Applications`
  (`list_applications_with_public_keys/1` with optional application
  filter, CRUD).
- New `VideoConferenceWeb.StreamServerAdminPortal.PublicStreamServerKeysLive`
  plus `/applications/public-stream-server-keys*` routes and `/stream-server-admin`-prefixed
  mirror routes in the portal router; "Public keys" sub-item in the
  portal sidebar.
- No new dependencies, no new env vars, no encryption configuration.
- Tests: context tests, LiveView tests, `PublicStreamServerKeysFixtures`
  for the portal, integrated-browser validation.
