defmodule VideoConferenceWeb.AdminPortal.StreamServersLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.AdminPortalFixtures
  import VideoConference.StreamServersFixtures

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.Countries

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()
    assert {:error, {:redirect, %{to: "/admin/log-in"}}} = live(conn, "/admin/stream-servers")
  end

  test "lists all stream servers with third-party and flag indicators",
       %{conn: conn} do
    server =
      stream_server_fixture(%{
        "name" => "frankfurt",
        "host" => "10.0.0.5:4433",
        "country" => "de",
        "third_party" => true
      })

    other = stream_server_fixture(%{"name" => "self-hosted"})

    {:ok, lv, html} = live(conn, "/admin/stream-servers")

    assert html =~ "frankfurt"
    assert html =~ "self-hosted"
    assert html =~ "10.0.0.5:4433"
    assert html =~ Countries.flag("de")
    assert has_element?(lv, "#stream-server-row-#{server.id}")
    assert has_element?(lv, "#stream-server-row-#{other.id}")
    assert has_element?(lv, "#stream-server-row-#{server.id} td", "Yes")
    assert has_element?(lv, "#stream-server-row-#{other.id} td", "No")
  end

  test "links to stream servers from the sidebar", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers")

    assert has_element?(lv, ~s|a#sidebar-stream-servers-link[href="/admin/stream-servers"]|)
  end

  test "adds a stream server", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()
    lv |> element(~s|#country-dropdown button[phx-value-code="us"]|) |> render_click()

    lv
    |> form("#stream-server-form",
      stream_server: %{
        "name" => "new server",
        "description" => "third party peer",
        "host" => "192.168.0.2:4433",
        "cert_hash" => "f00ba4",
        "third_party" => "true"
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers")

    html = render(lv)
    assert html =~ "new server"
    assert html =~ Countries.flag("us")

    server = Enum.find(StreamServers.list_stream_servers(), &(&1.name == "new server"))
    assert server.settings["cert_hash"] == "f00ba4"
    assert server.third_party == true
  end

  test "offers an empty country choice", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#country-dropdown button[phx-value-code=""]|, "None")
  end

  test "shows an inline error on a duplicate name", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "taken"})
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    html =
      lv
      |> form("#stream-server-form", stream_server: %{"name" => "taken"})
      |> render_submit()

    assert html =~ "has already been taken"

    refute Enum.any?(
             StreamServers.list_stream_servers(),
             &(&1.name == server.name and &1.id != server.id)
           )
  end

  test "edits a stream server", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "peer", "cert_hash" => "abc"})
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/#{server.id}/edit")

    lv |> element("#country-dropdown-button") |> render_click()
    lv |> element(~s|#country-dropdown button[phx-value-code="jp"]|) |> render_click()

    lv
    |> form("#stream-server-form",
      stream_server: %{
        "name" => "renamed",
        "host" => "10.1.2.3",
        "cert_hash" => ""
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers")

    updated = StreamServers.get_stream_server!(server.id)
    assert updated.name == "renamed"
    assert updated.host == "10.1.2.3"
    assert updated.country == "jp"
    refute Map.has_key?(updated.settings, "cert_hash")
    assert render(lv) =~ Countries.flag("jp")
  end

  test "filters country options via the search field", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()

    assert has_element?(lv, ~s|#country-dropdown button[phx-value-code="jp"]|)

    lv |> element("#country-search") |> render_change(%{"country_search" => "germ"})

    assert has_element?(lv, ~s|#country-dropdown button[phx-value-code="de"]|)
    refute has_element?(lv, ~s|#country-dropdown button[phx-value-code="jp"]|)
  end

  test "picking a country sets the form value and closes the dropdown", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()
    lv |> element(~s|#country-dropdown button[phx-value-code="de"]|) |> render_click()

    assert has_element?(lv, ~s|input[name="stream_server[country]"][value="de"]|)
    refute has_element?(lv, "#country-dropdown")
  end

  test "keeps the selected country while filtering", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "peer", "country" => "jp"})
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/#{server.id}/edit")

    lv |> element("#country-dropdown-button") |> render_click()
    lv |> element("#country-search") |> render_change(%{"country_search" => "germ"})

    assert has_element?(lv, ~s|input[name="stream_server[country]"][value="jp"]|)
  end

  test "shows only the empty choice when country search finds nothing", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/new")

    lv |> element("#country-dropdown-button") |> render_click()
    lv |> element("#country-search") |> render_change(%{"country_search" => "zzzzz"})

    assert has_element?(lv, ~s|#country-dropdown button[phx-value-code=""]|, "None")
    refute has_element?(lv, ~s|#country-dropdown button[phx-value-code="de"]|)
  end

  test "removes a stream server", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "to remove"})
    {:ok, lv, _html} = live(conn, "/admin/stream-servers")

    lv |> element("#delete-stream-server-#{server.id}") |> render_click()

    refute has_element?(lv, "#stream-server-row-#{server.id}")

    assert_raise Ecto.NoResultsError, fn -> StreamServers.get_stream_server!(server.id) end
  end
end
