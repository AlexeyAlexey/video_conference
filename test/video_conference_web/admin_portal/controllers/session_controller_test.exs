defmodule VideoConferenceWeb.AdminPortal.SessionControllerTest do
  use VideoConferenceWeb.ConnCase, async: false

  import VideoConference.AdminPortalFixtures

  setup %{conn: conn} do
    %{conn: conn, admin: admin_fixture()}
  end

  describe "GET /admin/log-in" do
    test "renders the log-in form posting to the session controller", %{conn: conn} do
      conn = get(conn, "/admin/log-in")

      assert html = html_response(conn, 200)
      assert html =~ "Admin Portal"
      assert html =~ ~s|action="/admin/log-in"|
      assert html =~ ~s|method="post"|
      assert html =~ ~s|name="admin[email]"|
      assert html =~ ~s|name="admin[password]"|
      # mobile-first responsive markup
      assert html =~ "max-w-sm"
      assert html =~ "sm:px-0"
    end

    test "does not render the admin sidebar when signed out", %{conn: conn} do
      conn = get(conn, "/admin/log-in")

      assert html = html_response(conn, 200)
      refute html =~ ~s|id="admin-sidebar"|
      refute html =~ ~s|id="admin-sidebar-toggle"|
    end

    test "redirects an authenticated admin to the dashboard", %{conn: conn, admin: admin} do
      conn = conn |> log_in_admin(admin) |> get("/admin/log-in")
      assert redirected_to(conn) == "/admin"
    end
  end

  describe "POST /admin/log-in" do
    test "establishes a session and redirects to the dashboard", %{
      conn: conn,
      admin: admin
    } do
      conn =
        post(conn, "/admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => valid_admin_password()}
        })

      assert get_session(conn, :admin_token)
      assert redirected_to(conn) == "/admin"

      conn = get(recycle(conn), "/admin")
      assert html_response(conn, 200) =~ "Admin Dashboard"
    end

    test "redirects back with an error on a wrong password", %{conn: conn, admin: admin} do
      conn =
        post(conn, "/admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => "wrong password"}
        })

      refute get_session(conn, :admin_token)
      assert redirected_to(conn) == "/admin/log-in"

      conn = get(recycle(conn), "/admin/log-in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end

    test "renders the error flash with close and auto-dismiss hooks", %{
      conn: conn,
      admin: admin
    } do
      conn =
        post(conn, "/admin/log-in", %{
          "admin" => %{"email" => admin.email, "password" => "wrong password"}
        })

      conn = get(recycle(conn), "/admin/log-in")
      html = html_response(conn, 200)
      assert html =~ "data-flash-close"
      assert html =~ "data-flash-autohide"
    end

    test "redirects back with an error on an unknown email", %{conn: conn} do
      conn =
        post(conn, "/admin/log-in", %{
          "admin" => %{"email" => "unknown@example.com", "password" => "whatever"}
        })

      refute get_session(conn, :admin_token)
      assert redirected_to(conn) == "/admin/log-in"

      conn = get(recycle(conn), "/admin/log-in")
      assert html_response(conn, 200) =~ "Invalid email or password"
    end
  end

  describe "DELETE /admin/log-out" do
    test "invalidates the session and redirects to log-in", %{conn: conn, admin: admin} do
      conn = log_in_admin(conn, admin)
      token = get_session(conn, :admin_token)
      {:ok, decoded} = Base.url_decode64(token, padding: false)

      conn = delete(conn, "/admin/log-out")
      assert redirected_to(conn) == "/admin/log-in"
      refute get_session(conn, :admin_token)

      assert {:error, :not_found} =
               VideoConference.AdminPortal.Accounts.get_admin_by_session_token(decoded)

      conn = get(recycle(conn), "/admin")
      assert redirected_to(conn) == "/admin/log-in"
    end

    test "requires authentication", %{conn: conn} do
      conn = delete(conn, "/admin/log-out")
      assert redirected_to(conn) == "/admin/log-in"
    end
  end

  describe "POST /admin/update-password" do
    test "changes the password, logs the admin out, and redirects to log-in", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_admin(conn, admin)
      old_token = get_session(conn, :admin_token)
      {:ok, decoded} = Base.url_decode64(old_token, padding: false)

      conn =
        post(conn, "/admin/update-password", %{
          "admin" => %{
            "current_password" => valid_admin_password(),
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/admin/log-in"
      refute get_session(conn, :admin_token)

      assert {:error, :not_found} =
               VideoConference.AdminPortal.Accounts.get_admin_by_session_token(decoded)

      conn = get(recycle(conn), "/admin/log-in")
      assert html_response(conn, 200) =~ "Password updated successfully"

      conn = get(recycle(conn), "/admin")
      assert redirected_to(conn) == "/admin/log-in"

      assert VideoConference.AdminPortal.Accounts.get_admin_by_email_and_password(
               admin.email,
               "new password"
             )
    end

    test "redirects back to settings with an error on invalid input", %{
      conn: conn,
      admin: admin
    } do
      conn = log_in_admin(conn, admin)

      conn =
        post(conn, "/admin/update-password", %{
          "admin" => %{
            "current_password" => "wrong password",
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/admin/settings"
      assert get_session(conn, :admin_token)

      conn = get(recycle(conn), "/admin/settings")
      assert html_response(conn, 200) =~ "Password could not be updated"
    end

    test "requires authentication", %{conn: conn} do
      conn =
        post(conn, "/admin/update-password", %{
          "admin" => %{
            "current_password" => valid_admin_password(),
            "password" => "new password",
            "password_confirmation" => "new password"
          }
        })

      assert redirected_to(conn) == "/admin/log-in"
    end
  end
end
