# Tasks

## 1. Data layer

- [x] 1.1 Create a migration in `priv/stream_server_admin_portal_repo/migrations` adding `stream_server_api_keys` (binary_id PK, `stream_server_id` FK `on_delete: :delete_all` NOT NULL, `name` NOT NULL, `hashed_api_key` NOT NULL, `description`, `enabled` default true NOT NULL, `lock_version` default 1, timestamps) with a unique index on `(stream_server_id, hashed_api_key)`; verify `dotenv -e .env mix ecto.migrate` migrates the portal repo cleanly
- [x] 1.2 Add `StreamServers.ApiKey` schema (`lib/video_conference/stream_server_admin_portal/stream_servers/api_key.ex`) with `changeset/2` for create and `name_changeset/2`, `description_changeset/2`, `enabled_changeset/2` each applying `optimistic_lock(:lock_version)`; no uniqueness validation on name; verify schema tests cover required fields, non-unique names, and the hashed-secret unique constraint

## 2. Shared secret module and context API

- [x] 2.1 Add `VideoConference.StreamServerAdminPortal.ApiKeySecret` (`lib/video_conference/stream_server_admin_portal/api_key_secret.ex`) with `generate/0` (`"ssak_" <> Base.url_encode64(32 random bytes)`) and `hash/1` (`Bcrypt.hash_pwd_salt`); refactor `Applications.create_api_key/1` to use it and turn `Applications.generate_api_key_secret/0` into a delegate; verify all existing API key tests still pass
- [x] 2.2 Extend `StreamServers` with `list_stream_server_api_keys/1`, `get_stream_server_api_key!/1`, `create_stream_server_api_key/1` (returns `plaintext_key` once, persists only the hash), `rename_stream_server_api_key/2`, `edit_stream_server_api_key_description/2`, `enable_/disable_stream_server_api_key/1`, and `change_stream_server_api_key/2`, all updates passing `stale_error_field: :lock_version`; verify context tests cover one-time plaintext, hashed-only persistence, per-field updates bumping `lock_version`, and stale-write failure

## 3. Portal page

- [x] 3.1 Add routes `live "/stream-servers/api-keys", StreamServerApiKeysLive, :index` and the `/stream-server-admin`-prefixed mirror route in the portal router; verify a LiveView test mounts the page at the public path without the unauthorized-mount reload loop
- [x] 3.2 Add an "API keys" sub-item under "Stream servers" in `admin_components.ex`; verify a LiveView test sees the sidebar link navigating to the new page
- [x] 3.3 Build `StreamServerApiKeysLive` index: searchable `DropdownComponent` filter with `"name (host)"` options and no empty/"all" option, `push_patch` to `?stream_server_id=`, select-a-server prompt with no table and no add action when unpicked; verify LiveView tests cover the prompt state, filtering, search narrowing, and the URL param
- [x] 3.4 Add the event-driven add modal (private `modal/1` component) with read-only "name (host)" server display and name/description/enabled fields, `stream_server_id` injected from the filter on save, and the one-time secret banner with copy + dismiss; verify tests cover creation for the filtered server, inline validation errors, and the secret being shown exactly once
- [x] 3.5 Wire per-field row editing — pencil → rename modal, pencil → description modal, enabled checkbox toggling via enable/disable — with stale `lock_version` failures surfacing as changeset/flash errors; verify LiveView tests cover each per-field edit, the toggle, and the stale-record error path

## 4. Verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and verify compile, format, and the full test suite pass with no warnings

## 5. Follow-up changes

- [x] 5.1 Add a `prefix` column (`:string`, `null: false`, unique index) to `stream_server_api_keys`; it stores `env_prefix <> "_" <> prefix_id` and is used to find an API key
- [x] 5.2 Change `ApiKeySecret.generate` to `generate/2` taking `env_prefix` and `prefix_id`, producing `env_prefix <> "_" <> prefix_id <> "_" <> <32 random bytes>`: `"ssak"` + an independently generated id for stream server API keys, `"aak"` + an independently generated id for application API keys; update callers, docs, and tests
- [x] 5.3 Add an "API KEY" column showing `stream_server_api_key.prefix` with a copy button to the stream server API keys table
