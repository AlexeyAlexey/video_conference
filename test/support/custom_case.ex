defmodule VideoConference.CustomCase do
  use ExUnit.Case

  alias VideoConference.Accounts.Phone
  alias VideoConference.Accounts

  def verify_and_validate_account_auth_token(auth_token) do
    VideoConference.AccountAuthToken.verify_and_validate(auth_token)
  end

  def verify_session_phone_token(phone, session_token) do
    {:ok, session_token} = Base.url_decode64(session_token, padding: false)

    {:ok, {%Phone{phone: token_phone}, _token_inserted_at}} =
      Accounts.get_by_session_token(session_token)

    assert phone == token_phone
  end

  def invitation_token do
    "1234321"
  end

  def valid_auth_token(%Phone{} = phone) do
    session_token =
      Accounts.generate_session_token(phone)

    VideoConference.AccountAuthToken.generate_and_sign!(%{
      "session_token" => session_token
    })
  end

  def generate_password do
    "12fdsnnjs3fsdfn"
  end

  def log_in(conn, %Phone{} = phone) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer " <> valid_auth_token(phone))
  end
end
