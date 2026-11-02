defmodule VideoConference.StreamServerAdminPortal.StreamServersTest do
  use VideoConference.DataCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Repo
  alias VideoConference.StreamServerAdminPortal.StreamServers
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  describe "list_stream_servers/1" do
    test "returns all stream servers ordered by name with applications preloaded" do
      application = application_fixture()
      b_server = stream_server_fixture(%{"name" => "b-server"})
      a_server = stream_server_fixture(%{"name" => "a-server"})
      {:ok, _} = StreamServers.assign_applications(b_server, [application.id])

      servers = StreamServers.list_stream_servers()

      assert Enum.map(servers, & &1.id) == [a_server.id, b_server.id]

      b_server = Enum.find(servers, &(&1.id == b_server.id))
      assert [loaded] = b_server.applications
      assert loaded.id == application.id
    end

    test "filters by application_id" do
      application = application_fixture()
      other = application_fixture()
      assigned = stream_server_fixture(%{"name" => "assigned"})
      _unassigned = stream_server_fixture(%{"name" => "unassigned"})
      {:ok, _} = StreamServers.assign_applications(assigned, [application.id])

      servers = StreamServers.list_stream_servers(application_id: application.id)

      assert Enum.map(servers, & &1.id) == [assigned.id]

      assert StreamServers.list_stream_servers(application_id: other.id) == []
    end

    test "filters to unassigned servers" do
      application = application_fixture()
      assigned = stream_server_fixture(%{"name" => "assigned"})
      unassigned = stream_server_fixture(%{"name" => "unassigned"})
      {:ok, _} = StreamServers.assign_applications(assigned, [application.id])

      servers = StreamServers.list_stream_servers(application_id: "unassigned")

      assert Enum.map(servers, & &1.id) == [unassigned.id]
    end
  end

  describe "get_stream_server!/1" do
    test "returns the stream server with applications preloaded" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_applications(stream_server, [application.id])

      loaded = StreamServers.get_stream_server!(stream_server.id)

      assert loaded.id == stream_server.id
      assert [app] = loaded.applications
      assert app.id == application.id
    end

    test "raises when the stream server does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        StreamServers.get_stream_server!(Ecto.UUID.generate())
      end
    end
  end

  describe "create_stream_server/1" do
    test "creates a stream server with a uuid and empty settings" do
      {:ok, %StreamServer{} = stream_server} =
        StreamServers.create_stream_server(%{
          "name" => "edge-1",
          "host" => "10.0.0.1:443",
          "country" => "de",
          "cert_hash" => "abc123"
        })

      assert {:ok, _} = Ecto.UUID.cast(stream_server.id)
      assert stream_server.name == "edge-1"
      assert stream_server.host == "10.0.0.1:443"
      assert stream_server.country == "de"
      assert stream_server.cert_hash == "abc123"
      assert stream_server.settings == %{}
    end

    test "requires a name" do
      {:error, changeset} = StreamServers.create_stream_server(%{"host" => "x"})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a duplicate name" do
      stream_server = stream_server_fixture(%{"name" => "taken"})

      {:error, changeset} = StreamServers.create_stream_server(%{"name" => "taken"})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
      assert stream_server.id
    end

    test "rejects an unsupported country" do
      {:error, changeset} =
        StreamServers.create_stream_server(%{"name" => "n", "country" => "xx"})

      assert %{country: ["is invalid"]} = errors_on(changeset)
    end
  end

  describe "update_stream_server/2" do
    test "updates the stream server fields" do
      stream_server = stream_server_fixture(%{"name" => "old", "host" => "1.1.1.1"})

      {:ok, updated} =
        StreamServers.update_stream_server(stream_server, %{
          "name" => "new",
          "host" => "2.2.2.2",
          "country" => "jp"
        })

      assert updated.name == "new"
      assert updated.host == "2.2.2.2"
      assert updated.country == "jp"
    end

    test "clears the cert hash when saved blank" do
      stream_server = stream_server_fixture(%{"cert_hash" => "abc"})

      {:ok, updated} =
        StreamServers.update_stream_server(stream_server, %{"cert_hash" => ""})

      assert updated.cert_hash == nil
      assert Repo.get!(StreamServer, stream_server.id).cert_hash == nil
    end
  end

  describe "delete_stream_server/1" do
    test "deletes the server and its application assignments" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_applications(stream_server, [application.id])

      {:ok, _} = StreamServers.delete_stream_server(stream_server)

      assert_raise Ecto.NoResultsError, fn ->
        StreamServers.get_stream_server!(stream_server.id)
      end

      assert Applications.get_application!(application.id)
      assert StreamServers.list_stream_servers(application_id: application.id) == []
    end
  end

  describe "change_stream_server/2" do
    test "returns a changeset" do
      stream_server = stream_server_fixture()
      assert %Ecto.Changeset{} = StreamServers.change_stream_server(stream_server)
    end
  end

  describe "assign_applications/2" do
    test "assigns applications to a stream server" do
      app1 = application_fixture()
      app2 = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.assign_applications(stream_server, [app1.id, app2.id])

      assert Enum.map(updated.applications, & &1.id) |> Enum.sort() ==
               Enum.sort([app1.id, app2.id])
    end

    test "replaces the assignment set" do
      app1 = application_fixture()
      app2 = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_applications(stream_server, [app1.id, app2.id])
      {:ok, updated} = StreamServers.assign_applications(stream_server, [app2.id])

      assert Enum.map(updated.applications, & &1.id) == [app2.id]
    end

    test "unassigns all applications with an empty list" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_applications(stream_server, [application.id])
      {:ok, updated} = StreamServers.assign_applications(stream_server, [])

      assert updated.applications == []
    end

    test "deleting an application removes its assignments" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_applications(stream_server, [application.id])

      {:ok, _} = Applications.delete_application(application)

      loaded = StreamServers.get_stream_server!(stream_server.id)
      assert loaded.applications == []
    end
  end
end
