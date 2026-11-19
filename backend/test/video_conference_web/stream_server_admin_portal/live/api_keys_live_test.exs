defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeysLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

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

  test "links to API keys from the sidebar under applications", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

    assert has_element?(
             lv,
             ~s|a#sidebar-api-keys-link[href="/stream-server-admin/api-keys"]|
           )
  end

  test "prompts to select an application before listing keys or adding one",
       %{conn: conn} do
    _application = application_fixture()

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

    assert has_element?(lv, "#select-application-prompt")
    refute has_element?(lv, "#api-keys-table")
    refute has_element?(lv, "#add-api-key")
  end

  test "filter options are application names and picking one lists that app's keys",
       %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    other = application_fixture(%{"name" => "metrics app"})
    key = api_key_fixture(application, %{"name" => "key-one"})
    other_key = api_key_fixture(other)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

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
      "/stream-server-admin/api-keys?application_id=#{application.id}"
    )

    assert has_element?(lv, "#api-key-row-#{key.id}")
    refute has_element?(lv, "#api-key-row-#{other_key.id}")
    refute has_element?(lv, "#select-application-prompt")
  end

  test "filter options are searchable", %{conn: conn} do
    application = application_fixture(%{"name" => "zucchini"})
    _other = application_fixture(%{"name" => "apple"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/api-keys")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element("#application-filter-search")
    |> render_change(%{"application-filter_search" => "zucch"})

    assert has_element?(
             lv,
             ~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|
           )

    refute has_element?(lv, "#application-filter-dropdown button", "apple")
  end

  test "opening the page with an application_id param lists that app's keys",
       %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    assert has_element?(lv, "#api-key-row-#{key.id}")
    refute has_element?(lv, "#select-application-prompt")
  end

  test "adds an API key for the filtered application through the modal", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    lv |> element("#add-api-key") |> render_click()

    assert has_element?(lv, "#add-api-key-modal")
    assert has_element?(lv, "#add-api-key-application", "billing app")
    refute has_element?(lv, "input[name='api_key[application_id]']")

    lv
    |> form("#api-key-form",
      api_key: %{"name" => "new key", "description" => "added by test"}
    )
    |> render_submit()

    [loaded] = Applications.list_api_keys(application.id)
    assert loaded.name == "new key"
    assert loaded.description == "added by test"
    assert loaded.enabled == true

    assert has_element?(lv, "#new-api-key-secret")
    assert render(lv) =~ "aak_"
    assert has_element?(lv, "#api-key-row-#{loaded.id}")
  end

  test "shows the generated secret exactly once", %{conn: conn} do
    application = application_fixture()

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
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
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    refute has_element?(lv, "#new-api-key-secret")
    refute render(lv) =~ ~r/aak_[0-9a-f-]{36}_[A-Za-z0-9_-]{43}/
  end

  test "shows an inline error when the name is blank", %{conn: conn} do
    application = application_fixture()

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    lv |> element("#add-api-key") |> render_click()

    html =
      lv
      |> form("#api-key-form", api_key: %{"name" => ""})
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    assert has_element?(lv, "#add-api-key-modal")
    assert Applications.list_api_keys(application.id) == []
  end

  test "renames a key through the name pencil modal", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    lv |> element("#rename-key-#{key.id}") |> render_click()

    assert has_element?(lv, "#rename-key-modal")

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "renamed key"})
    |> render_submit()

    assert Applications.get_api_key!(key.id).name == "renamed key"
    refute has_element?(lv, "#rename-key-modal")
    assert has_element?(lv, "#api-key-row-#{key.id}", "renamed key")
  end

  test "edits a key's description through the description pencil modal", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    lv |> element("#edit-description-#{key.id}") |> render_click()

    assert has_element?(lv, "#edit-description-modal")

    lv
    |> form("#edit-description-form", key_description: %{"description" => "new desc"})
    |> render_submit()

    assert Applications.get_api_key!(key.id).description == "new desc"
    refute has_element?(lv, "#edit-description-modal")
    assert has_element?(lv, "#api-key-row-#{key.id}", "new desc")
  end

  test "truncates descriptions longer than 50 characters with an expandable control",
       %{conn: conn} do
    application = application_fixture()
    long = String.duplicate("x", 60)
    key = api_key_fixture(application, %{"description" => long})
    short = api_key_fixture(application, %{"description" => "short desc"})

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    assert has_element?(
             lv,
             "#key-description-short-#{key.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#key-description-full-#{key.id}.hidden", long)
    assert has_element?(lv, "#key-description-#{key.id}[phx-click]")

    # short descriptions render as plain text without a toggle
    assert has_element?(lv, "#api-key-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#key-description-#{short.id}")
  end

  test "toggles a key's enabled flag via the checkbox", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert Applications.get_api_key!(key.id).enabled == false
    refute has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert Applications.get_api_key!(key.id).enabled == true
    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")
  end

  test "a stale rename surfaces the lock_version error in the modal", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    lv |> element("#rename-key-#{key.id}") |> render_click()

    {:ok, _} = Applications.rename_api_key(key.id, "concurrent rename")

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "stale write"})
    |> render_submit()

    assert has_element?(lv, "#rename-key-modal", "is stale")
    assert Applications.get_api_key!(key.id).name == "concurrent rename"
  end

  test "a stale toggle surfaces a flash error", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    {:ok, _} = Applications.edit_api_key_description(key.id, "changed")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert render(lv) =~ "The enabled flag cannot be changed"
    assert Applications.get_api_key!(key.id).enabled == true
  end

  test "the API KEY column shows the key prefix with a copy control",
       %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    assert key.prefix =~ ~r/^aak_[0-9a-f-]{36}$/
    assert has_element?(lv, "#api-key-row-#{key.id} td", key.prefix)
    assert has_element?(lv, "#api-key-prefix-value-#{key.id}.hidden", key.prefix)

    assert has_element?(
             lv,
             ~s|#copy-api-key-prefix-#{key.id}[onclick*="navigator.clipboard.writeText"]|
           )
  end

  test "the keys table scrolls horizontally inside its container", %{conn: conn} do
    application = application_fixture()
    _key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    assert has_element?(lv, "#api-keys-section .overflow-x-auto #api-keys-table")
  end

  test "has no whole-row edit form and no delete control", %{conn: conn} do
    application = application_fixture()
    key = api_key_fixture(application)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/api-keys?application_id=#{application.id}"
      )

    refute has_element?(lv, "#edit-key-#{key.id}")
    refute has_element?(lv, "#delete-key-#{key.id}")
    refute has_element?(lv, "#edit-api-key-#{key.id}")
    refute has_element?(lv, "#delete-api-key-#{key.id}")
  end
end
