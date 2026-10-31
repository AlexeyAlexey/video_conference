defmodule VideoConference.StreamServerAdminPortalFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.StreamServerAdminPortal` contexts.
  """

  alias VideoConference.StreamServerAdminPortal.Accounts
  alias VideoConference.StreamServerAdminPortal.Accounts.{Admin, Scope}
  alias VideoConference.StreamServerAdminPortal.Applications
  alias VideoConference.StreamServerAdminPortal.Applications.{ApiKey, Application}

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

  def unique_application_name, do: "application-#{System.unique_integer([:positive])}"
  def unique_api_key_name, do: "api-key-#{System.unique_integer([:positive])}"

  def application_fixture(attrs \\ %{}) do
    {:ok, %Application{} = application} =
      attrs
      |> Enum.into(%{"name" => unique_application_name()})
      |> Applications.create_application()

    application
  end

  def api_key_fixture(%Application{} = application, attrs \\ %{}) do
    {:ok, %ApiKey{} = api_key} =
      attrs
      |> Enum.into(%{"name" => unique_api_key_name()})
      |> Map.put("application_id", application.id)
      |> Applications.create_api_key()

    api_key
  end
end
