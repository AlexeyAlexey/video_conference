defmodule VideoConference.AdminPortal.AccountsTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.AdminPortal.Accounts
  alias VideoConference.AdminPortal.Accounts.{Admin, Scope, Token}

  import VideoConference.AdminPortalFixtures

  describe "get_admin_by_email/1" do
    test "returns the admin with matching email" do
      admin = admin_fixture()
      assert Accounts.get_admin_by_email(admin.email).id == admin.id
    end

    test "returns nil for unknown email" do
      assert Accounts.get_admin_by_email("unknown@example.com") == nil
    end
  end

  describe "get_admin_by_email_and_password/2" do
    test "returns the admin on valid credentials" do
      admin = admin_fixture()

      assert %Admin{id: id} =
               Accounts.get_admin_by_email_and_password(admin.email, valid_admin_password())

      assert id == admin.id
    end

    test "returns nil on wrong password" do
      admin = admin_fixture()
      assert Accounts.get_admin_by_email_and_password(admin.email, "wrong password") == nil
    end

    test "returns nil on unknown email" do
      assert Accounts.get_admin_by_email_and_password("unknown@example.com", "password") == nil
    end
  end

  describe "register_admin/1" do
    test "registers an admin with hashed password" do
      email = unique_admin_email()

      {:ok, admin} =
        Accounts.register_admin(%{
          "email" => email,
          "password" => valid_admin_password(),
          "password_confirmation" => valid_admin_password()
        })

      assert admin.email == email
      assert is_binary(admin.hashed_password)
      assert Admin.valid_password?(admin, valid_admin_password())
    end

    test "returns an error changeset for duplicate email" do
      admin = admin_fixture()

      {:error, changeset} =
        Accounts.register_admin(%{
          "email" => admin.email,
          "password" => valid_admin_password(),
          "password_confirmation" => valid_admin_password()
        })

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "session tokens" do
    test "generate_session_token/1 stores a token" do
      admin = admin_fixture()
      token = Accounts.generate_session_token(admin)

      assert Repo.exists?(from(t in Token, where: t.admin_id == ^admin.id))
      assert is_binary(token)
    end

    test "get_admin_by_session_token/1 returns the admin for a valid token" do
      admin = admin_fixture()
      token = Accounts.generate_session_token(admin)
      {:ok, token} = Base.url_decode64(token, padding: false)

      assert {:ok, {%Admin{id: id}, _inserted_at}} = Accounts.get_admin_by_session_token(token)
      assert id == admin.id
    end

    test "get_admin_by_session_token/1 returns error for invalid token" do
      assert {:error, :not_found} = Accounts.get_admin_by_session_token("invalid")
    end

    test "delete_session_token/1 removes the token" do
      admin = admin_fixture()
      token = Accounts.generate_session_token(admin)
      {:ok, token} = Base.url_decode64(token, padding: false)

      assert :ok = Accounts.delete_session_token(token)
      assert {:error, :not_found} = Accounts.get_admin_by_session_token(token)
    end
  end

  describe "change_admin_password/2" do
    test "returns a changeset" do
      admin = admin_fixture()
      assert %Ecto.Changeset{data: %Admin{}} = Accounts.change_admin_password(admin)
    end
  end

  describe "update_admin_password/2" do
    test "updates the password and expires all tokens" do
      admin = admin_fixture()
      token = Accounts.generate_session_token(admin)

      {:ok, {updated_admin, expired_tokens}} =
        Accounts.update_admin_password(admin, %{
          "current_password" => valid_admin_password(),
          "password" => "new password",
          "password_confirmation" => "new password"
        })

      assert Admin.valid_password?(updated_admin, "new password")
      assert expired_tokens != []
      assert {:error, :not_found} = Accounts.get_admin_by_session_token(token)
    end

    test "fails on wrong current password" do
      admin = admin_fixture()

      {:error, changeset} =
        Accounts.update_admin_password(admin, %{
          "current_password" => "wrong password",
          "password" => "new password",
          "password_confirmation" => "new password"
        })

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end
  end

  describe "Scope.for/1" do
    test "builds a scope carrying the admin" do
      admin = admin_fixture()
      assert %Scope{admin: ^admin} = Scope.for(admin)
    end

    test "returns nil for nil" do
      assert Scope.for(nil) == nil
    end
  end
end
