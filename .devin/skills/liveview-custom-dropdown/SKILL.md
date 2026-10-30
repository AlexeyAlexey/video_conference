---
name: liveview-custom-dropdown
description: How to add dropdown/select fields in this Phoenix LiveView app using the shared DropdownComponent. Use whenever a form needs a dropdown — never use a native <select>, because in Chrome mobile/responsive mode its option popup renders detached at a wrong position on the page.
---

# Custom LiveView dropdown (never a native `<select>`)

## Why

Native `<select>` elements are broken in this app's UI: in Chrome's mobile /
responsive device mode the browser renders the option popup detached, at an
unrelated position on the page. Always use
`VideoConferenceWeb.DropdownComponent`
(`lib/video_conference_web/components/dropdown_component.ex`) — a stateful
LiveComponent that renders a daisyUI button+listbox, owns its open/search
state, binds the picked value to the enclosing form via a hidden input, and
supports an optional filter and an empty ("None") choice.

## Reference implementations

- `lib/video_conference_web/admin_portal/live/public_stream_server_keys_live.ex` —
  stream server dropdown, static `{label, value}` list, `value_key="id"`,
  no search, no empty choice.
- `lib/video_conference_web/admin_portal/live/stream_servers_live.ex` —
  country dropdown, `options={&Countries.options_for_select/1}` fun,
  `searchable`, `empty_label="None"`, `value_key="code"`.

## Usage

Render the component **inside `<.form>`** — its hidden input submits the
picked value through the form's normal `phx-change`/`phx-submit` flow:

```heex
<.live_component
  module={DropdownComponent}
  id="stream-server"                        # also the DOM-id prefix
  label="Stream server"
  field={@form[:stream_server_id]}          # Phoenix.HTML.FormField
  options={for s <- @stream_servers, do: {s.name, s.id}}
  placeholder="Choose a stream server"
  value_key="id"                            # renders phx-value-id on options
  on_change={fn id -> send(self(), {:stream_server_picked, id}) end}
/>
```

Searchable variant with an empty choice (long option lists):

```heex
<.live_component
  module={DropdownComponent}
  id="country"
  label="Country"
  field={@form[:country]}
  options={&Countries.options_for_select/1}
  searchable
  empty_label="None"
  search_placeholder="Type to filter countries"
  value_key="code"
  on_change={fn code -> send(self(), {:country_picked, code}) end}
/>
```

### Assigns

| Assign | Required | Notes |
|--------|----------|-------|
| `id` | yes | Component id + DOM-id prefix (see DOM ids below) |
| `label` | yes | Field label |
| `field` | yes | `@form[:field]` — drives hidden input id/name/value |
| `options` | yes | `{label, value}` list **or** arity-1 `query -> list` fun |
| `on_change` | yes | Arity-1 callback invoked with the picked value (a string) |
| `placeholder` | no | Button text when nothing selected (default `""`) |
| `empty_label` | no | When set, renders an empty choice first and is the empty-value button label |
| `searchable` | no | Renders a debounced filter input (default `false`) |
| `search_placeholder` | no | Filter input placeholder (default `"Type to filter"`) |
| `value_key` | no | `phx-value-*` key on option buttons (default `"value"`) |

`options` details:

- A **list** is filtered internally by case-insensitive substring match on
  the label — only relevant when `searchable`.
- A **fun** `query -> list` supplies the filtered list itself
  (`&Countries.options_for_select/1`), so the caller controls filtering
  semantics. It must be a cheap pure lookup — it runs on every open and on
  each debounced keystroke — and `fun.("")` must return all options (it is
  also called to resolve the selected value's label).

## Parent side: `on_change` + `handle_info`

The component never stores the selected value — the parent owns it. Pick
emits the raw string through `on_change`; the standard recipe is to send
the parent a message and apply it in `handle_info`:

```elixir
def handle_info({:stream_server_picked, id}, socket) do
  changeset =
    socket.assigns.form.source
    |> Ecto.Changeset.put_change(:stream_server_id, String.to_integer(id))
    |> Map.update!(:errors, &Keyword.delete(&1, :stream_server_id))

  {:noreply, assign_form(socket, changeset)}
end
```

Two non-obvious steps are required:

- **Cast the value yourself** (`String.to_integer(id)` for integer/belongs_to
  fields) — `put_change/3` does not cast, and the component emits strings.
- **`put_change/3` does not remove an existing validation error.** If the
  form was already validated, the field's `can't be blank` stays rendered
  even though the value is set. `Keyword.delete` on `changeset.errors`
  clears it.

## DOM-id convention

Every rendered id derives from the component `id` (`#{id}` = `id` below):

- `#{id}-field` — outer `div.fieldset`
- `#{id}-dropdown-button` — the toggle button
- `#{id}-dropdown` — the open listbox (`role="listbox"`)
- `#{id}-search` — filter input (`name="#{id}_search"`, searchable only)
- `#{id}-option-none` — empty choice (when `empty_label` set)
- `#{id}-option-#{value}` — each real option (`role="option"`)

All events are handled inside the component with `phx-target={@myself}` —
the parent keeps **zero** dropdown assigns or `handle_event`s.

## Testing

- LiveViewTest **cannot forge hidden-input values**
  (`value for hidden ... must be one of [...]`). Drive the dropdown like a
  user instead:

  ```elixir
  lv |> element("#country-dropdown-button") |> render_click()
  lv |> element(~s|#country-dropdown button[phx-value-code="de"]|) |> render_click()
  ```

- Assert the hidden input got the value:
  `has_element?(lv, ~s|input[name="stream_server[country]"][value="de"]|)`.
- `phx-click-away` is **not** simulated by LiveViewTest — assert the
  `[phx-click-away="close"]` binding exists, and exercise the component's
  `"close"` event with a test element like
  `<button phx-click="close" phx-target="#<id>-field">` (the test DOM
  resolves the selector to the component via `data-phx-component`).
- Component-level coverage lives in
  `test/video_conference_web/components/dropdown_component_test.exs`,
  which drives the component through a minimal host LiveView mounted with
  `live_isolated/3`.
