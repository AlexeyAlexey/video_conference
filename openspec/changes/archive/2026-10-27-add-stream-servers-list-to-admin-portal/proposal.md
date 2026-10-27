# Proposal

## Why

The app currently knows exactly one stream server: the single
env-configured HTTP/3 endpoint (`HTTP3_SERVER_HOST`/`PORT`/`CERT_HASH`)
read by `ConnectionCredentials`, `PageController`, and a router plug.
Operators need to manage multiple stream servers — both self-hosted ones
we run and third-party ones we do not control — and designate which one
the app should hand to participants. That requires a `stream_servers`
directory in the database and an admin UI to manage it. Wiring the
runtime to resolve the active server from the table is a follow-up
change; this one delivers the data model and management UI.

## What Changes

- New `stream_servers` table: `name` (unique, required), `description`
  (optional), `host` (ip, domain, or ip:port string), `country`
  (optional ISO 3166-1 alpha-2 code for the server's location), `settings`
  (map, default `%{}`, carries `cert_hash`), and `third_party` (boolean,
  default false — true for servers we do not own).
- New `VideoConference.AdminPortal.StreamServers` context +
  `StreamServers.StreamServer` schema (admin portal scope, matching the
  `KnownHosts` layout). A virtual `cert_hash` field on the schema is
  folded into `settings["cert_hash"]` by the changeset so the form can
  set it as a first-class input.
- New admin LiveView at `/admin/stream-servers` (`:index`/`:new`/`:edit`,
  plus `/admin`-prefixed mirror routes) listing all stream servers with
  Third-party indicators and add/edit/remove actions. The form
  offers the country as a searchable select of flag + country-name
  options including an empty choice; the list shows each server's flag.
- New "Stream servers" item in the admin sidebar.
- Tests for the context and the LiveView, plus manual validation of the
  page in a browser.

## Capabilities

### New Capabilities

- `stream-servers`: The directory of HTTP/3 stream servers available to
  carry video/audio/event streams — its data model (unique name,
  description, host address, country location, cert-hash-bearing
  settings, third-party flag) and the admin UI for
  listing/adding/editing/removing entries.

### Modified Capabilities

## Impact

- New migration `create_stream_servers` (columns above; unique index on
  `name`).
- New `lib/video_conference/admin_portal/stream_servers.ex` context and
  `lib/video_conference/admin_portal/stream_servers/stream_server.ex`
  schema (declared in the admin portal scope, matching
  `AdminPortal.KnownHosts`).
- New `lib/video_conference_web/admin_portal/live/stream_servers_live.ex`
  plus routes (with `/admin`-prefixed mirror routes) in
  `VideoConferenceWeb.AdminPortal.Router`.
- `lib/video_conference_web/admin_portal/admin_components.ex` — sidebar
  nav item.
- New fixtures and tests under `test/`.
