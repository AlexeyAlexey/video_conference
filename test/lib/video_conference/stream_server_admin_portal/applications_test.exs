defmodule VideoConference.StreamServerAdminPortal.ApplicationsTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.{ApiKey, Application}
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
end
