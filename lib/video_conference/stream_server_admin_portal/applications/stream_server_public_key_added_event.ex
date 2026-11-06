defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyAddedEvent do
  @moduledoc """
  Domain event emitted when a stream server public key is created.

  `stream_id` is the created key's id — the event lands on that key's
  stream. The remaining fields snapshot the key's values at creation
  time.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey

  defstruct [:stream_id, :application_id, :name, :key, :enabled, :description]

  @doc """
  Builds the event from a `%StreamServerPublicKey{}`.
  """
  def new(%StreamServerPublicKey{} = key) do
    %__MODULE__{
      stream_id: key.id,
      application_id: key.application_id,
      name: key.name,
      key: key.key,
      enabled: key.enabled,
      description: key.description
    }
  end
end
