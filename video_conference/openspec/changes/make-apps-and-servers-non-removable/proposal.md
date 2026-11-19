# Proposal

## Why

Applications and stream servers in the stream server admin portal are
permanent registry entries: once created they own API keys, public keys,
assignments, and event streams that should never silently disappear. At
the same time, `name` is no longer the identity of either record — an
application is identified by its UUID (the "App ID" operators need when
configuring integrations) and a stream server is identified by its
unique `host`. Name uniqueness adds friction without adding safety.

## What Changes

- **BREAKING (behavior)**: Applications can no longer be removed. The
  Remove button and `delete` event are dropped from
  `ApplicationsLive`, `Applications.remove_application/1` is removed,
  and the `ApplicationWasRemoved` event module is deleted.
- **BREAKING (behavior)**: Stream servers can no longer be removed. The
  Remove button and `delete` event are dropped from
  `StreamServersLive`, `StreamServers.remove_stream_server/1` is
  removed, and the `StreamServerWasRemoved` event module is deleted.
- **BREAKING (validation)**: Application and stream server names are no
  longer unique. The `unique_index` on `applications.name` and
  `stream_servers.name` is dropped in a new migration, and the
  `unsafe_validate_unique`/`unique_constraint(:name)` checks are removed
  from both schemas' create and rename changesets. Names stay required.
  Stream server `host` remains unique — it is the server's identifier.
- The applications table gains an **App ID** column displaying each
  application's UUID, copyable like the cert-hash column on the stream
  servers page.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-applications`: the application-record requirement drops
  name uniqueness; the management requirement loses delete and gains the
  App ID display; the removed-event requirement is removed.
- `stream-server-directory`: the portal stream server record drops name
  uniqueness (host stays unique and immutable); the management and
  removal/assignment-cascade/removed-event requirements are removed.

## Impact

- **Migration**: new migration in
  `priv/stream_server_admin_portal_repo/migrations/` dropping
  `applications_name_index` and `stream_servers_name_index`.
- **Code**:
  `lib/video_conference/stream_server_admin_portal/applications/application.ex`
  and `.../stream_servers/stream_server.ex` (drop name-unique
  validations),
  `lib/video_conference/stream_server_admin_portal/applications.ex` and
  `.../stream_servers.ex` (drop remove functions and event aliases),
  `lib/video_conference_web/stream_server_admin_portal/live/applications_live.ex`
  (Remove button/handler out, App ID column in),
  `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`
  (Remove button/handler out).
- **Deleted files**:
  `applications/events/application_was_removed.ex`,
  `stream_servers/events/stream_server_was_removed.ex`.
- **Event store**: any historical `ApplicationWasRemoved` /
  `StreamServerWasRemoved` rows in `events` become undecodable if ever
  queried by type; no listener is configured (`event_listeners: []`) and
  nothing queries those types, so this is accepted.
- **Tests**: applications/stream servers context tests and both LiveView
  tests lose removal/duplicate-name coverage and gain
  duplicate-names-allowed + App ID coverage.
- The `/admin` portal's own `stream_servers` table (`VideoConference.Repo`)
  is untouched: its host is not unique, so name remains its identifier.
