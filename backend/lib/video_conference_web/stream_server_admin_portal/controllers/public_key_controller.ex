defmodule VideoConferenceWeb.StreamServerAdminPortal.PublicKeyController do
  @moduledoc """
  Serves application public key material to remote stream servers.

  Reached at `GET /stream-server-admin/api/stream-server/public-key` —
  the main router forwards `"/stream-server-admin"` to the portal
  router, which pipes this route through `:api` and `ApiKeyAuth`, so
  `conn.assigns.api_credential` is already set on arrival.
  """
  use VideoConferenceWeb, :controller

  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.StreamServers

  @doc """
  Returns the stored public key material for `public_key_id` belonging
  to `application_id`.

  Only `ssak_` credentials may call this endpoint; the authenticated
  stream server must be assigned to the application, and both the
  application and the key must be enabled.
  """
  def show(conn, params) do
    with {:ok, api_key} <- stream_server_credential(conn.assigns[:api_credential]),
         {:ok, application_id, public_key_id} <- validate_params(params),
         :ok <- ensure_application(application_id),
         :ok <- authorize(api_key.stream_server_id, application_id),
         {:ok, key} <- fetch_key(application_id, public_key_id) do
      json(conn, %{
        application_id: application_id,
        public_key_id: public_key_id,
        key: key.key
      })
    else
      {:error, status} -> error(conn, status)
    end
  end

  defp stream_server_credential({:stream_server, api_key}), do: {:ok, api_key}
  defp stream_server_credential(_credential), do: {:error, :unauthorized}

  defp validate_params(%{"application_id" => application_id, "public_key_id" => public_key_id}) do
    with {:ok, application_id} <- Ecto.UUID.cast(application_id),
         {:ok, public_key_id} <- Ecto.UUID.cast(public_key_id) do
      {:ok, application_id, public_key_id}
    else
      :error -> {:error, :bad_request}
    end
  end

  defp validate_params(_params), do: {:error, :bad_request}

  defp ensure_application(application_id) do
    if Applications.enabled_application?(application_id) do
      :ok
    else
      {:error, :not_found}
    end
  end

  defp authorize(stream_server_id, application_id) do
    if StreamServers.assigned_to_application?(stream_server_id, application_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end

  defp fetch_key(application_id, public_key_id) do
    Applications.get_enabled_stream_server_public_key(application_id, public_key_id)
  end

  defp error(conn, status) do
    code = Plug.Conn.Status.code(status)

    conn
    |> put_status(code)
    |> json(%{errors: %{detail: Plug.Conn.Status.reason_phrase(code)}})
  end
end
