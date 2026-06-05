defmodule VideoConference.TelephoneSwitchboard.OneToOneCallAuthToken do
  alias VideoConference.TelephoneSwitchboard.AuthToken

  def generate(from: from, to: to, direction: direction)
      when is_integer(from) and is_integer(to) do
    AuthToken.generate_and_sign!(%{
      "type" => "phone_call",
      "direction" => direction,
      "from" => from,
      "to" => to
    })
  end
end
