defmodule VideoConferenceWeb.AdminPortal.PublicStreamServerKeysLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.AdminPortalFixtures
  import VideoConference.PublicStreamServerKeysFixtures
  import VideoConference.StreamServersFixtures

  alias VideoConference.AdminPortal.StreamServers

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page" do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/admin/log-in"}}} =
             live(conn, "/admin/stream-servers/keys")
  end

  test "shows 'No stream servers found' when there are none", %{conn: conn} do
    {:ok, _lv, html} = live(conn, "/admin/stream-servers/keys")

    assert html =~ "No stream servers found"
  end

  test "lists public keys grouped by stream server with an explanation", %{conn: conn} do
    server_a = stream_server_fixture(%{"name" => "alpha"})
    server_b = stream_server_fixture(%{"name" => "beta"})

    key_a = public_stream_server_key_fixture(server_a, %{"name" => "key-a"})
    key_b = public_stream_server_key_fixture(server_b, %{"name" => "key-b"})

    {:ok, lv, html} = live(conn, "/admin/stream-servers/keys")

    assert html =~ "signed JWT"
    assert has_element?(lv, "#stream-server-group-#{server_a.id}")
    assert has_element?(lv, "#stream-server-group-#{server_b.id}")
    assert has_element?(lv, "#stream-server-group-#{server_a.id} #public-key-row-#{key_a.id}")
    assert has_element?(lv, "#stream-server-group-#{server_b.id} #public-key-row-#{key_b.id}")
    assert has_element?(lv, "#public-key-row-#{key_a.id}", "Enabled")
  end

  test "marks disabled keys in the list", %{conn: conn} do
    server = stream_server_fixture()
    key = public_stream_server_key_fixture(server, %{"disabled" => "true"})

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys")

    assert has_element?(lv, "#public-key-row-#{key.id}", "Disabled")
  end

  test "shows short descriptions as plain text in the list", %{conn: conn} do
    server = stream_server_fixture()
    key = public_stream_server_key_fixture(server, %{"description" => "short desc"})

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys")

    assert has_element?(lv, "#public-key-row-#{key.id} td", "short desc")
    refute has_element?(lv, "#key-description-#{key.id}")
  end

  test "truncates long descriptions with an expandable control", %{conn: conn} do
    server = stream_server_fixture()
    long = String.duplicate("x", 120)
    key = public_stream_server_key_fixture(server, %{"description" => long})

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys")

    assert has_element?(
             lv,
             "#key-description-short-#{key.id}",
             String.slice(long, 0, 80) <> "..."
           )

    assert has_element?(lv, "#key-description-full-#{key.id}.hidden", long)
    refute render(lv) =~ long <> "..."
  end

  test "links to public keys from the sidebar under stream servers", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys")

    assert has_element?(lv, ~s|a#sidebar-public-keys-link[href="/admin/stream-servers/keys"]|)
  end

  test "adds a public key with a chosen stream server", %{conn: conn} do
    server = stream_server_fixture()
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/new")

    lv |> element("#stream-server-dropdown-button") |> render_click()

    lv
    |> element(~s|#stream-server-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    lv
    |> form("#public-key-form",
      public_stream_server_key: %{
        "name" => "new key",
        "public_key_id" => "pk-1",
        "public_key" => valid_public_key_pem(),
        "private_key_pem" => valid_private_key_pem(),
        "description" => "added by test"
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers/keys")

    html = render(lv)
    assert html =~ "new key"
    assert html =~ "pk-1"

    [key] =
      StreamServers.list_stream_servers_with_public_keys()
      |> hd()
      |> Map.get(:public_stream_server_keys)

    assert key.public_key_id == "pk-1"
    assert {:ok, pem} = StreamServers.decrypt_private_key(key)
    assert pem == valid_private_key_pem()
  end

  test "picking a stream server sets the form value and closes the dropdown", %{conn: conn} do
    server = stream_server_fixture()
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/new")

    lv |> element("#stream-server-dropdown-button") |> render_click()

    lv
    |> element(~s|#stream-server-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    assert has_element?(
             lv,
             ~s|input[name="public_stream_server_key[stream_server_id]"][value="#{server.id}"]|
           )

    refute has_element?(lv, "#stream-server-dropdown")
  end

  test "picking a stream server clears a previously shown validation error", %{conn: conn} do
    server = stream_server_fixture()
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/new")

    lv
    |> form("#public-key-form", public_stream_server_key: %{"name" => "x"})
    |> render_change()

    assert has_element?(lv, "#stream-server-field p.text-error", "can't be blank")

    lv |> element("#stream-server-dropdown-button") |> render_click()

    lv
    |> element(~s|#stream-server-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    refute has_element?(lv, "#stream-server-field p.text-error")
    assert has_element?(lv, "#stream-server-dropdown-button", server.name)
  end

  test "generates a key pair without a public key id", %{conn: conn} do
    server = stream_server_fixture()
    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/generate")

    lv |> element("#stream-server-dropdown-button") |> render_click()

    lv
    |> element(~s|#stream-server-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    lv
    |> form("#public-key-form",
      public_stream_server_key: %{
        "name" => "generated key"
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers/keys")
    assert render(lv) =~ "generated key"

    key =
      StreamServers.list_stream_servers_with_public_keys()
      |> Enum.find(&(&1.id == server.id))
      |> Map.get(:public_stream_server_keys)
      |> hd()

    assert key.public_key =~ "PUBLIC KEY"
    assert key.public_key_id == nil
    assert {:ok, pem} = StreamServers.decrypt_private_key(key)
    assert pem =~ "BEGIN PRIVATE KEY"
  end

  test "shows an inline error on a duplicate name for the same server", %{conn: conn} do
    server = stream_server_fixture()
    public_stream_server_key_fixture(server, %{"name" => "taken"})

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/new")

    lv |> element("#stream-server-dropdown-button") |> render_click()

    lv
    |> element(~s|#stream-server-dropdown button[phx-value-id="#{server.id}"]|)
    |> render_click()

    html =
      lv
      |> form("#public-key-form",
        public_stream_server_key: %{
          "name" => "taken",
          "public_key" => valid_public_key_pem(),
          "private_key_pem" => valid_private_key_pem()
        }
      )
      |> render_submit()

    assert html =~ "has already been taken"
  end

  test "edits a key and fills in the public key id", %{conn: conn} do
    server = stream_server_fixture()
    key = public_stream_server_key_fixture(server)

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys/#{key.id}/edit")

    lv
    |> form("#public-key-form",
      public_stream_server_key: %{
        "name" => "renamed key",
        "public_key_id" => "pk-9",
        "disabled" => "true"
      }
    )
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers/keys")

    updated = StreamServers.get_public_stream_server_key!(key.id)
    assert updated.name == "renamed key"
    assert updated.public_key_id == "pk-9"
    assert updated.disabled == true
  end

  test "edit form keeps private key secret and blank keeps it", %{conn: conn} do
    server = stream_server_fixture()
    key = public_stream_server_key_fixture(server)
    {:ok, pem} = StreamServers.decrypt_private_key(key)

    {:ok, lv, html} = live(conn, "/admin/stream-servers/keys/#{key.id}/edit")

    refute html =~ pem
    refute html =~ key.private_key
    assert has_element?(lv, ~s|textarea[name="public_stream_server_key[private_key_pem]"]|)

    lv
    |> form("#public-key-form", public_stream_server_key: %{"private_key_pem" => ""})
    |> render_submit()

    assert_patch(lv, "/admin/stream-servers/keys")
    assert StreamServers.get_public_stream_server_key!(key.id).private_key == key.private_key
  end

  test "removes a public key", %{conn: conn} do
    server = stream_server_fixture()
    key = public_stream_server_key_fixture(server)

    {:ok, lv, _html} = live(conn, "/admin/stream-servers/keys")

    lv |> element("#delete-public-key-#{key.id}") |> render_click()

    refute has_element?(lv, "#public-key-row-#{key.id}")

    assert_raise Ecto.NoResultsError, fn ->
      StreamServers.get_public_stream_server_key!(key.id)
    end
  end
end
