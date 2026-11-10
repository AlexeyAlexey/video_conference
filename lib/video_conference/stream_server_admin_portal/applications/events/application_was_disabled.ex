defmodule VideoConference.StreamServerAdminPortal.Applications.ApplicationWasDisabled do
  @moduledoc """
  Domain event emitted when an application is disabled.

  `stream_id` is the application's id — the event lands on that
  application's stream. `lock_version` is the application's version
  after the update; the event type implies the new `enabled` value.
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
