defmodule VideoConference.StreamServerAdminPortal.ApplicationsTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.Applications

  alias VideoConference.StreamServerAdminPortal.Applications.{
    ApiKey,
    Application,
    PublicStreamServerKey
  }

  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo

  import VideoConference.StreamServerAdminPortalFixtures

  describe "list_applications/0" do
    test "returns applications ordered by name" do
      app = application_fixture(%{"name" => "zzz app"})

      names = Enum.map(Applications.list_applications(), & &1.name)

      assert "Default App" in names
      assert app.name in names
      assert names == Enum.sort(names)
    end
  end

  describe "create_application/1" do
    test "creates an application with a generated UUID and enabled flag" do
      {:ok, %Application{} = application} =
        Applications.create_application(%{"name" => "my app", "description" => "desc"})

      assert {:ok, _} = Ecto.UUID.cast(application.id)
      assert application.name == "my app"
      assert application.description == "desc"
      assert application.enabled == true
      assert application.inserted_at
      assert application.updated_at
    end

    test "returns an error changeset without a name" do
      {:error, changeset} = Applications.create_application(%{"description" => "no name"})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error changeset for a duplicate name" do
      application = application_fixture()

      {:error, changeset} = Applications.create_application(%{"name" => application.name})

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update_application/2" do
    test "updates name, description, and enabled" do
      application = application_fixture()

      {:ok, updated} =
        Applications.update_application(application, %{
          "name" => "renamed",
          "description" => "new desc",
          "enabled" => false
        })

      assert updated.name == "renamed"
      assert updated.description == "new desc"
      assert updated.enabled == false
    end
  end

  describe "delete_application/1" do
    test "deletes the application and cascades to its API keys" do
      application = application_fixture()
      key = api_key_fixture(application)

      {:ok, _} = Applications.delete_application(application)

      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_application!(application.id)
      end

      assert_raise Ecto.NoResultsError, fn -> Applications.get_api_key!(key.id) end
      refute PortalRepo.exists?(from(k in ApiKey, where: k.application_id == ^application.id))
    end
  end

  describe "create_api_key/1" do
    test "creates a key under the application and returns the plaintext secret once" do
      application = application_fixture()

      {:ok, %ApiKey{} = api_key} =
        Applications.create_api_key(%{
          "name" => "key one",
          "application_id" => application.id,
          "description" => "desc"
        })

      assert {:ok, _} = Ecto.UUID.cast(api_key.id)
      assert api_key.application_id == application.id
      assert api_key.enabled == true
      assert api_key.plaintext_key =~ ~r/^ssak_[A-Za-z0-9_-]{43}$/
      assert Bcrypt.verify_pass(api_key.plaintext_key, api_key.hashed_api_key)
    end

    test "stores the secret only as a hash" do
      application = application_fixture()

      {:ok, api_key} =
        Applications.create_api_key(%{
          "name" => "key one",
          "application_id" => application.id
        })

      stored = Applications.get_api_key!(api_key.id)

      assert stored.hashed_api_key =~ "$2b$"
      refute stored.hashed_api_key == api_key.plaintext_key
      refute stored.plaintext_key
    end

    test "returns an error changeset for a duplicate name within the application" do
      application = application_fixture()
      api_key = api_key_fixture(application)

      {:error, changeset} =
        Applications.create_api_key(%{
          "name" => api_key.name,
          "application_id" => application.id
        })

      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows the same key name on different applications" do
      application = application_fixture()
      other = application_fixture()
      api_key = api_key_fixture(application)

      {:ok, other_key} =
        Applications.create_api_key(%{
          "name" => api_key.name,
          "application_id" => other.id
        })

      assert other_key.application_id == other.id
    end
  end

  describe "update_api_key/2" do
    test "updates fields without changing the stored secret hash" do
      application = application_fixture()
      api_key = api_key_fixture(application)

      {:ok, updated} =
        Applications.update_api_key(api_key, %{
          "name" => "renamed key",
          "description" => "new desc",
          "enabled" => false
        })

      assert updated.name == "renamed key"
      assert updated.description == "new desc"
      assert updated.enabled == false
      assert updated.hashed_api_key == api_key.hashed_api_key

      reloaded = Applications.get_api_key!(api_key.id)
      refute reloaded.plaintext_key
    end
  end

  describe "delete_api_key/1" do
    test "removes the key" do
      api_key = api_key_fixture(application_fixture())

      {:ok, _} = Applications.delete_api_key(api_key)

      assert_raise Ecto.NoResultsError, fn -> Applications.get_api_key!(api_key.id) end
    end
  end

  describe "list_applications_with_api_keys/0" do
    test "preloads each application's keys" do
      application = application_fixture()
      key = api_key_fixture(application)

      loaded =
        Applications.list_applications_with_api_keys()
        |> Enum.find(&(&1.id == application.id))

      assert [%ApiKey{id: id}] = loaded.api_keys
      assert id == key.id
    end
  end

  describe "create_public_stream_server_key/1" do
    test "creates a key with a generated UUID that serves as its public key id" do
      application = application_fixture()

      {:ok, %PublicStreamServerKey{} = key} =
        Applications.create_public_stream_server_key(%{
          "name" => "key one",
          "public_key" => valid_public_key_pem(),
          "application_id" => application.id,
          "description" => "desc"
        })

      assert {:ok, _} = Ecto.UUID.cast(key.id)
      assert key.name == "key one"
      assert key.public_key == valid_public_key_pem()
      assert key.application_id == application.id
      assert key.disabled == false
      assert key.description == "desc"
      assert key.inserted_at
      assert key.updated_at
    end

    test "creates a key without a name" do
      application = application_fixture()

      {:ok, %PublicStreamServerKey{} = key} =
        Applications.create_public_stream_server_key(%{
          "public_key" => valid_public_key_pem(),
          "application_id" => application.id
        })

      assert key.name == nil
    end

    test "allows duplicate names within the same application" do
      application = application_fixture()
      key = public_stream_server_key_fixture(application)

      {:ok, other} =
        Applications.create_public_stream_server_key(%{
          "name" => key.name,
          "public_key" => valid_public_key_pem(),
          "application_id" => application.id
        })

      assert other.name == key.name
      assert other.id != key.id
    end

    test "returns an error changeset without a public key" do
      application = application_fixture()

      {:error, changeset} =
        Applications.create_public_stream_server_key(%{
          "name" => "key one",
          "application_id" => application.id
        })

      assert %{public_key: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error changeset without an application" do
      {:error, changeset} =
        Applications.create_public_stream_server_key(%{
          "public_key" => valid_public_key_pem()
        })

      assert %{application_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "raises a constraint error for a nonexistent application" do
      assert_raise Ecto.ConstraintError, fn ->
        Applications.create_public_stream_server_key(%{
          "public_key" => valid_public_key_pem(),
          "application_id" => Ecto.UUID.generate()
        })
      end
    end
  end

  describe "get_public_stream_server_key!/1" do
    test "returns the key" do
      key = public_stream_server_key_fixture(application_fixture())

      assert Applications.get_public_stream_server_key!(key.id).id == key.id
    end

    test "raises when the key does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_public_stream_server_key!(Ecto.UUID.generate())
      end
    end
  end

  describe "update_public_stream_server_key/2" do
    test "updates fields" do
      application = application_fixture()
      other = application_fixture()
      key = public_stream_server_key_fixture(application)

      {:ok, updated} =
        Applications.update_public_stream_server_key(key, %{
          "name" => "renamed key",
          "public_key" => "-----BEGIN PUBLIC KEY-----\nother\n-----END PUBLIC KEY-----",
          "disabled" => true,
          "description" => "new desc",
          "application_id" => other.id
        })

      assert updated.name == "renamed key"
      assert updated.public_key =~ "other"
      assert updated.disabled == true
      assert updated.description == "new desc"
      assert updated.application_id == other.id
    end
  end

  describe "delete_public_stream_server_key/1" do
    test "removes the key" do
      key = public_stream_server_key_fixture(application_fixture())

      {:ok, _} = Applications.delete_public_stream_server_key(key)

      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_public_stream_server_key!(key.id)
      end
    end
  end

  describe "change_public_stream_server_key/2" do
    test "returns a changeset" do
      key = public_stream_server_key_fixture(application_fixture())

      assert %Ecto.Changeset{} = Applications.change_public_stream_server_key(key)
    end
  end

  describe "list_applications_with_public_keys/1" do
    test "preloads each application's public keys ordered by name" do
      application = application_fixture()
      _key_b = public_stream_server_key_fixture(application, %{"name" => "b-key"})
      key_a = public_stream_server_key_fixture(application, %{"name" => "a-key"})

      loaded =
        Applications.list_applications_with_public_keys()
        |> Enum.find(&(&1.id == application.id))

      assert [%PublicStreamServerKey{name: "a-key"}, %PublicStreamServerKey{name: "b-key"}] =
               loaded.public_stream_server_keys

      assert hd(loaded.public_stream_server_keys).id == key_a.id
    end

    test "filters to a single application" do
      application = application_fixture()
      other = application_fixture()
      key = public_stream_server_key_fixture(application)
      _other_key = public_stream_server_key_fixture(other)

      loaded = Applications.list_applications_with_public_keys(application_id: application.id)

      assert [%Application{id: id}] = loaded
      assert id == application.id
      assert [%PublicStreamServerKey{id: key_id}] = hd(loaded).public_stream_server_keys
      assert key_id == key.id
    end

    test "nil and empty filter list every application" do
      application = application_fixture()
      _key = public_stream_server_key_fixture(application)

      assert Applications.list_applications_with_public_keys() != []

      assert Enum.map(
               Applications.list_applications_with_public_keys(application_id: ""),
               & &1.id
             ) ==
               Enum.map(Applications.list_applications_with_public_keys(), & &1.id)
    end
  end

  describe "delete_application/1 with public keys" do
    test "deletes the application and cascades to its public stream server keys" do
      application = application_fixture()
      key = public_stream_server_key_fixture(application)

      {:ok, _} = Applications.delete_application(application)

      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_public_stream_server_key!(key.id)
      end

      refute PortalRepo.exists?(
               from(k in PublicStreamServerKey, where: k.application_id == ^application.id)
             )
    end
  end
end
