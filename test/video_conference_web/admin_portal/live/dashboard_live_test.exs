defmodule VideoConferenceWeb.AdminPortal.DashboardLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.AdminPortalFixtures

  test "redirects unauthenticated visitors to the log-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, "/admin")
  end

  test "renders the dashboard with the current admin", %{conn: conn} do
    admin = admin_fixture()

    {:ok, lv, html} = live(conn |> log_in_admin(admin), "/admin")

    assert html =~ "Admin Dashboard"
    assert html =~ admin.email
    # admin navigation bar: admin email, settings link and form-based log out
    assert has_element?(lv, "#admin-navbar-email", admin.email)
    assert has_element?(lv, ~s|a#nav-settings-link[href="/admin/settings"]|)
    assert has_element?(lv, ~s|form[action="/admin/log-out"][method="post"]|)
    assert has_element?(lv, ~s|input[name="_method"][value="delete"]|)

    # mobile-first responsive markup
    assert html =~ "grid-cols-1"
    assert html =~ "sm:grid-cols-2"
    assert html =~ "sm:p-6"
  end
end
