defmodule VideoConference.TelephoneSwitchboard.PhoneCalls do
  @moduledoc """
  The Accounts context.
  """

  @directions ["outcome", "income"]

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.TelephoneSwitchboard.PhoneCalls.{PhoneCall}
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  def call_to(attrs) do
    %PhoneCall{}
    |> PhoneCall.call_changeset(attrs)
    |> Repo.insert()
  end

  def current_income_calls(to: to) when is_integer(to) do
    called_at = DateTime.utc_now() |> DateTime.shift(second: -30) |> DateTime.to_unix()

    from(c in PhoneCall)
    |> where([c], is_nil(c.to_host_id) and c.to == ^to)
    |> where(
      [c],
      c.called_at > ^called_at and is_nil(c.ended_at) and
        is_nil(c.responded_at)
    )
    |> group_by([c], [c.from_host_id, c.from])
    |> select([c], %{from_host_id: c.from_host_id, from: c.from})
    |> Repo.all()
  end

  def connection_credentials(
        from_host_id: "local",
        from: from,
        to_host_id: "local",
        to: to,
        direction: direction,
        stream_type: stream_type
      )
      when is_integer(from) and is_integer(to) and direction in @directions and
             is_list(stream_type) and
             direction in @directions do
    with :ok <- check_if_not_call_himself(from, to) do
      params = %{
        "from" => "local@#{from}",
        "to" => "local@#{to}",
        "direction" => direction,
        "host" => "local"
      }

      # host ("host" => "local") is used by stream server (http3 server) to find public key to validate tokens
      connection_options =
        if "audio" in stream_type do
          ConnectionCredentials.for(
            "audio",
            "phone_call",
            params
          )
        else
          %{}
        end

      connection_options =
        if "video" in stream_type do
          connection_options
          |> Map.merge(
            ConnectionCredentials.for(
              "video",
              "phone_call",
              params
            )
          )
        else
          connection_options
        end

      {:ok, _} =
        call_to(%{
          from: from,
          to: to,
          called_at: DateTime.utc_now()
        })

      {:ok, connection_options}
    end
  end

  defp check_if_not_call_himself(from, to) when from == to do
    {:error, "You are trying to call yourself"}
  end

  defp check_if_not_call_himself(_from, _to), do: :ok
end
