defmodule VideoConferenceWeb.StreamServerAdminPortal.ApplicationStreamServersLiveTest do
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
             live(conn, "/stream-server-admin/applications/stream-servers")
  end

  test "links to application stream servers from the sidebar under applications",
       %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-servers")

    assert has_element?(
             lv,
             ~s|a#sidebar-application-stream-servers-link[href="/stream-server-admin/applications/stream-servers"]|
           )
  end

  test "prompts to select an application before listing servers", %{conn: conn} do
    application = application_fixture()
    server = stream_server_fixture()
    {:ok, _} = StreamServers.assign_application(server.id, application.id)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-servers")

    assert has_element?(lv, "#select-application-prompt")
    refute has_element?(lv, "#stream-servers-table")
    refute has_element?(lv, "#stream-server-row-#{server.id}")
  end

  test "picking an application lists only that app's assigned servers and updates the URL",
       %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    other = application_fixture(%{"name" => "metrics app"})
    server = stream_server_fixture(%{"name" => "edge-de"})
    other_server = stream_server_fixture(%{"name" => "edge-us"})
    {:ok, _} = StreamServers.assign_application(server.id, application.id)
    {:ok, _} = StreamServers.assign_application(other_server.id, other.id)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-servers")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    assert has_element?(
             lv,
             ~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|,
             "billing app"
           )

    refute has_element?(lv, "#application-filter-option-none")

    lv
    |> element(~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
    )

    assert has_element?(lv, "#stream-server-row-#{server.id}")
    refute has_element?(lv, "#stream-server-row-#{other_server.id}")
    refute has_element?(lv, "#select-application-prompt")
  end

  test "selection options are searchable", %{conn: conn} do
    application = application_fixture(%{"name" => "zucchini app"})
    _other = application_fixture(%{"name" => "apple app"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-servers")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element("#application-filter-search")
    |> render_change(%{"application-filter_search" => "zucch"})

    assert has_element?(
             lv,
             ~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|
           )

    refute has_element?(lv, "#application-filter-dropdown button", "apple app")
  end

  test "opening the page with an application_id param lists that app's servers",
       %{conn: conn} do
    application = application_fixture()
    server = stream_server_fixture()
    {:ok, _} = StreamServers.assign_application(server.id, application.id)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(lv, "#stream-server-row-#{server.id}")
    refute has_element?(lv, "#select-application-prompt")
  end

  test "each row shows name, host, country flag, description, and cert hash copy control",
       %{conn: conn} do
    application = application_fixture()

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
    {:ok, _} = StreamServers.assign_application(plain.id, application.id)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge-de")
    assert has_element?(lv, "#stream-server-row-#{server.id}", "10.0.0.1:443")
    assert has_element?(lv, "#stream-server-row-#{server.id}", Countries.flag("de"))
    assert has_element?(lv, "#stream-server-row-#{server.id}", "edge node")
    assert has_element?(lv, "#cert-hash-#{server.id}", "Set")
    assert has_element?(lv, "#cert-hash-#{plain.id}", "—")

    assert has_element?(
             lv,
             ~s|#copy-cert-hash-#{server.id}[onclick*="navigator.clipboard.writeText"]|
           )

    assert has_element?(lv, "#cert-hash-value-#{server.id}.hidden", "abc")
    refute has_element?(lv, "#copy-cert-hash-#{plain.id}")
  end

  test "the description column truncates long descriptions with an expandable control",
       %{conn: conn} do
    application = application_fixture()
    long = String.duplicate("x", 60)
    server = stream_server_fixture(%{"description" => long})
    short = stream_server_fixture(%{"description" => "short desc"})
    {:ok, _} = StreamServers.assign_application(server.id, application.id)
    {:ok, _} = StreamServers.assign_application(short.id, application.id)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(
             lv,
             "#server-description-short-#{server.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#server-description-full-#{server.id}.hidden", long)
    assert has_element?(lv, "#server-description-#{server.id}[phx-click]")

    assert has_element?(lv, "#stream-server-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#server-description-#{short.id}")
  end

  test "shows an empty list for an application without assigned servers", %{conn: conn} do
    application = application_fixture()
    other = application_fixture()
    server = stream_server_fixture()
    {:ok, _} = StreamServers.assign_application(server.id, other.id)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(lv, "#no-stream-servers", "No stream servers assigned")
    refute has_element?(lv, "#stream-servers-table")
    refute has_element?(lv, "#stream-server-row-#{server.id}")
  end

  test "the list is read-only: no add, edit, remove, assign, or applications column",
       %{conn: conn} do
    application = application_fixture(%{"name" => "chipped app"})
    server = stream_server_fixture(%{"country" => "de", "cert_hash" => "abc"})
    {:ok, _} = StreamServers.assign_application(server.id, application.id)

    {:ok, lv, html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    refute has_element?(lv, "#add-stream-server-link")
    refute has_element?(lv, "#rename-server-#{server.id}")
    refute has_element?(lv, "#edit-description-#{server.id}")
    refute has_element?(lv, "#edit-country-#{server.id}")
    refute has_element?(lv, "#edit-cert-hash-#{server.id}")
    refute has_element?(lv, "#assign-stream-server-#{server.id}")
    refute has_element?(lv, "#application-chip-#{server.id}-#{application.id}")
    refute html =~ ~s|<th>Applications</th>|
    refute has_element?(lv, "button", "Remove")
    refute has_element?(lv, "button", "Assign")
  end

  test "paginates the assigned servers with a page param", %{conn: conn} do
    application = application_fixture()

    servers =
      for i <- 1..21 do
        server =
          stream_server_fixture(%{"name" => "edge-#{String.pad_leading("#{i}", 2, "0")}"})

        {:ok, _} = StreamServers.assign_application(server.id, application.id)
        server
      end

    first = hd(servers)
    last = List.last(servers)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(lv, "#page-status", "Page 1 of 2")
    assert has_element?(lv, "#stream-server-row-#{first.id}")
    refute has_element?(lv, "#stream-server-row-#{last.id}")
    refute has_element?(lv, "#prev-page")

    lv |> element("#next-page") |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/applications/stream-servers?application_id=#{application.id}&page=2"
    )

    assert has_element?(lv, "#page-status", "Page 2 of 2")
    assert has_element?(lv, "#stream-server-row-#{last.id}")
    refute has_element?(lv, "#stream-server-row-#{first.id}")
    refute has_element?(lv, "#next-page")

    lv |> element("#prev-page") |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
    )

    assert has_element?(lv, "#page-status", "Page 1 of 2")
    assert has_element?(lv, "#stream-server-row-#{first.id}")
  end

  test "an out-of-range or invalid page param falls back to a valid page",
       %{conn: conn} do
    application = application_fixture()

    for i <- 1..21 do
      server = stream_server_fixture(%{"name" => "edge-#{i}"})
      {:ok, _} = StreamServers.assign_application(server.id, application.id)
    end

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}&page=99"
      )

    assert has_element?(lv, "#page-status", "Page 2 of 2")

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}&page=abc"
      )

    assert has_element?(lv, "#page-status", "Page 1 of 2")
  end

  test "picking an application starts on page 1", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}&page=3"
      )

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
    )
  end

  test "the servers table scrolls horizontally inside its container", %{conn: conn} do
    application = application_fixture()
    server = stream_server_fixture()
    {:ok, _} = StreamServers.assign_application(server.id, application.id)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-servers?application_id=#{application.id}"
      )

    assert has_element?(
             lv,
             "#stream-servers-section .overflow-x-auto #stream-servers-table"
           )
  end
end
