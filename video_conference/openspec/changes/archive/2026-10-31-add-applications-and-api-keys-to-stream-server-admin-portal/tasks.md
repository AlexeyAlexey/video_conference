# Tasks

## 1. Database tables and default seeding

- [x] 1.1 Create a portal-repo migration `create_applications_and_api_keys` in `priv/stream_server_admin_portal_repo/migrations/` creating `applications` (`:binary_id` PK, unique `name`, `description`, `enabled`, `timestamps()`) and `api_keys` (`:binary_id` PK, `application_id` FK `type: :binary_id, on_delete: :delete_all`, `name`, `hashed_api_key`, `description`, `enabled`, `timestamps()`), plus unique indexes on `applications.name`, `(application_id, name)`, `(application_id, hashed_api_key)`; verify `dotenv -e .env.test mix ecto.migrate` creates the tables in the portal DB only
- [x] 1.2 Create a `seed_default_application_and_api_key` portal-repo migration that `insert_all`s "Default App" (id from `DEFAULT_STREAM_SERVER_APP_ID`, generated UUID fallback) and "Default API Key" (`Bcrypt.hash_pwd_salt(DEFAULT_STREAM_SERVER_API_KEY)`, generated secret fallback) with the required warning descriptions and `on_conflict: :nothing`; verify migrating an empty portal DB seeds both rows and re-running creates no duplicates or errors
- [x] 1.3 Add `DEFAULT_STREAM_SERVER_APP_ID` and `DEFAULT_STREAM_SERVER_API_KEY` to `.env.example` and `.env.test.example` (and local `.env`/`.env.test`); verify the seeded rows pick up the env-provided values in dev and test

## 2. Applications context and schemas

- [x] 2.1 Create `lib/video_conference/stream_server_admin_portal/applications/` with `Application` schema (`@primary_key {:id, :binary_id, autogenerate: true}`, `has_many :api_keys`, name/description/enabled changeset with `unsafe_validate_unique` + `unique_constraint` on name) and `ApiKey` schema (`@foreign_key_type :binary_id`, `belongs_to :application`, `hashed_api_key`/`plaintext_key` redacted fields, changeset casting name/description/enabled); verify `mix compile` succeeds
- [x] 2.2 Create `Applications` context (`lib/video_conference/stream_server_admin_portal/applications.ex`) pointed at the portal `Repo` with list/get/create/update/delete for applications (delete cascades keys) and list-by-application/get/create/update/delete for API keys; `create_api_key` generates `ssak_`-prefixed `Base.url_encode64` secret, stores `Bcrypt.hash_pwd_salt`, returns `{:ok, api_key}` with `plaintext_key` set; verify `mix compile` succeeds
- [x] 2.3 Add fixtures (`test/support/fixtures/stream_server_admin_portal_applications_fixtures.exs` or matching layout) for application and API key creation; verify a fixture API key verifies its known plaintext against `hashed_api_key` via `Bcrypt.verify_pass`
- [x] 2.4 Add context tests covering: app name uniqueness and required name, enabled flag, key name uniqueness per app (allowed across apps), cascade delete, hashed-only storage, and `plaintext_key` populated at creation; verify `dotenv -e .env.test mix test` passes

## 3. Applications page and sidebar navigation

- [x] 3.1 Add `live "/applications", ApplicationsLive, :index/:new/:edit` routes plus `/stream-server-admin`-prefixed mirror routes to the portal `live_session`; verify `mix phx.routes` shows them
- [x] 3.2 Create `ApplicationsLive` (`live/applications_live.ex`) following the `StreamServersLive` pattern: index lists all applications with name, enabled state, edit/delete actions; new/edit forms (name, description, enabled checkbox) validate and save via the context; verify the page mounts at `/stream-server-admin/applications` for authenticated admins and redirects unauthenticated visitors to log-in
- [x] 3.3 Add an "Applications" item with an "API keys" sub-item to `admin_components.ex` sidebar (linking to the two pages) and navigation cards on `DashboardLive` if the card grid pattern applies; verify sidebar renders both items on every portal page
- [x] 3.4 Add LiveView tests for the applications page: list rendering, create/edit/delete flows, duplicate-name and blank-name errors, enabled toggle, sidebar items present, unauthenticated redirect; verify `dotenv -e .env.test mix test` passes

## 4. API keys page

- [x] 4.1 Create `ApiKeysLive` (`live/api_keys_live.ex`) with `:index`/`:new`/`:edit` routes plus mirror routes; index renders API keys grouped under each application; verify the page mounts and renders groups for seeded and created data
- [x] 4.2 Implement the new/edit form (name, description, enabled) with `DropdownComponent` for selecting the parent application (`options={for a <- @applications, do: {a.name, a.id}}`, `on_change` → `handle_info` → `put_change(:application_id, id)` + clear stale error per the dropdown skill); verify picking an application sets `application_id` without a native `<select>`
- [x] 4.3 Implement one-time secret display: after create, assign `plaintext_key` and render a dismissible alert showing the secret on index; clear on dismiss/navigation; verify a test asserts the secret appears exactly once after create and not on later renders
- [x] 4.4 Add LiveView tests for the API keys page: grouped-by-application rendering, create flow emitting the one-time secret, edit without touching `hashed_api_key`, delete, duplicate-name-per-app error, application dropdown interaction via `#application-dropdown-button`/`phx-value-id`; verify `dotenv -e .env.test mix test` passes

## 5. Integration verification

- [x] 5.1 Start `dotenv -e .env mix phx.server` and validate in the integrated browser: sign in to `/stream-server-admin`, sidebar shows Applications → API keys, create/edit/disable/delete an application, create an API key (secret shown once, copyable, gone after dismiss), keys grouped per application, delete app cascades keys, responsive layout at mobile and desktop widths; verify each flow works end-to-end
- [x] 5.2 Run `dotenv -e .env.test mix precommit` and fix all warnings/test failures; verify it exits clean

## 6. Refinements

- [x] 6.1 Add a copy-to-clipboard button to the one-time API key secret alert on `ApiKeysLive` (`onclick` + `navigator.clipboard`, no JS hook); verify the button renders alongside the secret and dismiss control
- [x] 6.2 Truncate descriptions longer than 50 characters with an ellipsis in the applications and API keys lists, expanding to the full text on click (same `JS.toggle_class` pattern as `PublicStreamServerKeysLive`); verify the truncated and full spans render on both pages
- [x] 6.3 Add LiveView tests for the copy button markup and description truncation/expansion on both pages; verify `dotenv -e .env.test mix precommit` exits clean
