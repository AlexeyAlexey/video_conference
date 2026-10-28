defmodule VideoConferenceWeb.AdminPortal.StreamServersLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.{Countries, StreamServer}

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Stream Servers",
       country_open: false,
       country_query: "",
       country_options: Countries.options_for_select()
     )}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:stream_servers, StreamServers.list_stream_servers())
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Stream Servers", stream_server: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    stream_server = %StreamServer{}

    socket
    |> assign(page_title: "New Stream Server", stream_server: stream_server)
    |> assign_form(StreamServers.change_stream_server(stream_server))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    stream_server = StreamServers.get_stream_server!(id)

    socket
    |> assign(page_title: "Edit #{stream_server.name}", stream_server: stream_server)
    |> assign_form(StreamServers.change_stream_server(stream_server))
  end

  def handle_event("validate", %{"stream_server" => stream_server_params}, socket) do
    changeset =
      socket.assigns.stream_server
      |> StreamServers.change_stream_server(stream_server_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"stream_server" => stream_server_params}, socket) do
    save_stream_server(socket, socket.assigns.live_action, stream_server_params)
  end

  def handle_event("toggle_country_dropdown", _params, socket) do
    open = not socket.assigns.country_open

    socket =
      if open do
        assign(socket,
          country_query: "",
          country_options: Countries.options_for_select()
        )
      else
        socket
      end

    {:noreply, assign(socket, :country_open, open)}
  end

  def handle_event("close_country_dropdown", _params, socket) do
    {:noreply, assign(socket, :country_open, false)}
  end

  def handle_event("pick_country", %{"code" => code}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:country, code)
      |> Map.update!(:errors, &Keyword.delete(&1, :country))

    {:noreply,
     socket
     |> assign_form(changeset)
     |> assign(
       country_open: false,
       country_query: "",
       country_options: Countries.options_for_select()
     )}
  end

  def handle_event("filter_countries", %{"country_search" => query}, socket) do
    {:noreply,
     assign(socket,
       country_query: query,
       country_options: Countries.options_for_select(query)
     )}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    stream_server = StreamServers.get_stream_server!(id)

    case StreamServers.delete_stream_server(stream_server) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server removed")
         |> assign(:stream_servers, StreamServers.list_stream_servers())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The stream server cannot be removed")}
    end
  end

  defp save_stream_server(socket, :new, stream_server_params) do
    case StreamServers.create_stream_server(stream_server_params) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server added")
         |> push_patch(to: "/admin/stream-servers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_stream_server(socket, :edit, stream_server_params) do
    case StreamServers.update_stream_server(socket.assigns.stream_server, stream_server_params) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server updated")
         |> push_patch(to: "/admin/stream-servers")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp country_label(code) when is_binary(code) and code != "",
    do: Countries.option_label(code)

  defp country_label(_code), do: "None"

  defp country_errors(form) do
    field = form[:country]

    if Phoenix.Component.used_input?(field),
      do: Enum.map(field.errors, &translate_error/1),
      else: []
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full px-2 sm:px-0">
        <.header>
          Stream Servers
          <:subtitle>HTTP/3 servers available to carry participant streams</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch="/admin/stream-servers/new"
              id="add-stream-server-link"
              class="btn btn-primary btn-sm"
            >
              Add server
            </.link>
          </:actions>
        </.header>

        <div
          :if={@live_action in [:new, :edit]}
          id="stream-server-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {if @live_action == :new, do: "Add stream server", else: "Edit stream server"}
            </h2>
            <.form
              for={@form}
              id="stream-server-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-2"
              autocomplete="off"
              novalidate
            >
              <.input field={@form[:name]} label="Name" required autocomplete="off" />
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                autocomplete="off"
              />
              <.input
                field={@form[:host]}
                label="Host"
                placeholder="ip, domain, or ip:port"
                autocomplete="off"
              />
              <div class="fieldset mb-2" id="country-field">
                <span class="label mb-1">Country</span>
                <div class="relative" phx-click-away="close_country_dropdown">
                  <button
                    type="button"
                    id="country-dropdown-button"
                    phx-click="toggle_country_dropdown"
                    class="input w-full cursor-pointer text-left"
                    aria-haspopup="listbox"
                    aria-expanded={to_string(@country_open)}
                  >
                    <span class="flex w-full items-center justify-between gap-2">
                      <span>{country_label(@form[:country].value)}</span>
                      <.icon name="hero-chevron-down" class="size-4 opacity-60" />
                    </span>
                  </button>
                  <div
                    :if={@country_open}
                    id="country-dropdown"
                    class="absolute inset-x-0 z-50 mt-1 max-h-64 overflow-y-auto rounded-box border border-base-300 bg-base-100 p-2 shadow-lg"
                    role="listbox"
                  >
                    <input
                      type="text"
                      id="country-search"
                      name="country_search"
                      value={@country_query}
                      placeholder="Type to filter countries"
                      phx-change="filter_countries"
                      phx-debounce="200"
                      phx-mounted={JS.focus()}
                      autocomplete="off"
                      class="input input-sm mb-1 w-full"
                    />
                    <ul>
                      <li>
                        <button
                          type="button"
                          id="country-option-none"
                          phx-click="pick_country"
                          phx-value-code=""
                          role="option"
                          aria-selected={to_string(@form[:country].value in [nil, ""])}
                          class={[
                            "block w-full rounded px-2 py-1 text-left hover:bg-base-200",
                            @form[:country].value in [nil, ""] && "bg-base-200 font-semibold"
                          ]}
                        >
                          None
                        </button>
                      </li>
                      <li :for={{label, code} <- @country_options}>
                        <button
                          type="button"
                          id={"country-option-#{code}"}
                          phx-click="pick_country"
                          phx-value-code={code}
                          role="option"
                          aria-selected={to_string(@form[:country].value == code)}
                          class={[
                            "block w-full rounded px-2 py-1 text-left hover:bg-base-200",
                            @form[:country].value == code && "bg-base-200 font-semibold"
                          ]}
                        >
                          {label}
                        </button>
                      </li>
                    </ul>
                  </div>
                </div>
                <input
                  type="hidden"
                  id={@form[:country].id}
                  name={@form[:country].name}
                  value={@form[:country].value}
                />
                <p
                  :for={msg <- country_errors(@form)}
                  class="mt-1.5 flex items-center gap-2 text-sm text-error"
                >
                  <.icon name="hero-exclamation-circle" class="size-5" />{msg}
                </p>
              </div>
              <.input
                field={@form[:cert_hash]}
                label="Certificate hash"
                autocomplete="off"
              />
              <.input field={@form[:third_party]} type="checkbox" label="Third-party" />
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch="/admin/stream-servers"
                  id="cancel-stream-server-form"
                  class="btn btn-ghost"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table id="stream-servers-table" class="table table-sm sm:table-md">
            <thead>
              <tr>
                <th>Name</th>
                <th>Host</th>
                <th>Country</th>
                <th>Third-party</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={server <- @stream_servers} id={"stream-server-row-#{server.id}"}>
                <td>
                  {server.name}
                </td>
                <td>{server.host}</td>
                <td>{Countries.flag(server.country)}</td>
                <td>{if server.third_party, do: "Yes", else: "No"}</td>
                <td class="text-right whitespace-nowrap">
                  <.link
                    patch={"/admin/stream-servers/#{server.id}/edit"}
                    id={"edit-stream-server-#{server.id}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Edit
                  </.link>
                  <button
                    id={"delete-stream-server-#{server.id}"}
                    type="button"
                    phx-click="delete"
                    phx-value-id={server.id}
                    data-confirm={"Remove #{server.name}?"}
                    class="btn btn-ghost btn-xs text-error"
                  >
                    Remove
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
