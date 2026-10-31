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

  test "lists all applications with enabled state and actions", %{conn: conn} do
    application = application_fixture(%{"name" => "billing app"})
    disabled = application_fixture(%{"name" => "off app", "enabled" => "false"})

    {:ok, lv, html} = live(conn, "/stream-server-admin/applications")

    assert html =~ "Default App"
    assert has_element?(lv, "#application-row-#{application.id}", "billing app")
    assert has_element?(lv, "#application-row-#{application.id} td", "Yes")
    assert has_element?(lv, "#application-row-#{disabled.id} td", "No")
    assert has_element?(lv, "#edit-application-#{application.id}")
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

  test "edits an application and toggles enabled", %{conn: conn} do
    application = application_fixture(%{"name" => "peer"})
    {:ok, lv, _html} = live(conn, "/stream-server-admin/applications/#{application.id}/edit")

    lv
    |> form("#application-form",
      application: %{
        "name" => "renamed",
        "description" => "updated",
        "enabled" => "false"
      }
    )
    |> render_submit()

    assert_patch(lv, "/stream-server-admin/applications")

    updated = Applications.get_application!(application.id)
    assert updated.name == "renamed"
    assert updated.description == "updated"
    assert updated.enabled == false

    assert has_element?(lv, "#application-row-#{application.id} td", "No")
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
