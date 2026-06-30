defmodule VideoConferenceWeb.SharedLinkPublicController do
  use VideoConferenceWeb, :controller

  action_fallback VideoConferenceWeb.FallbackController

  alias VideoConference.SharedLinks

  def info(conn, %{"link_id" => link_id}) do
    SharedLinks.one_by(conn.assigns.current_scope, link_id: link_id)
    |> case do
      {:ok, shared_link} ->
        render(conn, :shared_link, shared_link: shared_link)

      error ->
        error
    end
  end
end
