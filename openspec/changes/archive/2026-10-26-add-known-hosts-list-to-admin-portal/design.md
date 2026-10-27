# Design

## Context

`known_hosts` already exists as a table (`id | name | settings | timestamps`,
empty, no indexes) created by migration `20260616121926`. That migration ran
on both dev and test SQLite databases, but the file has stray trailing lines
(`phone_books`, `phone_call_participants`) that make it a `CompileError` on
any fresh `mix ecto.migrate`/`ecto.reset`. The user confirmed no DB
back-compatibility is needed.

Admin portal plumbing to reuse: `forward "/admin"` →
`VideoConferenceWeb.AdminPortal.Router` (inner router sees stripped paths,
LiveView mount resolution requires `/admin`-prefixed mirror routes),
`Layouts.admin` layout + `AdminComponents.admin_sidebar`, `on_mount` hooks
(`mount_current_scope`, `ensure_authenticated`, `admin_sidebar`), and the
`seed_default_admin` migration as the seeding precedent. `phone_books` and
`phone_call_participants` carry a loose `:integer` `host_id` (`nil` = local)
with no FK — that stays as-is; nothing is wired to `known_hosts` yet.

## Goals / Non-Goals

**Goals:**
- Full `known_hosts` schema (unique name, alias, description, host,
  current_host, enabled, settings) with DB-level guarantees.
- A `VideoConference.AdminPortal.KnownHosts` context enforcing the current-host rules.
- A LiveView list/add/edit/remove UI at `/admin/known-hosts` + sidebar item.
- Tests + a browser-validated page.

**Non-Goals:**
- No call-flow wiring: `"local"` hardcoding, `HostPublicKey`,
  `host_id` resolution, remote calls — all future work.
- No FK constraints added to `host_id` columns (existing convention keeps
  them loose integers).
- No way to transfer `current_host` to another row through the UI/API.
- `enabled` is stored and displayed only; it gates nothing yet.

## Decisions

### Amend the create migration in place + separate seed migration

Edit `20260616121926_create_known_hosts.exs`: remove the stray lines, add
`name` (null: false), `name_alias`, `description`, `host`, `current_host`
(boolean, default false, null: false), `enabled` (boolean, default true,
null: false); `settings` stays `:map`. Add `unique_index(:known_hosts,
[:name])` and a partial unique index on `current_host`
(`where: "current_host"` — SQLite supports partial indexes,
`ecto_sqlite3` supports `where:`). A second migration seeds the
`current host` row (`insert_all`, `on_conflict: :nothing`) mirroring
`seed_default_admin`.

*Alternative — new alter migration:* rejected. The original migration is
broken anyway (stray text), no back-compat is required, and a clean single
create migration is easier to reason about. Cost: existing dev/test DBs
must be recreated.

### Context placement: `VideoConference.AdminPortal.KnownHosts`

New `lib/video_conference/admin_portal/known_hosts.ex` context and
`lib/video_conference/admin_portal/known_hosts/known_host.ex` schema,
matching the `AdminPortal.Accounts` + `Admin` layout — the user requires
the schema declared in the admin portal scope. If call routing later needs
to read the directory it will reference `AdminPortal.KnownHosts` (or the
context gets promoted in a future change).

### Current-host invariants enforced in the context, backed by the DB

- `current_host` is **not** a form field: it is set once by the seed and
  the UI never offers it. "Exactly one" is enforced by the partial unique
  index as backstop plus a context check rejecting `current_host: true`
  on any other row.
- `delete_known_host/1` returns an error tuple when
  `known_host.current_host` is true.
- Updates to the current host may not clear `current_host` or set
  `enabled` false — the changeset validates it (and the form locks the
  `name`/`enabled` inputs for that row).

*Alternative — editable current_host flag with transfer semantics:*
rejected; nothing needs it and it makes "exactly one" much harder to
guarantee.

### LiveView: one module, `live_action` routes + mirrors

`VideoConferenceWeb.AdminPortal.KnownHostsLive` in the `:admin`
live_session. Routes (plus `/admin`-prefixed mirrors for LV mount
resolution, per the router comment):

    live "/known-hosts",          KnownHostsLive, :index
    live "/known-hosts/new",      KnownHostsLive, :new
    live "/known-hosts/:id/edit", KnownHostsLive, :edit

`handle_params` assigns the form/list per action; `:new`/`:edit` render a
form panel (daisyUI card) above the table, keeping everything in one
LiveView like `SettingsLive`. Delete is `phx-click="delete"` with
`phx-value-id` and a browser `data-confirm`. The current host row renders a
"Current" badge, an edit action (locked fields), and no delete/disable
control.

*Alternative — single `:index` route with event-driven modal:* fewer
routes, but `live_action` is the canonical Phoenix pattern, easier to test
via `live(conn, path)` and to link to.

### Sidebar

Add a "Known hosts" `<.link navigate="/admin/known-hosts">` item in
`AdminComponents.admin_sidebar` between Dashboard and the email/settings
block, with `hero-server-stack` icon.

### Testing

- `test/support/fixtures/known_hosts_fixtures.exs` — `known_host_fixture/1`.
- `test/lib/video_conference/admin_portal/known_hosts_test.exs` — CRUD, unique name,
  single current host, current-host guards (DataCase).
- `test/video_conference_web/admin_portal/live/known_hosts_live_test.exs` —
  list renders, badge, add/edit/delete flows, missing controls on the
  current row, unauthenticated redirect (mirrors existing
  `settings_live_test.exs`/`dashboard_live_test.exs` login pattern).
- Manual: run dev server and verify the page in a real browser.

## Risks / Trade-offs

- Amended migration breaks existing DBs → dev/test SQLite files live
  outside the repo (`/home/alexey/Documents/elixir/video_conference_db/`);
  recreate via `mix ecto.reset` (or delete + `mix ecto.setup`) under
  `dotenv -e .env` / `.env.test`. Task list calls this out.
- `name` on the current host is locked in the form → if `name` later
  becomes the wire identifier replacing `"local"`, the seeded name
  `"current host"` may need renaming in a future migration. Acceptable:
  that migration can update the row.
- Partial unique index is SQLite-specific → fine; the app is SQLite-only
  (`ecto_sqlite3`).

## Migration Plan

1. Amend migration + add seed migration.
2. Reset dev and test databases so the corrected migration applies.
3. Implement context, LiveView, routes, sidebar.
4. `dotenv -e .env.test mix precommit`; then run the dev server and verify
   in the browser.
