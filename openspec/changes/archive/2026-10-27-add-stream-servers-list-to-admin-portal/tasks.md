# Tasks

## 1. Data layer

- [x] 1.1 Create migration `create_stream_servers`: `name` (string, null false), `description` (text), `host` (string), `country` (string, nullable), `settings` (map), `third_party`/`is_default` (booleans, default false, null false), timestamps; unique index on `name`, partial unique index on `is_default` (`where: "is_default"`). Verify `dotenv -e .env.test mix ecto.migrate` completes without error.
- [x] 1.2 Create schema `VideoConference.AdminPortal.StreamServers.StreamServer` (`lib/video_conference/admin_portal/stream_servers/stream_server.ex`) with `country` validated against a fixed supported ISO alpha-2 code list (code → `{name, flag}` mapping kept in the context or a small helper module), virtual `cert_hash` folded into `settings["cert_hash"]` by the changeset (blank clears the key, other keys preserved; populated from `settings` for edit forms), required `name`, `unsafe_validate_unique` + `unique_constraint(:name)`. Verify via context tests below.
- [x] 1.3 Create context `VideoConference.AdminPortal.StreamServers` (`lib/video_conference/admin_portal/stream_servers.ex`): `list_stream_servers/0` (default first, then name), `get_stream_server!/1`, `create_stream_server/1`, `update_stream_server/2`, `delete_stream_server/1`, `change_stream_server/2`. Create/update wrap the write in `Repo.transaction` and clear `is_default` on other rows when the saved row is default. Verify via the context test.
- [x] 1.4 Add `test/support/fixtures/stream_servers_fixtures.exs` (unique name generator, valid attrs incl. `"cert_hash"`, `stream_server_fixture/1`) and `test/lib/video_conference/admin_portal/stream_servers_test.exs` covering: CRUD, duplicate-name rejection, cert_hash set/cleared in `settings`, country persisted/cleared/invalid-code rejected, second default transfers the flag, deleting the default row succeeds. Verify `dotenv -e .env.test mix test test/lib/video_conference/admin_portal/stream_servers_test.exs` passes.

## 2. Admin UI

- [x] 2.1 Add routes in `VideoConferenceWeb.AdminPortal.Router` inside the `:admin` live_session — `live "/stream-servers"` (`:index`), `live "/stream-servers/new"` (`:new`), `live "/stream-servers/:id/edit"` (`:edit`) — each with its `/admin`-prefixed mirror route. Verify `mix phx.routes` lists them.
- [x] 2.2 Create `lib/video_conference_web/admin_portal/live/stream_servers_live.ex` mirroring `KnownHostsLive`: table (name + "Default" badge, host, country flag, third-party, actions), `handle_params`-driven add/edit form with name/description/host/country (flag select with an empty "None" option)/cert-hash/third-party/default fields, `phx-click` delete with `data-confirm`. Verify via the LiveView test below.
- [x] 2.3 Add the "Stream servers" sidebar item in `AdminComponents.admin_sidebar` (navigate `/admin/stream-servers`, `hero-signal` icon, after "Known hosts"). Verify it renders in the LiveView test assertion and the browser check.
- [x] 2.4 Add `test/video_conference_web/admin_portal/live/stream_servers_live_test.exs` covering: unauthenticated redirect, list rendering with Default/Third-party indicators and country flag, sidebar link, add/edit/delete flows, country select offering an empty option, duplicate-name inline error. Verify `dotenv -e .env.test mix test test/video_conference_web/admin_portal/live/stream_servers_live_test.exs` passes.

## 3. Integration validation

- [x] 3.1 Migrate dev and test databases (`dotenv -e .env mix ecto.migrate`, `dotenv -e .env.test mix ecto.migrate`) and confirm `stream_servers` exists and is empty (no seed).
- [x] 3.2 Run `dotenv -e .env.test mix precommit` and fix any failures (compile warnings-as-errors, formatting, tests).
- [x] 3.3 Start the dev server (`dotenv -e .env mix phx.server`), sign in to `/admin` in the integrated browser, and verify: the sidebar shows "Stream servers", `/admin/stream-servers` lists and manages servers, marking a server default shows the badge and transfers the flag, and removal works.

## 4. Revisions

- [x] 4.1 Remove `is_default` end to end: drop the column and partial unique index from the `create_stream_servers` migration (uncommitted — edit in place, then `dotenv -e .env mix ecto.rollback` + `ecto.migrate` on dev and test), remove the field from the schema cast, revert the context to plain `Repo.insert`/`Repo.update` with name-only ordering, and remove the form checkbox, Default badge, and default-related tests.
- [x] 4.2 Make the country select searchable: add a `phx-keyup`/`phx-debounce` search input in the form that filters flag+name options server-side via `Countries.options_for_select/1` (case-insensitive name/code match), always pinning the currently selected code so filtering cannot silently change the stored value. Extend the LiveView test to cover filtering.
- [x] 4.3 Re-run `dotenv -e .env.test mix precommit` and refresh the `/admin/stream-servers` browser check (no Default badge, country search filters the options).
- [x] 4.6 Make the admin UI responsive
- [x] 4.7 Replace the native `<select>` country picker with a combobox — the
  native picker opens mispositioned on mobile Chrome (its anchor element sits
  inside a LiveView-patched DOM). New UI: a button that opens an `absolute`
  dropdown anchored under the field containing the search input, a "None"
  item, and the filtered flag+name options; `phx-click="pick_country"` sets
  the value via `Ecto.Changeset.put_change` on the existing changeset (keeps
  other edits), `phx-click-away` / re-clicking the button closes it; a hidden
  `stream_server[country]` input keeps form casting unchanged. Filtering no
  longer pins the selection — the selection is independent of the list.
  Update LiveView tests: open the dropdown, filter, pick, assert the hidden
  input value and empty-result state.
- [x] 4.8 Stop Chrome's detached field popups — autofill suggestions and the
  `required` validation bubble anchor to inputs that LiveView re-patches on
  every `validate` keystroke, so they surface at stale positions. Add
  `autocomplete="off"` to the stream-server form + text inputs and
  `novalidate` to the form (server-side validation renders inline; the
  native bubble also blocked `phx-submit` from reaching the server). Same
  treatment for the known-hosts form, which shares the pattern. (mobile/tablet/desktop): wrap the stream-servers and known-hosts tables in `overflow-x-auto` with smaller padding on small screens, widen the admin main container to `max-w-5xl`, and turn the sidebar into a below-`lg` drawer — `hidden lg:block` when collapsed (closed by default), hamburger toggle hidden on `lg+`, a backdrop to dismiss, and auto-collapse on `handle_params` navigation; on `lg+` the sidebar is permanent (documented trade-off: no desktop collapse). Verify the LV suite still passes and check narrow widths in the browser.
