defmodule VideoConferenceWeb.AdminPortal.KnownHostsLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.AdminPortalFixtures
  import VideoConference.KnownHostsFixtures

  alias VideoConference.AdminPortal.KnownHosts

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()
    assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, "/admin/known-hosts")
  end

  test "lists all known hosts with the current host badge", %{conn: conn} do
    host = known_host_fixture(%{"name" => "peer one", "host" => "10.0.0.5:4433"})
    current_host = current_host_fixture()

    {:ok, lv, html} = live(conn, "/admin/known-hosts")

    assert html =~ "peer one"
    assert html =~ "current host"
    assert html =~ "some alias"
    assert html =~ "10.0.0.5:4433"
    assert html =~ "Enabled"
    assert has_element?(lv, "#known-host-row-#{host.id}")
    assert has_element?(lv, "#known-host-row-#{current_host.id}")
    assert has_element?(lv, "#known-host-row-#{current_host.id} .badge", "Current")
    refute has_element?(lv, "#known-host-row-#{host.id} .badge", "Current")
  end

  test "links to known hosts from the sidebar", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/known-hosts")

    assert has_element?(lv, ~s|a#sidebar-known-hosts-link[href="/admin/known-hosts"]|)
  end

  test "adds a known host", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/known-hosts/new")

    lv
    |> form("#known-host-form",
      known_host: %{
        "name" => "new peer",
        "name_alias" => "peer alias",
        "host" => "192.168.0.2:4433"
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/known-hosts")

    html = render(lv)
    assert html =~ "new peer"
    assert html =~ "peer alias"

    assert Enum.any?(KnownHosts.list_known_hosts(), &(&1.name == "new peer"))
  end

  test "shows an inline error on a duplicate name", %{conn: conn} do
    host = known_host_fixture(%{"name" => "taken"})
    {:ok, lv, _html} = live(conn, "/admin/known-hosts/new")

    html =
      lv
      |> form("#known-host-form", known_host: %{"name" => "taken"})
      |> render_submit()

    assert html =~ "has already been taken"

    refute Enum.any?(
             KnownHosts.list_known_hosts(),
             &(&1.name == host.name and &1.id != host.id)
           )
  end

  test "edits a known host", %{conn: conn} do
    host = known_host_fixture(%{"name" => "peer"})
    {:ok, lv, _html} = live(conn, "/admin/known-hosts/#{host.id}/edit")

    lv
    |> form("#known-host-form",
      known_host: %{"name_alias" => "new alias", "host" => "10.1.2.3", "enabled" => "false"}
    )
    |> render_submit()

    assert_patch(lv, "/admin/known-hosts")

    updated = KnownHosts.get_known_host!(host.id)
    assert updated.name_alias == "new alias"
    assert updated.host == "10.1.2.3"
    assert updated.enabled == false
    assert render(lv) =~ "new alias"
  end

  test "removes a known host", %{conn: conn} do
    host = known_host_fixture(%{"name" => "to remove"})
    {:ok, lv, _html} = live(conn, "/admin/known-hosts")

    lv |> element("#delete-known-host-#{host.id}") |> render_click()

    refute has_element?(lv, "#known-host-row-#{host.id}")

    assert_raise Ecto.NoResultsError, fn -> KnownHosts.get_known_host!(host.id) end
  end

  test "current host row has no remove control and its form locks name and enabled",
       %{conn: conn} do
    current_host = current_host_fixture()

    {:ok, lv, _html} = live(conn, "/admin/known-hosts")

    assert has_element?(lv, "#known-host-row-#{current_host.id} .badge", "Current")
    assert has_element?(lv, "#edit-known-host-#{current_host.id}")
    refute has_element?(lv, "#delete-known-host-#{current_host.id}")

    {:ok, lv, _html} = live(conn, "/admin/known-hosts/#{current_host.id}/edit")

    assert has_element?(lv, ~s|input[name="known_host[name]"][disabled]|)
    assert has_element?(lv, ~s|input[name="known_host[enabled]"][disabled]|)
  end

  test "cannot disable the current host through the edit form", %{conn: conn} do
    current_host = current_host_fixture()
    {:ok, lv, _html} = live(conn, "/admin/known-hosts/#{current_host.id}/edit")

    html = render_submit(lv, "save", %{"known_host" => %{"enabled" => "false"}})

    assert html =~ "cannot be disabled"
    assert KnownHosts.get_known_host!(current_host.id).enabled == true
  end
end
