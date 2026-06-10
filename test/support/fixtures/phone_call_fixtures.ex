defmodule VideoConference.PhoneCallFixtures do
  # import Ecto.Query
  alias VideoConference.Repo

  alias VideoConference.PhoneCalls.PhoneCall

  def create_phone_call(attrs) when is_map(attrs) do
    {:ok, phone_call} =
      %PhoneCall{}
      |> PhoneCall.changeset(attrs)
      |> Repo.insert()

    phone_call
  end
end
