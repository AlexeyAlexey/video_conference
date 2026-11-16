# Design

## Context

The portal already has three pages built on the "required parent picker"
pattern this page needs: `StreamServerPublicKeysLive` and `ApiKeysLive`
(pick an application), `StreamServerApiKeysLive` (pick a stream server).
Each resolves a `?<parent>_id=` param in `handle_params`, renders a
`DropdownComponent` filter form, push-patches on `{:filter_picked, id}`,
and prompts until a parent is selected. The read side also already
exists: `StreamServers.list_stream_servers(application_id: id)` returns
servers assigned to an application, ordered by name.

See proposal.md for motivation and specs/ for the behavior contract.

## Goals / Non-Goals

**Goals:**

- A read-only, application-scoped stream server list under the
  "Applications" sidebar group, consistent with the sibling pages.
- No new context functions, events, or migrations.

**Non-Goals:**

- Assigning/unassigning servers from this page — that stays on the
  stream servers assign view.
- Editing server fields (rename, country, cert hash, description) —
  those stay on `/stream-server-admin/stream-servers`.
- Changing the existing stream servers list or its optional filter.

## Decisions

### New LiveView modeled on the public keys page

Create
`VideoConferenceWeb.StreamServerAdminPortal.ApplicationStreamServersLive`
as a trimmed-down port of `StreamServerPublicKeysLive`: `handle_params`
lists applications and resolves `params["application_id"]`; a
`filter_form` (`to_form(..., as: :filter)`) feeds a searchable
`DropdownComponent` whose `on_change` sends `{:filter_picked, id}`,
handled by `handle_info` with `push_patch` to the index path. Server
rows come from `StreamServers.list_stream_servers(application_id: id)`;
`nil` application yields an empty list plus the selection prompt.

Alternative considered: reuse `StreamServersLive` with a "required"
variant. Rejected — that page carries the assign view, the new-server
form, and per-row edit modals; gating all of it behind a required
selection would tangle two different pages into one assign space.

### Route placement and mirror route

`live "/applications/stream-servers", ApplicationStreamServersLive,
:index` inside `live_session :stream_server_admin`, plus the
`/stream-server-admin/applications/stream-servers` mirror route. The
mirror is required by the `forward "/stream-server-admin"` mount quirk
documented in the router — the LiveView channel resolves the public URL
against this router, so both paths must exist.

### Read-only table

Reuse the stream servers table markup minus the "Applications" column
(redundant — every row shares the selected app) and minus every
interactive control (rename, edit modals, actions menu, remove). Keep
the country flag and the cert-hash "Set" + copy button — connection
details are the reason an admin opens this page. Description keeps the
expand/collapse behavior for long text since it is presentation-only.

### Sidebar

Add a "Stream servers" `<li>` under the "Applications" group in
`AdminComponents.admin_sidebar/1`, after "Stream server public keys",
with its own link id (`sidebar-application-stream-servers-link`) for
LiveView tests.

## Risks / Trade-offs

- Duplicated table markup between the two server-list pages →
  acceptable; extracting a shared component now would touch the working
  stream servers page for little gain. If a third read view appears,
  extract then.
- Disabled applications appear in the picker (same as the sibling
  pages) → consistent; filtering them out is a separate product
  decision.
