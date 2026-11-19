defmodule VideoConference.StreamServerAdminPortal.StreamServers.StreamServerWasAdded do
  @moduledoc """
  Domain event emitted when a stream server is created.

  `stream_id` is the created stream server's id — the event lands on
  that server's stream. The remaining fields snapshot the server's
  values at creation time; `lock_version` is always 1.
  """
  alias VideoConference.StreamServerAdminPortal.StreamServers.StreamServer

  defstruct [
    :stream_id,
    :id,
    :name,
    :description,
    :host,
    :country,
    :settings,
    :cert_hash,
    :lock_version
  ]

  @doc """
  Builds the event from a `%StreamServer{}`.
  """
  def new(%StreamServer{} = stream_server) do
    %__MODULE__{
      stream_id: stream_server.id,
      id: stream_server.id,
      name: stream_server.name,
      description: stream_server.description,
      host: stream_server.host,
      country: stream_server.country,
      settings: stream_server.settings,
      cert_hash: stream_server.cert_hash,
      lock_version: stream_server.lock_version
    }
  end
end
