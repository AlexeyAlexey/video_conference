# Tasks

## 1. Data layer

- [x] 1.1 Amend `priv/repo/migrations/20260616121926_create_known_hosts.exs`: remove the stray `phone_books`/`phone_call_participants` lines, make `name` non-null, add `name_alias`, `description`, `host`, `current_host` (boolean, default false, null: false), `enabled` (boolean, default true, null: false), plus a unique index on `name` and a partial unique index on `current_host` (`where: "current_host"`). Verify with `dotenv -e .env.test mix ecto.reset` completing without error.
- [x] 1.2 Create the schema `VideoConference.AdminPortal.KnownHosts.KnownHost` (`lib/video_conference/admin_portal/known_hosts/known_host.ex`) with changesets enforcing required `name`, `unique_constraint(:name)`, and rejecting `enabled: false` or `current_host: false` on the current host row. Verify via the context tests below.
- [x] 1.3 Create the context `VideoConference.AdminPortal.KnownHosts` (`lib/video_conference/admin_portal/known_hosts.ex`) with `list_known_hosts/0`, `get_known_host!/1`, `create_known_host/1`, `update_known_host/2`, `delete_known_host/1`, `change_known_host/2`; `delete_known_host` and updates that clear `current_host`/`enabled` or set `current_host` on a second row return error tuples. Verify via `test/lib/video_conference/admin_portal/known_hosts_test.exs`.
- [x] 1.4 Add `test/support/fixtures/known_hosts_fixtures.exs` and `test/lib/video_conference/admin_portal/known_hosts_test.exs` covering CRUD, duplicate-name rejection, second-current-host rejection, and current-host delete/disable guards. Verify `dotenv -e .env.test mix test test/lib/video_conference/admin_portal/known_hosts_test.exs` passes.
- [x] 1.5 Create the seed migration inserting the `current host` row (`current_host: true`, `enabled: true`, `on_conflict: :nothing`), following `seed_default_admin`. Verify a fresh `dotenv -e .env.test mix ecto.reset` leaves exactly one `current_host` row named `current host`.

## 2. Admin UI

- [x] 2.1 Add routes in `VideoConferenceWeb.AdminPortal.Router` inside the `:admin` live_session — `live "/known-hosts"` (`:index`), `live "/known-hosts/new"` (`:new`), `live "/known-hosts/:id/edit"` (`:edit`) — each with its `/admin`-prefixed mirror route. Verify `mix phx.routes` lists them.
- [x] 2.2 Create `lib/video_conference_web/admin_portal/live/known_hosts_live.ex`: table of all hosts (name, alias, host, enabled), "Current" badge on the current host, `handle_params`-driven add/edit form, `phx-click` delete with `data-confirm`; current host row has no delete/disable control and its form locks `name`/`enabled`. Verify via the LiveView test below.
- [x] 2.3 Add the "Known hosts" sidebar item in `AdminComponents.admin_sidebar` (navigate to `/admin/known-hosts`, `hero-server-stack` icon). Verify it appears in the sidebar test assertions and visually in the browser step.
- [x] 2.4 Add `test/video_conference_web/admin_portal/live/known_hosts_live_test.exs` covering list rendering, "Current" badge, add/edit/delete flows, absent delete/disable controls on the current host row, duplicate-name inline error, and the unauthenticated redirect. Verify `dotenv -e .env.test mix test test/video_conference_web/admin_portal/live/known_hosts_live_test.exs` passes.

## 3. Database reset and end-to-end validation

- [x] 3.1 Reset dev and test SQLite databases so the amended migration applies (`dotenv -e .env mix ecto.reset`, `dotenv -e .env.test mix ecto.reset`; DB files live under `/home/alexey/Documents/elixir/video_conference_db/`). Verify `known_hosts` has the new columns and one `current host` row.
- [x] 3.2 Run `dotenv -e .env.test mix precommit` and fix any failures (compile warnings-as-errors, formatting, tests).
- [x] 3.3 Start the dev server (`dotenv -e .env mix phx.server`), open the app in the integrated browser, sign in to `/admin`, and verify: the sidebar shows "Known hosts", `/admin/known-hosts` lists the seeded `current host` row with its badge, and add/edit/remove work in the UI.
