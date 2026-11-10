defmodule VideoConferenceWeb.StreamServerAdminPortal.ApplicationsLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Applications",
       modal: nil,
       modal_application: nil,
       modal_form: nil
     )}
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
         |> assign_applications()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The application cannot be removed")}
    end
  end

  def handle_event("toggle-enabled", %{"id" => id, "enabled" => enabled}, socket) do
    result =
      if enabled == "true",
        do: Applications.disable_application(id),
        else: Applications.enable_application(id)

    case result do
      {:ok, _application} ->
        {:noreply, assign_applications(socket)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "The enabled flag cannot be changed")}
    end
  end

  def handle_event("rename-application", %{"id" => id}, socket) do
    socket = open_modal(socket, :rename, id)
    application = socket.assigns.modal_application

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(Application.name_changeset(application, %{}), as: :rename_application)
     )}
  end

  def handle_event("edit-description", %{"id" => id}, socket) do
    socket = open_modal(socket, :edit_description, id)
    application = socket.assigns.modal_application

    {:noreply,
     assign(
       socket,
       :modal_form,
       to_form(%{"description" => application.description}, as: :application_description)
     )}
  end

  def handle_event("close-modal", _params, socket) do
    {:noreply, close_modal(socket)}
  end

  def handle_event("save-name", %{"rename_application" => %{"name" => name}}, socket) do
    case Applications.rename_application(socket.assigns.modal_application.id, name) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application renamed")
         |> close_modal()
         |> assign_applications()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :rename_application))}
    end
  end

  def handle_event(
        "save-description",
        %{"application_description" => %{"description" => description}},
        socket
      ) do
    case Applications.edit_application_description(
           socket.assigns.modal_application.id,
           description
         ) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Application description updated")
         |> close_modal()
         |> assign_applications()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :modal_form, to_form(changeset, as: :application_description))}
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

  defp open_modal(socket, modal, id) do
    assign(socket,
      modal: modal,
      modal_application: Applications.get_application!(id),
      modal_form: nil
    )
  end

  defp close_modal(socket) do
    assign(socket, modal: nil, modal_application: nil, modal_form: nil)
  end

  defp assign_applications(socket) do
    assign(socket, :applications, Applications.list_applications())
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
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
          :if={@live_action == :new}
          id="application-form-card"
          class="card bg-base-200 mb-6"
        >
          <div class="card-body">
            <h2 class="card-title">
              Add application
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
                <td class="whitespace-nowrap">
                  {application.name}
                  <button
                    type="button"
                    id={"rename-application-#{application.id}"}
                    phx-click="rename-application"
                    phx-value-id={application.id}
                    class="btn btn-ghost btn-xs btn-square"
                    title="Rename application"
                  >
                    <.icon name="hero-pencil" class="size-3.5" />
                  </button>
                </td>
                <td class="max-w-64">
                  <div class="flex items-start gap-1">
                    <div class="min-w-0 flex-1">
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
                        class="w-full cursor-pointer text-left"
                        title="Show the full description"
                      >
                        <span
                          id={"application-description-short-#{application.id}"}
                          class="break-all"
                        >
                          {truncated_description(application.description)}
                        </span>
                        <span
                          id={"application-description-full-#{application.id}"}
                          class="hidden whitespace-pre-wrap break-all"
                        >
                          {application.description}
                        </span>
                      </button>
                      <span
                        :if={not description_long?(application.description)}
                        class="break-all"
                      >
                        {application.description}
                      </span>
                    </div>
                    <button
                      type="button"
                      id={"edit-description-#{application.id}"}
                      phx-click="edit-description"
                      phx-value-id={application.id}
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
                    id={"enabled-application-#{application.id}"}
                    phx-click="toggle-enabled"
                    phx-value-id={application.id}
                    phx-value-enabled={to_string(application.enabled)}
                    checked={application.enabled}
                    class="checkbox checkbox-sm"
                    title="Toggle enabled"
                  />
                </td>
                <td class="text-right whitespace-nowrap">
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

        <.modal
          :if={@modal == :rename and @modal_application}
          id="rename-application-modal"
          title="Rename application"
        >
          <.form
            for={@modal_form}
            id="rename-application-form"
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
          :if={@modal == :edit_description and @modal_application}
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
      </div>
    </Layouts.stream_server_admin>
    """
  end
end
