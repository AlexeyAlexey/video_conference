defmodule VideoConference.AdminPortal.Accounts.AdminTest do
  use VideoConference.DataCase, async: false

  alias VideoConference.AdminPortal.Accounts.Admin
  import VideoConference.AdminPortalFixtures

  describe "registration_changeset/3" do
    test "requires email and password" do
      changeset = Admin.registration_changeset(%Admin{}, %{})

      assert %{email: ["can't be blank"], password: ["can't be blank"]} =
               errors_on(changeset)
    end

    test "validates email format" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{
          "email" => "has spaces@and space.com",
          "password" => valid_admin_password(),
          "password_confirmation" => valid_admin_password()
        })

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates email uniqueness" do
      %{email: email} = admin_fixture()

      changeset =
        Admin.registration_changeset(%Admin{}, %{
          "email" => email,
          "password" => valid_admin_password(),
          "password_confirmation" => valid_admin_password()
        })

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end

    test "validates password confirmation" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{
          "email" => unique_admin_email(),
          "password" => valid_admin_password(),
          "password_confirmation" => "different password"
        })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "hashes the password" do
      changeset =
        Admin.registration_changeset(%Admin{}, %{
          "email" => unique_admin_email(),
          "password" => valid_admin_password(),
          "password_confirmation" => valid_admin_password()
        })

      assert changeset.valid?
      assert is_binary(get_change(changeset, :hashed_password))
      assert is_nil(get_change(changeset, :password))
    end
  end

  describe "password_changeset/3" do
    test "requires password" do
      changeset = Admin.password_changeset(%Admin{}, %{})
      assert %{password: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates password length" do
      changeset = Admin.password_changeset(%Admin{}, %{"password" => "ab"})
      assert %{password: ["should be at least 3 character(s)"]} = errors_on(changeset)
    end

    test "validates confirmation" do
      changeset =
        Admin.password_changeset(%Admin{}, %{
          "password" => "new password",
          "password_confirmation" => "other password"
        })

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end

    test "does not hash when hash_password: false" do
      changeset =
        Admin.password_changeset(%Admin{}, %{"password" => "new password"}, hash_password: false)

      assert changeset.valid?
      assert is_nil(get_change(changeset, :hashed_password))
    end

    test "validates current password when validate_current: true" do
      admin = admin_fixture()

      changeset =
        Admin.password_changeset(
          admin,
          %{"password" => "new password", "current_password" => "wrong password"},
          validate_current: true,
          hash_password: false
        )

      assert %{current_password: ["is not valid"]} = errors_on(changeset)

      changeset =
        Admin.password_changeset(
          admin,
          %{
            "password" => "new password",
            "current_password" => valid_admin_password()
          },
          validate_current: true,
          hash_password: false
        )

      assert changeset.valid?
    end
  end

  describe "valid_password?/2" do
    test "returns true for correct password" do
      admin = admin_fixture()
      assert Admin.valid_password?(admin, valid_admin_password())
    end

    test "returns false for incorrect password" do
      admin = admin_fixture()
      refute Admin.valid_password?(admin, "wrong password")
    end

    test "returns false for nil admin" do
      refute Admin.valid_password?(nil, valid_admin_password())
    end
  end
end
