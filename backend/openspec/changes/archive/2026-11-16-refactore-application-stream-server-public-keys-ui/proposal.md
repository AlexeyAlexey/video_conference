# Proposal

## Why

The stream server public keys page is the last portal page still using the
old grouped-by-application layout. The API keys pages (`/stream-server-admin/api-keys`,
`/stream-server-admin/stream-servers/api-keys`) established a simpler pattern —
pick an owner first, then manage one flat list — and public keys should match
it so all portal key-management pages behave the same way.

## What Changes

- The public keys page shows keys for **one selected application** in a single
  flat table instead of listing every application with its keys grouped under
  it. **BREAKING** (page behavior): nothing is listed until an application is
  selected — the "All applications" filter option is removed and a
  select-an-application prompt is shown instead.
- Adding a key moves from a separate `/new` route with an inline card form to
  an `:add` modal, matching the API keys pages. The add form no longer carries
  its own application dropdown — the selected application is shown as text and
  its id is injected on save. **BREAKING** (route removal):
  `/stream-server-admin/applications/stream-server-public-keys/new` goes away.
- All existing per-key features are kept: rename, edit description, toggle
  enabled, show public key modal, copy key id / public key, and the row
  actions menu (Change app, Remove).
- Context: `Applications` gains a flat
  `list_stream_server_public_keys(application_id)` mirroring `list_api_keys/1`;
  `list_applications_with_stream_server_public_keys/1` is removed (its only
  production caller was this page's grouped listing).

## Capabilities

### New Capabilities

### Modified Capabilities

- `portal-public-stream-server-keys`: the admin list requirement changes from
  grouped-by-application to a required application selection with a flat key
  list; the filter requirement loses the all-applications option and becomes a
  required selection; the management requirement's add form loses its
  application dropdown (the selected application supplies it); the change-app
  scenario is reworded for the flat list.

## Impact

- `lib/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live.ex`
  — rewritten on the `ApiKeysLive` pattern.
- `lib/video_conference_web/stream_server_admin_portal/router.ex` — `:new`
  live routes removed (stripped-path and `/stream-server-admin` mirror).
- `lib/video_conference/stream_server_admin_portal/applications.ex` —
  `list_stream_server_public_keys/1` added,
  `list_applications_with_stream_server_public_keys/1` removed.
- `test/video_conference_web/stream_server_admin_portal/live/stream_server_public_keys_live_test.exs`
  — rewritten mirroring `api_keys_live_test.exs`.
- `test/lib/video_conference/stream_server_admin_portal/applications_test.exs`
  — grouped-listing tests replaced with flat-list tests.
- No sidebar/navigation changes; URL path and `application_id` query param
  are unchanged.
