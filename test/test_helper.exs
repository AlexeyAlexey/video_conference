Code.require_file("support/fixtures/known_hosts_fixtures.exs", __DIR__)
Code.require_file("support/fixtures/stream_servers_fixtures.exs", __DIR__)
Code.require_file("support/fixtures/public_stream_server_keys_fixtures.exs", __DIR__)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(VideoConference.Repo, :manual)
