---
name: add-event-store-event
description: Recipe for adding a named domain event to the stream server admin portal event store — a defstruct event module under the context's events/ folder wired into the mutation via Ecto.Multi + EventStore.append. Use whenever a StreamServerAdminPortal context mutation should record a domain event on an aggregate's stream; the event store currently exists only in that context.
---

# Adding a named event-store event

> **Scope:** this recipe applies to the `StreamServerAdminPortal` context —
> the event store (`EventStore`, `Event`, `Stream`, listeners) lives in
> `lib/video_conference/stream_server_admin_portal/` and no other context has
> one for now.

## Why

The portal's `EventStore` (`lib/video_conference/stream_server_admin_portal/event_store.ex`)
records every domain event as a row whose `event_type` is the event module's
name and whose `payload` is the struct via `:erlang.term_to_binary/1`. Events
must commit atomically with the record change they describe, so they are
always appended inside the same `Ecto.Multi` transaction as the mutation.

## What you need to know first

Before writing the event module, pin down four things:

- **Which aggregate's id becomes `stream_id`** — almost always the id of the
  record being mutated (e.g. `application.id`). The event lands on that
  aggregate's stream.
- **Which mutation triggers it** — the context function that commits the
  record change (create, rename, delete, ...).
- **Which fields it snapshots** — only what the event type doesn't already
  imply. An add event snapshots the creation state; a rename carries the new
  `name`; a toggle or remove carries nothing but `lock_version` — the type
  implies the outcome.
- **`lock_version` is the post-mutation value** — 1 for creates, the
  incremented value for updates. For deletes it is the version the delete
  matched, which means building the event from the *pre-delete* struct, not
  the one `Multi.delete` returns (the returned struct carries the
  `optimistic_lock` increment).

## Event module interface

A domain event is a plain `defstruct` — no schema, no changeset — with a
`new/1` constructor that maps fields off the entity struct:

- File lives under the context's `events/` folder:
  `lib/video_conference/stream_server_admin_portal/<context>/events/<event_name>.ex`
- Module stays in the context's **flat** namespace
  (`...Applications.ApplicationWasRenamed`), not an `Events.*` sub-namespace.
- Name it in the **past tense** describing what happened:
  `ApplicationWasAdded`, `StreamServerPublicKeyAddedEvent`.
- First field is always `:stream_id`, then the snapshot fields, then
  `:lock_version`.

```elixir
defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationWasRenamed do
  @moduledoc """
  Domain event emitted when an application is renamed.
  """

  alias VideoConference.StreamServerAdminPortal.Applications.Application

  defstruct [:stream_id, :id, :name, :lock_version]

  def new(%Application{} = application) do
    %__MODULE__{
      stream_id: application.id,
      id: application.id,
      name: application.name,
      lock_version: application.lock_version
    }
  end
end
```

Reference implementations: `Applications.ApplicationWasAdded` and siblings in
`lib/video_conference/stream_server_admin_portal/applications/events/`, plus
`StreamServerPublicKeyAddedEvent`.

## Wiring the mutation

Restructure the context function around `Ecto.Multi` — the record op first,
then `Multi.merge` appending the event via `EventStore.append`. The merge runs
after the record op, so `new(app)` reads the post-increment `lock_version`
for free.

```elixir
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
```

- `Multi.insert` for creates, `Multi.update` for updates, `Multi.delete` for
  removes — forward `stale_error_field: :lock_version` in the op opts so a
  stale write still returns `{:error, changeset}` with
  `lock_version: ["is stale"]`.
- **Delete is the exception to the merge pattern**: build the event from the
  pre-delete struct (`Multi.merge(fn _changes -> ... end)` over the function
  argument), because the struct `Multi.delete` returns already carries the
  `optimistic_lock` increment — but deletes don't actually bump the version,
  and the event must record the version the delete matched.
- Map `Repo.transaction` results back to `{:ok, record}` /
  `{:error, changeset}` with a shared `transaction_result/1` helper so public
  signatures don't change.

## Invariants

- **Atomicity**: the record change and its event commit or roll back
  together. Never `Repo.insert` the record in one call and append the event
  in another — always one `Multi`.
- **`stream_id` must be non-empty and never `"$all"`** — `"$all"` is the
  store's reserved global-count stream; `EventStore` rejects it and blank
  ids.
- **Module names are immutable once events are stored** — `payload` is
  decoded with `binary_to_term`, and `event_type` is the module name string.
  Renaming or moving a module orphans every stored row of that type. This is
  why event modules live in the context's flat namespace.
- **No-op mutations still emit** — e.g. enabling an already-enabled record
  still bumps `lock_version` and stores the event; the event records that the
  operation ran. Subscribers must be idempotent.
- **A failed mutation stores nothing** — validation or stale-lock failure
  aborts the `Multi` before the append runs; assert this in tests.

## Testing

- `new/1` mapping test per event: build the entity struct by hand and assert
  field-for-field equality (mirror the
  `StreamServerPublicKeyAddedEvent.new/1` test).
- Per-mutation test: run the context function, then
  `EventStore.get_events([inspect(EventModule)], 0)` and assert the stored
  payload — including `stream_id` and the post-mutation `lock_version`.
- Remember the stored row's `version` column is the event's *position in the
  stream*, not the entity's `lock_version` — a stream that already had an add
  event stores the next event at version 2, 3, ...
- Assert failed mutations leave `get_events` empty for that event type.
