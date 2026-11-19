defmodule VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKeyWasMoved do
  @moduledoc """
  Domain event emitted when a stream server public key is moved to
  another application.

  `stream_id` is the moved key's id — the event lands on that key's
  stream. `from_application_id` is the source application,
  `to_application_id` the destination, and `lock_version` the
  incremented version after the move.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.StreamServerPublicKey

  defstruct [:stream_id, :id, :from_application_id, :to_application_id, :lock_version]

  @doc """
  Builds the event from the pre-move and post-move
  `%StreamServerPublicKey{}` structs.
  """
  def new(%StreamServerPublicKey{} = before_move, %StreamServerPublicKey{} = after_move) do
    %__MODULE__{
      stream_id: after_move.id,
      id: after_move.id,
      from_application_id: before_move.application_id,
      to_application_id: after_move.application_id,
      lock_version: after_move.lock_version
    }
  end
end
