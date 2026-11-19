defmodule VideoConference.StreamServerAdminPortal.StreamServers.StreamServerWasAssignedToApplication do
  @moduledoc """
  Domain event emitted when a stream server is assigned to an
  application.

  `stream_id` is the stream server's id — the event lands on that
  server's stream. `application_id` is the assigned application, and
  `lock_version` the incremented version after the assignment.
  """
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  defstruct [:stream_id, :id, :application_id, :lock_version]

  @doc """
  Builds the event from the `%StreamServer{}` after its `lock_version`
  bump and the assigned application's id.
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
