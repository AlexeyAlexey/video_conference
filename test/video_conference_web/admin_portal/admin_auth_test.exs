defmodule VideoConferenceWeb.AdminPortal.AdminAuthTest do
  use VideoConferenceWeb.ConnCase, async: false

  alias VideoConference.AdminPortal.Accounts
  alias VideoConferenceWeb.AdminPortal.AdminAuth

  import VideoConference.AdminPortalFixtures

  setup %{conn: conn} do
    %{conn: conn, admin: admin_fixture()}
  end

  describe "fetch_current_scope_for_admin/2" do
    test "assigns current_scope carrying the admin", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> AdminAuth.fetch_current_scope_for_admin([])

      assert conn.assigns.current_scope.admin.id == admin.id
    end

    test "assigns a nil scope when there is no token", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AdminAuth.fetch_current_scope_for_admin([])

      assert conn.assigns.current_scope == nil
    end

    test "assigns a nil scope for an invalid token", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{admin_token: "invalid"})
        |> AdminAuth.fetch_current_scope_for_admin([])

      assert conn.assigns.current_scope == nil
    end
  end

  describe "require_authenticated_admin/2" do
    test "redirects unauthenticated requests to the log-in page", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Phoenix.Controller.fetch_flash()
        |> AdminAuth.fetch_current_scope_for_admin([])
        |> AdminAuth.require_authenticated_admin([])

      assert conn.halted
      assert redirected_to(conn) == "/admin/log-in"

      assert get_session(conn, :phoenix_flash)["error"] ==
               "You must log in to access this page."
    end

    test "passes through when the admin is authenticated", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> AdminAuth.fetch_current_scope_for_admin([])
        |> AdminAuth.require_authenticated_admin([])

      refute conn.halted
    end
  end

  describe "redirect_if_admin_is_authenticated/2" do
    test "redirects authenticated admins to the dashboard", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_admin(admin)
        |> AdminAuth.fetch_current_scope_for_admin([])
        |> AdminAuth.redirect_if_admin_is_authenticated([])

      assert conn.halted
      assert redirected_to(conn) == "/admin"
    end

    test "passes through when unauthenticated", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AdminAuth.fetch_current_scope_for_admin([])
        |> AdminAuth.redirect_if_admin_is_authenticated([])

      refute conn.halted
    end
  end

  describe "log_in_admin/3" do
    test "stores the admin token in the session", %{conn: conn, admin: admin} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AdminAuth.log_in_admin(admin)

      assert token = get_session(conn, :admin_token)
      assert {:ok, decoded} = Base.url_decode64(token, padding: false)
      assert {:ok, {logged_in_admin, _}} = Accounts.get_admin_by_session_token(decoded)
      assert logged_in_admin.id == admin.id
    end
  end

  describe "log_out_admin/1" do
    test "deletes the session token and redirects to log-in", %{conn: conn, admin: admin} do
      conn = log_in_admin(conn, admin)
      token = get_session(conn, :admin_token)
      {:ok, decoded} = Base.url_decode64(token, padding: false)

      conn = AdminAuth.log_out_admin(conn)

      assert redirected_to(conn) == "/admin/log-in"
      assert {:error, :not_found} = Accounts.get_admin_by_session_token(decoded)
    end
  end
end
