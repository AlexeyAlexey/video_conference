# Design

## Context

The `StreamServers` context (`StreamServerAdminPortal`) mutates stream
servers through six functions: `create_stream_server/1`,
`rename_stream_server/2`, `edit_stream_server_description/2`,
`edit_stream_server_country/2`, `edit_stream_server_cert_hash/2`,
`delete_stream_server/1`, plus the join-table pair
`assign_application/2` / `unassign_application/2`. None records an
event today. The four field edits stay plain — their fields are
portal-cosmetic (see proposal).

Event modules and `Multi` + `EventStore.append` wiring follow the
recipe in `.devin/skills/add-event-store-event/SKILL.md`, exercised by
the `ApplicationWas*` and `StreamServerPublicKeyWas*` siblings in
`applications/events/`.

## Goals / Non-Goals

**Goals:**

- Create, remove, assign, and unassign mutations each append their
  event atomically with the record change on the server's stream
  (stream_id = the stream server's id).
- Event modules share the established shape: `:stream_id` first, then
  snapshot fields; file under `stream_servers/events/`; module in the
  `StreamServers` flat namespace.
- Public signatures keep returning `{:ok, record}` /
  `{:error, changeset}` — callers see only the
  `delete_stream_server` → `remove_stream_server` rename.

**Non-Goals:**

- No events for rename, description, country, or cert-hash edits.
- No listener or projection changes.
- The separate `AdminPortal.StreamServers` context (email/password
  admin) is out of scope; its `delete_stream_server/1` keeps its name.

## Decisions

### Event name and verb: `assign`/`unassign`, function names unchanged

The user-facing verbs already say "assign"/"unassign"
(`assign_application/2`, the assign view's checkboxes), so the events
name what happened:
`StreamServerWasAssignedToApplication` ↔ `assign_application`,
`StreamServerWasUnassignedFromApplication` ↔
`unassign_application`. No function rename needed here — only
`delete_stream_server` → `remove_stream_server`, pairing with
`StreamServerWasRemoved` like `remove_application` /
`ApplicationWasRemoved`.

Alternative considered: `ApplicationWasAssignedToStreamServer` —
rejected; the aggregate is the server, the event lands on the server's
stream, and the server's perspective matches how the portal phrases
the operation.

### `WasAdded` snapshots every creation-time column

`StreamServerWasAdded` carries `:stream_id, :id, :name, :description,
:host, :country, :settings, :cert_hash, :lock_version` — the full
record minus timestamps, matching `ApplicationWasAdded`'s convention
of snapshotting creation state. `host` matters most: it is immutable,
so the add event is the only place it ever appears. `lock_version` is
always 1.

### `WasRemoved` built from the pre-delete struct

`StreamServerWasRemoved` carries only `:stream_id, :id, :lock_version`
(the tombstone shape of `ApplicationWasRemoved`), built from the
function argument — the pre-delete struct — because `Multi.delete`'s
returned struct carries an `optimistic_lock` increment that never
actually persisted.

### Assignments bump the server's `lock_version`; events carry it

Assigning or unassigning an application changes the server's
observable state (its `applications` set), so it is treated as an
update of the server aggregate: the `Multi` updates the server with
`change() |> optimistic_lock(:lock_version)`, bumping its version in
the same transaction as the join-row write. Both assignment events are
`defstruct [:stream_id, :id, :application_id, :lock_version]` with a
`new(%StreamServer{} = server, application_id)` constructor — the
post-bump struct provides `stream_id`, `id`, and the incremented
`lock_version`.

Alternative considered: leave `lock_version` untouched (join write
only) and emit events without it. Rejected — a listener projecting
server state could then see assignment events with a stale version
relative to later field edits, and every other mutating operation on
the aggregate already bumps the version.

### No-op assignments still emit

`assign_application` uses `on_conflict: :nothing` and
`unassign_application` a `delete_all`; both can match zero rows. Per
the event store's no-op-emits invariant the events are appended
unconditionally — the operation ran, and subscribers must be
idempotent. Conditional emission would need an extra existence check
inside the transaction for a distinction listeners don't need.

### Join ops restructure: `Multi` with a lock bump, then reload

`assign_application`/`unassign_application` currently write the join
row, then reload the server with `applications` preloaded. They become
three `Multi` steps: `Multi.insert(:assignment,
%ApplicationStreamServer{...}, on_conflict: :nothing)` /
`Multi.delete_all(:assignment, query)`, then
`Multi.update(:stream_server, change(server) |>
optimistic_lock(:lock_version), stale_error_field: :lock_version,
force: true)` for the version bump (the server is loaded once at the
top via `get_stream_server!/1`), then `Multi.merge` appending the
event built from the bumped struct. `force: true` is required because
Ecto ≥ 3.5 no-ops updates whose changeset has no changes — the
`optimistic_lock` increment is applied in `prepare_changes`, which
never runs unless the update is forced. They keep returning
`{:ok, get_stream_server!(id)}` — the reload stays *after*
`Repo.transaction` so the preload sees committed rows without adding a
`Multi.run` step.

### `transaction_result/1` added to the context

Mirroring `Applications`, a private helper maps
`{:ok, %{stream_server: server}}` → `{:ok, server}` and
`{:error, _op, %Ecto.Changeset{} = cs, _}` → `{:error, cs}`. The
assign/unassign functions bypass it: their public result is the
reloaded server, not the Multi value.

## Risks / Trade-offs

- **Duplicate assignment events** → Re-assigning an already-assigned
  application stores another `WasAssignedToApplication`. Accepted per
  the no-op-emits invariant; listeners dedupe by idempotency.
- **Events on `$all` grow** → every assignment write appends to the
  server's stream and bumps `$all`, as with all existing events —
  expected store behavior.
- **Rename is a breaking API change** → only two call sites exist
  (LiveView + tests); both updated in the same change.
