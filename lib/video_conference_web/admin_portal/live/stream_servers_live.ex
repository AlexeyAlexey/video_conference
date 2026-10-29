defmodule VideoConferenceWeb.AdminPortal.StreamServersLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.{Countries, StreamServer}
  alias VideoConferenceWeb.AdminPortal.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Stream Servers")}
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

  def handle_info({:country_picked, code}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:country, code)
      |> Map.update!(:errors, &Keyword.delete(&1, :country))

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
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
