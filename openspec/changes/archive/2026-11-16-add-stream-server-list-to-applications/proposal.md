# Proposal

## Why

The stream server admin portal lets an admin browse everything that
belongs to an application — its API keys and its stream server public
keys — through per-application pages under the "Applications" sidebar
group. The stream servers assigned to an application are the missing
piece of that picture: today the only way to see them is the optional
application filter on the stream servers page, which is a server-centric
view. An admin thinking "what serves application X?" has no dedicated
place to look.

## What Changes

- Add a read-only page at
  `/stream-server-admin/applications/stream-servers` that lists the
  stream servers assigned to a selected application.
- The page requires an application selection via a searchable dropdown:
  until one is picked it prompts the admin and lists nothing; the choice
  is carried in the `?application_id=` URL parameter.
- Each listed server shows name, host, country flag, description, and
  certificate hash (with copy affordance). The "Applications" column of
  the main stream servers table is omitted — every row shares the
  selected application — and there are no row actions: assignments stay
  managed on `/stream-server-admin/stream-servers`.
- The sidebar gains a "Stream servers" sub-item under "Applications",
  after "Stream server public keys".

## Capabilities

### New Capabilities

### Modified Capabilities

- `stream-server-directory`: adds a requirement for the per-application
  stream servers page (required application filter, read-only list of
  assigned servers).
- `stream-server-admin-portal`: the "Portal navigation" requirement
  gains a "Stream servers" sub-item under "Applications".

## Impact

- New LiveView
  `VideoConferenceWeb.StreamServerAdminPortal.ApplicationStreamServersLive`;
  reuses `StreamServers.list_stream_servers(application_id: ...)`
  (already implemented) — no context or schema changes.
- `VideoConferenceWeb.StreamServerAdminPortal.Router`: one `live` route
  plus its `/stream-server-admin`-prefixed mirror route for LiveView
  URL resolution.
- `VideoConferenceWeb.StreamServerAdminPortal.AdminComponents`: one new
  sidebar sub-item.
- No API, event, or database changes; assignments remain managed on the
  stream servers page.
