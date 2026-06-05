defmodule VideoConferenceWeb.PhoneRegistrationJSON do
  def register(%{auth_token: auth_token}) do
    %{auth_token: auth_token}
  end
end
