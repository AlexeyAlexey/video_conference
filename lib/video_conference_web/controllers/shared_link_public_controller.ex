defmodule VideoConferenceWeb.SharedLinkPublicController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.TelephoneSwitchboard

  def info(conn, %{"link_id" => link_id}) do
    TelephoneSwitchboard.shared_link_by(link_id: link_id)
    |> case do
      {:ok, shared_link} ->
        render(conn, :shared_link, shared_link: shared_link)

      error ->
        error
    end
  end

  def conference_credentials(conn, %{"link_id" => link_id, "password" => password}) do
    TelephoneSwitchboard.connection_credentials(
      shared_link_id: link_id,
      password: password
    )
    |> case do
      {:ok, credentials} ->
        render(conn, :conference_credentials, credentials: credentials)

      error ->
        error
    end
  end

  def conference_credentials(conn, %{"link_id" => link_id}) do
    TelephoneSwitchboard.connection_credentials(shared_link_id: link_id)
    |> case do
      {:ok, credentials} ->
        render(conn, :conference_credentials, credentials: credentials)

      error ->
        error
    end
  end
end
