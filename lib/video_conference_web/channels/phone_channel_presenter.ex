defmodule VideoConferenceWeb.PhoneChannelPresenter do
  def list_of_phones(list_of_phones) when is_list(list_of_phones) do
    list_of_phones |> Enum.map(&%{"phone" => &1.phone, "name" => &1.phone, "host" => "local"})
  end

  def current_income_calls(current_income_calls) when is_list(current_income_calls) do
    current_income_calls
    |> Enum.map(&%{"from_host" => &1.from_host, "from" => &1.from})
  end
end
