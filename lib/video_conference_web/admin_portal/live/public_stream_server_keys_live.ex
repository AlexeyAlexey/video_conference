defmodule VideoConferenceWeb.AdminPortal.PublicStreamServerKeysLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.PublicStreamServerKey
  alias VideoConferenceWeb.AdminPortal.DropdownComponent

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign_servers()
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp assign_servers(socket) do
    assign(socket, stream_servers: StreamServers.list_stream_servers_with_public_keys())
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Public Keys", public_stream_server_key: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    key = %PublicStreamServerKey{}

    socket
    |> assign(page_title: "Add Public Key", public_stream_server_key: key)
    |> assign_form(StreamServers.change_public_stream_server_key(key))
  end

  defp apply_action(socket, :generate, _params) do
    key = %PublicStreamServerKey{}

    socket
    |> assign(page_title: "Generate Public Key", public_stream_server_key: key)
    |> assign_form(StreamServers.change_generate_public_stream_server_key(key))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    key = StreamServers.get_public_stream_server_key!(id)

    socket
    |> assign(page_title: "Edit #{key.name}", public_stream_server_key: key)
    |> assign_form(StreamServers.change_public_stream_server_key(key))
  end

  def handle_event("validate", %{"public_stream_server_key" => key_params}, socket) do
    changeset =
      socket.assigns.public_stream_server_key
      |> change_for_action(socket.assigns.live_action, key_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"public_stream_server_key" => key_params}, socket) do
    save_key(socket, socket.assigns.live_action, key_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    key = StreamServers.get_public_stream_server_key!(id)

    case StreamServers.delete_public_stream_server_key(key) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key removed")
         |> assign_servers()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The public key cannot be removed")}
    end
  end

  defp change_for_action(key, :generate, params),
    do: StreamServers.change_generate_public_stream_server_key(key, params)

  defp change_for_action(key, _action, params),
    do: StreamServers.change_public_stream_server_key(key, params)

  defp save_key(socket, :new, key_params) do
    case StreamServers.create_public_stream_server_key(key_params) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key added")
         |> push_patch(to: "/admin/stream-servers/keys")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_key(socket, :generate, key_params) do
    case StreamServers.generate_public_stream_server_key(key_params) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key generated")
         |> push_patch(to: "/admin/stream-servers/keys")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_key(socket, :edit, key_params) do
    case StreamServers.update_public_stream_server_key(
           socket.assigns.public_stream_server_key,
           key_params
         ) do
      {:ok, _key} ->
        {:noreply,
         socket
         |> put_flash(:info, "Public key updated")
         |> push_patch(to: "/admin/stream-servers/keys")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_info({:stream_server_picked, id}, socket) do
    changeset =
      socket.assigns.form.source
      |> Ecto.Changeset.put_change(:stream_server_id, String.to_integer(id))
      |> Map.update!(:errors, &Keyword.delete(&1, :stream_server_id))

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
          Public Keys
          <:subtitle>Signing key pairs registered for each stream server</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch="/admin/stream-servers/keys/generate"
              id="generate-public-key-link"
              class="btn btn-primary btn-sm"
            >
              Generate
            </.link>
            <.link
              :if={@live_action == :index}
              patch="/admin/stream-servers/keys/new"
              id="add-public-key-link"
              class="btn btn-primary btn-sm"
            >
              Add key
            </.link>
          </:actions>
        </.header>

        <p id="public-keys-description" class="mb-6 text-sm opacity-70">
          This application shares each public key below with the corresponding stream
          server. The stream server assigns it a public key ID, which it uses to pick
          the public key that verifies the signed JWT this application presents when a
          participant connects (audio/video/events). Private keys are stored encrypted
          and are never shown.
        </p>

        <div
          :if={@live_action in [:new, :edit, :generate]}
          id="public-key-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {form_title(@live_action)}
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
              <.input field={@form[:name]} label="Name" required autocomplete="off" />
              <.live_component
                module={DropdownComponent}
                id="stream-server"
                label="Stream server"
                field={@form[:stream_server_id]}
                options={for server <- @stream_servers, do: {server.name, server.id}}
                placeholder="Choose a stream server"
                value_key="id"
                on_change={fn id -> send(self(), {:stream_server_picked, id}) end}
              />
              <.input
                :if={@live_action == :new}
                field={@form[:public_key_id]}
                label="Public key ID"
                autocomplete="off"
              />
              <.input
                :if={@live_action in [:new, :edit]}
                field={@form[:public_key]}
                type="textarea"
                label="Public key"
                autocomplete="off"
              />
              <.input
                :if={@live_action in [:new, :edit]}
                field={@form[:private_key_pem]}
                type="textarea"
                label="Private key"
                placeholder={private_key_placeholder(@live_action)}
                autocomplete="off"
              />
              <.input
                :if={@live_action == :edit}
                field={@form[:public_key_id]}
                label="Public key ID"
                autocomplete="off"
              />
              <.input
                :if={@live_action in [:new, :edit]}
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
                  patch="/admin/stream-servers/keys"
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
          :if={@live_action == :index and @stream_servers == []}
          id="no-stream-servers"
          class="py-8 text-center"
        >
          No stream servers found
        </p>

        <div
          :for={server <- @stream_servers}
          :if={@live_action == :index}
          id={"stream-server-group-#{server.id}"}
          class="mb-6"
        >
          <h3 class="mb-2 text-lg font-semibold">
            {server.name}
            <span :if={server.host} class="text-sm font-normal opacity-60">{server.host}</span>
          </h3>
          <p
            :if={server.public_stream_server_keys == []}
            id={"no-keys-#{server.id}"}
            class="text-sm opacity-60"
          >
            No public keys yet
          </p>
          <div :if={server.public_stream_server_keys != []} class="overflow-x-auto">
            <table id={"public-keys-table-#{server.id}"} class="table table-sm sm:table-md">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Public key ID</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                <tr :for={key <- server.public_stream_server_keys} id={"public-key-row-#{key.id}"}>
                  <td>{key.name}</td>
                  <td>{key.public_key_id}</td>
                  <td class="max-w-64">
                    <button
                      :if={description_long?(key.description)}
                      type="button"
                      id={"key-description-#{key.id}"}
                      phx-click={
                        JS.toggle_class("hidden", to: "#key-description-short-#{key.id}")
                        |> JS.toggle_class("hidden", to: "#key-description-full-#{key.id}")
                      }
                      class="cursor-pointer text-left"
                      title="Show the full description"
                    >
                      <span id={"key-description-short-#{key.id}"}>
                        {truncated_description(key.description)}
                      </span>
                      <span
                        id={"key-description-full-#{key.id}"}
                        class="hidden whitespace-pre-wrap"
                      >
                        {key.description}
                      </span>
                    </button>
                    <span :if={not description_long?(key.description)}>{key.description}</span>
                  </td>
                  <td>{if key.disabled, do: "Disabled", else: "Enabled"}</td>
                  <td class="text-right whitespace-nowrap">
                    <.link
                      patch={"/admin/stream-servers/keys/#{key.id}/edit"}
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
    </Layouts.admin>
    """
  end

  defp form_title(:new), do: "Add public key"
  defp form_title(:generate), do: "Generate public key"
  defp form_title(:edit), do: "Edit public key"

  defp private_key_placeholder(:edit), do: "Leave blank to keep the current key"
  defp private_key_placeholder(_action), do: "-----BEGIN PRIVATE KEY-----"

  defp description_long?(description) when is_binary(description),
    do: String.length(description) > 80

  defp description_long?(_description), do: false

  defp truncated_description(description) when is_binary(description),
    do: String.slice(description, 0, 80) <> "..."
end
