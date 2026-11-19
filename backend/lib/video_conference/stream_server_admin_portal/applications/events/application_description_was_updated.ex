defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationDescriptionWasUpdated do
  @moduledoc """
  Domain event emitted when an application's description is updated.

  `stream_id` is the application's id — the event lands on that
  application's stream. `description` is the new description and
  `lock_version` the application's version after the update.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  defstruct [:stream_id, :id, :description, :lock_version]

  @doc """
  Builds the event from an `%Application{}`.
  """
  def new(%Application{} = application) do
    %__MODULE__{
      stream_id: application.id,
      id: application.id,
      description: application.description,
      lock_version: application.lock_version
    }
  end
end
