# Tasks

## 1. Available countries endpoint

- [x] 1.1 Add `Applications.available_countries(application_id: id)` to
  `lib/video_conference/stream_server_admin_portal/applications.ex` — a
  `SELECT DISTINCT` query over the application's assigned stream servers
  returning non-null `country` codes ordered alphabetically (load ignored);
  verify tests cover dedup, NULL-country exclusion, and ordering
- [x] 1.2 Add `get "/available-countries", ConnectionInfoController, :available_countries`
  inside the existing `"/api/application"` scope in the portal router, and
  implement the action in
  `lib/video_conference_web/stream_server_admin_portal/controllers/connection_info_controller.ex`:
  resolve the application via `Applications.authenticated_application/1`
  (rejects `ssak_` credentials) and return the bare JSON array; verify request
  tests cover `200` with sorted unique codes, `200 []` with no assigned
  servers, `401` for an `ssak_` secret, and `401` for a disabled application

## 2. Verification

- [x] 2.1 Run `dotenv -e .env.test mix test` for the new request tests and
  `dotenv -e .env.test mix precommit`; verify both pass clean
