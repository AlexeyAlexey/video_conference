defmodule VideoConference.TelephoneSwitchboard.PhoneCallsTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.TelephoneSwitchboard.PhoneCallFixtures

  alias VideoConference.TelephoneSwitchboard.AuthTokenTestHelper
  alias VideoConference.TelephoneSwitchboard.PhoneCalls
  alias VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCall

  describe "call_to/1" do
    test "creates a phone call successfully" do
      attrs = %{
        from: 123,
        to: 456,
        called_at: DateTime.utc_now()
      }

      assert {:ok, %PhoneCall{} = phone_call} = PhoneCalls.call_to(attrs)
      assert is_integer(phone_call.called_at)

      participants =
        phone_call
        |> PhoneCalls.list_participants()
        |> Enum.map(&Map.take(&1, [:direction, :phone, :phone_call_id, :phone_call_called_at]))
        |> Enum.sort_by(& &1.direction)

      assert [
               %{
                 direction: "income",
                 phone: 456,
                 phone_call_id: income_call_id,
                 phone_call_called_at: income_called_at
               },
               %{
                 direction: "outcome",
                 phone: 123,
                 phone_call_id: outcome_call_id,
                 phone_call_called_at: outcome_called_at
               }
             ] = participants

      assert income_call_id == phone_call.id
      assert outcome_call_id == phone_call.id
      assert DateTime.to_unix(income_called_at, :millisecond) == phone_call.called_at
      assert DateTime.to_unix(outcome_called_at, :millisecond) == phone_call.called_at
    end

    test "creates a phone call with all fields" do
      attrs = %{
        from_host_id: 1,
        from: 123,
        to_host_id: 2,
        to: 456,
        called_at: DateTime.utc_now()
      }

      assert {:ok, %PhoneCall{} = phone_call} = PhoneCalls.call_to(attrs)

      participants = PhoneCalls.list_participants(phone_call)
      outcome = Enum.find(participants, &(&1.direction == "outcome"))
      income = Enum.find(participants, &(&1.direction == "income"))

      assert %{host_id: 1, phone: 123} = Map.take(outcome, [:host_id, :phone])
      assert %{host_id: 2, phone: 456} = Map.take(income, [:host_id, :phone])
    end
  end

  describe "current_income_calls/1" do
    test "returns calls within the last 30 seconds" do
      to = 123

      create_phone_call(%{
        from: 432,
        to: to,
        called_at: DateTime.utc_now()
      })

      create_phone_call(%{
        from: 4567,
        to: to,
        called_at: ~U[2026-06-01 08:08:25.747857Z]
      })

      assert PhoneCalls.current_income_calls(to: to) == [
               %{from: 432, from_host_id: nil}
             ]
    end
  end

  describe "connection_credentials/1" do
    test "returns connection options for audio and video streams" do
      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: 123,
          to_host_id: "local",
          to: 456,
          direction: "outcome",
          stream_type: ["audio", "video"]
        )

      assert {:ok, connection_options} = result
      assert is_map(connection_options)

      assert %{
               "switchboard_audio_server_cert_hash" => switchboard_audio_server_cert_hash,
               "switchboard_audio_uri" => switchboard_audio_uri,
               "switchboard_video_server_cert_hash" => switchboard_video_server_cert_hash,
               "switchboard_video_uri" => switchboard_video_uri
             } = connection_options

      assert switchboard_audio_server_cert_hash
      assert switchboard_audio_uri
      assert switchboard_video_server_cert_hash
      assert switchboard_video_uri
    end

    test "switchboard_video_uri and switchboard_audio_uri params" do
      from = 123
      to = 456

      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: from,
          to_host_id: "local",
          to: to,
          direction: "outcome",
          stream_type: ["audio", "video"]
        )

      assert {:ok, connection_options} = result
      assert is_map(connection_options)

      assert %{
               "switchboard_audio_server_cert_hash" => _,
               "switchboard_audio_uri" => switchboard_audio_uri,
               "switchboard_video_server_cert_hash" => _,
               "switchboard_video_uri" => switchboard_video_uri
             } = connection_options

      assert {:ok,
              %{
                "room_id" => audio_room_id,
                "participant_id" => ^from,
                "host" => "local",
                "custom_params" => %{
                  "from" => ^from,
                  "from_host_id" => "local",
                  "to" => ^to,
                  "to_host_id" => "local",
                  "direction" => "outcome",
                  "connection_type" => "phone_call",
                  "stream_type" => "audio",
                  "called_at" => audio_called_at,
                  "phone_call_id" => audio_phone_call_id
                }
              }} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(switchboard_audio_uri)

      assert audio_room_id == "phone_call/audio/#{audio_called_at}/#{audio_phone_call_id}"

      assert {:ok,
              %{
                "room_id" => video_room_id,
                "participant_id" => ^from,
                "host" => "local",
                "custom_params" => %{
                  "from" => ^from,
                  "from_host_id" => "local",
                  "to" => ^to,
                  "to_host_id" => "local",
                  "direction" => "outcome",
                  "connection_type" => "phone_call",
                  "stream_type" => "video",
                  "called_at" => video_called_at,
                  "phone_call_id" => video_phone_call_id
                }
              }} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(switchboard_video_uri)

      assert video_room_id == "phone_call/video/#{video_called_at}/#{video_phone_call_id}"

      assert audio_phone_call_id == video_phone_call_id
      assert audio_called_at == video_called_at
      assert audio_room_id != video_room_id
    end

    test "income direction returns credentials for the pending call" do
      from = 123
      to = 456

      {:ok, outcome_options} =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: from,
          to_host_id: "local",
          to: to,
          direction: "outcome",
          stream_type: ["video"]
        )

      {:ok, income_options} =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: from,
          to_host_id: "local",
          to: to,
          direction: "income",
          stream_type: ["video"]
        )

      assert {:ok, %{"room_id" => outcome_room_id, "participant_id" => ^from}} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(
                 outcome_options["switchboard_video_uri"]
               )

      assert {:ok, %{"room_id" => income_room_id, "participant_id" => ^to}} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(
                 income_options["switchboard_video_uri"]
               )

      assert outcome_room_id == income_room_id
    end

    test "income direction returns error when there is no pending call" do
      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: 123,
          to_host_id: "local",
          to: 456,
          direction: "income",
          stream_type: ["audio"]
        )

      assert {:error, "call_not_found"} = result
    end

    test "returns error when calling yourself" do
      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: 123,
          to_host_id: "local",
          to: 123,
          direction: "outcome",
          stream_type: ["audio"]
        )

      assert {:error, "You are trying to call yourself"} = result
    end

    test "returns connection options for audio only" do
      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: 123,
          to_host_id: "local",
          to: 456,
          direction: "outcome",
          stream_type: ["audio"]
        )

      assert {:ok, connection_options} = result
      assert is_map(connection_options)

      assert %{
               "switchboard_audio_server_cert_hash" => switchboard_audio_server_cert_hash,
               "switchboard_audio_uri" => switchboard_audio_uri
             } = connection_options

      assert switchboard_audio_server_cert_hash
      assert switchboard_audio_uri
    end

    test "returns connection options for video only" do
      result =
        PhoneCalls.connection_credentials(
          from_host_id: "local",
          from: 123,
          to_host_id: "local",
          to: 456,
          direction: "outcome",
          stream_type: ["video"]
        )

      assert {:ok, connection_options} = result
      assert is_map(connection_options)

      assert %{
               "switchboard_video_server_cert_hash" => switchboard_video_server_cert_hash,
               "switchboard_video_uri" => switchboard_video_uri
             } = connection_options

      assert switchboard_video_server_cert_hash
      assert switchboard_video_uri
    end
  end
end
