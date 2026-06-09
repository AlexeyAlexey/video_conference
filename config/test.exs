import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
# config :video_conference, VideoConference.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "video_conference_test#{System.get_env("MIX_TEST_PARTITION")}",
#   pool: Ecto.Adapters.SQL.Sandbox,
#   pool_size: System.schedulers_online() * 2

# config :video_conference,
#   ecto_repos: [VideoConference.Repo],
#   database: "/home/alexey/Documents/elixir/video_conference/test.db"

# config :video_conference, VideoConference.Repo, database: ":memory:", pool_size: 1

config :video_conference, VideoConference.Repo,
  database: "/home/alexey/Documents/elixir/video_conference_db/test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 1

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :video_conference, VideoConferenceWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "eMYz+y/9D8QJz4uA+fGWE62mFS/YGEXTxNAK7Kf3kF73yD6Ruzk1Zr6RjbsHg/Jn",
  server: false

# In test we don't send emails
config :video_conference, VideoConference.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :joken, default_signer: System.get_env("JWT_SECRET")

config :video_conference, :telephone_switchboard,
  private_key: System.get_env("TELEPHONE_SWITCHBOARD_PRIVET_KEY")
