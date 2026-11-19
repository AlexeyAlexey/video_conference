defmodule VideoConferenceWeb.AdminPortal.KnownHostsLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.AdminPortal.KnownHosts
  alias VideoConference.AdminPortal.KnownHosts.KnownHost

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Known Hosts")}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:known_hosts, KnownHosts.list_known_hosts())
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Known Hosts", known_host: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    known_host = %KnownHost{}

    socket
    |> assign(page_title: "New Known Host", known_host: known_host)
    |> assign_form(KnownHosts.change_known_host(known_host))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    known_host = KnownHosts.get_known_host!(id)

    socket
    |> assign(page_title: "Edit #{known_host.name}", known_host: known_host)
    |> assign_form(KnownHosts.change_known_host(known_host))
  end

  def handle_event("validate", %{"known_host" => known_host_params}, socket) do
    changeset =
      socket.assigns.known_host
      |> KnownHosts.change_known_host(known_host_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"known_host" => known_host_params}, socket) do
    save_known_host(socket, socket.assigns.live_action, known_host_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    known_host = KnownHosts.get_known_host!(id)

    case KnownHosts.delete_known_host(known_host) do
      {:ok, _known_host} ->
        {:noreply,
         socket
         |> put_flash(:info, "Known host removed")
         |> assign(:known_hosts, KnownHosts.list_known_hosts())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The current host cannot be removed")}
    end
  end

  defp save_known_host(socket, :new, known_host_params) do
    case KnownHosts.create_known_host(known_host_params) do
      {:ok, _known_host} ->
        {:noreply,
         socket
         |> put_flash(:info, "Known host added")
         |> push_patch(to: "/admin/known-hosts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_known_host(socket, :edit, known_host_params) do
    case KnownHosts.update_known_host(socket.assigns.known_host, known_host_params) do
      {:ok, _known_host} ->
        {:noreply,
         socket
         |> put_flash(:info, "Known host updated")
         |> push_patch(to: "/admin/known-hosts")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
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
          Known Hosts
          <:subtitle>Peer instances this host knows about</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch="/admin/known-hosts/new"
              id="add-known-host-link"
              class="btn btn-primary btn-sm"
            >
              Add host
            </.link>
          </:actions>
        </.header>

        <div
          :if={@live_action in [:new, :edit]}
          id="known-host-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {if @live_action == :new, do: "Add known host", else: "Edit known host"}
            </h2>
            <.form
              for={@form}
              id="known-host-form"
              phx-change="validate"
              phx-submit="save"
              class="space-y-2"
              autocomplete="off"
              novalidate
            >
              <.input
                field={@form[:name]}
                label="Name"
                required
                disabled={@known_host.current_host}
                autocomplete="off"
              />
              <.input field={@form[:name_alias]} label="Alias" autocomplete="off" />
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
              <.input
                field={@form[:enabled]}
                type="checkbox"
                label="Enabled"
                disabled={@known_host.current_host}
              />
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link patch="/admin/known-hosts" id="cancel-known-host-form" class="btn btn-ghost">
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table id="known-hosts-table" class="table table-sm sm:table-md">
            <thead>
              <tr>
                <th>Name</th>
                <th>Alias</th>
                <th>Host</th>
                <th>Status</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={host <- @known_hosts} id={"known-host-row-#{host.id}"}>
                <td>
                  {host.name}
                  <span :if={host.current_host} class="badge badge-primary badge-sm ml-2">Current</span>
                </td>
                <td>{host.name_alias}</td>
                <td>{host.host}</td>
                <td>{if host.enabled, do: "Enabled", else: "Disabled"}</td>
                <td class="text-right whitespace-nowrap">
                  <.link
                    patch={"/admin/known-hosts/#{host.id}/edit"}
                    id={"edit-known-host-#{host.id}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Edit
                  </.link>
                  <button
                    :if={not host.current_host}
                    id={"delete-known-host-#{host.id}"}
                    type="button"
                    phx-click="delete"
                    phx-value-id={host.id}
                    data-confirm={"Remove #{host.name}?"}
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
