defmodule VideoConferenceWeb.StreamServerAdminPortal.Applications.ConnectionInfoController do
  @moduledoc """
  Resolves an application's requested country codes to stream server
  connection info.

  Reached at `GET /stream-server-admin/api/application/connection-info` —
  the main router forwards `"/stream-server-admin"` to the portal
  router, which pipes this route through `:api` and `ApiKeyAuth`, so
  `conn.assigns.api_credential` is already set on arrival.
  """
  use VideoConferenceWeb, :controller

  alias VideoConference.StreamServerAdminPortal.Applications

  @max_country_codes 4
  @country_code_pattern ~r/^[a-z]{2}$/i

  @doc """
  Returns connection info for each requested country code.

  Only `aak_` credentials may call this endpoint; the authenticated
  credential identifies the application, which must be enabled.

  ## Params

    * `country_codes` — required list of ISO alpha-2 country codes
      (`1..4` distinct codes), sent as repeated params
      (`country_codes=us&country_codes=gb`) or brackets
      (`country_codes[]=us`). Case-insensitive (`"US"` resolves as
      `"us"`); duplicates are allowed and produce duplicate entries.

  ## Response

  `200` — a JSON array with one `%{country_code, url, cert_hash?}`
  entry per requested code, in request order.

  `422` — `%{errors: %{detail, country_codes}}` naming the codes with
  no assigned server. `400` malformed params, `401` wrong credential
  type; a credential on a disabled application is rejected by
  `ApiKeyAuth` with 401 before this endpoint runs.
  """
  def show(conn, params) do
    with {:ok, application} <-
           Applications.authenticated_application(conn.assigns[:api_credential]),
         {:ok, country_codes} <- validate_params(params),
         {:ok, connection_info} <-
           Applications.connection_info(
             application_id: application.id,
             country_codes: country_codes
           ) do
      json(conn, connection_info)
    else
      {:error, :unprocessable_entity, codes} -> unavailable(conn, codes)
      {:error, status} -> error(conn, status)
    end
  end

  @doc """
  Returns the country codes the application has assigned servers for.

  Only `aak_` credentials may call this endpoint; the authenticated
  credential identifies the application, which must be enabled.

  ## Response

  `200` — a JSON array of the ISO alpha-2 `country` codes of the
  application's assigned stream servers, deduplicated, sorted
  alphabetically, and excluding servers without a country. `[]` when
  the application has no qualifying assignments. `401` wrong
  credential type; a credential on a disabled application is rejected
  by `ApiKeyAuth` with 401 before this endpoint runs.
  """
  def available_countries(conn, _params) do
    case Applications.authenticated_application(conn.assigns[:api_credential]) do
      {:ok, application} ->
        json(conn, Applications.available_countries(application_id: application.id))

      {:error, status} ->
        error(conn, status)
    end
  end

  defp validate_params(%{"country_codes" => codes}) when is_list(codes) do
    if codes != [] and length(Enum.uniq(codes)) <= @max_country_codes and
         Enum.all?(codes, &valid_code?/1) do
      {:ok, codes}
    else
      {:error, :bad_request}
    end
  end

  defp validate_params(_params), do: {:error, :bad_request}

  defp valid_code?(code) when is_binary(code),
    do: Regex.match?(@country_code_pattern, code)

  defp valid_code?(_code), do: false

  defp unavailable(conn, codes) do
    conn
    |> put_status(422)
    |> json(%{errors: %{detail: "No stream server available", country_codes: codes}})
  end

  defp error(conn, status) do
    code = Plug.Conn.Status.code(status)

    conn
    |> put_status(code)
    |> json(%{errors: %{detail: Plug.Conn.Status.reason_phrase(code)}})
  end
end
