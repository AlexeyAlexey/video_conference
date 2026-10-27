defmodule VideoConference.AdminPortal.StreamServers do
  @moduledoc """
  The AdminPortal StreamServers context.

  Manages the directory of HTTP/3 stream servers — self-hosted and
  third-party — that can carry video, audio, and event streams.
  """

  import Ecto.Query, warn: false
  alias VideoConference.Repo

  alias VideoConference.AdminPortal.StreamServers.StreamServer

  @doc """
  Returns all stream servers, ordered by name.
  """
  def list_stream_servers do
    Repo.all(from s in StreamServer, order_by: [asc: s.name])
  end

  @doc """
  Gets a single stream server.

  Raises `Ecto.NoResultsError` if the stream server does not exist.
  """
  def get_stream_server!(id), do: Repo.get!(StreamServer, id)

  @doc """
  Creates a stream server.
  """
  def create_stream_server(attrs \\ %{}) do
    %StreamServer{}
    |> StreamServer.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a stream server.
  """
  def update_stream_server(%StreamServer{} = stream_server, attrs) do
    stream_server
    |> StreamServer.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a stream server.
  """
  def delete_stream_server(%StreamServer{} = stream_server) do
    Repo.delete(stream_server)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server changes.
  """
  def change_stream_server(%StreamServer{} = stream_server, attrs \\ %{}) do
    StreamServer.changeset(stream_server, attrs)
  end
end
