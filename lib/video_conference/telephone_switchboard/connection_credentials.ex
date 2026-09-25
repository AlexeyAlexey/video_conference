# TODO add tests
defmodule VideoConference.TelephoneSwitchboard.ConnectionCredentials do
  @stream_type ["video", "audio"]

  alias VideoConference.TelephoneSwitchboard.HostPublicKey
  alias VideoConference.TelephoneSwitchboard.AuthToken

  def get_public_key_by_host(host) when is_binary(host) do
    HostPublicKey.fetch(host)
  end

  def for(
        connection_type: "conference" = connection_type,
        stream_type: stream_type,
        conference_id: conference_id,
        participant_id: participant_id,
        host: host
      )
      when stream_type in @stream_type and is_binary(host) do
    token_params = %{
      room_id: "#{connection_type}/#{stream_type}/#{conference_id}",
      participant_id: participant_id,
      host: host,
      custom_params: %{
        "connection_type" => connection_type,
        "stream_type" => stream_type
      }
    }

    if stream_type == "video" do
      {:ok,
       %{
         "switchboard_video_uri" => video_uri(token_params),
         "switchboard_video_server_cert_hash" => stream_server_hash()
       }}
    else
      {:ok,
       %{
         "switchboard_audio_uri" => audio_uri(token_params),
         "switchboard_audio_server_cert_hash" => stream_server_hash()
       }}
    end
  end

  def for(
        connection_type: "phone_call" = connection_type,
        stream_type: stream_type,
        from_host_id: from_host_id,
        from: from,
        to_host_id: to_host_id,
        to: to,
        direction: direction,
        host: host
      )
      when stream_type in @stream_type and is_binary(host) do
    participant_id = if direction == "outcome", do: from, else: to

    token_params = %{
      room_id: "#{connection_type}/#{stream_type}/#{from}/#{to}",
      participant_id: participant_id,
      host: host,
      custom_params: %{
        "connection_type" => connection_type,
        "stream_type" => stream_type,
        "from_host_id" => from_host_id,
        "from" => from,
        "to_host_id" => to_host_id,
        "to" => to,
        "direction" => direction
      }
    }

    if stream_type == "video" do
      {:ok,
       %{
         "switchboard_video_uri" => video_uri(token_params),
         "switchboard_video_server_cert_hash" => stream_server_hash()
       }}
    else
      {:ok,
       %{
         "switchboard_audio_uri" => audio_uri(token_params),
         "switchboard_audio_server_cert_hash" => stream_server_hash()
       }}
    end
  end

  def for(
        connection_type: _connection_type,
        stream_type: stream_type,
        conference_id: _conference_id,
        participant_id: _participant_id,
        host: _host
      )
      when stream_type not in @stream_type do
    {:error, "stream_type_format_is_wrong"}
  end

  defp switchboard_auth_token(params) when is_map(params) do
    {:ok, auth_token} = AuthToken.generate_token(params)
    auth_token
  end

  defp video_uri(token_params) do
    "#{uri()}/video?auth_token=#{switchboard_auth_token(token_params)}"
  end

  defp audio_uri(token_params) do
    "#{uri()}/audio?auth_token=#{switchboard_auth_token(token_params)}"
  end

  defp uri, do: "https://#{host()}:#{port()}"

  defp host, do: Application.get_env(:video_conference, :stream_server) |> Keyword.get(:host)
  defp port, do: Application.get_env(:video_conference, :stream_server) |> Keyword.get(:port)

  defp stream_server_hash,
    do:
      Application.get_env(:video_conference, :stream_server)
      |> Keyword.get(:cert_hash)
end
