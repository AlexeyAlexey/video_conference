defmodule VideoConferenceWeb.AdminPortal.SettingsLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.AdminPortalFixtures

  alias VideoConference.AdminPortal.Accounts

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()
    assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, "/admin/settings")
  end

  test "renders the password form", %{conn: conn} do
    {:ok, lv, html} = live(conn, "/admin/settings")

    assert html =~ "Admin Settings"
    assert html =~ "max-w-sm"
    assert html =~ "sm:px-0"
    assert has_element?(lv, ~s|form#password_form[action="/admin/update-password"]|)
    assert has_element?(lv, ~s|input[name="admin[current_password]"]|)
    assert has_element?(lv, ~s|input[name="admin[password]"]|)
    assert has_element?(lv, ~s|input[name="admin[password_confirmation]"]|)
  end

  test "updates the password and logs the admin out", %{conn: conn, admin: admin} do
    {:ok, lv, _html} = live(conn, "/admin/settings")

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
    assert redirected_to(new_conn) == "/admin/log-in"
    refute get_session(new_conn, :admin_token)

    conn = get(recycle(new_conn), "/admin")
    assert redirected_to(conn) == "/admin/log-in"

    assert Accounts.get_admin_by_email_and_password(admin.email, "new password")
  end

  test "shows an error on a wrong current password", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/settings")

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
    {:ok, lv, _html} = live(conn, "/admin/settings")

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
