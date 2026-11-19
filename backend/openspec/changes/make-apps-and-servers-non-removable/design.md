# Design

## Context

The stream server admin portal (`StreamServerAdminPortal.Repo`,
`priv/stream_server_admin_portal_repo/migrations/`) holds `applications`
and `stream_servers` tables, each with a `unique_index` on `name` (the
servers table additionally has `unique_index` on `host`). Removal today
is a full path: Remove button → `"delete"` LiveView event →
`remove_application/1` / `remove_stream_server/1` → `Ecto.Multi.delete` +
`*WasRemoved` event append in one transaction. Events are persisted as
`event_type` = `inspect(module)` plus a `term_to_binary` payload, decoded
with `binary_to_term(..., [:safe])`. `config :event_listeners` is `[]` in
every env — nothing consumes `*WasRemoved` events.

See proposal.md for motivation and the spec deltas for the resulting
behavior contract.

## Goals / Non-Goals

**Goals:**

- Make applications and portal stream servers undeletable end to end —
  UI, context API, and event types.
- Re-identity both records: application UUID and server `host` become
  the identifiers; `name` becomes a non-unique required label.
- Surface the application UUID in the applications list as a copyable
  App ID.

**Non-Goals:**

- The `/admin` portal's separate `stream_servers` table
  (`VideoConference.Repo`): its `host` is not unique, so `name` stays
  its identifier and its Remove button stays.
- Removing `on_delete: :delete_all` foreign keys on `api_keys`,
  `stream_server_public_keys`, and `application_stream_servers`. With no
  delete path they are dead-but-harmless; leaving them keeps the schema
  compatible if deletion is ever reintroduced.
- API keys and stream server public keys remain removable — only the two
  aggregate roots lose their delete.
- Migrating or scrubbing historical `*WasRemoved` rows in `events`.

## Decisions

### Drop the name indexes in a new forward migration

A new migration drops `index(:applications, [:name])` and
`index(:stream_servers, [:name])`; the earlier create migrations are not
edited (they may already have run elsewhere). **Alternative** — editing
the original migrations — was rejected: it rewrites migration history
and silently diverges from databases that already ran them.

### Strip name-uniqueness validation, keep `validate_required([:name])`

`unsafe_validate_unique(:name, Repo)` + `unique_constraint(:name)` are
removed from `Application.changeset/2`, `Application.name_changeset/2`,
`StreamServer.changeset/2`, and `StreamServer.name_changeset/2`. `host`
keeps both its unique index and its changeset checks. With no unique
index, a leftover `unique_constraint(:name)` could never fire but would
be misleading; a leftover `unsafe_validate_unique` would race-check a
constraint that no longer exists — both go.

### Full excision of the delete path, including event modules

Remove buttons, `"delete"` `handle_event` clauses,
`remove_application/1`, `remove_stream_server/1`, the
`ApplicationWasRemoved` / `StreamServerWasRemoved` aliases, and the two
event module files are all deleted. **Alternative** — keeping the
context functions and event modules while removing only the UI — was
rejected (user decision): dead privileged code invites accidental
future use, and the spec deltas remove the behavior entirely.

Consequence recorded here rather than left implicit: event payloads are
`term_to_binary`'d structs, so deleting the modules makes any
pre-existing `*WasRemoved` rows raise on decode *if* they are ever
fetched by type. `get_events/2` filters by `event_type` before decoding,
no listener subscribes, and nothing else queries those types — the risk
is a manual ad-hoc query, which is acceptable.

### App ID rendered like cert_hash

The applications table gains an App ID column showing the full
`application.id` UUID with a copy-to-clipboard button, reusing the
cert-hash column's pattern (hidden `span` holding the value +
`navigator.clipboard.writeText` button). **Alternative** — a truncated
UUID — rejected: the App ID exists to be copied into integration config,
so fidelity beats compactness; the column sits first so it reads as the
row's identity.

## Risks / Trade-offs

- **[Duplicate names confuse operators]** → Accepted deliberately: name
  is now a display label. The App ID column and host uniqueness carry
  identification duties.
- **[A future need to delete resurfaces]** → Reversal is additive:
  re-add a context function + event module. The `delete_all` FKs were
  intentionally left in place to keep that cheap.
- **[Ad-hoc `get_events` on a removed type crashes]** → Accepted:
  requires explicitly querying for a type the system no longer emits;
  no code path does this.
- **[Tests relying on delete fixtures break]** → Test updates are part
  of the change; fixture helpers for applications/servers lose any
  delete-based cleanup (sandbox rollback covers it anyway).

## Migration Plan

1. Deploy code + migration together: the new migration only drops
   indexes, so old and new code inter-operate during rolling deploys
   (old code's `unique_constraint` still sees the index until the
   migration runs; worst case a duplicate-name insert fails on a
   constraint the new code no longer checks — transient and benign).
2. Rollback: `mix ecto.rollback` restores both indexes (they are
   `create`d by `drop`'s inverse only if the migration uses
   `drop index(...) ... name:` — use explicit `name:`/`create` in
   `down` if reversible `change` cannot infer it). Revert the code
   deploy to restore the delete path.
