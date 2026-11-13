# Tasks

## 1. Data layer

- [x] 1.1 Create a migration in `priv/stream_server_admin_portal_repo/migrations` that drops the `api_keys` unique indexes on `(application_id, name)` and `(application_id, hashed_api_key)`, renames `api_keys` to `application_api_keys`, adds `prefix :string, null: false, default: ""` and `lock_version :integer, default: 1, null: false`, backfills each row's `prefix` with `ApiKeySecret.prefix("aak", Ecto.UUID.generate())`, and creates unique indexes on `prefix` and `(application_id, hashed_api_key)`; verify `dotenv -e .env mix ecto.migrate` migrates the portal repo cleanly and seeded rows gain unique `aak_` prefixes
- [x] 1.2 Update `Applications.ApiKey` (`lib/video_conference/stream_server_admin_portal/applications/api_key.ex`): `schema "application_api_keys"`, add `prefix` and `lock_version` fields, remove name `unsafe_validate_unique`/`unique_constraint`, keep the `(application_id, hashed_api_key)` unique constraint, add `unique_constraint(:prefix)`, and add `name_changeset/2`, `description_changeset/2`, `enabled_changeset/2` each applying `optimistic_lock(:lock_version)`; verify schema tests cover required fields, duplicate names allowed, and the hashed-secret and prefix unique constraints

## 2. Context API

- [x] 2.1 Rework `Applications` API key functions to mirror `StreamServers`: `list_api_keys(application_id)`, `create_api_key/1` storing `ApiKeySecret.prefix("aak", prefix_id)` in `prefix` alongside the hash, `rename_api_key/2`, `edit_api_key_description/2`, `enable_api_key/1`, `disable_api_key/1` accepting key or id via `fetch_api_key/1` and using `stale_error_field: :lock_version`; remove `update_api_key/2`, `delete_api_key/1`, and `list_applications_with_api_keys/0`; verify context tests cover one-time plaintext, persisted `prefix`, hashed-only persistence, per-field updates bumping `lock_version`, and stale-write failure
- [x] 2.2 Add a `:search` option to `Applications.list_applications/0` (case-insensitive `like` on name) mirroring `list_stream_servers(search:)`; verify a context test narrows the list by search text

## 3. Portal page

- [x] 3.1 Remove routes `/api-keys/new` and `/api-keys/:id/edit` and their `/stream-server-admin`-prefixed mirrors in the portal router; verify a LiveView test mounts `/stream-server-admin/api-keys` without the unauthorized-mount reload loop
- [x] 3.2 Rework `ApiKeysLive` to the `StreamServerApiKeysLive` structure: required searchable `DropdownComponent` application filter with `{application.name, application.id}` options and no empty/"all" option, `push_patch` to `?application_id=`, select-an-application prompt with no table and no add action when unpicked; verify LiveView tests cover the prompt state, filtering, search narrowing, and the URL param
- [x] 3.3 Add the event-driven add modal (private `modal/1` component) with read-only application name and name/description/enabled fields, `application_id` injected from the filter on save, and the one-time secret banner with copy + dismiss; verify tests cover creation for the filtered application, inline validation errors, and the secret being shown exactly once
- [x] 3.4 Wire the key table: API KEY column showing `prefix` with a copy button, pencil → rename modal, description truncate/expand + pencil → description modal, enabled checkbox toggling via enable/disable — no Remove action and no whole-row edit — with stale `lock_version` failures surfacing as changeset/flash errors; verify LiveView tests cover the prefix column, each per-field edit, the toggle, and the stale-record error path

## 4. Verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and verify compile, format, and the full test suite pass with no warnings
