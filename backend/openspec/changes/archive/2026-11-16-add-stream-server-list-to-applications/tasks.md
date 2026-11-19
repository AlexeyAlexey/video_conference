# Tasks

## 1. Page LiveView

- [x] 1.1 Create
  `VideoConferenceWeb.StreamServerAdminPortal.ApplicationStreamServersLive`
  modeled on `StreamServerPublicKeysLive`: `handle_params` resolves
  `params["application_id"]`, assigns a `filter_form` backed by a
  searchable `DropdownComponent` of application names (required picker —
  no empty option), `handle_info({:filter_picked, id})` push-patches to
  `?application_id=<id>`, and rows come from
  `StreamServers.list_stream_servers(application_id: id)`. Render a
  prompt when no application is selected and a read-only table (name,
  host, country flag, description, cert hash + copy) otherwise — no
  actions column. Verify: page compiles and renders both states in a
  browser.
- [x] 1.2 Add LiveView tests in
  `test/video_conference_web/stream_server_admin_portal/live/application_stream_servers_live_test.exs`
  covering the spec scenarios (prompt without selection, listing only
  the chosen application's assigned servers, `?application_id=` in the
  URL, unauthenticated redirect). Verify:
  `dotenv -e .env.test mix test test/video_conference_web/stream_server_admin_portal/live/application_stream_servers_live_test.exs`
  passes.

## 2. Routing

- [x] 2.1 Add
  `live "/applications/stream-servers", ApplicationStreamServersLive, :index`
  inside `live_session :stream_server_admin` in
  `lib/video_conference_web/stream_server_admin_portal/router.ex`, plus
  the `/stream-server-admin`-prefixed mirror route in the mirror block.
  Verify: the page mounts at
  `/stream-server-admin/applications/stream-servers` without a LiveView
  reload loop (mirror route resolves `route_info`).

## 3. Sidebar

- [x] 3.1 Add a "Stream servers" sub-item under "Applications" (after
  "Stream server public keys") in
  `AdminComponents.admin_sidebar/1` with id
  `sidebar-application-stream-servers-link`, navigating to
  `/stream-server-admin/applications/stream-servers`. Verify: the link
  renders in the sidebar and navigates to the page; cover the sidebar
  navigation scenario in the new LiveView test file or an existing
  portal test.

## 4. Precommit

- [x] 4.1 Run `dotenv -e .env.test mix precommit` and fix any failures.
  Verify: compile (warnings as errors), format, and full test suite are
  green.
