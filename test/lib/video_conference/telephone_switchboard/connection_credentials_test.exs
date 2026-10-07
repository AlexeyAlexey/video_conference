defmodule VideoConference.TelephoneSwitchboard.ConnectionCredentialsTest do
  use VideoConferenceWeb.ConnCase

  alias VideoConference.TelephoneSwitchboard.AuthTokenTestHelper
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  describe "get_public_key_by_host/1" do
    test "returns public key for a known host" do
      assert {:ok, public_key} = ConnectionCredentials.get_public_key_by_host("local")
      assert public_key =~ "BEGIN PUBLIC KEY"
    end

    test "returns error for an unknown host" do
      assert {:error, :not_found} = ConnectionCredentials.get_public_key_by_host("unknown")
    end
  end

  describe "for/1 with conference connection" do
    test "returns video credentials" do
      assert {:ok, credentials} = conference_credentials("video")

      assert %{
               "switchboard_video_uri" => uri,
               "switchboard_video_server_cert_hash" => cert_hash
             } = credentials

      assert cert_hash == stream_server_cert_hash()
      assert_stream_uri(uri, "video")
    end

    test "returns audio credentials" do
      assert {:ok, credentials} = conference_credentials("audio")

      assert %{
               "switchboard_audio_uri" => uri,
               "switchboard_audio_server_cert_hash" => cert_hash
             } = credentials

      assert cert_hash == stream_server_cert_hash()
      assert_stream_uri(uri, "audio")
    end

    test "returns event credentials" do
      assert {:ok, credentials} = conference_credentials("event")

      assert %{
               "switchboard_event_uri" => uri,
               "switchboard_event_server_cert_hash" => cert_hash
             } = credentials

      assert cert_hash == stream_server_cert_hash()
      assert_stream_uri(uri, "event")
    end

    test "embeds connection params in the auth token" do
      conference_id = "conf-123"
      participant_id = 42

      assert {:ok, %{"switchboard_video_uri" => uri}} =
               conference_credentials("video",
                 conference_id: conference_id,
                 participant_id: participant_id
               )

      assert {:ok,
              %{
                "room_id" => room_id,
                "participant_id" => ^participant_id,
                "host" => "local",
                "stream_type" => "video",
                "custom_params" => %{
                  "connection_type" => "conference",
                  "stream_type" => "video"
                }
              }} = AuthTokenTestHelper.parse_and_decode_token_from_uri(uri)

      assert room_id == "conference/video/#{conference_id}"
    end

    test "returns error for invalid stream_type" do
      assert {:error, "stream_type_format_is_wrong"} =
               conference_credentials("smoke_signals")
    end

    test "raises when host is not a binary" do
      assert_raise FunctionClauseError, fn ->
        ConnectionCredentials.for(
          connection_type: "conference",
          stream_type: "video",
          conference_id: "conf-123",
          participant_id: 42,
          host: nil
        )
      end
    end
  end

  describe "for/1 with phone_call connection" do
    test "returns credentials for each stream type" do
      for stream_type <- ["video", "audio", "event"] do
        assert {:ok, credentials} = phone_call_credentials(stream_type: stream_type)

        uri_key = "switchboard_#{stream_type}_uri"
        cert_hash_key = "switchboard_#{stream_type}_server_cert_hash"

        assert %{^uri_key => uri, ^cert_hash_key => cert_hash} = credentials
        assert cert_hash == stream_server_cert_hash()
        assert_stream_uri(uri, stream_type)
      end
    end

    test "uses 'from' as participant_id for outcome direction" do
      from = 123

      assert {:ok, %{"switchboard_video_uri" => uri}} =
               phone_call_credentials(
                 stream_type: "video",
                 direction: "outcome",
                 from: from,
                 to: 456
               )

      assert {:ok, %{"participant_id" => ^from}} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(uri)
    end

    test "uses 'to' as participant_id for income direction" do
      to = 456

      assert {:ok, %{"switchboard_video_uri" => uri}} =
               phone_call_credentials(
                 stream_type: "video",
                 direction: "income",
                 from: 123,
                 to: to
               )

      assert {:ok, %{"participant_id" => ^to}} =
               AuthTokenTestHelper.parse_and_decode_token_from_uri(uri)
    end

    test "embeds call details in the auth token" do
      called_at = 1_700_000_000_000
      phone_call_id = "call-789"

      assert {:ok, %{"switchboard_audio_uri" => uri}} =
               phone_call_credentials(
                 stream_type: "audio",
                 direction: "income",
                 called_at: called_at,
                 phone_call_id: phone_call_id
               )

      assert {:ok,
              %{
                "room_id" => room_id,
                "participant_id" => 456,
                "host" => "local",
                "stream_type" => "audio",
                "custom_params" => %{
                  "connection_type" => "phone_call",
                  "stream_type" => "audio",
                  "from_host_id" => "local",
                  "from" => 123,
                  "to_host_id" => "remote",
                  "to" => 456,
                  "direction" => "income",
                  "called_at" => ^called_at,
                  "phone_call_id" => ^phone_call_id
                }
              }} = AuthTokenTestHelper.parse_and_decode_token_from_uri(uri)

      assert room_id == "phone_call/audio/#{called_at}/#{phone_call_id}"
    end
  end

  defp conference_credentials(stream_type, overrides \\ []) do
    opts = Map.new(overrides)

    ConnectionCredentials.for(
      connection_type: "conference",
      stream_type: stream_type,
      conference_id: Map.get(opts, :conference_id, "conf-123"),
      participant_id: Map.get(opts, :participant_id, 42),
      host: Map.get(opts, :host, "local")
    )
  end

  defp phone_call_credentials(overrides) do
    opts = Map.new(overrides)

    ConnectionCredentials.for(
      connection_type: "phone_call",
      stream_type: Map.get(opts, :stream_type, "video"),
      from_host_id: Map.get(opts, :from_host_id, "local"),
      from: Map.get(opts, :from, 123),
      to_host_id: Map.get(opts, :to_host_id, "remote"),
      to: Map.get(opts, :to, 456),
      phone_call_id: Map.get(opts, :phone_call_id, "call-789"),
      called_at: Map.get(opts, :called_at, 1_700_000_000_000),
      direction: Map.get(opts, :direction, "outcome"),
      host: Map.get(opts, :host, "local")
    )
  end

  defp assert_stream_uri(uri, stream_type) do
    %URI{scheme: scheme, host: host, port: port, path: path} = URI.parse(uri)
    config = Application.get_env(:video_conference, :stream_server)

    assert scheme == "https"
    assert host == Keyword.get(config, :host)
    assert port == Keyword.get(config, :port)
    assert path == "/#{stream_type}"
  end

  defp stream_server_cert_hash do
    Application.get_env(:video_conference, :stream_server)
    |> Keyword.get(:cert_hash)
  end
end
