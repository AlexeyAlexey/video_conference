defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeysLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.ApiKeySecret
  alias VideoConference.StreamServerAdminPortal.Applications

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_stream_server_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin/api-keys")
  end

  test "lists API keys grouped under their application", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    other = application_fixture(%{"name" => "metrics app"})
    empty = application_fixture(%{"name" => "empty app"})

    key = api_key_fixture(application, %{"name" => "key-one"})
    other_key = api_key_fixture(other, %{"name" => "key-two", "enabled" => "false"})

    {:ok, lv, html} = live(conn, "/stream-server-admin/api-keys")

    assert html =~ "Default App"
    assert html =~ "Default API Key"
    assert has_element?(lv, "#application-group-#{application.id}")
    assert has_element?(lv, "#application-group-#{application.id} #api-key-row-#{key.id}")
    assert has_element?(lv, "#application-group-#{other.id} #api-key-row-#{other_key.id}")
    assert has_element?(lv, "#api-key-row-#{key.id} td", "Yes")
    assert has_element?(lv, "#api-key-row-#{other_key.id} td", "No")
    assert has_element?(lv, "#no-api-keys-#{empty.id}", "No API keys yet")
  end

  test "adds an API key with a chosen application and shows the secret once", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys/new")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    lv
    |> form("#api-key-form",
      api_key: %{"name" => "new key", "description" => "added by test"}
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/api-keys")

    api_key = Enum.find(Applications.list_api_keys(application), &(&1.name == "new key"))

    html = render(lv)
    assert html =~ api_key.name

    # The generated secret is displayed exactly once after creation,
    # with a copy-to-clipboard button next to it
    assert has_element?(lv, "#new-api-key-secret")

    assert has_element?(
             lv,
             ~s|#copy-new-api-key-secret[onclick*="navigator.clipboard.writeText"]|
           )

    [secret] = Regex.run(~r/aak_[A-Za-z0-9_-]{20,}/, html)
    assert ApiKeySecret.verify(secret, api_key.hashed_api_key)

    # Dismissing removes it and it is not rendered again
    lv |> element("#dismiss-new-api-key-secret") |> render_click()
    refute has_element?(lv, "#new-api-key-secret")
    refute render(lv) =~ secret
  end

  test "the secret is not shown again after navigating away and back", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys/new")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    lv
    |> form("#api-key-form", api_key: %{"name" => "new key"})
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/api-keys")
    [secret] = Regex.run(~r/aak_[A-Za-z0-9_-]{20,}/, render(lv))

    api_key = Enum.find(Applications.list_api_keys(application), &(&1.name == "new key"))

    # Navigate to the edit form and back to the index
    render_patch(lv, "/stream-server-admin/api-keys/#{api_key.id}/edit")
    assert has_element?(lv, "#api-key-form")
    render_patch(lv, "/stream-server-admin/api-keys")

    refute has_element?(lv, "#new-api-key-secret")
    refute render(lv) =~ secret
  end

  test "picking an application sets the form value and clears a stale error", %{conn: conn} do
    application = application_fixture()
    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys/new")

    lv
    |> form("#api-key-form", api_key: %{"name" => "x"})
    |> render_change()

    assert has_element?(lv, "#application-field p.text-error", "can't be blank")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    refute has_element?(lv, "#application-field p.text-error")

    assert has_element?(
             lv,
             ~s|input[name="api_key[application_id]"][value="#{application.id}"]|
           )
  end

  test "shows an inline error on a duplicate name within the same application", %{conn: conn} do
    application = application_fixture()
    api_key = api_key_fixture(application, %{"name" => "taken"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys/new")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    html =
      lv
      |> form("#api-key-form", api_key: %{"name" => api_key.name})
      |> render_submit()

    assert html =~ "has already been taken"
    assert Enum.count(Applications.list_api_keys(application)) == 1
  end

  test "edits an API key without changing the stored secret hash", %{conn: conn} do
    application = application_fixture()
    api_key = api_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys/#{api_key.id}/edit")

    lv
    |> form("#api-key-form",
      api_key: %{
        "name" => "renamed key",
        "description" => "updated",
        "enabled" => "false"
      }
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/api-keys")

    updated = Applications.get_api_key!(api_key.id)
    assert updated.name == "renamed key"
    assert updated.description == "updated"
    assert updated.enabled == false
    assert updated.hashed_api_key == api_key.hashed_api_key
    refute updated.plaintext_key
    refute has_element?(lv, "#new-api-key-secret")
  end

  test "truncates descriptions longer than 50 characters with an expandable control",
       %{conn: conn} do
    application = application_fixture()
    long = String.duplicate("x", 60)
    api_key = api_key_fixture(application, %{"description" => long})
    short = api_key_fixture(application, %{"description" => "short desc"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

    assert has_element?(
             lv,
             "#api-key-description-short-#{api_key.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#api-key-description-full-#{api_key.id}.hidden", long)
    assert has_element?(lv, "#api-key-description-#{api_key.id}[phx-click]")

    # short descriptions render as plain text without a toggle
    assert has_element?(lv, "#api-key-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#api-key-description-#{short.id}")
  end

  test "removes an API key", %{conn: conn} do
    application = application_fixture()
    api_key = api_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

    lv |> element("#delete-api-key-#{api_key.id}") |> render_click()

    refute has_element?(lv, "#api-key-row-#{api_key.id}")

    assert_raise Ecto.NoResultsError, fn -> Applications.get_api_key!(api_key.id) end
  end
end
