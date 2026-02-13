defmodule VideoConference.Repo do
  use Ecto.Repo,
    otp_app: :video_conference,
    adapter: Ecto.Adapters.Postgres
end
