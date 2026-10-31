defmodule VideoConferenceWeb.StreamServerAdminPortal.ApplicationsLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Applications")}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> assign(:applications, Applications.list_applications())
      |> apply_action(socket.assigns.live_action, params)

    {:noreply, socket}
  end

  defp apply_action(socket, :index, _params) do
    assign(socket, page_title: "Applications", application: nil, form: nil)
  end

  defp apply_action(socket, :new, _params) do
    application = %Application{}

    socket
    |> assign(page_title: "New Application", application: application)
    |> assign_form(Applications.change_application(application))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    application = Applications.get_application!(id)

    socket
    |> assign(page_title: "Edit #{application.name}", application: application)
    |> assign_form(Applications.change_application(application))
  end

  def handle_event("validate", %{"application" => application_params}, socket) do
    changeset =
      socket.assigns.application
      |> Applications.change_application(application_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"application" => application_params}, socket) do
    save_application(socket, socket.assigns.live_action, application_params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    application = Applications.get_application!(id)

    case Applications.delete_application(application) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application removed")
         |> assign(:applications, Applications.list_applications())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The application cannot be removed")}
    end
  end

  defp save_application(socket, :new, application_params) do
    case Applications.create_application(application_params) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application added")
         |> push_patch(to: "/stream-server-admin/applications")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_application(socket, :edit, application_params) do
    case Applications.update_application(socket.assigns.application, application_params) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application updated")
         |> push_patch(to: "/stream-server-admin/applications")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
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
          Applications
          <:subtitle>Third-party applications that call the stream server API</:subtitle>
          <:actions>
            <.link
              :if={@live_action == :index}
              patch="/stream-server-admin/applications/new"
              id="add-application-link"
              class="btn btn-primary btn-sm"
            >
              Add application
            </.link>
          </:actions>
        </.header>

        <div
          :if={@live_action in [:new, :edit]}
          id="application-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              {if @live_action == :new, do: "Add application", else: "Edit application"}
            </h2>
            <.form
              for={@form}
              id="application-form"
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
              <.input field={@form[:enabled]} type="checkbox" label="Enabled" />
              <div class="flex gap-2 pt-2">
                <.button class="btn btn-primary" phx-disable-with="Saving...">
                  Save
                </.button>
                <.link
                  patch="/stream-server-admin/applications"
                  id="cancel-application-form"
                  class="btn btn-ghost"
                >
                  Cancel
                </.link>
              </div>
            </.form>
          </div>
        </div>

        <div class="overflow-x-auto">
          <table id="applications-table" class="table table-sm sm:table-md">
            <thead>
              <tr>
                <th>Name</th>
                <th>Description</th>
                <th>Enabled</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr :for={application <- @applications} id={"application-row-#{application.id}"}>
                <td>{application.name}</td>
                <td class="max-w-64">
                  <button
                    :if={description_long?(application.description)}
                    type="button"
                    id={"application-description-#{application.id}"}
                    phx-click={
                      JS.toggle_class("hidden",
                        to: "#application-description-short-#{application.id}"
                      )
                      |> JS.toggle_class("hidden",
                        to: "#application-description-full-#{application.id}"
                      )
                    }
                    class="cursor-pointer text-left"
                    title="Show the full description"
                  >
                    <span id={"application-description-short-#{application.id}"}>
                      {truncated_description(application.description)}
                    </span>
                    <span
                      id={"application-description-full-#{application.id}"}
                      class="hidden whitespace-pre-wrap"
                    >
                      {application.description}
                    </span>
                  </button>
                  <span :if={not description_long?(application.description)}>
                    {application.description}
                  </span>
                </td>
                <td>{if application.enabled, do: "Yes", else: "No"}</td>
                <td class="text-right whitespace-nowrap">
                  <.link
                    patch={"/stream-server-admin/applications/#{application.id}/edit"}
                    id={"edit-application-#{application.id}"}
                    class="btn btn-ghost btn-xs"
                  >
                    Edit
                  </.link>
                  <button
                    id={"delete-application-#{application.id}"}
                    type="button"
                    phx-click="delete"
                    phx-value-id={application.id}
                    data-confirm={"Remove #{application.name} and all of its API keys?"}
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
