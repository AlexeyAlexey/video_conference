defmodule VideoConference.StreamServerAdminPortal.StreamServers do
  @moduledoc """
  The StreamServerAdminPortal StreamServers context.

  Manages the portal's registry of physical stream servers — the servers
  available to carry video, audio, and event streams — and their
  many-to-many assignment to applications.
  """

  import Ecto.Query, warn: false
  alias VideoConference.StreamServerAdminPortal.Repo

  alias VideoConference.StreamServerAdminPortal.Applications.Application

  alias VideoConference.StreamServerAdminPortal.StreamServers.{
    ApplicationStreamServer,
    StreamServer
  }

  @doc """
  Returns all stream servers ordered by name, each with its assigned
  applications preloaded (ordered by name).

  Options:

    * `:application_id` — limits the list to servers assigned to the given
      application id, or to servers with no assigned application when
      `"unassigned"` is passed. `nil` or `""` lists every server.
  """
  def list_stream_servers(opts \\ []) do
    applications = from a in Application, order_by: [asc: a.name]

    StreamServer
    |> filter_by_application(Keyword.get(opts, :application_id))
    |> order_by([s], asc: s.name)
    |> preload(applications: ^applications)
    |> Repo.all()
  end

  defp filter_by_application(query, application_id) when application_id in [nil, ""],
    do: query

  defp filter_by_application(query, "unassigned") do
    from s in query,
      left_join: j in ApplicationStreamServer,
      on: j.stream_server_id == s.id,
      where: is_nil(j.stream_server_id)
  end

  defp filter_by_application(query, application_id) do
    from s in query,
      join: j in ApplicationStreamServer,
      on: j.stream_server_id == s.id,
      where: j.application_id == ^application_id
  end

  @doc """
  Gets a single stream server with its assigned applications preloaded.

  Raises `Ecto.NoResultsError` if the stream server does not exist.
  """
  def get_stream_server!(id) do
    StreamServer
    |> Repo.get!(id)
    |> Repo.preload(:applications)
  end

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
  Deletes a stream server. Its application assignments are removed by the
  database's `on_delete: :delete_all` foreign key.
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

  @doc """
  Replaces the server's assigned applications with exactly the
  applications matching `application_ids`, returning the updated server
  with its applications preloaded.
  """
  def assign_applications(%StreamServer{} = stream_server, application_ids) do
    applications =
      Repo.all(from a in Application, where: a.id in ^List.wrap(application_ids))

    stream_server
    |> Repo.preload(:applications)
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:applications, applications)
    |> Repo.update()
  end
end
