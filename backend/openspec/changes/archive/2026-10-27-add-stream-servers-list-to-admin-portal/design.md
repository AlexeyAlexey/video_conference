# Design

## Context

See proposal.md — Why. The app currently knows exactly one stream
server, via `HTTP3_SERVER_*` env vars; nothing about that wiring changes
here. The `KnownHosts` feature established every convention this change
reuses: `AdminPortal.<Ctx>` context + nested schema, a single LiveView
with `:index`/`:new`/`:edit` live_actions plus `/admin`-prefixed mirror
routes in the `:admin` live_session, `Layouts.admin` +
`admin_sidebar`, `phx-click` delete with `data-confirm`, and the
fixtures/context-test/LiveView-test trio.

## Goals / Non-Goals

**Goals:**
- `stream_servers` table and `AdminPortal.StreamServers` context
  (schema declared in the admin portal scope).
- Admin LiveView management UI + sidebar entry.

**Non-Goals:**
- Wiring stream servers into the runtime — `ConnectionCredentials`,
  `PageController`, the router's `put_http3_server_*` plugs, channels,
  and the frontend keep reading env config exactly as today. Selecting a
  server from the table is a follow-up change.
- Health checking / reachability probing — there is no `online` flag
  and nothing checks whether a server is alive.
- Load balancing or per-conference server assignment.
- Migrating or seeding the env-configured server into the table — the
  table starts empty.
- IPv6 `host:port` parsing edge cases — `host` is stored as a free-form
  string this change never parses.
- Changing `HostPublicKey` (still a stub) or call-flow host resolution.

## Decisions

### Schema and column names

`stream_servers`: `name` (string, null false, unique), `description`
(text), `host` (string), `country` (string, nullable — ISO 3166-1
alpha-2 code), `settings` (map), `third_party` (boolean,
default false, null false). Indexes: unique on `name`.

### `country` as an ISO alpha-2 code with a flag select

`country` stores the lowercase ISO 3166-1 alpha-2 code (`"de"`, `"us"`),
nullable — empty choice persists `nil`. A module constant in the context
(or a small `StreamServers.Countries` module) maps code →
`{name, flag_emoji}` for a fixed supported set; the changeset validates
inclusion (`validate_inclusion`) so only supported codes are stored. The
form exposes the choices as a custom combobox (button + anchored
dropdown of `"#{flag} #{name}"` items with a "None" item); the table
shows the flag emoji in a Country column (empty cell when unset).

With ~250 supported countries, the picker needs search, and a native
`<select>` proved unreliable: its picker opens mispositioned on mobile
Chrome — the `<select>` sits inside a LiveView-patched DOM, and the
native popup anchors to a node the browser may have detached. The form
therefore renders a combobox: a button toggles an `absolute` dropdown
directly under the field containing a debounced `phx-change` search
input, a "None" item, and the filtered `Countries.options_for_select/1`
list (name or code match, case-insensitive). `phx-click="pick_country"`
sets the value via `Ecto.Changeset.put_change` on the existing changeset
(other in-progress edits survive), `phx-click-away` / re-clicking the
button closes it, and a hidden `stream_server[country]` input keeps the
standard changeset cast on submit. Everything stays server-driven and
exercisable in `Phoenix.LiveViewTest`.

*Alternative — keep the native `<select>`:* rejected; mobile Chrome
renders its popup detached from the field, and there is no reliable way
to style or position a native picker.

*Alternative — client-side JS hook filtering a full select:* rejected;
it adds a DOM-sync burden under LiveView patching and can't be covered
by `Phoenix.LiveViewTest`.

Flag *emojis* rather than image assets: zero dependencies and they
render inside native `<option>` elements. Known caveat: on Windows,
regional-indicator pairs render as the two letters (`DE`) instead of a
flag — acceptable; if it becomes an issue a flag sprite is a drop-in
replacement behind the same code→flag mapping.

