# Tasks

## 1. Event modules

- [ ] 1.1 Create `lib/video_conference/stream_server_admin_portal/stream_servers/events/stream_server_was_added.ex` — `StreamServers.StreamServerWasAdded`, `defstruct [:stream_id, :id, :name, :description, :host, :country, :settings, :cert_hash, :lock_version]` with `new(%StreamServer{})` mapping each field (following `ApplicationWasAdded`); verify `mix compile` succeeds
- [ ] 1.2 Create `events/stream_server_was_removed.ex` — `defstruct [:stream_id, :id, :lock_version]` with `new(%StreamServer{})` (following `ApplicationWasRemoved`); verify `mix compile` succeeds
- [ ] 1.3 Create `events/stream_server_was_assigned_to_application.ex` and `events/stream_server_was_unassigned_from_application.ex` — each `defstruct [:stream_id, :id, :application_id, :lock_version]` with `new(%StreamServer{} = server, application_id)` mapping `stream_id`/`id`/`lock_version` off the (post-bump) server struct; verify `mix compile` succeeds
- [ ] 1.4 Add `new/1`/`new/2` mapping tests in `stream_servers_test.exs`: build `%StreamServer{}` by hand and assert field-for-field equality for `WasAdded` and `WasRemoved`; assert the assign/unassign events map `stream_id`/`id`/`lock_version` from the server struct and `application_id` from the argument; verify the tests pass

## 2. Context rework

- [ ] 2.1 Add `alias Ecto.Multi` and `EventStore` plus the four event modules to `stream_servers.ex` aliases, and add a private `transaction_result/1` mapping `{:ok, %{stream_server: server}}` and `{:error, _op, %Ecto.Changeset{}, _}` (following `Applications.transaction_result/1`); verify `mix compile` succeeds
- [ ] 2.2 Rework `create_stream_server/1` to `Multi.insert(:stream_server, StreamServer.changeset(...))` + `Multi.merge` appending `StreamServerWasAdded.new(server)`; verify a test asserts the stored event lands on the server's stream carrying every creation field and `lock_version` 1, and that a failed insert (e.g. duplicate name) stores no event
- [ ] 2.3 Rename `delete_stream_server/1` to `remove_stream_server/1` and rework it to `Multi.delete` (existing `change() |> optimistic_lock(:lock_version)` + `stale_error_field: :lock_version`) + `Multi.merge` appending `StreamServerWasRemoved.new(stream_server)` built from the *pre-delete* struct; update the call site at `stream_server_admin_portal/live/stream_servers_live.ex` (~line 89) and rename the test describes; verify tests assert the tombstone event carries the matched `lock_version`, the stale-delete test still returns `{:error, changeset}` with `lock_version: ["is stale"]` and stores no event
- [ ] 2.4 Rework `assign_application/2`: load the server with `get_stream_server!/1`, then `Multi.insert(:assignment, %ApplicationStreamServer{...}, on_conflict: :nothing)` + `Multi.update(:stream_server, change(server) |> optimistic_lock(:lock_version), stale_error_field: :lock_version)` + `Multi.merge` appending `StreamServerWasAssignedToApplication.new(server, application_id)` built from the bumped struct, still returning `{:ok, get_stream_server!(stream_server_id)}` after the transaction; verify tests assert the event's `stream_id`/`application_id`/incremented `lock_version`, that the server's `lock_version` is bumped, that re-assigning an already-assigned application stores a second event, and the assignment tests still pass
- [ ] 2.5 Rework `unassign_application/2` the same way with `Multi.delete_all(:assignment, query)` + the lock-bump update + `Multi.merge` appending `StreamServerWasUnassignedFromApplication.new(server, application_id)`; verify tests assert the event's `stream_id`/`application_id`/incremented `lock_version`, that the server's `lock_version` is bumped, and that unassigning a non-assigned application still stores the event
- [ ] 2.6 Verify non-evented mutations are untouched: rename/description/country/cert-hash edits remain plain `Repo.update` calls and store no event (assert via `EventStore.get_events` on the server's stream)

## 3. Verification

- [ ] 3.1 Exercise the portal stream servers page in the dev server (`dotenv -e .env mix phx.server`): create a server, assign and unassign an application, remove a server, then confirm the matching rows exist via `EventStore.get_events/2` in `iex`
- [ ] 3.2 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
