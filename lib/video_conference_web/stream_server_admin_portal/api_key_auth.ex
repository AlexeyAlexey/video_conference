defmodule VideoConferenceWeb.StreamServerAdminPortal.ApiKeyAuth do
  @moduledoc """
  Authenticates requests to the stream server admin portal API by the
  `X-API-Key` header.

  The presented secret has the form
  `env_prefix <> "_" <> prefix_id <> "_" <> random`. The `env_prefix`
  selects the credential table (`"ssak"` for stream server API keys,
  `"aak"` for application API keys), the credential is looked up by its
  stored `env_prefix <> "_" <> prefix_id` `prefix`, the secret is
  verified against the stored bcrypt hash, and the credential must be
  enabled. On success the credential is assigned as
  `conn.assigns.api_credential` in the shape `{:stream_server, key}` or
  `{:application, key}`; every failure halts the connection with a 401
  JSON response.
  """

  @behaviour Plug

  import Plug.Conn

  alias VideoConference.StreamServerAdminPortal.ApiKeySecret
  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_req_header(conn, "x-api-key") do
      [secret] -> authenticate(conn, secret)
      _ -> unauthorized(conn)
    end
  end

  defp authenticate(conn, secret) do
    with {:ok, env_prefix, prefix} <- parse_secret(secret),
         {:ok, credential} <- fetch_credential(env_prefix, prefix),
         true <- credential.enabled,
         true <- ApiKeySecret.verify(secret, credential.hashed_api_key) do
      assign(conn, :api_credential, credential_assign(env_prefix, credential))
    else
      _ -> unauthorized(conn)
    end
  end

  defp parse_secret(secret) do
    case String.split(secret, "_", parts: 3) do
      [env_prefix, prefix_id, random] when env_prefix != "" and random != "" ->
        case Ecto.UUID.cast(prefix_id) do
          {:ok, _} -> {:ok, env_prefix, env_prefix <> "_" <> prefix_id}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp fetch_credential(env_prefix, prefix) do
    lookup =
      case env_prefix do
        "ssak" -> fn -> StreamServers.get_stream_server_api_key_by_prefix(prefix) end
        "aak" -> fn -> Applications.get_api_key_by_prefix(prefix, :application_enabled) end
        _other -> fn -> {:error, :not_found} end
      end

    case lookup.() do
      {:ok, credential} ->
        {:ok, credential}

      {:error, :not_found} ->
        # Keep a prefix miss as expensive as a hit so valid
        # `env_prefix <> "_" <> prefix_id` prefixes cannot be enumerated
        # by response timing.
        Bcrypt.no_user_verify()
        :error
    end
  end

  defp credential_assign("ssak", key), do: {:stream_server, key}
  defp credential_assign("aak", key), do: {:application, key}

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{errors: %{detail: "Unauthorized"}}))
    |> halt()
  end
end
