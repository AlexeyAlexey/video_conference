# Tasks

## 1. AdminPortal data layer

- [x] 1.1 Create a `priv/repo/migrations/` migration for `admins` (email unique, hashed_password) and `admin_tokens` (token binary, context, admin_id FK, authenticated_at); verify `mix ecto.migrate` creates the tables in the existing database.
- [x] 1.2 Create a `priv/repo/migrations/` seed migration inserting default admin `admin@admin.com` with `Bcrypt.hash_pwd_salt("admin")` using `on_conflict: :nothing`; verify the credential exists after migrate and re-running does not duplicate.
- [x] 1.3 Create `VideoConference.AdminPortal.Accounts.Admin` schema (email, virtual password redacted, hashed_password) with registration and password changesets plus `valid_password?/2` using `Bcrypt`, mirroring `Accounts.Phone`; verify changeset unit tests pass.
- [x] 1.4 Create `VideoConference.AdminPortal.Accounts.Token` schema and `VideoConference.AdminPortal.Accounts` context (`get_admin_by_email_and_password/2`, `generate_session_token/1`, `get_admin_by_session_token/1`, `delete_session_token/1`, `change_admin_password/2`, `update_admin_password/2` expiring all tokens); verify context tests pass.
- [x] 1.5 Create `VideoConference.AdminPortal.Accounts.Scope` with `for/1` mirroring `Accounts.Scope`; verify `Scope.for(admin)` produces `%Scope{admin: admin}` in a test.
- [x] 1.6 Create `test/support/fixtures/admin_portal_fixtures.ex` (`admin_fixture/0`, `valid_admin_password/0`); verify existing tests still pass with `dotenv -e .env.test mix test`.

## 2. Admin auth and router split

- [x] 2.1 Create `lib/video_conference_web/admin_portal/admin_auth.ex` with `fetch_current_scope_for_admin/2`, `require_authenticated_admin/2`, `redirect_if_admin_is_authenticated/2`, `log_in_admin/3` (renew session + `put_session(:admin_token, token)`), `log_out_admin/1`, and `on_mount` hooks (`:mount_current_scope`, `:ensure_authenticated`, `:redirect_if_authenticated`); verify plug tests pass.
- [x] 2.2 Create `lib/video_conference_web/admin_portal/router.ex` (`VideoConferenceWeb.AdminPortal.Router`) with its own `:browser` pipeline (includes `fetch_current_scope_for_admin`) and the scopes from design.md (log-in + POST session unauthenticated; `live_session :admin` + DELETE log-out authenticated); verify router compiles.
- [x] 2.3 In `lib/video_conference_web/router.ex` add `forward "/admin", VideoConferenceWeb.AdminPortal.Router`; verify `mix phx.routes` shows both existing routes and `/admin` forwarded routes, and no existing route changed.
- [x] 2.4 Create `lib/video_conference_web/admin_portal/controllers/session_controller.ex` (or flat `session_controller.ex` matching project layout) with `create` (verify credentials → `log_in_admin` → redirect `/admin`; failure → flash + redirect back) and `delete` (`log_out_admin` → redirect `/admin/log-in`); verify controller tests pass (success, bad password, unknown email, sign-out).

## 3. Admin portal LiveViews

- [x] 3.1 Create `lib/video_conference_web/admin_portal/controllers/session_html/log_in.html.heex` (+ `SessionHTML` and `SessionController.new`) rendering a `<.form>` that POSTs email/password to the session controller, wrapped in `<Layouts.admin flash={@flash}>`; verify controller test renders the form and unauthenticated POSTs behave per spec.
- [x] 3.2 Create `lib/video_conference_web/admin_portal/live/dashboard_live.ex` mounted at `/admin` inside `live_session :admin`, wrapped in `<Layouts.admin flash={@flash} current_scope={@current_scope}>`; verify LiveView test: authenticated admin sees dashboard, unauthenticated is redirected to `/admin/log-in`.
- [x] 3.3 Create `lib/video_conference_web/admin_portal/live/settings_live.ex` with a password-change form (current password, new password, confirmation) calling `Accounts.update_admin_password/2`; on success all admin tokens are expired and the admin is signed out and redirected to `/admin/log-in`; verify LiveView tests for success, wrong current password, and mismatched confirmation.
- [x] 3.4 Wire navigation between dashboard and settings via the `Layouts.admin` navigation bar (signed-in admin email on the right, Settings link) and a form-based log out (POST `/admin/log-out` with `_method=delete`, works without JS); verify via LiveView test that links resolve.
- [x] 3.5 Make all admin pages responsive (log-in, dashboard, settings) using Tailwind mobile-first breakpoints; verify rendered markup uses responsive classes and check pages at mobile and desktop widths.
- [x] 3.6 Remove the default Phoenix header from admin pages by introducing `Layouts.admin` (portal brand + admin nav) instead of `Layouts.app`; flash messages dismiss manually via `data-flash-close` and automatically after ~3s via `data-flash-autohide` + an `app.js` listener/`MutationObserver`, working without a LiveView connection.

## 4. Test coverage and verification

- [x] 4.1 Add `log_in_admin/2` ConnCase helper (create session token, `init_test_session(%{admin_token: token})`) and verify authenticated conn tests use it.
- [x] 4.2 Add `AdminAuth` plug tests covering redirect-on-unauthenticated, redirect-if-authenticated, and `current_scope` assignment; verify `mix test test/video_conference_web/admin_portal` passes.
- [x] 4.3 Run `dotenv -e .env.test mix test` and `mix precommit`; verify everything passes and fix any warnings/issues.
