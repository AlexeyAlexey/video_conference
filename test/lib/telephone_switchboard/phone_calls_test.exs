defmodule VideoConference.TelephoneSwitchboard.PhoneCallsTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.TelephoneSwitchboard.PhoneCallFixtures

  alias VideoConference.TelephoneSwitchboard.PhoneCalls
  alias VideoConference.TelephoneSwitchboard.PhoneCalls.PhoneCall

  describe "call_to/1" do
    test "creates a phone call successfully" do
      attrs = %{
        from: 123,
        to: 456,
        called_at: DateTime.utc_now()
      }

      assert {:ok, %PhoneCall{from: 123, to: 456}} = PhoneCalls.call_to(attrs)
    end

    test "creates a phone call with all fields" do
      attrs = %{
        from_host_id: 1,
        from: 123,
        to_host_id: 2,
        to: 456,
        called_at: DateTime.utc_now()
      }

      assert {:ok, %PhoneCall{from: 123, to: 456, from_host_id: 1, to_host_id: 2}} =
               PhoneCalls.call_to(attrs)
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

    test "does not return ended calls" do
      to = 123

      create_phone_call(%{
        from: 432,
        to: to,
        called_at: DateTime.utc_now(),
        ended_at: DateTime.utc_now()
      })

      assert PhoneCalls.current_income_calls(to: to) == []
    end

    test "does not return responded calls" do
      to = 123

      create_phone_call(%{
        from: 432,
        to: to,
        called_at: DateTime.utc_now(),
        responded_at: DateTime.utc_now()
      })

      assert PhoneCalls.current_income_calls(to: to) == []
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
          direction: "income",
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
