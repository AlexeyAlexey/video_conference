defmodule VideoConference.TelephoneSwitchboard.PhoneCallsTest do
  use VideoConferenceWeb.ConnCase

  import VideoConference.TelephoneSwitchboard.PhoneCallFixtures

  alias VideoConference.TelephoneSwitchboard.PhoneCalls

  test "current_income_calls" do
    to = 123

    create_phone_call(%{
      from: 432,
      to: to,
      called_at: DateTime.utc_now()
    })

    create_phone_call(%{
      from: 4567,
      to: to,
      called_at: ~U[2026-06-01 08:08:25.747857Z]
    })

    assert PhoneCalls.current_income_calls(to: to) == [
             %{from: 432, from_host_id: nil}
           ]
  end
end
