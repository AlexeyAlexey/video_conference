defmodule StreamServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    options = Application.fetch_env!(:stream_server, :options)

    children = [
      # Starts a worker by calling: StreamServer.Worker.start_link(arg)
      # {StreamServer.Worker, arg}
      {Registry, name: AudioPhoneCallManager, keys: :unique},
      {Registry, name: VideoPhoneCallManager, keys: :unique},
      {Wtransport.Supervisor, options},
      PubSub,
      {DynamicSupervisor,
       strategy: :one_for_one, name: StreamServer.AudioPhoneCallManagerSupervisor},
      {DynamicSupervisor,
       strategy: :one_for_one, name: StreamServer.VideoPhoneCallManagerSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StreamServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
