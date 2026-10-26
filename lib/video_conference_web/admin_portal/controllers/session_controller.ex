defmodule VideoConferenceWeb.AdminPortal.SessionController do
  use VideoConferenceWeb, :controller

  alias VideoConference.AdminPortal.Accounts
  alias VideoConferenceWeb.AdminPortal.AdminAuth

  def new(conn, _params) do
    render(conn, :log_in,
      form: Phoenix.Component.to_form(%{"email" => nil, "password" => nil}, as: :admin),
      page_title: "Admin Log In"
    )
  end

  def create(conn, %{"admin" => %{"email" => email, "password" => password}}) do
    if admin = Accounts.get_admin_by_email_and_password(email, password) do
      conn
      |> AdminAuth.log_in_admin(admin)
      |> put_flash(:info, "Welcome back!")
      |> redirect(to: "/admin")
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: "/admin/log-in")
    end
  end

  def update_password(conn, %{"admin" => admin_params}) do
    admin = conn.assigns.current_scope.admin

    case Accounts.update_admin_password(admin, admin_params) do
      {:ok, {_admin, _expired_tokens}} ->
        conn
        |> put_flash(:info, "Password updated successfully. Please log in again.")
        |> AdminAuth.log_out_admin()

      {:error, _changeset} ->
        conn
        |> put_flash(
          :error,
          "Password could not be updated. Please review the form and try again."
        )
        |> redirect(to: "/admin/settings")
    end
  end

  def delete(conn, _params) do
    AdminAuth.log_out_admin(conn)
  end
end
