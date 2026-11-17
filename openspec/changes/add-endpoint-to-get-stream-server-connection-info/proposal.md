# Proposal

## Why

Applications that integrate with the stream server currently have no way
to discover which stream server they should connect to. Stream server
connection details (`HTTP3_SERVER_HOST`, `HTTP3_SERVER_PORT`,
`HTTP3_SERVER_CERT_HASH`) are static environment configuration, so there
is no application-scoped, country-aware, load-aware routing of streams to
servers. Applications need an authenticated lookup that resolves each of
their logical streams (video, audio, event, ...) to the connection info
of a suitable assigned stream server.

## What Changes

- Add `GET /stream-server-admin/api/application/connection-info` to the
  stream server admin portal API, inside the existing `[:api, ApiKeyAuth]`
  scope.
- The endpoint authenticates with an `aak_` application API key via the
  existing `X-API-Key` machinery; the authenticated credential identifies
  the calling application. `ssak_` credentials are rejected (401), and a
  disabled application is rejected (404).
- The endpoint accepts a `streams` query param (Phoenix bracket notation)
  of 1–4 entries, each with a required `name` (non-empty, max 20 chars,
  first occurrence wins on duplicates) and a required `country_code` in
  the stored format — lowercase ISO alpha-2 — or the reserved value
  `"any"` meaning no country preference.
- For each requested country it selects the least-loaded stream server
  assigned to the application (`ORDER BY load, name`); `"any"` selects
  the least-loaded among all assigned servers. A country with no
  assigned server fails the whole request with 422, naming the streams
  that could not be satisfied.
- On success it returns a JSON map keyed by stream `name`, each value
  containing `url` (`"https://" <> host`) and `cert_hash` when one is
  stored.

## Capabilities

### New Capabilities

- `application-connection-info`: The application-facing endpoint that
  resolves a set of named streams to stream server connection info,
  including its validation, credential scoping, server selection, and
  error semantics.

### Modified Capabilities

<!-- None: the X-API-Key dispatch in `stream-server-api` already covers
     `aak` credentials; no requirement there changes. -->

## Impact

- `lib/video_conference_web/stream_server_admin_portal/router.ex` — new
  route in the `ApiKeyAuth`-protected API scope.
- New controller
  `VideoConferenceWeb.StreamServerAdminPortal.Applications.ConnectionInfoController`.
- `VideoConference.StreamServerAdminPortal.StreamServers` (or
  `Applications`) — a query returning assigned stream servers for an
  application grouped by country, least-loaded first.
- New spec `openspec/specs/application-connection-info/` once the change
  is archived.
- No schema migrations; uses existing `application_stream_servers`,
  `stream_servers.country`, `cert_hash`, and `load` columns.
