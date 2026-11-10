# Tasks

## 1. Event modules

- [ ] 1.1 Move `lib/video_conference/stream_server_admin_portal/applications/stream_server_public_key_added_event.ex` to `applications/events/stream_server_public_key_was_added.ex`; rename the module to `Applications.StreamServerPublicKeyWasAdded`; add `:id` and `:lock_version` to the defstruct and set both in `new/1` (`id: key.id`, `lock_version: key.lock_version`); align the moduledoc with the `ApplicationWasAdded` style; update every reference (`applications.ex` alias, `event_store/listener.ex` moduledoc example, `event_store_test.exs`, `listener_test.exs`, `listener_runner_test.exs`, `applications_test.exs`); verify `mix compile` succeeds and the touched event-store tests pass
- [ ] 1.2 Add `events/stream_server_public_key_was_enabled.ex`, `stream_server_public_key_was_disabled.ex`, and `stream_server_public_key_was_removed.ex` — each `defstruct [:stream_id, :id, :lock_version]` with a `new(%StreamServerPublicKey{})` constructor following `ApplicationWasRemoved`; verify `mix compile` succeeds
- [ ] 1.3 Add `events/stream_server_public_key_was_moved.ex` (`Applications.StreamServerPublicKeyWasMoved`) — `defstruct [:stream_id, :id, :from_application_id, :to_application_id, :lock_version]` with a `new/2` constructor taking the pre-move and post-move `%StreamServerPublicKey{}` structs (`from_application_id` from the pre-move struct, `to_application_id` and `lock_version` from the post-move one); verify `mix compile` succeeds
- [ ] 1.4 Update the `StreamServerPublicKeyAddedEvent.new/1` mapping test in `applications_test.exs` to `StreamServerPublicKeyWasAdded.new/1` (per 1.1), asserting `id` and `lock_version` are copied; add `new/1` mapping tests for `WasEnabled`/`WasDisabled`/`WasRemoved` and a `new/2` test for `WasMoved` asserting `from_application_id`/`to_application_id` map from the two structs; verify the tests pass

## 2. Context rework

- [ ] 2.1 Generalize `transaction_result/1` in `applications.ex` with a `{:ok, %{stream_server_public_key: key}} -> {:ok, key}` clause and replace the inline `case` in `create_stream_server_public_key/1` with `|> transaction_result()`; verify the existing create tests pass unchanged
- [ ] 2.2 Rework `enable_stream_server_public_key/1` and `disable_stream_server_public_key/1` to `Multi.update` (keeping `stale_error_field: :lock_version`) + `Multi.merge` appending `StreamServerPublicKeyWasEnabled`/`StreamServerPublicKeyWasDisabled`; verify tests assert each stored event carries `stream_id` = key id, `id`, and the incremented `lock_version`, and that an already-enabled/already-disabled key still stores its event
- [ ] 2.3 Rename `switch_stream_server_public_key_application/2` to `move_stream_server_public_key_to_application/2` and rework it to `Multi.update` + `Multi.merge` appending `StreamServerPublicKeyWasMoved.new(pre_key, post_key)`; update the call site at `stream_server_public_keys_live.ex` (the `change-app` handler ~line 188); verify a test asserts the stored event's `from_application_id`/`to_application_id` and incremented `lock_version`
- [ ] 2.4 Rename `delete_stream_server_public_key/1` to `remove_stream_server_public_key/1` and rework it to `Multi.delete` (existing `change() |> optimistic_lock(:lock_version)` + `stale_error_field`) + `Multi.merge` appending `StreamServerPublicKeyWasRemoved.new(key)` built from the *pre-delete* struct (per the skill's delete exception); update the call site at `stream_server_public_keys_live.ex` (~line 82); verify a test asserts the tombstone event carries the matched `lock_version`
- [ ] 2.5 Verify stale/failure behavior is preserved: stale update and stale delete tests still return `{:error, changeset}` with `lock_version: ["is stale"]`, and a failing mutation (e.g. move to a missing application) stores no event

## 3. Verification

- [ ] 3.1 Exercise the stream server public keys page in the dev server (`dotenv -e .env mix phx.server`): toggle enabled, move a key via "Change app", remove a key, then confirm the matching rows exist in the portal DB `events` table via `EventStore.get_events/2` in `iex`; optionally delete rows stored as the orphaned `StreamServerPublicKeyAddedEvent` type
- [ ] 3.2 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
