defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServerApiKeysLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.StreamServers

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_stream_server_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin/stream-servers/api-keys")
  end

  test "links to stream server API keys from the sidebar under stream servers",
       %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/api-keys")

    assert has_element?(
             lv,
             ~s|a#sidebar-stream-server-api-keys-link[href="/stream-server-admin/stream-servers/api-keys"]|
           )
  end

  test "prompts to select a stream server before listing keys or adding one",
       %{conn: conn} do
    _server = stream_server_fixture()

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/api-keys")

    assert has_element?(lv, "#select-stream-server-prompt")
    refute has_element?(lv, "#api-keys-table")
    refute has_element?(lv, "#add-api-key")
  end

  test "filter options read 'name (host)' and picking one lists that server's keys",
       %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge-1", "host" => "10.0.0.1:443"})
    other = stream_server_fixture(%{"name" => "edge-2", "host" => "10.0.0.2:443"})
    key = stream_server_api_key_fixture(server, %{"name" => "node-agent"})
    other_key = stream_server_api_key_fixture(other)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/api-keys")

    lv |> element("#stream-server-filter-dropdown-button") |> render_click()

    assert has_element?(
             lv,
             ~s|#stream-server-filter-dropdown button[phx-value-id="#{server.id}"]|,
             "edge-1 (10.0.0.1:443)"
           )

    refute has_element?(lv, "#stream-server-filter-option-none")

    lv
    |> element(~s|#stream-server-filter-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
    )

    assert has_element?(lv, "#api-key-row-#{key.id}")
    refute has_element?(lv, "#api-key-row-#{other_key.id}")
    refute has_element?(lv, "#select-stream-server-prompt")
  end

  test "filter options are searchable", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "zucchini"})
    _other = stream_server_fixture(%{"name" => "apple"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/stream-servers/api-keys")

    lv |> element("#stream-server-filter-dropdown-button") |> render_click()

    lv
    |> element("#stream-server-filter-search")
    |> render_change(%{"stream-server-filter_search" => "zucch"})

    assert has_element?(
             lv,
             ~s|#stream-server-filter-dropdown button[phx-value-id="#{server.id}"]|
           )

    refute has_element?(lv, "#stream-server-filter-dropdown button", "apple")
  end

  test "opening the page with a stream_server_id param lists that server's keys",
       %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    assert has_element?(lv, "#api-key-row-#{key.id}")
    refute has_element?(lv, "#select-stream-server-prompt")
  end

  test "adds an API key for the filtered server through the modal", %{conn: conn} do
    server = stream_server_fixture(%{"name" => "edge-1", "host" => "10.0.0.1:443"})

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#add-api-key") |> render_click()

    assert has_element?(lv, "#add-api-key-modal")
    assert has_element?(lv, "#add-api-key-server", "edge-1 (10.0.0.1:443)")
    refute has_element?(lv, "input[name='api_key[stream_server_id]']")

    lv
    |> form("#api-key-form",
      api_key: %{"name" => "node-agent", "description" => "agent on edge-1"}
    )
    |> render_submit()

    [loaded] = StreamServers.list_stream_server_api_keys(server.id)
    assert loaded.name == "node-agent"
    assert loaded.description == "agent on edge-1"
    assert loaded.enabled == true

    assert has_element?(lv, "#new-api-key-secret")
    assert render(lv) =~ "ssak_"
    assert has_element?(lv, "#api-key-row-#{loaded.id}")
  end

  test "shows the generated secret exactly once", %{conn: conn} do
    server = stream_server_fixture()

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#add-api-key") |> render_click()

    lv
    |> form("#api-key-form", api_key: %{"name" => "n"})
    |> render_submit()

    assert has_element?(lv, "#new-api-key-secret")

    lv |> element("#dismiss-new-api-key-secret") |> render_click()
    refute has_element?(lv, "#new-api-key-secret")

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    refute has_element?(lv, "#new-api-key-secret")
    refute render(lv) =~ ~r/ssak_[0-9a-f-]{36}_[A-Za-z0-9_-]{43}/
  end

  test "shows an inline error when the name is blank", %{conn: conn} do
    server = stream_server_fixture()

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#add-api-key") |> render_click()

    html =
      lv
      |> form("#api-key-form", api_key: %{"name" => ""})
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    assert has_element?(lv, "#add-api-key-modal")
    assert StreamServers.list_stream_server_api_keys(server.id) == []
  end

  test "renames a key through the name pencil modal", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#rename-key-#{key.id}") |> render_click()

    assert has_element?(lv, "#rename-key-modal")

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "renamed key"})
    |> render_submit()

    assert StreamServers.get_stream_server_api_key!(key.id).name == "renamed key"
    refute has_element?(lv, "#rename-key-modal")
    assert has_element?(lv, "#api-key-row-#{key.id}", "renamed key")
  end

  test "edits a key's description through the description pencil modal", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#edit-description-#{key.id}") |> render_click()

    assert has_element?(lv, "#edit-description-modal")

    lv
    |> form("#edit-description-form", key_description: %{"description" => "new desc"})
    |> render_submit()

    assert StreamServers.get_stream_server_api_key!(key.id).description == "new desc"
    refute has_element?(lv, "#edit-description-modal")
    assert has_element?(lv, "#api-key-row-#{key.id}", "new desc")
  end

  test "toggles a key's enabled flag via the checkbox", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert StreamServers.get_stream_server_api_key!(key.id).enabled == false
    refute has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert StreamServers.get_stream_server_api_key!(key.id).enabled == true
    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")
  end

  test "a stale rename surfaces the lock_version error in the modal", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    lv |> element("#rename-key-#{key.id}") |> render_click()

    {:ok, _} = StreamServers.rename_stream_server_api_key(key.id, "concurrent rename")

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "stale write"})
    |> render_submit()

    assert has_element?(lv, "#rename-key-modal", "is stale")
    assert StreamServers.get_stream_server_api_key!(key.id).name == "concurrent rename"
  end

  test "a stale toggle surfaces a flash error", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    {:ok, _} = StreamServers.edit_stream_server_api_key_description(key.id, "changed")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert render(lv) =~ "The enabled flag cannot be changed"
    assert StreamServers.get_stream_server_api_key!(key.id).enabled == true
  end

  test "the API KEY column shows the key prefix with a copy control",
       %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    assert key.prefix =~ ~r/^ssak_[0-9a-f-]{36}$/
    assert has_element?(lv, "#api-key-row-#{key.id} td", key.prefix)
    assert has_element?(lv, "#api-key-prefix-value-#{key.id}.hidden", key.prefix)

    assert has_element?(
             lv,
             ~s|#copy-api-key-prefix-#{key.id}[onclick*="navigator.clipboard.writeText"]|
           )
  end

  test "the keys table scrolls horizontally inside its container", %{conn: conn} do
    server = stream_server_fixture()
    _key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    assert has_element?(lv, "#api-keys-section .overflow-x-auto #api-keys-table")
  end

  test "has no whole-row edit form and no delete control", %{conn: conn} do
    server = stream_server_fixture()
    key = stream_server_api_key_fixture(server)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/stream-servers/api-keys?stream_server_id=#{server.id}"
      )

    refute has_element?(lv, "#edit-key-#{key.id}")
    refute has_element?(lv, "#delete-key-#{key.id}")
  end
end
