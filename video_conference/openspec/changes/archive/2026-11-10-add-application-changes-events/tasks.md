# Tasks

## 1. Event modules

- [x] 1.1 Create `lib/video_conference/stream_server_admin_portal/applications/events/` with `application_was_added.ex` (`Applications.ApplicationWasAdded`: `stream_id`, `name`, `description`, `enabled`, `lock_version`) and `application_was_renamed.ex` (`Applications.ApplicationWasRenamed`: `stream_id`, `name`, `lock_version`), each a plain `defstruct` with a `new(%Application{})` constructor following `StreamServerPublicKeyAddedEvent`; verify `mix compile` succeeds
- [x] 1.2 Add `application_description_was_updated.ex` (`stream_id`, `description`, `lock_version`), `application_was_enabled.ex`, `application_was_disabled.ex`, and `application_was_removed.ex` (`stream_id`, `lock_version` each) in the same folder and namespace; verify `mix compile` succeeds
- [x] 1.3 Add `new/1` mapping tests in `applications_test.exs` asserting each constructor copies its fields from an `%Application{}` (mirroring the `StreamServerPublicKeyAddedEvent.new/1` test); verify the tests pass

## 2. Context rework

- [x] 2.1 Add a private `transaction_result/1` helper to `Applications` mapping `{:ok, %{application: app}} -> {:ok, app}`, `{:error, _op, %Ecto.Changeset{} = cs, _} -> {:error, cs}`, and `{:error, _op, error, _} -> {:error, error}`; rework `create_application/1` to `Multi.insert` + `Multi.merge` appending `ApplicationWasAdded`; verify a create test asserts the stored event payload (fields + `lock_version` 1) on the application's stream
- [x] 2.2 Rework `rename_application/2`, `edit_application_description/2`, `enable_application/1`, and `disable_application/1` to `Multi.update` (keeping `stale_error_field: :lock_version` in the op opts) + `Multi.merge` appending `ApplicationWasRenamed` / `ApplicationDescriptionWasUpdated` / `ApplicationWasEnabled` / `ApplicationWasDisabled`; verify tests assert each stored event carries the incremented `lock_version`
- [x] 2.3 Rework `remove_application/1` to `Multi.delete` (existing `change() |> optimistic_lock(:lock_version)` + `stale_error_field`) + `Multi.merge` appending `ApplicationWasRemoved` with the matched `lock_version`; verify a test asserts the event is stored on the removed application's stream
- [x] 2.4 Verify stale-path behavior is preserved: tests asserting a stale update and a stale delete return `{:error, changeset}` with `lock_version: ["is stale"]` still pass, and a failing mutation stores no event

## 3. Documentation

- [x] 3.1 Create `.devin/skills/add-event-store-event/SKILL.md` (frontmatter `name` + `description`, following `liveview-custom-dropdown/SKILL.md` format) documenting the recipe for adding a named domain event: the interface (plain `defstruct` with `stream_id` + payload fields + a `new/1` entity constructor, file under the context's `events/` folder, past-tense module name in the context's flat namespace) and the information needed to define one (which aggregate's id becomes `stream_id`, which mutation triggers it, which fields it snapshots, that `lock_version` is the post-mutation value). Cover the invariants: event and record change commit atomically via `Multi` + `EventStore.append`, `stream_id` must be non-empty and never `"$all"`, module names must stay stable because `binary_to_term` decodes stored payloads, and no-op mutations still emit. Verify the file renders and the recipe matches the implementation in group 2

## 4. Verification

- [x] 4.1 Exercise the applications page in the dev server (`dotenv -e .env mix phx.server`): create, rename, edit description, toggle enabled, and remove an application, then confirm the matching rows exist in the portal DB `events` table via `EventStore.get_events/2` in `iex`
- [x] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures
