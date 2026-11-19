defmodule VideoConferenceWeb.StreamServerAdminPortal.DashboardLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  test "redirects unauthenticated visitors to the log-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin")
  end

  test "renders the dashboard with the current admin", %{conn: conn} do
    admin = admin_fixture()

    {:ok, lv, html} = live(conn |> log_in_stream_server_admin(admin), "/stream-server-admin")

    assert html =~ "Stream Server Admin Dashboard"
    assert html =~ admin.email

    # portal sidebar: dashboard link, admin email, settings link and
    # form-based log out
    assert has_element?(lv, "aside#stream-server-admin-sidebar")
    assert has_element?(lv, ~s|a#sidebar-dashboard-link[href="/stream-server-admin"]|)
    assert has_element?(lv, "#stream-server-admin-sidebar-email", admin.email)
    assert has_element?(lv, ~s|a#sidebar-settings-link[href="/stream-server-admin/settings"]|)

    assert has_element?(
             lv,
             ~s|a#sidebar-change-password-link[href="/stream-server-admin/settings"]|
           )

    assert has_element?(lv, ~s|form[action="/stream-server-admin/log-out"][method="post"]|)
    assert has_element?(lv, ~s|input[name="_method"][value="delete"]|)

    # navbar keeps the brand and the sidebar toggle
    assert has_element?(
             lv,
             ~s|button#stream-server-admin-sidebar-toggle[phx-click="toggle_admin_sidebar"]|
           )

    # mobile-first responsive markup
    assert html =~ "grid-cols-1"
    assert html =~ "sm:grid-cols-2"
    assert html =~ "sm:p-6"
  end

  test "opens and closes the sidebar drawer via the toggle and backdrop", %{conn: conn} do
    admin = admin_fixture()

    {:ok, lv, _html} = live(conn |> log_in_stream_server_admin(admin), "/stream-server-admin")

    # starts as a closed drawer: hidden below lg, always shown at lg+
    assert has_element?(lv, "aside#stream-server-admin-sidebar.hidden.lg\\:block")
    refute has_element?(lv, "#stream-server-admin-sidebar-backdrop")

    lv |> element("#stream-server-admin-sidebar-toggle") |> render_click()
    refute has_element?(lv, "aside#stream-server-admin-sidebar.hidden")
    assert has_element?(lv, "#stream-server-admin-sidebar-backdrop")

    lv |> element("#stream-server-admin-sidebar-backdrop") |> render_click()
    assert has_element?(lv, "aside#stream-server-admin-sidebar.hidden")
    refute has_element?(lv, "#stream-server-admin-sidebar-backdrop")
  end
end
