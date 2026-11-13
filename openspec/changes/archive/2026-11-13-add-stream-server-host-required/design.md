# Design

## Context

`StreamServerAdminPortal.StreamServers.StreamServer` persists portal
stream servers in the portal's dedicated SQLite database
(`StreamServerAdminPortal.Repo`). `host` is already a unique,
create-only field: `changeset/2` casts and unique-validates it, and no
update changeset (`name_changeset`, `description_changeset`,
`country_changeset`, `cert_hash_changeset`) casts it. The column is
nullable today and `validate_required([:name])` omits it. See
proposal.md for motivation.

## Goals / Non-Goals

**Goals:**

- Reject creation of host-less stream servers at both the changeset
  and database levels.
- Reflect the requirement in the new-server form UI.
- Keep all existing validation and immutability behavior intact.

**Non-Goals:**

- Backfilling or repairing existing NULL-host rows (the migration fails
  loudly instead — see Migration Plan).
- Host format validation (ip vs. domain vs. ip:port) — `host` remains a
  free-form string.
- Changes to the main admin portal's `stream_servers` table, which is a
  separate schema in the main Repo.

## Decisions

- **Changeset-level requirement via `validate_required([:name, :host])`**.
  This is the same mechanism already used for `name`, produces the
  standard "can't be blank" error, and surfaces inline in the LiveView
  form via `phx-change="validate"`. Alternative — a custom validation —
  adds machinery for no behavioral gain.
- **New portal migration setting `host` to `NOT NULL`.** SQLite cannot
  alter a column in place and `ecto_sqlite3` rejects `modify/3`
  outright, so the migration rebuilds the table manually: copy rows
  into a `stream_servers_new` table with `host NOT NULL`, drop the old
  table, rename, and recreate the unique index. Because
  `application_stream_servers` has an `ON DELETE CASCADE` foreign key
  to `stream_servers`, its rows are first staged in a constraint-free
  backup table and the join table is recreated afterwards — dropping
  the parent while children reference it would delete them. All of it
  stays inside the migration's DDL transaction. The existing unique
  index on `host` (added in
  `20261110120000_add_host_uniqueness_and_lock_version_to_stream_servers`)
  is preserved. Alternative — a CHECK constraint — is also a table
  rebuild on SQLite and weaker than `NOT NULL`.
- **Delete existing NULL-host rows in the migration rather than
  backfilling.** `host` is unique and immutable, so there is no safe
  synthetic value. The migration runs
  `DELETE FROM stream_servers WHERE host IS NULL` before the rebuild;
  the `ON DELETE CASCADE` on `application_stream_servers` drops their
  assignments too, and the orphaned `StreamServerWasAdded` event
  history is accepted — backward compatibility for host-less rows is
  not required. Alternative considered: placeholder backfill —
  rejected because it manufactures invalid unique data.
- **Mark the host `<.input>` `required`** in
  `stream_servers_live.ex` (matching the existing `name` input) so the
  form communicates the requirement; server-side validation remains the
  real gate.
- **Fixture default host.** `stream_server_fixture/1` in
  `stream_server_admin_portal_fixtures.exs` gains a unique default
  `host` (e.g. derived from the unique name) so existing tests that
  create servers without a host keep passing.

## Risks / Trade-offs

- [Portal databases with NULL-host rows lose those rows on migrate] →
  Accepted; host-less servers are useless registry entries and
  backward compatibility is not required. Their application
  assignments are cascade-deleted and their `StreamServerWasAdded`
  event history is orphaned.
- [Unique index on a now-required column rejects multiple legitimately
  distinct servers sharing a host] → Pre-existing behavior
  (uniqueness was added earlier); unchanged by this change.
- [Fixture uniqueness across tests] → Default host is derived from the
  unique name generator, so no collisions.

## Migration Plan

1. Deploy code + migration together. On `mix ecto.migrate` (portal
   repo), NULL-host rows are deleted and the table rewrite enforces
   `NOT NULL`.
2. Rollback: revert the migration to restore a nullable column; the
  changeset requirement is code-only and rolls back with the release.
  Deleted NULL-host rows are not restored by a rollback.
