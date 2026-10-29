defmodule VideoConferenceWeb.AdminPortal.DropdownComponent do
  @moduledoc """
  Reusable custom dropdown/select form control for admin portal forms.

  Never a native `<select>` element: in Chrome's mobile/responsive mode the
  native option popup renders detached at a wrong position on the page.

  ## Usage

      <.live_component
        module={DropdownComponent}
        id="stream-server"
        label="Stream server"
        field={@form[:stream_server_id]}
        options={for s <- @stream_servers, do: {s.name, s.id}}
        placeholder="Choose a stream server"
        on_change={fn id -> send(self(), {:stream_server_picked, id}) end}
      />

  ## Assigns

    * `id` (required) — component id, also the DOM-id prefix. The rendered
      ids are `"\#{id}-field"`, `"\#{id}-dropdown-button"`, `"\#{id}-dropdown"`,
      `"\#{id}-search"` (searchable only, `name="\#{id}_search"`),
      `"\#{id}-option-none"` (empty choice), and `"\#{id}-option-\#{value}"`.
    * `label` (required) — the field label.
    * `field` (required) — a `Phoenix.HTML.FormField`, e.g.
      `@form[:stream_server_id]`. Its `id`/`name`/`value` drive the hidden
      input that submits the picked value through the enclosing form.
    * `options` (required) — `{label, value}` tuples, either a list or an
      arity-1 `query -> list` function. A list is filtered internally by
      case-insensitive substring match on the label; a function is invoked
      with the current query and must return the filtered list itself. The
      function must be a cheap pure lookup — it runs on every open and on
      each debounced keystroke — and `fun.("")` must return all options.
    * `placeholder` — button text when nothing is selected (default `""`).
    * `empty_label` — when set, renders an extra "empty" option (e.g.
      `"None"`) before the real options, and is also used as the button text
      while the field value is empty. Picking it delivers `""`.
    * `searchable` — when `true`, renders a filter input inside the open
      listbox (default `false`).
    * `search_placeholder` — placeholder for the filter input (default
      `"Type to filter"`).
    * `value_key` — the `phx-value-*` key carried by each option button and
      read back from the `"pick"` event params (default `"value"`).
    * `on_change` (required) — arity-1 callback invoked with the picked
      value (a string). Per the "Unifying LiveView and LiveComponent
      communication" pattern, the callback decides how the value reaches
      the parent — typically `fn value -> send(self(), {:picked, value}) end`
      handled in the parent's `handle_info`. The parent owns the selected
      value; the component never stores a copy. Casting is the parent's job
      (`put_change/3` does not cast — e.g. `String.to_integer/1` for integer
      fields). Note `put_change/3` also does not clear an existing
      validation error on the field; delete it from `changeset.errors`.

  ## Parent recipe

      def handle_info({:picked, value}, socket) do
        changeset =
          socket.assigns.form.source
          |> Ecto.Changeset.put_change(:field, value)
          |> Map.update!(:errors, &Keyword.delete(&1, :field))

        {:noreply, assign_form(socket, changeset)}
      end
  """
  use VideoConferenceWeb, :live_component

  @impl true
  def update(assigns, socket) do
    unless is_function(assigns[:on_change], 1) do
      raise ArgumentError,
            "DropdownComponent requires an :on_change assign, an arity-1 " <>
              "callback invoked with the picked value"
    end

    options_fun = normalize_options(assigns.options)

    socket =
      socket
      |> assign(assigns)
      |> assign(:options_fun, options_fun)
      |> assign_new(:open, fn -> false end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:searchable, fn -> false end)
      |> assign_new(:empty_label, fn -> nil end)
      |> assign_new(:value_key, fn -> "value" end)
      |> assign_new(:placeholder, fn -> "" end)
      |> assign_new(:search_placeholder, fn -> "Type to filter" end)

    {:ok, assign(socket, :visible_options, options_fun.(socket.assigns.query))}
  end

  @impl true
  def handle_event("toggle", _params, socket) do
    open = not socket.assigns.open
    query = if open, do: "", else: socket.assigns.query

    {:noreply,
     assign(socket,
       open: open,
       query: query,
       visible_options: socket.assigns.options_fun.(query)
     )}
  end

  def handle_event("close", _params, socket) do
    {:noreply, assign(socket, :open, false)}
  end

  def handle_event("pick", params, socket) do
    value = Map.fetch!(params, socket.assigns.value_key)
    socket.assigns.on_change.(value)

    {:noreply, assign(socket, open: false, query: "")}
  end

  def handle_event("filter", params, socket) do
    query = Map.get(params, "#{socket.assigns.id}_search", "")

    {:noreply,
     assign(socket,
       query: query,
       visible_options: socket.assigns.options_fun.(query)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fieldset mb-2" id={"#{@id}-field"}>
      <span class="label mb-1">{@label}</span>
      <div class="relative" phx-click-away="close" phx-target={@myself}>
        <button
          type="button"
          id={"#{@id}-dropdown-button"}
          phx-click="toggle"
          phx-target={@myself}
          class="input w-full cursor-pointer text-left"
          aria-haspopup="listbox"
          aria-expanded={to_string(@open)}
        >
          <span class="flex w-full items-center justify-between gap-2">
            <span>{selected_label(assigns)}</span>
            <.icon name="hero-chevron-down" class="size-4 opacity-60" />
          </span>
        </button>
        <div
          :if={@open}
          id={"#{@id}-dropdown"}
          class="absolute inset-x-0 z-50 mt-1 max-h-64 overflow-y-auto rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
          role="listbox"
        >
          <input
            :if={@searchable}
            type="text"
            id={"#{@id}-search"}
            name={"#{@id}_search"}
            value={@query}
            placeholder={@search_placeholder}
            phx-change="filter"
            phx-target={@myself}
            phx-debounce="200"
            phx-mounted={JS.focus()}
            autocomplete="off"
            class="input input-sm mb-1 w-full"
          />
          <ul>
            <li :if={@empty_label}>
              <button
                type="button"
                id={"#{@id}-option-none"}
                phx-click="pick"
                phx-target={@myself}
                {pick_attrs(assigns, "")}
                role="option"
                aria-selected={to_string(@field.value in [nil, ""])}
                class={[
                  "block w-full rounded px-2 py-1 text-left hover:bg-base-200",
                  @field.value in [nil, ""] && "bg-base-200 font-semibold"
                ]}
              >
                {@empty_label}
              </button>
            </li>
            <li :for={{label, value} <- @visible_options}>
              <button
                type="button"
                id={"#{@id}-option-#{value}"}
                phx-click="pick"
                phx-target={@myself}
                {pick_attrs(assigns, value)}
                role="option"
                aria-selected={to_string(to_string(@field.value) == to_string(value))}
                class={[
                  "block w-full rounded px-2 py-1 text-left hover:bg-base-200",
                  to_string(@field.value) == to_string(value) && "bg-base-200 font-semibold"
                ]}
              >
                {label}
              </button>
            </li>
          </ul>
        </div>
      </div>
      <input type="hidden" id={@field.id} name={@field.name} value={@field.value} />
      <p
        :for={msg <- field_errors(assigns)}
        class="mt-1.5 flex items-center gap-2 text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />{msg}
      </p>
    </div>
    """
  end

  defp normalize_options(options) when is_function(options, 1), do: options

  defp normalize_options(options) when is_list(options) do
    fn query ->
      query = String.downcase(String.trim(to_string(query)))

      Enum.filter(options, fn {label, _value} ->
        query == "" or String.contains?(String.downcase(to_string(label)), query)
      end)
    end
  end

  defp selected_label(assigns) do
    value = assigns.field.value

    if value in [nil, ""] do
      assigns.empty_label || assigns.placeholder
    else
      case Enum.find(assigns.options_fun.(""), fn {_label, option_value} ->
             to_string(option_value) == to_string(value)
           end) do
        {label, _value} -> label
        nil -> to_string(value)
      end
    end
  end

  defp pick_attrs(assigns, value) do
    %{"phx-value-#{assigns.value_key}" => to_string(value)}
  end

  defp field_errors(assigns) do
    if Phoenix.Component.used_input?(assigns.field),
      do: Enum.map(assigns.field.errors, &translate_error/1),
      else: []
  end
end
