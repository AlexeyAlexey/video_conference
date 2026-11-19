# Tasks

## 1. Context query

- [x] 1.1 Add `Applications.list_stream_server_public_keys(application_id)` (flat, ordered by name, mirroring `list_api_keys/1`) and remove `list_applications_with_stream_server_public_keys/1`; replace its describe block in `applications_test.exs` with flat-list tests (only that application's keys, name ordering, empty list for unknown id); verify via `dotenv -e .env.test mix test test/lib/video_conference/stream_server_admin_portal/applications_test.exs`

## 2. LiveView rewrite

- [x] 2.1 Rewrite `StreamServerPublicKeysLive` on the `ApiKeysLive` pattern: `handle_params/3` resolves `params["application_id"]` via `Enum.find(Applications.list_applications(), ...)` into `@application`, assigns `@filter_form` and `@public_keys` (`[]` when no application); drop `apply_action/2`, `live_action`, `filter_query/1`, `@filter_applications`, and the `{:application_picked, _}` handler; verify `mix compile` succeeds
- [x] 2.2 Rework the template: required `DropdownComponent` (`label="Application"`, `placeholder="Choose an application"`, `searchable`, `options={&application_options/1}`, no `empty_label`); `#select-application-prompt` when `@application == nil`; single `#public-keys-table` keeping the Key Id + copy, Public key show-control, description truncate/edit, enabled checkbox, and row actions menu (Change app / Remove); Add button `:if={@application}` opening an `:add` modal that shows the application name as text (`#add-key-application`) and injects `application_id` on save; verify the rendered page matches `ApiKeysLive` markup conventions (ids `application-filter-form`, `public-keys-section`, `no-public-keys`, modal ids `add-key-modal`, `rename-key-modal`, `edit-description-modal`, `show-key-modal`, `change-app-modal`)
- [x] 2.3 Remove the `/applications/stream-server-public-keys/new` live routes from `VideoConferenceWeb.StreamServerAdminPortal.Router` (both the stripped-path route and the `/stream-server-admin` mirror); verify `mix phx.routes` no longer lists them
- [x] 2.4 Make the change-app modal dropdown search-backed via `options={&application_options/1}` like the filter, dropping `@filter_applications` entirely; verify the change-app flow still moves a key (key disappears from the current list)

## 3. LiveView tests

- [x] 3.1 Rewrite `stream_server_public_keys_live_test.exs` mirroring `api_keys_live_test.exs`: prompt shown without selection, flat list for a selected application, filter patches the URL with `application_id`, add-modal flow (no app picker, key lands under the selected application), rename/description/enabled/show-key/copy-id, change-app removes the key from the list, remove deletes; verify via `dotenv -e .env.test mix test test/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live_test.exs`

## 4. Final verification

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix any warnings/test failures
