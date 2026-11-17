# Tasks

## 1. Server resolution query

- [ ] 1.1 Add a context function to `VideoConference.StreamServerAdminPortal.StreamServers` returning every stream server assigned to an application via `application_stream_servers`, ordered `load ASC, name ASC` (e.g. `list_assigned_stream_servers/1`); verify with a `DataCase` test covering assignment scoping and the ordering, including servers whose `country` is nil.
- [ ] 1.2 Cover the empty-result case in the same test file (application with no assigned servers returns `[]`); verify the query returns an empty list rather than raising.

## 2. Connection info endpoint

- [ ] 2.1 Register `scope "/api/application", VideoConferenceWeb.StreamServerAdminPortal.Applications` in `lib/video_conference_web/stream_server_admin_portal/router.ex` with `pipe_through [:api, ApiKeyAuth]` and `get "/connection-info", ConnectionInfoController, :show`; verify `mix phx.routes VideoConferenceWeb.StreamServerAdminPortal.Router` lists `GET /api/application/connection-info`.
- [ ] 2.2 Implement `VideoConferenceWeb.StreamServerAdminPortal.Applications.ConnectionInfoController.show/2` following the `PublicKeyController` `with`-pipeline pattern: reject non-`{:application, _}` credentials (401), reject disabled applications (404), validate `streams` (list of 1–4, `name` required non-empty max 20, `country_code` required as `"any"` or `~r/^[a-z]{2}$/` → 400), dedupe names first-wins, resolve via the task-1 query picking the first server per requested code — and the overall first for `"any"` — (else 422 naming the unsatisfiable names), and respond `%{name => %{url: "https://" <> host, cert_hash?: ...}}`; verify with `ConnCase` tests covering each status, name deduplication, least-loaded selection, the `"any"` reserved code, malformed codes like `"US"`, same-country resolution, and `cert_hash` omission.

## 3. Integration check

- [ ] 3.1 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures; verify it exits clean.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
