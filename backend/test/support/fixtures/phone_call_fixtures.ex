defmodule VideoConference.TelephoneSwitchboard.PhoneCallFixtures do
  # import Ecto.Query
  alias VideoConference.TelephoneSwitchboard.PhoneCalls

  def create_phone_call(attrs) when is_map(attrs) do
    {:ok, phone_call} =
      attrs
      |> Map.take([:from, :from_host_id, :to, :to_host_id, :called_at])
      |> PhoneCalls.call_to()

    phone_call
  end
end
