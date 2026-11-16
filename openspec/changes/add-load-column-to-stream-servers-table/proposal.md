# Proposal

## Why

Portal admins currently have no visibility into how busy each stream
server is. Storing a per-server load value (0–100) in the directory —
and surfacing it on the stream servers list — is the foundation for
later capacity-aware routing and monitoring. How the value is computed
or reported is deliberately out of scope; this change only persists
and displays it.

## What Changes

- Add a `load` integer column to the portal repo's `stream_servers`
  table: `null: false`, `default: 0`, with a `0 <= load <= 100` check
  constraint.
- Add `load` to the `StreamServer` schema and a `load_changeset` that
  validates the 0–100 range.
- Add `StreamServers.update_stream_server_load/2` as the write path.
  Load updates are **not** guarded by `optimistic_lock` and do not
  increment `lock_version`, so frequent load reports can never stale
  out a pending admin edit. No event is appended — load is telemetry,
  not domain state.
- Show the load on `/stream-server-admin/stream-servers` as a new
  `Load` column (progress bar + percentage). No edit affordance — the
  field is read-only in the UI.
- `StreamServerWasAdded` is unchanged: `load` is deliberately excluded
  from the creation event payload.

## Capabilities

### New Capabilities

- None

### Modified Capabilities

- `stream-server-directory`: adds the `load` field semantics
  (range, default, lock-version-exempt write path, no event) and adds
  load to the columns shown on the portal stream servers list.

## Impact

- **Migration**: new migration in `priv/stream_server_admin_portal_repo/migrations/`.
- **Schema**: `StreamServerAdminPortal.StreamServers.StreamServer`.
- **Context**: `StreamServerAdminPortal.StreamServers` — new
  `update_stream_server_load/2` and `load_changeset`.
- **UI**: `StreamServerAdminPortal.StreamServersLive` — new table
  column; no new modal or event.
- **Events**: none — `StreamServerWasAdded` and the event store are
  untouched.
- **Out of scope**: computing/reporting the load value, any API
  endpoint for servers to self-report, and showing load on the
  `/admin/stream-servers` page (separate repo/table).
