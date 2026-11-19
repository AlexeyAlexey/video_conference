defmodule VideoConference.StreamServerAdminPortal.Accounts.Scope do
  @moduledoc """
  Defines the scope of the admin caller to be used throughout the stream
  server admin portal.

  Mirrors `VideoConference.AdminPortal.Accounts.Scope`, carrying the
  authenticated portal admin.
  """

  alias VideoConference.StreamServerAdminPortal.Accounts.Admin

  defstruct admin: nil

  @doc """
  Creates a scope for the given admin.

  Returns nil if no admin is given.
  """
  def for(%Admin{} = admin) do
    %__MODULE__{admin: admin}
  end

  def for(nil), do: nil
end
