defmodule VideoConferenceWeb.PhoneChannelPresenter do
  def list_of_phones(list_of_phones) when is_list(list_of_phones) do
    list_of_phones |> Enum.map(&%{"phone" => &1.phone, "name" => &1.phone, "host" => "local"})
  end
end
