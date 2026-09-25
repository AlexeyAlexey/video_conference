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
      connection_cred =
        Enum.reduce(stream_type, %{}, fn type, acc ->
          {:ok, cred} =
            ConnectionCredentials.for(
              connection_type: "phone_call",
              stream_type: type,
              from_host_id: "local",
              from: from,
              to_host_id: "local",
              to: to,
              direction: direction,
              host: "local"
            )

          acc |> Map.merge(cred)
        end)

      {:ok, _} =
        call_to(%{
          from: from,
          to: to,
          called_at: DateTime.utc_now()
        })

      {:ok, connection_cred}
    end
  end

  defp check_if_not_call_himself(from, to) when from == to do
    {:error, "You are trying to call yourself"}
  end

  defp check_if_not_call_himself(_from, _to), do: :ok
end
