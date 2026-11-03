# Proposal

## Why

The stream server public keys page in the stream server admin portal edits every
attribute of a key through a single full-row edit form — including the public
key material itself, which should be immutable once registered (a stream server
relies on the key id → key mapping to verify signed JWTs). The page also exposes
raw state as text and buries destructive actions inline. Finer-grained, per-field
editing makes the key material tamper-proof and matches how the other portal
pages are evolving.

## What Changes

- **BREAKING (UI flow)**: The whole-row Edit action and the `/stream-server-admin/applications/stream-server-public-keys/:id/edit` route are removed. Editing happens through targeted per-field modals instead.
- The public key material becomes **immutable after creation** — enforced at the changeset level, not just hidden in the UI. The `:new` form still requires it.
- A new **Public key** column shows a "show" icon instead of key content; clicking it opens a modal with the full key and a copy-to-clipboard control.
- **Name** and **Description** each get a pencil icon that opens a small edit modal.
- The **Status** column is renamed **Enabled** and shows a live checkbox (checked = enabled) that toggles the key immediately on click.
- Row actions collapse into a three-dots (⋯) menu containing **Change app** (modal with an application dropdown) and **Remove** (with the existing confirm).
- The context gains granular update functions — `rename_stream_server_public_key/2`, `edit_stream_server_public_key_description/2`, `switch_stream_server_public_key_application/2`, `enable_stream_server_public_key/1`, `disable_stream_server_public_key/1` — and the generic `update_stream_server_public_key/2` is removed along with its only caller (the `:edit` form).
- Modals are event-driven (no new routes): the codebase has no modal component, so this introduces the first modal markup in the LiveView.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `portal-public-stream-server-keys`: the record requirement gains key immutability; the admin list requirement changes columns (Public key show-modal, Enabled checkbox); the management requirement replaces full-row edit with per-field modals, an application switch, and a row actions menu.

## Impact

- **Code**: `lib/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live.ex` (major rework), `lib/video_conference/stream_server_admin_portal/applications.ex` (new functions, removed updater), `lib/video_conference/stream_server_admin_portal/applications/stream_server_public_key.ex` (per-field changesets — `key` appears in no update cast), `lib/video_conference_web/stream_server_admin_portal/router.ex` (`:edit` route removed, both real and mirror).
- **Tests**: `test/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live_test.exs`, `test/video_conference/stream_server_admin_portal/applications_test.exs`.
- **Routes**: `GET /stream-server-admin/applications/stream-server-public-keys/:id/edit` disappears; `:new` and `:index` are unchanged.
- No database migration needed — immutability is enforced in the changeset.
