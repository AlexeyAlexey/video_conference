# Tasks

## 1. Shared Countries module

- [ ] 1.1 Move `Countries` from `VideoConference.AdminPortal.StreamServers` to `VideoConference.StreamServers.Countries`, update aliases in `StreamServer` schema and `StreamServersLive`, and verify `dotenv -e .env.test mix test` passes for the existing stream servers tests

## 2. Data layer

- [ ] 2.1 Create portal-repo migration adding `stream_servers` (binary_id PK, name not null, description, host, country, settings map, cert_hash, unique index on name) and `application_stream_servers` (binary_id FKs `on_delete: :delete_all`, unique composite index); verify `dotenv -e .env.test mix test` runs the migration cleanly on the test portal DB
- [ ] 2.2 Add `StreamServers.StreamServer` schema (`binary_id` PK, `cert_hash` column, `many_to_many :applications` through the join table, changeset with required name, unique name, country inclusion via `Countries`) and the join schema; verify schemas compile and changeset validations behave in `iex`/unit test
- [ ] 2.3 Add `VideoConference.StreamServerAdminPortal.StreamServers` context: `list_stream_servers/1` (optional `application_id` filter including `"unassigned"`, applications preloaded), `get_stream_server!/1`, `create/update/delete/change_stream_server`, `assign_applications/2` (replace-set semantics); verify with context tests covering CRUD, unique name, filtering by application, unassigned filter, assign/unassign, and cascade on application/server delete

## 3. Portal UI

- [ ] 3.1 Add routes in the portal router for `:index`, `:new`, `:edit`, `:assign` plus `/stream-server-admin`-prefixed mirror routes; verify `mix phx.routes` lists them and LiveView mounts resolve
- [ ] 3.2 Implement `StreamServersLive` index: filter `DropdownComponent` (All / Unassigned / each application) patching `?application_id=`, responsive table with name, host, flag, cert-hash indicator, assigned application chips, Edit/Assign/Remove actions; verify with LiveView tests for list render, filter behavior, and delete
- [ ] 3.3 Implement new/edit form reusing the portal CRUD pattern (name, description, host, country `DropdownComponent` with flags, cert_hash); verify with LiveView tests for create, update, and inline validation errors
- [ ] 3.4 Implement the `:assign` view listing all applications as checkboxes with save/cancel patching back to index; verify with LiveView tests for assign, unassign, and multi-application assignment
- [ ] 3.5 Add the "Stream servers" item to the portal sidebar in `admin_components.ex`; verify with a LiveView/layout test asserting the item links to `/stream-server-admin/stream-servers`

## 4. Verification

- [ ] 4.1 Validate the page in the integrated browser: sidebar item, list, filter options, add/edit/remove, per-row assign flow, and responsive layout at mobile and desktop widths
- [ ] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings, unused deps, formatting, or test failures
