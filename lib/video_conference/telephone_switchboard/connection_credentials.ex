defmodule VideoConference.TelephoneSwitchboard.ConnectionCredentials do
  alias VideoConference.TelephoneSwitchboard.HostPublicKey
  alias VideoConference.TelephoneSwitchboard.AuthToken

  def get_public_key_by_host(host) when is_binary(host) do
    HostPublicKey.fetch(host)
  end

  def for("video", "conference" = type, token_params)
      when is_map(token_params) do
    token_params =
      token_params
      |> Map.put("type", type)

    %{
      "switchboard_video_uri" => video_uri(token_params),
      "switchboard_video_server_cert_hash" => System.fetch_env!("HTTP3_SERVER_CERT_HASH")
    }
  end

  def for("audio", "conference" = type, token_params)
      when is_map(token_params) do
    token_params =
      token_params
      |> Map.put("type", type)

    %{
      "switchboard_audio_uri" => audio_uri(token_params),
      "switchboard_audio_server_cert_hash" => System.fetch_env!("HTTP3_SERVER_CERT_HASH")
    }
  end

  def for("video", "phone_call" = type, token_params)
      when is_map(token_params) do
    token_params =
      token_params
      |> Map.put("type", type)

    %{
      "switchboard_video_uri" => video_uri(token_params),
      "switchboard_video_server_cert_hash" => System.fetch_env!("HTTP3_SERVER_CERT_HASH")
    }
  end

  def for("audio", "phone_call" = type, token_params)
      when is_map(token_params) do
    token_params =
      token_params
      |> Map.put("type", type)

    %{
      "switchboard_audio_uri" => audio_uri(token_params),
      "switchboard_audio_server_cert_hash" => System.fetch_env!("HTTP3_SERVER_CERT_HASH")
    }
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
end
