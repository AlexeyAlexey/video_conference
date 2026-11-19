defmodule VideoConferenceWeb.AdminPortal.AdminAuth do
  @moduledoc """
  Authentication plugs and LiveView hooks for the admin portal.

  Admin routes live under the `"/admin"` prefix forwarded to
  `VideoConferenceWeb.AdminPortal.Router`, so redirects use literal
  paths instead of verified routes.
  """

  import Plug.Conn
  import Phoenix.Controller

  alias VideoConference.AdminPortal.Accounts
  alias VideoConference.AdminPortal.Accounts.Scope

  @doc """
  Logs the admin in.

  It renews the session ID and clears the whole session to avoid
  fixation attacks, then stores the admin session token in the session.
  """
  def log_in_admin(conn, admin, _params \\ %{}) do
    token = Accounts.generate_session_token(admin)

    conn
    |> renew_session()
    |> put_session(:admin_token, token)
  end

  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the admin out.

  It deletes the admin session token from the database, clears the
  session, and redirects to the admin log-in page.
  """
  def log_out_admin(conn) do
    with admin_token when is_binary(admin_token) <- get_session(conn, :admin_token),
         {:ok, token} <- Base.url_decode64(admin_token, padding: false) do
      Accounts.delete_session_token(token)
    end

    conn
    |> renew_session()
    |> redirect(to: "/admin/log-in")
  end

  @doc """
  Authenticates the admin by looking into the session.

  Assigns `current_scope` based on the `:admin_token` stored in the
  session, or `nil` when there is no valid token.
  """
  def fetch_current_scope_for_admin(conn, _opts) do
    with token when is_binary(token) <- get_session(conn, :admin_token),
         {:ok, token} <- Base.url_decode64(token, padding: false),
         {:ok, {admin, _token_inserted_at}} <- Accounts.get_admin_by_session_token(token) do
      assign(conn, :current_scope, Scope.for(admin))
    else
      _ -> assign(conn, :current_scope, Scope.for(nil))
    end
  end

  @doc """
  Plug for routes that require the admin to be authenticated.
  """
  def require_authenticated_admin(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.admin do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/admin/log-in")
      |> halt()
    end
  end

  @doc """
  Plug for routes that require the admin to not be authenticated.
  """
  def redirect_if_admin_is_authenticated(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.admin do
      conn
      |> redirect(to: "/admin")
      |> halt()
    else
      conn
    end
  end

  @doc """
  `on_mount` hooks for admin LiveViews.
  """
  def on_mount(:mount_current_scope, _params, session, socket) do
    {:cont, mount_current_scope(socket, session)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.admin do
      {:cont, socket}
    else
      socket =
        socket
        |> Phoenix.LiveView.put_flash(:error, "You must log in to access this page.")
        |> Phoenix.LiveView.redirect(to: "/admin/log-in")

      {:halt, socket}
    end
  end

  def on_mount(:admin_sidebar, _params, _session, socket) do
    {:cont,
     socket
     |> Phoenix.Component.assign(:admin_sidebar_collapsed, true)
     |> Phoenix.LiveView.attach_hook(:toggle_admin_sidebar, :handle_event, fn
       "toggle_admin_sidebar", _params, socket ->
         {:halt,
          Phoenix.Component.assign(
            socket,
            :admin_sidebar_collapsed,
            not socket.assigns.admin_sidebar_collapsed
          )}

       _event, _params, socket ->
         {:cont, socket}
     end)
     |> Phoenix.LiveView.attach_hook(:close_admin_sidebar_on_navigate, :handle_params, fn
       # The collapsed flag only affects the below-lg drawer; on lg+ the
       # sidebar is permanent, so collapsing here is free and closes the
       # drawer after the admin picks a destination.
       _params, _uri, socket ->
         {:cont, Phoenix.Component.assign(socket, :admin_sidebar_collapsed, true)}
     end)}
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_scope(socket, session)

    if socket.assigns.current_scope && socket.assigns.current_scope.admin do
      {:halt, Phoenix.LiveView.redirect(socket, to: "/admin")}
    else
      {:cont, socket}
    end
  end

  defp mount_current_scope(socket, session) do
    Phoenix.Component.assign(socket, :current_scope, session_scope(session))
  end

  defp session_scope(%{"admin_token" => admin_token}) when is_binary(admin_token) do
    with {:ok, token} <- Base.url_decode64(admin_token, padding: false),
         {:ok, {admin, _token_inserted_at}} <- Accounts.get_admin_by_session_token(token) do
      Scope.for(admin)
    else
      _ -> Scope.for(nil)
    end
  end

  defp session_scope(_session), do: Scope.for(nil)
end
