# Design

## Context

The `Applications` context mutates stream server public keys through six
functions. Only `create_stream_server_public_key/1` records an event
(`StreamServerPublicKeyAddedEvent`, in `applications/` not `events/`);
`enable_`, `disable_`, `switch_stream_server_public_key_application`,
and `delete_stream_server_public_key` are plain `Repo.update` /
`Repo.delete` calls. `rename_` and `edit_..._description` stay plain —
their fields are portal-cosmetic (see proposal).

The event modules and `Multi` + `EventStore.append` wiring follow the
recipe in `.devin/skills/add-event-store-event/SKILL.md`, already
exercised by the `ApplicationWas*` siblings in the same context.

## Goals / Non-Goals

**Goals:**

- Every behaviorally meaningful key mutation (add, enable, disable,
  remove, move) appends its event atomically with the record change.
- Event modules share the established shape: `:stream_id` first, then
  snapshot fields, then `:lock_version`; file under `events/`; module in
  the context's flat namespace.
- Public context signatures keep returning `{:ok, key}` /
  `{:error, changeset}` — callers see only the two renames.

**Non-Goals:**

- No events for rename or description edits.
- No migration of rows already stored as `StreamServerPublicKeyAddedEvent`
  (dev data; see Risks).
- No listener or projection changes — `listener.ex` needs only a
  moduledoc rename; no listener currently subscribes to key events in
  production code.

## Decisions

### Event name and verb: `WasMoved`, function `move_..._to_application`

`StreamServerPublicKeyApplicationWasChanged` was rejected — its subject
is ambiguous ("the application was changed"). The existing docstring
already says *"Moves a stream server public key to another application"*,
so the verb `move` is the domain's own language:
`move_stream_server_public_key_to_application/2` ↔
`StreamServerPublicKeyWasMoved`. `change_..._application` was rejected
because `change_*` is the codebase's changeset-builder convention
(`change_stream_server_public_key/2` already exists).

Alternative considered: `StreamServerPublicKeyWasReassigned` /
`reassign_stream_server_public_key`. Workable but introduces a second
verb for the same operation; the code and docs already say "move".

### `WasMoved` payload: `from_application_id` + `to_application_id`

Unlike rename-style events that snapshot only post-state, a move's
meaning *is* the delta. A listener projecting "application → keys" needs
the source to evict the key from the old application's set — the
destination alone cannot say where it came from, and requiring a
key→application reverse index in every listener is needless coupling.
Both values are available at append time: `from` off the pre-update
struct (function argument), `to` off the merged update result.

Alternative considered: `application_id` (new only) for consistency with
siblings. Rejected — it pushes real work onto subscribers.

### `WasAdded` gains `id` and `lock_version`

The event predates the convention solidified by `ApplicationWasAdded`
(`:stream_id, :id, ...fields, :lock_version`). Renaming the module is
already a breaking change for stored rows, so this is the cheapest
moment to normalize the field set.

### `WasRemoved` built from the pre-delete struct

Per the skill's delete exception: `Multi.delete`'s returned struct
carries the `optimistic_lock` increment, but deletes don't actually bump
the version — the event must record the version the delete matched. The
merge callback ignores its `changes` argument and builds the event from
the `%StreamServerPublicKey{}` passed in (same as `remove_application`).

### `transaction_result/1` generalized by operation key

The helper currently maps `%{application: app}` only;
`create_stream_server_public_key` carries a private inline `case`. The
helper gains a `%{stream_server_public_key: key}` clause and the inline
`case` is deleted — one mapping for both aggregates.

## Risks / Trade-offs

- **Orphaned stored events** → Rows stored as
  `StreamServerPublicKeyAddedEvent` can never decode after the rename
  (`binary_to_term` needs the module atom; `get_events` filters by the
  new `event_type` string so they silently never surface). Dev data
  only — delete the stale rows or accept them as dead weight; note it
  in tasks verification.
- **No-op moves** → `move_stream_server_public_key_to_application` with
  the key's current `application_id` still emits `WasMoved` with equal
  from/to (the skill's no-op-emits invariant; listeners must be
  idempotent). Acceptable — the operation ran; filtering would add an
  exceptional path for no benefit.
- **Longer `Multi` boilerplate** → Six near-identical function bodies.
  Resist extracting a shared "update + emit" helper: the Application
  siblings kept them explicit, and each event's `new/1` call site stays
  grep-able.
