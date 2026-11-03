# Tasks

## 1. Data layer

- [x] 1.1 Rename `priv/stream_server_admin_portal_repo/migrations/20261103100000_create_public_stream_server_keys.exs` to `20261103100000_create_stream_server_public_keys.exs` (same version timestamp), rename the module to `CreateStreamServerPublicKeys`, rename the table to `stream_server_public_keys`, rename the `public_key` column to `key`, and replace the `disabled` column with `enabled` (default true); verify `dotenv -e .env.test mix test` recreates and migrates the test portal DB cleanly
- [x] 1.2 Rename `applications/public_stream_server_key.ex` → `applications/stream_server_public_key.ex` and the module to `Applications.StreamServerPublicKey` (`field :key` required, `belongs_to :application`, `assoc_constraint`), update `Application` to `has_many :stream_server_public_keys`; verify changeset tests still pass under the new names

## 2. Context and fixtures

- [x] 2.1 In `StreamServerAdminPortal.Applications` rename `list_applications_with_public_keys/1` → `list_applications_with_stream_server_public_keys/1` and `get/create/update/delete/change_public_stream_server_key*` → `*_stream_server_public_key*`; rename fixtures `public_stream_server_key_fixture` → `stream_server_public_key_fixture` and `unique_public_stream_server_key_name` → `unique_stream_server_public_key_name` (keep `valid_public_key_pem`); update context tests to the new names

## 3. Portal UI

- [x] 3.1 Rename the LiveView file/module to `StreamServerPublicKeysLive`, the assign to `stream_server_public_key`, the form param to `stream_server_public_key`, all `public-key-*`/`public-keys-*` DOM ids to `key-*`/`keys-*`, and user-facing text (title/header "Stream Server Public Keys", "Key Id" column, "Stream server public key added/updated/removed" flashes, page description wording); update the form checkbox and status column to the `enabled` field; update routes to `/applications/stream-server-public-keys*` plus `/stream-server-admin`-prefixed mirror routes and verify `mix phx.routes` + LiveView mounts
- [x] 3.2 Rename the sidebar sub-item to "Stream server public keys" (`sidebar-stream-server-public-keys-link`) pointing at `/stream-server-admin/applications/stream-server-public-keys`; update `admin_components.ex` moduledoc
- [x] 3.3 Rename the LiveView test file/module to `StreamServerPublicKeysLiveTest` and update all DOM ids, strings, routes, and form params; verify LiveView tests cover every spec scenario under the new names

## 4. Verification

- [x] 4.1 Recreate the dev portal DB (drop `public_stream_server_keys` and its `schema_migrations` row, or recreate the portal repo) and validate the renamed page in the integrated browser: sidebar "Stream server public keys", grouped list, filter, Add/Edit/Remove, copy "Key Id", description expand/wrap
- [x] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings, unused deps, formatting, or test failures
