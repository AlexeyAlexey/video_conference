# Design

## Context

The app has a single Ecto repository (`VideoConference.Repo`, SQLite via
`DATABASE_PATH`) and one admin portal at `/admin` — a forwarded router
(`VideoConferenceWeb.AdminPortal.Router`) with its own email/password
auth (`admins`/`admins_tokens` tables, session key `:admin_token`,
`Scope` carrying `current_scope.admin`), a collapsible left sidebar, and
LiveView pages including settings/change-password. Per proposal.md, this
change stands up a second, isolated portal at `/stream-server-admin` for
future stream-server management; nothing moves out of `AdminPortal`.

## Goals / Non-Goals

**Goals:**

- Physical data isolation: portal tables live in a second SQLite file
  behind a second Repo, so future managed entities (API keys, public
  keys, access rules) inherit the boundary for free.
- Full portal shell: sign-in, dashboard, settings/change-password,
  responsive sidebar layout — behaviorally identical to `/admin`.
- Both repos migrate and sandbox cleanly in dev, test, and prod.

**Non-Goals:**

- No managed stream-server entities, no HTTP API between portals, no
  deployment role gating — later changes.
- No shared/refactored auth code between the two portals.
- No changes to `/admin` routes, tables, or specs.

## Decisions

### D1: Second Repo with its own `priv` directory

`VideoConference.StreamServerAdminPortal.Repo` (ecto_sqlite3) is added
to `ecto_repos` in `config/config.exs` and to the supervision tree. Its
database path comes from `STREAM_SERVER_ADMIN_DATABASE_PATH` in dev,
test, and prod (runtime.exs), mirroring `DATABASE_PATH`.

Its config MUST set `priv: "priv/stream_server_admin_portal_repo"`.
Without it, Ecto derives the priv dir from the repo's last module
segment (`Repo` → `priv/repo`), colliding with the main repo's
migrations. With `ecto_repos` listing both, `mix ecto.create` /
`mix ecto.migrate` cover both automatically; `priv/repo/seeds.exs` stays
a main-repo concern.

Alternative considered: separate tables in the main DB — rejected, it
violates the "own database" isolation the user requires. An umbrella
child app was rejected as disproportionate; the portals share one
endpoint and process space, which is acceptable for now.

### D2: Copy, don't share

`Accounts` (Admin/Token/Scope schemas + context), `AdminAuth`
plugs/on_mount hooks, `admin_components` (sidebar), the session
controller + login HTML, and the settings/dashboard LiveViews are copied
into the new scopes and minimally renamed. Deliberate duplication keeps
each portal free to diverge and avoids a shared-auth refactor touching a
working portal. The user explicitly authorized copying the layout.

The copied `Scope` keeps the `admin` field name so `current_scope.admin`
works identically in both portals and components need no reshaping.

### D3: Independent session key and literal paths

Session key `:stream_server_admin_token`; redirects use literal
`/stream-server-admin/...` paths (verified routes can't see forwarded
paths — same constraint as the admin portal). Combined with separate
token tables in separate DBs, a session in one portal provably cannot
open the other.

### D4: Router via `forward` + mirrored live routes

Main router gains `forward "/stream-server-admin",
VideoConferenceWeb.StreamServerAdminPortal.Router`. The inner router
duplicates the admin router's workaround: stripped dispatch paths plus
`/stream-server-admin`-prefixed mirror `live` routes so the LiveView
channel mount's `route_info` check resolves the public URL. The
explanatory comment from the admin router is carried over.

### D5: Seed default admin via migration in the portal repo

A migration in `priv/stream_server_admin_portal_repo/migrations`
inserts `admin@admin.com` / bcrypt("admin") with `on_conflict: :nothing`
using `repo()` — which resolves to the portal repo because the migration
runs from its migrations directory. Mirrors
`20261024100100_seed_default_admin.exs`.

### D6: Test setup — dual sandbox, both repos migrated

- `test.exs`: portal repo gets `database:` from
  `STREAM_SERVER_ADMIN_DATABASE_PATH` and `pool:
  Ecto.Adapters.SQL.Sandbox`.
- `DataCase.setup_sandbox/1`: `start_owner!` + `stop_owner` for both
  repos (shared mode when not async).
- `.env.test(.example)`: add `STREAM_SERVER_ADMIN_DATABASE_PATH` so
  `dotenv -e .env.test mix test`/`mix precommit` work.
- `mix.exs` aliases: `ecto.setup`/`ecto.reset`/`test` already cover both
  repos once `ecto_repos` lists both; no per-repo `-r` needed. Seeds run
  remains main-repo only.
- New `StreamServerAdminPortalFixtures` for portal admin creation.

## Risks / Trade-offs

- Missing `STREAM_SERVER_ADMIN_DATABASE_PATH` in an env → repo fails at
  boot, same failure mode as `DATABASE_PATH` today. Mitigate: document
  in `.env.example`/`.env.test.example`; runtime.exs raise for prod like
  the main DB if desired (dev/test read env directly, consistent with
  `DATABASE_PATH`).
- Duplicated auth/UI code drifting from the admin portal → accepted;
  the isolation boundary is the point. Specs are per-portal so drift is
  detectable.
- LiveView-through-forward quirk → mirror routes + carried-over comment;
  already proven in the admin router.
- Extra SQLite file on app deployments that never use the portal →
  trivial cost; role gating deferred deliberately.

## Migration Plan

1. Add repo config (`config.exs` `ecto_repos` + `priv`, dev/test/runtime
   env wiring) and the repo module.
2. Add migrations dir + auth-tables migration + default-admin seed
   migration; `mix ecto.create && mix ecto.migrate`.
3. Add context + web scopes, then the `forward` line — last, so the
   route never exists without its backing code.
4. Extend test setup; run `dotenv -e .env.test mix test`, then
   `mix precommit`.

Rollback: revert the `forward`, remove the repo from `ecto_repos` and
the supervision tree, delete the new dirs. No data migration involved —
the portal DB is new.

## Open Questions

- Sidebar brand label/icon for the portal (cosmetic; pick during
  implementation, e.g. "Stream Server Admin").
