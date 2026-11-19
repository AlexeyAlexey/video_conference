# Tasks

## 1. Portal repository, configuration, and test infrastructure

- [x] 1.1 Add `VideoConference.StreamServerAdminPortal.Repo` (ecto_sqlite3); register it in `ecto_repos` in `config/config.exs` with `priv: "priv/stream_server_admin_portal_repo"`; verify `mix compile` succeeds
- [x] 1.2 Wire `STREAM_SERVER_ADMIN_DATABASE_PATH` into `config/dev.exs`, `config/test.exs` (with `pool: Ecto.Adapters.SQL.Sandbox`), and `config/runtime.exs` prod block; add the var to `.env.example` and `.env.test.example` (and local `.env`/`.env.test`); verify `dotenv -e .env mix phx.server` boots with both repos
- [x] 1.3 Add the repo to the supervision tree in `lib/video_conference/application.ex`; verify both repos appear in `Application.started_applications`/repo logs on boot
- [x] 1.4 Create `priv/stream_server_admin_portal_repo/migrations/` with a create-`admins`+`admins_tokens` migration (mirroring `20261024100000_create_admins_auth_tables.exs`) and a seed-default-admin migration (mirroring `20261024100100_seed_default_admin.exs`, `repo()` + `on_conflict: :nothing`); verify `mix ecto.create && mix ecto.migrate` creates both DBs and the default admin row exists only in the portal DB
- [x] 1.5 Extend `DataCase.setup_sandbox/1` (and any `ConnCase` sandbox usage) to `start_owner!`/`stop_owner` the portal repo alongside `VideoConference.Repo`; verify `dotenv -e .env.test mix test` still passes for existing tests
- [x] 1.6 Verify `mix.exs` aliases (`ecto.setup`, `ecto.reset`, `test`) cover both repos via `ecto_repos` (no `-r` needed) and that seeds run remains main-repo only; verify `mix ecto.reset` leaves the portal DB migrated with the seeded admin

## 2. Portal accounts context

- [x] 2.1 Create `lib/video_conference/stream_server_admin_portal/accounts/` with `Admin`, `Token`, `Scope` schemas (scope keeps the `admin` field) plus `accounts.ex` context — copied from `VideoConference.AdminPortal.Accounts`, repointed to the portal repo and module names; verify `mix compile` succeeds
- [x] 2.2 Add `test/support/fixtures/stream_server_admin_portal_fixtures.exs` for portal admin creation; verify fixture inserts into the portal repo
- [x] 2.3 Add context tests (`test/lib/video_conference/stream_server_admin_portal/accounts_test.exs` or matching project layout) covering sign-in lookup, session token generation/lookup/deletion, and password update expiring tokens; verify they pass with `dotenv -e .env.test mix test`

## 3. Portal router, auth plugs, and sign-in

- [x] 3.1 Create `VideoConferenceWeb.StreamServerAdminPortal.AdminAuth` (session key `:stream_server_admin_token`, literal `/stream-server-admin` redirects, `on_mount` hooks incl. sidebar toggle — copied from `AdminPortal.AdminAuth`); verify `mix compile` succeeds
- [x] 3.2 Create `VideoConferenceWeb.StreamServerAdminPortal.Router` with browser pipeline, public `GET/POST /log-in`, authenticated `DELETE /log-out` + `POST /update-password`, and a `live_session` with dashboard/settings routes plus `/stream-server-admin`-prefixed mirror `live` routes (carry over the admin router's explanatory comment); add `forward "/stream-server-admin"` in the main router; verify `mix phx.routes` shows the routes
- [x] 3.3 Create `SessionController` + `SessionHTML` + `log_in.html.heex` under `stream_server_admin_portal/` (copied from the admin portal, brand/text adjusted); verify `GET /stream-server-admin/log-in` renders and posting `admin@admin.com`/`admin` establishes the session and redirects to `/stream-server-admin`
- [x] 3.4 Add conn tests covering: successful/failed sign-in (timing-safe), unauthenticated redirect to `/stream-server-admin/log-in`, sign-out invalidation, and session independence (an `/admin` session does not open `/stream-server-admin` and vice versa); verify they pass with `dotenv -e .env.test mix test`

## 4. Portal layout components and LiveViews

- [x] 4.1 Create `admin_components.ex` with the sidebar/nav components copied from the admin portal, trimmed to Dashboard + admin email + Settings (Change password) + log out; verify sidebar renders only when authenticated
- [x] 4.2 Create `DashboardLive` and `SettingsLive` (change-password form, all-sessions-expired behavior) copied and repointed from the admin portal versions; verify both mount at `/stream-server-admin` and `/stream-server-admin/settings` via the live_session and mirror routes
- [x] 4.3 Add LiveView tests for dashboard rendering, settings password change (success signs out, wrong current password, mismatched confirmation), sidebar contents/collapse, and responsive drawer behavior hooks; verify they pass with `dotenv -e .env.test mix test`

## 5. Integration verification

- [x] 5.1 Start the dev server and use the integrated browser preview to validate: sign-in page at `/stream-server-admin/log-in`, login with default credentials, sidebar navigation/collapse, log out, change password flow ending in re-login with the new password, and mobile viewport layout; verify each flow works end-to-end
- [x] 5.2 Run `dotenv -e .env.test mix precommit` and fix all warnings/test failures; verify it exits clean
