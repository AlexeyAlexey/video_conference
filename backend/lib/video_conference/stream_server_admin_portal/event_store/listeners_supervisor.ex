defmodule VideoConference.StreamServerAdminPortal.EventStore.ListenersSupervisor do
  @moduledoc """
  `DynamicSupervisor` holding one `EventStore.ListenerRunner` per
  configured listener module.

  Runners are `:temporary` children: a runner that exhausts its retry
  budget marks its row `failed` and halts — and must *stay* down until
  `EventStore.resume_listener/1` starts it again.
  """
  use DynamicSupervisor

  alias VideoConference.StreamServerAdminPortal.EventStore.ListenerRunner

  def start_link(init_arg \\ []) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a runner for every listener module named in the
  `:event_listeners` option of
  `config :video_conference, :stream_server_admin_portal`.

  Listeners whose persisted `event_listeners` status is `"failed"`
  refuse to start (their runner returns `:ignore`).
  """
  def start_configured_listeners do
    for module <- configured_listeners() do
      DynamicSupervisor.start_child(__MODULE__, {ListenerRunner, module})
    end
  end

  @doc """
  Returns the listener module from the `:event_listeners` option of
  `config :video_conference, :stream_server_admin_portal` whose
  declared `name` matches, or `nil`.
  """
  def configured_listener(name) do
    Enum.find(configured_listeners(), fn module ->
      module.__listener__().name == name
    end)
  end

  defp configured_listeners do
    :video_conference
    |> Application.get_env(:stream_server_admin_portal, [])
    |> Keyword.get(:event_listeners, [])
  end
end
