defmodule VideoConference.PhoneCallsTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.PhoneCallFixtures

  alias VideoConference.PhoneCalls

  test "get_current_income_calls" do
    to_host = "local"
    to = 123

    create_phone_call(%{
      from_host: "local",
      from: 432,
      to_host: to_host,
      to: to,
      called_at: DateTime.utc_now()
    })

    create_phone_call(%{
      from_host: "local",
      from: 4567,
      to_host: to_host,
      to: to,
      called_at: ~U[2026-06-01 08:08:25.747857Z]
    })

    assert PhoneCalls.get_current_income_calls(to_host: to_host, to: to) == [
             %{from: 432, from_host: "local"}
           ]
  end
end
