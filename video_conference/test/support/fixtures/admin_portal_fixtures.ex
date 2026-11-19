defmodule VideoConference.AdminPortalFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.AdminPortal` contexts.
  """

  alias VideoConference.AdminPortal.Accounts
  alias VideoConference.AdminPortal.Accounts.{Admin, Scope}

  def unique_admin_email, do: "admin#{System.unique_integer([:positive])}@example.com"
  def valid_admin_password, do: "hello world!"

  def valid_admin_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "email" => unique_admin_email(),
      "password" => valid_admin_password(),
      "password_confirmation" => valid_admin_password()
    })
  end

  def admin_fixture(attrs \\ %{}) do
    {:ok, %Admin{} = admin} =
      attrs
      |> valid_admin_attributes()
      |> Accounts.register_admin()

    admin
  end

  def admin_scope_fixture(admin) do
    Scope.for(admin)
  end
end
