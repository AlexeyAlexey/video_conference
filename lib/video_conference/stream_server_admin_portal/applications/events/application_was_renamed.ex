defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationWasRenamed do
  @moduledoc """
  Domain event emitted when an application is renamed.

  `stream_id` is the application's id — the event lands on that
  application's stream. `name` is the new name and `lock_version` the
  application's version after the rename.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  defstruct [:stream_id, :id, :name, :lock_version]

  @doc """
  Builds the event from an `%Application{}`.
  """
  def new(%Application{} = application) do
    %__MODULE__{
      stream_id: application.id,
      id: application.id,
      name: application.name,
      lock_version: application.lock_version
    }
  end
end
