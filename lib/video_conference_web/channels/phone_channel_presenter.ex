defmodule VideoConferenceWeb.PhoneChannelPresenter do
  def list_of_phones(list_of_phones) when is_list(list_of_phones) do
    list_of_phones |> Enum.map(&%{"phone" => &1.phone, "name" => &1.phone, "host_id" => nil})
  end

  def current_income_calls(current_income_calls) when is_list(current_income_calls) do
    current_income_calls
    |> Enum.map(&%{"from_host_id" => &1.from_host_id, "from" => &1.from})
  end
end
