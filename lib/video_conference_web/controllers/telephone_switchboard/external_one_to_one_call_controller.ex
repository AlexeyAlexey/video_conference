defmodule VideoConferenceWeb.TelephoneSwitchboard.ExternalOneToOneCallController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  # alias VideoConference.Accounts
  # alias VideoConference.Accounts.Phone

  # TODO The idea is that calls can be from different hosts
  # You can add phones from different hosts to phones list and start receiving calls or call them
  # Every hosts share their public key to validate switchboard_auth_token
  # This token can be used to connect to a caller stream server to have a call
  # We can broadcast income_call event

  # def call(conn, %{"switchboard_auth_token" => token}) do
  # end
end
