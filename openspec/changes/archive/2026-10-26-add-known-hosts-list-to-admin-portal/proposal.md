# Proposal

## Why

The `known_hosts` table exists but is an empty stub: it only has `name` and
`settings` columns, holds no rows, and nothing in the app reads or writes it.
Known hosts are peer instances of this same application — when two instances
know each other, their participants can eventually call each other. Before any
federation wiring lands, the app needs a usable data model for hosts and an
admin-facing way to manage them. The migration file also currently has stray
trailing text that crashes a fresh `mix ecto.migrate` run.

## What Changes

- Extend the `known_hosts` table with the full attribute set: `name`
  (unique, required), `name_alias` (optional display name), `description`
  (optional), `host` (ip/domain/ip+port text), `current_host` (boolean),
  `enabled` (boolean), `settings` (map, default `%{}`). This amends the
  existing `create_known_hosts` migration in place — no DB back-compat is
  required, dev/test databases will be reset. The stray trailing lines in
  the migration file are removed.
- Add a unique index on `known_hosts.name` and a partial unique index on
  `current_host` so at most one row can be the current host.
- Seed a single "current host" row via a migration (following the
  `seed_default_admin` precedent): `name: "current host"`,
  `current_host: true`, `enabled: true`.
- New `VideoConference.AdminPortal.KnownHosts` context with
  list/get/create/update/delete/change functions and guards: unique names,
  at most one current host, and the current host cannot be disabled or
  removed.
- New admin LiveView at `/admin/known-hosts` listing all hosts with add,
  edit, and remove actions. The current host row shows a "Current" badge
  and cannot be disabled or removed.
- New "Known hosts" item in the admin sidebar.
- Tests for the context, the LiveView, and the seed migration behavior,
  plus manual validation of the page in a browser.
- **BREAKING** (dev only): the existing `create_known_hosts` migration is
  edited in place; databases that already ran it must be recreated
  (`mix ecto.reset` or delete the SQLite file).

Out of scope: wiring `host_id` into call routing, replacing the hardcoded
`"local"` identity in `phone_channel.ex` / `connection_credentials.ex` /
`HostPublicKey`, remote-call federation, and any behavior driven by the
`enabled` flag beyond storage and display.

## Capabilities

### New Capabilities

- `known-hosts`: The directory of peer application instances this host
  knows about — its data model (unique name, display alias, description,
  address, current-host flag, enabled flag, free-form settings) and the
  admin UI for listing, adding, editing, and removing entries, including
  the rules protecting the single current host.

### Modified Capabilities

## Impact

- `priv/repo/migrations/20260616121926_create_known_hosts.exs` — amended
  in place (new columns, indexes, stray text removed).
- New migration seeding the current-host row.
- New `lib/video_conference/admin_portal/known_hosts.ex` context and
  `lib/video_conference/admin_portal/known_hosts/known_host.ex` schema
  (declared in the admin portal scope, matching `AdminPortal.Accounts`).
- New `lib/video_conference_web/admin_portal/live/known_hosts_live.ex`
  plus routes (with `/admin`-prefixed mirror routes) in
  `VideoConferenceWeb.AdminPortal.Router`.
- `lib/video_conference_web/admin_portal/admin_components.ex` — sidebar
  nav item.
- New fixtures and tests under `test/`.
- No changes to public APIs, channels, or call flows.
