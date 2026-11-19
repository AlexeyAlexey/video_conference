defmodule VideoConference.AdminPortal.PublicStreamServerKeysTest do
  use VideoConference.DataCase, async: false

  import VideoConference.PublicStreamServerKeysFixtures
  import VideoConference.StreamServersFixtures

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.{KeyEncryption, PublicStreamServerKey}
  alias VideoConference.Repo

  setup do
    %{stream_server: stream_server_fixture()}
  end

  describe "create_public_stream_server_key/1" do
    test "persists a key with required fields and defaults", %{stream_server: server} do
      {:ok, key} =
        StreamServers.create_public_stream_server_key(
          valid_public_stream_server_key_attributes(%{"stream_server_id" => server.id})
        )

      assert key.disabled == false
      assert key.public_key_id == nil
      assert key.stream_server_id == server.id
    end

    test "stores the private key encrypted and decryptable", %{stream_server: server} do
      {:ok, key} =
        StreamServers.create_public_stream_server_key(
          valid_public_stream_server_key_attributes(%{"stream_server_id" => server.id})
        )

      assert key.private_key != valid_private_key_pem()
      refute key.private_key =~ "fake-private-key"
      assert {:ok, pem} = StreamServers.decrypt_private_key(key)
      assert pem == valid_private_key_pem()
      assert Repo.get!(PublicStreamServerKey, key.id).private_key == key.private_key
    end

    test "requires name, public_key, stream_server_id and private_key_pem" do
      {:error, changeset} = StreamServers.create_public_stream_server_key(%{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).public_key
      assert "can't be blank" in errors_on(changeset).stream_server_id
      assert "can't be blank" in errors_on(changeset).private_key_pem
    end

    test "rejects a duplicate name on the same server", %{stream_server: server} do
      key = public_stream_server_key_fixture(server, %{"name" => "taken"})

      {:error, changeset} =
        StreamServers.create_public_stream_server_key(
          valid_public_stream_server_key_attributes(%{
            "name" => "taken",
            "stream_server_id" => server.id
          })
        )

      assert "has already been taken" in errors_on(changeset).name
      assert Repo.get!(PublicStreamServerKey, key.id).name == "taken"
    end

    test "allows the same name on a different server", %{stream_server: server} do
      other = stream_server_fixture()
      public_stream_server_key_fixture(server, %{"name" => "same name"})

      {:ok, key} =
        StreamServers.create_public_stream_server_key(
          valid_public_stream_server_key_attributes(%{
            "name" => "same name",
            "stream_server_id" => other.id
          })
        )

      assert key.stream_server_id == other.id
    end
  end

  describe "update_public_stream_server_key/2" do
    test "a blank private_key_pem keeps the stored private key", %{stream_server: server} do
      key = public_stream_server_key_fixture(server)

      {:ok, updated} =
        StreamServers.update_public_stream_server_key(key, %{
          "name" => "renamed",
          "private_key_pem" => ""
        })

      assert updated.name == "renamed"
      assert updated.private_key == key.private_key
      assert {:ok, pem} = StreamServers.decrypt_private_key(updated)
      assert pem == valid_private_key_pem()
    end

    test "a new private_key_pem replaces and re-encrypts the key", %{stream_server: server} do
      key = public_stream_server_key_fixture(server)
      new_pem = "-----BEGIN PRIVATE KEY-----\nnew-key\n-----END PRIVATE KEY-----"

      {:ok, updated} =
        StreamServers.update_public_stream_server_key(key, %{"private_key_pem" => new_pem})

      assert updated.private_key != key.private_key
      assert {:ok, ^new_pem} = StreamServers.decrypt_private_key(updated)
    end

    test "fills in public_key_id later", %{stream_server: server} do
      key = public_stream_server_key_fixture(server)
      assert key.public_key_id == nil

      {:ok, updated} =
        StreamServers.update_public_stream_server_key(key, %{"public_key_id" => "key-42"})

      assert updated.public_key_id == "key-42"
    end
  end

  describe "generate_public_stream_server_key/1" do
    test "generates and persists a key pair without a public_key_id",
         %{stream_server: server} do
      {:ok, key} =
        StreamServers.generate_public_stream_server_key(%{
          "name" => "generated",
          "stream_server_id" => server.id
        })

      assert key.public_key =~ "PUBLIC KEY"
      refute key.private_key =~ "PRIVATE KEY"
      assert key.public_key_id == nil
      assert {:ok, private_pem} = StreamServers.decrypt_private_key(key)
      assert private_pem =~ "BEGIN PRIVATE KEY"
    end

    test "generated keys differ between calls", %{stream_server: server} do
      {:ok, first} =
        StreamServers.generate_public_stream_server_key(%{
          "name" => "gen1",
          "stream_server_id" => server.id
        })

      {:ok, second} =
        StreamServers.generate_public_stream_server_key(%{
          "name" => "gen2",
          "stream_server_id" => server.id
        })

      assert first.public_key != second.public_key
    end
  end

  describe "list_stream_servers_with_public_keys/0" do
    test "returns servers with their keys preloaded", %{stream_server: server} do
      key = public_stream_server_key_fixture(server)
      empty = stream_server_fixture(%{"name" => "empty"})

      servers = StreamServers.list_stream_servers_with_public_keys()

      loaded = Enum.find(servers, &(&1.id == server.id))
      assert [%PublicStreamServerKey{id: id}] = loaded.public_stream_server_keys
      assert id == key.id

      empty_loaded = Enum.find(servers, &(&1.id == empty.id))
      assert empty_loaded.public_stream_server_keys == []
    end
  end

  describe "change_public_stream_server_key/2" do
    test "returns a changeset", %{stream_server: server} do
      key = public_stream_server_key_fixture(server)
      assert %Ecto.Changeset{} = StreamServers.change_public_stream_server_key(key)
    end
  end

  test "delete_public_stream_server_key/1 removes the key", %{stream_server: server} do
    key = public_stream_server_key_fixture(server)

    assert {:ok, %PublicStreamServerKey{}} = StreamServers.delete_public_stream_server_key(key)

    assert_raise Ecto.NoResultsError, fn ->
      StreamServers.get_public_stream_server_key!(key.id)
    end
  end

  test "KeyEncryption is used transparently on update", %{stream_server: server} do
    key = public_stream_server_key_fixture(server)

    {:ok, updated} =
      StreamServers.update_public_stream_server_key(key, %{"description" => "d"})

    assert updated.private_key == key.private_key
    assert {:ok, pem} = KeyEncryption.decrypt(updated.private_key)
    assert pem == valid_private_key_pem()
  end
end
