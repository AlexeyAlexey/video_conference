# Proposal

## Why

The stream servers page in the stream server admin portal edits every
attribute of a server through a single full-row edit form — including the
`host`, which should be immutable once registered (it is the server's
network identity) and which currently accepts duplicates. The application
assign view collects checkbox changes behind a Save button, so a single
(un)assignment costs a full form submit. Finer-grained, per-field editing
makes `host` tamper-proof, lets `host` be unique, and matches how the
public keys page was reworked.

## What Changes

- **BREAKING (UI flow)**: The whole-row Edit action and the
  `/stream-server-admin/stream-servers/:id/edit` route are removed.
  Editing happens through targeted per-field modals instead.
- `host` becomes **immutable after creation** — enforced at the
  changeset level (it appears in no update cast), not just hidden in the
  UI. The `:new` form still collects it. It also becomes **unique**,
  enforced by `unsafe_validate_unique` + `unique_constraint` and a new
  unique index.
- **Name** gets a pencil icon that opens a rename modal (uniqueness
  validation kept). **Country** gets a pencil that opens a modal with
  the searchable country `DropdownComponent`. A new **Description**
  column gets a pencil that opens a textarea modal. **Cert hash** gets
  a pencil that opens an input modal — a blank value clears the hash.
- The assign view loses its Save button: each application checkbox
  toggles immediately, sending a request that assigns or unassigns
  that one application to the server. Cancel is replaced by a Back
  link to the list.
- `stream_servers` gains a `lock_version` integer column (default 1)
  with `Ecto.Changeset.optimistic_lock/3` applied on every
  update/delete path; stale conflicts surface as changeset errors
  rather than `Ecto.StaleEntryError` crashes — the same treatment the
  event-store change gave public keys.
- The context gains granular update functions —
  `rename_stream_server/2`, `edit_stream_server_description/2`,
  `edit_stream_server_cert_hash/2`, `edit_stream_server_country/2`,
  `assign_application/2`, `unassign_application/2` — and the generic
  `update_stream_server/2` and `assign_applications/2` are removed
  along with their callers.
- Modals are event-driven (no new routes), reusing the private `modal`
  component pattern introduced on the public keys page.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-directory`: the record requirement gains `host`
  uniqueness and immutability plus a `lock_version` column; a new
  optimistic-concurrency requirement covers update/delete; the list
  requirement gains a Description column; the management requirement
  replaces full-row edit with per-field modals; the assignment
  requirement replaces select-and-save with immediate per-checkbox
  toggles.

## Impact

- **Code**:
  `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`
  (major rework),
  `lib/video_conference/stream_server_admin_portal/stream_servers.ex`
  (new functions, removed updaters),
  `lib/video_conference/stream_server_admin_portal/stream_servers/stream_server.ex`
  (per-field changesets + `host` uniqueness — `host` appears in no
  update cast),
  `lib/video_conference_web/stream_server_admin_portal/router.ex`
  (`:edit` route removed, both real and mirror).
- **Migration**: unique index on `stream_servers.host` and a
  `lock_version` column (default 1, not null) in
  `priv/stream_server_admin_portal_repo/migrations/`.
- **Tests**:
  `test/video_conference_web/stream_server_admin_portal/live/stream_servers_live_test.exs`,
  `test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs`.
- **Routes**: `GET /stream-server-admin/stream-servers/:id/edit`
  disappears; `:new`, `:index`, and `:assign` are unchanged.
- No event store changes — stream server mutations do not emit events.
