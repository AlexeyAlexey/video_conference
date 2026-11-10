# Proposal

## Why

Only stream server public key *creation* records a domain event — enable,
disable, remove, and move-to-another-application mutations commit
silently, so event store listeners cannot observe the key lifecycle
changes the stream server cares about. The one existing event also
predates the event-module convention: it lives outside `events/`, is
named `StreamServerPublicKeyAddedEvent` instead of past tense, and lacks
the `id`/`lock_version` fields every `ApplicationWas*` sibling carries.

## What Changes

- Move `stream_server_public_key_added_event.ex` into
  `applications/events/` and rename the module
  `StreamServerPublicKeyAddedEvent` to `StreamServerPublicKeyWasAdded`,
  adding `id` and `lock_version` fields to match the sibling event
  convention. **BREAKING**: rows already stored under the old event type
  are orphaned (payloads decode via `binary_to_term`; dev data only).
- Add event modules under `applications/events/`:
  `StreamServerPublicKeyWasEnabled`, `StreamServerPublicKeyWasDisabled`,
  `StreamServerPublicKeyWasRemoved`, and `StreamServerPublicKeyWasMoved`
  (carrying `from_application_id` and `to_application_id`).
- Rework `enable_stream_server_public_key/1`,
  `disable_stream_server_public_key/1`, the application move, and the
  key removal to commit record + event atomically via `Ecto.Multi` +
  `EventStore.append`, keeping `stale_error_field: :lock_version`.
- **BREAKING** (context API): rename `delete_stream_server_public_key/1`
  to `remove_stream_server_public_key/1` and
  `switch_stream_server_public_key_application/2` to
  `move_stream_server_public_key_to_application/2` so function names
  pair with their event names.
- Key renames and description edits emit **no** event — they are
  portal-cosmetic fields downstream listeners do not consume, so those
  mutations stay plain `Repo.update` calls.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `portal-public-stream-server-keys`: the creation-event requirement is
  updated for the renamed `StreamServerPublicKeyWasAdded` module and its
  added `id`/`lock_version` fields; new requirements cover lifecycle
  events for enable/disable/remove/move and the `lock_version` each
  event carries.

## Impact

- `lib/video_conference/stream_server_admin_portal/applications.ex` —
  four mutations reworked to `Ecto.Multi` + `EventStore.append`;
  `transaction_result/1` generalized to also map the
  `:stream_server_public_key` multi name (replacing the inline `case` in
  `create_stream_server_public_key/1`).
- `lib/video_conference/stream_server_admin_portal/applications/events/`
  — one event module moved in and renamed, four added.
- `lib/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live.ex`
  — call sites updated for the two renamed context functions.
- `lib/video_conference/stream_server_admin_portal/event_store/listener.ex`
  — moduledoc example updated to the new event module name.
- Tests in `applications_test.exs`, `listener_test.exs`,
  `listener_runner_test.exs`, `event_store_test.exs` updated for the
  module rename; new stored-event assertions per mutation.
- Stored events of type `StreamServerPublicKeyAddedEvent` become
  undecodable dead rows — acceptable in dev; delete them if a DB must
  stay clean.
