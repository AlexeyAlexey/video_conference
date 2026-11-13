defmodule VideoConference.StreamServerAdminPortal.ApplicationsTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.StreamServerAdminPortal.ApiKeySecret
  alias VideoConference.StreamServerAdminPortal.Applications

  alias VideoConference.StreamServerAdminPortal.Applications.{
    ApiKey,
    Application,
    ApplicationDescriptionWasUpdated,
    ApplicationWasAdded,
    ApplicationWasDisabled,
    ApplicationWasEnabled,
    ApplicationWasRenamed,
    StreamServerPublicKey,
    StreamServerPublicKeyWasAdded,
    StreamServerPublicKeyWasDisabled,
    StreamServerPublicKeyWasEnabled,
    StreamServerPublicKeyWasMoved,
    StreamServerPublicKeyWasRemoved
  }

  alias VideoConference.StreamServerAdminPortal.EventStore
  alias VideoConference.StreamServerAdminPortal.Repo, as: PortalRepo

  import VideoConference.StreamServerAdminPortalFixtures

  describe "list_applications/1" do
    test "returns applications ordered by name" do
      app = application_fixture(%{"name" => "zzz app"})

      names = Enum.map(Applications.list_applications(), & &1.name)

      assert "Default App" in names
      assert app.name in names
      assert names == Enum.sort(names)
    end

    test "narrows the list by a case-insensitive name search" do
      _match = application_fixture(%{"name" => "Zucchini App"})
      _other = application_fixture(%{"name" => "plain metrics"})

      names = Enum.map(Applications.list_applications(search: "zucchini"), & &1.name)

      assert names == ["Zucchini App"]
    end

    test "nil and empty search list every application" do
      all = Enum.map(Applications.list_applications(), & &1.id)

      assert Enum.map(Applications.list_applications(search: ""), & &1.id) == all
      assert Enum.map(Applications.list_applications(search: nil), & &1.id) == all
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

    test "allows two applications to share a name" do
      application = application_fixture()

      {:ok, %Application{} = other} =
        Applications.create_application(%{"name" => application.name})

      assert other.name == application.name
      assert other.id != application.id
    end

    test "commits the application and an ApplicationWasAdded event together" do
      {:ok, %Application{} = application} =
        Applications.create_application(%{"name" => "my app", "description" => "desc"})

      assert [stored] = EventStore.get_events([inspect(ApplicationWasAdded)], 0)
      assert stored.stream_id == application.id
      assert stored.version == 1

      assert stored.payload == %ApplicationWasAdded{
               stream_id: application.id,
               id: application.id,
               name: "my app",
               description: "desc",
               enabled: true,
               lock_version: 1
             }
    end

    test "a failing create stores no event" do
      {:error, _changeset} = Applications.create_application(%{"description" => "no name"})

      assert EventStore.get_events([inspect(ApplicationWasAdded)], 0) == []
    end
  end

  describe "rename_application/2" do
    test "renames the application" do
      application = application_fixture()

      {:ok, updated} = Applications.rename_application(application.id, "renamed")

      assert updated.name == "renamed"
      assert Applications.get_application!(application.id).name == "renamed"
    end

    test "allows renaming to a name another application already has" do
      application = application_fixture()
      other = application_fixture()

      {:ok, updated} = Applications.rename_application(other.id, application.name)

      assert updated.name == application.name
    end

    test "returns an error changeset without a name" do
      application = application_fixture()

      {:error, changeset} = Applications.rename_application(application.id, "")

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "stores an ApplicationWasRenamed event with the incremented lock_version" do
      application = application_fixture()

      {:ok, updated} = Applications.rename_application(application.id, "renamed")
      assert updated.lock_version == 2

      assert [stored] = EventStore.get_events([inspect(ApplicationWasRenamed)], 0)
      assert stored.stream_id == application.id
      assert stored.version == 2

      assert stored.payload == %ApplicationWasRenamed{
               stream_id: application.id,
               id: application.id,
               name: "renamed",
               lock_version: 2
             }
    end

    test "a failing rename stores no event" do
      application = application_fixture()

      {:error, _changeset} = Applications.rename_application(application.id, "")

      assert EventStore.get_events([inspect(ApplicationWasRenamed)], 0) == []
    end
  end

  describe "edit_application_description/2" do
    test "updates the description" do
      application = application_fixture()

      {:ok, updated} =
        Applications.edit_application_description(application.id, "new desc")

      assert updated.description == "new desc"
      assert Applications.get_application!(application.id).description == "new desc"
    end

    test "stores an ApplicationDescriptionWasUpdated event with the incremented lock_version" do
      application = application_fixture()

      {:ok, updated} =
        Applications.edit_application_description(application.id, "new desc")

      assert updated.lock_version == 2

      assert [stored] =
               EventStore.get_events([inspect(ApplicationDescriptionWasUpdated)], 0)

      assert stored.stream_id == application.id
      assert stored.version == 2

      assert stored.payload == %ApplicationDescriptionWasUpdated{
               stream_id: application.id,
               id: application.id,
               description: "new desc",
               lock_version: 2
             }
    end
  end

  describe "enable_application/1 and disable_application/1" do
    test "toggles the enabled flag" do
      application = application_fixture()
      assert application.enabled == true

      {:ok, disabled} = Applications.disable_application(application.id)
      assert disabled.enabled == false
      assert Applications.get_application!(application.id).enabled == false

      {:ok, enabled} = Applications.enable_application(application.id)
      assert enabled.enabled == true
      assert Applications.get_application!(application.id).enabled == true
    end

    test "stores enabled and disabled events with the incremented lock_version" do
      application = application_fixture()

      {:ok, disabled} = Applications.disable_application(application.id)
      assert disabled.lock_version == 2

      {:ok, enabled} = Applications.enable_application(application.id)
      assert enabled.lock_version == 3

      assert [disabled_event] =
               EventStore.get_events([inspect(ApplicationWasDisabled)], 0)

      assert disabled_event.stream_id == application.id

      assert disabled_event.payload == %ApplicationWasDisabled{
               stream_id: application.id,
               id: application.id,
               lock_version: 2
             }

      assert [enabled_event] = EventStore.get_events([inspect(ApplicationWasEnabled)], 0)
      assert enabled_event.stream_id == application.id

      assert enabled_event.payload == %ApplicationWasEnabled{
               stream_id: application.id,
               id: application.id,
               lock_version: 3
             }
    end
  end

  describe "application optimistic locking" do
    test "increments lock_version on each update" do
      application = application_fixture()
      assert application.lock_version == 1

      {:ok, application} = Applications.rename_application(application.id, "renamed")
      assert application.lock_version == 2

      {:ok, application} =
        Applications.edit_application_description(application.id, "desc")

      assert application.lock_version == 3

      {:ok, application} = Applications.disable_application(application.id)
      assert application.lock_version == 4

      assert Applications.get_application!(application.id).lock_version == 4
    end

    test "a stale update returns an error changeset instead of raising" do
      application = application_fixture()
      stale = Applications.get_application!(application.id)

      {:ok, _} = Applications.rename_application(application.id, "renamed")

      assert {:error, changeset} =
               stale
               |> Application.name_changeset(%{"name" => "stale name"})
               |> PortalRepo.update(stale_error_field: :lock_version)

      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert Applications.get_application!(application.id).name == "renamed"
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
      assert api_key.lock_version == 1
      assert api_key.prefix =~ ~r/^aak_[0-9a-f-]{36}$/
      assert api_key.plaintext_key =~ ~r/^aak_[0-9a-f-]{36}_[A-Za-z0-9_-]{43}$/
      assert String.starts_with?(api_key.plaintext_key, api_key.prefix <> "_")
      assert ApiKeySecret.verify(api_key.plaintext_key, api_key.hashed_api_key)

      loaded = Applications.get_api_key!(api_key.id)
      assert loaded.prefix == api_key.prefix
      assert loaded.plaintext_key == nil
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

    test "requires a name and an application_id" do
      {:error, changeset} = Applications.create_api_key(%{})

      assert %{name: ["can't be blank"], application_id: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "rejects a missing application" do
      assert_raise Ecto.ConstraintError, fn ->
        Applications.create_api_key(%{
          "name" => "n",
          "application_id" => Ecto.UUID.generate()
        })
      end
    end

    test "allows duplicate names within the same application" do
      application = application_fixture()
      api_key = api_key_fixture(application)

      {:ok, %ApiKey{} = other_key} =
        Applications.create_api_key(%{
          "name" => api_key.name,
          "application_id" => application.id
        })

      assert other_key.name == api_key.name
      assert other_key.id != api_key.id
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

    test "enforces the prefix unique constraint" do
      application = application_fixture()
      existing = api_key_fixture(application)

      {:error, changeset} =
        %ApiKey{}
        |> ApiKey.changeset(%{
          "name" => "other",
          "application_id" => application.id
        })
        |> Ecto.Changeset.put_change(:prefix, existing.prefix)
        |> Ecto.Changeset.put_change(:hashed_api_key, "another-hash")
        |> PortalRepo.insert()

      assert %{prefix: ["has already been taken"]} = errors_on(changeset)
    end

    test "enforces the hashed secret unique constraint per application" do
      application = application_fixture()
      existing = api_key_fixture(application)

      {:error, changeset} =
        %ApiKey{}
        |> ApiKey.changeset(%{
          "name" => "other",
          "application_id" => application.id
        })
        |> Ecto.Changeset.put_change(:prefix, "aak_" <> Ecto.UUID.generate())
        |> Ecto.Changeset.put_change(:hashed_api_key, existing.hashed_api_key)
        |> PortalRepo.insert()

      assert %{hashed_api_key: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "list_api_keys/1" do
    test "returns the application's keys ordered by name" do
      application = application_fixture()
      b_key = api_key_fixture(application, %{"name" => "b-key"})
      a_key = api_key_fixture(application, %{"name" => "a-key"})
      _other = api_key_fixture(application_fixture())

      keys = Applications.list_api_keys(application.id)

      assert Enum.map(keys, & &1.id) == [a_key.id, b_key.id]
    end
  end

  describe "get_api_key!/1" do
    test "returns the key and raises when missing" do
      key = api_key_fixture(application_fixture())

      assert Applications.get_api_key!(key.id).id == key.id

      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_api_key!(Ecto.UUID.generate())
      end
    end
  end

  describe "api key field updates" do
    test "rename, description edit, and enable/disable bump lock_version" do
      key = api_key_fixture(application_fixture())
      assert key.lock_version == 1

      {:ok, key} = Applications.rename_api_key(key.id, "renamed")
      assert key.name == "renamed"
      assert key.lock_version == 2

      {:ok, key} = Applications.edit_api_key_description(key.id, "new desc")
      assert key.description == "new desc"
      assert key.lock_version == 3

      {:ok, key} = Applications.disable_api_key(key.id)
      assert key.enabled == false
      assert key.lock_version == 4

      {:ok, key} = Applications.enable_api_key(key.id)
      assert key.enabled == true
      assert key.lock_version == 5

      assert Applications.get_api_key!(key.id).lock_version == 5
    end

    test "rename requires a name" do
      key = api_key_fixture(application_fixture())

      {:error, changeset} = Applications.rename_api_key(key.id, "")

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "a stale update returns an error changeset instead of raising" do
      key = api_key_fixture(application_fixture())
      stale = Applications.get_api_key!(key.id)

      {:ok, _} = Applications.rename_api_key(key.id, "renamed")

      assert {:error, changeset} =
               stale
               |> ApiKey.name_changeset(%{"name" => "stale name"})
               |> PortalRepo.update(stale_error_field: :lock_version)

      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert Applications.get_api_key!(key.id).name == "renamed"
    end

    test "no update path can change the hashed secret" do
      key = api_key_fixture(application_fixture())
      attrs = %{"hashed_api_key" => "forged"}

      for changeset <- [
            ApiKey.name_changeset(key, Map.put(attrs, "name", "x")),
            ApiKey.description_changeset(key, attrs),
            ApiKey.enabled_changeset(key, Map.put(attrs, "enabled", false))
          ] do
        refute Map.has_key?(changeset.changes, :hashed_api_key)
      end
    end
  end

  describe "change_api_key/2" do
    test "returns a changeset" do
      key = api_key_fixture(application_fixture())

      assert %Ecto.Changeset{} = Applications.change_api_key(key)
    end
  end

  describe "create_stream_server_public_key/1" do
    test "creates a key with a generated UUID that serves as its key id" do
      application = application_fixture()

      {:ok, %StreamServerPublicKey{} = key} =
        Applications.create_stream_server_public_key(%{
          "name" => "key one",
          "key" => valid_public_key_pem(),
          "application_id" => application.id,
          "description" => "desc"
        })

      assert {:ok, _} = Ecto.UUID.cast(key.id)
      assert key.name == "key one"
      assert key.key == valid_public_key_pem()
      assert key.application_id == application.id
      assert key.enabled == true
      assert key.description == "desc"
      assert key.lock_version == 1
      assert key.inserted_at
      assert key.updated_at
    end

    test "creates a key without a name" do
      application = application_fixture()

      {:ok, %StreamServerPublicKey{} = key} =
        Applications.create_stream_server_public_key(%{
          "key" => valid_public_key_pem(),
          "application_id" => application.id
        })

      assert key.name == nil
    end

    test "allows duplicate names within the same application" do
      application = application_fixture()
      key = stream_server_public_key_fixture(application)

      {:ok, other} =
        Applications.create_stream_server_public_key(%{
          "name" => key.name,
          "key" => valid_public_key_pem(),
          "application_id" => application.id
        })

      assert other.name == key.name
      assert other.id != key.id
    end

    test "returns an error changeset without a key" do
      application = application_fixture()

      {:error, changeset} =
        Applications.create_stream_server_public_key(%{
          "name" => "key one",
          "application_id" => application.id
        })

      assert %{key: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an error changeset without an application" do
      {:error, changeset} =
        Applications.create_stream_server_public_key(%{
          "key" => valid_public_key_pem()
        })

      assert %{application_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "raises a constraint error for a nonexistent application" do
      assert_raise Ecto.ConstraintError, fn ->
        Applications.create_stream_server_public_key(%{
          "key" => valid_public_key_pem(),
          "application_id" => Ecto.UUID.generate()
        })
      end
    end

    test "commits the key and a StreamServerPublicKeyWasAdded together" do
      application = application_fixture()

      {:ok, %StreamServerPublicKey{} = key} =
        Applications.create_stream_server_public_key(%{
          "name" => "key one",
          "key" => valid_public_key_pem(),
          "application_id" => application.id,
          "description" => "desc"
        })

      assert [stored] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasAdded)], 0)

      assert stored.stream_id == key.id
      assert stored.version == 1

      assert stored.payload == %StreamServerPublicKeyWasAdded{
               stream_id: key.id,
               id: key.id,
               application_id: application.id,
               name: "key one",
               key: valid_public_key_pem(),
               enabled: true,
               description: "desc",
               lock_version: 1
             }
    end

    test "a failing event append rolls back the key insert" do
      application = application_fixture()

      changeset =
        StreamServerPublicKey.changeset(%StreamServerPublicKey{}, %{
          "name" => "rolled back",
          "key" => valid_public_key_pem(),
          "application_id" => application.id
        })

      assert {:error, _operation, %Ecto.Changeset{} = error_changeset, _changes} =
               Ecto.Multi.new()
               |> Ecto.Multi.insert(:stream_server_public_key, changeset)
               |> Ecto.Multi.merge(fn _changes ->
                 EventStore.append([%StreamServerPublicKeyWasAdded{stream_id: nil}])
               end)
               |> PortalRepo.transaction()

      assert %{stream_id: ["can't be blank"]} = errors_on(error_changeset)

      refute PortalRepo.exists?(from(k in StreamServerPublicKey, where: k.name == "rolled back"))
    end
  end

  describe "application event new/1" do
    test "ApplicationWasAdded maps all fields from the application" do
      application = %Application{
        id: Ecto.UUID.generate(),
        lock_version: 1,
        name: "name",
        description: "desc",
        enabled: true
      }

      assert ApplicationWasAdded.new(application) == %ApplicationWasAdded{
               stream_id: application.id,
               id: application.id,
               name: "name",
               description: "desc",
               enabled: true,
               lock_version: 1
             }
    end

    test "ApplicationWasRenamed maps all fields from the application" do
      application = %Application{
        id: Ecto.UUID.generate(),
        lock_version: 2,
        name: "renamed",
        description: "desc",
        enabled: false
      }

      assert ApplicationWasRenamed.new(application) == %ApplicationWasRenamed{
               stream_id: application.id,
               id: application.id,
               name: "renamed",
               lock_version: 2
             }
    end

    test "ApplicationDescriptionWasUpdated maps all fields from the application" do
      application = %Application{
        id: Ecto.UUID.generate(),
        lock_version: 3,
        name: "name",
        description: "new desc",
        enabled: true
      }

      assert ApplicationDescriptionWasUpdated.new(application) ==
               %ApplicationDescriptionWasUpdated{
                 stream_id: application.id,
                 id: application.id,
                 description: "new desc",
                 lock_version: 3
               }
    end

    test "ApplicationWasEnabled maps all fields from the application" do
      application = %Application{
        id: Ecto.UUID.generate(),
        lock_version: 4,
        name: "name",
        description: "desc",
        enabled: true
      }

      assert ApplicationWasEnabled.new(application) == %ApplicationWasEnabled{
               stream_id: application.id,
               id: application.id,
               lock_version: 4
             }
    end

    test "ApplicationWasDisabled maps all fields from the application" do
      application = %Application{
        id: Ecto.UUID.generate(),
        lock_version: 5,
        name: "name",
        description: "desc",
        enabled: false
      }

      assert ApplicationWasDisabled.new(application) == %ApplicationWasDisabled{
               stream_id: application.id,
               id: application.id,
               lock_version: 5
             }
    end
  end

  describe "stream server public key event constructors" do
    test "StreamServerPublicKeyWasAdded maps all fields from the key" do
      key = %StreamServerPublicKey{
        id: Ecto.UUID.generate(),
        lock_version: 2,
        application_id: Ecto.UUID.generate(),
        name: "name",
        key: "pem",
        enabled: false,
        description: "desc"
      }

      assert StreamServerPublicKeyWasAdded.new(key) == %StreamServerPublicKeyWasAdded{
               stream_id: key.id,
               id: key.id,
               application_id: key.application_id,
               name: "name",
               key: "pem",
               enabled: false,
               description: "desc",
               lock_version: 2
             }
    end

    test "StreamServerPublicKeyWasEnabled maps all fields from the key" do
      key = %StreamServerPublicKey{
        id: Ecto.UUID.generate(),
        lock_version: 3,
        application_id: Ecto.UUID.generate(),
        name: "name",
        key: "pem",
        enabled: true
      }

      assert StreamServerPublicKeyWasEnabled.new(key) == %StreamServerPublicKeyWasEnabled{
               stream_id: key.id,
               id: key.id,
               lock_version: 3
             }
    end

    test "StreamServerPublicKeyWasDisabled maps all fields from the key" do
      key = %StreamServerPublicKey{
        id: Ecto.UUID.generate(),
        lock_version: 4,
        application_id: Ecto.UUID.generate(),
        name: "name",
        key: "pem",
        enabled: false
      }

      assert StreamServerPublicKeyWasDisabled.new(key) == %StreamServerPublicKeyWasDisabled{
               stream_id: key.id,
               id: key.id,
               lock_version: 4
             }
    end

    test "StreamServerPublicKeyWasRemoved maps all fields from the key" do
      key = %StreamServerPublicKey{
        id: Ecto.UUID.generate(),
        lock_version: 5,
        application_id: Ecto.UUID.generate(),
        name: "name",
        key: "pem",
        enabled: true
      }

      assert StreamServerPublicKeyWasRemoved.new(key) == %StreamServerPublicKeyWasRemoved{
               stream_id: key.id,
               id: key.id,
               lock_version: 5
             }
    end

    test "StreamServerPublicKeyWasMoved maps applications from the pre- and post-move keys" do
      from_application_id = Ecto.UUID.generate()
      to_application_id = Ecto.UUID.generate()
      key_id = Ecto.UUID.generate()

      before_move = %StreamServerPublicKey{
        id: key_id,
        lock_version: 1,
        application_id: from_application_id,
        name: "name",
        key: "pem",
        enabled: true
      }

      after_move = %StreamServerPublicKey{
        id: key_id,
        lock_version: 2,
        application_id: to_application_id,
        name: "name",
        key: "pem",
        enabled: true
      }

      assert StreamServerPublicKeyWasMoved.new(before_move, after_move) ==
               %StreamServerPublicKeyWasMoved{
                 stream_id: key_id,
                 id: key_id,
                 from_application_id: from_application_id,
                 to_application_id: to_application_id,
                 lock_version: 2
               }
    end
  end

  describe "stream server public key optimistic locking" do
    test "increments lock_version on each update" do
      application = application_fixture()
      other = application_fixture()
      key = stream_server_public_key_fixture(application)
      assert key.lock_version == 1

      {:ok, key} = Applications.rename_stream_server_public_key(key.id, "renamed")
      assert key.lock_version == 2

      {:ok, key} = Applications.edit_stream_server_public_key_description(key.id, "desc")
      assert key.lock_version == 3

      {:ok, key} =
        Applications.move_stream_server_public_key_to_application(key.id, other.id)

      assert key.lock_version == 4

      {:ok, key} = Applications.disable_stream_server_public_key(key.id)
      assert key.lock_version == 5

      assert Applications.get_stream_server_public_key!(key.id).lock_version == 5
    end

    test "a stale update returns an error changeset instead of raising" do
      key = stream_server_public_key_fixture(application_fixture())
      stale = Applications.get_stream_server_public_key!(key.id)

      {:ok, _} = Applications.rename_stream_server_public_key(key.id, "renamed")

      assert {:error, changeset} =
               stale
               |> StreamServerPublicKey.name_changeset(%{"name" => "stale name"})
               |> PortalRepo.update(stale_error_field: :lock_version)

      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert Applications.get_stream_server_public_key!(key.id).name == "renamed"
    end

    test "a stale delete returns an error changeset instead of raising" do
      key = stream_server_public_key_fixture(application_fixture())
      stale = Applications.get_stream_server_public_key!(key.id)

      {:ok, _} = Applications.rename_stream_server_public_key(key.id, "renamed")

      assert {:error, changeset} = Applications.remove_stream_server_public_key(stale)
      assert %{lock_version: ["is stale"]} = errors_on(changeset)
      assert Applications.get_stream_server_public_key!(key.id)
      assert EventStore.get_events([inspect(StreamServerPublicKeyWasRemoved)], 0) == []
    end
  end

  describe "get_stream_server_public_key!/1" do
    test "returns the key" do
      key = stream_server_public_key_fixture(application_fixture())

      assert Applications.get_stream_server_public_key!(key.id).id == key.id
    end

    test "raises when the key does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_stream_server_public_key!(Ecto.UUID.generate())
      end
    end
  end

  describe "rename_stream_server_public_key/2" do
    test "renames the key" do
      key = stream_server_public_key_fixture(application_fixture())

      {:ok, updated} = Applications.rename_stream_server_public_key(key.id, "renamed key")

      assert updated.name == "renamed key"
      assert Applications.get_stream_server_public_key!(key.id).name == "renamed key"
    end

    test "cannot change the key" do
      key = stream_server_public_key_fixture(application_fixture())

      {:ok, updated} = Applications.rename_stream_server_public_key(key.id, "renamed key")

      assert updated.key == key.key
      assert Applications.get_stream_server_public_key!(key.id).key == key.key
    end
  end

  describe "edit_stream_server_public_key_description/2" do
    test "updates the description" do
      key = stream_server_public_key_fixture(application_fixture())

      {:ok, updated} =
        Applications.edit_stream_server_public_key_description(key.id, "new desc")

      assert updated.description == "new desc"

      assert Applications.get_stream_server_public_key!(key.id).description == "new desc"
    end
  end

  describe "move_stream_server_public_key_to_application/2" do
    test "moves the key to another application" do
      application = application_fixture()
      other = application_fixture()
      key = stream_server_public_key_fixture(application)

      {:ok, updated} =
        Applications.move_stream_server_public_key_to_application(key.id, other.id)

      assert updated.application_id == other.id

      assert Applications.get_stream_server_public_key!(key.id).application_id == other.id
    end

    test "stores a StreamServerPublicKeyWasMoved event with both applications" do
      application = application_fixture()
      other = application_fixture()
      key = stream_server_public_key_fixture(application)

      {:ok, updated} =
        Applications.move_stream_server_public_key_to_application(key.id, other.id)

      assert updated.lock_version == 2

      assert [stored] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasMoved)], 0)

      assert stored.stream_id == key.id
      assert stored.version == 2

      assert stored.payload == %StreamServerPublicKeyWasMoved{
               stream_id: key.id,
               id: key.id,
               from_application_id: application.id,
               to_application_id: other.id,
               lock_version: 2
             }
    end

    test "returns an error changeset without an application and stores no event" do
      key = stream_server_public_key_fixture(application_fixture())

      {:error, changeset} =
        Applications.move_stream_server_public_key_to_application(key.id, nil)

      assert %{application_id: ["can't be blank"]} = errors_on(changeset)
      assert EventStore.get_events([inspect(StreamServerPublicKeyWasMoved)], 0) == []
    end

    test "raises a constraint error for a nonexistent application" do
      key = stream_server_public_key_fixture(application_fixture())

      assert_raise Ecto.ConstraintError, fn ->
        Applications.move_stream_server_public_key_to_application(key.id, Ecto.UUID.generate())
      end
    end
  end

  describe "enable_stream_server_public_key/1 and disable_stream_server_public_key/1" do
    test "toggles the enabled flag" do
      key = stream_server_public_key_fixture(application_fixture())
      assert key.enabled == true

      {:ok, disabled} = Applications.disable_stream_server_public_key(key.id)
      assert disabled.enabled == false
      assert Applications.get_stream_server_public_key!(key.id).enabled == false

      {:ok, enabled} = Applications.enable_stream_server_public_key(key.id)
      assert enabled.enabled == true
      assert Applications.get_stream_server_public_key!(key.id).enabled == true
    end

    test "stores enabled and disabled events with the incremented lock_version" do
      key = stream_server_public_key_fixture(application_fixture())

      {:ok, disabled} = Applications.disable_stream_server_public_key(key.id)
      assert disabled.lock_version == 2

      {:ok, enabled} = Applications.enable_stream_server_public_key(key.id)
      assert enabled.lock_version == 3

      assert [disabled_event] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasDisabled)], 0)

      assert disabled_event.stream_id == key.id

      assert disabled_event.payload == %StreamServerPublicKeyWasDisabled{
               stream_id: key.id,
               id: key.id,
               lock_version: 2
             }

      assert [enabled_event] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasEnabled)], 0)

      assert enabled_event.stream_id == key.id

      assert enabled_event.payload == %StreamServerPublicKeyWasEnabled{
               stream_id: key.id,
               id: key.id,
               lock_version: 3
             }
    end

    test "toggling an already-set flag still stores the event" do
      key = stream_server_public_key_fixture(application_fixture())
      assert key.enabled == true

      {:ok, still_enabled} = Applications.enable_stream_server_public_key(key.id)
      assert still_enabled.enabled == true

      assert [stored] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasEnabled)], 0)

      assert stored.payload == %StreamServerPublicKeyWasEnabled{
               stream_id: key.id,
               id: key.id,
               lock_version: 1
             }
    end
  end

  describe "remove_stream_server_public_key/1" do
    test "removes the key" do
      key = stream_server_public_key_fixture(application_fixture())

      {:ok, _} = Applications.remove_stream_server_public_key(key)

      assert_raise Ecto.NoResultsError, fn ->
        Applications.get_stream_server_public_key!(key.id)
      end
    end

    test "stores a StreamServerPublicKeyWasRemoved event with the matched lock_version" do
      key = stream_server_public_key_fixture(application_fixture())
      {:ok, renamed} = Applications.rename_stream_server_public_key(key.id, "renamed")

      {:ok, _} = Applications.remove_stream_server_public_key(renamed)

      assert [stored] =
               EventStore.get_events([inspect(StreamServerPublicKeyWasRemoved)], 0)

      assert stored.stream_id == key.id
      assert stored.version == 2

      assert stored.payload == %StreamServerPublicKeyWasRemoved{
               stream_id: key.id,
               id: key.id,
               lock_version: 2
             }
    end
  end

  describe "change_stream_server_public_key/2" do
    test "returns a changeset" do
      key = stream_server_public_key_fixture(application_fixture())

      assert %Ecto.Changeset{} = Applications.change_stream_server_public_key(key)
    end
  end

  describe "list_applications_with_stream_server_public_keys/1" do
    test "preloads each application's stream server public keys ordered by name" do
      application = application_fixture()
      _key_b = stream_server_public_key_fixture(application, %{"name" => "b-key"})
      key_a = stream_server_public_key_fixture(application, %{"name" => "a-key"})

      loaded =
        Applications.list_applications_with_stream_server_public_keys()
        |> Enum.find(&(&1.id == application.id))

      assert [%StreamServerPublicKey{name: "a-key"}, %StreamServerPublicKey{name: "b-key"}] =
               loaded.stream_server_public_keys

      assert hd(loaded.stream_server_public_keys).id == key_a.id
    end

    test "filters to a single application" do
      application = application_fixture()
      other = application_fixture()
      key = stream_server_public_key_fixture(application)
      _other_key = stream_server_public_key_fixture(other)

      loaded =
        Applications.list_applications_with_stream_server_public_keys(
          application_id: application.id
        )

      assert [%Application{id: id}] = loaded
      assert id == application.id
      assert [%StreamServerPublicKey{id: key_id}] = hd(loaded).stream_server_public_keys
      assert key_id == key.id
    end

    test "nil and empty filter list every application" do
      application = application_fixture()
      _key = stream_server_public_key_fixture(application)

      assert Applications.list_applications_with_stream_server_public_keys() != []

      assert Enum.map(
               Applications.list_applications_with_stream_server_public_keys(application_id: ""),
               & &1.id
             ) ==
               Enum.map(Applications.list_applications_with_stream_server_public_keys(), & &1.id)
    end
  end
end
