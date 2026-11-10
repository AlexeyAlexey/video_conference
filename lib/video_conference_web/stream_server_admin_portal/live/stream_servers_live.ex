defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServersLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer
  alias VideoConference.StreamServers.Countries
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Stream Servers",
       modal: nil,
       modal_server: nil,
       modal_form: nil
     )}
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

  def handle_event("delete", %{"id" => id}, socket) do
    stream_server = StreamServers.get_stream_server!(id)

    case StreamServers.delete_stream_server(stream_server) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server removed")
         |> assign_stream_servers()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The stream server cannot be removed")}
    end
  end

  def handle_event(
        "toggle-assignment",
        %{"application-id" => application_id, "assigned" => assigned},
        socket
      ) do
    stream_server_id = socket.assigns.stream_server.id

    {:ok, stream_server} =
      if assigned == "true",
        do: StreamServers.unassign_application(stream_server_id, application_id),
        else: StreamServers.assign_application(stream_server_id, application_id)

    {:noreply,
     assign(
       socket,
       :assigned_application_ids,
       Enum.map(stream_server.applications, & &1.id)
     )}
  end

  def handle_event("rename-server", %{"id" => id}, socket) do
    socket = open_modal(socket, :rename, id)
    server = socket.assigns.modal_server

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(StreamServer.name_changeset(server, %{}), as: :rename_server)
     )}
  end

  def handle_event("edit-description", %{"id" => id}, socket) do
    socket = open_modal(socket, :edit_description, id)
    server = socket.assigns.modal_server

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"description" => server.description}, as: :server_description)
     )}
  end

  def handle_event("edit-country", %{"id" => id}, socket) do
    socket = open_modal(socket, :edit_country, id)
    server = socket.assigns.modal_server

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"country" => server.country}, as: :edit_country)
     )}
  end

  def handle_event("edit-cert-hash", %{"id" => id}, socket) do
    socket = open_modal(socket, :edit_cert_hash, id)
    server = socket.assigns.modal_server

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"cert_hash" => server.cert_hash}, as: :server_cert_hash)
     )}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("save-name", %{"rename_server" => %{"name" => name}}, socket) do
    case StreamServers.rename_stream_server(socket.assigns.modal_server.id, name) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server renamed")
         |> close_modal()
         |> assign_stream_servers()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :rename_server))}
    end
  end

  def handle_event(
        "save-description",
        %{"server_description" => %{"description" => description}},
        socket
      ) do
    case StreamServers.edit_stream_server_description(
           socket.assigns.modal_server.id,
           description
         ) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server description updated")
         |> close_modal()
         |> assign_stream_servers()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :server_description))}
    end
  end

  def handle_event("save-country", %{"edit_country" => %{"country" => country}}, socket) do
    case StreamServers.edit_stream_server_country(
           socket.assigns.modal_server.id,
           country
         ) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server country updated")
         |> close_modal()
         |> assign_stream_servers()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :edit_country))}
    end
  end

  def handle_event(
        "save-cert-hash",
        %{"server_cert_hash" => %{"cert_hash" => cert_hash}},
        socket
      ) do
    case StreamServers.edit_stream_server_cert_hash(
           socket.assigns.modal_server.id,
           cert_hash
         ) do
      {:ok, _stream_server} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server certificate hash updated")
         |> close_modal()
         |> assign_stream_servers()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :server_cert_hash))}
    end
  end

  def handle_info({:country_picked, code}, socket) do
    if socket.assigns.modal == :edit_country do
      {:noreply, assign(socket, :modal_form, to_form(%{"country" => code}, as: :edit_country))}
    else
      changeset =
        socket.assigns.form.source
        |> Ecto.Changeset.put_change(:country, code)
        |> Map.update!(:errors, &Keyword.delete(&1, :country))

      {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp open_modal(socket, modal, id) do
    assign(socket,
      modal: modal,
      modal_server: StreamServers.get_stream_server!(id),
      modal_form: nil
    )
  end

  defp close_modal(socket) do
    assign(socket, modal: nil, modal_server: nil, modal_form: nil)
  end

  defp assign_stream_servers(socket) do
    assign(socket,
      stream_servers:
        StreamServers.list_stream_servers(application_id: socket.assigns.application_filter)
    )
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

  defp description_long?(description) when is_binary(description),
    do: String.length(description) > 50

  defp description_long?(_description), do: false

  defp truncated_description(description) when is_binary(description),
    do: String.slice(description, 0, 50) <> "..."

  attr :id, :string, required: true
  attr :title, :string, required: true
  slot :inner_block, required: true

  defp modal(assigns) do
    ~H"""
    <div id={@id} class="modal modal-open" role="dialog">
      <div class="modal-box w-11/12 max-w-lg">
        <div class="mb-4 flex items-start justify-between gap-2">
          <h3 class="text-lg font-bold">{@title}</h3>
          <button
            type="button"
            id={"#{@id}-close"}
            phx-click="close-modal"
            class="btn btn-ghost btn-sm btn-square"
            title="Close"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>
        {render_slot(@inner_block)}
      </div>
      <div class="modal-backdrop" phx-click="close-modal"></div>
    </div>
    """
  end

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
          :if={@live_action == :new}
          id="stream-server-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              Add stream server
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
            <div :if={@applications != []} id="assign-applications" class="space-y-2">
              <label
                :for={application <- @applications}
                class="flex items-center gap-2 py-1"
              >
                <input
                  type="checkbox"
                  id={"assign-application-#{application.id}"}
                  phx-click="toggle-assignment"
                  phx-value-application-id={application.id}
                  phx-value-assigned={to_string(application.id in @assigned_application_ids)}
                  checked={application.id in @assigned_application_ids}
                  class="checkbox checkbox-sm"
                />
                <span>{application.name}</span>
              </label>
            </div>
            <div class="flex gap-2 pt-2">
              <.link
                patch={index_path(@application_filter)}
                id="back-to-stream-servers"
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
                <th>Description</th>
                <th>Cert hash</th>
                <th>Applications</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={server <- @stream_servers} id={"stream-server-row-#{server.id}"}>
                <td class="whitespace-nowrap">
                  {server.name}
                  <button
                    type="button"
                    id={"rename-server-#{server.id}"}
                    phx-click="rename-server"
                    phx-value-id={server.id}
                    class="btn btn-ghost btn-xs btn-square"
                    title="Rename server"
                  >
                    <.icon name="hero-pencil" class="size-3.5" />
                  </button>
                </td>
                <td>{server.host}</td>
                <td class="whitespace-nowrap">
                  {Countries.flag(server.country)}
                  <button
                    type="button"
                    id={"edit-country-#{server.id}"}
                    phx-click="edit-country"
                    phx-value-id={server.id}
                    class="btn btn-ghost btn-xs btn-square"
                    title="Edit country"
                  >
                    <.icon name="hero-pencil" class="size-3.5" />
                  </button>
                </td>
                <td class="max-w-64 break-all">
                  <div class="flex items-start gap-1">
                    <div class="min-w-0 flex-1">
                      <button
                        :if={description_long?(server.description)}
                        type="button"
                        id={"server-description-#{server.id}"}
                        phx-click={
                          JS.toggle_class("hidden",
                            to: "#server-description-short-#{server.id}"
                          )
                          |> JS.toggle_class("hidden",
                            to: "#server-description-full-#{server.id}"
                          )
                        }
                        class="w-full cursor-pointer text-left"
                        title="Show the full description"
                      >
                        <span
                          id={"server-description-short-#{server.id}"}
                          class="break-all"
                        >
                          {truncated_description(server.description)}
                        </span>
                        <span
                          id={"server-description-full-#{server.id}"}
                          class="hidden whitespace-pre-wrap break-all"
                        >
                          {server.description}
                        </span>
                      </button>
                      <span
                        :if={not description_long?(server.description)}
                        class="break-all"
                      >
                        {server.description}
                      </span>
                    </div>
                    <button
                      type="button"
                      id={"edit-description-#{server.id}"}
                      phx-click="edit-description"
                      phx-value-id={server.id}
                      class="btn btn-ghost btn-xs btn-square"
                      title="Edit description"
                    >
                      <.icon name="hero-pencil" class="size-3.5" />
                    </button>
                  </div>
                </td>
                <td id={"cert-hash-#{server.id}"} class="whitespace-nowrap">
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
                  <button
                    type="button"
                    id={"edit-cert-hash-#{server.id}"}
                    phx-click="edit-cert-hash"
                    phx-value-id={server.id}
                    class="btn btn-ghost btn-xs btn-square"
                    title="Edit certificate hash"
                  >
                    <.icon name="hero-pencil" class="size-3.5" />
                  </button>
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

        <.modal
          :if={@modal == :rename and @modal_server}
          id="rename-server-modal"
          title="Rename stream server"
        >
          <.form
            for={@modal_form}
            id="rename-server-form"
            phx-submit="save-name"
            autocomplete="off"
            novalidate
          >
            <.input field={@modal_form[:name]} label="Name" required autocomplete="off" />
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </.modal>

        <.modal
          :if={@modal == :edit_description and @modal_server}
          id="edit-description-modal"
          title="Edit description"
        >
          <.form
            for={@modal_form}
            id="edit-description-form"
            phx-submit="save-description"
            autocomplete="off"
            novalidate
          >
            <.input
              field={@modal_form[:description]}
              type="textarea"
              label="Description"
              autocomplete="off"
            />
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </.modal>

        <.modal
          :if={@modal == :edit_country and @modal_server}
          id="edit-country-modal"
          title="Edit country"
        >
          <.form
            for={@modal_form}
            id="edit-country-form"
            phx-submit="save-country"
            autocomplete="off"
            novalidate
          >
            <.live_component
              module={DropdownComponent}
              id="edit-country"
              label="Country"
              field={@modal_form[:country]}
              options={&Countries.options_for_select/1}
              searchable
              empty_label="None"
              search_placeholder="Type to filter countries"
              value_key="code"
              on_change={fn code -> send(self(), {:country_picked, code}) end}
            />
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </.modal>

        <.modal
          :if={@modal == :edit_cert_hash and @modal_server}
          id="edit-cert-hash-modal"
          title="Edit certificate hash"
        >
          <.form
            for={@modal_form}
            id="edit-cert-hash-form"
            phx-submit="save-cert-hash"
            autocomplete="off"
            novalidate
          >
            <.input
              field={@modal_form[:cert_hash]}
              label="Certificate hash"
              autocomplete="off"
            />
            <p class="mt-1 text-sm opacity-60">Leave blank to clear the certificate hash</p>
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </.modal>
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
