# Proposal

## Why

The stream server admin portal's event store records domain events durably,
but nothing consumes them — the archived event-store change explicitly
deferred subscribers. Developers need a supported way to react to stored
events (projections, notifications, downstream sync) with guaranteed
in-order, at-least-once delivery and durable per-listener progress.

## What Changes

- New `event_listeners` table in the stream server admin portal database:
  unique `name`, `description`, `last_seen_seq` cursor, `status`
  (`:ok` / `:failed`), and `last_error` for the failure that halted the
  listener.
- New `EventStore.Listener` behaviour + `use` macro: a listener module
  declares `name`, `description`, an explicit `events:` list of event
  modules it subscribes to, and retry options (`retries`, exponential
  `backoff`), then implements `handle_event/1` clauses returning `:ok`
  or `{:error, reason}`.
- New `EventStore.ListenerRunner` GenServer — one process per listener:
  polls `EventStore.get_events/2` for its declared event types after
  `last_seen_seq`, dispatches each decoded event struct to
  `handle_event/1` in `seq` order, advances the cursor on `:ok`, retries
  with exponential backoff on failure (raised exceptions are rescued and
  normalized to failures), and marks the listener `:failed` after
  retries are exhausted — then halts and stays down.
- New `EventStore.ListenersSupervisor` (`DynamicSupervisor`, `:temporary`
  children) started under `VideoConference.Supervisor`; it starts a
  runner per listener module named in app config, skipping listeners
  whose persisted status is `:failed`.
- New `EventStore.resume_listener/1`: clears `:failed` status and starts
  the listener's runner so it resumes from its last good cursor —
  retrying the event that failed.

## Capabilities

### New Capabilities

- `stream-server-event-listeners`: durable, supervised event
  subscriptions for the portal event store — declared listeners with
  per-listener persisted cursors, in-order at-least-once dispatch,
  configurable retries with exponential backoff, durable `:failed`
  state, and manual resume.

### Modified Capabilities

None — the event store's storage, append, and retrieval requirements are
unchanged; listeners consume the existing `get_events/2` read contract.

## Impact

- **New code**: `event_store/listener.ex` (behaviour + `use` macro),
  `event_store/listener_runner.ex` (GenServer),
  `event_store/listeners_supervisor.ex` (DynamicSupervisor),
  `event_store/listener_state.ex` (`event_listeners` schema),
  `EventStore.resume_listener/1`, a migration creating
  `event_listeners`, and an `:event_listeners` option in the
  `:stream_server_admin_portal` app config naming the listener modules
  to start.
- **Modified code**: `lib/video_conference/application.ex` gains the
  listeners supervisor child; `event_store.ex` gains the resume API.
- **Delivery semantics**: at-least-once — a crash between a handler's
  `:ok` and the cursor write re-delivers that event, so
  `handle_event/1` implementations must be idempotent.
- **Out of scope**: admin UI for listener status/restart (the
  `event_listeners` table already carries everything a future page
  needs), PubSub push notification (polling only; a wake-up poke can be
  added later without changing cursor semantics), multi-node
  distribution.
