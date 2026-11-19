# Proposal

## Why

Stream-server administration must be isolated from the application: the
stream-server admin portal will own stream-server data (API keys,
registered application public keys, access rules) in its own database and
communicate with the rest of the app only through an API, like a separate
application. This change stands up the portal shell — dedicated database,
independent email/password authentication, own router, responsive layout —
so later changes can add the managed entities on that isolated foundation.

## What Changes

- Add a `VideoConference.StreamServerAdminPortal` context scope with its
  own Ecto repository backed by a separate SQLite database file
  (`STREAM_SERVER_ADMIN_DATABASE_PATH`).
- Add a `VideoConferenceWeb.StreamServerAdminPortal` web scope with its
  own router, reached through `forward "/stream-server-admin"` in the main
  router, including `/stream-server-admin`-prefixed mirror `live` routes
  for LiveView URL resolution (same workaround the admin router uses).
- Add email/password sign-in for portal admins backed by `admins` and
  `admins_tokens` tables in the portal database, under session key
  `:stream_server_admin_token`.
- Seed a default portal admin (`admin@admin.com` / `admin`) through a
  migration in the portal repository.
- Add dashboard and settings (change password) LiveViews plus a
  responsive layout with a collapsible left sidebar, copied from the
  admin portal.
- Extend repo/test setup (`mix` aliases, dev/test/runtime config,
  `.env.test*`, `DataCase`/`ConnCase` sandbox) so the portal database is
  created, migrated, and checked out alongside the main one.
- Add automated tests for the new scope and validate the portal manually
  in the integrated browser.

Out of scope (future changes): managed stream-server entities (API keys,
application public keys, access rules), the HTTP API between the two
portals, AdminPortal "push public key" flows, and deployment role gating.
Nothing is moved out of `AdminPortal` — `/admin` and its data are
untouched.

## Capabilities

### New Capabilities

- `stream-server-admin-portal`: An isolated administrative web portal for
  stream-server management at `/stream-server-admin`, with its own
  database and repository, independent email/password authentication, a
  migration-seeded default admin, sidebar navigation, dashboard, and
  settings (change password) pages — responsive across viewports.

### Modified Capabilities

## Impact

- **New code**: `lib/video_conference/stream_server_admin_portal/`
  (repo, accounts context, admin/token/scope schemas),
  `lib/video_conference_web/stream_server_admin_portal/` (router, auth
  plugs/on_mount, components, session controller + HTML, dashboard and
  settings LiveViews),
  `priv/stream_server_admin_portal_repo/migrations/`.
- **Modified code**: `lib/video_conference/application.ex` (second repo in
  the supervision tree), `lib/video_conference_web/router.ex` (`forward`),
  `mix.exs` (`ecto.*`/`test` aliases for both repos), `config/dev.exs`,
  `config/test.exs`, `config/runtime.exs` (second database path),
  `.env.example`, `.env.test.example`, `test/support/data_case.ex` and
  `conn_case.ex` (dual sandbox checkout).
- **New tests**: context, controller, and LiveView tests for the portal
  scope; portal admin fixtures.
- **No impact** on the existing admin portal, its tables, or its routes.
