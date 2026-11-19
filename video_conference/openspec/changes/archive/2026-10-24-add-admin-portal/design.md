# Design

## Context

The app is a Phoenix 1.8 API server with a single SQLite3 repo (`VideoConference.Repo`, migrations in `priv/repo/migrations`) and phone-based auth (`VideoConference.Accounts` + `Accounts.Scope` + `AccountAuth` plugs). `phoenix_live_view ~> 1.2` and `bcrypt_elixir ~> 3.3` are already dependencies. The router is a single file with a `:browser` pipeline used only for `/`. There is no admin UI or admin data model today. The existing `Phone`/`Token` schema pair and `Accounts` context already implement the `phx.gen.auth` session-token pattern this design mirrors.

## Goals / Non-Goals

**Goals:**
- A self-contained `VideoConference.AdminPortal` context with its own schemas, scope, and dedicated admin tables in the shared SQLite database — logically isolated from phone auth.
- Session-cookie-based admin sign-in (controller POST), LiveView-rendered admin pages mounted under `/admin`.
- A separate router module that owns all admin pipelines and routes.
- A settings page where the admin can change their password, expiring other sessions.

**Non-Goals:**
- Managing multiple admin accounts (no admin CRUD UI; the schema supports it, but only the seeded default admin exists).
- Any actual app-level settings beyond the admin password — the dashboard is a scaffold for future settings.
- API/token-based admin auth, roles/permissions, password reset flows, email delivery.
- Changes to existing phone-auth routes, channels, or the public API.

## Decisions

### Shared repo, dedicated admin tables

`VideoConference.AdminPortal` uses the existing `VideoConference.Repo` and shared SQLite database. Admin data lives in dedicated tables (`admins`, `admin_tokens`) created by migrations in `priv/repo/migrations`, so `mix ecto.create`/`ecto.migrate`/test sandbox all work unchanged — no new repo, config, supervision child, or env var. The `AdminPortal` context and `admin_`-prefixed table names keep the boundary explicit.

*Alternative considered:* dedicated `VideoConference.AdminPortal.Repo` with its own SQLite file and `priv/admin_portal/migrations`. Rejected — revised requirement is a shared database, and a second repo would add config, supervision, and migration plumbing for no benefit here.

### Data model mirrors Phone/Token

- `admins`: `email` (string, unique), `hashed_password`, virtual `password` (redacted), timestamps. Changesets follow `Accounts.Phone`: `registration_changeset`-style validation and `password_changeset` hashing via `Bcrypt.hash_pwd_salt`, plus `valid_password?/2` with `Bcrypt.no_user_verify/0` for unknown emails.
- `admin_tokens`: `token` (binary 32), `context` ("session"), `admin_id` FK, `authenticated_at`; `build_session_token/1` and `verify_session_token_query/1` copied from `Accounts.Token` semantics (14-day validity).
- `VideoConference.AdminPortal.Accounts` exposes `get_admin_by_email_and_password/2`, `generate_session_token/1`, `get_admin_by_session_token/1`, `delete_session_token/1`, `change_admin_password/2`, `update_admin_password/2` (updates password in a transaction and deletes all tokens, returning the expired tokens like `Accounts.update_phone_password/2`).
- `VideoConference.AdminPortal.Accounts.Scope` — `%Scope{admin: nil}` with `for/1`, mirroring `Accounts.Scope`.

### Router split via `forward`

`VideoConferenceWeb.Router` keeps all current routes and adds `forward "/admin", VideoConferenceWeb.AdminPortal.Router`. The forwarded path is stripped, so the admin router defines routes relative to `/`. This is the cleanest "two files" split: one router module per file, no macro gymnastics.

*Alternative considered:* keeping one router and moving admin scopes to a helper module's macros — messier and doesn't match the requested file split.

*Implementation amendment:* LiveView officially does not work with `forward` — the LV channel verifies the public connect URL (`/admin/...`) resolves to the same LiveView + `live_session` via `Phoenix.Router.route_info/4` on the router that served the page, and a forwarded router only knows the stripped paths. The admin router therefore also declares `/admin`-prefixed mirror `live` routes (inside the same `live_session :admin`/default scopes) purely for URL→route resolution; they are unreachable at dispatch time. Controller routes (`post`/`delete`) are unaffected and dispatch normally through the forward.

`VideoConferenceWeb.AdminPortal.Router` (`use VideoConferenceWeb, :router`) defines its own `:browser` pipeline — same plugs as the main browser pipeline minus the app-specific assigns (`put_user_token`, http3 assigns), plus `fetch_current_scope_for_admin` so `current_scope` is always assigned. Routes:

```elixir
# Unauthenticated
scope "/", VideoConferenceWeb.AdminPortal do
  pipe_through [:browser, :redirect_if_admin_is_authenticated]
  get "/log-in", SessionController, :new
  post "/log-in", SessionController, :create
end

# Authenticated
scope "/", VideoConferenceWeb.AdminPortal do
  pipe_through [:browser, :require_authenticated_admin]
  delete "/log-out", SessionController, :delete
  post "/update-password", SessionController, :update_password

  live_session :admin, on_mount: [{VideoConferenceWeb.AdminPortal.AdminAuth, :mount_current_scope},
                                  {VideoConferenceWeb.AdminPortal.AdminAuth, :ensure_authenticated}] do
    live "/", DashboardLive, :index
    live "/settings", SettingsLive, :edit
    # "/admin"-prefixed mirror live routes for route_info resolution — see the
    # implementation amendment on the router-split decision above.
  end
end
```

