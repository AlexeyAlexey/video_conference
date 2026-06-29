defmodule VideoConferenceWeb.SharedLinkJSON do
  def shared_link(%{
        shared_link: shared_link
      }) do
    shared_link_template(shared_link)
  end

  def shared_links(%{
        shared_links: shared_links
      }) do
    shared_links |> Enum.map(&shared_link_template/1)
  end

  def enable_password(%{
        shared_link: %{id: id, password_required: password_required}
      }) do
    %{
      id: id,
      password_required: password_required
    }
  end

  def disable_password(%{
        shared_link: %{id: id, password_required: password_required}
      }) do
    %{
      id: id,
      password_required: password_required
    }
  end

  defp shared_link_template(%{
         id: id,
         name: name,
         link_id: link_id,
         password_required: password_required
       }) do
    %{
      id: id,
      name: name,
      link: Utils.SharedLink.url_for(link_id: link_id),
      password_required: password_required
    }
  end
end
