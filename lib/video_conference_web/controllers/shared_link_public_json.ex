defmodule VideoConferenceWeb.SharedLinkPublicJSON do
  def shared_link(%{
        shared_link: %{password_required: password_required, link_id: link_id}
      }) do
    %{
      password_required: password_required,
      link: Utils.SharedLink.url_for(link_id: link_id),
      link_id: link_id
    }
  end
end
