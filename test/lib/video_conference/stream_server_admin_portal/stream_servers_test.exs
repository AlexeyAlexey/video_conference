defmodule VideoConference.StreamServerAdminPortal.StreamServersTest do
  use VideoConference.DataCase, async: false

  import VideoConference.StreamServerAdminPortalFixtures

  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.Repo
  alias VideoConference.StreamServerAdminPortal.StreamServers

  alias VideoConference.StreamServerAdminPortal.StreamServers.{
    StreamServer,
    StreamServerWasAdded,
    StreamServerWasAssignedToApplication,
    StreamServerWasUnassignedFromApplication
  }

  describe "list_stream_servers/1" do
    test "returns all stream servers ordered by name with applications preloaded" do
      application = application_fixture()
      b_server = stream_server_fixture(%{"name" => "b-server"})
      a_server = stream_server_fixture(%{"name" => "a-server"})
      {:ok, _} = StreamServers.assign_application(b_server.id, application.id)

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
      {:ok, _} = StreamServers.assign_application(assigned.id, application.id)

      servers = StreamServers.list_stream_servers(application_id: application.id)

      assert Enum.map(servers, & &1.id) == [assigned.id]

      assert StreamServers.list_stream_servers(application_id: other.id) == []
    end

    test "filters to unassigned servers" do
      application = application_fixture()
      assigned = stream_server_fixture(%{"name" => "assigned"})
      unassigned = stream_server_fixture(%{"name" => "unassigned"})
      {:ok, _} = StreamServers.assign_application(assigned.id, application.id)

      servers = StreamServers.list_stream_servers(application_id: "unassigned")

      assert Enum.map(servers, & &1.id) == [unassigned.id]
    end
  end

  describe "get_stream_server!/1" do
    test "returns the stream server with applications preloaded" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)

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
      assert stream_server.lock_version == 1
    end

    test "requires a name" do
      {:error, changeset} = StreamServers.create_stream_server(%{"host" => "x"})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows two stream servers to share a name" do
      stream_server = stream_server_fixture(%{"name" => "shared"})

      {:ok, %StreamServer{} = other} =
        StreamServers.create_stream_server(%{"name" => "shared"})

      assert other.name == stream_server.name
      assert other.id != stream_server.id
    end

    test "rejects a duplicate host" do
      stream_server = stream_server_fixture(%{"host" => "10.0.0.1:443"})

      {:error, changeset} =
        StreamServers.create_stream_server(%{"name" => "n", "host" => "10.0.0.1:443"})

      assert %{host: ["has already been taken"]} = errors_on(changeset)
      assert stream_server.id
    end

    test "rejects an unsupported country" do
      {:error, changeset} =
        StreamServers.create_stream_server(%{"name" => "n", "country" => "xx"})

      assert %{country: ["is invalid"]} = errors_on(changeset)
    end

    test "commits the server and a StreamServerWasAdded event together" do
      {:ok, %StreamServer{} = stream_server} =
        StreamServers.create_stream_server(%{
          "name" => "edge-1",
          "description" => "edge desc",
          "host" => "10.0.0.1:443",
          "country" => "de",
          "settings" => %{"region" => "eu"},
          "cert_hash" => "abc123"
        })

      assert [stored] = EventStore.get_events([inspect(StreamServerWasAdded)], 0)
      assert stored.stream_id == stream_server.id
      assert stored.version == 1

      assert stored.payload == %StreamServerWasAdded{
               stream_id: stream_server.id,
               id: stream_server.id,
               name: "edge-1",
               description: "edge desc",
               host: "10.0.0.1:443",
               country: "de",
               settings: %{"region" => "eu"},
               cert_hash: "abc123",
               lock_version: 1
             }
    end

    test "a failing create stores no event" do
      _existing = stream_server_fixture(%{"host" => "10.0.0.1:443"})
      before = EventStore.get_events([inspect(StreamServerWasAdded)], 0)

      {:error, _changeset} =
        StreamServers.create_stream_server(%{"name" => "n", "host" => "10.0.0.1:443"})

      assert EventStore.get_events([inspect(StreamServerWasAdded)], 0) == before
    end
  end

  describe "rename_stream_server/2" do
    test "renames a stream server" do
      stream_server = stream_server_fixture(%{"name" => "old", "host" => "1.1.1.1"})

      {:ok, updated} = StreamServers.rename_stream_server(stream_server.id, "new")

      assert updated.name == "new"
      assert StreamServers.get_stream_server!(stream_server.id).name == "new"
    end

    test "allows renaming to a name another stream server already has" do
      _other = stream_server_fixture(%{"name" => "taken"})
      stream_server = stream_server_fixture(%{"name" => "old"})

      {:ok, updated} = StreamServers.rename_stream_server(stream_server.id, "taken")

      assert updated.name == "taken"
      assert StreamServers.get_stream_server!(stream_server.id).name == "taken"
    end

    test "requires a name" do
      stream_server = stream_server_fixture()

      {:error, changeset} = StreamServers.rename_stream_server(stream_server.id, "")

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "edit_stream_server_description/2" do
    test "updates the description" do
      stream_server = stream_server_fixture()

      {:ok, updated} =
        StreamServers.edit_stream_server_description(stream_server.id, "new desc")

      assert updated.description == "new desc"

      assert StreamServers.get_stream_server!(stream_server.id).description == "new desc"
    end
  end

  describe "edit_stream_server_country/2" do
    test "updates the country" do
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.edit_stream_server_country(stream_server.id, "jp")

      assert updated.country == "jp"
      assert StreamServers.get_stream_server!(stream_server.id).country == "jp"
    end

    test "clears the country with a blank value" do
      stream_server = stream_server_fixture(%{"country" => "de"})

      {:ok, updated} = StreamServers.edit_stream_server_country(stream_server.id, "")

      assert updated.country == nil
      assert StreamServers.get_stream_server!(stream_server.id).country == nil
    end

    test "rejects an unsupported country" do
      stream_server = stream_server_fixture(%{"country" => "de"})

      {:error, changeset} = StreamServers.edit_stream_server_country(stream_server.id, "xx")

      assert %{country: ["is invalid"]} = errors_on(changeset)
      assert StreamServers.get_stream_server!(stream_server.id).country == "de"
    end
  end

  describe "edit_stream_server_cert_hash/2" do
    test "updates the certificate hash" do
      stream_server = stream_server_fixture()

      {:ok, updated} =
        StreamServers.edit_stream_server_cert_hash(stream_server.id, "deadbeef")

      assert updated.cert_hash == "deadbeef"

      assert StreamServers.get_stream_server!(stream_server.id).cert_hash == "deadbeef"
    end

    test "clears the cert hash when saved blank" do
      stream_server = stream_server_fixture(%{"cert_hash" => "abc"})

      {:ok, updated} = StreamServers.edit_stream_server_cert_hash(stream_server.id, "")

      assert updated.cert_hash == nil
      assert Repo.get!(StreamServer, stream_server.id).cert_hash == nil
    end
  end

  describe "host immutability" do
    test "no update path can change host" do
      stream_server = stream_server_fixture(%{"host" => "1.1.1.1"})
      attrs = %{"host" => "9.9.9.9"}

      for changeset <- [
            StreamServer.name_changeset(stream_server, Map.put(attrs, "name", "x")),
            StreamServer.description_changeset(stream_server, attrs),
            StreamServer.country_changeset(stream_server, attrs),
            StreamServer.cert_hash_changeset(stream_server, attrs)
          ] do
        refute Map.has_key?(changeset.changes, :host)
      end

      {:ok, _} = StreamServers.rename_stream_server(stream_server.id, "renamed")
      {:ok, _} = StreamServers.edit_stream_server_description(stream_server.id, "desc")
      {:ok, _} = StreamServers.edit_stream_server_country(stream_server.id, "jp")
      {:ok, _} = StreamServers.edit_stream_server_cert_hash(stream_server.id, "abc")

      assert Repo.get!(StreamServer, stream_server.id).host == "1.1.1.1"
    end
  end

  describe "stream server optimistic locking" do
    test "increments lock_version on each update" do
      stream_server = stream_server_fixture()
      assert stream_server.lock_version == 1

      {:ok, stream_server} = StreamServers.rename_stream_server(stream_server.id, "renamed")
      assert stream_server.lock_version == 2

      {:ok, stream_server} =
        StreamServers.edit_stream_server_description(stream_server.id, "desc")

      assert stream_server.lock_version == 3

      {:ok, stream_server} = StreamServers.edit_stream_server_country(stream_server.id, "jp")
      assert stream_server.lock_version == 4

      {:ok, stream_server} =
        StreamServers.edit_stream_server_cert_hash(stream_server.id, "abc")

      assert stream_server.lock_version == 5

      assert StreamServers.get_stream_server!(stream_server.id).lock_version == 5
    end

    test "a stale update returns an error changeset instead of raising" do
      stream_server = stream_server_fixture()
      stale = StreamServers.get_stream_server!(stream_server.id)

      {:ok, _} = StreamServers.rename_stream_server(stream_server.id, "renamed")

      assert {:error, changeset} =
               stale
               |> StreamServer.name_changeset(%{"name" => "stale name"})
               |> Repo.update(stale_error_field: :lock_version)

      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert StreamServers.get_stream_server!(stream_server.id).name == "renamed"
    end
  end

  describe "change_stream_server/2" do
    test "returns a changeset" do
      stream_server = stream_server_fixture()
      assert %Ecto.Changeset{} = StreamServers.change_stream_server(stream_server)
    end
  end

  describe "assign_application/2 and unassign_application/2" do
    test "assigns an application to a stream server" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.assign_application(stream_server.id, application.id)

      assert Enum.map(updated.applications, & &1.id) == [application.id]
    end

    test "assigning an application stores an assigned event and bumps lock_version" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.assign_application(stream_server.id, application.id)

      assert updated.lock_version == 2
      assert StreamServers.get_stream_server!(stream_server.id).lock_version == 2

      assert [stored] =
               EventStore.get_events([inspect(StreamServerWasAssignedToApplication)], 0)

      assert stored.stream_id == stream_server.id
      assert stored.version == 2

      assert stored.payload == %StreamServerWasAssignedToApplication{
               stream_id: stream_server.id,
               id: stream_server.id,
               application_id: application.id,
               lock_version: 2
             }
    end

    test "assigning the same application twice is a no-op but stores a second event" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)
      {:ok, updated} = StreamServers.assign_application(stream_server.id, application.id)

      assert Enum.map(updated.applications, & &1.id) == [application.id]
      assert updated.lock_version == 3

      assert [_, second] =
               EventStore.get_events([inspect(StreamServerWasAssignedToApplication)], 0)

      assert second.stream_id == stream_server.id
      assert second.version == 3

      assert second.payload == %StreamServerWasAssignedToApplication{
               stream_id: stream_server.id,
               id: stream_server.id,
               application_id: application.id,
               lock_version: 3
             }
    end

    test "assigns the same server to several applications" do
      app1 = application_fixture()
      app2 = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_application(stream_server.id, app1.id)
      {:ok, updated} = StreamServers.assign_application(stream_server.id, app2.id)

      assert Enum.map(updated.applications, & &1.id) |> Enum.sort() ==
               Enum.sort([app1.id, app2.id])
    end

    test "unassigns an application" do
      app1 = application_fixture()
      app2 = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_application(stream_server.id, app1.id)
      {:ok, _} = StreamServers.assign_application(stream_server.id, app2.id)
      {:ok, updated} = StreamServers.unassign_application(stream_server.id, app1.id)

      assert Enum.map(updated.applications, & &1.id) == [app2.id]
    end

    test "unassigning an application stores an unassigned event and bumps lock_version" do
      app1 = application_fixture()
      app2 = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_application(stream_server.id, app1.id)
      {:ok, _} = StreamServers.assign_application(stream_server.id, app2.id)
      {:ok, updated} = StreamServers.unassign_application(stream_server.id, app1.id)

      assert updated.lock_version == 4
      assert StreamServers.get_stream_server!(stream_server.id).lock_version == 4

      assert [stored] =
               EventStore.get_events([inspect(StreamServerWasUnassignedFromApplication)], 0)

      assert stored.stream_id == stream_server.id
      assert stored.version == 4

      assert stored.payload == %StreamServerWasUnassignedFromApplication{
               stream_id: stream_server.id,
               id: stream_server.id,
               application_id: app1.id,
               lock_version: 4
             }
    end

    test "unassigning an application that is not assigned is a no-op but still emits" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.unassign_application(stream_server.id, application.id)

      assert updated.applications == []
      assert updated.lock_version == 2

      assert [stored] =
               EventStore.get_events([inspect(StreamServerWasUnassignedFromApplication)], 0)

      assert stored.stream_id == stream_server.id

      assert stored.payload == %StreamServerWasUnassignedFromApplication{
               stream_id: stream_server.id,
               id: stream_server.id,
               application_id: application.id,
               lock_version: 2
             }
    end
  end

  describe "non-evented mutations" do
    test "rename and field edits store no event on the server's stream" do
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.rename_stream_server(stream_server.id, "renamed")
      {:ok, _} = StreamServers.edit_stream_server_description(stream_server.id, "desc")
      {:ok, _} = StreamServers.edit_stream_server_country(stream_server.id, "jp")
      {:ok, _} = StreamServers.edit_stream_server_cert_hash(stream_server.id, "abc")

      event_types = [
        inspect(StreamServerWasAdded),
        inspect(StreamServerWasAssignedToApplication),
        inspect(StreamServerWasUnassignedFromApplication)
      ]

      assert [stored] =
               event_types
               |> EventStore.get_events(0)
               |> Enum.filter(&(&1.stream_id == stream_server.id))

      assert stored.event_type == inspect(StreamServerWasAdded)
      assert stored.version == 1
    end
  end

  describe "stream server event new/1 and new/2" do
    test "StreamServerWasAdded maps all fields from the stream server" do
      stream_server = %StreamServer{
        id: Ecto.UUID.generate(),
        lock_version: 1,
        name: "edge-1",
        description: "desc",
        host: "10.0.0.1:443",
        country: "de",
        settings: %{"region" => "eu"},
        cert_hash: "abc123"
      }

      assert StreamServerWasAdded.new(stream_server) == %StreamServerWasAdded{
               stream_id: stream_server.id,
               id: stream_server.id,
               name: "edge-1",
               description: "desc",
               host: "10.0.0.1:443",
               country: "de",
               settings: %{"region" => "eu"},
               cert_hash: "abc123",
               lock_version: 1
             }
    end

    test "StreamServerWasAssignedToApplication maps server fields and application_id" do
      stream_server = %StreamServer{
        id: Ecto.UUID.generate(),
        lock_version: 2,
        name: "edge-1"
      }

      application_id = Ecto.UUID.generate()

      assert StreamServerWasAssignedToApplication.new(stream_server, application_id) ==
               %StreamServerWasAssignedToApplication{
                 stream_id: stream_server.id,
                 id: stream_server.id,
                 application_id: application_id,
                 lock_version: 2
               }
    end

    test "StreamServerWasUnassignedFromApplication maps server fields and application_id" do
      stream_server = %StreamServer{
        id: Ecto.UUID.generate(),
        lock_version: 4,
        name: "edge-1"
      }

      application_id = Ecto.UUID.generate()

      assert StreamServerWasUnassignedFromApplication.new(stream_server, application_id) ==
               %StreamServerWasUnassignedFromApplication{
                 stream_id: stream_server.id,
                 id: stream_server.id,
                 application_id: application_id,
                 lock_version: 4
               }
    end
  end
end
