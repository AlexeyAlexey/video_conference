Code.require_file("support/fixtures/known_hosts_fixtures.exs", __DIR__)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(VideoConference.Repo, :manual)
