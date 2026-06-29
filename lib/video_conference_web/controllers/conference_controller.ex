defmodule VideoConferenceWeb.ConferenceController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  def generate(conn, %{"link_id" => _link_id, "password" => _password}) do
    # TODO return credentials to connect to http3 server
    conn
    |> put_status(204)
    |> json(nil)
  end
end
