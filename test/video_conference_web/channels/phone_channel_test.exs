defmodule VideoConferenceWeb.PhoneChannelTest do
  use VideoConferenceWeb.ChannelCase

  import VideoConference.CustomCase
  import VideoConference.AccountsFixtures

  alias VideoConferenceWeb.PhoneSocket
  alias VideoConferenceWeb.PhoneChannel

  alias VideoConference.Accounts.Phone
  alias VideoConference.Accounts.Scope

  describe "phone socket connection" do
    test "assign current_scope and current_phone_number" do
      phone = create_phone_account(1234)

      assert {:ok, socket} =
               connect(PhoneSocket, %{},
                 connect_info: %{
                   auth_token: valid_auth_token(phone)
                 }
               )

      assert %{current_scope: %Scope{phone: %Phone{phone: 1234}}, current_phone_number: 1234} =
               socket.assigns
    end

    test "invalid auth token" do
      assert :error = connect(PhoneSocket, %{}, connect_info: %{auth_token: "invalidtoken"})
    end
  end

  describe "join to his own phone channel" do
    test "cannot connect to not own phone channel" do
      phone = create_phone_account(1234)

      assert {:ok, socket} =
               connect(PhoneSocket, %{}, connect_info: %{auth_token: valid_auth_token(phone)})

      {:error, %{reason: "unauthorized"}} =
        subscribe_and_join(socket, PhoneChannel, "phone:#{29876}", %{})
    end

    test "successfully connecting to his own channel" do
      phone = create_phone_account(1234)

      assert {:ok, socket} =
               connect(PhoneSocket, %{}, connect_info: %{auth_token: valid_auth_token(phone)})

      {:ok, _, _socket} =
        subscribe_and_join(socket, PhoneChannel, "phone:#{1234}", %{})
    end
  end

  # describe "phone books" do
  #   test "list of phones" do
  #     phone = create_phone_account(1234)
  #     create_phone_account(54321)
  #     create_phone_account(64321)

  #     assert {:ok, socket} =
  #              connect(PhoneSocket, %{}, connect_info: %{auth_token: valid_auth_token(phone)})

  #     {:ok, _, socket} =
  #       subscribe_and_join(socket, PhoneChannel, "phone:#{1234}", %{})

  #     ref = push(socket, "list_of_phones", %{})
  #     assert_reply ref, :ok, [%{"phone" => 54321}, %{"phone" => 64321}]
  #   end
  # end

  describe "calls between locals" do
    test "receive switchboard auth token" do
      outcome_phone = create_phone_account(1234)
      create_phone_account(54321)
      to = 54321

      {:ok, socket} =
        connect(PhoneSocket, %{}, connect_info: %{auth_token: valid_auth_token(outcome_phone)})

      {:ok, _, socket} =
        subscribe_and_join(socket, PhoneChannel, "phone:#{1234}", %{})

      ref = push(socket, "call", %{"to" => to})

      assert_reply ref, :ok, %{
        "to" => ^to,
        "switchboard_audio_server_cert_hash" => switchboard_audio_server_cert_hash,
        "switchboard_audio_uri" => switchboard_audio_uri,
        "switchboard_video_server_cert_hash" => switchboard_video_server_cert_hash,
        "switchboard_video_uri" => switchboard_video_uri
      }

      assert switchboard_audio_server_cert_hash
      assert switchboard_audio_uri
      assert switchboard_video_server_cert_hash
      assert switchboard_video_uri
    end

    test "broadcast income call to destination" do
      outcome_phone = create_phone_account(1234)
      create_phone_account(54321)
      from = 1234
      to = 54321

      calling_topic = "phone:#{to}"

      {:ok, socket} =
        connect(PhoneSocket, %{}, connect_info: %{auth_token: valid_auth_token(outcome_phone)})

      {:ok, _, socket} =
        subscribe_and_join(socket, PhoneChannel, "phone:#{1234}", %{})

      VideoConferenceWeb.Endpoint.subscribe(calling_topic)

      push(socket, "call", %{"to" => to})

      assert_receive %Phoenix.Socket.Broadcast{
        topic: ^calling_topic,
        event: "income_call",
        payload: %{"from" => ^from}
      }
    end
  end

  describe "income_call from local" do
    test "income_call" do
      create_phone_account(1234)
      destination_phone = create_phone_account(54321)
      from = 1234
      to = 54321

      {:ok, socket} =
        connect(PhoneSocket, %{},
          connect_info: %{auth_token: valid_auth_token(destination_phone)}
        )

      {:ok, _, socket} =
        subscribe_and_join(socket, PhoneChannel, "phone:#{to}", %{})

      ref = push(socket, "income_call", %{"from" => from})

      assert_reply ref, :ok, %{
        "from" => ^from,
        "switchboard_audio_server_cert_hash" => switchboard_audio_server_cert_hash,
        "switchboard_audio_uri" => switchboard_audio_uri,
        "switchboard_video_server_cert_hash" => switchboard_video_server_cert_hash,
        "switchboard_video_uri" => switchboard_video_uri
      }

      assert switchboard_audio_server_cert_hash
      assert switchboard_audio_uri
      assert switchboard_video_server_cert_hash
      assert switchboard_video_uri
    end
  end
end
