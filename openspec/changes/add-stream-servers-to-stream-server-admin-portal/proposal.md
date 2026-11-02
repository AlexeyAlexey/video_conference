# Proposal

## Why

The stream server admin portal manages applications that integrate with
the stream server, but it has no registry of the physical stream servers
themselves. Portal admins need to record which servers are available to
carry video/audio/event streams and which applications each server is
assigned to, so the portal can become the source of truth for
application-to-server allocation.

## What Changes

- Add a `stream_servers` table to the portal's dedicated database
  (UUID primary key, `name`, optional `description`, `host`, optional
  `country`, `settings` map defaulting to `%{}`, `cert_hash` column) and
  an `application_stream_servers` join table giving a many-to-many
  between portal stream servers and applications.
- Add a `VideoConference.StreamServerAdminPortal.StreamServers` context
  with CRUD, application filtering (including an "unassigned" filter),
  and assign/unassign operations.
- Add a `StreamServersLive` page at `/stream-server-admin/stream-servers`
  where portal admins list, add, edit, and remove stream servers; see the
  assigned applications per server; filter the list by application; and
  assign/unassign applications via a dedicated per-row assign view.
- Add a "Stream servers" item to the portal sidebar navigation.
- Move the `Countries` module to a shared namespace so both admin
  portals can use it.

The portal's stream server directory is independent of the existing
`/admin/stream-servers` directory in the main application database —
that page, its table, and the `stream-servers` spec are untouched.

## Capabilities

### New Capabilities

- `stream-server-directory`: The stream server admin portal's registry
  of physical stream servers (name, description, host, country,
  settings, cert_hash) and the many-to-many assignment of servers to
  applications, including the portal UI to manage servers, view and
  change assignments, and filter servers by application.

### Modified Capabilities

- `stream-server-admin-portal`: The *Portal navigation* requirement
  changes — the sidebar gains a "Stream servers" item.

## Impact

- New portal-repo migration (two tables) under
  `priv/stream_server_admin_portal_repo/migrations/`.
- New context `lib/video_conference/stream_server_admin_portal/stream_servers.ex`
  plus `stream_servers/` schema directory.
- New LiveView
  `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`
  and routes (including `/stream-server-admin`-prefixed mirror routes)
  in the portal router.
- Sidebar component in
  `lib/video_conference_web/stream_server_admin_portal/admin_components.ex`
  gains a "Stream servers" item.
- `Countries` moves out of
  `VideoConference.AdminPortal.StreamServers` into a shared namespace;
  existing admin-portal references updated.
- Tests: context tests, LiveView tests, integrated-browser validation.
