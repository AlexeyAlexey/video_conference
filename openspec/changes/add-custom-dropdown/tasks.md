# Tasks

## 1. DropdownComponent

- [ ] 1.1 Create `lib/video_conference_web/admin_portal/dropdown_component.ex`
  (`VideoConferenceWeb.AdminPortal.DropdownComponent`,
  `use VideoConferenceWeb, :live_component`) implementing the API and DOM
  ids from design.md: `id` (DOM-id prefix), `label`, `field`, `options`
  `{label, value}` tuples, `placeholder`, optional `empty_label`,
  `searchable`, `search_placeholder`, required `on_change` callback. Move
  the `div.fieldset` block (button + listbox + hidden input + error list)
  in as the component's single root; `options` accepts a `{label, value}`
  list **or** an arity-1 `query -> list` fun (normalized internally to a
  fun). Verify it compiles with `mix compile --warnings-as-errors`.
- [ ] 1.2 Add component `handle_event`s `"toggle"`, `"close"`
  (`phx-click-away`), `"pick"` (`phx-value-value`, invokes
  `@on_change.(value)` and closes), and `"filter"` (searchable only), all
  bound with `phx-target={@myself}`; `visible_options` is recomputed as
  `options_fun.(query)` inside `update`/`"filter"`/`"toggle"` — for list
  options a case-insensitive substring match on the label, for fun options
  the fun's own result. Verify events are exercised by the tests in 1.3.
- [ ] 1.3 Add component tests
  `test/video_conference_web/admin_portal/dropdown_component_test.exs`
  driven through a minimal host LiveView (or one of the migrated pages):
  open on button click, close on `phx-click-away`, pick invokes the
  callback and closes, `aria-expanded`/`aria-selected`/`role` attributes,
  hidden input carries `field` name+value, inline error rendering,
  search filters options (cover both a static list and an
  `options={fn query -> ... end}` host), `empty_label` row clears the
  value. Verify with
  `dotenv -e .env.test mix test test/video_conference_web/admin_portal/dropdown_component_test.exs`.

## 2. Migrate PublicStreamServerKeysLive

- [ ] 2.1 In `public_stream_server_keys_live.ex` replace the
  `div#stream-server-field` block with
  `<.live_component module={DropdownComponent} id="stream-server" ...>`
  passing `options` as `{server.name, server.id}` tuples and
  `on_change={fn id -> send(self(), {:stream_server_picked, id}) end}`;
  keep every existing DOM id (`stream-server-field`,
  `stream-server-dropdown-button`, `stream-server-option-<id>`). Verify by
  rendering the form manually in `iex` or via test.
- [ ] 2.2 Remove `server_open` assign and the
  `toggle_server_dropdown`/`close_server_dropdown`/`pick_server`
  `handle_event`s; add `handle_info({:stream_server_picked, id}, socket)`
  that `put_change(:stream_server_id, String.to_integer(id))`, deletes the
  field error, and re-assigns the form; remove now-unused
  `stream_server_label`/`stream_server_errors` helpers. Verify the module
  has no dropdown remnants and compiles.
- [ ] 2.3 Verify `dotenv -e .env.test mix test
  test/video_conference_web/admin_portal/live/public_stream_server_keys_live_test.exs`
  passes unchanged (dropdown ids and behavior preserved).

## 3. Migrate StreamServersLive

- [ ] 3.1 In `stream_servers_live.ex` replace the `div#country-field`
  block with the component using `id="country"`, `searchable`,
  `empty_label="None"`, `options={&Countries.options_for_select/1}` (fun —
  remove the `country_query`/`country_open`/`country_options` assigns and
  all `options_for_select/0,1` refresh logic), `on_change={fn code ->
  send(self(), {:country_picked, code}) end}`; keep ids
  `country-dropdown-button`, `country-search`, `country-option-none`,
  `country-option-<code>`.
- [ ] 3.2 Remove `toggle_country_dropdown`/`close_country_dropdown`/
  `pick_country`/`filter_countries` `handle_event`s and the
  `country_open`/`country_query` assigns; add
  `handle_info({:country_picked, code}, socket)` (put_change `:country`,
  delete field error, re-assign form); drop unused helpers. Verify the
  module compiles with no leftovers.
- [ ] 3.3 Verify `dotenv -e .env.test mix test
  test/video_conference_web/admin_portal/live/stream_servers_live_test.exs`
  passes unchanged.

## 4. Docs and final verification

- [ ] 4.1 Rewrite `.devin/skills/liveview-custom-dropdown/SKILL.md` around
  `DropdownComponent`: why (no native `<select>`), the assign API,
  `on_change` callback pattern, `handle_info` recipe (incl. casting and the
  error-clearing pitfall), DOM-id convention, testing recipe. Verify the
  doc's snippets match the shipped component.
- [ ] 4.2 Run `dotenv -e .env.test mix precommit` and fix any warnings or
  failures.
