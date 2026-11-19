defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasDisabled do
  @moduledoc """
  Domain event emitted when a stream server public key is disabled.

  `stream_id` is the disabled key's id — the event lands on that key's
  stream. `lock_version` is the incremented version after the update.
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
