defmodule VideoConference.TelephoneSwitchboard.AuthTokenTestHelper do
  alias VideoConference.TelephoneSwitchboard.AuthToken
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  def parse_and_decode_token_from_uri(uri, host \\ "local")

  def parse_and_decode_token_from_uri(uri, host) when is_binary(uri) do
    with {:ok, auth_token} <- extract_token_from(uri: uri),
         {:ok, parsed_token} <- parse_token(auth_token, host) do
      {:ok, parsed_token}
    end
  end

  def parse_and_decode_token_from_uri(_uri, _host), do: {:error, "uri must be binary"}

  def parse_token(token, host \\ "local") do
    with {:ok, public_key} <- ConnectionCredentials.get_public_key_by_host(host),
         {:ok, parsed_token} <-
           AuthToken.verify_token(token, public_key) do
      {:ok, parsed_token}
    end
  end

  def extract_token_from(uri: uri) do
    uri = URI.parse(uri)

    URI.decode_query(uri.query || "")
    |> Map.fetch("auth_token")
    |> case do
      {:ok, auth_token} ->
        {:ok, auth_token}

      :error ->
        {:error, "auth token cannot be extracted from uri"}
    end
  end
end
