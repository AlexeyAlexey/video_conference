defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationWasAdded do
  @moduledoc """
  Domain event emitted when an application is created.

  `stream_id` is the created application's id — the event lands on that
  application's stream. The remaining fields snapshot the application's
  values at creation time; `lock_version` is always 1.
  """
  alias VideoConference.StreamServerAdminPortal.Applications.Application

  defstruct [:stream_id, :id, :name, :description, :enabled, :lock_version]

  @doc """
  Builds the event from an `%Application{}`.
  """
  def new(%Application{} = application) do
    %__MODULE__{
      stream_id: application.id,
      id: application.id,
      name: application.name,
      description: application.description,
      enabled: application.enabled,
      lock_version: application.lock_version
    }
  end
end
