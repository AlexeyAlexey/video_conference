# Design

## Context

Two near-identical dropdown implementations exist today (see proposal.md —
Why): a plain one in `PublicStreamServerKeysLive` (`server_open`,
`toggle_/close_server_dropdown`, `pick_server`) and a searchable one in
`StreamServersLive` (`country_open/query/options`, `filter_countries`,
`pick_country`). Both render the same daisyUI button+listbox markup with a
hidden input bound to `Phoenix.HTML.FormField`. `use VideoConferenceWeb,
:live_component` is already wired in `video_conference_web.ex`, and
`CoreComponents.translate_error/1` is public.

## Goals / Non-Goals

**Goals:**
- One stateful `DropdownComponent` owning open/close + search state and all
  listbox markup/events, reusable by any admin form.
- Component→parent notification via an injected `on_change` callback
  (Phoenix's "Unifying LiveView and LiveComponent communication" pattern),
  so the same component works under a LiveView or another component.
- Preserve existing DOM ids (`stream-server-dropdown-button`,
  `country-option-none`, `country-search`, …) so current LiveView tests and
  any external tooling keep working unchanged.
- Keep the Tailwind/daisyUI classes identical to the current markup so the
  visual result and responsive behavior do not regress.

**Non-Goals:**
- No keyboard navigation / type-ahead selection (aria basics only).
- No multi-select, no async/remote option loading, no JS hook.
- No changes to the public (non-admin) UI, routes, or data layer.
- The user request's "Stream server dropdown in stream servers page" is
  interpreted as the **country** dropdown — the only dropdown on that page;
  there is no stream-server picker there.

## Decisions

### Single LiveComponent in the admin portal namespace

`VideoConferenceWeb.AdminPortal.DropdownComponent` at
`lib/video_conference_web/admin_portal/dropdown_component.ex`, declared
with `use VideoConferenceWeb, :live_component`. LiveComponent (not a
function component) because it must own stateful interactions — open
state and the search query — and handle its own events. Admin-portal
namespace because that is where it is used; moving it later is trivial.

### Assigns / public API

```
<.live_component
  module={DropdownComponent}
  id="stream-server"                       # also the DOM-id prefix
  label="Stream server"                    # field label
  field={@form[:stream_server_id]}         # Phoenix.HTML.FormField
  options={for s <- @stream_servers, do: {s.name, s.id}}   # list OR (query -> list)
  placeholder="Choose a stream server"
  empty_label={nil}                        # optional "None" row when set
  searchable={false}                       # optional filter input
  search_placeholder="Type to filter"
  on_change={fn value -> send(self(), {:stream_server_picked, value}) end}
/>
```

- `options` as `{label, value}` tuples — generic; callers map structs.
  It accepts **either a list (static options) or an arity-1 function
  `query -> list` (searchable options)**; the component normalizes a list to
  `fn _query -> list end` and invokes the fun with the current query. For
  `StreamServersLive` this becomes `options={&Countries.options_for_select/1}`,
  removing the `country_options`/`country_query` assigns entirely — options
  are fetched lazily on open/filter instead of eagerly on mount.
  Alternative considered: `option_label`/`option_value` accessor functions;
  rejected as more ceremony for no benefit.
- `empty_label` doubles as the flag for rendering the empty choice; when
  nil, no empty row is rendered (public-keys case). `"None"` for country.
- DOM ids derived from `id`: `"#{id}-field"`, `"#{id}-dropdown-button"`,
  `"#{id}-dropdown"`, `"#{id}-search"` (`name="#{id}_search"`),
  `"#{id}-option-none"`, `"#{id}-option-#{value}"`. With `id="country"` and
  `id="stream-server"` every existing id is reproduced exactly.

### Communication: injected `on_change` callback

Per the Phoenix docs' unifying pattern, `pick` calls
`@on_change.(value)` instead of `send(self(), ...)`. Each LiveView passes a
closure that builds its own message:

```elixir
on_change={fn id -> send(self(), {:stream_server_picked, id}) end}
```

and handles it in `handle_info`, where it `put_change`s the changeset,
deletes the field error (the known `put_change/3` does-not-clear-errors
issue), and re-assigns the form. Casting stays the parent's job:
`pick` emits the raw string value and `StreamServersLive` stores the code
as-is while `PublicStreamServerKeysLive` does `String.to_integer/1` —
`put_change` does not cast, as before. Alternative considered: hard-coded
`send(self(), {:picked, id, value})` — rejected, it leaks message-shape
decisions into the component and breaks if the component is ever nested
inside another component (where `send_update/2` is needed instead).

### Events live inside the component

`"toggle"`, `"close"` (on `phx-click-away` on the `.relative` wrapper),
`"pick"` (`phx-value-value`), and `"filter"` are all `handle_event`s on the
component with `phx-target={@myself}` on each bound element. The parent
keeps zero dropdown events — only its `handle_info` for the callback.

### Search via injected options function

The component stores `query` and a `visible_options` assign; the options to
show are computed as `options_fun.(query)` inside `update`/`handle_event` —
**synchronously, in the same event that changes the query**, so the query
and the filtered list are never rendered out of sync. When the parent
passed a plain list, the normalized fun filters it by case-insensitive
substring match on the label; when it passed a `query -> list` fun, the
fun supplies the filtered list itself (`&Countries.options_for_select/1`),
so the parent keeps full control of filtering semantics without any
message plumbing. `phx-debounce="200"` and `phx-mounted={JS.focus()}` are
kept on the search input; the fun must be a cheap pure lookup since it runs
on each debounced keystroke.

Alternatives considered: (a) an `on_search` callback where the parent does
`send(self(), ...)` → `handle_info` → `send_update` with new options — the
literal "unifying communication" pattern, rejected because it adds
`handle_info`/`send_update` boilerplate to every host LiveView and renders
the stale option list for one cycle before the update lands; (b) only
list + in-component filtering — rejected because it forces the parent to
materialize options eagerly and can't accommodate remote/DB filtering. If
filtering ever needs true async (remote API), `send_update`-driven options
can be added later without breaking this API.

### Hidden input + errors inside the component

The hidden `<input>` (id/name/value from `@field`) and the error list are
rendered by the component inside its single-root `div.fieldset` — the
whole existing `<div class="fieldset mb-2">…</div>` block moves in. LiveView
renders the component inline within the parent `<.form>` DOM, so the input
still submits with `phx-change`/`phx-submit` normally. Errors use
`Phoenix.Component.used_input?/1` + `CoreComponents.translate_error/1`.

## Risks / Trade-offs

- [LiveComponent adds per-component diff/state overhead] → Negligible here
  (one per form); and it is the only clean way to own open/search state
  without a JS hook, per Phoenix guidance.
- [Component inside `<.form>`: hidden input must survive LV diffs] →
  Verified by existing tests asserting
  `input[name="..."][value="..."]` after pick; keep those assertions.
- [Parent forgetting `handle_info` = silent no-op on pick] → Documented in
  the component moduledoc and the rewritten skill; tests on both pages
  cover it.
- [Options fun is expensive or stateful] → Documented contract: the fun
  must be a cheap pure lookup; it runs on every open and debounced
  keystroke. Truly async option loading stays out of scope — a
  `send_update`-driven `on_search` variant can be added without breaking
  the API.
- [User labeled the stream-servers-page dropdown "stream server dropdown"]
  → Recorded assumption: it is the country dropdown (the only one there).

## Migration Plan

Pure refactor; no data or API migration. Roll out in one deploy: component
first, then swap the two call sites, run `dotenv -e .env.test mix precommit`.
Rollback is a git revert — no persistent state involved.
