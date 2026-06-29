defmodule Utils.SharedLink do
  use Phoenix.VerifiedRoutes,
    endpoint: VideoConferenceWeb.Endpoint,
    router: VideoConferenceWeb.Router

  def url_for(link_id: link_id) do
    url(~p"/conference/shared_link/#{link_id}")
  end
end
