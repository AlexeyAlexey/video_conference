defmodule VideoConferenceWeb.PhoneSessionJSON do
  def auth_token(%{auth_token: auth_token}) do
    %{auth_token: auth_token}
  end
end
