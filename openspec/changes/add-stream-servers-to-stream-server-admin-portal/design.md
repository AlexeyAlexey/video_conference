# Design

## Context

The stream server admin portal (`/stream-server-admin`) is an isolated
shell: dedicated SQLite repo
(`VideoConference.StreamServerAdminPortal.Repo`), migrations under
`priv/stream_server_admin_portal_repo/migrations/`, a forwarded router
that requires `/stream-server-admin`-prefixed mirror `live` routes for
LiveView URL resolution, a collapsible sidebar in `admin_components.ex`,
and `Layouts.stream_server_admin`. Its `applications`/`api_keys` tables
use `binary_id` UUID primary keys. `ApplicationsLive` establishes the
CRUD pattern: `live_action` `:index`/`:new`/`:edit`, inline
section-swapping (no modals), `push_patch`, `assign_form`, and
`DropdownComponent` for select fields (native `<select>` is forbidden).
A separate `stream_servers` table already exists in the **main** repo
for `/admin/stream-servers` (integer PK, `third_party`, cert hash inside
`settings`) — this change does not touch it; the portal gets its own
directory (see proposal.md).

## Goals / Non-Goals

**Goals:**

- Portal-owned `stream_servers` table with UUID PK and a real
  many-to-many `application_stream_servers` join (FKs on both sides).
- Portal CRUD UI at `/stream-server-admin/stream-servers` with
  application assignment, assigned-application display, and application
  filtering (all / unassigned / per application).
- Sidebar gains a "Stream servers" item.

**Non-Goals:**

- Any change to `/admin/stream-servers`, the main repo's
  `stream_servers` table, or `public_stream_server_keys`.
- Runtime use of the directory (stream selection at call time stays
  env-configured; a later change consumes the registry).
- The future REST API's authorization rules around assignment (only the
  data model is laid down here).

## Decisions

### D1: Portal repo, `binary_id` keys, `cert_hash` as a column

Both tables go in `priv/stream_server_admin_portal_repo/migrations/`,
honoring portal isolation. `stream_servers` declares
`@primary_key {:id, :binary_id, autogenerate: true}` like
`applications`/`api_keys`. `cert_hash` is a **dedicated string column**
(not folded into `settings` as the main-repo table does): the portal has
no legacy shape to preserve, and a column is explicit and queryable. The
`settings` map stays free-form for future keys. There is no
`third_party` flag — application assignment expresses ownership.

### D2: Join table `application_stream_servers` with `delete_all` FKs

`application_id` and `stream_server_id` reference their tables
`on_delete: :delete_all`, with a unique index on the pair. Deleting an
application or a server removes its assignments automatically —
satisfying the assignment-cascade requirement without application-level
cleanup. Schemas use `many_to_many` with `join_through` on the join
schema (or the join-table name) so assignments preload into the list
query.

### D3: `assign_applications/2` uses replace-set semantics

The context exposes a function that sets a server's full application set
from a list of application ids (put_assoc-style), rather than
incremental add/remove calls. The assign view submits the complete
selection, so replace semantics is the simplest correct contract and
covers both assign and unassign.

### D4: A fourth `live_action :assign` for the per-row assign view

`StreamServersLive` gets `:index`, `:new`, `:edit`, `:assign` —
`/stream-server-admin/stream-servers/:id/assign` renders a dedicated
"Assign applications to <name>" view with a checkbox list of all
applications (checked = assigned) and save/cancel that `push_patch`es
back to the index. This mirrors the portal's inline section-swap pattern
and needs no new component. A checkbox list (not `DropdownComponent`,
which is single-select) is acceptable since it isn't a native `<select>`.

### D5: Filter via `?application_id=` query param handled in `handle_params`

The index's filter is a `searchable` `DropdownComponent` (single
select) whose picked
value `push_patch`es to `?application_id=<id>`,
`?application_id=unassigned`, or no param for all servers. The component
is wrapped in a `<.form>` (`onsubmit` prevented): LiveView serializes
`phx-change` through the enclosing form, and a formless input throws
client-side before the `filter` event is ever pushed — which silently
broke the search field. Keeping the
filter in the URL survives patch navigation (`:new`/`:edit`/`:assign`
and back) and makes filtered views shareable. The list query applies the
filter with a join on `application_stream_servers`, or `WHERE NOT
EXISTS` for `unassigned`.

### D6: `Countries` moves to a shared namespace

`VideoConference.AdminPortal.StreamServers.Countries` is pure data; it
moves to `VideoConference.StreamServers.Countries` so the portal context
doesn't depend on `AdminPortal` internals. The existing schema and
`StreamServersLive` update their alias — mechanical, no behavior change.

## Risks / Trade-offs

- [Two stream-server directories now exist (`/admin` vs portal)] →
  Accepted by the user: the portal registry serves third-party
  application allocation; the `/admin` list is the app-facing directory.
  A later change may converge them or have one feed the other.
- [Join row uniqueness race on concurrent saves] → unique composite
  index on `(application_id, stream_server_id)` enforces it at the DB;
  `replace` semantics rewrites the set in one transaction.
- [Mirror-route drift: forgetting `/stream-server-admin`-prefixed
  mirrors breaks LiveView mounts with an infinite reload] → every real
  route gets its mirror, and browser validation covers mount of each
  action.

## Migration Plan

1. Add the portal-repo migration (new tables only — no data migration;
   the portal directory starts empty).
2. Move `Countries` and update existing aliases before adding new code,
   so both steps compile independently.
3. Deploy runs `mix ecto.migrate` for both repos as today.
