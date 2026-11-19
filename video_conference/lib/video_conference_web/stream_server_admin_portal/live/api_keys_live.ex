defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.ApiKey
  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "API Keys",
       modal: nil,
       modal_key: nil,
       modal_form: nil,
       new_key_secret: nil
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
      |> assign(:api_keys, api_keys(application))

    {:noreply, socket}
  end

  defp application(id) when id in [nil, ""], do: nil
  defp application(id), do: Applications.get_application!(id)

  defp selected_id(nil), do: ""
  defp selected_id(%Application{} = application), do: application.id

  defp api_keys(nil), do: []
  defp api_keys(%Application{} = a), do: Applications.list_api_keys(a.id)

  def handle_event("open-add-modal", _params, socket) do
    {:noreply,
     assign(socket,
       modal: :add,
       modal_key: nil,
       modal_form: to_form(Applications.change_api_key(%ApiKey{enabled: true}))
     )}
  end

  def handle_event("validate", %{"api_key" => api_key_params}, socket) do
    changeset =
      %ApiKey{}
      |> Applications.change_api_key(api_key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :modal_form, to_form(changeset))}
  end

  def handle_event("save", %{"api_key" => api_key_params}, socket) do
    attrs = Map.put(api_key_params, "application_id", socket.assigns.application.id)

    case Applications.create_api_key(attrs) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(:new_key_secret, api_key.plaintext_key)
         |> put_flash(:info, "API key added — copy the secret now, it will not be shown again")
         |> close_modal()
         |> assign_api_keys()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset))}
    end
  end

  def handle_event("dismiss-secret", _params, socket) do
    {:noreply, assign(socket, :new_key_secret, nil)}
  end

  def handle_event("toggle-enabled", %{"id" => id, "enabled" => enabled}, socket) do
    key = Enum.find(socket.assigns.api_keys, &(&1.id == id)) || id

    result =
      if enabled == "true",
        do: Applications.disable_api_key(key),
        else: Applications.enable_api_key(key)

    case result do
      {:ok, _key} ->
        {:noreply, assign_api_keys(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The enabled flag cannot be changed")}
    end
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

  def handle_event("close-modal", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("save-name", %{"rename_key" => %{"name" => name}}, socket) do
    case Applications.rename_api_key(socket.assigns.modal_key, name) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API key renamed")
         |> close_modal()
         |> assign_api_keys()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :rename_key))}
    end
  end

  def handle_event(
        "save-description",
        %{"key_description" => %{"description" => description}},
        socket
      ) do
    case Applications.edit_api_key_description(
           socket.assigns.modal_key,
           description
         ) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API key description updated")
         |> close_modal()
         |> assign_api_keys()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :key_description))}
    end
  end

  def handle_info({:filter_picked, application_id}, socket) do
    {:noreply, push_patch(socket, to: index_path(application_id))}
  end

  defp open_modal(socket, modal, id) do
    assign(socket,
      modal: modal,
      modal_key: Applications.get_api_key!(id),
      modal_form: nil
    )
  end

  defp close_modal(socket) do
    assign(socket, modal: nil, modal_key: nil, modal_form: nil)
  end

  defp assign_api_keys(socket) do
    assign(socket, :api_keys, api_keys(socket.assigns.application))
  end

  defp index_path(application_id) when application_id in [nil, ""],
    do: "/stream-server-admin/api-keys"

  defp index_path(application_id),
    do: "/stream-server-admin/api-keys?application_id=#{application_id}"

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
          API Keys
          <:subtitle>Credentials that authenticate each application's API calls</:subtitle>
          <:actions>
            <.button
              :if={@application}
              id="add-api-key"
              phx-click="open-add-modal"
              class="btn btn-primary btn-sm"
            >
              Add API key
            </.button>
          </:actions>
        </.header>

        <div
          :if={@new_key_secret}
          id="new-api-key-secret"
          role="alert"
          class="alert alert-success mb-6"
        >
          <div class="w-full min-w-0">
            <p class="font-semibold">
              API key created — copy the secret now, it will not be shown again
            </p>
            <code id="new-api-key-secret-value" class="mt-1 block break-all">
              {@new_key_secret}
            </code>
          </div>
          <div class="flex gap-2">
            <button
              id="copy-new-api-key-secret"
              type="button"
              onclick="navigator.clipboard.writeText(document.getElementById('new-api-key-secret-value').textContent.trim()); this.textContent = 'Copied!'"
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-document-duplicate" class="size-4" /> Copy
            </button>
            <button
              id="dismiss-new-api-key-secret"
              type="button"
              phx-click="dismiss-secret"
              class="btn btn-ghost btn-sm"
            >
              Dismiss
            </button>
          </div>
        </div>

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
          Select an application to manage its API keys
        </p>

        <div :if={@application} id="api-keys-section">
          <p :if={@api_keys == []} id="no-api-keys" class="py-8 text-center">
            No API keys yet
          </p>
          <div :if={@api_keys != []} class="overflow-x-auto">
            <table id="api-keys-table" class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>API KEY</th>
                  <th>Description</th>
                  <th>Enabled</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={api_key <- @api_keys} id={"api-key-row-#{api_key.id}"}>
                  <td class="whitespace-nowrap">
                    {api_key.name}
                    <button
                      type="button"
                      id={"rename-key-#{api_key.id}"}
                      phx-click="rename-key"
                      phx-value-id={api_key.id}
                      class="btn btn-ghost btn-xs btn-square"
                      title="Rename key"
                    >
                      <.icon name="hero-pencil" class="size-3.5" />
                    </button>
                  </td>
                  <td class="whitespace-nowrap" id={"api-key-prefix-#{api_key.id}"}>
                    {api_key.prefix}
                    <span id={"api-key-prefix-value-#{api_key.id}"} class="hidden">
                      {api_key.prefix}
                    </span>
                    <button
                      type="button"
                      id={"copy-api-key-prefix-#{api_key.id}"}
                      onclick={"navigator.clipboard.writeText(document.getElementById('api-key-prefix-value-#{api_key.id}').textContent.trim())"}
                      class="btn btn-ghost btn-xs"
                      title="Copy API key prefix"
                    >
                      <.icon name="hero-document-duplicate" class="size-4" />
                    </button>
                  </td>
                  <td class="max-w-64 break-all">
                    <div class="flex items-start gap-1">
                      <div class="min-w-0 flex-1">
                        <button
                          :if={description_long?(api_key.description)}
                          type="button"
                          id={"key-description-#{api_key.id}"}
                          phx-click={
                            JS.toggle_class("hidden",
                              to: "#key-description-short-#{api_key.id}"
                            )
                            |> JS.toggle_class("hidden",
                              to: "#key-description-full-#{api_key.id}"
                            )
                          }
                          class="w-full cursor-pointer text-left"
                          title="Show the full description"
                        >
                          <span
                            id={"key-description-short-#{api_key.id}"}
                            class="break-all"
                          >
                            {truncated_description(api_key.description)}
                          </span>
                          <span
                            id={"key-description-full-#{api_key.id}"}
                            class="hidden whitespace-pre-wrap break-all"
                          >
                            {api_key.description}
                          </span>
                        </button>
                        <span
                          :if={not description_long?(api_key.description)}
                          class="break-all"
                        >
                          {api_key.description}
                        </span>
                      </div>
                      <button
                        type="button"
                        id={"edit-description-#{api_key.id}"}
                        phx-click="edit-description"
                        phx-value-id={api_key.id}
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
                      id={"enabled-key-#{api_key.id}"}
                      phx-click="toggle-enabled"
                      phx-value-id={api_key.id}
                      phx-value-enabled={to_string(api_key.enabled)}
                      checked={api_key.enabled}
                      class="checkbox checkbox-sm"
                      title="Toggle enabled"
                    />
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <.modal :if={@modal == :add} id="add-api-key-modal" title="Add API key">
          <p id="add-api-key-application" class="mb-4 text-sm opacity-70">
            {@application.name}
          </p>
          <.form
            for={@modal_form}
            id="api-key-form"
            phx-change="validate"
            phx-submit="save"
            class="space-y-2"
            autocomplete="off"
            novalidate
          >
            <.input field={@modal_form[:name]} label="Name" required autocomplete="off" />
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
              <.button class="btn btn-primary" phx-disable-with="Saving...">Save</.button>
            </div>
          </.form>
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
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
