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

    # admin sidebar: dashboard link, admin email, settings link and
    # form-based log out
    assert has_element?(lv, "aside#admin-sidebar")
    assert has_element?(lv, ~s|a#sidebar-dashboard-link[href="/admin"]|)
    assert has_element?(lv, "#admin-sidebar-email", admin.email)
    assert has_element?(lv, ~s|a#sidebar-known-hosts-link[href="/admin/known-hosts"]|)
    assert has_element?(lv, ~s|a#sidebar-settings-link[href="/admin/settings"]|)
    assert has_element?(lv, ~s|a#sidebar-change-password-link[href="/admin/settings"]|)
    assert has_element?(lv, ~s|form[action="/admin/log-out"][method="post"]|)
    assert has_element?(lv, ~s|input[name="_method"][value="delete"]|)

    # navbar keeps the brand and the sidebar toggle
    assert has_element?(lv, ~s|button#admin-sidebar-toggle[phx-click="toggle_admin_sidebar"]|)

    # mobile-first responsive markup
    assert html =~ "grid-cols-1"
    assert html =~ "sm:grid-cols-2"
    assert html =~ "sm:p-6"
  end

  test "opens and closes the sidebar drawer via the toggle and backdrop", %{conn: conn} do
    admin = admin_fixture()

    {:ok, lv, _html} = live(conn |> log_in_admin(admin), "/admin")

    # starts as a closed drawer: hidden below lg, always shown at lg+
    assert has_element?(lv, "aside#admin-sidebar.hidden.lg\\:block")
    refute has_element?(lv, "#admin-sidebar-backdrop")

    lv |> element("#admin-sidebar-toggle") |> render_click()
    refute has_element?(lv, "aside#admin-sidebar.hidden")
    assert has_element?(lv, "#admin-sidebar-backdrop")

    lv |> element("#admin-sidebar-backdrop") |> render_click()
    assert has_element?(lv, "aside#admin-sidebar.hidden")
    refute has_element?(lv, "#admin-sidebar-backdrop")
  end
end
