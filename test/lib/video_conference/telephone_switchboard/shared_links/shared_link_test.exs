defmodule VideoConference.TelephoneSwitchboard.SharedLinks.SharedLinkTest do
  use VideoConference.DataCase

  import VideoConference.TelephoneSwitchboard.SharedLinksFixtures
  import VideoConference.AccountsFixtures

  alias VideoConference.TelephoneSwitchboard.SharedLinks.SharedLink

  describe "password validation" do
    test "validates password for shared link with password" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => generate_shared_link_link_id(),
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      assert SharedLink.valid_password?(shared_link, "secret123")
      refute SharedLink.valid_password?(shared_link, "wrongpassword")
    end

    test "valid_password? returns false for non-matching password" do
      phone = create_phone_account(unique_phone())

      attrs = %{
        "name" => "Test Link",
        "link_id" => "sssssssssssssss",
        "phone_id" => phone.id,
        "password_required" => true,
        "password" => "secret123"
      }

      shared_link = create_shared_link(attrs)

      refute SharedLink.valid_password?(shared_link, "wrongpass")
    end
  end

  describe "password required" do
    test "required" do
      assert SharedLink.password_required(%SharedLink{password_required: true})
    end

    test "not required" do
      assert SharedLink.password_required(%SharedLink{password_required: false}) == false
    end
  end
end
