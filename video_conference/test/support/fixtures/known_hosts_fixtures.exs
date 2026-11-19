defmodule VideoConference.KnownHostsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.AdminPortal.KnownHosts` context.
  """

  alias VideoConference.AdminPortal.KnownHosts
  alias VideoConference.AdminPortal.KnownHosts.KnownHost
  alias VideoConference.Repo

  def unique_known_host_name, do: "host#{System.unique_integer([:positive])}"

  def valid_known_host_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => unique_known_host_name(),
      "name_alias" => "some alias",
      "description" => "some description",
      "host" => "192.168.1.1:4433",
      "enabled" => true
    })
  end

  def known_host_fixture(attrs \\ %{}) do
    {:ok, %KnownHost{} = known_host} =
      attrs
      |> valid_known_host_attributes()
      |> KnownHosts.create_known_host()

    known_host
  end

  @doc """
  Returns the seeded current host row.
  """
  def current_host_fixture do
    Repo.get_by!(KnownHost, current_host: true)
  end
end
