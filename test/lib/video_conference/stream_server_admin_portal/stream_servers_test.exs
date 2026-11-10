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

    test "rejects a duplicate name" do
      stream_server = stream_server_fixture(%{"name" => "taken"})

      {:error, changeset} = StreamServers.create_stream_server(%{"name" => "taken"})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
      assert stream_server.id
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
  end

  describe "rename_stream_server/2" do
    test "renames a stream server" do
      stream_server = stream_server_fixture(%{"name" => "old", "host" => "1.1.1.1"})

      {:ok, updated} = StreamServers.rename_stream_server(stream_server.id, "new")

      assert updated.name == "new"
      assert StreamServers.get_stream_server!(stream_server.id).name == "new"
    end

    test "rejects a duplicate name" do
      _other = stream_server_fixture(%{"name" => "taken"})
      stream_server = stream_server_fixture(%{"name" => "old"})

      {:error, changeset} = StreamServers.rename_stream_server(stream_server.id, "taken")

      assert %{name: ["has already been taken"]} = errors_on(changeset)
      assert StreamServers.get_stream_server!(stream_server.id).name == "old"
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

    test "a stale delete returns an error changeset instead of raising" do
      stream_server = stream_server_fixture()
      stale = StreamServers.get_stream_server!(stream_server.id)

      {:ok, _} = StreamServers.rename_stream_server(stream_server.id, "renamed")

      assert {:error, changeset} = StreamServers.delete_stream_server(stale)
      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert StreamServers.get_stream_server!(stream_server.id)
    end
  end

  describe "delete_stream_server/1" do
    test "deletes the server and its application assignments" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)

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

  describe "assign_application/2 and unassign_application/2" do
    test "assigns an application to a stream server" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.assign_application(stream_server.id, application.id)

      assert Enum.map(updated.applications, & &1.id) == [application.id]
    end

    test "assigning the same application twice is a no-op" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)
      {:ok, updated} = StreamServers.assign_application(stream_server.id, application.id)

      assert Enum.map(updated.applications, & &1.id) == [application.id]
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

    test "unassigning an application that is not assigned is a no-op" do
      application = application_fixture()
      stream_server = stream_server_fixture()

      {:ok, updated} = StreamServers.unassign_application(stream_server.id, application.id)

      assert updated.applications == []
    end

    test "deleting an application removes its assignments" do
      application = application_fixture()
      stream_server = stream_server_fixture()
      {:ok, _} = StreamServers.assign_application(stream_server.id, application.id)

      {:ok, _} = Applications.delete_application(application)

      loaded = StreamServers.get_stream_server!(stream_server.id)
      assert loaded.applications == []
    end
  end
end
