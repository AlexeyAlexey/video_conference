defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServerPublicKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Stream Server Public Keys",
       modal: nil,
       modal_key: nil,
       modal_form: nil
     )}
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
        Applications.list_applications_with_stream_server_public_keys(
          application_id: application_filter
        )
      )
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp filter_form(application_filter) do
    to_form(%{"application_id" => application_filter}, as: :filter)
  end

  defp apply_action(socket, :index, _params) do
    assign(socket,
      page_title: "Stream Server Public Keys",
      stream_server_public_key: nil,
      form: nil
    )
  end

  defp apply_action(socket, :new, _params) do
    key = %StreamServerPublicKey{}

    socket
    |> assign(page_title: "Add Stream Server Public Key", stream_server_public_key: key)
    |> assign_form(Applications.change_stream_server_public_key(key))
  end

  def handle_event("validate", %{"stream_server_public_key" => key_params}, socket) do
    changeset =
      socket.assigns.stream_server_public_key
      |> Applications.change_stream_server_public_key(key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"stream_server_public_key" => key_params}, socket) do
    case Applications.create_stream_server_public_key(key_params) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key added")
         |> push_patch(to: index_path(socket.assigns.application_filter))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    key = Applications.get_stream_server_public_key!(id)

    case Applications.remove_stream_server_public_key(key) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key removed")
         |> assign_applications()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The stream server public key cannot be removed")}
    end
  end

  def handle_event("toggle-enabled", %{"id" => id, "enabled" => enabled}, socket) do
    result =
      if enabled == "true",
        do: Applications.disable_stream_server_public_key(id),
        else: Applications.enable_stream_server_public_key(id)

    case result do
      {:ok, _key} ->
        {:noreply, assign_applications(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The enabled flag cannot be changed")}
    end
  end

  def handle_event("show-key", %{"id" => id}, socket) do
    {:noreply, open_modal(socket, :show_key, id)}
  end

  def handle_event("rename-key", %{"id" => id}, socket) do
    socket = open_modal(socket, :rename, id)
    key = socket.assigns.modal_key

    {:noreply, assign(socket, :modal_form, to_form(%{"name" => key.name}, as: :rename_key))}
  end

  def handle_event("edit-description", %{"id" => id}, socket) do
    socket = open_modal(socket, :edit_description, id)
    key = socket.assigns.modal_key

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"description" => key.description}, as: :key_description)
     )}
  end

  def handle_event("change-app", %{"id" => id}, socket) do
    socket = open_modal(socket, :change_app, id)
    key = socket.assigns.modal_key

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"application_id" => key.application_id}, as: :change_app)
     )}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("save-name", %{"rename_key" => %{"name" => name}}, socket) do
    case Applications.rename_stream_server_public_key(socket.assigns.modal_key.id, name) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key renamed")
         |> close_modal()
         |> assign_applications()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :rename_key))}
    end
  end

  def handle_event(
        "save-description",
        %{"key_description" => %{"description" => description}},
        socket
      ) do
    case Applications.edit_stream_server_public_key_description(
           socket.assigns.modal_key.id,
           description
         ) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key description updated")
         |> close_modal()
         |> assign_applications()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :key_description))}
    end
  end

  def handle_event(
        "save-application",
        %{"change_app" => %{"application_id" => application_id}},
        socket
      ) do
    case Applications.move_stream_server_public_key_to_application(
           socket.assigns.modal_key.id,
           application_id
         ) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key application changed")
         |> close_modal()
         |> assign_applications()}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "The stream server public key application cannot be changed")}
    end
  end

  def handle_info({:application_picked, id}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:application_id, id)
      |> Map.update!(:errors, &Keyword.delete(&1, :application_id))

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_info({:change_app_picked, application_id}, socket) do
    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"application_id" => application_id}, as: :change_app)
     )}
  end

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp open_modal(socket, modal, id) do
    assign(socket,
      modal: modal,
      modal_key: Applications.get_stream_server_public_key!(id),
      modal_form: nil
    )
  end

  defp close_modal(socket) do
    assign(socket, modal: nil, modal_key: nil, modal_form: nil)
  end

  defp assign_applications(socket) do
    assign(socket,
      applications:
        Applications.list_applications_with_stream_server_public_keys(
          application_id: socket.assigns.application_filter
        )
    )
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp index_path(application_filter) when application_filter in [nil, ""],
    do: "/stream-server-admin/applications/stream-server-public-keys"

  defp index_path(application_filter),
    do:
      "/stream-server-admin/applications/stream-server-public-keys?application_id=#{application_filter}"

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
          Stream Server Public Keys
          <:subtitle>Stream server public keys registered for each application</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch={
                "/stream-server-admin/applications/stream-server-public-keys/new" <>
                  filter_query(@application_filter)
              }
              id="add-key-link"
              class="btn btn-primary btn-sm"
            >
              Add key
            </.link>
          </:actions>
        </.header>

        <p id="keys-description" class="mb-6 text-sm opacity-70">
          Each stream server public key below belongs to an application. The portal assigns it a
          key id — the key record's own id — which a stream server uses to
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
          :if={@live_action == :new}
          id="key-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              Add stream server public key
            </h2>
            <.form
              for={@form}
              id="key-form"
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
                field={@form[:key]}
                type="textarea"
                label="Key"
                autocomplete="off"
              />
              <.input
                field={@form[:enabled]}
                type="checkbox"
                label="Enabled"
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
                  id="cancel-key-form"
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
            :if={application.stream_server_public_keys == []}
            id={"no-keys-#{application.id}"}
            class="text-sm opacity-60"
          >
            No stream server public keys yet
          </p>
          <div :if={application.stream_server_public_keys != []} class="overflow-x-auto">
            <table id={"keys-table-#{application.id}"} class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Key Id</th>
                  <th>Public key</th>
                  <th>Description</th>
                  <th>Enabled</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={key <- application.stream_server_public_keys}
                  id={"key-row-#{key.id}"}
                >
                  <td class="whitespace-nowrap">
                    {key.name}
                    <button
                      type="button"
                      id={"rename-key-#{key.id}"}
                      phx-click="rename-key"
                      phx-value-id={key.id}
                      class="btn btn-ghost btn-xs btn-square"
                      title="Rename key"
                    >
                      <.icon name="hero-pencil" class="size-3.5" />
                    </button>
                  </td>
                  <td class="whitespace-nowrap" id={"key-id-#{key.id}"}>
                    {key.id}
                    <span id={"key-id-value-#{key.id}"} class="hidden">
                      {key.id}
                    </span>
                    <button
                      type="button"
                      id={"copy-key-id-#{key.id}"}
                      onclick={"navigator.clipboard.writeText(document.getElementById('key-id-value-#{key.id}').textContent.trim())"}
                      class="btn btn-ghost btn-xs"
                      title="Copy key id"
                    >
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  </td>
                  <td>
                    <button
                      type="button"
                      id={"show-key-#{key.id}"}
                      phx-click="show-key"
                      phx-value-id={key.id}
                      class="btn btn-ghost btn-xs btn-square"
                      title="Show public key"
                    >
                      <.icon name="hero-eye" class="size-4" />
                    </button>
                  </td>
                  <td class="max-w-64 break-all">
                    <div class="flex items-start gap-1">
                      <div class="min-w-0 flex-1">
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
                      </div>
                      <button
                        type="button"
                        id={"edit-description-#{key.id}"}
                        phx-click="edit-description"
                        phx-value-id={key.id}
                        class="btn btn-ghost btn-xs btn-square"
                        title="Edit description"
                      >
                        <.icon name="hero-pencil" class="size-3.5" />
                      </button>
                    </div>
                  </td>
                  <td>
                    <input
                      type="checkbox"
                      id={"enabled-key-#{key.id}"}
                      phx-click="toggle-enabled"
                      phx-value-id={key.id}
                      phx-value-enabled={to_string(key.enabled)}
                      checked={key.enabled}
                      class="checkbox checkbox-sm"
                      title="Toggle enabled"
                    />
                  </td>
                  <td class="text-right whitespace-nowrap">
                    <details class="dropdown dropdown-end" id={"key-actions-#{key.id}"}>
                      <summary class="btn btn-ghost btn-xs btn-square" title="Key actions">
                        <.icon name="hero-ellipsis-vertical" class="size-4" />
                      </summary>
                      <ul class="menu dropdown-content z-50 w-36 rounded-box border border-base-300 bg-base-100 p-2 shadow">
                        <li>
                          <button
                            type="button"
                            id={"change-app-#{key.id}"}
                            phx-click={
                              JS.push("change-app")
                              |> JS.remove_attribute("open", to: "#key-actions-#{key.id}")
                            }
                            phx-value-id={key.id}
                          >
                            Change app
                          </button>
                        </li>
                        <li>
                          <button
                            type="button"
                            id={"delete-key-#{key.id}"}
                            phx-click="delete"
                            phx-value-id={key.id}
                            data-confirm={"Remove #{key.name}?"}
                            class="text-error"
                          >
                            Remove
                          </button>
                        </li>
                      </ul>
                    </details>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <.modal :if={@modal == :show_key and @modal_key} id="show-key-modal" title="Public key">
          <code id="show-key-content" class="block break-all whitespace-pre-wrap text-sm">
            {@modal_key.key}
          </code>
          <span id="show-key-value" class="hidden">{@modal_key.key}</span>
          <div class="modal-action">
            <button
              type="button"
              id="copy-public-key"
              onclick="navigator.clipboard.writeText(document.getElementById('show-key-value').textContent.trim())"
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-document-duplicate" class="size-4" /> Copy
            </button>
          </div>
        </.modal>

        <.modal :if={@modal == :rename and @modal_key} id="rename-key-modal" title="Rename key">
          <.form
            for={@modal_form}
            id="rename-key-form"
            phx-submit="save-name"
            autocomplete="off"
            novalidate
          >
            <.input field={@modal_form[:name]} label="Name" autocomplete="off" />
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
        </.modal>

        <.modal
          :if={@modal == :edit_description and @modal_key}
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
          :if={@modal == :change_app and @modal_key}
          id="change-app-modal"
          title="Change app"
        >
          <.form
            for={@modal_form}
            id="change-app-form"
            phx-submit="save-application"
            autocomplete="off"
            novalidate
          >
            <.live_component
              module={DropdownComponent}
              id="change-app"
              label="Application"
              field={@modal_form[:application_id]}
              options={
                for application <- @filter_applications, do: {application.name, application.id}
              }
              placeholder="Choose an application"
              searchable
              search_placeholder="Type to filter applications"
              value_key="id"
              on_change={fn id -> send(self(), {:change_app_picked, id}) end}
            />
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
