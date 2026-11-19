# Proposal

## Why

The portal feature shipped in `add-public-stream-server-keys` uses
`public_stream_server_keys` / `public_key` naming, but the intended
terminology is *stream server public keys*: the entity is "a stream
server public key", so the table, field, modules, routes, and labels
should read `stream_server_public_keys` / `key`. Renaming now — before
the feature accumulates call sites and before it is released — is far
cheaper than renaming later.

## What Changes

- **BREAKING** Rename the portal table `public_stream_server_keys` →
  `stream_server_public_keys` by **editing the unreleased create
  migration in place** (same migration version; file and module renamed
  `CreateStreamServerPublicKeys`). Dev/test portal databases recreate
  the table — no data-preserving rename migration is added.
- **BREAKING** Rename the record field `public_key` → `key` (schema,
  changeset, migration, fixtures, form params, tests), and replace the
  `disabled` flag (default false) with `enabled` (default true) — same
  checkbox/status semantics, positive polarity.
- Rename the schema `Applications.PublicStreamServerKey` →
  `Applications.StreamServerPublicKey`, the `has_many
  :public_stream_server_keys` association, and all context functions
  (`*_public_stream_server_key*` → `*_stream_server_public_key*`,
  `list_applications_with_public_keys` →
  `list_applications_with_stream_server_public_keys`).
- Rename `PublicStreamServerKeysLive` → `StreamServerPublicKeysLive`,
  its routes `/applications/public-stream-server-keys*` →
  `/applications/stream-server-public-keys*` (plus the
  `/stream-server-admin`-prefixed mirror routes), and all `public-key-*`
  DOM ids → `key-*`.
- **BREAKING** User-facing surface renames: sidebar sub-item "Public
  keys" → "Stream server public keys" (path updated), page title/header
  "Public Keys" → "Stream Server Public Keys", "Public key Id" column →
  "Key Id", flash messages and the page description wording.
- The `/admin` portal's `public_stream_server_keys` feature is
  untouched — this rename applies only to the stream server admin
  portal.
- No behavior change: same CRUD, filter, copy-id, truncation/expand, and
  responsive semantics under new names.

## Capabilities

### New Capabilities

### Modified Capabilities

- `portal-public-stream-server-keys`: Every requirement is reworded to
  the new terminology — requirement names rename from *public stream
  server key* to *stream server public key*, the record requirement uses
  the `key` field name, and the page URL becomes
  `/stream-server-admin/applications/stream-server-public-keys`.
- `stream-server-admin-portal`: The *Portal navigation* requirement
  changes — the sidebar sub-item "Public keys" becomes "Stream server
  public keys".

## Impact

- Edited in place:
  `priv/stream_server_admin_portal_repo/migrations/20261103100000_create_public_stream_server_keys.exs`
  (renamed file/module, `stream_server_public_keys` table, `key`
  column). Already-migrated dev portal DBs must drop the old table /
  recreate the portal DB — dev data is discarded.
- `lib/video_conference/stream_server_admin_portal/applications/`:
  renamed schema file/module, `Application` association.
- `lib/video_conference/stream_server_admin_portal/applications.ex`:
  renamed functions.
- `lib/video_conference_web/stream_server_admin_portal/live/`:
  renamed LiveView file/module, assigns, form param
  `stream_server_public_key`, DOM ids, labels.
- `router.ex`: renamed routes and mirror routes.
- `admin_components.ex`: renamed sidebar link, label, path.
- Tests: renamed fixture helpers, LiveView test file/module, updated
  ids, strings, and form params.
- No new dependencies, no new env vars.
