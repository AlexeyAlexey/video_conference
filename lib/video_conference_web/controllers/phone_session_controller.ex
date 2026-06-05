defmodule VideoConferenceWeb.PhoneSessionController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.Accounts

  # TODO Refresh token

  def log_in(conn, %{"phone" => phone, "password" => password}) do
    if phone = Accounts.get_by_phone_and_password(phone, password) do
      session_token =
        Accounts.generate_session_token(phone)

      auth_token =
        VideoConference.AccountAuthToken.generate_and_sign!(%{
          "session_token" => session_token
        })

      render(conn, :auth_token, auth_token: auth_token)
    else
      {:error, "Invalid phone or password"}
    end
  end

  def log_out(conn, _params) do
    :ok = Accounts.log_out(session_token: conn.assigns.current_session_token)

    # Elixir.VideoConferenceWeb.Endpoint.broadcast("phone_socket:#{conn.assigns.current_scope.phone}", "disconnect", %{})

    conn
    |> put_status(204)
    |> json(nil)
  end
end
