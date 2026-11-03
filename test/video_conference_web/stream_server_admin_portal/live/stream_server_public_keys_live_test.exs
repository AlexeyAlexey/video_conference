defmodule VideoConferenceWeb.StreamServerAdminPortal.StreamServerPublicKeysLiveTest do
  use VideoConferenceWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.Application
  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo

  setup %{conn: conn} do
    admin = admin_fixture()
    %{conn: log_in_stream_server_admin(conn, admin), admin: admin}
  end

  test "redirects unauthenticated visitors to the log-in page", %{conn: _conn} do
    conn = build_conn()

    assert {:error, {:redirect, %{to: "/stream-server-admin/log-in"}}} =
             live(conn, "/stream-server-admin/applications/stream-server-public-keys")
  end

  test "links to stream server public keys from the sidebar under applications", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert has_element?(
             lv,
             ~s|a#sidebar-stream-server-public-keys-link[href="/stream-server-admin/applications/stream-server-public-keys"]|
           )
  end

  test "shows 'No applications found' when there are none", %{conn: conn} do
    PortalRepo.delete_all(Application)

    {:ok, _lv, html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert html =~ "No applications found"
  end

  test "lists stream server public keys grouped by application with an explanation", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    other = application_fixture(%{"name" => "metrics app"})
    empty = application_fixture(%{"name" => "empty app"})

    key = stream_server_public_key_fixture(application, %{"name" => "key-one"})

    other_key =
      stream_server_public_key_fixture(other, %{"name" => "key-two", "enabled" => "false"})

    {:ok, lv, html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert html =~ "signed JWT"
    assert html =~ "Default App"
    assert has_element?(lv, "#application-group-#{application.id}")
    assert has_element?(lv, "#application-group-#{application.id} #key-row-#{key.id}")
    assert has_element?(lv, "#application-group-#{other.id} #key-row-#{other_key.id}")
    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")
    refute has_element?(lv, "#enabled-key-#{other_key.id}[checked]")
    assert has_element?(lv, "#no-keys-#{empty.id}", "No stream server public keys yet")
  end

  test "the key id column shows the key record's UUID with a copy control",
       %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert has_element?(lv, "#key-row-#{key.id} td", key.id)
    assert {:ok, _} = Ecto.UUID.cast(key.id)
    assert has_element?(lv, "#key-id-value-#{key.id}.hidden", key.id)

    assert has_element?(
             lv,
             ~s|#copy-key-id-#{key.id}[onclick*="navigator.clipboard.writeText"]|
           )
  end

  test "truncates descriptions longer than 50 characters with an expandable control",
       %{conn: conn} do
    application = application_fixture()
    long = String.duplicate("x", 60)
    key = stream_server_public_key_fixture(application, %{"description" => long})
    short = stream_server_public_key_fixture(application, %{"description" => "short desc"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert has_element?(
             lv,
             "#key-description-short-#{key.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#key-description-full-#{key.id}.hidden", long)
    assert has_element?(lv, "#key-description-#{key.id}[phx-click]")

    # description content wraps inside its column instead of overlapping
    assert has_element?(lv, "#key-description-full-#{key.id}.break-all.whitespace-pre-wrap")
    assert has_element?(lv, "#key-description-short-#{key.id}.break-all")
    refute render(lv) =~ long <> "..."

    # short descriptions render as plain text without a toggle
    assert has_element?(lv, "#key-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#key-description-#{short.id}")
  end

  test "filters stream server public keys by application", %{conn: conn} do
    application = application_fixture()
    other = application_fixture()
    key = stream_server_public_key_fixture(application)
    other_key = stream_server_public_key_fixture(other)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    lv |> element("#application-filter-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-filter-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    assert_patch(
      lv,
      "/stream-server-admin/applications/stream-server-public-keys?application_id=#{application.id}"
    )

    assert has_element?(lv, "#key-row-#{key.id}")
    refute has_element?(lv, "#key-row-#{other_key.id}")
    refute has_element?(lv, "#application-group-#{other.id}")
  end

  test "clearing the filter lists every application's keys again", %{conn: conn} do
    application = application_fixture()
    other = application_fixture()
    key = stream_server_public_key_fixture(application)
    other_key = stream_server_public_key_fixture(other)

    {:ok, lv, _html} =
      live(
        conn,
        "/stream-server-admin/applications/stream-server-public-keys?application_id=#{application.id}"
      )

    refute has_element?(lv, "#key-row-#{other_key.id}")

    lv |> element("#application-filter-dropdown-button") |> render_click()
    lv |> element("#application-filter-option-none") |> render_click()

    assert_patch(lv, "/stream-server-admin/applications/stream-server-public-keys")
    assert has_element?(lv, "#key-row-#{key.id}")
    assert has_element?(lv, "#key-row-#{other_key.id}")
  end

  test "filter options are searchable", %{conn: conn} do
    application = application_fixture(%{"name" => "zucchini app"})
    _other = application_fixture(%{"name" => "apple app"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

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

  test "adds a stream server public key with a chosen application", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/applications/stream-server-public-keys/new")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    lv
    |> form("#key-form",
      stream_server_public_key: %{
        "name" => "new key",
        "key" => valid_public_key_pem(),
        "description" => "added by test"
      }
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/applications/stream-server-public-keys")

    html = render(lv)
    assert html =~ "new key"

    [loaded] =
      Applications.list_applications_with_stream_server_public_keys(
        application_id: application.id
      )
      |> hd()
      |> Map.get(:stream_server_public_keys)

    assert loaded.name == "new key"
    assert loaded.key == valid_public_key_pem()
    assert has_element?(lv, "#key-row-#{loaded.id} td", loaded.id)
  end

  test "picking an application sets the form value and clears a stale error", %{conn: conn} do
    application = application_fixture()

    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/applications/stream-server-public-keys/new")

    lv
    |> form("#key-form", stream_server_public_key: %{"name" => "x"})
    |> render_change()

    assert has_element?(lv, "#application-field p.text-error", "can't be blank")

    lv |> element("#application-dropdown-button") |> render_click()

    lv
    |> element(~s|#application-dropdown button[phx-value-id="#{application.id}"]|)
    |> render_click()

    refute has_element?(lv, "#application-field p.text-error")

    assert has_element?(
             lv,
             ~s|input[name="stream_server_public_key[application_id]"][value="#{application.id}"]|
           )
  end

  test "shows an inline error when no application is chosen", %{conn: conn} do
    {:ok, lv, _html} =
      live(conn, "/stream-server-admin/applications/stream-server-public-keys/new")

    html =
      lv
      |> form("#key-form",
        stream_server_public_key: %{"key" => valid_public_key_pem()}
      )
      |> render_submit()

    assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    assert has_element?(lv, "#application-field p.text-error")
  end

  test "the form has no private key field and the page has no generate flow", %{conn: conn} do
    {:ok, lv, html} =
      live(conn, "/stream-server-admin/applications/stream-server-public-keys/new")

    refute html =~ "private_key"
    refute has_element?(lv, "a", "Generate")

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")
    refute has_element?(lv, "#generate-key-link")
    refute has_element?(lv, "a", "Generate")
  end

  test "the public key column shows a show control instead of the key content",
       %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    refute html =~ valid_public_key_pem()
    assert has_element?(lv, "#key-row-#{key.id} #show-key-#{key.id}")
  end

  test "shows the full public key in a modal with a copy control", %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    refute has_element?(lv, "#show-key-modal")

    lv |> element("#show-key-#{key.id}") |> render_click()

    assert has_element?(lv, "#show-key-modal")
    assert has_element?(lv, "#show-key-content")
    assert render(lv) =~ key.key

    assert has_element?(
             lv,
             ~s|#copy-public-key[onclick*="navigator.clipboard.writeText"]|
           )
  end

  test "renames a key through the name pencil modal without touching the key",
       %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    lv |> element("#rename-key-#{key.id}") |> render_click()

    assert has_element?(lv, "#rename-key-modal")

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "renamed key"})
    |> render_submit()

    updated = Applications.get_stream_server_public_key!(key.id)
    assert updated.name == "renamed key"
    assert updated.key == key.key

    refute has_element?(lv, "#rename-key-modal")
    assert has_element?(lv, "#key-row-#{key.id}", "renamed key")
  end

  test "edits a key's description through the description pencil modal", %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    lv |> element("#edit-description-#{key.id}") |> render_click()

    assert has_element?(lv, "#edit-description-modal")

    lv
    |> form("#edit-description-form", key_description: %{"description" => "new desc"})
    |> render_submit()

    updated = Applications.get_stream_server_public_key!(key.id)
    assert updated.description == "new desc"

    refute has_element?(lv, "#edit-description-modal")
    assert has_element?(lv, "#key-row-#{key.id}", "new desc")
  end

  test "toggles a key's enabled flag via the checkbox", %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert Applications.get_stream_server_public_key!(key.id).enabled == false
    refute has_element?(lv, "#enabled-key-#{key.id}[checked]")

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert Applications.get_stream_server_public_key!(key.id).enabled == true
    assert has_element?(lv, "#enabled-key-#{key.id}[checked]")
  end

  test "the row actions menu offers Change app and Remove", %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    assert has_element?(lv, "#key-actions-#{key.id}")
    assert has_element?(lv, "#key-actions-#{key.id} #change-app-#{key.id}", "Change app")
    assert has_element?(lv, "#key-actions-#{key.id} #delete-key-#{key.id}", "Remove")
  end

  test "changes a key's application through the row menu modal", %{conn: conn} do
    application = application_fixture(%{"name" => "source app"})
    other = application_fixture(%{"name" => "target app"})
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    lv |> element("#change-app-#{key.id}") |> render_click()

    assert has_element?(lv, "#change-app-modal")

    lv |> element("#change-app-dropdown-button") |> render_click()

    # the dropdown is searchable to simplify finding the application
    assert has_element?(lv, "#change-app-search")

    lv
    |> element("#change-app-search")
    |> render_change(%{"change-app_search" => "targ"})

    refute has_element?(lv, "#change-app-dropdown button", "source app")

    lv
    |> element(~s|#change-app-dropdown button[phx-value-id="#{other.id}"]|)
    |> render_click()

    assert has_element?(
             lv,
             ~s|input[name="change_app[application_id]"][value="#{other.id}"]|
           )

    lv |> form("#change-app-form") |> render_submit()

    updated = Applications.get_stream_server_public_key!(key.id)
    assert updated.application_id == other.id
    assert updated.key == key.key

    refute has_element?(lv, "#change-app-modal")
    assert has_element?(lv, "#application-group-#{other.id} #key-row-#{key.id}")
    refute has_element?(lv, "#application-group-#{application.id} #key-row-#{key.id}")
  end

  test "has no whole-row edit control and no control that changes the public key",
       %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    refute has_element?(lv, "#edit-key-#{key.id}")
    refute has_element?(lv, "input[name='stream_server_public_key[key]']")

    # editing every attribute leaves the stored public key value unchanged
    lv |> element("#rename-key-#{key.id}") |> render_click()

    lv
    |> form("#rename-key-form", rename_key: %{"name" => "x"})
    |> render_submit()

    lv |> element("#edit-description-#{key.id}") |> render_click()

    lv
    |> form("#edit-description-form", key_description: %{"description" => "y"})
    |> render_submit()

    lv |> element("#enabled-key-#{key.id}") |> render_click()

    assert Applications.get_stream_server_public_key!(key.id).key == key.key
  end

  test "removes a stream server public key", %{conn: conn} do
    application = application_fixture()
    key = stream_server_public_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/stream-server-public-keys")

    lv |> element("#delete-key-#{key.id}") |> render_click()

    refute has_element?(lv, "#key-row-#{key.id}")

    assert_raise Ecto.NoResultsError, fn ->
      Applications.get_stream_server_public_key!(key.id)
    end
  end
end
