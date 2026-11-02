defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServersLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer
  alias VideoConference.StreamServers.Countries
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Stream Servers")}
  end

  def handle_params(params, _uri, socket) do
    application_filter = params["application_id"] || ""

    socket =
      socket
      |> assign(:applications, Applications.list_applications())
      |> assign(:application_filter, application_filter)
      |> assign(:filter_form, filter_form(application_filter))
      |> assign(
        :stream_servers,
        StreamServers.list_stream_servers(application_id: application_filter)
      )
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp filter_form(application_filter) do
    to_form(%{"application_id" => application_filter}, as: :filter)
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

  defp apply_action(socket, :assign, %{"id" => id}) do
    stream_server = StreamServers.get_stream_server!(id)

    assign(socket,
      page_title: "Assign #{stream_server.name}",
      stream_server: stream_server,
      assigned_application_ids: Enum.map(stream_server.applications, & &1.id),
      form: nil
    )
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

  def handle_event("save_assign", params, socket) do
    application_ids =
      params
      |> Map.get("application_ids", [])
      |> Enum.reject(&(&1 == ""))

    {:ok, _stream_server} =
      StreamServers.assign_applications(socket.assigns.stream_server, application_ids)

    {:noreply,
     socket
     |> put_flash(:info, "Assignments updated")
     |> push_patch(to: index_path(socket.assigns.application_filter))}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    stream_server = StreamServers.get_stream_server!(id)

    case StreamServers.delete_stream_server(stream_server) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server removed")
         |> assign(
           :stream_servers,
           StreamServers.list_stream_servers(application_id: socket.assigns.application_filter)
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The stream server cannot be removed")}
    end
  end

  def handle_info({:country_picked, code}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:country, code)
      |> Map.update!(:errors, &Keyword.delete(&1, :country))

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp save_stream_server(socket, :new, stream_server_params) do
    case StreamServers.create_stream_server(stream_server_params) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server added")
         |> push_patch(to: index_path(socket.assigns.application_filter))}

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
         |> push_patch(to: index_path(socket.assigns.application_filter))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp index_path(application_filter) when application_filter in [nil, ""],
    do: "/stream-server-admin/stream-servers"

  defp index_path(application_filter),
    do: "/stream-server-admin/stream-servers?application_id=#{application_filter}"

  defp filter_query(application_filter) when application_filter in [nil, ""], do: ""
  defp filter_query(application_filter), do: "?application_id=#{application_filter}"

  def render(assigns) do
    ~H"""
    <Layouts.stream_server_admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full px-2 sm:px-0">
        <.header>
          Stream Servers
          <:subtitle>Servers available to carry application streams</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch={"/stream-server-admin/stream-servers/new" <> filter_query(@application_filter)}
              id="add-stream-server-link"
              class="btn btn-primary btn-sm"
            >
              Add server
            </.link>
          </:actions>
        </.header>

        <div :if={@live_action == :index} class="mb-4 max-w-xs">
          <.form
            for={@filter_form}
            id="application-filter-form"
            onsubmit="event.preventDefault()"
          >
            <.live_component
              module={DropdownComponent}
              id="application-filter"
              label="Filter by application"
              field={@filter_form[:application_id]}
              options={
                [{"Unassigned", "unassigned"}] ++
                  for(application <- @applications, do: {application.name, application.id})
              }
              empty_label="All servers"
              searchable
              search_placeholder="Type to filter applications"
              value_key="id"
              on_change={fn id -> send(self(), {:filter_picked, id}) end}
            />
          </.form>
        </div>

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
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch={index_path(@application_filter)}
                  id="cancel-stream-server-form"
                  class="btn btn-ghost"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <div :if={@live_action == :assign} id="assign-card" class="card bg-base-200 mb-6">
          <div class="card-body">
            <h2 class="card-title">Assign applications to {@stream_server.name}</h2>
            <p
              :if={@applications == []}
              id="no-applications-to-assign"
              class="text-sm opacity-60"
            >
              No applications yet
            </p>
            <form
              :if={@applications != []}
              id="assign-form"
              phx-submit="save_assign"
              class="space-y-2"
            >
              <input type="hidden" name="application_ids[]" value="" />
              <label
                :for={application <- @applications}
                class="flex items-center gap-2 py-1"
              >
                <input
                  type="checkbox"
                  id={"assign-application-#{application.id}"}
                  name="application_ids[]"
                  value={application.id}
                  checked={application.id in @assigned_application_ids}
                  class="checkbox checkbox-sm"
                />
                <span>{application.name}</span>
              </label>
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch={index_path(@application_filter)}
                  id="cancel-assign-form"
                  class="btn btn-ghost"
                >
                  Cancel
                </.link>
              </div>
            </form>
            <div :if={@applications == []} class="flex gap-2 pt-2">
              <.link
                patch={index_path(@application_filter)}
                id="cancel-assign-empty"
                class="btn btn-ghost"
              >
                Back
              </.link>
            </div>
          </div>
        </div>

        <p
          :if={@live_action == :index and @stream_servers == []}
          id="no-stream-servers"
          class="py-8 text-center"
        >
          No stream servers found
        </p>

        <div :if={@live_action == :index and @stream_servers != []} class="overflow-x-auto">
          <table id="stream-servers-table" class="table table-sm sm:table-md">
            <thead>
              <tr>
                <th>Name</th>
                <th>Host</th>
                <th>Country</th>
                <th>Cert hash</th>
                <th>Applications</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={server <- @stream_servers} id={"stream-server-row-#{server.id}"}>
                <td>{server.name}</td>
                <td>{server.host}</td>
                <td>{Countries.flag(server.country)}</td>
                <td id={"cert-hash-#{server.id}"}>
                  <%= if server.cert_hash do %>
                    Set
                    <span id={"cert-hash-value-#{server.id}"} class="hidden">
                      {server.cert_hash}
                    </span>
                    <button
                      type="button"
                      id={"copy-cert-hash-#{server.id}"}
                      onclick={"navigator.clipboard.writeText(document.getElementById('cert-hash-value-#{server.id}').textContent.trim())"}
                      class="btn btn-ghost btn-xs"
                      title="Copy certificate hash"
                    >
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  <% else %>
                    —
                  <% end %>
                </td>
                <td>
                  <span
                    :for={application <- server.applications}
                    id={"application-chip-#{server.id}-#{application.id}"}
                    class="badge badge-sm badge-outline mr-1"
                  >
                    {application.name}
                  </span>
                  <span :if={server.applications == []} class="opacity-50">—</span>
                </td>
                <td class="text-right whitespace-nowrap">
                  <.link
                    patch={
                      "/stream-server-admin/stream-servers/#{server.id}/edit" <>
                        filter_query(@application_filter)
                    }
                    id={"edit-stream-server-#{server.id}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Edit
                  </.link>
                  <.link
                    patch={
                      "/stream-server-admin/stream-servers/#{server.id}/assign" <>
                        filter_query(@application_filter)
                    }
                    id={"assign-stream-server-#{server.id}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Assign
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
    </Layouts.stream_server_admin>
    """
  end
end
