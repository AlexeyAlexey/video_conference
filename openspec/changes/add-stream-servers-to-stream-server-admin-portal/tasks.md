# Tasks

## 1. Shared Countries module

- [x] 1.1 Move `Countries` from `VideoConference.AdminPortal.StreamServers` to `VideoConference.StreamServers.Countries`, update aliases in `StreamServer` schema and `StreamServersLive`, and verify `dotenv -e .env.test mix test` passes for the existing stream servers tests

## 2. Data layer

- [x] 2.1 Create portal-repo migration adding `stream_servers` (binary_id PK, name not null, description, host, country, settings map, cert_hash, unique index on name) and `application_stream_servers` (binary_id FKs `on_delete: :delete_all`, unique composite index); verify `dotenv -e .env.test mix test` runs the migration cleanly on the test portal DB
- [x] 2.2 Add `StreamServers.StreamServer` schema (`binary_id` PK, `cert_hash` column, `many_to_many :applications` through the join table, changeset with required name, unique name, country inclusion via `Countries`) and the join schema; verify schemas compile and changeset validations behave in `iex`/unit test
- [x] 2.3 Add `VideoConference.StreamServerAdminPortal.StreamServers` context: `list_stream_servers/1` (optional `application_id` filter including `"unassigned"`, applications preloaded), `get_stream_server!/1`, `create/update/delete/change_stream_server`, `assign_applications/2` (replace-set semantics); verify with context tests covering CRUD, unique name, filtering by application, unassigned filter, assign/unassign, and cascade on application/server delete

## 3. Portal UI

- [x] 3.1 Add routes in the portal router for `:index`, `:new`, `:edit`, `:assign` plus `/stream-server-admin`-prefixed mirror routes; verify `mix phx.routes` lists them and LiveView mounts resolve
- [x] 3.2 Implement `StreamServersLive` index: filter `DropdownComponent` (All / Unassigned / each application) patching `?application_id=`, responsive table with name, host, flag, cert-hash indicator, assigned application chips, Edit/Assign/Remove actions; verify with LiveView tests for list render, filter behavior, and delete
- [x] 3.3 Implement new/edit form reusing the portal CRUD pattern (name, description, host, country `DropdownComponent` with flags, cert_hash); verify with LiveView tests for create, update, and inline validation errors
- [x] 3.4 Implement the `:assign` view listing all applications as checkboxes with save/cancel patching back to index; verify with LiveView tests for assign, unassign, and multi-application assignment
- [x] 3.5 Add the "Stream servers" item to the portal sidebar in `admin_components.ex`; verify with a LiveView/layout test asserting the item links to `/stream-server-admin/stream-servers`

## 4. Verification

- [x] 4.1 Validate the page in the integrated browser: sidebar item, list, filter options, add/edit/remove, per-row assign flow, and responsive layout at mobile and desktop widths
- [x] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings, unused deps, formatting, or test failures

## 5. Follow-up changes

- [x] 5.1 Keep `third_party` on the main-repo `stream_servers` table — an earlier revision dropped it; the drop migration is rolled back and deleted, and the schema field, `/admin/stream-servers` checkbox/column, and tests are restored unchanged
- [x] 5.2 Add a copy-to-clipboard icon button next to the cert-hash indicator in the portal stream servers list (copies `cert_hash` on click), plus a LiveView test asserting the control
- [x] 5.3 Make the index application filter `DropdownComponent` `searchable` (filter input inside the listbox), plus a LiveView test covering the search
- [x] 5.4 Fix the filter search field not working in the browser: wrap the filter `DropdownComponent` in a `<.form>` (`onsubmit` prevented) — LiveView serializes `phx-change` via the enclosing form and a formless input throws client-side before the event is pushed
