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
  Renames a stream server. `host` is immutable and cannot be changed
  through this function.
  """
  def rename_stream_server(id, name) do
    id
    |> get_stream_server!()
    |> StreamServer.name_changeset(%{"name" => name})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server's description. `host` is immutable and cannot
  be changed through this function.
  """
  def edit_stream_server_description(id, description) do
    id
    |> get_stream_server!()
    |> StreamServer.description_changeset(%{"description" => description})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server's country. `host` is immutable and cannot be
  changed through this function.
  """
  def edit_stream_server_country(id, country) do
    id
    |> get_stream_server!()
    |> StreamServer.country_changeset(%{"country" => country})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Updates a stream server's certificate hash. `host` is immutable and
  cannot be changed through this function.
  """
  def edit_stream_server_cert_hash(id, cert_hash) do
    id
    |> get_stream_server!()
    |> StreamServer.cert_hash_changeset(%{"cert_hash" => cert_hash})
    |> Repo.update(stale_error_field: :lock_version)
  end

  @doc """
  Deletes a stream server. Its application assignments are removed by the
  database's `on_delete: :delete_all` foreign key.
  """
  def delete_stream_server(%StreamServer{} = stream_server) do
    stream_server
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.optimistic_lock(:lock_version)
    |> Repo.delete(stale_error_field: :lock_version)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking stream server changes.
  """
  def change_stream_server(%StreamServer{} = stream_server, attrs \\ %{}) do
    StreamServer.changeset(stream_server, attrs)
  end

  @doc """
  Assigns one application to a stream server, returning the server
  reloaded with its applications preloaded. Assigning an already
  assigned application is a no-op.
  """
  def assign_application(stream_server_id, application_id) do
    Repo.insert(
      %ApplicationStreamServer{
        stream_server_id: stream_server_id,
        application_id: application_id
      },
      on_conflict: :nothing
    )

    {:ok, get_stream_server!(stream_server_id)}
  end

  @doc """
  Removes one application's assignment from a stream server, returning
  the server reloaded with its applications preloaded. Unassigning an
  application that is not assigned is a no-op.
  """
  def unassign_application(stream_server_id, application_id) do
    Repo.delete_all(
      from j in ApplicationStreamServer,
        where: j.stream_server_id == ^stream_server_id and j.application_id == ^application_id
    )

    {:ok, get_stream_server!(stream_server_id)}
  end
end
