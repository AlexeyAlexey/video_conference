# Proposal

## Why

The application currently has no administrative interface - there is no way for an operator to sign in and manage app settings. We need a dedicated AdminPortal, isolated from the phone-based user auth, with its own context and tables in the shared database.

## What Changes

- Add a new `AdminPortal` bounded context under `lib/video_conference/admin_portal/` using the existing `VideoConference.Repo`; admin tables and migrations live alongside the app's (in `priv/repo/migrations`).
- Add `admins` and `admin_tokens` tables (email + hashed password; session tokens) and seed a default admin (`admin@admin.com` / `admin`) via migration.
- Add `VideoConference.AdminPortal.Accounts` context and `VideoConference.AdminPortal.Accounts.Scope` mirroring the existing `VideoConference.Accounts.Scope` pattern, scoped to an `admin` instead of a `phone`.
- Add email + password sign-in rendered and processed by a controller (`AdminPortal.SessionController` + `SessionHTML` template) that stores the admin session token in the HTTP session cookie.
- Add LiveView-based admin pages under `lib/video_conference_web/admin_portal/`: a dashboard (portal home) and a settings page where the admin can change their password, both wrapped in a dedicated `Layouts.admin` layout with an admin navigation bar (settings link + form-based log out).
- Add `VideoConferenceWeb.AdminPortal.AdminAuth` plugs (`fetch_current_scope_for_admin`, `require_authenticated_admin`, `redirect_if_admin_is_authenticated`) and a LiveView `on_mount` hook to load `current_scope` for admin LiveViews.
- Split the Phoenix router into two files: `VideoConferenceWeb.Router` keeps existing routes and forwards `/admin` to a new `VideoConferenceWeb.AdminPortal.Router` module that owns admin pipelines, sign-in/log-out controller routes, and an authenticated `live_session`.
- Add tests for the admin context, auth plugs, session controller, and LiveViews.

## Capabilities

### New Capabilities

- `admin-portal`: Admin authentication (email/password sign-in and session management), the LiveView admin portal itself (dashboard, password change), and the admin data model in the shared database.

### Modified Capabilities

- (none)

## Impact

- **New code**: `lib/video_conference/admin_portal/` context (Accounts, Admin + Token schemas, Scope), `lib/video_conference_web/admin_portal/` (router, auth plugs, session controller, LiveViews), new migrations in `priv/repo/migrations/`.
- **Modified code**: `lib/video_conference_web/router.ex` (forward `/admin`), `test/support/` helpers (fixtures, ConnCase `log_in_admin`).
- **Dependencies**: none new - `phoenix_live_view`, `bcrypt_elixir`, and `ecto_sqlite3` are already deps.
- **No changes** to the existing phone-auth API routes or channels.
