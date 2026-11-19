defmodule VideoConferenceWeb.StreamServerAdminPortal.SessionControllerTest do
  use VideoConferenceWeb.ConnCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Accounts

  setup %{conn: conn} do
    %{conn: conn, admin: admin_fixture()}
  end

  describe "GET /stream-server-admin/log-in" do
    test "renders the log-in form posting to the session controller", %{conn: conn} do
      conn = get(conn, "/stream-server-admin/log-in")

      assert html = html_response(conn, 200)
      assert html =~ "Stream Server Admin"
      assert html =~ ~s|action="/stream-server-admin/log-in"|
      assert html =~ ~s|method="post"|
      assert html =~ ~s|name="admin[email]"|
      assert html =~ ~s|name="admin[password]"|
      # mobile-first responsive markup
      assert html =~ "max-w-sm"
      assert html =~ "sm:px-0"
    end

    test "does not render the portal sidebar when signed out", %{conn: conn} do
      conn = get(conn, "/stream-server-admin/log-in")

      assert html = html_response(conn, 200)
      refute html =~ ~s|id="stream-server-admin-sidebar"|
      refute html =~ ~s|id="stream-server-admin-sidebar-toggle"|
    end

    test "redirects an authenticated admin to the dashboard", %{conn: conn, admin: admin} do
      conn = conn |> log_in_stream_server_admin(admin) |> get("/stream-server-admin/log-in")
      assert redirected_to(conn) == "/stream-server-admin"
    end
  end

  describe "POST /stream-server-admin/log-in" do
    test "establishes a session and redirects to the dashboard", %{
      conn: conn,
      admin: admin
    } do
      conn =
        post(conn, "/stream-server-admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert get_session(conn, :stream_server_admin_token)
      assert redirected_to(conn) == "/stream-server-admin"

      conn = get(recycle(conn), "/stream-server-admin")
      assert html_response(conn, 200) =~ "Stream Server Admin Dashboard"
    end

    test "redirects back with an error on a wrong password", %{conn: conn, admin: admin} do
      conn =
        post(conn, "/stream-server-admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => "wrong password"}
        })

      refute get_session(conn, :stream_server_admin_token)
      assert redirected_to(conn) == "/stream-server-admin/log-in"

      conn = get(recycle(conn), "/stream-server-admin/log-in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end

    test "renders the error flash with close and auto-dismiss hooks", %{
      conn: conn,
      admin: admin
    } do
      conn =
        post(conn, "/stream-server-admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => "wrong password"}
        })

      conn = get(recycle(conn), "/stream-server-admin/log-in")
      html = html_response(conn, 200)
      assert html =~ "data-flash-close"
      assert html =~ "data-flash-autohide"
    end

    test "redirects back with an error on an unknown email", %{conn: conn} do
      conn =
        post(conn, "/stream-server-admin/log-in", %{
          "admin" => %{"email" => "unknown@example.com", "password" => "whatever"}
        })

      refute get_session(conn, :stream_server_admin_token)
      assert redirected_to(conn) == "/stream-server-admin/log-in"

      conn = get(recycle(conn), "/stream-server-admin/log-in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "DELETE /stream-server-admin/log-out" do
    test "invalidates the session and redirects to log-in", %{conn: conn, admin: admin} do
      conn = log_in_stream_server_admin(conn, admin)
      token = get_session(conn, :stream_server_admin_token)
      {:ok, decoded} = Base.url_decode64(token, padding: false)

      conn = delete(conn, "/stream-server-admin/log-out")
      assert redirected_to(conn) == "/stream-server-admin/log-in"
      refute get_session(conn, :stream_server_admin_token)

      assert {:error, :not_found} = Accounts.get_admin_by_session_token(decoded)

      conn = get(recycle(conn), "/stream-server-admin")
      assert redirected_to(conn) == "/stream-server-admin/log-in"
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, "/stream-server-admin/log-out")
      assert redirected_to(conn) == "/stream-server-admin/log-in"
    end
  end

  describe "POST /stream-server-admin/update-password" do
    test "changes the password, logs the admin out, and redirects to log-in", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_stream_server_admin(conn, admin)
      old_token = get_session(conn, :stream_server_admin_token)
      {:ok, decoded} = Base.url_decode64(old_token, padding: false)

      conn =
        post(conn, "/stream-server-admin/update-password", %{
          "admin" => %{
            "current_password" => valid_admin_password(),
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/stream-server-admin/log-in"
      refute get_session(conn, :stream_server_admin_token)

      assert {:error, :not_found} = Accounts.get_admin_by_session_token(decoded)

      conn = get(recycle(conn), "/stream-server-admin/log-in")
      assert html_response(conn, 200) =~ "Password updated successfully"

      conn = get(recycle(conn), "/stream-server-admin")
      assert redirected_to(conn) == "/stream-server-admin/log-in"

      assert Accounts.get_admin_by_email_and_password(admin.email, "new password")
    end

    test "redirects back to settings with an error on invalid input", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_stream_server_admin(conn, admin)

      conn =
        post(conn, "/stream-server-admin/update-password", %{
          "admin" => %{
            "current_password" => "wrong password",
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/stream-server-admin/settings"
      assert get_session(conn, :stream_server_admin_token)

      conn = get(recycle(conn), "/stream-server-admin/settings")
      assert html_response(conn, 200) =~ "Password could not be updated"
    end

    test "requires authentication", %{conn: conn} do
      conn =
        post(conn, "/stream-server-admin/update-password", %{
          "admin" => %{
            "current_password" => valid_admin_password(),
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/stream-server-admin/log-in"
    end
  end

  describe "session independence" do
    test "an /admin session does not open the portal", %{conn: conn} do
      admin_portal_admin = VideoConference.AdminPortalFixtures.admin_fixture()

      conn =
        conn
        |> log_in_admin(admin_portal_admin)
        |> get("/stream-server-admin")

      assert redirected_to(conn) == "/stream-server-admin/log-in"
    end

    test "a portal session does not open the admin portal", %{conn: conn, admin: admin} do
      conn =
        conn
        |> log_in_stream_server_admin(admin)
        |> get("/admin")

      assert redirected_to(conn) == "/admin/log-in"
    end
  end
end
