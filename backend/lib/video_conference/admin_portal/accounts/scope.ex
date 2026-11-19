defmodule VideoConference.AdminPortal.Accounts.Scope do
  @moduledoc """
  Defines the scope of the admin caller to be used throughout the admin portal.

  Mirrors `VideoConference.Accounts.Scope`, carrying the authenticated
  admin instead of a phone.
  """

  alias VideoConference.AdminPortal.Accounts.Admin

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
