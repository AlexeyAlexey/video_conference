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

  def conference_credentials(%{
        credentials: credentials
      }) do
    %{
      "switchboard_video_uri" => credentials["switchboard_video_uri"],
      "switchboard_video_server_cert_hash" => credentials["switchboard_video_server_cert_hash"],
      "switchboard_audio_uri" => credentials["switchboard_audio_uri"],
      "switchboard_audio_server_cert_hash" => credentials["switchboard_audio_server_cert_hash"]
    }
  end
end
