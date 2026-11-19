defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServerPublicKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications

  alias VideoConference.StreamServerAdminPortal.Applications.{
    Application,
    StreamServerPublicKey
  }

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
    application = application(params["application_id"])

    socket =
      socket
      |> assign(:application, application)
      |> assign(
        :filter_form,
        to_form(%{"application_id" => selected_id(application)}, as: :filter)
      )
      |> assign(:public_keys, public_keys(application))

    {:noreply, socket}
  end

  defp application(id) when id in [nil, ""], do: nil
  defp application(id), do: Applications.get_application!(id)

  defp selected_id(nil), do: ""
  defp selected_id(%Application{} = application), do: application.id

  defp public_keys(nil), do: []

  defp public_keys(%Application{} = application),
    do: Applications.list_stream_server_public_keys(application.id)

  def handle_event("open-add-modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :add,
       modal_key: nil,
       modal_form:
         to_form(
           Applications.change_stream_server_public_key(%StreamServerPublicKey{enabled: true})
         )
     )}
  end

  def handle_event("validate", %{"stream_server_public_key" => key_params}, socket) do
    changeset =
      %StreamServerPublicKey{}
      |> Applications.change_stream_server_public_key(key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :modal_form, to_form(changeset))}
  end

  def handle_event("save", %{"stream_server_public_key" => key_params}, socket) do
    attrs = Map.put(key_params, "application_id", socket.assigns.application.id)

    case Applications.create_stream_server_public_key(attrs) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key added")
         |> close_modal()
         |> assign_public_keys()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    key = Applications.get_stream_server_public_key!(id)

    case Applications.remove_stream_server_public_key(key) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Stream server public key removed")
         |> assign_public_keys()}

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
        {:noreply, assign_public_keys(socket)}

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
         |> assign_public_keys()}

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
         |> assign_public_keys()}

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
         |> assign_public_keys()}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "The stream server public key application cannot be changed")}
    end
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

  defp assign_public_keys(socket) do
    assign(socket, :public_keys, public_keys(socket.assigns.application))
  end

  defp index_path(application_id) when application_id in [nil, ""],
    do: "/stream-server-admin/applications/stream-server-public-keys"

  defp index_path(application_id),
    do:
      "/stream-server-admin/applications/stream-server-public-keys?application_id=#{application_id}"

  defp application_options(query) do
    for application <- Applications.list_applications(search: query),
        do: {application.name, application.id}
  end

  defp lock_version_error(form) do
    for {:lock_version, {msg, _opts}} <- form.errors, do: msg
  end

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
            <.button
              :if={@application}
              id="add-key"
              phx-click="open-add-modal"
              class="btn btn-primary btn-sm"
            >
              Add key
            </.button>
          </:actions>
        </.header>

        <p id="keys-description" class="mb-6 text-sm opacity-70">
          Each stream server public key below belongs to an application. The portal assigns it a
          key id — the key record's own id — which a stream server uses to
          pick the public key that verifies the signed JWT the application presents
          when a participant connects (audio/video/events).
        </p>

        <div class="mb-4 max-w-xs">
          <.form
            for={@filter_form}
            id="application-filter-form"
            onsubmit="event.preventDefault()"
          >
            <.live_component
              module={DropdownComponent}
              id="application-filter"
              label="Application"
              field={@filter_form[:application_id]}
              options={&application_options/1}
              placeholder="Choose an application"
              searchable
              search_placeholder="Type to filter applications"
              value_key="id"
              on_change={fn id -> send(self(), {:filter_picked, id}) end}
            />
          </.form>
        </div>

        <p :if={@application == nil} id="select-application-prompt" class="py-8 text-center">
          Select an application to manage its stream server public keys
        </p>

        <div :if={@application} id="public-keys-section">
          <p :if={@public_keys == []} id="no-public-keys" class="py-8 text-center">
            No stream server public keys yet
          </p>
          <div :if={@public_keys != []} class="overflow-x-auto">
            <table id="public-keys-table" class="table table-sm sm:table-md">
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
                <tr :for={key <- @public_keys} id={"key-row-#{key.id}"}>
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
                    <div id={"key-actions-#{key.id}"} class="inline-block">
                      <button
                        type="button"
                        popovertarget={"key-actions-menu-#{key.id}"}
                        style={"anchor-name:--key-actions-#{key.id}"}
                        class="btn btn-ghost btn-xs btn-square"
                        title="Key actions"
                      >
                        <.icon name="hero-ellipsis-vertical" class="size-4" />
                      </button>
                      <ul
                        popover
                        id={"key-actions-menu-#{key.id}"}
                        style={
                          "position-anchor:--key-actions-#{key.id}; position-try-fallbacks: flip-block"
                        }
                        class="dropdown dropdown-end menu w-36 rounded-box border border-base-300 bg-base-100 p-2 shadow"
                      >
                        <li>
                          <button
                            type="button"
                            id={"change-app-#{key.id}"}
                            phx-click="change-app"
                            phx-value-id={key.id}
                            popovertarget={"key-actions-menu-#{key.id}"}
                            popovertargetaction="hide"
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
                            popovertarget={"key-actions-menu-#{key.id}"}
                            popovertargetaction="hide"
                            class="text-error"
                          >
                            Remove
                          </button>
                        </li>
                      </ul>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <.modal
          :if={@modal == :add}
          id="add-key-modal"
          title="Add stream server public key"
        >
          <p id="add-key-application" class="mb-4 text-sm opacity-70">
            {@application.name}
          </p>
          <.form
            for={@modal_form}
            id="key-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
            autocomplete="off"
            novalidate
          >
            <.input field={@modal_form[:name]} label="Name" autocomplete="off" />
            <.input
              field={@modal_form[:key]}
              type="textarea"
              label="Key"
              autocomplete="off"
            />
            <.input
              field={@modal_form[:description]}
              type="textarea"
              label="Description"
              autocomplete="off"
            />
            <.input field={@modal_form[:enabled]} type="checkbox" label="Enabled" />
            <p :for={msg <- lock_version_error(@modal_form)} class="text-sm text-error">
              {msg}
            </p>
            <div class="modal-action">
              <.button class="btn btn-primary" phx-disable-with="Saving...">
                Save
              </.button>
            </div>
          </.form>
        </.modal>

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
            <p :for={msg <- lock_version_error(@modal_form)} class="text-sm text-error">
              {msg}
            </p>
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
            <p :for={msg <- lock_version_error(@modal_form)} class="text-sm text-error">
              {msg}
            </p>
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
              options={&application_options/1}
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
