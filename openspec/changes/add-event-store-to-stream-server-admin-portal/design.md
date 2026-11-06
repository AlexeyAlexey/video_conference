# Design

## Context

The stream server admin portal has a dedicated SQLite database via
`VideoConference.StreamServerAdminPortal.Repo`
(`priv/stream_server_admin_portal_repo/migrations`, `migration_timestamps:
:utc_datetime`). `Applications.create_stream_server_public_key/1` is a
bare `Repo.insert` called from `StreamServerPublicKeysLive` ("save"
event) and the `stream_server_public_key_fixture` test fixture. The
codebase has no `Ecto.Multi` usage today; update paths go through
per-field changesets (`name_changeset`, `description_changeset`,
`application_changeset`, `enabled_changeset`) and `delete` uses
`Repo.delete` on the bare struct. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Append-only `events` table in the portal DB with a guaranteed total
  order and a per-aggregate idempotency key.
- `EventStore.append` composes into a caller's `Ecto.Multi` so key
  creation + event emission commit atomically.
- Optimistic locking on `stream_server_public_keys` that degrades to a
  changeset error, not a crash.
- Public context function signatures and return shapes stay compatible
  (`{:ok, key}` / `{:error, %Ecto.Changeset{}}`).

**Non-Goals:**

- Subscribers, dispatch, or projections (explicitly deferred).
- Events for update/delete mutations — only `StreamServerPublicKeyAddedEvent`.
- Cross-DB or multi-writer ordering guarantees.

## Decisions

### Ordering: integer rowid `seq` primary key

SQLite `INTEGER PRIMARY KEY` is a rowid alias: it monotonically
increases in insertion order, including for multiple inserts inside one
transaction — a total order across all event types for free.

- *Alternative: order by `added_at`.* Rejected — `utc_datetime_usec`
  values are generated app-side (`DateTime.utc_now`) and can tie within
  a transaction. `added_at` is a filter cursor, not an ordering key.
- *Alternative: order by uuid `id`.* Rejected — uuids are random.

### `(stream_id, version)` — contiguous per-stream position, no counter table

`stream_id` is an opaque, non-empty string identifying the stream the
event belongs to — for `StreamServerPublicKeyAddedEvent` it is the
created key's UUID, but the store accepts any non-empty identity. The
store assigns `version` as `MAX(version) + 1` over that `stream_id`,
computed inside the append transaction — a contiguous per-stream
position fully decoupled from the aggregate's `lock_version`.
`unique_index(:events, [:stream_id, :version])` is the correctness
backstop: two writes can never record the same stream position.

- *Alternative: `(id, version)` = (aggregate uuid, aggregate
  `lock_version`).* Rejected — couples event identity to entity
  concurrency control, produces version gaps when mutations don't emit
  events, and conflates two independent concerns.
- *Alternative: a `streams` counter table.* Rejected — under SQLite's
  single writer the counter buys nothing the `MAX + 1` read inside the
  transaction doesn't already give; it only pays off for row-level
  stream locking and expected-version preconditions on a multi-writer
  database, and can be added later without changing stored data.
- *Idempotency is out of scope:* the producer does not pick `version`,
  so retrying an append after it commits stores a second event at the
  next position. Retries of the whole operation retry the transaction,
  not the store.

### `EventStore.append` returns an `Ecto.Multi`

```elixir
def append(events), do: append(Multi.new(), events)
def append(%Multi{} = multi, events)
```

`append/1` is exactly what `Ecto.Multi.merge/2` needs; `append/2`
extends a caller's multi directly. One `Multi.run` per event reads
`MAX(version) + 1` for its `stream_id` and inserts the row through a
changeset carrying `validate_required(:stream_id)` (rejects `nil` and
`""`) and the `unique_constraint` on `(stream_id, version)` — all in
the order the events were given, so `seq` order matches append order.

The event depends on the inserted key's generated values, so creation
uses `merge`:

```elixir
Multi.new()
|> Multi.insert(:stream_server_public_key, changeset)
|> Multi.merge(fn %{stream_server_public_key: key} ->
     EventStore.append([StreamServerPublicKeyAddedEvent.new(key)])
   end)
|> Repo.transaction()
```

`Repo.transaction` failures come back as
`{:error, failed_op, value, changes}` — the context maps them to
`{:error, %Ecto.Changeset{}}` so LiveView handling is unchanged.

- *Alternative: `Multi.run` inserting the event row directly.* Rejected
  — same result but hides the store's write behind a callback instead
  of a first-class composable multi.

### `optimistic_lock` only on update changesets

