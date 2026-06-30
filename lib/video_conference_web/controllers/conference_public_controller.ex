defmodule VideoConferenceWeb.ConferencePublicController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  # alias VideoConference.TelephoneSwitchboard

  def shared_link(conn, %{"link_id" => _link_id, "password" => _password}) do
    # TelephoneSwitchboard.connection_credentials(
    #   shared_link_id: link_id,
    #   password: password,
    #   stream_type: "audio:video"
    # )

    # TODO return credentials to connect to http3 server
    conn
    |> put_status(204)
    |> json(nil)
  end

  def shared_link(conn, %{"link_id" => _link_id}) do
    # TODO return credentials to connect to http3 server
    conn
    |> put_status(204)
    |> json(nil)
  end
end
