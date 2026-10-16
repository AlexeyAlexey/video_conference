defmodule VideoConferenceWeb.SharedLinkPublicJSON do
  def shared_link(%{
        shared_link: %{password_required: password_required, link_id: link_id}
      }) do
    %{
      password_required: password_required,
      link_id: link_id
    }
  end

  def conference_credentials(%{
        credentials: credentials
      }) do
    %{
      "stream_server_video_uri" => credentials["switchboard_video_uri"],
      "stream_server_video_server_cert_hash" => credentials["switchboard_video_server_cert_hash"],
      "stream_server_audio_uri" => credentials["switchboard_audio_uri"],
      "stream_server_audio_server_cert_hash" => credentials["switchboard_audio_server_cert_hash"],
      "stream_server_event_uri" => credentials["switchboard_event_uri"],
      "stream_server_event_server_cert_hash" => credentials["switchboard_event_server_cert_hash"],
      "participant_id" => credentials["participant_id"]
    }
  end
end
