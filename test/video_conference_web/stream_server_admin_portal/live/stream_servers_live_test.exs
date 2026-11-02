defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServersLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConference.StreamServers.Countries

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_stream_server_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin/stream-servers")
  end

  test "sidebar links to stream servers", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    assert has_element?(
             lv,
             ~s|a#sidebar-stream-servers-link[href="/stream-server-admin/stream-servers"]|
           )
  end

  test "lists all stream servers with host, flag, cert hash, applications, and actions",
       %{conn: conn} do
    application = application_fixture(%{"name" => "chipped app"})

    server =
      stream_server_fixture(%{
        "name" => "edge-de",
        "host" => "10.0.0.1:443",
        "country" => "de",
        "cert_hash" => "abc"
      })

    plain = stream_server_fixture(%{"name" => "edge-none"})
    {:ok, _} = StreamServers.assign_applications(server, [application.id])

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge-de")
    assert has_element?(lv, "#stream-server-row-#{server.id}", "10.0.0.1:443")
    assert has_element?(lv, "#stream-server-row-#{server.id}", Countries.flag("de"))
    assert has_element?(lv, "#cert-hash-#{server.id}", "Set")
    assert has_element?(lv, "#cert-hash-#{plain.id}", "—")

    assert has_element?(lv, "#copy-cert-hash-#{server.id}")
    assert has_element?(lv, "#cert-hash-value-#{server.id}.hidden", "abc")
    refute has_element?(lv, "#copy-cert-hash-#{plain.id}")

    assert has_element?(
             lv,
             "#application-chip-#{server.id}-#{application.id}",
             "chipped app"
           )

    assert has_element?(lv, "#edit-stream-server-#{server.id}")
    assert has_element?(lv, "#assign-stream-server-#{server.id}")
    assert has_element?(lv, "#delete-stream-server-#{server.id}")
  end

  test "filters stream servers by application", %{conn: conn} do
    application = application_fixture()
    assigned = stream_server_fixture(%{"name" => "assigned"})
    _other = stream_server_fixture(%{"name" => "other"})
    {:ok, _} = StreamServers.assign_applications(assigned, [application.id])

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/stream-servers?application_id=#{application.id}"
    )

    assert has_element?(lv, "#stream-server-row-#{assigned.id}")
    refute has_element?(lv, "tr[id^=stream-server-row-]", "other")
  end

  test "filters to unassigned stream servers", %{conn: conn} do
    application = application_fixture()
    assigned = stream_server_fixture(%{"name" => "assigned"})
    unassigned = stream_server_fixture(%{"name" => "unassigned"})
    {:ok, _} = StreamServers.assign_applications(assigned, [application.id])

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-filter-dropdown button[phx-value-id="unassigned"]|)
    |> render_click()

    assert_patch(lv, "/stream-server-admin/stream-servers?application_id=unassigned")
    assert has_element?(lv, "#stream-server-row-#{unassigned.id}")
    refute has_element?(lv, "#stream-server-row-#{assigned.id}")
  end

  test "filter options are searchable", %{conn: conn} do
    application = application_fixture(%{"name" => "zucchini app"})
    _other = application_fixture(%{"name" => "apple app"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    assert has_element?(
             lv,
             ~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|
           )

    lv
    |> element("#application-filter-search")
    |> render_change(%{"application-filter_search" => "zucch"})

    assert has_element?(
             lv,
             ~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|
           )

    refute has_element?(lv, "#application-filter-dropdown button", "apple app")
  end

  test "clearing the filter lists every server again", %{conn: conn} do
    application = application_fixture()
    assigned = stream_server_fixture(%{"name" => "assigned"})
    unassigned = stream_server_fixture(%{"name" => "unassigned"})
    {:ok, _} = StreamServers.assign_applications(assigned, [application.id])

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers?application_id=unassigned")

    refute has_element?(lv, "#stream-server-row-#{assigned.id}")

    lv |> element("#application-filter-dropdown-button") |> render_click()
    lv |> element("#application-filter-option-none") |> render_click()

    assert_patch(lv, "/stream-server-admin/stream-servers")
    assert has_element?(lv, "#stream-server-row-#{assigned.id}")
    assert has_element?(lv, "#stream-server-row-#{unassigned.id}")
  end

  test "adds a stream server", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()

    lv
    |> element(~s|#country-dropdown button[phx-value-code="jp"]|)
    |> render_click()

    lv
    |> form("#stream-server-form",
      stream_server: %{
        "name" => "new server",
        "host" => "203.0.113.10",
        "cert_hash" => "deadbeef"
      }
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/stream-servers")
    assert render(lv) =~ "new server"

    server = Enum.find(StreamServers.list_stream_servers(), &(&1.name == "new server"))
    assert server.host == "203.0.113.10"
    assert server.country == "jp"
    assert server.cert_hash == "deadbeef"
    assert server.settings == %{}
  end

  test "shows an inline error on a blank name", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/new")

    lv
    |> form("#stream-server-form", stream_server: %{"name" => ""})
    |> render_submit()

    assert has_element?(lv, "#stream-server-form p.text-error", "can't be blank")
  end

  test "shows an inline error on a duplicate name", %{conn: conn} do
    _server = stream_server_fixture(%{"name" => "taken"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/new")

    html =
      lv
      |> form("#stream-server-form", stream_server: %{"name" => "taken"})
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "edits a stream server", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge-1", "host" => "1.1.1.1"})

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/edit")

    lv
    |> form("#stream-server-form",
      stream_server: %{"name" => "edge-renamed", "host" => "2.2.2.2:443"}
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/stream-servers")

    updated = StreamServers.get_stream_server!(server.id)
    assert updated.name == "edge-renamed"
    assert updated.host == "2.2.2.2:443"
    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge-renamed")
  end

  test "clears the cert hash on edit", %{conn: conn} do
    server = stream_server_fixture(%{"cert_hash" => "abc"})

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/edit")

    lv
    |> form("#stream-server-form", stream_server: %{"cert_hash" => ""})
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/stream-servers")
    assert StreamServers.get_stream_server!(server.id).cert_hash == nil
    assert has_element?(lv, "#cert-hash-#{server.id}", "—")
  end

  test "removes a stream server and its assignments", %{conn: conn} do
    application = application_fixture()
    server = stream_server_fixture(%{"name" => "to remove"})
    {:ok, _} = StreamServers.assign_applications(server, [application.id])

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#delete-stream-server-#{server.id}") |> render_click()

    refute has_element?(lv, "#stream-server-row-#{server.id}")

    assert_raise Ecto.NoResultsError, fn ->
      StreamServers.get_stream_server!(server.id)
    end

    assert StreamServers.list_stream_servers(application_id: application.id) == []
  end

  test "assign view lists applications as checkboxes and saves the selection",
       %{conn: conn} do
    app1 = application_fixture(%{"name" => "app one"})
    app2 = application_fixture(%{"name" => "app two"})
    server = stream_server_fixture(%{"name" => "edge"})
    {:ok, _} = StreamServers.assign_applications(server, [app1.id])

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    assert render(lv) =~ "Assign applications to edge"
    assert has_element?(lv, "#assign-application-#{app1.id}[checked]")
    refute has_element?(lv, "#assign-application-#{app2.id}[checked]")

    lv
    |> element("#assign-form")
    |> render_submit(%{"application_ids" => ["", app2.id]})

    assert_patch(lv, "/stream-server-admin/stream-servers")

    assigned = Enum.map(StreamServers.get_stream_server!(server.id).applications, & &1.id)
    assert assigned == [app2.id]

    assert has_element?(lv, "#application-chip-#{server.id}-#{app2.id}")
    refute has_element?(lv, "#application-chip-#{server.id}-#{app1.id}")
  end

  test "assign view supports multiple applications and cancel returns to the list",
       %{conn: conn} do
    app1 = application_fixture()
    app2 = application_fixture()
    server = stream_server_fixture()

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    lv
    |> element("#assign-form")
    |> render_submit(%{"application_ids" => ["", app1.id, app2.id]})

    assert_patch(lv, "/stream-server-admin/stream-servers")

    assigned = StreamServers.get_stream_server!(server.id).applications
    assert Enum.map(assigned, & &1.id) |> Enum.sort() == Enum.sort([app1.id, app2.id])

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    lv |> element("#cancel-assign-form") |> render_click()
    assert_patch(lv, "/stream-server-admin/stream-servers")
  end
end