`optimistic_lock/3` bumps the field via `prepare_changes`, which runs
on **insert** too — a create changeset using it would persist
`lock_version` 2. So: `lock_version` column + schema field
(`default: 1`), and `optimistic_lock(:lock_version)` applied inside
`name_changeset`, `description_changeset`, `application_changeset`,
`enabled_changeset` — not `changeset/2`. Delete wraps the struct:
`key |> change() |> optimistic_lock(:lock_version) |> Repo.delete(opts)`.

### Stale conflicts become changeset errors

Repo ops pass `stale_error_field: :lock_version` (message e.g.
"is stale"), so a lost race returns `{:error, changeset}` with a
`stale: true` error instead of raising `Ecto.StaleEntryError` through
the LiveView. In a `Multi`, the failing op's error propagates as the
multi error and is mapped the same way.

### `event_type` via `inspect/1`, payload via ETF

`inspect(event.__struct__)` stores
`"VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent"`
— round-trips cleanly (`String.to_existing_atom("Elixir." <> name)`).
`to_string/1` would store the `"Elixir."`-prefixed form. Payload is
`:erlang.term_to_binary(event)`; reads decode with
`:erlang.binary_to_term(payload, [:safe])` through
`EventStore.decode_payload/1` — atoms already exist, and `[:safe]`
blocks creating new ones from stored data.

### `added_at` autogenerated, explicit `:utc_datetime_usec`

`field :added_at, :utc_datetime_usec, autogenerate: {DateTime, :utc_now, []}`
on the `events` schema — the repo's `migration_timestamps` is
`:utc_datetime`, and `added_at` is not a `timestamps()` column anyway.
It stays as observability data (when an event happened), not as the
read cursor.

`get_events(event_names, seq)` filters `seq > cursor` and orders by
`seq` — the same monotonic rowid used for ordering doubles as the
cursor, so a resumed reader can't silently skip a same-microsecond
event the way an `added_at` cursor could. It returns `%Event{}` rows
(not bare decoded structs) with each `payload` decoded via
`decode_payload/1` into the original event struct, so callers keep
`seq`/`added_at`/`event_type` — the cursor material for later
subscribers.

### Module layout

- `VideoConference.StreamServerAdminPortal.EventStore` — `append/1`,
  `append/2`, `get_events/2`, `decode_payload/1`.
- `VideoConference.StreamServerAdminPortal.EventStore.Event` — `events`
  schema (PK `:seq`, string `stream_id`, no `timestamps`).
- `VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent`
  — plain `defstruct`, fields: `stream_id`, `application_id`,
  `name`, `key`, `enabled`, `description`, with a
  `new(%StreamServerPublicKey{})` constructor that maps the entity to
  the event (`stream_id` = key id, snapshot fields copied). Keeping the
  stream mapping inside `new/1` means the `Multi.merge` step is a
  one-liner and the mapping rule lives in exactly one place — every
  future entity event follows the same constructor convention.
- Two migrations under `priv/stream_server_admin_portal_repo/migrations/`:
  `create_events` (with `unique_index(:events, [:stream_id, :version])`)
  and `add_lock_version_to_stream_server_public_keys`.

## Risks / Trade-offs

- **ETF payloads are opaque to SQL and brittle to renames** → keep event
  structs small and their module names stable; `(stream_id, version)`
  plus the stored `event_type` give an upcast path if a payload ever
  needs migrating.
- **`seq` cursor assumes rowid monotonicity** → guaranteed by SQLite
  `INTEGER PRIMARY KEY` for this append-only table; no row is ever
  updated or deleted, so `seq > cursor` resumes exactly.
- **Racing appends to one stream can collide on `MAX + 1`** → two
  deferred transactions may compute the same next position; the loser
  fails on `UNIQUE(stream_id, version)` loudly and retries — never
  silently double-records. In practice appends follow the aggregate
  write in the same transaction, which already holds SQLite's writer
  lock.
- **Version derives from the rows themselves** → safe only because the
  table is append-only; deleting events would let `MAX + 1` reuse
  positions. No delete path exists.
- **No idempotent retry** → `version` is store-assigned, so a retried
  append is a new append. Callers that need exactly-once must retry the
  whole transaction (which re-runs the aggregate write too).
- **Renamed event modules break decode** → `binary_to_term` yields a
  struct for whatever atom the payload names; a removed module raises.
  Keep modules stable; rescue-and-skip is a later decision for
  subscribers.

## Migration Plan

1. Mix tasks run the new migrations against the portal DB
   (`mix ecto.migrate` covers the second repo via `ecto_repos`).
2. `lock_version` backfills to 1 on existing rows via column default.
3. Rollback: `mix ecto.rollback` drops `events` and the `lock_version`
   column; both are additive so no data is at risk.
