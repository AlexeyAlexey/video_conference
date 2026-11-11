defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServersLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo
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

  test "lists all stream servers with host, flag, description, cert hash, applications, and actions",
       %{conn: conn} do
    application = application_fixture(%{"name" => "chipped app"})

    server =
      stream_server_fixture(%{
        "name" => "edge-de",
        "host" => "10.0.0.1:443",
        "country" => "de",
        "description" => "edge node",
        "cert_hash" => "abc"
      })

    plain = stream_server_fixture(%{"name" => "edge-none"})
    {:ok, _} = StreamServers.assign_application(server.id, application.id)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge-de")
    assert has_element?(lv, "#stream-server-row-#{server.id}", "10.0.0.1:443")
    assert has_element?(lv, "#stream-server-row-#{server.id}", Countries.flag("de"))
    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge node")
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

    assert has_element?(lv, "#rename-server-#{server.id}")
    assert has_element?(lv, "#edit-description-#{server.id}")
    assert has_element?(lv, "#edit-country-#{server.id}")
    assert has_element?(lv, "#edit-cert-hash-#{server.id}")
    assert has_element?(lv, "#assign-stream-server-#{server.id}")
    refute has_element?(lv, "#delete-stream-server-#{server.id}")
    refute has_element?(lv, "button", "Remove")
  end

  test "the description column truncates long descriptions with an expandable control",
       %{conn: conn} do
    long = String.duplicate("x", 60)
    server = stream_server_fixture(%{"description" => long})
    short = stream_server_fixture(%{"description" => "short desc"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    assert has_element?(
             lv,
             "#server-description-short-#{server.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#server-description-full-#{server.id}.hidden", long)
    assert has_element?(lv, "#server-description-#{server.id}[phx-click]")

    # description content wraps inside its column instead of overlapping
    assert has_element?(
             lv,
             "#server-description-full-#{server.id}.break-all.whitespace-pre-wrap"
           )

    assert has_element?(lv, "#server-description-short-#{server.id}.break-all")
    refute render(lv) =~ long <> "..."

    # short descriptions render as plain text without a toggle
    assert has_element?(lv, "#stream-server-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#server-description-#{short.id}")
  end

  test "filters stream servers by application", %{conn: conn} do
    application = application_fixture()
    assigned = stream_server_fixture(%{"name" => "assigned"})
    _other = stream_server_fixture(%{"name" => "other"})
    {:ok, _} = StreamServers.assign_application(assigned.id, application.id)

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
    {:ok, _} = StreamServers.assign_application(assigned.id, application.id)

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
    {:ok, _} = StreamServers.assign_application(assigned.id, application.id)

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

  test "adds a stream server with a name another server already has", %{conn: conn} do
    _server = stream_server_fixture(%{"name" => "taken"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/new")

    lv
    |> form("#stream-server-form",
      stream_server: %{"name" => "taken", "host" => "203.0.113.20"}
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/stream-servers")

    assert Enum.count(StreamServers.list_stream_servers(), &(&1.name == "taken")) == 2
  end

  test "shows an inline error on a duplicate host", %{conn: conn} do
    _server = stream_server_fixture(%{"host" => "10.0.0.1:443"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/new")

    lv
    |> form("#stream-server-form",
      stream_server: %{"name" => "new", "host" => "10.0.0.1:443"}
    )
    |> render_submit()

    assert has_element?(lv, "#stream-server-form p.text-error", "has already been taken")
  end

  test "renames a server through the name pencil modal", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge-1", "host" => "1.1.1.1"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#rename-server-#{server.id}") |> render_click()

    assert has_element?(lv, "#rename-server-modal")

    lv
    |> form("#rename-server-form", rename_server: %{"name" => "edge-renamed"})
    |> render_submit()

    updated = StreamServers.get_stream_server!(server.id)
    assert updated.name == "edge-renamed"
    assert updated.host == "1.1.1.1"

    refute has_element?(lv, "#rename-server-modal")
    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge-renamed")
  end

  test "renames a server to a name another server already has", %{conn: conn} do
    _other = stream_server_fixture(%{"name" => "taken"})
    server = stream_server_fixture(%{"name" => "edge-1"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#rename-server-#{server.id}") |> render_click()

    lv
    |> form("#rename-server-form", rename_server: %{"name" => "taken"})
    |> render_submit()

    refute has_element?(lv, "#rename-server-modal")
    assert StreamServers.get_stream_server!(server.id).name == "taken"
  end

  test "edits a server's description through the description pencil modal", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#edit-description-#{server.id}") |> render_click()

    assert has_element?(lv, "#edit-description-modal")

    lv
    |> form("#edit-description-form",
      server_description: %{"description" => "new desc"}
    )
    |> render_submit()

    assert StreamServers.get_stream_server!(server.id).description == "new desc"

    refute has_element?(lv, "#edit-description-modal")
    assert has_element?(lv, "#stream-server-row-#{server.id}", "new desc")
  end

  test "edits a server's country through the country pencil modal", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge", "country" => "de"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#edit-country-#{server.id}") |> render_click()

    assert has_element?(lv, "#edit-country-modal")
    assert has_element?(lv, "#edit-country-dropdown-button")

    lv |> element("#edit-country-dropdown-button") |> render_click()

    # the dropdown is searchable to simplify finding the country
    assert has_element?(lv, "#edit-country-search")

    lv
    |> element("#edit-country-search")
    |> render_change(%{"edit-country_search" => "japan"})

    refute has_element?(lv, "#edit-country-dropdown button", Countries.flag("de"))

    lv
    |> element(~s|#edit-country-dropdown button[phx-value-code="jp"]|)
    |> render_click()

    assert has_element?(lv, ~s|input[name="edit_country[country]"][value="jp"]|)

    lv |> form("#edit-country-form") |> render_submit()

    assert StreamServers.get_stream_server!(server.id).country == "jp"

    refute has_element?(lv, "#edit-country-modal")
    assert has_element?(lv, "#stream-server-row-#{server.id}", Countries.flag("jp"))
  end

  test "the country modal's empty choice clears the country", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge", "country" => "de"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#edit-country-#{server.id}") |> render_click()
    lv |> element("#edit-country-dropdown-button") |> render_click()
    lv |> element("#edit-country-option-none") |> render_click()

    assert has_element?(lv, ~s|input[name="edit_country[country]"][value=""]|)

    lv |> form("#edit-country-form") |> render_submit()

    assert StreamServers.get_stream_server!(server.id).country == nil
    refute has_element?(lv, "#edit-country-modal")
  end

  test "sets a certificate hash through the cert hash pencil modal", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    assert has_element?(lv, "#cert-hash-#{server.id}", "—")

    lv |> element("#edit-cert-hash-#{server.id}") |> render_click()

    assert has_element?(lv, "#edit-cert-hash-modal")

    lv
    |> form("#edit-cert-hash-form", server_cert_hash: %{"cert_hash" => "deadbeef"})
    |> render_submit()

    assert StreamServers.get_stream_server!(server.id).cert_hash == "deadbeef"

    refute has_element?(lv, "#edit-cert-hash-modal")
    assert has_element?(lv, "#cert-hash-#{server.id}", "Set")
    assert has_element?(lv, "#cert-hash-value-#{server.id}.hidden", "deadbeef")
  end

  test "clears a certificate hash by saving the cert hash modal blank", %{conn: conn} do
    server = stream_server_fixture(%{"cert_hash" => "abc"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    lv |> element("#edit-cert-hash-#{server.id}") |> render_click()

    lv
    |> form("#edit-cert-hash-form", server_cert_hash: %{"cert_hash" => ""})
    |> render_submit()

    assert StreamServers.get_stream_server!(server.id).cert_hash == nil

    refute has_element?(lv, "#edit-cert-hash-modal")
    assert has_element?(lv, "#cert-hash-#{server.id}", "—")
  end

  test "host has no edit affordance and no whole-row edit control", %{conn: conn} do
    server = stream_server_fixture(%{"host" => "1.1.1.1"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers")

    # the host cell renders plain text with no buttons
    refute has_element?(lv, "#stream-server-row-#{server.id} td:nth-child(2) button")
    refute has_element?(lv, "#edit-stream-server-#{server.id}")

    # editing every editable field leaves the stored host unchanged
    lv |> element("#rename-server-#{server.id}") |> render_click()

    lv
    |> form("#rename-server-form", rename_server: %{"name" => "x"})
    |> render_submit()

    lv |> element("#edit-description-#{server.id}") |> render_click()

    lv
    |> form("#edit-description-form", server_description: %{"description" => "y"})
    |> render_submit()

    lv |> element("#edit-cert-hash-#{server.id}") |> render_click()

    lv
    |> form("#edit-cert-hash-form", server_cert_hash: %{"cert_hash" => "z"})
    |> render_submit()

    assert StreamServers.get_stream_server!(server.id).host == "1.1.1.1"
  end

  test "the edit route is gone", %{conn: conn} do
    server = stream_server_fixture()

    conn = get(conn, "/stream-server-admin/stream-servers/#{server.id}/edit")

    assert conn.status == 404
  end

  test "assign view toggles application checkboxes immediately", %{conn: conn} do
    app1 = application_fixture(%{"name" => "app one"})
    app2 = application_fixture(%{"name" => "app two"})
    server = stream_server_fixture(%{"name" => "edge"})
    {:ok, _} = StreamServers.assign_application(server.id, app1.id)

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    assert render(lv) =~ "Assign applications to edge"
    assert has_element?(lv, "#assign-application-#{app1.id}[checked]")
    refute has_element?(lv, "#assign-application-#{app2.id}[checked]")

    # unchecking an assigned application removes the assignment at once
    lv |> element("#assign-application-#{app1.id}") |> render_click()

    assert StreamServers.get_stream_server!(server.id).applications == []
    refute has_element?(lv, "#assign-application-#{app1.id}[checked]")

    # checking an application assigns it at once
    lv |> element("#assign-application-#{app2.id}") |> render_click()

    assert Enum.map(StreamServers.get_stream_server!(server.id).applications, & &1.id) ==
             [app2.id]

    assert has_element?(lv, "#assign-application-#{app2.id}[checked]")
  end

  test "assign view back link returns to the list", %{conn: conn} do
    server = stream_server_fixture()

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    lv |> element("#back-to-stream-servers") |> render_click()

    assert_patch(lv, "/stream-server-admin/stream-servers")
  end

  test "assign view shows a back link and a notice when there are no applications",
       %{conn: conn} do
    PortalRepo.delete_all(Application)
    server = stream_server_fixture()

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/stream-servers/#{server.id}/assign")

    assert has_element?(lv, "#no-applications-to-assign", "No applications yet")
    assert has_element?(lv, "#back-to-stream-servers")
  end
end