### Controller-rendered sign-in

`AdminPortal.SessionController` owns both the sign-in page and session state: `new` renders the log-in form via `SessionHTML` (plain controller HTML, no LiveView), `create` verifies credentials via `Accounts.get_admin_by_email_and_password/2`, generates a session token, calls `AdminAuth.log_in_admin/3` (`renew_session` to prevent fixation + `put_session(:admin_token, token)`), then redirects to `/admin`. `delete` calls `AdminAuth.log_out_admin/1` (deletes the DB token, clears session, redirects to `/admin/log-in`). `update_password` applies `Accounts.update_admin_password/2` (which already expires all admin tokens) and then calls `AdminAuth.log_out_admin/1`, so the admin is signed out and redirected to `/admin/log-in` to sign in again with the new password — no session survives a password rotation.

On bad credentials `create` puts a flash and redirects back to `/admin/log-in`. The log-out link in the admin navigation bar is a plain `<form method="post">` with hidden `_method=delete` handled by `Plug.MethodOverride`, so it requires no JavaScript (unlike `data-method` links, which need `phoenix_html`).

### `AdminAuth` plugs and `on_mount` hooks

`VideoConferenceWeb.AdminPortal.AdminAuth` provides:
- `fetch_current_scope_for_admin/2` — reads `:admin_token` from the session, loads the admin via `Accounts.get_admin_by_session_token/1`, assigns `current_scope` (`Scope.for(admin)` or nil-safe).
- `require_authenticated_admin/2` — redirect to `/admin/log-in` (with error flash) when `current_scope.admin` is nil.
- `redirect_if_admin_is_authenticated/2` — redirect to `/admin` when already signed in.
- `on_mount` callbacks `:mount_current_scope` (assigns `current_scope` from `session["admin_token"]`), `:ensure_authenticated` (redirects socket to log-in when nil), `:redirect_if_authenticated` (for the log-in LiveView).

### Password change

`SettingsLive` shows a password form (current password + new password + confirmation). On submit it validates the changeset LiveView-side and, when valid, sets `phx-trigger-action` so the form POSTs to `SessionController.update_password`. The controller runs `Accounts.update_admin_password/2` (which expires every admin token, including the current session's) and then signs the admin out via `AdminAuth.log_out_admin/1`, redirecting to `/admin/log-in` with a "please log in again" flash. Validation failures stay in the LiveView; a controller-side changeset error flashes and redirects back to `/admin/settings`.

### Layouts and tests

- Admin pages wrap content in a dedicated `<Layouts.admin flash={@flash} current_scope={@current_scope}>` component — an admin-specific layout without the default Phoenix marketing header, providing a portal navbar (brand, signed-in admin email, Settings link, Log out form) shown when `current_scope.admin` is present.
- Flash messages dismiss manually via `data-flash-close` and automatically after ~3 seconds: flash containers carry `data-flash-autohide`, and a small listener + `MutationObserver` in `app.js` arms a timer that clicks the close button (which also pushes `lv:clear-flash` on LiveView pages). Both work on controller-rendered pages that have no LiveView socket (`phx-click` alone only works once a socket connects). The LiveView connectivity alerts (`client-error`/`server-error`) opt out via `autohide={false}`.
- `group_socket.js` must stay import-safe (no DOM access at module load; it connects `/socket` same-origin) — an earlier version read `#settingsForm` inputs at load time, which threw on non-conference pages and killed the whole bundle, including LiveSocket and the flash listeners.
- Admin pages are built responsive-first with Tailwind utilities (mobile breakpoints on all layout containers/forms), per the responsive-UI requirement — no custom CSS or separate mobile views.
- `DataCase.setup_sandbox/1` already covers the shared repo; an `AdminPortalFixtures` module provides `admin_fixture/0` and a ConnCase helper `log_in_admin(conn, admin)` that creates a token and sets `conn |> init_test_session(%{admin_token: token})`.

## Risks / Trade-offs

- **Default credentials shipped** (`admin`/`admin`) → Mitigation: bcrypt-hashed at migration time; document that it must be changed immediately in production; the password-change feature exists for exactly this.
- **Shared DB means no physical isolation** of admin data → Mitigation: dedicated `admin_`-prefixed tables and a separate `AdminPortal` context keep the boundary clear; a split into a second repo remains possible later.
- **`~p` verified routes across `forward`** may not resolve admin routes in every case → Mitigation: fall back to literal `"/admin/..."` paths in redirects/templates if verification fails; decide during implementation.
- **Bcrypt inside the seed migration** makes the hash nondeterministic in the file → Acceptable: hash is computed at migration run; `on_conflict: :nothing` keeps re-runs safe.
- **Shared session cookie store** for phone API + admin → No conflict: admin token lives under `:admin_token`; the phone API uses `Authorization` headers, not the session.

## Migration Plan

1. `mix ecto.migrate` applies the new `priv/repo/migrations` (admin tables + default-admin seed) to the existing database.
2. Rollback: `mix ecto.rollback` reverts the admin migrations; reverting the forward restores the old router.

## Open Questions

- Which app settings beyond the admin password the portal should manage — deferred; the dashboard is intentionally a scaffold, and future settings become new capabilities.
