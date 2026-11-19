defmodule VideoConference.StreamServerAdminPortal.Applications.ConnectionInfo do
  @moduledoc """
  Resolves an application's stream server connection info — the `url`
  (`"https://" <> host`) and `cert_hash` (when stored) of the
  least-loaded stream server assigned to the application per country,
  via `Applications.stream_servers/1`.
  """

  alias VideoConference.StreamServerAdminPortal.Applications

  @doc """
  Resolves `country_codes` — a list of ISO alpha-2 codes,
  case-insensitive and duplicates allowed — to a list of
  `%{country_code:, url:, cert_hash?:}` entries, one per requested
  code in request order (duplicates preserved). Codes are normalized
  to the stored lowercase format, so `"US"` resolves as `"us"`.

  Returns `{:error, :unprocessable_entity, codes}` naming the unique
  normalized codes whose country has no assigned server.
  """
  def execute(application_id: application_id, country_codes: country_codes)
      when is_list(country_codes) do
    country_codes = Enum.map(country_codes, &String.downcase/1)
    codes = Enum.uniq(country_codes)

    groups =
      Applications.stream_servers(
        application_id: application_id,
        country_codes: codes,
        min_loaded: true
      )

    unsatisfiable = for code <- codes, not Map.has_key?(groups, code), do: code

    if unsatisfiable == [] do
      {:ok, Enum.map(country_codes, &connection_info(&1, groups[&1]))}
    else
      {:error, :unprocessable_entity, unsatisfiable}
    end
  end

  defp connection_info(code, server) do
    %{country_code: code, url: "https://" <> server.host}
    |> maybe_put_cert_hash(server.cert_hash)
  end

  defp maybe_put_cert_hash(info, cert_hash) when cert_hash in [nil, ""], do: info
  defp maybe_put_cert_hash(info, cert_hash), do: Map.put(info, :cert_hash, cert_hash)
end
