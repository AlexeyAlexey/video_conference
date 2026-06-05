defmodule VideoConferenceWeb.PhoneRegistrationController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.Accounts
  alias VideoConference.Accounts.Phone

  def register(conn, %{"invitation_token" => "1234321"} = params) do
    with {:ok, %Phone{} = phone} <- Accounts.register_phone(params) do
      session_token =
        Accounts.generate_session_token(phone)

      auth_token =
        VideoConference.AccountAuthToken.generate_and_sign!(%{
          "session_token" => session_token
        })

      render(conn, :register, auth_token: auth_token)
    end
  end
end
