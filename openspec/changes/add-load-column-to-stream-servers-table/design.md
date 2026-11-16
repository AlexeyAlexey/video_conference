# Design

## Context

The stream server admin portal keeps its own `stream_servers` table in
a dedicated repo (`StreamServerAdminPortal.Repo`, migrations under
`priv/stream_server_admin_portal_repo/`). Every persisted mutation in
the `StreamServers` context goes through a per-field changeset guarded
by `optimistic_lock(:lock_version)`, and significant mutations append
domain events to the context's event store. The list page
(`StreamServersLive`) renders one column per field, with row-level
edit modals for each editable field.

See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Persist a `load` value (0–100) per portal stream server, defaulting
  to 0, enforced both in the changeset and by a database check
  constraint.
- Provide a context-level write path that future producers (e.g. an
  `ssak_`-authenticated self-report endpoint) can call without
  colliding with admin edits.
- Render the value on `/stream-server-admin/stream-servers`.

**Non-Goals:**

- Computing, aggregating, or reporting the load value.
- An HTTP endpoint for servers to report load — the context function
  is the seam for a later change.
- Any admin edit affordance for `load`.
- Emitting or extending domain events (`StreamServerWasAdded` keeps
  its current payload; no `LoadWasUpdated` event exists).
- The `/admin/stream-servers` page — that is a different table in a
  different repo.

## Decisions

### Dedicated column, not `settings.load`

`load` gets a real `integer` column rather than a key in the free-form
`settings` map. A column gives type safety, a check constraint, and
cheap ordering/filtering later (e.g. "least loaded server") — all of
which a map key cannot enforce.

### Range enforced at two layers

- `load_changeset` casts `:load` and runs
  `validate_number(:load, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)`.
- The migration adds `constraint(:stream_servers, :load_must_be_between_0_and_100, check: "load >= 0 AND load <= 100")`
  so direct SQL writes cannot bypass the range.

The main `changeset/2` does **not** cast `:load`: creation always
starts at the column default of 0 and the only write path is
`update_stream_server_load/2`.

### Load updates bypass `optimistic_lock`

`update_stream_server_load/2` updates through `load_changeset`
**without** `optimistic_lock(:lock_version)`. Rationale: load is
volatile telemetry. If every report checked and bumped
`lock_version`, (a) a report landing between an admin opening an edit
modal and saving it would fail the admin's write with a stale error,
and (b) the version counter would churn on telemetry rather than
meaningful edits. Last-writer-wins is correct for a gauge — only the
newest reading matters.

Alternative considered: guarding load updates like other fields —
rejected for the stale-edit collision above.

### No domain event for load

Load is a measurement, not a domain decision; an event per report
would flood the server's event stream with noise. `load` is also
excluded from `StreamServerWasAdded` — the event payload stays
unchanged.

### Read path needs nothing new

`list_stream_servers/1` selects the whole row, so `load` flows to the
LiveView for free once the column and schema field exist.

### Display: daisyUI progress bar + label

A `Load` column is added between `Cert hash` and `Applications`
(configuration columns left, metric column right). The cell renders a
`<progress class="progress" value={server.load} max="100">` bar with
the numeric percentage beside it — a bar communicates a 0–100 gauge
at a glance and matches the page's daisyUI styling.

## Risks / Trade-offs

- [A `Repo.update` on a loaded struct can clobber a concurrent admin
  edit if the updater's copy is old] → `load_changeset` only casts
  `:load`, so Ecto writes only the `load` column (plus `updated_at`);
  untouched fields are never overwritten.
- [Last-writer-wins drops intermediate readings] → acceptable: the
  column models "current load", not a history; history belongs in the
  future reporting mechanism, not this field.
- [Admins may expect to edit load like other columns] → out of scope
  by request; if needed later, a modal following the existing pattern
  is a small addition.
