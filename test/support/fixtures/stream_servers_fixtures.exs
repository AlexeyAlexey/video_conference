defmodule VideoConference.StreamServersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.AdminPortal.StreamServers` context.
  """

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.StreamServer

  def unique_stream_server_name, do: "server#{System.unique_integer([:positive])}"

  def valid_stream_server_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => unique_stream_server_name(),
      "description" => "some description",
      "host" => "192.168.1.1:4433",
      "cert_hash" => "abc123"
    })
  end

  def stream_server_fixture(attrs \\ %{}) do
    {:ok, %StreamServer{} = stream_server} =
      attrs
      |> valid_stream_server_attributes()
      |> StreamServers.create_stream_server()

    stream_server
  end
end
