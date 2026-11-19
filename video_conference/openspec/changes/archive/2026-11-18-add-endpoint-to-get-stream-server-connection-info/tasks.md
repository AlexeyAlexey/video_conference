# Tasks

## 1. Server resolution query

- [x] 1.1 Add `VideoConference.StreamServerAdminPortal.Applications.stream_servers/1`, called as `stream_servers(application_id: id, country_codes: codes, min_loaded: true)`, grouping the application's `application_stream_servers` assignments by `country` at the database level (`GROUP BY` + `min(load)` bare-column pick) and returning each group's least-loaded server as `%{country => server}` (`country_codes: []` groups every country, including nil); verify with a `DataCase` test covering assignment scoping, the filter, and the min-loaded grouping, including servers whose `country` is nil.
- [x] 1.2 Cover the empty-result case in the same test file (application with no assigned servers returns `%{}`); verify the query returns an empty map rather than raising.

## 2. Connection info endpoint

- [x] 2.1 Register `scope "/api/application", VideoConferenceWeb.StreamServerAdminPortal.Applications` in `lib/video_conference_web/stream_server_admin_portal/router.ex` with `pipe_through [:api, ApiKeyAuth]` and `get "/connection-info", ConnectionInfoController, :show`; verify `mix phx.routes VideoConferenceWeb.StreamServerAdminPortal.Router` lists `GET /api/application/connection-info`.
- [x] 2.2 Implement `VideoConferenceWeb.StreamServerAdminPortal.Applications.ConnectionInfoController.show/2` following the `PublicKeyController` `with`-pipeline pattern: reject non-`{:application, _}` credentials (401), reject disabled applications (404), validate `country_codes` (list of 1–4 distinct alpha-2 codes, case-insensitive and normalized to lowercase; duplicates allowed; anything else → 400), resolve via `Applications.connection_info(application_id:, country_codes:)` → `ConnectionInfo.execute/1` picking the least-loaded server per code (else 422 naming the unsatisfiable codes in a `country_codes` field), and respond `[%{country_code:, url: "https://" <> host, cert_hash?: ...}]` — one entry per requested code, order and duplicates preserved; verify with `ConnCase` tests covering each status, order/duplicate handling, least-loaded selection, malformed codes like `"any"` and `"d1"`, and case-insensitive matching, and `cert_hash` omission.

## 3. Integration check

- [x] 3.1 Run `dotenv -e .env.test mix precommit` and fix any warnings or failures; verify it exits clean.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
