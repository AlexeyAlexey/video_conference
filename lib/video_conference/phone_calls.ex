defmodule VideoConference.PhoneCalls do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.PhoneCalls.{PhoneCall}

  def call_to(attrs) do
    %PhoneCall{}
    |> PhoneCall.call_changeset(attrs)
    |> Repo.insert()
  end

  def get_current_income_calls(to: to) do
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
end
