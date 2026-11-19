defmodule VideoConference.PublicStreamServerKeysFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `VideoConference.AdminPortal.StreamServers` context.
  """

  alias VideoConference.AdminPortal.StreamServers
  alias VideoConference.AdminPortal.StreamServers.PublicStreamServerKey

  def unique_public_key_name, do: "key#{System.unique_integer([:positive])}"

  def valid_private_key_pem,
    do: "-----BEGIN PRIVATE KEY-----\nfake-private-key\n-----END PRIVATE KEY-----"

  def valid_public_key_pem,
    do: "-----BEGIN PUBLIC KEY-----\nfake-public-key\n-----END PUBLIC KEY-----"

  def valid_public_stream_server_key_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "name" => unique_public_key_name(),
      "public_key" => valid_public_key_pem(),
      "private_key_pem" => valid_private_key_pem(),
      "description" => "some description"
    })
  end

  def public_stream_server_key_fixture(stream_server, attrs \\ %{}) do
    {:ok, %PublicStreamServerKey{} = key} =
      attrs
      |> valid_public_stream_server_key_attributes()
      |> Map.put("stream_server_id", stream_server.id)
      |> StreamServers.create_public_stream_server_key()

    key
  end
end
