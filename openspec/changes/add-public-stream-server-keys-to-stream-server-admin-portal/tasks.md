# Tasks

## 1. Data layer

- [ ] 1.1 Create portal-repo migration `create_public_stream_server_keys` under `priv/stream_server_admin_portal_repo/migrations/` (binary_id PK, `name` nullable string, `public_key` text not null, `application_id` binary_id FK `on_delete: :delete_all` referencing `applications`, `disabled` default false not null, `description` text, timestamps; no `public_key_id`, `private_key`, or `stream_server_id` columns; no unique index on `name`) and verify the migration runs cleanly on the test portal DB via `dotenv -e .env.test mix test`
- [ ] 1.2 Create `StreamServerAdminPortal.Applications.PublicStreamServerKey` schema (binary_id PK/FK type, required `public_key`/`application_id`, optional `name`, `belongs_to :application`, `assoc_constraint`) and add `has_many :public_stream_server_keys` to the `Application` schema; verify changeset tests cover required fields, optional name, and non-unique names

## 2. Context

- [ ] 2.1 Add to `StreamServerAdminPortal.Applications`: `list_applications_with_public_keys/1` (optional `application_id` filter, keys preloaded ordered by name), `get_public_stream_server_key!/1`, `create_public_stream_server_key/1`, `update_public_stream_server_key/2`, `delete_public_stream_server_key/1`, `change_public_stream_server_key/2`, plus portal `PublicStreamServerKeysFixtures`; verify context tests cover CRUD, UUID serving as public key id, the application filter, and cascade delete when an application is removed

## 3. Portal UI

- [ ] 3.1 Add routes `/applications/public-stream-server-keys`, `/applications/public-stream-server-keys/new`, `/applications/public-stream-server-keys/:id/edit` plus `/stream-server-admin`-prefixed mirror routes in `StreamServerAdminPortal.Router`; verify `mix phx.routes` lists them and LiveView mounts resolve
- [ ] 3.2 Add `StreamServerAdminPortal.PublicStreamServerKeysLive` (`:index`, `:new`, `:edit` actions) under `Layouts.stream_server_admin`: grouped-by-application list with page description, "Public key Id" column rendering `key.id`, "No public keys yet" per application, "No applications found" empty state, Add/Edit forms with application `DropdownComponent` (UUID `application_id`, no `String.to_integer`) and a public key textarea — no private key field, no generate flow — delete with confirm, responsive `overflow-x-auto` tables; verify LiveView tests cover each spec scenario
- [ ] 3.3 Add the searchable application `DropdownComponent` filter replicating the stream servers page (wrapped in a `<.form>` with `onsubmit` prevented, `?application_id=` param handled in `handle_params`); verify LiveView tests cover filtering to one application, clearing to all, and searching options
- [ ] 3.4 Add a Description column behavior to the list tables: long descriptions render as a truncated `...` preview inside a clickable button that expands/collapses the full text (client-side `JS.toggle_class`, no server event); verify LiveView tests cover truncation and the expandable control
- [ ] 3.5 Add a "Public keys" sub-item under "Applications" in the portal sidebar (`admin_components.ex`, inside the existing nested `<ul>` with "API keys") linking to `/stream-server-admin/applications/public-stream-server-keys`; verify a LiveView/layout test asserts the sub-item and unauthenticated redirect to the portal sign-in page

## 4. Verification

- [ ] 4.1 Validate the page in the integrated browser: sidebar sub-item under Applications, grouped-by-application list with UUID public key ids, application filter (select, clear, search), Add/Edit/Remove flows, dropdown, and responsive layout at mobile and desktop widths
- [ ] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings, unused deps, formatting, or test failures
