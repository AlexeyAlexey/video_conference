# Tasks

## 1. Persistence

- [x] 1.1 Create migration `create_event_listeners` in `priv/stream_server_admin_portal_repo/migrations/` (`name` unique non-empty, `description`, `last_seen_seq` default 0, `status`, `last_error` nullable) and verify `dotenv -e .env.test mix ecto.migrate` succeeds
- [x] 1.2 Create `EventStore.ListenerState` schema for `event_listeners` and verify changeset validation tests pass (`name` required/unique, `status` in `["ok","failed"]`, `last_seen_seq` >= 0)

## 2. Listener Contract

- [x] 2.1 Create `EventStore.Listener` module with `handle_event/1` behaviour callback and `__using__` macro storing `name`/`description`/`events`/`retries`/`backoff`/`max_backoff`, generating `__listener__/0`; verify a test listener module compiles with declared opts and `__listener__/0` returns them
- [x] 2.2 Verify `use EventStore.Listener` with missing `name` or empty `events` list raises a compile-time error

## 3. Runner

- [x] 3.1 Implement `EventStore.ListenerRunner` GenServer: on init upsert listener row, refuse start when `status == "failed"`, poll `EventStore.get_events/2` on interval; verify listener starting with cursor 0 delivers matching events in `seq` order
- [x] 3.2 Implement dispatch: call `module.handle_event(decoded_struct)` per event, update `last_seen_seq` on `:ok` before next event; verify cursor advances only after success and failed events leave the cursor unchanged
- [x] 3.3 Implement retry with exponential backoff (`backoff * 2^(n-1)` capped at `max_backoff`) and rescue-and-normalize of raised exceptions; verify a handler that raises is retried the configured number of times
- [x] 3.4 Implement failure: on exhausted retries set `status = "failed"` and `last_error`, then halt the runner; verify the listener row records the failure and no further events are delivered

## 4. Supervision & Resume

- [x] 4.1 Create `EventStore.ListenersSupervisor` (`DynamicSupervisor`) and add it to `VideoConference.Application` children; verify the app boots and starts runners for modules in `config :video_conference, :stream_server_admin_portal`'s `:event_listeners`
- [x] 4.2 Verify a listener row with `status = "failed"` is not started on boot while `ok` listeners start normally
- [x] 4.3 Implement `EventStore.resume_listener/1` (clear `failed`/`last_error`, start child); verify resuming a failed listener retries the failed event first and `:not_found`/`:not_failed` errors are returned appropriately

## 5. Integration Verification

- [x] 5.1 Add an end-to-end test listener subscribing to `StreamServerPublicKeyAddedEvent`; verify creating a stream server public key delivers the event and advances the cursor
- [x] 5.2 Run `dotenv -e .env.test mix precommit` and fix any failures