*Alternative — free-text country:* rejected; the flag picker needs a
closed vocabulary, and alpha-2 codes keep the stored value stable if
country display names are ever localized.

### `cert_hash` as a virtual field folded into `settings`

The schema gets `field :cert_hash, :string, virtual: true`. The changeset
casts it and merges into `settings["cert_hash"]` (empty/blank removes the
key, preserving other settings keys); it also derives the virtual value
from persisted `settings` when building a form for an existing row.
This keeps `settings` a free-form map for future keys while the form
gets a normal validated `<.input field={@form[:cert_hash]}>`.

*Alternative — post `settings[cert_hash]` directly:* rejected; a form bug
or crafted params could clobber the whole map, and error rendering on a
map field is awkward.

### LiveView and routes

`StreamServersLive` mirrors `KnownHostsLive` almost line-for-line:
`live_action` routes `/stream-servers`, `/stream-servers/new`,
`/stream-servers/:id/edit` plus `/admin`-prefixed mirrors in the
`:admin` live_session; `handle_params` assigns list + form; `phx-click`
delete with `data-confirm`; `push_patch` back to index on save. Form
fields: name, description (textarea), host, searchable country combobox
with an empty choice, cert hash (virtual), third
party (checkbox). Table columns: name, host, country flag, third-party,
actions. `list_stream_servers/0` orders by `name` asc.

### Sidebar

Add "Stream servers" `<.link navigate="/admin/stream-servers">` after
"Known hosts" in `AdminComponents.admin_sidebar`, `hero-signal` icon
(server-stack is taken by known hosts).

### Responsive admin shell

The admin layout predates mobile support: the sidebar was `fixed`
overlay starting *expanded* on small screens (covering content), and the
5-column tables overflowed the `max-w-2xl` container. Fixes:

- The sidebar becomes a drawer below `lg`: `admin_sidebar_collapsed`
  defaults to `true`, and the collapsed state renders
  `hidden lg:block` — so the drawer is closed by default on
  mobile/tablet while `lg:block` keeps the sidebar permanent on desktop.
  A `bg-black/50` backdrop (`top-16` so the navbar toggle stays
  clickable) dismisses the drawer, a `handle_params` hook collapses it
  on every navigation, and the toggle button is `lg:hidden`.
  *Trade-off:* the toggle no longer collapses the desktop sidebar —
  accepting a permanent `lg+` sidebar is what lets one boolean drive
  both breakpoints without viewport detection.
- Tables get `overflow-x-auto` wrappers + `table-sm sm:table-md`, and
  `<main>` gets `min-w-0` (flex children can't shrink below content
  width without it — the wrapper would never scroll) and `max-w-5xl`.

### Testing

- `stream_servers_fixtures.exs`: unique name generator, valid attrs,
  `stream_server_fixture/1`.
- `stream_servers_test.exs` (DataCase): CRUD, unique name, cert_hash
  fold/clear into settings, country set/cleared/invalid-code rejection.
- `stream_servers_live_test.exs` (ConnCase): mirrors the known-hosts
  suite — unauth redirect, list rendering with Third-party indicator
  and flag, sidebar link, add/edit/delete, country select with an empty
  option and server-side search filtering, duplicate-name inline
  error.
- Manual: dev server + integrated browser, verify the page end to end.

## Risks / Trade-offs

- `host` is a free-form string with no format validation (matching
  `known_hosts`) → malformed values are stored harmlessly until the
  resolution change needs to parse them; that change should add parsing
  or validation.
- Third-party hosts are stored but indistinguishable in behavior →
  `third_party` is display-only for now, as specified.

## Migration Plan

1. Add `create_stream_servers` migration (additive — existing DBs just
   run `mix ecto.migrate`, no reset needed; no seed).
2. Context + schema.
3. LiveView + routes + sidebar.
4. `dotenv -e .env.test mix precommit`; dev server + browser check.

Rollback: drop the table (new migration reversible); nothing else is
touched.
