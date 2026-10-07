defmodule VideoConference.TelephoneSwitchboard.PhoneCalls do
  @moduledoc """
  The Accounts context.
  """

  @directions ["outcome", "income"]

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.TelephoneSwitchboard.PhoneCalls.{PhoneCall, PhoneCallParticipant}
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  def call_to(attrs) do
    called_at = Map.get(attrs, :called_at, DateTime.utc_now())

    Repo.transaction(fn ->
      with {:ok, phone_call} <- insert_call(called_at),
           {:ok, _participants} <- insert_participants(phone_call, attrs) do
        phone_call
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  def list_participants(%PhoneCall{id: id, called_at: called_at}) do
    from(p in PhoneCallParticipant,
      where: p.phone_call_id == ^id and p.phone_call_called_at == ^called_at
    )
    |> Repo.all()
  end

  defp insert_call(called_at) do
    %PhoneCall{}
    |> PhoneCall.changeset(%{called_at: called_at})
    |> Repo.insert()
  end

  defp insert_participants(phone_call, attrs) do
    [
      %{
        host_id: Map.get(attrs, :from_host_id),
        phone: Map.get(attrs, :from),
        direction: "outcome"
      },
      %{
        host_id: Map.get(attrs, :to_host_id),
        phone: Map.get(attrs, :to),
        direction: "income"
      }
    ]
    |> Enum.reduce_while({:ok, []}, fn participant_attrs, {:ok, acc} ->
      case insert_participant(phone_call, participant_attrs) do
        {:ok, participant} -> {:cont, {:ok, [participant | acc]}}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp insert_participant(phone_call, attrs) do
    %PhoneCallParticipant{}
    |> PhoneCallParticipant.call_changeset(attrs, phone_call)
    |> Repo.insert()
  end

  def current_income_calls(to: to) when is_integer(to) do
    called_at =
      DateTime.utc_now() |> DateTime.shift(second: -30) |> DateTime.to_unix(:millisecond)

    from(callee in PhoneCallParticipant)
    |> join(:inner, [callee], caller in PhoneCallParticipant,
      on:
        caller.phone_call_id == callee.phone_call_id and
          caller.phone_call_called_at == callee.phone_call_called_at and
          caller.direction == "outcome"
    )
    |> where(
      [callee, caller],
      callee.direction == "income" and callee.phone == ^to and is_nil(callee.host_id) and
        callee.phone_call_called_at > ^called_at
    )
    |> group_by([callee, caller], [caller.host_id, caller.phone])
    |> select([callee, caller], %{from_host_id: caller.host_id, from: caller.phone})
    |> Repo.all()
  end

  def connection_credentials(
        from_host_id: "local",
        from: from,
        to_host_id: "local",
        to: to,
        direction: direction,
        stream_types: stream_types
      )
      when is_integer(from) and is_integer(to) and direction in @directions and
             is_list(stream_types) and
             direction in @directions do
    with :ok <- check_if_not_call_himself(from, to),
         {:ok, phone_call} <- fetch_or_create_call(direction, from, to) do
      connection_cred =
        Enum.reduce(stream_types, %{}, fn type, acc ->
          {:ok, cred} =
            ConnectionCredentials.for(
              connection_type: "phone_call",
              stream_type: type,
              from_host_id: "local",
              from: from,
              to_host_id: "local",
              to: to,
              phone_call_id: phone_call.id,
              called_at: unix_milli(phone_call.called_at),
              direction: direction,
              host: "local"
            )

          acc |> Map.merge(cred)
        end)

      {:ok, connection_cred}
    end
  end

  defp fetch_or_create_call("outcome", from, to) do
    call_to(%{
      from: from,
      to: to,
      called_at: DateTime.utc_now()
    })
  end

  defp fetch_or_create_call("income", from, to) do
    find_pending_income_call(from, to)
  end

  defp find_pending_income_call(from, to) do
    called_at =
      DateTime.utc_now() |> DateTime.shift(second: -30) |> DateTime.to_unix(:millisecond)

    from(c in PhoneCall)
    |> join(:inner, [c], callee in PhoneCallParticipant,
      on:
        callee.phone_call_id == c.id and callee.phone_call_called_at == c.called_at and
          callee.direction == "income"
    )
    |> join(:inner, [c, callee], caller in PhoneCallParticipant,
      on:
        caller.phone_call_id == callee.phone_call_id and
          caller.phone_call_called_at == callee.phone_call_called_at and
          caller.direction == "outcome"
    )
    |> where(
      [c, callee, caller],
      callee.phone == ^to and is_nil(callee.host_id) and caller.phone == ^from and
        callee.phone_call_called_at > ^called_at
    )
    |> order_by([c], desc: c.called_at)
    |> limit(1)
    |> Repo.one()
    |> case do
      nil -> {:error, "call_not_found"}
      phone_call -> {:ok, phone_call}
    end
  end

  defp unix_milli(%DateTime{} = called_at) do
    DateTime.to_unix(called_at, :millisecond)
  end

  defp unix_milli(called_at) when is_integer(called_at), do: called_at

  defp check_if_not_call_himself(from, to) when from == to do
    {:error, "You are trying to call yourself"}
  end

  defp check_if_not_call_himself(_from, _to), do: :ok
end
