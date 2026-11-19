defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasAdded do
  @moduledoc """
  Domain event emitted when a stream server public key is created.

  `stream_id` is the created key's id — the event lands on that key's
  stream. The remaining fields snapshot the key's values at creation
  time; `lock_version` is always 1.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey

  defstruct [:stream_id, :id, :application_id, :name, :key, :enabled, :description, :lock_version]

  @doc """
  Builds the event from a `%StreamServerPublicKey{}`.
  """
  def new(%StreamServerPublicKey{} = key) do
    %__MODULE__{
      stream_id: key.id,
      id: key.id,
      application_id: key.application_id,
      name: key.name,
      key: key.key,
      enabled: key.enabled,
      description: key.description,
      lock_version: key.lock_version
    }
  end
end
