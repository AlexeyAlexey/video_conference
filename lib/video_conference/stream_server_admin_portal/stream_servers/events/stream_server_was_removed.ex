defmodule VideoConference.StreamServerAdminPortal.StreamServers.StreamServerWasRemoved do
  @moduledoc """
  Domain event emitted when a stream server is deleted.

  `stream_id` is the removed stream server's id — the event lands on
  that server's stream as its tombstone. `lock_version` is the version
  the delete matched (deletes do not increment it).
  """
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  defstruct [:stream_id, :id, :lock_version]

  @doc """
  Builds the event from a `%StreamServer{}`.
  """
  def new(%StreamServer{} = stream_server) do
    %__MODULE__{
      stream_id: stream_server.id,
      id: stream_server.id,
      lock_version: stream_server.lock_version
    }
  end
end
