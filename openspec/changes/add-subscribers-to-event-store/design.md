# Design

## Context

The portal event store (`VideoConference.StreamServerAdminPortal.EventStore`,
portal `Repo`, SQLite) already provides `get_events(event_names, seq)` —
events filtered by `event_type` list, `seq > cursor`, ascending `seq`,
payloads decoded into structs. `events.seq` is a monotonic rowid: a safe
read cursor. `Phoenix.PubSub` (`VideoConference.PubSub`) runs but is
unused for this; the app has a flat `Supervisor` in
`VideoConference.Application`. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- `use EventStore.Listener` declares name, description, subscribed event
  modules, retry options; `handle_event/1` returns `:ok` /
  `{:error, reason}`.
- One supervised process per listener; durable cursor + status in an
  `event_listeners` table; durable `:failed` until explicit resume.
- `EventStore.resume_listener(name)` clears failure and restarts
  delivery at the last good cursor.

**Non-Goals:**

- Admin UI for listener status/restart (deferred; the table already
  holds what a page needs).
- PubSub/post-commit wake-up pokes (polling only; adding a poke later
  does not change cursor semantics).
- Multi-node delivery, exactly-once, or transactional side-effects.

## Decisions

### One GenServer per listener under a `DynamicSupervisor`

```
VideoConference.Supervisor
  |-- EventStore.ListenersSupervisor  (DynamicSupervisor, :temporary children)
        |-- ListenerRunner(MyListener)      GenServer
        |-- ListenerRunner(OtherListener)   GenServer
```

- A single process per listener makes in-order dispatch trivial — one
  event at a time, cursor owned by exactly one writer.
- `:temporary` restart policy is deliberate: a failed listener must
  *stay* down until resumed. A static `Supervisor` or `:permanent`
  policy would auto-restart and undo the `failed` marking.
- `DynamicSupervisor` gives resume for free — `resume_listener` is just
  `start_child` again.
- *Alternative: a Task that polls.* Rejected — no supervision identity,
  no named resume target.
- *Alternative: one consumer process dispatching to all listeners.*
  Rejected — one poison event would stall every listener; per-listener
  processes isolate failure.

### Durable state in `event_listeners` table

Columns: `name` (unique, non-empty), `description`, `last_seen_seq`
(integer, default 0), `status` (`"ok"` / `"failed"`), `last_error`
(string, nullable). Runner upserts its row on boot (metadata comes from
the module; the row carries cursor/status), then refuses to start if
`status` is `"failed"`.

- Cursor is written **after each successful `handle_event`**, before the
  next event is fetched — the acknowledged set is never ahead of the
  durable cursor.
- *Alternative: cursor in memory + snapshot.* Rejected — restart would
  replay from an old snapshot or zero.
- *Alternative: update cursor in the same transaction as handler
  side-effects.* Not possible — the handler is an opaque callback; we
  accept at-least-once and document idempotency.

### Polling loop, no push notification

Runner polls `get_events(types, cursor)` on an interval (config
`:event_listener_poll_interval`, default ~1s), sleeping when the result
is empty. Wake-up pokes are a later optimization: since the append
commits inside the *caller's* `Repo.transaction`, a reliable poke must
be emitted after commit — `Repo.transaction`'s `{:ok, _}` return is the
only safe hook, which couples producers to listeners. Polling decouples
them entirely; ~1s latency is fine for an admin portal.

### Retry policy: exponential backoff, per-listener config

`use EventStore.Listener, retries: 5, backoff: 500` — attempt 1 fails,
sleep `backoff * 2^(n-1)` (capped, e.g. `max_backoff: 30_000`), retry.
`retries: 0` means fail immediately. Exceptions/exits inside
`handle_event` are rescued/caught and normalized to `{:error, reason}`
so they flow through the same retry path instead of crashing the
runner.

- *Alternative: fixed delay.* Rejected — failures usually mean an
  unhappy downstream; backing off is kinder and standard.

### `resume_listener/1` on `EventStore`

```elixir
def resume_listener(name) :: :ok | {:error, :not_found | :not_failed}
```

Sets `status` `"ok"` (clears `last_error`), then
`DynamicSupervisor.start_child` for that listener. The runner resumes at
its persisted cursor — the failed event is delivered first. Callable
from IEx today, from an admin UI later.

### `use` macro surface

`__using__` stores `name`, `description`, `events` (module list →
`inspect/1` strings matching stored `event_type`), `retries`, `backoff`
as module attributes; injects a `handle_event/1` behaviour callback.
Runner reads config via `module.__listener__/0` (generated) rather than
`module_info` tricks.

- Subscription is explicit, not derived from `handle_event` clauses —
  clauses can't be enumerated reliably at runtime, and explicitness
  makes typos fail loudly at compile time.

### Listener registration via app config

`config :video_conference, :event_listeners, [MyListener, ...]` —
supervisor iterates the list at boot, skipping `failed` rows. Adding a
listener is a config edit, not a code edit in the supervisor.

## Risks / Trade-offs

- **At-least-once redelivery** → handlers must be idempotent; documented
  in the `Listener` moduledoc.
- **Poison event halts a listener until human resume** → `last_error` +
  `last_seen_seq` point at the offending event; resume retries it.
- **SQLite write per event for cursor** → fine at admin-portal event
  volume; batch later if volume grows.
- **Poll latency up to interval** → acceptable; poke can be added
  without changing semantics.
- **No compile-time check that `events:` matches `handle_event`
  clauses** → a subscribed type with no clause raises
  `FunctionClauseError`, normalized to a failure — the listener fails
  loudly rather than silently dropping.

## Migration Plan

1. Migration creates `event_listeners` (portal repo).
2. New modules compile; `:event_listeners` config names modules to run
   (empty list = feature inert).
3. Rollback: remove supervisor child + config; table is additive, keep
   or drop.
