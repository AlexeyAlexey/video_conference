# Proposal

## Why

Applications calling `GET /api/application/connection-info` can only discover which
country codes are satisfiable by trial and error — a code with no assigned server
fails the whole request with 422. A discovery endpoint listing the countries where
the application actually has assigned stream servers lets clients pick a valid code
up front.

## What Changes

- Add `GET /stream-server-admin/api/application/available-countries` to the stream server
  admin portal API, authenticated by `aak_` application API keys. It returns a JSON
  array of the ISO alpha-2 country codes for which the authenticated application
  has at least one assigned stream server — unique, sorted alphabetically,
  excluding servers without a country. An application with no qualifying
  assignments receives `200` with `[]`.

## Capabilities

### New Capabilities

- `application-available-countries`: application-facing endpoint that lists the
  country codes for which the authenticated application has at least one assigned
  stream server.

### Modified Capabilities

<!-- No existing capability requirements change. -->

## Impact

- `lib/video_conference/stream_server_admin_portal/applications.ex` — new
  `available_countries/1` context function
- `lib/video_conference_web/stream_server_admin_portal/router.ex` — new route in
  the existing `"/api/application"` scope
- `lib/video_conference_web/stream_server_admin_portal/controllers/connection_info_controller.ex` —
  new `available_countries` action
- Request-level test coverage alongside `connection_info_controller_test.exs`
- API consumers gain a discovery endpoint; no breaking changes
