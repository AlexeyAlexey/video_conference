# Proposal

## Why

The stream server admin portal needs a durable record of domain changes so
that future subscribers (out of scope here) can react to them — starting with
"an application registered a stream server public key". A simple append-only
event store in the portal database, written atomically with the change it
describes, gives us that record without any external infrastructure.

## What Changes

- New `events` table in the stream server admin portal database
  (`VideoConference.StreamServerAdminPortal.Repo`): an auto-increment integer
  `seq` primary key providing total ordering, an aggregate `id` + `version`
  pair (unique, serving as the idempotency key), `event_type` (module name
  string), `payload` (`:erlang.term_to_binary` of the event struct), and
  `added_at` (`utc_datetime_usec`).
- New `VideoConference.StreamServerAdminPortal.EventStore` context exposing:
  - `append(events)` — returns an `Ecto.Multi` inserting the given event
    structs, so callers can merge it into their own transaction.
    `append(multi, events)` extends an existing `Ecto.Multi`.
  - `get_events(event_names, seq)` — returns stored events whose
    `event_type` is in `event_names` and `seq` is greater than the given
    cursor, ordered by `seq`, with payloads decoded back into their
    event structs.
  - `decode_payload(payload)` — decodes a stored `payload` binary into
    its event struct.
- New event struct
  `VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent`
  carrying the created key's `id`, `version`, and snapshot fields
  (`application_id`, `name`, `key`, `enabled`, `description`), with a
  `new/1` constructor that builds the event from a
  `%StreamServerPublicKey{}`.
- `stream_server_public_keys` gains a `lock_version` integer column
  (default 1) with `Ecto.Changeset.optimistic_lock/3` applied on every
  update/delete path; stale conflicts surface as changeset errors rather
  than `Ecto.StaleEntryError` crashes.
- `Applications.create_stream_server_public_key/1` wraps the insert and the
  `StreamServerPublicKeyAddedEvent` append in a single `Ecto.Multi`
  transaction. The event's `(id, version)` is `(key.id, key.lock_version)`
  = `(uuid, 1)` for a newly created key.

## Capabilities

### New Capabilities

- `stream-server-event-store`: append-only event persistence in the portal
  database — seq-ordered storage, `(id, version)` idempotent identity,
  `Ecto.Multi`-composable appends, and name+timestamp-filtered reads.

### Modified Capabilities

- `portal-public-stream-server-keys`: the record gains optimistic
  concurrency control via `lock_version`, and creation atomically emits a
  `StreamServerPublicKeyAddedEvent` to the event store.

## Impact

- **New code**: `lib/video_conference/stream_server_admin_portal/event_store.ex`,
  `lib/video_conference/stream_server_admin_portal/event_store/event.ex`,
  `lib/video_conference/stream_server_admin_portal/applications/stream_server_public_key_added_event.ex`,
  migration in `priv/stream_server_admin_portal_repo/migrations/`.
- **Modified code**: `Applications.create_stream_server_public_key/1` and
  the `StreamServerPublicKey` changesets (optimistic lock). Public function
  signatures are unchanged; callers (LiveView, fixtures) are unaffected.
- **Out of scope**: event subscribers/dispatch, events for update/delete
  mutations, ordering guarantees beyond `seq`.
