defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasRemoved do
  @moduledoc """
  Domain event emitted when a stream server public key is deleted.

  `stream_id` is the removed key's id — the event lands on that key's
  stream as its tombstone. `lock_version` is the version the delete
  matched (deletes do not increment it).
  """
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey

  defstruct [:stream_id, :id, :lock_version]

  @doc """
  Builds the event from a `%StreamServerPublicKey{}`.
  """
  def new(%StreamServerPublicKey{} = key) do
    %__MODULE__{
      stream_id: key.id,
      id: key.id,
      lock_version: key.lock_version
    }
  end
end
