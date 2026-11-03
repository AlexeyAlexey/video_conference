defmodule VideoConferenceWeb.StreamServerAdminPortal.PublicStreamServerKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.PublicStreamServerKey
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Public Keys")}
  end

  def handle_params(params, _uri, socket) do
    application_filter = params["application_id"] || ""

    socket =
      socket
      |> assign(:filter_applications, Applications.list_applications())
      |> assign(:application_filter, application_filter)
      |> assign(:filter_form, filter_form(application_filter))
      |> assign(
        :applications,
        Applications.list_applications_with_public_keys(application_id: application_filter)
      )
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp filter_form(application_filter) do
    to_form(%{"application_id" => application_filter}, as: :filter)
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Public Keys", public_stream_server_key: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    key = %PublicStreamServerKey{}

    socket
    |> assign(page_title: "Add Public Key", public_stream_server_key: key)
    |> assign_form(Applications.change_public_stream_server_key(key))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    key = Applications.get_public_stream_server_key!(id)

    socket
    |> assign(page_title: "Edit #{key.name}", public_stream_server_key: key)
    |> assign_form(Applications.change_public_stream_server_key(key))
  end

  def handle_event("validate", %{"public_stream_server_key" => key_params}, socket) do
    changeset =
      socket.assigns.public_stream_server_key
      |> Applications.change_public_stream_server_key(key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"public_stream_server_key" => key_params}, socket) do
    save_key(socket, socket.assigns.live_action, key_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    key = Applications.get_public_stream_server_key!(id)

    case Applications.delete_public_stream_server_key(key) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key removed")
         |> assign_applications()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The public key cannot be removed")}
    end
  end

  def handle_info({:application_picked, id}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:application_id, id)
      |> Map.update!(:errors, &Keyword.delete(&1, :application_id))

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp save_key(socket, :new, key_params) do
    case Applications.create_public_stream_server_key(key_params) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key added")
         |> push_patch(to: index_path(socket.assigns.application_filter))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_key(socket, :edit, key_params) do
    case Applications.update_public_stream_server_key(
           socket.assigns.public_stream_server_key,
           key_params
         ) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key updated")
         |> push_patch(to: index_path(socket.assigns.application_filter))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_applications(socket) do
    assign(socket,
      applications:
        Applications.list_applications_with_public_keys(
          application_id: socket.assigns.application_filter
        )
    )
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp index_path(application_filter) when application_filter in [nil, ""],
    do: "/stream-server-admin/applications/public-stream-server-keys"

  defp index_path(application_filter),
    do:
      "/stream-server-admin/applications/public-stream-server-keys?application_id=#{application_filter}"

  defp filter_query(application_filter) when application_filter in [nil, ""], do: ""
  defp filter_query(application_filter), do: "?application_id=#{application_filter}"

  defp description_long?(description) when is_binary(description),
    do: String.length(description) > 50

  defp description_long?(_description), do: false

  defp truncated_description(description) when is_binary(description),
    do: String.slice(description, 0, 50) <> "..."

  def render(assigns) do
    ~H"""
    <Layouts.stream_server_admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full px-2 sm:px-0">
        <.header>
          Public Keys
          <:subtitle>Public stream server keys registered for each application</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch={
                "/stream-server-admin/applications/public-stream-server-keys/new" <>
                  filter_query(@application_filter)
              }
              id="add-public-key-link"
              class="btn btn-primary btn-sm"
            >
              Add key
            </.link>
          </:actions>
        </.header>

        <p id="public-keys-description" class="mb-6 text-sm opacity-70">
          Each public key below belongs to an application. The portal assigns it a
          public key id — the key record's own id — which a stream server uses to
          pick the public key that verifies the signed JWT the application presents
          when a participant connects (audio/video/events).
        </p>

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
                for application <- @filter_applications, do: {application.name, application.id}
              }
              empty_label="All applications"
              searchable
              search_placeholder="Type to filter applications"
              value_key="id"
              on_change={fn id -> send(self(), {:filter_picked, id}) end}
            />
          </.form>
        </div>

        <div
          :if={@live_action in [:new, :edit]}
          id="public-key-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {if @live_action == :new, do: "Add public key", else: "Edit public key"}
            </h2>
            <.form
              for={@form}
              id="public-key-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-2"
              autocomplete="off"
              novalidate
            >
              <.input field={@form[:name]} label="Name" autocomplete="off" />
              <.live_component
                module={DropdownComponent}
                id="application"
                label="Application"
                field={@form[:application_id]}
                options={
                  for application <- @filter_applications, do: {application.name, application.id}
                }
                placeholder="Choose an application"
                value_key="id"
                on_change={fn id -> send(self(), {:application_picked, id}) end}
              />
              <.input
                field={@form[:public_key]}
                type="textarea"
                label="Public key"
                autocomplete="off"
              />
              <.input
                field={@form[:disabled]}
                type="checkbox"
                label="Disabled"
              />
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                autocomplete="off"
              />
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch={index_path(@application_filter)}
                  id="cancel-public-key-form"
                  class="btn btn-ghost"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <p
          :if={@live_action == :index and @applications == []}
          id="no-applications"
          class="py-8 text-center"
        >
          No applications found
        </p>

        <div
          :for={application <- @applications}
          :if={@live_action == :index}
          id={"application-group-#{application.id}"}
          class="mb-6"
        >
          <h3 class="mb-2 text-lg font-semibold">
            {application.name}
            <span :if={not application.enabled} class="text-sm font-normal opacity-60">
              disabled
            </span>
          </h3>
          <p
            :if={application.public_stream_server_keys == []}
            id={"no-public-keys-#{application.id}"}
            class="text-sm opacity-60"
          >
            No public keys yet
          </p>
          <div :if={application.public_stream_server_keys != []} class="overflow-x-auto">
            <table id={"public-keys-table-#{application.id}"} class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Public key Id</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={key <- application.public_stream_server_keys}
                  id={"public-key-row-#{key.id}"}
                >
                  <td>{key.name}</td>
                  <td class="whitespace-nowrap" id={"public-key-id-#{key.id}"}>
                    {key.id}
                    <span id={"public-key-id-value-#{key.id}"} class="hidden">
                      {key.id}
                    </span>
                    <button
                      type="button"
                      id={"copy-public-key-id-#{key.id}"}
                      onclick={"navigator.clipboard.writeText(document.getElementById('public-key-id-value-#{key.id}').textContent.trim())"}
                      class="btn btn-ghost btn-xs"
                      title="Copy public key id"
                    >
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  </td>
                  <td class="max-w-64 break-all">
                    <button
                      :if={description_long?(key.description)}
                      type="button"
                      id={"key-description-#{key.id}"}
                      phx-click={
                        JS.toggle_class("hidden", to: "#key-description-short-#{key.id}")
                        |> JS.toggle_class("hidden", to: "#key-description-full-#{key.id}")
                      }
                      class="w-full cursor-pointer text-left"
                      title="Show the full description"
                    >
                      <span id={"key-description-short-#{key.id}"} class="break-all">
                        {truncated_description(key.description)}
                      </span>
                      <span
                        id={"key-description-full-#{key.id}"}
                        class="hidden whitespace-pre-wrap break-all"
                      >
                        {key.description}
                      </span>
                    </button>
                    <span
                      :if={not description_long?(key.description)}
                      class="break-all"
                    >
                      {key.description}
                    </span>
                  </td>
                  <td>{if key.disabled, do: "Disabled", else: "Enabled"}</td>
                  <td class="text-right whitespace-nowrap">
                    <.link
                      patch={
                        "/stream-server-admin/applications/public-stream-server-keys/#{key.id}/edit" <>
                          filter_query(@application_filter)
                      }
                      id={"edit-public-key-#{key.id}"}
                      class="btn btn-ghost btn-xs"
                    >
                      Edit
                    </.link>
                    <button
                      id={"delete-public-key-#{key.id}"}
                      type="button"
                      phx-click="delete"
                      phx-value-id={key.id}
                      data-confirm={"Remove #{key.name}?"}
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
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
