defmodule VideoConference.StreamServerAdminPortal.Repo do
  use Ecto.Repo,
    otp_app: :video_conference,
    adapter: Ecto.Adapters.SQLite3
end
