defmodule VideoConferenceWeb.StreamServerAdminPortal.ApplicationsLiveTest do
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
             live(conn, "/stream-server-admin/applications")
  end

  test "lists all applications with enabled checkboxes and actions", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    disabled = application_fixture(%{"name" => "off app", "enabled" => "false"})

    {:ok, lv, html} = live(conn, "/stream-server-admin/applications")

    assert html =~ "Default App"
    assert has_element?(lv, "#application-row-#{application.id}", "billing app")
    assert has_element?(lv, "#enabled-application-#{application.id}[checked]")
    refute has_element?(lv, "#enabled-application-#{disabled.id}[checked]")
    assert has_element?(lv, "#rename-application-#{application.id}")
    assert has_element?(lv, "#edit-description-#{application.id}")
    assert has_element?(lv, "#delete-application-#{application.id}")
  end

  test "sidebar links to applications and api keys", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    assert has_element?(
             lv,
             ~s|a#sidebar-applications-link[href="/stream-server-admin/applications"]|
           )

    assert has_element?(lv, ~s|a#sidebar-api-keys-link[href="/stream-server-admin/api-keys"]|)
  end

  test "adds an application", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/new")

    lv
    |> form("#application-form",
      application: %{
        "name" => "new app",
        "description" => "created by test"
      }
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/applications")
    assert render(lv) =~ "new app"

    application = Enum.find(Applications.list_applications(), &(&1.name == "new app"))
    assert application.description == "created by test"
    assert application.enabled == true
  end

  test "shows an inline error on a duplicate name", %{conn: conn} do
    application = application_fixture(%{"name" => "taken"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/new")

    html =
      lv
      |> form("#application-form", application: %{"name" => "taken"})
      |> render_submit()

    assert html =~ "has already been taken"

    refute Enum.any?(
             Applications.list_applications(),
             &(&1.name == application.name and &1.id != application.id)
           )
  end

  test "shows an inline error on a blank name", %{conn: conn} do
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/new")

    lv
    |> form("#application-form", application: %{"name" => ""})
    |> render_submit()

    assert has_element?(lv, "#application-form p.text-error", "can't be blank")
  end

  test "renames an application through the name pencil modal", %{conn: conn} do
    application = application_fixture(%{"name" => "peer"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    lv |> element("#rename-application-#{application.id}") |> render_click()

    assert has_element?(lv, "#rename-application-modal")

    lv
    |> form("#rename-application-form", rename_application: %{"name" => "renamed"})
    |> render_submit()

    updated = Applications.get_application!(application.id)
    assert updated.name == "renamed"
    assert updated.description == application.description
    assert updated.enabled == application.enabled

    refute has_element?(lv, "#rename-application-modal")
    assert has_element?(lv, "#application-row-#{application.id}", "renamed")
  end

  test "rejects a duplicate name inline in the rename modal", %{conn: conn} do
    application = application_fixture(%{"name" => "taken"})
    other = application_fixture(%{"name" => "other"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    lv |> element("#rename-application-#{other.id}") |> render_click()

    html =
      lv
      |> form("#rename-application-form", rename_application: %{"name" => "taken"})
      |> render_submit()

    assert html =~ "has already been taken"
    assert has_element?(lv, "#rename-application-modal")
    assert Applications.get_application!(other.id).name == "other"
    assert Applications.get_application!(application.id).name == "taken"
  end

  test "edits an application's description through the description pencil modal",
       %{conn: conn} do
    application = application_fixture(%{"name" => "peer"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    lv |> element("#edit-description-#{application.id}") |> render_click()

    assert has_element?(lv, "#edit-description-modal")

    lv
    |> form("#edit-description-form",
      application_description: %{"description" => "updated desc"}
    )
    |> render_submit()

    updated = Applications.get_application!(application.id)
    assert updated.description == "updated desc"
    assert updated.name == application.name

    refute has_element?(lv, "#edit-description-modal")
    assert has_element?(lv, "#application-row-#{application.id}", "updated desc")
  end

  test "toggles an application's enabled flag via the checkbox", %{conn: conn} do
    application = application_fixture()

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    assert has_element?(lv, "#enabled-application-#{application.id}[checked]")

    lv |> element("#enabled-application-#{application.id}") |> render_click()

    assert Applications.get_application!(application.id).enabled == false
    refute has_element?(lv, "#enabled-application-#{application.id}[checked]")

    lv |> element("#enabled-application-#{application.id}") |> render_click()

    assert Applications.get_application!(application.id).enabled == true
    assert has_element?(lv, "#enabled-application-#{application.id}[checked]")
  end

  test "truncates descriptions longer than 50 characters with an expandable control",
       %{conn: conn} do
    long = String.duplicate("x", 60)
    application = application_fixture(%{"description" => long})
    short = application_fixture(%{"description" => "short desc"})

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    assert has_element?(
             lv,
             "#application-description-short-#{application.id}",
             String.slice(long, 0, 50) <> "..."
           )

    assert has_element?(lv, "#application-description-full-#{application.id}.hidden", long)
    assert has_element?(lv, "#application-description-#{application.id}[phx-click]")

    # short descriptions render as plain text without a toggle
    assert has_element?(lv, "#application-row-#{short.id} td", "short desc")
    refute has_element?(lv, "#application-description-#{short.id}")
  end

  test "has no whole-row edit link or edit route", %{conn: conn} do
    application = application_fixture()

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    refute has_element?(lv, "#edit-application-#{application.id}")
    refute has_element?(lv, "a", "Edit")

    conn = get(conn, "/stream-server-admin/applications/#{application.id}/edit")
    assert conn.status == 404
  end

  test "removes an application and cascades to its API keys", %{conn: conn} do
    application = application_fixture(%{"name" => "to remove"})
    api_key = api_key_fixture(application)

    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications")

    lv |> element("#delete-application-#{application.id}") |> render_click()

    refute has_element?(lv, "#application-row-#{application.id}")

    assert_raise Ecto.NoResultsError, fn ->
      Applications.get_application!(application.id)
    end

    assert_raise Ecto.NoResultsError, fn -> Applications.get_api_key!(api_key.id) end
  end
end
