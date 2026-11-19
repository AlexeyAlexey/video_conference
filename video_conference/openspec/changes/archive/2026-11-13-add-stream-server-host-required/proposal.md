# Proposal

## Why

A portal stream server's `host` is the address clients use to reach it,
yet it is currently optional: the changeset only requires `name`, the
`stream_servers.host` column is nullable, and the new-server form accepts
a blank host. A server without a host is a useless registry entry — it
cannot be connected to — so every stream server must carry a host.

## What Changes

- Require `host` on portal stream server creation:
  `StreamServer.changeset/2` validates `host` as required in addition to
  `name`. **BREAKING** for any caller persisting host-less servers.
- Add a portal database migration making `stream_servers.host`
  `NOT NULL` (existing NULL-host rows are deleted by the migration).
- Mark the host input as required in the new stream server form.
- Update the portal test fixture so `stream_server_fixture/1` supplies a
  default host, and add coverage for the required-host validation.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `stream-server-directory`: The "Portal stream server record"
  requirement changes `host` from a unique-but-optional address to a
  required unique address, and the "Portal stream server management"
  requirement gains explicit host-required form validation behavior.

## Impact

- `lib/video_conference/stream_server_admin_portal/stream_servers/stream_server.ex`
  — `validate_required` gains `:host`.
- New migration under `priv/stream_server_admin_portal_repo/migrations/`
  — `host` becomes `null: false`.
- `lib/video_conference_web/stream_server_admin_portal/live/stream_servers_live.ex`
  — host input marked required.
- `test/support/fixtures/stream_server_admin_portal_fixtures.exs` —
  fixture default gains a `host`.
- `test/lib/video_conference/stream_server_admin_portal/stream_servers_test.exs`
  and the portal stream servers LiveView test — new assertions for the
  required host.
- Deployments with existing NULL-host rows lose those rows when the
  migration runs; the migration deletes them rather than backfilling
  fabricated hosts.
