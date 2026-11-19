# Design

## Context

`Applications` manages `Application` records with `lock_version`
optimistic locking: each update path fetches via `get_application!/1`,
applies a per-field changeset (`name_changeset`, `description_changeset`,
`enabled_changeset`), and calls `Repo.update(stale_error_field: :lock_version)`;
`remove_application/1` wraps the struct in `change() |> optimistic_lock`
before `Repo.delete`; `create_application/1` is a bare `Repo.insert`.
`EventStore.append/1,2` returns an `Ecto.Multi` that bumps the event's
stream counter and the `$all` counter inside the caller's transaction —
`create_stream_server_public_key/1` already uses it via
`Multi.insert` + `Multi.merge`. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Emit one domain event per `Application` lifecycle mutation, committed
  atomically with the record change.
- Every event carries the application's post-mutation `lock_version` so
  subscribers can reconcile event history against the entity.
- Keep public function signatures and return shapes
  (`{:ok, app}` / `{:error, %Ecto.Changeset{}}`) unchanged.

**Non-Goals:**

- Events for `ApiKey` or `StreamServerPublicKey` mutations (the public
  key's create-event stays the only key event for now).
- Backfilling events for pre-existing applications, including the
  migration-seeded "Default App".
- Moving or renaming `StreamServerPublicKeyAddedEvent` — its module
  name is the `event_type` of already-stored rows and renaming breaks
  `binary_to_term` decode.

## Decisions

### Flat `Applications.*` modules inside an `events/` folder

The six event modules live physically in
`lib/video_conference/stream_server_admin_portal/applications/events/`
but stay in the flat
`VideoConference.StreamServerAdminPortal.Applications` namespace
(e.g. `Applications.ApplicationWasAdded`), matching where
`StreamServerPublicKeyAddedEvent` sits. Event modules are plain
`defstruct`s with a `new/1` constructor, following the existing event's
convention.

- *Alternative: `Applications.Events.*` namespace.* Rejected — splits
  one aggregate's events across two namespaces and invites a later
  rename of `StreamServerPublicKeyAddedEvent`, whose stored
  `event_type` strings must stay valid.

### Minimal per-event payloads

Each event carries only what it describes plus `lock_version`:
`ApplicationWasAdded` snapshots `name`, `description`, `enabled`
(creation state); `ApplicationWasRenamed` carries `name`;
`ApplicationDescriptionWasUpdated` carries `description`;
`ApplicationWasEnabled`, `ApplicationWasDisabled`, and
`ApplicationWasRemoved` carry no entity fields beyond `lock_version` —
the event type implies the outcome. `stream_id` is always the
application's id, so no separate `application_id` field is needed.

- *Alternative: full snapshot on every event.* Rejected — larger
  payloads duplicating fields the event type already conveys; a
  subscriber that needs full state folds the deltas in order.

### `lock_version` semantics

`Multi.merge` runs after the record op, so `new(updated_app)` reads the
post-increment `lock_version` for free — no extra plumbing. Creates
carry 1 (the column default). `Repo.delete` does not increment
`lock_version`, so `ApplicationWasRemoved` carries the version the
delete matched — "gone as of version N".

### Uniform `Multi` shape for all six mutations

```elixir
def rename_application(id, name) do
  application = get_application!(id)

  Multi.new()
  |> Multi.update(
    :application,
    Application.name_changeset(application, %{"name" => name}),
    stale_error_field: :lock_version
  )
  |> Multi.merge(fn %{application: app} ->
    EventStore.append([ApplicationWasRenamed.new(app)])
  end)
  |> Repo.transaction()
  |> transaction_result()
end
```

- `Multi.update/4` forwards `stale_error_field: :lock_version`, so a
  stale write still returns an error changeset (`lock_version: ["is stale"]`)
  — identical behavior to today's `Repo.update` call sites.
- `create` uses `Multi.insert`; `delete` uses `Multi.delete` with the
  existing `change() |> optimistic_lock(:lock_version)` changeset and
  the same `stale_error_field` opt.
- `get_application!/1` stays outside the transaction: the changeset's
  lock check inside the transaction is what guards the race, and the
  fetch must happen before the changeset can be built anyway.
- `transaction_result/1` — a private helper mapping
  `{:ok, %{application: app}} -> {:ok, app}` and
  `{:error, _op, %Ecto.Changeset{} = cs, _} -> {:error, cs}` —
  replaces the inline `case` so it isn't repeated six times (the public
  key create keeps its own inline mapping or shares the helper).

### No-op toggles still emit

`enable_application` on an already-enabled app runs the `UPDATE` today
(lock_version still bumps via `optimistic_lock`), so the matching event
emits too — the event records that the operation ran, not that a value
changed. This keeps emission unconditional and avoids a "did anything
change?" branch in every function.

### `ApplicationWasRemoved` on a deleted aggregate's stream

`stream_id` is an opaque string to the store — appending to the removed
application's stream after its row is gone is legal, and the event is
the tombstone subscribers need to drop their projection of the
application. The `streams` row survives; its `deleted_at` column stays
reserved for future soft-delete semantics.

### Recipe captured as a skill

The repeatable part of this change — define a `defstruct` event with
`stream_id` + `new/1`, wire the mutation through `Multi` +
`EventStore.append`, keep module names and `stream_id` choices stable —
is documented in `.devin/skills/add-event-store-event/SKILL.md` so the
next event (api keys, public key updates) follows the same recipe
without re-deriving it from this file.

## Risks / Trade-offs

- **Unconditional emission on no-op toggles** → documented as
  "operation ran" semantics; a subscriber diffing `enabled` sees a
  duplicate and must be idempotent (already required by at-least-once
  delivery).
- **Historical applications have no `ApplicationWasAdded`** →
  subscribers replaying history must treat "application exists without
  an add event" as normal; a backfill can be a follow-up if needed.
- **Six near-identical `Multi` bodies** → the per-mutation boilerplate
  is deliberate (one event constructor per changeset); only the result
  mapping is extracted. If api-key or public-key update events arrive
  later, the same template applies.
- **`binary_to_term` brittleness** (carried from the store design) →
  event modules must keep stable names; the flat `Applications.*`
  namespace was chosen partly to avoid future moves.

## Migration Plan

No schema or data migration — the `events`/`streams` tables already
exist and the new writes are additive. Deploy the code; events start
flowing on the next application mutation. Rollback is a code revert:
previously stored events remain valid and decodable.
