defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationWasRemoved do
  @moduledoc """
  Domain event emitted when an application is deleted.

  `stream_id` is the removed application's id — the event lands on that
  application's stream as its tombstone. `lock_version` is the version
  the delete matched (deletes do not increment it).
  """
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  defstruct [:stream_id, :id, :lock_version]

  @doc """
  Builds the event from an `%Application{}`.
  """
  def new(%Application{} = application) do
    %__MODULE__{
      stream_id: application.id,
      id: application.id,
      lock_version: application.lock_version
    }
  end
end
