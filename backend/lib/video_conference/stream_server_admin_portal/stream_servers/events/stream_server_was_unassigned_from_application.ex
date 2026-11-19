defmodule VideoConference.StreamServerAdminPortal.StreamServers.StreamServerWasUnassignedFromApplication do
  @moduledoc """
  Domain event emitted when a stream server is unassigned from an
  application.

  `stream_id` is the stream server's id — the event lands on that
  server's stream. `application_id` is the unassigned application, and
  `lock_version` the incremented version after the unassignment.
  """
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  defstruct [:stream_id, :id, :application_id, :lock_version]

  @doc """
  Builds the event from the `%StreamServer{}` after its `lock_version`
  bump and the unassigned application's id.
  """
  def new(%StreamServer{} = stream_server, application_id) do
    %__MODULE__{
      stream_id: stream_server.id,
      id: stream_server.id,
      application_id: application_id,
      lock_version: stream_server.lock_version
    }
  end
end
