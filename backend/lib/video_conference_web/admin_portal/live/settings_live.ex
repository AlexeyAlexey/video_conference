defmodule VideoConferenceWeb.AdminPortal.SettingsLive do
  use VideoConferenceWeb, :live_view

  alias VideoConference.AdminPortal.Accounts

  def mount(_params, _session, socket) do
    admin = socket.assigns.current_scope.admin

    socket =
      socket
      |> assign(page_title: "Admin Settings", trigger_submit: false)
      |> assign(password_form: to_form(Accounts.change_admin_password(admin)))

    {:ok, socket}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    password_form =
      socket.assigns.current_scope.admin
      |> Accounts.change_admin_password(admin_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("save", %{"admin" => admin_params}, socket) do
    changeset =
      socket.assigns.current_scope.admin
      |> Accounts.change_admin_password(admin_params,
        hash_password: false,
        validate_current: true
      )
      |> Map.put(:action, :validate)

    if changeset.valid? do
      {:noreply, assign(socket, password_form: to_form(changeset), trigger_submit: true)}
    else
      {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_scope={@current_scope}
      admin_sidebar_collapsed={@admin_sidebar_collapsed}
    >
      <div class="mx-auto w-full max-w-sm px-2 sm:px-0">
        <.header>
          Admin Settings
          <:subtitle>Change the password for {@current_scope.admin.email}</:subtitle>
        </.header>

        <.form
          for={@password_form}
          id="password_form"
          phx-change="validate"
          phx-submit="save"
          action="/admin/update-password"
          method="post"
          phx-trigger-action={@trigger_submit}
          class="mt-8 space-y-4"
        >
          <.input
            field={@password_form[:current_password]}
            type="password"
            label="Current password"
            autocomplete="current-password"
            required
          />
          <.input
            field={@password_form[:password]}
            type="password"
            label="New password"
            autocomplete="new-password"
            required
          />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            autocomplete="new-password"
            required
          />
          <.button class="btn btn-primary w-full" phx-disable-with="Saving...">
            Change password
          </.button>
        </.form>
      </div>
    </Layouts.admin>
    """
  end
end
