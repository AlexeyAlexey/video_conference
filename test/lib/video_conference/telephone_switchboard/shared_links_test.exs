defmodule VideoConference.TelephoneSwitchboard.SharedLinksTest do
  use VideoConference.DataCase

  import VideoConference.AccountsFixtures
  import VideoConference.TelephoneSwitchboard.SharedLinksFixtures
  alias VideoConference.TelephoneSwitchboard.SharedLinks
  alias VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink
  alias VideoConference.Accounts.Scope

  describe "connection_credentials/1" do
    test "returns connection credentials for shared link without password" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)

      assert {:ok, result} = SharedLinks.connection_credentials(link_id: shared_link.link_id)

      assert is_map(result)
      assert result["switchboard_video_uri"]
      assert result["switchboard_audio_uri"]

      assert result["switchboard_video_server_cert_hash"]
      assert result["switchboard_audio_server_cert_hash"]
    end

    test "returns connection credentials for shared link with password" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      assert {:ok, result} =
               SharedLinks.connection_credentials(
                 link_id: shared_link.link_id,
                 password: "secret123"
               )

      assert is_map(result)
      assert result["switchboard_video_uri"]
      assert result["switchboard_audio_uri"]

      assert result["switchboard_video_server_cert_hash"]
      assert result["switchboard_audio_server_cert_hash"]
    end

    test "returns error for non-existent shared link" do
      result = SharedLinks.connection_credentials(link_id: "nonexistent")

      assert result == {:error, :not_found}
    end

    test "returns error for invalid password" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      result =
        SharedLinks.connection_credentials(
          link_id: shared_link.link_id,
          password: "wrongpassword"
        )

      assert result == {:error, "invalid password"}
    end

    test "returns error when password required but not provided" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      result = SharedLinks.connection_credentials(link_id: shared_link.link_id)

      assert result == {:error, "requires password"}
    end
  end

  describe "one_by/1" do
    test "returns shared link by link_id" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)

      result = SharedLinks.one_by(link_id: shared_link.link_id)

      assert {:ok, %SharedLink{id: id}} = result
      assert id == shared_link.id
    end

    test "returns error for non-existent link" do
      result = SharedLinks.one_by(link_id: "nonexistent")

      assert result == {:error, :not_found}
    end
  end

  describe "one_by/2 with scope" do
    test "returns shared link by link_id within user's scope" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs1 = %{
        "name" => "My Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs1)

      scope2 = Scope.for(phone2)
      result = SharedLinks.one_by(scope2, link_id: shared_link.link_id)

      assert result == {:error, :not_found}

      scope1 = Scope.for(phone1)
      result = SharedLinks.one_by(scope1, link_id: shared_link.link_id)

      assert {:ok, %SharedLink{id: id}} = result
      assert id == shared_link.id
    end
  end

  describe "list/1" do
    test "returns all shared links for a user" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      attrs1 = %{
        "name" => "Link A",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => false
      }

      attrs2 = %{
        "name" => "Link B",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "pass123"
      }

      link1 = create_shared_link(attrs1)
      link2 = create_shared_link(attrs2)

      result = SharedLinks.list(scope)

      assert length(result) == 2
      assert Enum.any?(result, fn l -> l.id == link1.id end)
      assert Enum.any?(result, fn l -> l.id == link2.id end)
    end

    test "only returns links for the specified user" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs1 = %{
        "name" => "My Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => false
      }

      attrs2 = %{
        "name" => "Other Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone2.id,
        "password_required" => false
      }

      link1 = create_shared_link(attrs1)
      link2 = create_shared_link(attrs2)

      scope1 = Scope.for(phone1)
      result1 = SharedLinks.list(scope1)
      assert length(result1) == 1
      assert Enum.any?(result1, fn l -> l.id == link1.id end)

      scope2 = Scope.for(phone2)
      result2 = SharedLinks.list(scope2)
      assert length(result2) == 1
      assert Enum.any?(result2, fn l -> l.id == link2.id end)
    end
  end

  describe "generate/2" do
    test "generates shared link without password" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      {:ok, shared_link} =
        SharedLinks.generate(scope, %{
          "name" => "Test Link"
        })

      assert shared_link.name == "Test Link"
      assert is_binary(shared_link.link_id)
      refute shared_link.password_required
      refute shared_link.hashed_password
    end

    test "generates shared link with password" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      {:ok, shared_link} =
        SharedLinks.generate(scope, %{
          "name" => "Test Link",
          "password" => "secret123"
        })

      assert shared_link.name == "Test Link"
      assert shared_link.link_id
      assert shared_link.password_required
      assert shared_link.hashed_password
    end

    test "generates unique link_id for each call" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      {:ok, link1} = SharedLinks.generate(scope, %{"name" => "Link 1"})
      {:ok, link2} = SharedLinks.generate(scope, %{"name" => "Link 2"})

      refute link1.link_id == link2.link_id
    end
  end

  describe "enable_password/2" do
    test "enables password on shared link" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)

      assert shared_link.password_required == false

      scope = Scope.for(phone)

      {:ok, updated_link} =
        SharedLinks.enable_password(scope, %{
          "id" => shared_link.id,
          "password" => "newpass123"
        })

      assert updated_link.password_required
      assert updated_link.hashed_password
    end

    test "returns error for non-existent link" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      result =
        SharedLinks.enable_password(scope, %{
          "id" => generate_shared_link_id(),
          "password" => "newpass123"
        })

      assert result == {:error, :not_found}
    end

    test "returns error for link belonging to another user" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)
      scope2 = Scope.for(phone2)

      result =
        SharedLinks.enable_password(scope2, %{
          "id" => shared_link.id,
          "password" => "newpass123"
        })

      assert result == {:error, :not_found}
    end
  end

  describe "disable_password/2" do
    test "disables password on shared link" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      assert shared_link.password_required
      assert shared_link.hashed_password

      scope = Scope.for(phone)

      {:ok, updated_link} =
        SharedLinks.disable_password(scope, %{
          "id" => shared_link.id
        })

      refute updated_link.password_required
      assert is_nil(updated_link.hashed_password)
    end

    test "returns error for non-existent link" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      result =
        SharedLinks.disable_password(scope, %{
          "id" => generate_shared_link_id()
        })

      assert result == {:error, :not_found}
    end

    test "returns error for link belonging to another user" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)
      scope2 = Scope.for(phone2)

      result =
        SharedLinks.disable_password(scope2, %{
          "id" => shared_link.id
        })

      assert result == {:error, :not_found}
    end
  end

  describe "remove/2" do
    test "removes shared link" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)
      scope = Scope.for(phone)

      assert Repo.exists?(SharedLink) == true

      {:ok, deleted_link} = SharedLinks.remove(scope, shared_link.id)

      assert deleted_link.id == shared_link.id
      refute Repo.exists?(SharedLink, id: shared_link.id)
    end

    test "returns error for non-existent link" do
      phone = create_phone_account(unique_phone())
      scope = Scope.for(phone)

      result = SharedLinks.remove(scope, generate_shared_link_id())

      assert result == {:error, :not_found}
    end

    test "returns error for link belonging to another user" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs)
      scope2 = Scope.for(phone2)

      result = SharedLinks.remove(scope2, shared_link.id)

      assert result == {:error, :not_found}
    end
  end

  describe "find_for/2" do
    test "finds shared link within user's scope" do
      phone1 = create_phone_account(unique_phone())
      phone2 = create_phone_account(unique_phone())

      attrs1 = %{
        "name" => "My Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone1.id,
        "password_required" => false
      }

      shared_link = create_shared_link(attrs1)

      scope2 = Scope.for(phone2)
      result = SharedLinks.find_for(scope2, id: shared_link.id)
      assert result == {:error, :not_found}

      scope1 = Scope.for(phone1)
      result = SharedLinks.find_for(scope1, id: shared_link.id)
      assert {:ok, %SharedLink{id: id}} = result
      assert id == shared_link.id
    end
  end
end
