# Proposal

## Why

The stream server admin portal event store currently records only one
domain event — `StreamServerPublicKeyAddedEvent` — and the event-store
design explicitly deferred events for update/delete mutations. Every
`Application` mutation (create, rename, description edit, enable,
disable, remove) commits silently, so event listeners have no way to
track the lifecycle of the aggregate that owns API keys and public
keys.

## What Changes

- Add six application domain events under
  `lib/video_conference/stream_server_admin_portal/applications/events/`,
  all in the flat `VideoConference.StreamServerAdminPortal.Applications`
  namespace alongside `StreamServerPublicKeyAddedEvent`:
  - `ApplicationWasAdded` — `stream_id`, `name`, `description`,
    `enabled`, `lock_version`
  - `ApplicationWasRenamed` — `stream_id`, `name`, `lock_version`
  - `ApplicationDescriptionWasUpdated` — `stream_id`, `description`,
    `lock_version`
  - `ApplicationWasEnabled` — `stream_id`, `lock_version`
  - `ApplicationWasDisabled` — `stream_id`, `lock_version`
  - `ApplicationWasRemoved` — `stream_id`, `lock_version`
- Each event carries the application's `lock_version` **after** the
  mutation (1 for adds; the version the delete matched for removes), so
  subscribers can reconcile event history against the entity's
  optimistic-concurrency counter.
- Rework `create_application/1`, `rename_application/2`,
  `edit_application_description/2`, `enable_application/1`,
  `disable_application/1`, and `delete_application/1` to run inside an
  `Ecto.Multi` that appends the matching event via
  `EventStore.append`, mirroring `create_stream_server_public_key/1` —
  record change and event commit or roll back together. Return shapes
  stay `{:ok, app}` / `{:error, %Ecto.Changeset{}}`.
- `StreamServerPublicKeyAddedEvent` is untouched: keeping its module
  name preserves the `event_type` strings of already-stored rows.
- Add a `.devin/skills/add-event-store-event/SKILL.md` skill
  documenting the recipe for adding a named domain event — the event
  interface (`defstruct` + `stream_id` + `new/1`), the transactional
  `Multi` + `EventStore.append` wiring, and the invariants a new event
  must satisfy.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-applications`: new requirement — each application
  lifecycle mutation SHALL append its corresponding domain event to the
  application's event stream atomically with the record change, and
  each event SHALL carry the application's post-mutation
  `lock_version`.

## Impact

- `lib/video_conference/stream_server_admin_portal/applications.ex` —
  six functions restructured around `Ecto.Multi`; a shared private
  helper maps `Repo.transaction` results.
- New directory
  `lib/video_conference/stream_server_admin_portal/applications/events/`
  with six plain-`defstruct` event modules exposing `new(%Application{})`.
- `test/lib/video_conference/stream_server_admin_portal/applications_test.exs`
  — per-mutation event assertions and `new/1` mapping tests.
- `.devin/skills/add-event-store-event/SKILL.md` — new repo skill
  capturing the add-a-named-event recipe.
- No migration or schema change; no LiveView changes (context return
  shapes are unchanged).
- Caveat carried forward: applications created before this change
  (including the migration-seeded "Default App") have no
  `ApplicationWasAdded` event; subscribers must tolerate applications
  that exist without an add event.
