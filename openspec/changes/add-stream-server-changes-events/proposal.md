# Proposal

## Why

Stream server mutations in the portal commit silently — creating,
removing, and assigning/unassigning a server to applications records
no domain event, so event store listeners cannot observe the lifecycle
changes the stream server infrastructure cares about. Stream servers
are the only remaining portal aggregate without events; applications
and stream server public keys already emit on every meaningful
mutation.

## What Changes

- Add event modules under
  `lib/video_conference/stream_server_admin_portal/stream_servers/events/`:
  `StreamServerWasAdded`, `StreamServerWasRemoved`,
  `StreamServerWasAssignedToApplication`, and
  `StreamServerWasUnassignedFromApplication`, in the context's flat
  `StreamServers` namespace.
- Rework `create_stream_server/1`, the stream server removal, and
  `assign_application/2` / `unassign_application/2` to commit
  record + event atomically via `Ecto.Multi` + `EventStore.append`,
  keeping `stale_error_field: :lock_version` on the delete.
- **BREAKING** (context API): rename `delete_stream_server/1` to
  `remove_stream_server/1` so the function name pairs with its
  `StreamServerWasRemoved` event.
- Assignment events land on the stream server's stream and carry the
  `application_id` they describe. Assigning or unassigning bumps the
  server's `lock_version` like any other server update, and the events
  carry the incremented value. No-op assignments/unassignments still
  emit, matching the event store's no-op-emits invariant.
- Renames and description, country, and certificate-hash edits emit
  **no** event — they are portal-cosmetic fields downstream listeners
  do not consume, so those mutations stay plain `Repo.update` calls.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `stream-server-directory`: new requirements cover lifecycle events
  for create, remove, and application assign/unassign, what each event
  carries, and the no-op-emits / failed-mutation-stores-nothing
  behavior.

## Impact

- `lib/video_conference/stream_server_admin_portal/stream_servers.ex` —
  four mutations reworked to `Ecto.Multi` + `EventStore.append`;
  `delete_stream_server/1` renamed to `remove_stream_server/1`; a
  `transaction_result/1` helper added.
- `lib/video_conference/stream_server_admin_portal/stream_servers/events/`
  — new folder, four event modules added.
- `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`
  — call site updated for the renamed removal function.
- `test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs`
  — `new/1`–`new/2` mapping tests per event and stored-event
  assertions per mutation; `delete_stream_server/1` describes renamed.
- The separate `VideoConference.AdminPortal.StreamServers` context
  (email/password admin portal) also has `delete_stream_server/1` —
  it is a different context with no event store and stays untouched.
