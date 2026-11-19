defmodule VideoConferenceWeb.StreamServerAdminPortal.SettingsLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Accounts

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_stream_server_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin/settings")
  end

  test "renders the password form", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/stream-server-admin/settings")

    assert html =~ "Stream Server Admin Settings"
    assert html =~ "max-w-sm"
    assert html =~ "sm:px-0"

    assert has_element?(
             lv,
             ~s|form#password_form[action="/stream-server-admin/update-password"]|
           )

    assert has_element?(lv, ~s|input[name="admin[current_password]"]|)
    assert has_element?(lv, ~s|input[name="admin[password]"]|)
    assert has_element?(lv, ~s|input[name="admin[password_confirmation]"]|)
  end

  test "updates the password and logs the admin out", %{conn: conn, admin: admin} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/settings")

    form =
      form(lv, "#password_form",
        admin: %{
          "current_password" => valid_admin_password(),
          "password" => "new password",
          "password_confirmation" => "new password"
        }
      )

    render_submit(form)

    new_conn = follow_trigger_action(form, conn)
    assert redirected_to(new_conn) == "/stream-server-admin/log-in"
    refute get_session(new_conn, :stream_server_admin_token)

    conn = get(recycle(new_conn), "/stream-server-admin")
    assert redirected_to(conn) == "/stream-server-admin/log-in"

    assert Accounts.get_admin_by_email_and_password(admin.email, "new password")
  end

  test "shows an error on a wrong current password", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/settings")

    html =
      lv
      |> form("#password_form",
        admin: %{
          "current_password" => "wrong password",
          "password" => "new password",
          "password_confirmation" => "new password"
        }
      )
      |> render_submit()

    assert html =~ "is not valid"
  end

  test "shows an error on mismatched confirmation", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/settings")

    html =
      lv
      |> form("#password_form",
        admin: %{
          "current_password" => valid_admin_password(),
          "password" => "new password",
          "password_confirmation" => "different password"
        }
      )
      |> render_submit()

    assert html =~ "does not match password"
  end
end
