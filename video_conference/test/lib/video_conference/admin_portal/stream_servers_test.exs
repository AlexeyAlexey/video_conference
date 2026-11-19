defmodule VideoConference.AdminPortal.StreamServersTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.StreamServer

  import VideoConference.StreamServersFixtures

  describe "list_stream_servers/0" do
    test "returns all stream servers" do
      stream_server = stream_server_fixture()

      ids = Enum.map(StreamServers.list_stream_servers(), & &1.id)

      assert stream_server.id in ids
    end

    test "lists servers ordered by name" do
      stream_server_fixture(%{"name" => "zzz"})
      stream_server_fixture(%{"name" => "aaa"})

      assert [%StreamServer{name: "aaa"} | _] = StreamServers.list_stream_servers()
    end
  end

  describe "get_stream_server!/1" do
    test "returns the server with the given id" do
      stream_server = stream_server_fixture()
      assert StreamServers.get_stream_server!(stream_server.id).id == stream_server.id
    end

    test "raises for an unknown id" do
      assert_raise Ecto.NoResultsError, fn -> StreamServers.get_stream_server!(0) end
    end
  end

  describe "create_stream_server/1" do
    test "persists a server with default flags, no country, and empty settings" do
      name = unique_stream_server_name()

      assert {:ok, %StreamServer{} = stream_server} =
               StreamServers.create_stream_server(%{"name" => name})

      assert stream_server.name == name
      assert stream_server.country == nil
      assert stream_server.third_party == false
      assert stream_server.settings == %{}
    end

    test "requires a name" do
      assert {:error, changeset} = StreamServers.create_stream_server(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects a duplicate name" do
      stream_server = stream_server_fixture()

      assert {:error, changeset} =
               StreamServers.create_stream_server(%{"name" => stream_server.name})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "certificate hash" do
    test "stores cert_hash under settings" do
      assert {:ok, %StreamServer{} = stream_server} =
               StreamServers.create_stream_server(%{
                 "name" => unique_stream_server_name(),
                 "cert_hash" => "xxxxxxxxxxx"
               })

      assert stream_server.settings == %{"cert_hash" => "xxxxxxxxxxx"}
    end

    test "updates and clears settings.cert_hash" do
      stream_server = stream_server_fixture(%{"cert_hash" => "abc"})

      assert {:ok, %StreamServer{} = updated} =
               StreamServers.update_stream_server(stream_server, %{"cert_hash" => "def"})

      assert updated.settings["cert_hash"] == "def"

      assert {:ok, %StreamServer{} = cleared} =
               StreamServers.update_stream_server(updated, %{"cert_hash" => ""})

      refute Map.has_key?(cleared.settings, "cert_hash")
    end

    test "preserves other settings keys" do
      stream_server = stream_server_fixture(%{"cert_hash" => "abc"})

      assert {:ok, %StreamServer{} = updated} =
               StreamServers.update_stream_server(stream_server, %{
                 "settings" => %{"cert_hash" => "abc", "other" => "value"},
                 "cert_hash" => ""
               })

      assert updated.settings == %{"other" => "value"}
    end

    test "populates the virtual field from settings for edit forms" do
      stream_server = stream_server_fixture(%{"cert_hash" => "abc"})

      changeset = StreamServers.change_stream_server(stream_server)
      assert Ecto.Changeset.get_field(changeset, :cert_hash) == "abc"
    end
  end

  describe "country" do
    test "persists a supported ISO alpha-2 code" do
      stream_server = stream_server_fixture(%{"country" => "de"})
      assert stream_server.country == "de"
    end

    test "clears the country" do
      stream_server = stream_server_fixture(%{"country" => "de"})

      assert {:ok, %StreamServer{} = updated} =
               StreamServers.update_stream_server(stream_server, %{"country" => ""})

      assert updated.country == nil
    end

    test "rejects an unsupported country code" do
      assert {:error, changeset} =
               StreamServers.create_stream_server(%{
                 "name" => unique_stream_server_name(),
                 "country" => "xx"
               })

      assert %{country: [_ | _]} = errors_on(changeset)
    end
  end

  describe "update_stream_server/2" do
    test "updates a server" do
      stream_server = stream_server_fixture()

      assert {:ok, %StreamServer{} = updated} =
               StreamServers.update_stream_server(stream_server, %{
                 "name" => "renamed",
                 "description" => "new description",
                 "host" => "10.0.0.1",
                 "third_party" => true
               })

      assert updated.name == "renamed"
      assert updated.description == "new description"
      assert updated.host == "10.0.0.1"
      assert updated.third_party == true
    end

    test "rejects renaming to a taken name" do
      stream_server = stream_server_fixture()
      other = stream_server_fixture()

      assert {:error, changeset} =
               StreamServers.update_stream_server(stream_server, %{"name" => other.name})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "delete_stream_server/1" do
    test "deletes a server" do
      stream_server = stream_server_fixture()

      assert {:ok, %StreamServer{}} = StreamServers.delete_stream_server(stream_server)
      refute Repo.exists?(from(s in StreamServer, where: s.id == ^stream_server.id))
    end
  end

  describe "change_stream_server/2" do
    test "returns a changeset" do
      stream_server = stream_server_fixture()

      assert %Ecto.Changeset{data: %StreamServer{}} =
               StreamServers.change_stream_server(stream_server)
    end
  end
end
