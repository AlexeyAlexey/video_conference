defmodule VideoConference.TelephoneSwitchboard.AuthTokenTest do
  use VideoConferenceWeb.ConnCase

  alias VideoConference.TelephoneSwitchboard.AuthToken
  alias VideoConference.TelephoneSwitchboard.ConnectionCredentials

  test "generate token and verify_token" do
    assert {:ok, token} =
             AuthToken.generate_token(%{"from" => 1234})

    {:ok, public_key} = ConnectionCredentials.get_public_key_by_host("local")

    assert {:ok,
            %{
              "aud" => "Joken",
              "exp" => _,
              "from" => 1234,
              "iat" => _,
              "iss" => "Joken",
              "jti" => _,
              "nbf" => _
            }} =
             AuthToken.verify_token(token, public_key)
  end
end
