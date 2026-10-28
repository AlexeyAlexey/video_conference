---
name: liveview-custom-dropdown
description: How to build dropdown/select fields in this Phoenix LiveView admin portal. Use whenever a form needs a dropdown — never use a native <select>, because in Chrome mobile/responsive mode its option popup renders detached at a wrong position on the page.
---

# Custom LiveView dropdown (never a native `<select>`)

## Why

Native `<select>` elements are broken in this app's UI: in Chrome's mobile /
responsive device mode the browser renders the option popup detached, at an
unrelated position on the page. The country picker in
`StreamServersLive` (change `2026-10-27-add-stream-servers-list-to-admin-portal`)
hit this first; the stream-server picker in `PublicStreamServerKeysLive` hit it
again. Always use the custom button + listbox pattern below.

## Reference implementations

- `lib/video_conference_web/admin_portal/live/stream_servers_live.ex` — country
  dropdown **with a search filter** (use when the option list is long).
- `lib/video_conference_web/admin_portal/live/public_stream_server_keys_live.ex` —
  stream server dropdown **without search** (use for short lists).

## The pattern

### Assigns

```elixir
def mount(_params, _session, socket) do
  {:ok, assign(socket, <field>_open: false)}
end
```

### Events

```elixir
def handle_event("toggle_<field>_dropdown", _params, socket) do
  {:noreply, assign(socket, :<field>_open, not socket.assigns.<field>_open)}
end

def handle_event("close_<field>_dropdown", _params, socket) do
  {:noreply, assign(socket, :<field>_open, false)}
end

def handle_event("pick_<field>", %{"id" => id}, socket) do
  changeset =
    socket.assigns.form.source
    |> Ecto.Changeset.put_change(:<field>, id)
    |> Map.update!(:errors, &Keyword.delete(&1, :<field>))

  {:noreply, socket |> assign_form(changeset) |> assign(:<field>_open, false)}
end
```

Two non-obvious steps are required in `pick_<field>`:

- Cast `id` to the field's type first (`String.to_integer(id)` for
  integer/belongs_to fields) — `put_change` does not cast.
- **`put_change/3` does not remove an existing validation error.** If the
  form was already validated (e.g. the user typed in another field first),
  the field's `can't be blank` stays rendered even though the value is set.
  `Keyword.delete` on `changeset.errors` clears it.

### Markup (inside `<.form>`)

```heex
<div class="fieldset mb-2" id="<field>-field">
  <span class="label mb-1"><Label></span>
  <div class="relative" phx-click-away="close_<field>_dropdown">
    <button
      type="button"
      id="<field>-dropdown-button"
      phx-click="toggle_<field>_dropdown"
      class="input w-full cursor-pointer text-left"
      aria-haspopup="listbox"
      aria-expanded={to_string(@<field>_open)}
    >
      <span class="flex w-full items-center justify-between gap-2">
        <span>{<label_fn>(@form[:<field>].value)}</span>
        <.icon name="hero-chevron-down" class="size-4 opacity-60" />
      </span>
    </button>
    <div
      :if={@<field>_open}
      id="<field>-dropdown"
      class="absolute inset-x-0 z-50 mt-1 max-h-64 overflow-y-auto rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
      role="listbox"
    >
      <ul>
        <li :for={opt <- @<options>}>
          <button
            type="button"
            id={"<field>-option-#{opt.id}"}
            phx-click="pick_<field>"
            phx-value-id={opt.id}
            role="option"
            aria-selected={to_string(to_string(@form[:<field>].value) == to_string(opt.id))}
            class={[
              "block w-full rounded px-2 py-1 text-left hover:bg-base-200",
              to_string(@form[:<field>].value) == to_string(opt.id) &&
                "bg-base-200 font-semibold"
            ]}
          >
            {opt.name}
          </button>
        </li>
      </ul>
    </div>
  </div>
  <input
    type="hidden"
    id={@form[:<field>].id}
    name={@form[:<field>].name}
    value={@form[:<field>].value}
  />
  <p :for={msg <- <field>_errors(@form)} class="mt-1.5 flex items-center gap-2 text-sm text-error">
    <.icon name="hero-exclamation-circle" class="size-5" />{msg}
  </p>
</div>
```

### Error helper

```elixir
defp <field>_errors(form) do
  field = form[:<field>]

  if Phoenix.Component.used_input?(field),
    do: Enum.map(field.errors, &translate_error/1),
    else: []
end
```

## Details that matter

- **`w-full` on the inner flex span is required.** Inside the daisyUI
  `input`-styled button the span can shrink to content width, leaving
  `justify-between` with no room — the chevron then sits next to the label
  instead of flush right.
- The hidden `<input>` lives **inside `<.form>`** so `phx-change`/`phx-submit`
  submit the picked value normally.
- `phx-click-away` on the `.relative` wrapper closes the listbox on outside
  clicks; options close it via the pick event.
- For long option lists, copy the searchable variant from
  `StreamServersLive`: a `phx-debounce="200"` filter input inside the listbox
  plus a `*_query`/`*_options` assign pair. Always include a "None"/empty
  option when the field is optional (see `country-option-none`).

## Testing

- LiveViewTest **cannot forge hidden-input values**
  (`value for hidden ... must be one of [...]`). Drive the dropdown like a
  user instead:

  ```elixir
  lv |> element("#<field>-dropdown-button") |> render_click()
  lv |> element(~s|#<field>-dropdown button[phx-value-id="#{id}"]|) |> render_click()
  ```

- Assert the hidden input got the value:
  `has_element?(lv, ~s|input[name="<schema>[<field>]"][value="#{id}"]|)`.
