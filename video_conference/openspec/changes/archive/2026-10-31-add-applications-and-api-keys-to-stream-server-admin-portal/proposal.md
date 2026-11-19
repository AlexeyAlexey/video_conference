# Proposal

## Why

The stream server admin portal will expose a REST API (a later change)
that third-party applications call to register public keys for stream
servers. Callers must authenticate with API keys issued per application.
Today the portal has no concept of external applications or credentials,
so there is nothing to authenticate that API against.

## What Changes

- Add an `applications` table and `api_keys` table to the stream server
  admin portal's dedicated database (portal repo, UUID primary keys),
  with `api_keys` belonging to applications and API key secrets stored
  only as bcrypt hashes.
- Add an `Applications` context under
  `VideoConference.StreamServerAdminPortal` with CRUD functions for
  applications and API keys, uniqueness enforcement, and API key
  generation (random secret returned once at creation, never stored in
  plaintext).
- Add portal LiveViews: an applications page (list, create, edit,
  enable/disable, delete) and an API keys page grouped by application
  (list, create, edit, enable/disable, delete; the generated key shown
  once after creation).
- Add an "Applications" item to the portal sidebar with an "API keys"
  sub-item, keeping the layout responsive.
- Seed a default application and default API key from the
  `DEFAULT_STREAM_SERVER_APP_ID` and `DEFAULT_STREAM_SERVER_API_KEY`
  environment variables through a portal-repo migration, so credentials
  exist on a fresh deployment.
- Add automated tests and validate the UI in the integrated browser.

Out of scope (future changes): the REST API that consumes these API keys
to add public keys for stream servers, and any key-rotation/regeneration
policy beyond delete-and-recreate.

## Capabilities

### New Capabilities

- `stream-server-applications`: Management of third-party applications
  and their API keys in the stream server admin portal — CRUD for both
  entities, API keys grouped by application, bcrypt-hashed key secrets
  shown only once at creation, enable/disable flags, and deployment-time
  seeding of a default application and default API key from environment
  variables.

### Modified Capabilities

- `stream-server-admin-portal`: The portal navigation requirement gains
  an "Applications" sidebar item with an "API keys" sub-item.

## Impact

- **New code**: `lib/video_conference/stream_server_admin_portal/applications/`
  (Application and ApiKey schemas) and `applications.ex` context;
  `lib/video_conference_web/stream_server_admin_portal/live/applications_live.ex`
  and `api_keys_live.ex`.
- **Modified code**: portal router (`live` routes plus
  `/stream-server-admin`-prefixed mirror routes), `admin_components.ex`
  sidebar, `dashboard_live.ex` navigation cards.
- **Database**: new migrations under
  `priv/stream_server_admin_portal_repo/migrations/` (create tables,
  seed defaults); main database untouched.
- **Config**: `DEFAULT_STREAM_SERVER_APP_ID` and
  `DEFAULT_STREAM_SERVER_API_KEY` added to `.env.example` /
  `.env.test.example` (and local env files); read at migration time.
- **Dependencies**: none new — `bcrypt_elixir` is already a dependency.
- **Tests**: fixtures for applications/API keys, context tests, LiveView
  tests, and portal sandbox coverage via the existing portal repo setup.
