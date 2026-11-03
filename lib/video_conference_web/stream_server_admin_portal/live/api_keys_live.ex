defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.ApiKey
  alias VideoConferenceWeb.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "API Keys", new_key_secret: nil)}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:applications, Applications.list_applications_with_api_keys())
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "API Keys", api_key: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    api_key = %ApiKey{}

    socket
    |> assign(
      page_title: "New API Key",
      api_key: api_key,
      new_key_secret: nil
    )
    |> assign_form(Applications.change_api_key(api_key))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    api_key = Applications.get_api_key!(id)

    socket
    |> assign(
      page_title: "Edit #{api_key.name}",
      api_key: api_key,
      new_key_secret: nil
    )
    |> assign_form(Applications.change_api_key(api_key))
  end

  def handle_event("validate", %{"api_key" => api_key_params}, socket) do
    changeset =
      socket.assigns.api_key
      |> Applications.change_api_key(api_key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"api_key" => api_key_params}, socket) do
    save_api_key(socket, socket.assigns.live_action, api_key_params)
  end

  def handle_event("dismiss-secret", _params, socket) do
    {:noreply, assign(socket, :new_key_secret, nil)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    api_key = Applications.get_api_key!(id)

    case Applications.delete_api_key(api_key) do
      {:ok, _api_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API key removed")
         |> assign(:applications, Applications.list_applications_with_api_keys())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The API key cannot be removed")}
    end
  end

  defp save_api_key(socket, :new, api_key_params) do
    case Applications.create_api_key(api_key_params) do
      {:ok, api_key} ->
        {:noreply,
         socket
         |> assign(:new_key_secret, api_key.plaintext_key)
         |> put_flash(:info, "API key added — copy the secret now, it will not be shown again")
         |> push_patch(to: "/stream-server-admin/api-keys")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_api_key(socket, :edit, api_key_params) do
    case Applications.update_api_key(socket.assigns.api_key, api_key_params) do
      {:ok, _api_key} ->
        {:noreply,
         socket
         |> put_flash(:info, "API key updated")
         |> push_patch(to: "/stream-server-admin/api-keys")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_info({:application_picked, id}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:application_id, id)
      |> Map.update!(:errors, &Keyword.delete(&1, :application_id))

    {:noreply, assign_form(socket, changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

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
          API Keys
          <:subtitle>Credentials that authenticate each application's API calls</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch="/stream-server-admin/api-keys/new"
              id="add-api-key-link"
              class="btn btn-primary btn-sm"
            >
              Add API key
            </.link>
          </:actions>
        </.header>

        <div
          :if={@live_action == :index && @new_key_secret}
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

        <div
          :if={@live_action in [:new, :edit]}
          id="api-key-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {if @live_action == :new, do: "Add API key", else: "Edit API key"}
            </h2>
            <.form
              for={@form}
              id="api-key-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-2"
              autocomplete="off"
              novalidate
            >
              <.input field={@form[:name]} label="Name" required autocomplete="off" />
              <.live_component
                module={DropdownComponent}
                id="application"
                label="Application"
                field={@form[:application_id]}
                options={for application <- @applications, do: {application.name, application.id}}
                placeholder="Choose an application"
                value_key="id"
                on_change={fn id -> send(self(), {:application_picked, id}) end}
              />
              <.input
                field={@form[:description]}
                type="textarea"
                label="Description"
                autocomplete="off"
              />
              <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch="/stream-server-admin/api-keys"
                  id="cancel-api-key-form"
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
            :if={application.api_keys == []}
            id={"no-api-keys-#{application.id}"}
            class="text-sm opacity-60"
          >
            No API keys yet
          </p>
          <div :if={application.api_keys != []} class="overflow-x-auto">
            <table id={"api-keys-table-#{application.id}"} class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Description</th>
                  <th>Enabled</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={api_key <- application.api_keys} id={"api-key-row-#{api_key.id}"}>
                  <td>{api_key.name}</td>
                  <td class="max-w-64 break-all">
                    <button
                      :if={description_long?(api_key.description)}
                      type="button"
                      id={"api-key-description-#{api_key.id}"}
                      phx-click={
                        JS.toggle_class("hidden",
                          to: "#api-key-description-short-#{api_key.id}"
                        )
                        |> JS.toggle_class("hidden",
                          to: "#api-key-description-full-#{api_key.id}"
                        )
                      }
                      class="w-full cursor-pointer text-left"
                      title="Show the full description"
                    >
                      <span id={"api-key-description-short-#{api_key.id}"} class="break-all">
                        {truncated_description(api_key.description)}
                      </span>
                      <span
                        id={"api-key-description-full-#{api_key.id}"}
                        class="hidden whitespace-pre-wrap break-all"
                      >
                        {api_key.description}
                      </span>
                    </button>
                    <span :if={not description_long?(api_key.description)} class="break-all">
                      {api_key.description}
                    </span>
                  </td>
                  <td>{if api_key.enabled, do: "Yes", else: "No"}</td>
                  <td class="text-right whitespace-nowrap">
                    <.link
                      patch={"/stream-server-admin/api-keys/#{api_key.id}/edit"}
                      id={"edit-api-key-#{api_key.id}"}
                      class="btn btn-ghost btn-xs"
                    >
                      Edit
                    </.link>
                    <button
                      id={"delete-api-key-#{api_key.id}"}
                      type="button"
                      phx-click="delete"
                      phx-value-id={api_key.id}
                      data-confirm={"Remove #{api_key.name}?"}
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
